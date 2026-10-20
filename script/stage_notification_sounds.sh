#!/usr/bin/env bash
set -euo pipefail

# UNNotificationSound resolves these filenames in the main bundle's Resources
# directory. Keep debug and release packaging identical and fail on missing
# assets instead of silently falling back to the system notification sound.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${1:?usage: stage_notification_sounds.sh APP_RESOURCES}"
mkdir -p "$DESTINATION"

for name in BetterBattery-Low.wav BetterBattery-Target.wav BetterBattery-Full.wav; do
    source_file="$ROOT_DIR/Resources/Sounds/$name"
    cp "$source_file" "$DESTINATION/$name"
    cmp "$source_file" "$DESTINATION/$name"
done
