extends GutTest
## Simulazione di battaglia: stelle, distruzione, bottino, zona di schieramento, trappole, determinismo e replay.


func _tiny_base() -> Dictionary:
	return {"buildings": [
		{"id": "lantern_hall", "level": 1, "x": 20, "y": 20},
		{"id": "cog_vault", "level": 1, "x": 25, "y": 20},
	], "hall_level": 1, "loot": {"cogs": 400.0, "sap": 0.0, "shards": 0.0}}


func _army(id: String, n: int, lvl: int = 1) -> Dictionary:
	return {"troops": {id: {"count": n, "level": lvl}}, "spells": {}}


func test_three_stars_on_undefended_base() -> void:
	var sim := BattleSim.new()
	sim.setup(_tiny_base(), _army("cogling", 20), 1)
	for i in 20:
		assert_true(sim.deploy_troop("cogling", Vector2(10.5, 20.5 + (i % 4))))
	sim.run_to_end()
	var r := sim.result()
	assert_eq(r["percent"], 100)
	assert_eq(r["stars"], 3)
	assert_true(r["hall_destroyed"])
	assert_eq(r["reason"], "destroyed")
	assert_almost_eq(float(r["loot"]["cogs"]), 400.0, 1.0, "tutto il bottino rilasciato a distruzione completa")


func test_partial_destruction_one_star() -> void:
	var base := {"buildings": [
		{"id": "lantern_hall", "level": 1, "x": 20, "y": 20},
		{"id": "cog_mine", "level": 1, "x": 6, "y": 6},
		{"id": "sap_well", "level": 1, "x": 34, "y": 34},
	], "hall_level": 1, "loot": {}}
	var sim := BattleSim.new()
	sim.setup(base, _army("magpie", 3), 1)
	# le gazze puntano alle risorse: distruggono mina e pozzo (2/3 = 66%) ma la Hall resta
	sim.deploy_troop("magpie", Vector2(3.5, 3.5))
	sim.deploy_troop("magpie", Vector2(40.5, 40.5))
	sim.deploy_troop("magpie", Vector2(40.5, 39.5))
	# fermiamo la simulazione appena cadono i due edifici delle risorse (poi le gazze passerebbero alla Hall)
	var guard := 0
	while sim.destroyed_counted < 2 and guard < 5400:
		sim.step()
		guard += 1
	var r := sim.result()
	assert_eq(r["percent"], 66)
	assert_eq(r["stars"], 1)
	assert_false(r["hall_destroyed"])
	assert_true(sim.buildings[0].alive, "le gazze hanno puntato prima alle risorse")


func test_deploy_zone() -> void:
	var sim := BattleSim.new()
	sim.setup(_tiny_base(), _army("cogling", 5), 1)
	assert_true(sim.can_deploy_at(Vector2(0.5, 0.5)), "il bordo e' sempre schierabile")
	assert_false(sim.can_deploy_at(Vector2(21.5, 21.5)), "dentro un edificio")
	assert_false(sim.can_deploy_at(Vector2(18.5, 21.5)), "entro 2 celle da un edificio")
	assert_true(sim.can_deploy_at(Vector2(17.5, 21.5)), "a 3 celle e' consentito")
	assert_false(sim.deploy_troop("cogling", Vector2(21.5, 21.5)))
	assert_false(sim.deploy_troop("slingwisp", Vector2(0.5, 0.5)), "truppa non nell'esercito")


func test_defense_kills_weak_army_and_battle_ends() -> void:
	var base := {"buildings": [
		{"id": "lantern_hall", "level": 1, "x": 20, "y": 20},
		{"id": "boltpost", "level": 10, "x": 16, "y": 21},
	], "hall_level": 10, "loot": {}}
	var sim := BattleSim.new()
	sim.setup(base, _army("cogling", 3), 1)
	for i in 3:
		sim.deploy_troop("cogling", Vector2(10.5, 21.5))
	sim.run_to_end()
	var r := sim.result()
	assert_eq(r["reason"], "no_troops")
	assert_eq(sim.alive_troops(), 0)


func test_timer_ends_battle_after_3_minutes() -> void:
	var base := {"buildings": [{"id": "lantern_hall", "level": 10, "x": 20, "y": 20}, {"id": "cog_vault", "level": 10, "x": 2, "y": 2}], "hall_level": 10, "loot": {}}
	var sim := BattleSim.new()
	sim.setup(base, _army("cogling", 30), 1)
	sim.deploy_troop("cogling", Vector2(40.5, 40.5))
	sim.run_to_end()
	assert_true(sim.tick <= 180 * 30)
	assert_true(sim.ended)


func test_traps_trigger_once() -> void:
	var base := {"buildings": [
		{"id": "lantern_hall", "level": 1, "x": 20, "y": 20},
		{"id": "bomb_trap", "level": 5, "x": 15, "y": 21},
	], "hall_level": 5, "loot": {}}
	var sim := BattleSim.new()
	sim.setup(base, _army("cogling", 5), 1)
	for i in 5:
		sim.deploy_troop("cogling", Vector2(10.5, 21.5))
	sim.run_to_end()
	var trap: BattleSim.SBuilding = sim.buildings[1]
	assert_false(trap.armed, "la trappola e' scattata")
	assert_eq(sim.total_counted, 1, "le trappole non contano per la percentuale")


func test_walls_block_or_get_broken() -> void:
	var base := {"buildings": [{"id": "lantern_hall", "level": 1, "x": 20, "y": 20}], "hall_level": 2, "loot": {}}
	for x in range(18, 26):
		for y in [18, 25]:
			base["buildings"].append({"id": "wall", "level": 1, "x": x, "y": y})
	for y in range(19, 25):
		for x in [18, 25]:
			base["buildings"].append({"id": "wall", "level": 1, "x": x, "y": y})
	var sim := BattleSim.new()
	sim.setup(base, _army("cogling", 10), 3)
	for i in 10:
		sim.deploy_troop("cogling", Vector2(10.5, 21.5))
	sim.run_to_end()
	var r := sim.result()
	assert_eq(r["stars"], 3, "le truppe sfondano il recinto chiuso e distruggono la Hall")
	assert_gt(int(r["walls_destroyed"]), 0)


func test_kegger_targets_walls() -> void:
	var base := {"buildings": [{"id": "lantern_hall", "level": 1, "x": 20, "y": 20}], "hall_level": 3, "loot": {}}
	for y in range(15, 30):
		base["buildings"].append({"id": "wall", "level": 3, "x": 16, "y": y})
	var sim := BattleSim.new()
	sim.setup(base, _army("kegger", 1), 1)
	sim.deploy_troop("kegger", Vector2(8.5, 22.5))
	for i in 600:
		sim.step()
	assert_gt(sim.walls_destroyed, 0, "il barilotto apre un varco nelle mura")


func test_spells_heal() -> void:
	var sim := BattleSim.new()
	sim.setup(_tiny_base(), {"troops": {"bulwark": {"count": 1, "level": 1}}, "spells": {"mending_mist": {"count": 1, "level": 1}}}, 1)
	sim.deploy_troop("bulwark", Vector2(3.5, 3.5))
	sim.step()
	var t: BattleSim.STroop = sim.troops[0]
	t.hp = t.max_hp * 0.5
	sim.cast_spell("mending_mist", t.pos)
	for i in 30:
		sim.step()
	assert_gt(t.hp, t.max_hp * 0.5)


func _run_scripted(seed: int) -> BattleSim:
	var base := CampaignData.load_level(7)
	var sim := BattleSim.new()
	sim.setup(base, {"troops": {"cogling": {"count": 20, "level": 2}, "slingwisp": {"count": 10, "level": 2}, "bulwark": {"count": 2, "level": 1}},
		"spells": {}}, seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	BattleAI.autoplay(sim, rng)
	return sim


func test_determinism() -> void:
	var a := _run_scripted(42)
	var b := _run_scripted(42)
	assert_eq(a.state_hash(), b.state_hash(), "stessi input -> stesso stato finale")
	assert_eq(a.result()["percent"], b.result()["percent"])


func test_replay_reproduces_battle() -> void:
	var a := _run_scripted(7)
	var r := Replay.run(a.replay_data())
	var ra := a.result()
	assert_eq(r["stars"], ra["stars"])
	assert_eq(r["percent"], ra["percent"])
	assert_eq(r["ticks"], ra["ticks"])
	assert_eq(r["loot"], ra["loot"])
