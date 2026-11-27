#!/usr/bin/env python3
"""Звуки інтерфейсу під кожну тему — синтезуються з нуля (numpy), без чужих семплів.

  ~/.local/share/parallax-venv/bin/python sfx_gen.py      → ~/.config/wallpapers_QS/sounds/<тема>/<подія>.wav

Тембр теми:
  sky        — мʼяка маримба (теплі дерев'яні удари)
  neon       — яскравий синт-«щипок» з відлунням
  mountains  — кришталеві дзвіночки з великим простором
  synthwave  — ретро-лід 80-х (пилка + вібрато + gated-ревер)
  aurora     — повітряний пед із мерехтінням октавою вище
"""
import os, wave
import numpy as np
from scipy.signal import lfilter, fftconvolve

SR = 48000
OUT = os.path.expanduser("~/.config/wallpapers_QS/sounds")
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.004, d=0.25, sustain=0.0, rel=0.05):
    """Атака → експоненційний спад (до sustain) → короткий відпуск у кінці."""
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4))
    dec = sustain + (1 - sustain) * np.exp(-np.maximum(0, t - a) / max(d, 1e-4))
    e = e * dec
    r = int(SR * rel)
    if r and n > r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, cut):
    """Простий однополюсний ФНЧ (м'якшає «пилку»)."""
    a = np.exp(-2 * np.pi * cut / SR)
    return lfilter([1 - a], [1, -a], x)


def reverb(x, size=1.2, mix=0.3, damp=3000):
    """Ревер згорткою з загасаючим шумом."""
    n = int(SR * size)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / size))
    ir = lowpass(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fftconvolve(x, ir)[: len(x) + n]
    wet = np.concatenate([wet, np.zeros(len(x) + n - len(wet))])
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - mix) + wet * mix * 0.9


def echo(x, delay=0.13, fb=0.35, taps=3):
    d = int(SR * delay)
    y = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        y[d * k: d * k + len(x)] += x * (fb ** k)
    return y


# ---------- тембри: (частота, тривалість, гучність) → семпли ----------
def marimba(f, dur, v=1.0):
    t = t_(dur)
    s = np.sin(2 * np.pi * f * t) * env(len(t), 0.002, dur * 0.35)
    s += 0.35 * np.sin(2 * np.pi * f * 4 * t) * env(len(t), 0.001, dur * 0.07)
    s += 0.12 * np.sin(2 * np.pi * f * 10 * t) * env(len(t), 0.001, 0.012)
    return s * v


def pluck(f, dur, v=1.0):
    t = t_(dur)
    s = sum((1 / k) * np.sin(2 * np.pi * f * k * t * (1 + 0.002 * (k % 2))) for k in range(1, 9))
    s += 0.5 * sum((1 / k) * np.sin(2 * np.pi * f * 1.006 * k * t) for k in range(1, 7))
    s = lowpass(s, 2600) * env(len(t), 0.002, dur * 0.28)
    return s * v * 0.7


def chime(f, dur, v=1.0):
    t = t_(dur)
    s = np.zeros_like(t)
    for ratio, amp, dk in ((1, 1, 0.6), (2.76, 0.45, 0.3), (5.40, 0.25, 0.16), (8.93, 0.12, 0.08)):
        s += amp * np.sin(2 * np.pi * f * ratio * t) * env(len(t), 0.001, dur * dk)
    return s * v * 0.8


def retro(f, dur, v=1.0):
    t = t_(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.12)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    s = sum(((-1) ** (k + 1)) / k * np.sin(k * ph) for k in range(1, 12))       # пилка
    s += 0.5 * np.sign(np.sin(ph * 0.5)) * 0.3                                   # «квадрат» октавою нижче
    s = lowpass(s, 3200) * env(len(t), 0.004, dur * 0.5, 0.25, 0.04)
    return s * v * 0.45


def pad(f, dur, v=1.0):
    t = t_(dur)
    s = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.003 * t)
    s += 0.3 * (2 / np.pi) * np.arcsin(np.sin(2 * np.pi * f * 0.5 * t))          # трикутник октавою нижче
    s += 0.22 * np.sin(2 * np.pi * f * 2 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t))   # мерехтіння
    a = min(0.05, dur * 0.3)
    return s * env(len(t), a, dur * 0.55, 0, 0.06) * v * 0.55


THEMES = {
    #           тембр    корінь(MIDI) лад (ступені)              ревер (розмір, мікс)  відлуння
    "sky":       (marimba, 72, [0, 2, 4, 7, 9, 12, 14, 16],  (0.9, 0.18), None),
    "neon":      (pluck,   69, [0, 3, 5, 7, 10, 12, 15, 17], (0.8, 0.15), (0.11, 0.33)),
    "mountains": (chime,   76, [0, 2, 4, 7, 9, 12, 14, 16],  (2.2, 0.38), None),
    "synthwave": (retro,   66, [0, 3, 5, 7, 10, 12, 15, 17], (0.5, 0.30), (0.16, 0.30)),
    "aurora":    (pad,     74, [0, 2, 4, 6, 7, 11, 12, 14],  (2.6, 0.42), None),
}

# подія → список (ступінь ладу, зсув октави, початок с, тривалість с, гучність)
EVENTS = {
    "volume":    [(4, 0, 0.00, 0.11, 0.8)],
    "notify":    [(2, 0, 0.00, 0.30, 0.8), (4, 0, 0.09, 0.45, 0.9)],
    "error":     [(3, 0, 0.00, 0.22, 0.9), (0, 0, 0.11, 0.22, 0.9), (0, -1, 0.22, 0.45, 0.8)],
    "critical":  [(4, 0, 0.00, 0.18, 1.0), (2, 0, 0.14, 0.18, 1.0), (0, 0, 0.28, 0.18, 1.0),
                  (4, 0, 0.62, 0.18, 1.0), (2, 0, 0.76, 0.18, 1.0), (0, 0, 0.90, 0.40, 1.0)],
    "plug":      [(0, 0, 0.00, 0.20, 0.8), (2, 0, 0.07, 0.20, 0.85), (4, 0, 0.14, 0.40, 0.9)],
    "unplug":    [(4, 0, 0.00, 0.20, 0.8), (0, 0, 0.09, 0.40, 0.8)],
    "usb-in":    [(3, 0, 0.00, 0.20, 0.85), (5, 0, 0.08, 0.45, 0.9)],
    "usb-out":   [(5, 0, 0.00, 0.20, 0.85), (3, 0, 0.08, 0.40, 0.8)],
    "theme":     [(0, 0, 0.00, 0.60, 0.7), (2, 0, 0.09, 0.60, 0.7), (4, 0, 0.18, 0.60, 0.75),
                  (5, 0, 0.27, 0.70, 0.75), (7, 0, 0.36, 1.10, 0.85)],
    "game-on":   [(0, -1, 0.00, 0.25, 0.8), (3, -1, 0.06, 0.25, 0.8), (5, -1, 0.12, 0.25, 0.85),
                  (0, 0, 0.18, 0.30, 0.9), (2, 0, 0.18, 0.60, 0.6), (4, 0, 0.18, 0.70, 0.7)],
    "game-off":  [(4, 0, 0.00, 0.30, 0.7), (2, 0, 0.10, 0.30, 0.7), (0, 0, 0.20, 0.60, 0.7)],
    "lock":      [(2, 0, 0.00, 0.25, 0.6), (0, 0, 0.10, 0.45, 0.6)],
    "unlock":    [(0, 0, 0.00, 0.22, 0.6), (2, 0, 0.08, 0.22, 0.65), (4, 0, 0.16, 0.45, 0.7)],
}


def shutter(n):
    """Звук знімка екрана: два клацання шторки."""
    out = np.zeros(int(SR * 0.22))
    for st in (0.0, 0.075):
        k = int(SR * 0.035)
        click = rng.standard_normal(k) * np.exp(-np.arange(k) / SR / 0.006)
        click = click - lowpass(click, 1500)                    # лише «клац», без гулу
        i = int(SR * st)
        out[i:i + k] += click * 0.6
    return out


def render(theme):
    voice, root, scale, (rs, rm), ec = THEMES[theme]
    os.makedirs(os.path.join(OUT, theme), exist_ok=True)
    for name, notes in list(EVENTS.items()) + [("screenshot", None)]:
        if notes is None:
            mix = shutter(0)
            blip = voice(midi(root + scale[4] + 12), 0.12, 0.35)
            j = int(SR * 0.09)
            mix = np.concatenate([mix, np.zeros(max(0, j + len(blip) - len(mix)))])
            mix[j:j + len(blip)] += blip
        else:
            total = max(st + d for _, _, st, d, _ in notes) + 0.02
            mix = np.zeros(int(SR * total))
            for deg, octv, st, d, v in notes:
                s = voice(midi(root + scale[deg % len(scale)] + 12 * (octv + deg // len(scale))), d, v)
                i = int(SR * st)
                mix[i:i + len(s)] += s[: len(mix) - i]
        if ec and name != "volume":
            mix = echo(mix, *ec)
        size = rs if name != "volume" else min(rs, 0.4)
        mix = reverb(mix, size, rm if name != "volume" else rm * 0.5)
        # обрізати тишу в хвості, нормалізувати
        nz = np.where(np.abs(mix) > 1e-4 * np.max(np.abs(mix)))[0]
        mix = mix[: nz[-1] + 1] if len(nz) else mix
        fade = min(len(mix), int(SR * 0.03))
        mix[-fade:] *= np.linspace(1, 0, fade)
        peak = {"volume": 0.45, "critical": 0.8, "error": 0.7}.get(name, 0.6)
        mix = mix / (np.max(np.abs(mix)) + 1e-9) * peak
        with wave.open(os.path.join(OUT, theme, name + ".wav"), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((mix * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    for th in THEMES:
        render(th)
        print("ok", th)
