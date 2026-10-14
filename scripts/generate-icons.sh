#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
resource_dir="$project_dir/Resources"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

for state in active deactivated; do
    source_svg="$resource_dir/source/glim-$state.svg"
    rsvg-convert -w 18 -h 18 -o "$resource_dir/glim-$state.png" "$source_svg"
    rsvg-convert -w 36 -h 36 -o "$resource_dir/glim-$state@2x.png" "$source_svg"

    if [[ "$state" == active ]]; then
        icon_name="Glim"
        start_color="#263E8C"
        end_color="#762F9A"
    else
        icon_name="Glim-Deactivated"
        start_color="#424650"
        end_color="#272A31"
    fi

    icon_svg="$scratch_dir/$icon_name.svg"
    {
        cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs><linearGradient id="background" x2="1" y2="1">
    <stop stop-color="$start_color"/>
    <stop offset="1" stop-color="$end_color"/>
  </linearGradient></defs>
  <rect x="64" y="64" width="896" height="896" rx="204" fill="url(#background)"/>
  <g transform="translate(64 64) scale(14)" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
EOF
        sed -n '/<path /p' "$source_svg"
        cat <<EOF
  </g>
</svg>
EOF
    } > "$icon_svg"

    iconset="$scratch_dir/$icon_name.iconset"
    mkdir "$iconset"
    for size in 16 32 128 256 512; do
        doubled=$((size * 2))
        rsvg-convert -w "$size" -h "$size" -o "$iconset/icon_${size}x${size}.png" "$icon_svg"
        rsvg-convert -w "$doubled" -h "$doubled" -o "$iconset/icon_${size}x${size}@2x.png" "$icon_svg"
    done
    iconutil -c icns "$iconset" -o "$resource_dir/$icon_name.icns"
done
