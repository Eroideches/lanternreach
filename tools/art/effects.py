"""Effetti: particelle, esplosioni, fuoco, fumo, fulmini, bandiere, rovine. Sprite bianchi/neutri dove possibile
(il colore si applica con modulate in Godot) e strip animate con piu' frame."""
import math
import random

from PIL import Image, ImageDraw, ImageFilter

from common import INK, PALETTE as C, Scene, render, lighten, darken, mix


def svg_img(w, h, fn, scale=1):
    S = Scene(w, h, 0, 0)
    fn(S)
    return render(S, scale)


def star4(S, cx, cy, r, fill="#FFD764", sw=3):
    S.poly([(cx, cy - r), (cx + r * 0.28, cy - r * 0.28), (cx + r, cy), (cx + r * 0.28, cy + r * 0.28), (cx, cy + r),
            (cx - r * 0.28, cy + r * 0.28), (cx - r, cy), (cx - r * 0.28, cy - r * 0.28)], fill, sw=sw)


def spark(frame=0, n=6):
    """Scintilla bianca a 4 punte che pulsa (colorabile)."""
    r = 6 + 14 * math.sin(frame / n * math.pi)
    return svg_img(40, 40, lambda S: star4(S, 20, 20, max(3, r), "#FFFFFF", 0))


def puff(frame, n, color="#F4EEF8", size=96, rise=0.0):
    t = frame / (n - 1)
    r = size * (0.25 + 0.3 * t)
    op = 1 - t * t
    W = int(size * 1.7)
    cy = W * 0.66 - size * 0.3 * t * (1 + rise)

    def f(S):
        for k2, (sw_, rk) in enumerate(((3 * (1 - t * 0.5), 1.0), (0, 0.86))):
            for dx, dy, k in ((-0.35, 0.1, 0.7), (0.3, 0.05, 0.8), (0, -0.25, 1.0), (0.05, 0.25, 0.7)):
                S.circle(W / 2 + dx * r * 1.3, cy + dy * r * 1.2, r * k * rk, color, stroke=INK if k2 == 0 else None, sw=sw_, op=op)
    return svg_img(W, W, f)


def flame(frame, n=6, small=False):
    sz = 64 if small else 96
    t = frame / n * math.pi * 2
    w = 1 + 0.12 * math.sin(t)
    h = 1 + 0.2 * math.sin(t + 1)
    bx, by = sz / 2, sz - 8

    def f(S):
        def tear(sx, sy, ww, hh, col, sw=3.5):
            S.path(f"M {bx - ww * sx * w:.1f},{by:.1f} Q {bx - ww * sx * w:.1f},{by - hh * 0.5:.1f} {bx + math.sin(t) * 4:.1f},{by - hh * h:.1f} "
                   f"Q {bx + ww * sx * w:.1f},{by - hh * 0.5:.1f} {bx + ww * sx * w:.1f},{by:.1f} Z", col, sw=sw)
        tear(1, 1, sz * 0.32, sz * 0.78, "#F0742A")
        tear(0.62, 1, sz * 0.32, sz * 0.6, "#FFB62E", 0)
        tear(0.3, 1, sz * 0.32, sz * 0.38, "#FFF3A8", 0)
    return svg_img(sz, sz, f)


def explosion(frame, n=8):
    t = frame / (n - 1)
    sz = 256
    r = 30 + 62 * math.sin(t * math.pi * 0.6) if t < 0.8 else 76 - (t - 0.8) * 140
    op = 1.0 if t < 0.6 else 1 - (t - 0.6) / 0.4 * 0.9

    def f(S):
        cx, cy = sz / 2, sz * 0.56
        rnd = random.Random(7)
        # fumo scuro che sale
        for i in range(6):
            a = i / 6 * math.pi * 2
            S.circle(cx + math.cos(a) * r * 0.7, cy + math.sin(a) * r * 0.5 - t * 20, r * 0.5, "#5B4A70", stroke=INK, sw=3, op=op * min(1, t * 2))
        # palla di fuoco
        for k, col in ((1.0, "#E8604C"), (0.8, "#F0742A"), (0.55, "#FFB62E"), (0.3, "#FFF3A8")):
            if t < 0.9 or k > 0.8:
                S.circle(cx, cy, r * k, col, stroke=INK if k == 1.0 else None, sw=4, op=op)
        # raggi di stella
        if t < 0.5:
            for i in range(8):
                a = i / 8 * math.pi * 2 + 0.2
                S.poly([(cx + math.cos(a - 0.12) * r * 0.8, cy + math.sin(a - 0.12) * r * 0.8), (cx + math.cos(a) * r * 1.35, cy + math.sin(a) * r * 1.35),
                        (cx + math.cos(a + 0.12) * r * 0.8, cy + math.sin(a + 0.12) * r * 0.8)], "#FFD764", sw=3, op=op)
    return svg_img(sz, sz, f)


def shock(frame, n=6):
    t = frame / (n - 1)
    sz = 128

    def f(S):
        S.ellipse(sz / 2, sz / 2, 14 + 46 * t, 7 + 23 * t, "none", stroke="#FFFFFF", sw=6 * (1 - t) + 1, op=1 - t * 0.8)
        S.ellipse(sz / 2, sz / 2, 8 + 34 * t, 4 + 17 * t, "none", stroke="#FFF3D6", sw=3 * (1 - t) + 1, op=1 - t)
    return svg_img(sz, sz, f)


def hit(frame, n=4):
    t = frame / (n - 1)
    sz = 64

    def f(S):
        r = 8 + 20 * t
        for i in range(8):
            a = i / 8 * math.pi * 2
            S.line((sz / 2 + math.cos(a) * r * 0.5, sz / 2 + math.sin(a) * r * 0.5), (sz / 2 + math.cos(a) * r, sz / 2 + math.sin(a) * r), "#FFFFFF", 5 * (1 - t) + 1.5, 1 - t * 0.6)
        S.circle(sz / 2, sz / 2, 10 * (1 - t) + 2, "#FFF3A8", stroke=None)
    return svg_img(sz, sz, f)


def muzzle(frame, n=3, fire=False):
    t = frame / (n - 1)
    sz = 96

    def f(S):
        cx, cy = sz / 2, sz / 2
        s = 1 - t * 0.45
        col = ("#FF8A2A", "#FFD764", "#FFF3D6") if fire else ("#FFD764", "#FFF3A8", "#FFFFFF")
        for k, c in zip((38, 26, 12), col):
            pts = []
            for i in range(10):
                a = i / 10 * math.pi * 2
                rr = k * s * (1.0 if i % 2 == 0 else 0.45)
                pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
            S.poly(pts, c, stroke=INK if k == 38 else None, sw=3)
    return svg_img(sz, sz, f)


def lightning(frame, n=4):
    rnd = random.Random(frame * 31 + 5)
    w, h = 160, 160

    def f(S):
        for bolt in range(3):
            x, y = 80, 150
            pts = [(x, y)]
            ang = -math.pi / 2 + rnd.uniform(-0.9, 0.9)
            for i in range(7):
                ang += rnd.uniform(-0.7, 0.7)
                x += math.cos(ang) * 18
                y += math.sin(ang) * 18
                pts.append((x, y))
            d = "M " + " L ".join(f"{px:.1f},{py:.1f}" for px, py in pts)
            S.path(d, "none", stroke="#FFFFFF", sw=8 if bolt == 0 else 5, op=1)
            S.path(d, "none", stroke="#BFF6FF", sw=3, op=0.9)
    return svg_img(w, h, f)


def bubbles(frame, n=4):
    rnd = random.Random(5)
    sz = 64
    t = frame / n

    def f(S):
        for i in range(4):
            ph = (t + i / 4) % 1
            x = 18 + (i * 14) % 32 + math.sin(ph * 6) * 3
            y = sz - 6 - ph * (sz - 14)
            S.circle(x, y, 4 + 3 * (1 - ph) + (i % 2) * 2, "#FFFFFF", stroke=None, op=0.85 * math.sin(ph * math.pi))
    return svg_img(sz, sz, f)


def flag(frame, color, n=4):
    w, h = 64, 48
    t = frame / n * math.pi * 2

    def f(S):
        pts_top, pts_bot = [], []
        for i in range(0, 9):
            x = 4 + i * 6
            off = math.sin(t - i * 0.7) * (1 + i * 0.5)
            pts_top.append((x, 6 + off))
            pts_bot.append((x, 30 + off))
        pts_bot.reverse()
        # coda a V
        S.poly(pts_top + [(pts_top[-1][0] - 6, 18 + math.sin(t - 5) * 4)] + pts_bot, color, sw=3.5)
        S.poly([(pts_top[0][0], pts_top[0][1]), (pts_top[2][0], pts_top[2][1]), (pts_bot[-3][0], pts_bot[-3][1]), (pts_bot[-1][0], pts_bot[-1][1])], lighten(color, 0.3), stroke=None, op=0.6)
    return svg_img(w, h, f)


def gear_sprite(r=64):
    def f(S):
        S.cog(r + 4, r + 4, r, "#E6DFF0", 9, 5)
        S.circle(r + 4, r + 4, r * 0.55, "#C9C0DA", sw=4)
    return svg_img(2 * r + 8, 2 * r + 8, f)


def ring_fx(color, frame, n=8):
    """Anello al suolo per incantesimi (ellisse iso, 2:1)."""
    t = frame / (n - 1)
    w, h = 256, 128

    def f(S):
        S.ellipse(w / 2, h / 2, 120 * (0.2 + 0.8 * min(1, t * 1.6)), 60 * (0.2 + 0.8 * min(1, t * 1.6)), color, stroke=None, op=0.28 * (1 - t * 0.5))
        S.ellipse(w / 2, h / 2, 120 * (0.2 + 0.8 * min(1, t * 1.6)), 60 * (0.2 + 0.8 * min(1, t * 1.6)), "none", stroke=color, sw=6, op=0.9 - t * 0.5)
        S.ellipse(w / 2, h / 2, 90 * (0.2 + 0.8 * min(1, t * 1.6)), 45 * (0.2 + 0.8 * min(1, t * 1.6)), "none", stroke="#FFFFFF", sw=3, op=0.6 - t * 0.4)
    return svg_img(w, h, f)


def particles():
    """Sprite singoli: monete, gocce, gemme, detriti, stelle, cuori/plus."""
    out = {}

    def coin(S):
        S.circle(24, 24, 18, S.grad("#FFE17A", "#E0A21E"), sw=4)
        S.cog(24, 24, 10, "#FFF3C0", 6, 2.5)
    out["coin_cog"] = svg_img(48, 48, coin)

    def drop(S):
        S.path("M 24,6 Q 38,24 36,32 Q 34,44 24,44 Q 14,44 12,32 Q 10,24 24,6 Z", S.grad("#8CF0B0", C["sap"]), sw=4)
        S.ellipse(19, 30, 4, 7, "#FFFFFF", stroke=None, op=0.6)
    out["drop_sap"] = svg_img(48, 52, drop)

    def shard(S):
        S.poly([(24, 4), (38, 18), (32, 44), (16, 44), (10, 18)], S.grad("#C9A8FF", C["shard"]), sw=4)
        S.poly([(24, 4), (24, 44), (16, 44), (10, 18)], "#FFFFFF", stroke=None, op=0.25)
    out["gem_shard"] = svg_img(48, 52, shard)

    def gem(S):
        S.poly([(24, 44), (6, 20), (14, 6), (34, 6), (42, 20)], S.grad("#B8F6FF", C["glimmer"]), sw=4)
        S.line((6, 20), (42, 20), "#FFFFFF", 2.5, 0.7)
        S.line((24, 44), (14, 6), "#FFFFFF", 2, 0.5)
        S.line((24, 44), (34, 6), "#FFFFFF", 2, 0.5)
    out["gem_glimmer"] = svg_img(48, 52, gem)

    def star(S):
        star4(S, 24, 24, 20, "#FFD764", 3.5)
    out["star_pop"] = svg_img(48, 48, star)

    def plus(S):
        S.poly([(18, 6), (30, 6), (30, 18), (42, 18), (42, 30), (30, 30), (30, 42), (18, 42), (18, 30), (6, 30), (6, 18), (18, 18)], C["sap"], sw=4)
    out["plus_heal"] = svg_img(48, 48, plus)

    def heart(S):
        S.path("M 24,42 C 2,26 6,6 24,16 C 42,6 46,26 24,42 Z", S.grad("#FF9EC4", "#E0457A"), sw=4)
    out["heart"] = svg_img(48, 48, heart)
    # detriti
    def chip(col, pts):
        def f(S):
            S.poly(pts, col, sw=3)
        return svg_img(40, 40, f)
    out["debris_wood"] = chip(C["wood_l"], [(6, 10), (32, 4), (36, 16), (10, 24)])
    out["debris_stone"] = chip(C["stone_m"], [(8, 30), (4, 14), (18, 6), (34, 12), (32, 28)])
    out["debris_brick"] = chip("#E8604C", [(6, 12), (30, 6), (34, 24), (12, 30)])
    def dcog(S):
        S.cog(20, 20, 14, "#C98A3C", 7, 3)
    out["debris_cog"] = svg_img(40, 40, dcog)
    def dplank(S):
        S.poly([(4, 16), (36, 8), (38, 20), (6, 28)], C["wood_d"], sw=3)
    out["debris_plank"] = svg_img(40, 40, dplank)
    return out


def rubble(N):
    """Rovina per edificio distrutto (footprint NxN): macerie, travi spezzate, un po' di fumo di brace."""
    from common import soft_shadow
    w, h = N * 128 + 80, N * 64 + 110
    ox, oy = w / 2, 70
    S = Scene(w, h, ox, oy)
    rnd = random.Random(N)
    S.ground_diamond(0.1, 0.1, N - 0.1, N - 0.1, "#5B4A70", stroke=INK, sw=4, op=0.9)
    S.ground_diamond(0.3, 0.3, N - 0.3, N - 0.3, "#3A2C4E", stroke=None, op=0.9)
    pieces = []
    for i in range(6 + 6 * N):
        x, y = rnd.uniform(0.3, N - 0.3), rnd.uniform(0.3, N - 0.3)
        pieces.append((x + y, x, y))
    for _, x, y in sorted(pieces):
        sx, sy = S.P(x, y, 0)
        k = rnd.random()
        if k < 0.45:
            S.poly([(sx - 14, sy), (sx - 8, sy - 14), (sx + 10, sy - 16), (sx + 16, sy)], rnd.choice([C["stone_m"], C["stone_d"], "#8A7BA0"]), sw=3)
        elif k < 0.75:
            ang = rnd.uniform(-0.6, 0.6)
            S.line((sx - 22, sy - 4 + ang * 10), (sx + 22, sy - 10 - ang * 10), INK, 10)
            S.line((sx - 22, sy - 4 + ang * 10), (sx + 22, sy - 10 - ang * 10), C["wood_d"], 5)
        else:
            S.cog(sx, sy - 8, 11, "#A07840", 7, 2.5)
    for i in range(N):
        sx, sy = S.P(rnd.uniform(0.5, N - 0.5), rnd.uniform(0.5, N - 0.5), 0)
        S.circle(sx, sy - 10, 4, "#FF8A2A", stroke=None, op=0.9)
    img = render(S)
    sh = soft_shadow(img.size, [(ox, oy), (ox + N * 64 + 8, oy + N * 32), (ox, oy + N * 64 + 8), (ox - N * 64 - 8, oy + N * 32)], blur=8, opacity=0.25)
    return Image.alpha_composite(sh, img), (ox, oy + N * 32)


def strip(fn, n, **kw):
    return [fn(i, n, **kw) if "n" in fn.__code__.co_varnames else fn(i) for i in range(n)]
