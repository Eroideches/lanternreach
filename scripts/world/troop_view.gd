class_name TroopView
extends Node2D
## Vista di una truppa in battaglia: AnimatedSprite2D con walk/attack/death in 2 direzioni + specchiatura (4 dir.),
## interpolazione tra due tick della simulazione, barra vita, ombra per i volanti.

var idx := -1
var id := ""
var anim: AnimatedSprite2D
var flying := false
var dead := false
var _last_anim := ""
var hp_frac := 1.0
var _prev_world := Vector2()
var _cur_world := Vector2()
var _flash := 0.0


func setup(p_idx: int, p_id: String, cell_pos: Vector2) -> void:
	idx = p_idx
	id = p_id
	flying = bool(Art.troop_meta(id).get("flying", false))
	anim = AnimatedSprite2D.new()
	anim.sprite_frames = Art.troop_frames(id)
	anim.centered = false
	anim.offset = -Art.troop_origin(id)
	add_child(anim)
	anim.play("walk_down")
	_cur_world = Iso.to_world(cell_pos)
	_prev_world = _cur_world
	position = _cur_world
	scale = Vector2(0.9, 0.9)
	# comparsa
	anim.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(anim, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


## Chiamato a ogni tick della simulazione.
func sim_update(cell_pos: Vector2, facing: Vector2, attacking: bool, hp: float) -> void:
	_prev_world = _cur_world
	_cur_world = Iso.to_world(cell_pos)
	if hp < hp_frac - 0.001:
		_flash = 0.06
	hp_frac = hp
	# direzione a schermo: facing (celle) -> mondo
	var sd := Iso.to_world(facing) - Iso.to_world(Vector2.ZERO)
	var up := sd.y < -0.01
	var an := ("attack_" if attacking else "walk_") + ("up" if up else "down")
	anim.flip_h = sd.x < 0.0
	if an != _last_anim:
		_last_anim = an
		anim.play(an)
	queue_redraw()


func interpolate(alpha: float) -> void:
	if not dead:
		position = _prev_world.lerp(_cur_world, alpha)


func die() -> void:
	if dead:
		return
	dead = true
	var up := _last_anim.ends_with("up")
	anim.play("death_up" if up else "death_down")
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		anim.modulate = Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE


func _draw() -> void:
	if dead:
		return
	if hp_frac < 0.999:
		var w := 44.0
		var y := -Art.troop_origin(id).y * 0.75 - 10.0
		draw_rect(Rect2(-w / 2 - 2, y - 2, w + 4, 10), Color(0.18, 0.125, 0.21))
		draw_rect(Rect2(-w / 2, y, w * hp_frac, 6), Color(0.35, 0.82, 0.35))
