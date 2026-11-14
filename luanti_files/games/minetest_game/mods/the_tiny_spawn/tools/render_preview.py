"""Render previews of the generated spawn straight from a world's map.sqlite.

usage: python3 -I render_preview.py <map.sqlite> <nodeinfo.json> <out_dir> <textures_dir> [<textures_dir> ...]

nodeinfo.json: {node_name: {tile, drawtype, light, alpha}} dumped from the server
(see README).  Produces preview_iso.png (night, isometric) and preview_top.png.
"""
import sqlite3, struct, sys, os, json, glob
from compression import zstd
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DB, INFO, OUT = sys.argv[1:4]
TEXDIRS = sys.argv[4:]
EXT = 70
YMIN, YMAX = -4, 140
info = json.load(open(INFO))

# ------------------------------------------------------------ load voxels
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)


def parse(data):
    d = zstd.decompress(data[1:])
    p = 1 + 2 + 4 + 1
    n = struct.unpack('>H', d[p:p + 2])[0]; p += 2
    names = {}
    for _ in range(n):
        i, l = struct.unpack('>HH', d[p:p + 4]); p += 4
        names[i] = d[p:p + l].decode(); p += l
    p += 2
    p0 = np.frombuffer(d[p:p + 8192], dtype='>u2').reshape(16, 16, 16)
    return names, p0


NX, NY = 2 * EXT + 1, YMAX - YMIN + 1
names_list, name_idx = ["air"], {"air": 0}
vox = np.zeros((NX, NY, NX), dtype=np.int32)
for bx in range(-EXT // 16 - 1, EXT // 16 + 1):
    for bz in range(-EXT // 16 - 1, EXT // 16 + 1):
        for by in range(YMIN // 16 - 1, YMAX // 16 + 1):
            r = con.execute("select data from blocks where x=? and y=? and z=?", (bx, by, bz)).fetchone()
            if not r:
                continue
            names, p0 = parse(r[0])
            lut = np.zeros(max(names) + 1, dtype=np.int32)
            for k, nm in names.items():
                if nm not in name_idx:
                    name_idx[nm] = len(names_list); names_list.append(nm)
                lut[k] = name_idx[nm]
            ids = lut[p0]
            for lz in range(16):
                z = bz * 16 + lz
                if abs(z) > EXT:
                    continue
                for ly in range(16):
                    y = by * 16 + ly
                    if y < YMIN or y > YMAX:
                        continue
                    xs = bx * 16 + np.arange(16)
                    mk = np.abs(xs) <= EXT
                    vox[xs[mk] + EXT, y - YMIN, z + EXT] = ids[lz, ly][mk]
if "ignore" in name_idx:
    vox[vox == name_idx["ignore"]] = 0

# ------------------------------------------------------------ materials
texfiles = {}
for d in TEXDIRS:
    for f in glob.glob(os.path.join(d, "**", "*.png"), recursive=True):
        texfiles.setdefault(os.path.basename(f), f)


def load_tex(tile):
    base = tile.split("^")[0].strip("()")
    if base.startswith("["):
        return None
    f = texfiles.get(base)
    if not f:
        return None
    im = Image.open(f).convert("RGBA")
    w = im.width
    return np.asarray(im)[:w, :w].astype(float)


THIN = ("fence", "walls:", "lamp_pole", "light_pillar")
mat = {}
for i, nm in enumerate(names_list):
    if nm == "air":
        continue
    ni = info.get(nm, {})
    dt = ni.get("drawtype", "normal")
    a = load_tex(ni.get("tile", "")) if ni else None
    if a is not None:
        w = a[..., 3:4] / 255.0
        col = (a[..., :3] * w).sum((0, 1)) / max(w.sum(), 1)
    else:
        col = np.array([120, 120, 120.0])
    light = ni.get("light", 0) or 0
    alpha = 1.0
    if ni.get("alpha") == "blend" or dt in ("liquid", "flowingliquid"):
        alpha = 0.75 if dt in ("liquid", "flowingliquid") else 0.45
    if "beam_halo" in nm:
        alpha = 0.18
    if "beam_core" in nm:
        alpha = 0.5
    box = (0, 1, 0, 1, 0, 1)
    if dt in ("plantlike", "firelike", "torchlike", "plantlike_rooted"):
        box = (0.3, 0.7, 0, 0.8, 0.3, 0.7)
        if "grass_" in nm:
            box = (0.35, 0.65, 0, 0.45, 0.35, 0.65)
    elif dt == "raillike":
        box = (0, 1, 0, 0.1, 0, 1)
    elif "slab_" in nm or "waterlily" in nm or "petals" in nm or "solar_panel" in nm:
        box = (0, 1, 0, 0.12 if ("waterlily" in nm or "petals" in nm) else 0.5, 0, 1)
    elif any(t in nm for t in THIN):
        box = (0.38, 0.62, 0, 1, 0.38, 0.62)
    elif "lantern" in nm or "lamp_head" in nm:
        box = (0.25, 0.75, 0, 0.8, 0.25, 0.75)
    elif "holo_pool" in nm:
        box = (0, 1, 0, 0.75, 0, 1)
    full = box == (0, 1, 0, 1, 0, 1)
    solid = alpha >= 1 and full and dt not in ("allfaces_optional", "allfaces", "glasslike")
    mat[i] = dict(col=col, em=light >= 5, light=light, alpha=alpha, box=box, full=full, solid=solid,
                  name=nm, dt=dt, tex=a)

solid = np.zeros(len(names_list), dtype=bool)
for i, m in mat.items():
    solid[i] = m["solid"]

# ------------------------------------------------------------ top view
TS = 8
top = np.zeros((NX * TS, NX * TS, 3), dtype=np.uint8)
top[:] = (10, 8, 20)
for x in range(NX):
    for z in range(NX):
        col = vox[x, :, z]
        for yy in np.nonzero(col)[0][::-1]:
            m = mat[col[yy]]
            if "beam_" in m["name"] or "grass_" in m["name"]:
                continue
            a = m["tex"]
            shade = 1.0 if m["em"] else 0.62 + 0.38 * min(1, max(0, (yy + YMIN) / 25))
            if a is not None and a.shape[0] >= TS:
                step = a.shape[0] // TS
                sub = a[::step, ::step][:TS, :TS].copy()
                lowa = sub[..., 3] < 128
                sub[lowa, :3] = m["col"]
                rgb = sub[..., :3]
            else:
                rgb = np.ones((TS, TS, 3)) * m["col"]
            py = (NX - 1 - z) * TS
            top[py:py + TS, x * TS:x * TS + TS] = np.clip(rgb * shade, 0, 255).astype(np.uint8)
            break
Image.fromarray(top).save(os.path.join(OUT, "preview_top.png"))

# ------------------------------------------------------------ isometric night view
SC = 2
A, Bq, C = 7 * SC, 3.5 * SC, 8.5 * SC
W = int(2 * NX * A + 80)
H = int(2 * NX * Bq + NY * C * 0.75 + 80)
ox, oy = W // 2, int(NY * C * 0.75) + int(NX * Bq)
base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
emis = Image.new("RGBA", (W, H), (0, 0, 0, 0))
db, de = ImageDraw.Draw(base, "RGBA"), ImageDraw.Draw(emis, "RGBA")


def proj(x, y, z):
    return ox + (x - z) * A, oy - (x + z) * Bq - y * C


def night(col, f):
    c = col * f * np.array([0.5, 0.5, 0.68]) + np.array([8, 6, 20])
    return c


nz = np.argwhere(vox > 0)
order = np.argsort(-(nz[:, 0] + nz[:, 2]) * 1000 + nz[:, 1], kind="stable")
nz = nz[order]
shape = vox.shape

# coloured light spill from bright sources onto nearby surfaces (cheap approximation)
lightmap = np.zeros((shape[0], shape[2], 3))
bright = [i for i, m in mat.items() if m["light"] >= 10]
for ix, iy, iz in np.argwhere(np.isin(vox, bright)):
    c = mat[vox[ix, iy, iz]]["col"]
    x0, x1, z0, z1 = max(0, ix - 3), min(shape[0], ix + 4), max(0, iz - 3), min(shape[2], iz + 4)
    lightmap[x0:x1, z0:z1] += c * 0.06

for ix, iy, iz in nz:
    m = mat[vox[ix, iy, iz]]
    x, y, z = ix - EXT, iy + YMIN, iz - EXT

    def nb(dx, dy, dz):
        jx, jy, jz = ix + dx, iy + dy, iz + dz
        if not (0 <= jx < shape[0] and 0 <= jz < shape[2]):
            return True
        if not (0 <= jy < shape[1]):
            return False
        return solid[vox[jx, jy, jz]]

    if m["full"]:
        up, south, west = not nb(0, 1, 0), not nb(0, 0, -1), not nb(-1, 0, 0)
        if not (up or south or west):
            continue
    else:
        up = south = west = True
    bx0, bx1, by0, by1, bz0, bz1 = m["box"]
    P = lambda a, b, c: proj(x + a, y + b, z + c)
    faces = []
    if up:
        faces.append(([P(bx0, by1, bz0), P(bx1, by1, bz0), P(bx1, by1, bz1), P(bx0, by1, bz1)], 1.0))
    if south:
        faces.append(([P(bx0, by0, bz0), P(bx1, by0, bz0), P(bx1, by1, bz0), P(bx0, by1, bz0)], 0.62))
    if west:
        faces.append(([P(bx0, by0, bz0), P(bx0, by0, bz1), P(bx0, by1, bz1), P(bx0, by1, bz0)], 0.8))
    col = m["col"]
    for poly, f in faces:
        if m["em"]:
            c = tuple(int(min(255, v * (0.75 + 0.25 * f))) for v in col)
            db.polygon(poly, fill=c + (int(255 * m["alpha"]),))
            de.polygon(poly, fill=c + (int(255 * min(1, m["alpha"] * 1.4)),))
        else:
            lit = np.clip(lightmap[ix, iz], 0, 90)
            c = night(col, f) + lit * (0.6 if f == 1.0 else 0.4)
            db.polygon(poly, fill=tuple(int(min(255, v)) for v in c) + (int(255 * m["alpha"]),))
            if m["alpha"] >= 1:
                de.polygon(poly, fill=(0, 0, 0, 255))

g = np.linspace(0, 1, H)[:, None]
arr = (np.array([10, 6, 30]) * (1 - g) + np.array([46, 18, 74]) * g)
arr = np.repeat(arr[:, None, :], W, 1).astype(np.uint8)
bg = Image.fromarray(np.dstack([arr, np.full((H, W, 1), 255, np.uint8)]), "RGBA")
bd = ImageDraw.Draw(bg)
rng = np.random.default_rng(3)
for _ in range(500):
    v = int(rng.integers(120, 255))
    bd.point((int(rng.integers(0, W)), int(rng.integers(0, H // 2))), fill=(v, v, 255, 255))
img = Image.alpha_composite(bg, base)
e = emis.convert("RGB")
out = np.asarray(img.convert("RGB")).astype(float)
out += np.asarray(e.filter(ImageFilter.GaussianBlur(5 * SC))).astype(float) * 0.8
out += np.asarray(e.filter(ImageFilter.GaussianBlur(20 * SC))).astype(float) * 0.7
iso = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
bbox = Image.fromarray((np.asarray(base)[..., 3] > 0).astype(np.uint8) * 255).getbbox()
if bbox:
    l, t, r, b = bbox
    iso = iso.crop((max(0, l - 40), max(0, t - 40), min(W, r + 40), min(H, b + 40)))
full = np.asarray(iso).astype(float)
hh, ww = full.shape[0] // 2 * 2, full.shape[1] // 2 * 2
small = full[:hh, :ww].reshape(hh // 2, 2, ww // 2, 2, 3).mean((1, 3))
Image.fromarray(small.astype(np.uint8)).save(os.path.join(OUT, "preview_iso.png"))
# close-up of the centre
cx, cy = ww // 2, int(hh * 0.62)
cw, ch = int(ww * 0.42), int(hh * 0.36)
Image.fromarray(full[cy - ch // 2:cy + ch // 2, cx - cw // 2:cx + cw // 2].astype(np.uint8)).save(
    os.path.join(OUT, "preview_close.png"))
print("ok", iso.size)
