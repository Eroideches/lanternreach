extends GutTest
## Smoke test delle scene reali (headless): boot, villaggio con tutti i pannelli e le modalita' di modifica,
## battaglia di campagna con schieramento, battaglia PvP, replay. Gli errori di script compaiono nel log (CI li intercetta).

const T0 := 1_900_000_000.0


func before_each() -> void:
	SaveManager.enabled = false
	TimeManager.trusted_max = 0.0
	TimeManager.freeze_at(T0)
	GameState.new_game(false)
	load("res://scripts/app/main.gd").apply_settings()


func after_each() -> void:
	TimeManager.unfreeze()
	TimeManager.trusted_max = 0.0


func test_boot_scene_runs_two_seconds() -> void:
	var boot: Control = load("res://scenes/boot.tscn").instantiate()
	add_child_autofree(boot)
	await wait_frames(2)
	var lbl: Label = boot.label
	assert_eq(lbl.text, "EroideGames")
	assert_almost_eq(boot.TOTAL, 2.0, 0.0001, "durata totale 2 s, dissolvenze incluse")
	assert_almost_eq(boot.FADE * 2.0 + (boot.TOTAL - 2.0 * boot.FADE), 2.0, 0.0001)
	# evita il cambio di scena reale durante il test
	boot.set_process(false)


func test_boot_game_new_player() -> void:
	load("res://scripts/app/main.gd").boot_game()
	assert_false(GameState.data.is_empty())
	assert_eq(GameState.hall_level(), 1)


func test_village_scene_and_panels() -> void:
	var v: Node2D = load("res://scenes/village.tscn").instantiate()
	add_child_autofree(v)
	await wait_frames(5)
	assert_gt(v.views.size(), 5, "viste create per edifici e ostacoli")
	for key in ["shop", "army", "lab", "attack", "quests", "settings", "clan", "log", "builders", "leagues"]:
		var p: Node = v.open_panel(key)
		await wait_frames(3)
		assert_true(is_instance_valid(p), "pannello %s aperto" % key)
		p.close()
		await wait_seconds(0.25)
	# pannello edificio + azioni contestuali
	var hall_uid := int(GameState.hall()["uid"])
	v._select(hall_uid)
	await wait_frames(3)
	v.open_building_panel(hall_uid)
	await wait_frames(3)
	v.current_panel.close()
	await wait_seconds(0.25)
	# posizionamento dal negozio e conferma
	v.start_place("cog_mine")
	await wait_frames(2)
	v._confirm_edit()
	await wait_frames(2)
	assert_eq(GameState.count_of("cog_mine"), 1, "mina piazzata dal negozio")
	# modalita' modifica (long-press) e spostamento
	var camp: Dictionary = GameState.buildings_of("army_camp")[0]
	v.start_edit(int(camp["uid"]))
	v._move_ghost(Vector2i(30, 30))
	v._confirm_edit()
	assert_eq(int(camp["x"]), 30)
	# mura tracciate a trascinamento: cerca una fila di 5 celle libere
	var row := Vector2i(-1, -1)
	for y in range(3, 40):
		for x in range(3, 34):
			var ok := true
			for i in 5:
				if not GameState.can_place("wall", x + i, y):
					ok = false
					break
			if ok:
				row = Vector2i(x, y)
				break
		if row.x >= 0:
			break
	v.start_place("wall")
	v._move_ghost(row)
	v._on_drag_start(Vector2.ZERO)
	v._wall_line_to(row + Vector2i(4, 0))
	v._confirm_edit()
	await wait_frames(2)
	assert_eq(GameState.count_of("wall"), 5, "linea di 5 segmenti")


func test_campaign_battle_scene() -> void:
	GameState.data["army"]["troops"]["cogling"] = 20
	Router.params = {"mode": "campaign", "level": 1}
	var b: Node2D = load("res://scenes/battle.tscn").instantiate()
	add_child_autofree(b)
	await wait_frames(5)
	assert_false(b.sim == null)
	for i in 20:
		b._deploy_at(Iso.to_world(Vector2(3.5, 10.5 + i * 0.5)))
	assert_true(b.started)
	b.speed = 8.0
	var guard := 0
	while not b.finished and guard < 2000:
		b._process(0.25)
		guard += 1
		if guard % 50 == 0:
			await wait_frames(1)
	assert_true(b.finished, "battaglia conclusa")
	assert_gt(Progression.campaign_stars(1), 0, "livello 1 vinto con 20 truppe")
	await wait_seconds(1.0)


func test_pvp_and_replay_scene() -> void:
	GameState.data["army"]["troops"]["cogling"] = 10
	Router.params = {"mode": "pvp"}
	var b: Node2D = load("res://scenes/battle.tscn").instantiate()
	add_child_autofree(b)
	await wait_frames(5)
	assert_eq(b.mode, "pvp")
	var cells: Array = BattleAI._side_cells(b.sim, RandomNumberGenerator.new())
	for c in cells:
		b._deploy_at(Iso.to_world(c + Vector2(0.5, 0.5)))
	b.sim.surrender()
	b._process(0.1)
	await wait_seconds(1.2)
	assert_true(b.finished)
	var data: Dictionary = b.sim.replay_data()
	Router.params = {"mode": "replay", "replay": data}
	var r: Node2D = load("res://scenes/battle.tscn").instantiate()
	add_child_autofree(r)
	await wait_frames(5)
	r.speed = 8.0
	var guard := 0
	while not r.finished and guard < 3000:
		r._process(0.25)
		guard += 1
	assert_true(r.finished, "il replay termina")
