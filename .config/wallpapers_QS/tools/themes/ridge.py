#!/usr/bin/env python3
"""Лінія силуету для візуалізатора: для кожної смуги — висота рельєфу (гори / дахи), з-за якого вона росте.

  ~/.local/share/parallax-venv/bin/python ridge.py            — усі теми з візуалізатором
Беремо всі шари ПЕРЕД візуалізатором (номер > visualizer.afterLayer), рахуємо, де в кожному стовпчику
починається непрозоре, переводимо в координати екрана (як Parallax.qml: шар = екран + 2×strength,
картинка PreserveAspectCrop по центру) і для смуги беремо НАЙНИЖЧУ точку під нею — так основа
смуги завжди схована за рельєфом. Пише bars.ridge (частки висоти екрана) у themes.json.
"""
import json, os
import numpy as np
from PIL import Image

HOME = os.path.expanduser("~")
TJ = os.path.join(HOME, ".config/wallpapers_QS/themes/themes.json")
PX = os.path.join(HOME, ".config/wallpapers_QS/bg_parallax_MDRG")
SW, SH = 1920, 1080


def ridge_for(t):
    v = t.get("visualizer") or {}
    if v.get("enabled") is False or "bars" not in v:
        return None
    after = int(v.get("afterLayer", 0))
    n = int(v["bars"].get("count", 64))
    s = int(t.get("strength", 20))
    lj = json.load(open(os.path.join(PX, "assets/parallax_backgrounds", t["wallpaper"], "layers.json")))
    layers = lj["layers"][after + 1:]
    if not layers:
        return None
    W2, H2 = SW + 2 * s, SH + 2 * s
    top = np.full(SW, SH, np.float32)                    # найвища непрозора точка рельєфу на екрані для кожного x
    for l in layers:
        im = Image.open(os.path.join(PX, "assets/parallax_backgrounds", t["wallpaper"], os.path.basename(l["file"]))).convert("RGBA")
        W, H = im.size
        k = max(W2 / W, H2 / H)
        dw, dh = W * k, H * k
        ox, oy = (W2 - dw) / 2 - s, (H2 - dh) / 2 - s       # куди лягає картинка відносно екрана
        a = np.asarray(im.getchannel("A")).astype(np.float32) / 255
        solid = a > 0.6
        rows = np.where(solid.any(0), solid.argmax(0), H)  # перший непрозорий рядок у кожному стовпчику
        xs = np.arange(SW)
        cols = np.clip(((xs - ox) / k).astype(int), 0, W - 1)
        y = rows[cols] * k + oy
        y = np.where(rows[cols] >= H, SH, y)
        top = np.minimum(top, y)
    out = []
    bw = SW / n
    for i in range(n):
        seg = top[int(i * bw):int((i + 1) * bw) + 1]
        out.append(float(np.max(seg)) / SH)                # найнижча точка під смугою — основа схована
    # шпилі / вершини, що стирчать набагато вище за решту, — основа ховається за ними (смуга виглядає з-за них)
    med = float(np.median(out))
    out = [round(max(r, med - 0.13), 4) for r in out]
    return out


def main():
    d = json.load(open(TJ))
    for t in d["themes"]:
        r = ridge_for(t)
        if r is not None:
            t["visualizer"]["bars"]["ridge"] = r
            print(t["id"], "силует:", min(r), "…", max(r))
    json.dump(d, open(TJ, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
