extends Modal
## Esercito: truppe pronte (rimozione con "-"), coda di addestramento con avanzamento e completamento immediato,
## griglia delle truppe/incantesimi da addestrare (tocco per aggiungere, info), capacita' nel titolo.
## Trascinamento: trascinare una carta della griglia sulla riga "pronte" la aggiunge; trascinare una truppa pronta
## fuori dalla riga la rimuove (oltre ai pulsanti "+"/"-").

var village: Node
var tab := "troop"
var _queue_bar: Control
var _queue_label: Label
var _title_label: Label
var _ready_row: HBoxContainer


func _init() -> void:
	super._init(" ", Vector2(1720, 940))


func _ready() -> void:
	title = tr("army.title")
	super._ready()
	EventBus.army_changed.connect(_soft_refresh)


func build() -> void:
	var top := UIK.hbox(14)
	_title_label = UIK.label("", 34, true, UIK.INK)
	top.add_child(_title_label)
	top.add_child(UIK.spacer())
	for t in ["troop", "spell"]:
		var b := UIK.button(tr("army.tab." + t), "gold" if t == tab else "blue", "army" if t == "troop" else "spells", Vector2(280, 96), 30)
		b.pressed.connect(func() -> void:
			tab = t
			rebuild())
		top.add_child(b)
	content.add_child(top)
	# pronte
	var ready_panel := UIK.panel("panel_inset", Vector4(16, 10, 16, 10))
	var rv := UIK.vbox(6)
	rv.add_child(UIK.label(tr("army.ready_hint"), 24))
	_ready_row = UIK.hbox(10)
	_ready_row.custom_minimum_size = Vector2(0, 190)
	rv.add_child(_ready_row)
	ready_panel.add_child(rv)
	content.add_child(ready_panel)
	# coda
	var q := UIK.hbox(16)
	q.add_child(UIK.icon("timer", 60))
	_queue_label = UIK.label("", 28)
	q.add_child(_queue_label)
	_queue_bar = UIK.bar(0.0, "bar_build", Vector2(520, 36))
	q.add_child(_queue_bar)
	var fin := UIK.button(tr("army.finish_now"), "purple", "glimmers", Vector2(320, 96), 26)
	fin.pressed.connect(func() -> void:
		if not EconomyManager.finish_training_now(tab):
			toast(tr("err.no_glimmers"), "error"))
	q.add_child(fin)
	content.add_child(q)
	# griglia
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var ids: Array = Balance.troop_order if tab == "troop" else Balance.spell_order
	for id in ids:
		grid.add_child(_card(id))
	content.add_child(scroll(grid))
	_soft_refresh()


func _card(id: String) -> Control:
	var is_troop := tab == "troop"
	var unlocked := EconomyManager.troop_unlocked(id) if is_troop else EconomyManager.spell_unlocked(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(312, 220)
	var st := UIK.style("slot" if unlocked else "slot_dark")
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	var tex: Texture2D = Art.portrait(id) if is_troop else Art.tex("icons", "spell/" + id)
	var pic := UIK.icon_rect(tex, 156)
	pic.position = Vector2(8, 34)
	if not unlocked:
		pic.modulate = Color(0.45, 0.42, 0.5)
	b.add_child(pic)
	var lvl := GameState.troop_level(id) if is_troop else GameState.spell_level(id)
	var lv := UIK.label("%s %d" % [tr("ui.lv"), lvl], 26, true, Color.WHITE, 6)
	lv.position = Vector2(14, 8)
	b.add_child(lv)
	var nm := UIK.label(tr(("troop." if is_troop else "spell.") + id), 24, true, Color.WHITE, 6)
	nm.position = Vector2(164, 74)
	nm.size = Vector2(144, 30)
	nm.clip_text = true
	b.add_child(nm)
	if unlocked:
		var cost := EconomyManager.troop_cost(id) if is_troop else EconomyManager.spell_cost(id)
		var cr := UIK.cost_row(cost, 24)
		cr.position = Vector2(166, 150)
		b.add_child(cr)
		var sz := UIK.label("%s %d" % [tr("army.space"), int((Balance.troop(id, 1) if is_troop else Balance.spell(id, 1))["size"])], 22, true, Color(1, 0.95, 0.84), 5)
		sz.position = Vector2(166, 110)
		b.add_child(sz)
	else:
		var req := int(Balance.troop(id, 1)["barracks_req"]) if is_troop else Balance.spell_order.find(id) + 1
		var lk := UIK.label(tr("army.req_barracks" if is_troop else "army.req_forge") % req, 22, true, Color(1, 0.7, 0.65), 5)
		lk.position = Vector2(166, 150)
		lk.size = Vector2(140, 60)
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(lk)
	var info := UIK.icon_button("info", 52)
	info.position = Vector2(226, -4)
	info.custom_minimum_size = Vector2(88, 76)
	info.pressed.connect(func() -> void: _show_info(id))
	b.add_child(info)
	UIK._feedback(b)
	b.pressed.connect(func() -> void:
		var err := EconomyManager.train(tab, id)
		if err != EconomyManager.Err.OK:
			toast(EconomyManager.err_text(err), "error")
		else:
			AudioManager.sfx("troop_train"))
	b.set_drag_forwarding(func(_p: Vector2) -> Variant: return {"add": id} if unlocked else null, Callable(), Callable())
	return b


func _show_info(id: String) -> void:
	var d: Modal = load("res://scripts/ui/confirm_dialog.gd").new()
	var lines: Array = []
	if tab == "troop":
		var t := Balance.troop(id, GameState.troop_level(id))
		lines = [tr("troop." + id) + " - " + tr("role." + str(t["role"])), tr("desc.troop." + id),
			"%s: %s   %s: %s   %s: %s" % [tr("stat.hp"), UIK.num(t["hp"]), tr("stat.dps"), str(t["dps"]), tr("stat.speed"), str(t["speed"])],
			"%s: %s   %s: %s" % [tr("stat.range"), str(t["range"]), tr("stat.preference"), tr("pref." + str(t["preference"]))]]
	else:
		var s := Balance.spell(id, GameState.spell_level(id))
		lines = [tr("spell." + id), tr("desc.spell." + id), "%s: %s   %s: %s s" % [tr("stat.radius"), str(s["radius"]), tr("stat.duration"), str(s["duration_s"])]]
	d.set("text", "\n".join(lines))
	d.set("yes_text", tr("ui.ok"))
	get_parent().add_child(d)


func _soft_refresh() -> void:
	if not is_instance_valid(_ready_row):
		return
	var is_troop := tab == "troop"
	var cap := EconomyManager.army_capacity() if is_troop else EconomyManager.spell_capacity()
	var used := EconomyManager.army_space() if is_troop else EconomyManager.spell_space()
	_title_label.text = "%s  %d/%d" % [tr("army.title") if is_troop else tr("army.spells_title"), used, cap]
	for c in _ready_row.get_children():
		c.queue_free()
	var army: Dictionary = GameState.army_troops() if is_troop else GameState.army_spells()
	var queued := {}
	for q in GameState.data["training"]["troops" if is_troop else "spells"]:
		queued[q["id"]] = int(queued.get(q["id"], 0)) + 1
	var ids: Array = Balance.troop_order if is_troop else Balance.spell_order
	for id in ids:
		var n := int(army.get(id, 0))
		var qn := int(queued.get(id, 0))
		if n + qn <= 0:
			continue
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UIK.style("slot", Vector4(6, 6, 6, 6)))
		slot.custom_minimum_size = Vector2(160, 180)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(148, 168)
		var tex: Texture2D = Art.portrait(id) if is_troop else Art.tex("icons", "spell/" + id)
		var pic := UIK.icon_rect(tex, 130)
		pic.position = Vector2(8, 18)
		if n == 0:
			pic.modulate.a = 0.5
		holder.add_child(pic)
		var l := UIK.label("x%d" % n + ("  (+%d)" % qn if qn > 0 else ""), 26, true, Color.WHITE, 6)
		l.position = Vector2(4, -2)
		holder.add_child(l)
		var minus := UIK.icon_button("minus", 52)
		minus.custom_minimum_size = Vector2(80, 80)
		minus.position = Vector2(84, 102)
		minus.pressed.connect(func() -> void: EconomyManager.untrain(tab, id))
		holder.add_child(minus)
		slot.add_child(holder)
		slot.set_drag_forwarding(func(_p: Vector2) -> Variant: return {"remove": id}, Callable(), Callable())
		_ready_row.add_child(slot)
	_ready_row.set_drag_forwarding(Callable(), func(_p: Vector2, d: Variant) -> bool: return d is Dictionary and d.has("add"),
		func(_p: Vector2, d: Variant) -> void:
			var err := EconomyManager.train(tab, d["add"])
			if err != EconomyManager.Err.OK:
				toast(EconomyManager.err_text(err), "error"))
	box.set_drag_forwarding(Callable(), func(_p: Vector2, d: Variant) -> bool: return d is Dictionary and d.has("remove"),
		func(_p: Vector2, d: Variant) -> void: EconomyManager.untrain(tab, d["remove"]))


func _process(_delta: float) -> void:
	if not is_instance_valid(_queue_bar):
		return
	var rem := EconomyManager.training_remaining(tab)
	var q: Array = GameState.data["training"]["troops" if tab == "troop" else "spells"]
	if q.is_empty():
		_queue_label.text = tr("army.queue_empty")
		UIK.set_bar(_queue_bar, 0.0)
	else:
		var first: Dictionary = q[0]
		var started := float(GameState.data["training"][("troops" if tab == "troop" else "spells") + "_started"])
		var frac := clampf((TimeManager.now() - started) / maxf(0.1, float(first["time"])), 0.0, 1.0)
		_queue_label.text = "%s (%d)  %s" % [tr(("troop." if tab == "troop" else "spell.") + str(first["id"])), q.size(), TimeManager.format_duration(rem)]
		UIK.set_bar(_queue_bar, frac)
