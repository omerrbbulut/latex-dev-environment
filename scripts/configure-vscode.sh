#!/usr/bin/env bash
# latex-dev-environment — apply VS Code + tool configuration for the current user.
#
#   ./scripts/configure-vscode.sh [--dry-run]
#
# What it touches (all inside $HOME, never system files):
#   ~/.config/Code/User/settings.json        managed block merged (JSONC-aware)
#   ~/.config/Code/User/keybindings.json     managed block merged
#   ~/.config/Code/User/snippets/latex.code-snippets
#   ~/.config/latexindent/{latexindent.yaml,indentconfig.yaml}
#   ~/.config/chktex/chktexrc
#   ~/.config/latex-dev-environment/latexmk/include-subdirs.pl
# Every file that changes is backed up first to
#   ~/.local/state/latex-dev-environment/backups/<timestamp>/
# Re-running is safe: unchanged files are left alone.
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done
export DRY_RUN

have python3 || die "python3 is required (sudo apt install python3)"

merge() { # kind target source
  local kind=$1 target=$2 source=$3 args=()
  [[ "$DRY_RUN" == 1 ]] && args+=(--dry-run)
  python3 "$MERGE_PY" merge --kind "$kind" --target "$target" --source "$source" \
    --subst "HOME=$HOME" --backup-dir "$LDE_BACKUP_DIR/${VSCODE_USER_DIR#"$HOME"/}" "${args[@]}" \
    | sed 's/^/    /'
}

step "VS Code user settings (${VSCODE_USER_DIR/#$HOME/\~})"
[[ "$DRY_RUN" == 1 ]] || mkdir -p "$VSCODE_USER_DIR/snippets"
merge settings "$VSCODE_USER_DIR/settings.json" "$LDE_REPO_DIR/vscode/settings.json"

step "VS Code keybindings"
merge keybindings "$VSCODE_USER_DIR/keybindings.json" "$LDE_REPO_DIR/vscode/keybindings.json"

step "LaTeX snippets"
install_file "$LDE_REPO_DIR/vscode/latex.code-snippets" "$VSCODE_USER_DIR/snippets/latex.code-snippets"

step "latexindent"
install_file "$LDE_REPO_DIR/config/latexindent.yaml" "$LATEXINDENT_DIR/latexindent.yaml"
indentconfig="$LATEXINDENT_DIR/indentconfig.yaml"
expected_indentconfig="# Managed by $LDE_NAME — tells latexindent where the user settings live.
paths:
  - $LATEXINDENT_DIR/latexindent.yaml"
if [[ -f "$indentconfig" ]] && ! grep -q "Managed by $LDE_NAME" "$indentconfig"; then
  if grep -qF "$LATEXINDENT_DIR/latexindent.yaml" "$indentconfig"; then
    ok "existing indentconfig.yaml already lists latexindent.yaml"
  else
    warn "your own $indentconfig exists and was left untouched."
    warn "add this line under 'paths:' to use the repository settings:"
    warn "  - $LATEXINDENT_DIR/latexindent.yaml"
  fi
else
  tmp=$(mktemp)
  printf '%s\n' "$expected_indentconfig" >"$tmp"
  install_file "$tmp" "$indentconfig"
  rm -f "$tmp"
fi
[[ "$DRY_RUN" == 1 ]] || mkdir -p "$LATEXINDENT_CACHE"

step "ChkTeX"
install_file "$LDE_REPO_DIR/config/chktexrc" "$CHKTEX_DIR/chktexrc"

step "latexmk helper (\\include subdirectories)"
install_file "$LDE_REPO_DIR/config/latexmk/include-subdirs.pl" "$LDE_CONFIG_DIR/latexmk/include-subdirs.pl"

step "Done"
if [[ -d "$LDE_BACKUP_DIR" ]]; then
  info "backups of changed files: ${LDE_BACKUP_DIR/#$HOME/\~}"
else
  info "nothing needed a backup (no existing file was changed)"
fi
info "VS Code picks up settings/keybindings/snippets immediately; reload the"
info "window (Ctrl+Shift+P → 'Developer: Reload Window') if LaTeX Workshop was running."
