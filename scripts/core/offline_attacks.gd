class_name OfflineAttacks
extends RefCounted
## Attacchi subiti mentre il giocatore e' offline (GDD §10.3): ogni 4-10 h (max 3 in 24 h), se non c'e' scudo,
## un avversario simulato attacca la base reale del giocatore con il motore di battaglia deterministico.
## Risultato: risorse perse, scudo, trofei, voce nel registro difese con replay.

const MAX_LOG := 20


## Elabora tutti gli attacchi programmati fino a `now`. Ritorna le nuove voci di registro.
static func process(now: float, max_attacks: int = 3) -> Array:
	var d: Dictionary = GameState.data
	var cfg: Dictionary = Balance.economy["shield"]
	var new_entries: Array = []
	var guard := 0
	while float(d.get("next_offline_attack", now + 1.0)) <= now and guard < max_attacks:
		guard += 1
		var at := float(d["next_offline_attack"])
		var rng := RandomNumberGenerator.new()
		rng.seed = int(at) ^ int(d["rng_seed"])
		var interval := rng.randf_range(float(cfg["offline_attack_interval_s"][0]), float(cfg["offline_attack_interval_s"][1]))
		d["next_offline_attack"] = at + interval
		if at < float(d.get("shield_until", 0.0)):
			d["next_offline_attack"] = maxf(float(d["next_offline_attack"]), float(d["shield_until"]) + 3600.0)
			continue
		if not GameState.data["tutorial"].get("done", false):
			continue
		var e := simulate_attack(at, rng)
		if not e.is_empty():
			new_entries.append(e)
	# rispetta il massimo di attacchi per 24 h spostando il prossimo
	var recent := 0
	for e in d["defense_log"]:
		if now - float(e["time"]) < 86400.0:
			recent += 1
	if recent >= int(cfg["offline_attacks_max_per_24h"]):
		d["next_offline_attack"] = maxf(float(d["next_offline_attack"]), now + 6.0 * 3600.0)
	return new_entries


static func simulate_attack(at: float, rng: RandomNumberGenerator) -> Dictionary:
	var hall := GameState.hall_level()
	var att_hall := clampi(hall + rng.randi_range(-1, 1), 1, 10)
	var base := GameState.base_snapshot()
	# bottino disponibile = percentuale dei depositi del giocatore, con tetto per Hall
	var eco: Dictionary = Balance.economy["loot"]
	var loot := {}
	for r in ["cogs", "sap", "shards"]:
		var content := GameState.res(r)
		var lootable := Formulas.storage_lootable(content, hall, eco["pct_stored_by_hall"])
		var cap: Array = eco["cap_by_hall"] if r != "shards" else eco["shard_cap_by_hall"]
		loot[r] = floorf(Formulas.cap_loot(lootable, hall, cap))
	base["loot"] = loot
	var army := BattleAI.random_army(att_hall, rng, rng.randf_range(0.6, 1.0))
	var sim := BattleSim.new()
	var seed := rng.randi()
	sim.setup(base, army, seed)
	var res := BattleAI.autoplay(sim, rng)
	# applica le perdite
	for r in ["cogs", "sap", "shards"]:
		var lost := minf(GameState.res(r), float(res["loot"][r]))
		GameState.data["res"][r] = GameState.res(r) - lost
		res["loot"][r] = lost
	# trofei: l'attaccante ha trofei simili ai nostri
	var own := Progression.trophies()
	var opp := maxi(0, own + rng.randi_range(-120, 120))
	var cfg: Dictionary = Balance.economy["trophies"]
	var delta := 0
	if int(res["stars"]) > 0:
		delta = -Formulas.trophy_delta(int(res["stars"]), opp, own, cfg)
	else:
		delta = int(round(float(cfg["loss_base"]) * 0.6))
		Progression.track("defense_wins", 1)
	Progression.change_trophies(delta)
	var shield := Formulas.shield_seconds(float(res["percent"]), Balance.economy["shield"]["thresholds"])
	if shield > 0.0:
		GameState.data["shield_until"] = maxf(float(GameState.data["shield_until"]), at + shield)
	# trappole scattate: da riarmare
	var replay := sim.replay_data()
	var used_traps: Array = []
	for b in sim.buildings:
		if b.cat == "trap" and not b.armed:
			used_traps.append(b.uid)
	for uid in used_traps:
		var tb := GameState.get_entity(int(uid))
		if not tb.is_empty():
			tb["armed"] = false
	var entry := {
		"time": at, "attacker": BaseGenerator.random_name(rng), "attacker_hall": att_hall, "stars": res["stars"],
		"percent": res["percent"], "loot": res["loot"], "trophies": delta, "replay": replay, "seen": false,
	}
	var dlog: Array = GameState.data["defense_log"]
	dlog.push_front(entry)
	while dlog.size() > MAX_LOG:
		dlog.pop_back()
	EventBus.defense_logged.emit(entry)
	EventBus.state_changed.emit()
	return entry


static func rearm_cost() -> float:
	var c := 0.0
	for b in GameState.buildings():
		if Balance.category(b["id"]) == "trap" and not b.get("armed", true):
			c += float(Balance.level_data(b["id"], int(b["level"])).get("rearm_cost", 0))
	return c


static func rearm_all() -> bool:
	var c := rearm_cost()
	if c <= 0.0 or not EconomyManager.spend({"cogs": c}):
		return false
	for b in GameState.buildings():
		if Balance.category(b["id"]) == "trap":
			b["armed"] = true
	return true
