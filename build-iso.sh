#!/usr/bin/env bash
#
# build-iso.sh - Build the arch-configs custom ISO
# Run build-aur-repo.sh first to create the local AUR repository

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[BUILD-ISO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_PROFILE="$REPO_ROOT/iso-profile"
AUR_REPO_DIR="/tmp/arch-configs-aur-repo"
OUT_DIR="$REPO_ROOT/out"

# Check dependencies
for cmd in mkarchiso reflector; do
  command -v "$cmd" >/dev/null || die "Missing required command: $cmd (install archiso and reflector)"
done

# Check AUR repo exists
[[ -d "$AUR_REPO_DIR" ]] || die "AUR repo not found at $AUR_REPO_DIR. Run ./build-aur-repo.sh first"
[[ -f "$AUR_REPO_DIR/arch-configs-aur.db.tar.gz" ]] || die "AUR repo database not found. Run ./build-aur-repo.sh first"

log "Using AUR repo: $AUR_REPO_DIR"

# Copy AUR repo into airootfs for build-time access
AUR_TARGET="$ISO_PROFILE/airootfs/run/archiso/bootmnt/arch-configs-aur"
log "Copying AUR repo to $AUR_TARGET..."
rm -rf "$AUR_TARGET"
mkdir -p "$AUR_TARGET"
cp -r "$AUR_REPO_DIR"/* "$AUR_TARGET/"

# Stage the arch-configs repo into airootfs for install.sh
ARCH_CONFIGS_TARGET="$ISO_PROFILE/airootfs/root/arch-configs"
log "Staging arch-configs repo to $ARCH_CONFIGS_TARGET..."
rm -rf "$ARCH_CONFIGS_TARGET"
mkdir -p "$ARCH_CONFIGS_TARGET"
rsync -a --delete \
  --exclude='.git' \
  --exclude='out' \
  --exclude='iso-profile' \
  --exclude='*.iso' \
  "$REPO_ROOT/" "$ARCH_CONFIGS_TARGET/"

# Generate ranked mirrorlist for the live environment
log "Generating ranked mirrorlist..."
MIRRORLIST="$ISO_PROFILE/airootfs/etc/pacman.d/mirrorlist"
mkdir -p "$(dirname "$MIRRORLIST")"

if command -v reflector >/dev/null 2>&1; then
  reflector --protocol https --latest 20 --sort rate --save "$MIRRORLIST" || warn "reflector failed, using fallback"
else
  warn "reflector not available, creating minimal mirrorlist"
  cat > "$MIRRORLIST" <<'EOF'
# Fallback mirrorlist - rank with reflector after boot
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.mit.edu/archlinux/$repo/os/$arch
Server = https://mirrors.ocf.berkeley.edu/archlinux/$repo/os/$arch
EOF
fi

# Prepare output directory
mkdir -p "$OUT_DIR"

# Build the ISO
log "Building ISO with mkarchiso..."
cd "$ISO_PROFILE"
sudo mkarchiso -v -w /tmp/arch-configs-iso-build -o "$OUT_DIR" .

# Find the built ISO
ISO_FILE=$(find "$OUT_DIR" -name 'arch-configs-*.iso' -type f | head -1)
if [[ -n "$ISO_FILE" ]]; then
  log "ISO built successfully: $ISO_FILE"
  ls -lh "$ISO_FILE"
  echo
  log "To write to USB:"
  echo "  sudo dd if=$ISO_FILE of=/dev/sdX bs=4M status=progress && sync"
  echo
  log "To test in QEMU:"
  echo "  qemu-system-x86_64 -enable-kvm -m 4G -cdrom $ISO_FILE -bios /usr/share/edk2-ovmf/x64/OVMF.fd"
else
  die "ISO not found in $OUT_DIR"
fi