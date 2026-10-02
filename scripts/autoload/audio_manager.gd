extends Node
## Musica (con dissolvenza incrociata) ed effetti con pool di player. Bus: Music / SFX / UI.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 12

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _mk("Music")
	_music_b = _mk("Music")
	for i in POOL:
		_pool.append(_mk("SFX"))
	apply_settings()
	EventBus.settings_changed.connect(apply_settings)


func _mk(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_settings() -> void:
	if GameState.data.is_empty():
		return
	var s: Dictionary = GameState.settings()
	_set_bus("Music", float(s.get("music", 0.7)))
	_set_bus("SFX", float(s.get("sfx", 0.9)))
	_set_bus("UI", float(s.get("sfx", 0.9)))


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.001, v)))


func _stream(path: String, loop: bool = false) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	_cache[path] = s
	return s


func play_music(name: String, fade: float = 0.6) -> void:
	if name == _current:
		return
	_current = name
	var st := _stream(MUSIC_DIR + name + ".wav", true)
	if st == null:
		return
	var old := _music_a if _music_a.playing else null
	var nw := _music_b if old == _music_a else _music_a
	nw.stream = st
	nw.volume_db = -40.0
	nw.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nw, "volume_db", 0.0, fade)
	if old:
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.chain().tween_callback(old.stop)
	if nw == _music_b:
		var t := _music_a
		_music_a = _music_b
		_music_b = t


func stop_music() -> void:
	_current = ""
	_music_a.stop()
	_music_b.stop()


## Suona un effetto; `min_gap` evita raffiche dello stesso suono (es. 30 colpi nello stesso tick).
func sfx(name: String, pitch_var: float = 0.06, min_gap: float = 0.045, ui: bool = false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(name, -1.0)) < min_gap:
		return
	_last_play[name] = now
	var st := _stream(SFX_DIR + name + ".wav")
	if st == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = st
			p.bus = "UI" if ui else "SFX"
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func click() -> void:
	sfx("ui_click", 0.03, 0.02, true)
