# Building the arch-configs Custom ISO

This directory contains the archiso profile and build scripts to create a bootable Arch Linux ISO with all your packages pre-installed.

## Quick Start

```bash
# 1. Build AUR packages into a local repository (requires internet)
./build-aur-repo.sh

# 2. Build the ISO (can be done offline if AUR repo exists)
./build-iso.sh

# 3. Write to USB
sudo dd if=out/arch-configs-*.iso of=/dev/sdX bs=4M status=progress && sync
```

## What's Included

The ISO contains:

### Official Packages (176 packages from `packages/official.txt`)
- Base system: `base`, `linux`, `linux-firmware`, `base-devel`, `intel-ucode`
- Boot: `grub`, `grub-btrfs`, `efibootmgr`, `snapper`, `snap-pac`
- GPU: `nvidia-open`, `nvidia-utils`, `mesa`, `vulkan-intel`, `intel-media-driver`, `libva-nvidia-driver`, `egl-wayland`
- Hyprland ecosystem: `hyprland`, `hyprland-guiutils`, `hyprlock`, `hypridle`, `hyprpaper`, `hyprsunset`, `hyprpicker`, `hyprpolkitagent`, `uwsm`
- Wayland desktop: `waybar`, `mako`, `fuzzel`, `foot`, `sddm`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`
- Audio: `pipewire`, `pipewire-pulse`, `wireplumber`, `pamixer`, `pavucontrol`
- Fonts: `noto-fonts`, `noto-fonts-emoji`, `ttf-jetbrains-mono-nerd`, `inter-font`, `adwaita-fonts`
- Apps: `ghostty`, `nautilus`, `code`, `chromium`, `mpv`, `imv`, `qbittorrent`, `obsidian`, `kdenlive`, `libreoffice-fresh`
- Utils: `btop`, `lazygit`, `lazydocker`, `fastfetch`, `starship`, `zoxide`, `eza`, `bat`, `fd`, `ripgrep`, `fzf`, `tmux`
- Fonts & I18n: `fcitx5`, `fcitx5-*`, `hunspell-*`, `hyphen-*`, `mythes-en`

### AUR Packages (7 packages from `packages/aur.txt`)
- `paru` - AUR helper
- `pantum-universal-driver` - Printer driver
- `vazirmatn-fonts` - Arabic UI font
- `ttf-amiri` - Arabic reading font
- `ttf-arabeyes-fonts` - Additional Arabic fonts
- `herdr-bin` - Terminal dashboard
- `hunspell-ar` - Arabic spell checking
- `localsend` - File sharing

### Pre-configured System
- All system configs in `/etc` (mkinitcpio, GRUB, SDDM, ufw, zram, etc.)
- Complete `arch-configs` repo at `/root/arch-configs` with `install.sh` ready to run
- Services pre-enabled (NetworkManager, sddm, bluetooth, docker, snapper, etc.)
- Root autologin on tty1 for immediate access
- Ranked mirrorlist for fast downloads
- 4G CoW filesystem for package installs in live session

## Build Process Details

### `build-aur-repo.sh`
1. Clones each AUR package from `packages/aur.txt`
2. Builds with `makepkg -s` (installs build dependencies automatically)
3. Creates a local pacman repository with `repo-add`
4. Output: `/tmp/arch-configs-aur-repo/arch-configs-aur.db.tar.gz` + packages

### `build-iso.sh`
1. Copies AUR repo into `airootfs/run/archiso/bootmnt/arch-configs-aur/`
2. Stages the entire `arch-configs` repo into `airootfs/root/arch-configs/`
3. Generates a ranked mirrorlist using `reflector`
4. Runs `mkarchiso` with the custom profile
5. Output: `out/arch-configs-YYYY.MM.DD-x86_64.iso`

## Profile Structure

```
iso-profile/
├── profiledef.sh          # ISO metadata, build modes, kernel params
├── pacman.conf            # Repositories (official + local AUR repo)
├── packages.x86_64        # Official package list (sorted, deduped)
├── airootfs/              # Overlay for live system root
│   ├── etc/
│   │   ├── pacman.conf    # Live environment pacman.conf with AUR repo
│   │   ├── locale.gen/.conf, vconsole.conf, hostname, hosts
│   │   ├── mkinitcpio.conf.d/, modprobe.d/, sudoers.d/
│   │   ├── systemd/system/  (enabled services)
│   │   ├── default/grub, sddm.conf.d/
│   │   └── pacman.d/mirrorlist  (ranked mirrors)
│   ├── run/archiso/bootmnt/arch-configs-aur/  # AUR repo (copied at build)
│   └── root/arch-configs/  # Complete repo for install.sh
├── efiboot/               # systemd-boot config (from releng profile)
├── grub/                  # GRUB config (from releng profile)
└── syslinux/              # Syslinux config (from releng profile)
```

## Offline Installation

The ISO is designed for **fully offline installation**:

1. All official packages are in the squashfs (no download needed)
2. AUR packages are in the local repo on the ISO
3. `install.sh` uses the local repo for `pacstrap` and AUR installs
4. Mirror ranking runs but gracefully falls back if no network

## Requirements to Build

- Arch Linux host (or Arch-based with `archiso` package)
- `archiso` package: `sudo pacman -S archiso`
- `reflector` for mirror ranking (optional but recommended)
- ~8GB free disk space for build
- Internet for `build-aur-repo.sh` (first run only)

## Testing

```bash
# Install QEMU
sudo pacman -S qemu-desktop edk2-ovmf

# Test the ISO
qemu-system-x86_64 -enable-kvm -m 4G -cdrom out/arch-configs-*.iso \
  -bios /usr/share/edk2-ovmf/x64/OVMF.fd
```

## Customization

To modify the ISO:
- Edit `packages.x86_64` to add/remove official packages
- Edit `packages/aur.txt` and re-run `build-aur-repo.sh` for AUR packages
- Add files to `airootfs/` for live system customizations
- Modify `profiledef.sh` for ISO metadata, kernel params, etc.
- The releng bootloader configs in `efiboot/`, `grub/`, `syslinux/` are copied from archiso's releng profile