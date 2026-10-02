extends SceneTree
## Valuta un livello di campagna con N Cogling L1 (diagnostica bilanciamento del tutorial).
var _done := false
func _process(_d):
	if _done: return false
	_done = true
	var CD = load("res://scripts/core/campaign_data.gd")
	var Sim = load("res://scripts/core/battle_sim.gd")
	var AI = load("res://scripts/core/battle_ai.gd")
	for level in [1, 2, 3]:
		for n in [5, 8, 10, 15]:
			var tot := 0
			var stars := []
			for seed in 5:
				var sim = Sim.new()
				sim.setup(CD.load_level(level), {"troops": {"cogling": {"count": n, "level": 1}}, "spells": {}}, seed)
				var rng := RandomNumberGenerator.new()
				rng.seed = seed
				var r = AI.autoplay(sim, rng)
				stars.append(r["stars"])
			print("livello %d, %d cogling: stelle %s" % [level, n, str(stars)])
	quit()
	return true
