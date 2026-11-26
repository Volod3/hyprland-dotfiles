#!/usr/bin/env python3
"""Адаптувати картинку для логотипа fastfetch під стиль робочого столу:
квадрат 1280, тони темне скло → блакитний → ледь рожеві відблиски, кольоровий логотип лишається,
м'яка віньєтка й заокруглені кути (прозорі — kitty їх показує).

  ~/.local/share/parallax-venv/bin/python ~/.config/fastfetch/adapt_image.py ВХІД.jpg ~/.config/fastfetch/my_image_fixed.png
"""
import sys
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
s = min(im.size); l = (im.width - s) // 2; t = (im.height - s) // 2
im = im.crop((l, t, l + s, t + s)).resize((1280, 1280), Image.LANCZOS)
a = np.asarray(im).astype(np.float32) / 255

# яскравість — трохи згладжена, щоб підняття контрасту не витягало JPEG-зерно
lumimg = im.convert("L").filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
lum = np.asarray(lumimg).astype(np.float32) / 255

# насичені пікселі (логотип Arch) лишаються у своєму кольорі
mx = a.max(-1); mn = a.min(-1); sat = (mx - mn) / (mx + 1e-5)
logo = np.clip((sat - 0.25) / 0.25, 0, 1)
logo = np.asarray(Image.fromarray((logo * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255

stops = [(0.0, (14, 16, 26)), (0.35, (40, 52, 86)), (0.70, (140, 170, 220)), (0.90, (232, 214, 232)), (1.0, (246, 240, 248))]
L = np.clip((lum - 0.42) / (1.0 - 0.42), 0, 1) ** 1.05
d = np.zeros(L.shape + (3,), np.float32)
for c in range(3):
    d[..., c] = np.interp(L, [p for p, _ in stops], [col[c] / 255 for _, col in stops])
out = d * (1 - logo[..., None]) + a * logo[..., None]
img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))

# м'яка віньєтка до кольору фону терміналу
v = Image.new("L", (1280, 1280), 0); ImageDraw.Draw(v).ellipse((-260, -260, 1540, 1540), fill=255)
img = Image.composite(img, Image.new("RGB", img.size, (14, 16, 24)), v.filter(ImageFilter.GaussianBlur(170)))

# заокруглені кути (згладжені: малюємо в 4 рази більше й зменшуємо)
m = Image.new("L", (5120, 5120), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, 5119, 5119), radius=440, fill=255)
img = img.convert("RGBA"); img.putalpha(m.resize((1280, 1280), Image.LANCZOS))
img.save(dst)
print("готово:", dst)
