#!/usr/bin/env bash
# wall.sh OUT_PKG : d3mon Grid wallpaper package (Codec grid, no axes,
# soft centre glow). Grid anchored at 0,0 like the old grid-*.png:
# minor every 48 px, major every 240 px, 1 px lines at 1x (2x doubles).
set -euo pipefail
out=$1
mkdir -p "$out/contents/images" "$out/contents/images_dark"
t=$(mktemp -d)
make() { # variant WxH scale
  local v=$1 size=$2 k=$3 w h bg minor major glow
  w=${size%x*} h=${size#*x}
  if [ "$v" = dark ]; then
    bg='#070707' minor='rgba(255,255,255,0.0363)' major='rgba(255,255,255,0.1008)'
    glow='rgba(255,255,255,0.055)-rgba(255,255,255,0)'
    dir=images_dark
  else
    bg='#f2f3ef' minor='rgba(0,0,0,0.0372)' major='rgba(0,0,0,0.1033)'
    glow='rgba(255,255,255,0.75)-rgba(255,255,255,0)'
    dir=images
  fi
  local c=$((48 * k)) M=$((240 * k)) lw=$k
  # one major tile: major line at 0, minor lines every $c
  local draw="fill $minor"
  for ((i = c; i < M; i += c)); do
    draw+=" rectangle $i,0 $((i + lw - 1)),$((M - 1)) rectangle 0,$i $((M - 1)),$((i + lw - 1))"
  done
  draw+=" fill $major rectangle 0,0 $((lw - 1)),$((M - 1)) rectangle 0,0 $((M - 1)),$((lw - 1))"
  magick -size ${M}x${M} "xc:$bg" -draw "$draw" "$t/tile.png"
  local g=$((h * 13 / 10))
  magick -size ${w}x${h} "tile:$t/tile.png" \
    \( -size ${g}x${g} "radial-gradient:$glow" \) -gravity center -composite \
    -depth 8 -define png:compression-level=9 "$out/contents/$dir/$size.png"
}
for v in dark light; do
  make $v 1920x1080 1; make $v 1920x1200 1; make $v 2560x1440 1
  make $v 3840x2160 2; make $v 3840x2400 2
done
rm -rf "$t"
