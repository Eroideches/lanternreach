"""Disegni degli edifici (tutti tranne Faro Madre, in buildings.py) e registro."""
import math

from PIL import Image

from common import (CW, CH, HW, HH, INK, PALETTE as C, GLOOM, Scene, render, soft_shadow, bbox_trim,
                    lighten, darken, mix)
from buildings import (Ctx, materials, plinth, pennant_pole, lantern_glow, door, windows, crenellations,
                       cog_pile, crystal, band, tower_cyl, d_hall, tier_of)


def poly_tube(S, p0, p1, w0, w1, color, sw=4):
    """Tubo/cannone (trapezio) da p0 a p1 con larghezze w0,w1 (px)."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L, dx / L
    pts = [(p0[0] + nx * w0, p0[1] + ny * w0), (p1[0] + nx * w1, p1[1] + ny * w1),
           (p1[0] - nx * w1, p1[1] - ny * w1), (p0[0] - nx * w0, p0[1] - ny * w0)]
    S.poly(pts, S.grad(lighten(color, 0.3), darken(color, 0.25), vertical=False), sw=sw)
    return pts


# ============================================================ ECONOMIA
def d_cog_mine(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.04, 7, m["wood"] if t < 3 else m["stone"])
    h = 56 * s
    S.box(0.3, 0.3, 1.2, 1.2, 7, 7 + h, m["wall"])
    S.face_rect("L", 0.3, 0.3, 1.2, 1.2, 7, 7 + h, 0.3, 0.7, 0, 36, "#2A1E36", sw=3.5)   # ingresso galleria
    S.hip_roof(0.3, 0.3, 1.2, 1.2, 7 + h, 34 * s, m["roof"], ridge="y")
    S.box(0.34, 0.34, 0.5, 0.5, 7, 7 + h * 0.9, m["wood"], sw=3, detail=False) if False else None
    # ruota dentata (overlay rotante) con asse
    ax, ay = S.face_point("R", 0.3, 0.3, 1.2, 1.2, 7, 0.5, h * 0.55)
    S.circle(ax, ay, 6, m["metal"], sw=3)
    c.overlays.append(dict(kind="gear", pos=[round(ax - c.ox, 1), round(ay - (c.oy + c.N * HH), 1)], r=26, color=m["metal"], speed=0.8))
    # cassa con ingranaggi e rampa
    S.box(1.3, 1.15, 1.85, 1.7, 7, 7 + 22, m["wood_l"], sw=3.5)
    cog_pile(c, 1.58, 1.42, 7 + 22, 2 + (t > 2) + (t > 4))
    cog_pile(c, 0.5, 1.6, 7, 3 + (t > 3))
    if t >= 3:
        S.box(1.05, 0.12, 1.2, 0.27, 7 + h, 7 + h + 40 * s, "#6B6B7C", sw=3.5)  # ciminiera
        c.ov("smoke", 1.12, 0.2, 7 + h + 40 * s)
    pennant_pole(c, 0.2, 1.3, 7, 70) if t >= 2 else None


def d_sap_well(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.04, 6)
    sx, sy = S.P(1, 1, 6)
    if t >= 3:   # serbatoio vetro dietro
        S.cylinder(1.35, 0.7, 0.34, 6, 6 + 74 * s, mix(m["metal"], "#FFFFFF", 0.25))
        S.cylinder(1.35, 0.7, 0.28, 10, 6 + 60 * s, C["sap"], sw=0, top=False)
        S.sphere(*S.P(1.35, 0.7, 6 + 76 * s), 10, m["metal"])
    S.cylinder(1, 1, 0.62, 6, 6 + 30 * s, m["stone_l"])
    S.ellipse(sx, sy - 30 * s, 0.5 * CW / 2 * 1.0, 0.5 * CH / 2 * 1.0, C["sap"], sw=3)
    S.ellipse(sx - 10, sy - 33 * s, 14, 6, lighten(C["sap"], 0.6), stroke=None, op=0.7)
    c.ov("bubbles", 1, 1, 6 + 30 * s, color=C["sap"])
    # pali + trave + secchio
    for (px, py) in ((0.45, 0.45), (1.55, 1.55)):
        S.line(S.P(px, py, 6), S.P(px, py, 6 + 72 * s), INK, 11)
        S.line(S.P(px, py, 6), S.P(px, py, 6 + 72 * s), m["wood"], 6)
    a, b = S.P(0.45, 0.45, 6 + 70 * s), S.P(1.55, 1.55, 6 + 70 * s)
    S.line(a, b, INK, 11)
    S.line(a, b, m["wood_l"], 6)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    S.line(mid, (mid[0], mid[1] + 34), INK, 4)
    S.poly([(mid[0] - 11, mid[1] + 30), (mid[0] + 11, mid[1] + 30), (mid[0] + 8, mid[1] + 48), (mid[0] - 8, mid[1] + 48)], m["metal"], sw=3.5)
    if t >= 4:
        crystal(S, sx + 38, sy + 6, 26, 7, C["sap"], 3)
        crystal(S, sx + 52, sy + 14, 18, 5, C["sap"], -2)


def d_shard_drill(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.04, 6, m["stone"])
    # cristalli viola alla base
    sx, sy = S.P(1, 1, 6)
    for dx, dy, h, w, tl in ((-40, 14, 44, 10, -4), (40, 16, 36, 9, 5), (-14, 26, 28, 8, -2), (22, 26, 40, 9, 3)):
        crystal(S, sx + dx, sy + dy, h, w, C["shard"] if c.m["glow"] == C["amber"] else GLOOM["spore"], tl)
    # cavalletto
    top = S.P(1, 1, 6 + 100 * s)
    for (px, py) in ((0.4, 0.4), (1.7, 0.45), (0.9, 1.7)):
        p = S.P(px, py, 6)
        S.line(p, top, INK, 11)
        S.line(p, top, m["wood_l"] if t < 3 else m["metal"], 6)
    S.box(0.75, 0.75, 1.25, 1.25, 6 + 92 * s, 6 + 120 * s, m["wall"], sw=3.5)
    # punta trivella
    tip = S.P(1, 1, 6 + 30)
    S.poly([(top[0] - 14, top[1] + 30), (top[0] + 14, top[1] + 30), (tip[0] + 2, tip[1] + 8), (tip[0] - 2, tip[1] + 8)], m["metal"], sw=3.5)
    for i in range(3):
        yy = top[1] + 40 + i * 14
        S.line((top[0] - 12 + i * 3, yy), (top[0] + 12 - i * 3, yy + 6), INK, 3)
    c.overlays.append(dict(kind="gear", pos=[round(top[0] - c.ox + 26, 1), round(top[1] - (c.oy + c.N * HH) - 4, 1)], r=18, color=m["metal"], speed=1.4))
    c.ov("sparkle", 1, 1, 6 + 16, color=C["shard"])


def d_cog_vault(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 7)
    h = 66 * s
    S.box(0.35, 0.35, 2.65, 2.65, 7, 7 + h, m["wall"] if t > 1 else m["stone_l"])
    S.box(0.3, 0.3, 2.7, 2.7, 7 + h, 7 + h + 10, m["metal"], sw=3.5)
    crenellations(c, 0.3, 0.3, 2.7, 2.7, 7 + h + 10, m["metal"], 4, 12)
    # portone tondo
    p = S.face_point("L", 0.35, 0.35, 2.65, 2.65, 7, 0.5, h * 0.45)
    S.circle(p[0], p[1], 40, S.grad(lighten(m["metal"], 0.25), darken(m["metal"], 0.25)), sw=5)
    S.circle(p[0], p[1], 29, darken(m["metal"], 0.12), sw=3.5)
    S.cog(p[0], p[1], 20, lighten(m["metal"], 0.3), 8, 3)
    for ang in range(0, 360, 45):
        S.line((p[0], p[1]), (p[0] + math.cos(math.radians(ang)) * 27, p[1] + math.sin(math.radians(ang)) * 27), INK, 2.5)
    windows(c, "R", (0.35, 0.35, 2.65, 2.65), 7, h, 2, 22)
    cog_pile(c, 0.3, 2.9, 7, 3 + (t > 2) + (t > 4))
    cog_pile(c, 1.4, 0.5, 7 + h + 10, 3)
    pennant_pole(c, 2.8, 2.8, 7, 90, None) if t >= 3 else None
    if t >= 4:
        S.box(2.2, 0.35, 2.65, 0.8, 7 + h, 7 + h + 40, m["wall"], sw=3.5)
        S.pyramid(2.2, 0.35, 2.65, 0.8, 7 + h + 40, 26, m["roof"], 0.08)


def d_sap_cistern(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 7)
    pos = {1: [(1.5, 1.5, 0.95)], 2: [(0.95, 0.95, 0.62), (1.95, 1.95, 0.7)], 3: [(0.95, 0.95, 0.62), (1.95, 1.95, 0.7)],
           4: [(0.8, 0.8, 0.55), (2.2, 0.9, 0.55), (1.45, 2.0, 0.7)], 5: [(0.8, 0.8, 0.55), (2.2, 0.9, 0.55), (1.45, 2.0, 0.7)]}[t]
    pos.sort(key=lambda p: p[0] + p[1])
    for (cx, cy, r) in pos:
        h = (64 + 14 * (r > 0.65)) * s
        S.cylinder(cx, cy, r, 7, 7 + h, m["wall"] if t != 1 else m["wood_l"])
        sx, sy = S.P(cx, cy, 7)
        rx = r * HW
        # fasce
        for zb in (0.28, 0.72):
            band(c, cx, cy, r + 0.02, 7 + h * zb - 4, 7 + h * zb + 4, m["metal"] if t > 1 else m["wood"], 3)
        # finestra livello linfa
        S.poly([(sx - 10, sy - h * 0.8), (sx + 10, sy - h * 0.8), (sx + 10, sy - h * 0.2), (sx - 10, sy - h * 0.2)], "#DFF8EC", sw=3.5)
        S.poly([(sx - 8, sy - h * 0.55), (sx + 8, sy - h * 0.55), (sx + 8, sy - h * 0.22), (sx - 8, sy - h * 0.22)], C["sap"], stroke=None)
        # coperchio a cupola
        S.sphere(sx, sy - h - 2, rx * 0.74, m["roof"] if t > 1 else m["wood"])
        c.ov("bubbles", cx, cy, 7 + h + 10, color=C["sap"])
    S.line(S.P(0.9, 2.9, 7), S.P(0.9, 2.9, 7 + 60), INK, 5)
    S.line(S.P(1.2, 2.9, 7), S.P(1.2, 2.9, 7 + 60), INK, 5)
    for i in range(5):
        S.line(S.P(0.9, 2.9, 12 + i * 12), S.P(1.2, 2.9, 12 + i * 12), INK, 3.5)


def d_shard_crate(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.05, 6, m["stone"])
    S.box(0.35, 0.35, 1.65, 1.65, 6, 6 + 16, m["stone_l"], sw=3.5)
    zc = 6 + 16
    S.box(0.5, 0.55, 1.5, 1.45, zc, zc + 30 * s, m["wood_l"], tops=None)
    S.box(0.46, 0.52, 1.54, 1.48, zc + 24 * s, zc + 34 * s, m["metal"], sw=3.5)
    sx, sy = S.P(1, 1, zc + 34 * s)
    S.glow(sx, sy - 16, 54, C["shard"] if m["glow"] == C["amber"] else GLOOM["spore"], 0.55)
    col = C["shard"] if m["glow"] == C["amber"] else GLOOM["spore"]
    for dx, h, w, tl in ((-24, 40, 10, -5), (0, 54, 12, 0), (24, 36, 9, 5)) if t >= 3 else ((-16, 34, 10, -3), (16, 30, 9, 3)):
        crystal(S, sx + dx, sy + 6, h, w, col, tl)
    c.ov("sparkle", 1, 1, zc + 60, color=col)


# =========================================================== MILITARI
def d_barracks(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 7)
    h = 60 * s
    S.box(0.35, 0.5, 2.65, 2.5, 7, 7 + h, m["wall"])
    door(c, "L", 0.35, 0.5, 2.65, 2.5, 7, 0.38, 0.62, 42)
    windows(c, "L", (0.35, 0.5, 2.65, 2.5), 7, h, 2, 20, gap=0.1)
    # emblema spade incrociate sulla faccia destra
    p = S.face_point("R", 0.35, 0.5, 2.65, 2.5, 7, 0.5, h * 0.55)
    S.circle(p[0], p[1], 22, m["banner"], sw=4)
    S.line((p[0] - 12, p[1] - 12), (p[0] + 12, p[1] + 12), "#FFF3D6", 4.5)
    S.line((p[0] + 12, p[1] - 12), (p[0] - 12, p[1] + 12), "#FFF3D6", 4.5)
    S.hip_roof(0.35, 0.5, 2.65, 2.5, 7 + h, 46 * s, m["roof"], ridge="x")
    pennant_pole(c, 2.75, 2.65, 7, 96)
    pennant_pole(c, 0.3, 2.65, 7, 96) if t >= 2 else None
    if t >= 3:
        S.box(0.08, 0.5, 0.58, 1.0, 7, 7 + h + 30, m["wall"], sw=3.5)
        S.pyramid(0.08, 0.5, 0.58, 1.0, 7 + h + 30, 30, m["roof"], 0.08)
    # bersaglio di paglia
    sx, sy = S.P(1.5, 2.9, 7)
    S.line((sx, sy), (sx, sy - 34), INK, 8)
    S.circle(sx, sy - 40, 14, "#E8C86A", sw=3.5)
    S.circle(sx, sy - 40, 7, m["banner"], sw=3)


def tent(c, cx, cy, r, h, color, flap=None):
    S = c.S
    S.cone(cx, cy, r, 6, h, color, sw=3.5)
    sx, sy = S.P(cx, cy, 6)
    S.poly([(sx - 10, sy + r * HH - 2), (sx, sy - h * 0.45), (sx + 10, sy + r * HH - 2)], flap or darken(color, 0.4), sw=3)
    S.circle(sx, sy - h, 4, INK, stroke=None)


def d_army_camp(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 6, mix(C["grass_m"], C["earth_l"], 0.35))
    tents = [(0.9, 0.9, 0.62), (3.1, 0.9, 0.62), (0.9, 3.1, 0.62), (3.1, 3.1, 0.62), (2.0, 0.55, 0.5), (3.5, 2.0, 0.5), (0.5, 2.0, 0.5), (2.0, 3.55, 0.5)]
    n = {1: 2, 2: 3, 3: 4, 4: 6, 5: 8}[t]
    order = [0, 1, 2, 3, 4, 5, 6, 7][:n]
    # tende dietro
    cols = [m["banner"], m["roof"], m["wall"], m["banner"], m["roof"], m["wall"], m["banner"], m["roof"]]
    ordered = sorted(order, key=lambda i: tents[i][0] + tents[i][1])
    # falo' centrale
    fx, fy = S.P(2, 2, 6)
    for a in range(0, 360, 60):
        S.ellipse(fx + math.cos(math.radians(a)) * 24, fy + math.sin(math.radians(a)) * 12, 9, 6, m["stone"], sw=3)
    S.poly([(fx - 22, fy + 2), (fx + 22, fy - 6), (fx + 22, fy + 2), (fx - 22, fy + 10)], m["wood"], sw=3)
    c.ov("fire", 2, 2, 12)
    c.ov("smoke", 2, 2, 60)
    for i in ordered:
        x, y, r = tents[i]
        tent(c, x, y, r, (62 + 6 * t) * 1.0, cols[i])
    if t >= 3:
        pennant_pole(c, 3.6, 3.6, 6, 90)
    # scatole/casse
    S.box(2.9, 1.6, 3.35, 2.05, 6, 24, m["wood_l"], sw=3.5)
    S.box(1.2, 2.9, 1.65, 3.35, 6, 20, m["wood_l"], sw=3.5)


def d_laboratory(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 7)
    h = 52 * s
    S.box(0.5, 0.5, 3.0, 3.0, 7, 7 + h, m["wall"])
    windows(c, "L", (0.5, 0.5, 3.0, 3.0), 7, h, 3, 22)
    door(c, "R", 0.5, 0.5, 3.0, 3.0, 7, 0.4, 0.6, 40)
    # cupola
    cx, cy = S.P(1.75, 1.75, 7 + h)
    S.ellipse(cx, cy + 4, 2.0 * HW * 0.78, 2.0 * HH * 0.78, m["metal"], sw=3.5)
    r = 52 + 4 * t
    S.circle(cx, cy - 14, r, S.radial(lighten(m["roof"], 0.4), m["roof"], 1, 1), sw=4.5)
    S.ellipse(cx - r * 0.35, cy - 14 - r * 0.45, r * 0.22, r * 0.12, "#FFFFFF", stroke=None, op=0.5)
    # oblo
    S.circle(cx + 6, cy - 4, 20, "#DFF8FF" if t % 2 else "#FFE9A8", sw=4)
    S.circle(cx + 6, cy - 4, 11, m["glow"], stroke=None, op=0.8)
    # telescopio
    poly_tube(S, (cx - 12, cy - 14 - r + 8), (cx - 52, cy - 14 - r - 26), 8, 5, m["metal"], 3.5)
    # ala laterale con ciminiera e provette
    S.box(2.9, 1.5, 3.7, 2.7, 7, 7 + 40 * s, lighten(m["wall"], 0.05))
    S.box(3.3, 1.6, 3.6, 1.9, 7 + 40 * s, 7 + 100 * s, "#6B6B7C", sw=3.5)
    c.ov("smoke", 3.45, 1.75, 7 + 100 * s)
    for i, col in enumerate((C["sap"], C["shard"], C["coral"])):
        fx, fy = S.P(0.3 + i * 0.35, 3.45, 7)
        S.poly([(fx - 7, fy - 20), (fx + 7, fy - 20), (fx + 12, fy), (fx - 12, fy)], "#DFF8FF", sw=3)
        S.poly([(fx - 9, fy - 8), (fx + 9, fy - 8), (fx + 11, fy - 1), (fx - 11, fy - 1)], col, stroke=None)
    c.ov("bubbles", 1.75, 1.75, 7 + h + 70, color=C["glimmer"])


def d_spell_forge(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 7, m["stone"])
    S.cylinder(1.5, 1.5, 1.2, 7, 17, m["stone_l"])
    sx, sy = S.P(1.5, 1.5, 17)
    col = m["crystal"] if t < 5 else C["shard"]
    for k, a in enumerate((0, 0.5)):
        S.ellipse(sx, sy, 1.0 * HW * (1 - a * 0.4), 1.0 * HH * (1 - a * 0.4), "none", stroke=lighten(col, 0.3), sw=3, op=0.9)
    # pilastri con cristalli
    for (px, py) in ((0.35, 0.75), (2.55, 0.75), (1.5, 2.65)):
        S.box(px - 0.15, py - 0.15, px + 0.15, py + 0.15, 17, 17 + 50 * s, m["wall"], sw=3.5)
        p = S.P(px, py, 17 + 50 * s)
        crystal(S, p[0], p[1], 26, 7, col)
    # calderone
    S.cylinder(1.5, 1.5, 0.5, 17, 17 + 34 * s, darken(m["metal"], 0.35))
    S.ellipse(sx, sy - 34 * s, 0.5 * HW, 0.5 * HH, C["sap"] if t % 2 else col, sw=3.5)
    S.ellipse(sx - 6, sy - 36 * s, 14, 5, "#FFFFFF", stroke=None, op=0.5)
    # orb fluttuante
    S.glow(sx, sy - 120 * s, 60, col, 0.6)
    S.sphere(sx, sy - 120 * s, 16 + t, col)
    c.ov("orb", 1.5, 1.5, 17 + 110 * s, color=col)
    c.ov("sparkle", 1.5, 1.5, 17 + 40 * s, color=col)


def d_clan_hall(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 7)
    # gradini
    S.box(1.4, 3.0, 2.6, 3.5, 7, 15, m["stone_l"], sw=3.5)
    h = 66 * s
    S.box(0.4, 0.9, 3.6, 3.0, 7, 7 + h, m["wall"])
    door(c, "L", 0.4, 0.9, 3.6, 3.0, 7, 0.44, 0.56, 46)
    windows(c, "L", (0.4, 0.9, 3.6, 3.0), 7, h, 2, 22, gap=0.07)
    S.hip_roof(0.4, 0.9, 3.6, 3.0, 7 + h, 52 * s, m["roof"], ridge="x")
    # stemma sul timpano (faccia destra)
    p = S.face_point("R", 0.4, 0.9, 3.6, 3.0, 7, 0.5, h * 0.5)
    S.poly([(p[0] - 20, p[1] - 22), (p[0] + 20, p[1] - 22), (p[0] + 20, p[1] + 4), (p[0], p[1] + 28), (p[0] - 20, p[1] + 4)], m["banner"], sw=4)
    S.cog(p[0], p[1] - 4, 10, "#FFF3D6", 6, 2.5)
    pennant_pole(c, 0.3, 3.2, 7, 110)
    pennant_pole(c, 3.7, 0.7, 7, 110)
    if t >= 3:
        S.box(3.0, 0.2, 3.7, 0.9, 7, 7 + h + 40, m["wall"], sw=3.5)
        S.pyramid(3.0, 0.2, 3.7, 0.9, 7 + h + 40, 34, m["roof"], 0.08)
    for (tx, ty) in ((1.2, 3.25), (2.8, 3.25)):
        p = S.P(tx, ty, 7)
        S.line(p, (p[0], p[1] - 30), INK, 7)
        S.circle(p[0], p[1] - 36, 7, C["amber"], sw=3)
        c.ov("fire", tx, ty, 7 + 38, small=True)


# ============================================================= DIFESE

def flair(c, n=None):
    """Dettagli per tier (rende ogni 2 livelli visibilmente diverso): stendardo, torce, pilastri, cristalli."""
    S, m, t = c.S, c.m, c.tier
    n = n or c.N
    e = 0.22
    if t >= 2:
        pennant_pole(c, e, n - e, 6, 62 + 6 * n)
    if t >= 3:
        for (x, y) in ((n - e, e), (n - e, n - e)):
            p = S.P(x, y, 6)
            S.line(p, (p[0], p[1] - 34), INK, 8)
            S.line(p, (p[0], p[1] - 34), m["wood_l"], 4)
            lantern_glow(c, p[0], p[1] - 40, 7)
    if t >= 4:
        for (x, y) in ((e, n - e), (n - e, e)):
            S.box(x - 0.13, y - 0.13, x + 0.13, y + 0.13, 6, 6 + 46, m["wall"], sw=3.5)
            S.box(x - 0.17, y - 0.17, x + 0.17, y + 0.17, 6 + 46, 6 + 56, m["metal"], sw=3.5)
            if t >= 5:
                p = S.P(x, y, 6 + 56)
                crystal(S, p[0], p[1], 30, 8, m["crystal"])
                S.glow(p[0], p[1] - 14, 34, m["crystal"], 0.5)

def d_boltpost(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 6, m["stone"])
    h = 78 * s
    tower_cyl(c, 1, 1, 0.86, 6, h, m["wall"], 1, m["metal"])
    zt = 6 + h
    # parapetto
    S.cylinder(1, 1, 0.97, zt, zt + 18, m["metal"], sw=3.5)
    px, py = S.P(1, 1, zt + 16)
    S.ellipse(px, py, 0.7 * HW, 0.7 * HH, darken(m["stone"], 0.2), sw=3)
    # balestra (arco) + dardo
    bow = f"M {px - 50:.1f},{py - 30:.1f} Q {px:.1f},{py - 78:.1f} {px + 50:.1f},{py - 30:.1f}"
    S.path(bow, "none", sw=13)
    S.path(bow, "none", stroke=m["wood_l"] if t < 3 else m["metal"], sw=7)
    S.line((px - 50, py - 30), (px + 50, py - 30), INK, 4)
    poly_tube(S, (px - 14, py - 2), (px + 14, py - 52), 9, 6, m["wood"], 3.5)
    S.poly([(px + 8, py - 46), (px + 22, py - 46), (px + 24, py - 70), (px + 15, py - 82), (px + 6, py - 70)], m["metal"], sw=3.5)
    if t >= 3:
        S.circle(px - 50, py - 30, 7, m["metal"], sw=3)
        S.circle(px + 50, py - 30, 7, m["metal"], sw=3)
    if t >= 5:
        crystal(S, px - 4, py - 74, 22, 7, m["crystal"])
    c.ov("muzzle", 1.0, 1.0, zt + 46)
    flair(c)


def d_lobber(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 6, m["stone"])
    h = 34 * s
    S.cylinder(1.5, 1.5, 1.05, 6, 6 + h, m["wall"])
    sx, sy = S.P(1.5, 1.5, 6 + h)
    S.ellipse(sx, sy, 0.8 * CW / 2 * 1.0, 0.8 * CH / 2 * 1.0, darken(m["stone"], 0.25), sw=3.5)
    # sacchi di sabbia
    for a in range(0, 360, 36):
        x = sx + math.cos(math.radians(a)) * 0.98 * HW * 0.95
        y = sy + math.sin(math.radians(a)) * 0.98 * HH * 0.95 - 4
        if math.sin(math.radians(a)) > -0.3:
            S.ellipse(x, y + 4, 13, 9, "#E3C98B", sw=3)
    # mortaio: base + tubo inclinato
    S.circle(sx, sy - 10, 26, m["metal"], sw=4)
    p1 = (sx + 56, sy - 112 - 6 * t)
    poly_tube(S, (sx, sy - 12), p1, 24, 31, mix(m["metal"], "#3A3040", 0.5), 4)
    S.ellipse(p1[0], p1[1], 33, 12, "#241A2C", sw=4)
    S.line((sx - 8, sy - 12 - 0), (p1[0] - 12, p1[1] + 18), lighten(m["metal"], 0.5), 3, 0.6)
    for k in (0.35, 0.7):
        q = (sx + (p1[0] - sx) * k, sy - 12 + (p1[1] - sy + 12) * k)
        S.ellipse(q[0], q[1], 27 + 3 * k, 8, m["metal"], sw=3, op=1)
    c.ov("muzzle", 1.5, 1.5, 6 + h + 90 + 6 * t, shift=[56, 0])
    flair(c)


def d_skyspear(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.05, 6, m["stone"])
    h = 86 * s
    tower_cyl(c, 1, 1, 0.72, 6, h, m["wall"], 1, m["metal"])
    zt = 6 + h
    S.cylinder(1, 1, 0.82, zt, zt + 12, m["metal"], sw=3.5)
    px, py = S.P(1, 1, zt + 12)
    # rotaie + lancia puntata in alto
    poly_tube(S, (px - 6, py), (px + 30, py - 112), 8, 8, m["wood"], 3.5)
    poly_tube(S, (px + 10, py - 4), (px + 46, py - 108), 6, 6, m["wood_l"], 3)
    S.poly([(px + 30 - 14, py - 100), (px + 30 + 14, py - 100), (px + 34, py - 156), (px + 30 - 8, py - 140)],
           S.grad(lighten(m["metal"], 0.5), m["metal"]), sw=4)
    # alette
    S.poly([(px + 18, py - 64), (px - 6, py - 76), (px + 10, py - 50)], m["banner"], sw=3.5)
    S.poly([(px + 38, py - 60), (px + 62, py - 74), (px + 46, py - 46)], m["banner"], sw=3.5)
    c.ov("muzzle", 1, 1, zt + 100 + 14, shift=[32, 0])
    flair(c)


def d_arc_coil(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.05, 6, m["stone"])
    S.cylinder(1, 1, 0.85, 6, 24, m["stone_l"])
    sx, sy = S.P(1, 1, 24)
    h = 84 * s
    for i in range(5):
        r = 0.66 - i * 0.07
        z0 = 24 + i * h / 5
        S.cylinder(1, 1, r, z0, z0 + h / 5 + 4, mix("#D9733A", m["metal"], 0.5 if t > 1 else 0.0), sw=3.5)
    # fasce
    zt = 24 + h + 4
    S.sphere(sx, sy - zt + 6, 26 + t, C["glimmer"] if m["glow"] == C["amber"] else GLOOM["glow"])
    S.glow(sx, sy - zt + 6, 76, C["glimmer"] if m["glow"] == C["amber"] else GLOOM["glow"], 0.5)
    for dx in (-34, 34):
        S.line((sx + dx, sy - 6), (sx + dx * 0.6, sy - zt + 6), INK, 7)
        S.line((sx + dx, sy - 6), (sx + dx * 0.6, sy - zt + 6), m["metal"], 3.5)
    c.ov("arc", 1, 1, zt - 4, color=C["glimmer"] if m["glow"] == C["amber"] else GLOOM["glow"])
    flair(c)


def d_ballista(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 6, m["stone"])
    S.box(0.45, 0.45, 2.55, 2.55, 6, 6 + 26 * s, m["wall"] if t > 1 else m["wood_l"])
    zt = 6 + 26 * s
    cx, cy = S.P(1.5, 1.5, zt)
    # ruote
    S.circle(cx - 66, cy + 30, 22, m["wood"], sw=4)
    S.circle(cx - 66, cy + 30, 8, m["metal"], sw=3)
    # arco gigante
    bow = f"M {cx - 70:.1f},{cy - 74:.1f} Q {cx - 14:.1f},{cy - 28:.1f} {cx + 54:.1f},{cy - 94:.1f}"
    S.path(bow, "none", sw=16)
    S.path(bow, "none", stroke=m["wood_l"] if t < 4 else m["metal"], sw=9)
    S.line((cx - 70, cy - 74), (cx + 54, cy - 94), INK, 4)
    # guida + dardo gigante
    poly_tube(S, (cx - 40, cy - 6), (cx + 80, cy - 128), 11, 8, m["wood"], 4)
    S.poly([(cx + 70, cy - 112), (cx + 94, cy - 136), (cx + 118, cy - 168), (cx + 84, cy - 150), (cx + 66, cy - 130)], m["metal"], sw=4)
    S.circle(cx - 40, cy - 6, 10, m["metal"], sw=3.5)
    if t >= 4:
        crystal(S, cx + 10, cy - 34, 22, 7, m["crystal"])
    c.ov("muzzle", 1.5, 1.5, zt + 150, shift=[70, 0])
    flair(c)


def d_thumper(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 6, m["stone"])
    h = 40 * s
    S.box(0.5, 0.5, 2.5, 2.5, 6, 6 + h, m["wall"] if t > 1 else m["stone_l"])
    zt = 6 + h
    # incudine
    S.box(0.9, 1.7, 1.9, 2.4, zt, zt + 16, "#4A4458", sw=3.5)
    # montante + leva + martello
    S.box(2.0, 0.6, 2.4, 1.0, zt, zt + 96 * s, m["wood"], sw=3.5)
    a = S.P(2.2, 0.8, zt + 88 * s)
    b = (a[0] - 118, a[1] + 28)
    S.line(a, b, INK, 20)
    S.line(a, b, m["wood_l"], 12)
    S.circle(a[0], a[1], 10, m["metal"], sw=3.5)
    # testa del martello
    hx, hy = b
    S.box(0.1, 0.1, 0.1, 0.1, 0, 0, "#000", detail=False) if False else None
    pts = [(hx - 44, hy - 26), (hx + 8, hy - 44), (hx + 48, hy - 20), (hx + 2, hy + 6)]
    S.poly(pts, S.grad(lighten(m["metal"], 0.3), darken(m["metal"], 0.25)), sw=4.5)
    S.poly([(hx - 44, hy - 26), (hx + 2, hy + 6), (hx + 2, hy + 30), (hx - 44, hy + 0)], darken(m["metal"], 0.3), sw=4.5)
    if t >= 3:
        S.circle(hx - 20, hy - 14, 6, lighten(m["metal"], 0.5), sw=2.5)
    c.ov("impact", 1.4, 2.05, zt + 20)
    flair(c)


def d_frost_spire(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.05, 6, mix(m["stone"], "#DDF0FF", 0.5))
    ice = "#7FD2FF" if m["glow"] == C["amber"] else "#8D8CEB"
    sx, sy = S.P(1, 1, 6)
    S.glow(sx, sy - 50, 90, ice, 0.4)
    S.ellipse(sx, sy + 4, 56, 26, "#F2FAFF", sw=3.5)
    for dx, dy, h, w, tl in ((-46, 8, 60, 13, -5), (46, 10, 52, 12, 6), (-20, 24, 40, 11, -3), (24, 24, 34, 10, 3)):
        crystal(S, sx + dx, sy + dy, h * s * 0.9, w, ice, tl)
    crystal(S, sx, sy + 8, (120 + 8 * t) * s, 22, ice, 0)
    c.ov("sparkle", 1, 1, 90, color="#E9F8FF")
    flair(c)


def d_cinder_spout(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.05, 6, "#5B5468")
    h = 44 * s
    S.box(0.2, 0.25, 1.8, 1.75, 6, 6 + h, "#575069", tops=(lighten("#575069", 0.25), "#575069", darken("#575069", 0.3)))
    # bocca fornace
    p = S.face_point("L", 0.2, 0.25, 1.8, 1.75, 6, 0.5, h * 0.4)
    S.circle(p[0], p[1], 22, "#1E1626", sw=4)
    S.circle(p[0], p[1] + 4, 14, "#FFB62E" if m["glow"] == C["amber"] else GLOOM["glow"], stroke=None, op=0.95)
    S.circle(p[0], p[1] + 6, 8, "#FFF3A8", stroke=None)
    # ciminiera + ugello
    S.box(1.35, 0.3, 1.7, 0.65, 6 + h, 6 + h + 50 * s, "#6B6B7C", sw=3.5)
    c.ov("smoke", 1.52, 0.47, 6 + h + 50 * s)
    top = S.P(0.9, 1.0, 6 + h)
    tip = (top[0] + 70, top[1] - 52)
    poly_tube(S, top, tip, 20, 13, m["metal"], 4)
    S.circle(tip[0], tip[1], 14, "#241A2C", sw=3.5)
    S.circle(tip[0], tip[1], 8, "#FF8A2A" if m["glow"] == C["amber"] else GLOOM["glow"], stroke=None)
    for k in (0.3, 0.65):
        q = (top[0] + (tip[0] - top[0]) * k, top[1] + (tip[1] - top[1]) * k)
        S.circle(q[0], q[1], 14, m["metal"], sw=3)
    c.ov("muzzle", 0.9, 1.0, 6 + h + 52, shift=[70, 0], color="fire")
    flair(c)


def d_storm_pylon(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 6, m["stone"])
    S.cylinder(1.5, 1.5, 0.8, 6, 22, m["stone_l"])
    sx, sy = S.P(1.5, 1.5, 22)
    h = 150 * s
    top = (sx, sy - h)
    for dx in (-72, 72):
        S.line((sx + dx, sy + 4), top, INK, 15)
        S.line((sx + dx, sy + 4), top, m["metal"], 8)
    S.line((sx, sy + 12), top, INK, 12)
    S.line((sx, sy + 12), top, lighten(m["metal"], 0.2), 6)
    for i in range(1, 4):
        w = 72 * (1 - i / 4)
        y = sy - h * i / 4 + 6
        S.line((sx - w, y), (sx + w, y), INK, 4)
    col = C["glimmer"] if m["glow"] == C["amber"] else GLOOM["glow"]
    S.glow(top[0], top[1] - 18, 100, col, 0.5)
    S.ellipse(top[0], top[1] - 18, 44, 18, "none", stroke=m["metal"], sw=7)
    S.sphere(top[0], top[1] - 18, 20 + t, col)
    S.poly([(top[0] - 10, top[1] + 4), (top[0] + 10, top[1] + 4), (top[0], top[1] - 40)], m["metal"], sw=3.5)
    c.ov("arc", 1.5, 1.5, h + 22 + 20, color=col, big=True)
    flair(c)


# ============================================================ TRAPPOLE
def d_bomb_trap(c):
    S, m, t = c.S, c.m, c.tier
    sx, sy = S.P(0.5, 0.5, 0)
    S.ellipse(sx, sy, 44, 22, mix(C["earth_l"], C["earth_d"], 0.3), sw=3.5)
    S.circle(sx, sy - 10, 24 + t * 1.5, "#3A3446", sw=4)
    S.ellipse(sx - 8, sy - 20, 8, 5, "#FFFFFF", stroke=None, op=0.4)
    S.line((sx + 8, sy - 30), (sx + 22, sy - 44), INK, 4)
    S.circle(sx + 24, sy - 46, 5, "#FFB62E", sw=2.5)
    if t >= 3:
        S.circle(sx, sy - 10, 8, "#E8604C", sw=3)


def d_spring_pad(c):
    S, m, t = c.S, c.m, c.tier
    sx, sy = S.P(0.5, 0.5, 0)
    S.ellipse(sx, sy, 44, 22, "#6E6788", sw=3.5)
    for i in range(4):
        S.ellipse(sx, sy - 6 - i * 7, 22 - i * 1.5, 8, "none", stroke=m["metal"], sw=5)
    S.ellipse(sx, sy - 34, 32, 14, "#E8604C" if t < 4 else "#F2B93B", sw=4)
    S.ellipse(sx - 8, sy - 36, 10, 4, "#FFFFFF", stroke=None, op=0.5)


def d_snare_trap(c):
    S, m, t = c.S, c.m, c.tier
    sx, sy = S.P(1, 1, 0)
    S.ellipse(sx, sy, 90, 45, mix(C["earth_l"], C["earth_d"], 0.25), sw=3.5)
    for r in (70, 48, 26):
        S.ellipse(sx, sy, r, r / 2, "none", stroke="#E8D3A5", sw=5)
    for a in range(0, 360, 45):
        S.line((sx, sy), (sx + math.cos(math.radians(a)) * 70, sy + math.sin(math.radians(a)) * 35), "#E8D3A5", 3)
    for a in range(0, 360, 90):
        S.circle(sx + math.cos(math.radians(a + 45)) * 62, sy + math.sin(math.radians(a + 45)) * 31 - 6, 8, m["metal"], sw=3)


def d_air_mine(c):
    S, m, t = c.S, c.m, c.tier
    sx, sy = S.P(0.5, 0.5, 0)
    S.ellipse(sx, sy, 38, 19, "#6E6788", sw=3.5)
    S.line((sx, sy), (sx, sy - 58), INK, 8)
    S.line((sx, sy), (sx, sy - 58), m["metal"], 4)
    S.circle(sx, sy - 74, 22, S.radial(lighten(C["glimmer"], 0.5), C["glimmer"], 1, 1), sw=4)
    for a in range(0, 360, 45):
        dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
        S.poly([(sx + dx * 20 - dy * 4, sy - 74 + dy * 20 + dx * 4), (sx + dx * 34, sy - 74 + dy * 34), (sx + dx * 20 + dy * 4, sy - 74 + dy * 20 - dx * 4)], m["metal"], sw=3)


# ============================================================ OSTACOLI
def d_sapling(c):
    S = c.S
    sx, sy = S.P(0.5, 0.5, 0)
    S.ellipse(sx, sy + 4, 30, 14, C["grass_d"], stroke=None, op=0.5)
    S.poly([(sx - 8, sy), (sx + 8, sy), (sx + 5, sy - 44), (sx - 5, sy - 44)], C["wood_d"], sw=3.5)
    for dx, dy, r, col in ((-24, -52, 28, C["grass_m"]), (22, -54, 26, C["grass_m"]), (0, -76, 32, C["grass_l"]), (-4, -50, 30, C["grass_l"])):
        S.circle(sx + dx, sy + dy, r, col, sw=4)
    S.ellipse(sx - 10, sy - 84, 12, 7, "#FFFFFF", stroke=None, op=0.35)


def d_boulder(c):
    S = c.S
    sx, sy = S.P(1, 1, 0)
    S.ellipse(sx + 6, sy + 6, 70, 28, "#3A2358", stroke=None, op=0.25)
    S.path(f"M {sx - 64:.1f},{sy + 6:.1f} Q {sx - 70:.1f},{sy - 44:.1f} {sx - 22:.1f},{sy - 62:.1f} Q {sx + 22:.1f},{sy - 74:.1f} {sx + 56:.1f},{sy - 36:.1f} Q {sx + 74:.1f},{sy - 4:.1f} {sx + 50:.1f},{sy + 14:.1f} Q {sx:.1f},{sy + 26:.1f} {sx - 64:.1f},{sy + 6:.1f} Z",
           S.grad(C["stone_l"], C["stone_d"]), sw=4.5)
    S.path(f"M {sx - 30:.1f},{sy - 40:.1f} Q {sx - 6:.1f},{sy - 54:.1f} {sx + 20:.1f},{sy - 46:.1f}", "none", stroke="#FFFFFF", sw=4, op=0.45)
    S.circle(sx + 26, sy - 14, 14, C["grass_m"], sw=3.5)
    S.circle(sx + 38, sy - 22, 9, C["grass_l"], sw=3)


def d_glowshroom(c):
    S = c.S
    sx, sy = S.P(1, 1, 0)
    for dx, dy, r, col in ((-30, 4, 30, "#E8419A"), (26, 10, 24, "#B14BE8"), (0, -8, 38, "#FF7BC0")):
        S.poly([(sx + dx - 9, sy + dy), (sx + dx + 9, sy + dy), (sx + dx + 6, sy + dy - r), (sx + dx - 6, sy + dy - r)], "#F3E6D6", sw=3.5)
        S.path(f"M {sx + dx - r * 1.2:.1f},{sy + dy - r:.1f} Q {sx + dx:.1f},{sy + dy - r * 2.4:.1f} {sx + dx + r * 1.2:.1f},{sy + dy - r:.1f} Z", col, sw=4)
        for k in (-0.5, 0.2, 0.7):
            S.circle(sx + dx + k * r * 0.8, sy + dy - r * 1.35 + abs(k) * 4, 4.5, "#FFF3D6", stroke=None, op=0.9)
    S.glow(sx, sy - 30, 60, "#FF7BC0", 0.35)


def d_moon_crystal(c):
    S = c.S
    sx, sy = S.P(1, 1, 0)
    S.glow(sx, sy - 40, 80, C["glimmer"], 0.45)
    S.ellipse(sx, sy + 6, 60, 24, "#6E6788", sw=3.5)
    for dx, h, w, tl, col in ((-34, 70, 14, -6, "#8CE8F5"), (34, 56, 13, 6, "#7FD2FF"), (0, 112, 20, 0, C["glimmer"]), (-12, 48, 12, -3, "#B8F3FA"), (18, 40, 11, 3, "#8CE8F5")):
        crystal(S, sx + dx, sy + 10 - abs(dx) * 0.15, h, w, col, tl)
    c.ov("sparkle", 1, 1, 90, color="#E9FFFF")


# ========================================================== CANTIERE
def d_construction(c):
    """Impalcatura generica per footprint N (cantiere): terra scavata, pali, assi, argano."""
    S, m, N = c.S, c.m, c.N
    S.ground_diamond(0.05, 0.05, N - 0.05, N - 0.05, mix(C["earth_l"], C["earth_d"], 0.35), stroke=INK, sw=4)
    S.ground_diamond(0.35, 0.35, N - 0.35, N - 0.35, mix(C["earth_d"], "#3A2358", 0.25), stroke=None)
    h = 34 + 26 * N
    posts = [(0.2, 0.2), (N - 0.2, 0.2), (0.2, N - 0.2), (N - 0.2, N - 0.2)]
    posts_b = [p for p in posts if p[0] + p[1] < N]
    posts_f = [p for p in posts if p[0] + p[1] >= N]

    def post(p):
        a, b = S.P(p[0], p[1], 0), S.P(p[0], p[1], h)
        S.line(a, b, INK, 11)
        S.line(a, b, C["wood_l"], 6)
    for p in posts_b:
        post(p)
    # assi trasversali dietro
    for z in (h * 0.4, h * 0.8):
        S.line(S.P(0.2, 0.2, z), S.P(N - 0.2, 0.2, z), INK, 9)
        S.line(S.P(0.2, 0.2, z), S.P(N - 0.2, 0.2, z), C["wood_d"], 5)
        S.line(S.P(0.2, 0.2, z), S.P(0.2, N - 0.2, z), INK, 9)
        S.line(S.P(0.2, 0.2, z), S.P(0.2, N - 0.2, z), C["wood_d"], 5)
    # mattoni/legna accatastati
    S.box(N * 0.35, N * 0.35, N * 0.35 + 0.5, N * 0.35 + 0.5, 0, 22, C["wood_l"], sw=3.5)
    S.box(N * 0.55, N * 0.4, N * 0.55 + 0.45, N * 0.4 + 0.45, 0, 16, "#C98A3C", sw=3.5)
    # argano con secchio
    top = S.P(N / 2, N / 2, h + 20)
    S.line(S.P(N / 2, N / 2, 0), top, INK, 11)
    S.line(S.P(N / 2, N / 2, 0), top, C["wood_d"], 6)
    S.line(top, (top[0] + 40, top[1] + 10), INK, 7)
    S.line((top[0] + 40, top[1] + 10), (top[0] + 40, top[1] + 52), INK, 3)
    S.poly([(top[0] + 30, top[1] + 52), (top[0] + 50, top[1] + 52), (top[0] + 46, top[1] + 70), (top[0] + 34, top[1] + 70)], C["wood_l"], sw=3.5)
    for p in posts_f:
        post(p)
    for z in (h * 0.4, h * 0.8):
        S.line(S.P(N - 0.2, 0.2, z), S.P(N - 0.2, N - 0.2, z), INK, 9)
        S.line(S.P(N - 0.2, 0.2, z), S.P(N - 0.2, N - 0.2, z), C["wood_d"], 5)
        S.line(S.P(0.2, N - 0.2, z), S.P(N - 0.2, N - 0.2, z), INK, 9)
        S.line(S.P(0.2, N - 0.2, z), S.P(N - 0.2, N - 0.2, z), C["wood_d"], 5)
    # bandierine di cantiere
    for p in posts:
        q = S.P(p[0], p[1], h)
        S.poly([(q[0], q[1]), (q[0] + 22, q[1] + 8), (q[0], q[1] + 16)], "#F0742A", sw=3)
    c.ov("dust", N / 2, N / 2, 30)


# ============================================================== REGISTRO
# id -> (footprint, margine alto px, funzione, categoria)
DESIGNS = {
    "lantern_hall": (4, 560, d_hall, "core"),
    "cog_mine": (2, 300, d_cog_mine, "economy"), "sap_well": (2, 290, d_sap_well, "economy"),
    "shard_drill": (2, 330, d_shard_drill, "economy"),
    "cog_vault": (3, 330, d_cog_vault, "storage"), "sap_cistern": (3, 300, d_sap_cistern, "storage"),
    "shard_crate": (2, 260, d_shard_crate, "storage"),
    "barracks": (3, 330, d_barracks, "military"), "army_camp": (4, 300, d_army_camp, "military"),
    "laboratory": (4, 420, d_laboratory, "military"), "spell_forge": (3, 340, d_spell_forge, "military"),
    "clan_hall": (4, 380, d_clan_hall, "social"),
    "boltpost": (2, 300, d_boltpost, "defense"), "lobber": (3, 320, d_lobber, "defense"),
    "skyspear": (2, 400, d_skyspear, "defense"), "arc_coil": (2, 300, d_arc_coil, "defense"),
    "ballista": (3, 380, d_ballista, "defense"), "thumper": (3, 340, d_thumper, "defense"),
    "frost_spire": (2, 330, d_frost_spire, "defense"), "cinder_spout": (2, 330, d_cinder_spout, "defense"),
    "storm_pylon": (3, 420, d_storm_pylon, "defense"),
    "bomb_trap": (1, 120, d_bomb_trap, "trap"), "spring_pad": (1, 120, d_spring_pad, "trap"),
    "snare_trap": (2, 120, d_snare_trap, "trap"), "air_mine": (1, 160, d_air_mine, "trap"),
    "sapling": (1, 170, d_sapling, "obstacle"), "boulder": (2, 140, d_boulder, "obstacle"),
    "glowshroom": (2, 170, d_glowshroom, "obstacle"), "moon_crystal": (2, 200, d_moon_crystal, "obstacle"),
}
# tier 1..5 per le classi con piu' livelli; trappole: 1 sprite per livello 1..5; ostacoli: un solo tier
SINGLE_TIER = {"sapling", "boulder", "glowshroom", "moon_crystal"}


def render_building(btype, tier, pal):
    N, top, fn, _ = DESIGNS[btype]
    m = materials(tier, pal)
    c = Ctx(N, top, m, tier)
    fn(c)
    img = render(c.S)
    cx, cy = c.ox, c.oy + N * HH
    if btype in SINGLE_TIER or btype.endswith("trap") or btype in ("spring_pad", "air_mine"):
        poly = [(cx - 40 * N, cy + 2), (cx, cy - 14 * N), (cx + 40 * N, cy + 2), (cx, cy + 20 * N)]
    else:
        poly = [(cx, cy - N * HH + 6), (cx + N * HW + 14, cy + 6), (cx, cy + N * HH + 16), (cx - N * HW - 14, cy + 6)]
    sh = soft_shadow(img.size, poly, blur=12, opacity=0.3 if btype not in SINGLE_TIER else 0.22)
    out = Image.alpha_composite(sh, img)
    return out, c


def render_construction(N, pal="player"):
    m = materials(1, pal)
    c = Ctx(N, 80 + 30 * N, m, 1)
    d_construction(c)
    img = render(c.S)
    cx, cy = c.ox, c.oy + N * HH
    sh = soft_shadow(img.size, [(cx, cy - N * HH + 6), (cx + N * HW + 14, cy + 6), (cx, cy + N * HH + 16), (cx - N * HW - 14, cy + 6)], blur=12, opacity=0.3)
    return Image.alpha_composite(sh, img), c


def finalize(img, c):
    trimmed, (l, t) = bbox_trim(img, 6)
    return trimmed, [round(c.ox - l, 1), round(c.oy + c.N * HH - t, 1)]
