#!/usr/bin/env python3
"""Відрізає гори від неба в layer00 теми «Гори» (за картою глибини _depth.png):
layer00m.png = ті самі пікселі layer00, але тільки нижче лінії хребта. Шар іде одразу після layer00 з тією ж
глибиною (рухається разом із ним, без щілин), а візуалізатор стає МІЖ ними — смуги ростуть з-за гори.
  ~/.local/share/parallax-venv/bin/python split_ridge.py [тема=mountains]
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import median_filter

th = sys.argv[1] if len(sys.argv) > 1 else "mountains"
D = os.path.expanduser("~/.config/wallpapers_QS/bg_parallax_MDRG/assets/parallax_backgrounds/" + th)
l0 = Image.open(os.path.join(D, "layer00.png")).convert("RGBA")
dep = np.asarray(Image.open(os.path.join(D, "_depth.png")).convert("L").resize(l0.size))
terr = dep > 8
H = terr.shape[0]
first = np.where(terr.any(0), terr.argmax(0), H)                      # перший рядок рельєфу в стовпчику
# прибрати поодинокі «голки» (гілки дерев)
first = median_filter(first, size=9).astype(np.float32) + 2           # +2 px — край трохи нижче, без ореолу неба
ys = np.arange(H, dtype=np.float32)[:, None]
alpha = np.clip((ys - first[None, :]) / 2.0 + 0.5, 0, 1)              # м'який край ~2 px
out = np.asarray(l0).copy()
out[..., 3] = (out[..., 3] * alpha).astype(np.uint8)
Image.fromarray(out).save(os.path.join(D, "layer00m.png"))
lj = json.load(open(os.path.join(D, "layers.json")))
L = [l for l in lj["layers"] if not l["file"].endswith("layer00m.png")]
L.insert(1, dict(L[0], file="./assets/parallax_backgrounds/%s/layer00m.png" % th))
lj["layers"] = L
json.dump(lj, open(os.path.join(D, "layers.json"), "w"), indent=2)
print("ok: хребет", int(first.min()), "…", int(first.max()), "з", H)
