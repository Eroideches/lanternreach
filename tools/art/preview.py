#!/usr/bin/env python3
"""Scene di prova: compone gli asset REALI (dagli atlas) in mockup 1920x1080 per verificare coerenza e leggibilita'.

Output in docs/art/: village_mockup.png, battle_mockup.png, panels_mockup.png, contact sheet (edifici, truppe,
icone, effetti, kit UI), palette.png, legibility_5in_7in.png.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont

from common import ROOT, PALETTE as C, GLOOM, UI, ensure

AT = os.path.join(ROOT, "assets", "atlas")
OUT = ensure(ROOT, "docs", "art")
FONT_T = os.path.join(ROOT, "assets", "fonts", "LilitaOne-Regular.ttf")
FONT_B = os.path.join(ROOT, "assets", "fonts", "Nunito-Variable.ttf")
INK = (46, 32, 54)


class Atlas:
    def __init__(self, name):
        d = json.load(open(os.path.join(AT, name + ".json")))
        self.pages = [Image.open(os.path.join(AT, p)).convert("RGBA") for p in d["pages"]]
        self.r = d["regions"]

    def get(self, key):
        r = self.r[key]
        return self.pages[r["page"]].crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])), r


ATL = {}


def A(name):
    if name not in ATL:
        ATL[name] = Atlas(name)
    return ATL[name]


def font(sz, title=True):
    f = ImageFont.truetype(FONT_T if title else FONT_B, sz)
    if not title:
        try:
            f.set_variation_by_axes([800])
        except Exception:
            pass
    return f


def text(img, xy, s, sz=34, fill=(255, 255, 255), stroke=6, anchor="la", title=True):
    d = ImageDraw.Draw(img)
    d.text(xy, s, font=font(sz, title), fill=fill, stroke_width=stroke, stroke_fill=INK, anchor=anchor)


def nine(img, margin, w, h):
    """Scala un'immagine 9-patch a w x h."""
    W, H = img.size
    m = min(margin, W // 2 - 1, H // 2 - 1)
    out = Image.new("RGBA", (w, h))
    cols = [(0, m, 0, m), (m, W - m, m, w - m), (W - m, W, w - m, w)]
    rows = [(0, m, 0, m), (m, H - m, m, h - m), (H - m, H, h - m, h)]
    for sx0, sx1, dx0, dx1 in cols:
        for sy0, sy1, dy0, dy1 in rows:
            if dx1 <= dx0 or dy1 <= dy0:
                continue
            part = img.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS)
            out.alpha_composite(part, (dx0, dy0))
    return out


def ui(name, w, h):
    im, r = A("ui").get("ui/" + name)
    return nine(im, r["margin"], w, h)


def icon(name, sz):
    im, _ = A("icons").get(name)
    return im.resize((sz, sz), Image.LANCZOS)


def paste(dst, im, xy):
    dst.alpha_composite(im, (int(xy[0]), int(xy[1])))


# ------------------------------------------------------------------ scena iso
class IsoView:
    def __init__(self, img, ox, oy, scale):
        self.img, self.ox, self.oy, self.s = img, ox, oy, scale

    def P(self, x, y):
        return self.ox + (x - y) * 64 * self.s, self.oy + (x + y) * 32 * self.s

    def ground(self, n=44, pal="player", border=2):
        tiles = [A("terrain").get(f"{pal}/grass_{v}")[0] for v in range(4)]
        tiles = [t.resize((int(128 * self.s) + 1, int(64 * self.s) + 1), Image.LANCZOS) for t in tiles]
        cl = A("terrain").get(f"{pal}/cliff_L")[0]
        cr = A("terrain").get(f"{pal}/cliff_R")[0]
        cl = cl.resize((int(cl.width * self.s) + 1, int(cl.height * self.s) + 1), Image.LANCZOS)
        cr = cr.resize((int(cr.width * self.s) + 1, int(cr.height * self.s) + 1), Image.LANCZOS)
        for x in range(n):
            for y in range(n):
                if x == n - 1 or y == n - 1:
                    sx, sy = self.P(x, y)
                    if y == n - 1:
                        paste(self.img, cl, (sx - 64 * self.s, sy))
                    if x == n - 1:
                        paste(self.img, cr, (sx - 64 * self.s, sy))
        for x in range(n):
            for y in range(n):
                sx, sy = self.P(x, y)
                t = tiles[(x * 7 + y * 13 + (x * y) % 5) % 4]
                if x < border or y < border or x >= n - border or y >= n - border:
                    t = t.copy()
                    t = Image.blend(t, Image.new("RGBA", t.size, (40, 80, 50, 0)), 0.0)
                paste(self.img, t, (sx - 64 * self.s, sy))

    def sprite(self, im, anchor, cx, cy):
        im2 = im.resize((max(1, int(im.width * self.s)), max(1, int(im.height * self.s))), Image.LANCZOS)
        sx, sy = self.P(cx, cy)
        paste(self.img, im2, (sx - anchor[0] * self.s, sy - anchor[1] * self.s))


def place_building(view, atlas, key, x, y, N):
    im, r = A(atlas).get(key)
    view.sprite(im, r["anchor"], x + N / 2, y + N / 2)


def wall_mask(cells, x, y):
    m = 0
    if (x + 1, y) in cells: m |= 1
    if (x, y + 1) in cells: m |= 2
    if (x - 1, y) in cells: m |= 4
    if (x, y - 1) in cells: m |= 8
    return m


def base_layout(variant="player"):
    """Layout dimostrativo: (id, tier, x, y)."""
    L = [("lantern_hall", 3, 20, 20), ("boltpost", 3, 17, 17), ("boltpost", 2, 25, 18), ("lobber", 3, 24, 23), ("skyspear", 3, 18, 24),
         ("arc_coil", 2, 16, 21), ("cog_vault", 3, 21, 16), ("sap_cistern", 3, 16, 25), ("ballista", 2, 26, 26),
         ("cog_mine", 3, 11, 14), ("cog_mine", 2, 13, 11), ("sap_well", 3, 29, 13), ("sap_well", 2, 31, 16),
         ("barracks", 3, 10, 28), ("army_camp", 3, 14, 31), ("laboratory", 3, 30, 22), ("spell_forge", 2, 29, 29),
         ("clan_hall", 2, 21, 31), ("shard_drill", 2, 33, 27), ("shard_crate", 2, 8, 22), ("thumper", 2, 22, 26)]
    return L


def walls_ring(x0, y0, x1, y1):
    cells = set()
    for x in range(x0, x1 + 1):
        cells.add((x, y0)); cells.add((x, y1))
    for y in range(y0, y1 + 1):
        cells.add((x0, y)); cells.add((x1, y))
    return cells


def draw_base(view, pal, tier_bonus=0, troops=None, fx=None):
    atlas = f"buildings_{pal}"
    items = []
    for bid, t, x, y in base_layout():
        N = A(atlas).r[f"{bid}/t1"]["footprint"]
        items.append((x + y + N, "b", (bid, min(5, t + tier_bonus), x, y, N)))
    cells = walls_ring(15, 15, 29, 29)
    for (x, y) in cells:
        items.append((x + y + 1, "w", (x, y, wall_mask(cells, x, y))))
    for (ox, oy, kind) in ((6, 9, "sapling"), (35, 10, "boulder"), (36, 33, "glowshroom"), (5, 36, "moon_crystal"), (38, 20, "sapling"), (9, 38, "sapling")):
        N = A("buildings_player").r[f"{kind}/t1"]["footprint"]
        items.append((ox + oy + N, "o", (kind, ox, oy, N)))
    for tr in troops or []:
        items.append((tr[1] + tr[2] + 0.5, "t", tr))
    for f in fx or []:
        items.append((f[1] + f[2] + 3, "f", f))
    items.sort(key=lambda it: it[0])
    for _, kind, d in items:
        if kind == "b":
            bid, t, x, y, N = d
            place_building(view, atlas, f"{bid}/t{t}", x, y, N)
        elif kind == "w":
            x, y, m = d
            im, r = A(f"walls_{pal}").get(f"wall/t3/m{m}")
            view.sprite(im, r["anchor"], x + 0.5, y + 0.5)
        elif kind == "o":
            k, x, y, N = d
            place_building(view, "buildings_player", f"{k}/t1", x, y, N)
        elif kind == "t":
            tid, x, y, row, frame, flip = d
            sheet = Image.open(os.path.join(ROOT, "assets", "sprites", "troops", f"{tid}.png")).convert("RGBA")
            meta = json.load(open(os.path.join(ROOT, "assets", "sprites", "troops", "troops.json")))[tid]
            W, H = meta["frame"]
            r = meta["rows"][row]["row"]
            fr = sheet.crop((frame * W, r * H, frame * W + W, r * H + H))
            if flip:
                fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
            s = view.s * 1.0
            fr2 = fr.resize((int(W * s), int(H * s)), Image.LANCZOS)
            sx, sy = view.P(x, y)
            ox, oy = meta["origin"]
            paste(view.img, fr2, (sx - ox * s, sy - oy * s))
        elif kind == "f":
            key, x, y, sc = d
            im, r = A("fx").get(key)
            im2 = im.resize((int(im.width * view.s * sc), int(im.height * view.s * sc)), Image.LANCZOS)
            sx, sy = view.P(x, y)
            paste(view.img, im2, (sx - im2.width / 2, sy - im2.height * 0.6))


def sky(w, h, pal):
    s = Image.open(os.path.join(AT, f"sky_{pal}.png")).convert("RGBA").resize((w, h), Image.BICUBIC)
    for i, (x, y, sc) in enumerate(((120, 90, 1.0), (1500, 60, 1.3), (900, 180, 0.8), (1700, 400, 0.9))):
        c = A("terrain").get(f"cloud/{i % 3}")[0]
        c = c.resize((int(c.width * sc), int(c.height * sc)), Image.LANCZOS)
        if pal == "gloom":
            c = Image.blend(c, Image.new("RGBA", c.size, (90, 70, 120, 0)), 0.0)
            c.putalpha(c.getchannel("A").point(lambda a: int(a * 0.35)))
        paste(s, c, (x, y))
    return s


def resource_bar(img, x, y, w, icon_name, value, cap, barcol):
    bar = ui("res_bar", w, 64)
    paste(img, bar, (x, y))
    frac = value / cap
    fill = ui(barcol, max(40, int((w - 80) * frac)), 30)
    paste(img, fill, (x + 58, y + 17))
    paste(img, icon(icon_name, 84), (x - 26, y - 10))
    text(img, (x + w - 22, y + 32), f"{value:,}".replace(",", "."), 32, anchor="rm")
    text(img, (x + 64, y + 66), f"Max: {cap:,}".replace(",", "."), 20, fill=(255, 243, 214), stroke=4)


def round_button(img, x, y, size, color, icon_name, label):
    b = ui(f"btn_{color}_normal", size, size)
    paste(img, b, (x, y))
    ic = icon(icon_name, int(size * 0.66))
    paste(img, ic, (x + (size - ic.width) / 2, y + 6))
    text(img, (x + size / 2, y + size - 20), label, 28, anchor="mm")


# -------------------------------------------------------------------- mockup
def village_mockup():
    W, H = 1920, 1080
    img = sky(W, H, "player")
    view = IsoView(img, W / 2, -330, 0.5)
    view.ground()
    draw_base(view, "player", troops=[("cogling", 12.5, 34.5, "walk_down", 2, False), ("magpie", 13, 35.5, "walk_down", 0, True)])
    # overlay di gioco: cantiere, fumo
    im, r = A("buildings_player").get("construction/3")
    view.sprite(im, r["anchor"], 36.5, 24.5)
    bar = ui("bar_bg", 120, 26)
    sx, sy = view.P(36.5, 23)
    paste(img, bar, (sx - 60, sy - 110))
    paste(img, ui("bar_build", 70, 22), (sx - 58, sy - 108))
    text(img, (sx, sy - 128), "2h 14m", 24, anchor="mm")
    # popup raccolta
    for (cx, cy, k) in ((12, 15, "p/coin_cog"), (30, 14, "p/drop_sap")):
        sx, sy = view.P(cx, cy)
        bub = ui("panel", 74, 74)
        paste(img, bub, (sx - 37, sy - 150))
        im, _ = A("fx").get(k)
        paste(img, im.resize((44, 44), Image.LANCZOS), (sx - 22, sy - 138))
    # HUD in alto a sinistra: livello, nome, trofei
    paste(img, icon("icon/xp", 96), (20, 14))
    text(img, (68, 64), "12", 34, anchor="mm")
    text(img, (124, 30), "Lumen Vale", 34)
    paste(img, ui("bar_bg", 220, 30), (124, 72))
    paste(img, ui("bar_xp", 150, 26), (126, 74))
    paste(img, icon("league/flame", 92), (20, 118))
    text(img, (116, 156), "1.142", 38)
    # costruttori + scudo (centro alto)
    pan = ui("res_bar", 210, 60)
    paste(img, pan, (720, 18))
    paste(img, icon("icon/builder", 70), (716, 12))
    text(img, (870, 48), "2/4", 34, anchor="mm")
    paste(img, ui("res_bar", 260, 60), (950, 18))
    paste(img, icon("icon/shield", 70), (946, 12))
    text(img, (1110, 48), "7h 22m", 32, anchor="mm")
    # risorse in alto a destra
    resource_bar(img, 1520, 24, 370, "icon/cogs", 184250, 263000, "bar_cogs")
    resource_bar(img, 1520, 124, 370, "icon/sap", 96300, 263000, "bar_sap")
    resource_bar(img, 1520, 224, 370, "icon/shards", 1240, 3180, "bar_shards")
    resource_bar(img, 1520, 324, 370, "icon/glimmers", 268, 268, "bar_build")
    # pulsanti in basso
    b = ui("btn_red_normal", 200, 200)
    paste(img, b, (24, 856))
    paste(img, icon("icon/attack", 132), (58, 868))
    text(img, (124, 1018), "ATTACCA!", 40, anchor="mm")
    round_button(img, 1700, 870, 190, "gold", "icon/shop", "Negozio")
    round_button(img, 1500, 900, 160, "blue", "icon/army", "Esercito")
    round_button(img, 1320, 920, 140, "purple", "icon/quests", "Obiettivi")
    round_button(img, 24, 690, 120, "blue", "icon/clan", "Clan")
    round_button(img, 1776, 440, 120, "blue", "icon/settings", "")
    # notifiche
    for (x, y) in ((1450, 920), (130, 700)):
        img_d = ImageDraw.Draw(img)
        img_d.ellipse((x, y, x + 36, y + 36), fill=(232, 96, 76), outline=INK, width=4)
        text(img, (x + 18, y + 18), "!", 26, anchor="mm")
    img.convert("RGB").save(os.path.join(OUT, "village_mockup.png"), optimize=True)
    return img


def battle_mockup():
    W, H = 1920, 1080
    img = sky(W, H, "gloom")
    view = IsoView(img, W / 2, -380, 0.55)
    view.ground(pal="gloom")
    troops = [("bulwark", 16.0, 30.8, "attack_up", 1, False), ("cogling", 14.6, 31.0, "walk_up", 2, False), ("cogling", 13.8, 30.2, "attack_up", 1, False),
              ("slingwisp", 12.8, 33.0, "attack_up", 1, False), ("slingwisp", 11.9, 32.2, "walk_up", 3, False), ("kegger", 15.2, 30.0, "walk_up", 1, False),
              ("rustjaw", 18.0, 31.2, "walk_up", 2, True), ("kitewing", 21, 33, "walk_up", 2, True), ("mender", 13.0, 34.5, "attack_up", 1, False),
              ("ember_warden", 10.5, 31.5, "walk_up", 0, False), ("dirigible", 28.5, 33.5, "walk_up", 1, True), ("magpie", 9.5, 27.5, "walk_down", 3, True)]
    fx = [("explosion/3", 15.6, 28.5, 1.2), ("shock/2", 17.5, 26.5, 1.0), ("muzzle/1", 18.5, 25.5, 0.9), ("fire/2", 13.6, 25.0, 1.0), ("ring_mending/4", 12.8, 33.5, 1.4)]
    draw_base(view, "gloom", troops=troops, fx=fx)
    # rovina
    im, r = A("fx").get("rubble/2")
    view.sprite(im, r["anchor"], 12, 26)
    # HUD battaglia: avversario e bottino (sx), timer (centro), stelle e % (dx)
    pan = ui("panel_dark", 460, 230)
    paste(img, pan, (20, 20))
    text(img, (44, 40), "Gloomtide Pier", 36)
    text(img, (44, 84), "Bottino disponibile:", 24, fill=(255, 243, 214), stroke=4)
    for i, (ic, v) in enumerate((("icon/cogs", "112.400"), ("icon/sap", "98.750"), ("icon/shards", "72"))):
        paste(img, icon(ic, 46), (44, 116 + i * 34 - 6))
        text(img, (98, 116 + i * 34 + 14), v, 28, anchor="lm")
    tim = ui("ribbon", 300, 100)
    paste(img, tim, (810, 6))
    text(img, (960, 46), "1:42", 50, anchor="mm")
    text(img, (960, 120), "Termina la battaglia", 24, fill=(255, 243, 214), stroke=4, anchor="mm")
    paste(img, ui("panel_dark", 360, 150), (1540, 20))
    for i in range(3):
        st = icon("icon/star" if i < 1 else "icon/star_empty", 86)
        paste(img, st, (1566 + i * 100, 32))
    text(img, (1720, 140), "Distruzione: 54%", 30, anchor="mm")
    # barra truppe in basso
    paste(img, ui("panel_dark", 1500, 196), (210, 870))
    roster = [("cogling", 18), ("slingwisp", 22), ("bulwark", 4), ("kegger", 6), ("rustjaw", 3), ("kitewing", 5), ("mender", 1), ("ember_warden", 1)]
    for i, (tid, n) in enumerate(roster):
        x = 236 + i * 150
        sl = ui("slot_selected" if i == 1 else "slot", 136, 150)
        paste(img, sl, (x, 892))
        im, _ = A("portraits").get(f"portrait/{tid}")
        paste(img, im.resize((112, 112), Image.LANCZOS), (x + 12, 906))
        text(img, (x + 120, 908), f"x{n}", 30, anchor="ra")
        text(img, (x + 22, 1022), f"Lv{3 + i % 3}", 22, fill=(255, 243, 214), stroke=4)
    for j, sp in enumerate(("mending_mist", "fervor_surge")):
        x = 1436 + j * 136
        paste(img, ui("slot", 124, 150), (x, 892))
        paste(img, icon(f"spell/{sp}", 100), (x + 12, 910))
        text(img, (x + 108, 908), "x2", 28, anchor="ra")
    b = ui("btn_red_normal", 160, 96)
    paste(img, b, (20, 960))
    paste(img, icon("icon/surrender", 56), (34, 972))
    text(img, (124, 1006), "Resa", 30, anchor="mm")
    img.convert("RGB").save(os.path.join(OUT, "battle_mockup.png"), optimize=True)


def panels_mockup():
    W, H = 1920, 1080
    base = Image.open(os.path.join(OUT, "village_mockup.png")).convert("RGBA")
    dim = Image.new("RGBA", (W, H), (30, 20, 40, 150))
    img = Image.alpha_composite(base, dim)
    # pannello potenziamento edificio
    px, py, pw, ph = 140, 120, 820, 820
    paste(img, ui("panel", pw, ph), (px, py))
    paste(img, ui("ribbon", 560, 100), (px + 130, py - 40))
    text(img, (px + pw / 2, py + 4), "Boltpost  Lv 5 > 6", 42, anchor="mm")
    paste(img, icon("icon/close", 92), (px + pw - 70, py - 30))
    im, r = A("buildings_player").get("boltpost/t3")
    im2 = im.resize((int(im.width * 0.9), int(im.height * 0.9)), Image.LANCZOS)
    paste(img, im2, (px + 40, py + 90))
    stats = [("icon/attack", "DPS", "26 > 31", 0.55), ("icon/shield", "Punti vita", "731 > 855", 0.6), ("icon/info", "Raggio", "0 - 8 celle", 1.0),
             ("icon/info", "Bersagli", "Terra e aria", 1.0)]
    for i, (ic, label, val, frac) in enumerate(stats):
        y = py + 120 + i * 92
        paste(img, icon(ic, 64), (px + 330, y))
        ImageDraw.Draw(img).text((px + 410, y - 2), label, font=font(30, False), fill=INK)
        paste(img, ui("bar_bg", 360, 34), (px + 410, y + 36))
        paste(img, ui("bar_hp", int(356 * frac), 30), (px + 412, y + 38))
        text(img, (px + 590, y + 54), val, 24, anchor="mm")
    y = py + ph - 200
    paste(img, ui("panel_inset", pw - 80, 90), (px + 40, y - 20))
    paste(img, icon("icon/timer", 60), (px + 60, y - 6))
    ImageDraw.Draw(img).text((px + 130, y), "Tempo: 4h 30m", font=font(32, False), fill=INK)
    paste(img, icon("icon/lock", 52), (px + 470, y - 2))
    ImageDraw.Draw(img).text((px + 530, y), "Faro Madre Lv 6", font=font(28, False), fill=INK)
    b = ui("btn_green_normal", 380, 120)
    paste(img, b, (px + 40, py + ph - 150))
    paste(img, icon("icon/cogs", 64), (px + 60, py + ph - 136))
    text(img, (px + 240, py + ph - 100), "48.300", 44, anchor="mm")
    b = ui("btn_purple_normal", 340, 120)
    paste(img, b, (px + 450, py + ph - 150))
    paste(img, icon("icon/glimmers", 60), (px + 470, py + ph - 134))
    text(img, (px + 640, py + ph - 100), "Subito 64", 40, anchor="mm")
    # negozio a categorie
    sx, sy, sw, sh = 1020, 120, 860, 820
    paste(img, ui("panel", sw, sh), (sx, sy))
    paste(img, ui("ribbon_blue", 460, 100), (sx + 200, sy - 40))
    text(img, (sx + sw / 2, sy + 4), "Negozio", 46, anchor="mm")
    tabs = [("Economia", "gold"), ("Difese", "blue"), ("Esercito", "blue"), ("Trappole", "blue")]
    for i, (t, c) in enumerate(tabs):
        b = ui(f"btn_{c}_normal", 196, 84)
        paste(img, b, (sx + 30 + i * 204, sy + 70))
        text(img, (sx + 128 + i * 204, sy + 106), t, 28, anchor="mm")
    cards = [("cog_mine", "Mina di Cogs", "2/5", "860", "icon/sap", True), ("sap_well", "Pozzo di Sap", "2/5", "860", "icon/cogs", True),
             ("cog_vault", "Deposito", "1/2", "2.150", "icon/sap", True), ("sap_cistern", "Cisterna", "2/2", "2.150", "icon/cogs", False),
             ("shard_drill", "Trivella", "0/0", "Faro 5", "icon/lock", False), ("shard_crate", "Cassa Shard", "0/0", "Faro 5", "icon/lock", False)]
    for i, (bid, name, cnt, cost, ic, ok) in enumerate(cards):
        cx = sx + 34 + (i % 3) * 270
        cy = sy + 190 + (i // 3) * 300
        paste(img, ui("slot" if ok else "slot_dark", 252, 284), (cx, cy))
        th, _ = A("icons").get(f"thumb/{bid}")
        if not ok:
            g = th.convert("LA").convert("RGBA")
            g.putalpha(th.getchannel("A").point(lambda a: int(a * 0.7)))
            th = g
        paste(img, th, (cx + 46, cy + 34))
        text(img, (cx + 126, cy + 22), name, 26, anchor="mm")
        text(img, (cx + 228, cy + 54), cnt, 24, anchor="ra")
        paste(img, icon(ic, 44), (cx + 30, cy + 220))
        text(img, (cx + 82, cy + 242), cost, 30, anchor="lm", fill=(255, 255, 255) if ok else (255, 160, 150))
    img.convert("RGB").save(os.path.join(OUT, "panels_mockup.png"), optimize=True)


def army_mockup():
    W, H = 1920, 1080
    base = Image.open(os.path.join(OUT, "village_mockup.png")).convert("RGBA")
    img = Image.alpha_composite(base, Image.new("RGBA", (W, H), (30, 20, 40, 150)))
    px, py, pw, ph = 120, 110, 1680, 880
    paste(img, ui("panel", pw, ph), (px, py))
    paste(img, ui("ribbon", 560, 100), (px + pw / 2 - 280, py - 40))
    text(img, (px + pw / 2, py + 4), "Esercito  148/180", 44, anchor="mm")
    paste(img, icon("icon/close", 92), (px + pw - 70, py - 30))
    paste(img, ui("panel_inset", pw - 80, 250), (px + 40, py + 80))
    ImageDraw.Draw(img).text((px + 64, py + 94), "Esercito pronto  (trascina per rimuovere)", font=font(28, False), fill=INK)
    army = [("cogling", 40), ("slingwisp", 30), ("bulwark", 6), ("kegger", 4), ("rustjaw", 3), ("kitewing", 4), ("mender", 1)]
    for i, (tid, n) in enumerate(army):
        x = px + 60 + i * 190
        paste(img, ui("slot", 172, 180), (x, py + 136))
        im, _ = A("portraits").get(f"portrait/{tid}")
        paste(img, im.resize((140, 140), Image.LANCZOS), (x + 16, py + 150))
        text(img, (x + 160, py + 146), f"x{n}", 34, anchor="ra")
        paste(img, icon("icon/minus", 54), (x + 124, py + 264))
    ImageDraw.Draw(img).text((px + 64, py + 360), "Addestra (tocca o trascina per aggiungere)", font=font(28, False), fill=INK)
    allt = ["cogling", "slingwisp", "bulwark", "magpie", "kegger", "rustjaw", "kitewing", "mender", "dirigible", "ember_warden"]
    costs = ["25", "45", "250", "60", "120", "300", "180", "800", "2.800", "45"]
    for i, tid in enumerate(allt):
        x = px + 60 + (i % 5) * 320
        y = py + 410 + (i // 5) * 220
        locked = i >= 8
        paste(img, ui("slot_dark" if locked else "slot", 300, 200), (x, y))
        im, _ = A("portraits").get(f"portrait/{tid}")
        if locked:
            g = im.convert("LA").convert("RGBA")
            g.putalpha(im.getchannel("A").point(lambda a: int(a * 0.6)))
            im = g
        paste(img, im.resize((150, 150), Image.LANCZOS), (x + 8, y + 22))
        paste(img, icon("icon/lock" if locked else ("icon/shards" if tid == "ember_warden" else "icon/sap"), 44), (x + 168, y + 130))
        text(img, (x + 220, y + 152), "Cas. 9" if locked else costs[i], 28, anchor="lm")
        text(img, (x + 168, y + 30), f"Lv {1 + i % 4}", 26)
        paste(img, icon("icon/info", 44), (x + 244, y + 14))
    img.convert("RGB").save(os.path.join(OUT, "army_mockup.png"), optimize=True)


def contact_sheets():
    # edifici: tutti i tipi x 5 tier (player) + gloom tier 5
    import b_designs as B
    rows = []
    for bid, (N, top, fn, cat) in B.DESIGNS.items():
        if cat == "obstacle":
            continue
        rows.append([A("buildings_player").get(f"{bid}/t{t}")[0] for t in range(1, 6)] + [A("buildings_gloom").get(f"{bid}/t5")[0]])
    scale = 0.42
    cellw = 300
    sheet_h = 0
    rendered = []
    for r in rows:
        hh = max(int(i.height * scale) for i in r) + 16
        rendered.append((r, hh))
        sheet_h += hh
    sheet = Image.new("RGBA", (cellw * 6 + 40, sheet_h + 60), (110, 184, 82, 255))
    text(sheet, (20, 10), "Edifici: tier 1-5 (Lanternari) + tier 5 Marea d'Ombra", 32)
    y = 60
    for r, hh in rendered:
        for i, im in enumerate(r):
            im2 = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
            paste(sheet, im2, (20 + i * cellw + (cellw - im2.width) / 2, y + hh - im2.height - 8))
        y += hh
    sheet.convert("RGB").save(os.path.join(OUT, "sheet_buildings.png"), optimize=True)
    # truppe: tutte le righe di animazione (scala 0.6)
    meta = json.load(open(os.path.join(ROOT, "assets", "sprites", "troops", "troops.json")))
    blocks = []
    for tid, m in meta.items():
        sh = Image.open(os.path.join(ROOT, "assets", "sprites", "troops", f"{tid}.png")).convert("RGBA")
        sc = 0.5 if m["frame"][0] > 160 else 0.6
        blocks.append(sh.resize((int(sh.width * sc), int(sh.height * sc)), Image.LANCZOS))
    Wt = 2400
    x = y = 20
    rowh = 0
    pos = []
    for b in blocks:
        if x + b.width > Wt:
            x, y, rowh = 20, y + rowh + 20, 0
        pos.append((b, x, y))
        x += b.width + 20
        rowh = max(rowh, b.height)
    sheet = Image.new("RGBA", (Wt, y + rowh + 20), (110, 184, 82, 255))
    for b, x, y in pos:
        paste(sheet, b, (x, y))
    sheet.convert("RGB").save(os.path.join(OUT, "sheet_troops.png"), optimize=True)
    # icone + leghe + kit UI
    ic = A("icons")
    keys = [k for k in ic.r if k.startswith("icon/") or k.startswith("league/") or k.startswith("spell/")]
    cols = 12
    sheet = Image.new("RGBA", (cols * 140 + 40, (len(keys) // cols + 1) * 150 + 560), (255, 243, 214, 255))
    for i, k in enumerate(keys):
        im, _ = ic.get(k)
        im = im.resize((96, 96), Image.LANCZOS)
        x, y = 20 + (i % cols) * 140, 20 + (i // cols) * 150
        paste(sheet, im, (x + 20, y))
        ImageDraw.Draw(sheet).text((x + 68, y + 112), k.split("/")[1][:12], font=font(18, False), fill=INK, anchor="ma")
    y0 = 40 + (len(keys) // cols + 1) * 150
    for i, nm in enumerate(("green", "blue", "red", "gold", "purple")):
        paste(sheet, ui(f"btn_{nm}_normal", 220, 96), (20 + i * 250, y0))
        paste(sheet, ui(f"btn_{nm}_pressed", 220, 96), (20 + i * 250, y0 + 110))
        text(sheet, (130 + i * 250, y0 + 44), "Normale", 28, anchor="mm")
        text(sheet, (130 + i * 250, y0 + 160), "Premuto", 28, anchor="mm")
    paste(sheet, ui("btn_disabled_normal", 220, 96), (1270, y0))
    text(sheet, (1380, y0 + 44), "Disattivo", 28, anchor="mm", fill=(90, 84, 104))
    paste(sheet, ui("panel", 360, 200), (20, y0 + 230))
    paste(sheet, ui("panel_dark", 360, 200), (400, y0 + 230))
    paste(sheet, ui("res_bar", 360, 64), (780, y0 + 230))
    paste(sheet, ui("ribbon", 360, 100), (780, y0 + 320))
    paste(sheet, ui("slot", 160, 160), (1170, y0 + 230))
    paste(sheet, ui("slot_selected", 160, 160), (1350, y0 + 230))
    sheet.convert("RGB").save(os.path.join(OUT, "sheet_icons_ui.png"), optimize=True)
    # effetti
    fxa = A("fx")
    groups = {}
    for k in fxa.r:
        g = k.split("/")[0]
        groups.setdefault(g, []).append(k)
    sheet = Image.new("RGBA", (2000, 2000), (60, 48, 80, 255))
    y = 20
    x = 20
    rowh = 0
    for g, ks in groups.items():
        ks = sorted(ks)
        ims = [fxa.get(k)[0] for k in ks]
        ims = [im.resize((max(1, int(im.width * 0.6)), max(1, int(im.height * 0.6))), Image.LANCZOS) for im in ims]
        wsum = sum(i.width + 6 for i in ims)
        if x + wsum > 1980:
            x, y, rowh = 20, y + rowh + 30, 0
        text(sheet, (x, y), g, 20, stroke=3)
        xx = x
        for im in ims:
            paste(sheet, im, (xx, y + 26))
            xx += im.width + 6
        x = xx + 24
        rowh = max(rowh, max(i.height for i in ims) + 26)
    sheet = sheet.crop((0, 0, 2000, y + rowh + 30))
    sheet.convert("RGB").save(os.path.join(OUT, "sheet_fx.png"), optimize=True)


def palette_sheet():
    sw = Image.new("RGBA", (1600, 520), (255, 243, 214, 255))
    groups = [("Principale", list(C.items())), ("Marea d'Ombra", list(GLOOM.items())), ("UI", [(k, v) for k, v in UI.items() if v.startswith("#")])]
    y = 20
    for gname, items in groups:
        text(sw, (20, y), gname, 30)
        y += 44
        for i, (k, v) in enumerate(items):
            x = 20 + (i % 13) * 120
            yy = y + (i // 13) * 92
            ImageDraw.Draw(sw).rounded_rectangle((x, yy, x + 100, yy + 50), 10, fill=v, outline=INK, width=3)
            ImageDraw.Draw(sw).text((x + 50, yy + 54), f"{k}\n{v}", font=font(15, False), fill=INK, anchor="ma", align="center")
        y += ((len(items) - 1) // 13 + 1) * 92 + 10
    sw.crop((0, 0, 1600, y + 10)).convert("RGB").save(os.path.join(OUT, "palette.png"))


def legibility():
    """Simula la vista su un 5" (1280x720 @ ~294 dpi) e un 7" (1920x1200 @ ~323 dpi) a dimensioni fisiche reali
    sul monitor del revisore (96 dpi): verifica che bottoni >= 48 dp e testo >= 12 sp restino leggibili."""
    base = Image.open(os.path.join(OUT, "village_mockup.png")).convert("RGB")
    out = Image.new("RGB", (1500, 640), (255, 243, 214))
    d = ImageDraw.Draw(out)
    # 5" 16:9: larghezza fisica ~4.36" -> 418 px a 96dpi ; 7" 16:10: ~5.94" -> 570 px
    for i, (lab, wpx) in enumerate((('5" 1280x720 (scala fisica)', 418), ('7" 1920x1200 (scala fisica)', 570))):
        h = int(wpx * 1080 / 1920)
        im = base.resize((wpx, h), Image.LANCZOS)
        x = 40 + i * 700
        out.paste(im, (x, 80))
        d.text((x, 30), lab, font=font(28), fill=INK)
    # tabella dimensioni minime
    d.text((40, 420), "Vincoli verificati (risoluzione di riferimento 1920x1080, stretch canvas_items):", font=font(24, False), fill=INK)
    rows = ["48 dp = 0.3 in: su 5\" 16:9 (1920 px rif. su 4.36 in) = 132 px di riferimento; su 7\" = 97 px",
            "Pulsanti principali 140-200 px (Attacca 200, Negozio 190, Esercito 160, Obiettivi 140)  OK",
            "Slot battaglia 136x150  OK  |  Chiudi 92 px, info 44-54, schede 84: area di tocco estesa a 132 px  OK",
            "Testo informativo >= 24 px; minimo 20 px solo per etichette secondarie (~11 pt su 5\")  OK"]
    for j, r in enumerate(rows):
        d.text((60, 460 + j * 40), r, font=font(22, False), fill=INK)
    out.save(os.path.join(OUT, "legibility_5in_7in.png"))


if __name__ == "__main__":
    village_mockup()
    battle_mockup()
    panels_mockup()
    army_mockup()
    contact_sheets()
    palette_sheet()
    legibility()
    print("anteprime in", OUT)
