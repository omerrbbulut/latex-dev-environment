#!/usr/bin/env bash
# latex-dev-environment — repository test suite (no changes to your $HOME).
#
#   ./tests/run-tests.sh
#
#  1. shell scripts: bash -n, ShellCheck (if installed)
#  2. JSON/JSONC validity of vscode/*.json and the snippet file
#  3. snippet grammar + rendering every snippet and compiling the result
#  4. unit tests of the JSONC merge tool
#  5. sandbox install: configure-vscode.sh against a copy of a VS Code
#     settings file in a temporary HOME, twice (idempotency), then
#     uninstall.sh (exact restore)
#  6. templates: compile with the VS Code XeLaTeX tool, ChkTeX clean,
#     latexindent content-preserving and idempotent
#  7. new-project.sh creates a compilable project
#  8. git diff --check / no binaries or secrets staged
set -Euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
FAILS=0
t_ok()   { printf '  \e[32mok\e[0m    %s\n' "$*"; }
t_fail() { printf '  \e[31mFAIL\e[0m  %s\n' "$*"; FAILS=$((FAILS + 1)); }
t_skip() { printf '  \e[33mskip\e[0m  %s\n' "$*"; }
hdr()    { printf '\n\e[34m[%s]\e[0m\n' "$*"; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lde-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
hdr "1. shell scripts"
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do
  bash -n "$f" && t_ok "bash -n $f" || t_fail "bash -n $f"
done
if command -v shellcheck >/dev/null; then
  if shellcheck -x -S warning scripts/*.sh scripts/lib/*.sh tests/*.sh; then t_ok "shellcheck (warning level)"
  else t_fail "shellcheck"; fi
else
  t_skip "shellcheck not installed (sudo apt install shellcheck)"
fi

# ---------------------------------------------------------------------------
hdr "2. JSON / JSONC"
python3 scripts/lib/vscode_merge.py validate vscode/settings.json vscode/keybindings.json \
  && t_ok "vscode/settings.json, vscode/keybindings.json (JSONC)" || t_fail "JSONC validation"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' vscode/latex.code-snippets \
  && t_ok "vscode/latex.code-snippets (strict JSON)" || t_fail "snippets JSON"

# ---------------------------------------------------------------------------
hdr "3. snippets"
mkdir -p "$WORK/snip"; cp tests/references.bib "$WORK/snip/"
if python3 tests/snippet_check.py vscode/latex.code-snippets --render "$WORK/snip/snippets.tex" >/dev/null; then
  t_ok "snippet grammar, tab stops, balanced braces/environments"
  for eng in -pdf -xelatex; do
    if (cd "$WORK/snip" && latexmk "$eng" -interaction=nonstopmode -file-line-error -outdir="build$eng" snippets.tex >/dev/null 2>&1); then
      t_ok "all expanded snippets compile ($eng)"
    else
      t_fail "expanded snippets do not compile ($eng): $WORK/snip/build$eng/snippets.log"
    fi
  done
else
  python3 tests/snippet_check.py vscode/latex.code-snippets; t_fail "snippet validation"
fi

# ---------------------------------------------------------------------------
hdr "4. merge tool unit tests"
if python3 -m unittest -q tests/test_vscode_merge.py >"$WORK/unit.log" 2>&1; then t_ok "$(grep -o 'Ran [0-9]* tests' "$WORK/unit.log")"
else cat "$WORK/unit.log"; t_fail "unit tests"; fi

# ---------------------------------------------------------------------------
hdr "5. sandbox install / uninstall"
SB="$WORK/home"
mkdir -p "$SB/.config/Code/User"
fixture="$HOME/.config/Code/User/settings.json"
# Fixture: the user's real settings minus any block we installed earlier. If
# that leaves no settings (fresh system), use a realistic sample instead.
if [[ -f "$fixture" ]]; then
  LDE_LIB=scripts/lib python3 -c 'import os,sys; sys.path.insert(0,os.environ["LDE_LIB"]); import vscode_merge as vm
t = vm.strip_block(open(sys.argv[1],encoding="utf-8").read())
sys.stdout.write(t if vm.loads(t, allow_empty=True) else "")' "$fixture" >"$SB/.config/Code/User/settings.json"
fi
if [[ ! -s "$SB/.config/Code/User/settings.json" ]]; then
  cat >"$SB/.config/Code/User/settings.json" <<'JSONC'
{
    // THEME & APPEARANCE
    "workbench.colorTheme": "Catppuccin Mocha",
    "editor.fontFamily": "'JetBrainsMono Nerd Font', monospace", // font
    "editor.formatOnSave": true,
    /* unrelated language settings */
    "[python]": { "editor.defaultFormatter": "charliermarsh.ruff" },
    "json.schemaDownload.trustedDomains": {
        "https://raw.githubusercontent.com/catppuccin/vscode/": true
    }
}
JSONC
fi
cp "$SB/.config/Code/User/settings.json" "$WORK/settings.orig"
sbenv=(env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME HOME="$SB" NO_COLOR=1)
if "${sbenv[@]}" scripts/configure-vscode.sh >"$WORK/cfg1.log" 2>&1; then t_ok "configure-vscode.sh (first run)"
else cat "$WORK/cfg1.log"; t_fail "configure-vscode.sh first run"; fi
find "$SB" -type f ! -path '*/backups/*' -exec md5sum {} + | sort >"$WORK/state1"
if "${sbenv[@]}" scripts/configure-vscode.sh >"$WORK/cfg2.log" 2>&1; then
  find "$SB" -type f ! -path '*/backups/*' -exec md5sum {} + | sort >"$WORK/state2"
  if cmp -s "$WORK/state1" "$WORK/state2" && grep -q 'already up to date' "$WORK/cfg2.log"; then t_ok "second run is a no-op (idempotent)"
  else t_fail "second run changed files"; fi
else t_fail "configure-vscode.sh second run"; fi
LDE_LIB=scripts/lib python3 - "$WORK/settings.orig" "$SB/.config/Code/User/settings.json" <<'PY' && t_ok "all pre-existing settings keep their values" || t_fail "pre-existing settings changed"
import os, sys
sys.path.insert(0, os.environ["LDE_LIB"])
import vscode_merge as vm
old = vm.loads(open(sys.argv[1]).read()); new = vm.loads(open(sys.argv[2]).read())
bad = [k for k in old if new.get(k) != old[k]]
sys.exit(1 if bad else 0)
PY
LDE_LIB=scripts/lib python3 - "$WORK/settings.orig" "$SB/.config/Code/User/settings.json" <<'PY' \
  && t_ok "text outside the managed block is unchanged (comments, theme, fonts, other languages)" \
  || t_fail "text outside the managed block changed"
import os, sys
sys.path.insert(0, os.environ["LDE_LIB"])
import vscode_merge as vm
orig = open(sys.argv[1], encoding="utf-8").read()
merged = open(sys.argv[2], encoding="utf-8").read()
sys.exit(0 if vm.strip_block(merged) == orig and vm.find_block(merged) else 1)
PY
if "${sbenv[@]}" scripts/uninstall.sh --yes >"$WORK/un.log" 2>&1 \
   && cmp -s "$WORK/settings.orig" "$SB/.config/Code/User/settings.json" \
   && [[ ! -e "$SB/.config/chktex/chktexrc" && ! -e "$SB/.config/Code/User/snippets/latex.code-snippets" ]]; then
  t_ok "uninstall.sh restores settings.json byte-for-byte and removes installed files"
else
  cat "$WORK/un.log"; t_fail "uninstall.sh"
fi
# re-install in the sandbox for the template tests below
"${sbenv[@]}" scripts/configure-vscode.sh >/dev/null 2>&1

# ---------------------------------------------------------------------------
hdr "6. templates"
tool_cmd() { # tool dir doc
  mapfile -d '' -t CMD < <(python3 scripts/lib/vscode_merge.py tool-args --source vscode/settings.json \
    --tool "$1" --subst "HOME=$SB" --var "DOC=$2/$3" --var "OUTDIR=$2/build" --var "AUXDIR=$2/build")
}
for t in article thesis technical-report; do
  d="$WORK/tpl-$t"; mkdir -p "$d"
  (cd "templates/$t" && tar --exclude=build -cf - .) | (cd "$d" && tar -xf -)
  for tool in lde-xelatexmk lde-lualatexmk; do
    tool_cmd "$tool" "$d" main
    rm -rf "$d/build"
    if (cd "$d" && "${CMD[@]}" >"$d/$tool.out" 2>&1) && [[ -s "$d/build/main.pdf" && -s "$d/build/main.synctex.gz" ]]; then
      w=$(grep -cE '^(LaTeX|Package [A-Za-z]+) Warning' "$d/build/main.log" || true)
      [[ "$w" == 0 ]] && t_ok "$t ($tool): PDF + SyncTeX, 0 warnings" || t_fail "$t ($tool): $w warnings"
    else
      t_fail "$t ($tool) failed: $d/$tool.out"
    fi
  done
  (cd "$d" && rm -rf build && latexmk -silent >/dev/null 2>&1) && [[ -s "$d/build/main.pdf" ]] \
    && t_ok "$t: plain 'latexmk' via .latexmkrc" || t_fail "$t: latexmk via .latexmkrc"
  lint=$(cd "templates/$t" && chktex -wall -n22 -n30 -e16 -q -v0 -l "$REPO/config/chktexrc" main.tex 2>/dev/null)
  [[ -z "$lint" ]] && t_ok "$t: ChkTeX clean" || { printf '%s\n' "$lint"; t_fail "$t: ChkTeX warnings"; }
  bad=0
  while IFS= read -r f; do
    latexindent -c "$WORK/" -l config/latexindent.yaml "-y=defaultIndent: '  '" "$f" >"$WORK/li1.tex" 2>/dev/null || bad=1
    latexindent -c "$WORK/" -l config/latexindent.yaml "-y=defaultIndent: '  '" "$WORK/li1.tex" >"$WORK/li2.tex" 2>/dev/null || bad=1
    [[ "$(tr -d ' \t\n' <"$f")" == "$(tr -d ' \t\n' <"$WORK/li1.tex")" ]] || { echo "content changed: $f"; bad=1; }
    cmp -s "$f" "$WORK/li1.tex" || { echo "not formatted: $f"; bad=1; }
    cmp -s "$WORK/li1.tex" "$WORK/li2.tex" || { echo "not idempotent: $f"; bad=1; }
  done < <(find "templates/$t" -name '*.tex' -not -path '*/build/*')
  ((bad == 0)) && t_ok "$t: latexindent preserves content, files already formatted, idempotent" || t_fail "$t: latexindent"
done
d="$WORK/smoke"; mkdir -p "$d"; cp tests/smoke-test.tex tests/references.bib "$d/"
tool_cmd lde-pdflatexmk "$d" smoke-test
(cd "$d" && "${CMD[@]}" >/dev/null 2>&1) && [[ -s "$d/build/smoke-test.pdf" ]] \
  && t_ok "smoke test (pdflatex recipe)" || t_fail "smoke test pdflatex"

# ---------------------------------------------------------------------------
hdr "7. new-project.sh"
if scripts/new-project.sh article "$WORK/newproj" >/dev/null 2>&1 \
   && (cd "$WORK/newproj" && latexmk -silent >/dev/null 2>&1) && [[ -s "$WORK/newproj/build/main.pdf" ]]; then
  t_ok "project created from template compiles"
else t_fail "new-project.sh"; fi
scripts/new-project.sh article "$WORK/newproj" >/dev/null 2>&1 && t_fail "new-project.sh overwrote a non-empty dir" \
  || t_ok "new-project.sh refuses non-empty target"

# ---------------------------------------------------------------------------
hdr "8. repository hygiene"
if ! command -v git >/dev/null || ! git rev-parse --git-dir >/dev/null 2>&1; then
  t_skip "not a git checkout (or git missing): diff/binary/secret checks skipped"
else
  git diff --check && git diff --cached --check && t_ok "git diff --check" || t_fail "whitespace errors"
  files=$( { git ls-files; git ls-files --others --exclude-standard; } | sort -u)
  bins=$(while IFS= read -r f; do [[ -f "$f" ]] && ! grep -Iq . "$f" && [[ -s "$f" ]] && echo "$f"; done <<<"$files")
  [[ -z "$bins" ]] && t_ok "no binary files" || t_fail "binary files: $bins"
  if grep -nEI '(gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]+|password\s*[:=]\s*\S+)' \
       $files 2>/dev/null; then t_fail "possible secret found"; else t_ok "no secrets / tokens / private keys"; fi
  if grep -nEi '\.(ttf|otf|ttc)$' <<<"$files"; then t_fail "font files present"; else t_ok "no font files"; fi
fi

printf '\n'
if ((FAILS == 0)); then printf '\e[32mAll tests passed.\e[0m\n'; else printf '\e[31m%d test(s) failed.\e[0m\n' "$FAILS"; fi
((FAILS == 0))
