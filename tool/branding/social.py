#!/usr/bin/env python3
"""Renders docs/social.png (1200x630 link-preview card) from the icon, the app screenshot and the name.

Run from the repo root after generate_icons.py:  python3 tool/branding/social.py
Needs the review screenshot .impeccable/review/phone-dark-home.png (SCREENSHOTS=1 flutter test test/screenshots).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1200, 630
gy, gx = np.mgrid[0:H, 0:W]
y, x = gy / (H - 1), gx / (W - 1)
base, glow, sky = np.array((0x0c, 0x13, 0x29), float), np.array((0x3d, 0x4b, 0x78), float), np.array((0x73, 0xb7, 0xf1), float)
t = np.clip(1.15 - np.hypot((x - 0.95) * 1.9, y), 0, 1)[..., None]
rgb = base + (glow - base) * t
a = np.clip(0.9 - np.hypot((x - 0.05) * 1.9, y - 0.75) * 1.3, 0, 1)[..., None] * 0.16
bg = Image.fromarray((rgb + (sky - rgb) * a).astype("uint8"), "RGB").convert("RGBA")

pw = 360
shot = Image.open(".impeccable/review/phone-dark-home.png").convert("RGB").crop((0, 0, 1080, 2160))
ph = int(pw * 2)
shot = shot.resize((pw, ph), Image.LANCZOS)
mask = Image.new("L", (pw, ph), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, pw - 1, ph - 1), radius=38, fill=255)
px, py = 770, 60
sd = Image.new("L", (W, H), 0)
ImageDraw.Draw(sd).rounded_rectangle((px, py + 18, px + pw, py + ph + 18), radius=38, fill=140)
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
shadow.paste((2, 5, 16, 255), (0, 0), sd.filter(ImageFilter.GaussianBlur(26)))
bg = Image.alpha_composite(bg, shadow)
bg.paste(shot, (px, py), mask)
edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(edge).rounded_rectangle((px, py, px + pw, py + ph), radius=38, outline=(255, 255, 255, 90), width=2)
bg = Image.alpha_composite(bg, edge)

icon = Image.open("docs/store/play_icon_512.png").convert("RGB").resize((96, 96), Image.LANCZOS)
im = Image.new("L", (96, 96), 0)
ImageDraw.Draw(im).rounded_rectangle((0, 0, 95, 95), radius=24, fill=255)
bg.paste(icon, (72, 76), im)
d = ImageDraw.Draw(bg)
bold, reg = "assets/fonts/NotoSans-Bold.ttf", "assets/fonts/NotoSans-Regular.ttf"
h, s, b, nm = (ImageFont.truetype(bold, 68), ImageFont.truetype(reg, 31), ImageFont.truetype(bold, 27), ImageFont.truetype(bold, 40))
d.text((186, 106), "Enough", font=nm, fill=(255, 255, 255))
d.text((72, 200), "Do you have", font=h, fill=(255, 255, 255))
d.text((72, 278), "enough for today?", font=h, fill=(255, 255, 255))
d.text((72, 400), "Type the balance you have left.", font=s, fill=(195, 203, 226))
d.text((72, 445), "Enough works out the rest.", font=s, fill=(195, 203, 226))
d.rounded_rectangle((72, 520, 372, 584), radius=18, fill=(115, 183, 241))
d.text((222, 552), "Free for Android", font=b, fill=(20, 32, 63), anchor="mm")
bg.convert("RGB").save("docs/social.png", optimize=True)
