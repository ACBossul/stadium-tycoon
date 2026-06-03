#!/usr/bin/env python3
"""
Generate tileable surface textures (real PNG files) for Stadium Tycoon.

These are procedural PATTERN textures (grass pitch, stadium seats, brick, metal,
asphalt) — not illustrations — so they can be generated without an artist. Run
this, then upload the PNGs in art/textures/ to Roblox (Asset Manager -> Add Images)
and send back the asset IDs; they get applied to the building parts via Texture /
SurfaceAppearance.

Requires Pillow:  pip install pillow
Usage:            python generate_textures.py
Output:           art/textures/*.png  (512x512, tileable)
"""

import os
import math
import random
from PIL import Image

SIZE = 512
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")
os.makedirs(OUT, exist_ok=True)


def clamp(v):
    return max(0, min(255, int(v)))


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote", path)


def pitch_grass():
    """Mowed-stripe grass; vertical stripes wrap horizontally -> tileable."""
    rnd = random.Random(11)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    stripe_w = SIZE // 8
    for x in range(SIZE):
        light = (x // stripe_w) % 2 == 0
        base = (52, 132, 64) if light else (40, 110, 54)
        for y in range(SIZE):
            n = rnd.randint(-10, 10)
            px[x, y] = (clamp(base[0] + n), clamp(base[1] + n), clamp(base[2] + n))
    save(img, "pitch_grass.png")


def stand_seats():
    """Grid of little seats in alternating team colors; repeats -> tileable."""
    img = Image.new("RGB", (SIZE, SIZE), (28, 30, 40))
    px = img.load()
    cell = SIZE // 16
    green = (45, 165, 85)
    gold = (245, 210, 60)
    for cy in range(0, SIZE, cell):
        for cx in range(0, SIZE, cell):
            col = green if ((cx // cell) + (cy // cell)) % 2 == 0 else gold
            for y in range(cy + 1, cy + cell - 1):
                for x in range(cx + 1, cx + cell - 1):
                    # rounded-ish seat: trim corners
                    if (x == cx + 1 or x == cx + cell - 2) and (y == cy + 1 or y == cy + cell - 2):
                        continue
                    px[x % SIZE, y % SIZE] = col
    save(img, "stand_seats.png")


def brick():
    """Offset brick courses; pattern repeats -> tileable."""
    img = Image.new("RGB", (SIZE, SIZE), (60, 62, 70))  # mortar
    px = img.load()
    rnd = random.Random(7)
    bh = SIZE // 16          # brick height
    bw = SIZE // 8           # brick width
    mortar = 3
    for row, y in enumerate(range(0, SIZE, bh)):
        offset = (bw // 2) if row % 2 else 0
        for x0 in range(-bw, SIZE + bw, bw):
            shade = rnd.randint(-12, 12)
            color = (clamp(150 + shade), clamp(70 + shade), clamp(55 + shade))
            for y in range(y + mortar, y + bh):
                for x in range(x0 + offset + mortar, x0 + offset + bw):
                    px[x % SIZE, y % SIZE] = color
    save(img, "brick.png")


def metal_panel():
    """Brushed metal with rivets; smooth horizontal gradient -> tileable vertically."""
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    rnd = random.Random(3)
    for y in range(SIZE):
        for x in range(SIZE):
            base = 70 + int(25 * math.sin(y / 26.0)) + rnd.randint(-6, 6)
            px[x, y] = (clamp(base), clamp(base + 4), clamp(base + 12))
    # rivets in a repeating grid
    for cy in range(32, SIZE, 96):
        for cx in range(32, SIZE, 96):
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    if dx * dx + dy * dy <= 9:
                        px[(cx + dx) % SIZE, (cy + dy) % SIZE] = (130, 135, 145)
    save(img, "metal_panel.png")


def asphalt():
    """Dark speckled parking surface; pure noise -> tileable."""
    rnd = random.Random(5)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for x in range(SIZE):
        for y in range(SIZE):
            n = rnd.randint(-12, 12)
            px[x, y] = (clamp(58 + n), clamp(60 + n), clamp(66 + n))
    save(img, "asphalt.png")


def main():
    pitch_grass()
    stand_seats()
    brick()
    metal_panel()
    asphalt()
    print("Done. Upload the PNGs in", OUT, "to Roblox and send back the asset IDs.")


if __name__ == "__main__":
    main()
