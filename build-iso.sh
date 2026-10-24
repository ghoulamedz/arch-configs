#!/usr/bin/env bash
#
# build-iso.sh - Build the arch-configs custom ISO
# Run from the arch-configs repo root

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ISO_PROFILE_DIR="$REPO_ROOT/iso-profile"
AUR_REPO_DIR="/tmp/arch-configs-aur-repo"
WORK_DIR="/tmp/archiso-tmp"
OUT_DIR="$REPO_ROOT/out"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[BUILD-ISO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Check requirements
[[ -f /etc/arch-release ]] || die "Must run on Arch Linux"
command -v mkarchiso >/dev/null || die "archiso package not installed (pacman -S archiso)"

# Check if AUR repo exists
if [[ ! -d "$AUR_REPO_DIR" ]]; then
  warn "AUR repo not found at $AUR_REPO_DIR"
  warn "Run ./build-aur-repo.sh first to build AUR packages"
  read -rp "Continue without AUR packages? [y/N] " -n 1
  echo
  [[ ${REPLY,,} == y ]] || die "Aborted"
  HAS_AUR_REPO=0
else
  HAS_AUR_REPO=1
  log "Using AUR repo at $AUR_REPO_DIR"
fi

# Prepare ISO profile with AUR repo if available
if (( HAS_AUR_REPO )); then
  log "Copying AUR repo to ISO profile airootfs..."
  mkdir -p "$ISO_PROFILE_DIR/airootfs/run/archiso/bootmnt"
  cp -r "$AUR_REPO_DIR" "$ISO_PROFILE_DIR/airootfs/run/archiso/bootmnt/arch-configs-aur"
fi

# Copy the arch-configs repo into the ISO so it's available for install.sh
log "Staging arch-configs repo into ISO profile..."
mkdir -p "$ISO_PROFILE_DIR/airootfs/root/arch-configs"
rsync -a --delete --exclude '.git/objects/pack/tmp*' \
  "$REPO_ROOT/" "$ISO_PROFILE_DIR/airootfs/root/arch-configs/"

# Create the mirrorlist for the live environment
log "Generating ranked mirrorlist for live ISO..."
if command -v reflector >/dev/null; then
  reflector --latest 20 --protocol https --sort rate --save "$ISO_PROFILE_DIR/airootfs/etc/pacman.d/mirrorlist" || warn "reflector failed, using default mirrorlist"
else
  warn "reflector not available, mirrorlist will be generated at runtime"
fi

# Build the ISO
log "Building ISO with mkarchiso..."
mkdir -p "$OUT_DIR"

mkarchiso -v -r -w "$WORK_DIR" -o "$OUT_DIR" "$ISO_PROFILE_DIR" || die "mkarchiso failed"

# Find the generated ISO
ISO_FILE=$(find "$OUT_DIR" -name '*.iso' -type f | head -1)
if [[ -n $ISO_FILE ]]; then
  log "ISO built successfully: $ISO_FILE"
  ls -lh "$ISO_FILE"
  
  # Generate checksums
  log "Generating checksums..."
  sha256sum "$ISO_FILE" > "$ISO_FILE.sha256"
  cat "$ISO_FILE.sha256"
else
  die "ISO file not found in $OUT_DIR"
fi

log "Done! You can now write the ISO to USB with:"
echo "  sudo dd if=$ISO_FILE of=/dev/sdX bs=4M status=progress && sync"
echo "Or test with QEMU:"
echo "  qemu-system-x86_64 -enable-kvm -m 4G -cdrom $ISO_FILE -bios /usr/share/edk2-ovmf/x64/OVMF.fd"