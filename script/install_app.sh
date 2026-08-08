#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGED_APP="/private/tmp/com.local.BetterBattery-release-package/Better Battery.app"
INSTALLED_APP="/Applications/Better Battery.app"

BETTER_BATTERY_SKIP_NOTARIZATION=1 "$ROOT_DIR/script/package_release.sh" >/dev/null

pkill -x "BetterBattery" >/dev/null 2>&1 || true
pkill -x "BatteryBar" >/dev/null 2>&1 || true

rm -rf "$INSTALLED_APP"
ditto "$STAGED_APP" "$INSTALLED_APP"
codesign --verify --deep --strict "$INSTALLED_APP"

/usr/bin/open -n "$INSTALLED_APP"
sleep 1
pgrep -x "BetterBattery" >/dev/null

echo "$INSTALLED_APP"
