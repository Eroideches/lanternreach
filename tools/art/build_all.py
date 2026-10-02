#!/usr/bin/env python3
"""Genera TUTTI gli asset visivi e sonori di Lanternreach.

Uso (richiede numpy, pillow, cairosvg; font in assets/fonts installati per il logo):
    python3 tools/art/build_all.py [--only buildings,troops,fx,terrain,icons,ui,branding,audio]

Output:
  assets/atlas/*.png + *.json   atlas con regioni, ancore e overlay
  assets/sprites/troops/*.png   fogli animazione truppe + troops.json
  assets/ui/theme.tres          Theme Godot
  assets/branding/*             icona app (legacy+adaptive), splash, logo
  assets/audio/{sfx,music}/*.wav
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image

from common import ROOT, ensure, bbox_trim
from atlas import Packer

ASSETS = os.path.join(ROOT, "assets")
ATLAS = ensure(ASSETS, "atlas")
LEVELS = {  # livelli massimi (per mappare livello -> tier visivo)
    "lantern_hall": 10, "cog_mine": 10, "sap_well": 10, "shard_drill": 6, "cog_vault": 10, "sap_cistern": 10, "shard_crate": 6,
    "barracks": 10, "army_camp": 8, "laboratory": 8, "spell_forge": 5, "clan_hall": 5,
    "boltpost": 10, "lobber": 10, "skyspear": 10, "arc_coil": 10, "ballista": 10, "thumper": 10, "frost_spire": 10,
    "cinder_spout": 10, "storm_pylon": 10, "wall": 10, "bomb_trap": 5, "spring_pad": 5, "snare_trap": 5, "air_mine": 5,
}


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def do_buildings():
    import b_designs as B
    from buildings import tier_of
    manifest = {"tier_of_level": {}, "footprint": {}, "category": {}}
    for bid, mx in LEVELS.items():
        manifest["tier_of_level"][bid] = [tier_of(L, mx) for L in range(1, mx + 1)]
    for pal in ("player", "gloom"):
        pk = Packer(2048)
        for bid, (N, top, fn, cat) in B.DESIGNS.items():
            manifest["footprint"][bid] = N
            manifest["category"][bid] = cat
            if cat == "obstacle":
                if pal == "gloom":
                    continue
                tiers = [1]
            elif cat == "trap":
                tiers = [1, 2, 3, 4, 5]
            else:
                tiers = [1, 2, 3, 4, 5]
            for t in tiers:
                img, c = B.render_building(bid, t, pal)
                img, anchor = B.finalize(img, c)
                pk.add(f"{bid}/t{t}", img, anchor=anchor, overlays=c.overlays, footprint=N)
        for N in (1, 2, 3, 4):
            img, c = B.render_construction(N, pal)
            img, anchor = B.finalize(img, c)
            pk.add(f"construction/{N}", img, anchor=anchor, overlays=c.overlays, footprint=N)
        pk.save(ATLAS, f"buildings_{pal}")
        log("edifici", pal, "ok")
    with open(os.path.join(ATLAS, "buildings_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1)


def do_walls():
    import b_designs as B
    from b_walls import wall_sprite
    for pal in ("player", "gloom"):
        pk = Packer(2048)
        for t in range(1, 6):
            for mask in range(16):
                c = wall_sprite(t, mask, pal)
                from common import render
                img = render(c.S)
                img, anchor = B.finalize(img, c)
                pk.add(f"wall/t{t}/m{mask}", img, anchor=anchor, footprint=1)
        pk.save(ATLAS, f"walls_{pal}")
    log("mura ok")


def do_troops():
    import troops as T
    out = ensure(ASSETS, "sprites", "troops")
    meta = {}
    for tid in T.DRAW:
        sheet, m = T.render_sheet(tid)
        sheet.save(os.path.join(out, f"{tid}.png"), optimize=True)
        m["flying"] = tid in T.FLYING
        meta[tid] = m
        log("truppa", tid)
    # ritratti 128x128 (frame walk_down 0, centrato)
    pk = Packer(2048)
    for tid in T.DRAW:
        fr = T.render_frame(tid, "walk", 0, False)
        im, _ = bbox_trim(fr, 2)
        im.thumbnail((116, 116), Image.LANCZOS)
        canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((128 - im.width) // 2, 128 - im.height - 4))
        pk.add(f"portrait/{tid}", canvas)
    pk.save(ATLAS, "portraits")
    with open(os.path.join(out, "troops.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)


def do_fx():
    import effects as E
    pk = Packer(2048)
    for i in range(6):
        pk.add(f"spark/{i}", E.spark(i, 6), anim="spark", frames=6, fps=18)
    for i in range(8):
        pk.add(f"explosion/{i}", E.explosion(i, 8), anim="explosion", frames=8, fps=20)
    for i in range(6):
        pk.add(f"smoke/{i}", E.puff(i, 6, "#EDE6F2", 80, 0.6), anim="smoke", frames=6, fps=8)
        pk.add(f"dust/{i}", E.puff(i, 6, "#E3C98B", 96, 0.0), anim="dust", frames=6, fps=14)
        pk.add(f"fire/{i}", E.flame(i, 6), anim="fire", frames=6, fps=12)
        pk.add(f"fire_small/{i}", E.flame(i, 6, True), anim="fire_small", frames=6, fps=12)
        pk.add(f"shock/{i}", E.shock(i, 6), anim="shock", frames=6, fps=20)
    for i in range(4):
        pk.add(f"hit/{i}", E.hit(i, 4), anim="hit", frames=4, fps=24)
        pk.add(f"arc/{i}", E.lightning(i, 4), anim="arc", frames=4, fps=16)
        pk.add(f"bubbles/{i}", E.bubbles(i, 4), anim="bubbles", frames=4, fps=6)
    for i in range(3):
        pk.add(f"muzzle/{i}", E.muzzle(i, 3), anim="muzzle", frames=3, fps=24)
        pk.add(f"muzzle_fire/{i}", E.muzzle(i, 3, True), anim="muzzle_fire", frames=3, fps=24)
    from common import PALETTE as C, GLOOM
    for cname, col in (("coral", C["coral"]), ("teal", C["teal"]), ("shard", C["shard"]), ("amber", C["amber"]), ("gloom", GLOOM["glow"])):
        for i in range(4):
            pk.add(f"flag_{cname}/{i}", E.flag(i, col), anim=f"flag_{cname}", frames=4, fps=8)
    for nm, col in (("mending", C["sap"]), ("fervor", C["ember"]), ("deploy", "#4AA8E8")):
        for i in range(8):
            pk.add(f"ring_{nm}/{i}", E.ring_fx(col, i, 8), anim=f"ring_{nm}", frames=8, fps=16)
    pk.add("gear", E.gear_sprite(48))
    pk.add("gear_small", E.gear_sprite(24))
    for k, im in E.particles().items():
        pk.add(f"p/{k}", im)
    for N in (1, 2, 3, 4):
        im, anchor = E.rubble(N)
        im2, (l, t) = bbox_trim(im, 4)
        pk.add(f"rubble/{N}", im2, anchor=[anchor[0] - l, anchor[1] - t], footprint=N)
    pk.save(ATLAS, "fx")
    log("effetti ok")


def do_terrain():
    import terrain as TR
    pk = Packer(2048)
    for pal in ("player", "gloom"):
        for v in range(4):
            pk.add(f"{pal}/grass_{v}", TR.grass_tile(v, pal))
        pk.add(f"{pal}/cliff_L", TR.cliff_piece("L", pal))
        pk.add(f"{pal}/cliff_R", TR.cliff_piece("R", pal))
    pk.add("hl/valid", TR.flat_tile("#58D05A", 0.45, "#FFFFFF", 2, 3))
    pk.add("hl/invalid", TR.flat_tile("#EB5A46", 0.5, "#FFFFFF", 2, 3))
    pk.add("hl/select", TR.flat_tile("none", 1.0, "#FFF3D6", 3, 4))
    pk.add("hl/range", TR.flat_tile("#FFFFFF", 0.15))
    pk.add("hl/deploy", TR.deploy_tile())
    pk.add("hl/nodeploy", TR.flat_tile("#E8604C", 0.18))
    pk.add("hl/path", TR.flat_tile("#C48A57", 0.9))
    for k in ("tuft", "flower_a", "flower_b", "pebbles", "mushroom", "lantern_post"):
        pk.add(f"deco/{k}", TR.deco(k))
    for v in range(3):
        pk.add(f"cloud/{v}", TR.cloud(v))
    pk.save(ATLAS, "terrain")
    for pal in ("player", "gloom"):
        TR.sky(pal=pal).save(os.path.join(ATLAS, f"sky_{pal}.png"))
    log("terreno ok")


def do_icons():
    import icons as I
    pk = Packer(2048)
    for k, im in I.render_icons().items():
        pk.add(f"icon/{k}", im)
    for i, (lid, _) in enumerate(I.LEAGUE_COLORS):
        pk.add(f"league/{lid}", I.league_badge(i))
    # miniature edifici per negozio (tier 1, 160x160)
    import b_designs as B
    for bid, (N, top, fn, cat) in B.DESIGNS.items():
        img, c = B.render_building(bid, 1, "player")
        img, _ = B.finalize(img, c)
        img.thumbnail((152, 152), Image.LANCZOS)
        cv = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
        cv.alpha_composite(img, ((160 - img.width) // 2, 160 - img.height - 4))
        pk.add(f"thumb/{bid}", cv)
    from b_walls import wall_sprite
    from common import render
    c = wall_sprite(1, 5, "player")
    w = render(c.S)
    w, _ = bbox_trim(w, 2)
    cv = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    w.thumbnail((140, 140), Image.LANCZOS)
    cv.alpha_composite(w, ((160 - w.width) // 2, 160 - w.height - 8))
    pk.add("thumb/wall", cv)
    # incantesimi
    import effects as E
    from icons import _icon, star_shape
    from common import PALETTE as C

    def mist(S, cx, cy):
        S.circle(cx, cy, 40, S.grad("#B8F5D0", C["sap"]), sw=5)
        S.poly([(cx - 8, cy - 22), (cx + 8, cy - 22), (cx + 8, cy - 8), (cx + 22, cy - 8), (cx + 22, cy + 8), (cx + 8, cy + 8), (cx + 8, cy + 22), (cx - 8, cy + 22), (cx - 8, cy + 8), (cx - 22, cy + 8), (cx - 22, cy - 8), (cx - 8, cy - 8)], "#FFFFFF", sw=4)

    def fervor(S, cx, cy):
        S.circle(cx, cy, 40, S.grad("#FFC48A", C["ember"]), sw=5)
        S.poly([(cx + 6, cy - 30), (cx - 18, cy + 4), (cx, cy + 4), (cx - 6, cy + 30), (cx + 18, cy - 4), (cx, cy - 4)], "#FFF3D6", sw=4)
    pk.add("spell/mending_mist", _icon(mist))
    pk.add("spell/fervor_surge", _icon(fervor))
    pk.save(ATLAS, "icons")
    log("icone ok")


def do_ui():
    import ui as U
    pk = Packer(1024)
    for name, (im, margin) in U.build_all().items():
        pk.add(f"ui/{name}", im, margin=margin)
    files, regions = pk.save(ATLAS, "ui")
    theme = U.godot_theme(regions, "res://assets/atlas/ui_{}.png")
    ensure(ASSETS, "ui")
    with open(os.path.join(ASSETS, "ui", "theme.tres"), "w", encoding="utf-8") as f:
        f.write(theme)
    log("ui ok")


def do_branding():
    import branding as BR
    out = ensure(ASSETS, "branding")
    bg, fg = BR.app_icon_layers()
    bg.save(os.path.join(out, "icon_adaptive_bg.png"))
    fg.save(os.path.join(out, "icon_adaptive_fg.png"))
    for s in (192, 512):
        BR.app_icon(s).save(os.path.join(out, f"icon_{s}.png"))
    BR.app_icon(256).save(os.path.join(ROOT, "icon.png"))
    BR.splash().convert("RGB").save(os.path.join(out, "splash.png"), optimize=True)
    BR.wordmark(1200, 300).save(os.path.join(out, "logo.png"))
    log("branding ok")


def do_audio():
    import audio as A
    sfx = A.sfx_all()
    for k, v in sfx.items():
        A.write_wav(os.path.join(ASSETS, "audio", "sfx", f"{k}.wav"), v)
    log("sfx", len(sfx))
    A.write_wav(os.path.join(ASSETS, "audio", "music", "village_theme.wav"), A.music_village())
    A.write_wav(os.path.join(ASSETS, "audio", "music", "battle_theme.wav"), A.music_battle())
    log("musica ok")


STEPS = dict(buildings=do_buildings, walls=do_walls, troops=do_troops, fx=do_fx, terrain=do_terrain, icons=do_icons,
             ui=do_ui, branding=do_branding, audio=do_audio)

if __name__ == "__main__":
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1].split(",")
    for k, fn in STEPS.items():
        if only and k not in only:
            continue
        fn()
