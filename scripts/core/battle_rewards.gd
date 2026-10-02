class_name BattleRewards
extends RefCounted
## Applica l'esito di un attacco del giocatore allo stato di gioco (usato dalla scena di battaglia e dai test).
## mode: "campaign" | "pvp". ctx: {level, opponent_trophies, league_bonus}


static func apply(mode: String, sim: BattleSim, ctx: Dictionary) -> Dictionary:
	var res := sim.result()
	var extra := {"loot": {}, "trophies": 0, "xp": 0, "gems": 0}
	var stars := int(res["stars"])
	var win := stars > 0
	# bottino (bonus lega sulle vittorie PvP), limitato dalla capacita' dei depositi
	for r in ["cogs", "sap", "shards"]:
		var amount := float(res["loot"][r])
		if mode == "pvp" and win:
			amount *= 1.0 + float(ctx.get("league_bonus", 0.0))
		var added := EconomyManager.add(r, amount)
		extra["loot"][r] = added
		if added > 0:
			Progression.track(r + "_looted", added)
	# truppe e incantesimi consumati: restano quelli non schierati
	var army: Dictionary = GameState.data["army"]
	for id in sim.army:
		army["troops"][id] = int(sim.army[id]["count"])
	for id in sim.spell_stock:
		army["spells"][id] = int(sim.spell_stock[id]["count"])
	var spells_used := 0
	for id in res["spells_used"]:
		spells_used += int(res["spells_used"][id])
	Progression.track("spells_cast", spells_used)
	Progression.track("defenses_destroyed", int(res["defenses_destroyed"]))
	Progression.track("walls_destroyed", int(res["walls_destroyed"]))
	Progression.track("stars_total", stars)
	if win:
		Progression.track("attack_wins", 1)
	var xp := 10 * stars + (5 if win else 0)
	Progression.add_xp(xp)
	extra["xp"] = xp
	match mode:
		"campaign":
			extra["gems"] = Progression.record_campaign(int(ctx.get("level", 1)), stars)
		"pvp":
			var delta := Formulas.trophy_delta(stars, Progression.trophies(), int(ctx.get("opponent_trophies", 0)), Balance.economy["trophies"])
			Progression.change_trophies(delta)
			extra["trophies"] = delta
			# attaccare un altro giocatore rimuove lo scudo
			GameState.data["shield_until"] = minf(float(GameState.data["shield_until"]), TimeManager.now())
	extra["replay"] = sim.replay_data()
	EventBus.army_changed.emit()
	EventBus.battle_finished.emit(res)
	EventBus.tutorial_event.emit("battle_won" if win else "battle_lost")
	EventBus.state_changed.emit()
	return extra
