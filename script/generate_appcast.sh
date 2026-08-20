#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "usage: $0 <version>" >&2
    exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$ROOT_DIR/outputs/Better-Battery.zip"
APPCAST="$ROOT_DIR/appcast.xml"
WORK_DIR="/private/tmp/com.local.BetterBattery-appcast"
SPARKLE_ROOT="$ROOT_DIR/.build/artifacts/sparkle/Sparkle"
GENERATE_APPCAST="$SPARKLE_ROOT/bin/generate_appcast"

if [[ ! -f "$ARCHIVE" ]]; then
    echo "Missing release archive: $ARCHIVE" >&2
    exit 2
fi
if [[ ! -x "$GENERATE_APPCAST" ]]; then
    echo "Resolve the Swift package before generating the appcast." >&2
    exit 2
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp "$ARCHIVE" "$WORK_DIR/Better-Battery.zip"
if [[ -f "$APPCAST" ]]; then
    cp "$APPCAST" "$WORK_DIR/appcast.xml"
fi

"$GENERATE_APPCAST" \
    --download-url-prefix \
    "https://github.com/apollozac/Better-Battery/releases/download/v$VERSION/" \
    --link "https://apollozac.com/better-battery" \
    --maximum-deltas 0 \
    "$WORK_DIR"

cp "$WORK_DIR/appcast.xml" "$APPCAST"
echo "$APPCAST"
