extends Node
## Salvataggio locale persistente: JSON cifrato (AES-256 con FileAccess.open_encrypted_with_pass),
## versione dello schema con migrazioni, autosalvataggio a ogni modifica (debounce) e alla chiusura/pausa.

const SAVE_PATH := "user://lanternreach.save"
const BACKUP_PATH := "user://lanternreach.bak"
const KEY := "lanternreach::v1::7c4e1f"
const DEBOUNCE := 0.8

var enabled := true          ## i test disattivano la scrittura su disco
var _dirty := false
var _timer := 0.0
var last_error := ""


func _ready() -> void:
	EventBus.state_changed.connect(_on_changed)


func _on_changed() -> void:
	_dirty = true
	_timer = DEBOUNCE


func _process(delta: float) -> void:
	if _dirty:
		_timer -= delta
		if _timer <= 0.0:
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not GameState.data.is_empty():
			save()


func save(path: String = SAVE_PATH) -> bool:
	if not enabled:
		_dirty = false
		return true
	GameState.data["last_seen"] = TimeManager.now()
	GameState.data["trusted_time"] = TimeManager.trusted_max
	var text := JSON.stringify(GameState.data)
	# backup del salvataggio precedente
	if path == SAVE_PATH and FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, KEY)
	if f == null:
		last_error = "open: %d" % FileAccess.get_open_error()
		push_warning("SaveManager: " + last_error)
		return false
	f.store_string(text)
	f.close()
	_dirty = false
	return true


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func read(path: String) -> Dictionary:
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, KEY)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Carica il salvataggio (o il backup se corrotto), applica migrazioni e progresso offline.
func load_game(path: String = SAVE_PATH) -> bool:
	var d := read(path)
	if d.is_empty() and path == SAVE_PATH:
		d = read(BACKUP_PATH)
	if d.is_empty():
		return false
	d = migrate(d)
	GameState.data = d
	GameState.rebuild_index()
	TimeManager.trusted_max = maxf(TimeManager.trusted_max, float(d.get("trusted_time", 0.0)))
	EconomyManager.process(TimeManager.now())
	return true


## Migrazioni di schema: ogni passo porta da n a n+1. Chiavi mancanti vengono completate dai default.
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("schema", 0))
	if v < 1:
		# v0 (prototipo): risorse in radice, nessuna progressione
		if not d.has("res"):
			d["res"] = {"cogs": float(d.get("cogs", 1500)), "sap": float(d.get("sap", 1500)), "shards": 0.0, "glimmers": float(d.get("gems", 50))}
		for k in ["cogs", "sap", "gems"]:
			d.erase(k)
		v = 1
	if v < 2:
		# v1 -> v2: introdotta la coda dei costruttori e il registro difese
		if not d.has("build_queue"):
			d["build_queue"] = []
		if not d.has("defense_log"):
			d["defense_log"] = []
		v = 2
	d["schema"] = v
	_fill_defaults(d, GameState.default_data())
	# i numeri JSON tornano float: normalizza gli interi usati come indici
	for b in d["buildings"]:
		b["uid"] = int(b["uid"])
		b["level"] = int(b["level"])
		b["x"] = int(b["x"])
		b["y"] = int(b["y"])
	for o in d["obstacles"]:
		o["uid"] = int(o["uid"])
		o["x"] = int(o["x"])
		o["y"] = int(o["y"])
	d["next_uid"] = int(d["next_uid"])
	return d


func _fill_defaults(d: Dictionary, defaults: Dictionary) -> void:
	for k in defaults:
		if not d.has(k):
			d[k] = defaults[k]
		elif defaults[k] is Dictionary and d[k] is Dictionary and not (k in ["army", "clan"]):
			_fill_defaults(d[k], defaults[k])


func delete_save() -> void:
	for p in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
