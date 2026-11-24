#!/usr/bin/env python3
"""Draw the I Want My MTV icon: a retro TV with a rewind symbol on black, in the
site's MTV Rewind palette (lilac, mustard, red, salmon, light blue, pink-to-blue).

An original design (no MTV logo). Usage: make-app-icon.py <output.png>
(1024x1024 opaque PNG; also writes a 240x240 copy for the loading screen
when a second path is given). Needs Pillow.
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 1024
BLACK = (0, 0, 0)
BODY = (0xAD, 0xC9, 0xEB)  # light blue
SCREEN = (0x10, 0x25, 0x4D)  # navy
PINK = (0xE4, 0x71, 0xBF)
YELLOW = (0xF4, 0xB9, 0x40)
CYAN = (0x69, 0xB0, 0xEF)
INK = (0x14, 0x14, 0x20)
RED = (0xC7, 0x2E, 0x20)
SALMON = (0xEE, 0x88, 0x87)
LILAC = (0xD1, 0xA1, 0xD2)

img = Image.new("RGB", (S, S), BLACK)

# Neon glow behind the TV.
glow = Image.new("RGB", (S, S), BLACK)
gd = ImageDraw.Draw(glow)
gd.ellipse((120, 220, 620, 900), fill=LILAC)
gd.ellipse((420, 220, 920, 900), fill=(0x2F, 0x5E, 0xB0))
img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(150)), 0.45)
d = ImageDraw.Draw(img)

# Antennas.
d.line((512, 300, 370, 150), fill=INK, width=34)
d.line((512, 300, 654, 150), fill=INK, width=34)
d.line((512, 300, 370, 150), fill=LILAC, width=20)
d.line((512, 300, 654, 150), fill=LILAC, width=20)
d.ellipse((338, 118, 402, 182), fill=YELLOW, outline=INK, width=8)
d.ellipse((622, 118, 686, 182), fill=YELLOW, outline=INK, width=8)

# Body and feet.
d.rounded_rectangle((250, 790, 330, 878), radius=20, fill=BODY, outline=INK, width=12)
d.rounded_rectangle((694, 790, 774, 878), radius=20, fill=BODY, outline=INK, width=12)
d.rounded_rectangle((166, 306, 890, 836), radius=90, fill=INK)  # hard drop shadow
d.rounded_rectangle((150, 290, 874, 820), radius=90, fill=BODY, outline=INK, width=14)

# Screen with scanlines.
sx0, sy0, sx1, sy1 = 210, 350, 714, 760
d.rounded_rectangle((sx0, sy0, sx1, sy1), radius=60, fill=SCREEN, outline=INK, width=12)
for y in range(sy0 + 30, sy1 - 20, 14):
    d.line((sx0 + 30, y, sx1 - 30, y), fill=(0x18, 0x33, 0x63), width=4)

# Rewind symbol: two triangles, pink and cyan, with a yellow offset shadow.
cx, cy = (sx0 + sx1) // 2, (sy0 + sy1) // 2
h = 120
w = 150


def rewind(dx, dy, colors):
    for i, color in enumerate(colors):
        x = cx + 68 - i * w + dx
        d.polygon(
            [(x + w // 2, cy - h + dy), (x + w // 2, cy + h + dy), (x - w // 2, cy + dy)],
            fill=color, outline=INK if dx == 0 else None, width=8 if dx == 0 else 0,
        )


rewind(14, 14, (INK, INK))
rewind(0, 0, (PINK, CYAN))

# Knobs.
d.ellipse((752, 400, 822, 470), fill=YELLOW, outline=INK, width=8)
d.ellipse((752, 510, 822, 580), fill=RED, outline=INK, width=8)
for y in (630, 670, 710):
    d.rounded_rectangle((752, y, 822, y + 16), radius=8, fill=INK)

img.save(sys.argv[1], "PNG")
if len(sys.argv) > 2:
    img.resize((240, 240), Image.LANCZOS).save(sys.argv[2], "PNG")
