#!/usr/bin/env bash
# latex-dev-environment — main entry point for Ubuntu.
#
#   ./scripts/install-ubuntu.sh [options]
#
# Steps
#   1. detect Ubuntu release and CPU architecture
#   2. install MISSING Ubuntu packages only (TeX Live subset, latexmk, biber,
#      chktex, fonts, ...) with apt — asks before using sudo
#   3. VS Code: verify it is installed (optionally install it from
#      Microsoft's official APT repository) and add the missing extensions
#   4. merge VS Code settings/keybindings/snippets and tool configuration
#   5. run ./scripts/doctor.sh
#
# Options
#   -y, --yes          do not ask for confirmation (apt, VS Code repository)
#   -n, --dry-run      show what would happen, change nothing
#   --skip-packages    do not check/install Ubuntu packages
#   --skip-vscode      do not touch VS Code or its extensions
#   --install-vscode   if VS Code is missing, install it from Microsoft's repo
#   --no-doctor        skip the final verification
#   -h, --help         show this help
#
# Never removes packages, never resets VS Code, never edits files outside
# $HOME except through apt. Safe to run repeatedly.
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR
refuse_sudo_invocation

ASSUME_YES=0 DRY_RUN=0 SKIP_PKGS=0 SKIP_VSCODE=0 INSTALL_VSCODE=0 RUN_DOCTOR=1
while (($#)); do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    --skip-packages) SKIP_PKGS=1 ;;
    --skip-vscode) SKIP_VSCODE=1 ;;
    --install-vscode) INSTALL_VSCODE=1 ;;
    --no-doctor) RUN_DOCTOR=0 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done
export ASSUME_YES DRY_RUN

# Ubuntu packages and the reason each is needed. Kept deliberately smaller
# than texlive-full (~6 GB): this set covers all templates and recipes.
PACKAGES=(
  texlive-base              # TeX Live core
  texlive-latex-base        # pdflatex
  texlive-latex-recommended # common packages (listings, csquotes, ...)
  texlive-latex-extra       # cleveref, acronym, algorithm, mwe, ...
  texlive-xetex             # xelatex + polyglossia/fontspec
  texlive-luatex            # lualatex
  texlive-bibtex-extra      # biblatex (+ styles)
  texlive-lang-european     # Turkish hyphenation and babel/polyglossia support
  texlive-pictures          # TikZ
  texlive-science           # siunitx, algorithmicx
  texlive-fonts-recommended # standard fonts
  texlive-extra-utils       # latexindent, texcount
  latexmk                   # build driver
  biber                     # biblatex backend
  chktex                    # linter
  fonts-lmodern             # Latin Modern Math (unicode-math)
  fonts-texgyre             # TeX Gyre Heros (fallback when Aptos is missing)
  fonts-dejavu-core         # DejaVu Sans Mono (code listings)
  fontconfig                # fc-list / font discovery for XeLaTeX
  poppler-utils             # pdfinfo/pdftotext used by doctor.sh
  python3                   # JSONC-aware VS Code settings merge
)
REQUIRED_COMMANDS=(pdflatex xelatex lualatex latexmk biber chktex latexindent texcount kpsewhich synctex fc-list python3 perl)

# ---------------------------------------------------------------------------
step "System"
[[ -r /etc/os-release ]] || die "/etc/os-release not found: not a supported Linux system"
id=$(os_id) ver=$(os_version) like=$(os_like)
info "OS:           $(os_pretty)"
info "Architecture: $(arch)"
if [[ "$id" != ubuntu ]]; then
  if [[ " $like " == *" ubuntu "* || " $like " == *" debian "* ]]; then
    warn "$id is not Ubuntu but Debian/Ubuntu based; continuing (untested)"
  else
    die "unsupported distribution '$id' (Ubuntu required)"
  fi
fi
case "$ver" in
  26.04|25.10|24.04) ok "Ubuntu $ver is supported" ;;
  *) warn "Ubuntu $ver is untested (tested: 26.04; expected to work: 24.04+)" ;;
esac
case "$(arch)" in
  amd64|arm64) ok "architecture $(arch) is supported" ;;
  *) warn "architecture $(arch) is untested" ;;
esac
have dpkg-query || die "dpkg-query not found"

# ---------------------------------------------------------------------------
if [[ "$SKIP_PKGS" == 0 ]]; then
  step "Ubuntu packages"
  missing=()
  for p in "${PACKAGES[@]}"; do
    if pkg_installed "$p"; then dim "installed: $p"; else missing+=("$p"); fi
  done
  if ((${#missing[@]} == 0)); then
    ok "all ${#PACKAGES[@]} packages are already installed"
  else
    info "missing: ${missing[*]}"
    if [[ "$DRY_RUN" == 1 ]]; then
      info "would run: ${SUDO[*]:+${SUDO[*]} }apt-get install --no-install-recommends ${missing[*]}"
    elif ask "Install ${#missing[@]} missing package(s) with apt-get${SUDO[*]:+ (via sudo)}?"; then
      have sudo || ((${#SUDO[@]} == 0)) || die "sudo not found; run as root or install sudo"
      "${SUDO[@]}" apt-get update
      "${SUDO[@]}" apt-get install -y --no-install-recommends "${missing[@]}"
      ok "packages installed"
    else
      warn "skipped package installation; missing tools will be reported by doctor.sh"
    fi
  fi
  for c in "${REQUIRED_COMMANDS[@]}"; do
    have "$c" || warn "command not found: $c"
  done
fi

# ---------------------------------------------------------------------------
if [[ "$SKIP_VSCODE" == 0 ]]; then
  vs_args=()
  [[ "$INSTALL_VSCODE" == 1 ]] && vs_args+=(--install-code)
  "$LDE_REPO_DIR/scripts/install-vscode.sh" "${vs_args[@]}"
  cfg_args=()
  [[ "$DRY_RUN" == 1 ]] && cfg_args+=(--dry-run)
  "$LDE_REPO_DIR/scripts/configure-vscode.sh" "${cfg_args[@]}"
fi

# ---------------------------------------------------------------------------
if [[ "$RUN_DOCTOR" == 1 && "$DRY_RUN" == 0 ]]; then
  "$LDE_REPO_DIR/scripts/doctor.sh" || warn "doctor.sh reported problems (see above)"
fi
step "Finished"
