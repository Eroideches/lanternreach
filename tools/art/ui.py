"""Elementi UI a 9-patch (pannelli, pulsanti con stati, barre) + generatore del Theme Godot (.tres).

Margini 9-patch e dimensioni in px a 1x della risoluzione di riferimento 1920x1080 (stretch canvas_items).
Area touch minima: 48 dp ~= 72 px a 1080p su un 6" (vedi ART_DIRECTION.md §UI).
"""
from common import INK, PALETTE as C, UI, Scene, render, lighten, darken, mix

NINE = {}   # nome -> (immagine, margine)


def rrect(S, x, y, w, h, r, fill, stroke=INK, sw=5, op=1.0):
    S.raw(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r:.1f}" ry="{r:.1f}" fill="{fill}" '
          + (f'stroke="{stroke}" stroke-width="{sw}"' if stroke else "") + f' opacity="{op}"/>')


def panel(name, fill, edge_hi, edge_lo, size=96, r=22, margin=30):
    S = Scene(size, size, 0, 0)
    rrect(S, 4, 7, size - 8, size - 10, r, darken(fill, 0.45), stroke=None)                   # ombra sotto
    rrect(S, 3, 3, size - 6, size - 10, r, S.grad(lighten(fill, 0.08), fill), sw=5)
    rrect(S, 9, 9, size - 18, size - 22, r - 7, "none", stroke=edge_hi, sw=3, op=0.8)
    NINE[name] = (render(S), margin)


def button(name, base, dark, state):
    w, h = 96, 88
    S = Scene(w, h, 0, 0)
    press = state == "pressed"
    dy = 6 if press else 0
    if state != "pressed":
        rrect(S, 3, 12, w - 6, h - 15, 22, darken(dark, 0.25), sw=5)                 # base 3D
    rrect(S, 3, 3 + dy, w - 6, h - 15, 22, S.grad(lighten(base, 0.28), base), sw=5)
    rrect(S, 11, 9 + dy, w - 22, 20, 10, "#FFFFFF", stroke=None, op=0.35)             # riflesso
    NINE[f"btn_{name}_{state}"] = (render(S), 26)


def pill(name, fill, h=48, w=96, inner=None):
    S = Scene(w, h, 0, 0)
    rrect(S, 3, 3, w - 6, h - 6, (h - 6) / 2, fill, sw=4)
    if inner:
        rrect(S, 9, 9, w - 18, (h - 18) / 2, (h - 18) / 4, inner, stroke=None, op=0.5)
    NINE[name] = (render(S), h // 2)


def bar_fill(name, col, h=40, w=80):
    S = Scene(w, h, 0, 0)
    rrect(S, 2, 2, w - 4, h - 4, (h - 4) / 2, S.grad(lighten(col, 0.3), darken(col, 0.1)), stroke=None)
    rrect(S, 8, 6, w - 16, (h - 12) / 2.4, (h - 12) / 4, "#FFFFFF", stroke=None, op=0.4)
    NINE[name] = (render(S), h // 2)


def ribbon(name, col):
    w, h = 192, 72
    S = Scene(w, h, 0, 0)
    S.poly([(4, 18), (30, 18), (30, 62), (16, 52), (4, 62)], darken(col, 0.3), sw=4)
    S.poly([(w - 4, 18), (w - 30, 18), (w - 30, 62), (w - 16, 52), (w - 4, 62)], darken(col, 0.3), sw=4)
    rrect(S, 20, 6, w - 40, 50, 10, S.grad(lighten(col, 0.25), col), sw=5)
    NINE[name] = (render(S), 34)


def slot(name, fill):
    S = Scene(96, 96, 0, 0)
    rrect(S, 4, 4, 88, 88, 16, darken(fill, 0.18), sw=4)
    rrect(S, 9, 9, 78, 74, 12, fill, stroke=None)
    NINE[name] = (render(S), 24)


def build_all():
    panel("panel", UI["panel"], "#FFFFFF", UI["panel_shade"])
    panel("panel_dark", UI["dark_panel"], "#6C5A82", "#241A2C")
    panel("panel_inset", "#F2E2BC", "#FFFFFF", "#D8C08A", 64, 14, 18)
    for nm in ("green", "blue", "red", "gold", "purple"):
        for st in ("normal", "pressed"):
            button(nm, UI[f"btn_{nm}"], UI[f"btn_{nm}_d"], st)
    button("disabled", UI["disabled"], UI["disabled_d"], "normal")
    pill("res_bar", "#3B2A4A", 52, 120, "#6C5A82")
    pill("bar_bg", "#3B2A4A", 36, 80)
    bar_fill("bar_hp", UI["hp_green"], 36)
    bar_fill("bar_hp_enemy", UI["hp_red"], 36)
    bar_fill("bar_build", C["glimmer"], 36)
    bar_fill("bar_cogs", C["amber"], 36)
    bar_fill("bar_sap", C["sap"], 36)
    bar_fill("bar_shards", C["shard"], 36)
    bar_fill("bar_xp", "#4AA8E8", 36)
    ribbon("ribbon", C["coral"])
    ribbon("ribbon_blue", "#4AA8E8")
    slot("slot", "#E8D3A5")
    slot("slot_selected", "#FFE17A")
    slot("slot_dark", "#5B4A70")
    pill("tooltip", "#2E2036", 56, 120)
    return NINE


THEME_TEMPLATE = """[gd_resource type="Theme" load_steps={steps} format=3]

{ext}
{subs}
[resource]
default_font = ExtResource("font_body")
default_font_size = 30
{props}
"""


def godot_theme(atlas_regions, atlas_page_path):
    """Theme Godot: StyleBoxTexture con regioni dell'atlas UI e margini 9-patch."""
    ext = ['[ext_resource type="FontFile" path="res://assets/fonts/Nunito-Variable.ttf" id="font_body"]',
           '[ext_resource type="FontFile" path="res://assets/fonts/LilitaOne-Regular.ttf" id="font_title"]']
    pages = sorted({r["page"] for k, r in atlas_regions.items()})
    for p in pages:
        ext.append(f'[ext_resource type="Texture2D" path="{atlas_page_path.format(p)}" id="ui_{p}"]')
    subs, props = [], []

    def sb(name, key, content=(18, 12, 18, 16)):
        r = atlas_regions[key]
        m = r["margin"]
        subs.append(f'[sub_resource type="StyleBoxTexture" id="{name}"]\ntexture = ExtResource("ui_{r["page"]}")\n'
                    f'region_rect = Rect2({r["x"]}, {r["y"]}, {r["w"]}, {r["h"]})\n'
                    f'texture_margin_left = {m}.0\ntexture_margin_top = {m}.0\ntexture_margin_right = {m}.0\ntexture_margin_bottom = {m}.0\n'
                    f'content_margin_left = {content[0]}.0\ncontent_margin_top = {content[1]}.0\ncontent_margin_right = {content[2]}.0\ncontent_margin_bottom = {content[3]}.0\n')
        return f'SubResource("{name}")'
    props.append(f'Button/styles/normal = {sb("btn_n", "ui/btn_green_normal", (24, 14, 24, 24))}')
    props.append(f'Button/styles/hover = {sb("btn_h", "ui/btn_green_normal", (24, 14, 24, 24))}')
    props.append(f'Button/styles/pressed = {sb("btn_p", "ui/btn_green_pressed", (24, 20, 24, 18))}')
    props.append(f'Button/styles/disabled = {sb("btn_d", "ui/btn_disabled_normal", (24, 14, 24, 24))}')
    props.append('Button/styles/focus = SubResource("empty")')
    subs.append('[sub_resource type="StyleBoxEmpty" id="empty"]\n')
    props += ['Button/fonts/font = ExtResource("font_title")', 'Button/font_sizes/font_size = 34',
              'Button/colors/font_color = Color(1, 0.97, 0.91, 1)', 'Button/colors/font_pressed_color = Color(1, 0.97, 0.91, 1)',
              'Button/colors/font_hover_color = Color(1, 1, 1, 1)', 'Button/colors/font_disabled_color = Color(0.36, 0.33, 0.42, 1)',
              'Button/colors/font_outline_color = Color(0.18, 0.125, 0.21, 1)', 'Button/constants/outline_size = 8']
    props.append(f'PanelContainer/styles/panel = {sb("panel", "ui/panel", (28, 26, 28, 30))}')
    props.append(f'Panel/styles/panel = {sb("panel2", "ui/panel", (28, 26, 28, 30))}')
    props.append(f'PopupPanel/styles/panel = {sb("panel3", "ui/panel", (28, 26, 28, 30))}')
    props.append(f'ProgressBar/styles/background = {sb("bar_bg", "ui/bar_bg", (8, 4, 8, 4))}')
    props.append(f'ProgressBar/styles/fill = {sb("bar_fill", "ui/bar_build", (8, 4, 8, 4))}')
    props += ['ProgressBar/fonts/font = ExtResource("font_title")', 'ProgressBar/font_sizes/font_size = 24',
              'ProgressBar/colors/font_color = Color(1, 1, 1, 1)', 'ProgressBar/colors/font_outline_color = Color(0.18, 0.125, 0.21, 1)',
              'ProgressBar/constants/outline_size = 6']
    props += ['Label/colors/font_color = Color(0.18, 0.125, 0.21, 1)', 'Label/font_sizes/font_size = 30',
              'HSlider/icons/grabber = null', 'TooltipPanel/styles/panel = ' + sb("tip", "ui/tooltip", (20, 10, 20, 12)),
              'TooltipLabel/colors/font_color = Color(1, 0.97, 0.91, 1)']
    props.append(f'LineEdit/styles/normal = {sb("le", "ui/panel_inset", (16, 10, 16, 10))}')
    props += ['LineEdit/colors/font_color = Color(0.18, 0.125, 0.21, 1)', 'LineEdit/font_sizes/font_size = 30']
    props.append(f'TabContainer/styles/panel = {sb("tabp", "ui/panel", (24, 24, 24, 28))}')
    props.append(f'TabContainer/styles/tab_selected = {sb("tabs", "ui/btn_gold_normal", (22, 10, 22, 18))}')
    props.append(f'TabContainer/styles/tab_unselected = {sb("tabu", "ui/btn_blue_normal", (22, 10, 22, 18))}')
    props += ['TabContainer/fonts/font = ExtResource("font_title")', 'TabContainer/font_sizes/font_size = 28',
              'TabContainer/colors/font_selected_color = Color(1, 0.97, 0.91, 1)', 'TabContainer/colors/font_unselected_color = Color(1, 0.97, 0.91, 1)',
              'TabContainer/colors/font_outline_color = Color(0.18, 0.125, 0.21, 1)', 'TabContainer/constants/outline_size = 6']
    # varianti titolo
    props += ['TitleLabel/base_type = &"Label"', 'TitleLabel/fonts/font = ExtResource("font_title")', 'TitleLabel/font_sizes/font_size = 48',
              'TitleLabel/colors/font_color = Color(1, 0.97, 0.91, 1)', 'TitleLabel/colors/font_outline_color = Color(0.18, 0.125, 0.21, 1)',
              'TitleLabel/constants/outline_size = 12',
              'HudLabel/base_type = &"Label"', 'HudLabel/fonts/font = ExtResource("font_title")', 'HudLabel/font_sizes/font_size = 34',
              'HudLabel/colors/font_color = Color(1, 1, 1, 1)', 'HudLabel/colors/font_outline_color = Color(0.18, 0.125, 0.21, 1)',
              'HudLabel/constants/outline_size = 10']
    for col in ("blue", "red", "gold", "purple"):
        props.append(f'Button{col.capitalize()}/base_type = &"Button"')
        props.append(f'Button{col.capitalize()}/styles/normal = {sb(f"b{col}n", f"ui/btn_{col}_normal", (24, 14, 24, 24))}')
        props.append(f'Button{col.capitalize()}/styles/hover = {sb(f"b{col}h", f"ui/btn_{col}_normal", (24, 14, 24, 24))}')
        props.append(f'Button{col.capitalize()}/styles/pressed = {sb(f"b{col}p", f"ui/btn_{col}_pressed", (24, 20, 24, 18))}')
        props += [f'Button{col.capitalize()}/fonts/font = ExtResource("font_title")', f'Button{col.capitalize()}/font_sizes/font_size = 34',
                  f'Button{col.capitalize()}/colors/font_color = Color(1, 0.97, 0.91, 1)', f'Button{col.capitalize()}/colors/font_pressed_color = Color(1, 0.97, 0.91, 1)',
                  f'Button{col.capitalize()}/colors/font_hover_color = Color(1, 1, 1, 1)', f'Button{col.capitalize()}/colors/font_disabled_color = Color(0.36, 0.33, 0.42, 1)',
                  f'Button{col.capitalize()}/colors/font_outline_color = Color(0.18, 0.125, 0.21, 1)', f'Button{col.capitalize()}/constants/outline_size = 8',
                  f'Button{col.capitalize()}/styles/disabled = SubResource("btn_d")', f'Button{col.capitalize()}/styles/focus = SubResource("empty")']
    props.append(f'PanelDark/base_type = &"PanelContainer"')
    props.append(f'PanelDark/styles/panel = {sb("pdark", "ui/panel_dark", (28, 26, 28, 30))}')
    props.append(f'ResourceBar/base_type = &"PanelContainer"')
    props.append(f'ResourceBar/styles/panel = {sb("resbar", "ui/res_bar", (64, 6, 20, 6))}')
    props.append(f'Slot/base_type = &"PanelContainer"')
    props.append(f'Slot/styles/panel = {sb("slot", "ui/slot", (10, 10, 10, 10))}')
    out = THEME_TEMPLATE.format(steps=len(ext) + len(subs) + 1, ext="\n".join(ext), subs="\n".join(subs), props="\n".join(props))
    return out.replace("HSlider/icons/grabber = null\n", "")
