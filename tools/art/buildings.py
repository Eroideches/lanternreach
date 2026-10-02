"""Sprite procedurali di edifici, difese, mura, trappole, ostacoli.

Ogni edificio ha 5 tier visivi (livelli 1-2, 3-4, 5-6, 7-8, 9-10) che cambiano materiale e dettagli,
in due palette: 'player' (Lanternari) e 'gloom' (Marea d'Ombra, per i villaggi di campagna).
Le animazioni idle (fumo, bandiere, ingranaggi, scintille) sono *overlay* separati: qui si registrano solo le
ancore (px relativi al centro del rombo di base) in ``overlays``.
"""
import math

from PIL import Image

from common import (CW, CH, HW, HH, INK, PALETTE as C, GLOOM, Scene, render, soft_shadow, bbox_trim,
                    lighten, darken, mix, faces)

TIERS = 5


def tier_of(level, max_level):
    """Tier visivo 1..5 dal livello (10 livelli -> ogni 2; 5 livelli -> 1:1; 6/8 livelli ripartiti)."""
    return min(TIERS, 1 + (level - 1) * TIERS // max_level)


# ------------------------------------------------------------- materiali
def materials(tier, pal):
    t = tier
    if pal == "player":
        walls = ["#DDA26A", "#D9D3E8", "#F4E4C1", "#93A9CF", "#F6F0E6"]
        roofs = ["#E3C060", "#E8604C", "#3EA7C9", "#4D66BA", "#A678FF"]
        metals = ["#B97E48", "#C98A3C", "#E07A3A", "#F2B93B", "#FFD764"]
        return dict(wall=walls[t - 1], roof=roofs[t - 1], metal=metals[t - 1], wood=C["wood_d"], wood_l=C["wood_l"],
                    stone=C["stone_m"], stone_l=C["stone_l"], plinth=mix(C["stone_m"], C["earth_l"], 0.25),
                    glow=C["amber"], banner=[C["coral"], C["teal"], C["coral"], C["teal"], C["shard"]][t - 1],
                    crystal=C["glimmer"], tier=t)
    k = (t - 1) / 4
    return dict(wall=mix(GLOOM["mire_l"], GLOOM["void"], k * 0.7), roof=mix(GLOOM["bruise"], GLOOM["void"], k * 0.5),
                metal=mix("#8E7F9E", "#B9A5D0", k), wood=mix("#5B4258", "#3A2C4E", k), wood_l=mix("#7C5B78", "#5B4A78", k),
                stone=mix("#6B5B80", "#403360", k), stone_l=mix("#8A76A0", "#5B4A7C", k),
                plinth=mix("#5B4A70", "#2F2548", k), glow=GLOOM["glow"], banner=GLOOM["glow"],
                crystal=GLOOM["spore"], tier=t)


class Ctx:
    """Contesto di disegno di un edificio."""
    def __init__(self, N, top, m, tier):
        self.N, self.m, self.tier = N, m, tier
        self.w = N * CW + 120
        self.h = N * CH + top + 40
        self.ox = self.w / 2
        self.oy = top
        self.S = Scene(self.w, self.h, self.ox, self.oy)
        self.overlays = []
        self.s = 1 + 0.12 * (tier - 1)            # fattore altezza per tier

    # coordinate in px rispetto al centro del rombo di base (ancora Godot)
    def anchor(self, x, y, z=0.0):
        px, py = self.S.P(x, y, z)
        return [round(px - self.ox, 1), round(py - (self.oy + self.N * HH), 1)]

    def ov(self, kind, x, y, z, **kw):
        d = dict(kind=kind, pos=self.anchor(x, y, z))
        d.update(kw)
        self.overlays.append(d)


def plinth(c, inset=0.05, h=8, color=None, n=None):
    n = n or c.N
    col = color or c.m["plinth"]
    c.S.box(inset, inset, n - inset, n - inset, 0, h, col, tops=(lighten(col, 0.25), col, darken(col, 0.3)))


def pennant_pole(c, x, y, z0, hgt, color=None):
    S = c.S
    a, b = S.P(x, y, z0), S.P(x, y, z0 + hgt)
    S.line(a, b, INK, 6)
    S.line(a, b, c.m["wood_l"], 3)
    S.circle(b[0], b[1], 5, c.m["metal"], sw=3)
    c.ov("flag", x, y, z0 + hgt - 6, color=color or c.m["banner"])


def lantern_glow(c, sx, sy, r=14):
    S = c.S
    S.glow(sx, sy, r * 2.4, c.m["glow"], 0.55)
    S.circle(sx, sy, r, S.radial("#FFFFFF", c.m["glow"], 1, 1), sw=3.5)


def door(c, side, x0, y0, x1, y1, z0, u0, u1, h):
    S = c.S
    S.face_rect(side, x0, y0, x1, y1, z0, z0 + h, u0, u1, 0, h, darken(c.m["wood"], 0.35), sw=3.5)
    mid = (u0 + u1) / 2
    p = S.face_point(side, x0, y0, x1, y1, z0, mid, h * 0.45)
    S.circle(p[0] + 7, p[1], 3, c.m["metal"], sw=2)


def windows(c, side, box, z0, h, n, size=22, color="#FFE8A0", gap=0.18):
    S = c.S
    x0, y0, x1, y1 = box
    span = (1 - 2 * gap)
    for i in range(n):
        u = gap + span * (i + 0.5) / n
        w = 0.055 if (side == "L" and (x1 - x0) > 1.5) or (side == "R" and (y1 - y0) > 1.5) else 0.08
        S.face_rect(side, x0, y0, x1, y1, z0, z0 + h, u - w, u + w, h * 0.35, h * 0.35 + size, color, sw=3)


def crenellations(c, x0, y0, x1, y1, z, base, n=4, h=12):
    S = c.S
    d = 1.0 / (n * 2)
    for i in range(n):
        a = i * 2 * d
        S.box(x0 + (x1 - x0) * a, y1 - 0.09, x0 + (x1 - x0) * (a + d), y1, z, z + h, base, sw=3, detail=False)
        S.box(x1 - 0.09, y0 + (y1 - y0) * a, x1, y0 + (y1 - y0) * (a + d), z, z + h, base, sw=3, detail=False)


def cog_pile(c, x, y, z, n=4):
    S = c.S
    sx, sy = S.P(x, y, z)
    offs = [(-14, 0, 13), (6, -3, 15), (22, 2, 11), (-2, -16, 12), (14, -18, 10)]
    for i in range(n):
        dx, dy, r = offs[i]
        S.cog(sx + dx, sy + dy, r, c.m["metal"] if i % 2 == 0 else lighten(c.m["metal"], 0.25), 7, 2.6, i)


def crystal(S, sx, sy, h, w, base, tilt=0.0, sw=3.0):
    """Cristallo esagonale appuntito (singolo)."""
    tx = sx + tilt
    pts = [(sx - w, sy), (sx - w * 0.7, sy - h * 0.75), (tx, sy - h), (sx + w * 0.7, sy - h * 0.75), (sx + w, sy)]
    S.poly(pts, S.grad(lighten(base, 0.35), darken(base, 0.15)), sw=sw)
    S.poly([(sx - w * 0.2, sy), (sx - w * 0.5, sy - h * 0.7), (tx - 2, sy - h * 0.98), (sx + w * 0.05, sy - h * 0.75)],
           lighten(base, 0.6), stroke=None, op=0.55)


# =================================================== EDIFICIO CENTRALE (4x4)
def d_hall(c):
    S, m, t, s = c.S, c.m, c.tier, c.s
    plinth(c, 0.0, 8, m["stone"])
    # selciato interno a cerchio
    S.ground_diamond(0.35, 0.35, 3.65, 3.65, lighten(m["plinth"], 0.2), stroke=INK, sw=3)
    S.ground_diamond(0.35, 0.35, 3.65, 3.65, "none", stroke=INK, sw=0)
    # torrini d'angolo (da tier 2) - dietro prima
    corners = [(0.2, 0.2), (3.0, 0.2), (0.2, 3.0), (3.0, 3.0)]
    ncorner = {1: 0, 2: 2, 3: 2, 4: 4, 5: 4}[t]
    order = [corners[0], corners[1], corners[2], corners[3]]
    use = {0: [], 2: [order[1], order[2]], 4: order}[ncorner]
    back = [p for p in use if p[0] + p[1] < 3.2]
    front = [p for p in use if p[0] + p[1] >= 3.2]

    def corner_tower(px, py):
        hh = 52 * s
        S.box(px, py, px + 0.8, py + 0.8, 8, 8 + hh, m["wall"])
        S.pyramid(px, py, px + 0.8, py + 0.8, 8 + hh, 34 * s, m["roof"], 0.1)
        sx, sy = S.P(px + 0.4, py + 0.4, 8 + hh + 34 * s)
        S.circle(sx, sy, 5, m["metal"], sw=3)
        S.face_rect("L", px, py, px + 0.8, py + 0.8, 8, 8 + hh, 0.32, 0.68, hh * 0.45, hh * 0.45 + 22, "#FFE8A0", sw=3)
        if t >= 4:
            c.ov("flag", px + 0.4, py + 0.4, 8 + hh + 34 * s, color=m["banner"])

    for p in back:
        corner_tower(*p)
    # corpo centrale: tre piani sovrapposti
    z = 8
    h1 = 78 * s
    S.box(0.9, 0.9, 3.1, 3.1, z, z + h1, m["wall"])
    # portone
    door(c, "L", 0.9, 0.9, 3.1, 3.1, z, 0.40, 0.60, 44)
    windows(c, "L", (0.9, 0.9, 3.1, 3.1), z, h1, 2, 24)
    windows(c, "R", (0.9, 0.9, 3.1, 3.1), z, h1, 2, 24)
    z += h1
    # cornice / balcone
    S.box(0.8, 0.8, 3.2, 3.2, z, z + 10, m["metal"], sw=3.5)
    if t >= 3:
        crenellations(c, 0.8, 0.8, 3.2, 3.2, z + 10, m["metal"], 5, 12)
    z += 10
    h2 = 62 * s
    S.box(1.25, 1.25, 2.75, 2.75, z, z + h2, lighten(m["wall"], 0.05))
    windows(c, "L", (1.25, 1.25, 2.75, 2.75), z, h2, 2, 22)
    z += h2
    S.box(1.15, 1.15, 2.85, 2.85, z, z + 8, m["metal"], sw=3.5)
    z += 8
    # lanterna di vetro (lanterna del faro)
    h3 = 54 * s
    S.box(1.55, 1.55, 2.45, 2.45, z, z + h3, mix(m["glow"], "#FFFFFF", 0.55),
          tops=(lighten(m["glow"], 0.7), mix(m["glow"], "#FFFFFF", 0.35), mix(m["glow"], "#B05020", 0.3)))
    cx, cy = S.P(2.0, 2.0, z + h3 * 0.5)
    S.glow(cx, cy, 90 * (1 + 0.1 * t), m["glow"], 0.45)
    S.circle(cx + 0, cy + 22, 22 + 2 * t, S.radial("#FFFFFF", m["glow"], 1, 1), sw=3.5)
    S.line(S.P(1.55, 2.45, z), S.P(1.55, 2.45, z + h3), INK, 4)
    S.line(S.P(2.0, 2.45, z), S.P(2.0, 2.45, z + h3), INK, 3)
    S.line(S.P(2.45, 2.45, z), S.P(2.45, 2.45, z + h3), INK, 3)
    z += h3
    A = S.pyramid(1.5, 1.5, 2.5, 2.5, z, 46 * s, m["roof"], 0.14)
    S.circle(A[0], A[1] - 4, 7, m["metal"], sw=3.5)
    if t >= 2:
        S.line((A[0], A[1] - 8), (A[0], A[1] - 38), INK, 6)
        S.line((A[0], A[1] - 8), (A[0], A[1] - 38), m["metal"], 3)
        c.ov("flag", 2.0, 2.0, z + 46 * s + 36, color=m["banner"])
    c.ov("beam", 2.0, 2.0, z - h3 * 0.5, r=70)
    c.ov("smoke", 3.2, 1.0, 8 + h1 * 0.6) if t >= 3 else None
    if t == 5:
        for dx, tl in ((-34, -6), (34, 6)):
            crystal(S, A[0] + dx, A[1] + 30, 40, 10, "#A678FF", tl)
    for p in front:
        corner_tower(*p)
    # bandiere sul portone
    pennant_pole(c, 0.55, 3.45, 8, 74 * s)
    pennant_pole(c, 3.45, 0.55, 8, 74 * s) if t >= 2 else None
    # cespugli decorativi
    for (bx, by) in ((0.45, 3.3), (1.6, 3.62), (3.6, 2.5)):
        sx, sy = S.P(bx, by, 8)
        S.ellipse(sx, sy - 6, 14, 10, C["grass_m"], sw=3)
        S.ellipse(sx - 4, sy - 10, 7, 5, C["grass_l"], stroke=None)




def band(c, cx, cy, r, z0, z1, color, sw=3.0):
    c.S.cylinder(cx, cy, r, z0, z1, color, sw=sw, top=False)


def tower_cyl(c, cx, cy, r, z0, h, color, bands=0, band_color=None):
    """Torre cilindrica con fasce metalliche e mattoni accennati."""
    S = c.S
    S.cylinder(cx, cy, r, z0, z0 + h, color)
    sx, sy = S.P(cx, cy, 0)
    rx, ry = r * HW, r * HH
    for i in range(1, 4):  # mattoni accennati (archi chiari)
        yy = sy - z0 - h * i / 4
        S.path(f"M {sx - rx:.1f},{yy:.1f} A {rx:.1f},{ry:.1f} 0 0 0 {sx + rx:.1f},{yy:.1f}", "none", stroke=darken(color, 0.22), sw=2, op=0.55)
    for i in range(bands):
        zb = z0 + h * (i + 1) / (bands + 1)
        band(c, cx, cy, r + 0.025, zb - 5, zb + 5, band_color or c.m["metal"], 3)
