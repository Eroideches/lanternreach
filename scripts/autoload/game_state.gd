extends Node
## Stato persistente del giocatore (un unico Dictionary serializzabile in JSON).
## Le regole economiche vivono in EconomyManager; qui solo struttura dati e accessori.

const SCHEMA_VERSION := 2
const GRID := 44
const BUILD_MIN := 2      ## area edificabile: celle 2..41
const BUILD_MAX := 41

var data: Dictionary = {}
var _by_uid: Dictionary = {}


func _ready() -> void:
	if data.is_empty():
		new_game()


# ------------------------------------------------------------ nuova partita
func default_data() -> Dictionary:
	var eco: Dictionary = Balance.economy
	var st: Dictionary = eco["starting"]
	var t := TimeManager.now()
	return {
		"schema": SCHEMA_VERSION,
		"created": t,
		"last_seen": t,
		"trusted_time": t,
		"player": {"name": "", "xp": 0, "level": 1, "trophies": 0, "best_trophies": 0, "leagues_reached": ["wick"]},
		"res": {"cogs": float(st["cogs"]), "sap": float(st["sap"]), "shards": float(st["shards"]), "glimmers": float(st["glimmers"])},
		"builders": int(st["builders"]),
		"buildings": [],
		"obstacles": [],
		"next_uid": 1,
		"obstacle_next_spawn": t + float(Balance.obstacles["rules"]["spawn_interval_s"]),
		"build_queue": [],
		"army": {"troops": {}, "spells": {}},
		"training": {"troops": [], "troops_started": 0.0, "spells": [], "spells_started": 0.0},
		"research": {"levels": {}, "spell_levels": {}, "job": {}},
		"progress": {"campaign": {}, "achievements": {}, "stats": {}, "daily": {}, "login": {"cycle_day": 0, "last_day": ""}},
		"shield_until": t + float(eco["shield"]["newbie_s"]),
		"defense_log": [],
		"next_offline_attack": t + float(eco["shield"]["newbie_s"]) + 14400.0,
		"offline_attacks": [],
		"clan": {},
		"tutorial": {"step": 0, "done": false},
		"settings": {"lang": "", "music": 0.7, "sfx": 0.9, "quality": "high", "shake": true},
		"rng_seed": randi(),
	}


func new_game(with_tutorial: bool = true) -> void:
	data = default_data()
	_by_uid.clear()
	# villaggio iniziale: Faro Madre, accampamento, alcuni ostacoli
	add_building("lantern_hall", 18, 18, 1)
	add_building("army_camp", 24, 17, 1)
	add_building("cog_vault", 13, 19, 1)
	add_building("sap_cistern", 23, 22, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var placed := 0
	var tries := 0
	while placed < 18 and tries < 500:
		tries += 1
		var kinds := ["sapling", "sapling", "sapling", "boulder", "boulder", "glowshroom"]
		var k: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var x := rng.randi_range(BUILD_MIN, BUILD_MAX - 1)
		var y := rng.randi_range(BUILD_MIN, BUILD_MAX - 1)
		if absi(x - 20) < 9 and absi(y - 20) < 9:
			continue
		if can_place(k, x, y):
			add_obstacle(k, x, y)
			placed += 1
	if not with_tutorial:
		data["tutorial"]["done"] = true
	EventBus.state_changed.emit()


# --------------------------------------------------------------- indici
func rebuild_index() -> void:
	_by_uid.clear()
	for b in data["buildings"]:
		_by_uid[int(b["uid"])] = b
	for o in data["obstacles"]:
		_by_uid[int(o["uid"])] = o


func next_uid() -> int:
	var u: int = int(data["next_uid"])
	data["next_uid"] = u + 1
	return u


func get_entity(uid: int) -> Dictionary:
	return _by_uid.get(uid, {})


func is_obstacle(e: Dictionary) -> bool:
	return Balance.category(e.get("id", "")) == "obstacle"


func buildings() -> Array:
	return data["buildings"]


func buildings_of(id: String) -> Array:
	var out: Array = []
	for b in data["buildings"]:
		if b["id"] == id:
			out.append(b)
	return out


func count_of(id: String) -> int:
	var n := 0
	for b in data["buildings"]:
		if b["id"] == id:
			n += 1
	return n


func hall() -> Dictionary:
	for b in data["buildings"]:
		if b["id"] == "lantern_hall":
			return b
	return {}


func hall_level() -> int:
	var h := hall()
	return maxi(1, int(h.get("level", 1)))


func highest_level(id: String) -> int:
	var m := 0
	for b in data["buildings"]:
		if b["id"] == id:
			m = maxi(m, int(b["level"]))
	return m


# --------------------------------------------------------------- griglia
func occupancy(ignore_uid: int = -1) -> Dictionary:
	## Vector2i -> uid per tutte le celle occupate da edifici e ostacoli.
	var occ := {}
	for list in [data["buildings"], data["obstacles"]]:
		for e in list:
			if int(e["uid"]) == ignore_uid:
				continue
			var n := Balance.footprint(e["id"])
			for dx in n:
				for dy in n:
					occ[Vector2i(int(e["x"]) + dx, int(e["y"]) + dy)] = int(e["uid"])
	return occ


func can_place(id: String, x: int, y: int, ignore_uid: int = -1, occ: Dictionary = {}) -> bool:
	var n := Balance.footprint(id)
	if x < BUILD_MIN or y < BUILD_MIN or x + n - 1 > BUILD_MAX or y + n - 1 > BUILD_MAX:
		return false
	var o := occ if not occ.is_empty() else occupancy(ignore_uid)
	for dx in n:
		for dy in n:
			if o.has(Vector2i(x + dx, y + dy)):
				return false
	return true


func find_free_spot(id: String, near: Vector2i = Vector2i(20, 20)) -> Vector2i:
	## Cerca la cella libera piu' vicina (spirale) per piazzare un nuovo edificio.
	var occ := occupancy()
	for r in range(0, 22):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var p := near + Vector2i(dx, dy)
				if can_place(id, p.x, p.y, -1, occ):
					return p
	return Vector2i(-1, -1)


# ------------------------------------------------------------- mutazioni
func add_building(id: String, x: int, y: int, level: int = 0) -> Dictionary:
	var b := {"uid": next_uid(), "id": id, "level": level, "x": x, "y": y, "flip": false, "job": {}}
	var cat := Balance.category(id)
	if cat == "economy":
		b["stored"] = 0.0
		b["last_prod"] = TimeManager.now()
	if cat == "trap":
		b["armed"] = true
	data["buildings"].append(b)
	_by_uid[int(b["uid"])] = b
	EventBus.building_added.emit(int(b["uid"]))
	return b


func add_obstacle(id: String, x: int, y: int) -> Dictionary:
	var o := {"uid": next_uid(), "id": id, "x": x, "y": y, "job": {}}
	data["obstacles"].append(o)
	_by_uid[int(o["uid"])] = o
	EventBus.obstacle_spawned.emit(int(o["uid"]))
	return o


func remove_entity(uid: int) -> void:
	var e := get_entity(uid)
	if e.is_empty():
		return
	data["buildings"].erase(e)
	data["obstacles"].erase(e)
	_by_uid.erase(uid)
	EventBus.building_removed.emit(uid)


func move_building(uid: int, x: int, y: int, flip: bool) -> bool:
	var b := get_entity(uid)
	if b.is_empty() or not can_place(b["id"], x, y, uid):
		return false
	b["x"] = x
	b["y"] = y
	b["flip"] = flip
	EventBus.building_moved.emit(uid)
	EventBus.state_changed.emit()
	return true


# -------------------------------------------------------------- esercito
func troop_level(id: String) -> int:
	return maxi(1, int(data["research"]["levels"].get(id, 1)))


func spell_level(id: String) -> int:
	## Il livello degli incantesimi segue il livello della Forgia (GDD §8.2).
	var f := buildings_of("spell_forge")
	var fl := 1 if f.is_empty() else maxi(1, int(f[0]["level"]))
	return clampi(fl, 1, Balance.spell_max_level(id))


func army_troops() -> Dictionary:
	return data["army"]["troops"]


func army_spells() -> Dictionary:
	return data["army"]["spells"]


func battle_army() -> Dictionary:
	## Esercito pronto nel formato della simulazione.
	var t := {}
	for id in army_troops():
		var n := int(army_troops()[id])
		if n > 0:
			t[id] = {"count": n, "level": troop_level(id)}
	var s := {}
	for id in army_spells():
		var n := int(army_spells()[id])
		if n > 0:
			s[id] = {"count": n, "level": spell_level(id)}
	return {"troops": t, "spells": s}


# ------------------------------------------------------------- risorse
func res(name: String) -> float:
	return float(data["res"].get(name, 0.0))


func stat(metric: String) -> float:
	return float(data["progress"]["stats"].get(metric, 0.0))


func settings() -> Dictionary:
	return data["settings"]


## Base del giocatore nel formato usato da simulazione e generatore (per attacchi subiti e replay).
func base_snapshot() -> Dictionary:
	var list: Array = []
	for b in data["buildings"]:
		if int(b["level"]) <= 0:
			continue
		if Balance.category(b["id"]) == "trap" and not b.get("armed", true):
			continue
		list.append({"id": b["id"], "level": int(b["level"]), "x": int(b["x"]), "y": int(b["y"]), "uid": int(b["uid"])})
	return {"buildings": list, "hall_level": hall_level(), "palette": "player"}
