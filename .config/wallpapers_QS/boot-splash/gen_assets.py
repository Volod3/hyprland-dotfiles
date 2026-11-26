#!/usr/bin/env python3
"""Графіка для заставки завантаження archglass (Plymouth) і для відео-прев'ю.
Запуск: ~/.local/share/parallax-venv/bin/python gen_assets.py"""
import os, subprocess, io, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "archglass")
os.makedirs(OUT, exist_ok=True)
BLUE = (140, 200, 255); PINK = (242, 184, 212); ARCH = (23, 147, 209)
S1 = 240                         # висота значка в кінці анімації

def save(img, name): img.save(os.path.join(OUT, name))

# ── значок Arch з SVG ──
png = subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", "/usr/share/pixmaps/archlinux-logo.svg"], capture_output=True).stdout
ic = Image.open(io.BytesIO(png)).convert("RGBA")
ic = ic.crop(ic.getchannel("A").getbbox())
w = round(ic.width * S1 / ic.height)
ic = ic.resize((w, S1), Image.LANCZOS)
A = np.asarray(ic.getchannel("A")).astype(np.float32) / 255
def fill(rgb):
    im = Image.new("RGBA", ic.size, rgb + (0,)); im.putalpha(ic.getchannel("A")); return im
save(fill(ARCH), "icon_blue.png")

# градієнт блакитний → рожевий по діагоналі + ледь світліший верх
yy, xx = np.mgrid[0:ic.height, 0:ic.width].astype(np.float32)
g = np.clip((xx / ic.width * 0.55 + yy / ic.height * 0.45), 0, 1)
rgb = np.zeros((ic.height, ic.width, 3), np.float32)
for c in range(3): rgb[..., c] = BLUE[c] * (1 - g) + PINK[c] * g
rgb += (1 - yy / ic.height)[..., None] * 18
def to_img(rgb, alpha):
    a = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")
save(to_img(rgb, A), "icon_grad.png")

# відблиск, що пробігає по значку (20 кадрів)
for i in range(20):
    pos = -0.4 + 1.8 * i / 19                       # смуга йде з лівого верху вниз праворуч
    d = (xx / ic.width + yy / ic.height) / 2 - pos / 1.0 * 0.5 - 0.0
    band = np.exp(-((d - 0.0) ** 2) / (2 * 0.045 ** 2)) * 0.85
    r2 = rgb + band[..., None] * (255 - rgb)
    save(to_img(r2, A), "shine_%02d.png" % i)

# ── сяйво позаду ──
R = 360
yy2, xx2 = np.mgrid[0:2 * R, 0:2 * R].astype(np.float32)
d = np.sqrt((xx2 - R) ** 2 + (yy2 - R) ** 2) / R
al = np.clip(1 - d, 0, 1) ** 2.2
mix = np.clip((xx2 + yy2) / (4 * R), 0, 1)[..., None]
col = np.array(BLUE, np.float32) * (1 - mix) + np.array(PINK, np.float32) * mix
save(to_img(col, al * 0.9), "glow.png")

# ── кільця-хвилі ──
def ring(rgb, name, size=600, width=0.012):
    yy3, xx3 = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt((xx3 - size / 2) ** 2 + (yy3 - size / 2) ** 2) / (size / 2)
    # кільце на радіусі 0.8 і плавне згасання до краю — ореол не обрізається квадратом картинки
    al = np.exp(-((r - 0.80) ** 2) / (2 * width ** 2)) + 0.35 * np.exp(-((r - 0.80) ** 2) / (2 * (width * 5) ** 2))
    al = al * np.clip((0.99 - r) / 0.1, 0, 1)
    save(to_img(np.ones((size, size, 3)) * np.array(rgb), np.clip(al, 0, 1)), name)
ring(BLUE, "ring_blue.png"); ring(PINK, "ring_pink.png")

# ── частинки: м'які точки з ореолом ──
for nm, c in (("b", BLUE), ("p", PINK), ("w", (236, 240, 250))):
    for k, s in enumerate((10, 16, 24)):
        yy4, xx4 = np.mgrid[0:s, 0:s].astype(np.float32)
        r = np.sqrt((xx4 - s / 2 + 0.5) ** 2 + (yy4 - s / 2 + 0.5) ** 2) / (s / 2)
        al = np.clip(1 - r, 0, 1) ** 1.6 + np.clip(1 - r * 2.6, 0, 1)
        save(to_img(np.ones((s, s, 3)) * np.array(c), np.clip(al, 0, 1)), "dot_%s%d.png" % (nm, k))

# ── напис ──
font = ImageFont.truetype(os.path.join(HERE, "Comfortaa.ttf"), 60)
try: font.set_variation_by_name("Light")
except Exception: pass
text = "arch linux"; spacing = 10
widths = [font.getlength(ch) for ch in text]
tw = int(sum(widths) + spacing * (len(text) - 1)) + 8
th = 90
mask = Image.new("L", (tw, th), 0); dr = ImageDraw.Draw(mask); x = 4
for ch, wch in zip(text, widths):
    dr.text((x, 8), ch, font=font, fill=255); x += wch + spacing
yy5, xx5 = np.mgrid[0:th, 0:tw].astype(np.float32)
g = (xx5 / tw)[..., None]
col = np.array((232, 236, 244), np.float32) * (1 - g) * 0.0 + (np.array(BLUE) * (1 - g) + np.array(PINK) * g)
col = col * 0.35 + 255 * 0.65 * np.ones_like(col) * 0 + np.array((232, 236, 244)) * 0.65
save(to_img(col, np.asarray(mask).astype(np.float32) / 255), "title.png")

# ── перший кадр як у прошивки: напис з splash-arch.bmp ──
bmp = Image.open("/usr/share/systemd/bootctl/splash-arch.bmp").convert("RGBA")
b = np.asarray(bmp).astype(np.float32)
blue_mask = (np.abs(b[..., 0] - 23) < 40) & (np.abs(b[..., 2] - 209) < 50) & (b[..., 2] > 120)
cols = np.where(blue_mask[:, :180].any(0))[0]; rows = np.where(blue_mask[:, :180].any(1))[0]
icon_box = (int(cols.min()), int(rows.min()), int(cols.max()) + 1, int(rows.max()) + 1)
split = 0                               # шар напису = уся картинка прошивки без синього значка (літери не обрізаються)
txt = bmp
ta = np.asarray(txt).astype(np.float32)
alpha = np.clip(ta[..., :3].max(-1) / 77 * 255, 0, 255)            # чорний фон → прозорий
blue_px = ta[..., 2] > 120
alpha = np.where(blue_px, np.clip(ta[..., 2] / 209 * 255, 0, 255), alpha)
rgbt = np.where(blue_px[..., None], np.array(ARCH, np.float32), np.array((77, 77, 77), np.float32))
icon_px = blue_px & (np.arange(ta.shape[1])[None, :] < icon_box[2])     # синій значок малюємо окремо (він рухається)
alpha = np.where(icon_px, 0, alpha)
save(to_img(rgbt, alpha / 255), "splash_text.png")

# розміщення відносно центру екрана (bmp у прошивки стоїть по центру)
L = {"bmp_w": bmp.width, "bmp_h": bmp.height, "icon_box": icon_box, "split": split,
     "icon_w": ic.width, "icon_h": ic.height, "title_w": tw, "title_h": th}
import json; json.dump(L, open(os.path.join(OUT, "layout.json"), "w"))
print(L)
