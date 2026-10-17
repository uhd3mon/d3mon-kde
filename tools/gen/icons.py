#!/usr/bin/env python3
"""Generate the d3mon folder icon themes (d3mon + d3mon-light).

usage: icons.py [ICONS_DIR]   (default: theme/icons of this repo)
Writes ICONS_DIR/d3mon (dark) and ICONS_DIR/d3mon-light. The light
theme has its own folder bodies; its places/symbolic is a symlink to
the dark one (line icons are recoloured by KDE, so they are shared).
"""
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICONS_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "theme", "icons")

# ink = glyph, back = back sheet + tab, body = front body,
# edge = top highlight of the front body, lime = tab strip,
# paper = sheet inside the open folder
PALETTES = {
    "d3mon": dict(ink="#c6c9c3", back="#53565c", body="#383a3f", edge="#62666d",
                  lime="#91e611", paper="#a4a7a2"),
    "d3mon-light": dict(ink="#3a3d37", back="#a9ada4", body="#cfd2ca", edge="#e6e8e2",
                        lime="#4f8f00", paper="#f7f8f4"),
}
SYM_DEFAULT = "#7c7f7a"  # symbolic default (KDE recolours via the scheme)

# Glyphs on a 24x24 grid, stroked, round caps/joins (own drawings).
G = {
    "home": '<path d="M4 11 12 4.5 20 11"/><path d="M6.5 9.5V19h11V9.5"/><path d="M10 19v-5h4v5"/>',
    "desktop": '<rect x="3.5" y="4.5" width="17" height="11" rx="1.5"/><path d="M12 15.5V19M8 19.5h8"/>',
    "documents": '<path d="M6.5 3.5h7l4 4v13h-11z"/><path d="M13.5 3.5v4h4"/><path d="M9.5 12.5h5M9.5 16h5"/>',
    "download": '<path d="M12 3.5v11M7.5 10l4.5 4.5 4.5-4.5"/><path d="M4.5 15v4.5h15V15"/>',
    "music": '<path d="M9.5 17.5V6l10-2v11.5"/><circle cx="7" cy="17.5" r="2.5"/><circle cx="17" cy="15.5" r="2.5"/>',
    "pictures": '<rect x="3.5" y="5" width="17" height="14" rx="1.5"/><circle cx="9" cy="10" r="1.6"/><path d="M4 17.5l5-4.5 3.5 3 3-2.5 4.5 4"/>',
    "videos": '<rect x="3.5" y="5" width="17" height="14" rx="2"/><path d="M10 9v6l5-3z"/>',
    "public": '<circle cx="12" cy="8.5" r="3.5"/><path d="M5 20c.6-4 3.3-6 7-6s6.4 2 7 6"/>',
    "templates": '<rect x="4" y="4" width="16" height="16" rx="1.5" stroke-dasharray="3 2.2"/><path d="M8 9h8M8 12.5h8M8 16h5"/>',
    "git": '<circle cx="7" cy="5.5" r="2"/><circle cx="7" cy="18.5" r="2"/><circle cx="17" cy="8" r="2"/><path d="M7 7.5v9"/><path d="M17 10c0 4-10 3-10 6.5"/>',
    "development": '<path d="M8.5 7 3.5 12l5 5M15.5 7l5 5-5 5M13.5 5l-3 14"/>',
    "games": '<path d="M7 7.5h10a4 4 0 0 1 4 4.4l-.5 4.1a2.5 2.5 0 0 1-4.3 1.4L14.5 15.5h-5L7.8 17.4a2.5 2.5 0 0 1-4.3-1.4L3 11.9a4 4 0 0 1 4-4.4z"/><path d="M8 10.5v3.5M6.25 12.25h3.5"/><path d="M15.5 11.5h.01M17.5 13.5h.01" stroke-width="2.4"/>',
    "cloud": '<path d="M7.5 18.5a4 4 0 0 1-.6-7.95A5.5 5.5 0 0 1 17.6 9.6a4.45 4.45 0 0 1-.6 8.9z"/>',
    "network": '<rect x="9" y="3.5" width="6" height="5" rx="1"/><rect x="3.5" y="15.5" width="6" height="5" rx="1"/><rect x="14.5" y="15.5" width="6" height="5" rx="1"/><path d="M12 8.5v3.5M6.5 15.5V12h11v3.5"/>',
    "remote": '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.4 3.5 5.3 3.5 8.5s-1 6.1-3.5 8.5c-2.5-2.4-3.5-5.3-3.5-8.5s1-6.1 3.5-8.5z"/>',
    "locked": '<rect x="5" y="10.5" width="14" height="10" rx="1.8"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/><path d="M12 14.5v2.5"/>',
    "trash": '<path d="M4 6.5h16M9.5 6.5V4h5v2.5"/><path d="M6 6.5l1 14h10l1-14"/><path d="M10 10.5v6.5M14 10.5v6.5"/>',
    "trash-full": '<path d="M5.5 9h13M6.5 9l1 11.5h9l1-11.5"/><path d="M7.5 9l1.5-4.5 3 1.8 2.6-2.8 2 5.5"/><path d="M10.5 12.5v5M13.5 12.5v5"/>',
    "recent": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5.2l3.5 2.3"/>',
    "favorites": '<path d="M12 3.8l2.5 5.2 5.6.8-4.1 3.9 1 5.6-5-2.7-5 2.7 1-5.6-4.1-3.9 5.6-.8z"/>',
    "folder": '<path d="M3.5 6.5a1.5 1.5 0 0 1 1.5-1.5h4.5l2 2H19a1.5 1.5 0 0 1 1.5 1.5v9.5A1.5 1.5 0 0 1 19 19.5H5A1.5 1.5 0 0 1 3.5 18z"/>',
    "folder-open": '<path d="M3.5 18V6.5A1.5 1.5 0 0 1 5 5h4.5l2 2H18a1.5 1.5 0 0 1 1.5 1.5V10"/><path d="M3.5 18.5l2.3-7.3a1.5 1.5 0 0 1 1.4-1.2h13.3a1 1 0 0 1 1 1.3l-2.2 7a1.5 1.5 0 0 1-1.4 1.2H3.5"/>',
}

# icon name -> glyph (None = plain folder); trash keeps a folder body.
ICONS = {
    "folder": None,
    "folder-open": "OPEN",
    "user-home": "home",
    "user-desktop": "desktop",
    "folder-documents": "documents",
    "folder-download": "download",
    "folder-music": "music",
    "folder-pictures": "pictures",
    "folder-videos": "videos",
    "folder-publicshare": "public",
    "folder-templates": "templates",
    "folder-git": "git",
    "folder-development": "development",
    "folder-games": "games",
    "folder-cloud": "cloud",
    "folder-network": "network",
    "folder-remote": "remote",
    "folder-locked": "locked",
    "user-trash": "trash",
    "user-trash-full": "trash-full",
    "folder-recent": "recent",
    "folder-favorites": "favorites",
}

ALIASES = {
    "inode-directory": "folder",
    "folder-home": "user-home",
    "folder-desktop": "user-desktop",
    "folder-downloads": "folder-download",
    "folder-images": "folder-pictures",
    "folder-image": "folder-pictures",
    "folder-video": "folder-videos",
    "folder-public": "folder-publicshare",
    "folder-github": "folder-git",
    "folder-gitlab": "folder-git",
    "folder-trash": "user-trash",
    "folder-temp": "folder-templates",
}

HEAD = '<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}" viewBox="0 0 {s} {s}">\n'

BACK_D = ('M4 13a4 4 0 0 1 4-4h12.5a3 3 0 0 1 2.1.9L25.7 13H56'
          'a4 4 0 0 1 4 4v33a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4z')


def glyph(name, cx, cy, size, width, colour):
    k = size / 24.0
    return (f'<g transform="translate({cx - 12 * k:.3f} {cy - 12 * k:.3f}) scale({k:.4f})" '
            f'fill="none" stroke="{colour}" stroke-width="{width / k:.3f}" '
            f'stroke-linecap="round" stroke-linejoin="round">{G[name]}</g>\n')


def big(c, g):
    s = HEAD.format(s=64) + f'<path fill="{c["back"]}" d="{BACK_D}"/>\n'
    s += f'<rect fill="{c["lime"]}" x="8" y="9" width="12.5" height="2"/>\n'
    if g == "OPEN":
        # front sheet tilted forward, inside shown darker
        s += f'<rect fill="{c["paper"]}" x="9" y="15" width="46" height="14" rx="1.5"/>\n'
        s += (f'<path fill="{c["body"]}" stroke="{c["body"]}" stroke-width="4" stroke-linejoin="round" '
              f'd="M11 26H60L55.5 52H5z"/>\n')
        s += f'<path fill="none" stroke="{c["edge"]}" stroke-width="1.5" stroke-linecap="round" d="M11 24.75H60"/>\n'
    else:
        s += f'<rect fill="{c["body"]}" x="4" y="19" width="56" height="35" rx="4"/>\n'
        s += f'<path fill="none" stroke="{c["edge"]}" stroke-width="1.5" stroke-linecap="round" d="M8 19.75H56"/>\n'
        if g:
            s += glyph(g, 32, 36.5, 22, 1.6, c["ink"])
    return s + "</svg>\n"


SYM_STYLE = ('<style type="text/css" id="current-color-scheme">'
             f'.ColorScheme-Text {{ color:{SYM_DEFAULT}; }}</style>\n')


def small(g):
    if g is None:
        g = "folder"
    elif g == "OPEN":
        g = "folder-open"
    k = 22 / 24.0
    s = HEAD.format(s=22) + SYM_STYLE
    s += (f'<g class="ColorScheme-Text" transform="scale({k:.4f})" fill="none" '
          f'stroke="currentColor" stroke-width="1.6" stroke-linecap="round" '
          f'stroke-linejoin="round">{G[g]}</g>\n')
    return s + "</svg>\n"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def link(target, path):
    if os.path.lexists(path):
        if os.path.isdir(path) and not os.path.islink(path):
            raise SystemExit(f"{path} is a real folder; remove it first")
        os.remove(path)
    os.symlink(target, path)


def icons(out, c):
    d = os.path.join(out, "places/scalable")
    for name, g in ICONS.items():
        write(os.path.join(d, name + ".svg"), big(c, g))
    for alias, target in ALIASES.items():
        link(target + ".svg", os.path.join(d, alias + ".svg"))


def symbolic(out):
    d = os.path.join(out, "places/symbolic")
    for name, g in ICONS.items():
        write(os.path.join(d, name + ".svg"), small(g))
    for alias, target in ALIASES.items():
        link(target + ".svg", os.path.join(d, alias + ".svg"))


INDEX = """[Icon Theme]
Name={name}
Comment=d3mon folder icons (everything else from {base})
Inherits={inherits}
Example=folder
Directories=places/symbolic,places/scalable

# Line icons for small sizes (Dolphin sidebar, details view);
# recoloured by KDE through the ColorScheme-Text class.
[places/symbolic]
Size=22
MinSize=16
MaxSize=31
Context=Places
Type=Scalable

[places/scalable]
Size=64
MinSize=32
MaxSize=512
Context=Places
Type=Scalable
"""

dark = os.path.join(ICONS_DIR, "d3mon")
light = os.path.join(ICONS_DIR, "d3mon-light")
icons(dark, PALETTES["d3mon"])
symbolic(dark)
write(os.path.join(dark, "index.theme"), INDEX.format(
    name="d3mon", base="Breeze Dark", inherits="breeze-dark,breeze,hicolor"))

# an old d3mon-light/places -> ../d3mon/places link becomes a real folder
places = os.path.join(light, "places")
if os.path.islink(places):
    os.remove(places)
icons(light, PALETTES["d3mon-light"])
link("../../d3mon/places/symbolic", os.path.join(places, "symbolic"))
write(os.path.join(light, "index.theme"), INDEX.format(
    name="d3mon Light", base="Breeze", inherits="breeze,hicolor"))
