extends Control
## Splash di Lanternreach, mostrato DOPO la scritta EroideGames: dissolvenza dal nero, caricamento del salvataggio
## (con progresso offline, missioni giornaliere e attacchi subiti mentre il gioco era chiuso), poi villaggio
## (il tutorial parte nel villaggio alla prima partita). Durata minima: MIN_TIME secondi.

const MIN_TIME := 1.6
const FADE_IN := 0.35

var splash: TextureRect
var status: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	splash = TextureRect.new()
	splash.texture = load("res://assets/branding/splash.png")
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.modulate.a = 0.0
	add_child(splash)
	status = UIK.label("", 30, true, Color.WHITE, 8)
	status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.position = Vector2(-400, -90)
	status.size = Vector2(800, 50)
	add_child(status)
	var t0 := Time.get_ticks_msec()
	var tw := create_tween()
	tw.tween_property(splash, "modulate:a", 1.0, FADE_IN)
	await tw.finished
	await get_tree().process_frame
	boot_game()
	status.text = tr("boot.loading")
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	if elapsed < MIN_TIME:
		await get_tree().create_timer(MIN_TIME - elapsed).timeout
	Router.go("village")


## Carica (o crea) la partita e porta lo stato al presente. Statico per poterlo usare anche nei test.
static func boot_game() -> void:
	var loaded := false
	if SaveManager.has_save():
		loaded = SaveManager.load_game()
	if not loaded:
		GameState.new_game(true)
		SaveManager.save()
	apply_settings()
	var now := TimeManager.now()
	EconomyManager.process(now)
	Progression.refresh_daily(now)
	OfflineAttacks.process(now)
	SaveManager.save()


static func apply_settings() -> void:
	var s: Dictionary = GameState.settings()
	var lang: String = s.get("lang", "")
	if lang == "":
		lang = "it" if OS.get_locale_language() == "it" else "en"
		s["lang"] = lang
	TranslationServer.set_locale(lang)
	Art.quality_high = s.get("quality", "high") == "high"
	AudioManager.apply_settings()
