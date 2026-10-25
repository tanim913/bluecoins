#!/usr/bin/env python3
"""Renders every launcher icon from tool/branding/icon-source.jpg: a glass tile with a wallet and
banknotes on deep navy.

Run from the repo root:  python3 tool/branding/generate_icons.py
Needs Pillow and numpy. Android only: the app is not built for iOS yet.
"""
import os
import numpy as np
from PIL import Image, ImageDraw

SRC = "tool/branding/icon-source.jpg"
RES = "android/app/src/main/res"
CX, CY, TILE = 622, 619, 959  # centre and width of the glass tile inside the 1254px source

src = Image.open(SRC).convert("RGB")


def crop(half):
    return src.crop((CX - half, CY - half, CX + half, CY + half))


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def rounded(img, frac):
    n = img.size[0]
    m = Image.new("L", (n * 4, n * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, n * 4 - 1, n * 4 - 1), radius=int(n * 4 * frac), fill=255)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(img, (0, 0), m.resize((n, n), Image.LANCZOS))
    return out


# Mean colour of the source's outer ring: the adaptive background, hidden behind the tile.
a = np.asarray(src).astype(float)
ring = np.concatenate([a[:20].reshape(-1, 3), a[-20:].reshape(-1, 3), a[:, :20].reshape(-1, 3), a[:, -20:].reshape(-1, 3)])
BG = tuple(int(v) for v in ring.mean(0))

# Adaptive layers are 108dp; the tile gets 60dp so no launcher mask (circle, squircle) trims it.
SCALE = 60 / TILE  # dp per source pixel


def foreground(px, mono=False):
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    w = int(src.size[0] * SCALE * px / 108)
    layer = src.resize((w, w), Image.LANCZOS)
    off = (px - w) // 2 + int((src.size[0] / 2 - CX) * SCALE * px / 108), (px - w) // 2 + int((src.size[1] / 2 - CY) * SCALE * px / 108)
    if mono:  # themed icon: brightness of the glass becomes the shape, drawn in white
        lum = np.asarray(layer.convert("L")).astype(float)
        alpha = np.clip((lum - 45) / 110, 0, 1) * 255
        layer = Image.merge("RGBA", (*(Image.new("L", layer.size, 255),) * 3, Image.fromarray(alpha.astype("uint8"))))
    canvas.paste(layer, off, layer if mono else None)
    return canvas


densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, k in densities.items():
    d = f"{RES}/mipmap-{name}"
    save(rounded(crop(560).resize((int(48 * k),) * 2, Image.LANCZOS), 0.22), f"{d}/ic_launcher.png")
    fg = int(108 * k)
    save(Image.new("RGB", (fg, fg), BG), f"{d}/ic_launcher_background.png")
    save(foreground(fg), f"{d}/ic_launcher_foreground.png")
    save(foreground(fg, mono=True), f"{d}/ic_launcher_monochrome.png")

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
store = crop(620).resize((512, 512), Image.LANCZOS)
save(store, "docs/store/play_icon_512.png")
save(store.resize((256, 256), Image.LANCZOS), "docs/icon.png")
print("icons written")
