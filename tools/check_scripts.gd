extends SceneTree
## Carica e compila tutti gli script del progetto (usato in CI e in locale): esce con codice 1 se uno fallisce.
var _done := false
func _process(_d):
	if _done: return false
	_done = true
	var bad := 0
	var n := 0
	for d in ["res://scripts/core", "res://scripts/autoload", "res://scripts/app", "res://scripts/world", "res://scripts/ui", "res://scenes", "res://tests/unit"]:
		if not DirAccess.dir_exists_absolute(d): continue
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				n += 1
				var s = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					print("ERRORE: ", d + "/" + f); bad += 1
	print("script controllati: %d, errori: %d" % [n, bad])
	quit(1 if bad > 0 else 0)
	return true
