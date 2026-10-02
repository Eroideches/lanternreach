extends GutTest
## A* su griglia: percorso libero, aggiramento degli edifici, scelta tra aggirare o abbattere le mura,
## niente taglio degli spigoli, obiettivo irraggiungibile, rispetto del raggio d'attacco.


func _pf() -> Pathfinder:
	return Pathfinder.new(44)


func test_straight_path() -> void:
	var pf := _pf()
	var r := pf.find_path(Vector2i(2, 10), Rect2(20, 10, 2, 2), 0.95, 0.1)
	assert_true(r["reached"])
	var last: Vector2i = r["path"].back()
	assert_true(Pathfinder.dist_to_rect(Vector2(last) + Vector2(0.5, 0.5), Rect2(20, 10, 2, 2)) <= 0.95)
	assert_eq(r["path"].size(), 17, "da x=2 a x=19 in linea retta")


func test_already_in_range() -> void:
	var r := _pf().find_path(Vector2i(19, 10), Rect2(20, 10, 2, 2), 0.95, 0.1)
	assert_true(r["reached"])
	assert_eq(r["path"].size(), 0)


func test_goes_around_buildings() -> void:
	var pf := _pf()
	# muro di edifici verticale da y=0 a y=30 in x=10 (non attraversabile)
	for y in 31:
		pf.block[y * 44 + 10] = 1
	var r := pf.find_path(Vector2i(5, 5), Rect2(20, 5, 2, 2), 0.95, 0.1)
	assert_true(r["reached"])
	for c in r["path"]:
		assert_false(pf.block[c.y * 44 + c.x] == 1, "nessuna cella occupata da edifici nel percorso")
	var max_y := 0
	for c in r["path"]:
		max_y = maxi(max_y, c.y)
	assert_true(max_y >= 31, "aggira dal basso")


func test_weak_wall_is_broken_strong_wall_is_avoided() -> void:
	var pf := _pf()
	# linea di mura da y=0 a y=43 in x=10 con un varco a y=40
	for y in 44:
		if y != 40:
			pf.wall[y * 44 + 10] = 300.0
	# truppa forte: wall_factor basso -> attraversa
	var strong := pf.find_path(Vector2i(5, 5), Rect2(20, 5, 2, 2), 0.95, 0.002)
	var crosses := false
	for c in strong["path"]:
		if pf.wall[c.y * 44 + c.x] > 0.0:
			crosses = true
	assert_true(crosses, "per chi abbatte in fretta conviene attraversare il muro")
	# truppa debole: wall_factor alto -> passa dal varco
	var weak := pf.find_path(Vector2i(5, 5), Rect2(20, 5, 2, 2), 0.95, 1.0)
	var crosses2 := false
	for c in weak["path"]:
		if pf.wall[c.y * 44 + c.x] > 0.0:
			crosses2 = true
	assert_false(crosses2, "per chi abbatte lentamente conviene aggirare dal varco")


func test_hop_walls_ignores_wall_cost() -> void:
	var pf := _pf()
	for y in 44:
		pf.wall[y * 44 + 10] = 99999.0
	var r := pf.find_path(Vector2i(5, 5), Rect2(20, 5, 2, 2), 0.95, 1.0, true)
	assert_eq(r["path"].size(), 14, "salta il muro in linea retta")


func test_no_corner_cutting() -> void:
	var pf := _pf()
	# due edifici a contatto in diagonale: (10,10) e (11,9)? blocchiamo (11,10) e (10,11)
	pf.block[10 * 44 + 11] = 1
	pf.block[11 * 44 + 10] = 1
	var r := pf.find_path(Vector2i(10, 10), Rect2(11, 11, 1, 1), 0.2, 0.1)
	assert_true(r["reached"])
	for i in r["path"].size():
		var c: Vector2i = r["path"][i]
		var prev: Vector2i = Vector2i(10, 10) if i == 0 else r["path"][i - 1]
		var d := c - prev
		if absi(d.x) == 1 and absi(d.y) == 1:
			assert_false(pf.block[prev.y * 44 + c.x] == 1 or pf.block[c.y * 44 + prev.x] == 1, "diagonale tra due celle bloccate")


func test_unreachable_target() -> void:
	var pf := _pf()
	# bersaglio chiuso da edifici su tutti i lati con raggio di mischia
	for x in range(18, 25):
		for y in range(18, 25):
			if x == 18 or y == 18 or x == 24 or y == 24:
				pf.block[y * 44 + x] = 1
	var r := pf.find_path(Vector2i(2, 2), Rect2(21, 21, 1, 1), 0.95, 0.1)
	assert_false(r["reached"])


func test_ranged_reach_stops_early() -> void:
	var r := _pf().find_path(Vector2i(2, 10), Rect2(20, 10, 2, 2), 5.35, 0.1)
	assert_true(r["reached"])
	assert_lt(r["path"].size(), 14, "la truppa a distanza si ferma prima")
