class_name IsoCamera
extends Camera2D
## Controlli touch: pan con un dito (con inerzia), pinch-zoom con due dita (limiti), rotella del mouse,
## tap (rilascio senza movimento), long-press (>= 0,5 s fermo) e trascinamento di oggetti in modalita' modifica.

signal tapped(world: Vector2)
signal long_pressed(world: Vector2)
signal drag_started(world: Vector2)
signal drag_moved(world: Vector2)
signal drag_ended(world: Vector2)

const TAP_SLOP := 14.0
const LONG_PRESS := 0.5
const ZOOM_MIN := 0.32
const ZOOM_MAX := 1.35

var touches: Dictionary = {}          ## index -> posizione schermo
var _press_pos := Vector2()
var _press_time := 0.0
var _moved := false
var _long_fired := false
var _pinch_dist := 0.0
var _pinch_zoom := 1.0
var _velocity := Vector2()
var dragging_object := false          ## modalita' modifica: i trascinamenti che iniziano su un oggetto lo spostano
var grab_check: Callable              ## func(world: Vector2) -> bool : il tocco e' sull'oggetto trascinabile?
var _obj := false                     ## il gesto corrente sta trascinando un oggetto
var input_enabled := true
var world_bounds := Rect2(-2900, -100, 5800, 2950)


func _ready() -> void:
	zoom = Vector2(0.62, 0.62)
	position = Iso.to_world(Vector2(22, 22))
	make_current()


func screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			touches[t.index] = t.position
			if touches.size() == 1:
				_press_pos = t.position
				_press_time = Time.get_ticks_msec() / 1000.0
				_moved = false
				_long_fired = false
				_velocity = Vector2.ZERO
				var w := screen_to_world(t.position)
				_obj = dragging_object and grab_check.is_valid() and bool(grab_check.call(w))
				if _obj:
					drag_started.emit(w)
			elif touches.size() == 2:
				var pts: Array = touches.values()
				_pinch_dist = (pts[0] as Vector2).distance_to(pts[1])
				_pinch_zoom = zoom.x
				_moved = true
		else:
			var was_single := touches.size() == 1
			touches.erase(t.index)
			if was_single:
				if _obj:
					_obj = false
					drag_ended.emit(screen_to_world(t.position))
				elif not _moved and not _long_fired:
					tapped.emit(screen_to_world(t.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		touches[d.index] = d.position
		if touches.size() >= 2:
			var pts: Array = touches.values()
			var dist: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 1.0:
				_set_zoom(_pinch_zoom * dist / _pinch_dist, ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5)
		else:
			if d.position.distance_to(_press_pos) > TAP_SLOP:
				_moved = true
			if _obj:
				drag_moved.emit(screen_to_world(d.position))
			elif _moved:
				position -= d.relative / zoom.x
				_velocity = -d.relative / zoom.x / maxf(0.001, get_process_delta_time())
				_clamp()
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		var m := event as InputEventMagnifyGesture
		_set_zoom(zoom.x * m.factor, m.position)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x * 1.1, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x / 1.1, mb.position)


func _set_zoom(z: float, focus_screen: Vector2) -> void:
	var before := screen_to_world(focus_screen)
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	force_update_scroll()
	var after := screen_to_world(focus_screen)
	position += before - after
	_clamp()


func _clamp() -> void:
	position.x = clampf(position.x, world_bounds.position.x, world_bounds.end.x)
	position.y = clampf(position.y, world_bounds.position.y, world_bounds.end.y)


func _process(delta: float) -> void:
	if touches.size() == 1 and not _moved and not _long_fired and not _obj:
		if Time.get_ticks_msec() / 1000.0 - _press_time >= LONG_PRESS:
			_long_fired = true
			long_pressed.emit(screen_to_world(_press_pos))
	if touches.is_empty() and _velocity.length() > 5.0:
		position += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
		_clamp()


func focus_on(world: Vector2, z: float = -1.0) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", world, 0.3)
	if z > 0.0:
		tw.parallel().tween_property(self, "zoom", Vector2(z, z), 0.3)


var _shake := 0.0


## Screen shake leggero (ampiezza px, durata s), disattivabile nelle impostazioni.
func shake(amount: float = 6.0, duration: float = 0.18) -> void:
	if not GameState.settings().get("shake", true):
		return
	var tw := create_tween()
	for i in 6:
		var k := 1.0 - float(i) / 6.0
		tw.tween_property(self, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * k, duration / 6.0)
	tw.tween_property(self, "offset", Vector2.ZERO, 0.03)
