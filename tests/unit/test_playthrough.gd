extends GutTest
## Partita completa automatica: dal villaggio iniziale del tutorial fino al Faro Madre livello 5,
## usando solo le API di gioco (costruzioni, raccolta, addestramento, attacchi di campagna/PvP, tempo che scorre).

const T0 := 1_900_000_000.0
const STEP_S := 1800.0          ## mezz'ora di gioco per iterazione
const MAX_DAYS := 25.0


func before_each() -> void:
	SaveManager.enabled = false
	TimeManager.trusted_max = 0.0
	TimeManager.freeze_at(T0)
	GameState.new_game(true)


func after_each() -> void:
	TimeManager.unfreeze()
	TimeManager.trusted_max = 0.0


func _build_anything() -> void:
	var order := ["cog_vault", "sap_cistern", "cog_mine", "sap_well", "barracks", "army_camp", "laboratory", "boltpost", "lobber",
		"skyspear", "arc_coil", "ballista", "clan_hall", "spell_forge", "shard_drill", "shard_crate", "bomb_trap", "spring_pad"]
	for id in order:
		if EconomyManager.free_builders() <= 0:
			return
		if EconomyManager.check_new(id) == EconomyManager.Err.OK:
			var p := GameState.find_free_spot(id, Vector2i(20, 20))
			if p.x >= 0:
				EconomyManager.place_new(id, p.x, p.y)


func _upgrade_anything() -> void:
	# priorita': Faro Madre, depositi, estrattori, caserma/accampamenti, difese
	var prio := {"lantern_hall": 0, "cog_vault": 1, "sap_cistern": 1, "cog_mine": 2, "sap_well": 2, "barracks": 3, "army_camp": 3}
	var list: Array = GameState.buildings().duplicate()
	list.sort_custom(func(a, b): return int(prio.get(a["id"], 5)) < int(prio.get(b["id"], 5)))
	for b in list:
		if EconomyManager.free_builders() <= 0:
			return
		if b["id"] == "wall":
			continue
		if EconomyManager.check_upgrade(b) == EconomyManager.Err.OK:
			# risparmia per il Faro Madre se e' il prossimo passo
			EconomyManager.start_upgrade(int(b["uid"]))


func _train() -> void:
	if EconomyManager.barracks_level() <= 0:
		return
	var guard := 0
	while guard < 300 and EconomyManager.army_space() < EconomyManager.army_capacity():
		guard += 1
		var id := "cogling"
		if EconomyManager.troop_unlocked("slingwisp") and guard % 3 == 0:
			id = "slingwisp"
		if EconomyManager.troop_unlocked("bulwark") and guard % 10 == 0:
			id = "bulwark"
		if EconomyManager.train("troop", id) != EconomyManager.Err.OK:
			break


func _attack(rng: RandomNumberGenerator) -> Dictionary:
	var army := GameState.battle_army()
	if army["troops"].is_empty():
		return {}
	var n := 1
	while n < Balance.campaign.size() and Progression.campaign_unlocked(n + 1):
		n += 1
	var mode := "campaign"
	var base: Dictionary
	var ctx := {}
	if int(Balance.campaign_level(n)["hall_level"]) > GameState.hall_level() + 1 or Progression.campaign_stars(n) == 3:
		mode = "pvp"
		var hall := BaseGenerator.hall_for_trophies(Progression.trophies(), GameState.hall_level(), rng)
		base = BaseGenerator.generate(hall, rng.randi())
		base["loot"] = BaseGenerator.loot_for(hall, rng, GameState.hall_level())
		ctx = {"opponent_trophies": Progression.trophies(), "league_bonus": float(Progression.league()["win_loot_bonus"])}
	else:
		base = CampaignData.load_level(n)
		ctx = {"level": n}
	var sim := BattleSim.new()
	sim.setup(base, army, rng.randi())
	BattleAI.autoplay(sim, rng)
	var extra := BattleRewards.apply(mode, sim, ctx)
	return {"mode": mode, "stars": sim.stars(), "extra": extra}


func test_tutorial_to_hall5() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var battles := 0
	var wins := 0
	var steps := 0
	var max_steps := int(MAX_DAYS * 86400.0 / STEP_S)
	while GameState.hall_level() < 5 and steps < max_steps:
		steps += 1
		var now := TimeManager.now()
		EconomyManager.process(now)
		for id in ["cog_mine", "sap_well", "shard_drill"]:
			EconomyManager.collect_all(id)
		# il Faro Madre ha la precedenza: se e' pronto da potenziare, lo fa subito
		var h := GameState.hall()
		if EconomyManager.check_upgrade(h) == EconomyManager.Err.OK:
			EconomyManager.start_upgrade(int(h["uid"]))
		_build_anything()
		_upgrade_anything()
		_train()
		if steps % 4 == 0:
			var r := _attack(rng)
			if not r.is_empty():
				battles += 1
				if int(r["stars"]) > 0:
					wins += 1
		if steps == 2:
			GameState.data["tutorial"]["done"] = true
		Progression.refresh_daily(now)
		OfflineAttacks.process(now)
		TimeManager.advance(STEP_S)
	var days := steps * STEP_S / 86400.0
	gut.p("Hall %d raggiunta in %.1f giorni di gioco simulati, %d battaglie (%d vinte), trofei %d, livello %d"
		% [GameState.hall_level(), days, battles, wins, Progression.trophies(), int(GameState.data["player"]["level"])])
	assert_eq(GameState.hall_level(), 5, "Faro Madre livello 5 raggiunto")
	assert_lt(days, MAX_DAYS)
	assert_gt(wins, 0)
