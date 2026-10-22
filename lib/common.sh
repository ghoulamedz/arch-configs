#!/usr/bin/env bash
#
# lib/common.sh — shared helpers for install.sh (host side) and install-chroot.sh
# (inside the new root). Sourced, never executed directly.
#
# Design rules:
#   * Every external command runs through run() so its *full* output is printed
#     live AND kept in a log file. When a command fails, the last 40 lines of
#     that command's own output are printed in the failure report — that is the
#     "last error output from the command that caused it".
#   * Every mutating helper is idempotent: it inspects current state first and
#     reports "already done" instead of doing it twice. Re-running the installer
#     after any failure must be safe.
#   * step() records completed phases in a state file, so a re-run resumes at the
#     first phase that did not finish. ARCH_FORCE=1 redoes everything.

set -euo pipefail

# errtrace (set -E) is load-bearing, not decoration: without it bash does NOT run
# the ERR trap for a command that fails INSIDE A FUNCTION — and with errexit the
# shell then exits silently. Every phase of this installer is a function, so
# without -E a failure deep in configure_snapper() would kill the run with no
# message at all. That is exactly the "it just stops" behaviour to avoid.
set -E

# Colours, only when stdout is a terminal, so log output stays clean when piped.
if [[ -t 1 ]]; then
  _c_reset=$'\033[0m'; _c_bold=$'\033[1m'
  _c_blue=$'\033[34m'; _c_green=$'\033[32m'; _c_yellow=$'\033[33m'; _c_red=$'\033[31m'
  _c_cyan=$'\033[36m'
else
  _c_reset=''; _c_bold=''; _c_blue=''; _c_green=''; _c_yellow=''; _c_red=''; _c_cyan=''
fi

# ---------------------------------------------------------------------------
# Verbosity: always on, always implicit. There is no flag to turn this off.
# ---------------------------------------------------------------------------
# PS4 shows function depth, file and line, so the trace of a 700-line install is
# still readable:  +install-chroot.sh:317:configure_snapper snapper -c root ...
export PS4='+${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main} '
set -x

# Log directory for per-command output. Falls back to /tmp if the real path is
# not writable (it is, inside the chroot, but not when common.sh is unit-tested).
ARCH_LOGDIR=${ARCH_LOGDIR:-/var/log/arch-configs}
if ! mkdir -p "$ARCH_LOGDIR" 2>/dev/null; then
  ARCH_LOGDIR=/tmp/arch-configs
  mkdir -p "$ARCH_LOGDIR"
fi

# State directory: which phases have completed. Separate from the logs so you can
# wipe one without losing the other.
ARCH_STATE=${ARCH_STATE:-/var/lib/arch-configs}
if ! mkdir -p "$ARCH_STATE" 2>/dev/null; then
  ARCH_STATE=/tmp/arch-configs-state
  mkdir -p "$ARCH_STATE"
fi
COMPLETED=$ARCH_STATE/completed
touch "$COMPLETED"

# Set by run() when it has already printed a failure report, so the ERR trap does
# not print a second, less useful one.
_RUN_REPORTED=0

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

# section <title> — a visible banner between phases.
section() { printf '\n%s==> %s%s\n' "$_c_bold$_c_blue" "$*" "$_c_reset"; }

# log <msg> — a normal, successful action.
log() { printf '  %s%s%s %s\n' "$_c_green" 'ok' "$_c_reset" "$*"; }

# skip <msg> — something already in the desired state.
skip() { printf '  %s--%s %s\n' "$_c_yellow" "$_c_reset" "$*"; }

# warn <msg> — not fatal, but the operator should know.
warn() { printf '  %s!!%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }

# die <msg> — fatal; prints and exits non-zero.
die() { printf '\n  %sXX%s %s\n\n' "$_c_red" "$_c_reset" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# run <description> -- <command...> — the only way external commands are run.
#
# Prints the command, streams its combined stdout+stderr live through tee (so you
# see everything as it happens, including pacman progress bars), and appends it
# to a per-command log. On failure it prints the tail of that log and exits, so
# the diagnostic is the failing command's own output — not the trace noise.
#
# `set +x` around the invocation keeps the trace readable: one line per command
# instead of one line per command plus every word-split argument.
# ---------------------------------------------------------------------------
run() {
  local desc=$1; shift
  [[ ${1:-} == -- ]] && shift
  local rc=0
  _stream "$desc" -- "$@" || rc=$?
  (( rc == 0 )) && return 0
  _report_failure "$rc"
  exit "$rc"
}

# _stream <desc> -- <cmd...> — internal: announce, tee live, record the log path,
# and return the command's own exit status without deciding what to do about it.
_stream() {
  local desc=$1; shift
  [[ ${1:-} == -- ]] && shift

  local slug logfile rc=0
  slug=$(printf '%s' "$desc" | tr -cs 'A-Za-z0-9._-' '_')
  logfile="$ARCH_LOGDIR/$slug.log"
  _LAST_LOG=$logfile
  _LAST_CMD="$*"

  printf '\n  %s>>>%s %s\n' "$_c_cyan" "$_c_reset" "$desc"

  # Truncate rather than append: the failure report tails this file, and stale
  # lines from an earlier run would otherwise be shown as "the error".
  : >"$logfile"

  # `if` suppresses errexit for this pipeline so PIPESTATUS is readable. pipefail
  # is set, so the pipeline reports the command's status, not tee's.
  local hadx=0
  [[ $- == *x* ]] && hadx=1 && set +x
  if "$@" 2>&1 | tee "$logfile"; then
    rc=0
  else
    rc=${PIPESTATUS[0]}
  fi
  (( hadx )) && set -x

  # Keep the full transcript across runs, separately from the per-command log.
  cat "$logfile" >>"$ARCH_LOGDIR/session.log" 2>/dev/null || true
  return "$rc"
}

# _report_failure <rc> — print the exit code, the command, the log path and the
# last 40 lines of the failing command's own output, then mark it reported so the
# ERR trap stays quiet.
_report_failure() {
  local rc=$1
  _RUN_REPORTED=1
  set +x   # keep the failure report readable: no trace lines inside it
  printf '\n' >&2
  printf '  %sXX%s command failed (exit %d)\n' "$_c_red" "$_c_reset" "$rc" >&2
  printf '  %s   command:%s %s\n' "$_c_red" "$_c_reset" "${_LAST_CMD:-unknown}" >&2
  printf '  %s   log:    %s%s\n' "$_c_red" "$_c_reset" "${_LAST_LOG:-unknown}" >&2
  printf '\n  %s--- last output of the failing command ---%s\n' "$_c_yellow" "$_c_reset" >&2
  tail -n 40 "${_LAST_LOG:-/dev/null}" 2>/dev/null | sed 's/^/  | /' >&2
  printf '  %s--- end ---%s\n\n' "$_c_yellow" "$_c_reset" >&2
}

# try_run <desc> -- <cmd...> — same streaming and logging as run(), but a failure
# is a warning, not fatal. For optional improvements (mirror ranking) that must
# never be able to abort an install.
try_run() {
  local desc=$1; shift
  [[ ${1:-} == -- ]] && shift
  local rc=0
  _stream "$desc" -- "$@" || rc=$?
  (( rc == 0 )) && return 0
  warn "optional command failed (exit $rc): $desc"
  [[ -s ${_LAST_LOG:-} ]] && tail -n 10 "${_LAST_LOG}" | sed 's/^/  | /' >&2
  return "$rc"
}

# capture <var> -- <command...> — run a read-only probe, keep its stdout in var.
# Output is not streamed (these are cheap queries), but stderr is shown on
# failure. Used where a command's stdout is a value, not a report.
capture() {
  local __var=$1; shift
  [[ ${1:-} == -- ]] && shift
  local __out __rc=0
  __out=$("$@" 2>"$ARCH_LOGDIR/capture.err") || __rc=$?
  if (( __rc != 0 )); then
    _RUN_REPORTED=1
    printf '  %sXX%s probe failed (exit %d): %s\n' "$_c_red" "$_c_reset" "$__rc" "$*" >&2
    sed 's/^/  | /' "$ARCH_LOGDIR/capture.err" >&2
    exit "$__rc"
  fi
  printf -v "$__var" '%s' "$__out"
}

# ---------------------------------------------------------------------------
# Failure reporting (fallback for commands not wrapped in run())
# ---------------------------------------------------------------------------
# BASH_SOURCE/BASH_LINENO/BASH_COMMAND must be read from the *caller* frame: the
# old version printed the trap function's own line number, which pointed at the
# trap instead of the failure.
die_report() {
  local err=$?
  if (( _RUN_REPORTED )); then
    exit "$err"
  fi
  local src=${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$0}}
  local line=${BASH_LINENO[0]:-$LINENO}
  local fn=${FUNCNAME[1]:-main}
  printf '\n  %sXX%s FAILED in %s() at %s:%d (exit %d)\n' \
    "$_c_red" "$_c_reset" "$fn" "${src##*/}" "$line" "$err" >&2
  printf '  %s   command:%s %s\n\n' "$_c_red" "$_c_reset" "$BASH_COMMAND" >&2
  exit "$err"
}
trap die_report ERR

# ---------------------------------------------------------------------------
# step <name> <function> — run one phase, record it, skip it next time.
# ---------------------------------------------------------------------------
step() {
  local name=$1 fn=$2
  if [[ ${ARCH_FORCE:-0} != 1 ]] && grep -qxF -- "$name" "$COMPLETED"; then
    skip "phase already complete: $name  (ARCH_FORCE=1 to redo)"
    return 0
  fi
  section "$name"
  "$fn"
  printf '%s\n' "$name" >>"$COMPLETED"
  log "phase complete: $name"
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
need_root() {
  (( EUID == 0 )) || die "must run as root (try: sudo $0)"
}

need_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
  done
}

pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

ensure_pkg() {
  local missing=() p
  for p in "$@"; do pkg_installed "$p" || missing+=("$p"); done
  (( ${#missing[@]} )) || { skip "already installed: $*"; return 0; }
  run "pacman -S ${missing[*]}" -- pacman -S --needed --noconfirm "${missing[@]}"
}

# ---------------------------------------------------------------------------
# Idempotent file writes
# ---------------------------------------------------------------------------

# write_file <path> [mode] [owner:group] — read content from stdin, install only
# when content, mode or ownership actually differ. `install -D` creates missing
# parents and sets mode/owner atomically.
#
# No RETURN trap here: a RETURN trap set inside a function stays armed after it
# returns (and would fire on the next function's exit, or clobber another trap).
# Cleanup is explicit instead.
write_file() {
  local path=$1 mode=${2:-0644} owner=${3:-root:root}
  local tmp; tmp=$(mktemp)

  if ! cat >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  if [[ -f $path ]] && cmp -s "$tmp" "$path" \
     && [[ $(stat -c '%a' "$path") == "${mode#0}" ]] \
     && [[ $(stat -c '%U:%G' "$path") == "$owner" ]]; then
    rm -f "$tmp"
    skip "unchanged: $path"
    return 0
  fi

  if ! install -D -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$tmp" "$path"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  log "wrote: $path"
}

# append_once <line> <file> — append only if that exact line is absent. Warns
# instead of dying when the file is missing (a package that was not installed
# should degrade, not abort a whole install phase).
append_once() {
  local line=$1 file=$2
  [[ -f $file ]] || { warn "cannot append to missing file: $file"; return 0; }
  if grep -qxF -- "$line" "$file"; then
    skip "already in $file: $line"
  else
    printf '%s\n' "$line" >>"$file"
    log "appended to $file: $line"
  fi
}

# backup_once <file> [expected-marker] — keep one pristine copy.
# The backup is only taken when the file does NOT yet contain our marker, so a
# re-run never overwrites the original with an already-modified version.
backup_once() {
  local file=$1
  [[ -f $file ]] || return 0
  if [[ -e "$file.pre-arch-configs" ]]; then
    skip "backup exists: $file.pre-arch-configs"
    return 0
  fi
  cp -a "$file" "$file.pre-arch-configs"
  log "backed up: $file -> $file.pre-arch-configs"
}

# ---------------------------------------------------------------------------
# Mirror ranking — official mirrors only
# ---------------------------------------------------------------------------
# rank_mirrors — rewrite /etc/pacman.d/mirrorlist with the fastest OFFICIAL
# Arch mirrors, measured from this machine.
#
# Guarantees, because mirror trust is not negotiable:
#   * only servers listed on https://archlinux.org/mirrors/status/ are written;
#     no third-party, no CachyOS/EndeavourOS/any other repo is added;
#   * /etc/pacman.conf is NOT touched here — no repository is added, removed or
#     re-pointed, by this function or any other;
#   * the previous mirrorlist is kept as mirrorlist.pre-arch-configs;
#   * any failure is a warning: the old mirrorlist stays and the install goes on.
#
# Ranker order: rate-mirrors (what CachyOS uses, AUR), then reflector (the
# official Arch package in packages/official.txt), then the mirror status JSON +
# python3 (present on the ISO), which needs no extra package at all.
#
# MIRROR_RANKING=0 skips this entirely. MIRROR_COUNT/MIRROR_PROTOCOL tune it.
MIRROR_COUNT=${MIRROR_COUNT:-20}
MIRROR_PROTOCOL=${MIRROR_PROTOCOL:-https}

rank_mirrors() {
  if [[ ${MIRROR_RANKING:-1} != 1 ]]; then
    skip "mirror ranking disabled (MIRROR_RANKING=0)"
    return 0
  fi

  local ml=/etc/pacman.d/mirrorlist
  [[ -f $ml ]] || die "missing $ml (pacman-mirrorlist should provide it)"
  backup_once "$ml"

  local tmp ok=0
  tmp=$(mktemp)

  if command -v rate-mirrors >/dev/null 2>&1; then
    log "mirror ranker: rate-mirrors (the one CachyOS ships)"
    try_run "rate-mirrors official arch ($MIRROR_PROTOCOL)" -- \
      bash -c "rate-mirrors --allow-root --protocol '$MIRROR_PROTOCOL' arch | tee '$tmp'" && ok=1

  elif command -v reflector >/dev/null 2>&1; then
    log "mirror ranker: reflector (official Arch package)"
    try_run "reflector --protocol $MIRROR_PROTOCOL --sort rate" -- \
      reflector --protocol "$MIRROR_PROTOCOL" --latest 50 --number "$MIRROR_COUNT" \
                --sort rate --threads 4 --connection-timeout 5 --download-timeout 10 \
                --save "$tmp" && ok=1

  elif command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    log "mirror ranker: archlinux.org/mirrors/status/json (no reflector installed yet)"
    local json; json=$(mktemp)
    if try_run "fetch official mirror status JSON" -- \
         curl -fsS --max-time 20 https://archlinux.org/mirrors/status/json/ -o "$json"; then
      if python3 - "$json" "$MIRROR_COUNT" "$MIRROR_PROTOCOL" >"$tmp" <<'PY'
import json, sys
path, count, proto = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(path) as fh:
    data = json.load(fh)
urls = [m for m in data.get("urls", [])
        if m.get("protocol") == proto
        and m.get("active")
        and float(m.get("completion_ratio") or 0) >= 0.99]
urls.sort(key=lambda m: (m.get("delay") or 99999, m.get("duration_avg") or 99999))
print("# Ranked official Arch mirrors (%s) from archlinux.org/mirrors/status/" % proto)
print("# Generated by arch-configs. No third-party hosts, no extra repositories.")
for m in urls[:count]:
    print("Server = %s$repo/os/$arch" % m["url"].rstrip("/"))
PY
      then
        ok=1
      else
        warn "could not parse the mirror status JSON"
      fi
    fi
    rm -f "$json"
  else
    warn "no mirror ranker available (need rate-mirrors, reflector, or curl+python3) — keeping the current mirrorlist"
    rm -f "$tmp"
    return 0
  fi

  local n=0
  (( ok )) && n=$(grep -c '^Server = ' "$tmp" 2>/dev/null || true)
  if (( n < 3 )); then
    warn "mirror ranking produced ${n} usable server(s) — keeping the previous mirrorlist"
    rm -f "$tmp"
    return 0
  fi

  write_file "$ml" 0644 root:root <"$tmp"
  rm -f "$tmp"
  log "mirrorlist ranked: $n official servers (previous kept as $ml.pre-arch-configs)"
}

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------
# enable_service <unit>... — enable, never start (no PID 1 in a chroot).
# Short names get .service; anything with a dot keeps its own suffix.
enable_service() {
  local u unit
  for u in "$@"; do
    case $u in
      *.*) unit=$u ;;
      *)   unit="$u.service" ;;
    esac

    if [[ ! -e /usr/lib/systemd/system/$unit && ! -e /etc/systemd/system/$unit ]]; then
      warn "unit not found, skipping: $unit"
      continue
    fi
    # is-enabled exits non-zero for 'disabled', 'static', 'masked' AND for a
    # dangling symlink; only trust a literal 'enabled'.
    if [[ $(systemctl is-enabled "$unit" 2>/dev/null || true) == enabled ]]; then
      skip "already enabled: $unit"
      continue
    fi
    run "systemctl enable $unit" -- systemctl enable "$unit"
    log "enabled: $unit"
  done
}

# ---------------------------------------------------------------------------
# Tree copying
# ---------------------------------------------------------------------------
# copy_tree <src> <dest> [owner] — copy a config tree, preserving modes, and fix
# ownership immediately so an interrupted run never leaves root-owned dotfiles.
# Unchanged files are still copied (cheap, and keeps the tree authoritative), but
# the ownership is applied per-run to the whole destination.
copy_tree() {
  local src=$1 dest=$2 owner=${3:-}
  [[ -d $src ]] || die "missing directory in repo: $src"
  mkdir -p "$dest"
  cp -a "$src/." "$dest/"
  if [[ -n $owner ]]; then
    chown -R "$owner" "$dest"
  fi
  log "copied: $src -> $dest${owner:+ (owner $owner)}"
}
