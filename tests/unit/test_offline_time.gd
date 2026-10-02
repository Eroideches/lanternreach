extends GutTest
## Timer basati su timestamp reali: avanzano a gioco chiuso; gli spostamenti indietro dell'orologio sono ignorati.

const T0 := 1_900_000_000.0


func before_each() -> void:
	SaveManager.enabled = false
	TimeManager.trusted_max = 0.0
	TimeManager.freeze_at(T0)
	GameState.new_game(false)


func after_each() -> void:
	TimeManager.unfreeze()
	TimeManager.trusted_max = 0.0


func test_jobs_finish_while_offline() -> void:
	var h := GameState.hall()
	EconomyManager.add("cogs", 5000)
	EconomyManager.start_upgrade(int(h["uid"]))
	# "chiudo" il gioco per 2 giorni: un solo process() al rientro
	TimeManager.advance(2 * 86400)
	EconomyManager.process(TimeManager.now())
	assert_eq(GameState.hall_level(), 2)


func test_chained_jobs_and_queue_offline() -> void:
	EconomyManager.add("cogs", 5000)
	EconomyManager.add("sap", 5000)
	var a := GameState.find_free_spot("cog_mine")
	EconomyManager.place_new("cog_mine", a.x, a.y)
	var b := GameState.find_free_spot("sap_well")
	EconomyManager.place_new("sap_well", b.x, b.y)
	var h := GameState.hall()
	EconomyManager.enqueue_upgrade(int(h["uid"]))
	TimeManager.advance(3600)
	EconomyManager.process(TimeManager.now())
	assert_eq(GameState.hall_level(), 2, "la coda e' stata servita durante l'assenza")
	assert_eq(GameState.highest_level("cog_mine"), 1)


func test_production_offline_capped() -> void:
	var a := GameState.find_free_spot("cog_mine")
	EconomyManager.place_new("cog_mine", a.x, a.y)
	TimeManager.advance(10)
	EconomyManager.process(TimeManager.now())
	TimeManager.advance(30 * 86400)
	EconomyManager.process(TimeManager.now())
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	assert_eq(float(mine["stored"]), 1600.0)


func test_training_offline() -> void:
	var p := GameState.find_free_spot("barracks")
	EconomyManager.place_new("barracks", p.x, p.y)
	TimeManager.advance(30)
	EconomyManager.process(TimeManager.now())
	for i in 10:
		EconomyManager.train("troop", "cogling")
	TimeManager.advance(3600)
	EconomyManager.process(TimeManager.now())
	assert_eq(int(GameState.army_troops()["cogling"]), 10)
	assert_true(GameState.data["training"]["troops"].is_empty())


func test_clock_rollback_is_ignored() -> void:
	var t1 := TimeManager.now()
	TimeManager.freeze_at(T0 - 86400.0)       # l'utente porta l'orologio indietro di un giorno
	var t2 := TimeManager.now()
	assert_eq(t2, t1, "il tempo fidato non torna indietro")
	assert_true(TimeManager.rollback_detected)
	var h := GameState.hall()
	EconomyManager.add("cogs", 5000)
	EconomyManager.start_upgrade(int(h["uid"]))
	var end := float(h["job"]["end"])
	assert_eq(end, t1 + 300.0, "i timer partono dal tempo fidato")
	# l'orologio torna avanti: il gioco riprende normalmente
	TimeManager.freeze_at(T0 + 400.0)
	EconomyManager.process(TimeManager.now())
	assert_eq(GameState.hall_level(), 2)


func test_obstacles_respawn_over_time() -> void:
	var n0: int = GameState.data["obstacles"].size()
	TimeManager.advance(float(Balance.obstacles["rules"]["spawn_interval_s"]) * 3 + 1)
	EconomyManager.process(TimeManager.now())
	assert_eq(GameState.data["obstacles"].size(), n0 + 3)
	TimeManager.advance(float(Balance.obstacles["rules"]["spawn_interval_s"]) * 200)
	EconomyManager.process(TimeManager.now())
	assert_true(GameState.data["obstacles"].size() <= int(Balance.obstacles["rules"]["max_on_map"]))


func test_offline_attack_needs_no_shield() -> void:
	GameState.data["shield_until"] = T0 + 100000.0
	GameState.data["next_offline_attack"] = T0 + 10.0
	TimeManager.advance(3600)
	var entries := OfflineAttacks.process(TimeManager.now())
	assert_eq(entries.size(), 0, "con lo scudo attivo nessun attacco")


func test_offline_attack_happens_and_logs() -> void:
	GameState.data["shield_until"] = 0.0
	GameState.data["next_offline_attack"] = T0 + 10.0
	TimeManager.advance(3600)
	var entries := OfflineAttacks.process(TimeManager.now())
	assert_eq(entries.size(), 1)
	var e: Dictionary = entries[0]
	assert_true(e.has("replay"))
	assert_eq(GameState.data["defense_log"].size(), 1)
	assert_true(float(e["loot"]["cogs"]) <= 1500.0)
	# replay della difesa riproduce lo stesso esito
	var r := Replay.run(e["replay"])
	assert_eq(int(r["stars"]), int(e["stars"]))
	assert_eq(int(r["percent"]), int(e["percent"]))
