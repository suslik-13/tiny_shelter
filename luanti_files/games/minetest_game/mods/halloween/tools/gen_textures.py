#!/usr/bin/env python3
"""Generates all textures and models of the halloween mod.

Usage:
  python3 gen_textures.py [NEW OLD OLD_SHAVED]

Each sheep argument is "<model.b3d>:<tex1.png>,<tex2.png>,..." - the model and the
original textures whose combined alpha decides which texels stay visible.
NEW        - mobs_sheep.b3d + mobs_sheep_base/wool.png from tiny_shelter / shelter_ta
OLD        - mobs_sheep.b3d + mobs_sheep_base/wool.png from survival_shelter (older mobs_animal)
OLD_SHAVED - mobs_sheep_shaved.b3d + mobs_sheep_shaved.png from survival_shelter
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import b3d  # noqa: E402

MOD = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(MOD, "textures")
MOD_MODELS = os.path.join(MOD, "models")

rnd = random.Random(1031)

# ---------------------------------------------------------------- palette
T = (0, 0, 0, 0)
BONE = (232, 226, 205, 255)
BONE_S = (196, 188, 164, 255)
BONE_D = (150, 141, 120, 255)
OUTL = (38, 32, 28, 255)
HOLE = (24, 16, 14, 255)
GLOW = (255, 140, 20, 255)
GLOW_Y = (255, 214, 70, 255)
GLOW_W = (255, 248, 190, 255)
P_DARK = (168, 70, 8, 255)
P_MID = (226, 112, 18, 255)
P_LIGHT = (246, 152, 44, 255)
STEM = (86, 104, 34, 255)
STEM_D = (60, 70, 24, 255)
WOOD_D = (40, 24, 18, 255)
WOOD = (66, 40, 28, 255)
WOOD_L = (92, 58, 38, 255)
VELVET = (110, 14, 26, 255)
VELVET_D = (70, 8, 16, 255)
IRON = (120, 120, 128, 255)


def save(img, name):
    img.save(os.path.join(TEX, name))


def from_rows(rows, pal):
    h = len(rows)
    w = len(rows[0])
    img = Image.new("RGBA", (w, h), T)
    px = img.load()
    for y, r in enumerate(rows):
        assert len(r) == w, (y, r, len(r))
        for x, c in enumerate(r):
            if c in pal:
                px[x, y] = pal[c]
    return img


def jitter(c, amount=10):
    d = rnd.randint(-amount, amount)
    return tuple(max(0, min(255, v + d)) for v in c[:3]) + (c[3],)


def outline(img, color=OUTL):
    """Adds a 1px outline around opaque pixels (4-neighbourhood)."""
    a = np.array(img)
    op = a[:, :, 3] > 0
    ring = np.zeros_like(op)
    ring[1:, :] |= op[:-1, :]
    ring[:-1, :] |= op[1:, :]
    ring[:, 1:] |= op[:, :-1]
    ring[:, :-1] |= op[:, 1:]
    ring &= ~op
    a[ring] = color
    return Image.fromarray(a)


# ---------------------------------------------------------------- cobwebs
def cobweb(size, cx, cy, radius, spokes, rings, alpha=200, a0=0.0, a1=2 * math.pi,
           color=(235, 235, 240), width=0.55, rng=None, h=None):
    """Draws a cobweb into a transparent RGBA image (anti-aliased by supersampling)."""
    rng = rng or rnd
    ss = 4
    W = size * ss
    H = (h or size) * ss
    acc = np.zeros((H, W), np.float32)
    cxs, cys, rs = cx * ss, cy * ss, radius * ss
    angs = [a0 + (a1 - a0) * i / (spokes - 1 if a1 - a0 < 2 * math.pi else spokes)
            for i in range(spokes)]
    angs = [a + rng.uniform(-0.08, 0.08) for a in angs]
    width = width * ss

    def seg(x0, y0, x1, y1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            xi, yi = int(x), int(y)
            r = int(math.ceil(width))
            for yy in range(yi - r, yi + r + 1):
                for xx in range(xi - r, xi + r + 1):
                    if 0 <= xx < W and 0 <= yy < H and (xx - x) ** 2 + (yy - y) ** 2 <= width ** 2:
                        acc[yy, xx] = 1

    for a in angs:
        seg(cxs, cys, cxs + math.cos(a) * rs, cys + math.sin(a) * rs)
    for k in range(1, rings + 1):
        rr = rs * k / (rings + 0.3)
        pts = [(cxs + math.cos(a) * rr, cys + math.sin(a) * rr) for a in angs]
        pairs = list(zip(pts, pts[1:]))
        if a1 - a0 >= 2 * math.pi:
            pairs.append((pts[-1], pts[0]))
        for (x0, y0), (x1, y1) in pairs:
            # sagging strand: midpoint pulled toward the centre
            mx, my = (x0 + x1) / 2, (y0 + y1) / 2
            mx += (cxs - mx) * 0.12
            my += (cys - my) * 0.12
            seg(x0, y0, mx, my)
            seg(mx, my, x1, y1)
    cov = acc.reshape(H // ss, ss, W // ss, ss).mean(axis=(1, 3))
    out = np.zeros((H // ss, W // ss, 4), np.uint8)
    out[:, :, 0:3] = color
    out[:, :, 3] = np.clip(cov * 1.8, 0, 1) * alpha
    return Image.fromarray(out)


def gen_cobwebs():
    # apple: web wrapped over the whole fruit
    save(cobweb(32, 15.5, 17, 15, 9, 4, alpha=215), "halloween_cobweb_apple.png")


# ---------------------------------------------------------------- skull (torch)
SKULL_PAL = {"b": BONE, "s": BONE_S, "d": BONE_D, "k": HOLE, "o": OUTL,
             "E": GLOW, "Y": GLOW_Y, "W": GLOW_W}

SKULL_FRONT = [
    "bbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbb",
    "bbkkkkbbbbkkkkbb",
    "bkkEEkkbbkkEEkkb",
    "bkEYYEkbbkEYYEkb",
    "bkEYWEkbbkEWYEkb",
    "bkkEEkkbbkkEEkkb",
    "sbkkkkbbbbkkkkbs",
    "sbbbbbbkkbbbbbbs",
    "sbbbbbkkkkbbbbbs",
    "ssbbbbbbbbbbbbss",
    "ssbkbkbkbkbkbkss",
    "ssbkbkbkbkbkbkss",
    "sssbbbbbbbbbbsss",
    "dsssssssssssssdd",
]


def gen_skull():
    # animated front: eyes flicker (4 frames, vertical strip)
    frames = []
    flick = [{"E": GLOW, "Y": GLOW_Y, "W": GLOW_W},
             {"E": (240, 110, 10, 255), "Y": GLOW, "W": GLOW_Y},
             {"E": GLOW, "Y": GLOW_Y, "W": GLOW_Y},
             {"E": (255, 160, 40, 255), "Y": GLOW_W, "W": GLOW_W}]
    for f in flick:
        pal = dict(SKULL_PAL)
        pal.update(f)
        img = from_rows(SKULL_FRONT, pal)
        px = img.load()
        for y in range(16):
            for x in range(16):
                if px[x, y] in (BONE, BONE_S):
                    px[x, y] = jitter(px[x, y], 5)
        frames.append(img)
    strip = Image.new("RGBA", (16, 64))
    for i, f in enumerate(frames):
        strip.paste(f, (0, i * 16))
    save(strip, "halloween_skull_front.png")
    save(frames[0], "halloween_skull_inv_base.png")

    def plain(dark_bottom=True, crack=False, temple=False):
        img = Image.new("RGBA", (16, 16), BONE)
        px = img.load()
        for y in range(16):
            for x in range(16):
                c = BONE
                if dark_bottom and y >= 12:
                    c = BONE_S if y < 15 else BONE_D
                if x in (0, 15):
                    c = BONE_S
                px[x, y] = jitter(c, 5)
        if temple:
            for y in range(5, 9):
                for x in range(5, 11):
                    if (x - 7.5) ** 2 / 9 + (y - 6.5) ** 2 / 4 <= 1:
                        px[x, y] = BONE_D
        if crack:
            for x, y in [(4, 3), (5, 4), (6, 4), (7, 5), (8, 6), (8, 7), (9, 8), (10, 8), (11, 9)]:
                px[x, y] = BONE_D
        return img
    save(plain(temple=True), "halloween_skull_side.png")
    save(plain(dark_bottom=False, crack=True), "halloween_skull_top.png")
    save(plain(), "halloween_skull_back.png")
    bottom = Image.new("RGBA", (16, 16), BONE_D)
    save(bottom, "halloween_skull_bottom.png")

    # inventory image: small skull with transparent margins + glow
    inv = Image.new("RGBA", (16, 16), T)
    small = frames[0].resize((12, 12), Image.NEAREST)
    m = Image.new("L", (12, 12), 255)
    mp = m.load()
    for (x, y) in [(0, 0), (11, 0), (0, 11), (11, 11), (1, 11), (10, 11), (0, 10), (11, 10)]:
        mp[x, y] = 0
    inv.paste(small, (2, 2), m)
    save(outline(inv), "halloween_skull_inv.png")
    os.remove(os.path.join(TEX, "halloween_skull_inv_base.png"))


def write_obj(path, box, faces):
    """Writes an OBJ box. box = (x0,y0,z0,x1,y1,z1) in nodes; faces maps
    material -> list of face names (+y,-y,+x,-x,+z,-z). Every face gets full 0..1 UV."""
    x0, y0, z0, x1, y1, z1 = box
    quads = {
        # vertices counter-clockwise seen from outside; uv (0,0) bottom-left
        "+y": [(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)],
        "-y": [(x0, y0, z1), (x0, y0, z0), (x1, y0, z0), (x1, y0, z1)],
        "+x": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        "-x": [(x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (x0, y0, z0)],
        "+z": [(x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (x0, y0, z1)],
        "-z": [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)],
    }
    normals = {"+y": (0, 1, 0), "-y": (0, -1, 0), "+x": (1, 0, 0),
               "-x": (-1, 0, 0), "+z": (0, 0, 1), "-z": (0, 0, -1)}
    # uv order matching vertex order: bottom-left, top-left, top-right, bottom-right
    uvs = [(0, 0), (0, 1), (1, 1), (1, 0)]
    lines = ["# generated by halloween/tools/gen_textures.py"]
    vi = 1
    body = []
    for mat, fl in faces:
        body.append("usemtl " + mat)
        for f in fl:
            for v in quads[f]:
                lines.append("v %.4f %.4f %.4f" % v)
            for uv in uvs:
                lines.append("vt %d %d" % uv)
            lines.append("vn %d %d %d" % normals[f])
            n = (vi - 1) // 4 + 1
            body.append("f " + " ".join("%d/%d/%d" % (vi + i, vi + i, n) for i in range(4)))
            vi += 4
    with open(path, "w") as fh:
        fh.write("\n".join(lines + body) + "\n")


def gen_skull_models():
    s = 3 / 16  # half size: 6px skull
    # Luanti meshes are mirrored on X compared to OBJ (OBJ is right-handed);
    # the face directions below are given in Luanti coordinates.
    def mx(box):
        x0, y0, z0, x1, y1, z1 = box
        return (-x1, y0, z0, -x0, y1, z1)

    def fl(names):
        sw = {"+x": "-x", "-x": "+x"}
        return [sw.get(n, n) for n in names]
    floor = (-s, -0.5, -s, s, -0.5 + 2 * s, s)
    ceil = (-s, 0.5 - 2 * s, -s, s, 0.5, s)
    wall = (-0.5, -s + 1 / 16, -s, -0.5 + 2 * s, s + 1 / 16, s)  # stuck to -X wall
    four = [("front", fl(["+x", "-x", "+z", "-z"])), ("top", ["+y"]), ("bottom", ["-y"])]
    write_obj(os.path.join(MOD_MODELS, "halloween_skull_floor.obj"), mx(floor), four)
    write_obj(os.path.join(MOD_MODELS, "halloween_skull_ceiling.obj"), mx(ceil), four)
    write_obj(os.path.join(MOD_MODELS, "halloween_skull_wall.obj"), mx(wall),
              [("front", fl(["+x"])), ("side", fl(["+z", "-z"])), ("top", ["+y"]),
               ("bottom", ["-y"]), ("back", fl(["-x"]))])


# ---------------------------------------------------------------- pumpkin (chest)
def pumpkin_side():
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            col = x % 5
            c = P_MID
            if col == 0:
                c = P_DARK
            elif col == 2:
                c = P_LIGHT
            if y in (0, 15) and col != 0:
                c = P_MID if c == P_LIGHT else P_DARK
            px[x, y] = jitter(c, 6)
    return img


def gen_pumpkin():
    side = pumpkin_side()
    save(side, "halloween_pumpkin_side.png")

    top = Image.new("RGBA", (16, 16))
    px = top.load()
    for y in range(16):
        for x in range(16):
            r = math.hypot(x - 7.5, y - 7.5)
            ang = math.atan2(y - 7.5, x - 7.5)
            c = P_MID
            if abs(math.sin(ang * 4)) < 0.25 and r > 2.5:
                c = P_DARK
            elif r < 3.5:
                c = P_DARK
            px[x, y] = jitter(c, 6)
    for (x, y) in [(7, 6), (8, 6), (7, 7), (8, 7), (7, 8), (8, 8), (7, 9), (8, 9)]:
        px[x, y] = STEM
    for (x, y) in [(9, 6), (9, 7), (6, 8), (6, 9)]:
        px[x, y] = STEM_D
    save(top, "halloween_pumpkin_top.png")

    face = [
        "................",
        "................",
        "................",
        "....E......E....",
        "...EYE....EYE...",
        "..EYWYE..EYWYE..",
        "..EEEEE..EEEEE..",
        ".......EE.......",
        "......EYYE......",
        "................",
        ".EE..........EE.",
        ".EYEE.EEEE.EEYE.",
        "..EYYYYWWYYYYE..",
        "...EYYE.EEYYE...",
        "....EE....EE....",
        "................",
    ]
    front = side.copy()
    front.alpha_composite(from_rows(face, {"E": GLOW, "Y": GLOW_Y, "W": GLOW_W}))
    save(front, "halloween_pumpkin_front.png")

    inside = Image.new("RGBA", (16, 16))
    px = inside.load()
    for y in range(16):
        for x in range(16):
            d = max(abs(x - 7.5), abs(y - 7.5))
            c = GLOW_Y if d < 4 else (GLOW if d < 6.5 else P_DARK)
            px[x, y] = jitter(c, 8)
    save(inside, "halloween_pumpkin_inside.png")


# ---------------------------------------------------------------- coffin (locked chest)
def planks(horizontal=True):
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            a = y if horizontal else x
            c = WOOD
            if a % 5 == 4:
                c = WOOD_D
            elif rnd.random() < 0.15:
                c = WOOD_L
            px[x, y] = jitter(c, 5)
    return img


def frame(img, color=WOOD_D):
    px = img.load()
    for i in range(16):
        px[i, 0] = px[i, 15] = px[0, i] = px[15, i] = color
    return img


def gen_coffin():
    top = frame(planks(False))
    px = top.load()
    for y in range(3, 14):
        px[7, y] = px[8, y] = BONE
    for x in range(5, 11):
        px[x, 6] = px[x, 7] = BONE
    for y in range(3, 14):
        px[9, y] = BONE_D if px[9, y] != BONE else BONE
    save(top, "halloween_coffin_top.png")
    save(frame(planks(True)), "halloween_coffin_side.png")

    front = frame(planks(True))
    px = front.load()
    for y in range(5, 11):
        for x in range(6, 10):
            px[x, y] = IRON
    px[7, 7] = px[8, 7] = HOLE
    px[7, 8] = HOLE
    save(front, "halloween_coffin_front.png")

    inside = Image.new("RGBA", (16, 16))
    px = inside.load()
    for y in range(16):
        for x in range(16):
            c = VELVET_D if (x + y) % 4 == 0 else VELVET
            if x in (0, 1, 14, 15) or y in (0, 1, 14, 15):
                c = WOOD
            px[x, y] = jitter(c, 5)
    save(inside, "halloween_coffin_inside.png")


# ---------------------------------------------------------------- armor
def load_mask(slot, kind):
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "masks", "%s_%s.png" % (slot, kind))
    return np.array(Image.open(p).convert("L")) > 127


def draw_rows(img, rows, ox, oy, pal, mask=None):
    px = img.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in pal:
                X, Y = ox + x, oy + y
                if mask is None or mask[Y, X]:
                    px[X, Y] = pal[c]


BP = {"b": BONE, "s": BONE_S, "d": BONE_D, "k": HOLE, "o": OUTL}
FACE8 = [
    "bbbbbbbb",
    "bbbbbbbb",
    "bkkbbkkb",
    "bkkbbkkb",
    "bbbkkbbb",
    "sbbbbbbs",
    "sbkbkbks",
    "ssbbbbss",
]
RIBS8x12 = [
    "...bb...",
    ".bbbbbb.",
    "b..bb..b",
    ".bbbbbb.",
    "b..bb..b",
    ".bbbbbb.",
    "b..bb..b",
    "..bbbb..",
    "...bb...",
    "...ss...",
    "..b..b..",
    ".bb..bb.",
]
SPINE8x12 = [
    "...ss...",
    "...bb...",
    "...ss...",
    "...bb...",
    "...ss...",
    "...bb...",
    "...ss...",
    "...bb...",
    "...ss...",
    "...bb...",
    "...ss...",
    "...bb...",
]
LIMB4x12 = [
    ".bb.",
    "bbbb",
    ".bb.",
    ".bb.",
    ".bs.",
    ".bb.",
    "bbbb",
    "b..b",
    ".bb.",
    ".bs.",
    ".bb.",
    "bbbb",
]
TOES4x7 = [
    "....",
    "....",
    "b.b.",
    "b.b.",
    "s.s.",
    "b.bb",
    "bbbb",
]


def gen_armor():
    m = {k: load_mask(k, "tex") for k in ("helmet", "chestplate", "leggings", "boots", "shield")}
    # helmet: skull on the front face of the hat layer
    img = Image.new("RGBA", (64, 32), T)
    draw_rows(img, FACE8, 40, 8, BP)
    save(img, "halloween_bones_head.png")
    # chestplate: ribs on the front, spine on the back, bones on the arms
    img = Image.new("RGBA", (64, 32), T)
    draw_rows(img, RIBS8x12, 20, 20, BP, m["chestplate"])
    draw_rows(img, SPINE8x12, 32, 20, BP, m["chestplate"])
    draw_rows(img, LIMB4x12, 44, 20, BP, m["chestplate"])
    save(img, "halloween_bones_torso.png")
    # leggings: femur on the front of the legs
    img = Image.new("RGBA", (64, 32), T)
    draw_rows(img, LIMB4x12, 4, 20, BP, m["leggings"])
    draw_rows(img, LIMB4x12, 20, 20, BP, m["leggings"])
    save(img, "halloween_bones_legs.png")
    # boots: toes on the front
    img = Image.new("RGBA", (64, 32), T)
    draw_rows(img, TOES4x7, 20, 4, BP, m["boots"])
    draw_rows(img, TOES4x7, 24, 4, BP, m["boots"])
    save(img, "halloween_bones_feet.png")
    # shield: skull in the middle
    img = Image.new("RGBA", (64, 32), T)
    draw_rows(img, FACE8, 2, 1, BP, m["shield"])
    save(img, "halloween_bones_shield.png")

    # previews (32x64 front view of the player)
    pm = {k: load_mask(k, "prev") for k in ("helmet", "chestplate", "leggings", "boots", "shield")}

    def up2(rows):
        return [("".join(c * 2 for c in r)) for r in rows for _ in (0, 1)]
    img = Image.new("RGBA", (32, 64), T)
    draw_rows(img, up2(FACE8), 8, 0, BP)
    save(img, "halloween_bones_head_preview.png")
    img = Image.new("RGBA", (32, 64), T)
    draw_rows(img, up2(RIBS8x12)[:24], 8, 16, BP, pm["chestplate"])
    draw_rows(img, up2(LIMB4x12)[:24], 0, 16, BP, pm["chestplate"])
    draw_rows(img, up2(LIMB4x12)[:24], 24, 16, BP, pm["chestplate"])
    save(img, "halloween_bones_torso_preview.png")
    img = Image.new("RGBA", (32, 64), T)
    draw_rows(img, up2(LIMB4x12)[:24], 8, 40, BP, pm["leggings"])
    draw_rows(img, up2(LIMB4x12)[:24], 16, 40, BP, pm["leggings"])
    save(img, "halloween_bones_legs_preview.png")
    img = Image.new("RGBA", (32, 64), T)
    draw_rows(img, up2(TOES4x7), 8, 50, BP, pm["boots"])
    draw_rows(img, up2(TOES4x7), 16, 50, BP, pm["boots"])
    save(img, "halloween_bones_feet_preview.png")
    img = Image.new("RGBA", (32, 64), T)
    draw_rows(img, up2(FACE8), 16, 32, BP, pm["shield"])
    save(img, "halloween_bones_shield_preview.png")

    # inventory badge: tiny skull in the bottom right corner
    badge = Image.new("RGBA", (16, 16), T)
    draw_rows(badge, [
        ".bbbb.",
        "bbbbbb",
        "bkbbkb",
        "bbbbbb",
        ".bkkb.",
    ], 9, 10, BP)
    save(outline(badge), "halloween_bones_badge.png")


# ---------------------------------------------------------------- sheep
def tri_normal(v):
    n = np.cross(v[1] - v[0], v[2] - v[0])
    ln = np.linalg.norm(n)
    return n / ln if ln > 0 else n


def paint_sheep(spec, out_name, W, H):
    model_path, alpha_src = spec.split(":", 1)
    m = b3d.load(model_path)
    V, UV, TR, VB = m["verts"], m["uv"], m["tris"], m["vbone"]

    # bone of a triangle = majority bone of its vertices
    def tbone(t):
        bs = [VB[i] for i in t]
        return max(set(bs), key=bs.count)
    tb = [tbone(t) for t in TR]
    tn = np.array([tri_normal(V[t]) for t in TR])
    # make sure normals point outwards: the face with the largest z must look to +z
    head = [i for i, b in enumerate(tb) if b == "Head"]
    front_i = max(head, key=lambda i: V[TR[i]][:, 2].mean())
    if tn[front_i][2] < 0:
        tn = -tn
    # head front plane (snout) and head core x-range (without ears/horns)
    # the face goes onto the biggest front-facing plane of the head
    planes = {}
    for i in head:
        if tn[i][2] > 0.7:
            k = round(float(V[TR[i]][:, 2].mean()), 1)
            area = np.linalg.norm(np.cross(V[TR[i]][1] - V[TR[i]][0], V[TR[i]][2] - V[TR[i]][0])) / 2
            planes.setdefault(k, [0.0, []])
            planes[k][0] += area
            planes[k][1].append(i)
    zf, (_, fronts) = max(planes.items(), key=lambda kv: kv[1][0])
    zf += 0.15
    fv = np.concatenate([V[TR[i]] for i in fronts])
    fx0, fx1 = fv[:, 0].min(), fv[:, 0].max()
    # the face is projected from the front over every front-facing part of the head
    # (main plane + protruding snout), like a decal
    fv = np.concatenate([V[TR[i]] for i in head if tn[i][2] > 0.7 and
                         V[TR[i]][:, 0].min() >= fx0 - 0.01 and V[TR[i]][:, 0].max() <= fx1 + 0.01])
    fy0, fy1 = fv[:, 1].min(), fv[:, 1].max()
    hv = np.concatenate([V[TR[i]] for i in head])
    hy1 = hv[:, 1].max()
    body = np.concatenate([V[TR[i]] for i, b in enumerate(tb) if b == "Root"])
    bz0, bz1 = body[:, 2].min(), body[:, 2].max()
    bx = (body[:, 0].min() + body[:, 0].max()) / 2

    img = np.zeros((H, W, 4), np.uint8)
    img[:, :] = (20, 18, 18, 255)  # unused areas: dark

    def color(p, n, bone):
        x, y, z = p
        if bone == "Head":
            core = fx0 - 0.05 <= x <= fx1 + 0.05
            if not core:  # ears / horns: dark green leaves
                return STEM if (int((y + z) * 2) % 2) else STEM_D
            if n[2] > 0.7:
                u = (x - fx0) / (fx1 - fx0)
                v = (fy1 - y) / (fy1 - fy0)
                return pumpkin_face(u, v)
            if n[1] > 0.7 and y > hy1 - 0.3:  # top: stem
                cx = (fx0 + fx1) / 2
                if abs(x - cx) < 0.5 and z > zf - 2.5:
                    return STEM
            # ridges around the pumpkin
            k = x if abs(n[0]) < 0.7 else z
            f = (k * 1.6) % 1.0
            return P_DARK if f < 0.18 else (P_LIGHT if 0.45 < f < 0.6 else P_MID)
        black = (22, 20, 20, 255)
        if bone == "Root":
            t = (z - bz0) / (bz1 - bz0)  # 0 tail .. 1 neck
            if n[1] > 0.7:  # back: spine
                if abs(x - bx) < 0.45:
                    return BONE if (z * 2) % 1.0 < 0.65 else BONE_D
                return black
            if n[1] < -0.7:  # belly: sternum
                if abs(x - bx) < 0.35 and 0.45 < t < 0.95:
                    return BONE_S
                return black
            if abs(n[0]) > 0.7:  # flanks: ribs + pelvis
                if 0.4 < t < 0.95:
                    if (z / 1.4) % 1.0 < 0.4 and y > -4.2:
                        return BONE
                    return black
                if 0.05 < t < 0.3 and abs(y + 2.0) < 1.3:
                    return BONE_S
                return black
            if n[2] < -0.7:  # rear: tail bones
                if abs(x - bx) < 0.35 and y > -2:
                    return BONE_S
                return black
            return black
        # legs
        if y < -9.2:
            return (60, 56, 52, 255)  # hooves
        if n[1] > 0.7 or n[1] < -0.7:
            return black
        k = x if abs(n[0]) < 0.7 else z
        bones_v = [V[TR[i]] for i, b in enumerate(tb) if b == bone]
        bvv = np.concatenate(bones_v)
        ax = 0 if abs(n[0]) < 0.7 else 2
        c0, c1 = bvv[:, ax].min(), bvv[:, ax].max()
        u = (k - c0) / (c1 - c0)
        if abs(y + 7.0) < 0.45:
            return BONE if 0.15 < u < 0.85 else black  # knee
        if 0.35 < u < 0.65:
            return BONE if y > -7 else BONE_S
        return black

    face_cache = {}

    def pumpkin_face(u, v):
        key = (round(u, 3), round(v, 3))
        if key in face_cache:
            return face_cache[key]
        c = P_MID if (u * 4) % 1.0 > 0.15 else P_DARK
        # eyes: triangles
        for ex in (0.28, 0.72):
            if 0.15 < v < 0.42:
                hw = (v - 0.15) * 0.55
                if abs(u - ex) < hw:
                    c = GLOW_Y if abs(u - ex) < hw - 0.05 and v > 0.22 else GLOW
        # nose
        if 0.45 < v < 0.55 and abs(u - 0.5) < (v - 0.45) * 0.8 + 0.02:
            c = GLOW
        # mouth with two teeth
        if 0.62 < v < 0.85:
            arc = 0.72 - 0.10 * ((u - 0.5) / 0.4) ** 2
            if abs(u - 0.5) < 0.4 and v > arc and v < arc + 0.13:
                c = GLOW_Y
                if (abs(u - 0.38) < 0.04 or abs(u - 0.62) < 0.04) and v < arc + 0.06:
                    c = P_MID
                elif v < arc + 0.03 or v > arc + 0.10:
                    c = GLOW
        face_cache[key] = c
        return c

    # rasterise every triangle in uv space
    for ti, t in enumerate(TR):
        uv = UV[t] * np.array([W, H])
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        a, b, c = uv
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9:
            continue
        for py in range(max(0, y0 - 1), min(H, y1 + 1)):
            for px_ in range(max(0, x0 - 1), min(W, x1 + 1)):
                q = (px_ + 0.5, py + 0.5)
                l1 = ((b[1] - c[1]) * (q[0] - c[0]) + (c[0] - b[0]) * (q[1] - c[1])) / den
                l2 = ((c[1] - a[1]) * (q[0] - c[0]) + (a[0] - c[0]) * (q[1] - c[1])) / den
                l3 = 1 - l1 - l2
                eps = -0.02
                if l1 < eps or l2 < eps or l3 < eps:
                    continue
                p = V[t[0]] * l1 + V[t[1]] * l2 + V[t[2]] * l3
                col = color(p, tn[ti], tb[ti])
                img[py, px_] = jitter(col, 6)
    # keep transparency of the original textures (horns, wool shell, ...)
    vis = np.zeros((H, W), bool)
    for src in alpha_src.split(","):
        a = Image.open(src).convert("RGBA").resize((W, H), Image.NEAREST)
        vis |= np.array(a)[:, :, 3] > 0
    img[~vis] = 0
    Image.fromarray(img).save(os.path.join(TEX, out_name))
    return m


# ---------------------------------------------------------------- unified_inventory decor
# Own random generator, so the textures above stay the same when this part changes.
urnd = random.Random(1031 + 31)

WEB_WHITE = (232, 232, 240)
WEB_BLACK = (6, 4, 8)
SPIDER_PAL = {"k": (14, 10, 16, 255), "l": (58, 48, 66, 255), "h": (78, 64, 92, 255),
              "R": (236, 44, 30, 255), "o": GLOW}
SPIDER = [
    "..l.........l..",
    "...l.......l...",
    "l...l.kkk.l...l",
    ".l...kRkRk...l.",
    "..lllkkkkklll..",
    "l...lkkkkkl...l",
    ".lll.kkhkk.lll.",
    "l...kkhkokk...l",
    ".l..kkoookk..l.",
    "..l.kkkokkk.l..",
    "...l.kkkkk.l...",
    "......kkk......",
]
THREAD = (225, 225, 235, 190)

PUMPKIN_PAL = {"d": P_DARK, "m": P_MID, "l": P_LIGHT, "g": STEM, "G": STEM_D,
               "Y": GLOW_Y}
PUMPKIN = [
    ".......Gg.......",
    "......Gg........",
    "...dmmlGmlmmd...",
    "..dmmlmmdmmlmmd.",
    ".dmmlmmdmmlmmdmd",
    ".dmYmlmdmmlmYmd.",
    "dmYYYlmdmmlYYYdm",
    "dlYYYYmdmmYYYYld",
    "dmlmmlmYYmlmmldm",
    "dmYmmlmdmmlmmYdm",
    ".dmYYmYYYYmYYmd.",
    ".dmlYYYmmYYYlmd.",
    "..dmmlmmdmmlmd..",
    "....dddddddd....",
]
UI_SKULL = [
    "...bbbbbb...",
    "..bbbbbbbb..",
    ".bbbbbbbbbb.",
    ".bbbbbbbbbs.",
    "bkkkbbbkkkbs",
    "bkkbbbbbkkbs",
    ".bbbbkbbbbs.",
    ".sbbkkkbbss.",
    "..sbbbbbbs..",
    "..bkbkbkbk..",
    "...ssssss...",
]
UI_BONE = [
    "bb..........bb",
    "bbbbbbbbbbbbbb",
    "ssbbbbbbbbbbss",
    "ss..........ss",
]


def pad(img, n=1):
    out = Image.new("RGBA", (img.size[0] + 2 * n, img.size[1] + 2 * n), T)
    out.alpha_composite(img, (n, n))
    return out


def spider_sprite():
    return pad(from_rows(SPIDER, SPIDER_PAL))


def corner_web(size, color, alpha):
    return cobweb(size, 0, 0, size * 0.98, 7, 6, alpha=alpha, a0=0.06, a1=math.pi / 2 - 0.06,
                  color=color, width=0.9, rng=urnd)


def crack(w, h, start, angle, length, branches):
    """A dark crack with a thin light edge, drawn as a jittered polyline with side branches."""
    img = Image.new("RGBA", (w, h), T)
    d = ImageDraw.Draw(img)

    def walk(x, y, a, n):
        pts = [(x, y)]
        for _ in range(n):
            a += urnd.uniform(-0.55, 0.55)
            step = urnd.uniform(4, 8)
            x += math.cos(a) * step
            y += math.sin(a) * step
            pts.append((x, y))
        return pts

    lines = []
    main = walk(start[0], start[1], angle, length)
    lines.append((main, 3))
    for _ in range(branches):
        i = urnd.randrange(2, len(main) - 1)
        side = urnd.choice((-1, 1))
        bx, by = main[i]
        lines.append((walk(bx, by, angle + side * urnd.uniform(0.6, 1.1),
                           urnd.randint(2, max(3, length // 2))), 2))
    for pts, wd in lines:
        d.line([(x + 1, y + 1) for x, y in pts], fill=(120, 110, 128, 110), width=wd)
    for pts, wd in lines:
        d.line(pts, fill=(10, 8, 12, 235), width=wd)
    return img


def spider_drop(frame_w=18, frame_h=160):
    """Vertical frame strip: the spider slides down its thread, dangles, climbs back."""
    sp = spider_sprite().transpose(Image.ROTATE_180)  # head down
    sw, sh = sp.size
    top, bottom = -sh + 4, frame_h - sh - 2
    ease = lambda t: t * t * (3 - 2 * t)  # noqa: E731
    ys = []
    ys += [top] * 3                                                 # hidden in the web
    ys += [top + (bottom - top) * ease(i / 9) for i in range(1, 10)]  # drop
    ys += [bottom, bottom - 2, bottom - 3, bottom - 2, bottom, bottom + 1]  # dangle
    ys += [bottom - (bottom - top) * (i / 7) for i in range(1, 8)]    # climb back
    frames = Image.new("RGBA", (frame_w, frame_h * len(ys)), T)
    for f, y in enumerate(ys):
        y = int(round(y))
        fr = Image.new("RGBA", (frame_w, frame_h), T)
        tx = frame_w // 2
        for ty in range(0, max(0, y + 2)):
            fr.putpixel((tx, ty), THREAD)
        sx = (frame_w - sw) // 2
        if y < 0:
            fr.alpha_composite(sp, (sx, 0), (0, -y))
        else:
            fr.alpha_composite(sp, (sx, y))
        frames.paste(fr, (0, f * frame_h))
    return frames, len(ys)


def ui_coffin():
    w, h = 26, 11
    img = Image.new("RGBA", (w, h), T)
    px = img.load()
    cy = (h - 1) / 2

    def half(x):  # half height of the lid seen from above: head, shoulders, feet
        if x < 7:
            return 2.6 + (5.0 - 2.6) * x / 7
        return 5.0 - (5.0 - 3.0) * (x - 7) / (w - 8)
    for x in range(w):
        for y in range(h):
            if abs(y - cy) <= half(x):
                c = WOOD
                if y % 3 == 0:
                    c = WOOD_D
                elif urnd.random() < 0.15:
                    c = WOOD_L
                px[x, y] = jitter(c, 5)
    for y in range(2, 9):  # cross on the lid
        px[8, y] = BONE
    for x in range(5, 12):
        px[x, 4] = BONE
    return outline(pad(img))


def ui_bones():
    bone = from_rows(UI_BONE, BP)
    img = Image.new("RGBA", (20, 14), T)
    for ang in (28, -28):
        r = bone.rotate(ang, resample=Image.NEAREST, expand=True)
        img.alpha_composite(r, ((20 - r.size[0]) // 2, (14 - r.size[1]) // 2))
    return outline(img)


def ui_ground(w=1024, h=48):
    """Dark graveyard soil with dry grass along the top and rounded bottom corners."""
    img = Image.new("RGBA", (w, h), T)
    px = img.load()
    surf = [10 + int(2 * math.sin(x / 23.0) + 1.5 * math.sin(x / 7.3 + 1)) for x in range(w)]
    for x in range(w):
        for y in range(surf[x], h):
            t = (y - surf[x]) / (h - surf[x])
            c = (int(58 - 30 * t), int(42 - 22 * t), int(40 - 18 * t), 255)
            if urnd.random() < 0.06:
                c = (78, 66, 60, 255) if urnd.random() < 0.5 else (24, 16, 18, 255)
            px[x, y] = jitter(c, 4)
    x = 0
    while x < w:  # dry grass tufts
        for k in range(urnd.randint(1, 4)):
            gx = x + k * 2
            if gx >= w:
                break
            gh = urnd.randint(3, 9)
            gc = urnd.choice([(74, 70, 36, 255), (58, 62, 30, 255), (92, 78, 44, 255)])
            for j in range(gh):
                yy = surf[gx] - j
                xx = gx + (j // 4) * urnd.choice((0, 0, 1))
                if 0 <= yy < h and xx < w:
                    px[xx, yy] = gc
        x += urnd.randint(5, 16)
    r = 6  # rounded bottom corners like the unified_inventory background
    for y in range(h - r, h):
        for x in range(r):
            if math.hypot(r - x - 0.5, y - (h - r) + 0.5) > r:
                px[x, y] = T
                px[w - 1 - x, y] = T
    return img


def gen_ui():
    save(corner_web(192, WEB_WHITE, 190), "halloween_ui_web_white.png")
    save(corner_web(192, WEB_BLACK, 235), "halloween_ui_web_black.png")
    save(cobweb(128, 64, 0, 66, 7, 4, alpha=190, a0=0.0, a1=math.pi, color=WEB_WHITE,
                width=0.9, rng=urnd, h=64), "halloween_ui_web_top.png")
    save(cobweb(96, 48, 48, 46, 9, 4, alpha=190, color=WEB_WHITE, width=0.9, rng=urnd),
         "halloween_ui_web_round.png")

    save(crack(96, 160, (0, 30), 0.35, 22, 4), "halloween_ui_crack1.png")
    save(crack(96, 80, (30, 0), 1.35, 12, 3), "halloween_ui_crack2.png")
    save(crack(96, 128, (48, 0), 1.6, 18, 4), "halloween_ui_crack3.png")
    save(crack(64, 96, (63, 70), math.pi + 0.5, 12, 3), "halloween_ui_crack4.png")

    save(spider_sprite(), "halloween_ui_spider.png")
    frames, n = spider_drop()
    assert n == 25, n
    save(frames, "halloween_ui_spider_drop.png")
    frames, n = spider_drop(frame_h=100)
    save(frames, "halloween_ui_spider_drop_short.png")

    save(outline(pad(from_rows(PUMPKIN, PUMPKIN_PAL))), "halloween_ui_pumpkin.png")
    save(outline(pad(from_rows(UI_SKULL, BP))), "halloween_ui_skull.png")
    save(ui_bones(), "halloween_ui_bones.png")
    save(ui_coffin(), "halloween_ui_coffin.png")
    save(ui_ground(), "halloween_ui_ground.png")


# ---------------------------------------------------------------- protector chest and doors
# Own random generator (and own jitter), so everything above stays the same.
hrnd = random.Random(1031 + 77)


def hjitter(c, amount=5):
    d = hrnd.randint(-amount, amount)
    return tuple(max(0, min(255, v + d)) for v in c[:3]) + (c[3],)


SC_PAL = {"b": BONE, "s": BONE_S, "d": BONE_D, "k": HOLE, "o": OUTL,
          "w": (246, 242, 226, 255), "R": (200, 30, 20, 255),
          "m": (40, 12, 22, 255), "M": (62, 20, 34, 255),
          "g": (240, 190, 40, 255), "G": (196, 140, 24, 255), "e": (60, 200, 90, 255)}

# skull chest: cranium 14x10x14 px, jaw 12x5x12 px (1 texel = 1/16 node)
SC_CRANIUM_FRONT = [
    "ssbbbbbbbbbbss",
    "sbbbbbbbbbbbbs",
    "bbkkkkbbkkkkbb",
    "bkkkkkbbkkkkkb",
    "bkkRkkbbkkRkkb",
    "bbkkkkbbkkkkbb",
    "sbbbbbkkbbbbbs",
    "sbbbbkkkkbbbbs",
    "ssbbbbbbbbbbss",
    "swkwkwkkwkwkws",
]
SC_JAW_FRONT = [
    "wkwkwkkwkwkw",
    "bbbbbbbbbbbb",
    "sbbbbbbbbbbs",
    "ssbbbbbbbbss",
    "dssssssssssd",
]
# inside of the mouth (top of the jaw, front edge at the bottom): treasure
SC_MOUTH = [
    "ssssssssssss",
    "smmmmmmmmmms",
    "smMmmgmmmMms",
    "smmgGmmGgmms",
    "smGgggeggGms",
    "smmgGgGgGmms",
    "smgggGgggGms",
    "smGgGggGgmms",
    "smmGmgmGmmMs",
    "smMmmmmmmmms",
    "smmmmmmmmmms",
    "wkwkwkkwkwkw",
]
# roof of the mouth (bottom of the cranium, front edge at the top)
SC_PALATE = [
    "swkwkwkkwkwkws",
    "smmmmmmmmmmmms",
    "smMmmmmmmmmMms",
    "smmmmMmmMmmmms",
    "smmmmmmmmmmmms",
    "smmMmmmmmmMmms",
    "smmmmmmmmmmmms",
    "smmmmMmmMmmmms",
    "smMmmmmmmmmMms",
    "smmmmmmmmmmmms",
    "smmmmmmmmmmmms",
    "smmmmmmmmmmmms",
    "smmmmmmmmmmmms",
    "ssssssssssssss",
]

# atlas regions: name -> (x, y, w, h); 1 px of padding around every region
SC_ATLAS = {
    "cf": (1, 1, 14, 10), "cs": (17, 1, 14, 10), "cb": (33, 1, 14, 10),
    "ct": (1, 13, 14, 14), "cp": (17, 13, 14, 14),
    "jt": (33, 13, 12, 12), "jb": (47, 13, 12, 12),
    "jf": (1, 29, 12, 5), "js": (15, 29, 12, 5), "jk": (29, 29, 12, 5),
}
SC_SIZE = 64


def sc_plain(w, h, dark_bottom=0, temple=False, crack=None):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            c = BONE
            if dark_bottom and y >= h - dark_bottom:
                c = BONE_S if y < h - 1 else BONE_D
            if x in (0, w - 1):
                c = BONE_S
            px[x, y] = hjitter(c)
    if temple:
        for y in range(h):
            for x in range(w):
                if (x - w * 0.42) ** 2 / 9 + (y - h * 0.45) ** 2 / 4 <= 1:
                    px[x, y] = BONE_D
    for (x, y) in crack or []:
        px[x, y] = BONE_D
    return img


def sc_rows(rows):
    img = from_rows(rows, SC_PAL)
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if px[x, y] in (BONE, BONE_S, SC_PAL["m"]):
                px[x, y] = hjitter(px[x, y])
    return img


def gen_skull_chest_texture():
    regions = {
        "cf": sc_rows(SC_CRANIUM_FRONT),
        "cs": sc_plain(14, 10, dark_bottom=2, temple=True),
        "cb": sc_plain(14, 10, dark_bottom=2),
        "ct": sc_plain(14, 14, crack=[(3, 2), (4, 3), (5, 3), (6, 4), (7, 5), (7, 6),
                                      (8, 7), (9, 7), (10, 8)]),
        "cp": sc_rows(SC_PALATE),
        "jt": sc_rows(SC_MOUTH),
        "jb": Image.new("RGBA", (12, 12), BONE_D),
        "jf": sc_rows(SC_JAW_FRONT),
        "js": sc_plain(12, 5, dark_bottom=2),
        "jk": sc_plain(12, 5, dark_bottom=2),
    }
    atlas = Image.new("RGBA", (SC_SIZE, SC_SIZE), (0, 0, 0, 255))
    for key, (x, y, w, h) in SC_ATLAS.items():
        img = regions[key]
        assert img.size == (w, h), (key, img.size)
        # repeat the edge pixels into the padding against texture bleeding
        col = Image.new("RGBA", (w + 2, h + 2))
        col.paste(img, (1, 1))
        col.paste(img.crop((0, 0, w, 1)), (1, 0))
        col.paste(img.crop((0, h - 1, w, h)), (1, h + 1))
        col.paste(col.crop((1, 0, 2, h + 2)), (0, 0))
        col.paste(col.crop((w, 0, w + 1, h + 2)), (w + 1, 0))
        atlas.paste(col, (x - 1, y - 1))
    save(atlas, "halloween_skullchest.png")


def box_faces(x0, y0, z0, x1, y1, z1, uv):
    """Quads of a box in Luanti coordinates (1/16 node units). Vertices go
    bottom-left, top-left, top-right, bottom-right as seen from outside, so the
    atlas regions are never mirrored. uv maps face -> atlas region key."""
    f = {
        "-z": [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)],
        "+z": [(x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (x0, y0, z1)],
        "+x": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        "-x": [(x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (x0, y0, z0)],
        "+y": [(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)],
        "-y": [(x0, y0, z1), (x0, y0, z0), (x1, y0, z0), (x1, y0, z1)],
    }
    return [(f[k], uv[k]) for k in f]


def rot_x(quads, angle, cy, cz):
    """Rotates quads around the X axis through (y=cy, z=cz); positive angle
    lifts the front (-Z) edge."""
    ca, sa = math.cos(angle), math.sin(angle)
    out = []
    for verts, key in quads:
        nv = []
        for x, y, z in verts:
            dy, dz = y - cy, z - cz
            nv.append((x, cy + dy * ca - dz * sa, cz + dy * sa + dz * ca))
        out.append((nv, key))
    return out


def write_atlas_obj(path, quads):
    lines = ["# generated by halloween/tools/gen_textures.py", "usemtl skull"]
    vlines, vtlines, vnlines, flines = [], [], [], []
    for i, (verts, key) in enumerate(quads):
        rx, ry, rw, rh = SC_ATLAS[key]
        uvs = [(rx, ry + rh), (rx, ry), (rx + rw, ry), (rx + rw, ry + rh)]
        a, b, c = (np.array(v, float) for v in verts[:3])
        n = np.cross(b - a, c - a)
        n = n / np.linalg.norm(n)
        for (x, y, z), (u, v) in zip(verts, uvs):
            # Luanti mirrors OBJ meshes on X
            vlines.append("v %.4f %.4f %.4f" % (-x / 16, y / 16, z / 16))
            vtlines.append("vt %.5f %.5f" % (u / SC_SIZE, 1 - v / SC_SIZE))
        vnlines.append("vn %.4f %.4f %.4f" % (n[0], n[1], n[2]))
        b0 = i * 4 + 1
        flines.append("f " + " ".join("%d/%d/%d" % (b0 + k, b0 + k, i + 1) for k in range(4)))
    with open(path, "w") as fh:
        fh.write("\n".join(lines[:1] + vlines + vtlines + vnlines + lines[1:] + flines) + "\n")


def gen_skull_chest_models():
    cranium = box_faces(-7, -3, -7, 7, 7, 7, {"-z": "cf", "+z": "cb", "+x": "cs", "-x": "cs",
                                               "+y": "ct", "-y": "cp"})
    jaw = box_faces(-6, -8, -7, 6, -3, 5, {"-z": "jf", "+z": "jk", "+x": "js", "-x": "js",
                                            "+y": "jt", "-y": "jb"})
    write_atlas_obj(os.path.join(MOD_MODELS, "halloween_skullchest.obj"), cranium + jaw)
    # open: the cranium tilts back around its back bottom edge, the mouth opens
    write_atlas_obj(os.path.join(MOD_MODELS, "halloween_skullchest_open.obj"),
                    rot_x(cranium, math.radians(38), -3, 7) + jaw)


def gen_skull_chest():
    gen_skull_chest_texture()
    gen_skull_chest_models()


# pumpkin painted on the lower panel of a locked door (12x11 px)
DOOR_PUMPKIN = [
    ".....Gg.....",
    "..dmmlGlmd..",
    ".dmlmmdmmld.",
    "dmYYmmdmYYmd",
    "dYWYlmdmYWYd",
    "dmmmlYYlmmmd",
    "dmYmlmmlmYmd",
    "dmYYYYYYYYmd",
    ".dmYmYYmYmd.",
    "..dmmlmlmd..",
    "...dddddd...",
]
DOOR_PUMPKIN_PAL = {"d": P_DARK, "m": P_MID, "l": P_LIGHT, "g": STEM, "G": STEM_D,
                    "Y": GLOW_Y, "W": GLOW_W}


def pumpkin_sprite(rows):
    img = from_rows(rows, DOOR_PUMPKIN_PAL)
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if px[x, y] in (P_MID, P_LIGHT):
                px[x, y] = hjitter(px[x, y], 6)
    return img


def gen_door_pumpkins():
    pk = outline(pad(pumpkin_sprite(DOOR_PUMPKIN)))  # 14x13
    # doors_door_*.png (38x32): front face x 0..15, back face x 16..31
    # (mirrored), the lower panel is x 2..13 / 18..29, y 18..29
    door = Image.new("RGBA", (38, 32), T)
    door.alpha_composite(pk, (1, 17))
    door.alpha_composite(pk.transpose(Image.FLIP_LEFT_RIGHT), (17, 17))
    save(door, "halloween_door_pumpkin.png")
    # trapdoor (16x16): on the middle of the cross
    trap = Image.new("RGBA", (16, 16), T)
    trap.alpha_composite(pk, (1, 2))
    save(trap, "halloween_trapdoor_pumpkin.png")
    # item badge (32x32 over a 16x16 icon = half size): bottom right corner
    badge = Image.new("RGBA", (32, 32), T)
    badge.alpha_composite(pk, (32 - 14, 32 - 13))
    save(badge, "halloween_badge_pumpkin.png")


def black_web(w, h, cx, cy, radius, a0, a1, spokes, rings):
    return cobweb(w, cx, cy, radius, spokes, rings, alpha=245, a0=a0, a1=a1,
                  color=WEB_BLACK, width=0.75, rng=hrnd, h=h)


def spider_on_thread(img, x, y_top, y, scale=1):
    sp = spider_sprite()
    if scale != 1:
        sp = sp.resize((sp.size[0] * scale, sp.size[1] * scale), Image.NEAREST)
    d = ImageDraw.Draw(img)
    d.line([(x, y_top), (x, y + 2)], fill=WEB_BLACK + (235,), width=1)
    img.alpha_composite(sp, (x - sp.size[0] // 2, y))


def gen_door_webs():
    # protector doors are two nodes with a 16x16 front tile each; the overlay
    # is drawn 4x finer (64 px per node) for thin threads
    full = Image.new("RGBA", (64, 128), T)
    full.alpha_composite(black_web(64, 128, 64, 0, 62, math.pi / 2, math.pi, 7, 6))
    full.alpha_composite(black_web(64, 128, 0, 128, 40, -math.pi / 2, 0, 6, 5))
    sp = spider_sprite().resize((34, 28), Image.NEAREST)
    full.alpha_composite(sp, (64 - 30, 6))
    spider_on_thread(full, 20, 0, 88)
    save(full.crop((0, 0, 64, 64)), "halloween_door_web_top.png")
    save(full.crop((0, 64, 64, 128)), "halloween_door_web_bottom.png")

    trap = Image.new("RGBA", (64, 64), T)
    trap.alpha_composite(black_web(64, 64, 0, 0, 58, 0, math.pi / 2, 6, 5))
    trap.alpha_composite(sp, (8, 6))
    save(trap, "halloween_trapdoor_web.png")

    badge = Image.new("RGBA", (32, 32), T)
    badge.alpha_composite(black_web(32, 32, 32, 32, 18, math.pi, 1.5 * math.pi, 5, 3))
    badge.alpha_composite(spider_sprite(), (32 - 17, 32 - 14))
    save(badge, "halloween_badge_spider.png")


def main():
    os.makedirs(TEX, exist_ok=True)
    os.makedirs(MOD_MODELS, exist_ok=True)
    gen_cobwebs()
    gen_skull()
    gen_skull_models()
    gen_pumpkin()
    gen_coffin()
    gen_armor()
    gen_ui()
    if len(sys.argv) >= 4:
        paint_sheep(sys.argv[1], "halloween_sheep.png", 128, 128)
        paint_sheep(sys.argv[2], "halloween_sheep_old.png", 160, 144)
        paint_sheep(sys.argv[3], "halloween_sheep_old_shaved.png", 160, 144)
    gen_skull_chest()
    gen_door_pumpkins()
    gen_door_webs()


if __name__ == "__main__":
    main()
