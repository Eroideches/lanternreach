class_name BaseGenerator
extends RefCounted
## Basi avversarie procedurali "plausibili" (GDD §10.2): algoritmo ad anelli concentrici attorno al Faro Madre.
##   anello 0 (core): Hall + difese ad area / alto danno, antiaeree che coprono la Hall
##   anello 1: depositi e difese a corto raggio, cinto da un compartimento di mura con 1-2 varchi
##   anello 2: estrattori, edifici militari, difese a lungo raggio, secondo anello di mura
##   esterno: mine, sala del clan; trappole vicino ai varchi
## Validazione: nessuna sovrapposizione, >= 85% delle celle libere raggiungibili dal bordo (mura attraversabili),
## >= 60% delle difese dentro il secondo anello. Se fallisce: seed+1 (max 8 tentativi).

const W := 44
const CORE_DEF := ["lobber", "thumper", "storm_pylon", "skyspear", "cinder_spout"]
const MID_DEF := ["boltpost", "arc_coil", "frost_spire", "skyspear"]
const OUTER_DEF := ["ballista", "boltpost"]
const STORAGES := ["cog_vault", "sap_cistern", "shard_crate"]
const EXTRACTORS := ["cog_mine", "sap_well", "shard_drill"]
const MILITARY := ["barracks", "army_camp", "laboratory", "spell_forge", "clan_hall"]
const TRAPS := ["bomb_trap", "spring_pad", "snare_trap", "air_mine"]

var rng := RandomNumberGenerator.new()
var occ := {}          ## Vector2i -> true
var walls := {}        ## Vector2i -> true
var out: Array = []
var hall_c := Vector2i(22, 22)
var r1 := 6
var r2 := 11


static func hall_for_trophies(trophies: int, player_hall: int, rng_in: RandomNumberGenerator) -> int:
	var h := clampi(1 + trophies / 330, 1, 10)
	var j := rng_in.randf()
	if j < 0.2:
		h -= 1
	elif j > 0.8:
		h += 1
	return clampi(h, maxi(1, player_hall - 1), mini(10, player_hall + 1))


static func generate(hall: int, seed: int, fill_min: float = 0.65) -> Dictionary:
	for attempt in 8:
		var g := BaseGenerator.new()
		var base := g._try(hall, seed + attempt, fill_min)
		if not base.is_empty():
			base["seed"] = seed + attempt
			return base
	# riserva: livello di campagna della stessa Hall
	for lv in Balance.campaign:
		if int(lv["hall_level"]) == hall:
			return CampaignData.load_level(int(lv["level"]))
	return {}


func _try(hall: int, seed: int, fill_min: float) -> Dictionary:
	rng.seed = seed
	occ.clear()
	walls.clear()
	out.clear()
	r1 = 4 + (2 if hall >= 3 else 0) + (1 if hall >= 6 else 0)
	r2 = r1 + 5 + (1 if hall >= 8 else 0)
	hall_c = Vector2i(20 + rng.randi_range(0, 2), 20 + rng.randi_range(0, 2))
	_place_at("lantern_hall", hall_c.x, hall_c.y, hall)
	var counts := {}
	for id in Balance.structure_ids():
		if id == "lantern_hall":
			continue
		var cat := Balance.category(id)
		if cat == "":
			continue
		var allowed := Balance.count_allowed(id, hall)
		if allowed <= 0:
			continue
		var fill := rng.randf_range(fill_min, 1.0)
		var n := allowed if cat in ["defense", "storage"] else maxi(1, int(round(allowed * fill)))
		if cat == "wall":
			n = int(round(allowed * fill))
		counts[id] = n
	var center := Vector2(hall_c) + Vector2(2, 2)
	# anello 0: difese pesanti vicino alla Hall
	var defense_list: Array = []
	for id in Balance.defense_order:
		for k in int(counts.get(id, 0)):
			defense_list.append(id)
	var core_n := 0
	for id in defense_list.duplicate():
		if id in CORE_DEF and core_n < 2 + hall / 3:
			if _place_ring(id, hall, center, 2.5, float(r1) - 1.0):
				defense_list.erase(id)
				core_n += 1
	# mura: due anelli rettangolari
	var wall_n := int(counts.get("wall", 0))
	wall_n = _ring_walls(center, r1, wall_n, hall)
	if wall_n > 0:
		wall_n = _ring_walls(center, r2, wall_n, hall)
	# depositi tra anello 1 e 2 (alcuni dentro il core)
	for id in STORAGES:
		for k in int(counts.get(id, 0)):
			_place_ring(id, hall, center, 3.0, float(r2) - 1.5)
	# difese restanti: 70% dentro l'anello 2
	for id in defense_list:
		var inner := rng.randf() < 0.7
		if not _place_ring(id, hall, center, float(r1) + 0.5 if inner else 2.5, float(r2) - 1.0 if inner else float(r2) + 4.0):
			_place_ring(id, hall, center, 2.0, float(r2) + 6.0)
	for id in EXTRACTORS + MILITARY:
		for k in int(counts.get(id, 0)):
			_place_ring(id, hall, center, float(r2) + 1.0, float(r2) + 8.0)
	for id in TRAPS:
		for k in int(counts.get(id, 0)):
			_place_ring(id, hall, center, float(r1) - 1.0, float(r2) + 1.0)
	return _validate(hall)


func _level_for(id: String, hall: int) -> int:
	var mx := Balance.max_level_at_hall(id, hall)
	if mx <= 0:
		return 0
	return clampi(mx - rng.randi_range(0, 2), 1, mx)


func _free(id: String, x: int, y: int) -> bool:
	var n := Balance.footprint(id)
	if x < 2 or y < 2 or x + n - 1 > 41 or y + n - 1 > 41:
		return false
	for dx in n:
		for dy in n:
			var c := Vector2i(x + dx, y + dy)
			if occ.has(c) or walls.has(c):
				return false
	return true


func _place_at(id: String, x: int, y: int, hall: int) -> bool:
	if not _free(id, x, y):
		return false
	var lvl := _level_for(id, hall) if id != "lantern_hall" else hall
	if lvl <= 0:
		return false
	var n := Balance.footprint(id)
	for dx in n:
		for dy in n:
			if id == "wall":
				walls[Vector2i(x + dx, y + dy)] = true
			else:
				occ[Vector2i(x + dx, y + dy)] = true
	out.append({"id": id, "level": lvl, "x": x, "y": y})
	return true


func _place_ring(id: String, hall: int, center: Vector2, rmin: float, rmax: float) -> bool:
	var n := Balance.footprint(id)
	for tries in 160:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var x := int(round(center.x + cos(ang) * r - n / 2.0))
		var y := int(round(center.y + sin(ang) * r - n / 2.0))
		# lascia 1 cella di respiro tra edifici (piu' leggibile e percorribile)
		if _free(id, x, y) and (Balance.category(id) == "trap" or _breathing(x, y, n)):
			return _place_at(id, x, y, hall)
	return false


func _breathing(x: int, y: int, n: int) -> bool:
	var touching := 0
	for dx in range(-1, n + 1):
		for dy in range(-1, n + 1):
			if dx >= 0 and dy >= 0 and dx < n and dy < n:
				continue
			if occ.has(Vector2i(x + dx, y + dy)):
				touching += 1
	return touching <= n


func _ring_walls(center: Vector2, r: int, budget: int, hall: int) -> int:
	var x0 := int(center.x) - r
	var y0 := int(center.y) - r
	var x1 := int(center.x) + r
	var y1 := int(center.y) + r
	var cells: Array = []
	for x in range(x0, x1 + 1):
		cells.append(Vector2i(x, y0))
		cells.append(Vector2i(x, y1))
	for y in range(y0 + 1, y1):
		cells.append(Vector2i(x0, y))
		cells.append(Vector2i(x1, y))
	# varchi
	var gaps := 1 + rng.randi_range(0, 1)
	var gap_cells := {}
	for g in gaps:
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		gap_cells[c] = true
	for c in cells:
		if budget <= 0:
			break
		if gap_cells.has(c) or occ.has(c):
			continue
		if _place_at("wall", c.x, c.y, hall):
			budget -= 1
	return budget


func _validate(hall: int) -> Dictionary:
	# connettivita' delle celle libere dal bordo
	var free_total := 0
	for x in range(2, 42):
		for y in range(2, 42):
			if not occ.has(Vector2i(x, y)):
				free_total += 1
	var seen := {}
	var stack: Array = []
	for i in W:
		for c in [Vector2i(i, 0), Vector2i(i, W - 1), Vector2i(0, i), Vector2i(W - 1, i)]:
			stack.append(c)
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if c.x < 0 or c.y < 0 or c.x >= W or c.y >= W or seen.has(c) or occ.has(c):
			continue
		seen[c] = true
		stack.append(c + Vector2i(1, 0))
		stack.append(c + Vector2i(-1, 0))
		stack.append(c + Vector2i(0, 1))
		stack.append(c + Vector2i(0, -1))
	var reach := 0
	for c in seen:
		if c.x >= 2 and c.y >= 2 and c.x < 42 and c.y < 42:
			reach += 1
	if free_total > 0 and float(reach) / float(free_total) < 0.85:
		return {}
	# difese protette
	var defs := 0
	var inner := 0
	var center := Vector2(hall_c) + Vector2(2, 2)
	for b in out:
		if Balance.category(b["id"]) == "defense":
			defs += 1
			var bc := Vector2(b["x"], b["y"]) + Vector2.ONE * Balance.footprint(b["id"]) / 2.0
			if maxf(absf(bc.x - center.x), absf(bc.y - center.y)) <= r2:
				inner += 1
	if defs > 0 and float(inner) / float(defs) < 0.6:
		return {}
	return {"buildings": out.duplicate(true), "hall_level": hall, "palette": "player"}


## Bottino disponibile in una base generata: contenuto simulato dei depositi, percentuale e tetto per Hall.
static func loot_for(hall: int, rng_in: RandomNumberGenerator, attacker_hall: int) -> Dictionary:
	var eco: Dictionary = Balance.economy["loot"]
	var mod := Formulas.loot_hall_modifier(hall, attacker_hall, eco["hall_diff_modifier"])
	var res := {}
	for r in ["cogs", "sap"]:
		var cap := 0.0
		var sid := "cog_vault" if r == "cogs" else "sap_cistern"
		var lvl := maxi(1, Balance.max_level_at_hall(sid, hall))
		cap = Balance.count_allowed(sid, hall) * float(Balance.level_data(sid, lvl)["capacity"])
		var content := cap * rng_in.randf_range(0.3, 0.9)
		var lootable := Formulas.storage_lootable(content, hall, eco["pct_stored_by_hall"])
		# estrattori pieni a meta'
		var eid := "cog_mine" if r == "cogs" else "sap_well"
		var el := maxi(1, Balance.max_level_at_hall(eid, hall))
		lootable += Balance.count_allowed(eid, hall) * float(Balance.level_data(eid, el)["capacity"]) * 0.5 * float(eco["pct_extractor"])
		res[r] = floorf(Formulas.cap_loot(lootable, hall, eco["cap_by_hall"]) * mod)
	res["shards"] = floorf(float(eco["shard_cap_by_hall"][hall - 1]) * rng_in.randf_range(0.3, 1.0) * mod)
	return res


static func random_name(rng_in: RandomNumberGenerator) -> String:
	var a := ["Amber", "Brass", "Cloud", "Dusk", "Ember", "Fern", "Gale", "Hollow", "Ivy", "Jade", "Kite", "Lumen", "Moss", "North", "Oak", "Pine", "Quill", "Rust", "Sky", "Tin", "Umber", "Vale", "Wisp", "Zephyr"]
	var b := ["haven", "spire", "reach", "hold", "cove", "watch", "field", "ridge", "nest", "gate", "drift", "crest"]
	return a[rng_in.randi_range(0, a.size() - 1)] + b[rng_in.randi_range(0, b.size() - 1)]
