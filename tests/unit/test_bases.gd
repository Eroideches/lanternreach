extends GutTest
## Basi procedurali e campagna: validita' dei layout (niente sovrapposizioni, limiti per Hall, connettivita').


func _check_layout(base: Dictionary, hall: int) -> void:
	var occ := {}
	var counts := {}
	for b in base["buildings"]:
		var n := Balance.footprint(b["id"])
		assert_true(int(b["x"]) >= 2 and int(b["y"]) >= 2 and int(b["x"]) + n - 1 <= 41 and int(b["y"]) + n - 1 <= 41, "%s dentro l'area" % b["id"])
		for dx in n:
			for dy in n:
				var c := Vector2i(int(b["x"]) + dx, int(b["y"]) + dy)
				assert_false(occ.has(c), "sovrapposizione in %s" % c)
				occ[c] = true
		counts[b["id"]] = int(counts.get(b["id"], 0)) + 1
		assert_true(int(b["level"]) >= 1)
		if b["id"] != "lantern_hall":
			assert_true(int(b["level"]) <= Balance.max_level_at_hall(b["id"], hall), "%s livello consentito" % b["id"])
	assert_eq(int(counts.get("lantern_hall", 0)), 1)
	for id in counts:
		if id != "lantern_hall":
			assert_true(int(counts[id]) <= Balance.count_allowed(id, hall), "%s x%d <= limite a Hall %d" % [id, counts[id], hall])


func test_generated_bases_all_halls() -> void:
	for hall in range(1, 11):
		for s in 3:
			var base := BaseGenerator.generate(hall, 1000 * hall + s)
			assert_false(base.is_empty(), "Hall %d generata" % hall)
			_check_layout(base, hall)


func test_generated_base_has_defenses_and_walls() -> void:
	var base := BaseGenerator.generate(7, 4242)
	var defs := 0
	var walls := 0
	for b in base["buildings"]:
		if Balance.is_defense(b["id"]):
			defs += 1
		elif b["id"] == "wall":
			walls += 1
	var expected := 0
	for id in Balance.defense_order:
		expected += Balance.count_allowed(id, 7)
	assert_gt(defs, expected * 0.8, "quasi tutte le difese piazzate")
	assert_gt(walls, 50)


func test_generation_is_deterministic() -> void:
	var a := BaseGenerator.generate(6, 777)
	var b := BaseGenerator.generate(6, 777)
	assert_eq(JSON.stringify(a), JSON.stringify(b))


func test_campaign_levels() -> void:
	assert_eq(Balance.campaign.size(), 25)
	for n in range(1, 26):
		var lv := Balance.campaign_level(n)
		var base := CampaignData.load_level(n)
		_check_layout(base, int(lv["hall_level"]))
		var defs := {}
		for b in base["buildings"]:
			if Balance.is_defense(b["id"]):
				defs[b["id"]] = int(defs.get(b["id"], 0)) + 1
		for id in Balance.defense_order:
			assert_eq(int(defs.get(id, 0)), int(lv[id]), "livello %d: %s come da GDD" % [n, id])


func test_loot_respects_caps() -> void:
	var rng := RandomNumberGenerator.new()
	for hall in range(1, 11):
		rng.seed = hall
		var loot := BaseGenerator.loot_for(hall, rng, hall)
		assert_true(float(loot["cogs"]) <= float(Balance.economy["loot"]["cap_by_hall"][hall - 1]) * 1.2 + 1)
		assert_true(float(loot["cogs"]) >= 0.0)
