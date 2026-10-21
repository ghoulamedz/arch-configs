#!/usr/bin/env bash
#
# install-chroot.sh — phase 2. Runs INSIDE `arch-chroot /mnt`, invoked by
# install.sh. Everything here needs the new root to be `/`: mkinitcpio, GRUB,
# useradd, systemctl enable, snapper, locale-gen, and the AUR build (which must
# run as a normal user, because makepkg refuses to run as root).
#
# Ordered deliberately. Two orderings matter and are explained at the point they
# happen: snapper's create-config must run before anything else writes much to /,
# and the dotfiles must land before the AUR step because paru runs as medo.
#
# Idempotent throughout: every step checks state before acting.

set -euo pipefail

# The repo as staged inside the new root by install.sh.
REPO=/root/arch-configs

# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration — everything specific to this machine lives here.
# ---------------------------------------------------------------------------

USER_NAME=medo                                        # login name
USER_HOME=/home/medo                                  # its home directory
HOST_NAME=medo-box                                    # /etc/hostname
TIMEZONE=Africa/Tunis                                 # /etc/localtime
LANG_VALUE=en_US.UTF-8                                # global LANG
LOCALES=(en_US.UTF-8 fr_FR.UTF-8 ar_EG.UTF-8)         # generated locales
TTY_KEYMAP=fr-pc                                      # console keymap (AZERTY)
GIT_NAME=ghoulamedz                                   # ~/.gitconfig user.name
GIT_EMAIL=mluke4120@gmail.com                         # ~/.gitconfig user.email

# Groups to add medo to. Filtered against /etc/group at runtime, so a group that
# does not exist (because its package is not installed) is skipped, not fatal.
GROUP_CANDIDATES=(wheel docker video render audio input lp storage)

# Units to enable. `enable_service` skips any unit whose file is missing.
SERVICES=(
  NetworkManager          # networking, driven by nmcli / the Waybar network module
  systemd-timesyncd       # NTP. Nothing else on this system syncs the clock: without
                          # it, HTTPS certificate checks and pacman signature
                          # timestamps drift after the first NTP-less week
  bluetooth               # bluetoothd, for bluez
  sddm                    # graphical login
  thermald                # Intel thermal management (this is a 14700HX)
  power-profiles-daemon   # powerprofilesctl
  docker                  # container daemon
  cups                    # printing, for the Pantum driver
  ufw                     # firewall; the policy itself is applied by
                          # configure_firewall(), not by enabling the unit
  plocate-updatedb.timer  # keeps the locate database current
  paccache.timer          # weekly pacman cache cleanup
  snapper-timeline.timer  # hourly timeline snapshots
  snapper-cleanup.timer   # prunes old snapshots
  grub-btrfsd             # regenerates the GRUB snapshot submenu on changes
)

# ---------------------------------------------------------------------------
# 1. Locale, time, and identity
# ---------------------------------------------------------------------------

# set_locales — uncomment the wanted locales in /etc/locale.gen and generate them.
# sed rather than a rewrite, because /etc/locale.gen ships from the `glibc`
# package and is 500 lines of commented candidates.
set_locales() {
  local loc escaped
  for loc in "${LOCALES[@]}"; do
    escaped=${loc//./\\.}                 # escape the dot so it is a literal dot
    if grep -qE "^${escaped}[[:space:]]+UTF-8" /etc/locale.gen; then
      skip "locale already enabled: $loc"
    else
      sed -i -E "s|^#[[:space:]]*(${escaped})[[:space:]]+UTF-8|\1 UTF-8|" /etc/locale.gen
      log "enabled locale: $loc"
    fi
  done
  locale-gen
}

# set_locale_conf — the global locale. LANGUAGE is deliberately NOT set: gettext
# falls through the LANGUAGE list when a catalog is missing, and there is no
# en_US catalog, so setting it would switch the UI to French.
set_locale_conf() {
  write_file /etc/locale.conf 0644 root:root <<EOF
LANG=$LANG_VALUE
EOF
}

# set_timezone — symlink the zoneinfo and write the clock back to the RTC.
# A symlink rather than `timedatectl set-timezone`, because there is no running
# systemd inside the chroot.
set_timezone() {
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  log "timezone: $TIMEZONE"
  hwclock --systohc || warn "hwclock --systohc failed; run it after first boot"
}

# set_console — the TTY keymap. fr-pc is the PC-style French AZERTY layout, which
# is what you asked for on the console; Hyprland uses xkb's `fr` instead.
set_console() {
  write_file /etc/vconsole.conf 0644 root:root <"$REPO/system/vconsole.conf"
}

# set_identity — hostname and hosts. The 127.0.1.1 line is what lets sudo and
# some daemons resolve the machine's own name without a DNS round trip.
set_identity() {
  write_file /etc/hostname 0644 root:root <<EOF
$HOST_NAME
EOF
  write_file /etc/hosts 0644 root:root <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST_NAME.localdomain $HOST_NAME
EOF
}

# ---------------------------------------------------------------------------
# 2. User
# ---------------------------------------------------------------------------

# create_user — create medo with the groups that actually exist, set its password
# interactively, and make ~/Bin. On a re-run the password prompt is skipped.
create_user() {
  # Build the group list by intersecting the candidates with /etc/group.
  local -a groups=()
  local g
  for g in "${GROUP_CANDIDATES[@]}"; do
    getent group "$g" >/dev/null 2>&1 && groups+=("$g")
  done

  if id "$USER_NAME" >/dev/null 2>&1; then
    # Existence is not enough: useradd without a password leaves the hash as `!`,
    # which is locked. If a previous run was interrupted between useradd and
    # passwd, a naive `skip` here would leave the account permanently
    # unloggable — with no root password either, recovery would need a live USB.
    # `passwd -S` reports L (locked) or NP (no password) for exactly this case.
    if passwd -S "$USER_NAME" 2>/dev/null | awk '{exit !($2 == "L" || $2 == "NP")}'; then
      warn "$USER_NAME exists but has no usable password — setting it now"
      passwd "$USER_NAME"
    else
      skip "user exists: $USER_NAME"
    fi
  else
    useradd -m -s /bin/bash "$USER_NAME"
    log "created user: $USER_NAME"
    printf '\n  Set the password for %s:\n' "$USER_NAME"
    passwd "$USER_NAME"
  fi

  # usermod -aG is additive and idempotent, so supplementary groups converge on
  # every run even if a package was installed later.
  for g in "${groups[@]}"; do
    usermod -aG "$g" "$USER_NAME"
  done
  log "groups for $USER_NAME: ${groups[*]}"

  # ~/Bin is where you drop your own executables; ~/.local/bin holds ours.
  install -d -o "$USER_NAME" -g "$USER_NAME" -m 0755 "$USER_HOME/Bin"
  log "ready: $USER_HOME/Bin"
}

# set_sudoers — wheel gets NOPASSWD, which is how you use sudo on this machine.
# 0440 is what sudo requires; a group-writable sudoers file is ignored.
set_sudoers() {
  write_file /etc/sudoers.d/10-wheel 0440 root:root <"$REPO/system/sudoers.d/10-wheel"
}

# ---------------------------------------------------------------------------
# 3. System files
# ---------------------------------------------------------------------------

# install_system_files — table-driven copy of system/ into /etc. Each entry is
# "source-relative-path:destination:mode". write_file is content-aware, so a
# re-run only reports "unchanged".
install_system_files() {
  local -a files=(
    "default-grub:/etc/default/grub:0644"
    "mkinitcpio.conf.d/10-system.conf:/etc/mkinitcpio.conf.d/10-system.conf:0644"
    "mkinitcpio.conf.d/20-nvidia.conf:/etc/mkinitcpio.conf.d/20-nvidia.conf:0644"
    "modprobe.d/nvidia.conf:/etc/modprobe.d/nvidia.conf:0644"
    "zram-generator.conf:/etc/systemd/zram-generator.conf:0644"
    "sddm.conf.d/10-theme.conf:/etc/sddm.conf.d/10-theme.conf:0644"
  )
  local entry src dest mode
  for entry in "${files[@]}"; do
    IFS=: read -r src dest mode <<<"$entry"
    write_file "$dest" "$mode" root:root <"$REPO/system/$src"
  done
}

# set_pacman_options — amend /etc/pacman.conf in place. Appending duplicate keys
# is not safe, so this uncomments the existing line when there is one.
set_pacman_option() {
  local key=$1 value=${2:-} file=/etc/pacman.conf line=$1
  [[ -n $value ]] && line="$key = $value"

  if grep -qE "^${key}([[:space:]]|=|$)" "$file"; then
    skip "pacman option already set: $key"
  elif grep -qE "^#[[:space:]]*${key}" "$file"; then
    sed -i -E "s|^#[[:space:]]*${key}.*|${line}|" "$file"
    log "pacman option enabled: $line"
  else
    printf '%s\n' "$line" >>"$file"
    log "pacman option added: $line"
  fi
}

# set_pacman_options — the four quality-of-life switches.
set_pacman_options() {
  backup_once /etc/pacman.conf
  set_pacman_option Color                       # coloured output
  set_pacman_option ILoveCandy                  # pacman progress bar as a snake
  set_pacman_option VerbosePkgLists             # show version changes per package
  set_pacman_option ParallelDownloads 8         # eight concurrent downloads
}

# set_keyring_pam — append pam_gnome_keyring to SDDM's PAM stack, so the login
# password also unlocks the keyring. Appended rather than replaced because
# /etc/pam.d/sddm is owned by the sddm package.
set_keyring_pam() {
  backup_once /etc/pam.d/sddm
  local line
  while IFS= read -r line; do
    [[ -z $line || $line == \#* ]] && continue
    append_once "$line" /etc/pam.d/sddm
  done <"$REPO/system/pam.d/sddm.keyring.snippet"
}

# ---------------------------------------------------------------------------
# 4. Initramfs
# ---------------------------------------------------------------------------

# build_initramfs — regenerate every kernel image. The drop-ins written above add
# btrfs and the NVIDIA modules for early KMS. This must run after nvidia-open is
# installed (it is, from pacstrap) or the MODULES entries would fail to resolve.
build_initramfs() {
  mkinitcpio -P
}

# ---------------------------------------------------------------------------
# 5. Bootloader
# ---------------------------------------------------------------------------

# install_grub — install GRUB to the ESP, then generate the config. The assert
# afterwards is the important part: grub-btrfs builds its own rootflags from
# /etc/fstab and appends subvol= for each snapshot. A rootflags in the kernel
# cmdline as well would produce two rootflags= parameters on snapshot entries.
install_grub() {
  [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode; this config assumes UEFI + GPT"

  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  log "GRUB installed to the ESP"

  # Assert on the ASSIGNMENT, not on the file's contents. /etc/default/grub's own
  # explanatory comments contain the word rootflags, so `grep 'rootflags' <file>`
  # matches the documentation and would abort the install on every run.
  #
  # Checking the generated grub.cfg instead would be wrong in the other
  # direction: grub-btrfs's snapshot entries legitimately contain rootflags=
  # (that is how they boot), so the only invariant worth asserting is that no
  # GRUB_CMDLINE_LINUX* variable passes it to the normal kernel.
  if grep -qE '^[[:space:]]*GRUB_CMDLINE_LINUX(_DEFAULT)?=.*rootflags' /etc/default/grub; then
    die "/etc/default/grub sets rootflags in GRUB_CMDLINE_LINUX* — remove it; it collides with grub-btrfs's per-snapshot rootflags"
  fi

  grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
  log "generated /boot/grub/grub.cfg (no kernel rootflags)"
}

# ---------------------------------------------------------------------------
# 6. Snapshots
# ---------------------------------------------------------------------------

# set_snapper_option <key> <value> — set one key in snapper's generated config.
# `snapper create-config` writes a file with dozens of keys; patching the ones we
# care about preserves snapper's own structure and defaults, which is safer than
# replacing the file with a partial one that might omit something snapper needs.
set_snapper_option() {
  local key=$1 value=$2 file=/etc/snapper/configs/root
  if grep -qE "^${key}=" "$file"; then
    sed -i -E "s|^${key}=.*|${key}=\"${value}\"|" "$file"
  else
    printf '%s="%s"\n' "$key" "$value" >>"$file"
  fi
  log "snapper: $key=\"$value\""
}

# configure_snapper — create the snapper config for / and tune it.
#
# Ordering note: this runs before the dotfiles and services steps, so the first
# snapshot is small. create-config also creates /.snapshots as its own subvolume
# inside @, which is why nothing pre-creates that directory: if /.snapshots
# already existed, create-config would refuse to run.
configure_snapper() {
  if [[ -f /etc/snapper/configs/root ]]; then
    skip "snapper config already exists for /"
  else
    snapper -c root create-config /
    log "created snapper config for / (and the /.snapshots subvolume)"
  fi

  # Automatic timeline snapshots, driven by snapper-timeline.timer.
  set_snapper_option TIMELINE_CREATE yes
  set_snapper_option TIMELINE_LIMIT_HOURLY 10
  set_snapper_option TIMELINE_LIMIT_DAILY 7
  set_snapper_option TIMELINE_LIMIT_WEEKLY 4
  set_snapper_option TIMELINE_LIMIT_MONTHLY 2
  set_snapper_option TIMELINE_LIMIT_YEARLY 0
  set_snapper_option TIMELINE_CLEANUP yes

  # Cap the total number of snapshots, so snap-pac's pre/post pairs around every
  # pacman transaction cannot grow without bound.
  set_snapper_option NUMBER_CLEANUP yes
  set_snapper_option NUMBER_LIMIT 20
  set_snapper_option NUMBER_LIMIT_IMPORTANT 10

  # Remove the empty pre/post snapshot directories that failed transactions leave.
  set_snapper_option EMPTY_PRE_POST_CLEANUP yes
  set_snapper_option EMPTY_PRE_POST_MIN_AGE 1800

  # Let medo list and compare snapshots without root.
  set_snapper_option ALLOW_USERS "$USER_NAME"

  # Compare in the background, so taking a snapshot never blocks a pacman run.
  set_snapper_option BACKGROUND_COMPARISON yes
}

# ---------------------------------------------------------------------------
# 7. Services
# ---------------------------------------------------------------------------

# enable_all_services — enable, never start. There is no PID 1 in a chroot.
enable_all_services() {
  enable_service "${SERVICES[@]}"
}

# configure_firewall — apply the policy and turn the firewall on.
#
# `systemctl enable ufw` only re-applies whatever policy is already on disk; it
# does not start filtering. Without these three commands a fresh install has a
# firewall package, an enabled unit and no rules — which is worse than nothing,
# because it looks configured. --force skips the interactive "this may disrupt
# SSH" prompt. All three are safe to re-run.
#
# Note for later: Docker writes its own iptables rules and bypasses ufw, so a
# container published with -p is reachable from the LAN regardless of this
# policy. That is a known and accepted limitation of this setup.
configure_firewall() {
  ufw default deny incoming  >/dev/null
  ufw default allow outgoing >/dev/null
  ufw --force enable         >/dev/null
  log "ufw: default deny incoming, default allow outgoing, enabled"
}

# ---------------------------------------------------------------------------
# 8. Dotfiles
# ---------------------------------------------------------------------------

# install_dotfiles — place every config, script and launcher entry, then hand the
# whole home directory to medo. Ownership matters: a root-owned ~/.config breaks
# Hyprland, Waybar and every GTK app.
install_dotfiles() {
  copy_tree "$REPO/configs" "$USER_HOME/.config"

  # home/ holds files that live directly in ~. gitconfig.tpl is excluded because
  # it is a template, not a config, and is rendered below.
  local f
  for f in bashrc bash_profile nanorc XCompose; do
    install -D -m 0644 "$REPO/home/$f" "$USER_HOME/$f"
  done
  log "installed shell and compose files"

  # The scripts, then their launcher entries.
  copy_tree "$REPO/bin" "$USER_HOME/.local/bin"
  install -d -m 0755 "$USER_HOME/.local/share/applications"
  copy_tree "$REPO/applications" "$USER_HOME/.local/share/applications"

  # Static data the scripts read: currently just the emoji list. Installed under
  # ~/.local/share/arch-configs so the list can be edited without touching the
  # script that reads it.
  install -d -m 0755 "$USER_HOME/.local/share/arch-configs"
  copy_tree "$REPO/data" "$USER_HOME/.local/share/arch-configs/data"

  # Wallpapers, and the cheatsheet the SUPER+K binding opens.
  install -d -m 0755 "$USER_HOME/Pictures/wallpapers"
  copy_tree "$REPO/wallpapers" "$USER_HOME/Pictures/wallpapers"
  install -D -m 0644 "$REPO/keybindings.md" "$USER_HOME/.config/hypr/keybindings.md"

  # Render ~/.gitconfig from the template.
  sed -e "s|@GIT_NAME@|$GIT_NAME|" -e "s|@GIT_EMAIL@|$GIT_EMAIL|" \
    "$REPO/home/gitconfig.tpl" >"$USER_HOME/.gitconfig"
  chmod 0644 "$USER_HOME/.gitconfig"
  log "rendered: $USER_HOME/.gitconfig"

  # Executables must be executable; everything else stays 0644. find -exec rather
  # than a glob, so an empty directory cannot turn into a literal-path error.
  find "$USER_HOME/.local/bin" -type f -exec chmod 0755 {} +
  find "$USER_HOME/.local/share/applications" -type f -name '*.desktop' -exec chmod 0644 {} +

  # Session PATH. The bindings and Waybar call these scripts by bare name, and
  # Hyprland's `exec` and Waybar's `exec` are not interactive bash — so
  # ~/.bashrc never runs for them and its PATH edit does not apply. This file is
  # read by Hyprland itself: envs.lua loads every file in environment.d (see the
  # loader there), so the scripts resolve whether or not the session is
  # uwsm-managed. $HOME and $PATH are expanded by that loader.
  write_file "$USER_HOME/.config/environment.d/10-path.conf" 0644 "$USER_NAME:$USER_NAME" <<'EOF'
# Session PATH. Loaded by ~/.config/hypr/envs.lua, which reads every .conf here
# and exports each KEY=VALUE into the Hyprland session environment.
#
# ~/Bin       your own executables
# ~/.local/bin the scripts installed from the arch-configs repo
PATH=$HOME/.local/bin:$HOME/Bin:$PATH
EOF

  # One recursive chown at the end covers every file copied above.
  chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"
  log "ownership: $USER_HOME -> $USER_NAME"

  # These three must run AS THE USER, not as root: fc-cache would build
  # /root/.cache/fontconfig (leaving the Arabic stack uncached for medo) and
  # update-desktop-database would leave a root-owned mimeinfo.cache inside the
  # user's home. runuser is used rather than `su -` so no login shell is started.
  runuser -u "$USER_NAME" -- fc-cache -f >/dev/null
  log "font cache rebuilt (as $USER_NAME)"

  runuser -u "$USER_NAME" -- update-desktop-database "$USER_HOME/.local/share/applications"
  log "launcher database updated"

  # Create ~/Documents, ~/Pictures and friends from the xdg-user-dirs defaults.
  # ~/Pictures/wallpapers was created above, so the wallpapers survive.
  runuser -u "$USER_NAME" -- xdg-user-dirs-update
  log "user directories created"
}

# ---------------------------------------------------------------------------
# 9. First rollback point
# ---------------------------------------------------------------------------

# take_first_snapshot — a labelled snapshot of the pristine system. This is what
# appears under "Arch Linux snapshots" in the GRUB menu.
take_first_snapshot() {
  # Substring match, not an exact-line match: snapper pads its columns with
  # spaces, so -x would never match.
  if snapper -c root list --columns description 2>/dev/null | grep -q 'post-install'; then
    skip "post-install snapshot already exists"
    return 0
  fi
  snapper -c root create -d 'post-install' >/dev/null
  log "created snapshot: post-install"

  # Regenerate the boot menu now that a snapshot exists, so the
  # "Arch Linux snapshots" submenu is populated on the very first boot. Without
  # this, grub-mkconfig ran against an empty /.snapshots and produced no entry;
  # grub-btrfsd only reacts to a *change*, so the first entry would not appear
  # until the first pacman transaction — precisely when a rollback is most
  # likely to be wanted.
  grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
  log "regenerated /boot/grub/grub.cfg with the snapshot submenu"
}

# ---------------------------------------------------------------------------
# 10. AUR
# ---------------------------------------------------------------------------

# install_aur — build paru, then everything in packages/aur.txt.
#
# This is the one step that must not run as root: makepkg refuses. medo is in
# wheel with NOPASSWD, so `su - medo -c` can sudo freely without a prompt.
# --skipreview is passed because there is no interactive editor in this context.
install_aur() {
  local -a pkgs
  mapfile -t pkgs < <(grep -v '^[[:space:]]*$' "$REPO/packages/aur.txt")
  (( ${#pkgs[@]} )) || { skip "no AUR packages listed"; return 0; }

  # paru bootstraps itself: clone the AUR repo, build, install. It is listed in
  # aur.txt for documentation, but installing it with itself would be circular.
  if command -v paru >/dev/null 2>&1; then
    skip "paru already installed"
  else
    log "building paru as $USER_NAME (needs rust + base-devel, both installed)"
    su - "$USER_NAME" -c \
      'rm -rf /tmp/paru-build && git clone -q https://aur.archlinux.org/paru.git /tmp/paru-build && cd /tmp/paru-build && makepkg -si --noconfirm'
  fi

  # Build the remaining AUR packages, minus paru itself.
  local -a rest=() p
  for p in "${pkgs[@]}"; do
    [[ $p == paru ]] && continue
    rest+=("$p")
  done
  (( ${#rest[@]} )) || return 0

  log "installing AUR packages: ${rest[*]}"
  # printf %q quotes each name so the su -c command survives the shell hop.
  su - "$USER_NAME" -c "paru -S --needed --noconfirm --skipreview $(printf '%q ' "${rest[@]}")"
}

# ---------------------------------------------------------------------------

main() {
  section "Locale, time and identity"
  set_locales
  set_locale_conf
  set_timezone
  set_console
  set_identity

  section "User and sudo"
  create_user
  set_sudoers

  section "System files"
  install_system_files
  set_pacman_options
  set_keyring_pam

  section "Initramfs"
  build_initramfs

  section "Bootloader"
  install_grub

  section "Snapshots"
  configure_snapper

  section "Services"
  enable_all_services

  section "Firewall"
  configure_firewall

  section "Dotfiles"
  install_dotfiles

  section "First snapshot"
  take_first_snapshot

  section "AUR packages"
  install_aur

  section "Done"
  log "system configured; returning to install.sh"
}

main "$@"
