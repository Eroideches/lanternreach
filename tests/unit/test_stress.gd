extends GutTest
## Test di simulazione: 100 battaglie automatiche su basi procedurali casuali (Hall 1-10) con eserciti casuali.
## Requisiti: nessun crash, ogni battaglia termina entro 3 minuti di gioco, nessuna truppa bloccata a lungo.

const BATTLES := 100
const MAX_STUCK_TICKS := 5 * 30     ## 5 s fermi senza attaccare = truppa bloccata


func test_100_random_battles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var t0 := Time.get_ticks_msec()
	var worst_stuck := 0
	var worst_case := ""
	var total_ticks := 0
	var stars_hist := [0, 0, 0, 0]
	for i in BATTLES:
		var hall := 1 + i % 10
		var base := BaseGenerator.generate(hall, 5000 + i)
		assert_false(base.is_empty(), "base %d generata" % i)
		base["loot"] = BaseGenerator.loot_for(hall, rng, hall)
		var att := clampi(hall + rng.randi_range(-1, 1), 1, 10)
		var army := BattleAI.random_army(att, rng, rng.randf_range(0.5, 1.0))
		var sim := BattleSim.new()
		sim.setup(base, army, 9000 + i)
		var r := BattleAI.autoplay(sim, rng)
		assert_true(sim.ended, "battaglia %d terminata" % i)
		assert_true(int(r["ticks"]) <= 180 * 30, "battaglia %d entro 3 minuti" % i)
		total_ticks += int(r["ticks"])
		stars_hist[int(r["stars"])] += 1
		if int(r["max_stuck_ticks"]) > worst_stuck:
			worst_stuck = int(r["max_stuck_ticks"])
			worst_case = "battaglia %d (Hall %d)" % [i, hall]
	var ms := Time.get_ticks_msec() - t0
	gut.p("100 battaglie: %d ms, %d tick simulati (%.0f tick/s), stelle 0/1/2/3 = %s, blocco massimo %d tick in %s"
		% [ms, total_ticks, total_ticks / maxf(0.001, ms / 1000.0), str(stars_hist), worst_stuck, worst_case])
	assert_lt(worst_stuck, MAX_STUCK_TICKS, "nessuna truppa bloccata per piu' di 5 s")


func test_performance_150_units() -> void:
	## Prestazione della sola simulazione: 150 truppe contro una base Hall 10.
	var base := BaseGenerator.generate(10, 31337)
	var troops := {"cogling": {"count": 90, "level": 8}, "slingwisp": {"count": 40, "level": 8}, "bulwark": {"count": 10, "level": 8}, "kitewing": {"count": 10, "level": 8}}
	var sim := BattleSim.new()
	sim.setup(base, {"troops": troops, "spells": {}}, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cells: Array = BattleAI._side_cells(sim, rng)
	var k := 0
	for id in troops:
		for n in int(troops[id]["count"]):
			var c: Vector2 = cells[k % cells.size()]
			sim.deploy_troop(id, c + Vector2(0.5, 0.5))
			k += 1
	var t0 := Time.get_ticks_usec()
	var ticks := 0
	while not sim.ended and ticks < 30 * 30:
		sim.step()
		ticks += 1
	var per_tick_ms := (Time.get_ticks_usec() - t0) / 1000.0 / ticks
	gut.p("150 unita': %.2f ms per tick (budget a 30 tick/s: 33 ms)" % per_tick_ms)
	assert_lt(per_tick_ms, 33.0, "la simulazione regge 30 tick/s con 150 unita'")
