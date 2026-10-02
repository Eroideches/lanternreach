extends Modal
## Dialogo di conferma Si'/No.

var text := ""
var on_yes: Callable
var yes_text := ""


func _init() -> void:
	super._init("", Vector2(900, 420))


func build() -> void:
	var l := UIK.label(text, 34, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(l)
	var h := UIK.hbox(30)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var no := UIK.button(tr("ui.no"), "red", "", Vector2(240, 110))
	no.pressed.connect(close)
	var yes := UIK.button(yes_text if yes_text != "" else tr("ui.yes"), "green", "", Vector2(240, 110))
	yes.pressed.connect(func() -> void:
		if on_yes.is_valid():
			on_yes.call()
		close())
	h.add_child(no)
	h.add_child(yes)
	content.add_child(h)
