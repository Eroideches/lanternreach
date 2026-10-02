class_name IsoGround
extends Node2D
## Terreno dell'isola: tessere erba, scogliere sui lati SO/SE, griglia/evidenziazioni opzionali.
## Disegnato una sola volta (canvas item statico); `queue_redraw()` solo quando cambia lo stato delle evidenziazioni.

var palette := "player"
var show_grid := false
var deploy_mask: PackedByteArray = PackedByteArray()   ## battaglia: celle schierabili
var show_deploy := false
var highlight_cells: Dictionary = {}                   ## Vector2i -> "valid"/"invalid"


func setup(pal: String) -> void:
	palette = pal
	queue_redraw()


func _draw() -> void:
	var tiles: Array = []
	for v in 4:
		tiles.append(Art.tex("terrain", "%s/grass_%d" % [palette, v]))
	var cl := Art.tex("terrain", palette + "/cliff_L")
	var cr := Art.tex("terrain", palette + "/cliff_R")
	var g := Iso.GRID
	# scogliere sotto il bordo inferiore
	for i in g:
		draw_texture(cl, Iso.to_world(Vector2(i, g - 1)) - Vector2(Iso.HW, 0))
		draw_texture(cr, Iso.to_world(Vector2(g - 1, i)) - Vector2(Iso.HW, 0))
	for x in g:
		for y in g:
			var t: Texture2D = tiles[(x * 7 + y * 13 + (x * y) % 5) % 4]
			var p := Iso.to_world(Vector2(x, y))
			draw_texture(t, p - Vector2(Iso.HW, 0))
	# bordo esterno leggermente piu' scuro (zona sempre schierabile)
	var border := PackedVector2Array([Iso.to_world(Vector2(2, 2)), Iso.to_world(Vector2(42, 2)), Iso.to_world(Vector2(42, 42)), Iso.to_world(Vector2(2, 42)), Iso.to_world(Vector2(2, 2))])
	draw_polyline(border, Color(1, 1, 1, 0.12), 3.0)
	if show_grid:
		var col := Color(1, 1, 1, 0.10)
		for i in range(2, 43):
			draw_line(Iso.to_world(Vector2(i, 2)), Iso.to_world(Vector2(i, 42)), col, 1.5)
			draw_line(Iso.to_world(Vector2(2, i)), Iso.to_world(Vector2(42, i)), col, 1.5)
	if show_deploy and not deploy_mask.is_empty():
		var bad := Art.tex("terrain", "hl/nodeploy")
		for x in g:
			for y in g:
				if deploy_mask[y * g + x] == 0:
					draw_texture(bad, Iso.to_world(Vector2(x, y)) - Vector2(Iso.HW, 0))
	for c in highlight_cells:
		var key: String = "hl/" + str(highlight_cells[c])
		draw_texture(Art.tex("terrain", key), Iso.to_world(Vector2(c)) - Vector2(Iso.HW, 0))
