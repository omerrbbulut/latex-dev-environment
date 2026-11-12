#!/usr/bin/env bash
# latex-dev-environment — environment verification.
#
#   ./scripts/doctor.sh [--quick] [--project DIR] [--keep]
#
#   --quick        skip compilation tests (tools and configuration only)
#   --project DIR  also inspect DIR/.vscode/settings.json for settings that
#                  override or break the global configuration
#   --keep         keep the temporary build directory for inspection
#
# Prints PASS / WARN / FAIL lines and a summary. Exit status is 1 if any
# FAIL was recorded; WARN (optional features) never fails the run.
# Compilation uses exactly the latexmk arguments VS Code uses
# (read from vscode/settings.json), in a temporary directory.
set -Euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

QUICK=0 KEEP=0 PROJECT=""
while (($#)); do
  case "$1" in
    --quick) QUICK=1 ;;
    --keep) KEEP=1 ;;
    --project) PROJECT=${2:?--project needs a directory}; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

N_PASS=0 N_WARN=0 N_FAIL=0
pass() { N_PASS=$((N_PASS + 1)); printf '  %sPASS%s  %s\n' "$_c_grn" "$_c_off" "$*"; }
wrn()  { N_WARN=$((N_WARN + 1)); printf '  %sWARN%s  %s\n' "$_c_yel" "$_c_off" "$*"; }
fl()   { N_FAIL=$((N_FAIL + 1)); printf '  %sFAIL%s  %s\n' "$_c_red" "$_c_off" "$*"; }
section() { printf '\n%s%s%s\n' "$_c_blu" "$*" "$_c_off"; }

first_line() { "$@" 2>&1 | head -n1; }

# ---------------------------------------------------------------------------
section "System"
if [[ "$(os_id)" == ubuntu ]]; then
  case "$(os_version)" in
    26.04|25.10|24.04) pass "$(os_pretty) ($(arch))" ;;
    *) wrn "$(os_pretty) ($(arch)) — untested release" ;;
  esac
else
  wrn "$(os_pretty) — not Ubuntu"
fi

# ---------------------------------------------------------------------------
section "TeX toolchain"
if have kpsewhich && have tex; then
  pass "TeX distribution: $(first_line tex --version | sed 's/^TeX //')"
else
  fl "TeX Live not found (./scripts/install-ubuntu.sh)"
fi
for c in pdflatex xelatex lualatex latexmk biber chktex latexindent synctex; do
  if have "$c"; then
    case "$c" in
      latexmk) v=$(latexmk -v 2>/dev/null | grep -o 'Version [0-9.]*' | head -n1) ;;
      latexindent) v="version $(latexindent --version 2>/dev/null | head -n1)" ;;
      biber) v=$(biber --version 2>/dev/null) ;;
      chktex) v=$(chktex --version 2>/dev/null | head -n1 | awk '{print $2}') ;;
      synctex) v="$(command -v synctex)" ;;
      *) v=$("$c" --version 2>/dev/null | head -n1) ;;
    esac
    pass "$c: $v"
  else
    fl "$c not found"
  fi
done
if have texcount; then pass "texcount (word count) available"; else wrn "texcount not found (word count disabled)"; fi
if latexindent --version >/dev/null 2>&1; then :; else fl "latexindent cannot start (missing Perl modules? sudo apt install texlive-extra-utils)"; fi
missing_tex=()
for sty in biblatex.sty polyglossia.sty fontspec.sty unicode-math.sty cleveref.sty siunitx.sty \
           listings.sty algpseudocode.sty tikz.sty acronym.sty example-image-a.pdf hyph-tr.tex; do
  kpsewhich "$sty" >/dev/null 2>&1 || missing_tex+=("$sty")
done
if ((${#missing_tex[@]} == 0)); then
  pass "TeX packages used by the templates are present (biblatex, polyglossia, cleveref, ...)"
else
  fl "TeX files missing: ${missing_tex[*]} (./scripts/install-ubuntu.sh)"
fi

# ---------------------------------------------------------------------------
section "Fonts"
if have fc-list; then
  # capture once: `fc-list | grep -q` would SIGPIPE fc-list under pipefail
  families=$(fc-list : family 2>/dev/null)
  pass "fontconfig: $(wc -l <<<"$families") font families/styles"
  if grep -Eq '^Aptos(,|$)' <<<"$families"; then
    pass "Aptos available (templates use it)"
  else
    wrn "Aptos not installed — templates fall back to TeX Gyre Heros (optional)"
  fi
  if grep -Eqi 'JetBrains ?Mono' <<<"$families"; then
    pass "JetBrains Mono available (editor font)"
  else
    wrn "JetBrains Mono not installed (editor font only, optional)"
  fi
  if grep -qi 'TeX Gyre Heros' <<<"$families"; then
    pass "TeX Gyre Heros (fallback font) available"
  else
    wrn "TeX Gyre Heros missing (fonts-texgyre); fallback font unavailable"
  fi
else
  fl "fc-list not found (fontconfig)"
fi

# ---------------------------------------------------------------------------
section "VS Code"
LW_DIR=""
if CODE=$(code_bin); then
  pass "$CODE $(first_line "$CODE" --version)"
  exts=$("$CODE" --list-extensions --show-versions 2>/dev/null | tr '[:upper:]' '[:lower:]')
  while IFS= read -r ext; do
    ext=${ext%%#*}; ext=${ext//[[:space:]]/}; [[ -n "$ext" ]] || continue
    if v=$(grep -i "^${ext}@" <<<"$exts"); then
      pass "extension $v"
    elif [[ "$ext" == james-yu.latex-workshop ]]; then
      fl "LaTeX Workshop not installed (./scripts/install-vscode.sh)"
    else
      wrn "extension $ext not installed (optional)"
    fi
  done <"$LDE_REPO_DIR/vscode/extensions.txt"
else
  fl "VS Code not found"
fi
LW_DIR=$(latex_workshop_dir)

# ---------------------------------------------------------------------------
section "Configuration"
check_block() { # kind file source label
  local out rc
  out=$(python3 "$MERGE_PY" check --kind "$1" --target "$2" --source "$3" --subst "HOME=$HOME" 2>&1); rc=$?
  if ((rc == 0)); then
    if [[ "$out" == *"overridden by user"* ]]; then wrn "$4: $out"; else pass "$4: $out"; fi
  else
    fl "$4: $out (./scripts/configure-vscode.sh)"
  fi
}
check_block settings "$VSCODE_USER_DIR/settings.json" "$LDE_REPO_DIR/vscode/settings.json" "settings.json"
check_block keybindings "$VSCODE_USER_DIR/keybindings.json" "$LDE_REPO_DIR/vscode/keybindings.json" "keybindings.json"
python3 "$MERGE_PY" validate "$VSCODE_USER_DIR/settings.json" >/dev/null 2>&1 \
  && pass "settings.json parses as JSONC without duplicate keys" || fl "settings.json is not valid JSONC"

# Every keybinding must point at a command that exists (no dead shortcuts).
if [[ -n "$LW_DIR" ]]; then
  lw_version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$LW_DIR/package.json")
  dead=$(LDE_LIB="$LDE_REPO_DIR/scripts/lib" python3 - "$LDE_REPO_DIR/vscode/keybindings.json" "$LW_DIR/package.json" <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["LDE_LIB"])
import vscode_merge as vm
kb = vm.loads(open(sys.argv[1], encoding="utf-8").read())
pkg = json.load(open(sys.argv[2], encoding="utf-8"))
lw = {c["command"] for c in pkg["contributes"]["commands"]}
builtin = {"editor.action.formatDocument"}
for b in kb:
    cmd = b["command"].lstrip("-")
    if cmd.startswith("latex-workshop.") and cmd not in lw:
        print(cmd)
    elif not cmd.startswith("latex-workshop.") and cmd not in builtin:
        print(cmd)
PY
)
  if [[ -z "$dead" ]]; then
    pass "all keybinding commands exist in LaTeX Workshop $lw_version"
  else
    fl "unknown keybinding command(s): $(tr '\n' ' ' <<<"$dead")"
  fi
  bad_keys=$(python3 - "$LDE_REPO_DIR/vscode/settings.json" "$LW_DIR/package.json" <<'PY'
import json, re, sys
src = open(sys.argv[1], encoding="utf-8").read()
keys = set(re.findall(r'^\s*"(latex-workshop\.[^"]+)"\s*:', src, re.M))
pkg = json.load(open(sys.argv[2], encoding="utf-8"))
conf = pkg["contributes"]["configuration"]
conf = conf if isinstance(conf, list) else [conf]
known = {k for c in conf for k in c.get("properties", {})}
print(" ".join(sorted(keys - known)))
PY
)
  if [[ -z "$bad_keys" ]]; then
    pass "all latex-workshop.* setting keys are supported by LaTeX Workshop $lw_version"
  else
    fl "setting keys unknown to LaTeX Workshop $lw_version: $bad_keys"
  fi
else
  wrn "LaTeX Workshop directory not found; command IDs not verified"
fi

snip="$VSCODE_USER_DIR/snippets/latex.code-snippets"
if [[ -f "$snip" ]] && cmp -s "$snip" "$LDE_REPO_DIR/vscode/latex.code-snippets"; then
  if out=$(python3 "$LDE_REPO_DIR/tests/snippet_check.py" "$snip" 2>&1); then pass "snippets: ${out#OK    }"; else fl "snippets invalid: $out"; fi
elif [[ -f "$snip" ]]; then
  wrn "snippets installed but differ from repository copy (local edits?)"
else
  fl "snippets not installed ($snip)"
fi
for pair in "config/latexindent.yaml:$LATEXINDENT_DIR/latexindent.yaml" \
            "config/chktexrc:$CHKTEX_DIR/chktexrc" \
            "config/latexmk/include-subdirs.pl:$LDE_CONFIG_DIR/latexmk/include-subdirs.pl"; do
  src=${pair%%:*} dst=${pair#*:}
  if [[ -f "$dst" ]] && cmp -s "$LDE_REPO_DIR/$src" "$dst"; then pass "installed: ${dst/#$HOME/\~}"
  elif [[ -f "$dst" ]]; then wrn "differs from repository: ${dst/#$HOME/\~}"
  else fl "missing: ${dst/#$HOME/\~}"; fi
done
if grep -qsF "$LATEXINDENT_DIR/latexindent.yaml" "$LATEXINDENT_DIR/indentconfig.yaml"; then
  pass "latexindent indentconfig.yaml points to latexindent.yaml"
else
  wrn "latexindent indentconfig.yaml does not reference the repository settings (CLI only; VS Code unaffected)"
fi

# ---------------------------------------------------------------------------
if [[ -n "$PROJECT" ]]; then
  section "Project: $PROJECT"
  ws="$PROJECT/.vscode/settings.json"
  if [[ -f "$ws" ]]; then
    LDE_LIB="$LDE_REPO_DIR/scripts/lib" python3 - "$ws" "${LW_DIR:+$LW_DIR/package.json}" <<'PY' | while IFS='|' read -r level msg; do
import json, os, sys
sys.path.insert(0, os.environ["LDE_LIB"])
import vscode_merge as vm
ws = vm.loads(open(sys.argv[1], encoding="utf-8").read())
known = set()
if len(sys.argv) > 2 and sys.argv[2]:
    pkg = json.load(open(sys.argv[2], encoding="utf-8"))
    conf = pkg["contributes"]["configuration"]
    conf = conf if isinstance(conf, list) else [conf]
    known = {k for c in conf for k in c.get("properties", {})}
for k in ws:
    if k.startswith("latex-workshop.") and known and k not in known:
        print(f"WARN|{k} is not a LaTeX Workshop setting (obsolete name?) and is ignored")
for k in ("latex-workshop.latex.recipes", "latex-workshop.latex.tools", "latex-workshop.latex.outDir"):
    if k in ws:
        print(f"WARN|{k} is overridden by this workspace (global recipes/keys are hidden here)")
if not any(k.startswith("latex-workshop.") for k in ws):
    print("PASS|no LaTeX Workshop overrides; global configuration applies")
PY
      if [[ "$level" == PASS ]]; then pass "$msg"; else wrn "$msg"; fi
    done
  else
    pass "no .vscode/settings.json; global configuration applies"
  fi
fi

# ---------------------------------------------------------------------------
if [[ "$QUICK" == 0 ]]; then
  section "Compilation (same latexmk arguments as VS Code)"
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/lde-doctor.XXXXXX")
  if [[ "$KEEP" == 0 ]]; then trap 'rm -rf "$WORK"' EXIT; else info "work dir: $WORK"; fi
  run_tool() { # tool dir docbase -> rc ; log in $dir/latexmk.out
    local tool=$1 dir=$2 doc=$3 cmd=()
    mapfile -d '' -t cmd < <(python3 "$MERGE_PY" tool-args --source "$LDE_REPO_DIR/vscode/settings.json" \
      --tool "$tool" --subst "HOME=$HOME" --var "DOC=$dir/$doc" --var "OUTDIR=$dir/build" --var "AUXDIR=$dir/build")
    (cd "$dir" && timeout 300 "${cmd[@]}" >"$dir/latexmk.out" 2>&1)
  }
  for engine in xelatex pdflatex lualatex; do
    d="$WORK/smoke-$engine"; mkdir -p "$d"
    cp "$LDE_REPO_DIR/tests/smoke-test.tex" "$LDE_REPO_DIR/tests/references.bib" "$d/"
    if run_tool "lde-${engine}mk" "$d" smoke-test; then
      [[ -s "$d/build/smoke-test.pdf" ]] && pass "$engine: build/smoke-test.pdf created" || fl "$engine: no PDF"
      if [[ "$engine" == xelatex ]]; then
        [[ -s "$d/build/smoke-test.synctex.gz" ]] && pass "SyncTeX file generated" || fl "no .synctex.gz"
        [[ -s "$d/build/smoke-test.bbl" ]] && ! grep -q "Citation .* undefined" "$d/build/smoke-test.log" \
          && pass "bibliography: biber ran, citations resolved" || fl "bibliography not resolved"
        [[ ! -e "$d/smoke-test.aux" && -e "$d/build/smoke-test.aux" ]] \
          && pass "output directory: all artifacts in build/, source dir clean" || fl "artifacts outside build/"
        line=$(grep -n 'SYNCTEX-MARKER-LINE' "$d/smoke-test.tex" | cut -d: -f1)
        if fwd=$(synctex view -i "$line:1:$d/smoke-test.tex" -o "$d/build/smoke-test.pdf" 2>/dev/null) \
           && grep -q '^Page:1' <<<"$fwd"; then
          x=$(grep -m1 '^x:' <<<"$fwd" | cut -d: -f2); y=$(grep -m1 '^y:' <<<"$fwd" | cut -d: -f2)
          pass "SyncTeX forward search: line $line -> page 1"
          inv=$(synctex edit -o "1:$x:$y:$d/build/smoke-test.pdf" 2>/dev/null | grep -m1 '^Line:' | cut -d: -f2)
          # Inverse search maps a PDF point back to the nearest recorded source
          # position; a few lines of tolerance is normal SyncTeX behaviour.
          if [[ "$inv" =~ ^[0-9]+$ ]] && ((inv >= line - 3 && inv <= line + 1)); then
            pass "SyncTeX inverse search: page 1 -> line $inv (target $line)"
          else
            wrn "SyncTeX inverse search returned line '${inv:-none}' (expected about $line)"
          fi
        else
          fl "SyncTeX forward search failed"
        fi
      fi
    else
      fl "$engine: compilation failed (see $d/latexmk.out)"; KEEP=1
    fi
  done

  section "Templates (XeLaTeX recipe)"
  for t in article thesis technical-report; do
    d="$WORK/tpl-$t"; mkdir -p "$d"
    (cd "$LDE_REPO_DIR/templates/$t" && tar --exclude=build -cf - .) | (cd "$d" && tar -xf -)
    if run_tool lde-xelatexmk "$d" main && [[ -s "$d/build/main.pdf" ]]; then
      pages=$(pdfinfo "$d/build/main.pdf" 2>/dev/null | awk '/^Pages:/{print $2}')
      nwarn=$(grep -cE '^(LaTeX|Package [A-Za-z]+) Warning' "$d/build/main.log" || true)
      if [[ "$nwarn" == 0 ]]; then pass "$t: ${pages:-?} pages, 0 warnings"
      else wrn "$t: ${pages:-?} pages, $nwarn LaTeX warnings"; fi
    else
      fl "$t: compilation failed (see $d/latexmk.out)"; KEEP=1
    fi
  done

  section "Linting, formatting, word count"
  d="$WORK/smoke-xelatex"
  out=$(cd "$d" && chktex -wall -n22 -n30 -e16 -q -l "$CHKTEX_DIR/chktexrc" smoke-test.tex 2>&1); rc=$?
  if ((rc == 0)) && [[ -z "$out" ]]; then pass "chktex runs with chktexrc (smoke test clean)"
  elif ((rc <= 2)); then wrn "chktex runs, but reports on the smoke test: $(head -n1 <<<"$out")"
  else fl "chktex failed (exit $rc)"; fi
  printf '\\section{A}\n\\begin{itemize}\n\\item x\n\\end{itemize}\n' >"$d/indent-in.tex"
  mkdir -p "$d/li"
  if latexindent -c "$d/li/" "$d/indent-in.tex" >"$d/indent-out.tex" 2>/dev/null \
     && grep -q '^  \\item x' "$d/indent-out.tex" \
     && [[ "$(tr -d ' \n' <"$d/indent-in.tex")" == "$(tr -d ' \n' <"$d/indent-out.tex")" ]]; then
    pass "latexindent formats (indent applied, content preserved, user config loaded)"
  else
    fl "latexindent formatting test failed"
  fi
  if have texcount; then
    w=$(cd "$d" && texcount -utf8 -merge -sum -1 smoke-test.tex 2>/dev/null | head -n1)
    [[ "$w" =~ ^[0-9]+ ]] && pass "texcount: $w words in smoke test" || wrn "texcount produced no count"
  fi
fi

# ---------------------------------------------------------------------------
printf '\n%sSummary:%s %s%d PASS%s, %s%d WARN%s, %s%d FAIL%s\n' "$_c_blu" "$_c_off" \
  "$_c_grn" "$N_PASS" "$_c_off" "$_c_yel" "$N_WARN" "$_c_off" "$_c_red" "$N_FAIL" "$_c_off"
if [[ "${KEEP}" == 1 && -n "${WORK:-}" ]]; then trap - EXIT; info "build files kept in $WORK"; fi
((N_FAIL == 0))
