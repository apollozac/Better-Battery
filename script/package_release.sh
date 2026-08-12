#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BetterBattery"
DISPLAY_NAME="Better Battery"
BUNDLE_ID="com.local.BatteryBar"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/outputs"
STAGING_DIR="/private/tmp/com.local.BetterBattery-release-package"
SCRATCH_DIR="/private/tmp/com.local.BetterBattery-release-build"
APP_BUNDLE="$STAGING_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
OUTPUT_ZIP="$OUTPUT_DIR/Better-Battery.zip"
SIGN_IDENTITY="${BETTER_BATTERY_SIGN_IDENTITY:-Developer ID Application: zac hall (XWKP9KZ69G)}"
NOTARY_PROFILE="${BETTER_BATTERY_NOTARY_PROFILE:-${NOTARY_PROFILE:-}}"
SKIP_NOTARIZATION="${BETTER_BATTERY_SKIP_NOTARIZATION:-0}"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app ]]; then
    export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi
export CLANG_MODULE_CACHE_PATH="/private/tmp/com.local.BetterBattery-module-cache"
export SWIFT_MODULE_CACHE_PATH="/private/tmp/com.local.BetterBattery-module-cache"
export XDG_CACHE_HOME="/private/tmp/com.local.BetterBattery-cache"

cd "$ROOT_DIR"

if [[ -z "$NOTARY_PROFILE" && "$SKIP_NOTARIZATION" != "1" ]]; then
    echo "Set BETTER_BATTERY_NOTARY_PROFILE to a notarytool Keychain profile." >&2
    echo "For a local signed-only build, set BETTER_BATTERY_SKIP_NOTARIZATION=1." >&2
    exit 2
fi

rm -rf "$SCRATCH_DIR"
swift build --disable-sandbox -c release --scratch-path "$SCRATCH_DIR"
BUILD_BINARY="$(swift build --disable-sandbox -c release --scratch-path "$SCRATCH_DIR" --show-bin-path)/$APP_NAME"

rm -rf "$STAGING_DIR"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_MACOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
"$ROOT_DIR/script/compile_app_icon.sh" "$APP_RESOURCES" "$BUNDLE_ID"
chmod +x "$APP_MACOS/$APP_NAME"
xattr -cr "$APP_BUNDLE"
codesign \
    --force \
    --sign "$SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$OUTPUT_ZIP"
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$APP_BUNDLE" "$OUTPUT_ZIP"

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    xcrun notarytool submit "$OUTPUT_ZIP" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    # Keep the accepted app's code seal untouched. The distributable DMG is
    # stapled after it is notarized, so Gatekeeper can validate it offline.
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

echo "$OUTPUT_ZIP"
