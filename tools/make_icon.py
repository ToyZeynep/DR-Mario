# tools/make_icon.ps1 (VirusHunt) betiğinin Python/Pillow karşılığı: aynı kompozisyon, 1024'lük tam ikon.
import sys, math
import numpy as np
from PIL import Image, ImageDraw

ROOT = sys.argv[1]; OUT = sys.argv[2]
SS = 2; S = 1024 * SS
DOCTOR = ROOT + '/assets/ui/doctor.png'; VIRUS = ROOT + '/assets/viruses/virus_red.png'

def over(dst, src):
    dst.alpha_composite(src); return dst

def background(size):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    t = np.clip((x + y) / (2.0 * size), 0, 1)[..., None]
    a = np.array([14, 21, 56], np.float32); b = np.array([58, 27, 99], np.float32)
    rgb = a + (b - a) * t
    img = np.concatenate([rgb, np.full((size, size, 1), 255, np.float32)], axis=2)
    base = Image.fromarray(img.astype(np.uint8), 'RGBA')
    # merkez ışığı
    R = size * 0.46; d = np.sqrt((x - size / 2) ** 2 + (y - size / 2) ** 2) / R
    alpha = np.where(d <= 1, 150 * (1 - d), 0)
    glow = np.zeros((size, size, 4), np.float32); glow[..., 0] = 92; glow[..., 1] = 120; glow[..., 2] = 226; glow[..., 3] = alpha
    base = over(base, Image.fromarray(glow.astype(np.uint8), 'RGBA'))
    # vinyet
    R2 = size * 0.62; d2 = np.sqrt((x - size / 2) ** 2 + (y - size / 2) ** 2) / R2
    a2 = np.where(d2 <= 1, 190 * d2, 0)
    vig = np.zeros((size, size, 4), np.float32); vig[..., 0] = 4; vig[..., 1] = 6; vig[..., 2] = 20; vig[..., 3] = a2
    return over(base, Image.fromarray(vig.astype(np.uint8), 'RGBA'))

def vgrad(w, h, top, bottom):
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    top = np.array(top, np.float32); bottom = np.array(bottom, np.float32)
    rgb = np.broadcast_to(top + (bottom - top) * t, (h, w, 3))
    return Image.fromarray(np.concatenate([rgb, np.full((h, w, 1), 255, np.float32)], axis=2).astype(np.uint8), 'RGBA')

def stadium_mask(size, x0, y0, w, h):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=h / 2, fill=255)
    return m

def capsule(canvas, cx, cy, length, thick, angle):
    pad = int(length * 0.2)
    W = int(length + 2 * pad); H = int(length + 2 * pad)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ox, oy = W / 2, H / 2
    half = length / 2; r = thick / 2; outline = 18.0 * SS
    body = stadium_mask((W, H), ox - half, oy - r, length, thick)
    layer.paste(Image.new('RGBA', (W, H), (8, 8, 20, 255)), (0, 0), body)
    ih = half - outline; ir = r - outline
    inner = stadium_mask((W, H), ox - ih, oy - ir, ih * 2, ir * 2)
    red = vgrad(int(half), int(thick), (245, 86, 64), (176, 28, 24))
    blue = vgrad(int(half), int(thick), (96, 168, 250), (30, 86, 190))
    halves = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    halves.paste(red, (int(ox - half), int(oy - r)))
    halves.paste(blue, (int(ox), int(oy - r)))
    layer.paste(halves, (0, 0), inner)
    d = ImageDraw.Draw(layer)
    d.line([(ox, oy - ir), (ox, oy + ir)], fill=(8, 8, 20, 255), width=int(14 * SS))
    sx = ox - ih + ir * 0.35; sy = oy - ir * 0.72; sw = ih * 2 - ir * 0.7; sh = ir * 0.5
    shine = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shine).rounded_rectangle([sx, sy, sx + sw, sy + sh], radius=sh / 2, fill=(255, 255, 255, 120))
    sm = Image.new('L', (W, H), 0); sm.paste(shine.getchannel('A'), (0, 0), inner)
    shine.putalpha(sm)
    layer.alpha_composite(shine)
    layer = layer.rotate(-angle, resample=Image.BICUBIC, expand=False)
    canvas.alpha_composite(layer, (int(cx - W / 2), int(cy - H / 2)))

def sprite(canvas, path, cx, cy, height, angle):
    img = Image.open(path).convert('RGBA')
    w = height * img.width / img.height
    spr = img.resize((int(w), int(height)), Image.LANCZOS)
    pad = int(height * 0.2)
    W = int(w + 2 * pad); H = int(height + 2 * pad)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    a = np.asarray(spr.getchannel('A'), np.float32) * 0.13
    shadow = np.zeros((spr.height, spr.width, 4), np.uint8); shadow[..., 3] = a.astype(np.uint8)
    shadow = Image.fromarray(shadow, 'RGBA')
    for dd in (0.012, 0.026, 0.040, 0.054):
        layer.alpha_composite(shadow, (int(pad + height * dd * 0.6), int(pad + height * dd)))
    layer.alpha_composite(spr, (pad, pad))
    if angle: layer = layer.rotate(-angle, resample=Image.BICUBIC, expand=False)
    canvas.alpha_composite(layer, (int(cx - W / 2), int(cy - H / 2)))

def figures(canvas, size, spread, fig):
    c = size / 2.0
    sprite(canvas, DOCTOR, c - size * 0.165 * spread, c + size * 0.035 * spread, size * 0.66 * fig, 0.0)
    sprite(canvas, VIRUS, c + size * 0.235 * spread, c - size * 0.235 * spread, size * 0.38 * fig, -12.0)
    capsule(canvas, c + size * 0.215 * spread, c + size * 0.215 * spread, size * 0.42 * fig, size * 0.145 * fig, -38.0)

icon = background(S)
figures(icon, S, 1.0, 1.0)
icon = icon.resize((1024, 1024), Image.LANCZOS).convert('RGB')  # App Store ikonu saydam olamaz
icon.save(OUT)
print('ok', OUT)
