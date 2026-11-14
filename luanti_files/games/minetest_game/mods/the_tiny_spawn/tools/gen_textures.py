#!/usr/bin/env python3
"""Generates all 16x16 textures of the_tiny_spawn mod.

Usage:  python3 tools/gen_textures.py            (run from the mod folder)
Requires Pillow.  Deterministic: the same PNGs every run.
"""
import os
import random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "textures")
os.makedirs(OUT, exist_ok=True)
P = "the_tiny_spawn_"
S = 16


def img(w=S, h=S, c=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), c)


def save(im, name):
    im.save(os.path.join(OUT, P + name + ".png"))


def clamp(v):
    return max(0, min(255, int(v)))


def noise_fill(im, base, amp, seed, y0=0, h=S):
    rnd = random.Random(seed)
    px = im.load()
    for y in range(y0, y0 + h):
        for x in range(im.width):
            d = rnd.randint(-amp, amp)
            px[x, y] = (clamp(base[0] + d), clamp(base[1] + d), clamp(base[2] + d),
                        base[3] if len(base) > 3 else 255)


def rect(im, x0, y0, x1, y1, c):
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = c


def border(im, c, y0=0):
    px = im.load()
    for i in range(S):
        px[i, y0] = c
        px[i, y0 + S - 1] = c
        px[0, y0 + i] = c
        px[S - 1, y0 + i] = c


# ---------------------------------------------------------------- floor / walls
im = img()
noise_fill(im, (30, 32, 46), 4, 1)
border(im, (18, 19, 28, 255))
for x, y in ((2, 2), (13, 2), (2, 13), (13, 13)):
    im.putpixel((x, y), (70, 74, 96, 255))
save(im, "plate")

im = img()
noise_fill(im, (62, 66, 86), 5, 2)
border(im, (40, 42, 58, 255))
rect(im, 1, 1, 14, 1, (88, 92, 116, 255))
save(im, "plate_light")

im = img()
noise_fill(im, (20, 20, 27), 5, 3)
save(im, "road")

im = img()
noise_fill(im, (20, 20, 27), 5, 3)
rect(im, 5, 5, 10, 10, (40, 240, 255, 255))
rect(im, 6, 6, 9, 9, (200, 255, 255, 255))
save(im, "road_line")

im = img()
noise_fill(im, (34, 36, 56), 3, 4)
for y in range(S):
    im.putpixel((4, y), (24, 25, 40, 255))
    im.putpixel((11, y), (24, 25, 40, 255))
rect(im, 0, 7, 15, 7, (24, 25, 40, 255))
im.putpixel((7, 3), (60, 220, 255, 255))
im.putpixel((8, 11), (255, 60, 220, 255))
save(im, "panel")


# ---------------------------------------------------------------- neon
def neon(name, core, edge):
    im = img()
    px = im.load()
    for y in range(S):
        for x in range(S):
            d = max(abs(x - 7.5), abs(y - 7.5)) / 7.5   # 0 centre .. 1 edge
            t = d ** 2
            px[x, y] = tuple(clamp(core[i] * (1 - t) + edge[i] * t) for i in range(3)) + (255,)
    border(im, tuple(clamp(c * 0.6) for c in edge) + (255,))
    save(im, name)


neon("neon_cyan", (220, 255, 255), (0, 200, 255))
neon("neon_magenta", (255, 210, 250), (255, 0, 200))
neon("neon_purple", (230, 200, 255), (140, 40, 255))
neon("neon_yellow", (255, 255, 210), (255, 200, 0))

# glass
im = img(c=(40, 220, 255, 70))
border(im, (120, 245, 255, 220))
im.putpixel((3, 3), (230, 255, 255, 200))
im.putpixel((4, 3), (230, 255, 255, 160))
im.putpixel((3, 4), (230, 255, 255, 160))
save(im, "glass_cyan")


# ---------------------------------------------------------------- beam (animated)
def beam(name, base_alpha, frames, colour, seed):
    rnd = random.Random(seed)
    streaks = [(rnd.randint(0, 15), rnd.randint(0, frames * S - 1), rnd.randint(3, 9)) for _ in range(14)]
    im = img(S, S * frames)
    px = im.load()
    H = S * frames
    for f in range(frames):
        for y in range(S):
            gy = f * S + y
            for x in range(S):
                a = base_alpha
                c = list(colour)
                for sx, sy, ln in streaks:
                    # streak moves upwards by 2 px per frame (tile is 16 px tall)
                    local = (y - (sy - f * 2)) % S
                    if x == sx and local < ln:
                        a = min(255, a + 70)
                        c = [255, 255, 255]
                px[x, gy] = (c[0], c[1], c[2], a)
    save(im, name)


beam("beam_core", 120, 8, (150, 245, 255), 11)
beam("beam_halo", 45, 8, (60, 160, 255), 12)

im = img()
px = im.load()
for y in range(S):
    for x in range(S):
        d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
        if d < 3:
            c = (240, 255, 255)
        elif abs(d - 5.5) < 1:
            c = (0, 230, 255)
        else:
            c = (20, 60, 90)
        px[x, y] = c + (255,)
save(im, "emitter")


# ---------------------------------------------------------------- holo pool / column / screen
def anim(name, frames, fn):
    im = img(S, S * frames)
    px = im.load()
    for f in range(frames):
        for y in range(S):
            for x in range(S):
                px[x, f * S + y] = fn(x, y, f)
    save(im, name)


import math

anim("holo_pool", 8, lambda x, y, f: (
    clamp(20 + 40 * (1 + math.sin((x + y + f * 2) * 0.8))),
    clamp(180 + 35 * math.sin((x - y - f * 2) * 0.7)),
    255, 200))

anim("holo_column", 8, lambda x, y, f: (
    (120, 250, 255, 150) if (y + 16 - f * 2) % 6 == 0 else (40, 200, 255, 70)))

anim("holo_screen", 8, lambda x, y, f: (
    (10, 30, 50, 255) if (x in (0, 15) or y in (0, 15)) else
    ((60, 240, 255, 255) if (y + f * 2) % 8 == 0 else
     (20, clamp(90 + 40 * math.sin(x * 1.3 + f)), clamp(130 + 30 * math.sin(y + f)), 255))))

anim("beacon_red", 4, lambda x, y, f: (
    (255, 60 + 40 * (f == 0), 60, 255) if f < 2 else (110, 10, 20, 255)))

# ---------------------------------------------------------------- trees & lamps
im = img()
noise_fill(im, (40, 30, 46), 6, 21)
for y in range(S):
    x = 4 + int(2 * math.sin(y * 0.6))
    im.putpixel((x, y), (255, 40, 210, 255))
    im.putpixel((11, (y + 5) % S), (200, 60, 255, 255) if y % 3 else (40, 20, 50, 255))
save(im, "neon_trunk")

im = img()
noise_fill(im, (40, 30, 46), 6, 22)
rect(im, 3, 3, 12, 12, (60, 44, 66, 255))
rect(im, 7, 7, 8, 8, (255, 40, 210, 255))
save(im, "neon_trunk_top")

rnd = random.Random(31)
im = img()
px = im.load()
for y in range(S):
    for x in range(S):
        r = rnd.random()
        if r < 0.18:
            px[x, y] = (0, 0, 0, 0)
        elif r < 0.30:
            px[x, y] = (255, 190, 245, 255)
        else:
            k = rnd.randint(-25, 25)
            px[x, y] = (clamp(230 + k), clamp(60 + k), clamp(200 + k), 255)
save(im, "neon_leaves")

im = img()
noise_fill(im, (26, 27, 36), 4, 41)
rect(im, 7, 0, 8, 15, (60, 64, 84, 255))
save(im, "lamp_pole")

neon("lamp_head", (255, 255, 255), (80, 230, 255))


# ---------------------------------------------------------------- solarpunk additions
neon("solar_lantern", (255, 250, 210), (255, 170, 60))

im = img()
noise_fill(im, (22, 34, 70), 3, 51)
for i in range(S):
    im.putpixel((i, 5), (90, 200, 255, 255)); im.putpixel((i, 10), (90, 200, 255, 255))
    im.putpixel((5, i), (60, 120, 190, 255)); im.putpixel((10, i), (60, 120, 190, 255))
border(im, (150, 160, 170, 255))
save(im, "solar_panel")

im = img()
noise_fill(im, (150, 160, 170), 6, 52)
save(im, "solar_side")

rnd = random.Random(61)
im = img()
px = im.load()
for x in (3, 7, 12):
    for y in range(S):
        if rnd.random() < 0.85:
            px[x + (y // 5) % 2 - 1, y] = (40, 170, 90, 255)
        if rnd.random() < 0.18:
            px[x, y] = (120, 255, 230, 255)
            px[min(15, x + 1), y] = (60, 230, 255, 255)
save(im, "glow_vine")

def crystal(name, c1, c2, seed):
    rnd = random.Random(seed)
    im = img()
    px = im.load()
    for cx, w, hgt in ((4, 2, 9), (8, 3, 14), (12, 2, 7)):
        for y in range(S - hgt, S):
            ww = max(0, int(w * (y - (S - hgt)) / 3)) if y < S - hgt + 3 else w
            for x in range(cx - ww, cx + ww + 1):
                if 0 <= x < S:
                    t = (x - cx + w) / (2 * w + 1)
                    px[x, y] = tuple(clamp(c1[i] * (1 - t) + c2[i] * t) for i in range(3)) + (255,)
    save(im, name)

crystal("crystal_cyan", (200, 255, 255), (0, 150, 255), 71)
crystal("crystal_magenta", (255, 210, 250), (190, 0, 220), 72)

rnd = random.Random(81)
im = img()
px = im.load()
for _ in range(34):
    x, y = rnd.randint(0, 15), rnd.randint(0, 15)
    px[x, y] = (255, rnd.randint(140, 200), rnd.randint(200, 240), 255)
save(im, "petals")

# ---------------------------------------------------------------- cyber machines
def machine_body(seed):
    im = img()
    noise_fill(im, (40, 42, 60), 3, seed)
    border(im, (20, 21, 32, 255))
    rect(im, 2, 2, 13, 2, (70, 74, 98, 255))
    rect(im, 2, 13, 13, 13, (70, 74, 98, 255))
    return im

im = machine_body(91)
for y in range(4, 12):
    im.putpixel((3, y), (0, 220, 255, 255)); im.putpixel((12, y), (255, 40, 210, 255))
save(im, "machine_side")
im = machine_body(92)
rect(im, 5, 5, 10, 10, (25, 26, 38, 255))
for i in range(5, 11):
    im.putpixel((i, 5), (0, 220, 255, 255)); im.putpixel((i, 10), (0, 220, 255, 255))
save(im, "machine_top")

def machine_front(name, col, frames, seed, active):
    im = img(S, S * frames)
    for f in range(frames):
        fr = machine_body(seed)
        px = fr.load()
        rect(fr, 3, 3, 12, 9, (8, 14, 24, 255))
        for x in range(3, 13):
            for y in range(3, 10):
                if active:
                    on = (x + y + f) % 4 == 0 or y == 3 + (f % 7)
                else:
                    on = y == 6 and x % 3 == 0
                if on:
                    px[x, y] = col + (255,)
        # status led + intake grill
        px[3, 11] = (60, 255, 120, 255) if active else (120, 30, 30, 255)
        for x in range(6, 13, 2):
            px[x, 11] = (90, 94, 120, 255); px[x, 12] = (90, 94, 120, 255)
        im.paste(fr, (0, f * S))
    save(im, name)

machine_front("fabricator_front", (0, 230, 255), 1, 93, False)
machine_front("fabricator_front_active", (0, 230, 255), 8, 93, True)
machine_front("synthesizer_front", (255, 50, 220), 1, 94, False)
machine_front("synthesizer_front_active", (255, 50, 220), 8, 94, True)

print("textures written to", os.path.abspath(OUT))
