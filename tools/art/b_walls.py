"""Mura 1x1 con auto-connessione: maschera 4 bit (1=+x/SE, 2=+y/SO, 4=-x/NO, 8=-y/NE)."""
from common import INK, lighten
from buildings import Ctx, materials


def wall_sprite(tier, mask, pal="player"):
    m = materials(tier, pal)
    c = Ctx(1, 100, m, tier)
    S = c.S
    h = 40 + 5 * tier
    body = m["stone"] if tier < 3 else m["wall"]
    th = 0.14

    def conn(x0, y0, x1, y1):
        S.box(x0, y0, x1, y1, 0, h * 0.8, body, sw=3.5)
        if tier >= 2:  # cimasa
            S.box(x0 - 0.01, y0 - 0.01, x1 + 0.01, y1 + 0.01, h * 0.8, h * 0.8 + 6, m["metal"], sw=3, detail=False)
    if mask & 4:
        conn(0.0, 0.5 - th, 0.5, 0.5 + th)
    if mask & 8:
        conn(0.5 - th, 0.0, 0.5 + th, 0.5)
    pil = 0.21
    S.box(0.5 - pil, 0.5 - pil, 0.5 + pil, 0.5 + pil, 0, h, body, sw=3.5)
    cap = m["metal"] if tier >= 2 else m["wood"]
    S.box(0.5 - pil - 0.03, 0.5 - pil - 0.03, 0.5 + pil + 0.03, 0.5 + pil + 0.03, h, h + 8, cap, sw=3.5)
    if tier >= 4:
        S.cone(0.5, 0.5, 0.17, h + 8, 18, m["roof"], sw=3)
    if tier == 5:
        px, py = S.P(0.5, 0.5, h + 26)
        S.circle(px, py, 4, m["crystal"], sw=2)
    if mask & 1:
        conn(0.5, 0.5 - th, 1.0, 0.5 + th)
    if mask & 2:
        conn(0.5 - th, 0.5, 0.5 + th, 1.0)
    return c
