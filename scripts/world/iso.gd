class_name Iso
extends RefCounted
## Proiezione isometrica 2:1. Unita' mondo = pixel degli sprite (cella = 128 x 64).

const HW := 64.0
const HH := 32.0
const GRID := 44


static func to_world(c: Vector2) -> Vector2:
	return Vector2((c.x - c.y) * HW, (c.x + c.y) * HH)


static func to_cell(w: Vector2) -> Vector2:
	return Vector2((w.x / HW + w.y / HH) * 0.5, (w.y / HH - w.x / HW) * 0.5)


static func cell_of(w: Vector2) -> Vector2i:
	var c := to_cell(w)
	return Vector2i(int(floor(c.x)), int(floor(c.y)))


## Centro (mondo) del footprint n x n con angolo in (x, y).
static func footprint_center(x: int, y: int, n: int) -> Vector2:
	return to_world(Vector2(x + n * 0.5, y + n * 0.5))


static func diamond(x: float, y: float, n: float) -> PackedVector2Array:
	return PackedVector2Array([to_world(Vector2(x, y)), to_world(Vector2(x + n, y)), to_world(Vector2(x + n, y + n)), to_world(Vector2(x, y + n))])
