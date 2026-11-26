#!/usr/bin/env python3
"""clean_sprites.py — чистить анімації пета (вирізані з відео GIF) і робить з них WebP.

  python clean_sprites.py IDLE.gif WALK.gif OUT_DIR [--height 384]

Що робить:
  * прибирає «сміття» — дрібні непрозорі шматочки довкола фігури;
  * зрізає 1 px краю (там ореол від фону відео) і робить край м'яким (справжня прозорість, не 1-бітна, як у GIF);
  * фарбує край кольором зсередини фігури (без темної/зеленої облямівки);
  * підганяє кольори ходьби під кольори спокою (ходьба знята при іншому світлі — волосся було рожевим);
  * кладе обидві анімації на ОДНАКОВЕ полотно, ноги внизу, однаковий масштаб фігури
    (раніше під час ходьби персонаж ставав більшим);
  * зберігає як анімований WebP (повна прозорість, у рази менший за GIF).
Потрібні: ffmpeg, python з opencv і numpy (~/.local/share/parallax-venv).
"""
import glob
import os
import subprocess
import sys
import tempfile

import cv2
import numpy as np
from scipy import ndimage


def extract(gif, d):
    os.makedirs(d, exist_ok=True)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-i", gif, "-pix_fmt", "rgba", f"{d}/%05d.png"], check=True)
    return sorted(glob.glob(f"{d}/*.png"))


def clean_alpha(a):
    m = (a > 127).astype(np.uint8)
    n, cc, st, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    if n > 1:
        big = st[1:, cv2.CC_STAT_AREA].max()
        keep = np.zeros(n, bool)
        keep[1:] = st[1:, cv2.CC_STAT_AREA] >= max(40, big * 0.004)
        m = keep[cc].astype(np.uint8)
    # дірки всередині фігури (шум відео) — залити
    m = ndimage.binary_fill_holes(m).astype(np.uint8)
    m = cv2.erode(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)))
    return m


def process(frames, color_fix=None):
    out = []
    for f in frames:
        im = cv2.imread(f, cv2.IMREAD_UNCHANGED)
        m = clean_alpha(im[:, :, 3])
        rgb = im[:, :, :3].copy()
        # колір краю — з найближчого пікселя всередині (на 2 px углиб), без ореолу
        inner = cv2.erode(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))) > 0
        if inner.any():
            _, idx = ndimage.distance_transform_edt(~inner, return_indices=True)
            band = (m > 0) & ~inner
            rgb[band] = rgb[idx[0][band], idx[1][band]]
        if color_fix is not None:
            rgb = color_fix(rgb, m > 0)
        alpha = cv2.GaussianBlur(m.astype(np.float32) * 255, (0, 0), 0.75)
        out.append(np.dstack([rgb, np.clip(alpha, 0, 255).astype(np.uint8)]))
    return out


def lab_stats(frames_rgba):
    px = []
    for fr in frames_rgba[:: max(1, len(frames_rgba) // 40)]:
        sel = fr[:, :, 3] > 200
        lab = cv2.cvtColor(fr[:, :, :3], cv2.COLOR_BGR2LAB).astype(np.float32)
        px.append(lab[sel])
    p = np.concatenate(px)
    return p.mean(0), p.std(0) + 1e-6


def bbox(frames):
    x0 = y0 = 10 ** 9
    x1 = y1 = 0
    for fr in frames:
        ys, xs = np.where(fr[:, :, 3] > 10)
        if len(xs):
            x0, x1 = min(x0, xs.min()), max(x1, xs.max())
            y0, y1 = min(y0, ys.min()), max(y1, ys.max())
    return x0, y0, x1 + 1, y1 + 1


def place(frames, box, scale, cw, ch, pad):
    x0, y0, x1, y1 = box
    res = []
    for fr in frames:
        crop = fr[y0:y1, x0:x1]
        w, h = max(1, round(crop.shape[1] * scale)), max(1, round(crop.shape[0] * scale))
        # premultiplied alpha при зменшенні — без темної облямівки
        f = crop.astype(np.float32) / 255
        f[:, :, :3] *= f[:, :, 3:4]
        f = cv2.resize(f, (w, h), interpolation=cv2.INTER_AREA)
        a = np.clip(f[:, :, 3:4], 1e-6, 1)
        f[:, :, :3] = np.where(a > 1e-5, f[:, :, :3] / a, 0)
        sm = np.clip(f * 255, 0, 255).astype(np.uint8)
        canvas = np.zeros((ch, cw, 4), np.uint8)
        ox, oy = (cw - w) // 2, ch - pad - h
        canvas[oy:oy + h, ox:ox + w] = sm
        res.append(canvas)
    return res


def write_webp(frames, path, fps):
    with tempfile.TemporaryDirectory() as d:
        for i, fr in enumerate(frames):
            cv2.imwrite(f"{d}/{i:05d}.png", fr)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(fps), "-i", f"{d}/%05d.png",
                        "-c:v", "libwebp_anim", "-lossless", "0", "-quality", "90", "-preset", "picture",
                        "-loop", "0", "-pix_fmt", "yuva420p", path], check=True)


def main():
    idle_gif, walk_gif, outdir = sys.argv[1:4]
    H = int(sys.argv[sys.argv.index("--height") + 1]) if "--height" in sys.argv else 384
    tmp = tempfile.mkdtemp()
    print("кадри…")
    idle = process(extract(idle_gif, f"{tmp}/i"))
    m_i, s_i = lab_stats(idle)
    walk_raw = process(extract(walk_gif, f"{tmp}/w"))
    m_w, s_w = lab_stats(walk_raw)

    def fix(rgb, sel, k=0.85):
        lab = cv2.cvtColor(rgb, cv2.COLOR_BGR2LAB).astype(np.float32)
        t = (lab - m_w) / s_w * s_i + m_i
        lab = lab * (1 - k) + t * k
        return cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)

    print("кольори ходьби → як у спокої…")
    walk = process(extract(walk_gif, f"{tmp}/w"), color_fix=fix)

    bi, bw = bbox(idle), bbox(walk)
    pad = max(2, H // 96)
    fig = H - 2 * pad
    si = fig / (bi[3] - bi[1])
    sw = fig / (bw[3] - bw[1]) * 0.97          # у ходьбі маківка частково зрізана — трохи менше
    cw = int(max((bi[2] - bi[0]) * si, (bw[2] - bw[0]) * sw)) + 2 * pad
    cw += cw % 2
    print(f"полотно {cw}x{H}")
    os.makedirs(outdir, exist_ok=True)
    write_webp(place(idle, bi, si, cw, H, pad), f"{outdir}/zhao_idle.webp", 30)
    write_webp(place(walk, bw, sw, cw, H, pad), f"{outdir}/zhao_walk.webp", 30)
    print("готово:", outdir)


if __name__ == "__main__":
    main()
