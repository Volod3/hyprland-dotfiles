#!/usr/bin/env python3
"""Додаткова графіка для космічної версії заставки (archglass): зорі, туманності, орбіта, комета,
кадри масштабу значка (щоб Plymouth нічого не масштабував на льоту — плавно).
Запуск після gen_assets.py:  ~/.local/share/parallax-venv/bin/python cosmic_assets.py"""
import json, os
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "archglass")
L = json.load(open(os.path.join(A, "layout.json")))
BLUE = np.array((140, 200, 255), np.float32); PINK = np.array((242, 184, 212), np.float32)
WHITE = np.array((236, 240, 250), np.float32)
rng = np.random.default_rng(7)


def rgba(rgb, a):
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 1) * 255]).astype(np.uint8), "RGBA")


# ── зорі: 3 розміри × 3 кольори ──
for ci, (nm, c) in enumerate((("w", WHITE), ("b", BLUE), ("p", PINK))):
    for k, s in enumerate((5, 8, 12)):
        yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
        r = np.sqrt((xx - s / 2 + 0.5) ** 2 + (yy - s / 2 + 0.5) ** 2) / (s / 2)
        a = np.clip(1 - r, 0, 1) ** 2.2 + 0.9 * np.clip(1 - r * 3.2, 0, 1)
        rgba(np.ones((s, s, 3)) * c, a).save(os.path.join(A, "star_%s%d.png" % (nm, k)))


# ── туманності: м'які кольорові хмари з «пилом» ──
def nebula(w, h, col_a, col_b, seed, name):
    g = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    for _ in range(26):
        cx, cy = g.uniform(0.15, 0.85) * w, g.uniform(0.2, 0.8) * h
        sx, sy = g.uniform(0.08, 0.28) * w, g.uniform(0.08, 0.3) * h
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        acc += g.uniform(0.3, 1.0) * np.exp(-(((xx - cx) / sx) ** 2 + ((yy - cy) / sy) ** 2) / 2)
    noise = np.asarray(Image.fromarray((g.random((h // 8, w // 8)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255
    acc = acc / acc.max() * (0.65 + 0.35 * noise)
    mix = np.clip(np.linspace(0, 1, w)[None, :] * 0.7 + noise * 0.3, 0, 1)[..., None]
    rgb = col_a * (1 - mix) + col_b * mix
    a = np.clip(acc ** 1.4, 0, 1) * 0.8
    # край завжди прозорий
    ex = np.minimum(np.minimum(np.arange(w), np.arange(w)[::-1]) / (0.12 * w), 1)[None, :]
    ey = np.minimum(np.minimum(np.arange(h), np.arange(h)[::-1]) / (0.15 * h), 1)[:, None]
    a = a * ex * ey
    # еліптичне згасання — без прямокутних країв
    yy2, xx2 = np.mgrid[0:h, 0:w].astype(np.float32)
    e = ((xx2 / w * 2 - 1) ** 2 + (yy2 / h * 2 - 1) ** 2)
    a = a * np.clip(1 - e, 0, 1) ** 1.3
    img = rgba(rgb, a).filter(ImageFilter.GaussianBlur(22))
    img.save(os.path.join(A, name))


nebula(1100, 640, BLUE * 0.85, np.array((120, 120, 230), np.float32), 3, "nebula_a.png")
nebula(1000, 600, PINK, np.array((190, 140, 230), np.float32), 11, "nebula_b.png")


# ── орбіта: нахилений еліпс, задня половина (за значком) і передня ──
OW, OH = 860, 250
def orbit(half, name):
    yy, xx = np.mgrid[0:OH, 0:OW].astype(np.float32)
    nx = (xx - OW / 2) / (OW / 2 - 12)
    ny = (yy - OH / 2) / (OH / 2 - 12)
    d = np.sqrt(nx ** 2 + ny ** 2)
    line = np.exp(-((d - 1) ** 2) / (2 * 0.006 ** 2)) + 0.25 * np.exp(-((d - 1) ** 2) / (2 * 0.03 ** 2))
    t = np.clip((nx + 1) / 2, 0, 1)[..., None]
    rgb = BLUE * (1 - t) + PINK * t
    sel = (ny < 0) if half == "back" else (ny >= 0)
    a = np.where(sel, line, 0) * (0.45 if half == "back" else 0.9)
    # край біля боків плавно
    rgba(rgb, a).save(os.path.join(A, name))


orbit("back", "orbit_back.png"); orbit("front", "orbit_front.png")

# ── комета: світла голова з довгим хвостом (летить праворуч-вниз) ──
CW, CH = 360, 24
yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
u = xx / CW
core = np.exp(-((yy - CH / 2) ** 2) / (2 * (1.2 + 3.5 * (1 - u)) ** 2))
a = core * (u ** 2.4) + np.exp(-(((xx - CW + 8) / 6) ** 2 + ((yy - CH / 2) / 6) ** 2))
rgb = (BLUE * (1 - u[..., None]) + WHITE * u[..., None])
rgba(rgb, np.clip(a, 0, 1)).rotate(-18, expand=True, resample=Image.BICUBIC).save(os.path.join(A, "comet.png"))

# ── кадри масштабу значка (від розміру в прошивці до кінцевого) ──
S0 = L["icon_box"][3] - L["icon_box"][1]
ib = Image.open(os.path.join(A, "icon_blue.png")); ig = Image.open(os.path.join(A, "icon_grad.png"))
NS = 40
for i in range(NS + 1):
    h = round(S0 + (ib.height - S0) * i / NS)
    w = round(h * ib.width / ib.height)
    ib.resize((w, h), Image.LANCZOS).save(os.path.join(A, "sb_%02d.png" % i))
    ig.resize((w, h), Image.LANCZOS).save(os.path.join(A, "sg_%02d.png" % i))
L["scale_steps"] = NS
json.dump(L, open(os.path.join(A, "layout.json"), "w"))
print("готово", L)
