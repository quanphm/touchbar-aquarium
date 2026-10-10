#!/bin/bash
# Builds the SwiftPM executable and assembles a launchable .app bundle.
# Works with Command Line Tools alone (no full Xcode required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
echo "Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP="$ROOT/Build/Touch Bar Aquarium.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/AquariumBar" "$APP/Contents/MacOS/AquariumBar"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/AquariumBar"

# Ad-hoc sign so it launches locally without Gatekeeper complaints.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built: $APP"
echo "Run:   open \"$APP\""
