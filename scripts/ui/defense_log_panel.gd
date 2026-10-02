extends Modal
## Registro difese: attacchi subiti offline (attaccante, stelle, %, risorse perse, trofei) con replay; riarmo trappole.

var village: Node


func _init() -> void:
	super._init(" ", Vector2(1600, 900))


func _ready() -> void:
	title = tr("log.title")
	super._ready()
	for e in GameState.data["defense_log"]:
		e["seen"] = true
	EventBus.state_changed.emit()


func build() -> void:
	var top := UIK.hbox(16)
	var sh := float(GameState.data.get("shield_until", 0.0)) - TimeManager.now()
	top.add_child(UIK.icon("shield", 64))
	top.add_child(UIK.label(tr("log.shield") % TimeManager.format_duration(sh) if sh > 0 else tr("log.no_shield"), 28))
	top.add_child(UIK.spacer())
	var rc := OfflineAttacks.rearm_cost()
	if rc > 0:
		var rb := UIK.button(tr("act.rearm"), "gold", "", Vector2(380, 96), 28)
		var cr := UIK.cost_row({"cogs": rc}, 22)
		rb.add_child(cr)
		cr.position = Vector2(230, 54)
		rb.pressed.connect(func() -> void:
			if OfflineAttacks.rearm_all():
				rebuild()
			else:
				toast(tr("err.no_resources"), "error"))
		top.add_child(rb)
	content.add_child(top)
	var list := UIK.vbox(10)
	var log_entries: Array = GameState.data["defense_log"]
	if log_entries.is_empty():
		list.add_child(UIK.label(tr("log.empty"), 28))
	for e in log_entries:
		var row := UIK.panel("panel_inset", Vector4(16, 10, 16, 10))
		var h := UIK.hbox(16)
		var stars := UIK.hbox(0)
		for i in 3:
			stars.add_child(UIK.icon("star" if i < int(e["stars"]) else "star_empty", 44))
		h.add_child(stars)
		var v := UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIK.label("%s  (%s %d)" % [e["attacker"], tr("ui.hall_short"), int(e["attacker_hall"])], 28, true, UIK.INK))
		var ago := TimeManager.now() - float(e["time"])
		v.add_child(UIK.label(tr("log.ago") % TimeManager.format_duration(ago) + "  -  " + tr("log.destruction") % int(e["percent"]), 22))
		h.add_child(v)
		for r in ["cogs", "sap", "shards"]:
			var amount := float(e["loot"].get(r, 0))
			if amount > 0:
				h.add_child(UIK.icon(r, 44))
				h.add_child(UIK.label("-" + UIK.num(amount), 24, true, Color(1, 0.6, 0.55), 6))
		h.add_child(UIK.icon("trophy", 44))
		var td := int(e["trophies"])
		h.add_child(UIK.label(("+" if td >= 0 else "") + str(td), 26, true, UIK.GREEN if td >= 0 else UIK.RED, 6))
		var rp := UIK.button(tr("log.replay"), "blue", "replay", Vector2(230, 92), 26)
		var data: Dictionary = e["replay"]
		rp.pressed.connect(func() -> void: Router.go("battle", {"mode": "replay", "replay": data, "defense": true}))
		h.add_child(rp)
		row.add_child(h)
		list.add_child(row)
	content.add_child(scroll(list))
