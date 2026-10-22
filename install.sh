#!/usr/bin/env bash
#
# install.sh — phase 1 (and 3) of the Arch install. RUN THIS FROM THE LIVE ISO,
# as root, after you have partitioned, formatted and mounted everything.
#
#   cd /root/arch-configs && ./install.sh
#
# What it does, in order:
#   1. preflight: verify the live environment, the mount table, and network
#   2. pacstrap: install packages/official.txt into /mnt
#   3. genfstab:  generate /mnt/etc/fstab from the live mount table
#   4. stage:     copy this repo into /mnt/root/arch-configs
#   5. chroot:    run install-chroot.sh inside /mnt for everything that needs
#                 the new root (initramfs, GRUB, users, services, dotfiles, AUR)
#   6. print the remaining manual commands
#
# It never partitions, formats, or creates subvolumes. You own that.
#
# This script is idempotent: every step checks state before acting, so a failed
# or interrupted run can simply be repeated.

set -euo pipefail

# Absolute path of this script's directory, so the script works no matter which
# directory it is invoked from.
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Shared logging and idempotent-write helpers.
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

# The new system is always mounted at /mnt by convention on the Arch ISO.
TARGET=/mnt

# Where the repo is staged inside the new root, so the chroot phase can read it.
STAGED="$TARGET/root/arch-configs"

# ---------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------

# check_live_iso — make sure we really are on the Arch ISO. Running this on an
# installed system would pacstrap over /mnt, which is never intended.
check_live_iso() {
  [[ -f /etc/arch-release ]] || die "this does not look like the Arch live ISO (/etc/arch-release missing)"
  log "running on the Arch live ISO"
}

# check_network — pacstrap needs to reach a mirror. Fail early with a clear
# message instead of letting pacstrap fail halfway through.
check_network() {
  if ping -c1 -W3 -q archlinux.org >/dev/null 2>&1; then
    log "network reachable"
  else
    die "no network. Connect first (ethernet, or: iwctl -> station wlan0 connect <SSID>)"
  fi
}

# check_mounts — verify the layout this installer assumes.
#
# The subvolume checks use findmnt's resolved *mount point*, not `--target`'s
# "does some mount cover this path" answer. `findmnt --target /mnt/var/lib/containerd`
# succeeds even when nothing is mounted there, because the mount at /mnt covers
# the path — which is why the old check never warned about a missing @docker.
#
# Verify only. Mounting and subvolume creation are yours to do (README §4-§5).
check_mounts() {
  local root_fstype root_opts
  root_fstype=$(findmnt -n -o FSTYPE --target "$TARGET" 2>/dev/null || true)
  [[ $root_fstype == btrfs ]] || die "$TARGET is not btrfs (found: ${root_fstype:-nothing})"

  root_opts=$(findmnt -n -o OPTIONS --target "$TARGET")
  [[ $root_opts == *subvol=/@* ]] || die "$TARGET is not mounted with subvol=/@ (found: $root_opts)"
  log "root: btrfs subvol=/@"

  local boot_target
  boot_target=$(findmnt -n -o TARGET --target "$TARGET/boot" 2>/dev/null || true)
  [[ $boot_target == "$TARGET/boot" ]] \
    || die "$TARGET/boot is not a mountpoint — mount the ESP there before running this"
  local boot_fstype
  boot_fstype=$(findmnt -n -o FSTYPE --target "$TARGET/boot")
  [[ $boot_fstype == vfat ]] || die "$TARGET/boot is not vfat (found: $boot_fstype)"
  log "boot: vfat ESP"

  # These are strongly recommended, not required. Warn rather than abort: without
  # them the install still works, but snapshots pin the pacman cache, containerd's
  # content store and the logs, and grub-btrfs cannot boot snapshots read-only.
  #
  # This machine mounts the @docker subvolume at /var/lib/containerd, so that is
  # the path checked here. /var/lib/docker is deliberately NOT checked and NOT
  # mentioned: it stays inside @ on this layout. Only the mount is verified — the
  # installer never creates, formats or mounts anything itself.
  local -a wanted=(/var/log /var/cache/pacman/pkg /var/lib/containerd)
  local sub resolved
  for sub in "${wanted[@]}"; do
    resolved=$(findmnt -n -o TARGET --target "$TARGET$sub" 2>/dev/null || true)
    if [[ $resolved == "$TARGET$sub" ]]; then
      log "separate mount: $sub ($(findmnt -n -o SOURCE --target "$TARGET$sub"))"
    else
      warn "$sub is not a separate mount (resolves to ${resolved:-nothing}) — it will be captured by snapshots"
    fi
  done
}

# check_repo — the package lists and everything else must be present and readable.
check_repo() {
  [[ -f $HERE/packages/official.txt ]] || die "packages/official.txt missing"
  [[ -f $HERE/install-chroot.sh ]]     || die "install-chroot.sh missing"
  (( $(grep -c . "$HERE/packages/official.txt") > 0 )) || die "packages/official.txt is empty"
  log "repo looks complete"
}

# ---------------------------------------------------------------------------
# 2-4. pacstrap, fstab, staging
# ---------------------------------------------------------------------------

# do_mirrors_iso — rank the OFFICIAL Arch mirrors from the live ISO before
# pacstrap touches the network. reflector may not exist on the ISO, in which case
# rank_mirrors() falls back to the official mirror status JSON with curl+python3
# (both on the ISO); if neither is available it leaves the mirrorlist alone.
# Nothing here adds a repository or touches pacman.conf.
do_mirrors_iso() {
  rank_mirrors
}

# do_mirrors_target — copy the ranked mirrorlist onto the new root once pacstrap
# has created /etc, so the installed system starts with the same ordering. The
# chroot phase re-ranks it in place (reflector is in official.txt); this copy is
# what makes that non-critical.
do_mirrors_target() {
  local dst=$TARGET/etc/pacman.d/mirrorlist
  if [[ ! -d $TARGET/etc/pacman.d ]]; then
    warn "$TARGET/etc/pacman.d missing — did pacstrap run? skipping the mirrorlist copy"
    return 0
  fi
  if [[ -f $dst ]]; then
    backup_once "$dst"
  fi
  write_file "$dst" 0644 root:root < /etc/pacman.d/mirrorlist
  log "copied the ranked mirrorlist to $dst"
}

# do_pacstrap — install every package in official.txt into the new root.
#   -K  initialise the pacman keyring on the target (needed for a fresh root)
#   -c  use the host's package cache, which on the ISO is the offline mirror
#
# Idempotency: the old check was "is /var/lib/pacman/local non-empty", which is
# true after a pacstrap that died on package 40 of 176. Instead ask pacman on the
# TARGET which of the listed packages are missing and only re-run when there is
# something to do. `pacstrap` with --needed would also work, but asking first
# avoids a multi-minute no-op.
do_pacstrap() {
  local -a pkgs=() missing=() p
  mapfile -t pkgs < <(grep -v '^[[:space:]]*$' "$HERE/packages/official.txt")
  (( ${#pkgs[@]} )) || die "packages/official.txt is empty"

  if [[ -d $TARGET/var/lib/pacman/local ]]; then
    for p in "${pkgs[@]}"; do
      pacman --root "$TARGET" --dbpath "$TARGET/var/lib/pacman" -Qq "$p" >/dev/null 2>&1 \
        || missing+=("$p")
    done
    if (( ${#missing[@]} == 0 )); then
      skip "all ${#pkgs[@]} official packages already installed on $TARGET"
      return 0
    fi
    warn "${#missing[@]} of ${#pkgs[@]} packages missing on $TARGET — resuming pacstrap"
    log "missing: ${missing[*]}"
    run "pacstrap $TARGET (resume)" -- pacstrap -K "$TARGET" "${pkgs[@]}"
  else
    log "pacstrap: ${#pkgs[@]} packages (fresh root)"
    run "pacstrap $TARGET" -- pacstrap -K "$TARGET" "${pkgs[@]}"
  fi
}

# do_fstab — generate /mnt/etc/fstab from the live mount table.
# -U writes UUID= rather than device paths, which is what you want for NVMe.
# This file is never hand-edited afterwards: grub-btrfs parses its mount options
# to build the rootflags for snapshot boot entries.
#
# Written afresh ("") rather than appended (">>"): genfstab emits its own header,
# so appending to a partial file produced duplicate entries and duplicate headers.
do_fstab() {
  if [[ -s $TARGET/etc/fstab ]] && grep -qs 'subvol=/@' "$TARGET/etc/fstab"; then
    skip "fstab already generated"
    return 0
  fi
  [[ -f $TARGET/etc/fstab ]] && backup_once "$TARGET/etc/fstab"
  local tmp; tmp=$(mktemp)
  # genfstab writes to stdout, so capture it, show it, then install it.
  run "genfstab -U $TARGET" -- sh -c "genfstab -U '$TARGET' | tee '$tmp'"
  write_file "$TARGET/etc/fstab" 0644 root:root <"$tmp"
  rm -f "$tmp"
  log "wrote: $TARGET/etc/fstab"
}

# do_stage — copy the repo into the new root. .git is kept on purpose so the
# installed system can `git pull` later. Deleted-in-repo files are removed from
# the staged copy so a resumed install never runs a stale script.
do_stage() {
  mkdir -p "$STAGED"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git/objects/pack/tmp*' "$HERE/" "$STAGED/"
  else
    cp -a "$HERE/." "$STAGED/"
  fi
  log "staged repo: $HERE -> $STAGED"
}

# ---------------------------------------------------------------------------
# 5. Chroot phase
# ---------------------------------------------------------------------------

# do_chroot — hand over to install-chroot.sh with /mnt as the new root.
# arch-chroot bind-mounts /etc/resolv.conf and the kernel filesystems, so the
# chroot has working DNS (needed for the AUR step) and /proc, /sys, /dev.
#
# arch-chroot gives no visual cue that the root changed (your prompt stays the
# same, it runs a command, not an interactive shell), so announce it explicitly
# and print what / is about to become. install-chroot.sh re-verifies this from
# the inside with verify_chroot().
do_chroot() {
  chmod +x "$STAGED/install-chroot.sh"
  log "entering chroot: $TARGET becomes / (no prompt change — arch-chroot runs the script non-interactively)"
  log "the new root is $(findmnt -n -o SOURCE,FSTYPE --target "$TARGET")"
  run "arch-chroot $TARGET install-chroot.sh" -- \
    arch-chroot "$TARGET" /root/arch-configs/install-chroot.sh
}

# ---------------------------------------------------------------------------
# 6. Done
# ---------------------------------------------------------------------------

# print_next_steps — the only things left are the ones this script must not do.
print_next_steps() {
  cat <<EOF

${_c_bold}Install complete.${_c_reset}

Finish with:

  umount -R $TARGET
  reboot

Then, once you are logged in at SDDM:

  - add the printer at http://localhost:631   (cups is enabled, the driver is installed)
  - gh auth login                             (github-cli is installed, not authenticated)
  - drop your own binaries into ~/Bin         (already on PATH)

Rollback: the installer took a "post-install" snapshot, so the first entry under
"Arch Linux snapshots" in the GRUB menu boots this exact state read-only.

If a phase failed, just run ./install.sh again: completed phases are recorded in
${COMPLETED} and skipped, and the chroot continues where it stopped. To redo
everything: ARCH_FORCE=1 ./install.sh
Per-command output: ${ARCH_LOGDIR}/*.log
EOF
}

# ---------------------------------------------------------------------------

main() {
  log "logs: $ARCH_LOGDIR"
  log "state: $COMPLETED"

  section "Preflight"
  need_root
  check_live_iso
  check_repo
  check_mounts
  check_network

  step "mirrors-iso"    do_mirrors_iso
  step "pacstrap"       do_pacstrap
  step "mirrors-target" do_mirrors_target
  step "fstab"          do_fstab

  # Staging is deliberately NOT a step: it must run on every invocation, so a
  # re-run always executes the repo as it is on disk now, not the copy that was
  # staged before you edited it.
  section "Staging the repo into the new root"
  do_stage

  step "chroot"   do_chroot

  print_next_steps
}

main "$@"
