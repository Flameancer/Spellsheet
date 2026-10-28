#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="Spellsheet.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/Spellsheet" "$APP/Contents/MacOS/Spellsheet"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/Spellsheet"
codesign --force --sign - "$APP"
echo "Built $(pwd)/$APP"
