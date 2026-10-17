#!/usr/bin/env bash
# Builds the d3mon theme as files KDE's own settings pages can install
# ("Install from File…"), without install.sh. Output: dist/ (or $1).
#
#   Global Theme   d3mon-dark.globaltheme.tar.gz, d3mon-light...
#                  (each carries its colour scheme as contents/colors)
#   Plasma Style   d3mon.plasmastyle.tar.gz
#   Colors         D3monDark.colors, D3monLight.colors
#   Icons          d3mon-icons.tar.gz (d3mon + d3mon-light)
#   Decorations    d3mon[-light].aurorae.tar.gz (kpackagetool6 -t KWin/Aurorae)
#   Wallpaper      d3mon-grid.wallpaper.tar.gz (unpack into ~/.local/share/wallpapers)
#   Konsole        d3mon-dark.colorscheme, d3mon-light.colorscheme
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(realpath -m "${1:-$REPO/dist}")"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

T="$REPO/theme"
mkdir -p "$OUT"
rm -f "$OUT"/*.tar.gz "$OUT"/*.colors "$OUT"/*.colorscheme "$OUT"/SHA256SUMS

# pack NAME DIR...: tar.gz of the given folders (inside $STAGE), with
# symlinks resolved so each archive stands on its own.
pack() {
	local name="$1"
	shift
	tar -C "$STAGE" --dereference --sort=name --owner=0 --group=0 \
		--mtime='2026-01-01 00:00Z' -czf "$OUT/$name" "$@"
	echo "built  $name"
}

for theme in dark light; do
	scheme=D3monDark
	[[ "$theme" == light ]] && scheme=D3monLight
	cp -a "$T/look-and-feel/org.d3mon.$theme" "$STAGE/"
	cp "$T/color-schemes/$scheme.colors" "$STAGE/org.d3mon.$theme/contents/colors"
	pack "d3mon-$theme.globaltheme.tar.gz" "org.d3mon.$theme"
done

cp -a "$T/plasma/d3mon" "$STAGE/plasma-d3mon"
mv "$STAGE/plasma-d3mon" "$STAGE/d3mon"
pack d3mon.plasmastyle.tar.gz d3mon
rm -rf "${STAGE:?}/d3mon"

cp -a "$T/icons/d3mon" "$T/icons/d3mon-light" "$STAGE/"
pack d3mon-icons.tar.gz d3mon d3mon-light
rm -rf "${STAGE:?}/d3mon" "${STAGE:?}/d3mon-light"

for deco in "$T"/aurorae/*/; do
	deco="$(basename "$deco")"
	cp -a "$T/aurorae/$deco" "$STAGE/"
	# KDE's package tool only accepts Aurorae themes as .svgz.
	for svg in "$STAGE/$deco"/*.svg; do
		gzip -9n -c "$svg" >"${svg}z"
		rm -f "$svg"
	done
	pack "$deco.aurorae.tar.gz" "$deco"
	rm -rf "${STAGE:?}/$deco"
done

cp -a "$T/wallpapers/d3mon-grid" "$STAGE/"
pack d3mon-grid.wallpaper.tar.gz d3mon-grid

cp "$T"/color-schemes/*.colors "$T"/konsole/*.colorscheme "$OUT/"
(cd "$OUT" && sha256sum -- * >SHA256SUMS)
echo "output: $OUT"
