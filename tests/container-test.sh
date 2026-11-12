#!/usr/bin/env bash
# latex-dev-environment — clean-system installation test in a container.
#
#   ./tests/container-test.sh [--mode user|root|both] [--image IMAGE]
#                             [--engine docker|podman] [--shell] [--keep]
#
# Starts a pristine Ubuntu container (default ubuntu:26.04), copies this
# repository into it and runs, from zero:
#   1. install-ubuntu.sh --yes --skip-vscode  (apt: installs every package)
#   2. install-ubuntu.sh again                (must report: nothing to install)
#   3. configure-vscode.sh twice              (second run must be a no-op)
#   4. doctor.sh --no-vscode                  (must have 0 FAIL)
#   5. tests/run-tests.sh                     (full repository test suite)
#
# Modes
#   user (default)  like a real desktop: a normal user "tester" with sudo runs
#                   the installer; apt goes through sudo. Extra checks: no
#                   root-owned files in the user's home, and
#                   `sudo ./scripts/install-ubuntu.sh` is refused.
#   root            run everything as root (containers / CI; no sudo at all)
#   both            run both modes, each in its own fresh container
#
# Options
#   --image IMAGE    base image (default: docker.io/library/ubuntu:26.04)
#   --engine NAME    docker or podman (default: whichever is installed)
#   --shell          open an interactive shell in the container afterwards
#   --keep           do not remove the container when done
#
# The host is not modified: the repository is mounted read-only and copied
# inside the container. Needs network access (image pull + apt).
# VS Code itself is not tested here (no GUI); see docs/INSTALLATION.md
# ("Temiz sistemde test") for the fresh-HOME GUI test.
set -Eeuo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMAGE=docker.io/library/ubuntu:26.04 ENGINE="" SHELL_AFTER=0 KEEP=0 MODE=user
while (($#)); do
  case "$1" in
    --mode) MODE=${2:?--mode needs user, root or both}; shift ;;
    --image) IMAGE=${2:?--image needs a value}; shift ;;
    --engine) ENGINE=${2:?--engine needs a value}; shift ;;
    --shell) SHELL_AFTER=1 ;;
    --keep) KEEP=1 ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$MODE" in user|root|both) ;; *) echo "--mode must be user, root or both" >&2; exit 2 ;; esac

if [[ -z "$ENGINE" ]]; then
  for e in docker podman; do command -v "$e" >/dev/null && { ENGINE=$e; break; }; done
fi
[[ -n "$ENGINE" ]] || { echo "Neither docker nor podman found. Install one:
  sudo apt install podman                                       # rootless, recommended
  sudo apt install docker.io && sudo usermod -aG docker \$USER   # then log out/in" >&2; exit 1; }
if ! "$ENGINE" info >/dev/null 2>&1; then
  echo "'$ENGINE info' failed. For Docker: is the daemon running and are you in the" >&2
  echo "'docker' group? (sudo usermod -aG docker \$USER, then log out and back in)" >&2
  exit 1
fi

# --- Test steps, executed as the target user inside the container ----------
read -r -d '' STEPS <<'EOS' || true
set -Euo pipefail
export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC NO_COLOR=1
FAILS=0
check() { if "$@"; then echo "  [ok]   $DESC"; else echo "  [FAIL] $DESC"; FAILS=$((FAILS + 1)); fi; }
cd "$WORKDIR"
. /etc/os-release
echo "==> container OS: $PRETTY_NAME ($(dpkg --print-architecture)), user: $(id -un) (uid $(id -u)), mode: $MODE"

echo; echo "==> 1. install-ubuntu.sh on a clean system"
DESC="first install exits 0"; check ./scripts/install-ubuntu.sh --yes --skip-vscode --no-doctor
DESC="TeX Live really installed (xelatex, latexmk, biber present)"; check bash -c 'command -v xelatex >/dev/null && command -v latexmk >/dev/null && command -v biber >/dev/null'

echo; echo "==> 2. install-ubuntu.sh again"
./scripts/install-ubuntu.sh --yes --skip-vscode --no-doctor >/tmp/second.log 2>&1
DESC="second install: all packages already installed"; check grep -q 'packages are already installed' /tmp/second.log
DESC="second install: no 'command not found' warnings"; check bash -c '! grep -q "command not found" /tmp/second.log'

echo; echo "==> 3. configure-vscode.sh (no VS Code needed)"
DESC="configure first run"; check ./scripts/configure-vscode.sh
./scripts/configure-vscode.sh >/tmp/cfg2.log 2>&1
DESC="configure second run is a no-op"; check bash -c '! grep -qE "installed:|updated|created" /tmp/cfg2.log'

if [[ "$MODE" == user ]]; then
  echo; echo "==> user-mode checks"
  DESC="no root-owned files in $HOME"; check bash -c '[[ -z "$(find "$HOME" -user root -print -quit)" ]]'
  DESC="config files owned by $(id -un)"; check bash -c '[[ -O "$HOME/.config/Code/User/settings.json" && -O "$HOME/.config/chktex/chktexrc" ]]'
  sudo ./scripts/install-ubuntu.sh --yes --skip-packages --no-doctor >/tmp/sudo.log 2>&1
  DESC="'sudo ./scripts/install-ubuntu.sh' is refused"; check bash -c '! sudo ./scripts/install-ubuntu.sh --yes --skip-packages --no-doctor >/dev/null 2>&1'
  DESC="refusal explains how to run it"; check grep -q 'do not run install-ubuntu.sh with sudo' /tmp/sudo.log
  DESC="refusal did not create anything in /root"; check sudo bash -c '[[ ! -e /root/.config/Code && ! -e /root/.config/chktex ]]'
fi

echo; echo "==> 4. doctor.sh --no-vscode"
DESC="doctor reports 0 FAIL"; check ./scripts/doctor.sh --no-vscode

echo; echo "==> 5. tests/run-tests.sh"
DESC="repository test suite"; check ./tests/run-tests.sh

echo
if ((FAILS == 0)); then echo "CONTAINER TEST PASSED ($MODE mode)"; else echo "CONTAINER TEST FAILED ($MODE mode, $FAILS)"; fi
exit "$FAILS"
EOS

# --- Root-side setup, then hand over to the target user ----------------------
read -r -d '' ENTRY <<'EOS' || true
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
if [[ "$MODE" == user ]]; then
  # A desktop Ubuntu ships sudo and a normal user; recreate exactly that.
  apt-get update -qq && apt-get install -y -qq sudo >/dev/null
  useradd -m -s /bin/bash tester
  # NOPASSWD only because nobody can type a password here; a real run asks.
  printf 'tester ALL=(ALL) NOPASSWD:ALL\nDefaults env_keep += "DEBIAN_FRONTEND"\n' >/etc/sudoers.d/tester
  chmod 440 /etc/sudoers.d/tester
  cp -a /src /home/tester/work && chown -R tester:tester /home/tester/work
  exec sudo -u tester -H env MODE=user WORKDIR=/home/tester/work bash -c "$STEPS"
else
  cp -a /src /work
  exec env MODE=root WORKDIR=/work bash -c "$STEPS"
fi
EOS

"$ENGINE" pull -q "$IMAGE" >/dev/null
run_one() { # mode
  local mode=$1 name rc
  name="lde-test-$mode-$(date +%Y%m%d-%H%M%S)"
  echo "==> $ENGINE: $IMAGE  (container $name, $mode mode)"
  local args=(run --name "$name" -v "$REPO:/src:ro" -e "MODE=$mode" -e "STEPS=$STEPS" -e "TERM=${TERM:-xterm}")
  [[ "$ENGINE" == podman ]] && args+=(--security-opt label=disable)
  set +e
  "$ENGINE" "${args[@]}" "$IMAGE" bash -c "$ENTRY"
  rc=$?
  set -e
  if [[ "$SHELL_AFTER" == 1 ]]; then
    echo "==> interactive shell (exit to finish)"
    "$ENGINE" commit "$name" "$name:debug" >/dev/null
    "$ENGINE" run --rm -it "$name:debug" bash
    "$ENGINE" rmi "$name:debug" >/dev/null
  fi
  if [[ "$KEEP" == 0 ]]; then "$ENGINE" rm "$name" >/dev/null; else echo "container kept: $name"; fi
  echo "==> $mode mode: exit status $rc"
  return "$rc"
}

overall=0
if [[ "$MODE" == both ]]; then
  run_one user || overall=1
  run_one root || overall=1
else
  run_one "$MODE" || overall=1
fi
exit "$overall"
