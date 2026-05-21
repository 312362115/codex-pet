#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
PET_IDS=("lingxi-ol" "maneki-neko")
rebuild_assets=0
run_tests=1

usage() {
  cat <<'USAGE'
Usage: ./scripts/install-codex-native-pet.sh [options]

Install Codex native pet packages.

Options:
  --rebuild-assets  Rebuild Lingxi OL and Maneki Neko assets first.
  --skip-tests      Do not run native package validation before installing.
  -h, --help        Show this help.

Environment:
  CODEX_HOME  Override Codex home directory. Default: ~/.codex
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --rebuild-assets)
      rebuild_assets=1
      ;;
    --skip-tests)
      run_tests=0
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

echo "==> Codex native pet root: $ROOT"

if [ "$rebuild_assets" -eq 1 ]; then
  echo "==> Rebuilding native pet assets"
  "$ROOT/scripts/build-shirt-skirt-assets.py"
  "$ROOT/scripts/build-maneki-neko-assets.py"
fi

if [ "$run_tests" -eq 1 ]; then
  echo "==> Validating source native pet packages"
  for pet_id in "${PET_IDS[@]}"; do
    "$ROOT/scripts/validate-codex-native-pet.py" "$ROOT/assets/$pet_id"
  done
fi

for pet_id in "${PET_IDS[@]}"; do
  source_dir="$ROOT/assets/$pet_id"
  target_dir="$CODEX_HOME_DIR/pets/$pet_id"

  echo "==> Installing Codex native pet to $target_dir"
  mkdir -p "$(dirname "$target_dir")"
  rm -rf "$target_dir"
  ditto "$source_dir" "$target_dir"

  echo "==> Validating installed native pet package"
  "$ROOT/scripts/validate-codex-native-pet.py" "$target_dir"
done

echo "==> Codex will load these as custom:<directory-name> from $CODEX_HOME_DIR/pets"
echo "==> If Codex is already running, restart Codex or click Refresh in Settings > Pets."
echo "==> Done"
