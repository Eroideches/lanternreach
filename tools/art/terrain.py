"""Terreno: tessere erba isometriche, bordi dell'isola sospesa, evidenziazioni, decorazioni, cielo e nuvole."""
import math
import random

from PIL import Image, ImageDraw, ImageFilter

from common import CW, CH, HW, HH, INK, PALETTE as C, GLOOM, Scene, render, lighten, darken, mix


def grass_tile(variant=0, pal="player"):
    """Tessera 128x64 (rombo). Variazione leggera di tono + ciuffi deterministici."""
    rnd = random.Random(variant * 17 + (0 if pal == "player" else 99))
    base = [C["grass_m"], mix(C["grass_m"], C["grass_l"], 0.25), mix(C["grass_m"], C["grass_d"], 0.18), mix(C["grass_m"], "#8FCF5A", 0.4)][variant % 4]
    if pal == "gloom":
        base = ["#5A4F78", "#605683", "#544A70", "#5D5A7E"][variant % 4]
    S = Scene(CW, CH, HW, 0)
    S.poly([(HW, 0), (CW, HH), (HW, CH), (0, HH)], base, stroke=None)
    # bordo superiore-sinistro leggermente piu' chiaro (luce), bordo destro piu' scuro
    S.line((0, HH), (HW, 0), lighten(base, 0.25), 2, 0.5)
    S.line((HW, CH), (CW, HH), darken(base, 0.15), 2, 0.5)
    for _ in range(5):
        x, y = rnd.uniform(28, 100), rnd.uniform(18, 46)
        if abs(x - HW) / HW + abs(y - HH) / HH > 0.8:
            continue
        col = lighten(base, 0.3) if rnd.random() < 0.6 else darken(base, 0.2)
        S.path(f"M {x - 4:.1f},{y:.1f} L {x - 2:.1f},{y - 6:.1f} M {x:.1f},{y:.1f} L {x + 1:.1f},{y - 8:.1f} M {x + 4:.1f},{y:.1f} L {x + 5:.1f},{y - 5:.1f}", "none", stroke=col, sw=2)
    return render(S)


def flat_tile(color, op=1.0, stroke=None, inset=0, sw=3):
    S = Scene(CW, CH, HW, 0)
    i = inset
    S.poly([(HW, i), (CW - i * 2, HH), (HW, CH - i), (i * 2, HH)], color, stroke=stroke, sw=sw, op=op)
    return render(S)


def deploy_tile():
    S = Scene(CW, CH, HW, 0)
    S.poly([(HW, 0), (CW, HH), (HW, CH), (0, HH)], "#4AA8E8", stroke=None, op=0.22)
    for k in range(-4, 5):
        x = HW + k * 16
        S.line((x - 16, HH + 8), (x + 16, HH - 8), "#FFFFFF", 3, 0.25)
    return render(S)


def cliff_piece(side, pal="player"):
    """Bordo di scogliera sotto il rombo di confine: side 'L' (lato sud-ovest) o 'R' (sud-est)."""
    H = 140
    S = Scene(CW, CH + H, HW, 0)
    rock = C["earth_l"] if pal == "player" else "#5B4A70"
    rock2 = C["earth_d"] if pal == "player" else "#3A2C4E"
    top = C["grass_m"] if pal == "player" else "#4E5A4A"
    if side == "L":
        a, b = (0, HH), (HW, CH)
        col = rock
    else:
        a, b = (HW, CH), (CW, HH)
        col = darken(rock, 0.2)
    rnd = random.Random(1 if side == "L" else 2)
    depth = [rnd.uniform(70, 120) for _ in range(5)]
    pts = [a, b]
    for i in range(4, -1, -1):
        t = i / 4
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t + depth[i]
        pts.append((x, y))
    S.poly(pts, S.grad(col, darken(col, 0.4)), sw=3.5)
    # strati di roccia
    for k in (0.3, 0.6):
        S.path(f"M {a[0]:.1f},{a[1] + 30 * k * 3:.1f} L {b[0]:.1f},{b[1] + 30 * k * 3:.1f}", "none", stroke=darken(col, 0.25), sw=2.5, op=0.6)
    # bordo d'erba che sporge
    S.path(f"M {a[0]:.1f},{a[1]:.1f} L {b[0]:.1f},{b[1]:.1f} L {b[0]:.1f},{b[1] + 10:.1f} Q {(a[0] + b[0]) / 2:.1f},{(a[1] + b[1]) / 2 + 18:.1f} {a[0]:.1f},{a[1] + 10:.1f} Z", top, sw=3)
    # radici e lanternine appese (identita')
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + 40
    S.path(f"M {mx:.1f},{my:.1f} Q {mx + 6:.1f},{my + 30:.1f} {mx - 2:.1f},{my + 50:.1f}", "none", stroke=rock2, sw=3)
    return render(S)


def deco(kind):
    S = Scene(64, 64, 0, 0)
    if kind == "tuft":
        for dx, h in ((-8, 18), (0, 24), (8, 16)):
            S.path(f"M {32 + dx - 3},{52} Q {32 + dx},{52 - h} {32 + dx + 5},{52 - h - 2} Q {32 + dx + 2},{52 - h * 0.5} {32 + dx + 4},{52} Z", C["grass_l"], sw=2.5)
    elif kind in ("flower_a", "flower_b"):
        col = "#FFD764" if kind == "flower_a" else "#FF9EC4"
        S.line((32, 52), (32, 34), "#4E9A46", 4)
        for a in range(0, 360, 72):
            S.circle(32 + math.cos(math.radians(a)) * 7, 30 + math.sin(math.radians(a)) * 7, 6, col, sw=2.5)
        S.circle(32, 30, 4, C["ember"], sw=2)
    elif kind == "pebbles":
        S.ellipse(26, 48, 9, 6, C["stone_l"], sw=2.5)
        S.ellipse(38, 50, 6, 4, C["stone_m"], sw=2.5)
    elif kind == "mushroom":
        S.line((32, 52), (32, 40), "#F3E6D6", 7)
        S.path("M 20,40 Q 32,22 44,40 Z", C["coral"], sw=2.5)
        S.circle(28, 34, 2.5, "#FFFFFF", stroke=None)
        S.circle(36, 33, 2, "#FFFFFF", stroke=None)
    elif kind == "lantern_post":
        S.line((32, 58), (32, 18), INK, 7)
        S.line((32, 58), (32, 18), C["wood_d"], 3)
        S.glow(32, 14, 18, C["amber"], 0.7)
        S.circle(32, 14, 7, C["amber"], sw=3)
    return render(S)


def cloud(variant):
    rnd = random.Random(variant + 3)
    w, h = 320, 140
    S = Scene(w, h, 0, 0)
    blobs = [(rnd.uniform(60, 260), rnd.uniform(60, 90), rnd.uniform(30, 55)) for _ in range(6)]
    for x, y, r in blobs:
        S.circle(x, y, r + 3, "#D8ECFA", stroke=None)
    for x, y, r in blobs:
        S.circle(x, y - 3, r, "#FFFFFF", stroke=None)
    S.poly([(40, 100), (280, 100), (280, 140), (40, 140)], "#000000", stroke=None, op=0)
    return render(S)


def sky(w=512, h=288, pal="player"):
    top, bot = ("#5FB8EE", "#D9F1FF") if pal == "player" else ("#2A2147", "#7A5C8F")
    img = Image.new("RGBA", (w, h))
    t, b = [int(top[i:i + 2], 16) for i in (1, 3, 5)], [int(bot[i:i + 2], 16) for i in (1, 3, 5)]
    d = ImageDraw.Draw(img)
    for y in range(h):
        k = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(t[i] + (b[i] - t[i]) * k) for i in range(3)) + (255,))
    return img
