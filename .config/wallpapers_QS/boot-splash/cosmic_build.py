#!/usr/bin/env python3
"""Космічна заставка завантаження archglass — ОДНЕ джерело для Plymouth-сценарію і відео 60 fps.

  ~/.local/share/parallax-venv/bin/python cosmic_build.py [--no-video]

Таймлайн (с):
  0.00  кадр як у прошивки (значок + «archlinux») — безшовно після UEFI
  0.25  проліт крізь зорі: зорі вилітають з центру, сповільнюються → спокійний дрейф
  0.30  напис тане, значок їде в центр і росте (заготовлені кадри — без масштабування на льоту)
  0.90  значок → блакитно-рожевий градієнт; туманності проступають
  1.30  навколо — нахилена орбіта, по ній кружляють два супутники (ховаються за значок)
  1.55  хвиля; 1.75 відблиск по значку
  2.20  «arch linux»; 2.6+ — внизу назви служб, що стартують (справжні, від systemd); комета раз на 6.5 с
"""
import json, math, os, random, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "archglass")
L = json.load(open(os.path.join(A, "layout.json")))
W, H = 1920, 1080
NS = L["scale_steps"]
ICON_W, ICON_H = L["icon_w"], L["icon_h"]
BMP_W, BMP_H = L["bmp_w"], L["bmp_h"]
S0 = L["icon_box"][3] - L["icon_box"][1]
ICON0_CX = -BMP_W / 2 + (L["icon_box"][0] + L["icon_box"][2]) / 2
TITLE_W, TITLE_H = L["title_w"], L["title_h"]
OW, OH = 860, 250
OA, OB = OW / 2 - 12, OH / 2 - 12
RMIN, SPAN = 40, 1150

rnd = random.Random(42)
STARS = []
for i in range(96):
    STARS.append({"a": rnd.uniform(0, 2 * math.pi), "r0": rnd.uniform(0, SPAN), "s": round(rnd.uniform(0.55, 1.6), 3),
                  "b": round(rnd.uniform(0.55, 1.0), 3), "ph": round(rnd.uniform(0, 6.28), 3),
                  "img": "star_%s%d" % (rnd.choice("wwwwbp"), rnd.choice((0, 0, 1, 1, 1, 2)))})
SATS = [{"ph": 0.0, "img": "dot_w2", "w": 0.85}, {"ph": math.pi * 0.9, "img": "dot_p2", "w": 0.85}]


def cl(x): return 0.0 if x < 0 else (1.0 if x > 1 else x)
def eo(x): x = cl(x); return 1 - (1 - x) ** 3
def eio(x):
    x = cl(x)
    return 4 * x * x * x if x < 0.5 else 1 - ((2 - 2 * x) ** 3) / 2
def fmod(x, m): return x - int(x / m) * m


def state(t):
    s = {}
    p = eio((t - 0.30) / 0.85)
    s["step"] = int(p * NS + 0.5)
    s["icx"] = ICON0_CX * (1 - p)
    s["icy"] = -60 * p
    s["text_op"] = 1 - eo((t - 0.30) / 0.45)
    s["text_dx"] = 60 * eo((t - 0.30) / 0.6)
    s["grad_op"] = eio((t - 0.9) / 0.5)
    s["shine"] = int(cl((t - 1.75) / 0.6) * 19.999) if (p >= 1 and 1.75 <= t < 2.35) else -1
    g = 0.55 * eo((t - 1.0) / 0.9)
    if t > 2.0: g *= 0.85 + 0.15 * math.sin(2 * math.pi * (t - 2.0) / 2.8)
    s["glow"] = g
    D = 820 * eo((t - 0.25) / 1.6) + 14 * t
    stars = []
    for S in STARS:
        r = RMIN + fmod(S["r0"] + D * S["s"], SPAN)
        op = cl((r - RMIN) / 160) * S["b"] * eo((t - 0.2) / 0.6) * (0.75 + 0.25 * math.sin(S["ph"] + 3 * t))
        stars.append((math.cos(S["a"]) * r, math.sin(S["a"]) * r * 0.9, op))
    s["stars"] = stars
    nb = eo((t - 0.9) / 1.2) * (0.85 + 0.15 * math.sin(t / 3))
    s["neb"] = [(-430 + 40 * math.sin(t / 7), -190, nb), (400 + 30 * math.sin(t / 9 + 1), 190, nb * 0.9)]
    s["orbit"] = eo((t - 1.3) / 0.8)
    sats = []
    for S in SATS:
        th = S["w"] * t + S["ph"]
        sats.append((OA * math.cos(th), 10 + OB * math.sin(th), math.sin(th) >= 0))
    s["sats"] = sats
    u = (t - 1.55) / 1.4
    s["ring"] = ((260 + 760 * eo(u)) / 0.8, 0.6 * (1 - u) * (1 - u)) if 0 <= u <= 1 else None
    s["comet"] = None
    if t > 2.6:
        cu = fmod(t - 2.6, 6.5) / 1.1
        if cu <= 1:
            s["comet"] = (-900 + 1500 * cu, -480 + 450 * cu, math.sin(math.pi * cu))
    e = eo((t - 2.2) / 0.8)
    s["title"] = (e, 168 + 22 * (1 - e))
    s["status"] = eo((t - 2.6) / 0.6)
    return s


# ═════════════ сценарій Plymouth ═════════════
def script():
    st = "\n".join('st[%d].a = %.4f; st[%d].r0 = %.1f; st[%d].s = %.3f; st[%d].b = %.3f; st[%d].ph = %.3f; st[%d].img = "%s";'
                   % (i, S["a"], i, S["r0"], i, S["s"], i, S["b"], i, S["ph"], i, S["img"]) for i, S in enumerate(STARS))
    sa = "\n".join('sa[%d].ph = %.4f; sa[%d].w = %.3f; sa[%d].img = "%s";' % (i, S["ph"], i, S["w"], i, S["img"]) for i, S in enumerate(SATS))
    return r'''# archglass (космос) — заставка завантаження. Згенеровано cosmic_build.py, не редагуй вручну.
# Plymouth малює ~50 кадрів/с; час = номер кадру / 50. Жодного масштабування на льоту — лише рух і прозорість.

Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);
global.W = Window.GetWidth();
global.H = Window.GetHeight();
global.CX = Window.GetX() + global.W / 2;
global.CY = Window.GetY() + global.H / 2;
global.frame = 0;

fun cl(x) { if (x < 0) return 0; if (x > 1) return 1; return x; }
fun eo(x) { x = cl(x); y = 1 - x; return 1 - y * y * y; }
fun eio(x) { x = cl(x); if (x < 0.5) return 4 * x * x * x; y = 2 - 2 * x; return 1 - y * y * y / 2; }
fun fmod(x, m) { return x - Math.Int(x / m) * m; }
fun two(i) { if (i < 10) return "0" + i; return "" + i; }

fun place(spr, img, cx, cy) {
    spr.SetImage(img);
    spr.SetX(cx - img.GetWidth() / 2);
    spr.SetY(cy - img.GetHeight() / 2);
}

# ── картинки ──
for (i = 0; i <= ''' + str(NS) + r'''; i++) {
    global.isb[i] = Image("sb_" + two(i) + ".png");
    global.isg[i] = Image("sg_" + two(i) + ".png");
}
for (i = 0; i < 20; i++) global.ishine[i] = Image("shine_" + two(i) + ".png");
global.i_text = Image("splash_text.png");
global.i_glow = Image("glow.png");
global.i_ring = Image("ring_blue.png");
global.i_title = Image("title.png");
global.i_neb_a = Image("nebula_a.png");
global.i_neb_b = Image("nebula_b.png");
global.i_orb_b = Image("orbit_back.png");
global.i_orb_f = Image("orbit_front.png");
global.i_comet = Image("comet.png");

# ── спрайти; z: зорі 1, туманності 2, сяйво 3, кільце 4, орбіта-зад 5, супутник-зад 6, значок 10-11, орбіта-перед 12, супутник-перед 13, текст 14 ──
''' + st + r'''
global.NST = ''' + str(len(STARS)) + r''';
for (i = 0; i < global.NST; i++) {
    global.star[i] = st[i];
    global.star[i].sp = Sprite(Image(st[i].img + ".png"));
    global.star[i].sp.SetZ(1);
    global.star[i].sp.SetOpacity(0);
    global.star[i].h = global.star[i].sp.GetImage().GetWidth() / 2;
}
global.neb_a = Sprite(global.i_neb_a); global.neb_a.SetZ(2); global.neb_a.SetOpacity(0);
global.neb_b = Sprite(global.i_neb_b); global.neb_b.SetZ(2); global.neb_b.SetOpacity(0);
global.glow = Sprite(global.i_glow); global.glow.SetZ(3); global.glow.SetOpacity(0);
global.ring = Sprite(); global.ring.SetZ(4); global.ring.SetOpacity(0);
global.ring_ready = 0;
global.orb_b = Sprite(global.i_orb_b); global.orb_b.SetZ(5); global.orb_b.SetOpacity(0);
global.orb_f = Sprite(global.i_orb_f); global.orb_f.SetZ(12); global.orb_f.SetOpacity(0);
''' + sa + r'''
for (i = 0; i < 2; i++) {
    global.sat[i] = sa[i];
    global.sat[i].sp = Sprite(Image(sa[i].img + ".png"));
    global.sat[i].sp.SetOpacity(0);
}
global.blue = Sprite(); global.blue.SetZ(10);
global.grad = Sprite(); global.grad.SetZ(11);
global.text = Sprite(global.i_text); global.text.SetZ(14);
global.title = Sprite(global.i_title); global.title.SetZ(14); global.title.SetOpacity(0);
global.comet = Sprite(global.i_comet); global.comet.SetZ(2); global.comet.SetOpacity(0);
global.status = Sprite(); global.status.SetZ(14); global.status.SetOpacity(0);
global.status_text = "";

fun refresh() {
    t = global.frame / 50;
    global.frame++;

    # значок: у центр і росте (готові кадри)
    pp = eio((t - 0.30) / 0.85);
    k = Math.Int(pp * ''' + str(NS) + r''' + 0.5);
    icx = ''' + "%.2f" % ICON0_CX + r''' * (1 - pp);
    icy = -60 * pp;
    x = global.CX + icx;
    y = global.CY + icy;
    go = eio((t - 0.9) / 0.5);
    place(global.blue, global.isb[k], x, y);
    if (pp >= 1 && t >= 1.75 && t < 2.35) {
        place(global.grad, global.ishine[Math.Int(cl((t - 1.75) / 0.6) * 19.999)], x, y);
    } else {
        place(global.grad, global.isg[k], x, y);
    }
    global.grad.SetOpacity(go);
    if (go >= 1) global.blue.SetOpacity(0); else global.blue.SetOpacity(1);

    # напис прошивки тане
    global.text.SetX(global.CX - ''' + str(BMP_W / 2) + r''' + 60 * eo((t - 0.30) / 0.6));
    global.text.SetY(global.CY - ''' + str(BMP_H / 2) + r''');
    global.text.SetOpacity(1 - eo((t - 0.30) / 0.45));

    # зорі: проліт → дрейф
    D = 820 * eo((t - 0.25) / 1.6) + 14 * t;
    fi = eo((t - 0.2) / 0.6);
    for (i = 0; i < global.NST; i++) {
        q = global.star[i];
        r = ''' + str(RMIN) + r''' + fmod(q.r0 + D * q.s, ''' + str(SPAN) + r''');
        q.sp.SetX(global.CX + Math.Cos(q.a) * r - q.h);
        q.sp.SetY(global.CY + Math.Sin(q.a) * r * 0.9 - q.h);
        q.sp.SetOpacity(cl((r - ''' + str(RMIN) + r''') / 160) * q.b * fi * (0.75 + 0.25 * Math.Sin(q.ph + 3 * t)));
    }

    # туманності
    nb = eo((t - 0.9) / 1.2) * (0.85 + 0.15 * Math.Sin(t / 3));
    global.neb_a.SetX(global.CX - 430 + 40 * Math.Sin(t / 7) - 550);  global.neb_a.SetY(global.CY - 190 - 320);
    global.neb_b.SetX(global.CX + 400 + 30 * Math.Sin(t / 9 + 1) - 500); global.neb_b.SetY(global.CY + 190 - 300);
    global.neb_a.SetOpacity(nb); global.neb_b.SetOpacity(nb * 0.9);

    # сяйво
    g = 0.55 * eo((t - 1.0) / 0.9);
    if (t > 2) g = g * (0.85 + 0.15 * Math.Sin(2 * Math.Pi * (t - 2) / 2.8));
    place(global.glow, global.i_glow, x, y);
    global.glow.SetOpacity(g);

    # хвиля (масштаб лише раз на кадр, поки йде хвиля)
    u = (t - 1.55) / 1.4;
    if (u >= 0 && u <= 1) {
        d = (260 + 760 * eo(u)) / 0.8;
        place(global.ring, global.i_ring.Scale(d, d), x, y);
        global.ring.SetOpacity(0.6 * (1 - u) * (1 - u));
    } else global.ring.SetOpacity(0);

    # орбіта й супутники
    oo = eo((t - 1.3) / 0.8);
    place(global.orb_b, global.i_orb_b, x, y + 10);
    place(global.orb_f, global.i_orb_f, x, y + 10);
    global.orb_b.SetOpacity(oo);
    global.orb_f.SetOpacity(oo);
    for (i = 0; i < 2; i++) {
        q = global.sat[i];
        th = q.w * t + q.ph;
        sn = Math.Sin(th);
        q.sp.SetX(x + ''' + "%.1f" % OA + r''' * Math.Cos(th) - 12);
        q.sp.SetY(y + 10 + ''' + "%.1f" % OB + r''' * sn - 12);
        if (sn >= 0) { q.sp.SetZ(13); q.sp.SetOpacity(oo); } else { q.sp.SetZ(6); q.sp.SetOpacity(oo * 0.55); }
    }

    # комета
    if (t > 2.6) {
        cu = fmod(t - 2.6, 6.5) / 1.1;
        if (cu <= 1) {
            global.comet.SetX(global.CX - 900 + 1500 * cu - 180);
            global.comet.SetY(global.CY - 480 + 450 * cu - 60);
            global.comet.SetOpacity(Math.Sin(Math.Pi * cu));
        } else global.comet.SetOpacity(0);
    }

    # напис і рядок статусу
    e = eo((t - 2.2) / 0.8);
    global.title.SetX(global.CX - ''' + str(TITLE_W / 2) + r''');
    global.title.SetY(global.CY + 168 + 22 * (1 - e) - ''' + str(TITLE_H / 2) + r''');
    global.title.SetOpacity(e);
    global.status.SetOpacity(eo((t - 2.6) / 0.6) * 0.75);
}
Plymouth.SetRefreshFunction(refresh);

# ── назви служб, що стартують (systemd) — дрібно внизу, «система вантажиться» ──
fun status_cb(text) {
    s = text;
    global.status.SetImage(Image.Text("›  " + s, 0.55, 0.78, 1.0, 1, "Monospace 11"));
    global.status.SetX(global.CX - global.status.GetImage().GetWidth() / 2);
    global.status.SetY(global.H - 70);
}
Plymouth.SetUpdateStatusFunction(status_cb);

# ── повідомлення про помилки — рожевим, вище ──
global.msg = Sprite(); global.msg.SetZ(20);
fun message(text) {
    global.msg.SetImage(Image.Text(text, 0.95, 0.72, 0.83, 1, "Sans 13"));
    global.msg.SetPosition(global.CX - global.msg.GetImage().GetWidth() / 2, global.H - 110, 20);
}
Plymouth.SetMessageFunction(message);

# ── пароль (на випадок шифрування диска) ──
global.pw = Sprite(); global.pw.SetZ(20);
fun password(prompt, bullets) {
    s = prompt + "  ";
    for (i = 0; i < bullets; i++) s = s + "●";
    global.pw.SetImage(Image.Text(s, 0.91, 0.93, 0.96, 1, "Sans 16"));
    global.pw.SetPosition(global.CX - global.pw.GetImage().GetWidth() / 2, global.CY + 230, 20);
    global.pw.SetOpacity(1);
}
fun normal() { global.pw.SetOpacity(0); }
Plymouth.SetDisplayPasswordFunction(password);
Plymouth.SetDisplayNormalFunction(normal);
'''


# ═════════════ відео 60 fps ═════════════
FAKE = ["systemd-udevd.service", "systemd-journald.service", "Mount /boot", "NetworkManager.service", "bluetooth.service",
        "power-profiles-daemon.service", "upower.service", "ollama.service", "sddm.service"]


def video(path, dur=7.5, fps=60):
    from PIL import ImageDraw, ImageFont
    I = {n[:-4]: Image.open(os.path.join(A, n)).convert("RGBA") for n in os.listdir(A) if n.endswith(".png")}
    try:
        mono = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf", 15)
    except OSError:
        mono = ImageFont.load_default()
    proc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
                             "-r", str(fps), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
                             "-movflags", "+faststart", path], stdin=subprocess.PIPE)
    cx, cy = W / 2, H / 2
    ring_cache = {}

    def put(c, img, x, y, op):
        if op <= 0.003: return
        if op < 0.999:
            img = img.copy(); img.putalpha(img.getchannel("A").point(lambda v: int(v * op)))
        c.alpha_composite(img, (int(round(x)), int(round(y))))

    def mid(c, img, x, y, op): put(c, img, x - img.width / 2, y - img.height / 2, op)

    frames = int(dur * fps)
    for f in range(frames):
        t = f / fps
        s = state(t)
        c = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        for (dx, dy, op), S in zip(s["stars"], STARS):
            mid(c, I[S["img"]], cx + dx, cy + dy, op)
        if s["comet"]:
            put(c, I["comet"], cx + s["comet"][0] - 180, cy + s["comet"][1] - 60, s["comet"][2])
        (ax, ay, aop), (bx, by, bop) = s["neb"]
        put(c, I["nebula_a"], cx + ax - 550, cy + ay - 320, aop)
        put(c, I["nebula_b"], cx + bx - 500, cy + by - 300, bop)
        x, y = cx + s["icx"], cy + s["icy"]
        mid(c, I["glow"], x, y, s["glow"])
        if s["ring"]:
            d = int(s["ring"][0])
            if d not in ring_cache: ring_cache[d] = I["ring_blue"].resize((d, d), Image.BILINEAR)
            mid(c, ring_cache[d], x, y, s["ring"][1])
        mid(c, I["orbit_back"], x, y + 10, s["orbit"])
        for (sx, sy, front), S in zip(s["sats"], SATS):
            if not front: mid(c, I[S["img"]], x + sx, y + sy, s["orbit"] * 0.55)
        k = s["step"]
        if s["grad_op"] < 1: mid(c, I["sb_%02d" % k], x, y, 1)
        mid(c, I["shine_%02d" % s["shine"]] if s["shine"] >= 0 else I["sg_%02d" % k], x, y, s["grad_op"])
        mid(c, I["orbit_front"], x, y + 10, s["orbit"])
        for (sx, sy, front), S in zip(s["sats"], SATS):
            if front: mid(c, I[S["img"]], x + sx, y + sy, s["orbit"])
        put(c, I["splash_text"], cx - BMP_W / 2 + s["text_dx"], cy - BMP_H / 2, s["text_op"])
        e, ty = s["title"]
        put(c, I["title"], cx - TITLE_W / 2, cy + ty - TITLE_H / 2, e)
        if s["status"] > 0.01:
            txt = "›  " + FAKE[min(len(FAKE) - 1, int(max(0, t - 2.4) / 0.55))]
            layer = Image.new("RGBA", (W, 40), (0, 0, 0, 0))
            dr = ImageDraw.Draw(layer)
            tw = dr.textlength(txt, font=mono)
            dr.text(((W - tw) / 2, 8), txt, font=mono, fill=(140, 199, 255, int(255 * 0.75 * s["status"])))
            c.alpha_composite(layer, (0, H - 78))
        if t > dur - 0.45:
            c = Image.blend(c, Image.new("RGBA", (W, H), (0, 0, 0, 255)), cl((t - (dur - 0.45)) / 0.45))
        proc.stdin.write(c.convert("RGB").tobytes())
        if f % 90 == 0: print("  кадр %d/%d" % (f, frames), flush=True)
    proc.stdin.close(); proc.wait()


if __name__ == "__main__":
    open(os.path.join(A, "archglass.script"), "w").write(script())
    print("сценарій Plymouth готовий")
    if "--no-video" not in sys.argv:
        out = os.path.expanduser("~/Відео/arch-boot.mp4")
        video(out)
        print("відео:", out)
