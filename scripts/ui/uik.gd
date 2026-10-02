class_name UIK
extends RefCounted
## Kit di costruzione dell'interfaccia in codice: stili coerenti con assets/ui/theme.tres (ART_DIRECTION §8).

const INK := Color(0.18, 0.125, 0.21)
const LIGHT := Color(1.0, 0.97, 0.91)
const RED := Color(0.92, 0.35, 0.27)
const GREEN := Color(0.3, 0.75, 0.35)
const MIN_TOUCH := 132.0      ## area di tocco minima in px di riferimento (48 dp su un 5")

static var _title: Font
static var _body: Font


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/LilitaOne-Regular.ttf")
	return _title


static func body_font() -> Font:
	if _body == null:
		var base: FontFile = load("res://assets/fonts/Nunito-Variable.ttf")
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_body = fv
	return _body


static func label(text: String, size: int = 30, title: bool = false, color: Color = INK, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func hud_label(text: String, size: int = 34) -> Label:
	return label(text, size, true, Color.WHITE, 10)


static func icon_rect(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func icon(key: String, size: float) -> TextureRect:
	return icon_rect(Art.icon(key), size)


static func nine(key: String) -> NinePatchRect:
	var r := Art.region("ui", "ui/" + key)
	var n := NinePatchRect.new()
	var at: AtlasTexture = Art.tex("ui", "ui/" + key)
	n.texture = at.atlas
	n.region_rect = at.region
	var m := int(r.get("margin", 20))
	m = mini(m, int(minf(at.region.size.x, at.region.size.y) / 2.0) - 1)
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m
	n.patch_margin_bottom = m
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


static func style(key: String, content: Vector4 = Vector4(16, 12, 16, 14)) -> StyleBoxTexture:
	var r := Art.region("ui", "ui/" + key)
	var at: AtlasTexture = Art.tex("ui", "ui/" + key)
	var sb := StyleBoxTexture.new()
	sb.texture = at.atlas
	sb.region_rect = at.region
	var m := float(mini(int(r.get("margin", 20)), int(minf(at.region.size.x, at.region.size.y) / 2.0) - 1))
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


## Pulsante con colore (green|blue|red|gold|purple), testo, icona, feedback di pressione e suono.
static func button(text: String, color: String = "green", icon_key: String = "", min_size: Vector2 = Vector2(220, 104), font_size: int = 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_size.x, 96), maxf(min_size.y, 88))
	if color != "green":
		b.theme_type_variation = "Button" + color.capitalize()
	b.add_theme_font_size_override("font_size", font_size)
	if icon_key != "":
		b.icon = Art.icon(icon_key)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(min_size.y * 0.55))
	b.focus_mode = Control.FOCUS_NONE
	_feedback(b)
	return b


static func _feedback(b: BaseButton) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.08))
	b.button_up.connect(func() -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK))
	b.pressed.connect(AudioManager.click)


## Pulsante-icona con area di tocco estesa a MIN_TOUCH anche se l'icona e' piu' piccola.
static func icon_button(icon_key: String, icon_size: float = 92.0) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH) * minf(1.0, maxf(icon_size, 92.0) / 92.0)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var t := icon(icon_key, icon_size)
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = -Vector2(icon_size, icon_size) * 0.5
	b.add_child(t)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	_feedback(b)
	return b


static func panel(kind: String = "panel", content: Vector4 = Vector4(28, 26, 28, 30)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(kind, content))
	return p


static func bar(frac: float, fill: String = "bar_build", size: Vector2 = Vector2(300, 34), text: String = "") -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := nine("bar_bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var f := nine(fill)
	f.name = "Fill"
	f.position = Vector2(2, 2)
	f.size = Vector2(maxf(size.y - 4, (size.x - 4) * clampf(frac, 0.0, 1.0)), size.y - 4)
	f.visible = frac > 0.001
	root.add_child(f)
	if text != "":
		var l := label(text, int(size.y * 0.7), true, Color.WHITE, 6)
		l.name = "Text"
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		root.add_child(l)
	return root


static func set_bar(b: Control, frac: float, text: String = "") -> void:
	var f: Control = b.get_node("Fill")
	f.visible = frac > 0.001
	f.size.x = maxf(b.size.y - 4 if b.size.y > 0 else 30.0, (b.custom_minimum_size.x - 4) * clampf(frac, 0.0, 1.0))
	if b.has_node("Text"):
		(b.get_node("Text") as Label).text = text


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(w: float = 0, h: float = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if w == 0 and h == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func num(v: float) -> String:
	var n := int(floor(v))
	var s := str(absi(n))
	var sep := "." if TranslationServer.get_locale().begins_with("it") else ","
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = sep + out
	return ("-" if n < 0 else "") + out


## Riga costi (icona + quantita'), in rosso se non sostenibili.
static func cost_row(costs: Dictionary, size: int = 30) -> HBoxContainer:
	var h := hbox(6)
	for r in costs:
		if float(costs[r]) <= 0:
			continue
		h.add_child(icon(r, size * 1.4))
		var ok := GameState.res(r) + 1e-6 >= float(costs[r])
		h.add_child(label(num(float(costs[r])), size, true, Color.WHITE if ok else Color(1, 0.55, 0.5), 8))
	return h


static func toast(parent: Node, text: String, kind: String = "info") -> void:
	var p := panel("tooltip", Vector4(30, 14, 30, 16))
	var l := label(text, 30, true, Color.WHITE)
	p.add_child(l)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	await parent.get_tree().process_frame
	p.position = Vector2((parent.get_viewport().get_visible_rect().size.x - p.size.x) * 0.5, -80)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", 150.0, 0.2).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.2)
	tw.tween_callback(p.queue_free)
	if kind == "error":
		AudioManager.sfx("ui_error", 0.0, 0.1, true)
