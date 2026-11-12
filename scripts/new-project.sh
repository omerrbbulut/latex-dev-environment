#!/usr/bin/env bash
# latex-dev-environment — create a new LaTeX project from a template.
#
#   ./scripts/new-project.sh <article|thesis|technical-report> <target-dir> [--open] [--git]
#
#   --open   open the new project in VS Code
#   --git    run `git init` in the new project (local only, no remote)
#
# The target directory must not exist or must be empty. Nothing else is
# touched.
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

usage() { sed -n '2,10p' "$0"; exit "${1:-0}"; }
OPEN=0 GIT=0 pos=()
for arg in "$@"; do
  case "$arg" in
    --open) OPEN=1 ;;
    --git) GIT=1 ;;
    -h|--help) usage 0 ;;
    -*) die "unknown option: $arg" ;;
    *) pos+=("$arg") ;;
  esac
done
((${#pos[@]} == 2)) || usage 2
tpl=${pos[0]} dest=${pos[1]}
src="$LDE_REPO_DIR/templates/$tpl"
[[ -d "$src" ]] || die "unknown template '$tpl' (available: $(find "$LDE_REPO_DIR/templates" -mindepth 1 -maxdepth 1 -type d -printf '%f ' | sort))"
if [[ -e "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
  die "target '$dest' exists and is not empty; refusing to overwrite"
fi

mkdir -p "$dest"
(cd "$src" && tar --exclude=build --exclude='indent.log' -cf - .) | (cd "$dest" && tar -xf -)
cp "$LDE_REPO_DIR/templates/project.gitignore" "$dest/.gitignore"
ok "created $dest from template '$tpl'"

if [[ "$GIT" == 1 ]]; then
  git -C "$dest" init -q && ok "git repository initialised (no remote)"
fi
info "next steps:"
dim "cd $dest && code ."
dim "open main.tex, save (Ctrl+S) or press Ctrl+Alt+B -> build/main.pdf"
dim "command line: latexmk   (uses the template's .latexmkrc)"
if [[ "$OPEN" == 1 ]]; then
  CODE=$(code_bin) || die "VS Code not found"
  "$CODE" "$dest" "$dest/main.tex"
fi
