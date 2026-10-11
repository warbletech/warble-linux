#!/usr/bin/env python3
"""Warble Linux brand art generator: SVG sources and PNG exports.

Every shape is authored here as plain SVG: flat, geometric (faceted) bird marks
in Warble Cloud brand colours. The only raster input is the existing Warble
Cloud icon (source/warble-cloud-icon-512.png), which is embedded unchanged.

    python3 assets/brand/generate.py            # write svg/ and png/
    python3 assets/brand/generate.py --svg-only

PNG rendering uses resvg-py (pip install resvg-py) or the `rsvg-convert` CLI.
Output is deterministic: the flock positions use a fixed seed.
"""
import math, os, random, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SVG_DIR = os.path.join(HERE, "svg")
PNG_DIR = os.path.join(HERE, "png")

# Palette: the Warble Cloud logo (sampled from the logo) and the warble-tech
# brand page tokens (--bg*, --accent*, --success, --warning, --text, --muted).
P = {
    "navy": "#102f5e", "navy2": "#12356a", "teal": "#10a6b4", "sky": "#99d0ea",
    "sky2": "#b6dbed", "violet": "#6c63ff", "cyan": "#4fc3f7", "lilac": "#a78bfa",
    "mint": "#34d399", "amber": "#fbbf24", "heron": "#1e3a5f", "bg": "#0a0a0f",
    "bg3": "#13131f", "bg4": "#1a1a2e", "text": "#e8e8f0", "muted": "#8888a0",
    "ink": "#0f172a", "slate": "#475569", "paper": "#f8fafc", "paper2": "#e0f2fe",
}

def poly(points, fill, opacity=1.0):
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    return f'<polygon points="{pts}" fill="{fill}"{op}/>'

# ── Mascots (1000x1000 design box, facing right) ────────────────────────────
def mascot_warble():
    """Warble: the brand songbird, singing (sound arcs = the 'warble')."""
    s = [
        poly([(430, 640), (200, 770), (255, 805), (480, 690)], P["navy"]),          # tail
        poly([(560, 320), (600, 435), (470, 425)], P["navy2"]),                     # nape/back
        poly([(470, 425), (600, 435), (620, 645), (430, 640)], P["navy"]),          # body
        poly([(600, 435), (690, 410), (705, 520), (620, 645)], P["sky"]),           # chest
        poly([(690, 410), (705, 520), (650, 520)], P["sky2"]),                      # throat light
        poly([(560, 320), (650, 282), (735, 335), (690, 410), (600, 435)], P["teal"]),  # head
        poly([(560, 320), (650, 282), (610, 345)], P["cyan"]),                      # crown facet
        poly([(718, 326), (800, 352), (712, 375)], P["amber"]),                     # beak
        poly([(545, 425), (290, 560), (520, 610)], P["navy2"]),                     # wing
        poly([(545, 425), (370, 470), (290, 560)], P["teal"]),                      # wing facet
        poly([(545, 425), (520, 610), (600, 520)], P["cyan"], 0.85),                # wing inner
        '<circle cx="662" cy="342" r="15" fill="#ffffff"/><circle cx="666" cy="342" r="8" fill="%s"/>' % P["bg"],
        f'<path d="M575 645 L568 705 M615 645 L628 705" stroke="{P["navy"]}" stroke-width="12" stroke-linecap="round"/>',
        f'<path d="M470 712 L760 712" stroke="{P["slate"]}" stroke-width="14" stroke-linecap="round"/>',
    ]
    for i, r in enumerate((60, 105, 150)):  # sound arcs from the beak
        s.append(f'<path d="M {820 + r * 0.15:.0f} {352 - r * 0.55:.0f} A {r} {r} 0 0 1 {820 + r * 0.15:.0f} {352 + r * 0.55:.0f}" '
                 f'fill="none" stroke="{P["teal"] if i % 2 == 0 else P["violet"]}" stroke-width="14" stroke-linecap="round" opacity="{0.9 - i * 0.2:.2f}"/>')
    return "\n".join(s)

def mascot_starling():
    """Starling: speckled, iridescent mimic ('speaks the language of any flock')."""
    s = [
        poly([(420, 610), (240, 690), (290, 730), (470, 660)], P["navy"]),          # tail
        poly([(450, 420), (610, 400), (640, 620), (420, 610)], P["navy2"]),         # body
        poly([(610, 400), (700, 420), (690, 560), (640, 620)], P["teal"]),          # chest
        poly([(700, 420), (690, 560), (650, 500)], P["mint"], 0.9),                 # sheen
        poly([(540, 300), (650, 280), (730, 340), (700, 420), (610, 400), (530, 360)], P["navy"]),  # head
        poly([(540, 300), (650, 280), (600, 345)], P["violet"], 0.9),               # crown sheen
        poly([(720, 330), (830, 362), (716, 372)], P["amber"]),                     # long pointed beak
        poly([(560, 410), (300, 600), (540, 590)], P["heron"]),                     # wing
        poly([(560, 410), (380, 470), (300, 600)], P["violet"], 0.85),              # wing sheen
        poly([(560, 410), (540, 590), (620, 500)], P["teal"], 0.8),
        '<circle cx="668" cy="335" r="13" fill="#ffffff"/><circle cx="671" cy="335" r="7" fill="%s"/>' % P["bg"],
        f'<path d="M560 615 L552 690 M600 618 L612 690" stroke="{P["navy"]}" stroke-width="11" stroke-linecap="round"/>',
    ]
    rnd = random.Random(7)  # starling speckles
    for _ in range(26):
        x, y = rnd.uniform(470, 690), rnd.uniform(380, 600)
        if x + y < 1290 and x - y > -170:
            s.append(f'<path d="M{x:.0f} {y - 7:.0f} L{x + 5:.0f} {y:.0f} L{x:.0f} {y + 7:.0f} L{x - 5:.0f} {y:.0f}Z" fill="{P["text"]}" opacity="0.85"/>')
    s.append(f'<text x="770" y="560" font-family="JetBrains Mono, DejaVu Sans Mono, monospace" font-size="92" font-weight="700" fill="{P["cyan"]}">{{ }}</text>')
    return "\n".join(s)

def mascot_heron():
    """Heron (Heron Ops): tall, patient observer standing in the stream."""
    s = [
        poly([(560, 180), (690, 175), (720, 205), (600, 220)], P["heron"]),         # head top
        poly([(600, 220), (720, 205), (650, 245)], P["cyan"]),                      # face facet
        poly([(712, 196), (900, 214), (716, 222)], P["amber"]),                     # long bill
        poly([(560, 180), (470, 160), (575, 205)], P["navy2"]),                     # crest plume
        poly([(600, 220), (650, 245), (585, 330), (560, 300)], P["heron"]),         # neck upper
        poly([(560, 300), (585, 330), (610, 430), (570, 440)], P["navy2"]),         # neck lower
        poly([(570, 440), (610, 430), (660, 470), (600, 500)], P["sky"]),           # breast
        poly([(600, 500), (660, 470), (640, 590), (420, 610), (330, 560), (430, 470)], P["heron"]),  # body
        poly([(430, 470), (600, 500), (520, 560), (330, 560)], P["teal"], 0.9),     # wing
        poly([(330, 560), (240, 640), (380, 600)], P["navy"]),                      # tail
        '<circle cx="665" cy="200" r="8" fill="#ffffff"/>',
        f'<path d="M520 600 L505 870 M565 600 L590 870 M470 870 L540 870 M560 870 L630 870" stroke="{P["heron"]}" stroke-width="12" stroke-linecap="round"/>',
    ]
    for i, y in enumerate((880, 912, 944)):  # the stream it watches
        s.append(f'<path d="M{330 + i * 30} {y} q 45 -18 90 0 t 90 0 t 90 0 t 90 0" fill="none" stroke="{P["cyan"]}" stroke-width="10" stroke-linecap="round" opacity="{0.8 - i * 0.2:.2f}"/>')
    return "\n".join(s)

def flock(n, cx, cy, w, h, color, seed=1, size=(6, 16), opacity=(0.35, 0.95)):
    """Murmuration: n small chevron birds along a swirling ribbon."""
    rnd = random.Random(seed)
    out = []
    for i in range(n):
        t = rnd.random() * 2 * math.pi
        r = 0.55 + 0.45 * math.sin(3 * t) ** 2
        x = cx + w / 2 * math.cos(t) * r + rnd.gauss(0, w * 0.045)
        y = cy + h / 2 * math.sin(2 * t) * r * 0.8 + rnd.gauss(0, h * 0.05)
        sz = rnd.uniform(*size)
        a = math.degrees(math.atan2(math.cos(2 * t), -math.sin(t))) + rnd.uniform(-25, 25)
        op = rnd.uniform(*opacity)
        out.append(f'<path transform="translate({x:.1f} {y:.1f}) rotate({a:.0f}) scale({sz / 10:.2f})" '
                   f'd="M-10 -4 Q-4 -1 0 2 Q4 -1 10 -4 Q4 1 0 5 Q-4 1 -10 -4Z" fill="{color}" opacity="{op:.2f}"/>')
    return "\n".join(out)

def mascot_murmuration():
    """Murmuration: the whole flock moving as one, led by the Warble songbird."""
    return "\n".join([
        flock(260, 470, 470, 760, 520, P["teal"], seed=3, size=(10, 22)),
        flock(90, 470, 470, 700, 480, P["violet"], seed=4, size=(8, 18)),
        f'<g transform="translate(640 230) scale(0.40)">{mascot_warble()}</g>',
    ])

MASCOTS = {
    "warble": ("Warble", mascot_warble),
    "starling": ("Starling", mascot_starling),
    "heron": ("Heron", mascot_heron),
    "murmuration": ("Murmuration", mascot_murmuration),
}

# Edition -> mascot (each bird's documented metaphor; see README.md)
EDITIONS = [
    ("minimal", "Minimal", "warble", "Openbox · Firefox · Terminator"),
    ("developer", "Developer", "starling", "Go · Rust · Python · Node · Neovim"),
    ("cloud-native", "Cloud-Native", "heron", "Docker · kubectl · helm"),
    ("full", "Full", "murmuration", "Developer + Cloud-Native"),
]
SIZES = [(1920, 1080), (2560, 1440), (3840, 2160)]

def mascot_svg(key):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000" width="1000" height="1000">\n'
            f'<!-- Warble Linux mascot: {MASCOTS[key][0]} (original flat art, Warble Cloud) -->\n'
            f'{MASCOTS[key][1]()}\n</svg>\n')

def wallpaper_svg(ed, theme):
    slug, title, bird, tools = ed
    dark = theme == "dark"
    bg1, bg2, bg3 = (P["bg"], P["bg3"], P["bg4"]) if dark else (P["paper"], "#eef2ff", P["paper2"])
    fg, sub = (P["text"], P["muted"]) if dark else (P["ink"], P["slate"])
    glow = P["violet"] if dark else P["cyan"]
    fl_col = P["cyan"] if dark else P["navy"]
    logo_bg = '<circle cx="150" cy="140" r="78" fill="#ffffff" opacity="0.92"/>' if dark else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1920 1080" width="1920" height="1080">
<!-- Warble Linux wallpaper: {title} edition, {theme} ({MASCOTS[bird][0]}). Original art, Warble Cloud. -->
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{bg1}"/><stop offset="0.55" stop-color="{bg2}"/><stop offset="1" stop-color="{bg3}"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{glow}" stop-opacity="{0.35 if dark else 0.30}"/><stop offset="1" stop-color="{glow}" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="rule" x1="0" x2="1"><stop offset="0" stop-color="{P["teal"]}"/><stop offset="1" stop-color="{P["violet"]}"/></linearGradient>
</defs>
<rect width="1920" height="1080" fill="url(#bg)"/>
<circle cx="1440" cy="560" r="520" fill="url(#glow)"/>
{flock(170, 760, 330, 1100, 380, fl_col, seed=11, size=(5, 13), opacity=(0.12, 0.45) if dark else (0.10, 0.35))}
<g transform="translate(1040 160) scale(0.80)">{MASCOTS[bird][1]()}</g>
{logo_bg}<image x="88" y="93" width="124" height="93" xlink:href="../source/warble-cloud-icon-512.png"/>
<text x="120" y="860" font-family="Inter, Noto Sans, DejaVu Sans, sans-serif" font-size="84" font-weight="800" fill="{fg}" letter-spacing="-1">Warble Linux</text>
<rect x="124" y="888" width="220" height="6" rx="3" fill="url(#rule)"/>
<text x="122" y="950" font-family="Inter, Noto Sans, DejaVu Sans, sans-serif" font-size="34" font-weight="600" fill="{fg}">{title} edition · {MASCOTS[bird][0]}</text>
<text x="122" y="996" font-family="Inter, Noto Sans, DejaVu Sans, sans-serif" font-size="26" fill="{sub}">{tools} · disposable live sandbox</text>
</svg>
'''

def render(svg_path, out_png, w, h):
    """Render an SVG file (relative image links resolve from svg/)."""
    try:
        import resvg_py  # type: ignore
        data = resvg_py.svg_to_bytes(svg_path=svg_path, width=w, height=h, resources_dir=SVG_DIR)
        with open(out_png, "wb") as f:
            f.write(bytes(data))
        return
    except ImportError:
        pass
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", out_png, svg_path], check=True)
        return
    sys.exit("no SVG renderer: pip install resvg-py, or install rsvg-convert")

def main():
    svg_only = "--svg-only" in sys.argv
    os.makedirs(SVG_DIR, exist_ok=True)
    os.makedirs(os.path.join(PNG_DIR, "mascots"), exist_ok=True)
    os.makedirs(os.path.join(PNG_DIR, "wallpapers"), exist_ok=True)
    for key in MASCOTS:
        path = os.path.join(SVG_DIR, f"mascot-{key}.svg")
        open(path, "w").write(mascot_svg(key))
        if not svg_only:
            render(path, os.path.join(PNG_DIR, "mascots", f"mascot-{key}-1024.png"), 1024, 1024)
    for ed in EDITIONS:
        for theme in ("dark", "light"):
            path = os.path.join(SVG_DIR, f"wallpaper-{ed[0]}-{theme}.svg")
            open(path, "w").write(wallpaper_svg(ed, theme))
            if not svg_only:
                for w, h in SIZES:
                    render(path, os.path.join(PNG_DIR, "wallpapers", f"warble-linux-{ed[0]}-{theme}-{w}x{h}.png"), w, h)
    # Live ISO copies: the size the desktop uses (feh scales to the screen)
    dest = os.path.join(HERE, "..", "..", "profile", "airootfs", "usr", "share", "backgrounds", "warble")
    if not svg_only:
        os.makedirs(dest, exist_ok=True)
        for ed in EDITIONS:
            for theme in ("dark", "light"):
                name = f"warble-linux-{ed[0]}-{theme}-2560x1440.png"
                shutil.copyfile(os.path.join(PNG_DIR, "wallpapers", name), os.path.join(dest, name))
    print("ok")

if __name__ == "__main__":
    main()
