#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NAME="Better Battery"
VOLUME_NAME="Better Battery"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/outputs"
STAGING_DIR="/private/tmp/com.local.BetterBattery-release-package"
APP_BUNDLE="$STAGING_DIR/$DISPLAY_NAME.app"
DMG_ROOT="/private/tmp/com.local.BetterBattery-dmg-root"
RW_DMG="/private/tmp/com.local.BetterBattery-release.dmg"
OUTPUT_DMG="$OUTPUT_DIR/Better-Battery.dmg"
BACKGROUND_DIR="$DMG_ROOT/.background"
BACKGROUND_IMAGE="$BACKGROUND_DIR/background.png"
VOLUME_ICON_SOURCE="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
SIGN_IDENTITY="${BETTER_BATTERY_SIGN_IDENTITY:-Developer ID Application: zac hall (XWKP9KZ69G)}"
NOTARY_PROFILE="${BETTER_BATTERY_NOTARY_PROFILE:-${NOTARY_PROFILE:-}}"
export CLANG_MODULE_CACHE_PATH="/private/tmp/com.local.BetterBattery-module-cache"
export SWIFT_MODULE_CACHE_PATH="/private/tmp/com.local.BetterBattery-module-cache"
export XDG_CACHE_HOME="/private/tmp/com.local.BetterBattery-cache"

if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "Set BETTER_BATTERY_NOTARY_PROFILE to a notarytool Keychain profile." >&2
    exit 2
fi

cd "$ROOT_DIR"
BETTER_BATTERY_NOTARY_PROFILE="$NOTARY_PROFILE" \
    "$ROOT_DIR/script/package_release.sh" >/dev/null

rm -rf "$DMG_ROOT"
mkdir -p "$BACKGROUND_DIR"
ditto "$APP_BUNDLE" "$DMG_ROOT/$DISPLAY_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
swift "$ROOT_DIR/script/render_dmg_background.swift" "$BACKGROUND_IMAGE"

rm -f "$RW_DMG" "$OUTPUT_DMG"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$RW_DMG" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')"
MOUNT_POINT="/Volumes/$VOLUME_NAME"

cleanup() {
    if [[ -n "${DEVICE:-}" ]]; then
        hdiutil detach "$DEVICE" -quiet || true
    fi
}
trap cleanup EXIT

osascript <<'APPLESCRIPT'
set backgroundImage to POSIX file "/Volumes/Better Battery/.background/background.png" as alias
tell application "Finder"
    tell disk "Better Battery"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 720, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set text size of viewOptions to 14
        set background picture of viewOptions to backgroundImage
        set position of item "Better Battery.app" of container window to {160, 210}
        set position of item "Applications" of container window to {440, 210}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

cp "$VOLUME_ICON_SOURCE" "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -a C "$MOUNT_POINT"
test -f "$MOUNT_POINT/.VolumeIcon.icns"
xattr -p com.apple.FinderInfo "$MOUNT_POINT" >/dev/null
sync
hdiutil detach "$DEVICE" -quiet
DEVICE=""
trap - EXIT

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 \
    -o "$OUTPUT_DMG" >/dev/null
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$OUTPUT_DMG"
codesign --verify --verbose=2 "$OUTPUT_DMG"

xcrun notarytool submit "$OUTPUT_DMG" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
xcrun stapler staple "$OUTPUT_DMG"
xcrun stapler validate "$OUTPUT_DMG"
spctl --assess --type open \
    --context context:primary-signature \
    --verbose=4 "$OUTPUT_DMG"

echo "$OUTPUT_DMG"
