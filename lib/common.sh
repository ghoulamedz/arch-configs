#!/usr/bin/env bash
#
# lib/common.sh — shared helpers for install.sh (host side) and install-chroot.sh
# (inside the new root). Sourced, never executed directly.
#
# Every helper is idempotent: running the installer twice must be a no-op, not a
# second set of edits. That is why writes go through write_file() and appends go
# through append_once().

# Fail fast, and treat unset variables and failed pipes as errors. Without this a
# typo in a variable name silently becomes an empty string and the script writes
# a broken config instead of stopping.
set -euo pipefail

# Colours, only when stdout is a terminal, so log output stays clean when piped.
if [[ -t 1 ]]; then
  _c_reset=$'\033[0m'; _c_bold=$'\033[1m'
  _c_blue=$'\033[34m'; _c_green=$'\033[32m'; _c_yellow=$'\033[33m'; _c_red=$'\033[31m'
else
  _c_reset=''; _c_bold=''; _c_blue=''; _c_green=''; _c_yellow=''; _c_red=''
fi

# ARCH_CONFIGS_DEBUG=1 — turn on shell tracing (set -x) for a verbose run.
# In any case, the ERR trap below prints the file:line of the command that
# died, so a failed install tells you exactly where to look instead of stopping
# silently in the middle of a long run.
set -x  # debug tracing on by default; set ARCH_CONFIGS_DEBUG=0 to disable

# die_report — ERR trap: report where the script failed, then exit with the
# same exit code. Triggered by `set -e` when a command returns non-zero
# (commands inside `if`/`||`/`&&` tests intentionally do not trigger it).
die_report() {
  local err=$?
  printf '\n  %sXX%s FAILED: %s:%d (exit %d)\n  running: %s\n\n' \
    "$_c_red" "$_c_reset" "${BASH_SOURCE[0]:-$0}" "$LINENO" "$err" "$BASH_COMMAND" >&2
  exit "$err"
}
trap die_report ERR

# section <title> — a visible banner between phases, so a long run is readable.
section() { printf '\n%s==> %s%s\n' "$_c_bold$_c_blue" "$*" "$_c_reset"; }

# log <msg> — a normal, successful action.
log() { printf '  %s%s%s %s\n' "$_c_green" 'ok' "$_c_reset" "$*"; }

# skip <msg> — something already in the desired state. Distinct from log so a
# re-run is obviously a re-run.
skip() { printf '  %s--%s %s\n' "$_c_yellow" "$_c_reset" "$*"; }

# warn <msg> — not fatal, but the operator should know.
warn() { printf '  %s!!%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }

# die <msg> — fatal; prints and exits non-zero.
die() { printf '\n  %sXX%s %s\n\n' "$_c_red" "$_c_reset" "$*" >&2; exit 1; }

# need_root — most of both phases runs as root. Check once, early, with a clear
# message rather than failing 40 lines later on a permission error.
need_root() {
  (( EUID == 0 )) || die "must run as root (try: sudo $0)"
}

# need_cmd <cmd>... — verify external tools the script depends on are present.
need_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
  done
}

# pkg_installed <pkg> — true if pacman knows the package as installed.
pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

# ensure_pkg <pkg>... — install only the ones that are missing, in one transaction.
# pacman -S --needed makes this safe to call on every run.
ensure_pkg() {
  local missing=() p
  for p in "$@"; do pkg_installed "$p" || missing+=("$p"); done
  (( ${#missing[@]} )) || { skip "already installed: $*"; return 0; }
  log "installing: ${missing[*]}"
  pacman -S --needed --noconfirm "${missing[@]}"
}

# write_file <path> [mode] [owner:group] — read the new content from stdin and
# install it atomically, but only if the content actually differs. `install -D`
# creates missing parent directories and sets mode/owner in one step.
write_file() {
  local path=$1 mode=${2:-0644} owner=${3:-root:root}
  local tmp; tmp=$(mktemp)
  cat >"$tmp"
  if [[ -f $path ]] && cmp -s "$tmp" "$path"; then
    skip "unchanged: $path"
  else
    install -D -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$tmp" "$path"
    log "wrote: $path"
  fi
  rm -f "$tmp"
}

# append_once <line> <file> — append a line only if that exact line is absent.
# Used for /etc/pacman.conf and /etc/pam.d/sddm, which are owned by packages and
# must be amended rather than replaced.
append_once() {
  local line=$1 file=$2
  [[ -f $file ]] || die "cannot append to missing file: $file"
  if grep -qxF -- "$line" "$file"; then
    skip "already in $file: $line"
  else
    printf '%s\n' "$line" >>"$file"
    log "appended to $file: $line"
  fi
}

# backup_once <file> — keep one .pre-arch-configs copy before the first change,
# so a package's original file can always be recovered.
backup_once() {
  local file=$1
  [[ -f $file ]] || return 0
  if [[ -e "$file.pre-arch-configs" ]]; then
    skip "backup exists: $file.pre-arch-configs"
  else
    cp -a "$file" "$file.pre-arch-configs"
    log "backed up: $file -> $file.pre-arch-configs"
  fi
}

# enable_service <unit>... — enable, never start. There is no running systemd in
# a chroot, so `systemctl start` would fail; enabling only creates the symlinks.
#
# Unit FILES always carry a suffix (`NetworkManager.service`), while the SERVICES
# array deliberately lists the readable short names. Without the normalisation
# below the existence check below would fail for every suffix-less entry and
# silently skip it — which is how an install ends up with no sddm and no
# NetworkManager on first boot while still reporting success.
#
# A unit whose file is absent is skipped with a warning, so a missing optional
# package degrades to a warning instead of aborting the whole install.
enable_service() {
  local u unit target wants_dir
  for u in "$@"; do
    case $u in
      *.*) unit=$u ;;          # already suffixed (.service, .timer, .socket…)
      *)   unit="$u.service" ;; # bare name, e.g. NetworkManager
    esac

    if [[ ! -e /usr/lib/systemd/system/$unit && ! -e /etc/systemd/system/$unit ]]; then
      warn "unit not found, skipping: $unit"
      continue
    fi
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
      skip "already enabled: $unit"
      continue
    fi

    # `systemctl enable` talks to D-Bus, which is not running inside the chroot
    # (no systemd PID 1), so it dies with
    # "org.freedesktop.DBus.Error.ServiceUnknown: ...systemd1". Never call it
    # here — enable units purely as symlinks under /etc/systemd/system, which
    # is all `systemctl enable` does anyway.
    target=$(grep -hE '^WantedBy=' /usr/lib/systemd/system/$unit /etc/systemd/system/$unit 2>/dev/null \
      | head -n1 | cut -d= -f2- | tr -d '[:space:]' || true)
    target=${target:-multi-user.target}
    wants_dir=/etc/systemd/system/${target}.wants
    mkdir -p "$wants_dir"
    ln -sf "/usr/lib/systemd/system/$unit" "$wants_dir/$unit"
    log "enabled: $unit -> ${target}.wants"
  done
}

# copy_tree <src> <dest> — copy a config tree, then hand it to a user. rsync is
# not installed at this point, so use cp -a and fix ownership afterwards.
copy_tree() {
  local src=$1 dest=$2
  [[ -d $src ]] || die "missing directory in repo: $src"
  mkdir -p "$dest"
  cp -a "$src/." "$dest/"
  log "copied: $src -> $dest"
}
