extends Modal
## Obiettivi permanenti, missioni giornaliere e ricompensa di accesso (ciclo di 7 giorni).

var village: Node
var tab := "daily"


func _init() -> void:
	super._init(" ", Vector2(1600, 900))


func _ready() -> void:
	title = tr("quests.title")
	if Progression.ready_achievements() > 0 and not Progression.login_pending():
		tab = "achievements"
	super._ready()


func build() -> void:
	var tabs := UIK.hbox(14)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in ["daily", "achievements"]:
		var b := UIK.button(tr("quests.tab." + t), "gold" if t == tab else "blue", "", Vector2(360, 96), 30)
		b.pressed.connect(func() -> void:
			tab = t
			rebuild())
		tabs.add_child(b)
	content.add_child(tabs)
	if tab == "daily":
		_build_daily()
	else:
		_build_achievements()


func _build_daily() -> void:
	# accesso
	var login := UIK.panel("panel_dark", Vector4(20, 14, 20, 14))
	var lh := UIK.hbox(14)
	lh.add_child(UIK.icon("gift", 80))
	var cyc: Array = Balance.daily["login_cycle"]
	var day := int(GameState.data["progress"]["login"].get("cycle_day", 0)) % cyc.size()
	for i in cyc.size():
		var r: Dictionary = cyc[i]
		var cell := UIK.vbox(2)
		var past := i < day or (i == day and not Progression.login_pending())
		cell.add_child(UIK.label(tr("quests.day") % (i + 1), 20, true, Color.WHITE if i != day else Color(1, 0.85, 0.3), 5))
		var ic := _reward_icon(r)
		var icon_r := UIK.icon(ic, 64)
		if past:
			icon_r.modulate = Color(0.5, 0.5, 0.55)
		cell.add_child(icon_r)
		lh.add_child(cell)
	var claim := UIK.button(tr("quests.claim"), "green", "", Vector2(240, 100), 30)
	claim.disabled = not Progression.login_pending()
	claim.pressed.connect(func() -> void:
		var r := Progression.claim_login()
		if not r.is_empty():
			AudioManager.sfx("reward")
			rebuild())
	lh.add_child(UIK.spacer())
	lh.add_child(claim)
	login.add_child(lh)
	content.add_child(login)
	content.add_child(UIK.label(tr("quests.daily_hint"), 26))
	var ms: Array = GameState.data["progress"]["daily"].get("missions", [])
	for i in ms.size():
		var m: Dictionary = ms[i]
		var d := Progression.mission_def(m["id"])
		var row := UIK.panel("panel_inset", Vector4(18, 10, 18, 10))
		var h := UIK.hbox(18)
		h.add_child(UIK.icon("quests", 64))
		var v := UIK.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIK.label(tr("daily." + str(m["id"])) % UIK.num(float(d["target"])), 28))
		v.add_child(UIK.bar(float(m["progress"]) / maxf(1.0, float(d["target"])), "bar_hp", Vector2(600, 34), "%s/%s" % [UIK.num(float(m["progress"])), UIK.num(float(d["target"]))]))
		h.add_child(v)
		var rw := {}
		if int(d["reward_gems"]) > 0:
			rw["glimmers"] = int(d["reward_gems"])
		if int(d["reward_sap_per_hall"]) > 0:
			rw["sap"] = int(d["reward_sap_per_hall"]) * GameState.hall_level()
		var cr := UIK.hbox(4)
		for k in rw:
			cr.add_child(UIK.icon(k, 50))
			cr.add_child(UIK.label(UIK.num(float(rw[k])), 28, true, Color.WHITE, 6))
		h.add_child(cr)
		var idx := i
		var done := float(m["progress"]) >= float(d["target"])
		var b := UIK.button(tr("quests.claimed") if m["claimed"] else tr("quests.claim"), "green", "", Vector2(220, 96), 28)
		b.disabled = m["claimed"] or not done
		b.pressed.connect(func() -> void:
			if Progression.claim_mission(idx):
				AudioManager.sfx("reward")
				rebuild())
		h.add_child(b)
		row.add_child(h)
		content.add_child(row)


func _reward_icon(r: Dictionary) -> String:
	match r["reward"]:
		"cogs":
			return "cogs"
		"sap", "cogs_sap":
			return "sap"
		"shards_or_gems":
			return "shards"
	return "glimmers"


func _build_achievements() -> void:
	var list := UIK.vbox(10)
	for id in Progression.achievement_ids():
		var s := Progression.achievement_state(id)
		var rows: Array = s["rows"]
		var claimed := int(s["claimed"])
		var row := UIK.panel("panel_inset", Vector4(18, 8, 18, 8))
		var h := UIK.hbox(16)
		var stars := UIK.hbox(0)
		for i in rows.size():
			stars.add_child(UIK.icon("star" if i < claimed else "star_empty", 40))
		stars.custom_minimum_size = Vector2(130, 0)
		h.add_child(stars)
		var v := UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIK.label(tr("ach." + id + ".name"), 28, true, UIK.INK))
		var nxt: Dictionary = s["next"]
		if nxt.is_empty():
			v.add_child(UIK.label(tr("quests.completed"), 22))
		else:
			v.add_child(UIK.label(tr("ach." + id + ".desc") % UIK.num(float(nxt["target"])), 22))
			v.add_child(UIK.bar(float(s["value"]) / maxf(1.0, float(nxt["target"])), "bar_hp", Vector2(560, 30), "%s/%s" % [UIK.num(minf(float(s["value"]), float(nxt["target"]))), UIK.num(float(nxt["target"]))]))
		h.add_child(v)
		if not nxt.is_empty():
			var g := UIK.hbox(4)
			g.add_child(UIK.icon("glimmers", 50))
			g.add_child(UIK.label(str(nxt["reward_gems"]), 28, true, Color.WHITE, 6))
			h.add_child(g)
			var b := UIK.button(tr("quests.claim"), "green", "", Vector2(200, 92), 28)
			b.disabled = not s["ready"]
			b.pressed.connect(func() -> void:
				if Progression.claim_achievement(id) > 0:
					AudioManager.sfx("reward")
					rebuild())
			h.add_child(b)
		row.add_child(h)
		list.add_child(row)
	content.add_child(scroll(list))
