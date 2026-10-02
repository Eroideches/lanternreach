class_name Formulas
extends RefCounted
## Formule di gioco pure (senza stato), documentate nel GDD. Tutti i parametri da Balance.economy.


## Interpolazione lineare a tratti su punti [[x, y], ...] ordinati per x.
static func piecewise(points: Array, x: float) -> float:
	if points.is_empty():
		return 0.0
	if x <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var x0 := float(points[i - 1][0])
		var x1 := float(points[i][0])
		if x <= x1:
			var t := (x - x0) / maxf(1e-9, x1 - x0)
			return lerpf(float(points[i - 1][1]), float(points[i][1]), t)
	# oltre l'ultimo punto: estrapola con l'ultima pendenza
	var n := points.size()
	var xa := float(points[n - 2][0])
	var xb := float(points[n - 1][0])
	var ya := float(points[n - 2][1])
	var yb := float(points[n - 1][1])
	return yb + (x - xb) * (yb - ya) / maxf(1e-9, xb - xa)


## Glimmers per accelerare `seconds` secondi residui (GDD §4.3).
static func speedup_cost(seconds: float, points: Array) -> int:
	if seconds <= 0.0:
		return 0
	return maxi(1, int(ceil(piecewise(points, seconds))))


## Glimmers per acquistare `amount` risorse mancanti.
static func resource_gem_cost(amount: float, points: Array) -> int:
	if amount <= 0.0:
		return 0
	return maxi(1, int(ceil(piecewise(points, amount))))


## Stelle: 1 al 50%, 1 per l'Edificio Centrale distrutto, 1 al 100% (GDD §9.5).
static func stars(percent: float, hall_destroyed: bool, star_percent: float = 0.5) -> int:
	var s := 0
	if percent >= star_percent * 100.0 - 1e-6:
		s += 1
	if hall_destroyed:
		s += 1
	if percent >= 100.0 - 1e-6:
		s += 1
	return s


## Percentuale di distruzione (intera, per difetto) da edifici distrutti/totali (mura e trappole escluse).
static func destruction_percent(destroyed: int, total: int) -> int:
	if total <= 0:
		return 0
	return int(floor(100.0 * float(destroyed) / float(total) + 1e-9))


## Variazione trofei (GDD §9.6).
static func trophy_delta(stars_won: int, own: int, opponent: int, cfg: Dictionary) -> int:
	var scale := float(cfg["diff_scale"])
	var cl := float(cfg["diff_clamp"])
	var diff := clampf(float(opponent - own) / scale, -cl, cl)
	if stars_won <= 0:
		return -int(round(float(cfg["loss_base"]) * (1.0 - diff)))
	return int(round(float(cfg["win_base"][stars_won]) * (1.0 + diff)))


## Modificatore del bottino per differenza di Edificio Centrale (difensore - attaccante).
static func loot_hall_modifier(def_hall: int, att_hall: int, table: Dictionary) -> float:
	var d := clampi(def_hall - att_hall, -3, 3)
	return float(table.get(str(d), 1.0))


## Quantita' saccheggiabile di un deposito (percentuale del contenuto per Hall del difensore).
static func storage_lootable(content: float, def_hall: int, pct_by_hall: Array) -> float:
	return content * float(pct_by_hall[clampi(def_hall, 1, pct_by_hall.size()) - 1])


## Ripartisce un totale disponibile in un tetto per attacco.
static func cap_loot(total: float, def_hall: int, caps: Array) -> float:
	return minf(total, float(caps[clampi(def_hall, 1, caps.size()) - 1]))


## Durata scudo dopo attacco subito.
static func shield_seconds(percent: float, thresholds: Array) -> float:
	var s := 0.0
	for th in thresholds:
		if percent / 100.0 >= float(th[0]) - 1e-6:
			s = float(th[1])
	return s
