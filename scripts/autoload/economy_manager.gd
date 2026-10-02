extends Node
## Regole economiche: costi, depositi, produzione, costruttori, coda lavori, addestramento, ricerca, ostacoli.
## Tutti i timer sono timestamp reali: `process(now)` porta lo stato a `now` (funziona anche dopo giorni offline).

enum Err { OK, NO_BUILDER, NO_RESOURCES, MAX_LEVEL, HALL_REQUIRED, LIMIT_REACHED, BUSY, INVALID_PLACE, NO_SPACE, NOT_UNLOCKED, QUEUE_FULL }

const QUEUE_MAX := 3
const TICK_EVERY := 1.0

var _acc := 0.0


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= TICK_EVERY:
		_acc = 0.0
		process(TimeManager.now())


# ---------------------------------------------------------------- risorse
func storage_cap(r: String) -> float:
	if r == "glimmers":
		return 1e12
	var cap := 0.0
	var hl := GameState.hall_level()
	if r == "cogs" or r == "sap":
		cap += float(Balance.level_data("lantern_hall", hl)["stored_" + r])
		var sid := "cog_vault" if r == "cogs" else "sap_cistern"
		for b in GameState.buildings_of(sid):
			if int(b["level"]) > 0:
				cap += float(Balance.level_data(sid, int(b["level"]))["capacity"])
	elif r == "shards":
		for b in GameState.buildings_of("shard_crate"):
			if int(b["level"]) > 0:
				cap += float(Balance.level_data("shard_crate", int(b["level"]))["capacity"])
		cap = maxf(cap, 200.0)   # piccola riserva anche senza cassa (ricompense)
	return cap


## Aggiunge risorse rispettando la capacita'. Ritorna la quantita' effettivamente aggiunta.
func add(r: String, amount: float, ignore_cap: bool = false) -> float:
	var cur := GameState.res(r)
	var cap := storage_cap(r)
	var nv := cur + amount if ignore_cap else minf(cap, cur + amount)
	if amount >= 0:
		nv = maxf(cur, nv)          # un guadagno non toglie mai risorse (anche se si e' gia' oltre il tetto)
	else:
		nv = maxf(0.0, cur + amount)
	var added := nv - cur
	GameState.data["res"][r] = nv
	EventBus.resources_changed.emit(r, nv)
	if added > 0 and r in ["cogs", "sap", "shards"]:
		Progression.track(r + "_collected", added)
	return added


func can_afford(costs: Dictionary) -> bool:
	for r in costs:
		if GameState.res(r) + 1e-6 < float(costs[r]):
			return false
	return true


func missing(costs: Dictionary) -> Dictionary:
	var m := {}
	for r in costs:
		var d := float(costs[r]) - GameState.res(r)
		if d > 0:
			m[r] = d
	return m


func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for r in costs:
		if float(costs[r]) > 0:
			add(r, -float(costs[r]))
	EventBus.state_changed.emit()
	return true


func refund(costs: Dictionary, fraction: float) -> void:
	for r in costs:
		add(r, float(costs[r]) * fraction)


# ------------------------------------------------------ costi edifici
func cost_for(id: String, level: int) -> Dictionary:
	var d := Balance.level_data(id, level)
	var c := {}
	if d.is_empty():
		return c
	c[d.get("cost_res", "cogs")] = float(d.get("cost", 0))
	if int(d.get("cost_shards", 0)) > 0:
		c["shards"] = float(d["cost_shards"])
	return c


func time_for(id: String, level: int) -> float:
	return float(Balance.level_data(id, level).get("time_s", 0))


## Verifica se un edificio puo' essere portato al livello successivo.
func check_upgrade(b: Dictionary) -> int:
	var id: String = b["id"]
	var lvl := int(b["level"])
	if not b.get("job", {}).is_empty():
		return Err.BUSY
	if lvl >= Balance.max_level(id):
		return Err.MAX_LEVEL
	var req := int(Balance.level_data(id, lvl + 1).get("req_hall", 1))
	if id != "lantern_hall" and req > GameState.hall_level():
		return Err.HALL_REQUIRED
	if id == "lantern_hall" and lvl + 1 > Balance.max_level("lantern_hall"):
		return Err.MAX_LEVEL
	if not can_afford(cost_for(id, lvl + 1)):
		return Err.NO_RESOURCES
	if id != "wall" and free_builders() <= 0:
		return Err.NO_BUILDER
	return Err.OK


func check_new(id: String) -> int:
	var hl := GameState.hall_level()
	if Balance.unlock_hall(id) > hl:
		return Err.NOT_UNLOCKED
	if GameState.count_of(id) >= Balance.count_allowed(id, hl):
		return Err.LIMIT_REACHED
	if not can_afford(cost_for(id, 1)):
		return Err.NO_RESOURCES
	if id != "wall" and free_builders() <= 0:
		return Err.NO_BUILDER
	return Err.OK


# ------------------------------------------------------------- costruttori
func busy_builders() -> int:
	var n := 0
	for list in [GameState.data["buildings"], GameState.data["obstacles"]]:
		for e in list:
			if not e.get("job", {}).is_empty():
				n += 1
	return n


func free_builders() -> int:
	return int(GameState.data["builders"]) - busy_builders()


func next_builder_price() -> int:
	var b := int(GameState.data["builders"])
	for p in Balance.economy["builders"]["prices"]:
		if int(p["builder"]) == b + 1:
			return int(p["gems"])
	return -1


func buy_builder() -> bool:
	var price := next_builder_price()
	if price < 0 or not spend({"glimmers": price}):
		return false
	GameState.data["builders"] = int(GameState.data["builders"]) + 1
	EventBus.state_changed.emit()
	return true


# --------------------------------------------------------------- lavori
func _start_job(e: Dictionary, kind: String, duration: float, target_level: int, costs: Dictionary) -> void:
	var t := TimeManager.now()
	e["job"] = {"type": kind, "start": t, "end": t + duration, "target": target_level, "costs": costs}
	EventBus.building_job_started.emit(int(e["uid"]))
	EventBus.state_changed.emit()
	if duration <= 0.0:
		_finish_job(e)


## Piazza un nuovo edificio (costo scalato subito). Le mura sono istantanee.
func place_new(id: String, x: int, y: int) -> int:
	var err := check_new(id)
	if err != Err.OK:
		return err
	if not GameState.can_place(id, x, y):
		return Err.INVALID_PLACE
	var costs := cost_for(id, 1)
	spend(costs)
	var b := GameState.add_building(id, x, y, 0)
	_start_job(b, "build", time_for(id, 1), 1, costs)
	Progression.track("upgrades_started", 1)
	EventBus.tutorial_event.emit("placed_" + id)
	return Err.OK


func start_upgrade(uid: int) -> int:
	var b := GameState.get_entity(uid)
	if b.is_empty():
		return Err.INVALID_PLACE
	var err := check_upgrade(b)
	if err != Err.OK:
		return err
	var lvl := int(b["level"]) + 1
	var costs := cost_for(b["id"], lvl)
	spend(costs)
	_start_job(b, "upgrade", time_for(b["id"], lvl), lvl, costs)
	Progression.track("upgrades_started", 1)
	EventBus.tutorial_event.emit("upgrade_" + str(b["id"]))
	return Err.OK


## Pianifica in coda (max 3) un potenziamento che partira' al primo costruttore libero.
func enqueue_upgrade(uid: int) -> int:
	var q: Array = GameState.data["build_queue"]
	if q.size() >= QUEUE_MAX:
		return Err.QUEUE_FULL
	if uid in q:
		return Err.BUSY
	q.append(uid)
	EventBus.state_changed.emit()
	return Err.OK


func cancel_job(uid: int) -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty() or e.get("job", {}).is_empty():
		return
	refund(e["job"].get("costs", {}), 0.5)
	if int(e.get("level", 1)) == 0 and not GameState.is_obstacle(e):
		GameState.remove_entity(uid)
	else:
		e["job"] = {}
	EventBus.state_changed.emit()


func remaining(e: Dictionary) -> float:
	if e.get("job", {}).is_empty():
		return 0.0
	return maxf(0.0, float(e["job"]["end"]) - TimeManager.now())


func speedup_cost_for(e: Dictionary) -> int:
	return Formulas.speedup_cost(remaining(e), Balance.economy["speedup_points"])


func speedup(uid: int) -> bool:
	var e := GameState.get_entity(uid)
	if e.is_empty() or e.get("job", {}).is_empty():
		return false
	var c := speedup_cost_for(e)
	if not spend({"glimmers": c}):
		return false
	e["job"]["end"] = TimeManager.now()
	_finish_job(e)
	Progression.track("speedups", 1)
	return true


func _finish_job(e: Dictionary) -> void:
	var job: Dictionary = e["job"]
	if job.is_empty():
		return
	e["job"] = {}
	if job["type"] == "remove":
		var gems := int(job.get("gems", 0))
		if gems > 0:
			add("glimmers", gems)
		Progression.add_xp(int(job.get("xp", 1)))
		Progression.track("obstacles_cleared", 1)
		GameState.remove_entity(int(e["uid"]))
		EventBus.obstacle_removed.emit(int(e["uid"]), gems)
		EventBus.state_changed.emit()
		return
	var lvl := int(job["target"])
	if Balance.category(e["id"]) == "economy":
		# la produzione riparte da ora (non si produce durante i lavori)
		e["last_prod"] = float(job["end"])
	e["level"] = lvl
	var xp := int(Balance.level_data(e["id"], lvl).get("xp", 1))
	Progression.add_xp(maxi(1, xp))
	Progression.track("upgrades_done", 1)
	if e["id"] == "lantern_hall":
		Progression.track_max("hall_level", lvl)
	EventBus.building_job_finished.emit(int(e["uid"]), lvl)
	EventBus.tutorial_event.emit("finished_" + str(e["id"]))
	EventBus.state_changed.emit()


# --------------------------------------------------------------- ostacoli
func obstacle_info(id: String) -> Dictionary:
	for o in Balance.obstacles["types"]:
		if o["id"] == id:
			return o
	return {}


func obstacle_cost(o: Dictionary) -> Dictionary:
	var info := obstacle_info(o["id"])
	var r := "cogs" if int(o["uid"]) % 2 == 0 else "sap"
	return {r: float(info["remove_cost_per_hall"]) * GameState.hall_level()}


func remove_obstacle(uid: int) -> int:
	var o := GameState.get_entity(uid)
	if o.is_empty() or not o.get("job", {}).is_empty():
		return Err.BUSY
	if free_builders() <= 0:
		return Err.NO_BUILDER
	var c := obstacle_cost(o)
	if not spend(c):
		return Err.NO_RESOURCES
	var info := obstacle_info(o["id"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o["uid"]) * 7919 + int(GameState.data["rng_seed"])
	var gems := rng.randi_range(int(info["gems"][0]), int(info["gems"][1]))
	var t := TimeManager.now()
	o["job"] = {"type": "remove", "start": t, "end": t + float(info["remove_time_s"]), "gems": gems, "xp": 2, "costs": c}
	EventBus.building_job_started.emit(uid)
	EventBus.state_changed.emit()
	return Err.OK


func _spawn_obstacles(now: float) -> void:
	var rules: Dictionary = Balance.obstacles["rules"]
	var interval := float(rules["spawn_interval_s"])
	var guard := 0
	while now >= float(GameState.data["obstacle_next_spawn"]) and guard < 50:
		guard += 1
		GameState.data["obstacle_next_spawn"] = float(GameState.data["obstacle_next_spawn"]) + interval
		if GameState.data["obstacles"].size() >= int(rules["max_on_map"]):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(GameState.data["obstacle_next_spawn"]) + int(GameState.data["rng_seed"])
		var total := 0
		for t in Balance.obstacles["types"]:
			total += int(t["weight"])
		var pick := rng.randi_range(1, total)
		var kind := "sapling"
		for t in Balance.obstacles["types"]:
			pick -= int(t["weight"])
			if pick <= 0:
				kind = t["id"]
				break
		var occ := GameState.occupancy()
		for i in 30:
			var x := rng.randi_range(GameState.BUILD_MIN, GameState.BUILD_MAX - 1)
			var y := rng.randi_range(GameState.BUILD_MIN, GameState.BUILD_MAX - 1)
			if GameState.can_place(kind, x, y, -1, occ):
				GameState.add_obstacle(kind, x, y)
				break


# -------------------------------------------------------------- produzione
func production_rate(b: Dictionary) -> float:
	## Unita' al secondo.
	if int(b["level"]) <= 0:
		return 0.0
	return float(Balance.level_data(b["id"], int(b["level"])).get("prod_per_hour", 0)) / 3600.0


func extractor_capacity(b: Dictionary) -> float:
	return float(Balance.level_data(b["id"], maxi(1, int(b["level"]))).get("capacity", 0))


func extractor_resource(id: String) -> String:
	match id:
		"cog_mine":
			return "cogs"
		"sap_well":
			return "sap"
		"shard_drill":
			return "shards"
	return ""


func _produce(b: Dictionary, now: float) -> void:
	if not b.get("job", {}).is_empty() or int(b["level"]) <= 0:
		b["last_prod"] = now
		return
	var last := float(b.get("last_prod", now))
	var dt := maxf(0.0, now - last)
	b["stored"] = minf(extractor_capacity(b), float(b.get("stored", 0.0)) + production_rate(b) * dt)
	b["last_prod"] = now


func collect(uid: int) -> int:
	var b := GameState.get_entity(uid)
	if b.is_empty():
		return 0
	_produce(b, TimeManager.now())
	var r := extractor_resource(b["id"])
	var amount := floorf(float(b.get("stored", 0.0)))
	if amount < 1.0:
		return 0
	var added := add(r, amount)
	b["stored"] = float(b["stored"]) - added
	if added > 0:
		EventBus.resource_collected.emit(uid, r, int(added))
		EventBus.tutorial_event.emit("collected")
		EventBus.state_changed.emit()
	return int(added)


func collect_all(id: String) -> int:
	var tot := 0
	for b in GameState.buildings_of(id):
		tot += collect(int(b["uid"]))
	return tot


# -------------------------------------------------------------- esercito
func army_capacity() -> int:
	var c := 0
	for b in GameState.buildings_of("army_camp"):
		if int(b["level"]) > 0:
			c += int(Balance.level_data("army_camp", int(b["level"]))["army_capacity"])
	return c


func army_space(include_queue: bool = true) -> int:
	var used := 0
	for id in GameState.army_troops():
		used += int(GameState.army_troops()[id]) * int(Balance.troop(id, 1)["size"])
	if include_queue:
		for q in GameState.data["training"]["troops"]:
			used += int(Balance.troop(q["id"], 1)["size"])
	return used


func spell_capacity() -> int:
	var f := GameState.buildings_of("spell_forge")
	if f.is_empty() or int(f[0]["level"]) <= 0:
		return 0
	return int(Balance.level_data("spell_forge", int(f[0]["level"]))["spell_slots"]) * 2


func spell_space(include_queue: bool = true) -> int:
	var used := 0
	for id in GameState.army_spells():
		used += int(GameState.army_spells()[id]) * int(Balance.spell(id, 1)["size"])
	if include_queue:
		for q in GameState.data["training"]["spells"]:
			used += int(Balance.spell(q["id"], 1)["size"])
	return used


func barracks_level() -> int:
	var b := GameState.buildings_of("barracks")
	return 0 if b.is_empty() else int(b[0]["level"])


func troop_unlocked(id: String) -> bool:
	return barracks_level() >= int(Balance.troop(id, 1)["barracks_req"])


func spell_unlocked(id: String) -> bool:
	var f := GameState.buildings_of("spell_forge")
	return not f.is_empty() and int(f[0]["level"]) >= 1 and Balance.spell_order.find(id) < int(f[0]["level"])


func troop_cost(id: String) -> Dictionary:
	var d := Balance.troop(id, GameState.troop_level(id))
	return {d["cost_res"]: float(d["cost"])}


func spell_cost(id: String) -> Dictionary:
	var d := Balance.spell(id, GameState.spell_level(id))
	return {d["cost_res"]: float(d["cost"])}


func train(kind: String, id: String) -> int:
	var tr: Dictionary = GameState.data["training"]
	var key := "troops" if kind == "troop" else "spells"
	if kind == "troop":
		if not troop_unlocked(id):
			return Err.NOT_UNLOCKED
		if army_space() + int(Balance.troop(id, 1)["size"]) > army_capacity():
			return Err.NO_SPACE
		if not spend(troop_cost(id)):
			return Err.NO_RESOURCES
		var d := Balance.troop(id, GameState.troop_level(id))
		_enqueue_training(tr, key, {"id": id, "time": float(d["train_s"]), "costs": troop_cost(id)})
	else:
		if not spell_unlocked(id):
			return Err.NOT_UNLOCKED
		if spell_space() + int(Balance.spell(id, 1)["size"]) > spell_capacity():
			return Err.NO_SPACE
		if not spend(spell_cost(id)):
			return Err.NO_RESOURCES
		var d := Balance.spell(id, GameState.spell_level(id))
		_enqueue_training(tr, key, {"id": id, "time": float(d["train_s"]), "costs": spell_cost(id)})
	Progression.track("troops_trained" if kind == "troop" else "spells_trained", 1)
	EventBus.army_changed.emit()
	EventBus.tutorial_event.emit("trained_" + id)
	EventBus.state_changed.emit()
	return Err.OK


func _enqueue_training(tr: Dictionary, key: String, item: Dictionary) -> void:
	if tr[key].is_empty():
		tr[key + "_started"] = TimeManager.now()
	tr[key].append(item)


## Rimuove dalla coda l'ultimo elemento di quel tipo (rimborso 100%), altrimenti dall'esercito pronto (nessun rimborso).
func untrain(kind: String, id: String) -> bool:
	var tr: Dictionary = GameState.data["training"]
	var key := "troops" if kind == "troop" else "spells"
	var q: Array = tr[key]
	for i in range(q.size() - 1, -1, -1):
		if q[i]["id"] == id:
			refund(q[i].get("costs", {}), 1.0)
			q.remove_at(i)
			if i == 0:
				tr[key + "_started"] = TimeManager.now()
			EventBus.army_changed.emit()
			EventBus.state_changed.emit()
			return true
	var army: Dictionary = GameState.data["army"][key]
	if int(army.get(id, 0)) > 0:
		army[id] = int(army[id]) - 1
		EventBus.army_changed.emit()
		EventBus.state_changed.emit()
		return true
	return false


func training_remaining(kind: String) -> float:
	var tr: Dictionary = GameState.data["training"]
	var key := "troops" if kind == "troop" else "spells"
	var total := 0.0
	for q in tr[key]:
		total += float(q["time"])
	return maxf(0.0, float(tr[key + "_started"]) + total - TimeManager.now())


func finish_training_now(kind: String) -> bool:
	var c := Formulas.speedup_cost(training_remaining(kind), Balance.economy["speedup_points"])
	if c <= 0 or not spend({"glimmers": c}):
		return false
	var tr: Dictionary = GameState.data["training"]
	var key := "troops" if kind == "troop" else "spells"
	tr[key + "_started"] = TimeManager.now() - 1e7
	_process_training(TimeManager.now())
	return true


func _process_training(now: float) -> void:
	var tr: Dictionary = GameState.data["training"]
	for key in ["troops", "spells"]:
		var q: Array = tr[key]
		var changed := false
		while not q.is_empty():
			var item: Dictionary = q[0]
			var done_at := float(tr[key + "_started"]) + float(item["time"])
			if now < done_at:
				break
			# truppe: solo se c'e' spazio (lo spazio e' gia' riservato dalla coda)
			q.remove_at(0)
			var army: Dictionary = GameState.data["army"][key]
			army[item["id"]] = int(army.get(item["id"], 0)) + 1
			tr[key + "_started"] = done_at
			changed = true
		if q.is_empty():
			tr[key + "_started"] = now
		if changed:
			EventBus.army_changed.emit()
			EventBus.tutorial_event.emit("army_ready")


# ---------------------------------------------------------------- ricerca
func lab_level() -> int:
	var l := GameState.buildings_of("laboratory")
	return 0 if l.is_empty() else int(l[0]["level"])


func research_check(id: String) -> int:
	var job: Dictionary = GameState.data["research"]["job"]
	if not job.is_empty():
		return Err.BUSY
	var lvl := GameState.troop_level(id)
	if lvl >= Balance.troop_max_level(id):
		return Err.MAX_LEVEL
	var row := Balance.lab_row(id, lvl + 1)
	if row.is_empty() or int(row["lab_req"]) > lab_level() or not troop_unlocked(id):
		return Err.NOT_UNLOCKED
	if not can_afford({row["cost_res"]: float(row["cost"])}):
		return Err.NO_RESOURCES
	return Err.OK


func start_research(id: String) -> int:
	var err := research_check(id)
	if err != Err.OK:
		return err
	var lvl := GameState.troop_level(id) + 1
	var row := Balance.lab_row(id, lvl)
	spend({row["cost_res"]: float(row["cost"])})
	var t := TimeManager.now()
	GameState.data["research"]["job"] = {"id": id, "level": lvl, "start": t, "end": t + float(row["time_s"])}
	EventBus.state_changed.emit()
	return Err.OK


func research_remaining() -> float:
	var job: Dictionary = GameState.data["research"]["job"]
	return 0.0 if job.is_empty() else maxf(0.0, float(job["end"]) - TimeManager.now())


func speedup_research() -> bool:
	var c := Formulas.speedup_cost(research_remaining(), Balance.economy["speedup_points"])
	if c <= 0 or not spend({"glimmers": c}):
		return false
	GameState.data["research"]["job"]["end"] = TimeManager.now()
	_process_research(TimeManager.now())
	return true


func _process_research(now: float) -> void:
	var job: Dictionary = GameState.data["research"]["job"]
	if job.is_empty() or now < float(job["end"]):
		return
	GameState.data["research"]["levels"][job["id"]] = int(job["level"])
	GameState.data["research"]["job"] = {}
	Progression.add_xp(int(Balance.lab_row(job["id"], int(job["level"])).get("xp", 1)))
	EventBus.research_finished.emit(job["id"], int(job["level"]))
	EventBus.state_changed.emit()


# -------------------------------------------------------------- avanzamento
## Porta tutto lo stato all'istante `now` (chiamato ogni secondo e al caricamento per il progresso offline).
func process(now: float) -> void:
	if GameState.data.is_empty():
		return
	# lavori completati in ordine di fine (cosi' i costruttori liberati servono la coda nell'ordine giusto)
	var done := true
	var guard := 0
	while done and guard < 200:
		guard += 1
		done = false
		var earliest: Dictionary = {}
		for list in [GameState.data["buildings"], GameState.data["obstacles"]]:
			for e in list:
				var j: Dictionary = e.get("job", {})
				if not j.is_empty() and float(j["end"]) <= now:
					if earliest.is_empty() or float(j["end"]) < float(earliest["job"]["end"]):
						earliest = e
		if not earliest.is_empty():
			var end_t := float(earliest["job"]["end"])
			_finish_job(earliest)
			_start_queued(end_t)
			done = true
	_start_queued(now)
	for b in GameState.data["buildings"]:
		if Balance.category(b["id"]) == "economy":
			_produce(b, now)
	_process_training(now)
	_process_research(now)
	_spawn_obstacles(now)
	GameState.data["last_seen"] = now


func _start_queued(at_time: float) -> void:
	var q: Array = GameState.data["build_queue"]
	while not q.is_empty() and free_builders() > 0:
		var uid := int(q[0])
		var b := GameState.get_entity(uid)
		if b.is_empty() or check_upgrade(b) == Err.MAX_LEVEL:
			q.remove_at(0)
			continue
		if check_upgrade(b) != Err.OK:
			break     # aspetta risorse
		q.remove_at(0)
		var lvl := int(b["level"]) + 1
		var costs := cost_for(b["id"], lvl)
		spend(costs)
		b["job"] = {"type": "upgrade", "start": at_time, "end": at_time + time_for(b["id"], lvl), "target": lvl, "costs": costs}
		EventBus.building_job_started.emit(uid)


func err_text(err: int) -> String:
	match err:
		Err.NO_BUILDER:
			return tr("err.no_builder")
		Err.NO_RESOURCES:
			return tr("err.no_resources")
		Err.MAX_LEVEL:
			return tr("err.max_level")
		Err.HALL_REQUIRED:
			return tr("err.hall_required")
		Err.LIMIT_REACHED:
			return tr("err.limit")
		Err.BUSY:
			return tr("err.busy")
		Err.INVALID_PLACE:
			return tr("err.invalid_place")
		Err.NO_SPACE:
			return tr("err.no_space")
		Err.NOT_UNLOCKED:
			return tr("err.locked")
		Err.QUEUE_FULL:
			return tr("err.queue_full")
	return ""
