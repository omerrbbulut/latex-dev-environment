#!/usr/bin/env bash
# latex-dev-environment — clean-system installation test in a container.
#
#   ./tests/container-test.sh [--image IMAGE] [--engine docker|podman] [--shell] [--keep]
#
# Starts a pristine Ubuntu container (default ubuntu:26.04), copies this
# repository into it and runs, from zero:
#   1. install-ubuntu.sh --yes --skip-vscode  (apt: installs every package)
#   2. install-ubuntu.sh again                (must report: nothing to install)
#   3. configure-vscode.sh twice              (second run must be a no-op)
#   4. doctor.sh --no-vscode                  (must have 0 FAIL)
#   5. tests/run-tests.sh                     (full repository test suite)
# VS Code itself is not tested here (no GUI); see docs/TROUBLESHOOTING.md for
# the separate fresh-HOME GUI test.
#
# Options
#   --image IMAGE    base image, e.g. ubuntu:24.04 (default: ubuntu:26.04)
#   --engine NAME    docker or podman (default: whichever is installed)
#   --shell          open an interactive shell in the container afterwards
#   --keep           do not remove the container when done
#
# Your host is not modified: the repository is mounted read-only and copied
# inside the container. Needs network access (image pull + apt).
# Requires Docker (sudo apt install docker.io; sudo usermod -aG docker $USER;
# then log out/in) or Podman (sudo apt install podman, rootless).
set -Eeuo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMAGE=ubuntu:26.04 ENGINE="" SHELL_AFTER=0 KEEP=0
while (($#)); do
  case "$1" in
    --image) IMAGE=${2:?--image needs a value}; shift ;;
    --engine) ENGINE=${2:?--engine needs a value}; shift ;;
    --shell) SHELL_AFTER=1 ;;
    --keep) KEEP=1 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -z "$ENGINE" ]]; then
  for e in docker podman; do command -v "$e" >/dev/null && { ENGINE=$e; break; }; done
fi
[[ -n "$ENGINE" ]] || { echo "Neither docker nor podman found. Install one:
  sudo apt install docker.io && sudo usermod -aG docker \$USER   # then log out/in
  sudo apt install podman                                       # rootless alternative" >&2; exit 1; }
if ! "$ENGINE" info >/dev/null 2>&1; then
  echo "'$ENGINE info' failed. For Docker: is the daemon running and are you in the" >&2
  echo "'docker' group? (sudo usermod -aG docker \$USER, then log out and back in)" >&2
  exit 1
fi

NAME="lde-test-$(date +%Y%m%d-%H%M%S)"
echo "==> $ENGINE: $IMAGE  (container $NAME)"
"$ENGINE" pull "$IMAGE"

# The test script that runs inside the container.
read -r -d '' INNER <<'EOS' || true
set -Euo pipefail
export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC NO_COLOR=1
FAILS=0
check() { if "$@"; then echo "  [ok]   $DESC"; else echo "  [FAIL] $DESC"; FAILS=$((FAILS + 1)); fi; }
cp -a /src /work && cd /work
. /etc/os-release; echo "==> container OS: $PRETTY_NAME ($(dpkg --print-architecture))"

echo; echo "==> 1. install-ubuntu.sh on a clean system"
DESC="first install exits 0"; check ./scripts/install-ubuntu.sh --yes --skip-vscode --no-doctor

echo; echo "==> 2. install-ubuntu.sh again"
./scripts/install-ubuntu.sh --yes --skip-vscode --no-doctor >/tmp/second.log 2>&1
DESC="second install: all packages already installed"; check grep -q 'packages are already installed' /tmp/second.log
DESC="second install: no 'command not found' warnings"; check bash -c '! grep -q "command not found" /tmp/second.log'

echo; echo "==> 3. configure-vscode.sh (no VS Code needed)"
DESC="configure first run"; check ./scripts/configure-vscode.sh
./scripts/configure-vscode.sh >/tmp/cfg2.log 2>&1
DESC="configure second run is a no-op"; check bash -c '! grep -qE "installed:|updated|created" /tmp/cfg2.log'

echo; echo "==> 4. doctor.sh --no-vscode"
DESC="doctor reports 0 FAIL"; check ./scripts/doctor.sh --no-vscode

echo; echo "==> 5. tests/run-tests.sh"
DESC="repository test suite"; check ./tests/run-tests.sh

echo
if ((FAILS == 0)); then echo "CONTAINER TEST PASSED"; else echo "CONTAINER TEST FAILED ($FAILS)"; fi
exit "$FAILS"
EOS

run_args=(run --name "$NAME" -v "$REPO:/src:ro" -e "TERM=${TERM:-xterm}")
[[ "$ENGINE" == podman ]] && run_args+=(--security-opt label=disable)
set +e
"$ENGINE" "${run_args[@]}" "$IMAGE" bash -c "$INNER"
rc=$?
set -e

if [[ "$SHELL_AFTER" == 1 ]]; then
  echo "==> interactive shell (repository copy in /work); exit to finish"
  "$ENGINE" commit "$NAME" "$NAME:debug" >/dev/null
  "$ENGINE" run --rm -it "$NAME:debug" bash -c 'cd /work; exec bash'
  "$ENGINE" rmi "$NAME:debug" >/dev/null
fi
if [[ "$KEEP" == 0 ]]; then "$ENGINE" rm "$NAME" >/dev/null; else echo "container kept: $NAME"; fi
echo "==> exit status $rc"
exit "$rc"
