extends Node2D
## Scena battaglia. Modalita': "campaign" (livello n), "pvp" (base procedurale con "Prossimo"), "replay".
## La simulazione (BattleSim) avanza a passo fisso 30 tick/s; la vista interpola tra i tick.
## Schieramento: tocco o trascinamento sulla zona consentita (un'unita' ogni 0,12 s finche' si tiene premuto).

const SCOUT_TIME := 30.0
const DEPLOY_EVERY := 0.12

var mode := "campaign"
var params: Dictionary = {}
var sim: BattleSim
var replay: Replay
var base: Dictionary = {}
var palette := "gloom"
var cam: IsoCamera
var ground: IsoGround
var entities: Node2D
var fx: FxLayer
var ui_layer: CanvasLayer
var bviews: Array = []
var tviews: Dictionary = {}
var acc := 0.0
var speed := 1.0
var started := false
var scout_left := SCOUT_TIME
var selected := ""                 ## "troop:<id>" | "spell:<id>"
var slots: Dictionary = {}
var holding := false
var hold_world := Vector2()
var hold_timer := 0.0
var opponent_trophies := 0
var opponent_name := ""
var finished := false
var last_stars := 0
var rng := RandomNumberGenerator.new()
var loot_total: Dictionary = {}
var league_bonus := 0.0
# HUD
var lbl_timer: Label
var lbl_timer_sub: Label
var lbl_percent: Label
var star_icons: Array = []
var loot_labels: Dictionary = {}
var bottom_bar: HBoxContainer
var bottom_panel: PanelContainer
var left_box: VBoxContainer
var btn_end: Button
var btn_next: Button
var hint: Control


func _ready() -> void:
	params = Router.params
	mode = str(params.get("mode", "campaign"))
	rng.seed = int(GameState.data["rng_seed"]) + int(GameState.stat("searches")) * 7919 + int(TimeManager.now())
	ground = IsoGround.new()
	add_child(ground)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	fx = FxLayer.new()
	fx.z_index = 20
	add_child(fx)
	cam = IsoCamera.new()
	add_child(cam)
	cam.zoom = Vector2(0.5, 0.5)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_setup_battle()
	_build_hud()
	AudioManager.play_music("battle_theme")
	if mode != "replay":
		cam.dragging_object = true
		cam.grab_check = _grab_check
		cam.drag_started.connect(_on_press)
		cam.drag_moved.connect(func(w: Vector2) -> void: hold_world = w)
		cam.drag_ended.connect(func(_w: Vector2) -> void: holding = false)
		cam.tapped.connect(_on_tap_invalid)
	else:
		started = true


# ================================================================= setup
func _setup_battle() -> void:
	var army := {}
	match mode:
		"campaign":
			var n := int(params.get("level", 1))
			base = CampaignData.load_level(n)
			opponent_name = base["name"]
			army = GameState.battle_army()
		"pvp":
			_generate_opponent()
			army = GameState.battle_army()
		"replay":
			replay = Replay.new(params["replay"])
			sim = replay.sim
			base = sim.base_info
			opponent_name = tr("battle.replay")
	if mode != "replay":
		sim = BattleSim.new()
		sim.setup(base, army, rng.randi())
	palette = str(base.get("palette", "gloom"))
	ground.setup(palette)
	ground.deploy_mask = sim.deployable
	for r in ["cogs", "sap", "shards"]:
		loot_total[r] = float(base.get("loot", {}).get(r, 0.0))
	_build_views()
	var c := Vector2.ZERO
	for b in sim.buildings:
		c += b.center
	if not sim.buildings.is_empty():
		c /= sim.buildings.size()
	cam.position = Iso.to_world(c) + Vector2(0, 60)


func _generate_opponent() -> void:
	Progression.track("searches", 1)
	var own := Progression.trophies()
	var hall := BaseGenerator.hall_for_trophies(own, GameState.hall_level(), rng)
	base = BaseGenerator.generate(hall, rng.randi())
	base["loot"] = BaseGenerator.loot_for(hall, rng, GameState.hall_level())
	opponent_trophies = maxi(0, own + rng.randi_range(-150, 150))
	opponent_name = BaseGenerator.random_name(rng)
	league_bonus = float(Progression.league()["win_loot_bonus"])


func _build_views() -> void:
	for v in bviews:
		if is_instance_valid(v):
			v.queue_free()
	bviews.clear()
	var walls := {}
	for b in sim.buildings:
		if b.cat == "wall":
			walls[Vector2i(b.x, b.y)] = true
	for b in sim.buildings:
		var v := BuildingView.new()
		v.uid = b.i
		if b.cat == "wall":
			var m := 0
			if walls.has(Vector2i(b.x + 1, b.y)): m |= 1
			if walls.has(Vector2i(b.x, b.y + 1)): m |= 2
			if walls.has(Vector2i(b.x - 1, b.y)): m |= 4
			if walls.has(Vector2i(b.x, b.y - 1)): m |= 8
			v.wall_mask = m
		v.hidden_trap = b.cat == "trap"
		entities.add_child(v)
		v.setup(b.id, b.level, b.x, b.y, palette, "battle")
		bviews.append(v)


# =================================================================== HUD
func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	# alto-sinistra: avversario e bottino
	var lp := UIK.panel("panel_dark", Vector4(22, 14, 22, 16))
	var lv := UIK.vbox(4)
	lv.add_child(UIK.label(opponent_name, 34, true, Color.WHITE, 8))
	if mode == "pvp":
		var th := UIK.hbox(6)
		th.add_child(UIK.icon("trophy", 40))
		th.add_child(UIK.label(UIK.num(opponent_trophies), 26, true, Color.WHITE, 6))
		lv.add_child(th)
	lv.add_child(UIK.label(tr("battle.loot_available"), 22, true, Color(1, 0.95, 0.84), 5))
	for r in ["cogs", "sap", "shards"]:
		if float(loot_total[r]) <= 0 and r == "shards":
			continue
		var h := UIK.hbox(8)
		h.add_child(UIK.icon(r, 46))
		var l := UIK.label(UIK.num(float(loot_total[r])), 28, true, Color.WHITE, 6)
		h.add_child(l)
		loot_labels[r] = l
		lv.add_child(h)
	lp.add_child(lv)
	lp.position = Vector2(18, 16)
	root.add_child(lp)
	# centro: timer
	var rib := UIK.nine("ribbon")
	rib.custom_minimum_size = Vector2(320, 100)
	rib.size = rib.custom_minimum_size
	rib.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rib.position = Vector2(-160, 8)
	root.add_child(rib)
	lbl_timer = UIK.label("3:00", 50, true, Color.WHITE, 12)
	lbl_timer.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_timer.offset_bottom = -12
	rib.add_child(lbl_timer)
	lbl_timer_sub = UIK.label("", 24, true, Color.WHITE, 6)
	lbl_timer_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_timer_sub.position = Vector2(-300, 112)
	lbl_timer_sub.size = Vector2(600, 36)
	lbl_timer_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_timer_sub)
	# alto-destra: stelle e percentuale
	var rp := UIK.panel("panel_dark", Vector4(22, 12, 22, 14))
	var rv := UIK.vbox(2)
	var sh := UIK.hbox(10)
	for i in 3:
		var s := UIK.icon("star_empty", 86)
		star_icons.append(s)
		sh.add_child(s)
	rv.add_child(sh)
	lbl_percent = UIK.label(tr("battle.destruction") % 0, 30, true, Color.WHITE, 8)
	lbl_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(lbl_percent)
	rp.add_child(rv)
	rp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rp.position = Vector2(-380, 16)
	root.add_child(rp)
	# basso: truppe e incantesimi
	var bp := UIK.panel("panel_dark", Vector4(16, 12, 16, 12))
	bottom_panel = bp
	bottom_bar = UIK.hbox(10)
	bp.add_child(bottom_bar)
	bp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.add_child(bp)
	if mode != "replay":
		for id in Balance.troop_order:
			if sim.army.has(id) and int(sim.army[id]["count"]) > 0:
				_add_slot("troop", id, int(sim.army[id]["count"]), int(sim.army[id]["level"]))
		for id in Balance.spell_order:
			if sim.spell_stock.has(id) and int(sim.spell_stock[id]["count"]) > 0:
				_add_slot("spell", id, int(sim.spell_stock[id]["count"]), int(sim.spell_stock[id]["level"]))
	else:
		for sp in [1.0, 2.0, 4.0]:
			var b := UIK.button("%dx" % int(sp), "gold" if sp == 1.0 else "blue", "", Vector2(160, 110), 36)
			b.pressed.connect(func() -> void:
				speed = sp
				for c in bottom_bar.get_children():
					(c as Button).theme_type_variation = "ButtonBlue"
				b.theme_type_variation = "ButtonGold")
			bottom_bar.add_child(b)
	if not slots.is_empty():
		_select(slots.keys()[0])
	# basso-sinistra: fine / prossimo
	var left := UIK.vbox(12)
	left_box = left
	root.add_child(left)
	if mode == "pvp":
		btn_next = UIK.button(tr("battle.next"), "gold", "", Vector2(250, 110), 30)
		var cost := float(Balance.economy["matchmaking"]["search_cost_cogs_per_hall"][GameState.hall_level() - 1])
		var cr := UIK.cost_row({"cogs": cost}, 22)
		btn_next.add_child(cr)
		cr.position = Vector2(60, 66)
		btn_next.pressed.connect(func() -> void:
			if started:
				return
			if EconomyManager.spend({"cogs": cost}):
				Router.go("battle", {"mode": "pvp"})
			else:
				UIK.toast(ui_layer, tr("err.no_resources"), "error"))
		left.add_child(btn_next)
	btn_end = UIK.button(tr("battle.home") if mode != "replay" else tr("ui.back"), "red", "surrender" if mode != "replay" else "home", Vector2(250, 110), 30)
	btn_end.pressed.connect(_on_end_pressed)
	left.add_child(btn_end)
	_layout_hud.call_deferred()
	get_viewport().size_changed.connect(_layout_hud)
	if not GameState.data["tutorial"].get("done", false) and mode == "campaign":
		_show_hint(tr("tut.battle_deploy"))


## Posiziona barra truppe e pulsanti in basso (senza await: funziona anche nei test headless).
func _layout_hud() -> void:
	if not is_instance_valid(bottom_panel):
		return
	var vs := get_viewport_rect().size
	bottom_panel.reset_size()
	bottom_panel.position = Vector2((vs.x - bottom_panel.size.x) * 0.5, vs.y - bottom_panel.size.y - 12)
	left_box.reset_size()
	left_box.position = Vector2(18, vs.y - left_box.size.y - 190)


func _add_slot(kind: String, id: String, count: int, level: int) -> void:
	var key := kind + ":" + id
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(136, 160)
	b.add_theme_stylebox_override("normal", UIK.style("slot", Vector4(4, 4, 4, 4)))
	b.add_theme_stylebox_override("hover", UIK.style("slot", Vector4(4, 4, 4, 4)))
	b.add_theme_stylebox_override("pressed", UIK.style("slot_selected", Vector4(4, 4, 4, 4)))
	var tex: Texture2D = Art.portrait(id) if kind == "troop" else Art.tex("icons", "spell/" + id)
	var pic := UIK.icon_rect(tex, 112)
	pic.position = Vector2(12, 16)
	b.add_child(pic)
	var cnt := UIK.label("x%d" % count, 30, true, Color.WHITE, 8)
	cnt.position = Vector2(60, 2)
	b.add_child(cnt)
	var lv := UIK.label("%s%d" % [tr("ui.lv"), level], 22, true, Color(1, 0.95, 0.84), 5)
	lv.position = Vector2(10, 124)
	b.add_child(lv)
	b.pressed.connect(func() -> void: _select(key))
	bottom_bar.add_child(b)
	slots[key] = {"button": b, "count": cnt}


func _select(key: String) -> void:
	selected = key
	for k in slots:
		var b: Button = slots[k]["button"]
		var sel: bool = k == key
		b.add_theme_stylebox_override("normal", UIK.style("slot_selected" if sel else "slot", Vector4(4, 4, 4, 4)))
	AudioManager.click()


func _refresh_slots() -> void:
	for k in slots:
		var parts: PackedStringArray = k.split(":")
		var n := int(sim.army[parts[1]]["count"]) if parts[0] == "troop" else int(sim.spell_stock[parts[1]]["count"])
		(slots[k]["count"] as Label).text = "x%d" % n
		(slots[k]["button"] as Button).modulate = Color(1, 1, 1) if n > 0 else Color(0.5, 0.5, 0.55)
	if selected != "" and _selected_count() <= 0:
		for k in slots:
			var parts2: PackedStringArray = k.split(":")
			var n2 := int(sim.army[parts2[1]]["count"]) if parts2[0] == "troop" else int(sim.spell_stock[parts2[1]]["count"])
			if n2 > 0:
				_select(k)
				return


func _selected_count() -> int:
	if selected == "":
		return 0
	var parts: PackedStringArray = selected.split(":")
	return int(sim.army[parts[1]]["count"]) if parts[0] == "troop" else int(sim.spell_stock[parts[1]]["count"])


func _show_hint(text: String) -> void:
	if hint:
		hint.queue_free()
	var p := UIK.panel("tooltip", Vector4(30, 16, 30, 18))
	var l := UIK.label(text, 30, true, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	p.add_child(l)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-480, 120)
	ui_layer.add_child(p)
	hint = p


# ================================================================== input
func _grab_check(world: Vector2) -> bool:
	if finished or selected == "" or _selected_count() <= 0:
		return false
	var c := Iso.to_cell(world)
	if selected.begins_with("spell:"):
		return c.x >= 0 and c.y >= 0 and c.x < 44 and c.y < 44
	return sim.can_deploy_at(c)


func _on_press(world: Vector2) -> void:
	hold_world = world
	if selected.begins_with("spell:"):
		_deploy_at(world)
		return
	holding = true
	hold_timer = DEPLOY_EVERY
	_deploy_at(world)


func _on_tap_invalid(world: Vector2) -> void:
	if finished or selected == "":
		return
	var c := Iso.to_cell(world)
	if not sim.can_deploy_at(c):
		ground.show_deploy = true
		ground.queue_redraw()
		UIK.toast(ui_layer, tr("battle.cannot_deploy"), "error")
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			ground.show_deploy = false
			ground.queue_redraw())


func _deploy_at(world: Vector2) -> void:
	if finished or selected == "":
		return
	var c := Iso.to_cell(world)
	var parts: PackedStringArray = selected.split(":")
	var ok := false
	if parts[0] == "troop":
		ok = sim.deploy_troop(parts[1], c)
	else:
		ok = sim.cast_spell(parts[1], c)
	if ok:
		if not started:
			_start()
		_refresh_slots()
		if hint:
			hint.queue_free()
			hint = null


func _start() -> void:
	started = true
	if btn_next:
		btn_next.visible = false
	btn_end.text = tr("battle.end")


func _on_end_pressed() -> void:
	if mode == "replay":
		Router.go("village")
		return
	if not started:
		Router.go("village")
		return
	var d: Modal = load("res://scripts/ui/confirm_dialog.gd").new()
	d.set("text", tr("battle.surrender_confirm"))
	d.set("on_yes", func() -> void: sim.surrender())
	ui_layer.add_child(d)


# ================================================================== loop
func _process(delta: float) -> void:
	if finished:
		return
	if not started:
		scout_left -= delta
		lbl_timer.text = _fmt(scout_left)
		lbl_timer_sub.text = tr("battle.scouting")
		if scout_left <= 0.0:
			_start()
		return
	if holding:
		hold_timer -= delta
		if hold_timer <= 0.0:
			hold_timer = DEPLOY_EVERY
			if sim.can_deploy_at(Iso.to_cell(hold_world)):
				_deploy_at(hold_world)
	acc += delta * speed
	var steps := 0
	while acc >= BattleSim.DT and steps < 8:
		acc -= BattleSim.DT
		steps += 1
		if replay:
			replay.advance()
		else:
			sim.step()
		_after_tick()
		if sim.ended:
			_on_ended()
			return
	var alpha := acc / BattleSim.DT
	for idx in tviews:
		(tviews[idx] as TroopView).interpolate(alpha)
	var left := float(sim.max_ticks - sim.tick) / BattleSim.TICK_RATE
	lbl_timer.text = _fmt(left)
	lbl_timer_sub.text = tr("battle.ends_in")


func _fmt(sec: float) -> String:
	var s := int(ceil(maxf(0.0, sec)))
	return "%d:%02d" % [s / 60, s % 60]


func _after_tick() -> void:
	for ev in sim.events:
		_handle_event(ev)
	for t in sim.troops:
		if t.alive and tviews.has(t.i):
			(tviews[t.i] as TroopView).sim_update(t.pos, t.facing, t.attacking, t.hp / t.max_hp)
	for b in sim.buildings:
		if b.alive and b.cat != "trap" and b.hp < b.max_hp:
			(bviews[b.i] as BuildingView).set_hp(b.hp / b.max_hp)
	# HUD
	var p := sim.percent()
	lbl_percent.text = tr("battle.destruction") % p
	var st := sim.stars()
	while last_stars < st:
		last_stars += 1
		_star_gained(last_stars)
	for r in loot_labels:
		(loot_labels[r] as Label).text = UIK.num(maxf(0.0, float(loot_total[r]) - float(sim.loot_taken[r])))


func _star_gained(n: int) -> void:
	var s: TextureRect = star_icons[n - 1]
	s.texture = Art.icon("star")
	s.pivot_offset = s.size * 0.5
	var tw := s.create_tween()
	s.scale = Vector2(2.2, 2.2)
	tw.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	AudioManager.sfx("star%d" % n)


func _world_of_building(i: int) -> Vector2:
	return (bviews[i] as BuildingView).position


func _troop_world(i: int) -> Vector2:
	return Iso.to_world(sim.troops[i].pos)


func _handle_event(ev: Dictionary) -> void:
	match ev["t"]:
		"deploy":
			var t: BattleSim.STroop = sim.troops[int(ev["troop"])]
			var tv := TroopView.new()
			entities.add_child(tv)
			tv.setup(t.i, t.id, t.pos)
			tviews[t.i] = tv
			fx.play("dust", Iso.to_world(t.pos), 0.6)
			AudioManager.sfx("deploy", 0.1, 0.06)
		"spell":
			var anim := "ring_mending" if ev["id"] == "mending_mist" else "ring_fervor"
			var d := Balance.spell(ev["id"], 1)
			fx.play(anim, Iso.to_world(ev["pos"]), float(d["radius"]) * 2.0 * Iso.HW / 240.0)
			AudioManager.sfx("spell_cast")
		"hit":
			var t2: BattleSim.STroop = sim.troops[int(ev["troop"])]
			var bw := _world_of_building(int(ev["b"]))
			if t2.atk_range > 2.0:
				fx.add_projectile("boltpost", _troop_world(t2.i) + Vector2(0, -40), bw + Vector2(0, -40), 0.15)
				AudioManager.sfx("arrow", 0.1, 0.08)
			else:
				AudioManager.sfx("hit_melee", 0.15, 0.06)
			fx.play("hit", bw + Vector2(randf_range(-30, 30), -50 + randf_range(-20, 10)), 0.8)
		"blast":
			var w := Iso.to_world(ev["pos"])
			fx.play("explosion", w, 0.7, Vector2(0, -60))
			AudioManager.sfx("explosion", 0.1, 0.05)
			cam.shake(4.0, 0.12)
		"destroyed":
			_on_building_destroyed(int(ev["b"]))
		"fire":
			var b: BattleSim.SBuilding = sim.buildings[int(ev["b"])]
			var from := _world_of_building(b.i) + Vector2(0, (bviews[b.i] as BuildingView).top_y() * 0.6)
			var to := _troop_world(int(ev["troop"])) + Vector2(0, -30 if not sim.troops[int(ev["troop"])].flying else -90)
			match b.id:
				"arc_coil", "storm_pylon":
					fx.add_arc(from, to)
					AudioManager.sfx("zap", 0.1, 0.08)
				"cinder_spout":
					fx.play("muzzle_fire", from.lerp(to, 0.5), 0.6)
					AudioManager.sfx("fire", 0.1, 0.25)
				"frost_spire":
					AudioManager.sfx("freeze", 0.1, 0.3)
				"thumper":
					fx.play("shock", to, 0.9)
					AudioManager.sfx("hit_melee", 0.05, 0.06)
					cam.shake(3.0, 0.1)
				_:
					var dist := from.distance_to(to)
					var spd: float = BattleSim.PROJ_SPEED.get(b.id, 15.0) * Iso.HW * 1.2
					fx.add_projectile(b.id, from, to, dist / spd)
					fx.play("muzzle", from, 0.5)
					AudioManager.sfx({"lobber": "shot_mortar", "skyspear": "shot_air", "ballista": "shot_bolt"}.get(b.id, "shot_bolt"), 0.1, 0.07)
		"impact":
			var w2 := Iso.to_world(ev["pos"])
			if ev["kind"] == "lobber" or ev["kind"] == "storm_pylon":
				fx.play("explosion", w2, 0.5, Vector2(0, -60))
				AudioManager.sfx("explosion", 0.15, 0.1)
			else:
				fx.play("hit", w2 + Vector2(0, -30), 0.6)
		"chain":
			fx.add_arc(_troop_world(int(ev["from"])) + Vector2(0, -30), _troop_world(int(ev["to"])) + Vector2(0, -30))
		"frost":
			fx.play("shock", Iso.to_world(ev["pos"]), 1.4, Vector2.ZERO, Color(0.6, 0.9, 1.0))
		"trap":
			var tb: BattleSim.SBuilding = sim.buildings[int(ev["b"])]
			var tv2: BuildingView = bviews[tb.i]
			tv2.sprite.visible = true
			var tw := tv2.create_tween()
			tw.tween_interval(0.5)
			tw.tween_property(tv2, "modulate:a", 0.0, 0.4)
			match tb.id:
				"bomb_trap", "air_mine":
					fx.play("explosion", tv2.position, 0.8, Vector2(0, -50))
					AudioManager.sfx("trap_bomb")
					cam.shake(5.0, 0.15)
				"spring_pad":
					AudioManager.sfx("trap_spring")
				"snare_trap":
					fx.play("shock", tv2.position, 1.6)
					AudioManager.sfx("freeze")
		"launched":
			var idx := int(ev["troop"])
			if tviews.has(idx):
				var lv: TroopView = tviews[idx]
				tviews.erase(idx)
				lv.dead = true
				var tw2 := lv.create_tween()
				tw2.tween_property(lv, "position", lv.position + Vector2(randf_range(-200, 200), -400), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw2.parallel().tween_property(lv, "modulate:a", 0.0, 0.6)
				tw2.tween_callback(lv.queue_free)
		"death":
			var di := int(ev["troop"])
			if tviews.has(di):
				(tviews[di] as TroopView).die()
				tviews.erase(di)
				AudioManager.sfx("troop_death", 0.15, 0.08)
		"surge":
			fx.play("shock", _troop_world(int(ev["troop"])), 1.6, Vector2.ZERO, Color(1, 0.6, 0.3))
			AudioManager.sfx("spell_cast")


func _on_building_destroyed(i: int) -> void:
	var b: BattleSim.SBuilding = sim.buildings[i]
	var v: BuildingView = bviews[i]
	if b.cat == "wall":
		fx.burst("debris_stone", v.position + Vector2(0, -20), 4, 40, 0.5)
		v.queue_free()
		AudioManager.sfx("wall_break", 0.1, 0.05)
		return
	if b.cat == "trap":
		return
	fx.play("explosion", v.position, 0.6 + b.n * 0.25, Vector2(0, -70))
	fx.burst("debris_wood", v.position + Vector2(0, -40), 4 + b.n * 2, 40.0 * b.n, 0.6)
	fx.burst("debris_stone", v.position + Vector2(0, -40), 3 + b.n * 2, 40.0 * b.n, 0.6)
	if b.loot.size() > 0:
		fx.burst("coin_cog", v.position + Vector2(0, -60), 5, 60, 0.6)
	cam.shake(6.0, 0.18)
	AudioManager.sfx("building_destroyed", 0.1, 0.05)
	# rovina al posto dell'edificio
	var r := Art.region("fx", "rubble/%d" % b.n)
	v.sprite.texture = Art.tex("fx", "rubble/%d" % b.n)
	v.sprite.offset = -Vector2(r["anchor"][0], r["anchor"][1])
	v.sprite.flip_h = false
	v.show_hp = false
	v.clear_overlays()
	v.queue_redraw()
	v.z_index = -1


# ================================================================= fine
func _on_ended() -> void:
	finished = true
	holding = false
	cam.dragging_object = false
	var res := sim.result()
	# i risultati si applicano subito (anche se la scena viene chiusa); il pannello compare dopo 0,8 s
	var extra := {}
	if mode != "replay":
		extra = _apply_results(res)
	AudioManager.stop_music()
	get_tree().create_timer(0.8).timeout.connect(_show_results.bind(res, extra))


func _show_results(res: Dictionary, extra: Dictionary) -> void:
	if not is_inside_tree():
		return
	AudioManager.sfx("victory" if int(res["stars"]) > 0 else "defeat", 0.0, 0.1)
	var p: Modal = load("res://scripts/ui/results_panel.gd").new()
	p.set("result", res)
	p.set("extra", extra)
	p.set("battle", self)
	ui_layer.add_child(p)


func _apply_results(_res: Dictionary) -> Dictionary:
	var extra := BattleRewards.apply(mode, sim, {"level": int(params.get("level", 1)), "opponent_trophies": opponent_trophies, "league_bonus": league_bonus})
	SaveManager.save()
	return extra
