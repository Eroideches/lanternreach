extends GutTest
## Economia: depositi, costi, costruttori, lavori, produzione, raccolta, addestramento, ricerca, ostacoli.

const T0 := 1_900_000_000.0


func before_each() -> void:
	SaveManager.enabled = false
	TimeManager.trusted_max = 0.0
	TimeManager.freeze_at(T0)
	GameState.new_game(false)


func after_each() -> void:
	TimeManager.unfreeze()
	TimeManager.trusted_max = 0.0


func _hall() -> Dictionary:
	return GameState.hall()


func test_starting_village() -> void:
	assert_eq(GameState.hall_level(), 1)
	assert_eq(int(GameState.data["builders"]), 2)
	assert_eq(EconomyManager.free_builders(), 2)
	assert_eq(GameState.res("cogs"), 1500.0)
	assert_eq(GameState.count_of("cog_vault"), 1)


func test_storage_cap_limits_add() -> void:
	var cap := EconomyManager.storage_cap("cogs")
	# Hall L1 (500) + Deposito L1 (1500)
	assert_eq(cap, 2000.0)
	var added := EconomyManager.add("cogs", 10000.0)
	assert_eq(GameState.res("cogs"), cap)
	assert_eq(added, cap - 1500.0)
	assert_eq(EconomyManager.add("glimmers", 1e6), 1e6, "le gemme non hanno tetto")


func test_spend_and_afford() -> void:
	assert_true(EconomyManager.can_afford({"cogs": 1500.0}))
	assert_false(EconomyManager.can_afford({"cogs": 1500.1}))
	assert_false(EconomyManager.spend({"cogs": 9999.0}))
	assert_eq(GameState.res("cogs"), 1500.0, "nessuna spesa se non sostenibile")
	assert_true(EconomyManager.spend({"cogs": 500.0, "sap": 100.0}))
	assert_eq(GameState.res("cogs"), 1000.0)
	assert_eq(GameState.res("sap"), 1400.0)


func test_place_new_building_costs_and_job() -> void:
	var p := GameState.find_free_spot("cog_mine")
	var err := EconomyManager.place_new("cog_mine", p.x, p.y)
	assert_eq(err, EconomyManager.Err.OK)
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	assert_eq(int(mine["level"]), 0)
	assert_false(mine["job"].is_empty())
	assert_eq(GameState.res("sap"), 1500.0 - 120.0, "la mina costa Sap")
	assert_eq(EconomyManager.free_builders(), 1)
	# il lavoro finisce dopo il suo tempo
	TimeManager.advance(float(Balance.level_data("cog_mine", 1)["time_s"]) + 0.1)
	EconomyManager.process(TimeManager.now())
	assert_eq(int(mine["level"]), 1)
	assert_true(mine["job"].is_empty())
	assert_eq(EconomyManager.free_builders(), 2)


func test_invalid_placement_and_limits() -> void:
	var h := _hall()
	assert_false(GameState.can_place("cog_mine", int(h["x"]), int(h["y"])), "sovrapposto alla Hall")
	assert_false(GameState.can_place("cog_mine", 0, 0), "fuori area edificabile")
	assert_false(GameState.can_place("cog_mine", 41, 41), "esce dal bordo")
	# limite di quantita' per Hall 1: 2 mine
	for i in 2:
		var p := GameState.find_free_spot("cog_mine")
		assert_eq(EconomyManager.place_new("cog_mine", p.x, p.y), EconomyManager.Err.OK)
	var p3 := GameState.find_free_spot("cog_mine")
	assert_eq(EconomyManager.place_new("cog_mine", p3.x, p3.y), EconomyManager.Err.LIMIT_REACHED)
	# edificio non ancora sbloccato
	assert_eq(EconomyManager.check_new("laboratory"), EconomyManager.Err.NOT_UNLOCKED)


func test_builders_are_limited() -> void:
	EconomyManager.add("cogs", 5000)
	EconomyManager.add("sap", 5000)
	var ids := ["cog_mine", "sap_well", "cog_mine"]
	var results: Array = []
	for id in ids:
		var p := GameState.find_free_spot(id)
		results.append(EconomyManager.place_new(id, p.x, p.y))
	assert_eq(results, [EconomyManager.Err.OK, EconomyManager.Err.OK, EconomyManager.Err.NO_BUILDER])


func test_upgrade_requires_hall() -> void:
	var p := GameState.find_free_spot("boltpost")
	assert_eq(EconomyManager.place_new("boltpost", p.x, p.y), EconomyManager.Err.OK)
	TimeManager.advance(100)
	EconomyManager.process(TimeManager.now())
	var bolt: Dictionary = GameState.buildings_of("boltpost")[0]
	assert_eq(int(bolt["level"]), 1)
	assert_eq(EconomyManager.check_upgrade(bolt), EconomyManager.Err.HALL_REQUIRED, "Boltpost Lv2 richiede Hall 2")


func test_speedup_spends_glimmers() -> void:
	var h := _hall()
	EconomyManager.add("cogs", 5000)
	assert_eq(EconomyManager.start_upgrade(int(h["uid"])), EconomyManager.Err.OK)
	var cost := EconomyManager.speedup_cost_for(h)
	assert_eq(cost, Formulas.speedup_cost(300, Balance.economy["speedup_points"]))
	var before := GameState.res("glimmers")
	assert_true(EconomyManager.speedup(int(h["uid"])))
	assert_eq(GameState.res("glimmers"), before - cost)
	assert_eq(GameState.hall_level(), 2)


func test_cancel_refunds_half() -> void:
	var p := GameState.find_free_spot("cog_mine")
	EconomyManager.place_new("cog_mine", p.x, p.y)
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	EconomyManager.cancel_job(int(mine["uid"]))
	assert_eq(GameState.count_of("cog_mine"), 0, "costruzione annullata: edificio rimosso")
	assert_eq(GameState.res("sap"), 1500.0 - 60.0, "rimborso 50%")


func test_production_accumulates_and_caps() -> void:
	var p := GameState.find_free_spot("cog_mine")
	EconomyManager.place_new("cog_mine", p.x, p.y)
	TimeManager.advance(10)
	EconomyManager.process(TimeManager.now())
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	TimeManager.advance(3600)
	EconomyManager.process(TimeManager.now())
	assert_almost_eq(float(mine["stored"]), 200.0, 0.5, "200/h al livello 1")
	TimeManager.advance(3600 * 100)
	EconomyManager.process(TimeManager.now())
	assert_eq(float(mine["stored"]), EconomyManager.extractor_capacity(mine), "fermo al tetto interno (8 h)")
	var before := GameState.res("cogs")
	var got := EconomyManager.collect(int(mine["uid"]))
	assert_gt(got, 0)
	assert_eq(GameState.res("cogs"), minf(EconomyManager.storage_cap("cogs"), before + 1600.0))


func test_no_production_while_upgrading() -> void:
	var p := GameState.find_free_spot("cog_mine")
	EconomyManager.place_new("cog_mine", p.x, p.y)
	TimeManager.advance(10)
	EconomyManager.process(TimeManager.now())
	var h := _hall()
	EconomyManager.add("cogs", 5000)
	EconomyManager.start_upgrade(int(h["uid"]))     # Hall L2 sblocca il livello 2 della mina
	TimeManager.advance(300)
	EconomyManager.process(TimeManager.now())
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	mine["stored"] = 0.0
	EconomyManager.add("sap", 5000)
	assert_eq(EconomyManager.start_upgrade(int(mine["uid"])), EconomyManager.Err.OK)
	var dur := float(mine["job"]["end"]) - float(mine["job"]["start"])
	TimeManager.advance(dur * 0.5)
	EconomyManager.process(TimeManager.now())
	assert_eq(float(mine["stored"]), 0.0, "nessuna produzione durante il potenziamento")


func test_training_queue_and_capacity() -> void:
	var p := GameState.find_free_spot("barracks")
	EconomyManager.place_new("barracks", p.x, p.y)
	TimeManager.advance(60)
	EconomyManager.process(TimeManager.now())
	assert_eq(EconomyManager.army_capacity(), 20)
	for i in 3:
		assert_eq(EconomyManager.train("troop", "cogling"), EconomyManager.Err.OK)
	assert_eq(EconomyManager.train("troop", "slingwisp"), EconomyManager.Err.NOT_UNLOCKED, "serve Caserma Lv2")
	TimeManager.advance(25)
	EconomyManager.process(TimeManager.now())
	assert_eq(int(GameState.army_troops().get("cogling", 0)), 2, "10 s ciascuno: dopo 25 s ne sono pronti 2")
	TimeManager.advance(10)
	EconomyManager.process(TimeManager.now())
	assert_eq(int(GameState.army_troops().get("cogling", 0)), 3)
	# riempi la capacita'
	for i in 17:
		EconomyManager.train("troop", "cogling")
	assert_eq(EconomyManager.train("troop", "cogling"), EconomyManager.Err.NO_SPACE)
	# rimozione dalla coda con rimborso completo
	var sap := GameState.res("sap")
	assert_true(EconomyManager.untrain("troop", "cogling"))
	assert_eq(GameState.res("sap"), sap + 25.0)


func test_research_flow() -> void:
	GameState.hall()["level"] = 3
	for id in ["laboratory", "barracks"]:
		var p := GameState.find_free_spot(id)
		GameState.data["res"]["sap"] = 20000.0     # oltre il tetto dei depositi solo per il test
		GameState.data["res"]["cogs"] = 20000.0
		assert_eq(EconomyManager.place_new(id, p.x, p.y), EconomyManager.Err.OK)
		TimeManager.advance(100)
		EconomyManager.process(TimeManager.now())
	assert_eq(EconomyManager.research_check("cogling"), EconomyManager.Err.NOT_UNLOCKED, "Lab Lv1 non basta per Lv2")
	var lab: Dictionary = GameState.buildings_of("laboratory")[0]
	lab["level"] = 2
	GameState.data["res"]["sap"] = 50000.0
	assert_eq(EconomyManager.start_research("cogling"), EconomyManager.Err.OK)
	assert_eq(EconomyManager.research_check("slingwisp"), EconomyManager.Err.BUSY, "una ricerca alla volta")
	TimeManager.advance(float(Balance.lab_row("cogling", 2)["time_s"]) + 1)
	EconomyManager.process(TimeManager.now())
	assert_eq(GameState.troop_level("cogling"), 2)


func test_obstacle_removal_gives_gems_and_uses_builder() -> void:
	var o: Dictionary = GameState.data["obstacles"][0]
	var uid := int(o["uid"])
	assert_eq(EconomyManager.remove_obstacle(uid), EconomyManager.Err.OK)
	assert_eq(EconomyManager.free_builders(), 1, "la rimozione occupa un costruttore")
	var gems: int = int(o["job"]["gems"])
	var before := GameState.res("glimmers")
	TimeManager.advance(3601)
	EconomyManager.process(TimeManager.now())
	assert_true(GameState.get_entity(uid).is_empty())
	assert_eq(GameState.res("glimmers"), before + gems)


func test_build_queue_starts_when_builder_frees() -> void:
	EconomyManager.add("cogs", 5000)
	EconomyManager.add("sap", 5000)
	var a := GameState.find_free_spot("cog_mine")
	EconomyManager.place_new("cog_mine", a.x, a.y)
	var b := GameState.find_free_spot("sap_well")
	EconomyManager.place_new("sap_well", b.x, b.y)
	var h := _hall()
	assert_eq(EconomyManager.start_upgrade(int(h["uid"])), EconomyManager.Err.NO_BUILDER)
	assert_eq(EconomyManager.enqueue_upgrade(int(h["uid"])), EconomyManager.Err.OK)
	TimeManager.advance(20)
	EconomyManager.process(TimeManager.now())
	assert_false(h["job"].is_empty(), "il potenziamento in coda parte appena si libera un costruttore")


func test_buy_builder() -> void:
	EconomyManager.add("glimmers", 1000)
	assert_eq(EconomyManager.next_builder_price(), 200)
	assert_true(EconomyManager.buy_builder())
	assert_eq(int(GameState.data["builders"]), 3)
	assert_eq(EconomyManager.next_builder_price(), 400)


func test_walls_are_instant() -> void:
	var p := GameState.find_free_spot("wall")
	assert_eq(EconomyManager.place_new("wall", p.x, p.y), EconomyManager.Err.OK)
	var w: Dictionary = GameState.buildings_of("wall")[0]
	assert_eq(int(w["level"]), 1, "le mura non usano timer")
	assert_eq(EconomyManager.free_builders(), 2, "ne' costruttori")
