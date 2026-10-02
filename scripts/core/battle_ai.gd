class_name BattleAI
extends RefCounted
## Attaccante automatico: usato per gli attacchi subiti offline, per la demo del tutorial e per i test di stress.
## Strategia: sceglie un lato, schiera prima i tank e i distruttori di mura, poi il resto a ondate; incantesimi sulle truppe.

const TANKS := ["bulwark", "ember_warden", "dirigible", "rustjaw"]
const BREAKERS := ["kegger"]


## Restituisce un piano [[tick, "troop"|"spell", id, x, y], ...] ordinato per tick.
static func plan(sim: BattleSim, rng: RandomNumberGenerator) -> Array:
	var cells := _side_cells(sim, rng)
	if cells.is_empty():
		return []
	var plan: Array = []
	var order: Array = []
	for id in sim.army:
		var n := int(sim.army[id]["count"])
		for k in n:
			order.append(id)
	order.sort_custom(func(a, b): return _rank(a) < _rank(b))
	var tick := 15
	var ci := 0
	var wave_size := maxi(4, order.size() / 4)
	for k in order.size():
		var id: String = order[k]
		var c: Vector2 = cells[ci % cells.size()]
		ci += 1
		var jitter := Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
		plan.append([tick, "troop", id, c.x + 0.5 + jitter.x, c.y + 0.5 + jitter.y])
		tick += 3
		if _rank(id) == 0 and k + 1 < order.size() and _rank(order[k + 1]) > 0:
			tick += 45           # pausa dopo i tank
		elif (k + 1) % wave_size == 0:
			tick += 60
	# incantesimi: a meta' battaglia sul punto di schieramento spostato verso la base
	var mid: Vector2 = cells[cells.size() / 2]
	var toward := (Vector2(22, 22) - mid).normalized()
	var st := tick + 60
	for id in sim.spell_stock:
		for k in int(sim.spell_stock[id]["count"]):
			var p := mid + toward * (7.0 + 2.0 * k)
			plan.append([st, "spell", id, p.x, p.y])
			st += 90
	plan.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return plan


static func _rank(id: String) -> int:
	if id in TANKS:
		return 0
	if id in BREAKERS:
		return 1
	return 2


static func _side_cells(sim: BattleSim, rng: RandomNumberGenerator) -> Array:
	## Celle schierabili lungo il lato scelto, le piu' vicine al centro della base.
	var side := rng.randi_range(0, 3)
	var center := Vector2(22, 22)
	var acc: Array = []
	for b in sim.buildings:
		acc.append(b.center)
	if not acc.is_empty():
		var s := Vector2()
		for p in acc:
			s += p
		center = s / acc.size()
	var best: Array = []
	for i in BattleSim.W:
		# scansiona dal bordo verso il centro lungo una linea, prendi la cella schierabile piu' interna
		var last := Vector2(-1, -1)
		for depth in BattleSim.W / 2:
			var c: Vector2i
			match side:
				0: c = Vector2i(i, depth)
				1: c = Vector2i(BattleSim.W - 1 - depth, i)
				2: c = Vector2i(i, BattleSim.W - 1 - depth)
				_: c = Vector2i(depth, i)
			if sim.deployable[c.y * BattleSim.W + c.x] == 1:
				last = Vector2(c)
			else:
				break
		if last.x >= 0:
			best.append(last)
	best.sort_custom(func(a, b): return a.distance_to(center) < b.distance_to(center))
	return best.slice(0, mini(8, best.size()))


## Esegue l'intera battaglia con il piano dell'IA.
static func autoplay(sim: BattleSim, rng: RandomNumberGenerator) -> Dictionary:
	var p := plan(sim, rng)
	var k := 0
	var guard := 0
	while not sim.ended and guard < sim.max_ticks + 10:
		while k < p.size() and int(p[k][0]) <= sim.tick:
			var e: Array = p[k]
			if e[1] == "troop":
				sim.deploy_troop(e[2], Vector2(e[3], e[4]))
			else:
				sim.cast_spell(e[2], Vector2(e[3], e[4]))
			k += 1
		sim.step()
		guard += 1
	return sim.result()


## Esercito plausibile per un attaccante di Hall `hall` (capacita' = capacita' massima a quella Hall).
static func random_army(hall: int, rng: RandomNumberGenerator, capacity_scale: float = 1.0) -> Dictionary:
	var cap := 0
	var camps := Balance.count_allowed("army_camp", hall)
	var camp_lvl := Balance.max_level_at_hall("army_camp", hall)
	cap = int(camps * int(Balance.level_data("army_camp", maxi(1, camp_lvl))["army_capacity"]) * capacity_scale)
	var barracks := Balance.max_level_at_hall("barracks", hall)
	var lab := Balance.max_level_at_hall("laboratory", hall)
	var avail: Array = []
	for id in Balance.troop_order:
		if int(Balance.troop(id, 1)["barracks_req"]) <= barracks:
			avail.append(id)
	var troops := {}
	var used := 0
	var guard := 0
	while used < cap and guard < 400 and not avail.is_empty():
		guard += 1
		var id: String = avail[rng.randi_range(0, avail.size() - 1)]
		var sz := int(Balance.troop(id, 1)["size"])
		if used + sz > cap:
			continue
		used += sz
		if not troops.has(id):
			troops[id] = {"count": 0, "level": clampi(maxi(1, lab), 1, Balance.troop_max_level(id))}
		troops[id]["count"] = int(troops[id]["count"]) + 1
	var spells := {}
	var forge := Balance.max_level_at_hall("spell_forge", hall)
	if forge > 0:
		spells["mending_mist"] = {"count": 1, "level": mini(forge, 5)}
		if forge >= 2:
			spells["fervor_surge"] = {"count": 1, "level": mini(forge, 5)}
	return {"troops": troops, "spells": spells}
