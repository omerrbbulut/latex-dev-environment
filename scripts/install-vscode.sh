#!/usr/bin/env bash
# latex-dev-environment — VS Code and extension installer.
#
#   ./scripts/install-vscode.sh [--install-code] [--dry-run] [--yes]
#
# * Checks that VS Code ("code") is installed. With --install-code and if it
#   is missing, adds Microsoft's official APT repository (signing key
#   fingerprint verified) and installs the "code" package.
# * Installs the extensions listed in vscode/extensions.txt that are not yet
#   installed. Already installed extensions (themes, C++, Python, Qt, ...)
#   are never modified or removed.
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR
refuse_sudo_invocation

INSTALL_CODE=0
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
for arg in "$@"; do
  case "$arg" in
    --install-code) INSTALL_CODE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done
export ASSUME_YES

# Microsoft's package signing key (packages.microsoft.com).
MS_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
MS_KEY_FPR="BC528686B50D79E339D3721CEB3E94ADBE1229CF"

install_code_from_microsoft() {
  have curl || die "curl is required to fetch Microsoft's signing key (sudo apt install curl)"
  have gpg || die "gpg is required (sudo apt install gpg)"
  local tmp; tmp=$(mktemp -d)
  curl -fsSL "$MS_KEY_URL" -o "$tmp/microsoft.asc"
  gpg --dearmor <"$tmp/microsoft.asc" >"$tmp/microsoft.gpg"
  local fpr
  fpr=$(gpg --show-keys --with-colons "$tmp/microsoft.gpg" 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')
  [[ "$fpr" == "$MS_KEY_FPR" ]] || die "unexpected Microsoft key fingerprint: $fpr"
  ok "Microsoft signing key fingerprint verified ($fpr)"
  "${SUDO[@]}" install -D -o root -g root -m 644 "$tmp/microsoft.gpg" /usr/share/keyrings/microsoft.gpg
  printf '%s\n' \
    "Types: deb" \
    "URIs: https://packages.microsoft.com/repos/code" \
    "Suites: stable" \
    "Components: main" \
    "Architectures: $(arch)" \
    "Signed-By: /usr/share/keyrings/microsoft.gpg" | "${SUDO[@]}" tee /etc/apt/sources.list.d/vscode.sources >/dev/null
  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" apt-get install -y code
  rm -rf "$tmp"
}

step "Visual Studio Code"
if CODE=$(code_bin); then
  ok "found $CODE $("$CODE" --version 2>/dev/null | head -n1)"
else
  if [[ "$INSTALL_CODE" == 1 ]]; then
    if [[ "$DRY_RUN" == 1 ]]; then
      info "would add Microsoft's APT repository and install the 'code' package"
      exit 0
    fi
    ask "VS Code is not installed. Add Microsoft's official APT repository and install it?" \
      || die "VS Code is required for the editor integration"
    install_code_from_microsoft
    CODE=$(code_bin) || die "VS Code installation failed"
  else
    warn "VS Code is not installed. Re-run with --install-code, or install it from"
    warn "https://code.visualstudio.com/docs/setup/linux (official .deb / APT repository)."
    exit 0
  fi
fi

step "Extensions"
mapfile -t installed < <("$CODE" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
while IFS= read -r ext; do
  ext=${ext%%#*}; ext=${ext//[[:space:]]/}
  [[ -n "$ext" ]] || continue
  if printf '%s\n' "${installed[@]}" | grep -qx "${ext,,}"; then
    ok "already installed: $ext"
  elif [[ "$DRY_RUN" == 1 ]]; then
    info "would install: $ext"
  else
    "$CODE" --install-extension "$ext" >/dev/null
    ok "installed: $ext"
  fi
done <"$LDE_REPO_DIR/vscode/extensions.txt"
