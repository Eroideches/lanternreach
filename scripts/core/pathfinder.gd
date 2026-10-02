class_name Pathfinder
extends RefCounted
## A* su griglia W x W, 8 direzioni, senza taglio degli spigoli.
## Modello di costo (unita' = tempo per percorrere una cella):
##   cella libera = 1 (diagonale = sqrt 2)
##   cella con muro vivo = 1 + hp_muro * wall_factor, con wall_factor = velocita' / DPS (celle percorribili nel tempo
##   necessario ad abbattere il muro). Se conviene aggirare, A* aggira; altrimenti attraversa (la truppa attacca il muro).
## Le celle occupate da edifici (non mura) non sono attraversabili.
## Obiettivo: qualunque cella il cui centro dista <= `reach` dal rettangolo del bersaglio.
##
## Due modalita':
##   find_path()        ricerca completa sincrona (test, casi rari)
##   start() + run(n)   ricerca INCREMENTALE: espande al massimo n nodi per chiamata, cosi' la simulazione ha un costo
##                      per tick limitato anche quando molte truppe chiedono un percorso insieme.
## Prestazioni: array riusati con "timbro di generazione", heap binario su Packed*Array, nessuna allocazione nel ciclo.

const SQRT2 := 1.41421356
const MAX_EXPANSIONS := 4000        ## oltre: percorso parziale verso il nodo piu' promettente
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

var w: int
var block: PackedByteArray        ## 1 = edificio (non attraversabile)
var wall: PackedFloat32Array      ## hp del muro nella cella (0 = nessun muro)
var expansions_last := 0

# stato della ricerca corrente
var active := false
var result: Dictionary = {}
var _si := 0
var _rx0 := 0.0
var _ry0 := 0.0
var _rx1 := 0.0
var _ry1 := 0.0
var _reach := 0.0
var _reach2 := 0.0
var _wf := 0.0
var _hop := false
var _best_node := 0
var _best_h := INF
var _cap := MAX_EXPANSIONS

var _g := PackedFloat32Array()
var _came := PackedInt32Array()
var _stamp := PackedInt32Array()     ## generazione in cui _g/_came sono validi
var _closed := PackedInt32Array()    ## generazione in cui la cella e' stata chiusa
var _gen := 0
var _hf := PackedFloat32Array()
var _hi := PackedInt32Array()
var _hn := 0


func _init(size: int = 44) -> void:
	w = size
	var n := w * w
	block = PackedByteArray()
	block.resize(n)
	wall = PackedFloat32Array()
	wall.resize(n)
	_g.resize(n)
	_came.resize(n)
	_stamp.resize(n)
	_closed.resize(n)
	_hf.resize(n * 8)
	_hi.resize(n * 8)


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < w


func set_block_rect(x: int, y: int, n: int, v: int) -> void:
	for dx in n:
		for dy in n:
			block[(y + dy) * w + x + dx] = v


static func dist_to_rect(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


## Ricerca completa (sincrona). Ritorna {path: Array[Vector2i] esclusa la partenza, reached: bool, cost, partial}.
func find_path(start_c: Vector2i, target: Rect2, reach: float, wall_factor: float, hop_walls: bool = false) -> Dictionary:
	if not start(start_c, target, reach, wall_factor, hop_walls):
		while active:
			run(1 << 30)
	return result


## Inizia una ricerca. Ritorna true se e' gia' conclusa (risultato in `result`).
func start(start_c: Vector2i, target: Rect2, reach: float, wall_factor: float, hop_walls: bool = false, cap: int = MAX_EXPANSIONS) -> bool:
	expansions_last = 0
	var sx := clampi(start_c.x, 0, w - 1)
	var sy := clampi(start_c.y, 0, w - 1)
	_rx0 = target.position.x
	_ry0 = target.position.y
	_rx1 = target.end.x
	_ry1 = target.end.y
	_reach = reach
	_reach2 = reach * reach
	_wf = wall_factor
	_hop = hop_walls
	_cap = cap
	var cxs := sx + 0.5
	var cys := sy + 0.5
	var ddx := maxf(maxf(_rx0 - cxs, 0.0), cxs - _rx1)
	var ddy := maxf(maxf(_ry0 - cys, 0.0), cys - _ry1)
	if ddx * ddx + ddy * ddy <= _reach2:
		result = {"path": [], "reached": true, "cost": 0.0, "partial": false}
		active = false
		return true
	_gen += 1
	_hn = 0
	_si = sy * w + sx
	_g[_si] = 0.0
	_came[_si] = -1
	_stamp[_si] = _gen
	_best_node = _si
	_best_h = INF
	_push(sqrt(ddx * ddx + ddy * ddy) - reach, _si)
	active = true
	return false


## Espande al massimo `budget` nodi. Ritorna i nodi espansi. A ricerca conclusa: active = false e `result` pronto.
func run(budget: int) -> int:
	if not active:
		return 0
	var gen := _gen
	var used := 0
	while _hn > 0 and used < budget:
		var cur := _pop()
		if _closed[cur] == gen:
			continue
		_closed[cur] = gen
		used += 1
		expansions_last += 1
		var cx := cur % w
		var cy := cur / w
		if cur != _si:
			var px := cx + 0.5
			var py := cy + 0.5
			var ex := maxf(maxf(_rx0 - px, 0.0), px - _rx1)
			var ey := maxf(maxf(_ry0 - py, 0.0), py - _ry1)
			var hh := ex * ex + ey * ey
			if hh <= _reach2:
				_finish(cur, false)
				return used
			if hh < _best_h:
				_best_h = hh
				_best_node = cur
		if expansions_last > _cap:
			_finish(_best_node if _best_node != _si else -1, true)
			return used
		var gcur := _g[cur]
		for k in 8:
			var nx: int = cx + DX[k]
			var ny: int = cy + DY[k]
			if nx < 0 or ny < 0 or nx >= w or ny >= w:
				continue
			var ni := ny * w + nx
			if _closed[ni] == gen or block[ni] == 1:
				continue
			var step := 1.0
			if k >= 4:
				# niente taglio degli spigoli: entrambe le celle ortogonali libere (anche da mura)
				var a := cy * w + nx
				var b := ny * w + cx
				if block[a] == 1 or block[b] == 1 or wall[a] > 0.0 or wall[b] > 0.0:
					continue
				step = SQRT2
			if not _hop and wall[ni] > 0.0:
				step += wall[ni] * _wf
			var ng := gcur + step
			if _stamp[ni] != gen or ng < _g[ni]:
				_stamp[ni] = gen
				_g[ni] = ng
				_came[ni] = cur
				var qx := nx + 0.5
				var qy := ny + 0.5
				var hx := maxf(maxf(_rx0 - qx, 0.0), qx - _rx1)
				var hy := maxf(maxf(_ry0 - qy, 0.0), qy - _ry1)
				_push(ng + maxf(0.0, sqrt(hx * hx + hy * hy) - _reach), ni)
	if _hn == 0:
		_finish(-1, false)
	return used


func _finish(goal: int, partial: bool) -> void:
	active = false
	if goal < 0:
		result = {"path": [], "reached": false, "cost": INF, "partial": partial}
		return
	var path: Array[Vector2i] = []
	var c := goal
	while c != _si and c >= 0:
		path.append(Vector2i(c % w, c / w))
		c = _came[c]
	path.reverse()
	result = {"path": path, "reached": true, "cost": _g[goal], "partial": partial}


func _push(f: float, i: int) -> void:
	if _hn >= _hf.size():
		_hf.resize(_hf.size() * 2)
		_hi.resize(_hi.size() * 2)
	var k := _hn
	_hn += 1
	while k > 0:
		var p := (k - 1) >> 1
		if _hf[p] <= f:
			break
		_hf[k] = _hf[p]
		_hi[k] = _hi[p]
		k = p
	_hf[k] = f
	_hi[k] = i


func _pop() -> int:
	var top := _hi[0]
	_hn -= 1
	if _hn == 0:
		return top
	var f := _hf[_hn]
	var it := _hi[_hn]
	var k := 0
	var n := _hn
	while true:
		var l := 2 * k + 1
		if l >= n:
			break
		var r := l + 1
		var m := l
		if r < n and _hf[r] < _hf[l]:
			m = r
		if _hf[m] >= f:
			break
		_hf[k] = _hf[m]
		_hi[k] = _hi[m]
		k = m
	_hf[k] = f
	_hi[k] = it
	return top
