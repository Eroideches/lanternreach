extends Modal
## Impostazioni: nome, lingua, volumi musica/effetti, qualita' grafica, scossa dello schermo, reset dati (doppia conferma), crediti.

var village: Node


func _init() -> void:
	super._init(" ", Vector2(1400, 920))


func _ready() -> void:
	title = tr("settings.title")
	super._ready()


func build() -> void:
	var s: Dictionary = GameState.settings()
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 18)
	# nome
	g.add_child(UIK.label(tr("settings.name"), 30, true, UIK.INK))
	var le := LineEdit.new()
	le.text = GameState.data["player"].get("name", "")
	le.placeholder_text = tr("player.default_name")
	le.max_length = 16
	le.custom_minimum_size = Vector2(520, 80)
	le.text_submitted.connect(func(t: String) -> void: _set_name(t))
	le.focus_exited.connect(func() -> void: _set_name(le.text))
	g.add_child(le)
	# lingua
	g.add_child(UIK.label(tr("settings.language"), 30, true, UIK.INK))
	var lh := UIK.hbox(14)
	for code in ["it", "en"]:
		var b := UIK.button(tr("lang." + code), "gold" if s.get("lang", "it") == code else "blue", "language", Vector2(250, 96), 28)
		b.pressed.connect(func() -> void:
			s["lang"] = code
			TranslationServer.set_locale(code)
			EventBus.language_changed.emit()
			EventBus.state_changed.emit()
			rebuild())
		lh.add_child(b)
	g.add_child(lh)
	# volumi
	for key in ["music", "sfx"]:
		g.add_child(UIK.label(tr("settings." + key), 30, true, UIK.INK))
		var hs := HSlider.new()
		hs.min_value = 0.0
		hs.max_value = 1.0
		hs.step = 0.05
		hs.value = float(s.get(key, 0.8))
		hs.custom_minimum_size = Vector2(520, 70)
		hs.add_theme_stylebox_override("slider", UIK.style("bar_bg", Vector4(0, 12, 0, 12)))
		hs.add_theme_stylebox_override("grabber_area", UIK.style("bar_build", Vector4(0, 12, 0, 12)))
		hs.add_theme_stylebox_override("grabber_area_highlight", UIK.style("bar_build", Vector4(0, 12, 0, 12)))
		hs.add_theme_icon_override("grabber", Art.tex("fx", "p/star_pop"))
		hs.add_theme_icon_override("grabber_highlight", Art.tex("fx", "p/star_pop"))
		hs.value_changed.connect(func(v: float) -> void:
			s[key] = v
			EventBus.settings_changed.emit()
			EventBus.state_changed.emit())
		g.add_child(hs)
	# qualita' e scossa
	g.add_child(UIK.label(tr("settings.quality"), 30, true, UIK.INK))
	var qh := UIK.hbox(14)
	for q in ["high", "low"]:
		var b := UIK.button(tr("settings.q_" + q), "gold" if s.get("quality", "high") == q else "blue", "", Vector2(250, 96), 28)
		b.pressed.connect(func() -> void:
			s["quality"] = q
			Art.quality_high = q == "high"
			EventBus.state_changed.emit()
			rebuild())
		qh.add_child(b)
	g.add_child(qh)
	g.add_child(UIK.label(tr("settings.shake"), 30, true, UIK.INK))
	var cb := CheckButton.new()
	cb.button_pressed = bool(s.get("shake", true))
	cb.custom_minimum_size = Vector2(132, 80)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		cb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	cb.add_theme_icon_override("checked", Art.icon("check"))
	cb.add_theme_icon_override("unchecked", Art.icon("close"))
	cb.toggled.connect(func(v: bool) -> void:
		s["shake"] = v
		EventBus.state_changed.emit())
	g.add_child(cb)
	content.add_child(g)
	content.add_child(UIK.spacer(0, 10))
	var bottom := UIK.hbox(20)
	var reset := UIK.button(tr("settings.reset"), "red", "reset", Vector2(380, 104), 28)
	reset.pressed.connect(_ask_reset)
	bottom.add_child(reset)
	var credits := UIK.button(tr("settings.credits"), "blue", "info", Vector2(320, 104), 28)
	credits.pressed.connect(_show_credits)
	bottom.add_child(credits)
	bottom.add_child(UIK.spacer())
	bottom.add_child(UIK.label("v" + str(ProjectSettings.get_setting("application/config/version")), 24))
	content.add_child(bottom)


func _set_name(t: String) -> void:
	GameState.data["player"]["name"] = t.strip_edges().left(16)
	EventBus.xp_changed.emit(int(GameState.data["player"]["xp"]), int(GameState.data["player"]["level"]))
	EventBus.state_changed.emit()


func _ask_reset() -> void:
	var d: Modal = load("res://scripts/ui/confirm_dialog.gd").new()
	d.set("text", tr("settings.reset_confirm1"))
	d.set("on_yes", func() -> void:
		var d2: Modal = load("res://scripts/ui/confirm_dialog.gd").new()
		d2.set("text", tr("settings.reset_confirm2"))
		d2.set("yes_text", tr("settings.reset_yes"))
		d2.set("on_yes", func() -> void:
			SaveManager.delete_save()
			GameState.new_game(true)
			SaveManager.save()
			Router.go("village"))
		get_parent().add_child(d2))
	get_parent().add_child(d)


func _show_credits() -> void:
	var d: Modal = load("res://scripts/ui/confirm_dialog.gd").new()
	d.set("text", tr("settings.credits_text"))
	d.set("yes_text", tr("ui.ok"))
	get_parent().add_child(d)
