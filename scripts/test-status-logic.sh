#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
CACHE_DIR="$ROOT/.clang-cache"

mkdir -p "$BUILD_DIR" "$CACHE_DIR"

swiftc \
  -module-cache-path "$CACHE_DIR" \
  -Xcc -fmodules-cache-path="$CACHE_DIR" \
  "$ROOT/Sources/PetCompanion/CodexActivityStatus.swift" \
  "$ROOT/Tests/PetCompanionStatusTestRunner.swift" \
  -o "$BUILD_DIR/status-tests"

"$BUILD_DIR/status-tests"
"$ROOT/scripts/validate-rig-assets.py"
"$ROOT/scripts/validate-maneki-neko-assets.py"
"$ROOT/scripts/validate-codex-native-pet.py" "$ROOT/assets/lingxi-ol"
"$ROOT/scripts/validate-codex-native-pet.py" "$ROOT/assets/maneki-neko"
