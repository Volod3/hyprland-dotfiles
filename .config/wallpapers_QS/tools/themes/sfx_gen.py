#!/usr/bin/env python3
"""Звуки інтерфейсу під кожну тему — мінімалістичні, короткі, синтезуються з нуля (numpy/scipy).

  ~/.local/share/parallax-venv/bin/python sfx_gen.py      → ~/.config/wallpapers_QS/sounds/<тема>/<подія>.wav

Характер теми (одна «фірмова» барва на тему, 1–3 ноти на подію, мало ревербу):
  sky        — «краплі»: синус, що підскакує вгору на старті, як крапля у воду
  neon       — FM-«блип»: чистий цифровий тон, коротке відлуння
  mountains  — «скло»: кришталевий дзвін, легкий простір
  synthwave  — «чіп»: квадрат 80-х з падінням висоти
  aurora     — «подих»: мʼякий синус з повітряним шумом

Звуки підключення флешки / зарядки беруться з KDE Plasma (тема Ocean), див. tools/sfx.
"""
import os, wave
import numpy as np
from scipy.signal import lfilter, fftconvolve, butter

SR = 48000
OUT = os.path.expanduser("~/.config/wallpapers_QS/sounds")
rng = np.random.default_rng(11)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def tt(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.003, d=0.15, rel=0.02):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-np.maximum(0, t - a) / max(d, 1e-4))
    r = min(n, int(SR * rel))
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def lp(x, cut):
    b, a = butter(2, min(cut, SR * 0.45) / (SR / 2))
    return lfilter(b, a, x)


def hp(x, cut):
    b, a = butter(2, cut / (SR / 2), "high")
    return lfilter(b, a, x)


def room(x, size=0.35, mix=0.12):
    n = int(SR * size)
    ir = lp(rng.standard_normal(n), 5000) * np.exp(-np.arange(n) / SR * (6.9 / size))
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fftconvolve(x, ir)
    return np.concatenate([x, np.zeros(len(wet) - len(x))]) * (1 - mix) + wet * mix


def slap(x, delay=0.085, g=0.28, taps=2):
    d = int(SR * delay)
    y = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        y[d * k:d * k + len(x)] += lp(x, 3500) * g ** k
    return y


# ---------- барви ----------
def v_drop(f, dur, v):                       # sky: крапля — висота підскакує вгору на старті
    t = tt(dur)
    fr = f * (0.72 + 0.28 * (1 - np.exp(-t / 0.012)))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    s = np.sin(ph) + 0.12 * np.sin(2 * ph)
    return s * env(len(t), 0.002, dur * 0.28) * v


def v_fm(f, dur, v):                         # neon: FM-блип
    t = tt(dur)
    idx = 2.2 * np.exp(-t / 0.03)
    s = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 2 * t))
    return s * env(len(t), 0.001, dur * 0.22) * v * 0.9


def v_glass(f, dur, v):                      # mountains: кришталевий дзвін
    t = tt(dur)
    s = np.sin(2 * np.pi * f * t) * env(len(t), 0.001, dur * 0.38)
    s += 0.22 * np.sin(2 * np.pi * f * 2.76 * t) * env(len(t), 0.001, dur * 0.12)
    s += 0.06 * np.sin(2 * np.pi * f * 5.4 * t) * env(len(t), 0.0005, 0.02)
    return s * v


def v_chip(f, dur, v):                       # synthwave: квадрат з падінням висоти
    t = tt(dur)
    fr = f * (1 + 0.06 * np.exp(-t / 0.02))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    sq = sum(np.sin(k * ph) / k for k in (1, 3, 5, 7, 9))
    return lp(sq, 4200) * env(len(t), 0.002, dur * 0.25) * v * 0.6


def v_breath(f, dur, v):                     # aurora: мʼякий синус + повітря
    t = tt(dur)
    a = min(0.03, dur * 0.25)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 1.5 * t)
    air = lp(hp(rng.standard_normal(len(t)), 2500), 7000) * 0.18
    return (s + air) * env(len(t), a, dur * 0.35) * v * 0.8


#            барва      корінь  лад                         простір (розмір, мікс)  відлуння
THEMES = {
    "sky":       (v_drop,   79, [0, 2, 4, 7, 9, 12, 14],   (0.30, 0.10), None),
    "neon":      (v_fm,     81, [0, 3, 5, 7, 10, 12, 15],  (0.25, 0.06), (0.075, 0.26)),
    "mountains": (v_glass,  84, [0, 2, 4, 7, 9, 12, 14],   (0.70, 0.16), None),
    "synthwave": (v_chip,   74, [0, 3, 5, 7, 10, 12, 15],  (0.35, 0.10), (0.11, 0.22)),
    "aurora":    (v_breath, 77, [0, 2, 4, 6, 7, 11, 12],   (0.90, 0.20), None),
}

# подія → [(ступінь, октава, старт с, тривалість с, гучність)] — мінімум нот
EVENTS = {
    "volume":   [(2, 0, 0.00, 0.07, 1.0)],
    "notify":   [(2, 0, 0.00, 0.16, 0.9), (4, 0, 0.075, 0.26, 1.0)],
    "error":    [(1, -1, 0.00, 0.14, 1.0), (0, -1, 0.10, 0.26, 0.9)],
    "critical": [(1, -1, 0.00, 0.12, 1.0), (0, -1, 0.09, 0.18, 0.9), (1, -1, 0.34, 0.12, 1.0), (0, -1, 0.43, 0.26, 0.9)],
    "theme":    [(0, 0, 0.00, 0.18, 0.8), (2, 0, 0.07, 0.18, 0.85), (4, 0, 0.14, 0.40, 1.0)],
    "game-on":  [(0, -1, 0.00, 0.10, 0.85), (4, -1, 0.06, 0.10, 0.9), (0, 0, 0.12, 0.30, 1.0)],
    "game-off": [(0, 0, 0.00, 0.12, 0.85), (0, -1, 0.09, 0.28, 0.85)],
    "lock":     [(2, 0, 0.00, 0.12, 0.8), (0, 0, 0.08, 0.24, 0.8)],
    "unlock":   [(0, 0, 0.00, 0.12, 0.8), (2, 0, 0.07, 0.24, 0.85)],
    # запасні — якщо в системі немає звуків KDE (пакет ocean-sound-theme)
    "plug":     [(0, 0, 0.00, 0.14, 0.9), (4, 0, 0.07, 0.24, 1.0)],
    "unplug":   [(4, 0, 0.00, 0.14, 0.9), (0, 0, 0.07, 0.24, 0.9)],
    "usb-in":   [(2, 0, 0.00, 0.14, 0.9), (5, 0, 0.07, 0.24, 1.0)],
    "usb-out":  [(5, 0, 0.00, 0.14, 0.9), (2, 0, 0.07, 0.24, 0.9)],
}
PEAK = {"volume": 0.42, "error": 0.62, "critical": 0.7}


def click():
    """Знімок екрана: одне сухе клацання шторки."""
    k = int(SR * 0.03)
    return hp(rng.standard_normal(k), 1800) * np.exp(-np.arange(k) / SR / 0.004) * 0.7


def render(theme):
    voice, root, scale, (rs, rm), ec = THEMES[theme]
    os.makedirs(os.path.join(OUT, theme), exist_ok=True)
    for name in list(EVENTS) + ["screenshot"]:
        if name == "screenshot":
            c = click()
            b = voice(midi(root + scale[4] + 12), 0.08, 0.35)
            mix = np.zeros(int(SR * 0.04) + len(b))
            mix[:len(c)] += c
            mix[int(SR * 0.04):] += b
        else:
            notes = EVENTS[name]
            mix = np.zeros(int(SR * (max(s + d for _, _, s, d, _ in notes) + 0.01)))
            for deg, octv, st, d, v in notes:
                s = voice(midi(root + scale[deg] + 12 * octv), d, v)
                i = int(SR * st)
                mix[i:i + len(s)] += s[:len(mix) - i]
        if ec and name not in ("volume", "screenshot"):
            mix = slap(mix, *ec)
        mix = room(mix, rs if name != "volume" else 0.2, rm if name != "volume" else rm * 0.4)
        nz = np.where(np.abs(mix) > 3e-4 * np.max(np.abs(mix)))[0]
        mix = mix[:nz[-1] + 1]
        f = min(len(mix), int(SR * 0.02))
        mix[-f:] *= np.linspace(1, 0, f)
        mix = mix / (np.max(np.abs(mix)) + 1e-9) * PEAK.get(name, 0.55)
        with wave.open(os.path.join(OUT, theme, name + ".wav"), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((mix * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    for th in THEMES:
        render(th)
        print("ok", th)
