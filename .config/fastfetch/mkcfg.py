import json, os, sys
cols, rows = int(sys.argv[1]), int(sys.argv[2])
home = os.path.expanduser("~")
c = json.load(open(home + "/.config/fastfetch/config.jsonc"))
m = c["modules"]
while m and m[0] == "break":
    m.pop(0)
while m and m[-1] == "break":
    m.pop()
if rows < 22:
    m.pop()
    lines = 18
else:
    m += ["break", "break"]
    lines = 21

# --- Розмір картинки: чим ширше вікно, тим більша (макс. 32x16) ---
BOX = 63        # ширина рамок з текстом
PAD = 1         # відступ праворуч від картинки
MIN_W = 18      # менша картинка не показується (вікно ~83 колонки)
MAX_W, MAX_H = 32, 16
RATIO = 2.0     # колонок на 1 рядок (щоб картинка була приблизно квадратна)

w = min(MAX_W, cols - BOX - PAD - 1)
h = min(MAX_H, -(-int(w) // 2)) if w > 0 else 0
if h > lines - 3:
    h = lines - 3
    w = min(w, int(h * RATIO))

if w < MIN_W or h < 1:
    c["logo"] = {"type": "none"}
else:
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "my_image_fixed.png")
    out, top, hh = src, 1, h
    try:
        from PIL import Image
        cache = home + "/.cache/ff-logo-h%d.png" % h
        if not os.path.exists(cache) or os.path.getmtime(cache) < os.path.getmtime(src):
            im = Image.open(src).convert("RGBA")
            W, H = im.size
            canvas = Image.new("RGBA", (W, round(H * (h + 1) / h)), (0, 0, 0, 0))
            canvas.paste(im, (0, round(H * 0.5 / h)))
            os.makedirs(home + "/.cache", exist_ok=True)
            canvas.save(cache)
        out, top, hh = cache, 0, h + 1
    except Exception:
        pass
    c["logo"].update(source=out, width=w, height=hh, padding={"top": top, "left": 0, "right": PAD})
print(json.dumps(c, ensure_ascii=False, indent=4))
l = c["logo"]
open(home + "/.cache/ff-logo.state", "w").write("none\n" if l.get("type") == "none" else "%d %d %d %s\n" % (l["width"], l["height"], l["padding"]["top"], l["source"]))
