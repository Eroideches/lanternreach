"""Truppe: sprite procedurali con animazioni camminata (6 frame), attacco (4), morte (4).

Due direzioni disegnate: 'down' (verso SE, viso visibile) e 'up' (verso NE, di schiena). Le altre due (SW, NW)
si ottengono specchiando in orizzontale (flip_h in Godot). Ogni truppa ha una silhouette distinta:
  cogling   = ometto tondo con ingranaggio sulla schiena (arancio)
  slingwisp = spiritello a goccia senza gambe che fluttua (azzurro)
  bulwark   = tank largo e basso dietro un grande scudo a torre (acciaio)
  magpie    = uccello nero/bianco con becco e sacco (ladro, veloce)
  kegger    = ometto con barilotto di polvere e miccia accesa (rosso)
  rustjaw   = cinghiale a quattro zampe con zanne ed elmo a ingranaggio (ruggine)
  kitewing  = aquilone con faccia e coda a nastri (giallo-lime, volante)
  mender    = lanterna-mongolfiera rosa con croce verde (guaritore volante)
  dirigible = dirigibile con bombe (volante pesante)
  ember_warden = cavaliere alto con mantello a brace e bastone-lanterna (elite)
"""
import math

from PIL import Image

from common import INK, PALETTE as C, Scene, render, lighten, darken, mix

WALK_FRAMES, ATK_FRAMES, DEATH_FRAMES = 6, 4, 4
ATK_LUNGE = [-6, 16, 8, 0]
ATK_SWING = [-65, 45, 20, 0]

SIZES = {  # troop: (W, H, ground y)
    "cogling": (128, 128, 112), "slingwisp": (128, 128, 112), "bulwark": (192, 176, 154), "magpie": (144, 128, 112),
    "kegger": (128, 128, 112), "rustjaw": (176, 144, 126), "kitewing": (144, 176, 120), "mender": (160, 190, 142),
    "dirigible": (256, 192, 124), "ember_warden": (176, 232, 216),
}
FLYING = {"kitewing", "mender", "dirigible"}


class Pose:
    def __init__(self, anim, f, back, W, H, gy, flying=False):
        self.anim, self.f, self.back = anim, f, back
        self.cx, self.gy = W / 2, gy
        self.W, self.H = W, H
        self.t = f / WALK_FRAMES if anim == "walk" else 0.0
        self.bob = 0.0
        self.step = 0.0
        self.lunge = 0.0
        self.swing = 0.0
        self.death = 0.0
        if anim == "walk":
            self.step = math.sin(self.t * 2 * math.pi)
            self.bob = -abs(math.sin(self.t * 2 * math.pi)) * 5
            self.swing = math.sin(self.t * 2 * math.pi) * 28
        elif anim == "attack":
            self.lunge = ATK_LUNGE[f]
            self.swing = ATK_SWING[f]
            self.bob = -3 if f == 1 else 0
        else:
            self.death = (f + 1) / DEATH_FRAMES
        self.flying = flying
        self.fly = math.sin((self.t if anim == "walk" else f * 0.25) * 2 * math.pi) * 5 if flying else 0
        # direzione di avanzamento nello schermo: giu'->(+x,+y), su->(+x,-y)
        self.dirx = 1
        self.diry = -1 if back else 1


def limb(S, a, b, w, col, outline=INK):
    S.line(a, b, outline, w + 6)
    S.line(a, b, col, w)


def eyes(S, x, y, sep=9, r=7, look=(3, 2)):
    for dx in (-sep, sep):
        S.ellipse(x + dx, y, r, r * 1.3, "#FFFFFF", sw=2.5)
        S.circle(x + dx + look[0], y + look[1] + 1, r * 0.55, INK, stroke=None)
        S.circle(x + dx + look[0] + 1.5, y + look[1] - 1.5, r * 0.2, "#FFFFFF", stroke=None)


def shadow(S, P, rx=30, ry=11, hover=0):
    S.ellipse(P.cx, P.gy + 2, rx, ry, "#2E2036", stroke=None, op=0.28 - min(0.1, hover / 300))


def legs(S, P, col, boot, spread=8, ln=16, w=10, hip=None, bootr=7):
    hip = hip if hip is not None else P.gy - ln - 4 + P.bob
    for k, side in enumerate((-1, 1)):
        ph = P.step if k == 0 else -P.step
        fx = P.cx + side * spread + ph * 9
        fy = P.gy - max(0.0, ph) * 7
        limb(S, (P.cx + side * spread, hip), (fx, fy - 3), w, col)
        S.ellipse(fx + 2, fy, bootr + 2, bootr * 0.7, boot, sw=3)


def head_blob(S, x, y, r, skin, back=False, hair=None):
    S.circle(x, y, r, S.radial(lighten(skin, 0.4), skin, 1, 1), sw=4.5)
    S.ellipse(x - r * 0.35, y - r * 0.45, r * 0.25, r * 0.15, "#FFFFFF", stroke=None, op=0.5)
    if back and hair:
        S.circle(x, y - 2, r * 0.96, hair, stroke=None, op=0.95)


def begin_group(S, P, flip=False):
    """Applica rotazione/dissolvenza di morte e piccoli offset di attacco a tutto il personaggio."""
    tr = []
    if P.anim == "attack":
        tr.append(f"translate({P.lunge * P.dirx * 0.6:.1f},{P.lunge * P.diry * 0.3:.1f})")
    if P.anim == "death":
        d = P.death
        tr.append(f"translate({P.cx:.1f},{P.gy:.1f}) rotate({-72 * d:.1f}) scale({1 - 0.15 * d:.2f},{1 - 0.35 * d:.2f}) translate({-P.cx:.1f},{-P.gy:.1f})")
    op = 1.0 if P.anim != "death" else max(0.0, 1.0 - 0.28 * (P.f)) if P.f < 3 else 0.0
    S.raw(f'<g transform="{" ".join(tr)}" opacity="{op:.2f}">')


def end_group(S):
    S.raw("</g>")


def death_fx(S, P):
    """Sbuffi e stelline quando la truppa 'si spegne' (nessun sangue)."""
    if P.anim != "death":
        return
    d = P.f
    n = 3 + d * 2
    for i in range(n):
        ang = i / n * math.pi * 2 + d * 0.7
        r = 14 + d * 12
        x, y = P.cx + math.cos(ang) * r * 1.4, P.gy - 26 + math.sin(ang) * r * 0.8 - d * 6
        col = ("#FFD764", "#FFF3D6", "#FF9A4A")[i % 3]
        S.poly([(x, y - 7), (x + 3, y - 2), (x + 8, y), (x + 3, y + 2), (x, y + 7), (x - 3, y + 2), (x - 8, y), (x - 3, y - 2)],
               col, stroke=INK, sw=2, op=max(0.2, 1 - d * 0.22))
    S.ellipse(P.cx, P.gy - 14, 22 + d * 9, 14 + d * 4, "#FFF3D6", stroke=None, op=0.25 * (d if d < 3 else 1) if d > 0 else 0)


# ----------------------------------------------------------------- troops
def t_cogling(S, P):
    cx, gy = P.cx, P.gy
    shadow(S, P)
    begin_group(S, P)
    skin, tunic, boots = "#F2C494", C["ember"], "#6B4430"
    legs(S, P, "#8A5A3C", boots, 7, 14, 9)
    by = gy - 36 + P.bob
    if P.back:   # ingranaggio sulla schiena
        S.ellipse(cx, by + 2, 21, 24, tunic, sw=4)
        S.cog(cx, by + 2, 24, C["amber"], 8, 3.5)
    else:
        S.ellipse(cx, by + 2, 21, 24, tunic, sw=4)
        S.ellipse(cx - 6, by - 8, 8, 5, "#FFFFFF", stroke=None, op=0.4)
        S.circle(cx, by + 8, 5, C["amber"], sw=2.5)
    hy = by - 30
    head_blob(S, cx, hy, 24, skin, P.back, "#6B3E25")
    # occhialoni
    if not P.back:
        S.poly([(cx - 24, hy - 10), (cx + 24, hy - 10), (cx + 22, hy - 4), (cx - 22, hy - 4)], "#6B4430", sw=3)
        eyes(S, cx, hy + 1, 9, 7, (3, 1))
        S.ellipse(cx, hy + 14, 5, 3, "#B05A4A", stroke=None)
    else:
        S.poly([(cx - 24, hy - 10), (cx + 24, hy - 10), (cx + 22, hy - 4), (cx - 22, hy - 4)], "#6B4430", sw=3)
    # chiave inglese
    ang = math.radians(-20 + P.swing * (1 if not P.back else -1))
    hx, hy2 = cx + 22, by + 4
    ex, ey = hx + math.cos(ang) * 6, hy2 - 8 + math.sin(ang) * -4
    tipx, tipy = ex + math.sin(-ang) * 26 + 6, ey - math.cos(ang) * 30
    limb(S, (cx + 12, by - 4), (hx, hy2 - 2), 8, skin)
    limb(S, (hx, hy2 - 2), (tipx, tipy), 7, "#B0B6C6")
    S.circle(tipx, tipy, 8, "#B0B6C6", sw=3.5)
    S.circle(tipx, tipy, 3.5, "#2E2036", stroke=None)
    limb(S, (cx - 12, by - 4), (cx - 24, by + 14), 8, skin)
    end_group(S)
    death_fx(S, P)


def t_slingwisp(S, P):
    cx, gy = P.cx, P.gy
    hover = 14 + P.fly + (P.bob if P.anim == "walk" else 0)
    shadow(S, P, 22, 8, hover)
    begin_group(S, P)
    col = "#6FD8F0"
    base = gy - hover
    # coda a nastro che ondeggia
    sw = math.sin((P.t if P.anim == "walk" else P.f * 0.3) * 2 * math.pi) * 12
    S.path(f"M {cx - 10:.1f},{base - 14:.1f} Q {cx - 20 + sw:.1f},{base + 6:.1f} {cx + sw * 1.5:.1f},{base + 4:.1f} Q {cx + 20 + sw:.1f},{base + 6:.1f} {cx + 10:.1f},{base - 14:.1f} Z", S.grad("#BDF1FF", "#4CB5E0"), sw=4)
    # corpo a goccia
    S.path(f"M {cx:.1f},{base - 78:.1f} Q {cx + 34:.1f},{base - 46:.1f} {cx + 28:.1f},{base - 22:.1f} Q {cx:.1f},{base + 2:.1f} {cx - 28:.1f},{base - 22:.1f} Q {cx - 34:.1f},{base - 46:.1f} {cx:.1f},{base - 78:.1f} Z",
           S.radial("#E7FBFF", col, 1, 1), sw=4.5)
    S.ellipse(cx - 12, base - 54, 8, 5, "#FFFFFF", stroke=None, op=0.6)
    if not P.back:
        eyes(S, cx, base - 36, 9, 7, (2, 1))
        S.ellipse(cx, base - 22, 5, 3, "#3E6A90", stroke=None)
    else:
        S.poly([(cx, base - 84), (cx + 6, base - 70), (cx - 6, base - 70)], "#4CB5E0", sw=3)
    # fionda
    ang = math.radians(P.swing)
    hx, hy = cx + 26, base - 38
    S.line((cx + 22, base - 36), (hx + 12, hy - 4), INK, 9)
    S.line((cx + 22, base - 36), (hx + 12, hy - 4), "#8A5A3C", 5)
    fx, fy = hx + 12, hy - 4
    S.path(f"M {fx:.1f},{fy:.1f} L {fx - 8:.1f},{fy - 22:.1f} M {fx:.1f},{fy:.1f} L {fx + 10:.1f},{fy - 20:.1f}", "none", sw=8)
    S.path(f"M {fx:.1f},{fy:.1f} L {fx - 8:.1f},{fy - 22:.1f} M {fx:.1f},{fy:.1f} L {fx + 10:.1f},{fy - 20:.1f}", "none", stroke="#8A5A3C", sw=4)
    pull = max(0, -P.swing) * 0.3 if P.anim == "attack" else 0
    S.path(f"M {fx - 8:.1f},{fy - 22:.1f} Q {fx - pull:.1f},{fy - 12 + pull * 0.4:.1f} {fx + 10:.1f},{fy - 20:.1f}", "none", stroke="#FFF3D6", sw=2.5)
    S.circle(fx - pull, fy - 12 + pull * 0.4, 5, "#6B6B7C", sw=2.5)
    end_group(S)
    death_fx(S, P)


def t_bulwark(S, P):
    cx, gy = P.cx, P.gy
    shadow(S, P, 50, 16)
    begin_group(S, P)
    steel, trim = "#6F8FC9", C["amber"]
    legs(S, P, "#4A5F8F", "#3A3446", 14, 20, 16, bootr=11)
    by = gy - 54 + P.bob
    # torso largo
    S.poly([(cx - 46, by - 34), (cx + 46, by - 34), (cx + 54, by + 22), (cx - 54, by + 22)], S.grad(lighten(steel, 0.3), darken(steel, 0.25)), sw=5)
    S.poly([(cx - 46, by - 34), (cx + 46, by - 34), (cx + 40, by - 22), (cx - 40, by - 22)], trim, sw=3.5)
    # testa piccola con elmo
    hy = by - 52
    if not P.back:
        S.circle(cx, hy, 21, "#F2C494", sw=4.5)
        eyes(S, cx, hy + 2, 8, 5, (2, 1))
    S.path(f"M {cx - 24:.1f},{hy + 2:.1f} A 24 22 0 0 1 {cx + 24:.1f},{hy + 2:.1f} L {cx + 24:.1f},{hy - 4:.1f} A 24 24 0 0 0 {cx - 24:.1f},{hy - 4:.1f} Z", steel, sw=4.5)
    S.poly([(cx - 5, hy - 22), (cx + 5, hy - 22), (cx + 5, hy - 36), (cx - 5, hy - 36)], C["coral"], sw=3)
    if P.back:
        S.circle(cx, hy - 2, 22, darken(steel, 0.1), sw=4.5)
    # grande scudo a torre davanti (solo di fronte) / sulla schiena
    sx = cx - 6 + P.lunge * 0.4
    if not P.back:
        S.poly([(sx - 40, by - 30), (sx + 40, by - 30), (sx + 40, by + 18), (sx, by + 48), (sx - 40, by + 18)], S.grad("#A9C1EC", "#5C76B0"), sw=5.5)
        S.poly([(sx - 30, by - 22), (sx + 30, by - 22), (sx + 30, by + 14), (sx, by + 36), (sx - 30, by + 14)], "none", stroke=trim, sw=3.5)
        S.glow(sx, by - 2, 24, C["amber"], 0.5)
        S.circle(sx, by - 2, 10, S.radial("#FFFFFF", C["amber"], 1, 1), sw=3)
    else:
        S.poly([(cx - 36, by - 28), (cx + 36, by - 28), (cx + 36, by + 14), (cx, by + 40), (cx - 36, by + 14)], S.grad("#A9C1EC", "#5C76B0"), sw=5)
    # braccio/mazza
    ang = math.radians(P.swing)
    S.circle(cx + 52, by - 8, 11, "#F2C494", sw=3.5)
    mx, my = cx + 56 + math.sin(ang) * 22, by - 22 - math.cos(ang) * 26
    limb(S, (cx + 52, by - 8), (mx, my), 8, "#8A5A3C")
    S.circle(mx, my, 13, "#8A8AA0", sw=4)
    end_group(S)
    death_fx(S, P)


def t_magpie(S, P):
    cx, gy = P.cx, P.gy
    shadow(S, P, 26, 9)
    begin_group(S, P)
    black, white, blue = "#33304A", "#FFF8F0", "#4FA0E8"
    # zampe sottili
    for k, side in enumerate((-1, 1)):
        ph = P.step if k == 0 else -P.step
        fx, fy = cx + side * 8 + ph * 12, gy - max(0, ph) * 8
        limb(S, (cx + side * 6, gy - 24 + P.bob), (fx, fy - 2), 4, "#E8943A")
        S.line((fx - 6, fy), (fx + 8, fy), INK, 4)
    by = gy - 38 + P.bob
    # coda
    S.poly([(cx - 22, by + 6), (cx - 52, by - 6 + math.sin(P.t * 6.28) * 5), (cx - 48, by + 16), (cx - 20, by + 18)], S.grad("#5C6BD6", black), sw=4)
    S.ellipse(cx, by, 28, 24, black, sw=4.5)
    S.ellipse(cx + 4, by + 8, 18, 14, white, stroke=None)
    S.path(f"M {cx - 22:.1f},{by - 8:.1f} Q {cx - 4:.1f},{by - 22:.1f} {cx + 14:.1f},{by - 2:.1f} Q {cx - 4:.1f},{by + 6:.1f} {cx - 22:.1f},{by - 8:.1f} Z", blue, sw=3.5)
    # testa + becco
    hx, hy = cx + 14, by - 26
    S.circle(hx, hy, 17, black, sw=4.5)
    if not P.back:
        eyes(S, hx - 2, hy - 2, 7, 5, (2, 1))
        S.poly([(hx + 14, hy + 2), (hx + 40, hy + 10), (hx + 14, hy + 14)], "#FFA23A", sw=3.5)
    else:
        S.poly([(hx + 14, hy - 4), (hx + 38, hy - 10), (hx + 14, hy + 6)], "#FFA23A", sw=3.5)
    # sacco del bottino
    S.path(f"M {cx - 6:.1f},{by - 12:.1f} Q {cx - 34:.1f},{by - 20:.1f} {cx - 30:.1f},{by + 12:.1f} Q {cx - 10:.1f},{by + 22:.1f} {cx - 4:.1f},{by + 4:.1f} Z", "#C98A3C", sw=4)
    S.circle(cx - 20, by - 8, 4, C["amber"], sw=2.5)
    end_group(S)
    death_fx(S, P)


def t_kegger(S, P):
    cx, gy = P.cx, P.gy
    shadow(S, P)
    begin_group(S, P)
    skin = "#F2C494"
    legs(S, P, "#6B4430", "#4A3340", 7, 12, 8)
    by = gy - 32 + P.bob
    S.ellipse(cx, by, 18, 20, "#6E6788", sw=4)
    hy = by - 26
    head_blob(S, cx, hy, 20, skin, P.back, "#4A3340")
    if not P.back:
        eyes(S, cx, hy + 3, 8, 6, (2, 1))
        S.path(f"M {cx - 6:.1f},{hy + 14:.1f} Q {cx:.1f},{hy + 19:.1f} {cx + 6:.1f},{hy + 14:.1f}", "none", stroke="#8A3A3A", sw=2.5)
    # pentola come elmo
    S.path(f"M {cx - 22:.1f},{hy - 4:.1f} A 22 18 0 0 1 {cx + 22:.1f},{hy - 4:.1f} L {cx + 24:.1f},{hy - 8:.1f} L {cx - 24:.1f},{hy - 8:.1f} Z", "#8A8AA0", sw=4)
    S.circle(cx, hy - 20, 4, INK, stroke=None)
    # barilotto in braccio
    bxs = cx + 14 + P.lunge * 0.5
    by2 = by + 6 - (6 if P.anim == "attack" and P.f == 1 else 0)
    if P.back:
        bxs = cx - 14
    S.poly([(bxs - 20, by2 - 20), (bxs + 20, by2 - 20), (bxs + 24, by2), (bxs + 20, by2 + 20), (bxs - 20, by2 + 20), (bxs - 24, by2)], S.grad("#F27A60", "#B83A30"), sw=4.5)
    for yy in (by2 - 9, by2 + 9):
        S.line((bxs - 22, yy), (bxs + 22, yy), "#5C2A2A", 4)
    S.circle(bxs, by2, 8, C["amber"], sw=3)
    # miccia
    S.path(f"M {bxs:.1f},{by2 - 20:.1f} Q {bxs + 6:.1f},{by2 - 34:.1f} {bxs + 2:.1f},{by2 - 40:.1f}", "none", sw=6)
    S.path(f"M {bxs:.1f},{by2 - 20:.1f} Q {bxs + 6:.1f},{by2 - 34:.1f} {bxs + 2:.1f},{by2 - 40:.1f}", "none", stroke="#E3C98B", sw=2.5)
    f = 1 + 0.4 * math.sin((P.t if P.anim == "walk" else P.f) * 6.28 * 2)
    S.glow(bxs + 2, by2 - 42, 14 * f, "#FFB62E", 0.9)
    S.circle(bxs + 2, by2 - 42, 4.5 * f, "#FFF3A8", stroke=None)
    limb(S, (cx - 10, by - 4), (cx - 22, by + 12), 7, skin)
    end_group(S)
    death_fx(S, P)


def t_rustjaw(S, P):
    cx, gy = P.cx, P.gy
    shadow(S, P, 48, 14)
    begin_group(S, P)
    rust, dark = "#D9783A", "#8A4A2A"
    hop = abs(math.sin(P.t * 6.28)) * 6 if P.anim == "walk" else 0
    for k, (ox, side) in enumerate(((-26, 0), (-8, 1), (14, 0), (32, 1))):
        ph = P.step if (k % 2 == 0) else -P.step
        fx, fy = cx + ox + ph * 8, gy - max(0, ph) * 6
        limb(S, (cx + ox, gy - 28 + P.bob), (fx, fy - 2), 9, dark)
        S.ellipse(fx, fy, 8, 5, "#3A3446", sw=3)
    by = gy - 44 + P.bob - hop
    S.ellipse(cx, by, 50, 28, S.radial(lighten(rust, 0.3), rust, 1, 1), sw=5)
    # criniera a ciuffi
    for i in range(5):
        x = cx - 34 + i * 16
        S.poly([(x - 8, by - 22), (x, by - 40 - (i % 2) * 6), (x + 8, by - 22)], "#5B3A2C", sw=3)
    # testa (verso avanti)
    hx = cx + 38 + P.lunge * 0.4
    hy = by + 4
    if P.back:
        S.circle(cx - 46, by - 2, 7, "#E8A0A0", sw=3)   # codina
    S.ellipse(hx, hy, 26, 22, S.radial(lighten(rust, 0.4), rust, 1, 1), sw=5)
    S.ellipse(hx + 14, hy + 8, 13, 9, "#F0B090", sw=3.5)
    S.circle(hx + 12, hy + 7, 2.5, INK, stroke=None)
    S.circle(hx + 19, hy + 8, 2.5, INK, stroke=None)
    if not P.back:
        eyes(S, hx - 4, hy - 8, 8, 5, (3, 1))
    S.poly([(hx + 6, hy + 14), (hx + 14, hy + 30), (hx + 20, hy + 12)], "#FFF3D6", sw=3.5)
    S.poly([(hx + 20, hy + 12), (hx + 32, hy + 26), (hx + 30, hy + 8)], "#FFF3D6", sw=3.5)
    # elmo ad ingranaggio
    S.path(f"M {hx - 24:.1f},{hy - 8:.1f} A 24 20 0 0 1 {hx + 22:.1f},{hy - 10:.1f} Z", "#8A8AA0", sw=4.5)
    S.cog(hx - 2, hy - 28, 12, C["amber"], 7, 3)
    S.poly([(hx - 22, hy - 4), (hx - 36, hy - 12), (hx - 26, hy - 20)], rust, sw=3.5)  # orecchio
    end_group(S)
    death_fx(S, P)


def t_kitewing(S, P):
    cx, gy = P.cx, P.gy
    hover = 42 + P.fly
    shadow(S, P, 24, 8, hover)
    begin_group(S, P)
    base = gy - hover
    col = "#C9E84A"
    sw = math.sin((P.t if P.anim == "walk" else P.f * 0.3) * 6.28) * 14
    # coda a nastri con fiocchi
    pts = [(cx, base + 34), (cx - 8 + sw, base + 54), (cx + 8 + sw * 1.4, base + 74), (cx - 6 + sw * 1.8, base + 92)]
    S.path("M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in pts), "none", sw=7)
    S.path("M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in pts), "none", stroke=C["coral"], sw=3)
    for (x, y) in pts[1:]:
        S.poly([(x, y), (x - 11, y - 6), (x - 11, y + 6)], C["amber"], sw=2.5)
        S.poly([(x, y), (x + 11, y - 6), (x + 11, y + 6)], C["amber"], sw=2.5)
    # ali sbattenti
    flap = math.sin((P.t if P.anim == "walk" else P.f * 0.5) * 6.28 * 2) * 14
    for side in (-1, 1):
        S.poly([(cx + side * 12, base - 6), (cx + side * 50, base - 22 - flap), (cx + side * 46, base + 8 - flap * 0.5), (cx + side * 14, base + 12)],
               S.grad("#F0FF9A", "#9ACA2A"), sw=4)
    # corpo a rombo (aquilone)
    S.poly([(cx, base - 44), (cx + 30, base - 6), (cx, base + 38), (cx - 30, base - 6)], S.grad("#F3FF9D", col), sw=5)
    S.line((cx, base - 44), (cx, base + 38), "#7AA21E", 3, 0.6)
    S.line((cx - 30, base - 6), (cx + 30, base - 6), "#7AA21E", 3, 0.6)
    if not P.back:
        eyes(S, cx, base - 10, 8, 6, (2, 1))
        S.poly([(cx - 5, base + 6), (cx + 5, base + 6), (cx, base + 14)], "#F28A2E", sw=2.5)
    end_group(S)
    death_fx(S, P)


def t_mender(S, P):
    cx, gy = P.cx, P.gy
    hover = 38 + P.fly
    shadow(S, P, 36, 11, hover)
    begin_group(S, P)
    base = gy - hover
    col = "#FF9EC4"
    # cestino appeso
    for dx in (-18, 18):
        S.line((cx + dx, base + 22), (cx + dx * 0.6, base + 48), INK, 4)
    S.poly([(cx - 22, base + 46), (cx + 22, base + 46), (cx + 16, base + 68), (cx - 16, base + 68)], "#C98A3C", sw=4.5)
    S.circle(cx, base + 52, 9, C["sap"], sw=3)
    S.line((cx, base + 47), (cx, base + 57), "#FFFFFF", 3)
    S.line((cx - 5, base + 52), (cx + 5, base + 52), "#FFFFFF", 3)
    # mongolfiera-lanterna
    S.path(f"M {cx:.1f},{base - 78:.1f} C {cx + 66:.1f},{base - 76:.1f} {cx + 58:.1f},{base + 20:.1f} {cx:.1f},{base + 26:.1f} C {cx - 58:.1f},{base + 20:.1f} {cx - 66:.1f},{base - 76:.1f} {cx:.1f},{base - 78:.1f} Z",
           S.radial("#FFE6F0", col, 1, 1), sw=5)
    for dx in (-26, 26):
        S.path(f"M {cx:.1f},{base - 78:.1f} Q {cx + dx * 1.5:.1f},{base - 26:.1f} {cx + dx * 0.4:.1f},{base + 26:.1f}", "none", stroke="#E0709C", sw=3, op=0.7)
    if not P.back:
        # croce di guarigione
        S.poly([(cx - 8, base - 40), (cx + 8, base - 40), (cx + 8, base - 26), (cx + 22, base - 26), (cx + 22, base - 12),
                (cx + 8, base - 12), (cx + 8, base + 2), (cx - 8, base + 2), (cx - 8, base - 12), (cx - 22, base - 12), (cx - 22, base - 26), (cx - 8, base - 26)],
               C["sap"], sw=4)
        eyes(S, cx, base - 56, 12, 6, (2, 1))
    # elichetta
    prop = P.fly * 3
    S.line((cx, base - 78), (cx, base - 90), INK, 6)
    S.ellipse(cx, base - 92, 22 + abs(prop) * 0.6, 4, "#FFF3D6", sw=3)
    # alone di cura quando attacca (= cura)
    if P.anim == "attack" and P.f in (1, 2):
        S.circle(cx, base - 20, 62 + P.f * 6, "none", stroke=C["sap"], sw=4, op=0.5)
    end_group(S)
    death_fx(S, P)


def t_dirigible(S, P):
    cx, gy = P.cx, P.gy
    hover = 64 + P.fly
    shadow(S, P, 66, 15, hover)
    begin_group(S, P)
    base = gy - hover
    cream, red = "#FFF0D0", C["coral"]
    # pinne
    S.poly([(cx - 76, base - 4), (cx - 108, base - 40), (cx - 98, base + 6)], red, sw=4.5)
    S.poly([(cx - 76, base + 8), (cx - 108, base + 38), (cx - 94, base + 12)], darken(red, 0.2), sw=4.5)
    # gondola
    S.poly([(cx - 30, base + 52), (cx + 30, base + 52), (cx + 24, base + 76), (cx - 24, base + 76)], "#8A5A3C", sw=4.5)
    for dx in (-18, 0, 18):
        S.circle(cx + dx, base + 62, 5, "#FFE8A0", sw=2.5)
    for dx in (-26, 26):
        S.line((cx + dx, base + 40), (cx + dx * 0.9, base + 52), INK, 5)
    # scafo
    S.ellipse(cx, base, 82, 48, S.radial("#FFFFFF", cream, 1, 1), sw=5.5)
    for dx in (-48, -16, 16, 48):
        S.path(f"M {cx + dx:.1f},{base - 44:.1f} Q {cx + dx * 1.15:.1f},{base:.1f} {cx + dx:.1f},{base + 44:.1f}", "none", stroke=red, sw=8)
    S.ellipse(cx - 28, base - 22, 22, 9, "#FFFFFF", stroke=None, op=0.55)
    if not P.back:
        eyes(S, cx + 38, base - 8, 8, 6, (3, 1))   # faccia sul muso
        S.ellipse(cx + 56, base + 8, 6, 3, "#C07050", stroke=None)
    # elica
    spin = (P.t if P.anim == "walk" else P.f * 0.4) * 6.28 * 3
    S.line((cx - 82, base), (cx - 94, base), INK, 6)
    S.ellipse(cx - 96, base, 6, 26 * abs(math.cos(spin)) + 4, "#FFF3D6", sw=3.5)
    # bombe
    for i, dx in enumerate((-12, 12)):
        drop = 0
        if P.anim == "attack":
            drop = [0, 6, 20, 0][P.f] if i == 0 else [0, 0, 6, 0][P.f]
        S.circle(cx + dx, base + 82 + drop, 9, "#3A3446", sw=3.5)
        S.line((cx + dx, base + 74 + drop), (cx + dx, base + 78 + drop), INK, 3)
    end_group(S)
    death_fx(S, P)


def t_ember_warden(S, P):
    cx, gy = P.cx, P.gy
    shadow(S, P, 52, 15)
    begin_group(S, P)
    armor, glow = "#4A3A68", "#FF8A2A"
    # mantello a brace (dietro)
    wave = math.sin((P.t if P.anim == "walk" else P.f * 0.4) * 6.28) * 8
    S.path(f"M {cx - 38:.1f},{gy - 118:.1f} Q {cx - 62:.1f},{gy - 50 + wave:.1f} {cx - 48:.1f},{gy - 8:.1f} L {cx + 48:.1f},{gy - 8:.1f} Q {cx + 62:.1f},{gy - 50 - wave:.1f} {cx + 38:.1f},{gy - 118:.1f} Z",
           S.grad("#FF8A2A", "#B8301E"), sw=4.5)
    if P.back:
        S.glow(cx, gy - 60, 44, glow, 0.45)
    legs(S, P, "#3A2C54", "#2A2038", 11, 22, 14, bootr=10)
    by = gy - 74 + P.bob
    S.poly([(cx - 36, by - 40), (cx + 36, by - 40), (cx + 30, by + 22), (cx - 30, by + 22)], S.grad(lighten(armor, 0.3), darken(armor, 0.2)), sw=5)
    if not P.back:
        for yy in (by - 20, by - 2, by + 14):
            S.line((cx - 24, yy), (cx + 24, yy), glow, 3.5, 0.9)
        S.glow(cx, by - 8, 26, glow, 0.5)
    S.ellipse(cx - 44, by - 40, 18, 12, armor, sw=4.5)     # spallacci
    S.ellipse(cx + 44, by - 40, 18, 12, armor, sw=4.5)
    hy = by - 62
    S.circle(cx, hy, 26, S.radial(lighten(armor, 0.35), armor, 1, 1), sw=5)
    if not P.back:
        S.poly([(cx - 20, hy - 4), (cx + 20, hy - 4), (cx + 16, hy + 6), (cx - 16, hy + 6)], "#1E1626", sw=3)
        S.circle(cx - 8, hy + 1, 3.5, glow, stroke=None)
        S.circle(cx + 8, hy + 1, 3.5, glow, stroke=None)
    # corna e cresta di brace
    S.poly([(cx - 22, hy - 14), (cx - 40, hy - 40), (cx - 14, hy - 24)], "#F2E3C6", sw=3.5)
    S.poly([(cx + 22, hy - 14), (cx + 40, hy - 40), (cx + 14, hy - 24)], "#F2E3C6", sw=3.5)
    S.path(f"M {cx - 8:.1f},{hy - 24:.1f} Q {cx:.1f},{hy - 58 - wave * 0.5:.1f} {cx + 8:.1f},{hy - 24:.1f} Z", glow, sw=3.5)
    # bastone-lanterna
    ang = math.radians(P.swing * 0.7)
    sx0, sy0 = cx + 52 + P.lunge * 0.5, by + 16
    sx1, sy1 = sx0 + math.sin(ang) * 20, sy0 - 108
    limb(S, (sx0, sy0), (sx1, sy1), 8, "#8A5A3C")
    S.circle(cx + 40, by - 20, 11, armor, sw=4)
    S.glow(sx1, sy1 - 6, 38, glow, 0.7)
    S.poly([(sx1 - 14, sy1 - 18), (sx1 + 14, sy1 - 18), (sx1 + 12, sy1 + 10), (sx1 - 12, sy1 + 10)], S.radial("#FFF3A8", glow, 1, 1), sw=4)
    S.line((sx1 - 14, sy1 - 18), (sx1, sy1 - 28), INK, 4)
    S.line((sx1 + 14, sy1 - 18), (sx1, sy1 - 28), INK, 4)
    # attacco: onda di brace
    if P.anim == "attack" and P.f in (1, 2):
        S.path(f"M {sx1 - 40:.1f},{sy1 + 40:.1f} Q {sx1 + 20:.1f},{sy1 + 110:.1f} {sx1 + 70:.1f},{sy1 + 40:.1f}", "none", stroke=glow, sw=10, op=0.8)
    end_group(S)
    death_fx(S, P)


DRAW = {"cogling": t_cogling, "slingwisp": t_slingwisp, "bulwark": t_bulwark, "magpie": t_magpie, "kegger": t_kegger,
        "rustjaw": t_rustjaw, "kitewing": t_kitewing, "mender": t_mender, "dirigible": t_dirigible, "ember_warden": t_ember_warden}

ANIMS = [("walk", WALK_FRAMES), ("attack", ATK_FRAMES), ("death", DEATH_FRAMES)]


def render_frame(troop, anim, f, back):
    W, H, gy = SIZES[troop]
    P = Pose(anim, f, back, W, H, gy, troop in FLYING)
    S = Scene(W, H, 0, 0)
    DRAW[troop](S, P)
    return render(S)


def render_sheet(troop):
    """Foglio unico: righe = walk_down, attack_down, death_down, walk_up, attack_up, death_up; 6 colonne."""
    W, H, gy = SIZES[troop]
    cols = max(n for _, n in ANIMS)
    sheet = Image.new("RGBA", (cols * W, 6 * H), (0, 0, 0, 0))
    meta = dict(frame=[W, H], origin=[W // 2, gy], rows={})
    r = 0
    for back in (False, True):
        for anim, n in ANIMS:
            name = f"{anim}_{'up' if back else 'down'}"
            for f in range(n):
                sheet.alpha_composite(render_frame(troop, anim, f, back), (f * W, r * H))
            meta["rows"][name] = dict(row=r, frames=n, fps={"walk": 12, "attack": 10, "death": 8}[anim], loop=(anim == "walk"))
            r += 1
    return sheet, meta
