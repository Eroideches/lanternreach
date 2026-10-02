extends Modal
## Pannello edificio: anteprima, descrizione, statistiche "attuale > successivo", tempo, requisiti, Potenzia/Accelera.

var uid := -1
var village: Node


func _init() -> void:
	super._init(" ", Vector2(1500, 860))


func _ready() -> void:
	var e := GameState.get_entity(uid)
	title = "%s  %s %d" % [tr("building." + str(e["id"])), tr("ui.lv"), maxi(1, int(e.get("level", 1)))]
	super._ready()


func build() -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty():
		return
	var id: String = e["id"]
	var lvl := maxi(1, int(e["level"]))
	var maxed := int(e["level"]) >= Balance.max_level(id)
	var nxt := lvl + 1 if not maxed else lvl
	var h := UIK.hbox(30)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(h)
	# anteprima e descrizione
	var left := UIK.vbox(10)
	left.custom_minimum_size = Vector2(440, 0)
	var info := Art.building_sprite(id, lvl, "player") if id != "wall" else Art.wall_sprite(lvl, 5, "player")
	var pic := UIK.icon_rect(info.get("tex"), 400)
	left.add_child(pic)
	var desc := UIK.label(tr("desc." + id), 24)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(420, 0)
	left.add_child(desc)
	h.add_child(left)
	var right := UIK.vbox(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var cur := Balance.level_data(id, lvl)
	var nd := Balance.level_data(id, nxt)
	for st in _stats(id, cur, nd, maxed):
		right.add_child(_stat_row(st))
	right.add_child(UIK.spacer(0, 0))
	var foot := UIK.vbox(14)
	right.add_child(foot)
	if not e.get("job", {}).is_empty():
		var rem := EconomyManager.remaining(e)
		var row := UIK.hbox(16)
		row.add_child(UIK.icon("timer", 64))
		row.add_child(UIK.label(tr("ui.in_progress") + ": " + TimeManager.format_duration(rem), 32))
		foot.add_child(row)
		var sp := UIK.button("%s  %d" % [tr("act.speedup"), EconomyManager.speedup_cost_for(e)], "purple", "glimmers", Vector2(420, 120))
		sp.pressed.connect(func() -> void:
			if EconomyManager.speedup(uid):
				AudioManager.sfx("speedup")
				close()
			else:
				toast(tr("err.no_glimmers"), "error"))
		foot.add_child(sp)
		return
	if maxed:
		foot.add_child(UIK.label(tr("ui.max_level"), 36, true, UIK.INK))
		return
	var inset := UIK.panel("panel_inset", Vector4(20, 12, 20, 12))
	var ih := UIK.hbox(18)
	ih.add_child(UIK.icon("timer", 60))
	ih.add_child(UIK.label(tr("ui.time") + ": " + TimeManager.format_duration(EconomyManager.time_for(id, nxt)) if EconomyManager.time_for(id, nxt) > 0 else tr("ui.instant"), 30))
	var req := int(nd.get("req_hall", 1))
	if id != "lantern_hall" and req > GameState.hall_level():
		ih.add_child(UIK.spacer(30))
		ih.add_child(UIK.icon("lock", 52))
		ih.add_child(UIK.label(tr("ui.requires_hall") % req, 30, false, UIK.RED))
	inset.add_child(ih)
	foot.add_child(inset)
	var btns := UIK.hbox(20)
	var costs := EconomyManager.cost_for(id, nxt)
	var up := UIK.button("", "green", "", Vector2(480, 150))
	var uv := UIK.vbox(0)
	uv.alignment = BoxContainer.ALIGNMENT_CENTER
	uv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	uv.offset_bottom = -14
	uv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ul := UIK.label(tr("act.upgrade"), 40, true, Color.WHITE, 10)
	ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uv.add_child(ul)
	var cr := UIK.cost_row(costs, 32)
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	uv.add_child(cr)
	up.add_child(uv)
	up.pressed.connect(_on_upgrade)
	btns.add_child(up)
	foot.add_child(btns)


func _stats(id: String, cur: Dictionary, nd: Dictionary, maxed: bool) -> Array:
	var out: Array = []
	var cat := Balance.category(id)
	var pairs: Array = []
	match cat:
		"defense":
			pairs = [["dps", "attack", "stat.dps"], ["hp", "shield", "stat.hp"]]
			out.append({"icon": "info", "label": tr("stat.range"), "text": "%s - %s %s" % [cur["range_min"], cur["range_max"], tr("ui.cells")], "frac": 1.0})
			out.append({"icon": "info", "label": tr("stat.targets"), "text": tr("targets." + str(cur["targets"])), "frac": 1.0})
		"economy":
			pairs = [["prod_per_hour", EconomyManager.extractor_resource(id), "stat.prod"], ["capacity", "timer", "stat.capacity"], ["hp", "shield", "stat.hp"]]
		"storage":
			pairs = [["capacity", "cogs" if id == "cog_vault" else ("sap" if id == "sap_cistern" else "shards"), "stat.capacity"], ["hp", "shield", "stat.hp"]]
		"wall":
			pairs = [["hp", "shield", "stat.hp"]]
		"trap":
			for k in ["damage", "launch_max_space", "freeze_seconds"]:
				if cur.has(k):
					pairs.append([k, "attack", "stat." + k])
		"core":
			pairs = [["hp", "shield", "stat.hp"], ["stored_cogs", "cogs", "stat.capacity"], ["stored_sap", "sap", "stat.capacity"]]
		_:
			match id:
				"army_camp":
					pairs = [["army_capacity", "army", "stat.army_capacity"], ["hp", "shield", "stat.hp"]]
				"laboratory":
					pairs = [["max_troop_level", "lab", "stat.max_troop_level"], ["hp", "shield", "stat.hp"]]
				"spell_forge":
					pairs = [["spell_slots", "spells", "stat.spell_slots"], ["hp", "shield", "stat.hp"]]
				"clan_hall":
					pairs = [["clan_slots", "clan", "stat.clan_slots"], ["hp", "shield", "stat.hp"]]
				_:
					pairs = [["hp", "shield", "stat.hp"]]
	var top := Balance.level_data(id, Balance.max_level(id))
	for p in pairs:
		var k: String = p[0]
		var a := float(cur.get(k, 0))
		var b := float(nd.get(k, a))
		var mx := maxf(1.0, float(top.get(k, b)))
		var txt := UIK.num(a) if maxed or is_equal_approx(a, b) else "%s > %s" % [UIK.num(a), UIK.num(b)]
		if k == "freeze_seconds":
			txt = "%.1f s" % a if maxed else "%.1f > %.1f s" % [a, b]
		out.append({"icon": p[1], "label": tr(p[2]), "text": txt, "frac": a / mx, "frac2": b / mx})
	if id == "barracks":
		var names: Array = []
		for t in str(cur.get("troops_unlocked", "")).split(","):
			if t != "":
				names.append(tr("troop." + t))
		out.append({"icon": "army", "label": tr("stat.unlocks"), "text": ", ".join(names), "frac": 1.0})
	return out


func _stat_row(st: Dictionary) -> Control:
	var row := UIK.hbox(16)
	row.add_child(UIK.icon(st["icon"], 64))
	var v := UIK.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIK.label(st["label"], 28))
	var b := UIK.bar(float(st.get("frac", 1.0)), "bar_hp", Vector2(760, 38), st["text"])
	if st.has("frac2") and float(st["frac2"]) > float(st["frac"]):
		var ghost := UIK.nine("bar_build")
		ghost.position = Vector2(2, 2)
		ghost.size = Vector2(maxf(30, 756 * float(st["frac2"])), 34)
		ghost.modulate.a = 0.45
		b.add_child(ghost)
		b.move_child(ghost, 1)
	v.add_child(b)
	row.add_child(v)
	return row


func _on_upgrade() -> void:
	var err := EconomyManager.start_upgrade(uid)
	if err == EconomyManager.Err.OK:
		close()
		return
	if err == EconomyManager.Err.NO_BUILDER:
		var q := EconomyManager.enqueue_upgrade(uid)
		toast(tr("toast.queued") if q == EconomyManager.Err.OK else EconomyManager.err_text(q), "info")
		close()
		return
	if err == EconomyManager.Err.NO_RESOURCES and village and village.has_method("_offer_buy_missing"):
		var e := GameState.get_entity(uid)
		village._offer_buy_missing(EconomyManager.cost_for(e["id"], int(e["level"]) + 1))
		close()
		return
	toast(EconomyManager.err_text(err), "error")
