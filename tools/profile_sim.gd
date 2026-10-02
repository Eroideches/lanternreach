extends SceneTree
## Profilo della simulazione con 150 unita' contro una base Hall 10 (diagnostica prestazioni).
## Le classi sono caricate a runtime: in modalita' -s gli autoload esistono solo dopo l'avvio.
var _done := false
func _process(_d):
	if _done: return false
	_done = true
	var BG = load("res://scripts/core/base_generator.gd")
	var Sim = load("res://scripts/core/battle_sim.gd")
	var AI = load("res://scripts/core/battle_ai.gd")
	var base = BG.generate(10, 31337)
	var troops := {"cogling": {"count": 90, "level": 8}, "slingwisp": {"count": 40, "level": 8}, "bulwark": {"count": 10, "level": 8}, "kitewing": {"count": 10, "level": 8}}
	var sim = Sim.new()
	sim.setup(base, {"troops": troops, "spells": {}}, 5)
	sim.profile = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cells: Array = AI._side_cells(sim, rng)
	var k := 0
	for id in troops:
		for n in int(troops[id]["count"]):
			sim.deploy_troop(id, cells[k % cells.size()] + Vector2(0.5, 0.5))
			k += 1
	var t0 := Time.get_ticks_usec()
	var ticks := 0
	var worst := 0.0
	var slow: Array = []
	while not sim.ended and ticks < 900:
		var before: Dictionary = sim.prof.duplicate()
		var a := Time.get_ticks_usec()
		sim.step()
		var ms := (Time.get_ticks_usec() - a) / 1000.0
		worst = maxf(worst, ms)
		if ms > 25.0:
			var d := {}
			for k2 in sim.prof:
				d[k2] = (sim.prof[k2] - before[k2]) / (1000.0 if k2 != "astar_calls" else 1.0)
			var ev := {}
			for e in sim.events:
				ev[e["t"]] = int(ev.get(e["t"], 0)) + 1
			slow.append("tick %d: %.1f ms %s eventi %s" % [sim.tick, ms, str(d), str(ev)])
		ticks += 1
	var tot := (Time.get_ticks_usec() - t0) / 1000.0
	print("ticks %d, totale %.0f ms, media %.2f ms/tick, peggiore %.2f ms" % [ticks, tot, tot / ticks, worst])
	for key in sim.prof:
		print("  %s: %s" % [key, str(sim.prof[key] / 1000.0 if key != "astar_calls" else sim.prof[key])])
	print("  truppe vive: %d, distruzione %d%%" % [sim.alive_troops(), sim.percent()])
	for line in slow.slice(0, 12):
		print(line)
	quit()
	return true
