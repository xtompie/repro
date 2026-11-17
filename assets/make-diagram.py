"""Draws flow.svg: one problem (models in the wrong folder) through every repro step.

Usage: python make-diagram.py <JetBrainsMono-Regular.ttf> <JetBrainsMono-Bold.ttf>   (needs fontTools)
The font is embedded as a subset, so the image looks the same everywhere.
"""
import base64, io, os, sys
from fontTools import subset
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
BG, M, D, L, W = "#0a0907", "#e2643f", "#b53e1b", "#ebae9c", "#f8efed"
TXT, DIM = "#cfc6b4", "#8a7a5c"
WID = 1280


def font(path, weight):
    opts = subset.Options(); opts.layout_features = []; opts.name_IDs = []
    f = TTFont(path); s = subset.Subsetter(opts)
    s.populate(unicodes=list(range(0x20, 0x7f)) + [0xB7, 0x2192, 0x2191, 0x2193]); s.subset(f)
    b = io.BytesIO(); f.save(b)
    return f"@font-face {{ font-family: JBM; font-weight: {weight}; src: url(data:font/ttf;base64,{base64.b64encode(b.getvalue()).decode()}) format('truetype'); }}"


def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def chamfer(x, y, w, h, c=14): return f"M{x+c} {y} H{x+w} V{y+h-c} L{x+w-c} {y+h} H{x} V{y+c} Z"


def logo(x, y, u):
    r = [(0, 0, 16, 1, M), (0, 13, 16, 1, M), (0, 0, 1, 14, M), (15, 0, 1, 14, M), (3.5, 4, 2.5, 2, M), (3.5, 9.5, 9, 1.25, D),
         (8.5, 2.5, 5, 1, L), (8.5, 6.5, 5, 1, L), (8.5, 2.5, 1, 5, L), (12.5, 2.5, 1, 5, L), (9.5, 3.5, 3, 3, W),
         (12.5, 7.5, 1, 1, L), (13.5, 8.5, 1, 1, L)]
    return "".join(f'<rect x="{x+a*u:.1f}" y="{y+b*u:.1f}" width="{w*u:.1f}" height="{h*u:.1f}" fill="{c}"/>' for a, b, w, h, c in r)


def text(x, y, s, cls="sm", fill=TXT): return f'<text x="{x}" y="{y}" class="{cls}" fill="{fill}">{esc(s)}</text>'


def runs(fails, label):
    def draw(y):
        o = ""
        for i in range(5):
            f = i < fails
            o += f'<rect x="{430+i*30}" y="{y-17}" width="22" height="22" fill="{M if f else "none"}" stroke="{M if f else L}" stroke-width="1.6"/>'
        return o + text(590, y, label, fill=M if fails else L)
    return draw


STEPS = [
    ("1", "SESSION", "What happened?", ['you: "add an Invoice model"', "model: writes src/Invoice.php", 'you: "no, models go in model/" (twice)']),
    ("2", "SUSPECT", "Whose fault?", ["cause: instruction gap. AGENTS.md never says where models go.",
                                       lambda y: text(430, y, "other causes: model ignored a rule, operator was vague, unknown", "xs", DIM)]),
    None,
    ("3", "REPRODUCE", "Does it happen again?", ["replay from the step before the mistake, 5 runs", runs(4, "4 of 5 put it in src/")]),
    ("4", "FIX", "Which text owns it?", ['AGENTS.md  +  "Models go in model/."']),
    ("5", "RERUN", "Does the fix work?", ["the same 5 runs, with the new text", runs(0, "0 of 5")]),
    ("6", "APPLY", "Only on yes.", ["shows the diff and 4/5 → 0/5, writes it, deletes the sandbox"]),
]


def main(regular, bold):
    body = logo(40, 32, 3.6) + f'<text x="120" y="70" class="title" fill="{W}">One problem, from session to proven fix.</text>'
    y = 120
    for step in STEPS:
        if step is None:
            body += text(40, y + 4, "↑ diagnosis: a guess", "xs", L)
            body += f'<line x1="40" y1="{y+20}" x2="1240" y2="{y+20}" stroke="{L}" stroke-dasharray="6 6"/>'
            body += text(40, y + 46, "↓ proof: the guess tested in a sandbox, with the real context", "xs", L)
            y += 70
            continue
        num, title, question, lines = step
        h = max(80, 30 * len(lines) + 34)
        body += f'<path d="{chamfer(40, y, 1200, h)}" fill="none" stroke="{M}" stroke-width="1.4"/>'
        body += f'<text x="64" y="{y+38}" class="num" fill="{W}">{num}</text>'
        body += f'<text x="100" y="{y+32}" class="lbl" fill="{W}">{title}</text>'
        body += text(100, y + 56, question, "xs", DIM)
        ly = y + 34
        for line in lines:
            body += line(ly) if callable(line) else text(430, ly, line)
            ly += 30
        y += h + 20
    body += text(40, y + 6, "If the operator was vague, repro says what was unclear and how to say it next time, and stops after step 2.", "xs", DIM)
    height = y + 36
    css = font(regular, 400) + font(bold, 700) + """
text { font-family: JBM, ui-monospace, monospace; font-size: 15px; }
.title { font-size: 26px; } .num { font-size: 28px; font-weight: 700; } .lbl { font-size: 14px; letter-spacing: 2px; font-weight: 700; }
.sm { font-size: 17px; } .xs { font-size: 14px; }"""
    label = "One problem, from session to proven fix: session, suspect, reproduce 4 of 5, fix, rerun 0 of 5, apply only on yes."
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WID} {height}" width="{WID}" height="{height}" role="img" aria-label="{label}">'
           f'<style>{css}</style><rect width="{WID}" height="{height}" fill="{BG}"/>{body}</svg>')
    with open(os.path.join(HERE, "flow.svg"), "w") as f:
        f.write(svg)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
