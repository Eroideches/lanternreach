class_name BuildingView
extends Node2D
## Vista di un edificio/ostacolo/trappola/muro: sprite col tier del livello, overlay animati (bandiere, fumo,
## ingranaggi...), cantiere con barra di avanzamento, fumetto di raccolta, barra vita in battaglia, selezione.
## Posizione = centro del footprint (y-sort corretto per footprint quadrati non sovrapposti).

signal finished_anim

var uid := -1
var id := ""
var level := 1
var cell := Vector2i()
var n := 1
var palette := "player"
var mode := "village"             ## "village" | "battle"
var selected := false
var ghost_state := ""             ## "" | "valid" | "invalid"
var flip := false
var wall_mask := 0
var hidden_trap := false          ## in battaglia le trappole sono invisibili finche' non scattano

var sprite: Sprite2D
var overlay_root: Node2D
var hp_frac := 1.0
var show_hp := false
var progress := -1.0              ## 0..1 se in costruzione/potenziamento
var progress_text := ""
var bubble: Node2D
var _bubble_res := ""
var _gears: Array = []
var _rng_phase := 0.0


func setup(p_id: String, p_level: int, x: int, y: int, p_palette: String = "player", p_mode: String = "village") -> void:
	id = p_id
	level = p_level
	cell = Vector2i(x, y)
	n = Balance.footprint(id)
	palette = p_palette
	mode = p_mode
	position = Iso.footprint_center(x, y, n)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
		overlay_root = Node2D.new()
		add_child(overlay_root)
	_rng_phase = float((x * 31 + y * 17) % 100) / 100.0
	refresh()


func set_cell(x: int, y: int) -> void:
	cell = Vector2i(x, y)
	position = Iso.footprint_center(x, y, n)


func clear_overlays() -> void:
	for c in overlay_root.get_children():
		c.queue_free()
	_gears.clear()


func refresh(under_construction: bool = false) -> void:
	clear_overlays()
	var info: Dictionary
	if id == "wall":
		info = Art.wall_sprite(maxi(1, level), wall_mask, palette)
	elif under_construction:
		info = Art.construction_sprite(n, palette)
	else:
		info = Art.building_sprite(id, maxi(1, level), palette)
	if info.is_empty():
		return
	sprite.texture = info["tex"]
	sprite.offset = -info["anchor"]
	sprite.flip_h = flip
	if flip:
		sprite.offset.x = -(sprite.texture.get_width() - info["anchor"].x)
	if hidden_trap:
		sprite.visible = false
	if not Art.quality_high or id == "wall":
		return
	for ov in info.get("overlays", []):
		_add_overlay(ov)


func _add_overlay(ov: Dictionary) -> void:
	var pos := Vector2(ov["pos"][0], ov["pos"][1])
	if flip:
		pos.x = -pos.x
	var kind: String = ov["kind"]
	match kind:
		"flag", "smoke", "fire", "bubbles", "sparkle", "arc", "dust":
			var anim := kind
			if kind == "flag":
				anim = "flag_" + _flag_color(str(ov.get("color", "")))
			elif kind == "fire" and ov.get("small", false):
				anim = "fire_small"
			elif kind == "sparkle":
				anim = "spark"
			if mode == "battle" and kind in ["dust"]:
				return
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.fx_frames(anim)
			a.animation = anim
			a.position = pos
			a.speed_scale = 0.85 + _rng_phase * 0.3
			a.frame = int(_rng_phase * 4.0)
			match kind:
				"flag":
					a.offset = Vector2(26, -14)
					a.scale = Vector2(0.8, 0.8)
				"smoke":
					a.offset = Vector2(0, -40)
					a.modulate.a = 0.85
				"fire":
					a.offset = Vector2(0, -36)
					a.scale = Vector2(0.6, 0.6)
				"bubbles":
					a.offset = Vector2(0, -24)
					a.modulate = Color(ov.get("color", "#ffffff")).lightened(0.5)
				"sparkle":
					a.modulate = Color(ov.get("color", "#ffffff"))
					a.scale = Vector2(0.9, 0.9)
				"arc":
					a.scale = Vector2(0.6, 0.6) if not ov.get("big", false) else Vector2(0.9, 0.9)
					a.offset = Vector2(0, -60)
					a.modulate = Color(ov.get("color", "#ffffff"))
			overlay_root.add_child(a)
			a.play()
		"gear":
			var g := Sprite2D.new()
			g.texture = Art.tex("fx", "gear" if float(ov.get("r", 20)) > 22 else "gear_small")
			g.position = pos
			var r := float(ov.get("r", 20))
			var s := r * 2.0 / g.texture.get_width() * 1.15
			g.scale = Vector2(s, s * 0.85)
			g.modulate = Color(ov.get("color", "#d9a441"))
			overlay_root.add_child(g)
			_gears.append([g, float(ov.get("speed", 1.0))])
		"beam", "orb":
			var glow := Sprite2D.new()
			glow.texture = Art.tex("fx", "spark/3")
			glow.position = pos
			glow.modulate = Color(1, 0.9, 0.6, 0.55) if kind == "beam" else Color(ov.get("color", "#ffffff"))
			glow.scale = Vector2(2.5, 2.5) if kind == "beam" else Vector2(1.2, 1.2)
			overlay_root.add_child(glow)
			var tw := glow.create_tween().set_loops()
			tw.tween_property(glow, "modulate:a", 0.25, 1.1 + _rng_phase).set_trans(Tween.TRANS_SINE)
			tw.tween_property(glow, "modulate:a", 0.75, 1.1 + _rng_phase).set_trans(Tween.TRANS_SINE)


func _flag_color(c: String) -> String:
	match c.to_upper():
		"#E8604C":
			return "coral"
		"#3EA7C9":
			return "teal"
		"#A06BFF", "#A678FF":
			return "shard"
		"#E8419A":
			return "gloom"
	return "amber"


func _process(delta: float) -> void:
	for g in _gears:
		var spr: Sprite2D = g[0]
		if is_instance_valid(spr):
			spr.rotation += delta * float(g[1])


# ------------------------------------------------------------- stato
func set_progress(frac: float, text: String) -> void:
	if absf(frac - progress) > 0.002 or text != progress_text:
		progress = frac
		progress_text = text
		queue_redraw()


func clear_progress() -> void:
	if progress >= 0.0:
		progress = -1.0
		queue_redraw()


func set_hp(frac: float) -> void:
	hp_frac = frac
	show_hp = frac < 0.999 and frac > 0.0
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()
	if v:
		var tw := create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.04, 0.96), 0.08)
		tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK)


func set_ghost(state: String) -> void:
	ghost_state = state
	match state:
		"valid":
			modulate = Color(0.75, 1.0, 0.75, 0.85)
		"invalid":
			modulate = Color(1.0, 0.6, 0.6, 0.75)
		_:
			modulate = Color.WHITE
	queue_redraw()


func pop() -> void:
	## Animazione "pop" a fine costruzione (scala 0,85 -> 1,05 -> 1,0 in 220 ms).
	var tw := create_tween()
	sprite.scale = Vector2(0.85, 0.85)
	tw.tween_property(sprite, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)


func show_bubble(res_name: String) -> void:
	if res_name == _bubble_res:
		return
	_bubble_res = res_name
	if bubble:
		bubble.queue_free()
		bubble = null
	if res_name == "":
		return
	bubble = Node2D.new()
	var bg := Sprite2D.new()
	bg.texture = Art.tex("ui", "ui/slot")
	bg.scale = Vector2(0.62, 0.62)
	bubble.add_child(bg)
	var ic := Sprite2D.new()
	ic.texture = Art.icon(res_name)
	ic.scale = Vector2(0.5, 0.5)
	bubble.add_child(ic)
	bubble.position = Vector2(0, sprite.offset.y + 10)
	add_child(bubble)
	var tw := bubble.create_tween().set_loops()
	tw.tween_property(bubble, "position:y", bubble.position.y - 10, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bubble, "position:y", bubble.position.y, 0.6).set_trans(Tween.TRANS_SINE)


func top_y() -> float:
	return sprite.offset.y if sprite else -80.0


func _draw() -> void:
	if selected or ghost_state != "":
		var col := Color(1, 0.95, 0.84, 0.9)
		if ghost_state == "invalid":
			col = Color(0.92, 0.35, 0.27, 0.9)
		elif ghost_state == "valid":
			col = Color(0.35, 0.82, 0.35, 0.9)
		var d := Iso.diamond(-n * 0.5, -n * 0.5, n)
		var poly := PackedVector2Array()
		for p in d:
			poly.append(p)
		draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.22))
		poly.append(d[0])
		draw_polyline(poly, col, 5.0, true)
		if selected and Balance.is_defense(id) and mode == "village":
			var dd := Balance.level_data(id, maxi(1, level))
			var r := (float(dd.get("range_max", 0)) + n * 0.5) * Iso.HW * 1.414
			_draw_iso_ellipse(r, Color(1, 1, 1, 0.5))
			if float(dd.get("range_min", 0)) > 0.0:
				_draw_iso_ellipse((float(dd["range_min"]) + n * 0.5) * Iso.HW * 1.414, Color(1, 0.4, 0.3, 0.5))
	var top := top_y()
	if progress >= 0.0:
		var w := 120.0
		var y := top - 34.0
		draw_rect(Rect2(-w / 2 - 3, y - 3, w + 6, 22), Color(0.18, 0.125, 0.21, 1))
		draw_rect(Rect2(-w / 2, y, w * clampf(progress, 0.0, 1.0), 16), Color(0.3, 0.89, 0.96, 1))
		if progress_text != "":
			var f: Font = UIK.title_font()
			draw_string_outline(f, Vector2(-w / 2, y - 8), progress_text, HORIZONTAL_ALIGNMENT_CENTER, w, 22, 6, Color(0.18, 0.125, 0.21))
			draw_string(f, Vector2(-w / 2, y - 8), progress_text, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color.WHITE)
	if show_hp and mode == "battle":
		var w2 := 70.0 + n * 14.0
		var y2 := top - 16.0
		draw_rect(Rect2(-w2 / 2 - 2, y2 - 2, w2 + 4, 14), Color(0.18, 0.125, 0.21, 1))
		var c := Color(0.92, 0.35, 0.27) if palette == "gloom" or mode == "battle" else Color(0.35, 0.82, 0.35)
		draw_rect(Rect2(-w2 / 2, y2, w2 * hp_frac, 10), c)


func _draw_iso_ellipse(r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, col, 3.0, true)
