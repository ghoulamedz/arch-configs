#!/usr/bin/env bash
#
# setup-local-aur-repo.sh - Set up the local AUR repository on the installed system
# Run this after installation to enable offline AUR package updates

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[SETUP-AUR]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

AUR_REPO_SOURCE="/run/archiso/bootmnt/arch-configs-aur"
AUR_REPO_TARGET="/var/cache/arch-configs-aur"
PACMAN_CONF="/etc/pacman.conf"

# Check if running as root
[[ $EUID -eq 0 ]] || die "Must run as root"

# Check if source repo exists (on live ISO)
if [[ ! -d "$AUR_REPO_SOURCE" ]]; then
  warn "AUR repo not found at $AUR_REPO_SOURCE"
  warn "This script should be run from the live ISO after installation,"
  warn "or you need to mount the ISO and point to the repo location."
  read -rp "Enter path to arch-configs-aur repo (or 'skip' to exit): " USER_PATH
  if [[ $USER_PATH == "skip" ]]; then
    exit 0
  fi
  AUR_REPO_SOURCE="$USER_PATH"
  [[ -d "$AUR_REPO_SOURCE" ]] || die "Path not found: $AUR_REPO_SOURCE"
fi

log "Copying AUR repo from $AUR_REPO_SOURCE to $AUR_REPO_TARGET..."
mkdir -p "$AUR_REPO_TARGET"
cp -r "$AUR_REPO_SOURCE"/* "$AUR_REPO_TARGET/"

log "Adding [arch-configs-aur] repository to $PACMAN_CONF..."
# Backup original
cp "$PACMAN_CONF" "$PACMAN_CONF.pre-arch-configs-aur"

# Check if repo already configured
if grep -q '^\[arch-configs-aur\]' "$PACMAN_CONF"; then
  log "Repository already configured in $PACMAN_CONF"
else
  # Insert before the first repository section
  awk '
    /^\[core\]/ && !inserted {
      print "[arch-configs-aur]"
      print "SigLevel = Optional TrustAll"
      print "Server = file:///var/cache/arch-configs-aur"
      print ""
      inserted = 1
    }
    { print }
  ' "$PACMAN_CONF" > "$PACMAN_CONF.new" && mv "$PACMAN_CONF.new" "$PACMAN_CONF"
  log "Added [arch-configs-aur] repository to $PACMAN_CONF"
fi

log "Updating package database..."
pacman -Sy || warn "pacman -Sy failed (expected if offline)"

log "Done! You can now:"
echo "  - Install AUR packages: pacman -S <pkgname> (from arch-configs-aur)"
echo "  - Update AUR packages:  paru -Syu (will use local repo)"
echo "  - Rebuild repo:         Run this script again after mounting ISO"