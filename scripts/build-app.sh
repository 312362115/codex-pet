#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/CodexPetCompanion.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
CACHE_DIR="$ROOT/.clang-cache"

mkdir -p "$BIN_DIR" "$APP_DIR/Contents/Resources" "$CACHE_DIR"

if [ -d "$ROOT/assets/lingxi-ol-rig" ]; then
  "$ROOT/scripts/validate-rig-assets.py"
fi

copy_resource_dir() {
  local source_dir="$1"
  local target_dir="$2"
  mkdir -p "$target_dir"
  rsync -a \
    --delete \
    --delete-excluded \
    --exclude '.DS_Store' \
    --exclude '._*' \
    "$source_dir"/ "$target_dir"/
}

swiftc \
  -module-cache-path "$CACHE_DIR" \
  -Xcc -fmodules-cache-path="$CACHE_DIR" \
  -framework AppKit \
  -framework SpriteKit \
  "$ROOT/Sources/PetCompanion/CodexActivityStatus.swift" \
  "$ROOT/Sources/CodexPetCompanion/main.swift" \
  -o "$BIN_DIR/CodexPetCompanion"

/usr/libexec/PlistBuddy -c "Clear dict" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string CodexPetCompanion" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.renlongyu.codex-pet-companion" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string CodexPetCompanion" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 0.1.0" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$APP_DIR/Contents/Info.plist"

copy_resource_dir "$ROOT/assets/lingxi-ol-hires" "$APP_DIR/Contents/Resources/lingxi-ol-hires"
copy_resource_dir "$ROOT/assets/lingxi-ol" "$APP_DIR/Contents/Resources/lingxi-ol"
if [ -d "$ROOT/assets/lingxi-ol-rig" ]; then
  copy_resource_dir "$ROOT/assets/lingxi-ol-rig" "$APP_DIR/Contents/Resources/lingxi-ol-rig"
fi

chmod +x "$BIN_DIR/CodexPetCompanion"
echo "$APP_DIR"
