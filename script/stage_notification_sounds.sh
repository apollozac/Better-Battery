#!/usr/bin/env bash
set -euo pipefail

# The app installs these original recordings from Resources into Library/Sounds
# under versioned notification filenames. Keep debug and release packaging
# identical and fail on missing source assets.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${1:?usage: stage_notification_sounds.sh APP_RESOURCES}"
mkdir -p "$DESTINATION"

for name in BetterBattery-Low.wav BetterBattery-Target.wav BetterBattery-Full.wav; do
    source_file="$ROOT_DIR/Resources/Sounds/$name"
    cp "$source_file" "$DESTINATION/$name"
    cmp "$source_file" "$DESTINATION/$name"
done
