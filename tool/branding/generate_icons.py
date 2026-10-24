#!/usr/bin/env python3
"""Renders every launcher icon from one mark: a glass coin with a navy B on the app's deep navy ground.

Run from the repo root:  python3 tool/branding/generate_icons.py
Needs Pillow. The letter uses the bundled Noto Sans Bold (SIL OFL).
Android only: the app is not built for iOS yet.
"""
import os
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

NAVY, SKY = (0x2B, 0x38, 0x5A), (0x73, 0xB7, 0xF1)
NAVY_DEEP = (0x14, 0x20, 0x4A)
FONT = "assets/fonts/NotoSans-Bold.ttf"
RES = "android/app/src/main/res"
SS = 4  # draw 4x and scale down for smooth edges


def ground(size):
    """Deep navy with a soft glow at the top right, like the app's own backdrop."""
    y, x = np.mgrid[0:size, 0:size] / (size - 1)
    base = np.array((0x0A, 0x10, 0x24), float)
    glow = np.array((0x3D, 0x4B, 0x78), float)
    t = np.clip(1.1 - np.hypot(x - 0.85, y - 0.1) * 1.3, 0, 1)[..., None]
    rgb = base + (glow - base) * t
    a = np.clip(0.9 - np.hypot(x - 0.1, y - 0.55) * 1.4, 0, 1)[..., None] * 0.18
    rgb = rgb + (np.array(SKY, float) - rgb) * a
    return Image.fromarray(rgb.astype("uint8"), "RGB").convert("RGBA")


def mark(size, coin=0.62, shadow=True, mono=False):
    """A glass coin: lit sky-blue gradient, bright rim, specular crescent, soft shadow."""
    s = size * SS
    c = s / 2
    r = s * coin / 2
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    disc = Image.new("L", (s, s), 0)
    ImageDraw.Draw(disc).ellipse((c - r, c - r, c + r, c + r), fill=255)
    if shadow and not mono:
        sh = Image.new("L", (s, s), 0)
        ImageDraw.Draw(sh).ellipse((c - r * 0.92, c - r * 0.92 + r * 0.16, c + r * 0.92, c + r * 0.92 + r * 0.16), fill=150)
        sh = sh.filter(ImageFilter.GaussianBlur(r * 0.12))
        out.paste(Image.new("RGBA", (s, s), (3, 6, 20, 255)), (0, 0), sh)
    y, x = np.mgrid[0:s, 0:s] / (s - 1)
    t = np.clip(((x - 0.5) * 0.6 + (y - 0.5) * 0.8) / (coin * 1.0) + 0.5, 0, 1)[..., None]
    top, mid, bot = np.array((0xC9, 0xE6, 0xFF), float), np.array(SKY, float), np.array((0x3F, 0x84, 0xD0), float)
    rgb = np.where(t < 0.5, top + (mid - top) * (t * 2), mid + (bot - mid) * ((t - 0.5) * 2))
    if mono:
        rgb = np.full_like(rgb, 255)
    face = Image.fromarray(rgb.astype("uint8"), "RGB").convert("RGBA")
    out.paste(face, (0, 0), disc)
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if not mono:
        w = max(2, int(r * 0.035))
        d.ellipse((c - r, c - r, c + r, c + r), outline=(255, 255, 255, 190), width=w)
        ring = r * 0.80
        d.ellipse((c - ring, c - ring, c + ring, c + ring), outline=(255, 255, 255, 90), width=max(2, int(r * 0.025)))
        spec = Image.new("L", (s, s), 0)
        ImageDraw.Draw(spec).ellipse((c - r * 0.9, c - r * 1.05, c + r * 0.55, c - r * 0.1), fill=110)
        spec = ImageChops.multiply(spec.filter(ImageFilter.GaussianBlur(r * 0.08)), disc)
        glint = Image.new("RGBA", (s, s), (255, 255, 255, 255))
        glint.putalpha(spec)
        layer = Image.alpha_composite(layer, glint)
    out = Image.alpha_composite(out, layer)
    font = ImageFont.truetype(FONT, int(r * 1.12))
    letter = Image.new("L", (s, s), 0)
    ImageDraw.Draw(letter).text((c, c + r * 0.02), "B", font=font, anchor="mm", fill=255)
    if mono:  # themed icon: the letter is a hole
        out.putalpha(ImageChops.subtract(out.getchannel("A"), letter))
    else:
        out.paste(Image.new("RGBA", (s, s), NAVY_DEEP + (255,)), (0, 0), letter.point(lambda v: int(v * 0.92)))
    return out.resize((size, size), Image.LANCZOS)


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
    plate = Image.alpha_composite(ground(legacy), mark(legacy, coin=0.66))
    save(rounded(plate, 0.22), f"{d}/ic_launcher.png")
    fg = int(108 * k)
    save(ground(fg), f"{d}/ic_launcher_background.png")
    save(mark(fg, coin=0.50), f"{d}/ic_launcher_foreground.png")  # inside the 66dp safe zone
    save(mark(fg, coin=0.50, mono=True), f"{d}/ic_launcher_monochrome.png")

os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
open(f"{RES}/mipmap-anydpi-v26/ic_launcher.xml", "w").write(
    """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
"""
)
if os.path.exists(f"{RES}/values/ic_launcher_background.xml"):
    os.remove(f"{RES}/values/ic_launcher_background.xml")  # replaced by the mipmap background
save(Image.alpha_composite(ground(512), mark(512, coin=0.66)).convert("RGB"), "docs/store/play_icon_512.png")
print("icons written")
