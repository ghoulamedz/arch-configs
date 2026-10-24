#!/usr/bin/env bash
#
# build-aur-repo.sh - Build AUR packages into a local pacman repository
# Run this first, then build-iso.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[BUILD-AUR]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Check dependencies
for cmd in git makepkg repo-add; do
  command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done

# Read AUR packages from packages/aur.txt
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUR_LIST="$REPO_ROOT/packages/aur.txt"
[[ -f "$AUR_LIST" ]] || die "Missing $AUR_LIST"

mapfile -t AUR_PKGS < <(grep -v '^[[:space:]]*#' "$AUR_LIST" | grep -v '^[[:space:]]*$')
(( ${#AUR_PKGS[@]} )) || die "No AUR packages listed in $AUR_LIST"

log "AUR packages to build: ${AUR_PKGS[*]}"

# Build directory
BUILD_DIR="/tmp/arch-configs-aur-build-$$"
REPO_DIR="/tmp/arch-configs-aur-repo"
mkdir -p "$BUILD_DIR" "$REPO_DIR"

# Cleanup on exit
trap 'rm -rf "$BUILD_DIR"' EXIT

# Build each package
for pkg in "${AUR_PKGS[@]}"; do
  log "Building $pkg..."
  cd "$BUILD_DIR"
  rm -rf "$pkg"
  
  if git clone "https://aur.archlinux.org/$pkg.git" "$pkg"; then
    cd "$pkg"
    if makepkg -s --noconfirm --skippgpcheck; then
      log "Built $pkg successfully"
      # Copy built packages to repo dir
      cp *.pkg.tar.zst "$REPO_DIR/" 2>/dev/null || true
    else
      warn "Failed to build $pkg (continuing...)"
    fi
  else
    warn "Failed to clone $pkg (continuing...)"
  fi
done

# Create repository database
log "Creating repository database..."
cd "$REPO_DIR"
repo-add arch-configs-aur.db.tar.gz *.pkg.tar.zst 2>/dev/null || warn "No packages to add to repo"

log "AUR repository ready at: $REPO_DIR"
ls -la "$REPO_DIR"
echo
log "Next step: run ./build-iso.sh"