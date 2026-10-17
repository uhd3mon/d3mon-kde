#!/usr/bin/env python3
"""Generate the d3mon Aurorae window decorations (dark + light).

usage: aurorae.py AURORAE_DIR   (AURORAE_DIR = theme/aurorae)
Element names follow KDE aurorae v2 (decoration.cpp/decorationbutton.cpp).
"""
import os
import sys

ROOT = sys.argv[1]

P = 14          # shadow padding on every side
R = 8           # top corner radius
IN = 10         # window part inside the corner/side elements (> R)
EDGE_H = 2      # bottom border (outline + 1 px)
TITLE = 30      # TitleEdgeTop + TitleHeight + TitleEdgeBottom
BW, BH, DOT = 18, 22, 6.5   # button cell + dot radius

VARIANTS = {
    "d3mon": dict(name="d3mon", bg="#141416", line="#2a2b2f", shadow=0.42,
                  shadow_in=0.26, text="#c6c9c3", text_in="#6d706b",
                  idle="#3a3c40", glyph="#0d0d0e"),
    "d3mon-light": dict(name="d3mon Light", bg="#f2f3ef", line="#d3d4cf",
                        shadow=0.20, shadow_in=0.12, text="#2a2b2e",
                        text_in="#8a8c88", idle="#c9cac5", glyph="#2a2b2e"),
}

BUTTONS = {
    "close": ("#ff5f56", '<path d="M-2.6-2.6 2.6 2.6M2.6-2.6-2.6 2.6" stroke="{g}" stroke-width="1.4" stroke-linecap="round" opacity=".75"/>'),
    "minimize": ("#f0b43c", '<path d="M-3 0H3" stroke="{g}" stroke-width="1.5" stroke-linecap="round" opacity=".75"/>'),
    "maximize": ("#91e611", '<path d="M-3 1V-3H1zM3-1V3H-1z" fill="{g}" opacity=".75"/>'),
    "restore": ("#91e611", '<path d="M-.4-.4V-4.2H-4.2zM.4 .4V4.2H4.2z" fill="{g}" opacity=".75"/>'),
}


def stops(alpha):
    prof = ((0, 1), (0.25, 0.55), (0.55, 0.2), (0.8, 0.05), (1, 0))
    return prof, alpha


def lin(gid, x1, y1, x2, y2, alpha):
    prof, a = stops(alpha)
    s = (f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" '
         f'x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">')
    for t, f in prof:
        s += f'<stop offset="{t}" stop-color="#000" stop-opacity="{a * f:.3f}"/>'
    return s + "</linearGradient>\n"


def rad(gid, cx, cy, r0, r1, alpha):
    prof, a = stops(alpha)
    s = (f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" '
         f'cx="{cx}" cy="{cy}" r="{r1}">')
    if r0 > 0:
        s += f'<stop offset="0" stop-color="#000" stop-opacity="{a:.3f}"/>'
    for t, f in prof:
        off = (r0 + t * (r1 - r0)) / r1
        s += f'<stop offset="{off:.4f}" stop-color="#000" stop-opacity="{a * f:.3f}"/>'
    return s + "</radialGradient>\n"


def frame(prefix, v, alpha, ox, oy):
    """Nine frame elements for one prefix, laid out from (ox, oy)."""
    bg, line = v["bg"], v["line"]
    WL = P + IN          # left/right element width
    HT = P + TITLE       # top element height
    HB = P + EDGE_H      # bottom element height
    M = 10               # stretchable middle size
    d, g = "", ""

    def at(x, y):
        return ox + x, oy + y

    # top-left
    x, y = at(0, 0)
    gid = f"{prefix}-g"
    g += rad(gid + "tl", x + P + R, y + P + R, R, P + R, alpha)
    g += lin(gid + "l", x + P, 0, x, 0, alpha)
    g += lin(gid + "t", 0, y + P, 0, y, alpha)
    d += (f'<g id="{prefix}-topleft">'
          f'<rect x="{x}" y="{y}" width="{P + R}" height="{P + R}" fill="url(#{gid}tl)"/>'
          f'<rect x="{x}" y="{y + P + R}" width="{P}" height="{HT - P - R}" fill="url(#{gid}l)"/>'
          f'<rect x="{x + P + R}" y="{y}" width="{WL - P - R}" height="{P}" fill="url(#{gid}t)"/>'
          f'<path fill="{line}" d="M{x + P} {y + HT}V{y + P + R}a{R} {R} 0 0 1 {R}-{R}H{x + WL}V{y + HT}z"/>'
          f'<path fill="{bg}" d="M{x + P + 1} {y + HT}V{y + P + R}a{R - 1} {R - 1} 0 0 1 {R - 1}-{R - 1}H{x + WL}V{y + HT}z"/>'
          '</g>\n')
    # top
    x, y = at(WL + 4, 0)
    d += (f'<g id="{prefix}-top">'
          f'<rect x="{x}" y="{y}" width="{M}" height="{P}" fill="url(#{gid}t2)"/>'
          f'<rect x="{x}" y="{y + P}" width="{M}" height="1" fill="{line}"/>'
          f'<rect x="{x}" y="{y + P + 1}" width="{M}" height="{TITLE - 1}" fill="{bg}"/>'
          '</g>\n')
    g += lin(gid + "t2", 0, y + P, 0, y, alpha)
    # top-right
    x, y = at(WL + M + 8, 0)
    g += rad(gid + "tr", x + IN - R, y + P + R, R, P + R, alpha)
    g += lin(gid + "r", x + IN, 0, x + WL, 0, alpha)
    g += lin(gid + "t3", 0, y + P, 0, y, alpha)
    d += (f'<g id="{prefix}-topright">'
          f'<rect x="{x + IN - R}" y="{y}" width="{P + R}" height="{P + R}" fill="url(#{gid}tr)"/>'
          f'<rect x="{x + IN}" y="{y + P + R}" width="{P}" height="{HT - P - R}" fill="url(#{gid}r)"/>'
          f'<rect x="{x}" y="{y}" width="{IN - R}" height="{P}" fill="url(#{gid}t3)"/>'
          f'<path fill="{line}" d="M{x} {y + HT}V{y + P}H{x + IN - R}a{R} {R} 0 0 1 {R} {R}V{y + HT}z"/>'
          f'<path fill="{bg}" d="M{x} {y + HT}V{y + P + 1}H{x + IN - R}a{R - 1} {R - 1} 0 0 1 {R - 1} {R - 1}V{y + HT}z"/>'
          '</g>\n')
    # left / center / right
    y0 = HT + 4
    x, y = at(0, y0)
    g += lin(gid + "l2", x + P, 0, x, 0, alpha)
    d += (f'<g id="{prefix}-left">'
          f'<rect x="{x}" y="{y}" width="{P}" height="{M}" fill="url(#{gid}l2)"/>'
          f'<rect x="{x + P}" y="{y}" width="1" height="{M}" fill="{line}"/>'
          f'<rect x="{x + P + 1}" y="{y}" width="{IN - 1}" height="{M}" fill="{bg}"/>'
          '</g>\n')
    x, y = at(WL + 4, y0)
    d += f'<rect id="{prefix}-center" x="{x}" y="{y}" width="{M}" height="{M}" fill="{bg}"/>\n'
    x, y = at(WL + M + 8, y0)
    g += lin(gid + "r2", x + IN, 0, x + WL, 0, alpha)
    d += (f'<g id="{prefix}-right">'
          f'<rect x="{x}" y="{y}" width="{IN - 1}" height="{M}" fill="{bg}"/>'
          f'<rect x="{x + IN - 1}" y="{y}" width="1" height="{M}" fill="{line}"/>'
          f'<rect x="{x + IN}" y="{y}" width="{P}" height="{M}" fill="url(#{gid}r2)"/>'
          '</g>\n')
    # bottom row (square corners)
    y0 += M + 4
    x, y = at(0, y0)
    g += lin(gid + "bl1", x + P, 0, x, 0, alpha)
    g += rad(gid + "bl2", x + P, y + EDGE_H, 0, P, alpha)
    g += lin(gid + "bl3", 0, y + EDGE_H, 0, y + HB, alpha)
    d += (f'<g id="{prefix}-bottomleft">'
          f'<rect x="{x}" y="{y}" width="{P}" height="{EDGE_H}" fill="url(#{gid}bl1)"/>'
          f'<rect x="{x}" y="{y + EDGE_H}" width="{P}" height="{P}" fill="url(#{gid}bl2)"/>'
          f'<rect x="{x + P}" y="{y + EDGE_H}" width="{IN}" height="{P}" fill="url(#{gid}bl3)"/>'
          f'<rect x="{x + P}" y="{y}" width="{IN}" height="{EDGE_H}" fill="{line}"/>'
          f'<rect x="{x + P + 1}" y="{y}" width="{IN - 1}" height="{EDGE_H - 1}" fill="{bg}"/>'
          '</g>\n')
    x, y = at(WL + 4, y0)
    g += lin(gid + "b", 0, y + EDGE_H, 0, y + HB, alpha)
    d += (f'<g id="{prefix}-bottom">'
          f'<rect x="{x}" y="{y}" width="{M}" height="{EDGE_H - 1}" fill="{bg}"/>'
          f'<rect x="{x}" y="{y + EDGE_H - 1}" width="{M}" height="1" fill="{line}"/>'
          f'<rect x="{x}" y="{y + EDGE_H}" width="{M}" height="{P}" fill="url(#{gid}b)"/>'
          '</g>\n')
    x, y = at(WL + M + 8, y0)
    g += lin(gid + "br1", x + IN, 0, x + WL, 0, alpha)
    g += rad(gid + "br2", x + IN, y + EDGE_H, 0, P, alpha)
    g += lin(gid + "br3", 0, y + EDGE_H, 0, y + HB, alpha)
    d += (f'<g id="{prefix}-bottomright">'
          f'<rect x="{x + IN}" y="{y}" width="{P}" height="{EDGE_H}" fill="url(#{gid}br1)"/>'
          f'<rect x="{x + IN}" y="{y + EDGE_H}" width="{P}" height="{P}" fill="url(#{gid}br2)"/>'
          f'<rect x="{x}" y="{y + EDGE_H}" width="{IN}" height="{P}" fill="url(#{gid}br3)"/>'
          f'<rect x="{x}" y="{y}" width="{IN}" height="{EDGE_H}" fill="{line}"/>'
          f'<rect x="{x}" y="{y}" width="{IN - 1}" height="{EDGE_H - 1}" fill="{bg}"/>'
          '</g>\n')
    return g, d


def decoration(v):
    defs, body = "", ""
    for i, (prefix, a) in enumerate((("decoration", v["shadow"]),
                                     ("decoration-inactive", v["shadow_in"]))):
        g, d = frame(prefix, v, a, 0, i * 100)
        defs += g
        body += d
    # maximized: no borders, only the centre is used
    body += f'<rect id="decoration-maximized-center" x="0" y="210" width="10" height="10" fill="{v["bg"]}"/>\n'
    body += f'<rect id="decoration-maximized-inactive-center" x="20" y="210" width="10" height="10" fill="{v["bg"]}"/>\n'
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="230" viewBox="0 0 80 230">\n'
            f'<defs>\n{defs}</defs>\n{body}</svg>\n')


def button(v, colour, glyph):
    g = glyph.format(g=v["glyph"])
    darker = shade(colour, 0.78)
    states = [
        ("active", colour, ""),
        ("hover", colour, g),
        ("pressed", darker, g),
        ("deactivated", v["idle"], ""),
        ("inactive", v["idle"], ""),
        ("hover-inactive", colour, g),
        ("pressed-inactive", darker, g),
        ("deactivated-inactive", v["idle"], ""),
    ]
    out = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{BW * len(states) + 4 * len(states)}" '
           f'height="{BH}" viewBox="0 0 {(BW + 4) * len(states)} {BH}">\n')
    for i, (state, fill, mark) in enumerate(states):
        x = i * (BW + 4)
        op = ' opacity=".45"' if state.startswith("deactivated") else ""
        out += (f'<g id="{state}-center"{op}>'
                f'<rect x="{x}" y="0" width="{BW}" height="{BH}" fill="#000" opacity="0"/>'
                f'<circle cx="{x + BW / 2}" cy="{BH / 2}" r="{DOT}" fill="{fill}"/>'
                f'<g transform="translate({x + BW / 2} {BH / 2})">{mark}</g></g>\n')
    return out + "</svg>\n"


def shade(hexc, f):
    r, g, b = (int(hexc[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % (int(r * f), int(g * f), int(b * f))


def rc(v):
    return f"""[General]
ActiveTextColor={hexrgb(v["text"])}
InactiveTextColor={hexrgb(v["text_in"])}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=150

[Layout]
BorderLeft=2
BorderRight=2
BorderBottom={EDGE_H}
TitleEdgeTop=4
TitleEdgeBottom=4
TitleEdgeLeft=10
TitleEdgeRight=10
TitleEdgeTopMaximized=4
TitleEdgeBottomMaximized=4
TitleEdgeLeftMaximized=8
TitleEdgeRightMaximized=8
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={TITLE - 8}
ButtonWidth={BW}
ButtonHeight={BH}
ButtonSpacing=2
ButtonMarginTop=0
ButtonMarginTopMaximized=0
ExplicitButtonSpacer=10
PaddingTop={P}
PaddingBottom={P}
PaddingLeft={P}
PaddingRight={P}
"""


def hexrgb(h):
    return ",".join(str(int(h[i:i + 2], 16)) for i in (1, 3, 5))


def metadata(theme, v):
    return f"""[Desktop Entry]
Name={v["name"]}
Comment=d3mon window decoration: flat titlebar, centred title, round buttons
X-KDE-PluginInfo-Name={theme}
X-KDE-PluginInfo-Author=d3mon
X-KDE-PluginInfo-Version=1.0
"""


for theme, v in VARIANTS.items():
    d = os.path.join(ROOT, theme)
    os.makedirs(d, exist_ok=True)
    files = {
        "metadata.desktop": metadata(theme, v),
        theme + "rc": rc(v),
        "decoration.svg": decoration(v),
    }
    for b, (colour, glyph) in BUTTONS.items():
        files[b + ".svg"] = button(v, colour, glyph)
    for name, text in files.items():
        with open(os.path.join(d, name), "w") as f:
            f.write(text)
