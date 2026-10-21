#!/usr/bin/env python3
"""Renders every launcher icon from one mark: a sky-blue coin with a navy B on the app navy.

Run from the repo root:  python3 tool/branding/generate_icons.py
Needs Pillow. The letter uses the bundled Noto Sans Bold (SIL OFL).
Android only: the app is not built for iOS yet.
"""
import os
from PIL import Image, ImageDraw, ImageFont

NAVY, SKY = (0x2B, 0x38, 0x5A), (0x73, 0xB7, 0xF1)
FONT = "assets/fonts/NotoSans-Bold.ttf"
RES = "android/app/src/main/res"
SS = 4  # draw 4x and scale down for smooth edges


def mark(size, coin=0.62, color=SKY, letter=NAVY, transparent_letter=False, bg=None):
    """The coin centred on a size x size canvas; coin is its diameter as a fraction of size."""
    s = size * SS
    img = Image.new("RGBA", (s, s), bg or (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = s * coin / 2
    c = s / 2
    d.ellipse((c - r, c - r, c + r, c + r), fill=color + (255,))
    ring = r * 0.82
    d.ellipse((c - ring, c - ring, c + ring, c + ring), outline=letter + (255,), width=max(2, int(r * 0.05)))
    font = ImageFont.truetype(FONT, int(r * 1.15))
    letter_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(letter_layer).text((c, c), "B", font=font, anchor="mm", fill=letter + (255,))
    if transparent_letter:  # for the themed (monochrome) icon: the letter is a hole
        alpha = img.getchannel("A")
        hole = letter_layer.getchannel("A")
        alpha = Image.composite(Image.new("L", (s, s), 0), alpha, hole)
        img.putalpha(alpha)
    else:
        img = Image.alpha_composite(img, letter_layer)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def rounded(img, radius_frac):
    size = img.size[0]
    m = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size * SS - 1, size * SS - 1), radius=int(size * SS * radius_frac), fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out


densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, k in densities.items():
    d = f"{RES}/mipmap-{name}"
    legacy = int(48 * k)
    save(rounded(mark(legacy, coin=0.66, bg=NAVY + (255,)), 0.22), f"{d}/ic_launcher.png")
    fg = int(108 * k)
    save(mark(fg, coin=0.50), f"{d}/ic_launcher_foreground.png")  # inside the 66dp safe zone
    save(mark(fg, coin=0.50, color=(255, 255, 255), transparent_letter=True), f"{d}/ic_launcher_monochrome.png")

os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
open(f"{RES}/mipmap-anydpi-v26/ic_launcher.xml", "w").write(
    """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
"""
)
open(f"{RES}/values/ic_launcher_background.xml", "w").write(
    """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2B385A</color>
</resources>
"""
)
save(mark(512, coin=0.66, bg=NAVY + (255,)).convert("RGB"), "docs/store/play_icon_512.png")
print("icons written")
