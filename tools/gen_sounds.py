#!/usr/bin/env python3
"""
Procedural sound-effect generator for Starfall (numpy + stdlib `wave`, no other
deps). Synthesises original blaster / explosion / hit / UI sounds and writes
16-bit mono 44.1 kHz WAVs to assets/sounds/.

Re-run after tweaking:  python3 tools/gen_sounds.py
"""

import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sounds"
SR = 44100

rng = np.random.default_rng(7)


# --- building blocks --------------------------------------------------------


def tarr(dur):
    return np.linspace(0.0, dur, int(SR * dur), endpoint=False)


def sweep_phase(f0, f1, t, curve=1.0):
    """Radian phase for an exponential glide from f0 to f1 across t."""
    if t[-1] <= 0:
        return np.zeros_like(t)
    k = (t / t[-1]) ** curve
    f = f0 * (f1 / f0) ** k
    return 2.0 * np.pi * np.cumsum(f) / SR


def env(t, attack=0.003, decay=0.15, curve=4.0):
    """Linear attack, exponential decay."""
    n = len(t)
    na = min(n, max(1, int(attack * SR)))
    e = np.ones(n)
    e[:na] = np.linspace(0.0, 1.0, na)
    ref = t[na - 1] if na < n else t[-1]
    e *= np.exp(-curve * np.maximum(0.0, t - ref) / max(decay, 1e-4))
    return e


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a scalar or a per-sample array."""
    if np.isscalar(cutoff):
        cutoff = np.full(len(x), float(cutoff))
    a = np.exp(-2.0 * np.pi * np.clip(cutoff, 20.0, SR / 2) / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1.0 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y


def crush(x, bits=6, hold=3):
    q = 2 ** bits
    y = np.round(x * q) / q
    if hold > 1:
        y = np.repeat(y[::hold], hold)[: len(x)]
    return y


def noise(n):
    return rng.uniform(-1.0, 1.0, n)


# --- the sounds -----------------------------------------------------------


def shot_player():
    t = tarr(0.18)
    ph = sweep_phase(1950, 470, t, curve=0.7)
    body = 0.6 * np.sign(np.sin(ph)) + 0.4 * np.sin(ph * 1.006)
    click = noise(len(t)) * np.exp(-t / 0.008) * 0.5
    return (body + click) * env(t, 0.001, 0.11, curve=5.0)


def shot_enemy():
    t = tarr(0.24)
    ph = sweep_phase(780, 200, t, curve=0.85)
    saw = 2.0 * ((ph / (2.0 * np.pi)) % 1.0) - 1.0
    sq = np.sign(np.sin(ph * 0.994))
    y = (0.6 * saw + 0.5 * sq) * env(t, 0.002, 0.17, curve=4.0)
    return lowpass(y, np.linspace(3600, 650, len(t)))


def explosion_small():
    t = tarr(0.5)
    body = lowpass(noise(len(t)), np.linspace(4600, 280, len(t)))
    body *= env(t, 0.002, 0.26, curve=3.0)
    sub = np.sin(sweep_phase(82, 36, t)) * np.exp(-t / 0.11)
    return 1.15 * body + 0.9 * sub


def explosion_big():
    t = tarr(1.0)
    body = lowpass(noise(len(t)), np.linspace(3200, 110, len(t)))
    body *= env(t, 0.003, 0.58, curve=2.2)

    debris = np.zeros_like(t)
    s = int(0.22 * SR)
    dn = lowpass(noise(len(t) - s), np.linspace(2400, 190, len(t) - s))
    debris[s:] = dn * np.exp(-(t[s:] - t[s]) / 0.24) * 0.6

    sub = np.sin(sweep_phase(58, 24, t)) * np.exp(-t / 0.34)
    rumble = 1.0 + 0.28 * np.sin(2.0 * np.pi * 27.0 * t)
    return (1.1 * body + debris) * rumble + 1.25 * sub


def hit():
    t = tarr(0.2)
    tone = np.sign(np.sin(sweep_phase(320, 110, t)))
    y = (0.5 * tone + 0.8 * noise(len(t))) * env(t, 0.001, 0.13, curve=4.0)
    y = crush(y, bits=5, hold=4)
    return lowpass(y, np.linspace(3200, 480, len(t)))


def special():
    t = tarr(0.75)
    swoosh = np.sign(np.sin(sweep_phase(180, 1300, t, 1.5))) * 0.28
    swoosh *= env(t, 0.02, 0.32, curve=2.5)
    air = lowpass(noise(len(t)), np.linspace(500, 6500, len(t)))
    air *= env(t, 0.04, 0.5, curve=1.6) * 0.75
    boom = np.sin(sweep_phase(120, 38, t)) * np.exp(-t / 0.42)
    return swoosh + air + 1.25 * boom


def powerup():
    t = tarr(0.28)
    y = np.zeros_like(t)
    for i, f in enumerate((523.0, 659.0, 784.0, 1046.0)):
        s = int(i * 0.05 * SR)
        e = min(len(t), int((i * 0.05 + 0.07) * SR))
        seg = t[s:e] - t[s]
        y[s:e] += np.sin(2.0 * np.pi * f * seg) * np.exp(-seg / 0.045)
    return y * 0.6


def ui_move():
    t = tarr(0.045)
    return np.sin(2.0 * np.pi * 880.0 * t) * env(t, 0.001, 0.028, curve=6.0) * 0.5


def ui_select():
    t = tarr(0.12)
    half = len(t) // 2
    y = np.empty_like(t)
    y[:half] = np.sin(2.0 * np.pi * 640.0 * t[:half])
    y[half:] = np.sin(2.0 * np.pi * 960.0 * t[half:])
    return y * env(t, 0.001, 0.085, curve=4.0) * 0.55


SOUNDS = [
    ("shot_player", shot_player, 0.75),
    ("shot_enemy", shot_enemy, 0.68),
    ("explosion_small", explosion_small, 0.90),
    ("explosion_big", explosion_big, 0.95),
    ("hit", hit, 0.85),
    ("special", special, 0.95),
    ("powerup", powerup, 0.70),
    ("ui_move", ui_move, 0.45),
    ("ui_select", ui_select, 0.60),
]


def save(name, y, gain):
    y = np.tanh(y * 1.2)                       # soft clip
    peak = float(np.max(np.abs(y))) or 1.0
    y = y / peak * gain
    fade = int(0.006 * SR)
    y[-fade:] *= np.linspace(1.0, 0.0, fade)   # de-click tail
    y[:16] *= np.linspace(0.0, 1.0, 16)        # de-click head
    data = np.clip(y * 32767.0, -32768, 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {name:16s} {len(y) / SR * 1000:5.0f} ms")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn, gain in SOUNDS:
        save(name, fn(), gain)
    print(f"wrote {len(SOUNDS)} sounds -> {OUT}")


if __name__ == "__main__":
    main()
