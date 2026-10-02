extends Modal
## Negozio a categorie con anteprima, quantita' costruite/max, costo e requisiti di sblocco.

signal chosen(id: String)

var village: Node
var tab := "economy"


func _init() -> void:
	super._init("", Vector2(1640, 900))


func _ready() -> void:
	title = tr("shop.title")
	ribbon_color = "ribbon_blue"
	super._ready()


func set_arg(a: Variant) -> void:
	tab = str(a)


func build() -> void:
	var tabs := UIK.hbox(14)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in ["economy", "defense", "army", "trap"]:
		var b := UIK.button(tr("shop.tab." + t), "gold" if t == tab else "blue", "", Vector2(320, 100), 32)
		b.pressed.connect(func() -> void:
			tab = t
			rebuild())
		tabs.add_child(b)
	content.add_child(tabs)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	for id in Balance.shop_ids(tab):
		grid.add_child(_card(id))
	content.add_child(scroll(grid))


func _card(id: String) -> Control:
	var hl := GameState.hall_level()
	var allowed := Balance.count_allowed(id, hl)
	var have := GameState.count_of(id)
	var unlock := Balance.unlock_hall(id)
	var locked := unlock > hl
	var full := have >= allowed
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(290, 330)
	var st := UIK.style("slot_dark" if (locked or full) else "slot")
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	var v := UIK.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var name_l := UIK.label(tr("building." + id), 28, true, Color.WHITE, 8)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var pic := UIK.icon_rect(Art.thumb(id), 170)
	if locked:
		pic.modulate = Color(0.45, 0.42, 0.5)
	v.add_child(pic)
	var cnt := UIK.label("%d/%d" % [have, allowed], 26, true, Color.WHITE, 6)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(cnt)
	if locked:
		var lk := UIK.hbox(6)
		lk.alignment = BoxContainer.ALIGNMENT_CENTER
		lk.add_child(UIK.icon("lock", 44))
		lk.add_child(UIK.label(tr("ui.requires_hall") % unlock, 24, true, Color(1, 0.7, 0.65), 6))
		v.add_child(lk)
	else:
		var cr := UIK.cost_row(EconomyManager.cost_for(id, 1), 28)
		cr.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(cr)
	UIK._feedback(b)
	b.pressed.connect(func() -> void:
		var err := EconomyManager.check_new(id)
		if err == EconomyManager.Err.OK or err == EconomyManager.Err.NO_RESOURCES or (err == EconomyManager.Err.NO_BUILDER):
			if err == EconomyManager.Err.NO_BUILDER:
				toast(EconomyManager.err_text(err), "error")
				return
			chosen.emit(id)
			close()
		else:
			toast(EconomyManager.err_text(err), "error"))
	return b
