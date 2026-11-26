#!/usr/bin/env python3
"""Шари паралакс-шпалер для тем (без швів: кожен шар окремий, з прозорістю).

  ~/.local/share/parallax-venv/bin/python gen_scenes.py [neon|synthwave|aurora|all]

  neon      — «Неон Сіті»: оригінальні намальовані шари міста (assets/parallax_backgrounds/Layer*.png),
              складені в повноекранні полотна в тих самих позиціях, що були в початковому конфігу
  synthwave — процедурно: небо, зорі, сонце зі смугами, неонові гори, сітка-підлога
  aurora    — процедурно: зоряне небо, північне сяйво (тайлиться по горизонталі — пливе саме), гори, ліс
Вихід: bg_parallax_MDRG/assets/parallax_backgrounds/<тема>/layerNN.png + layers.json + preview.png
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HOME = os.path.expanduser("~")
BASE = os.path.join(HOME, ".config/wallpapers_QS/bg_parallax_MDRG")
PB = os.path.join(BASE, "assets/parallax_backgrounds")
rng = np.random.default_rng(1234)


def save_layers(name, layers, strength_px):
    """layers: [(PIL RGBA, depth, extra dict)] від далекого до близького."""
    out = os.path.join(PB, name)
    os.makedirs(out, exist_ok=True)
    meta = []
    prev = None
    for i, (img, depth, extra) in enumerate(layers):
        fn = "layer%02d.png" % i
        img.save(os.path.join(out, fn), optimize=True)
        d = {"file": "./assets/parallax_backgrounds/%s/%s" % (name, fn), "crop": True, "depth": round(depth, 3)}
        d.update(extra or {})
        meta.append(d)
        prev = img if prev is None else Image.alpha_composite(prev, img)
    json.dump({"layers": meta, "strength": strength_px}, open(os.path.join(out, "layers.json"), "w"), indent=1)
    w, h = prev.size
    sx, sy = (w - 1920) // 2, (h - 1080) // 2
    prev.crop((sx, sy, sx + 1920, sy + 1080)).convert("RGB").save(os.path.join(out, "preview.png"))
    prev.crop((sx, sy, sx + 1920, sy + 1080)).convert("RGB").resize((480, 270), Image.LANCZOS).save(os.path.join(out, "thumb.png"))
    print(name, "→", len(layers), "шарів")


def rgba(arr_rgb, alpha):
    a = np.dstack([np.clip(arr_rgb, 0, 255), np.clip(alpha, 0, 1) * 255]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def vgrad(w, h, stops):
    """Вертикальний градієнт: stops = [(0..1, (r,g,b)), ...]"""
    y = np.linspace(0, 1, h)[:, None]
    out = np.zeros((h, w, 3), np.float32)
    for c in range(3):
        out[..., c] = np.interp(y, [p for p, _ in stops], [col[c] for _, col in stops])
    return out


def stars(w, h, n, ymax=1.0, big=0.04, seed=0, tint=((255, 255, 255),)):
    g = np.random.default_rng(seed)
    img = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y = g.uniform(0, w * 2), g.uniform(0, h * 2 * ymax) * g.uniform(0.3, 1) ** 0.4
        r = g.uniform(0.6, 1.6) * (3.2 if g.random() < big else 1)
        a = int(g.uniform(90, 255))
        col = tint[g.integers(len(tint))]
        d.ellipse((x - r, y - r, x + r, y + r), fill=col + (a,))
    img = img.resize((w, h), Image.LANCZOS)
    glow = img.filter(ImageFilter.GaussianBlur(3))
    return Image.alpha_composite(glow, img)


def ridge(w, h, base_y, amp, rough, seed, smooth=1):
    """Лінія хребта (y для кожного x) — сума синусоїд, періодична по x."""
    g = np.random.default_rng(seed)
    x = np.linspace(0, 1, w, endpoint=False)
    y = np.full(w, base_y, np.float32)
    for k in range(1, 9):
        y += amp / (k ** rough) * np.sin(2 * math.pi * (k * x + g.random())) * g.uniform(0.6, 1.2)
    if smooth > 1:
        y = np.convolve(np.r_[y[-smooth:], y, y[:smooth]], np.ones(smooth) / smooth, "same")[smooth:-smooth]
    return y


def silhouette(w, h, ys, color, rim=None, rim_w=2.0, grad=None):
    ss = 2
    W, H = w * ss, h * ss
    yy = np.arange(H)[:, None] / ss
    ysf = np.interp(np.arange(W) / ss, np.arange(w), ys)[None, :]
    inside = (yy >= ysf).astype(np.float32)
    rgb = np.ones((H, W, 3), np.float32) * np.array(color, np.float32)
    if grad is not None:          # затемнення донизу
        t = np.clip((yy - ysf) / grad[0], 0, 1)
        rgb = rgb * (1 - t[..., None]) + np.array(grad[1], np.float32) * t[..., None]
    alpha = inside
    if rim is not None:
        dist = np.abs(yy - ysf)
        line = np.exp(-(dist / (rim_w * ss / 2)) ** 2)
        rgb = rgb * (1 - line[..., None]) + np.array(rim, np.float32) * line[..., None]
        alpha = np.maximum(alpha, line)
    img = rgba(rgb, alpha).resize((w, h), Image.LANCZOS)
    return img


# ═════════════ «Неон Сіті» ═════════════
def neon():
    src = PB
    W, H = 1960, 1120                    # екран + 2×strength(20) — як у початковому конфігу
    f = W / 2048
    layers = []
    sky = Image.open(os.path.join(src, "LayerClouds5BackgroundParalax.png")).convert("RGBA").resize((W, H), Image.BICUBIC)
    sky = Image.alpha_composite(sky, stars(W, H, 260, ymax=0.55, big=0.02, seed=5, tint=((255, 255, 255), (255, 170, 240), (140, 220, 255))))
    layers.append((sky, 0.02, {}))
    order = [("LayerClouds4BackgroundParalax.png", -30, 0.12, 9), ("LayerClouds3BackgroundParalax.png", -80, 0.2, 14),
             ("LayerClouds2BackgroundParalax.png", 100, 0.3, 0), ("LayerClouds1BackgroundParalax.png", 170, 0.38, 0),
             ("Layer4BackgroundParalax.png", 0, 0.5, 0), ("Layer3BackgroundParalax.png", 40, 0.62, 0),
             ("Layer2BackgroundParalax.png", 320, 0.78, 0), ("Layer1BackgroundParalax.png", 430, 0.95, 0)]
    for fn, yoff, depth, speed in order:
        im = Image.open(os.path.join(src, fn)).convert("RGBA")
        w, h = round(im.width * f), round(im.height * f)
        im = im.resize((w, h), Image.LANCZOS)
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        y = round((H - h) / 2 + yoff)
        canvas.alpha_composite(im, (0, max(-h, y)))
        if y + h < H and "Layer" in fn and "Clouds" not in fn:     # будинки — без «дірки» знизу
            bottom = im.crop((0, h - 2, w, h)).resize((w, H - (y + h)))
            canvas.alpha_composite(bottom, (0, y + h))
        layers.append((canvas, depth, {"speed": speed} if speed else {}))
    save_layers("neon", layers, 20)


# ═════════════ «Синтвейв» ═════════════
def synthwave():
    W, H = 2040, 1200
    hz = int(H * 0.63)                                    # лінія горизонту
    layers = []
    sky = vgrad(W, H, [(0, (9, 2, 28)), (0.35, (38, 6, 64)), (0.55, (120, 20, 110)), (0.63, (255, 70, 140)), (1, (255, 70, 140))])
    img = rgba(sky, np.ones((H, W)))
    img = Image.alpha_composite(img, stars(W, H, 420, ymax=0.5, big=0.03, seed=7, tint=((255, 255, 255), (255, 190, 240), (180, 220, 255))))
    layers.append((img, 0.02, {}))
    # сонце
    R, cx, cy = 280, W // 2, hz - 175
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    t = np.clip((yy - (cy - R)) / (2 * R), 0, 1)
    col = np.dstack([255 + 0 * t, 214 - 150 * t, 110 - 10 * t])
    disk = np.clip(R - d + 1, 0, 1)
    # смуги в нижній половині: що нижче — то ширші щілини
    rel = (yy - cy) / R
    gaps = np.zeros_like(rel)
    for k, (pos, wdt) in enumerate([(0.05, 0.03), (0.22, 0.045), (0.38, 0.06), (0.53, 0.075), (0.67, 0.09), (0.8, 0.1), (0.92, 0.11)]):
        gaps = np.maximum(gaps, np.clip(1 - np.abs(rel - pos) / (wdt / 2), 0, 1) ** 0.5 * (np.abs(rel - pos) < wdt / 2))
    disk = disk * (1 - gaps)
    glow = np.exp(-np.clip(d - R, 0, None) / 70) * 0.55
    alpha = np.clip(disk + glow * (d > R), 0, 1)
    sun = rgba(col, alpha * (yy < hz + 2))
    layers.append((sun, 0.08, {}))
    # далекі гори з неоновим контуром
    ys = ridge(W, H, hz - 70, 70, 1.3, seed=3, smooth=9)
    ys = np.minimum(ys, hz)
    layers.append((silhouette(W, H, ys, (30, 8, 58), rim=(255, 90, 200), rim_w=3.0, grad=(140, (14, 4, 30))), 0.28, {}))
    # ближчі гори з боків (центр відкритий — видно сонце)
    x = np.linspace(-1, 1, W)
    ys2 = ridge(W, H, hz - 10, 60, 1.1, seed=11, smooth=7) - 150 * (np.abs(x) ** 2.2) + 40
    ys2 = np.where(np.abs(x) < 0.32, hz + 30, ys2)
    ys2 = np.minimum(ys2, hz + 30)
    layers.append((silhouette(W, H, ys2, (18, 4, 38), rim=(120, 230, 255), rim_w=2.6, grad=(120, (8, 2, 20))), 0.5, {}))
    # сітка-підлога: чисті лінії (без муару), з сяйвом
    ss = 2
    fl = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(fl)
    for yy0 in range(hz * ss, H * ss):                     # темна підлога з градієнтом
        t = (yy0 / ss - hz) / (H - hz)
        d.line([(0, yy0), (W * ss, yy0)], fill=(int(26 - 14 * t), int(4 - 2 * t), int(50 - 28 * t), 255))
    lines = Image.new("L", (W * ss, H * ss), 0)
    dl = ImageDraw.Draw(lines)
    for n in range(0, 40):                                  # горизонтальні: що ближче до горизонту — тим щільніше
        y = hz + 900 / (n + 1.15) - 0
        if y > H or y - hz < 3:
            continue
        a_ = int(255 * min(1, (y - hz) / 60))
        dl.line([(0, y * ss), (W * ss, y * ss)], fill=a_, width=max(2, int(4 * (y - hz) / (H - hz) + 1.5)))
    vx = W / 2
    for k in range(-40, 41):                                # вертикальні: сходяться в точку на горизонті
        xb = vx + k * 150
        dl.line([(vx * ss, hz * ss), (xb * ss + (xb - vx) * 2.2 * ss, (H + 400) * ss)], fill=255, width=3)
    # біля самого горизонту лінії гаснуть (інакше муар)
    fade = Image.linear_gradient("L").resize((W * ss, H * ss))
    yy2 = np.arange(H * ss)[:, None] / ss
    fade_arr = np.clip((yy2 - hz) / 70, 0, 1) * np.ones((1, W * ss))
    la = np.asarray(lines).astype(np.float32) / 255 * fade_arr
    lines = Image.fromarray((la * 255).astype(np.uint8))
    glow = lines.filter(ImageFilter.GaussianBlur(10))
    neon_c = (255, 70, 200)
    fl.alpha_composite(Image.merge("RGBA", [Image.new("L", fl.size, c) for c in neon_c] + [glow.point(lambda v: int(v * 0.8))]))
    fl.alpha_composite(Image.merge("RGBA", [Image.new("L", fl.size, c) for c in (255, 150, 235)] + [lines]))
    # світіння вздовж горизонту
    hgl = Image.new("L", fl.size, 0)
    ImageDraw.Draw(hgl).rectangle((0, (hz - 2) * ss, W * ss, (hz + 3) * ss), fill=255)
    hgl = hgl.filter(ImageFilter.GaussianBlur(14))
    fl.alpha_composite(Image.merge("RGBA", [Image.new("L", fl.size, c) for c in (255, 110, 190)] + [hgl]))
    fl = fl.resize((W, H), Image.LANCZOS)
    layers.append((fl, 0.85, {}))
    save_layers("synthwave", layers, 30)


# ═════════════ «Північне сяйво» ═════════════
def aurora():
    W, H = 2040, 1200
    layers = []
    sky = vgrad(W, H, [(0, (2, 5, 16)), (0.45, (5, 18, 34)), (0.72, (12, 40, 58)), (1, (12, 40, 58))])
    img = rgba(sky, np.ones((H, W)))
    img = Image.alpha_composite(img, stars(W, H, 700, ymax=0.75, big=0.025, seed=21, tint=((255, 255, 255), (200, 230, 255), (255, 240, 220))))
    layers.append((img, 0.02, {}))
    # сяйво: періодичне по x (тайлиться) — шар пливе сам («speed»)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    X = xx / W * 2 * math.pi
    alpha = np.zeros((H, W), np.float32)
    rgb = np.zeros((H, W, 3), np.float32)
    for k, (base, amp, thick, colA, colB, inten, ph) in enumerate([
            (0.20, 0.05, 0.075, (90, 255, 190), (60, 160, 255), 0.8, 0.0),
            (0.14, 0.04, 0.055, (120, 255, 170), (170, 110, 255), 0.5, 1.7),
            (0.27, 0.05, 0.05, (80, 230, 255), (90, 255, 200), 0.4, 3.1)]):
        cy = (base + amp * np.sin(X * 2 + ph) + amp * 0.5 * np.sin(X * 5 + ph * 2) + 0.02 * np.sin(X * 11 + ph)) * H
        dy = (yy - cy) / (thick * H)
        # завіса: різка знизу, довгі промені вгору
        band = np.where(dy > 0, np.exp(-(dy * 3.2) ** 2), np.exp(-np.abs(dy) * 1.1))
        rays = 0.55 + 0.45 * np.sin(X * 37 + ph * 3) * np.sin(X * 13 - ph) ** 2
        a = band * rays * inten
        t = np.clip(-dy * 0.6 + 0.3, 0, 1)[..., None]
        c = np.array(colA, np.float32) * (1 - t) + np.array(colB, np.float32) * t
        rgb = rgb * (1 - a[..., None]) + c * a[..., None] + rgb * 0
        alpha = 1 - (1 - alpha) * (1 - a)
    rgb = np.where(alpha[..., None] > 0, rgb / np.maximum(alpha[..., None], 1e-3) * np.minimum(alpha[..., None] * 1.6, 1), 0)
    aur = rgba(rgb, np.clip(alpha * 0.85, 0, 1)).filter(ImageFilter.GaussianBlur(4))
    layers.append((aur, 0.06, {"speed": 6}))
    # засніжені гори
    # гострі скелясті вершини: «перевернуті» модулі синусоїд + дрібний шум
    xs = np.linspace(0, 1, W, endpoint=False)
    g = np.random.default_rng(41)
    ys = np.full(W, H * 0.66, np.float32)
    for k, amp in ((2, 150), (3, 90), (5, 55), (9, 28), (17, 14), (31, 7)):
        ys -= amp * (1 - np.abs(np.sin(math.pi * (k * xs + g.random())))) ** 1.6
    ys += np.convolve(g.normal(0, 3.0, W + 20), np.ones(7) / 7, "same")[10:-10]     # дрібна нерівність, згладжена (без смуг)
    m = silhouette(W, H, ys, (70, 92, 122), grad=(300, (14, 24, 36)))
    # сніг на вершинах: лише вище певної висоти, рваний край (згладжений шум, без смуг)
    snow = np.asarray(m).astype(np.float32)
    ysf = ys[None, :]
    nz = np.convolve(g.normal(0, 1, W + 40), np.ones(13) / 13, "same")[20:-20]
    snowline = H * 0.585 + 22 * nz                    # де закінчується сніг
    depth_in = yy - ysf
    cap = (yy < snowline[None, :]) * np.clip(1 - depth_in / 140, 0, 1) ** 0.6 * (depth_in >= 0)
    cap = np.asarray(Image.fromarray((cap * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
    ysm = np.convolve(ys, np.ones(25) / 25, "same")
    shade = 0.78 + 0.22 * np.clip(np.gradient(ysm)[None, :] / 2, -1, 1)     # схили, повернуті до світла, світліші
    snow[..., :3] = snow[..., :3] * (1 - cap[..., None]) + (np.array((205, 222, 240)) * shade[..., None]) * cap[..., None]
    layers.append((Image.fromarray(snow.astype(np.uint8), "RGBA"), 0.25, {}))
    # пагорби
    ys2 = ridge(W, H, H * 0.76, 45, 1.0, seed=52, smooth=11)
    layers.append((silhouette(W, H, ys2, (12, 26, 34), grad=(200, (5, 12, 16))), 0.45, {}))
    # ялиновий ліс (силуети ялинок уздовж лінії)
    def forest(base_y, hmin, hmax, density, color, seed):
        g = np.random.default_rng(seed)
        ss = 2
        im = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        x = 0.0
        while x < W:
            hgt = g.uniform(hmin, hmax)
            wid = hgt * g.uniform(0.32, 0.42)
            by = base_y + g.uniform(-12, 12)
            tiers = 6
            for t in range(tiers):
                ty = by - hgt * (t / tiers)
                tw = wid * (1 - t / tiers) * 0.95
                d.polygon([((x - tw / 2) * ss, ty * ss), ((x + tw / 2) * ss, ty * ss), (x * ss, (ty - hgt / tiers * 1.9) * ss)], fill=color + (255,))
            d.rectangle(((x - wid * 0.06) * ss, by * ss, (x + wid * 0.06) * ss, H * ss), fill=color + (255,))
            x += wid * density
        d.rectangle((0, int((base_y + 6) * ss), W * ss, H * ss), fill=color + (255,))
        return im.resize((W, H), Image.LANCZOS)
    layers.append((forest(H * 0.86, 90, 170, 0.55, (6, 16, 20), 61), 0.65, {}))
    layers.append((forest(H * 0.99, 220, 360, 0.75, (2, 7, 9), 73), 0.95, {}))
    save_layers("aurora", layers, 30)


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    for name, fn in (("neon", neon), ("synthwave", synthwave), ("aurora", aurora)):
        if which in (name, "all"):
            fn()
