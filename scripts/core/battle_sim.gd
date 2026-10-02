class_name BattleSim
extends RefCounted
## Simulazione di battaglia deterministica a passo fisso (30 tick/s), separata dalla visualizzazione.
## Stessa base + stesso esercito + stessi input (tick, comando) => stesso risultato: e' la base dei replay.
##
## Coordinate: celle (float). Una truppa in (x, y) sta nella cella floor(x), floor(y).

const TICK_RATE := 30
const DT := 1.0 / 30.0
const W := 44
const EXPANSION_BUDGET := 700        ## nodi A* espansi al massimo per tick (costo per tick limitato)
const TARGET_BUDGET := 24            ## scelte di bersaglio massime per tick (le altre truppe attendono un tick)
const RETARGET_DEF_TICKS := 15       ## le difese rivalutano il bersaglio ogni 0,5 s
const PROJ_SPEED := {"boltpost": 18.0, "skyspear": 20.0, "ballista": 16.0, "lobber": 7.0, "storm_pylon": 14.0}
const INSTANT := ["arc_coil", "cinder_spout", "frost_spire", "thumper"]
const RESOURCE_BUILDINGS := ["cog_mine", "sap_well", "shard_drill", "cog_vault", "sap_cistern", "shard_crate"]
enum Kind { NORMAL, DEFENSE, RESOURCE, WALL, TRAP }
enum Prio { NEAREST, CLUSTER, LOWEST_HP, FARTHEST, HIGHEST_HP }
const PRIO_OF := {"nearest": Prio.NEAREST, "nearest_air": Prio.NEAREST, "highest_hp_cluster": Prio.CLUSTER,
	"nearest_air_cluster": Prio.CLUSTER, "lowest_hp": Prio.LOWEST_HP, "farthest_in_range": Prio.FARTHEST, "highest_hp": Prio.HIGHEST_HP}


class SBuilding:
	var i := 0
	var uid := 0
	var id := ""
	var cat := ""
	var level := 1
	var x := 0
	var y := 0
	var n := 1
	var hp := 1.0
	var max_hp := 1.0
	var alive := true
	var counts := true        ## conta per la % di distruzione
	var d: Dictionary = {}
	var cooldown := 0.0
	var target := -1
	var retarget := 0
	var loot: Dictionary = {}
	var looted: Dictionary = {}
	var armed := true
	var rect := Rect2()
	var center := Vector2()
	var hp_boost := 1.0
	# parametri precalcolati (evitano letture da dizionario nel ciclo caldo)
	var kind := 0
	var rmin2 := 0.0
	var rmax2 := 0.0
	var t_ground := true
	var t_air := false
	var interval := 1.0
	var dmg := 0.0
	var splash := 0.0
	var prio := 0
	var trig2 := 0.0
	var eff_r := 0.0
	var trap_air := false


class STroop:
	var i := 0
	var id := ""
	var level := 1
	var d: Dictionary = {}
	var hp := 1.0
	var max_hp := 1.0
	var dps := 0.0
	var speed := 1.0
	var atk_range := 0.6
	var flying := false
	var pref := "any"
	var size := 1
	var pos := Vector2()
	var prev_pos := Vector2()
	var alive := true
	var target := -1          ## indice edificio
	var wall_target := -1     ## muro che sta abbattendo lungo il percorso
	var ally := -1            ## (Mender) truppa seguita
	var path: Array = []
	var path_i := 0
	var need_path := true
	var cooldown := 0.0
	var attacking := false
	var frozen_until := 0
	var slow_until := 0
	var slow_frac := 0.0
	var buff_dmg := 0.0
	var buff_speed := 0.0
	var surge_used := false
	var surge_until := 0
	var heal_left := 0.0
	var stuck_ticks := 0
	var max_stuck := 0
	var anchor := Vector2()
	var facing := Vector2(1, 1)
	var hop := false
	var path_pending := false
	var is_mender := false
	var is_warden := false
	var is_kegger := false
	var is_magpie := false
	var is_dirigible := false


class SProj:
	var kind := ""
	var from := -1
	var target := -1
	var start := Vector2()
	var aim := Vector2()
	var impact_tick := 0
	var start_tick := 0
	var damage := 0.0
	var splash := 0.0
	var air := false
	var ground := true
	var alive := true


var buildings: Array[SBuilding] = []
var troops: Array[STroop] = []
var projectiles: Array[SProj] = []
var spells: Array = []                 ## {id, pos, radius, end, d}
var tick := 0
var max_ticks := 180 * TICK_RATE
var seed := 0
var rng := RandomNumberGenerator.new()
var pf: Pathfinder
var cell_b := PackedInt32Array()       ## cella -> indice edificio (non muro, non trappola), -1
var cell_w := PackedInt32Array()       ## cella -> indice muro, -1
var deployable := PackedByteArray()
var wall_version := 0
var _path_cache: Dictionary = {}
var _group_paths: Dictionary = {}      ## percorsi riusabili per (bersaglio, profilo, versione mura)
var _path_queue: Array[int] = []
var _search_troop := -1
var _search_target := -1
var _search_key := ""
var _search_gkey := ""
var _target_budget := 0
var army: Dictionary = {}              ## id -> {count, level} rimanenti
var spell_stock: Dictionary = {}
var _pending: Array = []               ## comandi da applicare al prossimo tick
var inputs: Array = []                 ## registro per il replay: [tick, tipo, id, x, y]
var events: Array = []                 ## eventi del tick corrente per la visualizzazione
var total_counted := 0
var destroyed_counted := 0
var hall_destroyed := false
var loot_taken := {"cogs": 0.0, "sap": 0.0, "shards": 0.0}
var ended := false
var end_reason := ""
var deployed_any := false
var used_troops: Dictionary = {}
var used_spells: Dictionary = {}
var defenses_destroyed := 0
var walls_destroyed := 0
var base_info: Dictionary = {}
var army_info: Dictionary = {}
var _hp_mult := 1.0                    ## difficolta' (campagna): moltiplicatori di punti vita e danni della base
var _dmg_mult := 1.0
var _gh := PackedInt32Array()          ## griglia spaziale delle truppe: cella -> prima truppa (-1)
var _gn := PackedInt32Array()          ## truppa -> successiva nella stessa cella
var profile := false                   ## misura i microsecondi per fase (diagnostica)
var prof: Dictionary = {"spells": 0, "troops": 0, "defenses": 0, "traps": 0, "projectiles": 0, "astar": 0, "astar_calls": 0}


# ================================================================= setup
## base: {buildings:[{id, level, x, y}], hall_level, loot:{cogs, sap, shards}, hall_hp_mult?}
## army: {troops:{id:{count, level}}, spells:{id:{count, level}}}
func setup(base: Dictionary, army_in: Dictionary, seed_in: int) -> void:
	base_info = base
	army_info = army_in.duplicate(true)
	seed = seed_in
	rng.seed = seed_in
	pf = Pathfinder.new(W)
	cell_b.resize(W * W)
	cell_b.fill(-1)
	cell_w.resize(W * W)
	cell_w.fill(-1)
	_hp_mult = float(base.get("hp_mult", 1.0))
	_dmg_mult = float(base.get("dmg_mult", 1.0))
	for bd in base["buildings"]:
		_add_building(bd, float(base.get("hall_hp_mult", 1.0)))
	_distribute_loot(base.get("loot", {}))
	_compute_deployable()
	_gh.resize(W * W)
	_gh.fill(-1)
	for id in army_in.get("troops", {}):
		army[id] = {"count": int(army_in["troops"][id]["count"]), "level": int(army_in["troops"][id]["level"])}
	for id in army_in.get("spells", {}):
		spell_stock[id] = {"count": int(army_in["spells"][id]["count"]), "level": int(army_in["spells"][id]["level"])}


func _add_building(bd: Dictionary, hall_mult: float) -> void:
	var b := SBuilding.new()
	b.i = buildings.size()
	b.uid = int(bd.get("uid", b.i))
	b.id = bd["id"]
	b.cat = Balance.category(b.id)
	b.level = int(bd["level"])
	b.x = int(bd["x"])
	b.y = int(bd["y"])
	b.n = Balance.footprint(b.id)
	b.d = Balance.level_data(b.id, b.level)
	b.rect = Rect2(b.x, b.y, b.n, b.n)
	b.center = b.rect.get_center()
	match b.cat:
		"defense":
			b.kind = Kind.DEFENSE
		"wall":
			b.kind = Kind.WALL
		"trap":
			b.kind = Kind.TRAP
		_:
			b.kind = Kind.RESOURCE if b.id in RESOURCE_BUILDINGS else Kind.NORMAL
	if b.kind == Kind.DEFENSE:
		var half := b.n * 0.5
		var rmax := float(b.d["range_max"]) + half
		b.rmax2 = rmax * rmax
		var rmin := float(b.d["range_min"])
		b.rmin2 = (rmin + half) * (rmin + half) if rmin > 0.0 else 0.0
		var tg: String = b.d["targets"]
		b.t_ground = tg != "air"
		b.t_air = tg != "ground"
		b.interval = float(b.d["interval_s"])
		b.dmg = float(b.d["damage_per_shot"]) * _dmg_mult
		b.splash = float(b.d.get("splash_radius", 0.0))
		b.prio = int(PRIO_OF.get(b.d["priority"], Prio.NEAREST))
	elif b.kind == Kind.TRAP:
		var trig := float(b.d["trigger_radius"])
		b.trig2 = trig * trig
		b.eff_r = float(b.d["effect_radius"])
		b.trap_air = b.d["targets"] == "air"
	if b.cat == "trap":
		b.hp = 1.0
		b.max_hp = 1.0
		b.counts = false
		b.armed = true
	else:
		b.max_hp = float(b.d.get("hp", 100)) * (hall_mult if b.id == "lantern_hall" else 1.0) * _hp_mult
		b.hp = b.max_hp
		b.counts = b.cat != "wall"
	if b.counts:
		total_counted += 1
	buildings.append(b)
	if b.cat == "wall":
		cell_w[b.y * W + b.x] = b.i
		pf.wall[b.y * W + b.x] = b.hp
	elif b.cat != "trap":
		for dx in b.n:
			for dy in b.n:
				cell_b[(b.y + dy) * W + b.x + dx] = b.i
		pf.set_block_rect(b.x, b.y, b.n, 1)
	if b.cat == "defense":
		b.cooldown = float(b.d.get("interval_s", 1.0)) * 0.5


func _distribute_loot(loot: Dictionary) -> void:
	## Distribuisce il bottino disponibile tra depositi/estrattori/Hall in proporzione alla capacita'.
	for r in ["cogs", "sap", "shards"]:
		var total := float(loot.get(r, 0.0))
		if total <= 0.0:
			continue
		var holders: Array = []
		var weight := 0.0
		for b in buildings:
			var w := _holder_weight(b, r)
			if w > 0.0:
				holders.append([b, w])
				weight += w
		for h in holders:
			var b: SBuilding = h[0]
			b.loot[r] = total * float(h[1]) / weight
			b.looted[r] = 0.0


func _holder_weight(b: SBuilding, r: String) -> float:
	match r:
		"cogs":
			if b.id == "cog_vault" or b.id == "cog_mine":
				return float(b.d.get("capacity", 1))
			if b.id == "lantern_hall":
				return float(b.d.get("stored_cogs", 1))
		"sap":
			if b.id == "sap_cistern" or b.id == "sap_well":
				return float(b.d.get("capacity", 1))
			if b.id == "lantern_hall":
				return float(b.d.get("stored_sap", 1))
		"shards":
			if b.id == "shard_crate" or b.id == "shard_drill":
				return float(b.d.get("capacity", 1))
	return 0.0


func _compute_deployable() -> void:
	var margin := int(Balance.economy["battle"]["no_deploy_margin"])
	deployable.resize(W * W)
	deployable.fill(1)
	for b in buildings:
		if b.cat == "trap":
			continue
		for x in range(b.x - margin, b.x + b.n + margin):
			for y in range(b.y - margin, b.y + b.n + margin):
				if x >= 0 and y >= 0 and x < W and y < W:
					deployable[y * W + x] = 0
	var border := int(Balance.economy["battle"]["border"])
	for x in W:
		for y in W:
			if x < border or y < border or x >= W - border or y >= W - border:
				deployable[y * W + x] = 1


func can_deploy_at(p: Vector2) -> bool:
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= W:
		return false
	return deployable[c.y * W + c.x] == 1


# ============================================================== comandi
func deploy_troop(id: String, p: Vector2) -> bool:
	if ended or not army.has(id) or int(army[id]["count"]) <= 0 or not can_deploy_at(p):
		return false
	army[id]["count"] = int(army[id]["count"]) - 1
	_pending.append(["troop", id, p.x, p.y])
	return true


func cast_spell(id: String, p: Vector2) -> bool:
	if ended or not spell_stock.has(id) or int(spell_stock[id]["count"]) <= 0:
		return false
	if p.x < 0 or p.y < 0 or p.x >= W or p.y >= W:
		return false
	spell_stock[id]["count"] = int(spell_stock[id]["count"]) - 1
	_pending.append(["spell", id, p.x, p.y])
	return true


func surrender() -> void:
	if not ended:
		_end("surrender")


func troops_left() -> int:
	var n := 0
	for id in army:
		n += int(army[id]["count"])
	return n


func spells_left() -> int:
	var n := 0
	for id in spell_stock:
		n += int(spell_stock[id]["count"])
	return n


# =================================================================== tick
func step() -> void:
	if ended:
		return
	events.clear()
	_target_budget = TARGET_BUDGET
	for cmd in _pending:
		inputs.append([tick, cmd[0], cmd[1], cmd[2], cmd[3]])
		if cmd[0] == "troop":
			_spawn_troop(cmd[1], Vector2(cmd[2], cmd[3]))
		else:
			_spawn_spell(cmd[1], Vector2(cmd[2], cmd[3]))
	_pending.clear()
	var t0 := Time.get_ticks_usec() if profile else 0
	_update_spells()
	var t1 := Time.get_ticks_usec() if profile else 0
	for t in troops:
		if t.alive:
			_update_troop(t)
	_process_paths()
	_build_grid()
	var t2 := Time.get_ticks_usec() if profile else 0
	for b in buildings:
		if b.alive and b.kind == Kind.DEFENSE:
			_update_defense(b)
	var t3 := Time.get_ticks_usec() if profile else 0
	for b in buildings:
		if b.kind == Kind.TRAP and b.armed and b.alive:
			_update_trap(b)
	var t4 := Time.get_ticks_usec() if profile else 0
	_update_projectiles()
	if profile:
		var t5 := Time.get_ticks_usec()
		prof["spells"] += t1 - t0
		prof["troops"] += t2 - t1
		prof["defenses"] += t3 - t2
		prof["traps"] += t4 - t3
		prof["projectiles"] += t5 - t4
	tick += 1
	_check_end()


func run_to_end(max_steps: int = 999999) -> void:
	var s := 0
	while not ended and s < max_steps:
		step()
		s += 1


func _spawn_troop(id: String, p: Vector2) -> void:
	var t := STroop.new()
	t.i = troops.size()
	t.id = id
	t.level = int(army[id]["level"])
	t.d = Balance.troop(id, t.level)
	t.hp = float(t.d["hp"])
	t.max_hp = t.hp
	t.dps = float(t.d["dps"])
	t.speed = float(t.d["speed"])
	t.atk_range = float(t.d["range"])
	t.flying = bool(t.d["flying"])
	t.pref = t.d["preference"]
	t.size = int(t.d["size"])
	t.pos = p
	t.prev_pos = p
	t.anchor = p
	t.hop = id == "rustjaw"
	t.is_mender = id == "mender"
	t.is_warden = id == "ember_warden"
	t.is_kegger = id == "kegger"
	t.is_magpie = id == "magpie"
	t.is_dirigible = id == "dirigible"
	if id == "kegger":
		t.dps = float(t.d.get("blast_damage", 60))
	troops.append(t)
	deployed_any = true
	used_troops[id] = int(used_troops.get(id, 0)) + 1
	events.append({"t": "deploy", "troop": t.i, "id": id})


func _spawn_spell(id: String, p: Vector2) -> void:
	var d := Balance.spell(id, int(spell_stock[id]["level"]))
	spells.append({"id": id, "pos": p, "radius": float(d["radius"]), "end": tick + int(float(d["duration_s"]) * TICK_RATE), "d": d})
	used_spells[id] = int(used_spells.get(id, 0)) + 1
	events.append({"t": "spell", "id": id, "pos": p})


# =============================================================== incantesimi
func _update_spells() -> void:
	for t in troops:
		t.buff_dmg = 0.0
		t.buff_speed = 0.0
	for s in spells:
		if tick >= int(s["end"]):
			continue
		var pos: Vector2 = s["pos"]
		var r: float = s["radius"]
		for t in troops:
			if not t.alive or t.pos.distance_to(pos) > r:
				continue
			if s["id"] == "mending_mist":
				_heal(t, float(s["d"]["heal_per_s"]) * DT)
			else:
				t.buff_dmg = maxf(t.buff_dmg, float(s["d"]["damage_bonus"]))
				t.buff_speed = maxf(t.buff_speed, float(s["d"]["speed_bonus"]))


func _heal(t: STroop, amount: float) -> void:
	t.hp = minf(t.max_hp, t.hp + amount)


# ================================================================== truppe
func _update_troop(t: STroop) -> void:
	t.prev_pos = t.pos
	if tick < t.frozen_until:
		return
	# abilita' dell'elite
	if t.is_warden and not t.surge_used and t.hp < t.max_hp * 0.5:
		t.surge_used = true
		t.surge_until = tick + 4 * TICK_RATE
		t.heal_left = t.max_hp * 0.25
		events.append({"t": "surge", "troop": t.i})
	if tick < t.surge_until:
		var h := t.heal_left / float(maxi(1, t.surge_until - tick))
		_heal(t, h)
		t.heal_left -= h
	if t.is_mender:
		_update_mender(t)
		return
	# bersaglio
	if t.target < 0 or not buildings[t.target].alive:
		if _target_budget <= 0:
			return
		_target_budget -= 1
		_choose_target(t)
		if t.target < 0:
			t.attacking = false
			return
	var tb := buildings[t.target]
	# muro lungo il percorso ancora in piedi?
	if t.wall_target >= 0 and not buildings[t.wall_target].alive:
		t.wall_target = -1
	var reach := t.atk_range + 0.35
	if t.wall_target >= 0:
		var wb := buildings[t.wall_target]
		if Pathfinder.dist_to_rect(t.pos, wb.rect) <= reach + 0.15:
			_attack(t, wb)
			return
	if Pathfinder.dist_to_rect(t.pos, tb.rect) <= reach:
		_attack(t, tb)
		return
	t.attacking = false
	_move(t, tb, reach)


func _speed(t: STroop) -> float:
	var s := t.speed * (1.0 + t.buff_speed)
	if tick < t.slow_until:
		s *= (1.0 - t.slow_frac)
	return s


func _move(t: STroop, tb: SBuilding, reach: float) -> void:
	var step_len := _speed(t) * DT
	if t.flying:
		var aim := _nearest_point(tb.rect, t.pos)
		_step_towards(t, aim, step_len)
		return
	if t.need_path:
		if not _try_cached_path(t, tb, reach):
			# in coda per A* incrementale: intanto si avvicina in linea retta senza entrare negli edifici
			if not t.path_pending:
				t.path_pending = true
				_path_queue.append(t.i)
			_step_safe(t, _nearest_point(tb.rect, t.pos), step_len)
			_track_stuck(t)
			return
	if t.path_i >= t.path.size():
		# percorso esaurito ma non a portata (percorso parziale o bersaglio irraggiungibile): ricalcola
		t.need_path = true
		_step_safe(t, _nearest_point(tb.rect, t.pos), step_len)
		_track_stuck(t)
		return
	var cell: Vector2i = t.path[t.path_i]
	var ci := cell.y * W + cell.x
	# muro sulla strada: abbatterlo (salvo chi salta le mura)
	if cell_w[ci] >= 0 and buildings[cell_w[ci]].alive and not t.hop:
		t.wall_target = cell_w[ci]
		if Pathfinder.dist_to_rect(t.pos, buildings[t.wall_target].rect) <= t.atk_range + 0.5:
			_attack(t, buildings[t.wall_target])
			return
	# edificio comparso sulla strada (non dovrebbe accadere) -> ricalcola
	if cell_b[ci] >= 0 and buildings[cell_b[ci]].alive:
		t.need_path = true
		return
	var wp := Vector2(cell) + Vector2(0.5, 0.5)
	if _step_towards(t, wp, step_len):
		t.path_i += 1
	_track_stuck(t)


func _track_stuck(t: STroop) -> void:
	if t.pos.distance_squared_to(t.prev_pos) < 1e-6 and not t.attacking:
		t.stuck_ticks += 1
		t.max_stuck = maxi(t.max_stuck, t.stuck_ticks)
		if t.stuck_ticks % 30 == 29 and not t.path_pending:
			t.need_path = true
			_path_cache.clear()
			_group_paths.clear()
	else:
		t.stuck_ticks = 0


func _step_towards(t: STroop, aim: Vector2, step_len: float) -> bool:
	var dvec := aim - t.pos
	var dist := dvec.length()
	if dist <= step_len or dist < 1e-4:
		t.pos = aim
		return true
	t.facing = dvec / dist
	t.pos += t.facing * step_len
	return false


func _step_safe(t: STroop, aim: Vector2, step_len: float) -> void:
	## Movimento diretto che non entra nelle celle degli edifici.
	var old := t.pos
	_step_towards(t, aim, step_len)
	var c := Vector2i(int(floor(t.pos.x)), int(floor(t.pos.y)))
	if c.x >= 0 and c.y >= 0 and c.x < W and c.y < W and cell_b[c.y * W + c.x] >= 0:
		t.pos = old


func _nearest_point(r: Rect2, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


func _wall_factor(t: STroop) -> float:
	if t.is_kegger:
		return 0.0005      # va dritto contro le mura
	return t.speed / maxf(1.0, t.dps * (1.0 + t.buff_dmg))


func _path_keys(t: STroop, tb: SBuilding, reach: float) -> Array:
	var start := Vector2i(int(floor(t.pos.x)), int(floor(t.pos.y)))
	var bucket := int(round(log(maxf(1e-4, _wall_factor(t))) * 2.0))
	var hop := 1 if t.hop else 0
	return [start, "%d,%d,%d,%d,%d,%d" % [start.x, start.y, tb.i, bucket, wall_version, hop],
		"%d,%d,%d,%d,%d" % [tb.i, bucket, wall_version, hop, int(reach * 4.0)]]


## Percorso gia' noto (stessa cella di partenza) o riutilizzabile da un altro della stessa squadra.
func _try_cached_path(t: STroop, tb: SBuilding, reach: float) -> bool:
	var keys := _path_keys(t, tb, reach)
	if _path_cache.has(keys[1]):
		_apply_path(t, _path_cache[keys[1]], tb)
		return true
	return _splice(keys[2], keys[0], t)


func _apply_path(t: STroop, res: Dictionary, tb: SBuilding) -> void:
	t.path_pending = false
	t.need_path = false
	t.wall_target = -1
	var path: Array = res["path"]
	# la truppa si e' mossa durante il calcolo: riparte dal punto del percorso piu' vicino (primi 12 passi)
	var here := Vector2i(int(floor(t.pos.x)), int(floor(t.pos.y)))
	var best_k := 0
	var best_d := 1 << 30
	for k in mini(12, path.size()):
		var c: Vector2i = path[k]
		var d := maxi(absi(c.x - here.x), absi(c.y - here.y))
		if d < best_d:
			best_d = d
			best_k = k
	t.path = path.slice(best_k) if best_k > 0 else path
	t.path_i = 0
	if not res["reached"]:
		# irraggiungibile: prendi come bersaglio l'edificio piu' vicino che non sia quello
		var alt := _nearest_kind(t.pos, 0, tb.i)
		if alt >= 0:
			t.target = alt
			t.need_path = true


## Riuso: se la truppa e' adiacente (Chebyshev <= 1, senza attraversare spigoli bloccati) a un percorso gia'
## calcolato verso lo stesso bersaglio con lo stesso profilo di costo, ne segue il tratto restante.
func _splice(gkey: String, start: Vector2i, t: STroop) -> bool:
	if not _group_paths.has(gkey):
		return false
	for path in _group_paths[gkey]:
		for k in path.size():
			var c: Vector2i = path[k]
			var d := c - start
			if absi(d.x) <= 1 and absi(d.y) <= 1:
				if absi(d.x) == 1 and absi(d.y) == 1:
					var a := start.y * W + start.x + d.x
					var b2 := (start.y + d.y) * W + start.x
					if pf.block[a] == 1 or pf.block[b2] == 1:
						continue
				t.path = path.slice(k)
				t.path_i = 0
				t.need_path = false
				t.path_pending = false
				t.wall_target = -1
				return true
	return false


## A* incrementale: serve la coda delle richieste espandendo al massimo EXPANSION_BUDGET nodi per tick.
func _process_paths() -> void:
	var budget := EXPANSION_BUDGET
	var guard := 0
	var ta := Time.get_ticks_usec() if profile else 0
	while budget > 0 and guard < 64:
		guard += 1
		if _search_troop < 0:
			if _path_queue.is_empty():
				break
			var ti: int = _path_queue.pop_front()
			var t := troops[ti]
			t.path_pending = false
			if not t.alive or t.flying or not t.need_path or t.target < 0 or not buildings[t.target].alive:
				continue
			var tb := buildings[t.target]
			var reach := t.atk_range + 0.35
			if _try_cached_path(t, tb, reach):
				continue
			var keys := _path_keys(t, tb, reach)
			_search_troop = ti
			_search_target = tb.i
			_search_key = keys[1]
			_search_gkey = keys[2]
			t.path_pending = true
			if profile:
				prof["astar_calls"] += 1
			if pf.start(keys[0], tb.rect, reach, _wall_factor(t), t.hop):
				_complete_search()
				continue
		var used := pf.run(budget)
		budget -= maxi(1, used)
		if not pf.active:
			_complete_search()
	if profile:
		prof["astar"] += Time.get_ticks_usec() - ta


func _complete_search() -> void:
	var res: Dictionary = pf.result
	_path_cache[_search_key] = res
	if res["reached"] and not res["path"].is_empty() and not res.get("partial", false):
		if not _group_paths.has(_search_gkey):
			_group_paths[_search_gkey] = []
		_group_paths[_search_gkey].append(res["path"])
	var t := troops[_search_troop]
	t.path_pending = false
	if t.alive and t.target == _search_target and t.need_path:
		_apply_path(t, res, buildings[_search_target])
	_search_troop = -1


func _choose_target(t: STroop) -> void:
	t.target = -1
	t.wall_target = -1
	t.need_path = true
	match t.pref:
		"defenses":
			t.target = _nearest_kind(t.pos, 1)
		"resources":
			t.target = _nearest_kind(t.pos, 2)
		"walls":
			_choose_wall_target(t)
			if t.target >= 0:
				return
	if t.target < 0:
		t.target = _nearest_kind(t.pos, 0)


func _choose_wall_target(t: STroop) -> void:
	## Kegger: il primo muro sulla linea retta verso l'edificio piu' vicino (Bresenham), altrimenti il muro piu' vicino.
	var nb := _nearest_kind(t.pos, 0)
	if nb < 0:
		return
	var x0 := int(floor(t.pos.x))
	var y0 := int(floor(t.pos.y))
	var c1 := buildings[nb].center
	var x1 := int(floor(c1.x))
	var y1 := int(floor(c1.y))
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	for i in 128:
		if x0 >= 0 and y0 >= 0 and x0 < W and y0 < W:
			var wi := cell_w[y0 * W + x0]
			if wi >= 0 and buildings[wi].alive:
				t.target = wi
				return
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	t.target = _nearest_kind(t.pos, 3)
	if t.target < 0:
		t.target = nb


func _nearest_building(p: Vector2, filt: Callable) -> int:
	var best := -1
	var bd := INF
	for b in buildings:
		if not b.alive or not filt.call(b):
			continue
		var d := Pathfinder.dist_to_rect(p, b.rect)
		if d < bd - 1e-6:
			bd = d
			best = b.i
	return best


## Versione veloce per i casi comuni. mode: 0 = qualunque edificio (non muro/trappola), 1 = difese,
## 2 = risorse, 3 = mura. `exclude` = indice da ignorare.
func _nearest_kind(p: Vector2, mode: int, exclude: int = -1) -> int:
	var best := -1
	var bd := INF
	for b in buildings:
		if not b.alive or b.i == exclude:
			continue
		match mode:
			0:
				if b.kind == Kind.WALL or b.kind == Kind.TRAP:
					continue
			1:
				if b.kind != Kind.DEFENSE:
					continue
			2:
				if b.kind != Kind.RESOURCE:
					continue
			3:
				if b.kind != Kind.WALL:
					continue
		var dx := maxf(maxf(b.rect.position.x - p.x, 0.0), p.x - b.rect.end.x)
		var dy := maxf(maxf(b.rect.position.y - p.y, 0.0), p.y - b.rect.end.y)
		var d := dx * dx + dy * dy
		if d < bd - 1e-9:
			bd = d
			best = b.i
	return best


func _attack(t: STroop, b: SBuilding) -> void:
	t.attacking = true
	t.stuck_ticks = 0
	var c := b.center - t.pos
	if c.length() > 0.01:
		t.facing = c.normalized()
	t.cooldown -= DT
	if t.cooldown > 0.0:
		return
	t.cooldown = 1.0
	if t.is_kegger:
		_kegger_blast(t)
		return
	var mult := 1.0 + t.buff_dmg
	if tick < t.surge_until:
		mult += 0.5
	if t.is_magpie and b.kind == Kind.RESOURCE:
		mult *= 2.0
	if t.hop and b.kind == Kind.DEFENSE:
		mult *= 1.5
	var dmg := t.dps * mult
	if t.is_dirigible:
		for o in buildings:
			if o.alive and o.cat != "trap" and Pathfinder.dist_to_rect(b.center, o.rect) <= 1.5:
				_damage_building(o, dmg if o == b else dmg * 0.6, t.i)
	else:
		_damage_building(b, dmg, t.i)
	events.append({"t": "hit", "troop": t.i, "b": b.i})


func _kegger_blast(t: STroop) -> void:
	var dmg := t.dps
	for o in buildings:
		if not o.alive or o.cat == "trap":
			continue
		if Pathfinder.dist_to_rect(t.pos, o.rect) <= 1.2:
			_damage_building(o, dmg * (40.0 if o.cat == "wall" else 1.0), t.i)
	events.append({"t": "blast", "troop": t.i, "pos": t.pos})
	_kill_troop(t)


func _update_mender(t: STroop) -> void:
	# segue l'alleato di terra piu' ferito (o il piu' vicino), cura in area le truppe di terra
	var best := -1
	var score := INF
	for o in troops:
		if not o.alive or o.flying:
			continue
		var s := (o.hp / o.max_hp) * 10.0 + o.pos.distance_to(t.pos) * 0.05
		if s < score:
			score = s
			best = o.i
	t.ally = best
	if best >= 0:
		var aim := troops[best].pos + Vector2(-0.6, -0.6)
		if t.pos.distance_to(aim) > 1.0:
			_step_towards(t, aim, _speed(t) * DT)
	var heal := float(t.d.get("heal_per_s", 40)) * DT
	var healed := false
	for o in troops:
		if o.alive and not o.flying and o.hp < o.max_hp and o.pos.distance_to(t.pos) <= 3.0:
			_heal(o, heal)
			healed = true
	t.attacking = healed


# ================================================================= edifici
func _damage_building(b: SBuilding, dmg: float, by: int) -> void:
	if not b.alive or dmg <= 0.0:
		return
	var before := b.hp
	b.hp = maxf(0.0, b.hp - dmg)
	if b.cat == "wall":
		pf.wall[b.y * W + b.x] = b.hp
	# bottino rilasciato in proporzione al danno
	for r in b.loot:
		var frac := (b.max_hp - b.hp) / b.max_hp
		var due := float(b.loot[r]) * frac
		var give := due - float(b.looted[r])
		if give > 0.0:
			b.looted[r] = due
			loot_taken[r] = float(loot_taken[r]) + give
	if b.hp <= 0.0 and before > 0.0:
		_destroy(b)


func _destroy(b: SBuilding) -> void:
	b.alive = false
	if b.cat == "wall":
		cell_w[b.y * W + b.x] = -1
		pf.wall[b.y * W + b.x] = 0.0
		walls_destroyed += 1
	else:
		for dx in b.n:
			for dy in b.n:
				cell_b[(b.y + dy) * W + b.x + dx] = -1
		pf.set_block_rect(b.x, b.y, b.n, 0)
	wall_version += 1
	_path_cache.clear()
	_group_paths.clear()
	if b.counts:
		destroyed_counted += 1
	if b.cat == "defense":
		defenses_destroyed += 1
	if b.id == "lantern_hall":
		hall_destroyed = true
	events.append({"t": "destroyed", "b": b.i})
	# chi stava abbattendo quel muro / attaccando quell'edificio riparte
	for t in troops:
		if t.alive and (t.target == b.i or t.wall_target == b.i):
			if t.wall_target == b.i:
				t.wall_target = -1
			else:
				t.target = -1


# ================================================================== difese
func _in_range(b: SBuilding, t: STroop) -> bool:
	var d2 := t.pos.distance_squared_to(b.center)
	return d2 <= b.rmax2 and d2 >= b.rmin2


func _can_target(b: SBuilding, t: STroop) -> bool:
	return b.t_air if t.flying else b.t_ground


func _build_grid() -> void:
	_gh.fill(-1)
	if _gn.size() < troops.size():
		_gn.resize(troops.size() + 64)
	for t in troops:
		if not t.alive:
			continue
		var cx := clampi(int(t.pos.x), 0, W - 1)
		var cy := clampi(int(t.pos.y), 0, W - 1)
		var ci := cy * W + cx
		_gn[t.i] = _gh[ci]
		_gh[ci] = t.i


## Numero di truppe (stesso tipo di volo) entro `r` celle da `p`, usando la griglia spaziale.
func _count_near(p: Vector2, r: float, flying: bool) -> int:
	var cnt := 0
	var r2 := r * r
	var x0 := maxi(0, int(p.x - r))
	var x1 := mini(W - 1, int(p.x + r))
	var y0 := maxi(0, int(p.y - r))
	var y1 := mini(W - 1, int(p.y + r))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var j := _gh[y * W + x]
			while j >= 0:
				var o := troops[j]
				if o.flying == flying and o.pos.distance_squared_to(p) <= r2:
					cnt += 1
				j = _gn[j]
	return cnt


func _update_defense(b: SBuilding) -> void:
	b.cooldown -= DT
	b.retarget -= 1
	var ok := false
	if b.target >= 0:
		var tt := troops[b.target]
		ok = tt.alive and _in_range(b, tt) and _can_target(b, tt)
	if b.retarget <= 0 and (not ok or b.prio == Prio.NEAREST):
		b.target = _pick_defense_target(b)
		# senza bersagli a portata si ricontrolla ogni 0,1 s invece che a ogni tick
		b.retarget = RETARGET_DEF_TICKS if b.target >= 0 else 3
	elif not ok:
		b.target = -1
	if b.target < 0 or b.cooldown > 0.0:
		return
	b.cooldown = b.interval
	_fire(b, troops[b.target])


func _pick_defense_target(b: SBuilding) -> int:
	var splash := maxf(1.2, b.splash)
	var best := -1
	var best_score := -INF
	var taunt_r := sqrt(b.rmax2) + 3.0
	var taunt_r2 := taunt_r * taunt_r
	for t in troops:
		if not t.alive or not _can_target(b, t):
			continue
		var d2 := t.pos.distance_squared_to(b.center)
		if d2 > b.rmax2 or d2 < b.rmin2:
			continue
		var s := -d2
		if t.id == "bulwark" and d2 <= taunt_r2:
			s = 1e6 - d2           # provocazione
		else:
			match b.prio:
				Prio.CLUSTER:
					s = _count_near(t.pos, splash, t.flying) * 1000.0 - d2 * 0.01
				Prio.LOWEST_HP:
					s = -t.hp - d2 * 0.001
				Prio.FARTHEST:
					s = d2
				Prio.HIGHEST_HP:
					s = t.hp - d2 * 0.001
		if s > best_score + 1e-9:
			best_score = s
			best = t.i
	return best


func _fire(b: SBuilding, t: STroop) -> void:
	var dmg := b.dmg
	var splash := b.splash
	events.append({"t": "fire", "b": b.i, "troop": t.i, "id": b.id})
	if b.id in INSTANT:
		match b.id:
			"arc_coil":
				var hit: Array = [t.i]
				var cur := t
				var k := 1.0
				_damage_troop(cur, dmg, b.i)
				for j in int(b.d.get("chain_targets", 3)) - 1:
					k *= 1.0 - float(b.d.get("chain_falloff", 0.25))
					var nxt: STroop = null
					var nd := 3.0
					for o in troops:
						if o.alive and not o.flying and not (o.i in hit) and o.pos.distance_to(cur.pos) <= nd:
							nd = o.pos.distance_to(cur.pos)
							nxt = o
					if nxt == null:
						break
					hit.append(nxt.i)
					events.append({"t": "chain", "from": cur.i, "to": nxt.i})
					_damage_troop(nxt, dmg * k, b.i)
					cur = nxt
			"frost_spire":
				for o in troops:
					if o.alive and _can_target(b, o) and o.pos.distance_to(t.pos) <= splash:
						_damage_troop(o, dmg, b.i)
						o.slow_until = tick + int(float(b.d.get("slow_seconds", 2.0)) * TICK_RATE)
						o.slow_frac = float(b.d.get("slow_fraction", 0.3))
				events.append({"t": "frost", "pos": t.pos})
			_:
				_damage_troop(t, dmg, b.i)
		return
	var p := SProj.new()
	p.kind = b.id
	p.from = b.i
	p.target = t.i
	p.start = b.center
	p.aim = t.pos
	p.damage = dmg
	p.splash = splash
	p.air = b.t_air
	p.ground = b.t_ground
	var spd: float = PROJ_SPEED.get(b.id, 15.0)
	p.start_tick = tick
	p.impact_tick = tick + maxi(1, int(ceil(b.center.distance_to(t.pos) / spd * TICK_RATE)))
	projectiles.append(p)


func _update_projectiles() -> void:
	var keep: Array[SProj] = []
	for p in projectiles:
		if tick < p.impact_tick:
			keep.append(p)
			continue
		var tgt := troops[p.target]
		if p.splash > 0.0:
			# i mortai colpiscono il punto mirato; le altre armi ad area seguono il bersaglio
			var at := p.aim if p.kind == "lobber" else tgt.pos
			for o in troops:
				if not o.alive:
					continue
				if (o.flying and not p.air) or (not o.flying and not p.ground):
					continue
				if o.pos.distance_to(at) <= p.splash:
					_damage_troop(o, p.damage, p.from)
			events.append({"t": "impact", "pos": at, "kind": p.kind})
		elif tgt.alive:
			_damage_troop(tgt, p.damage, p.from)
			events.append({"t": "impact", "pos": tgt.pos, "kind": p.kind})
	projectiles = keep


func _damage_troop(t: STroop, dmg: float, by: int) -> void:
	if not t.alive:
		return
	t.hp -= dmg
	if t.hp <= 0.0:
		_kill_troop(t)


func _kill_troop(t: STroop) -> void:
	if not t.alive:
		return
	t.alive = false
	t.hp = 0.0
	t.attacking = false
	events.append({"t": "death", "troop": t.i})


# ================================================================= trappole
func _update_trap(b: SBuilding) -> void:
	if _count_near(b.center, sqrt(b.trig2), b.trap_air) == 0:
		return
	var air := b.trap_air
	b.armed = false
	b.alive = false
	var r := b.eff_r
	events.append({"t": "trap", "b": b.i, "id": b.id})
	match b.id:
		"bomb_trap", "air_mine":
			for t in troops:
				if t.alive and t.flying == air and t.pos.distance_to(b.center) <= r + 0.5:
					_damage_troop(t, float(b.d["damage"]) * _dmg_mult, b.i)
		"spring_pad":
			var cap := int(b.d["launch_max_space"])
			for t in troops:
				if t.alive and not t.flying and t.pos.distance_to(b.center) <= r + 0.6 and t.size <= cap:
					cap -= t.size
					events.append({"t": "launched", "troop": t.i})
					_kill_troop(t)
		"snare_trap":
			for t in troops:
				if t.alive and not t.flying and t.pos.distance_to(b.center) <= r:
					t.frozen_until = tick + int(float(b.d["freeze_seconds"]) * TICK_RATE)


# ===================================================================== fine
func percent() -> int:
	return Formulas.destruction_percent(destroyed_counted, total_counted)


func stars() -> int:
	return Formulas.stars(float(percent()), hall_destroyed, float(Balance.economy["battle"]["star_percent"]))


func alive_troops() -> int:
	var n := 0
	for t in troops:
		if t.alive:
			n += 1
	return n


func _check_end() -> void:
	if ended:
		return
	if percent() >= 100:
		_end("destroyed")
	elif tick >= max_ticks:
		_end("time")
	elif deployed_any and alive_troops() == 0 and troops_left() == 0 and _pending.is_empty():
		_end("no_troops")


func _end(reason: String) -> void:
	ended = true
	end_reason = reason
	events.append({"t": "end", "reason": reason})


func result() -> Dictionary:
	var max_stuck := 0
	for t in troops:
		max_stuck = maxi(max_stuck, t.max_stuck)
	return {
		"stars": stars(), "percent": percent(), "hall_destroyed": hall_destroyed,
		"loot": {"cogs": floorf(loot_taken["cogs"]), "sap": floorf(loot_taken["sap"]), "shards": floorf(loot_taken["shards"])},
		"ticks": tick, "reason": end_reason, "troops_used": used_troops, "spells_used": used_spells,
		"defenses_destroyed": defenses_destroyed, "walls_destroyed": walls_destroyed, "max_stuck_ticks": max_stuck,
	}


## Dati sufficienti per riprodurre la battaglia (replay deterministico).
func replay_data() -> Dictionary:
	return {"base": base_info, "army": army_info, "seed": seed, "inputs": inputs.duplicate(true), "version": 1}


## Firma dello stato (per verificare il determinismo nei test).
func state_hash() -> int:
	var parts: Array = [tick, destroyed_counted, int(loot_taken["cogs"]), int(loot_taken["sap"])]
	for t in troops:
		parts.append(snappedf(t.pos.x, 0.0001))
		parts.append(snappedf(t.pos.y, 0.0001))
		parts.append(snappedf(t.hp, 0.01))
	for b in buildings:
		parts.append(snappedf(b.hp, 0.01))
	return hash(str(parts))
