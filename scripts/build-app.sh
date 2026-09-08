#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"
APP_PATH="$PROJECT_ROOT/build/TypeCompass.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/TypeCompass" "$APP_PATH/Contents/MacOS/TypeCompass"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
ditto "$BIN_PATH/TypeCompass_TypeCompassCore.bundle" "$APP_PATH/Contents/Resources/TypeCompass_TypeCompassCore.bundle"
codesign --force --sign - "$APP_PATH"
printf 'Built %s\n' "$APP_PATH"
