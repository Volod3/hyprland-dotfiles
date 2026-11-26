#!/usr/bin/env python3
"""Хореографія заставки archglass — ОДНЕ джерело для двох виходів:
  1) archglass/archglass.script — сценарій Plymouth (заставка під час завантаження);
  2) arch-boot.mp4 — те саме відео 60 fps (прев'ю / щоб було в тебе).

  ~/.local/share/parallax-venv/bin/python build.py [--no-video]

Таймлайн (секунди):
  0.00  кадр як у прошивки: значок + «archlinux» по центру на чорному (безшовно після UEFI-заставки)
  0.35  напис тане й відпливає, значок їде в центр і росте
  0.95  значок перефарбовується в блакитно-рожевий градієнт, 1.45 — по ньому пробігає відблиск
  1.05  дві хвилі-кільця розходяться (блакитна, потім рожева)
  1.10  сяйво позаду, 1.2 — частинки вилітають і виходять на орбіти
  2.00  напис «arch linux», 2.6 — три крапки завантаження
  далі  сяйво «дихає», частинки кружляють, крапки пульсують — до кінця завантаження
"""
import json, math, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "archglass")
L = json.load(open(os.path.join(A, "layout.json")))
W, H = 1920, 1080

# ── частинки (детерміновані — однакові у відео й у Plymouth) ──
N = 42
PART = []
for i in range(N):
    PART.append({
        "a": (i * 2.399963) % (2 * math.pi),                  # «золотий кут» — рівномірно навколо
        "R": 175 + (i * 37) % 190,                            # радіус орбіти
        "d": round((i * 0.137) % 0.7, 3),                     # затримка появи
        "w": round((0.10 + (i % 5) * 0.035) * (1 if i % 2 else -1), 4),   # кутова швидкість
        "ph": round(i * 1.7, 3),                              # фаза мерехтіння
        "img": "dot_%s%d" % ("bpw"[i % 3], (i // 3) % 3),
    })

ICON_W, ICON_H = L["icon_w"], L["icon_h"]
BMP_W, BMP_H = L["bmp_w"], L["bmp_h"]
S0 = L["icon_box"][3] - L["icon_box"][1]                      # висота значка в bmp прошивки
ICON0_CX = -BMP_W / 2 + (L["icon_box"][0] + L["icon_box"][2]) / 2   # відносно центру екрана
TEXT0_X = -BMP_W / 2 + L["split"]
TITLE_W, TITLE_H = L["title_w"], L["title_h"]


# ═════════════ спільна математика (у Plymouth — те саме, див. SCRIPT нижче) ═════════════
def cl(x): return 0.0 if x < 0 else (1.0 if x > 1 else x)
def eo(x): x = cl(x); return 1 - (1 - x) ** 3
def eio(x):
    x = cl(x)
    return 4 * x * x * x if x < 0.5 else 1 - ((2 - 2 * x) ** 3) / 2


def state(t):
    """Що й де намалювати в момент t. Координати — відносно центру екрана."""
    s = {}
    p = eio((t - 0.35) / 0.85)
    h = S0 + (ICON_H - S0) * p
    s["icon_h"] = h
    s["icon_w"] = h * ICON_W / ICON_H
    s["icx"] = ICON0_CX * (1 - p)
    s["icy"] = -70 * p
    k = eo((t - 0.35) / 0.6)
    s["text_op"] = 1 - eo((t - 0.35) / 0.5)
    s["text_x"] = TEXT0_X + 60 * k
    s["grad_op"] = eio((t - 0.95) / 0.5)
    s["shine"] = int(cl((t - 1.45) / 0.6) * 19.999) if 1.45 <= t < 2.05 else -1
    g = 0.6 * eo((t - 1.1) / 0.9)
    if t > 2.0: g *= 0.85 + 0.15 * math.sin(2 * math.pi * (t - 2.0) / 2.6)
    s["glow_op"] = g
    rings = []
    for st, img in ((1.05, "ring_blue"), (1.4, "ring_pink")):
        u = (t - st) / 1.4
        if 0 <= u <= 1:
            rings.append((img, (260 + 760 * eo(u)) / 0.8, 0.75 * (1 - u) * (1 - u)))   # /0.8: кільце в картинці на радіусі 0.8
    s["rings"] = rings
    parts = []
    for P in PART:
        st = 1.2 + P["d"]
        if t < st: parts.append(None); continue
        k = eo((t - st) / 1.8)
        r = 30 + (P["R"] - 30) * k
        ang = P["a"] + P["w"] * (t - st)
        op = eo((t - st) / 0.4) * (0.55 + 0.45 * math.sin(P["ph"] + 2.2 * t))
        parts.append((s["icx"] + math.cos(ang) * r, s["icy"] + math.sin(ang) * r, op))
    s["parts"] = parts
    e = eo((t - 2.0) / 0.8)
    s["title_op"] = e
    s["title_y"] = 95 + 25 * (1 - e)
    l = eo((t - 2.6) / 0.5)
    s["dots"] = [l * (0.25 + 0.75 * max(0.0, math.sin(2 * math.pi * t / 1.3 - i * 0.7)) ** 2) for i in range(3)]
    return s


# ═════════════ 1) сценарій Plymouth ═════════════
def script():
    pa = "\n".join(
        'p[%d].a = %.5f; p[%d].R = %d; p[%d].d = %.3f; p[%d].w = %.4f; p[%d].ph = %.3f; p[%d].img = "%s";'
        % (i, P["a"], i, P["R"], i, P["d"], i, P["w"], i, P["ph"], i, P["img"]) for i, P in enumerate(PART))
    return r'''# archglass — заставка завантаження в стилі робочого столу (згенеровано build.py, не редагуй вручну)
# Plymouth малює ~50 кадрів/с; час = номер кадру / 50.

Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

global.W = Window.GetWidth();
global.H = Window.GetHeight();
global.CX = Window.GetX() + global.W / 2;
global.CY = Window.GetY() + global.H / 2;
global.frame = 0;

fun cl(x) { if (x < 0) return 0; if (x > 1) return 1; return x; }
fun eo(x) { x = cl(x); y = 1 - x; return 1 - y * y * y; }
fun eio(x) {
    x = cl(x);
    if (x < 0.5) return 4 * x * x * x;
    y = 2 - 2 * x;
    return 1 - y * y * y / 2;
}

# ── картинки ──
global.img_blue = Image("icon_blue.png");
global.img_grad = Image("icon_grad.png");
for (i = 0; i < 20; i++) {
    if (i < 10) n = "0" + i; else n = "" + i;
    global.img_shine[i] = Image("shine_" + n + ".png");
}
global.img_text = Image("splash_text.png");
global.img_glow = Image("glow.png");
global.img_ring_blue = Image("ring_blue.png");
global.img_ring_pink = Image("ring_pink.png");
global.img_title = Image("title.png");

# ── спрайти (z: сяйво < кільця < частинки < значок < текст) ──
global.glow = Sprite(global.img_glow);  global.glow.SetZ(1);  global.glow.SetOpacity(0);
global.ring0 = Sprite();  global.ring0.SetZ(2);
global.ring1 = Sprite();  global.ring1.SetZ(2);
global.blue = Sprite();   global.blue.SetZ(10);
global.grad = Sprite();   global.grad.SetZ(11);
global.text = Sprite(global.img_text);  global.text.SetZ(12);
global.title = Sprite(global.img_title);  global.title.SetZ(12);  global.title.SetOpacity(0);


''' + pa + r'''
global.NP = ''' + str(N) + r''';
for (i = 0; i < global.NP; i++) {
    global.part[i] = p[i];
    global.part[i].sprite = Sprite(Image(p[i].img + ".png"));
    global.part[i].sprite.SetZ(5);
    global.part[i].sprite.SetOpacity(0);
}
for (i = 0; i < 3; i++) {
    if (i == 0) dn = "dot_b1.png"; else if (i == 1) dn = "dot_w1.png"; else dn = "dot_p1.png";
    global.dot[i] = Sprite(Image(dn));
    global.dot[i].SetZ(12);
    global.dot[i].SetOpacity(0);
    global.dot[i].SetPosition(global.CX - 8 + (i - 1) * 26, global.CY + 205 - 8, 12);
}

global.last_h = -1;

fun place(spr, img, cx, cy) {
    spr.SetImage(img);
    spr.SetX(cx - img.GetWidth() / 2);
    spr.SetY(cy - img.GetHeight() / 2);
}

fun ring(spr, img, t, st) {
    u = (t - st) / 1.4;
    if (u < 0 || u > 1) { spr.SetOpacity(0); return; }
    d = (260 + 760 * eo(u)) / 0.8;
    place(spr, img.Scale(d, d), global.CX + global.icx, global.CY + global.icy);
    spr.SetOpacity(0.75 * (1 - u) * (1 - u));
}

fun refresh() {
    t = global.frame / 50;
    global.frame++;

    # значок: їде в центр і росте
    pp = eio((t - 0.35) / 0.85);
    h = ''' + str(S0) + r''' + (''' + str(ICON_H) + ''' - ''' + str(S0) + r''') * pp;
    w = h * ''' + str(ICON_W) + ''' / ''' + str(ICON_H) + r''';
    global.icx = ''' + "%.2f" % ICON0_CX + r''' * (1 - pp);
    global.icy = -70 * pp;
    x = global.CX + global.icx;
    y = global.CY + global.icy;
    go = eio((t - 0.95) / 0.5);
    if (pp < 1) {
        hi = Math.Int(h + 0.5);
        if (hi != global.last_h) {
            global.cur_blue = global.img_blue.Scale(Math.Int(w + 0.5), hi);
            global.cur_grad = global.img_grad.Scale(Math.Int(w + 0.5), hi);
            global.last_h = hi;
        }
        place(global.blue, global.cur_blue, x, y);
        place(global.grad, global.cur_grad, x, y);
    } else {
        place(global.blue, global.img_blue, x, y);
        if (t >= 1.45 && t < 2.05) {
            k = Math.Int(cl((t - 1.45) / 0.6) * 19.999);
            place(global.grad, global.img_shine[k], x, y);
        } else {
            place(global.grad, global.img_grad, x, y);
        }
    }
    global.grad.SetOpacity(go);
    if (go >= 1) global.blue.SetOpacity(0); else global.blue.SetOpacity(1);

    # напис прошивки тане й відпливає
    tk = eo((t - 0.35) / 0.6);
    global.text.SetX(global.CX + ''' + "%.2f" % TEXT0_X + r''' + 60 * tk);
    global.text.SetY(global.CY - ''' + str(BMP_H / 2) + r''');
    global.text.SetOpacity(1 - eo((t - 0.35) / 0.5));

    # сяйво (дихає)
    g = 0.6 * eo((t - 1.1) / 0.9);
    if (t > 2) g = g * (0.85 + 0.15 * Math.Sin(2 * Math.Pi * (t - 2) / 2.6));
    place(global.glow, global.img_glow, x, y);
    global.glow.SetOpacity(g);

    # хвилі
    ring(global.ring0, global.img_ring_blue, t, 1.05);
    ring(global.ring1, global.img_ring_pink, t, 1.4);

    # частинки на орбітах
    for (i = 0; i < global.NP; i++) {
        q = global.part[i];
        st = 1.2 + q.d;
        if (t >= st) {
            k = eo((t - st) / 1.8);
            r = 30 + (q.R - 30) * k;
            a = q.a + q.w * (t - st);
            q.sprite.SetX(x + Math.Cos(a) * r - q.sprite.GetImage().GetWidth() / 2);
            q.sprite.SetY(y + Math.Sin(a) * r - q.sprite.GetImage().GetHeight() / 2);
            q.sprite.SetOpacity(eo((t - st) / 0.4) * (0.55 + 0.45 * Math.Sin(q.ph + 2.2 * t)));
        }
    }

    # напис «arch linux»
    e = eo((t - 2) / 0.8);
    global.title.SetX(global.CX - ''' + str(TITLE_W / 2) + r''');
    global.title.SetY(global.CY + 95 + 25 * (1 - e) - ''' + str(TITLE_H / 2) + r''');
    global.title.SetOpacity(e);

    # крапки завантаження
    l = eo((t - 2.6) / 0.5);
    for (i = 0; i < 3; i++) {
        sv = Math.Sin(2 * Math.Pi * t / 1.3 - i * 0.7);
        if (sv < 0) sv = 0;
        global.dot[i].SetOpacity(l * (0.25 + 0.75 * sv * sv));
    }
}
Plymouth.SetRefreshFunction(refresh);

# ── повідомлення (помилки служб тощо) — внизу екрана, щоб їх було видно ──
global.msg = Sprite();
global.msg.SetZ(20);
fun message(text) {
    global.msg.SetImage(Image.Text(text, 0.95, 0.72, 0.83, 1, "Sans 14"));
    global.msg.SetPosition(global.CX - global.msg.GetImage().GetWidth() / 2, global.H - 80, 20);
}
Plymouth.SetMessageFunction(message);

# ── пароль (якщо колись буде шифрування диска) ──
global.pw = Sprite();
global.pw.SetZ(20);
fun password(prompt, bullets) {
    s = prompt + "  ";
    for (i = 0; i < bullets; i++) s = s + "●";
    global.pw.SetImage(Image.Text(s, 0.91, 0.93, 0.96, 1, "Sans 16"));
    global.pw.SetPosition(global.CX - global.pw.GetImage().GetWidth() / 2, global.CY + 260, 20);
    global.pw.SetOpacity(1);
}
fun normal() { global.pw.SetOpacity(0); }
Plymouth.SetDisplayPasswordFunction(password);
Plymouth.SetDisplayNormalFunction(normal);
'''


# ═════════════ 2) відео 60 fps (те саме, що state()) ═════════════
def video(path, dur=7.0, fps=60):
    I = {n[:-4]: Image.open(os.path.join(A, n)).convert("RGBA") for n in os.listdir(A) if n.endswith(".png")}
    bmp_icon_blue = I["icon_blue"]
    proc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                             "-s", "%dx%d" % (W, H), "-r", str(fps), "-i", "-",
                             "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
                             "-movflags", "+faststart", path], stdin=subprocess.PIPE)
    cx, cy = W / 2, H / 2
    cache = {}

    def put(canvas, img, x, y, op):
        if op <= 0.003: return
        if op < 0.999:
            a = img.getchannel("A").point(lambda v: int(v * op))
            img = img.copy(); img.putalpha(a)
        canvas.alpha_composite(img, (int(round(x)), int(round(y))))

    def centered(canvas, img, x, y, op):
        put(canvas, img, x - img.width / 2, y - img.height / 2, op)

    def scaled(name, w, h):
        k = (name, int(round(w)), int(round(h)))
        if k not in cache:
            if len(cache) > 400: cache.clear()
            cache[k] = I[name].resize((max(1, k[1]), max(1, k[2])), Image.LANCZOS)
        return cache[k]

    frames = int(dur * fps)
    fade_from = dur - 0.45
    for f in range(frames):
        t = f / fps
        s = state(t)
        c = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        x, y = cx + s["icx"], cy + s["icy"]
        centered(c, I["glow"], x, y, s["glow_op"])
        for img, d, op in s["rings"]:
            centered(c, scaled(img, d, d), x, y, op)
        for i, pr in enumerate(s["parts"]):
            if pr: centered(c, I[PART[i]["img"]], cx + pr[0], cy + pr[1], pr[2])
        if s["icon_h"] < ICON_H - 0.01:
            blue = scaled("icon_blue", s["icon_w"], s["icon_h"]); grad = scaled("icon_grad", s["icon_w"], s["icon_h"])
        else:
            blue = I["icon_blue"]; grad = I["shine_%02d" % s["shine"]] if s["shine"] >= 0 else I["icon_grad"]
        if s["grad_op"] < 1: centered(c, blue, x, y, 1)
        centered(c, grad, x, y, s["grad_op"])
        put(c, I["splash_text"], cx + s["text_x"], cy - BMP_H / 2, s["text_op"])
        put(c, I["title"], cx - TITLE_W / 2, cy + s["title_y"] - TITLE_H / 2, s["title_op"])
        for i, op in enumerate(s["dots"]):
            centered(c, I[("dot_b1", "dot_w1", "dot_p1")[i]], cx + (i - 1) * 26, cy + 205, op)
        if t > fade_from:                                        # кінець: плавно в чорне (далі — екран входу)
            k = cl((t - fade_from) / 0.45)
            c = Image.blend(c, Image.new("RGBA", (W, H), (0, 0, 0, 255)), k)
        proc.stdin.write(c.convert("RGB").tobytes())
        if f % 60 == 0: print("  кадр %d/%d" % (f, frames), flush=True)
    proc.stdin.close(); proc.wait()


if __name__ == "__main__":
    open(os.path.join(A, "archglass.script"), "w").write(script())
    open(os.path.join(A, "archglass.plymouth"), "w").write("""[Plymouth Theme]
Name=archglass
Description=Логотип Arch → блакитно-рожевий градієнт, хвилі, частинки на орбітах (стиль робочого столу)
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/archglass
ScriptFile=/usr/share/plymouth/themes/archglass/archglass.script
""")
    print("сценарій Plymouth готовий")
    if "--no-video" not in sys.argv:
        out = os.path.expanduser("~/Відео/arch-boot.mp4")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        video(out)
        print("відео:", out)
