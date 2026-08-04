#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:?usage: compile_app_icon.sh OUTPUT_DIR BUNDLE_ID}"
BUNDLE_ID="${2:?usage: compile_app_icon.sh OUTPUT_DIR BUNDLE_ID}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icon"
WORK_DIR="$(mktemp -d /private/tmp/com.local.BetterBattery-icon.XXXXXX)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"

xcrun actool "$ICON_SOURCE" \
    --compile "$OUTPUT_DIR" \
    --output-format human-readable-text \
    --notices \
    --warnings \
    --output-partial-info-plist "$WORK_DIR/assetcatalog_generated_info.plist" \
    --app-icon AppIcon \
    --enable-on-demand-resources NO \
    --development-region en \
    --target-device mac \
    --minimum-deployment-target 13.0 \
    --platform macosx \
    --bundle-identifier "$BUNDLE_ID"

test -f "$OUTPUT_DIR/AppIcon.icns"
test -f "$OUTPUT_DIR/Assets.car"
