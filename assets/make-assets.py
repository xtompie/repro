"""Draws the repro banner (dark, light) and the social preview.

Same layout as the family (droid, mentor): logo on the left, a pixel title, the description,
tags in two rows, the address. All text is turned into shapes, so the images look the same everywhere.

Usage: python make-assets.py <JetBrainsMono-Regular.ttf>   (needs fontTools)
Writes banner-dark.svg, banner-light.svg and social-preview.svg next to this file.
Render social-preview.png from the SVG at 1280x640 with any browser.
"""
import os
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = sys.argv[1]

TITLE = "repro"
H3A = "Find where a session went wrong,"
H3B = "reproduce it, fix the prompt."
TAGS = [["claude-code", "agentic-engineering", "ai-agents"], ["prompt-engineering", "evals", "claude-skills"]]
URL = "github.com/xtompie/repro"

THEMES = {
    "dark": dict(bg="#0a0907", main="#ff5a1f", dark="#c23f12", ring="#ffab85", lens="#fff1ea",
                 h1="#f3ead8", h3="#cfc6b4", tag="#c23f12", tagtext="#ffab85", url="#8a7a5c"),
    "light": dict(bg=None, main="#d9480f", dark="#a8350d", ring="#e8743f", lens="#ffd9c7",
                  h1="#1f1a12", h3="#4a4234", tag="#e8743f", tagtext="#a8350d", url="#7a6440"),
}

# 5x7 pixel letters; lowercase starts at row 2 and nothing goes below row 6.
PIX = {
    "r": [".....", ".....", "#.###", "##...", "#....", "#....", "#...."],
    "e": [".....", ".....", ".###.", "#...#", "#####", "#....", ".####"],
    "p": [".....", ".....", "####.", "#...#", "####.", "#....", "#...."],
    "o": [".....", ".....", ".###.", "#...#", "#...#", "#...#", ".###."],
}

_font = TTFont(FONT)
_glyphs = _font.getGlyphSet()
_cmap = _font.getBestCmap()
_upm = _font["head"].unitsPerEm


def text(s, size, x, y, fill):
    k = size / _upm
    pen = SVGPathPen(_glyphs, ntos=lambda v: f"{v:.1f}".rstrip("0").rstrip("."))
    for ch in s:
        g = _cmap.get(ord(ch))
        if g is None:
            continue
        _glyphs[g].draw(TransformPen(pen, (k, 0, 0, -k, x, y)))
        x += _glyphs[g].width * k
    return f'<path d="{pen.getCommands()}" fill="{fill}"/>', x


def pixel_title(x, y, u, fill):
    d = ""
    for c in TITLE:
        g = PIX[c]
        for r, row in enumerate(g):
            cc = 0
            while cc < len(row):
                if row[cc] == "#":
                    e = cc
                    while e < len(row) and row[e] == "#":
                        e += 1
                    d += f"M{x + cc * u:.1f} {y + r * u:.1f}h{(e - cc) * u:.1f}v{u + 0.5:.1f}h{-(e - cc) * u:.1f}Z"
                    cc = e
                else:
                    cc += 1
        x += (len(g[0]) + 1.4) * u
    return f'<path d="{d}" fill="{fill}"/>'


def logo(x, y, u, t):
    """Droid head without the antenna; the right eye is a magnifier. Grid 16 x 14 units."""
    def r(a, b, w, h, c, cls=""):
        k = f' class="{cls}"' if cls else ""
        return f'<rect{k} x="{x + a * u:.1f}" y="{y + (b - 4) * u:.1f}" width="{w * u:.1f}" height="{h * u:.1f}" fill="{c}"/>'
    o = r(0, 4, 16, 1, t["main"]) + r(0, 17, 16, 1, t["main"]) + r(0, 4, 1, 14, t["main"]) + r(15, 4, 1, 14, t["main"])
    o += r(3.5, 8, 2.5, 2, t["main"], "eye")
    o += r(8.5, 6.5, 5, 1, t["ring"]) + r(8.5, 10.5, 5, 1, t["ring"]) + r(8.5, 6.5, 1, 5, t["ring"]) + r(12.5, 6.5, 1, 5, t["ring"])
    o += r(9.5, 7.5, 3, 3, t["lens"]) + r(12.5, 11.5, 1, 1, t["ring"]) + r(13.5, 12.5, 1, 1, t["ring"])
    o += r(3.5, 13.5, 9, 1.25, t["dark"])
    return o


CSS = """
.eye { transform-box: fill-box; transform-origin: center; animation: blink 12s infinite; }
@keyframes blink { 0%,24% { transform: scaleY(1) } 25% { transform: scaleY(.12) } 26%,84% { transform: scaleY(1) } 85% { transform: scaleY(.12) } 86%,100% { transform: scaleY(1) } }
@media (prefers-reduced-motion: reduce) { .eye { animation: none; } }
"""


def chamfer(x, y, w, h, c):
    return f"M{x} {y} H{x + w} V{y + h - c} L{x + w - c} {y + h} H{x} Z"


def content(t):
    lu = 15
    logo_w, logo_h = 16 * lu, 14 * lu
    tx = logo_w + 64
    y = 0
    o = pixel_title(tx, y, 10, t["h1"])
    y += 70 + 50
    p, _ = text(H3A, 24, tx, y, t["h3"]); o += p; y += 34
    p, right = text(H3B, 24, tx, y, t["h3"]); o += p; y += 22
    for row in TAGS:
        y += 14
        x = tx
        for tg in row:
            p, x2 = text(tg, 19, x + 13, y + 23, t["tagtext"])
            w = x2 - x + 13
            o += f'<path d="{chamfer(x, y, w, 32, 8)}" fill="none" stroke="{t["tag"]}" stroke-width="1.4"/>' + p
            x += w + 12
            right = max(right, x)
        y += 32
    y += 40
    p, x2 = text(URL, 20, tx, y, t["url"]); o += p
    right = max(right, x2)
    hc = y + 6
    return logo(0, (hc - logo_h) / 2, lu, t) + o, right, hc


def svg(w, h, theme):
    t = THEMES[theme]
    body, wc, hc = content(t)
    bg = f'<rect width="{w}" height="{h}" fill="{t["bg"]}"/>' if t["bg"] else ""
    tx, ty = (w - wc) / 2, (h - hc) / 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" '
            f'aria-label="repro. {H3A} {H3B}"><style>{CSS}</style>{bg}'
            f'<g transform="translate({tx:.1f} {ty:.1f})">{body}</g></svg>')


_, _, hc = content(THEMES["dark"])
banner_h = int(hc + 120)
for name, w, h, theme in [("banner-dark", 1280, banner_h, "dark"), ("banner-light", 1280, banner_h, "light"),
                          ("social-preview", 1280, 640, "dark")]:
    with open(os.path.join(HERE, f"{name}.svg"), "w") as f:
        f.write(svg(w, h, theme))
print(f"banner 1280x{banner_h}, social 1280x640")
