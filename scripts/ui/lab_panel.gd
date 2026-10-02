extends Modal
## Laboratorio: ricerca dei livelli delle truppe (una alla volta), costo, tempo, requisiti, accelerazione.

var village: Node
var _status: Label
var _bar: Control


func _init() -> void:
	super._init(" ", Vector2(1680, 900))


func _ready() -> void:
	title = tr("building.laboratory")
	super._ready()
	EventBus.research_finished.connect(func(_a, _b): rebuild())


func build() -> void:
	var top := UIK.hbox(16)
	top.add_child(UIK.icon("lab", 70))
	_status = UIK.label("", 30)
	top.add_child(_status)
	_bar = UIK.bar(0.0, "bar_build", Vector2(460, 36))
	top.add_child(_bar)
	var job: Dictionary = GameState.data["research"]["job"]
	if not job.is_empty():
		var sp := UIK.button(tr("act.speedup"), "purple", "glimmers", Vector2(300, 96), 28)
		sp.pressed.connect(func() -> void:
			if not EconomyManager.speedup_research():
				toast(tr("err.no_glimmers"), "error"))
		top.add_child(sp)
	content.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for id in Balance.troop_order:
		grid.add_child(_card(id))
	content.add_child(scroll(grid))


func _card(id: String) -> Control:
	var lvl := GameState.troop_level(id)
	var maxed := lvl >= Balance.troop_max_level(id)
	var check := EconomyManager.research_check(id)
	var ok := check == EconomyManager.Err.OK or check == EconomyManager.Err.NO_RESOURCES
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(312, 250)
	var st := UIK.style("slot" if ok or maxed else "slot_dark")
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	var pic := UIK.icon_rect(Art.portrait(id), 150)
	pic.position = Vector2(8, 40)
	b.add_child(pic)
	var l := UIK.label("%s %d%s" % [tr("ui.lv"), lvl, "" if maxed else " > %d" % (lvl + 1)], 28, true, Color.WHITE, 6)
	l.position = Vector2(14, 8)
	b.add_child(l)
	var nm := UIK.label(tr("troop." + id), 24, true, Color.WHITE, 6)
	nm.position = Vector2(166, 50)
	b.add_child(nm)
	if maxed:
		var m := UIK.label(tr("ui.max_level"), 24, true, Color(0.7, 1, 0.7), 6)
		m.position = Vector2(166, 160)
		b.add_child(m)
	else:
		var row := Balance.lab_row(id, lvl + 1)
		var cr := UIK.cost_row({row["cost_res"]: float(row["cost"])}, 24)
		cr.position = Vector2(162, 150)
		b.add_child(cr)
		var tl := UIK.label(TimeManager.format_duration(float(row["time_s"])), 22, true, Color(1, 0.95, 0.84), 5)
		tl.position = Vector2(166, 100)
		b.add_child(tl)
		if check == EconomyManager.Err.NOT_UNLOCKED:
			var lk := UIK.label(tr("lab.req") % int(row["lab_req"]), 22, true, Color(1, 0.7, 0.65), 5)
			lk.position = Vector2(166, 200)
			b.add_child(lk)
	UIK._feedback(b)
	b.pressed.connect(func() -> void:
		var err := EconomyManager.start_research(id)
		if err == EconomyManager.Err.OK:
			AudioManager.sfx("spell_cast")
			rebuild()
		else:
			toast(EconomyManager.err_text(err), "error"))
	return b


func _process(_d: float) -> void:
	if not is_instance_valid(_status):
		return
	var job: Dictionary = GameState.data["research"]["job"]
	if job.is_empty():
		_status.text = tr("lab.idle")
		UIK.set_bar(_bar, 0.0)
	else:
		var rem := EconomyManager.research_remaining()
		var tot := maxf(1.0, float(job["end"]) - float(job["start"]))
		_status.text = "%s %s %d  -  %s" % [tr("troop." + str(job["id"])), tr("ui.lv"), int(job["level"]), TimeManager.format_duration(rem)]
		UIK.set_bar(_bar, 1.0 - rem / tot)
