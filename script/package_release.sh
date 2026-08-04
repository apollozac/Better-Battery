#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BetterBattery"
DISPLAY_NAME="Better Battery"
BUNDLE_ID="com.local.BatteryBar"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/outputs"
STAGING_DIR="/private/tmp/com.local.BetterBattery-release-package"
APP_BUNDLE="$STAGING_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
OUTPUT_ZIP="$OUTPUT_DIR/$DISPLAY_NAME.zip"
SIGN_IDENTITY="${BETTER_BATTERY_SIGN_IDENTITY:-Developer ID Application: zac hall (XWKP9KZ69G)}"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app ]]; then
    export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFT_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export XDG_CACHE_HOME="$ROOT_DIR/.build/cache"

cd "$ROOT_DIR"
swift build --disable-sandbox -c release
BUILD_BINARY="$(swift build --disable-sandbox -c release --show-bin-path)/$APP_NAME"

rm -rf "$STAGING_DIR"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_MACOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
"$ROOT_DIR/script/compile_app_icon.sh" "$APP_RESOURCES" "$BUNDLE_ID"
chmod +x "$APP_MACOS/$APP_NAME"
codesign \
    --force \
    --sign "$SIGN_IDENTITY" \
    --options runtime \
    --timestamp=none \
    "$APP_BUNDLE" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"

rm -f "$OUTPUT_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$OUTPUT_ZIP"

echo "$OUTPUT_ZIP"
