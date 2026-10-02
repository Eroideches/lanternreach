extends Node
## Cambio scena con transizione (chiusura/apertura in 2 x 250 ms) e passaggio di parametri.

const SCENES := {
	"village": "res://scenes/village.tscn",
	"battle": "res://scenes/battle.tscn",
}

var params: Dictionary = {}
var _layer: CanvasLayer
var _rect: ColorRect
var busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = Color(0.18, 0.125, 0.21, 1)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_layer.add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func go(scene: String, p: Dictionary = {}) -> void:
	if busy:
		return
	busy = true
	params = p
	_rect.position = Vector2.ZERO
	_rect.size = get_viewport().get_visible_rect().size
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, 0.25)
	await tw.finished
	get_tree().change_scene_to_file(SCENES.get(scene, scene))
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "modulate:a", 0.0, 0.25)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
