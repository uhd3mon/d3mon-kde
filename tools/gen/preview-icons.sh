#!/usr/bin/env bash
# preview-icons.sh ICON_DIR OUT_DIR : contact sheets on dark + light bg
set -euo pipefail
src=$1 out=$2
mkdir -p "$out/tiles"
for bg in 0d0d0e f2f3ef; do
  [ "$bg" = 0d0d0e ] && fg='#c6c9c3' || fg='#2a2b2e'
  tiles=()
  for f in "$src"/places/scalable/*.svg; do
    [ -L "$f" ] && continue
    n=$(basename "$f" .svg)
    s=$(sed "s/#7c7f7a/${fg}/" "$src/places/symbolic/$n.svg")
    rsvg-convert -w 96 -h 96 "$f" -o "$out/tiles/$n-96.png"
    rsvg-convert -w 48 -h 48 "$f" -o "$out/tiles/$n-48.png"
    printf '%s' "$s" | rsvg-convert -w 22 -h 22 -o "$out/tiles/$n-22.png"
    printf '%s' "$s" | rsvg-convert -w 16 -h 16 -o "$out/tiles/$n-16.png"
    magick -size 170x170 "xc:#$bg" \
      "$out/tiles/$n-96.png" -geometry +4+4 -composite \
      "$out/tiles/$n-48.png" -geometry +112+4 -composite \
      "$out/tiles/$n-22.png" -geometry +112+64 -composite \
      "$out/tiles/$n-16.png" -geometry +142+68 -composite \
      -fill "$fg" -font DejaVu-Sans -pointsize 11 -gravity south \
      -annotate +0+8 "$n" "$out/tiles/$n-$bg.png"
    tiles+=("$out/tiles/$n-$bg.png")
  done
  magick montage "${tiles[@]}" -tile 6x -geometry +0+0 \
    -background "#$bg" "$out/icons-$bg.png"
done
