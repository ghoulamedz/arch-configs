#!/usr/bin/env bash
#
# build-aur-repo.sh - Build AUR packages and create a local repository
# Run this from the arch-configs repo root before building the ISO

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
AUR_PKGS_FILE="$REPO_ROOT/packages/aur.txt"
BUILD_DIR="/tmp/arch-configs-aur-build"
REPO_DIR="/tmp/arch-configs-aur-repo"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Check if running on Arch (required for makepkg)
[[ -f /etc/arch-release ]] || die "This script must run on Arch Linux"

# Read AUR packages
mapfile -t AUR_PKGS < <(grep -v '^[[:space:]]*$' "$AUR_PKGS_FILE" | grep -v '^[[:space:]]*#')
(( ${#AUR_PKGS[@]} )) || die "No AUR packages found in $AUR_PKGS_FILE"

log "Building ${#AUR_PKGS[@]} AUR packages: ${AUR_PKGS[*]}"

# Clean and create directories
rm -rf "$BUILD_DIR" "$REPO_DIR"
mkdir -p "$BUILD_DIR" "$REPO_DIR"

# Install build dependencies
log "Installing build dependencies (base-devel, git, pacman-contrib)..."
sudo pacman -S --needed --noconfirm base-devel git pacman-contrib || die "Failed to install build dependencies"

# Build each AUR package
for pkg in "${AUR_PKGS[@]}"; do
  log "Building $pkg..."
  cd "$BUILD_DIR"
  
  # Clone the AUR package
  git clone "https://aur.archlinux.org/$pkg.git" || die "Failed to clone $pkg"
  cd "$pkg"
  
  # Build the package
  makepkg -s --noconfirm --skippgpcheck || die "Failed to build $pkg"
  
  # Move built packages to repo directory
  for built_pkg in *.pkg.tar.zst; do
    [[ -f $built_pkg ]] && mv "$built_pkg" "$REPO_DIR/"
  done
  
  log "Built $pkg successfully"
done

# Create the repository database
log "Creating repository database..."
cd "$REPO_DIR"
repo-add arch-configs-aur.db.tar.gz *.pkg.tar.zst || die "Failed to create repository database"

log "Repository created at: $REPO_DIR"
log "Packages in repo:"
ls -la "$REPO_DIR"/*.pkg.tar.zst

echo
echo "To use this repo in your ISO build:"
echo "  1. Copy $REPO_DIR to your ISO profile directory"
echo "  2. Update pacman.conf to include [arch-configs-aur] with Server = file:///path/to/repo"
echo "  3. The repo will be accessible during ISO build and in the live environment"