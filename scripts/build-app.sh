#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
swift build -c release

binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_dir/dist/Color Editor.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$binary_dir/ColorEditor" "$app_dir/Contents/MacOS/ColorEditor"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
echo "$app_dir"
