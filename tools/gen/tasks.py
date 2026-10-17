#!/usr/bin/env python3
"""Generates theme/plasma/d3mon/widgets/tasks.svg (Plasma task manager frames).

Each state is a 9-patch: 4 px rounded corners/edges of a faint tint, and a
centre that carries the tint plus the state's mark (accent bar, warn bar or
a small dot) at its bottom edge, so the mark scales with the task button.
"""
import sys

B = 4          # border / corner radius
C = 40         # centre size (frame = C + 2B)
F = C + 2 * B
BAR_W, BAR_H = 16, 3   # 40 % of the centre
DOT_R = 1.6

# prefix: (tint class, tint opacity, mark, mark class, mark opacity)
STATES = {
    "normal":          (None, 0, "dot", "ColorScheme-Text", .55),
    "hover":           ("ColorScheme-Text", .08, None, None, 0),
    "launcher-hover":  ("ColorScheme-Text", .08, None, None, 0),
    "focus":           ("ColorScheme-Text", .10, "bar", "ColorScheme-Highlight", 1),
    "focus-hover":     ("ColorScheme-Text", .15, "bar", "ColorScheme-Highlight", 1),
    "minimized":       (None, 0, "dot", "ColorScheme-Text", .30),
    "minimized-hover": ("ColorScheme-Text", .08, "dot", "ColorScheme-Text", .45),
    "attention":       ("ColorScheme-NeutralText", .12, "bar", "ColorScheme-NeutralText", 1),
    "attention-hover": ("ColorScheme-NeutralText", .18, "bar", "ColorScheme-NeutralText", 1),
    "progress":        ("ColorScheme-PositiveText", .22, None, None, 0),
}

out = []
w = out.append


def fill(cls, op, d):
    if cls is None:
        return f'<path d="{d}" fill="none"/>'
    return f'<path class="{cls}" d="{d}" fill="currentColor" opacity="{op:g}"/>'


def rect(x, y, wd, ht):
    return f"M{x} {y}h{wd}v{ht}h{-wd}z"


def frame(prefix, ox, oy, tint, top, mark, mcls, mop):
    r = B
    # corners: quarter discs anchored at the inner corner
    corners = {
        "topleft": (ox, oy, f"M{ox} {oy+r}a{r} {r} 0 0 1 {r} {-r}v{r}z"),
        "topright": (ox + B + C, oy, f"M{ox+B+C} {oy}a{r} {r} 0 0 1 {r} {r}h{-r}z"),
        "bottomleft": (ox, oy + B + C, f"M{ox} {oy+B+C}h{r}v{r}a{r} {r} 0 0 1 {-r} {-r}z"),
        "bottomright": (ox + B + C, oy + B + C, f"M{ox+B+C} {oy+B+C}h{r}a{r} {r} 0 0 1 {-r} {r}z"),
    }
    for name, (x, y, d) in corners.items():
        w(f'<g id="{prefix}-{name}">')
        w(f'  <path d="{rect(x, y, B, B)}" fill="none"/>')
        if tint:
            w("  " + fill(tint, top, d))
        w("</g>")
    edges = {
        "top": (ox + B, oy, C, B),
        "bottom": (ox + B, oy + B + C, C, B),
        "left": (ox, oy + B, B, C),
        "right": (ox + B + C, oy + B, B, C),
    }
    for name, (x, y, wd, ht) in edges.items():
        w(f'<g id="{prefix}-{name}">' + fill(tint, top, rect(x, y, wd, ht)) + "</g>")
    cx, cy = ox + B, oy + B
    w(f'<g id="{prefix}-center">')
    w("  " + fill(tint, top, rect(cx, cy, C, C)))
    if mark == "bar":
        bx = cx + (C - BAR_W) / 2
        w(f'  <rect class="{mcls}" x="{bx:g}" y="{cy + C - BAR_H}" width="{BAR_W}" '
          f'height="{BAR_H}" rx="{BAR_H/2:g}" fill="currentColor" opacity="{mop:g}"/>')
    elif mark == "dot":
        w(f'  <circle class="{mcls}" cx="{cx + C/2:g}" cy="{cy + C - DOT_R - .4:g}" r="{DOT_R}" '
          f'fill="currentColor" opacity="{mop:g}"/>')
    w("</g>")


cols = 4
for i, (prefix, (tint, top, mark, mcls, mop)) in enumerate(STATES.items()):
    frame(prefix, (i % cols) * (F + 4), (i // cols) * (F + 4), tint, top, mark, mcls, mop)

rows = (len(STATES) + cols - 1) // cols
hy = rows * (F + 4)
# Content margins (icon padding) for every task, read from "normal".
for i, side in enumerate(("top", "bottom", "left", "right")):
    w(f'<rect id="normal-hint-{side}-margin" x="{i*8}" y="{hy}" width="4" height="4" fill="none"/>')

# Group expander: small "+" badge in the accent colour.
ex = 4 * 8
for i, side in enumerate(("top", "bottom", "left", "right")):
    x = ex + i * 14
    w(f'<g id="group-expander-{side}">')
    w(f'  <circle class="ColorScheme-Highlight" cx="{x+5}" cy="{hy+5}" r="5" fill="currentColor"/>')
    w(f'  <path class="ColorScheme-HighlightedText" d="M{x+4.25} {hy+2.5}h1.5v1.75h1.75v1.5h-1.75v1.75h-1.5v-1.75h-1.75v-1.5h1.75z" fill="currentColor"/>')
    w("</g>")

W = cols * (F + 4)
H = hy + 12
style = """<style id="current-color-scheme" type="text/css">
.ColorScheme-Text { color:#f8f8f2; }
.ColorScheme-Highlight { color:#91e611; }
.ColorScheme-HighlightedText { color:#0b0b0b; }
.ColorScheme-NeutralText { color:#f5b841; }
.ColorScheme-PositiveText { color:#91e611; }
</style>"""
body = "\n".join(out)
sys.stdout.write(
    f'<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="{W}" height="{H}" '
    f'viewBox="0 0 {W} {H}">\n{style}\n{body}\n</svg>\n')
