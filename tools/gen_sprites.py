#!/usr/bin/env python3
"""
Procedural pixel-art sprite generator for Starfall.

Produces original ship / bullet / explosion sprites (bilateral symmetry, a
limited palette, rim light, dark exterior outline) and packs them into

    assets/sprites/atlas.png     - the texture the game loads
    assets/sprites/atlas.txt     - "name x y w h frames" manifest (game reads this)
    assets/sprites/atlas.json    - same data as JSON, for external tools
    assets/sprites/preview.png   - 6x zoom contact sheet, for eyeballing
    assets/sprites/<name>.png    - each sprite on its own, for reuse

Nothing here is derived from any existing asset pack - it's all drawn from
maths. Re-run after tweaking:  python3 tools/gen_sprites.py
"""

import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"

# ---------------------------------------------------------------------------
# palette: outline, shade, base, light, accent (canopy), glow (engine)
# ---------------------------------------------------------------------------


def _pal(*hexes):
    out = []
    for hx in hexes:
        hx = hx.lstrip("#")
        out.append((int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16), 255))
    return out


PALETTES = {
    "player": _pal("0a0f1c", "20508f", "418fd6", "9fd6ff", "ffe27a", "8ff0ff"),
    "grunt":  _pal("07140f", "1c6b52", "2fae86", "9ff0d0", "ff5b5b", "d9fff0"),
    "darter": _pal("15150a", "7c7c1e", "cccc36", "f4f486", "ff9a3c", "ffffd0"),
    "brute":  _pal("140a16", "5f1c7c", "9a2fc0", "e08ff0", "8fd0ff", "ffd9ff"),
    "boss1":  _pal("0a0f1c", "24507f", "3f8fd6", "a6dcff", "ffd166", "8ff0ff"),
    "boss2":  _pal("1a0f05", "8f4f16", "e0912f", "ffca7a", "ff5b5b", "fff0d6"),
    "boss3":  _pal("1a0707", "8f2422", "e0402f", "ff9a7a", "ffd166", "ffe0d6"),
    "boss4":  _pal("101418", "45525f", "8a97a6", "cdd7e1", "7ad0ff", "f2f6fa"),
    "boss5":  _pal("120a1a", "4f1c8f", "8f3fd6", "c9a6ff", "ff7ad0", "efe6ff"),
    "weaver": _pal("1a1205", "7c5a16", "d69a2f", "ffe08a", "ff6b3c", "fff0c0"),
    "sentinel": _pal("0a1618", "1c6b6b", "2faeae", "9ff0f0", "ff5b5b", "d9ffff"),
    "hunter": _pal("140a16", "6b1c7c", "b02fc0", "e88ff0", "ffd166", "ffd9ff"),
    "racer":  _pal("07140a", "1c7c3a", "2fc060", "9ff0b8", "ffd166", "d9ffe4"),
    "warden": _pal("1a0707", "7c2222", "c02f2f", "f08f8f", "ffce6b", "ffe0d6"),
    "shot_p": _pal("0a1420", "2f8fd6", "8fd6ff", "ffffff", "ffffff", "cdeeff"),
    "shot_e": _pal("1a0710", "8f2060", "e0407f", "ffd0e4", "ffffff", "ff8fae"),
}

OUTLINE, SHADE, BASE, LIGHT, ACCENT, GLOW = range(6)
CLEAR = (0, 0, 0, 0)


# ---------------------------------------------------------------------------
# raster helpers - work on an (h, w, 4) uint8 array
# ---------------------------------------------------------------------------


def canvas(w, h):
    return np.zeros((h, w, 4), dtype=np.uint8)


def _set(img, x, y, rgba):
    h, w = img.shape[:2]
    if 0 <= int(x) < w and 0 <= int(y) < h:
        img[int(y), int(x)] = rgba


def _get(img, x, y):
    h, w = img.shape[:2]
    if 0 <= int(x) < w and 0 <= int(y) < h:
        return img[int(y), int(x)]
    return CLEAR


def hspan(img, y, x0, x1, rgba):
    if x1 < x0:
        x0, x1 = x1, x0
    for x in range(int(round(x0)), int(round(x1)) + 1):
        _set(img, x, y, rgba)


def disc(img, cx, cy, r, rgba, jitter=0.0, rng=None):
    r2 = r * r
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            edge = r2 * (1.0 + (rng.uniform(-jitter, jitter) if rng else 0.0))
            if d2 <= edge:
                _set(img, x, y, rgba)


def outline_pass(img, color):
    """Any transparent pixel 4-adjacent to a solid one becomes `color`."""
    h, w = img.shape[:2]
    a = img[:, :, 3]
    solid = a > 0
    ring = np.zeros_like(solid)
    ring[1:, :] |= solid[:-1, :]
    ring[:-1, :] |= solid[1:, :]
    ring[:, 1:] |= solid[:, :-1]
    ring[:, :-1] |= solid[:, 1:]
    ring &= ~solid
    img[ring] = color


# ---------------------------------------------------------------------------
# ship builder
# ---------------------------------------------------------------------------


def profile(points, t):
    """Piecewise-linear half-width fraction at position t in [0,1]."""
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        if t0 <= t <= t1:
            u = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            return v0 + (v1 - v0) * u
    return points[-1][1]


def make_ship(
    w,
    h,
    palette,
    hull,
    *,
    nose_up=True,
    canopy_t=0.30,        # centre of the canopy along the hull (0 = nose)
    canopy_px=(4, 5),     # (half-width, half-height) of the canopy, in pixels
    engine_frac=0.14,     # fraction of the hull length that is engine block
    panels=(),            # tuple of t positions for thin panel lines
    struts=False,         # dark lines along the wing roots
    seed=0,
):
    rng = random.Random(seed)
    P = PALETTES[palette]
    img = canvas(w, h)
    cx = (w - 1) / 2.0
    maxhw = (w - 2) / 2.0

    def hw_at(tn):
        return profile(hull, max(0.0, min(1.0, tn))) * maxhw

    # --- silhouette + directional shading -------------------------------
    for y in range(h):
        tn = (y / (h - 1)) if nose_up else 1.0 - (y / (h - 1))
        hw = hw_at(tn)
        if hw < 0.4:
            continue
        left, right = cx - hw, cx + hw
        hspan(img, y, left, right, P[BASE])
        hspan(img, y, left, left + 0.6, P[LIGHT])       # lit edge
        hspan(img, y, right - 0.6, right, P[SHADE])     # dark edge
        if tn < 0.10:                                   # bright nose cap
            hspan(img, y, left, right, P[LIGHT])
        if tn > 1.0 - engine_frac:                      # engine block
            hspan(img, y, left, right, P[SHADE])

    # --- panel lines ---------------------------------------------------
    for pt in panels:
        y = int((pt if nose_up else 1 - pt) * (h - 1))
        row_hw = hw_at(pt)
        hspan(img, y, cx - row_hw + 1, cx + row_hw - 1, P[SHADE])

    # --- wing-root struts -------------------------------------------
    if struts:
        for y in range(h):
            tn = (y / (h - 1)) if nose_up else 1.0 - (y / (h - 1))
            if 0.45 < tn < 0.9:
                hw = hw_at(tn)
                _set(img, cx - hw * 0.45, y, P[SHADE])
                _set(img, cx + hw * 0.45, y, P[SHADE])

    # --- canopy ------------------------------------------------------
    cyc = (canopy_t if nose_up else 1 - canopy_t) * (h - 1)
    chw, chh = canopy_px
    for dy in range(-chh, chh + 1):
        k = 1.0 - (dy / (chh + 0.5)) ** 2
        if k <= 0:
            continue
        ww = max(1, round(chw * math.sqrt(k)))
        hspan(img, cyc + dy, cx - ww, cx + ww, P[ACCENT])
    _set(img, cx, cyc, P[LIGHT])
    _set(img, cx - 1, cyc - (1 if nose_up else -1), (255, 255, 255, 255))

    # --- nozzle glow, kept inside the hull ------------------------------
    ty = (h - 1) if nose_up else 0
    inner = (ty - 1) if nose_up else (ty + 1)
    tail_hw = hw_at(1.0 - 1.0 / (h - 1))
    for dx in range(int(-tail_hw + 1), int(tail_hw)):
        if dx % 2 == 0:
            _set(img, cx + dx, ty, P[GLOW])
            _set(img, cx + dx, inner, P[GLOW])

    outline_pass(img, P[OUTLINE])
    return img


def rect(img, x0, y0, x1, y1, rgba):
    for y in range(int(y0), int(y1) + 1):
        hspan(img, y, x0, x1, rgba)


# Per-boss silhouette: size, hull profile, and superstructure knobs. Each
# level's capital ship reads differently at a glance.
BOSS_SHAPE = {
    1: dict(  # BLOCKADE WARDEN - a wide, shallow picket platform
        w=126, h=44, core_frac=0.40, core_h=0.86,
        hull=[(0.00, 0.22), (0.14, 0.40), (0.34, 0.42), (0.50, 0.38),
              (0.66, 0.42), (0.84, 0.40), (0.94, 0.22), (1.00, 0.10)],
        pods=2, pod_x=0.33, pod_span=(0.28, 0.60), barrels=7, barrel_spread=0.78,
        plates=2, core_r=5, wings=False, ring=False, mega_barrel=False),
    2: dict(  # BELT CRUSHER - a bulky, rounded mining rig
        w=100, h=58, core_frac=0.56, core_h=0.82,
        hull=[(0.00, 0.26), (0.16, 0.46), (0.36, 0.52), (0.52, 0.46),
              (0.68, 0.54), (0.82, 0.50), (0.92, 0.30), (1.00, 0.16)],
        pods=2, pod_x=0.34, pod_span=(0.30, 0.72), barrels=3, barrel_spread=0.30,
        plates=3, core_r=7, wings=False, ring=False, mega_barrel=False),
    3: dict(  # YARD SOVEREIGN - a tall, narrow arrowhead
        w=74, h=66, core_frac=0.62, core_h=0.90,
        hull=[(0.00, 0.10), (0.14, 0.24), (0.34, 0.30), (0.50, 0.24),
              (0.64, 0.42), (0.78, 0.44), (0.90, 0.24), (1.00, 0.08)],
        pods=0, pod_x=0.30, pod_span=(0.30, 0.66), barrels=2, barrel_spread=0.24,
        plates=2, core_r=6, wings=False, ring=False, mega_barrel=False),
    4: dict(  # SIEGE COLOSSUS - a massive block with one central cannon
        w=118, h=62, core_frac=0.66, core_h=0.80,
        hull=[(0.00, 0.24), (0.10, 0.48), (0.24, 0.64), (0.44, 0.66),
              (0.60, 0.64), (0.78, 0.60), (0.90, 0.42), (1.00, 0.24)],
        pods=1, pod_x=0.0, pod_span=(0.30, 0.66), barrels=0, barrel_spread=0.30,
        plates=4, core_r=8, wings=False, ring=False, mega_barrel=True),
    5: dict(  # ANDROMEDAN THRONE - layered, winged, big glowing core
        w=98, h=60, core_frac=0.50, core_h=0.82,
        hull=[(0.00, 0.16), (0.14, 0.32), (0.32, 0.36), (0.50, 0.30),
              (0.66, 0.42), (0.80, 0.42), (0.90, 0.24), (1.00, 0.12)],
        pods=3, pod_x=0.34, pod_span=(0.32, 0.62), barrels=3, barrel_spread=0.34,
        plates=3, core_r=9, wings=True, ring=True, mega_barrel=False),
}


def make_boss(level):
    """One capital ship per level, each a distinct silhouette - see BOSS_SHAPE."""
    pal = f"boss{level}"
    P = PALETTES[pal]
    S = BOSS_SHAPE[level]
    w, h = S["w"], S["h"]
    cx = (w - 1) / 2.0
    img = canvas(w, h)

    # central hull (nose points down, toward the player)
    core_h = int(h * S["core_h"])
    core = make_ship(
        int(w * S["core_frac"]), core_h, pal, S["hull"],
        nose_up=False,
        canopy_t=0.22, canopy_px=(3, 4),
        engine_frac=0.12, panels=(0.4, 0.62),
        seed=level * 7,
    )
    ox = int(cx - core.shape[1] / 2)
    m = core[:, :, 3] > 0
    img[:core_h, ox:ox + core.shape[1]][m] = core[m]

    ps0, ps1 = S["pod_span"]

    if S["mega_barrel"]:
        # one huge central cannon, jutting well below the hull
        rect(img, cx - 7, h * 0.36, cx + 7, h * 0.98, P[SHADE])
        rect(img, cx - 5, h * 0.36, cx + 5, h * 0.98, P[BASE])
        rect(img, cx - 5, h * 0.36, cx - 4, h * 0.98, P[LIGHT])
        _set(img, cx, h * 0.98, P[GLOW])
        _set(img, cx, h * 0.98 - 1, P[GLOW])

    # side / triple weapon pods
    if S["pods"] == 3:
        offsets = (-S["pod_x"], 0.0, S["pod_x"])
    elif S["pods"] == 2:
        offsets = (-S["pod_x"], S["pod_x"])
    else:
        offsets = ()
    for fx in offsets:
        px = cx + fx * w
        lo, hi = ps0, ps1
        if level == 2 and fx > 0:          # rig asymmetry: right claw hangs lower
            lo, hi = ps0 + 0.06, ps1 + 0.10
        rect(img, px - 8, h * lo - 2, px + 8, h * lo, P[SHADE])       # brace
        rect(img, px - 8, h * lo, px + 8, h * hi, P[BASE])
        rect(img, px - 8, h * lo, px - 7, h * hi, P[LIGHT] if fx < 0 else P[SHADE])
        rect(img, px + 7, h * lo, px + 8, h * hi, P[LIGHT] if fx < 0 else P[SHADE])
        rect(img, px - 6, h * hi, px + 6, h * hi + h * 0.10, P[SHADE])  # muzzle
        disc(img, px, h * (lo + hi) / 2.0, 3, P[GLOW])
        a, b = sorted((px, cx))
        rect(img, a + 3, h * 0.42, b - 3, h * 0.46, P[SHADE])          # strut

    # sovereign has swept prongs instead of pods
    if level == 3:
        for side in (-1, 1):
            for j in range(int(h * 0.46)):
                yy = h * 0.30 + j
                t = j / (h * 0.46)
                xx = cx + side * (w * 0.26 + t * w * 0.14)
                _set(img, xx, yy, P[BASE])
                _set(img, xx + side, yy, P[SHADE])
            _set(img, cx + side * (w * 0.40), h * 0.76, P[GLOW])

    # inner downward barrels
    n = S["barrels"]
    for i in range(n):
        frac = 0.0 if n == 1 else (i / (n - 1) - 0.5)
        bx = cx + frac * (w * S["barrel_spread"])
        rect(img, bx - 2, h * 0.60, bx + 2, h * 0.82, P[SHADE])
        _set(img, bx, h * 0.82, P[GLOW])
        _set(img, bx, h * 0.82 + 1, P[GLOW])

    # winglets sweeping up off the throne
    if S["wings"]:
        for side in (-1, 1):
            for j in range(7):
                xx = cx + side * (w * 0.22 + j * 3)
                yy = h * 0.36 - j * 2
                _set(img, xx, yy, P[LIGHT])
                _set(img, xx, yy + 1, P[BASE])
                _set(img, xx, yy + 2, P[SHADE])

    # armour plates banding the hull
    for i in range(S["plates"]):
        dy = 0.30 + i * (0.34 / max(1, S["plates"]))
        rect(img, cx - 5 - i, h * dy, cx + 5 + i, h * dy + 1, P[SHADE])

    # reactor core
    r = S["core_r"]
    disc(img, cx, h * 0.40, r + 1, P[SHADE])
    disc(img, cx, h * 0.40, r - 1, P[GLOW])
    disc(img, cx, h * 0.40, max(1, r - 3), (255, 255, 255, 255))
    if S["ring"]:
        for a in range(0, 360, 24):
            rad = math.radians(a)
            _set(img, cx + math.cos(rad) * (r + 4), h * 0.40 + math.sin(rad) * (r + 4), P[GLOW])

    outline_pass(img, P[OUTLINE])
    return img


def make_bullet_player():
    w, h = 6, 16
    P = PALETTES["shot_p"]
    img = canvas(w, h)
    cx = (w - 1) / 2.0
    for y in range(1, h - 1):
        k = math.sin((y - 1) / (h - 3) * math.pi)
        hw = 0.5 + 2.0 * k
        hspan(img, y, cx - hw, cx + hw, P[GLOW])
    for y in range(2, h - 2):
        hspan(img, y, cx - 1, cx + 1, P[LIGHT])
    for y in range(3, h - 3):
        _set(img, cx, y, (255, 255, 255, 255))
    outline_pass(img, P[OUTLINE])
    return img


def make_bullet_enemy():
    w = h = 9
    P = PALETTES["shot_e"]
    img = canvas(w, h)
    c = (w - 1) / 2.0
    disc(img, c, c, 3.4, P[GLOW])
    disc(img, c, c, 2.4, P[BASE])
    disc(img, c, c, 1.2, P[LIGHT])
    _set(img, c, c, (255, 255, 255, 255))
    outline_pass(img, P[OUTLINE])
    return img


def make_missile():
    """A small seeker for the special weapon - nose points up (rotated in game)."""
    w, h = 7, 17
    P = PALETTES["shot_p"]
    img = canvas(w, h)
    cx = (w - 1) / 2.0
    for y in range(2, h - 1):
        t = (y - 2) / (h - 4)
        hw = 0.6 + 2.4 * min(1.0, t * 1.7)
        if t > 0.72:
            hw *= 1.0 - 0.55 * (t - 0.72) / 0.28
        hspan(img, y, cx - hw, cx + hw, P[BASE])
    for y in range(2, 5):
        hspan(img, y, cx - 1, cx + 1, P[LIGHT])          # nose cone
    for y in range(h - 6, h - 3):                        # tail fins
        _set(img, cx - 2, y, P[SHADE])
        _set(img, cx + 2, y, P[SHADE])
    _set(img, cx, h - 2, P[GLOW])
    _set(img, cx, h - 1, (255, 180, 70, 255))            # exhaust spark
    outline_pass(img, P[OUTLINE])
    return img


def make_pickup():
    """Special-weapon recharge item: a glowing cyan diamond."""
    w = h = 15
    img = canvas(w, h)
    c = (w - 1) / 2.0
    outline = (10, 32, 42, 255)
    mid     = (60, 170, 220, 255)
    glow    = (130, 240, 255, 255)
    core    = (240, 255, 255, 255)
    for y in range(h):
        rad = (c - 1) - abs(y - c)
        if rad >= 0:
            hspan(img, y, c - rad, c + rad, mid)
    for y in range(h):
        rad = (c - 3) - abs(y - c)
        if rad >= 0:
            hspan(img, y, c - rad, c + rad, glow)
    disc(img, c, c, 2.2, core)
    outline_pass(img, outline)
    return img


# ---------------------------------------------------------------------------
# cheap deterministic value noise, for organic (non-elliptical) coastlines
# and streaky cloud bands on the Earth sprite
# ---------------------------------------------------------------------------


def clamp01(v):
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


def _hash01(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFFFFFF) / 4294967295.0


def _vnoise(x, y, seed):
    x0, y0 = math.floor(x), math.floor(y)
    sx, sy = x - x0, y - y0
    x0i, y0i = int(x0), int(y0)
    n00 = _hash01(x0i, y0i, seed)
    n10 = _hash01(x0i + 1, y0i, seed)
    n01 = _hash01(x0i, y0i + 1, seed)
    n11 = _hash01(x0i + 1, y0i + 1, seed)
    sx = sx * sx * (3 - 2 * sx)
    sy = sy * sy * (3 - 2 * sy)
    a = n00 + (n10 - n00) * sx
    b = n01 + (n11 - n01) * sx
    return a + (b - a) * sy


def _fbm(x, y, seed, octaves=4, lac=2.0, gain=0.5):
    amp, freq, total, norm = 0.5, 1.0, 0.0, 0.0
    for i in range(octaves):
        total += amp * _vnoise(x * freq, y * freq, seed * 97 + i * 131)
        norm += amp
        amp *= gain
        freq *= lac
    return total / norm


# ---------------------------------------------------------------------------
# backdrop planets - one distant world per level, drawn behind the starfield
# ---------------------------------------------------------------------------

PLANET_PX = 120


def _planet_base(kind, nx, ny):
    """Albedo (float rgb, 0-255) at a point on the unit disc, before lighting."""
    if kind == "titan":
        haze = 0.5 + 0.5 * math.sin(ny * 2.3 + 0.6)
        return [208 + 14 * haze, 150 + 12 * haze, 70 + 16 * haze]
    if kind == "jupiter":
        band = math.sin(ny * 9.0) + 0.35 * math.sin(ny * 23.0 + 1.0)
        if band > 0.55:
            return [236, 216, 184]
        if band > 0.0:
            return [214, 182, 138]
        if band > -0.55:
            return [180, 138, 96]
        return [201, 166, 120]
    if kind == "mars":
        v = 0.5 + 0.5 * math.sin(nx * 3.1 + ny * 2.0)
        return [176 + 20 * v, 78 + 16 * v, 50 + 12 * v]
    if kind == "moon":
        v = 0.5 + 0.5 * math.sin(nx * 4.0 + 1.3) * math.sin(ny * 3.3)
        g = 138 + 20 * v
        return [g, g + 4, g + 14]
    # earth: deep polar ocean warming towards the equator, capped with ice
    # at both poles (soft gradient, not a hard-edged blot).
    polar = clamp01((abs(ny) - 0.72) / 0.28)
    eq    = 1.0 - min(1.0, abs(ny) / 0.92)
    deep, warm, ice = (24, 66, 112), (34, 108, 150), (234, 240, 246)
    base = [deep[i] + (warm[i] - deep[i]) * (0.4 * eq) for i in range(3)]
    return [base[i] + (ice[i] - base[i]) * polar for i in range(3)]


def make_planet(kind, seed):
    S = PLANET_PX
    R = S * 0.44
    c = (S - 1) / 2.0
    rng = random.Random(seed)
    img = canvas(S, S)

    alb = np.zeros((S, S, 3), dtype=np.float32)
    mask = np.zeros((S, S), dtype=bool)
    for y in range(S):
        for x in range(S):
            nx, ny = (x - c) / R, (y - c) / R
            if nx * nx + ny * ny <= 1.0:
                mask[y, x] = True
                alb[y, x] = _planet_base(kind, nx, ny)

    def blot(bx, by, rx, ry, color, hard=0.55):
        col = np.array(color, np.float32)
        for y in range(max(0, int(by - ry - 1)), min(S, int(by + ry + 2))):
            for x in range(max(0, int(bx - rx - 1)), min(S, int(bx + rx + 2))):
                if not mask[y, x]:
                    continue
                dx, dy = (x - bx) / rx, (y - by) / ry
                q = dx * dx + dy * dy
                if q <= 1.0:
                    k = 1.0 if q <= hard else 1.0 - (q - hard) / (1.0 - hard)
                    alb[y, x] = alb[y, x] * (1.0 - k) + col * k

    if kind == "titan":
        for _ in range(5):
            blot(c + rng.uniform(-R, R), c + rng.uniform(-R, R),
                 rng.uniform(0.5 * R, 0.9 * R), rng.uniform(0.18 * R, 0.32 * R),
                 [196, 132, 58], hard=0.15)
        blot(c, c + 0.1 * R, 1.05 * R, 0.13 * R, [232, 186, 110], hard=0.1)

    elif kind == "jupiter":
        for _ in range(9):
            blot(c + rng.uniform(-R, R), c + rng.uniform(-0.85 * R, 0.85 * R),
                 rng.uniform(0.25 * R, 0.6 * R), rng.uniform(0.05 * R, 0.11 * R),
                 [244, 228, 200] if rng.random() > 0.5 else [168, 126, 86], hard=0.1)
        blot(c + 0.34 * R, c + 0.2 * R, 0.24 * R, 0.15 * R, [198, 96, 66], hard=0.45)
        blot(c + 0.34 * R, c + 0.2 * R, 0.14 * R, 0.09 * R, [220, 130, 96], hard=0.5)

    elif kind == "mars":
        for _ in range(6):
            blot(c + rng.uniform(-0.8 * R, 0.8 * R), c + rng.uniform(-0.6 * R, 0.8 * R),
                 rng.uniform(0.3 * R, 0.6 * R), rng.uniform(0.22 * R, 0.4 * R),
                 [118, 52, 38], hard=0.12)
        for _ in range(3):
            blot(c + rng.uniform(-0.7 * R, 0.7 * R), c + rng.uniform(-0.7 * R, 0.7 * R),
                 rng.uniform(0.2 * R, 0.4 * R), rng.uniform(0.16 * R, 0.3 * R),
                 [206, 122, 86], hard=0.12)
        blot(c, c - 0.82 * R, 0.28 * R, 0.16 * R, [232, 226, 216], hard=0.4)
        blot(c, c + 0.9 * R, 0.16 * R, 0.1 * R, [226, 220, 210], hard=0.4)

    elif kind == "moon":
        for _ in range(5):
            blot(c + rng.uniform(-0.7 * R, 0.7 * R), c + rng.uniform(-0.7 * R, 0.7 * R),
                 rng.uniform(0.28 * R, 0.55 * R), rng.uniform(0.24 * R, 0.5 * R),
                 [96, 98, 110], hard=0.15)
        for _ in range(22):
            cr = rng.uniform(0.04 * R, 0.13 * R)
            bx = c + rng.uniform(-0.92 * R, 0.92 * R)
            by = c + rng.uniform(-0.92 * R, 0.92 * R)
            blot(bx, by, cr * 1.35, cr * 1.35, [178, 180, 190], hard=0.6)
            blot(bx, by, cr, cr, [104, 106, 118], hard=0.5)

    else:  # earth - noise-warped continents with ragged coasts, plus clouds
        bumps = [(-0.58, -0.12, 0.32), (0.02, -0.42, 0.28),
                 (0.32, 0.08, 0.24), (0.66, 0.46, 0.15)]
        trop, temp, arid, sand = (58, 122, 60), (108, 122, 66), (176, 146, 96), (214, 202, 160)
        water = mask.copy()

        for y in range(S):
            for x in range(S):
                if not mask[y, x]:
                    continue
                nx, ny = (x - c) / R, (y - c) / R
                if abs(ny) > 0.86:
                    continue                        # under the polar ice, no coast to draw
                bump = max(1.0 - math.hypot(nx - bx, ny - by) / br for bx, by, br in bumps)
                n = _fbm(nx * 3.4 + 11.3, ny * 3.4 - 7.1, seed, octaves=4)
                field = bump * 0.62 + (n - 0.5) * 0.9
                if field <= 0.30:
                    continue
                lat  = abs(ny)
                terr = _fbm(nx * 2.0 + 50.0, ny * 2.0 + 50.0, seed + 5, octaves=3)
                land = trop if lat < 0.30 else (arid if terr > 0.58 else temp)
                shore = clamp01(1.0 - (field - 0.30) / 0.09)
                alb[y, x] = [land[i] * (1.0 - shore) + sand[i] * shore for i in range(3)]
                water[y, x] = False

        for _ in range(16):                                          # small islands
            ang = rng.uniform(0, math.tau)
            rad = rng.uniform(0.35, 0.92) * R
            bx, by = c + math.cos(ang) * rad, c + math.sin(ang) * rad
            if abs((by - c) / R) > 0.85:
                continue
            blot(bx, by, rng.uniform(1.2, 2.6), rng.uniform(1.2, 2.6), trop, hard=0.5)

        cloud_col = np.array([246, 248, 250], np.float32)
        for y in range(S):
            for x in range(S):
                if not mask[y, x]:
                    continue
                nx, ny = (x - c) / R, (y - c) / R
                band = _fbm(nx * 2.2 + 91.0, ny * 5.5 - 91.0, seed + 9, octaves=3)
                wisp = _fbm(nx * 6.0 - 33.0, ny * 6.0 + 33.0, seed + 17, octaves=2)
                a = clamp01((band + 0.30 * wisp - 0.70) / 0.20)
                if a <= 0.0:
                    continue
                alb[y, x] = alb[y, x] * (1.0 - a) + cloud_col * a

    # sphere lighting: diffuse from the upper-left + limb darkening ---------
    lx, ly, lz = -0.50, -0.44, 0.75
    for y in range(S):
        for x in range(S):
            if not mask[y, x]:
                continue
            nx, ny = (x - c) / R, (y - c) / R
            nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
            lam = max(0.0, nx * lx + ny * ly + nz * lz)
            f = (0.14 + 0.98 * lam) * (0.5 + 0.5 * nz)
            r, g, b = alb[y, x] * f
            d2 = nx * nx + ny * ny
            if d2 > 0.9 and lam > 0.35:                 # lit-limb rim light
                t = (d2 - 0.9) / 0.1
                r, g, b = r + 60 * t, g + 70 * t, b + 85 * t
            if kind == "earth" and water[y, x]:          # sun glint on the ocean
                gd = math.hypot(nx - lx, ny - ly)
                if gd < 0.16 and nz > 0.2:
                    t = (1.0 - gd / 0.16) ** 2 * min(1.0, nz * 1.3)
                    r, g, b = r + 95 * t, g + 82 * t, b + 55 * t
            img[y, x] = (int(max(0, min(255, r))), int(max(0, min(255, g))),
                         int(max(0, min(255, b))), 255)

    if kind == "earth":
        for y in range(S):                             # thin atmosphere halo
            for x in range(S):
                d = math.hypot(x - c, y - c)
                if R < d <= R + 3.2:
                    _set(img, x, y, (120, 195, 255, int(130 * (1.0 - (d - R) / 3.2))))
    else:
        outline_pass(img, {
            "titan":   (70, 44, 16, 255),
            "jupiter": (60, 44, 28, 255),
            "mars":    (58, 22, 16, 255),
            "moon":    (40, 40, 50, 255),
        }[kind])

    return img


def make_explosion(frames=7, size=34):
    stops = [
        (255, 255, 235, 255),
        (255, 224, 150, 255),
        (255, 160, 60, 255),
        (226, 74, 42, 255),
        (120, 120, 132, 255),
    ]
    sheet = canvas(size * frames, size)
    c = size / 2.0
    for f in range(frames):
        rng = random.Random(1000 + f)
        p = f / (frames - 1)
        ox = f * size
        core_r = 3 + (size * 0.42) * math.sin(min(1.0, p * 1.3) * math.pi / 2)
        ci = min(len(stops) - 1, int(p * (len(stops) - 1) + 0.5))
        col = list(stops[ci])
        if p > 0.55:
            col[3] = int(255 * max(0.0, 1.0 - (p - 0.55) / 0.45))
        frame = canvas(size, size)
        if p < 0.85:
            disc(frame, c, c, core_r, tuple(col), jitter=0.30, rng=rng)
            disc(frame, c, c, core_r * 0.55, stops[max(0, ci - 1)], jitter=0.2, rng=rng)
        # sparks on an expanding ring
        ring_r = 3 + (size * 0.5) * p
        for i in range(7):
            a = i * (2 * math.pi / 7) + f
            sx = c + math.cos(a) * ring_r
            sy = c + math.sin(a) * ring_r
            sa = int(255 * max(0.0, 1.0 - p))
            if sa > 10:
                _set(frame, sx, sy, (255, 230, 170, sa))
        sheet[:, ox:ox + size] = frame
    return sheet, frames


# ---------------------------------------------------------------------------
# assemble
# ---------------------------------------------------------------------------


def build():
    sprites = []  # (name, img, frames)

    # player - a sleek interceptor, nose up
    player_hull = [
        (0.00, 0.05), (0.14, 0.12), (0.34, 0.30), (0.54, 0.30),
        (0.64, 0.52), (0.72, 1.00), (0.80, 1.00), (0.86, 0.36),
        (0.94, 0.42), (1.00, 0.30),
    ]
    sprites.append(("player", make_ship(28, 34, "player", player_hull,
                                        canopy_t=0.34, canopy_px=(3, 5),
                                        panels=(0.58,), struts=True, seed=1), 1))

    # grunt - a stubby wide fighter, nose down
    grunt_hull = [
        (0.00, 0.10), (0.10, 0.34), (0.26, 0.60), (0.40, 1.00),
        (0.56, 1.00), (0.70, 0.56), (0.84, 0.62), (1.00, 0.20),
    ]
    sprites.append(("enemy_grunt", make_ship(30, 24, "grunt", grunt_hull,
                                             nose_up=False, canopy_t=0.24,
                                             canopy_px=(3, 3), panels=(0.5,), seed=2), 1))

    # darter - a thin dagger with tail fins, nose down
    darter_hull = [
        (0.00, 0.24), (0.10, 0.40), (0.20, 0.44), (0.34, 0.40),
        (0.55, 0.30), (0.70, 0.92), (0.80, 0.92), (0.88, 0.30),
        (1.00, 0.05),
    ]
    sprites.append(("enemy_darter", make_ship(22, 30, "darter", darter_hull,
                                              nose_up=False, canopy_t=0.22,
                                              canopy_px=(2, 5), panels=(0.4,), seed=3), 1))

    # brute - a broad gunship, nose down
    brute_hull = [
        (0.00, 0.10), (0.08, 0.34), (0.16, 0.60), (0.28, 0.78),
        (0.40, 1.00), (0.58, 1.00), (0.70, 0.70), (0.84, 0.74),
        (0.94, 0.40), (1.00, 0.24),
    ]
    sprites.append(("enemy_brute", make_ship(40, 32, "brute", brute_hull,
                                             nose_up=False, canopy_t=0.20,
                                             canopy_px=(4, 4), panels=(0.42, 0.64),
                                             struts=True, seed=4), 1))

    # weaver - swept twin-boom raider, nose down
    weaver_hull = [
        (0.00, 0.14), (0.12, 0.30), (0.24, 0.34), (0.40, 0.26),
        (0.52, 0.92), (0.64, 1.00), (0.74, 0.66), (0.86, 0.70),
        (0.94, 0.34), (1.00, 0.16),
    ]
    sprites.append(("enemy_weaver", make_ship(34, 26, "weaver", weaver_hull,
                                              nose_up=False, canopy_t=0.26,
                                              canopy_px=(3, 3), panels=(0.44, 0.7),
                                              struts=True, seed=11), 1))

    # sentinel - compact hovering gun platform, near-square
    sentinel_hull = [
        (0.00, 0.40), (0.12, 0.66), (0.24, 0.78), (0.40, 0.82),
        (0.60, 0.82), (0.74, 0.90), (0.86, 0.78), (1.00, 0.50),
    ]
    sprites.append(("enemy_sentinel", make_ship(30, 28, "sentinel", sentinel_hull,
                                                nose_up=False, canopy_t=0.5,
                                                canopy_px=(4, 4), panels=(0.3, 0.62),
                                                seed=12), 1))

    # hunter - forward-swept interceptor, nose down
    hunter_hull = [
        (0.00, 0.06), (0.12, 0.16), (0.30, 0.30), (0.44, 0.34),
        (0.56, 1.00), (0.66, 1.00), (0.74, 0.34), (0.86, 0.44),
        (0.94, 0.30), (1.00, 0.12),
    ]
    sprites.append(("enemy_hunter", make_ship(30, 30, "hunter", hunter_hull,
                                              nose_up=False, canopy_t=0.28,
                                              canopy_px=(2, 4), panels=(0.5,),
                                              struts=True, seed=13), 1))

    # racer - a thin needle, nose down
    racer_hull = [
        (0.00, 0.05), (0.16, 0.14), (0.34, 0.20), (0.52, 0.24),
        (0.60, 0.66), (0.70, 0.66), (0.78, 0.22), (0.90, 0.24),
        (1.00, 0.10),
    ]
    sprites.append(("enemy_racer", make_ship(18, 34, "racer", racer_hull,
                                             nose_up=False, canopy_t=0.24,
                                             canopy_px=(2, 5), panels=(0.42,), seed=14), 1))

    # warden - a heavy elite gunship, nose down
    warden_hull = [
        (0.00, 0.12), (0.08, 0.36), (0.16, 0.62), (0.28, 0.82),
        (0.40, 1.00), (0.60, 1.00), (0.72, 0.72), (0.85, 0.78),
        (0.94, 0.42), (1.00, 0.26),
    ]
    sprites.append(("enemy_warden", make_ship(44, 34, "warden", warden_hull,
                                              nose_up=False, canopy_t=0.2,
                                              canopy_px=(5, 5), panels=(0.4, 0.64),
                                              struts=True, seed=15), 1))

    for lvl in range(1, 6):
        sprites.append((f"boss_{lvl}", make_boss(lvl), 1))

    sprites.append(("bullet_player", make_bullet_player(), 1))
    sprites.append(("bullet_enemy", make_bullet_enemy(), 1))
    sprites.append(("missile", make_missile(), 1))
    sprites.append(("pickup", make_pickup(), 1))

    # backdrop planets, one per level: Titan, Jupiter, Mars, the Moon, Earth
    for i, pk in enumerate(["titan", "jupiter", "mars", "moon", "earth"], start=1):
        sprites.append((f"planet_{i}", make_planet(pk, 400 + i * 13), 1))

    ex, exf = make_explosion()
    sprites.append(("explosion", ex, exf))

    # shelf pack ------------------------------------------------------------
    PAD = 2
    WIDTH = 256
    items = sorted(sprites, key=lambda s: -s[1].shape[0])
    x = y = PAD
    shelf = 0
    placed = []
    for name, im, frames in items:
        ih, iw = im.shape[:2]
        if x + iw + PAD > WIDTH:
            x = PAD
            y += shelf + PAD
            shelf = 0
        placed.append((name, im, frames, x, y))
        x += iw + PAD
        shelf = max(shelf, ih)
    atlas = canvas(WIDTH, y + shelf + PAD)
    manifest = {}
    for name, im, frames, px, py in placed:
        ih, iw = im.shape[:2]
        atlas[py:py + ih, px:px + iw] = im
        manifest[name] = {"x": px, "y": py, "w": iw, "h": ih, "frames": frames}

    # write ---------------------------------------------------------------
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas, "RGBA").save(OUT / "atlas.png")

    lines = ["# name x y w h frames"]
    for name, m in sorted(manifest.items()):
        lines.append(f"{name} {m['x']} {m['y']} {m['w']} {m['h']} {m['frames']}")
    (OUT / "atlas.txt").write_text("\n".join(lines) + "\n")
    (OUT / "atlas.json").write_text(json.dumps(manifest, indent=2) + "\n")

    for name, im, frames in sprites:
        Image.fromarray(im, "RGBA").save(OUT / f"{name}.png")

    # preview contact sheet
    zoom = 6
    pv = Image.fromarray(atlas, "RGBA").resize(
        (atlas.shape[1] * zoom, atlas.shape[0] * zoom), Image.NEAREST
    )
    bg = Image.new("RGBA", pv.size, (14, 16, 26, 255))
    bg.alpha_composite(pv)
    bg.convert("RGB").save(OUT / "preview.png")

    print(f"wrote {len(sprites)} sprites -> {OUT}")
    print(f"atlas {atlas.shape[1]}x{atlas.shape[0]}")


if __name__ == "__main__":
    build()
