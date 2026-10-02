extends Node
## Dati di bilanciamento caricati da res://data/*.json (generati da tools/gen_balance.py).
## Nessun numero di gameplay e' scritto nel codice: tutto passa da qui.

const DATA_DIR := "res://data/"

var hall_rows: Array = []
var hall_unlocks: Array = []
var max_level_by_hall: Array = []
var economy: Dictionary = {}
var leagues: Array = []
var xp_levels: Array = []
var campaign: Array = []
var achievements: Array = []
var daily: Dictionary = {}
var obstacles: Dictionary = {}

var _levels: Dictionary = {}      ## id -> Array[Dictionary] (indice = livello-1)
var _footprint: Dictionary = {}   ## id -> int
var _category: Dictionary = {}    ## id -> String
var _unlock: Dictionary = {}      ## id -> hall di sblocco
var _counts: Dictionary = {}      ## id -> Array[int] (indice = hall-1)
var _troops: Dictionary = {}      ## id -> Array livelli
var _lab: Dictionary = {}         ## id -> {livello: riga}
var _spells: Dictionary = {}      ## id -> Array livelli
var troop_order: Array = []
var spell_order: Array = []
var defense_order: Array = []


func _ready() -> void:
	load_all()


func _json(file: String) -> Variant:
	var f := FileAccess.open(DATA_DIR + file, FileAccess.READ)
	if f == null:
		push_error("Balance: impossibile aprire %s" % file)
		return null
	return JSON.parse_string(f.get_as_text())


func _index_levels(rows: Array, category: String) -> void:
	for r in rows:
		var id: String = r["id"]
		if not _levels.has(id):
			_levels[id] = []
			_category[id] = category
		_levels[id].append(r)


func load_all() -> void:
	_levels.clear()
	hall_rows = _json("hall.json")
	_levels["lantern_hall"] = hall_rows
	_category["lantern_hall"] = "core"
	_footprint["lantern_hall"] = 4
	_unlock["lantern_hall"] = 1
	hall_unlocks = _json("hall_unlocks.json")
	max_level_by_hall = _json("max_level_by_hall.json")
	var b: Dictionary = _json("buildings.json")
	_index_levels(b["economy"], "economy")
	_index_levels(b["storage"], "storage")
	for r in b["military"]:
		var cat := "social" if r["id"] == "clan_hall" else "military"
		_index_levels([r], cat)
	for id in b["footprints"]:
		_footprint[id] = int(b["footprints"][id])
	for id in b["unlock_hall"]:
		_unlock[id] = int(b["unlock_hall"][id])
	for id in b["counts_by_hall"]:
		_counts[id] = b["counts_by_hall"][id]
	var d: Dictionary = _json("defenses.json")
	_index_levels(d["levels"], "defense")
	for id in d["unlock_hall"]:
		_unlock[id] = int(d["unlock_hall"][id])
		_counts[id] = d["counts_by_hall"][id]
		_footprint[id] = int(_levels[id][0]["size"])
	defense_order = d["order"]
	var w: Dictionary = _json("walls.json")
	_index_levels(w["levels"], "wall")
	_counts["wall"] = w["counts_by_hall"]
	_footprint["wall"] = 1
	_unlock["wall"] = 1
	var t: Dictionary = _json("traps.json")
	_index_levels(t["levels"], "trap")
	for id in t["counts_by_hall"]:
		_counts[id] = t["counts_by_hall"][id]
		_footprint[id] = int(_levels[id][0]["size"])
		_unlock[id] = int(_levels[id][0]["req_hall"])
	var tr: Dictionary = _json("troops.json")
	_troops.clear()
	troop_order.clear()
	for r in tr["levels"]:
		if not _troops.has(r["id"]):
			_troops[r["id"]] = []
			troop_order.append(r["id"])
		_troops[r["id"]].append(r)
	_lab.clear()
	for r in tr["lab"]:
		if not _lab.has(r["id"]):
			_lab[r["id"]] = {}
		_lab[r["id"]][int(r["level"])] = r
	_spells.clear()
	spell_order.clear()
	for r in tr["spells"]:
		if not _spells.has(r["id"]):
			_spells[r["id"]] = []
			spell_order.append(r["id"])
		_spells[r["id"]].append(r)
	economy = _json("economy.json")
	leagues = _json("leagues.json")
	xp_levels = _json("xp_levels.json")
	campaign = _json("campaign.json")
	achievements = _json("achievements.json")
	daily = _json("daily.json")
	obstacles = _json("obstacles.json")
	for o in obstacles["types"]:
		_footprint[o["id"]] = int(o["size"])
		_category[o["id"]] = "obstacle"


# ------------------------------------------------------------ strutture
func has_structure(id: String) -> bool:
	return _levels.has(id)


func structure_ids() -> Array:
	return _levels.keys()


func category(id: String) -> String:
	return _category.get(id, "")


func footprint(id: String) -> int:
	return int(_footprint.get(id, 1))


func max_level(id: String) -> int:
	return _levels[id].size() if _levels.has(id) else 0


func level_data(id: String, level: int) -> Dictionary:
	if not _levels.has(id):
		return {}
	var arr: Array = _levels[id]
	return arr[clampi(level, 1, arr.size()) - 1]


func unlock_hall(id: String) -> int:
	return int(_unlock.get(id, 1))


func count_allowed(id: String, hall: int) -> int:
	if id == "lantern_hall":
		return 1
	if not _counts.has(id):
		return 0
	return int(_counts[id][clampi(hall, 1, 10) - 1])


func max_level_at_hall(id: String, hall: int) -> int:
	if id == "lantern_hall":
		return mini(10, hall + 1)
	var row: Dictionary = max_level_by_hall[clampi(hall, 1, 10) - 1]
	return int(row.get(id, 0))


func is_defense(id: String) -> bool:
	return _category.get(id, "") == "defense"


func shop_ids(cat: String) -> Array:
	## Elenco per le schede del negozio.
	match cat:
		"economy":
			return ["cog_mine", "sap_well", "shard_drill", "cog_vault", "sap_cistern", "shard_crate"]
		"defense":
			return defense_order + ["wall"]
		"army":
			return ["barracks", "army_camp", "laboratory", "spell_forge", "clan_hall"]
		"trap":
			return ["bomb_trap", "spring_pad", "snare_trap", "air_mine"]
	return []


# ----------------------------------------------------------------- truppe
func troop(id: String, level: int) -> Dictionary:
	var arr: Array = _troops[id]
	return arr[clampi(level, 1, arr.size()) - 1]


func troop_max_level(id: String) -> int:
	return _troops[id].size()


func lab_row(id: String, level: int) -> Dictionary:
	return _lab.get(id, {}).get(level, {})


func spell(id: String, level: int) -> Dictionary:
	var arr: Array = _spells[id]
	return arr[clampi(level, 1, arr.size()) - 1]


func spell_max_level(id: String) -> int:
	return _spells[id].size()


# ---------------------------------------------------------- progressione
func league_for(trophies: int) -> Dictionary:
	for l in leagues:
		if trophies >= int(l["trophies_min"]) and trophies <= int(l["trophies_max"]):
			return l
	return leagues[0]


func campaign_level(n: int) -> Dictionary:
	return campaign[clampi(n, 1, campaign.size()) - 1]
