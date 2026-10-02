extends Modal
## Attacca: ricerca di un avversario (basi procedurali, costo per Hall) e mappa della campagna (25 livelli, stelle).

var village: Node


func _init() -> void:
	super._init(" ", Vector2(1720, 940))


func _ready() -> void:
	title = tr("attack.title")
	super._ready()


func build() -> void:
	var top := UIK.hbox(24)
	var army := GameState.battle_army()
	var troops_n := 0
	for id in army["troops"]:
		troops_n += int(army["troops"][id]["count"])
	# carta multiplayer
	var mp := UIK.panel("panel_dark", Vector4(24, 18, 24, 18))
	var mv := UIK.vbox(10)
	mv.add_child(UIK.label(tr("attack.pvp"), 38, true, Color.WHITE, 8))
	var desc := UIK.label(tr("attack.pvp_desc"), 24, false, Color(1, 0.95, 0.84))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(560, 0)
	mv.add_child(desc)
	var cost := float(Balance.economy["matchmaking"]["search_cost_cogs_per_hall"][GameState.hall_level() - 1])
	var find := UIK.button(tr("attack.find"), "red", "attack", Vector2(560, 120), 36)
	var cr := UIK.cost_row({"cogs": cost}, 26)
	find.add_child(cr)
	cr.position = Vector2(370, 70)
	find.disabled = troops_n == 0
	find.pressed.connect(func() -> void:
		if not EconomyManager.spend({"cogs": cost}):
			toast(tr("err.no_resources"), "error")
			return
		Router.go("battle", {"mode": "pvp"}))
	mv.add_child(find)
	var sh := float(GameState.data.get("shield_until", 0.0)) - TimeManager.now()
	if sh > 0:
		mv.add_child(UIK.label(tr("attack.shield_warning"), 22, false, Color(1, 0.8, 0.6)))
	mp.add_child(mv)
	top.add_child(mp)
	var army_box := UIK.panel("panel_inset", Vector4(18, 14, 18, 14))
	var av := UIK.vbox(6)
	av.add_child(UIK.label(tr("attack.your_army"), 28, true, UIK.INK))
	var row := UIK.hbox(6)
	for id in army["troops"]:
		var c := Control.new()
		c.custom_minimum_size = Vector2(96, 110)
		var p := UIK.icon_rect(Art.portrait(id), 92)
		c.add_child(p)
		var l := UIK.label("x%d" % int(army["troops"][id]["count"]), 24, true, Color.WHITE, 6)
		l.position = Vector2(40, 74)
		c.add_child(l)
		row.add_child(c)
	if troops_n == 0:
		row.add_child(UIK.label(tr("attack.no_army"), 26, false, UIK.RED))
	av.add_child(row)
	army_box.add_child(av)
	army_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(army_box)
	content.add_child(top)
	content.add_child(UIK.label(tr("attack.campaign") + "  (%d/75)" % Progression.campaign_total_stars(), 34, true, UIK.INK))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for n in range(1, Balance.campaign.size() + 1):
		grid.add_child(_level(n, troops_n > 0))
	content.add_child(scroll(grid))


func _level(n: int, has_army: bool) -> Control:
	var lv := Balance.campaign_level(n)
	var unlocked := Progression.campaign_unlocked(n)
	var stars := Progression.campaign_stars(n)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 170)
	var boss := bool(lv["boss"])
	var st := UIK.style("slot_selected" if boss and unlocked else ("slot" if unlocked else "slot_dark"))
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	var num := UIK.label(str(n), 48, true, Color.WHITE, 10)
	num.position = Vector2(0, 14)
	num.size = Vector2(170, 60)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(num)
	var sr := UIK.hbox(0)
	sr.position = Vector2(14, 78)
	for i in 3:
		sr.add_child(UIK.icon("star" if i < stars else "star_empty", 46))
	b.add_child(sr)
	var nm := UIK.label(CampaignData.tr_name(n), 15, true, Color.WHITE, 4)
	nm.position = Vector2(4, 122)
	nm.size = Vector2(162, 46)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	b.add_child(nm)
	if not unlocked:
		var lk := UIK.icon("lock", 56)
		lk.position = Vector2(110, 0)
		b.add_child(lk)
	UIK._feedback(b)
	b.pressed.connect(func() -> void:
		if not unlocked:
			toast(tr("attack.locked"), "error")
		elif not has_army:
			toast(tr("attack.no_army"), "error")
		else:
			Router.go("battle", {"mode": "campaign", "level": n}))
	return b
