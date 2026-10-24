#!/usr/bin/env bash
# shellcheck disable=SC2034

# arch-configs custom ISO profile
# Based on releng profile from archiso

iso_name="arch-configs"
iso_label="ARCH-CONFIGS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="medo <mluke4120@gmail.com>"
iso_application="Arch Linux with Hyprland (arch-configs)"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')

# Increase CoW filesystem size for package installs during live session
kernel_params_x86_64="cow_spacesize=4G"

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  # arch-configs specific
  ["/root/arch-configs/install.sh"]="0:0:755"
  ["/root/arch-configs/install-chroot.sh"]="0:0:755"
  ["/root/arch-configs/lib/common.sh"]="0:0:644"
  ["/etc/pacman.d/arch-configs-mirrorlist"]="0:0:644"
)