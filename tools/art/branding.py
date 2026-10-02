"""Icona app (legacy + adaptive Android), logo e splash screen."""
import math

from PIL import Image

from common import INK, PALETTE as C, Scene, render, lighten, darken, mix


def lantern(S, cx, cy, s=1.0, glow=True):
    """La lanterna-faro simbolo del gioco."""
    if glow:
        S.glow(cx, cy, 150 * s, C["amber"], 0.55)
    # anello di aggancio
    S.circle(cx, cy - 92 * s, 16 * s, "none", stroke=INK, sw=9 * s)
    S.circle(cx, cy - 92 * s, 16 * s, "none", stroke=C["amber"], sw=4 * s)
    # cappello
    S.poly([(cx - 62 * s, cy - 50 * s), (cx, cy - 86 * s), (cx + 62 * s, cy - 50 * s)], S.grad("#FF8A76", C["coral"]), sw=8 * s)
    S.poly([(cx - 52 * s, cy - 54 * s), (cx + 52 * s, cy - 54 * s), (cx + 50 * s, cy - 40 * s), (cx - 50 * s, cy - 40 * s)], "#D9961E", sw=7 * s)
    # vetro con fiamma
    S.poly([(cx - 46 * s, cy - 40 * s), (cx + 46 * s, cy - 40 * s), (cx + 40 * s, cy + 46 * s), (cx - 40 * s, cy + 46 * s)], S.radial("#FFFBE0", "#FFC24A", 1, 1), sw=8 * s)
    S.path(f"M {cx - 20 * s:.1f},{cy + 26 * s:.1f} Q {cx - 26 * s:.1f},{cy - 6 * s:.1f} {cx:.1f},{cy - 28 * s:.1f} Q {cx + 26 * s:.1f},{cy - 6 * s:.1f} {cx + 20 * s:.1f},{cy + 26 * s:.1f} Q {cx:.1f},{cy + 40 * s:.1f} {cx - 20 * s:.1f},{cy + 26 * s:.1f} Z",
           C["ember"], sw=5 * s)
    S.path(f"M {cx - 9 * s:.1f},{cy + 24 * s:.1f} Q {cx - 10 * s:.1f},{cy + 4 * s:.1f} {cx:.1f},{cy - 8 * s:.1f} Q {cx + 10 * s:.1f},{cy + 4 * s:.1f} {cx + 9 * s:.1f},{cy + 24 * s:.1f} Z", "#FFF3A8", stroke=None)
    for dx in (-24, 24):
        S.line((cx + dx * s, cy - 40 * s), (cx + dx * 0.88 * s, cy + 46 * s), INK, 5 * s)
    # base
    S.poly([(cx - 52 * s, cy + 46 * s), (cx + 52 * s, cy + 46 * s), (cx + 58 * s, cy + 64 * s), (cx - 58 * s, cy + 64 * s)], "#D9961E", sw=7 * s)
    # ingranaggio dietro (identita' Cogs)
    S.ellipse(cx - 30 * s, cy - 18 * s, 8 * s, 18 * s, "#FFFFFF", stroke=None, op=0.5)


def app_icon_layers():
    """Adaptive icon: background 432 + foreground 432 (contenuto nel cerchio sicuro di 264 px)."""
    bg = Scene(432, 432, 0, 0)
    bg.raw('<rect x="0" y="0" width="432" height="432" fill="url(#bgg)"/>')
    bg.defs.append('<radialGradient id="bgg" cx="0.5" cy="0.42" r="0.7"><stop offset="0" stop-color="#5FB8EE"/><stop offset="1" stop-color="#2E4C9A"/></radialGradient>')
    # isoletta sospesa
    bg.ellipse(216, 330, 170, 40, "#4E9A46", stroke=None, op=0.9)
    fg = Scene(432, 432, 0, 0)
    fg.cog(150, 268, 54, S_grad(fg, "#FFE17A", "#D9961E"), 9, 7)
    lantern(fg, 222, 226, 1.15)
    return render(bg), render(fg)


def S_grad(S, a, b):
    return S.grad(a, b)


def app_icon(size):
    bg, fg = app_icon_layers()
    img = Image.alpha_composite(bg, fg)
    # forma squircle per icona legacy
    mask = Image.new("L", (432, 432), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 431, 431), radius=96, fill=255)
    out = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def wordmark(w=1200, h=300, text="Lanternreach"):
    S = Scene(w, h, 0, 0)
    S.defs.append('<linearGradient id="wm" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF3A8"/><stop offset="0.55" stop-color="#FFB62E"/><stop offset="1" stop-color="#F0742A"/></linearGradient>')
    style = 'font-family="Lilita One" font-size="190" text-anchor="middle"'
    S.raw(f'<text x="{w / 2}" y="{h * 0.72 + 12}" {style} fill="#2E2036" stroke="#2E2036" stroke-width="34" stroke-linejoin="round">{text}</text>')
    S.raw(f'<text x="{w / 2}" y="{h * 0.72}" {style} fill="#2E2036" stroke="#2E2036" stroke-width="28" stroke-linejoin="round">{text}</text>')
    S.raw(f'<text x="{w / 2}" y="{h * 0.72}" {style} fill="url(#wm)" stroke="#FFF3D6" stroke-width="5" stroke-linejoin="round" paint-order="stroke">{text}</text>')
    return render(S)


def splash(w=1920, h=1080):
    S = Scene(w, h, 0, 0)
    S.defs.append('<linearGradient id="sk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3F7FD8"/><stop offset="0.65" stop-color="#8FD0F5"/><stop offset="1" stop-color="#FFE3B0"/></linearGradient>')
    S.raw(f'<rect x="0" y="0" width="{w}" height="{h}" fill="url(#sk)"/>')
    # nuvole
    for (x, y, r) in ((260, 300, 70), (330, 280, 90), (420, 310, 64), (1560, 220, 80), (1650, 200, 100), (1750, 240, 70), (1180, 820, 60), (1260, 800, 80)):
        S.circle(x, y, r, "#FFFFFF", stroke=None, op=0.85)
    # isola sospesa con faro
    cx, cy = w / 2, 640
    S.path(f"M {cx - 420},{cy} Q {cx},{cy - 90} {cx + 420},{cy} Q {cx + 300},{cy + 160} {cx + 80},{cy + 330} Q {cx},{cy + 380} {cx - 70},{cy + 320} Q {cx - 300},{cy + 160} {cx - 420},{cy} Z",
           S.grad(C["earth_l"], "#5B3A2C"), sw=8)
    S.path(f"M {cx - 420},{cy} Q {cx},{cy - 90} {cx + 420},{cy} Q {cx},{cy + 70} {cx - 420},{cy} Z", S.grad(C["grass_l"], C["grass_d"]), sw=8)
    lantern(S, cx, cy - 190, 2.1)
    for (x, s) in ((cx - 260, 0.5), (cx + 250, 0.55)):
        S.circle(x, cy - 30, 40 * s * 2, C["grass_m"], sw=6)
    img = render(S)
    wm = wordmark(1300, 300)
    img.alpha_composite(wm, ((w - wm.width) // 2, 70))
    return img
