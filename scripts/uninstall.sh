#!/usr/bin/env bash
# latex-dev-environment — remove what configure-vscode.sh added.
#
#   ./scripts/uninstall.sh [--yes]
#
# Removes ONLY:
#   * the managed blocks in ~/.config/Code/User/{settings,keybindings}.json
#   * installed copies of the snippets / latexindent / chktex / latexmk files,
#     and only if they are still identical to the repository copies
# Everything removed is backed up first. Ubuntu packages, TeX Live,
# VS Code and extensions are NOT removed (other tools may depend on them);
# the commands to do that manually are printed at the end.
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done
export ASSUME_YES

step "Uninstall latex-dev-environment configuration"
info "This removes the managed VS Code blocks and the installed config files."
ask "Continue?" || die "aborted (nothing changed)"

step "VS Code"
for kind in settings keybindings; do
  python3 "$MERGE_PY" remove --kind "$kind" --target "$VSCODE_USER_DIR/$kind.json" \
    --backup-dir "$LDE_BACKUP_DIR/${VSCODE_USER_DIR#"$HOME"/}" | sed 's/^/    /'
done
remove_if_ours "$LDE_REPO_DIR/vscode/latex.code-snippets" "$VSCODE_USER_DIR/snippets/latex.code-snippets"

step "Tool configuration"
remove_if_ours "$LDE_REPO_DIR/config/latexindent.yaml" "$LATEXINDENT_DIR/latexindent.yaml"
if grep -qs "Managed by $LDE_NAME" "$LATEXINDENT_DIR/indentconfig.yaml"; then
  backup_file "$LATEXINDENT_DIR/indentconfig.yaml"
  rm -f "$LATEXINDENT_DIR/indentconfig.yaml"
  ok "removed: ${LATEXINDENT_DIR/#$HOME/\~}/indentconfig.yaml"
fi
remove_if_ours "$LDE_REPO_DIR/config/chktexrc" "$CHKTEX_DIR/chktexrc"
remove_if_ours "$LDE_REPO_DIR/config/latexmk/include-subdirs.pl" "$LDE_CONFIG_DIR/latexmk/include-subdirs.pl"
rmdir "$LDE_CONFIG_DIR/latexmk" "$LDE_CONFIG_DIR" "$CHKTEX_DIR" "$LATEXINDENT_DIR" 2>/dev/null || true

step "Done"
[[ -d "$LDE_BACKUP_DIR" ]] && info "backups: ${LDE_BACKUP_DIR/#$HOME/\~}"
info "Not removed (do it manually if you really want to):"
dim "code --uninstall-extension james-yu.latex-workshop"
dim "code --uninstall-extension streetsidesoftware.code-spell-checker-turkish"
dim "sudo apt remove latexmk biber chktex texlive-xetex texlive-luatex ...   # see install-ubuntu.sh"
