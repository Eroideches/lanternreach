extends GutTest
## Formule pure: accelerazione, acquisto risorse, stelle, percentuale, trofei, bottino, scudo.


func test_speedup_cost_points() -> void:
	var pts: Array = Balance.economy["speedup_points"]
	assert_eq(Formulas.speedup_cost(0, pts), 0, "0 s = gratis")
	assert_eq(Formulas.speedup_cost(1, pts), 1, "minimo 1 gemma")
	assert_eq(Formulas.speedup_cost(60, pts), 1)
	assert_eq(Formulas.speedup_cost(3600, pts), 20)
	assert_eq(Formulas.speedup_cost(86400, pts), 260)
	assert_eq(Formulas.speedup_cost(259200, pts), 650)
	# interpolazione lineare tra (1 h, 20) e (24 h, 260): 12 h -> 134,8 -> 135
	assert_eq(Formulas.speedup_cost(43200, pts), 135)
	# monotona crescente
	var prev := 0
	for s in [10, 100, 1000, 10000, 100000, 500000]:
		var c := Formulas.speedup_cost(s, pts)
		assert_true(c >= prev, "monotona a %d s" % s)
		prev = c


func test_resource_gem_cost() -> void:
	var pts: Array = Balance.economy["resource_to_gem_points"]
	assert_eq(Formulas.resource_gem_cost(0, pts), 0)
	assert_eq(Formulas.resource_gem_cost(100, pts), 1)
	assert_eq(Formulas.resource_gem_cost(1000, pts), 5)
	assert_eq(Formulas.resource_gem_cost(100000, pts), 125)


func test_stars() -> void:
	assert_eq(Formulas.stars(0, false), 0)
	assert_eq(Formulas.stars(49, false), 0)
	assert_eq(Formulas.stars(50, false), 1)
	assert_eq(Formulas.stars(30, true), 1, "solo Hall distrutta")
	assert_eq(Formulas.stars(75, true), 2)
	assert_eq(Formulas.stars(100, true), 3)
	assert_eq(Formulas.stars(100, false), 2, "100% senza Hall non e' possibile in pratica, ma la formula e' additiva")


func test_destruction_percent_floors() -> void:
	assert_eq(Formulas.destruction_percent(0, 10), 0)
	assert_eq(Formulas.destruction_percent(1, 3), 33)
	assert_eq(Formulas.destruction_percent(2, 3), 66)
	assert_eq(Formulas.destruction_percent(3, 3), 100)
	assert_eq(Formulas.destruction_percent(5, 0), 0)


func test_trophy_delta() -> void:
	var cfg: Dictionary = Balance.economy["trophies"]
	assert_eq(Formulas.trophy_delta(3, 1000, 1000, cfg), 40)
	assert_eq(Formulas.trophy_delta(1, 1000, 1000, cfg), 20)
	assert_eq(Formulas.trophy_delta(0, 1000, 1000, cfg), -25)
	# avversario piu' forte: piu' trofei in caso di vittoria, meno persi in sconfitta
	assert_gt(Formulas.trophy_delta(2, 1000, 1400, cfg), Formulas.trophy_delta(2, 1000, 1000, cfg))
	assert_gt(Formulas.trophy_delta(0, 1000, 1400, cfg), Formulas.trophy_delta(0, 1000, 1000, cfg))
	# clamp a +-50%
	assert_eq(Formulas.trophy_delta(3, 0, 5000, cfg), 60)


func test_loot_modifiers_and_caps() -> void:
	var loot: Dictionary = Balance.economy["loot"]
	assert_almost_eq(Formulas.loot_hall_modifier(5, 5, loot["hall_diff_modifier"]), 1.0, 0.0001)
	assert_almost_eq(Formulas.loot_hall_modifier(2, 8, loot["hall_diff_modifier"]), 0.5, 0.0001, "clamp a -3")
	assert_almost_eq(Formulas.storage_lootable(1000.0, 1, loot["pct_stored_by_hall"]), 500.0, 0.001)
	assert_almost_eq(Formulas.cap_loot(1e9, 1, loot["cap_by_hall"]), 500.0, 0.001)


func test_shield_seconds() -> void:
	var th: Array = Balance.economy["shield"]["thresholds"]
	assert_eq(Formulas.shield_seconds(10, th), 0.0)
	assert_eq(Formulas.shield_seconds(40, th), 28800.0)
	assert_eq(Formulas.shield_seconds(80, th), 43200.0)
	assert_eq(Formulas.shield_seconds(100, th), 57600.0)
