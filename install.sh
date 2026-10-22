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

# check_mounts — verify the layout this installer assumes. The subvolume names
# are not cosmetic: @ is what snapper snapshots, @var_log is required by
# grub-btrfs for read-only snapshot boots, and @pkg/@docker keep the pacman
# cache and docker layers out of snapshots.
check_mounts() {
  local root_fstype root_opts
  root_fstype=$(findmnt -n -o FSTYPE --target "$TARGET" 2>/dev/null || true)
  [[ $root_fstype == btrfs ]] || die "$TARGET is not btrfs (found: ${root_fstype:-nothing})"

  root_opts=$(findmnt -n -o OPTIONS --target "$TARGET")
  [[ $root_opts == *subvol=/@* ]] || die "$TARGET is not mounted with subvol=/@ (found: $root_opts)"
  log "root: btrfs subvol=/@"

  findmnt -n --target "$TARGET/boot" >/dev/null 2>&1 \
    || die "$TARGET/boot is not mounted — mount the ESP there before running this"
  local boot_fstype
  boot_fstype=$(findmnt -n -o FSTYPE --target "$TARGET/boot")
  [[ $boot_fstype == vfat ]] || die "$TARGET/boot is not vfat (found: $boot_fstype)"
  log "boot: vfat ESP"

  # These three are strongly recommended, not required. Warn rather than abort:
  # without them the install still works, but snapshots will pin the pacman
  # cache and docker layers, and grub-btrfs cannot boot snapshots read-only.
  local sub
  for sub in /var/log /var/cache/pacman/pkg /var/lib/docker; do
    if findmnt -n --target "$TARGET$sub" >/dev/null 2>&1; then
      log "separate subvolume: $sub"
    else
      warn "$sub is not a separate subvolume — it will be captured by snapshots"
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

# do_pacstrap — install every package in official.txt into the new root.
#   -K  initialise the pacman keyring on the target (needed for a fresh root)
#   -c  use the host's package cache, which on the ISO is the offline mirror
# Reading the list with $(<file) word-splits on whitespace, so blank lines and
# multiple names per line would both work; the file uses one name per line.
do_pacstrap() {
  # Idempotent: if the target already has a populated pacman database, the
  # packages are in. Re-running pacstrap would just re-download and reinstall.
  if [[ -d $TARGET/var/lib/pacman/local ]] && (( $(ls -1A $TARGET/var/lib/pacman/local 2>/dev/null | wc -l) > 0 )); then
    skip "pacstrap already done (pacman db present on $TARGET)"
    return 0
  fi
  local -a pkgs
  mapfile -t pkgs < <(grep -v '^[[:space:]]*$' "$HERE/packages/official.txt")
  log "pacstrap: ${#pkgs[@]} packages"
  pacstrap -K $TARGET "${pkgs[@]}"
}

# do_fstab — generate /mnt/etc/fstab from the live mount table.
# -U writes UUID= rather than device paths, which is what you want for NVMe.
# This file is never hand-edited afterwards: grub-btrfs parses its mount options
# to build the rootflags for snapshot boot entries.
do_fstab() {
  if [[ -f $TARGET/etc/fstab ]] && grep -qs 'subvol=/' "$TARGET/etc/fstab"; then
    skip "fstab already generated"
    return 0
  fi
  genfstab -U "$TARGET" >>"$TARGET/etc/fstab"
  log "wrote: $TARGET/etc/fstab"
}

# do_stage — copy the repo into the new root. .git is kept on purpose so the
# installed system can `git pull` later.
do_stage() {
  mkdir -p "$STAGED"
  cp -a "$HERE/." "$STAGED/"
  log "staged repo: $HERE -> $STAGED"
}

# ---------------------------------------------------------------------------
# 5. Chroot phase
# ---------------------------------------------------------------------------

# do_chroot — hand over to install-chroot.sh with /mnt as the new root.
# arch-chroot bind-mounts /etc/resolv.conf and the kernel filesystems, so the
# chroot has working DNS (needed for the AUR step) and /proc, /sys, /dev.
do_chroot() {
  [[ -x $STAGED/install-chroot.sh ]] || chmod +x "$STAGED/install-chroot.sh"
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
EOF
}

# ---------------------------------------------------------------------------

main() {
  section "Preflight"
  need_root
  check_live_iso
  check_repo
  check_mounts
  check_network

  section "Installing packages (pacstrap)"
  do_pacstrap

  section "Generating fstab"
  do_fstab

  section "Staging the repo into the new root"
  do_stage

  section "Configuring the new system (chroot)"
  do_chroot

  print_next_steps
}

main "$@"
