extends Node
## Guida le scene del gioco e salva gli screenshot (vedi tools/capture.gd).

const OUT := "res://docs/screens/"


func _ready() -> void:
	_run()


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("screenshot: ", name, " ", img.get_size())


func scene() -> Node:
	return get_tree().current_scene


func demo_village() -> void:
	GameState.new_game(false)
	GameState.data["tutorial"]["done"] = true
	GameState.data["player"]["name"] = "Lumen Vale"
	GameState.data["player"]["level"] = 12
	GameState.data["player"]["xp"] = 300
	GameState.data["player"]["trophies"] = 1142
	GameState.data["builders"] = 4
	var h := GameState.hall()
	h["level"] = 6
	# rimuovi i depositi iniziali e ricostruisci un villaggio "maturo"
	for b in GameState.buildings().duplicate():
		if b["id"] != "lantern_hall":
			GameState.remove_entity(int(b["uid"]))
	for o in GameState.data["obstacles"].duplicate():
		GameState.remove_entity(int(o["uid"]))
	GameState.move_building(int(h["uid"]), 20, 20, false)
	var layout := [["barracks", 6, 9, 27], ["boltpost", 5, 17, 17], ["boltpost", 4, 25, 18], ["lobber", 5, 24, 23], ["skyspear", 5, 17, 25],
		["arc_coil", 3, 16, 21], ["cog_vault", 6, 21, 15], ["sap_cistern", 6, 15, 26], ["ballista", 2, 26, 26],
		["thumper", 1, 22, 26], ["cog_mine", 6, 11, 14], ["cog_mine", 5, 13, 11], ["sap_well", 6, 29, 13],
		["sap_well", 5, 31, 16], ["barracks", 6, 10, 28], ["army_camp", 5, 14, 31], ["laboratory", 4, 30, 22],
		["spell_forge", 2, 29, 29], ["clan_hall", 3, 21, 31], ["shard_drill", 2, 33, 27], ["shard_crate", 2, 8, 22],
		["cog_vault", 5, 26, 10], ["sap_cistern", 5, 9, 17], ["army_camp", 5, 34, 33], ["boltpost", 4, 12, 22]]
	for e in layout:
		if GameState.can_place(e[0], e[2], e[3]):
			GameState.add_building(e[0], e[2], e[3], e[1])
	for x in range(15, 30):
		for y in [15, 29]:
			if GameState.can_place("wall", x, y):
				GameState.add_building("wall", x, y, 5)
	for y in range(16, 29):
		for x in [15, 29]:
			if GameState.can_place("wall", x, y):
				GameState.add_building("wall", x, y, 5)
	# un cantiere in corso
	var t := TimeManager.now()
	var p := GameState.find_free_spot("cog_vault", Vector2i(35, 22))
	var nb := GameState.add_building("cog_vault", p.x, p.y, 0)
	nb["job"] = {"type": "build", "start": t - 300, "end": t + 7900, "target": 1, "costs": {}}
	for b in GameState.buildings_of("cog_mine") + GameState.buildings_of("sap_well"):
		b["stored"] = 5000.0
		b["last_prod"] = t
	GameState.data["res"] = {"cogs": 184250.0, "sap": 66300.0, "shards": 1240.0, "glimmers": 268.0}
	GameState.data["army"]["troops"] = {"cogling": 26, "slingwisp": 18, "bulwark": 4, "kegger": 2, "rustjaw": 1, "kitewing": 2}
	for pos in [Vector2i(6, 9), Vector2i(36, 10), Vector2i(37, 34), Vector2i(5, 37), Vector2i(39, 20)]:
		if GameState.can_place("sapling", pos.x, pos.y):
			GameState.add_obstacle("sapling" if pos.x % 2 == 0 else "boulder", pos.x, pos.y)
	GameState.data["army"]["spells"] = {"mending_mist": 1, "fervor_surge": 1}
	GameState.data["research"]["levels"] = {"cogling": 4, "slingwisp": 3, "bulwark": 2}
	GameState.data["shield_until"] = t + 7.0 * 3600.0
	for n in range(1, 9):
		GameState.data["progress"]["campaign"][str(n)] = 3 if n < 6 else 2
	Progression.refresh_daily(t)
	Progression.claim_login()
	GameState.rebuild_index()


func _run() -> void:
	await wait(0.2)
	# 1) avvio: EroideGames e splash
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await wait(1.0)
	await shot("01_boot_eroidegames")
	await wait(1.4)
	await shot("02_splash_lanternreach")
	await wait(3.0)
	# 2) villaggio dimostrativo
	demo_village()
	load("res://scripts/app/main.gd").apply_settings()
	get_tree().change_scene_to_file("res://scenes/village.tscn")
	await wait(1.2)
	await shot("03_village")
	var v: Node = scene()
	v._select(int(GameState.buildings_of("boltpost")[0]["uid"]))
	await wait(0.6)
	await shot("04_village_selected")
	v._deselect()
	v.open_building_panel(int(GameState.buildings_of("boltpost")[0]["uid"]))
	await wait(0.6)
	await shot("05_building_panel")
	v.current_panel.close()
	await wait(0.3)
	for key in ["shop", "army", "lab", "attack", "quests", "settings", "clan", "log"]:
		v.open_panel(key)
		await wait(0.6)
		await shot("06_panel_" + key)
		v.current_panel.close()
		await wait(0.3)
	v.start_place("boltpost")
	await wait(0.5)
	await shot("07_place_mode")
	v._cancel_edit()
	await input_checks_village(v)
	# 3) battaglia di campagna (Marea d'Ombra) a meta' combattimento
	Router.params = {"mode": "campaign", "level": 9}
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
	await wait(0.8)
	var b: Node = scene()
	await shot("08_battle_scouting")
	await input_checks_battle(b)
	var cells: Array = BattleAI._side_cells(b.sim, RandomNumberGenerator.new())
	var order := ["troop:bulwark", "troop:cogling", "troop:slingwisp", "troop:kegger", "troop:rustjaw", "troop:kitewing", "troop:mender"]
	for key in order:
		if b.slots.has(key):
			b._select(key)
			for i in 10:
				b._deploy_at(Iso.to_world(cells[i % cells.size()] + Vector2(0.5, 0.5)))
	b._select("spell:fervor_surge")
	b._deploy_at(Iso.to_world(cells[0] + Vector2(3.5, 3.5)))
	await wait(9.0)
	await shot("09_battle_fight")
	await wait(9.0)
	await shot("10_battle_fight2")
	b.sim.surrender()
	await wait(1.6)
	await shot("11_battle_results")
	# 4) tutorial di una nuova partita
	GameState.new_game(true)
	load("res://scripts/app/main.gd").apply_settings()
	get_tree().change_scene_to_file("res://scenes/village.tscn")
	await wait(1.2)
	await shot("12_tutorial_start")
	await play_tutorial()
	print("cattura completata")
	get_tree().quit()


## Gioca il tutorial attraverso l'interfaccia reale e verifica che arrivi in fondo.
func play_tutorial() -> void:
	var v: Node = scene()
	var tut: Node = v.tutorial
	var log_step := func(tag: String) -> void:
		print("tutorial: ", tag, " -> passo ", GameState.data["tutorial"]["step"])
	tut._on_next()                                   # benvenuto
	log_step.call("benvenuto")
	for id in ["cog_mine", "sap_well"]:
		v.open_panel("shop")
		await wait(0.4)
		v.current_panel.chosen.emit(id)
		v.current_panel.close()
		await wait(0.4)
		v._confirm_edit()
		log_step.call("piazzato " + id)
		await wait(3.2)                              # accelerazione gratuita del tutorial
		log_step.call("completato " + id)
	await shot("13_tutorial_collect")
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	v._on_tap(v.world_pos_of(int(mine["uid"])) + Vector2(0, -20))
	await wait(0.8)
	log_step.call("raccolta")
	v.start_place("barracks")
	v._confirm_edit()
	await wait(3.2)
	log_step.call("caserma")
	v.open_panel("army")
	await wait(0.4)
	for i in 5:
		EconomyManager.train("troop", "cogling")
	await wait(0.6)
	await shot("14_tutorial_train")
	v.current_panel.close()
	await wait(0.4)
	log_step.call("addestramento")
	# primo attacco: livello 1 della campagna
	Router.params = {"mode": "campaign", "level": 1}
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
	await wait(0.8)
	var b: Node = scene()
	await shot("15_tutorial_battle_hint")
	var cells: Array = BattleAI._side_cells(b.sim, RandomNumberGenerator.new())
	for i in 5:
		b._deploy_at(Iso.to_world(cells[i % cells.size()] + Vector2(0.5, 0.5)))
	b.speed = 4.0
	var guard := 0
	while not b.finished and guard < 400:
		await wait(0.25)
		guard += 1
	await wait(1.2)
	await shot("16_tutorial_battle_won")
	print("tutorial: battaglia finita, stelle livello 1 = ", Progression.campaign_stars(1))
	get_tree().change_scene_to_file("res://scenes/village.tscn")
	await wait(1.2)
	v = scene()
	log_step.call("ritorno al villaggio")
	v.start_place("boltpost")
	v._confirm_edit()
	await wait(0.6)
	log_step.call("difesa")
	var h := GameState.hall()
	await wait(0.4)
	EconomyManager.start_upgrade(int(h["uid"]))
	await wait(0.6)
	log_step.call("potenziamento Faro")
	await wait(3.4)
	log_step.call("Faro completato")
	await shot("17_tutorial_done_dialog")
	if v.tutorial and is_instance_valid(v.tutorial):
		v.tutorial._on_next()
	await wait(0.6)
	print("tutorial: completato = ", GameState.data["tutorial"]["done"], ", Faro Madre Lv ", GameState.hall_level(), ", Glimmers ", GameState.res("glimmers"))


# ---------------------------------------------------------- input touch reali
func _screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	get_viewport().push_input(e)


func drag(pos: Vector2, rel: Vector2, index: int = 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	get_viewport().push_input(e)


func input_checks_village(v: Node) -> void:
	# 1) tap su una miniera piena: raccolta
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	mine["stored"] = 3000.0
	mine["last_prod"] = TimeManager.now()
	GameState.data["res"]["cogs"] = 1000.0
	var p := _screen(v.world_pos_of(int(mine["uid"])) + Vector2(0, -30))
	touch(p, true)
	await wait(0.1)
	touch(p, false)
	await wait(0.5)
	print("input: tap raccolta -> Cogs ", GameState.res("cogs"), " (prima 1000) ", "OK" if GameState.res("cogs") > 1000.0 else "FALLITO")
	# 2) long-press su una torre: modalita' modifica, trascinamento, annulla
	# la torre piu' in primo piano (le altre possono essere coperte dal Faro Madre)
	var bolts: Array = GameState.buildings_of("boltpost")
	bolts.sort_custom(func(a, b): return int(a["x"]) + int(a["y"]) > int(b["x"]) + int(b["y"]))
	var bolt: Dictionary = bolts[0]
	var bp := _screen(v.world_pos_of(int(bolt["uid"])) + Vector2(0, -40))
	touch(bp, true)
	await wait(0.8)
	var in_edit: bool = v.mode == "edit"
	touch(bp, false)
	await wait(0.2)
	var start_cell: Vector2i = v.edit_cell
	touch(bp, true)
	for i in 6:
		drag(bp + Vector2(30 * (i + 1), 15 * (i + 1)), Vector2(30, 15))
		await wait(0.05)
	touch(bp + Vector2(180, 90), false)
	await wait(0.2)
	print("input: long-press su ", bolt["id"], " ", Vector2i(int(bolt["x"]), int(bolt["y"])), " -> modifica ", "OK" if (in_edit and v.edit_uid == int(bolt["uid"])) or (in_edit and v.ghost != null) else "FALLITO", ", trascinamento cella ", start_cell, " -> ", v.edit_cell, " ", "OK" if v.edit_cell != start_cell else "FALLITO")
	await shot("07b_edit_drag")
	v._cancel_edit()
	await wait(0.2)
	# 3) pinch-zoom con due dita
	var z0: float = v.cam.zoom.x
	var c := Vector2(960, 540)
	touch(c - Vector2(100, 0), true, 0)
	touch(c + Vector2(100, 0), true, 1)
	for i in 5:
		drag(c - Vector2(100 + 40 * (i + 1), 0), Vector2(-40, 0), 0)
		drag(c + Vector2(100 + 40 * (i + 1), 0), Vector2(40, 0), 1)
		await wait(0.05)
	touch(c - Vector2(300, 0), false, 0)
	touch(c + Vector2(300, 0), false, 1)
	await wait(0.2)
	print("input: pinch-zoom ", z0, " -> ", v.cam.zoom.x, " ", "OK" if v.cam.zoom.x > z0 else "FALLITO")
	# 4) pan con un dito
	var pos0: Vector2 = v.cam.position
	touch(Vector2(900, 600), true)
	for i in 6:
		drag(Vector2(900 - 40 * (i + 1), 600), Vector2(-40, 0))
		await wait(0.03)
	touch(Vector2(660, 600), false)
	await wait(0.2)
	print("input: pan ", pos0, " -> ", v.cam.position, " ", "OK" if v.cam.position.x > pos0.x else "FALLITO")


func input_checks_battle(b: Node) -> void:
	# schieramento tenendo premuto e trascinando sulla zona consentita
	b._select("troop:cogling")
	var before := int(b.sim.army["cogling"]["count"])
	var cells: Array = BattleAI._side_cells(b.sim, RandomNumberGenerator.new())
	var w: Vector2 = Iso.to_world(cells[0] + Vector2(0.5, 0.5))
	var p := _screen(w)
	touch(p, true)
	for i in 8:
		drag(p + Vector2(0, 6 * (i + 1)), Vector2(0, 6))
		await wait(0.1)
	touch(p + Vector2(0, 48), false)
	await wait(0.2)
	var after := int(b.sim.army["cogling"]["count"])
	print("input: schieramento a trascinamento ", before - after, " truppe ", "OK" if before - after >= 3 else "FALLITO")
