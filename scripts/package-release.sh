#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_APP="$ROOT/build/CodexPetCompanion.app"
DIST_DIR="$ROOT/dist"
PLATFORM="macos-arm64"
PACKAGE_NAME="CodexPetCompanion-$PLATFORM"

VERSION=""
run_tests=1
rebuild_assets=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/package-release.sh [options]

Build a precompiled macOS release zip for GitHub Releases.

Options:
  --version VERSION  Release version, for example 2026.5.1 or v2026.5.1.
  --skip-tests       Do not run status logic tests before packaging.
  --rebuild-assets   Rebuild runtime PNG frames before packaging.
  -h, --help         Show this help.

Output:
  dist/CodexPetCompanion-macos-arm64-<version>.zip
  dist/SHA256SUMS.txt
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      if [ "$#" -lt 2 ]; then
        echo "--version requires a value" >&2
        exit 2
      fi
      VERSION="$2"
      shift
      ;;
    --skip-tests)
      run_tests=0
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

if [ -z "$VERSION" ]; then
  if git -C "$ROOT" describe --tags --exact-match >/dev/null 2>&1; then
    VERSION="$(git -C "$ROOT" describe --tags --exact-match)"
  else
    VERSION="dev-$(date +%Y%m%d-%H%M%S)"
  fi
fi

VERSION="${VERSION#v}"
PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME"
VERSIONED_ZIP="$DIST_DIR/$PACKAGE_NAME-$VERSION.zip"
LEGACY_UNVERSIONED_ZIP="$DIST_DIR/$PACKAGE_NAME.zip"

echo "==> Packaging CodexPetCompanion $VERSION for $PLATFORM"

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

echo "==> Preparing package directory"
rm -rf "$PACKAGE_DIR" "$VERSIONED_ZIP" "$LEGACY_UNVERSIONED_ZIP"
mkdir -p "$PACKAGE_DIR"
ditto "$BUILD_APP" "$PACKAGE_DIR/CodexPetCompanion.app"

cat > "$PACKAGE_DIR/install-release.sh" <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/CodexPetCompanion.app"
INSTALL_DIR="${CODEX_PET_INSTALL_DIR:-$HOME/.codex/pet-companion}"
INSTALLED_APP="$INSTALL_DIR/CodexPetCompanion.app"
restart_app=1

usage() {
  cat <<'USAGE'
Usage: ./install-release.sh [options]

Install the prebuilt CodexPetCompanion.app from this release package.

Options:
  --no-restart  Install the app but do not stop/start the running pet.
  -h, --help    Show this help.

Environment:
  CODEX_PET_INSTALL_DIR  Override install directory. Default: ~/.codex/pet-companion
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-restart)
      restart_app=0
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

if [ ! -d "$APP_SOURCE" ]; then
  echo "Cannot find $APP_SOURCE. Run this script from the extracted release folder." >&2
  exit 1
fi

echo "==> Installing to $INSTALLED_APP"
mkdir -p "$INSTALL_DIR"
ditto "$APP_SOURCE" "$INSTALLED_APP"

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
INSTALLER
chmod +x "$PACKAGE_DIR/install-release.sh"

cat > "$PACKAGE_DIR/README.txt" <<README
Codex Pet Companion $VERSION ($PLATFORM)

Install:
  ./install-release.sh

Custom install directory:
  CODEX_PET_INSTALL_DIR="\$HOME/.codex/pet-companion-dev" ./install-release.sh

This release package contains a prebuilt CodexPetCompanion.app. It does not
require cloning the source repository or compiling Swift locally.
README

echo "==> Creating zip archives"
ditto -c -k --norsrc --keepParent "$PACKAGE_DIR" "$VERSIONED_ZIP"

echo "==> Writing checksums"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$VERSIONED_ZIP")" > SHA256SUMS.txt
)

echo "==> Release artifacts"
echo "    $VERSIONED_ZIP"
echo "    $DIST_DIR/SHA256SUMS.txt"
