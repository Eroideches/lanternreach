"""Kit di disegno condiviso: palette, colori, primitive isometriche SVG, rendering.

Convenzioni (vedi ART_DIRECTION.md):
- Cella isometrica 2:1: rombo di CW x CH = 128 x 64 px (sprite a 2x rispetto alla griglia logica 64x32).
- Luce SEMPRE da in alto a sinistra: faccia superiore piu' chiara/calda, faccia sinistra media,
  faccia destra scura/fredda (ombre virate al viola, luci virate al giallo).
- Contorno prugna morbido (INK) con giunzioni arrotondate.
"""
import colorsys
import io
import math
import os

import cairosvg
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART_SRC = os.path.join(ROOT, "art_src")          # PNG singoli (generati, non versionati)
ATLAS_DIR = os.path.join(ROOT, "assets", "atlas")  # atlas packed (versionati)
CW, CH = 128, 64        # rombo cella
HW, HH = CW / 2, CH / 2
INK = "#2E2036"
OUTLINE = 4.0           # spessore contorno di base (px a 128 di cella)

# ------------------------------------------------------------------ palette
PALETTE = {
    "ink":        "#2E2036",  # contorni, testo scuro
    "parchment":  "#FFF3D6",  # carta, testo chiaro, pannelli
    "amber":      "#FFB62E",  # lanterna, accenti primari, Cogs
    "ember":      "#F0742A",  # arancio fiamma, pulsanti attacco
    "coral":      "#E8604C",  # tetti, allarmi
    "sap":        "#3FD17C",  # risorsa Sap (verde smeraldo)
    "shard":      "#A06BFF",  # Starshards (viola)
    "glimmer":    "#4DE3F5",  # Glimmers (ciano)
    "sky":        "#7CC8F2",  # cielo
    "grass_l":    "#9BD96B",
    "grass_m":    "#6DB852",
    "grass_d":    "#4E9A46",
    "earth_l":    "#C48A57",
    "earth_d":    "#8A5A3C",
    "stone_l":    "#D5CFE3",
    "stone_m":    "#A59CBC",
    "stone_d":    "#6E6788",
    "wood_l":     "#D9A066",
    "wood_d":     "#9C6238",
    "teal":       "#3EA7C9",
}
# Fazione nemica: Marea d'Ombra (viola prugna sporco, bagliore magenta, nessun verde per non confondersi col Sap)
GLOOM = {
    "void":    "#2A2147",
    "mire":    "#4A3558",
    "mire_l":  "#6C4D82",
    "glow":    "#E8419A",
    "bruise":  "#2F7F8F",
    "spore":   "#C9A8FF",
}
# UI
UI = {
    "panel":      "#FFF3D6",
    "panel_edge": "#2E2036",
    "panel_shade":"#E8D3A5",
    "dark_panel": "#3B2A4A",
    "btn_green":  "#4CC05A", "btn_green_d": "#2C8A3E",
    "btn_blue":   "#4AA8E8", "btn_blue_d":  "#2A74B5",
    "btn_red":    "#E8604C", "btn_red_d":   "#A93A2E",
    "btn_gold":   "#FFC53D", "btn_gold_d":  "#C9881A",
    "btn_purple": "#8E6BE0", "btn_purple_d": "#5B3FA6",
    "disabled":   "#B8B0C4", "disabled_d": "#8C849A",
    "text":       "#2E2036", "text_light": "#FFF8E8",
    "hp_green":   "#58D05A", "hp_red": "#EB5A46",
}


# ---------------------------------------------------------------- colori
def h2r(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def r2h(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    ca, cb = h2r(a), h2r(b)
    return r2h([ca[i] + (cb[i] - ca[i]) * t for i in range(3)])


def lighten(c, t):
    """Schiarisce verso un giallo caldo (luce da in alto a sinistra)."""
    return mix(c, "#FFF1B8", t)


def darken(c, t):
    """Scurisce verso un viola freddo (ombre cartoon)."""
    return mix(c, "#3A2358", t)


def faces(base, top_t=0.28, left_t=0.0, right_t=0.34):
    """Terna (top, left, right) di colori per un volume illuminato da in alto a sinistra."""
    return lighten(base, top_t), lighten(base, left_t) if left_t else base, darken(base, right_t)


def hsl_shift(c, dh=0.0, ds=0.0, dl=0.0):
    r, g, b = [v / 255 for v in h2r(c)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    h = (h + dh) % 1
    s = max(0, min(1, s + ds))
    l = max(0, min(1, l + dl))
    return r2h([v * 255 for v in colorsys.hls_to_rgb(h, l, s)])


# ---------------------------------------------------------------- proiezione
def proj(x, y, z=0.0, ox=0.0, oy=0.0):
    """Cella (x,y) e altezza z (px) -> schermo. (0,0) = vertice alto del rombo, x verso destra-giu, y verso sinistra-giu."""
    return (ox + (x - y) * HW, oy + (x + y) * HH - z)


class Scene:
    """Accumulatore di elementi SVG con origine isometrica."""

    def __init__(self, w, h, ox, oy):
        self.w, self.h, self.ox, self.oy = w, h, ox, oy
        self.els = []
        self.defs = []
        self._gid = 0

    # --- primitive di basso livello
    def P(self, x, y, z=0.0):
        return proj(x, y, z, self.ox, self.oy)

    def raw(self, s):
        self.els.append(s)

    def grad(self, c1, c2, vertical=True):
        self._gid += 1
        gid = f"g{self._gid}"
        coords = 'x1="0" y1="0" x2="0" y2="1"' if vertical else 'x1="0" y1="0" x2="1" y2="0"'
        self.defs.append(f'<linearGradient id="{gid}" {coords}><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>')
        return f"url(#{gid})"

    def radial(self, c_in, c_out, a_in=1.0, a_out=0.0):
        self._gid += 1
        gid = f"g{self._gid}"
        self.defs.append(f'<radialGradient id="{gid}"><stop offset="0" stop-color="{c_in}" stop-opacity="{a_in}"/><stop offset="1" stop-color="{c_out}" stop-opacity="{a_out}"/></radialGradient>')
        return f"url(#{gid})"

    def poly(self, pts, fill, stroke=INK, sw=OUTLINE, op=1.0, join="round"):
        d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="{join}" stroke-linecap="round"' if stroke else ""
        self.els.append(f'<polygon points="{d}" fill="{fill}"{st} opacity="{op}"/>')

    def path(self, d, fill="none", stroke=INK, sw=OUTLINE, op=1.0):
        st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
        self.els.append(f'<path d="{d}" fill="{fill}"{st} opacity="{op}"/>')

    def circle(self, cx, cy, r, fill, stroke=INK, sw=OUTLINE, op=1.0):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.els.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}"{st} opacity="{op}"/>')

    def ellipse(self, cx, cy, rx, ry, fill, stroke=INK, sw=OUTLINE, op=1.0):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.els.append(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}"{st} opacity="{op}"/>')

    def line(self, a, b, color=INK, sw=OUTLINE, op=1.0):
        self.els.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" opacity="{op}"/>')

    # --- volumi isometrici
    def box(self, x0, y0, x1, y1, z0, z1, base, tops=None, sw=OUTLINE, detail=True):
        """Parallelepipedo. Ritorna dict di punti per usi successivi (finestre, porte)."""
        top_c, left_c, right_c = tops if tops else faces(base)
        P = self.P
        # faccia sinistra (y = y1, lungo x)
        L = [P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)]
        # faccia destra (x = x1, lungo y)
        R = [P(x1, y1, z0), P(x1, y0, z0), P(x1, y0, z1), P(x1, y1, z1)]
        T = [P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)]
        self.poly(L, self.grad(lighten(left_c, 0.12), left_c), sw=sw)
        self.poly(R, self.grad(right_c, darken(right_c, 0.12)), sw=sw)
        self.poly(T, top_c, sw=sw)
        if detail:  # filo di luce sul bordo alto-sinistro
            self.line(P(x0, y1, z1), P(x0, y0, z1), lighten(top_c, 0.6), 2.0, 0.8)
            self.line(P(x0, y0, z1), P(x1, y0, z1), lighten(top_c, 0.6), 2.0, 0.8)
        return dict(L=L, R=R, T=T)

    def face_rect(self, side, x0, y0, x1, y1, z0, z1, u0, u1, v0, v1, fill, stroke=INK, sw=3.0, op=1.0):
        """Rettangolo applicato su una faccia ('L' o 'R'); u,v in [0,1] (u orizzontale, v verticale in px relativi)."""
        P = self.P
        if side == "L":
            xa, xb = x0 + (x1 - x0) * u0, x0 + (x1 - x0) * u1
            pts = [P(xa, y1, z0 + v0), P(xb, y1, z0 + v0), P(xb, y1, z0 + v1), P(xa, y1, z0 + v1)]
        else:
            ya, yb = y1 + (y0 - y1) * u0, y1 + (y0 - y1) * u1
            pts = [P(x1, ya, z0 + v0), P(x1, yb, z0 + v0), P(x1, yb, z0 + v1), P(x1, ya, z0 + v1)]
        self.poly(pts, fill, stroke=stroke, sw=sw, op=op)
        return pts

    def face_point(self, side, x0, y0, x1, y1, z0, u, v):
        P = self.P
        if side == "L":
            return P(x0 + (x1 - x0) * u, y1, z0 + v)
        return P(x1, y1 + (y0 - y1) * u, z0 + v)

    def pyramid(self, x0, y0, x1, y1, z, h, base, over=0.12, sw=OUTLINE, apex=None):
        """Tetto a piramide con gronda sporgente."""
        P = self.P
        x0, y0, x1, y1 = x0 - over, y0 - over, x1 + over, y1 + over
        ax, ay = apex if apex else ((x0 + x1) / 2, (y0 + y1) / 2)
        top_c, left_c, right_c = faces(base, 0.3, 0.05, 0.3)
        A = P(ax, ay, z + h)
        L = [P(x0, y1, z), P(x1, y1, z), A]
        R = [P(x1, y1, z), P(x1, y0, z), A]
        self.poly(L, self.grad(lighten(left_c, 0.15), left_c), sw=sw)
        self.poly(R, self.grad(right_c, darken(right_c, 0.1)), sw=sw)
        self.line(P(x0, y1, z), A, lighten(top_c, 0.5), 2.0, 0.7)
        return A

    def hip_roof(self, x0, y0, x1, y1, z, h, base, ridge="x", over=0.1, sw=OUTLINE):
        """Tetto a due falde (con ridge lungo x o y)."""
        P = self.P
        x0, y0, x1, y1 = x0 - over, y0 - over, x1 + over, y1 + over
        top_c, left_c, right_c = faces(base, 0.3, 0.05, 0.3)
        if ridge == "x":
            ym = (y0 + y1) / 2
            r0, r1 = P(x0, ym, z + h), P(x1, ym, z + h)
            front = [P(x0, y1, z), P(x1, y1, z), r1, r0]
            back = [P(x0, y0, z), P(x1, y0, z), r1, r0]
            self.poly(back, darken(base, 0.1), sw=sw)
            self.poly(front, self.grad(lighten(left_c, 0.15), left_c), sw=sw)
            gab = [P(x1, y1, z), P(x1, y0, z), r1]
            self.poly(gab, self.grad(right_c, darken(right_c, 0.1)), sw=sw)
        else:
            xm = (x0 + x1) / 2
            r0, r1 = P(xm, y0, z + h), P(xm, y1, z + h)
            front = [P(x1, y0, z), P(x1, y1, z), r1, r0]
            back = [P(x0, y0, z), P(x0, y1, z), r1, r0]
            self.poly(back, lighten(base, 0.1), sw=sw)
            self.poly(front, self.grad(right_c, darken(right_c, 0.1)), sw=sw)
            gab = [P(x0, y1, z), P(x1, y1, z), r1]
            self.poly(gab, self.grad(lighten(left_c, 0.15), left_c), sw=sw)

    def cylinder(self, cx, cy, r, z0, z1, base, sw=OUTLINE, top=True):
        """Cilindro verticale con asse in (cx,cy), raggio r in celle (ellisse in iso)."""
        P = self.P
        sx, sy = P(cx, cy, 0)
        rx, ry = r * CW / 2 * 1.0, r * CH / 2 * 1.0
        top_c, left_c, right_c = faces(base, 0.3, 0.08, 0.3)
        yb, yt = sy - z0, sy - z1
        gid = self.grad(lighten(base, 0.18), darken(base, 0.28), vertical=False)
        d = (f"M {sx - rx:.1f},{yt:.1f} A {rx:.1f},{ry:.1f} 0 0 0 {sx + rx:.1f},{yt:.1f} "
             f"L {sx + rx:.1f},{yb:.1f} A {rx:.1f},{ry:.1f} 0 0 1 {sx - rx:.1f},{yb:.1f} Z")
        self.path(d, gid, sw=sw)
        if top:
            self.ellipse(sx, yt, rx, ry, top_c, sw=sw)
        return (sx, yt, rx, ry)

    def cone(self, cx, cy, r, z0, h, base, sw=OUTLINE):
        sx, sy = self.P(cx, cy, 0)
        rx, ry = r * HW, r * HH
        gid = self.grad(lighten(base, 0.22), darken(base, 0.3), vertical=False)
        yb, ya = sy - z0, sy - z0 - h
        d = f"M {sx - rx:.1f},{yb:.1f} A {rx:.1f},{ry:.1f} 0 0 0 {sx + rx:.1f},{yb:.1f} L {sx:.1f},{ya:.1f} Z"
        self.path(d, gid, sw=sw)
        return (sx, ya)

    def sphere(self, sx, sy, r, base, sw=OUTLINE, glow=False):
        gid = self.radial(lighten(base, 0.5), base, 1, 1)
        self._gid += 1
        self.circle(sx, sy, r, gid if not glow else gid, sw=sw)
        # riflesso in alto a sinistra
        self.ellipse(sx - r * 0.35, sy - r * 0.38, r * 0.25, r * 0.17, "#FFFFFF", stroke=None, op=0.55)

    def glow(self, sx, sy, r, color, a=0.8):
        self.circle(sx, sy, r, self.radial(color, color, a, 0.0), stroke=None)

    def cog(self, sx, sy, r, color, teeth=8, sw=3.0, rot=0.0, hole=True):
        pts = []
        n = teeth * 2
        for i in range(n * 2):
            ang = rot + math.pi * 2 * i / (n * 2)
            rr = r if (i // 2) % 2 == 0 else r * 0.76
            pts.append((sx + math.cos(ang) * rr, sy + math.sin(ang) * rr))
        self.poly(pts, color, sw=sw)
        if hole:
            hc = darken(color, 0.45) if color.startswith("#") else "#8A5A2A"
            self.circle(sx, sy, r * 0.32, hc, sw=sw * 0.8)

    def ground_diamond(self, x0, y0, x1, y1, fill, stroke=None, sw=2.0, op=1.0):
        P = self.P
        self.poly([P(x0, y0), P(x1, y0), P(x1, y1), P(x0, y1)], fill, stroke=stroke, sw=sw, op=op)

    def svg(self, scale=1.0):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w * scale}" height="{self.h * scale}" viewBox="0 0 {self.w} {self.h}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.els)}</svg>')


# ------------------------------------------------------------- rendering
def render(scene_or_svg, scale=1.0):
    svg = scene_or_svg.svg(scale) if isinstance(scene_or_svg, Scene) else scene_or_svg
    png = cairosvg.svg2png(bytestring=svg.encode("utf-8"))
    return Image.open(io.BytesIO(png)).convert("RGBA")


def soft_shadow(size, polygon, blur=10, opacity=0.38, color=(46, 32, 54)):
    """Ombra morbida: poligono (px) sfocato. Ritorna immagine RGBA di `size`."""
    m = Image.new("L", size, 0)
    from PIL import ImageDraw
    ImageDraw.Draw(m).polygon(polygon, fill=int(255 * opacity))
    m = m.filter(ImageFilter.GaussianBlur(blur))
    img = Image.new("RGBA", size, color + (0,))
    img.putalpha(m)
    return img


def ensure(*parts):
    p = os.path.join(*parts)
    os.makedirs(p, exist_ok=True)
    return p


def bbox_trim(img, pad=2):
    bb = img.getbbox()
    if not bb:
        return img, (0, 0)
    l, t, r, b = bb
    l, t, r, b = max(0, l - pad), max(0, t - pad), min(img.width, r + pad), min(img.height, b + pad)
    return img.crop((l, t, r, b)), (l, t)
