# shellcheck shell=bash
# latex-dev-environment — shared helpers for the scripts in scripts/.
# Source this file; do not execute it.

# ---- Paths ------------------------------------------------------------------
LDE_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LDE_NAME="latex-dev-environment"

# Every target path is derived from HOME / XDG variables, so the scripts can
# be tested against a throw-away HOME (see tests/run-tests.sh).
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
VSCODE_USER_DIR="${VSCODE_USER_DIR:-$XDG_CONFIG_HOME/Code/User}"
LDE_CONFIG_DIR="$XDG_CONFIG_HOME/$LDE_NAME"
LDE_STATE_DIR="$XDG_STATE_HOME/$LDE_NAME"
LATEXINDENT_DIR="$XDG_CONFIG_HOME/latexindent"
CHKTEX_DIR="$XDG_CONFIG_HOME/chktex"
LATEXINDENT_CACHE="$XDG_CACHE_HOME/latexindent"
LDE_BACKUP_DIR="${LDE_BACKUP_DIR:-$LDE_STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)}"
MERGE_PY="$LDE_REPO_DIR/scripts/lib/vscode_merge.py"

# ---- Output -----------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  _c_red=$'\e[31m' _c_grn=$'\e[32m' _c_yel=$'\e[33m' _c_blu=$'\e[34m' _c_dim=$'\e[2m' _c_off=$'\e[0m'
else
  _c_red='' _c_grn='' _c_yel='' _c_blu='' _c_dim='' _c_off=''
fi
step() { printf '\n%s==> %s%s\n' "$_c_blu" "$*" "$_c_off"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '  %s✔%s %s\n' "$_c_grn" "$_c_off" "$*"; }
warn() { printf '  %s!%s %s\n' "$_c_yel" "$_c_off" "$*" >&2; }
die()  { printf '  %s✘ %s%s\n' "$_c_red" "$*" "$_c_off" >&2; exit 1; }
dim()  { printf '    %s%s%s\n' "$_c_dim" "$*" "$_c_off"; }

on_error() {
  local rc=$? line=$1
  printf '%s✘ %s failed at line %s (exit %s)%s\n' "$_c_red" "$(basename "$0")" "$line" "$rc" "$_c_off" >&2
  exit "$rc"
}

have() { command -v "$1" >/dev/null 2>&1; }

# ask "question" -> 0 for yes. Honours ASSUME_YES=1. Non-interactive => no.
ask() {
  if [[ "${ASSUME_YES:-0}" == 1 ]]; then return 0; fi
  if [[ ! -t 0 ]]; then return 1; fi
  local reply
  read -r -p "    $1 [y/N] " reply
  [[ "$reply" =~ ^[YyEe] ]]
}

# ---- Files ------------------------------------------------------------------
# backup_file PATH -> copies PATH into the timestamped backup directory,
# keeping its path below HOME so restores are obvious.
backup_file() {
  local src=$1 rel dest
  [[ -e "$src" ]] || return 0
  rel="${src#"$HOME"/}"
  dest="$LDE_BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  dim "backup: $dest"
}

# install_file SRC DEST -> copy only if content differs; back up the old file.
install_file() {
  local src=$1 dest=$2
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    ok "up to date: ${dest/#$HOME/\~}"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    info "would install ${dest/#$HOME/\~}"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  backup_file "$dest"
  cp "$src" "$dest"
  ok "installed: ${dest/#$HOME/\~}"
}

# remove_if_ours SRC DEST -> delete DEST only if identical to the repo copy.
remove_if_ours() {
  local src=$1 dest=$2
  [[ -e "$dest" ]] || { ok "not present: ${dest/#$HOME/\~}"; return 0; }
  if cmp -s "$src" "$dest"; then
    backup_file "$dest"
    rm -f "$dest"
    ok "removed: ${dest/#$HOME/\~}"
  else
    warn "kept (modified locally, not identical to repository copy): ${dest/#$HOME/\~}"
  fi
}

# ---- System -----------------------------------------------------------------
os_id()      { . /etc/os-release 2>/dev/null && printf '%s' "${ID:-unknown}"; }
os_version() { . /etc/os-release 2>/dev/null && printf '%s' "${VERSION_ID:-unknown}"; }
os_pretty()  { . /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-unknown}"; }
os_like()    { . /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}"; }
arch()       { dpkg --print-architecture 2>/dev/null || uname -m; }

pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

code_bin() {
  local c
  for c in code code-insiders codium; do
    if have "$c"; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

# Installed LaTeX Workshop directory (newest version), empty if none.
latex_workshop_dir() {
  local d
  d=$(find "${VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}" -maxdepth 1 -type d \
        -iname 'james-yu.latex-workshop-*' 2>/dev/null | sort -V | tail -n1)
  printf '%s' "$d"
}
