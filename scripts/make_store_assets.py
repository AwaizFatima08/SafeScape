#!/usr/bin/env python3
"""Play Store feature graphic (1024 x 500), drawn in code with Sammy.

Screenshots come from the emulator (scripts/take_screenshots.sh).
"""
import math
import pathlib
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import make_icon

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT_BOLD = str(ROOT / "assets/fonts/Andika-Bold.ttf")
FONT = str(ROOT / "assets/fonts/Andika-Regular.ttf")
SLATE = (18, 19, 28)
TEXT = (232, 230, 240)
DIM = (169, 167, 186)
TONES = [(157, 141, 241), (144, 219, 183), (244, 228, 186), (137, 207, 240)]


def feature_graphic():
    W, H = 1024, 500
    im = Image.new("RGBA", (W, H), SLATE + (255,))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    rnd = random.Random(3)
    # Soft ripples and particles like the Flow Canvas.
    for i in range(7):
        cx, cy, r = 760 + rnd.randint(-120, 120), 250 + rnd.randint(-120, 120), rnd.randint(40, 170)
        g.ellipse([cx - r, cy - r, cx + r, cy + r], outline=TONES[i % 4] + (70,), width=5)
    for _ in range(160):
        a = rnd.random() * 2 * math.pi
        d = rnd.random() ** 0.6 * 300
        x, y = 760 + math.cos(a) * d * 1.2, 250 + math.sin(a) * d * 0.8
        r = rnd.uniform(2, 7)
        c = TONES[rnd.randrange(4)]
        g.ellipse([x - r * 3, y - r * 3, x + r * 3, y + r * 3], fill=c + (30,))
        g.ellipse([x - r, y - r, x + r, y + r], fill=c + (170,))
    glow = glow.filter(ImageFilter.GaussianBlur(1.2))
    im.alpha_composite(glow)
    # Breathing ring + Sammy.
    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([760 - 150, 250 - 150, 760 + 150, 250 + 150], fill=(157, 141, 241, 36), outline=(157, 141, 241, 150), width=6)
    im.alpha_composite(ring)
    sammy = make_icon.turtle(1024, 0.9).resize((330, 330), Image.LANCZOS)
    im.alpha_composite(sammy, (760 - 165, 250 - 150))
    d = ImageDraw.Draw(im)
    d.text((64, 128), "Sensory", font=ImageFont.truetype(FONT_BOLD, 64), fill=TONES[0])
    d.text((64, 196), "SafeScape", font=ImageFont.truetype(FONT_BOLD, 76), fill=TEXT)
    d.text((66, 300), "Calm sensory play & visual routines", font=ImageFont.truetype(FONT, 30), fill=DIM)
    d.text((66, 342), "for sensitive, neurodivergent kids", font=ImageFont.truetype(FONT, 30), fill=DIM)
    out = ROOT / "store-assets"
    out.mkdir(exist_ok=True)
    im.convert("RGB").save(out / "feature-graphic-1024x500.png")
    print("feature graphic written")


def fit_screenshots():
    """Play rejects screenshots whose long side is more than twice the short
    side. Modern phones are ~2.22:1, so pad the sides with the app's slate
    colour to exactly 2:1 (nothing is cropped). Writes to screenshots-play/."""
    src_root = ROOT / "store-assets/screenshots"
    for src in sorted(src_root.rglob("*.png")):
        im = Image.open(src).convert("RGB")
        w, h = im.size
        # Hide the phone's status bar (notification icons, battery level):
        # every SafeScape screen is plain slate there, so this only removes
        # system chrome, never app content.
        ImageDraw.Draw(im).rectangle([0, 0, w, int(h * 0.0275)], fill=SLATE)
        if h > 2 * w:
            canvas = Image.new("RGB", (h // 2, h), SLATE)
            canvas.paste(im, ((h // 2 - w) // 2, 0))
            im = canvas
        out = ROOT / "store-assets/screenshots-play" / src.relative_to(src_root)
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out)
        print(f"{out.relative_to(ROOT)}: {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    feature_graphic()
    fit_screenshots()
