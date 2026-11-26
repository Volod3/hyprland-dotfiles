#!/usr/bin/env python3
"""Тема курсора «Glass» у стилі робочого столу: темне скло + блакитно-рожевий градієнтний контур + м'яка тінь.
Збирає Xcursor-тему в ~/.local/share/icons/Glass (працює і в Hyprland, і в усіх програмах).

  python3 ~/.config/wallpapers_QS/cursor-theme/build.py
Потрібні: rsvg-convert (librsvg), xcursorgen (xorg-xcursorgen).
"""
import math
import os
import shutil
import subprocess
import tempfile

import sys
HOME = os.path.expanduser("~")
VARIANT = sys.argv[1] if len(sys.argv) > 1 else "Glass"      # Glass | Minimal
MINIMAL = VARIANT == "Minimal"
OUT = os.path.join(HOME, ".local/share/icons/" + VARIANT)
SIZES = [24, 28, 32, 40, 48, 56, 64, 96]          # Xcursor бере найближчий розмір
BLUE, PINK, DARK, WARN = "#8cc8ff", "#f2b8d4", "#12141c", "#f2a0b4"
if MINIMAL:          # простий сучасний: темна заливка, тонкий білий контур, без кольорів
    BLUE = PINK = "#ffffff"; DARK = "#15171c"; WARN = "#ff6b7a"

DEFS = f'''<defs>
  <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{BLUE}"/><stop offset="1" stop-color="{PINK}"/></linearGradient>
  <linearGradient id="gf" x1="0" y1="0" x2="0.9" y2="1">
    <stop offset="0" stop-color="#a9d6ff"/><stop offset="1" stop-color="#f6c8de"/></linearGradient>
  <filter id="sh" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx="0" dy="0.9" stdDeviation="0.9" flood-color="#000" flood-opacity="0.5"/></filter>
</defs>'''


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">{DEFS}<g filter="url(#sh)">{body}</g></svg>'


ARROW = ("M5 3 L5 23.2 L9.9 18.7 L13.2 26.3 L16.1 25.1 L12.9 17.6 L19.4 17.6 Z" if MINIMAL
         else "M4 2.5 L4 24.5 L9.4 19.4 L13 27.6 L16.6 26.1 L13 18.1 L20.4 18.1 Z")
# рука-вказівник (для Minimal)
HAND = ("M12.2 5.2c0-1.25 1-2.2 2.2-2.2s2.2.95 2.2 2.2V12.6c.35-.75 1.15-1.2 2-1.1.95.1 1.65.9 1.65 1.85v.55"
        "c.4-.6 1.1-.95 1.9-.85.95.1 1.65.9 1.65 1.85v.9c.4-.45 1-.7 1.65-.6.9.15 1.55.95 1.55 1.85V22"
        "c0 4.1-3.1 7.2-7.2 7.2h-2.4c-2.4 0-4.5-1.15-5.8-3.1L6.3 20.4c-.6-.95-.35-2.2.55-2.75.85-.55 2-.35 2.6.45l2.75 3.3Z")


def hand(fill=None):
    f = fill or DARK
    return (f'<path d="{HAND}" fill="{f}" fill-opacity="0.96" stroke="#ffffff" stroke-width="1.35" stroke-linejoin="round"/>'
            f'<path d="M16.6 13.6v4.2M20.25 14.4v3.4M23.8 16v2" stroke="#ffffff" stroke-opacity="0.55" stroke-width="1" stroke-linecap="round"/>')


def arrow(fill=None, stroke="url(#g)", extra=""):
    fill = fill or DARK
    if MINIMAL:
        return f'<path d="{ARROW}" fill="{fill}" fill-opacity="0.97" stroke="#ffffff" stroke-width="1.35" stroke-linejoin="round"/>' + extra
    return (f'<path d="{ARROW}" fill="{fill}" fill-opacity="0.94" stroke="{stroke}" stroke-width="1.7" stroke-linejoin="round"/>'
            f'<path d="M5.6 6.2 L5.6 11" stroke="#ffffff" stroke-opacity="0.22" stroke-width="1" stroke-linecap="round"/>' + extra)


def dual(path, w=2.0):
    """Лінія з темним обведенням під градієнтом — видно і на світлому, і на темному."""
    return (f'<path d="{path}" fill="none" stroke="{DARK}" stroke-width="{w + 2.4}" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{path}" fill="none" stroke="url(#g)" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')


def double_arrow(angle):
    p = "M6 16 L26 16 M10 11.5 L5.5 16 L10 20.5 M22 11.5 L26.5 16 L22 20.5"
    return f'<g transform="rotate({angle} 16 16)">{dual(p, 2.2)}</g>'


def spinner(phase, cx=16, cy=16, r=9.0, w=3.0):
    a0 = phase * 2 * math.pi
    a1 = a0 + math.radians(110)
    x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
    x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{DARK}" stroke-width="{w + 2.4}" stroke-opacity="0.85"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#ffffff" stroke-opacity="0.16" stroke-width="{w}"/>'
            f'<path d="M{x0:.2f} {y0:.2f} A{r} {r} 0 0 1 {x1:.2f} {y1:.2f}" fill="none" stroke="url(#g)" stroke-width="{w}" stroke-linecap="round"/>')


# name: (svg або [svg-кадри], hotspot_x, hotspot_y (у сітці 32), затримка кадру мс)
CURSORS = {
    "default": (svg(arrow()), 4, 2.5, 0),
    "pointer": ((svg(hand()), 14.4, 3.2, 0) if MINIMAL else (svg(arrow(fill="url(#gf)", stroke=DARK)), 4, 2.5, 0)),
    "text": (svg(dual("M16 7 L16 25 M12.5 6.5 Q16 7.6 19.5 6.5 M12.5 25.5 Q16 24.4 19.5 25.5", 1.8)), 16, 16, 0),
    "wait": ([svg(spinner(i / 18)) for i in range(18)], 16, 16, 40),
    "progress": ([svg(arrow() + spinner(i / 18, 24.5, 24.5, 4.6, 2.2)) for i in range(18)], 4, 2.5, 40),
    "crosshair": (svg(dual("M16 4 L16 12.5 M16 19.5 L16 28 M4 16 L12.5 16 M19.5 16 L28 16", 1.8)
                      + f'<circle cx="16" cy="16" r="1.4" fill="url(#g)" stroke="{DARK}" stroke-width="0.8"/>'), 16, 16, 0),
    "not-allowed": (svg(f'<circle cx="16" cy="16" r="9.5" fill="{DARK}" fill-opacity="0.55" stroke="{DARK}" stroke-width="5"/>'
                        f'<circle cx="16" cy="16" r="9.5" fill="none" stroke="{WARN}" stroke-width="2.6"/>'
                        f'<path d="M9.4 22.6 L22.6 9.4" stroke="{WARN}" stroke-width="2.6" stroke-linecap="round"/>'), 16, 16, 0),
    "move": (svg(dual("M16 4.5 L16 27.5 M4.5 16 L27.5 16 M12.5 8 L16 4.5 L19.5 8 M12.5 24 L16 27.5 L19.5 24 "
                      "M8 12.5 L4.5 16 L8 19.5 M24 12.5 L27.5 16 L24 19.5", 2.0)), 16, 16, 0),
    "grab": (svg(hand()), 16, 14, 0) if MINIMAL else (svg(arrow(extra=f'<circle cx="22" cy="23" r="4.2" fill="{DARK}" stroke="url(#g)" stroke-width="1.6"/>')), 4, 2.5, 0),
    "grabbing": (svg(hand("#3a3e48")), 16, 14, 0) if MINIMAL else (svg(arrow(fill="url(#gf)", stroke=DARK, extra=f'<circle cx="22" cy="23" r="4.2" fill="url(#g)" stroke="{DARK}" stroke-width="1.6"/>')), 4, 2.5, 0),
    "ew-resize": (svg(double_arrow(0)), 16, 16, 0),
    "ns-resize": (svg(double_arrow(90)), 16, 16, 0),
    "nwse-resize": (svg(double_arrow(45)), 16, 16, 0),
    "nesw-resize": (svg(double_arrow(-45)), 16, 16, 0),
    "help": (svg(arrow() + f'<circle cx="23.5" cy="23.5" r="6" fill="url(#g)" stroke="{DARK}" stroke-width="1.4"/>'
                 f'<text x="23.5" y="27" text-anchor="middle" font-family="Noto Sans" font-weight="700" font-size="9" fill="{DARK}">?</text>'), 4, 2.5, 0),
    "copy": (svg(arrow() + f'<circle cx="23.5" cy="23.5" r="6" fill="url(#g)" stroke="{DARK}" stroke-width="1.4"/>'
                 + f'<path d="M23.5 20.3 L23.5 26.7 M20.3 23.5 L26.7 23.5" stroke="{DARK}" stroke-width="1.8" stroke-linecap="round"/>'), 4, 2.5, 0),
    "zoom-in": (svg(dual("M14 6 A8 8 0 1 0 14.01 6 M19.8 19.8 L26.5 26.5 M14 10.5 L14 17.5 M10.5 14 L17.5 14", 1.9)), 14, 14, 0),
    "zoom-out": (svg(dual("M14 6 A8 8 0 1 0 14.01 6 M19.8 19.8 L26.5 26.5 M10.5 14 L17.5 14", 1.9)), 14, 14, 0),
}

# усі імена, які просять програми (X11, CSS, GTK, Qt), → наш курсор
ALIASES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "context-menu", "center_ptr", "right_ptr", "up_arrow", "draft", "X_cursor", "x-cursor", "dnd-none"],
    "pointer": ["hand", "hand1", "hand2", "pointing_hand", "9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106", "link", "alias", "dnd-link", "3085a0e285430894940527032f8b26df", "640fb0e74195791501fd1ed57b41487f"],
    "text": ["xterm", "ibeam", "vertical-text"],
    "wait": ["watch", "clock"],
    "progress": ["left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"],
    "crosshair": ["cross", "tcross", "cell", "plus", "cross_reverse", "diamond_cross", "target", "color-picker", "pencil"],
    "not-allowed": ["no-drop", "forbidden", "circle", "crossed_circle", "dnd-no-drop", "03b6e0fcb3499374a867c041f52298f0"],
    "move": ["fleur", "all-scroll", "size_all", "dnd-move", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "grab": ["openhand", "fcf1c3c7cd4491d801f1e1c78f100000", "5aca4d189052212118709018842178c0"],
    "grabbing": ["closedhand", "208530c400c041818281048008011002", "9116a3ea924ed2162ecab71ba103b17f"],
    "ew-resize": ["col-resize", "sb_h_double_arrow", "h_double_arrow", "size_hor", "left_side", "right_side", "e-resize", "w-resize", "split_h",
                  "14fef782d02440884392942c11205230", "028006030e0e7ebffc7f7070c0600140", "2870a09082c103050810ffdffffe0204"],
    "ns-resize": ["row-resize", "sb_v_double_arrow", "v_double_arrow", "size_ver", "top_side", "bottom_side", "n-resize", "s-resize", "split_v", "double_arrow",
                  "2870a09082c103050810ffdffffe0204", "00008160000006810000408080010102", "c07385c7190e701020ff7ffffd08103c"],
    "nwse-resize": ["size_fdiag", "bd_double_arrow", "top_left_corner", "bottom_right_corner", "nw-resize", "se-resize", "c7088f0f3e6c8088236ef8e1e3e70000"],
    "nesw-resize": ["size_bdiag", "fd_double_arrow", "top_right_corner", "bottom_left_corner", "ne-resize", "sw-resize"],
    "help": ["question_arrow", "whats_this", "left_ptr_help", "d9ce0ab605698f320427677b458ad60b", "5c6cd98b3f3ebcb1f9c7f1c204630408"],
    "copy": ["dnd-copy", "1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872", "b66166c04f8c3109214a4fbd64a50fc8"],
    "zoom-in": ["zoom_in"],
    "zoom-out": ["zoom_out"],
}


def render(svgtext, size, path):
    p = subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", path], input=svgtext.encode(), capture_output=True)
    if p.returncode:
        raise RuntimeError(p.stderr.decode())


def main():
    tmp = tempfile.mkdtemp()
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(os.path.join(OUT, "cursors"))
    for name, (art, hx, hy, delay) in CURSORS.items():
        frames = art if isinstance(art, list) else [art]
        cfg = []
        for s in SIZES:
            for i, fr in enumerate(frames):
                png = os.path.join(tmp, f"{name}_{s}_{i}.png")
                render(fr, s, png)
                line = f"{s} {round(hx * s / 32)} {round(hy * s / 32)} {png}"
                cfg.append(line + (f" {delay}" if delay else ""))
        cfgp = os.path.join(tmp, name + ".cfg")
        open(cfgp, "w").write("\n".join(cfg) + "\n")
        subprocess.run(["xcursorgen", cfgp, os.path.join(OUT, "cursors", name)], check=True)
        for al in ALIASES.get(name, []):
            dst = os.path.join(OUT, "cursors", al)
            if not os.path.lexists(dst):
                os.symlink(name, dst)
    open(os.path.join(OUT, "index.theme"), "w").write(
        "[Icon Theme]\nName=%s\nComment=%s\n" % (VARIANT, "Простий сучасний мінімалістичний" if MINIMAL else "Темне скло з блакитно-рожевим контуром (стиль робочого столу)"))
    open(os.path.join(OUT, "cursor.theme"), "w").write("[Icon Theme]\nName=%s\nInherits=%s\n" % (VARIANT, VARIANT))
    shutil.rmtree(tmp)
    # прев'ю для README / перевірки
    prev = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview.png")
    names = list(CURSORS)
    tiles = []
    for n in names:
        art = CURSORS[n][0]
        p = os.path.join(tempfile.gettempdir(), "glass_prev_" + n + ".png")
        render(art[3] if isinstance(art, list) else art, 64, p)
        tiles.append(p)
    print("готово:", OUT, "—", len(CURSORS), "курсорів,", sum(len(v) for v in ALIASES.values()), "псевдонімів")
    print("\n".join(tiles))


if __name__ == "__main__":
    main()
