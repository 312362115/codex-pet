#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_APP="$ROOT/build/CodexPetCompanion.app"
INSTALL_DIR="${CODEX_PET_INSTALL_DIR:-$HOME/.codex/pet-companion}"
INSTALLED_APP="$INSTALL_DIR/CodexPetCompanion.app"

run_tests=1
restart_app=1
rebuild_assets=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/install.sh [options]

Build, sign, install, and restart CodexPetCompanion.app.

Options:
  --skip-tests      Do not run status logic tests before building.
  --no-restart      Install the app but do not stop/start the running pet.
  --rebuild-assets  Rebuild runtime PNG frames before building the app.
  -h, --help        Show this help.

Environment:
  CODEX_PET_INSTALL_DIR  Override install directory. Default: ~/.codex/pet-companion
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-tests)
      run_tests=0
      ;;
    --no-restart)
      restart_app=0
      ;;
    --rebuild-assets)
      rebuild_assets=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

echo "==> Codex Pet install root: $ROOT"

if [ "$rebuild_assets" -eq 1 ]; then
  echo "==> Rebuilding runtime assets"
  "$ROOT/scripts/build-shirt-skirt-assets.py"
fi

if [ "$run_tests" -eq 1 ]; then
  echo "==> Running status logic tests"
  "$ROOT/scripts/test-status-logic.sh"
fi

echo "==> Building app"
"$ROOT/scripts/build-app.sh" >/dev/null

echo "==> Signing app"
codesign --force --deep --sign - "$BUILD_APP"
codesign --verify --deep --strict "$BUILD_APP"

echo "==> Installing to $INSTALLED_APP"
mkdir -p "$INSTALL_DIR"
ditto "$BUILD_APP" "$INSTALLED_APP"

if [ "$restart_app" -eq 1 ]; then
  echo "==> Restarting CodexPetCompanion"
  pids="$(ps -axo pid=,command= | awk '/CodexPetCompanion.app\/Contents\/MacOS\/CodexPetCompanion/ { print $1 }' || true)"
  if [ -n "$pids" ]; then
    # shellcheck disable=SC2086
    kill $pids || true
    sleep 0.5
  fi
  open "$INSTALLED_APP"
else
  echo "==> Installed. Restart skipped."
fi

echo "==> Done"
