#!/usr/bin/env python3
"""Draw the I Want My MTV icon: a retro TV with a neon rewind symbol on black.

An original design (no MTV logo). Usage: make-app-icon.py <output.png>
(1024x1024 opaque PNG; also writes a 240x240 copy for the loading screen
when a second path is given). Needs Pillow.
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 1024
BLACK = (0, 0, 0)
BODY = (0xF4, 0xF0, 0xE8)
SCREEN = (0x14, 0x10, 0x24)
PINK = (0xFF, 0x2D, 0x95)
YELLOW = (0xFF, 0xE1, 0x3B)
CYAN = (0x2B, 0xE8, 0xFF)

img = Image.new("RGB", (S, S), BLACK)

# Neon glow behind the TV.
glow = Image.new("RGB", (S, S), BLACK)
gd = ImageDraw.Draw(glow)
gd.ellipse((120, 220, 620, 900), fill=PINK)
gd.ellipse((420, 220, 920, 900), fill=CYAN)
img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(150)), 0.45)
d = ImageDraw.Draw(img)

# Antennas.
d.line((512, 300, 370, 150), fill=BODY, width=26)
d.line((512, 300, 654, 150), fill=BODY, width=26)
d.ellipse((344, 124, 396, 176), fill=YELLOW)
d.ellipse((628, 124, 680, 176), fill=YELLOW)

# Body and feet.
d.rounded_rectangle((150, 290, 874, 820), radius=90, fill=BODY)
d.rounded_rectangle((250, 800, 330, 870), radius=20, fill=BODY)
d.rounded_rectangle((694, 800, 774, 870), radius=20, fill=BODY)

# Screen with scanlines.
sx0, sy0, sx1, sy1 = 210, 350, 714, 760
d.rounded_rectangle((sx0, sy0, sx1, sy1), radius=60, fill=SCREEN)
for y in range(sy0 + 30, sy1 - 20, 14):
    d.line((sx0 + 30, y, sx1 - 30, y), fill=(0x22, 0x1C, 0x38), width=4)

# Rewind symbol: two triangles, pink and cyan, with a yellow offset shadow.
cx, cy = (sx0 + sx1) // 2, (sy0 + sy1) // 2
h = 120
w = 150


def rewind(dx, dy, colors):
    for i, color in enumerate(colors):
        x = cx + 68 - i * w + dx
        d.polygon([(x + w // 2, cy - h + dy), (x + w // 2, cy + h + dy), (x - w // 2, cy + dy)], fill=color)


rewind(14, 14, (YELLOW, YELLOW))
rewind(0, 0, (PINK, CYAN))

# Knobs.
d.ellipse((752, 400, 822, 470), fill=PINK)
d.ellipse((752, 510, 822, 580), fill=CYAN)
for y in (630, 670, 710):
    d.rounded_rectangle((752, y, 822, y + 16), radius=8, fill=SCREEN)

img.save(sys.argv[1], "PNG")
if len(sys.argv) > 2:
    img.resize((240, 240), Image.LANCZOS).save(sys.argv[2], "PNG")
