class_name Modal
extends Control
## Pannello modale: oscuramento (150 ms) + pannello che compare con scala 0,9 -> 1,0 TRANS_BACK (220 ms),
## nastro titolo e pulsante chiudi con area di tocco estesa. Le sottoclassi riempiono `content` in build().

signal closed

var title := ""
var panel_size := Vector2(1500, 860)
var ribbon_color := "ribbon"
var dim: ColorRect
var box: PanelContainer
var content: VBoxContainer
var _closing := false
var close_on_dim := true


func _init(p_title: String = "", p_size: Vector2 = Vector2(1500, 860)) -> void:
	title = p_title
	panel_size = p_size


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.16, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if close_on_dim and e is InputEventScreenTouch and not e.pressed:
			close())
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box = UIK.panel("panel", Vector4(36, 60, 36, 36))
	box.custom_minimum_size = panel_size
	box.size = panel_size
	add_child(box)
	content = UIK.vbox(14)
	box.add_child(content)
	if title != "":
		var rib := UIK.nine(ribbon_color)
		rib.custom_minimum_size = Vector2(minf(panel_size.x * 0.6, 760), 104)
		rib.size = rib.custom_minimum_size
		add_child(rib)
		rib.set_meta("ribbon", true)
		var tl := UIK.label(title, 46, true, Color.WHITE, 12)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.set_anchors_preset(Control.PRESET_FULL_RECT)
		tl.offset_bottom = -12
		rib.add_child(tl)
	var cb := UIK.icon_button("close", 92)
	cb.pressed.connect(close)
	add_child(cb)
	cb.set_meta("closebtn", true)
	build()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_open_anim()
	EventBus.panel_opened.emit(get_class_name())
	AudioManager.sfx("ui_open", 0.02, 0.05, true)


func get_class_name() -> String:
	return title


func _layout() -> void:
	var vs := get_viewport_rect().size
	# dimensioni esplicite: un Control creato in codice sotto un CanvasLayer non eredita la dimensione dagli ancoraggi
	position = Vector2.ZERO
	size = vs
	dim.position = Vector2.ZERO
	dim.size = vs
	box.size = Vector2(minf(panel_size.x, vs.x - 40), minf(panel_size.y, vs.y - 90))
	box.position = (vs - box.size) * 0.5 + Vector2(0, 30)
	box.pivot_offset = box.size * 0.5
	for c in get_children():
		if c.has_meta("ribbon"):
			c.position = Vector2(box.position.x + (box.size.x - c.size.x) * 0.5, box.position.y - 52)
		elif c.has_meta("closebtn"):
			c.position = Vector2(box.position.x + box.size.x - c.custom_minimum_size.x * 0.6, box.position.y - c.custom_minimum_size.y * 0.4)


## Da ridefinire: costruisce il contenuto in `content`.
func build() -> void:
	pass


## Ricostruisce il contenuto (dopo un acquisto ecc.).
func rebuild() -> void:
	for c in content.get_children():
		c.queue_free()
	build()


func _open_anim() -> void:
	box.scale = Vector2(0.9, 0.9)
	box.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.15)
	tw.tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.12)


func close() -> void:
	if _closing:
		return
	_closing = true
	AudioManager.sfx("ui_close", 0.02, 0.05, true)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "modulate:a", 0.0, 0.15)
	tw.tween_property(box, "scale", Vector2(0.95, 0.95), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		EventBus.panel_closed.emit(get_class_name())
		queue_free())


## Contenitore scorrevole verticale per liste lunghe.
func scroll(child: Control, height: float = 0.0) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if height > 0:
		s.custom_minimum_size.y = height
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


func toast(text: String, kind: String = "info") -> void:
	UIK.toast(get_parent(), text, kind)
