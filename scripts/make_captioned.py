#!/usr/bin/env python3
"""Captioned Play screenshots for SafeScape v1.2 (8 = Play's phone maximum).

Same look as homilabs_site/social/kids-captioned/build.py (which made the
v1.1 set): purple gradient, English headline in Fredoka, Urdu in Noto
Nastaliq, the screen in a rounded frame. Rendered with headless Chrome.

    python3 scripts/make_captioned.py [source-dir]
Source: store-assets/screenshots-play/phone-v12 (run make_store_assets.py first).
Output: store-assets/captioned/NN_name.jpg (the previous set is replaced).
"""
import pathlib
import subprocess
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "store-assets/screenshots-play/phone-v12"
OUT = ROOT / "store-assets/captioned"
FONT = pathlib.Path("/usr/share/fonts/truetype/noto/NotoNastaliqUrdu-Regular.ttf")
BG, FG, UR = "linear-gradient(170deg,#3B3466 0%,#1E1B33 100%)", "#F4F1FF", "#B7F0D2"

# (screenshot, English, Urdu). The v1.1 captions are kept word for word; the
# two marked NEW are v1.2 and need the owner's review of the Urdu.
ITEMS = [
    ("03_canvas", "Touch, breathe, calm down", "چھوئیں، سانس لیں، سکون پائیں"),
    ("11_lessons", "Learn calm skills with Sammy", "سیمی کے ساتھ سکون کے طریقے سیکھیں"),  # NEW
    ("15_story", "Picture stories for big days", "بڑے دنوں کے لیے تصویری کہانیاں"),  # NEW
    ("05_routine", "Picture routines: first… then…", "تصویری معمولات: پہلے… پھر…"),
    ("04_routines", "Doctor, haircut, school, bedtime", "ڈاکٹر، بال، اسکول، سونا"),
    ("06_sounds", "Soft sounds, sharp pitches filtered", "نرم، فلٹر شدہ آوازیں"),
    ("07_wait", "A gentle wait timer — no alarms", "انتظار کا نرم ٹائمر"),
    ("02_hub", "Low-glare colours, no flashing", "کم چمک، کوئی فلیش نہیں"),
]

CSS = """@font-face{{font-family:Nast;src:url('{font}')}}
html,body{{margin:0;width:1080px;height:1920px;overflow:hidden}}
body{{background:{bg};color:{fg};text-align:center;font-family:'Fredoka','Baloo 2',sans-serif}}
.en{{font-size:72px;font-weight:700;line-height:1.1;padding:100px 70px 0}}
.ur{{font-family:Nast;font-size:48px;line-height:2;color:{ur};direction:rtl;margin-top:10px}}
.shot{{position:absolute;left:50%;transform:translateX(-50%);top:470px;width:640px;border-radius:54px;background:#111;padding:14px;box-shadow:0 30px 70px rgba(0,0,0,.35)}}
.shot img{{display:block;width:100%;border-radius:40px}}"""


def main():
    missing = [n for n, _, _ in ITEMS if not (SRC / f"{n}.png").exists()]
    if missing:
        sys.exit(f"missing screenshots in {SRC}: {missing}")
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.jpg"):
        old.unlink()
    css = CSS.format(font=FONT.as_uri(), bg=BG, fg=FG, ur=UR)
    for i, (name, en, ur) in enumerate(ITEMS, 1):
        page = OUT / f"_{i}.html"
        page.write_text(
            '<!doctype html><html><head><meta charset="utf-8">'
            '<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@600;700&display=block" rel="stylesheet">'
            f'<style>{css}</style></head><body><div class="en">{en}</div><div class="ur">{ur}</div>'
            f'<div class="shot"><img src="{(SRC / f"{name}.png").as_uri()}"></div></body></html>',
            encoding="utf-8")
        png = OUT / f"{i:02d}_{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=1", "--allow-file-access-from-files",
                        "--virtual-time-budget=8000", "--window-size=1080,1920", f"--screenshot={png}",
                        page.as_uri()], check=True, capture_output=True)
        page.unlink()
        Image.open(png).convert("RGB").save(png.with_suffix(".jpg"), quality=88, optimize=True)
        png.unlink()
        print(f"{i:02d}_{name}.jpg")


if __name__ == "__main__":
    main()
