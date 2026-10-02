class_name FxLayer
extends Node2D
## Effetti con object pooling: animazioni (esplosioni, colpi, fumo...), particelle (monete, detriti, stelle),
## proiettili con traiettoria (disegnati in _draw: dardi, palle di mortaio ad arco, lance, sfere) e archi elettrici.

const POOL_ANIM := 48
const POOL_PART := 96

var _anims: Array[AnimatedSprite2D] = []
var _parts: Array[Sprite2D] = []
var projectiles: Array = []      ## {from, to, t0, t1, kind, arc}
var arcs: Array = []             ## {a, b, until}
var _time := 0.0


func _ready() -> void:
	for i in POOL_ANIM:
		var a := AnimatedSprite2D.new()
		a.visible = false
		a.animation_finished.connect(_on_anim_done.bind(a))
		add_child(a)
		_anims.append(a)
	for i in POOL_PART:
		var s := Sprite2D.new()
		s.visible = false
		add_child(s)
		_parts.append(s)


func _on_anim_done(a: AnimatedSprite2D) -> void:
	a.visible = false


func play(anim: String, world: Vector2, sc: float = 1.0, offset: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	if not Art.quality_high and anim in ["smoke", "dust", "spark"]:
		return
	for a in _anims:
		if not a.visible:
			a.sprite_frames = Art.fx_frames(anim)
			a.animation = anim
			a.position = world
			a.offset = offset
			a.scale = Vector2(sc, sc)
			a.modulate = tint
			a.visible = true
			a.frame = 0
			a.play(anim)
			return


func _free_part() -> Sprite2D:
	for s in _parts:
		if not s.visible:
			return s
	return null


## Particelle che saltano e cadono (detriti) o volano verso un punto (monete verso la barra risorse).
func burst(key: String, world: Vector2, count: int, spread: float = 60.0, sc: float = 0.7) -> void:
	var n := count if Art.quality_high else maxi(1, count / 3)
	for i in n:
		var s := _free_part()
		if s == null:
			return
		s.texture = Art.tex("fx", "p/" + key)
		s.position = world
		s.scale = Vector2(sc, sc)
		s.modulate = Color.WHITE
		s.rotation = randf() * TAU
		s.visible = true
		var dest := world + Vector2(randf_range(-spread, spread), randf_range(-spread * 0.3, spread * 0.5))
		var peak := world.lerp(dest, 0.5) + Vector2(0, -randf_range(40, 110))
		var tw := s.create_tween()
		var dur := randf_range(0.45, 0.7)
		var move := func(t: float) -> void:
			var a := world.lerp(peak, t)
			var b := peak.lerp(dest, t)
			s.position = a.lerp(b, t)
			s.rotation += 0.15
		var hide_fn := func() -> void:
			s.visible = false
		tw.tween_method(move, 0.0, 1.0, dur)
		tw.tween_property(s, "modulate:a", 0.0, 0.25)
		tw.tween_callback(hide_fn)


## Particelle che volano verso una posizione sullo schermo (in coordinate mondo) e poi chiamano `done`.
func fly_to(key: String, world: Vector2, target_world: Vector2, count: int, done: Callable = Callable()) -> void:
	for i in count:
		var s := _free_part()
		if s == null:
			break
		s.texture = Art.tex("fx", "p/" + key)
		s.position = world + Vector2(randf_range(-20, 20), randf_range(-20, 10))
		s.scale = Vector2(0.75, 0.75)
		s.modulate = Color.WHITE
		s.rotation = 0
		s.visible = true
		var mid := s.position + Vector2(randf_range(-80, 80), -randf_range(60, 140))
		var start := s.position
		var tw := s.create_tween()
		tw.tween_interval(i * 0.04)
		var fly := func(t: float) -> void:
			s.position = start.lerp(mid, t).lerp(mid.lerp(target_world, t), t)
		var last := i == count - 1
		var finish := func() -> void:
			s.visible = false
			if last and done.is_valid():
				done.call()
		tw.tween_method(fly, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(finish)


func text_pop(world: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIK.title_font())
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.125, 0.21))
	l.add_theme_constant_override("outline_size", 10)
	l.position = world - Vector2(80, 60)
	l.size = Vector2(160, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 70, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(l.queue_free)


func add_projectile(kind: String, from: Vector2, to: Vector2, duration: float) -> void:
	projectiles.append({"kind": kind, "from": from, "to": to, "t0": _time, "t1": _time + maxf(0.03, duration)})


func add_arc(a: Vector2, b: Vector2, dur: float = 0.18) -> void:
	arcs.append({"a": a, "b": b, "until": _time + dur})


func _process(delta: float) -> void:
	_time += delta
	if not projectiles.is_empty() or not arcs.is_empty():
		projectiles = projectiles.filter(func(p): return _time < float(p["t1"]))
		arcs = arcs.filter(func(a): return _time < float(a["until"]))
		queue_redraw()


func _draw() -> void:
	var ink := Color(0.18, 0.125, 0.21)
	for p in projectiles:
		var t := clampf((_time - float(p["t0"])) / (float(p["t1"]) - float(p["t0"])), 0.0, 1.0)
		var a: Vector2 = p["from"]
		var b: Vector2 = p["to"]
		var pos := a.lerp(b, t)
		match p["kind"]:
			"lobber":
				var h := a.distance_to(b) * 0.45
				pos.y -= sin(t * PI) * h
				draw_circle(pos + Vector2(3, 3), 13, Color(0, 0, 0, 0.25))
				draw_circle(pos, 13, ink)
				draw_circle(pos, 9, Color(0.32, 0.29, 0.38))
			"storm_pylon":
				draw_circle(pos, 14, Color(0.3, 0.89, 0.96, 0.5))
				draw_circle(pos, 8, Color(1, 1, 1))
			_:
				var dir := (b - a).normalized()
				var plen := 34.0 if p["kind"] != "ballista" else 54.0
				pos.y -= sin(t * PI) * 30.0
				draw_line(pos - dir * plen, pos, ink, 9.0)
				draw_line(pos - dir * plen, pos, Color(0.85, 0.63, 0.4) if p["kind"] != "skyspear" else Color(0.95, 0.95, 1.0), 5.0)
				draw_circle(pos, 5, Color(0.9, 0.9, 0.95))
	for arc in arcs:
		var a2: Vector2 = arc["a"]
		var b2: Vector2 = arc["b"]
		var pts := PackedVector2Array([a2])
		var segs := 6
		for i in range(1, segs):
			var q := a2.lerp(b2, float(i) / segs)
			pts.append(q + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
		pts.append(b2)
		draw_polyline(pts, Color(0.75, 0.97, 1.0, 0.9), 7.0)
		draw_polyline(pts, Color(1, 1, 1), 3.0)
