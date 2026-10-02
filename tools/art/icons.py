"""Icone UI (96x96, contorno prugna, stile coerente con gli sprite) e stemmi lega (128x128)."""
import math

from common import INK, PALETTE as C, UI, Scene, render, lighten, darken, mix

SZ = 96


def _icon(fn, size=SZ):
    S = Scene(size, size, 0, 0)
    fn(S, size / 2, size / 2)
    return render(S)


def star_shape(S, cx, cy, r, fill, sw=4.5, inner=0.48, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    S.poly(pts, fill, sw=sw)


ICONS = {}


def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco


@icon("cogs")
def _(S, cx, cy):
    S.cog(cx + 12, cy + 12, 26, S.grad("#FFE17A", "#D9961E"), 8, 4.5)
    S.cog(cx - 14, cy - 12, 22, S.grad("#FFE9A0", "#E8A82A"), 8, 4.5)


@icon("sap")
def _(S, cx, cy):
    S.path(f"M {cx},{cy - 38} Q {cx + 30},{cy - 2} {cx + 26},{cy + 14} Q {cx + 20},{cy + 38} {cx},{cy + 38} Q {cx - 20},{cy + 38} {cx - 26},{cy + 14} Q {cx - 30},{cy - 2} {cx},{cy - 38} Z",
           S.grad("#9CF5BE", "#23A85A"), sw=5)
    S.ellipse(cx - 10, cy + 6, 6, 12, "#FFFFFF", stroke=None, op=0.6)


@icon("shards")
def _(S, cx, cy):
    S.poly([(cx, cy - 40), (cx + 26, cy - 12), (cx + 16, cy + 38), (cx - 16, cy + 38), (cx - 26, cy - 12)], S.grad("#D9C2FF", "#7A44E0"), sw=5)
    S.poly([(cx, cy - 40), (cx, cy + 38), (cx - 16, cy + 38), (cx - 26, cy - 12)], "#FFFFFF", stroke=None, op=0.25)
    S.line((cx - 26, cy - 12), (cx + 26, cy - 12), "#FFFFFF", 2.5, 0.6)


@icon("glimmers")
def _(S, cx, cy):
    S.poly([(cx, cy + 38), (cx - 36, cy - 6), (cx - 22, cy - 32), (cx + 22, cy - 32), (cx + 36, cy - 6)], S.grad("#D2FBFF", "#1EB8D6"), sw=5)
    S.line((cx - 36, cy - 6), (cx + 36, cy - 6), "#FFFFFF", 3, 0.7)
    S.line((cx, cy + 38), (cx - 12, cy - 32), "#FFFFFF", 2.5, 0.5)
    S.line((cx, cy + 38), (cx + 12, cy - 32), "#FFFFFF", 2.5, 0.5)


@icon("trophy")
def _(S, cx, cy):
    S.path(f"M {cx - 22},{cy - 30} L {cx + 22},{cy - 30} L {cx + 20},{cy} Q {cx},{cy + 18} {cx - 20},{cy} Z", S.grad("#FFE17A", "#D9961E"), sw=5)
    S.path(f"M {cx - 22},{cy - 24} Q {cx - 40},{cy - 22} {cx - 30},{cy - 4} L {cx - 18},{cy - 2}", "none", sw=5)
    S.path(f"M {cx + 22},{cy - 24} Q {cx + 40},{cy - 22} {cx + 30},{cy - 4} L {cx + 18},{cy - 2}", "none", sw=5)
    S.poly([(cx - 6, cy + 10), (cx + 6, cy + 10), (cx + 8, cy + 24), (cx - 8, cy + 24)], "#D9961E", sw=4)
    S.poly([(cx - 22, cy + 24), (cx + 22, cy + 24), (cx + 22, cy + 36), (cx - 22, cy + 36)], C["wood_d"], sw=4.5)
    star_shape(S, cx, cy - 14, 9, "#FFF3D6", 2.5)


@icon("star")
def _(S, cx, cy):
    star_shape(S, cx, cy + 3, 40, S.grad("#FFF0A0", "#F2A51E"), 5)
    S.ellipse(cx - 10, cy - 8, 8, 5, "#FFFFFF", stroke=None, op=0.6)


@icon("star_empty")
def _(S, cx, cy):
    star_shape(S, cx, cy + 3, 40, "#5B4A70", 5)


@icon("builder")
def _(S, cx, cy):
    S.line((cx - 24, cy + 30), (cx + 12, cy - 6), INK, 14)
    S.line((cx - 24, cy + 30), (cx + 12, cy - 6), C["wood_l"], 7)
    S.poly([(cx - 2, cy - 22), (cx + 22, cy - 40), (cx + 38, cy - 20), (cx + 18, cy - 4)], S.grad("#C9C2D6", "#6E6788"), sw=5)


@icon("timer")
def _(S, cx, cy):
    S.circle(cx, cy + 4, 34, "#FFF3D6", sw=5)
    S.poly([(cx - 8, cy - 40), (cx + 8, cy - 40), (cx + 8, cy - 30), (cx - 8, cy - 30)], C["coral"], sw=4)
    S.line((cx, cy + 4), (cx, cy - 18), INK, 5)
    S.line((cx, cy + 4), (cx + 16, cy + 12), INK, 5)
    S.circle(cx, cy + 4, 4, INK, stroke=None)


@icon("attack")
def _(S, cx, cy):
    for sgn in (-1, 1):
        S.line((cx - sgn * 30, cy + 30), (cx + sgn * 26, cy - 26), INK, 13)
        S.line((cx - sgn * 30, cy + 30), (cx + sgn * 26, cy - 26), "#E6E8F2", 7)
        S.line((cx - sgn * 26, cy + 14), (cx - sgn * 12, cy + 28), INK, 9)
        S.line((cx - sgn * 26, cy + 14), (cx - sgn * 12, cy + 28), C["amber"], 4)


@icon("shop")
def _(S, cx, cy):
    S.path(f"M {cx - 30},{cy - 14} L {cx + 30},{cy - 14} L {cx + 26},{cy + 34} L {cx - 26},{cy + 34} Z", S.grad("#F2A86A", "#C9712E"), sw=5)
    S.path(f"M {cx - 14},{cy - 14} Q {cx - 14},{cy - 38} {cx},{cy - 38} Q {cx + 14},{cy - 38} {cx + 14},{cy - 14}", "none", sw=5)
    S.cog(cx, cy + 10, 12, "#FFE17A", 7, 3)


@icon("army")
def _(S, cx, cy):
    S.path(f"M {cx - 32},{cy + 10} Q {cx - 32},{cy - 32} {cx},{cy - 34} Q {cx + 32},{cy - 32} {cx + 32},{cy + 10} Z", S.grad("#A9C1EC", "#5C76B0"), sw=5)
    S.poly([(cx - 38, cy + 8), (cx + 38, cy + 8), (cx + 34, cy + 22), (cx - 34, cy + 22)], C["amber"], sw=4.5)
    S.poly([(cx - 6, cy - 34), (cx + 6, cy - 34), (cx + 6, cy - 48), (cx - 6, cy - 48)], C["coral"], sw=4)
    S.line((cx, cy - 26), (cx, cy + 6), INK, 4)


@icon("settings")
def _(S, cx, cy):
    S.cog(cx, cy, 36, S.grad("#E6E0F0", "#9C94B0"), 8, 5)
    S.circle(cx, cy, 12, "#FFF3D6", sw=4)


@icon("clan")
def _(S, cx, cy):
    S.poly([(cx - 30, cy - 34), (cx + 30, cy - 34), (cx + 30, cy + 6), (cx, cy + 38), (cx - 30, cy + 6)], S.grad("#7FC8F0", "#2A74B5"), sw=5)
    S.cog(cx, cy - 6, 14, "#FFF3D6", 7, 3)


@icon("quests")
def _(S, cx, cy):
    S.poly([(cx - 24, cy - 34), (cx + 28, cy - 34), (cx + 28, cy + 34), (cx - 24, cy + 34)], "#FFF3D6", sw=5)
    for i, yy in enumerate((-18, -2, 14)):
        S.line((cx - 12, cy + yy), (cx + 18, cy + yy), INK, 4)
        S.circle(cx - 18, cy + yy, 3, C["sap"] if i == 0 else "#B8B0C4", stroke=None)
    S.circle(cx - 28, cy - 34, 8, C["wood_l"], sw=4)


@icon("upgrade")
def _(S, cx, cy):
    S.poly([(cx, cy - 38), (cx + 34, cy), (cx + 14, cy), (cx + 14, cy + 36), (cx - 14, cy + 36), (cx - 14, cy), (cx - 34, cy)], S.grad("#9CF07A", "#2C9A3E"), sw=5)


@icon("speedup")
def _(S, cx, cy):
    S.poly([(cx + 8, cy - 40), (cx - 26, cy + 6), (cx - 2, cy + 6), (cx - 10, cy + 40), (cx + 26, cy - 8), (cx + 2, cy - 8)], S.grad("#FFF0A0", "#F2A51E"), sw=5)


@icon("info")
def _(S, cx, cy):
    S.circle(cx, cy, 34, S.grad("#7FC8F0", "#2A74B5"), sw=5)
    S.circle(cx, cy - 16, 5, "#FFFFFF", stroke=None)
    S.line((cx, cy - 2), (cx, cy + 20), "#FFFFFF", 9)


@icon("close")
def _(S, cx, cy):
    S.circle(cx, cy, 34, S.grad("#FF8A76", "#C9402E"), sw=5)
    S.line((cx - 13, cy - 13), (cx + 13, cy + 13), "#FFFFFF", 9)
    S.line((cx + 13, cy - 13), (cx - 13, cy + 13), "#FFFFFF", 9)


@icon("check")
def _(S, cx, cy):
    S.circle(cx, cy, 34, S.grad("#9CF07A", "#2C9A3E"), sw=5)
    S.path(f"M {cx - 16},{cy + 2} L {cx - 4},{cy + 14} L {cx + 18},{cy - 12}", "none", stroke="#FFFFFF", sw=9)


@icon("plus")
def _(S, cx, cy):
    S.circle(cx, cy, 30, S.grad("#9CF07A", "#2C9A3E"), sw=5)
    S.line((cx - 14, cy), (cx + 14, cy), "#FFFFFF", 9)
    S.line((cx, cy - 14), (cx, cy + 14), "#FFFFFF", 9)


@icon("minus")
def _(S, cx, cy):
    S.circle(cx, cy, 30, S.grad("#FF8A76", "#C9402E"), sw=5)
    S.line((cx - 14, cy), (cx + 14, cy), "#FFFFFF", 9)


@icon("lock")
def _(S, cx, cy):
    S.path(f"M {cx - 18},{cy - 6} L {cx - 18},{cy - 18} Q {cx - 18},{cy - 38} {cx},{cy - 38} Q {cx + 18},{cy - 38} {cx + 18},{cy - 18} L {cx + 18},{cy - 6}", "none", sw=8)
    S.poly([(cx - 28, cy - 8), (cx + 28, cy - 8), (cx + 28, cy + 34), (cx - 28, cy + 34)], S.grad("#FFE17A", "#D9961E"), sw=5)
    S.circle(cx, cy + 10, 6, INK, stroke=None)


@icon("lab")
def _(S, cx, cy):
    S.path(f"M {cx - 10},{cy - 38} L {cx + 10},{cy - 38} L {cx + 10},{cy - 10} L {cx + 32},{cy + 30} Q {cx + 34},{cy + 38} {cx + 24},{cy + 38} L {cx - 24},{cy + 38} Q {cx - 34},{cy + 38} {cx - 32},{cy + 30} L {cx - 10},{cy - 10} Z", "#E6F6FF", sw=5)
    S.path(f"M {cx - 22},{cy + 14} L {cx + 22},{cy + 14} L {cx + 30},{cy + 32} L {cx - 30},{cy + 32} Z", C["glimmer"], stroke=None)
    S.circle(cx - 4, cy + 22, 4, "#FFFFFF", stroke=None)


@icon("spells")
def _(S, cx, cy):
    S.line((cx - 28, cy + 30), (cx + 8, cy - 6), INK, 12)
    S.line((cx - 28, cy + 30), (cx + 8, cy - 6), C["wood_l"], 6)
    star_shape(S, cx + 14, cy - 14, 22, C["shard"], 4.5)


@icon("home")
def _(S, cx, cy):
    S.poly([(cx, cy - 36), (cx + 36, cy - 4), (cx - 36, cy - 4)], C["coral"], sw=5)
    S.poly([(cx - 26, cy - 4), (cx + 26, cy - 4), (cx + 26, cy + 34), (cx - 26, cy + 34)], "#FFF3D6", sw=5)
    S.poly([(cx - 8, cy + 10), (cx + 8, cy + 10), (cx + 8, cy + 34), (cx - 8, cy + 34)], C["wood_d"], sw=4)


@icon("move")
def _(S, cx, cy):
    for a in range(4):
        ang = a * math.pi / 2
        dx, dy = math.cos(ang), math.sin(ang)
        tip = (cx + dx * 38, cy + dy * 38)
        S.line((cx, cy), (cx + dx * 26, cy + dy * 26), INK, 10)
        S.poly([tip, (cx + dx * 22 - dy * 12, cy + dy * 22 + dx * 12), (cx + dx * 22 + dy * 12, cy + dy * 22 - dx * 12)], "#FFF3D6", sw=4)
    S.circle(cx, cy, 8, "#FFF3D6", sw=4)


@icon("rotate")
def _(S, cx, cy):
    S.path(f"M {cx + 26},{cy + 12} A 28 28 0 1 1 {cx + 22},{cy - 20}", "none", sw=11)
    S.path(f"M {cx + 26},{cy + 12} A 28 28 0 1 1 {cx + 22},{cy - 20}", "none", stroke="#FFF3D6", sw=5)
    S.poly([(cx + 10, cy - 26), (cx + 36, cy - 32), (cx + 30, cy - 6)], "#FFF3D6", sw=4)


@icon("trash")
def _(S, cx, cy):
    S.poly([(cx - 24, cy - 18), (cx + 24, cy - 18), (cx + 20, cy + 36), (cx - 20, cy + 36)], "#E6E0F0", sw=5)
    S.poly([(cx - 32, cy - 30), (cx + 32, cy - 30), (cx + 32, cy - 18), (cx - 32, cy - 18)], C["coral"], sw=4.5)
    for dx in (-10, 0, 10):
        S.line((cx + dx, cy - 8), (cx + dx, cy + 26), INK, 3.5)


@icon("play")
def _(S, cx, cy):
    S.poly([(cx - 20, cy - 32), (cx + 30, cy), (cx - 20, cy + 32)], S.grad("#9CF07A", "#2C9A3E"), sw=5)


@icon("pause")
def _(S, cx, cy):
    for dx in (-14, 14):
        S.poly([(cx + dx - 8, cy - 30), (cx + dx + 8, cy - 30), (cx + dx + 8, cy + 30), (cx + dx - 8, cy + 30)], "#FFF3D6", sw=5)


@icon("surrender")
def _(S, cx, cy):
    S.line((cx - 22, cy + 38), (cx - 22, cy - 36), INK, 10)
    S.line((cx - 22, cy + 38), (cx - 22, cy - 36), C["wood_l"], 5)
    S.path(f"M {cx - 20},{cy - 34} Q {cx},{cy - 42} {cx + 30},{cy - 30} L {cx + 30},{cy} Q {cx},{cy - 10} {cx - 20},{cy - 2} Z", "#FFFFFF", sw=5)


@icon("replay")
def _(S, cx, cy):
    S.path(f"M {cx - 26},{cy - 6} A 28 28 0 1 0 {cx - 10},{cy - 26}", "none", sw=11)
    S.path(f"M {cx - 26},{cy - 6} A 28 28 0 1 0 {cx - 10},{cy - 26}", "none", stroke="#FFF3D6", sw=5)
    S.poly([(cx - 30, cy - 36), (cx - 4, cy - 38), (cx - 18, cy - 14)], "#FFF3D6", sw=4)
    S.poly([(cx - 6, cy - 10), (cx + 16, cy + 2), (cx - 6, cy + 14)], "#FFF3D6", sw=3.5)


@icon("sound_on")
def _(S, cx, cy):
    S.poly([(cx - 34, cy - 12), (cx - 18, cy - 12), (cx + 2, cy - 30), (cx + 2, cy + 30), (cx - 18, cy + 12), (cx - 34, cy + 12)], "#FFF3D6", sw=5)
    for r in (16, 30):
        S.path(f"M {cx + 10},{cy - r * 0.8} A {r} {r} 0 0 1 {cx + 10},{cy + r * 0.8}", "none", stroke=INK, sw=5)


@icon("sound_off")
def _(S, cx, cy):
    S.poly([(cx - 34, cy - 12), (cx - 18, cy - 12), (cx + 2, cy - 30), (cx + 2, cy + 30), (cx - 18, cy + 12), (cx - 34, cy + 12)], "#B8B0C4", sw=5)
    S.line((cx + 12, cy - 14), (cx + 36, cy + 14), C["coral"], 8)
    S.line((cx + 36, cy - 14), (cx + 12, cy + 14), C["coral"], 8)


@icon("music")
def _(S, cx, cy):
    S.line((cx - 10, cy + 26), (cx - 10, cy - 32), INK, 6)
    S.line((cx + 24, cy + 18), (cx + 24, cy - 40), INK, 6)
    S.poly([(cx - 10, cy - 32), (cx + 24, cy - 40), (cx + 24, cy - 26), (cx - 10, cy - 18)], INK, sw=3)
    S.ellipse(cx - 20, cy + 28, 13, 10, "#FFF3D6", sw=5)
    S.ellipse(cx + 14, cy + 20, 13, 10, "#FFF3D6", sw=5)


@icon("language")
def _(S, cx, cy):
    S.circle(cx, cy, 34, S.grad("#7FC8F0", "#2A74B5"), sw=5)
    S.ellipse(cx, cy, 14, 34, "none", stroke=INK, sw=3.5)
    S.line((cx - 34, cy), (cx + 34, cy), INK, 3.5)
    S.path(f"M {cx - 30},{cy - 16} Q {cx},{cy - 10} {cx + 30},{cy - 16}", "none", stroke=INK, sw=3)
    S.path(f"M {cx - 30},{cy + 16} Q {cx},{cy + 10} {cx + 30},{cy + 16}", "none", stroke=INK, sw=3)


@icon("reset")
def _(S, cx, cy):
    S.path(f"M {cx + 24},{cy - 18} A 30 30 0 1 0 {cx + 28},{cy + 8}", "none", sw=11)
    S.path(f"M {cx + 24},{cy - 18} A 30 30 0 1 0 {cx + 28},{cy + 8}", "none", stroke=C["coral"], sw=5)
    S.poly([(cx + 8, cy - 22), (cx + 36, cy - 36), (cx + 34, cy - 6)], C["coral"], sw=4)


@icon("shield")
def _(S, cx, cy):
    S.poly([(cx - 30, cy - 34), (cx + 30, cy - 34), (cx + 30, cy + 2), (cx, cy + 38), (cx - 30, cy + 2)], S.grad("#B8F6FF", "#3EA7C9"), sw=5)
    S.poly([(cx - 18, cy - 24), (cx, cy - 24), (cx, cy + 22), (cx - 18, cy + 2)], "#FFFFFF", stroke=None, op=0.35)


@icon("chat")
def _(S, cx, cy):
    S.path(f"M {cx - 34},{cy - 26} L {cx + 34},{cy - 26} L {cx + 34},{cy + 16} L {cx - 6},{cy + 16} L {cx - 22},{cy + 34} L {cx - 20},{cy + 16} L {cx - 34},{cy + 16} Z", "#FFF3D6", sw=5)
    for dx in (-16, 0, 16):
        S.circle(cx + dx, cy - 5, 4.5, INK, stroke=None)


@icon("gift")
def _(S, cx, cy):
    S.poly([(cx - 30, cy - 8), (cx + 30, cy - 8), (cx + 30, cy + 34), (cx - 30, cy + 34)], C["coral"], sw=5)
    S.poly([(cx - 34, cy - 22), (cx + 34, cy - 22), (cx + 34, cy - 6), (cx - 34, cy - 6)], "#FF8A76", sw=5)
    S.poly([(cx - 7, cy - 22), (cx + 7, cy - 22), (cx + 7, cy + 34), (cx - 7, cy + 34)], C["amber"], sw=3.5)
    S.ellipse(cx - 14, cy - 30, 13, 8, C["amber"], sw=4)
    S.ellipse(cx + 14, cy - 30, 13, 8, C["amber"], sw=4)


@icon("xp")
def _(S, cx, cy):
    star_shape(S, cx, cy + 2, 40, S.grad("#9CE8FF", "#3EA7C9"), 5, 0.55, 6)


@icon("log")
def _(S, cx, cy):
    S.poly([(cx - 30, cy - 34), (cx + 30, cy - 34), (cx + 30, cy + 2), (cx, cy + 38), (cx - 30, cy + 2)], S.grad("#B8B0C4", "#6E6788"), sw=5)
    for sgn in (-1, 1):
        S.line((cx - sgn * 14, cy + 12), (cx + sgn * 14, cy - 18), "#FFF3D6", 5)


@icon("campaign")
def _(S, cx, cy):
    S.poly([(cx - 38, cy - 24), (cx - 12, cy - 32), (cx + 12, cy - 24), (cx + 38, cy - 32), (cx + 38, cy + 28), (cx + 12, cy + 36), (cx - 12, cy + 28), (cx - 38, cy + 36)], "#F2E3B6", sw=5)
    S.path(f"M {cx - 26},{cy + 18} Q {cx - 8},{cy - 10} {cx + 6},{cy + 8} Q {cx + 18},{cy + 20} {cx + 26},{cy - 14}", "none", stroke=C["coral"], sw=4)
    S.line((cx + 20, cy - 20), (cx + 32, cy - 8), C["coral"], 5)
    S.line((cx + 32, cy - 20), (cx + 20, cy - 8), C["coral"], 5)


def render_icons():
    return {k: _icon(fn) for k, fn in ICONS.items()}


LEAGUE_COLORS = [("wick", "#B8A28A"), ("spark", "#E3B35A"), ("ember", "#F0742A"), ("flame", "#E8604C"),
                 ("blaze", "#E8419A"), ("beacon", "#4AA8E8"), ("lighthouse", "#A06BFF"), ("sunforge", "#FFD25A")]


def league_badge(i):
    lid, col = LEAGUE_COLORS[i]

    def f(S, cx, cy):
        S.poly([(cx - 46, cy - 50), (cx + 46, cy - 50), (cx + 46, cy + 8), (cx, cy + 56), (cx - 46, cy + 8)], S.grad(lighten(col, 0.35), darken(col, 0.25)), sw=6)
        S.poly([(cx - 36, cy - 40), (cx + 36, cy - 40), (cx + 36, cy + 4), (cx, cy + 42), (cx - 36, cy + 4)], "none", stroke="#FFF3D6", sw=3.5)
        # fiamma di livello crescente
        h = 22 + i * 4
        S.path(f"M {cx - 16},{cy + 14} Q {cx - 20},{cy - h * 0.4} {cx},{cy - h} Q {cx + 20},{cy - h * 0.4} {cx + 16},{cy + 14} Q {cx},{cy + 24} {cx - 16},{cy + 14} Z", "#FFF3D6", sw=4)
        S.path(f"M {cx - 8},{cy + 12} Q {cx - 8},{cy - h * 0.2} {cx},{cy - h * 0.55} Q {cx + 8},{cy - h * 0.2} {cx + 8},{cy + 12} Z", C["amber"], stroke=None)
        for k in range(min(3, i // 2 + 1) if i > 0 else 0):
            star_shape(S, cx - 20 + k * 20 if i // 2 >= 1 else cx, cy - 52, 7, "#FFD764", 2.5)
    return _icon(f, 128)
