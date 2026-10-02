extends Node
## Progressione: esperienza e livelli, trofei e leghe, statistiche, obiettivi permanenti, missioni giornaliere, login.


# ------------------------------------------------------------------- XP
func level_info() -> Dictionary:
	var p: Dictionary = GameState.data["player"]
	var lvl := int(p["level"])
	var rows: Array = Balance.xp_levels
	var need := int(rows[clampi(lvl, 1, rows.size()) - 1]["xp_to_next"])
	return {"level": lvl, "xp": int(p["xp"]), "need": need, "max": lvl >= rows.size()}


func add_xp(amount: int) -> void:
	if GameState.data.is_empty() or amount <= 0:
		return
	var p: Dictionary = GameState.data["player"]
	var rows: Array = Balance.xp_levels
	p["xp"] = int(p["xp"]) + amount
	while int(p["level"]) < rows.size():
		var need := int(rows[int(p["level"]) - 1]["xp_to_next"])
		if int(p["xp"]) < need:
			break
		p["xp"] = int(p["xp"]) - need
		p["level"] = int(p["level"]) + 1
		EventBus.level_up.emit(int(p["level"]))
	if int(p["level"]) >= rows.size():
		p["xp"] = mini(int(p["xp"]), int(rows[rows.size() - 1]["xp_to_next"]))
	EventBus.xp_changed.emit(int(p["xp"]), int(p["level"]))


# --------------------------------------------------------------- trofei
func trophies() -> int:
	return int(GameState.data["player"]["trophies"])


func change_trophies(delta: int) -> void:
	var p: Dictionary = GameState.data["player"]
	p["trophies"] = maxi(0, int(p["trophies"]) + delta)
	p["best_trophies"] = maxi(int(p["best_trophies"]), int(p["trophies"]))
	track_max("trophies_best", int(p["best_trophies"]))
	var lg := Balance.league_for(int(p["trophies"]))
	var reached: Array = p["leagues_reached"]
	if not lg["id"] in reached:
		reached.append(lg["id"])
		var gems := int(lg["first_reach_gems"])
		if gems > 0:
			EconomyManager.add("glimmers", gems)
		EventBus.league_reached.emit(lg["id"])
	EventBus.trophies_changed.emit(int(p["trophies"]))


func league() -> Dictionary:
	return Balance.league_for(trophies())


# ------------------------------------------------------------ statistiche
func track(metric: String, amount: float = 1.0) -> void:
	if GameState.data.is_empty():
		return
	var st: Dictionary = GameState.data["progress"]["stats"]
	st[metric] = float(st.get(metric, 0.0)) + amount
	_daily_progress(metric, amount)
	_check_achievements(metric)


func track_max(metric: String, value: float) -> void:
	if GameState.data.is_empty():
		return
	var st: Dictionary = GameState.data["progress"]["stats"]
	st[metric] = maxf(float(st.get(metric, 0.0)), value)
	_check_achievements(metric)


## Mappa nomi metrica usati dal gioco -> metriche degli obiettivi (data/achievements.json).
const METRIC_ALIAS := {
	"cogs_looted_total": "cogs_looted", "sap_looted_total": "sap_looted",
	"shards_collected": "shards_collected",
}


func _metric_value(metric: String) -> float:
	var st: Dictionary = GameState.data["progress"]["stats"]
	var key: String = METRIC_ALIAS.get(metric, metric)
	return float(st.get(key, 0.0))


# --------------------------------------------------------------- obiettivi
func achievement_rows(id: String) -> Array:
	var out: Array = []
	for r in Balance.achievements:
		if r["id"] == id:
			out.append(r)
	return out


func achievement_ids() -> Array:
	var ids: Array = []
	for r in Balance.achievements:
		if not r["id"] in ids:
			ids.append(r["id"])
	return ids


func achievement_state(id: String) -> Dictionary:
	## {claimed: livelli gia' riscossi, rows, value, next (riga o {}), ready (bool)}
	var rows := achievement_rows(id)
	var claimed := int(GameState.data["progress"]["achievements"].get(id, 0))
	var value := _metric_value(rows[0]["metric"]) if not rows.is_empty() else 0.0
	var next: Dictionary = rows[claimed] if claimed < rows.size() else {}
	var ready := not next.is_empty() and value >= float(next["target"])
	return {"claimed": claimed, "rows": rows, "value": value, "next": next, "ready": ready}


func _check_achievements(metric: String) -> void:
	for id in achievement_ids():
		var rows := achievement_rows(id)
		if METRIC_ALIAS.get(rows[0]["metric"], rows[0]["metric"]) != metric and rows[0]["metric"] != metric:
			continue
		var s := achievement_state(id)
		if s["ready"]:
			EventBus.achievement_ready.emit(id, int(s["claimed"]) + 1)


func claim_achievement(id: String) -> int:
	var s := achievement_state(id)
	if not s["ready"]:
		return 0
	var gems := int(s["next"]["reward_gems"])
	GameState.data["progress"]["achievements"][id] = int(s["claimed"]) + 1
	EconomyManager.add("glimmers", gems)
	add_xp(10 * (int(s["claimed"]) + 1))
	EventBus.state_changed.emit()
	return gems


func ready_achievements() -> int:
	var n := 0
	for id in achievement_ids():
		if achievement_state(id)["ready"]:
			n += 1
	return n


# ---------------------------------------------------- missioni giornaliere
func refresh_daily(now: float) -> void:
	var d: Dictionary = GameState.data["progress"]["daily"]
	var key := TimeManager.day_key(now)
	if d.get("day", "") == key:
		return
	var pool: Array = Balance.daily["missions"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ int(GameState.data["rng_seed"])
	var idx: Array = range(pool.size())
	# mescolamento deterministico per giorno
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var missions: Array = []
	for i in mini(int(Balance.daily["missions_per_day"]), idx.size()):
		missions.append({"id": pool[idx[i]]["id"], "progress": 0.0, "claimed": false})
	d["day"] = key
	d["missions"] = missions
	_login(key)
	EventBus.daily_updated.emit()


func mission_def(id: String) -> Dictionary:
	for m in Balance.daily["missions"]:
		if m["id"] == id:
			return m
	return {}


func _daily_progress(metric: String, amount: float) -> void:
	var d: Dictionary = GameState.data["progress"]["daily"]
	var changed := false
	for m in d.get("missions", []):
		var def := mission_def(m["id"])
		if def.get("metric", "") == metric and not m["claimed"]:
			m["progress"] = minf(float(def["target"]), float(m["progress"]) + amount)
			changed = true
	if changed:
		EventBus.daily_updated.emit()


func claim_mission(i: int) -> bool:
	var ms: Array = GameState.data["progress"]["daily"].get("missions", [])
	if i < 0 or i >= ms.size():
		return false
	var m: Dictionary = ms[i]
	var def := mission_def(m["id"])
	if m["claimed"] or float(m["progress"]) < float(def["target"]):
		return false
	m["claimed"] = true
	if int(def["reward_gems"]) > 0:
		EconomyManager.add("glimmers", int(def["reward_gems"]))
	if int(def["reward_sap_per_hall"]) > 0:
		EconomyManager.add("sap", int(def["reward_sap_per_hall"]) * GameState.hall_level())
	add_xp(5)
	EventBus.daily_updated.emit()
	EventBus.state_changed.emit()
	return true


# ----------------------------------------------------------------- login
func _login(day: String) -> void:
	var lg: Dictionary = GameState.data["progress"]["login"]
	if lg.get("last_day", "") == day:
		return
	lg["last_day"] = day
	lg["pending"] = true
	EventBus.state_changed.emit()


func login_pending() -> bool:
	return bool(GameState.data["progress"]["login"].get("pending", false))


func login_reward_today() -> Dictionary:
	var lg: Dictionary = GameState.data["progress"]["login"]
	var cycle: Array = Balance.daily["login_cycle"]
	return cycle[int(lg.get("cycle_day", 0)) % cycle.size()]


func claim_login() -> Dictionary:
	if not login_pending():
		return {}
	var r := login_reward_today()
	var hall := GameState.hall_level()
	match r["reward"]:
		"cogs":
			EconomyManager.add("cogs", int(r["amount_per_hall"]) * hall)
		"sap":
			EconomyManager.add("sap", int(r["amount_per_hall"]) * hall)
		"cogs_sap":
			EconomyManager.add("cogs", int(r["amount_per_hall"]) * hall)
			EconomyManager.add("sap", int(r["amount_per_hall"]) * hall)
		"gems":
			EconomyManager.add("glimmers", int(r["amount"]))
		"shards_or_gems":
			if hall >= 5:
				EconomyManager.add("shards", int(r["amount"]))
			else:
				EconomyManager.add("glimmers", int(r["fallback_gems"]))
	var lg: Dictionary = GameState.data["progress"]["login"]
	lg["cycle_day"] = int(lg.get("cycle_day", 0)) + 1
	lg["pending"] = false
	EventBus.state_changed.emit()
	return r


# --------------------------------------------------------------- campagna
func campaign_stars(n: int) -> int:
	return int(GameState.data["progress"]["campaign"].get(str(n), 0))


func campaign_total_stars() -> int:
	var t := 0
	for k in GameState.data["progress"]["campaign"]:
		t += int(GameState.data["progress"]["campaign"][k])
	return t


func campaign_unlocked(n: int) -> bool:
	return n == 1 or campaign_stars(n - 1) > 0


func record_campaign(n: int, stars: int) -> int:
	## Ritorna le gemme assegnate (solo alla prima vittoria a 3 stelle).
	var prev := campaign_stars(n)
	var gems := 0
	if stars > prev:
		GameState.data["progress"]["campaign"][str(n)] = stars
		track("campaign_stars", stars - prev)
		if stars == 3 and prev < 3:
			gems = int(Balance.campaign_level(n)["first_3star_gems"])
			EconomyManager.add("glimmers", gems)
	return gems
