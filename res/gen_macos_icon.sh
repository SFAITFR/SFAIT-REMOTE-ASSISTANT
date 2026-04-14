#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SVG_PATH="$ROOT_DIR/res/macos-icon.svg"
RENDER_DIR="/tmp/sfait-macos-icon-render"
ICONSET_DIR="/tmp/sfait-macos-appicon.iconset"
APPICONSET_DIR="$ROOT_DIR/flutter/macos/Assets.xcassets/AppIcon.appiconset"
ICNS_PATH="$ROOT_DIR/flutter/macos/Runner/AppIcon.icns"

rm -rf "$RENDER_DIR" "$ICONSET_DIR"
mkdir -p "$RENDER_DIR" "$ICONSET_DIR" "$APPICONSET_DIR"

qlmanage -t -s 1024 -o "$RENDER_DIR" "$SVG_PATH" >/dev/null
SOURCE_PNG="$RENDER_DIR/$(basename "$SVG_PATH").png"

sips -z 16 16 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SOURCE_PNG" --out "$APPICONSET_DIR/icon_512x512@2x.png" >/dev/null

cp "$APPICONSET_DIR"/icon_*.png "$ICONSET_DIR"/
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

echo "Generated macOS icons from $SVG_PATH"
