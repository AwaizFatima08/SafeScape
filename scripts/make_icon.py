#!/usr/bin/env python3
"""Draw Sammy the Turtle's app icon (no generative art) and write:

  android/app/src/main/res/mipmap-*/ic_launcher.png          legacy icons
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png adaptive foreground
  android/app/src/main/res/drawable/splash_sammy.png         launch screen
  store-assets/icon-512.png                                  Play Store icon
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
SLATE = (18, 19, 28)
LAVENDER = (157, 141, 241)
MINT = (144, 219, 183)
SHELL = (127, 200, 169)
PLATE = (99, 174, 144)
RIM = (232, 211, 154)
SKIN = (169, 216, 166)
SKIN_DARK = (134, 191, 134)
INK = (43, 45, 58)
BLUSH = (242, 184, 160)
S = 1024  # master canvas


def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.pi / 6 + i * math.pi / 3), cy + r * math.sin(math.pi / 6 + i * math.pi / 3)) for i in range(6)]


def turtle(size=S, scale=1.0):
    """Sammy on a transparent canvas, centred, occupying ~`scale` of the width."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = size / 200 * scale
    ox = size / 2 - 113 * k  # artwork spans x 18..208
    oy = size / 2 - 86 * k

    def P(x, y):
        return (ox + x * k, oy + y * k)

    def R(x0, y0, x1, y1):
        return [P(x0, y0), P(x1, y1)]

    for x in (52, 132):
        d.rounded_rectangle(R(x, 100, x + 26, 128), radius=12 * k, fill=SKIN_DARK)
    for x in (68, 148):
        d.rounded_rectangle(R(x, 102, x + 26, 130), radius=12 * k, fill=SKIN)
    d.polygon([P(40, 104), P(18, 116), P(46, 112)], fill=SKIN)
    # head + neck
    hx, hy = 184, 72
    d.rounded_rectangle(R(hx - 34, hy + 4, hx + 6, hy + 30), radius=13 * k, fill=SKIN)
    d.ellipse(R(hx - 24, hy - 24, hx + 24, hy + 24), fill=SKIN)
    d.ellipse(R(hx + 3.4, hy - 9.6, hx + 12.6, hy - 0.4), fill=INK)
    d.ellipse(R(hx + 8, hy - 8.2, hx + 11.2, hy - 5), fill=(247, 244, 234))
    d.ellipse(R(hx - 3, hy + 4, hx + 7, hy + 10), fill=BLUSH)
    d.arc(R(hx + 8, hy + 2, hx + 18, hy + 10), start=10, end=140, fill=INK, width=max(2, int(3 * k)))
    # shell dome (polygon approximation of a cubic dome)
    pts = []
    for i in range(61):
        t = i / 60
        x = (1 - t) ** 3 * 34 + 3 * (1 - t) ** 2 * t * 34 + 3 * (1 - t) * t ** 2 * 166 + t ** 3 * 166
        y = (1 - t) ** 3 * 108 + 3 * (1 - t) ** 2 * t * 40 + 3 * (1 - t) * t ** 2 * 40 + t ** 3 * 108
        pts.append(P(x, y))
    shell_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(shell_mask).polygon(pts, fill=255)
    shell = Image.new("RGBA", (size, size), SHELL + (255,))
    sd = ImageDraw.Draw(shell)
    for cx, cy, r in ((100, 62, 17), (68, 88, 15), (132, 88, 15), (100, 100, 15)):
        sd.polygon([P(x, y) for x, y in hexagon(cx, cy, r)], fill=PLATE)
    sd.ellipse(R(58, 50, 108, 66), fill=(160, 220, 195))
    im.paste(shell, (0, 0), shell_mask)
    d.rounded_rectangle(R(28, 102, 172, 114), radius=6 * k, fill=RIM)
    return im


def background(size):
    bg = Image.new("RGBA", (size, size), SLATE + (255,))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    r = size * 0.36
    g.ellipse([size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r], fill=LAVENDER + (90,))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.08))
    bg.alpha_composite(glow)
    return bg


def full_icon(size, scale=0.78):
    im = background(S)
    im.alpha_composite(turtle(S, scale))
    return im.resize((size, size), Image.LANCZOS)


def main():
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    master_fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # Adaptive foreground: keep Sammy inside the 66% safe zone.
    master_fg.alpha_composite(turtle(S, 0.58))
    for name, f in densities.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy = full_icon(int(48 * f))
        mask = Image.new("L", legacy.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, legacy.width - 1, legacy.height - 1], radius=legacy.width * 0.22, fill=255)
        out = Image.new("RGBA", legacy.size, (0, 0, 0, 0))
        out.paste(legacy, (0, 0), mask)
        out.save(folder / "ic_launcher.png")
        master_fg.resize((int(108 * f),) * 2, Image.LANCZOS).save(folder / "ic_launcher_foreground.png")
    (RES / "drawable").mkdir(exist_ok=True)
    turtle(S, 0.9).resize((288, 288), Image.LANCZOS).save(RES / "drawable/splash_sammy.png")
    store = ROOT / "store-assets"
    store.mkdir(exist_ok=True)
    full_icon(512).convert("RGB").save(store / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()
