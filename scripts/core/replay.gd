class_name Replay
extends RefCounted
## Riproduzione deterministica: ricostruisce la simulazione e riapplica gli input registrati al tick esatto.

var sim: BattleSim
var data: Dictionary
var cursor := 0


func _init(d: Dictionary) -> void:
	data = d
	sim = BattleSim.new()
	sim.setup(d["base"], d["army"], int(d["seed"]))


## Avanza di un tick applicando gli input registrati per quel tick.
func advance() -> void:
	var inputs: Array = data["inputs"]
	while cursor < inputs.size() and int(inputs[cursor][0]) == sim.tick:
		var inp: Array = inputs[cursor]
		var p := Vector2(float(inp[3]), float(inp[4]))
		if inp[1] == "troop":
			sim.deploy_troop(inp[2], p)
		else:
			sim.cast_spell(inp[2], p)
		cursor += 1
	# i comandi accodati vengono applicati all'inizio di step() con il tick corrente
	sim.step()


func finished() -> bool:
	return sim.ended or (cursor >= data["inputs"].size() and sim.tick > int(data["inputs"].back()[0] if not data["inputs"].is_empty() else 0) + sim.max_ticks)


## Esegue l'intero replay e ritorna il risultato.
static func run(d: Dictionary) -> Dictionary:
	var r := Replay.new(d)
	var guard := 0
	while not r.sim.ended and guard < r.sim.max_ticks + 10:
		r.advance()
		guard += 1
	return r.sim.result()
