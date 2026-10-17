#!/usr/bin/env bash
# preview-deco.sh THEME_DIR OUT.png WALL_COLOUR
# Mimics KSvg FrameSvg: corners at native size, edges/centre stretched,
# then draws the caption and the right-hand buttons like Aurorae v2.
set -euo pipefail
dir=$1 out=$2 wall=$3
t=$(mktemp -d)
W=760 H=300 P=14 BW=18 BH=22
theme=$(basename "$dir")
rc="$dir/${theme}rc"
txt() { awk -F= -v k="$1" '$1==k{print $2}' "$rc" | tr , ' ' | xargs printf '#%02x%02x%02x'; }

piece() { # prefix side
  rsvg-convert -i "$1-$2" "$dir/decoration.svg" -o "$t/$1-$2.png"
}
win() { # prefix state caption -> $t/win-$1.png
  local p=$1
  for s in topleft top topright left center right bottomleft bottom bottomright; do
    piece "$p" "$s"
  done
  local lw th rw bh
  lw=$(magick identify -format %w "$t/$p-left.png")
  rw=$(magick identify -format %w "$t/$p-right.png")
  th=$(magick identify -format %h "$t/$p-top.png")
  bh=$(magick identify -format %h "$t/$p-bottom.png")
  local fw=$((W + 2 * P)) fh=$((H + 2 * P))
  local mw=$((fw - lw - rw)) mh=$((fh - th - bh))
  magick -size ${fw}x${fh} xc:none \
    "$t/$p-topleft.png" -geometry +0+0 -composite \
    \( "$t/$p-top.png" -resize "${mw}x${th}!" \) -geometry +${lw}+0 -composite \
    "$t/$p-topright.png" -geometry +$((lw + mw))+0 -composite \
    \( "$t/$p-left.png" -resize "${lw}x${mh}!" \) -geometry +0+${th} -composite \
    \( "$t/$p-center.png" -resize "${mw}x${mh}!" \) -geometry +${lw}+${th} -composite \
    \( "$t/$p-right.png" -resize "${rw}x${mh}!" \) -geometry +$((lw + mw))+${th} -composite \
    "$t/$p-bottomleft.png" -geometry +0+$((th + mh)) -composite \
    \( "$t/$p-bottom.png" -resize "${mw}x${bh}!" \) -geometry +${lw}+$((th + mh)) -composite \
    "$t/$p-bottomright.png" -geometry +$((lw + mw))+$((th + mh)) -composite \
    "$t/frame-$p.png"
  # buttons, right side: minimize maximize close; TitleEdgeRight=10, top 4
  local x=$((P + W - 10 - 3 * BW - 2 * 2)) y=$((P + 4)) i=0
  local args=()
  for b in minimize maximize close; do
    rsvg-convert -i "$2-center" "$dir/$b.svg" -o "$t/b-$b-$2.png"
    args+=("$t/b-$b-$2.png" -geometry +$((x + i * (BW + 2)))+$y -composite)
    i=$((i + 1))
  done
  local colour
  [ "$p" = decoration ] && colour=$(txt ActiveTextColor) || colour=$(txt InactiveTextColor)
  magick "$t/frame-$p.png" "${args[@]}" \
    -fill "$colour" -font /usr/share/fonts/noto/NotoSans-Regular.ttf -pointsize 13 -gravity north \
    -annotate +0+$((P + 9)) "$3" "$t/win-$p.png"
}
win decoration active "Home — Dolphin"
cp "$t/b-close-active.png" /dev/null
# hovered close on the active window
win decoration-inactive inactive "~ : cava — Konsole"
magick -size $((W + 2 * P + 120))x$((2 * H + 4 * P + 100)) "xc:$wall" \
  "$t/win-decoration.png" -geometry +40+30 -composite \
  "$t/win-decoration-inactive.png" -geometry +80+$((H + 2 * P + 60)) -composite \
  "$out"
# button state strip, 4x zoom
for b in close minimize maximize restore; do
  rsvg-convert -z 4 -b "$wall" "$dir/$b.svg" -o "$t/strip-$b.png"
done
magick "$t"/strip-{close,minimize,maximize,restore}.png -append "${out%.png}-buttons.png"
rm -rf "$t"
