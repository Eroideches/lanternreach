extends Modal
## Clan (struttura dati + UI di base, servizio locale): crea / cerca / entra; vista membri e chat locale simulata.

var village: Node
var view := "home"            ## home | create
var _chat_box: VBoxContainer
var _badge := 0


func _init() -> void:
	super._init(" ", Vector2(1640, 920))


func _ready() -> void:
	title = tr("clan.title")
	super._ready()


func build() -> void:
	if GameState.count_of("clan_hall") == 0 or GameState.highest_level("clan_hall") == 0:
		var l := UIK.label(tr("clan.need_hall"), 32)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(l)
		return
	if ClanService.in_clan():
		_build_clan()
	elif view == "create":
		_build_create()
	else:
		_build_browse()


func _badge_icon(i: int, size: float) -> Control:
	var c := UIK.icon("clan", size)
	c.modulate = Color.from_hsv(float(i) / 12.0, 0.55, 1.0)
	return c


func _build_browse() -> void:
	var top := UIK.hbox(14)
	top.add_child(UIK.label(tr("clan.browse"), 34, true, UIK.INK))
	top.add_child(UIK.spacer())
	var cb := UIK.button(tr("clan.create"), "green", "plus", Vector2(320, 100), 30)
	cb.pressed.connect(func() -> void:
		view = "create"
		rebuild())
	top.add_child(cb)
	content.add_child(top)
	var list := UIK.vbox(10)
	for c in ClanService.browse():
		var row := UIK.panel("panel_inset", Vector4(16, 8, 16, 8))
		var h := UIK.hbox(16)
		h.add_child(_badge_icon(int(c["badge"]), 80))
		var v := UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIK.label(c["name"], 30, true, UIK.INK))
		v.add_child(UIK.label(tr(c["description"]), 22))
		h.add_child(v)
		h.add_child(UIK.icon("army", 50))
		h.add_child(UIK.label("%d/%d" % [c["members"].size(), int(Balance.economy["clan"]["member_cap"])], 26, true, UIK.INK))
		h.add_child(UIK.icon("trophy", 50))
		h.add_child(UIK.label(str(c["trophy_min"]), 26, true, UIK.INK))
		var jb := UIK.button(tr("clan.join"), "blue", "", Vector2(200, 92), 28)
		var clan: Dictionary = c
		jb.pressed.connect(func() -> void:
			var err := ClanService.join(clan)
			if err == EconomyManager.Err.OK:
				rebuild()
			else:
				toast(tr("clan.join_fail"), "error"))
		h.add_child(jb)
		row.add_child(h)
		list.add_child(row)
	content.add_child(scroll(list))


func _build_create() -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 16)
	g.add_child(UIK.label(tr("clan.name"), 30, true, UIK.INK))
	var name_le := LineEdit.new()
	name_le.max_length = 18
	name_le.custom_minimum_size = Vector2(600, 80)
	g.add_child(name_le)
	g.add_child(UIK.label(tr("clan.badge"), 30, true, UIK.INK))
	var bh := UIK.hbox(4)
	for i in 12:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 96)
		var ic := _badge_icon(i, 72)
		ic.position = Vector2(6, 10)
		b.add_child(ic)
		if i == _badge:
			b.add_theme_stylebox_override("normal", UIK.style("slot_selected", Vector4(4, 4, 4, 4)))
		var idx := i
		b.pressed.connect(func() -> void:
			_badge = idx
			rebuild())
		bh.add_child(b)
	g.add_child(bh)
	g.add_child(UIK.label(tr("clan.description"), 30, true, UIK.INK))
	var desc := LineEdit.new()
	desc.max_length = 120
	desc.custom_minimum_size = Vector2(600, 80)
	g.add_child(desc)
	g.add_child(UIK.label(tr("clan.trophy_min"), 30, true, UIK.INK))
	var tm := SpinBox.new()
	tm.min_value = 0
	tm.max_value = 3200
	tm.step = 100
	tm.custom_minimum_size = Vector2(240, 80)
	g.add_child(tm)
	content.add_child(g)
	var h := UIK.hbox(20)
	var back := UIK.button(tr("ui.back"), "blue", "", Vector2(240, 104))
	back.pressed.connect(func() -> void:
		view = "home"
		rebuild())
	h.add_child(back)
	var create := UIK.button(tr("clan.create"), "green", "", Vector2(420, 104))
	var cr := UIK.cost_row({"cogs": float(Balance.economy["clan"]["create_cost_cogs"])}, 24)
	create.add_child(cr)
	cr.position = Vector2(250, 56)
	create.pressed.connect(func() -> void:
		if name_le.text.strip_edges().length() < 3:
			toast(tr("clan.name_short"), "error")
			return
		var err := ClanService.create(name_le.text, _badge, desc.text, int(tm.value))
		if err == EconomyManager.Err.OK:
			view = "home"
			rebuild()
		else:
			toast(EconomyManager.err_text(err), "error"))
	h.add_child(create)
	content.add_child(h)


func _build_clan() -> void:
	var c := ClanService.current()
	var top := UIK.hbox(16)
	top.add_child(_badge_icon(int(c["badge"]), 96))
	var v := UIK.vbox(2)
	v.add_child(UIK.label(c["name"], 38, true, UIK.INK))
	var dsc: String = str(c.get("description", ""))
	v.add_child(UIK.label(tr(dsc) if dsc.begins_with("clan.") else dsc, 24))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(v)
	var leave := UIK.button(tr("clan.leave"), "red", "", Vector2(220, 96), 28)
	leave.pressed.connect(func() -> void:
		ClanService.leave()
		rebuild())
	top.add_child(leave)
	content.add_child(top)
	var h := UIK.hbox(20)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# membri
	var members := UIK.vbox(6)
	var sorted: Array = c["members"].duplicate()
	sorted.sort_custom(func(a, b): return int(a["trophies"]) > int(b["trophies"]))
	for m in sorted:
		var row := UIK.panel("panel_inset", Vector4(12, 6, 12, 6))
		var mh := UIK.hbox(10)
		mh.add_child(UIK.label(m["name"], 26, true, UIK.INK))
		mh.add_child(UIK.label(tr("clan.role." + str(m["role"])), 20))
		mh.add_child(UIK.spacer())
		mh.add_child(UIK.icon("trophy", 40))
		mh.add_child(UIK.label(str(m["trophies"]), 24, true, UIK.INK))
		row.add_child(mh)
		members.add_child(row)
	var ms := scroll(members)
	ms.custom_minimum_size = Vector2(620, 0)
	ms.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(ms)
	# chat
	var chat := UIK.vbox(8)
	chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_box = UIK.vbox(6)
	var cs := scroll(_chat_box)
	chat.add_child(cs)
	var ih := UIK.hbox(10)
	var le := LineEdit.new()
	le.placeholder_text = tr("clan.chat_placeholder")
	le.max_length = 200
	le.custom_minimum_size = Vector2(600, 84)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(le)
	var send := UIK.button(tr("clan.send"), "green", "chat", Vector2(200, 92), 28)
	var do_send := func() -> void:
		ClanService.post(le.text)
		le.text = ""
		_fill_chat()
		await get_tree().process_frame
		cs.scroll_vertical = int(cs.get_v_scroll_bar().max_value)
	send.pressed.connect(do_send)
	le.text_submitted.connect(func(_t: String) -> void: do_send.call())
	ih.add_child(send)
	chat.add_child(ih)
	h.add_child(chat)
	content.add_child(h)
	_fill_chat()


func _fill_chat() -> void:
	for c in _chat_box.get_children():
		c.queue_free()
	for m in ClanService.current().get("chat", []):
		var txt: String = tr(m["text"]) if m.get("key", false) else str(m["text"])
		var who: String = str(m.get("author", ""))
		var l := UIK.label(("%s: %s" % [who, txt]) if who != "" else txt, 24, false, UIK.INK if not m.get("system", false) else Color(0.4, 0.35, 0.5))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if m.get("me", false):
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_chat_box.add_child(l)
