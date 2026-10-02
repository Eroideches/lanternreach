extends Control
## Tutorial interattivo (primi ~10 minuti): guida passo passo con la "Custode della Lanterna", freccia che indica
## il controllo o l'edificio da usare, avanzamento sugli eventi reali del gioco (EventBus.tutorial_event).
## Passi: benvenuto -> Mina -> Pozzo -> raccolta -> Caserma -> addestramento -> primo attacco (campagna 1)
## -> Boltpost -> potenziamento del Faro Madre (accelerazione gratuita) -> fine (ricompensa).

var village: Node
var step := 0
var panel: PanelContainer
var text_label: Label
var next_btn: Button
var finger: TextureRect
var _target_ctrl: Control
var _target_uid := -1
var _bob := 0.0

const STEPS := [
	{"text": "tut.welcome", "wait": "next"},
	{"text": "tut.build_mine", "wait": "placed_cog_mine", "target": "hud:shop"},
	{"text": "tut.wait_build", "wait": "finished_cog_mine", "target": "building:cog_mine", "free_speedup": true},
	{"text": "tut.build_well", "wait": "placed_sap_well", "target": "hud:shop"},
	{"text": "tut.wait_build", "wait": "finished_sap_well", "target": "building:sap_well", "free_speedup": true},
	{"text": "tut.collect", "wait": "collected", "target": "building:cog_mine", "gift_stored": true},
	{"text": "tut.build_barracks", "wait": "placed_barracks", "target": "hud:shop"},
	{"text": "tut.wait_build", "wait": "finished_barracks", "target": "building:barracks", "free_speedup": true},
	{"text": "tut.train", "wait": "army5", "target": "hud:army"},
	{"text": "tut.attack", "wait": "battle_won", "target": "hud:attack"},
	{"text": "tut.build_defense", "wait": "placed_boltpost", "target": "hud:shop"},
	{"text": "tut.upgrade_hall", "wait": "upgrade_lantern_hall", "target": "building:lantern_hall"},
	{"text": "tut.hall_speed", "wait": "finished_lantern_hall", "target": "building:lantern_hall", "free_speedup": true},
	{"text": "tut.done", "wait": "next", "reward": 50},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	step = int(GameState.data["tutorial"].get("step", 0))
	panel = UIK.panel("panel", Vector4(24, 18, 24, 20))
	var h := UIK.hbox(20)
	var portrait := UIK.icon_rect(load("res://assets/branding/icon_192.png"), 150)
	h.add_child(portrait)
	var v := UIK.vbox(10)
	text_label = UIK.label("", 30)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(760, 0)
	v.add_child(text_label)
	var bh := UIK.hbox(16)
	next_btn = UIK.button(tr("ui.next"), "green", "", Vector2(220, 96), 30)
	next_btn.pressed.connect(_on_next)
	bh.add_child(next_btn)
	var skip := UIK.button(tr("tut.skip"), "blue", "", Vector2(260, 96), 26)
	skip.pressed.connect(_skip)
	bh.add_child(skip)
	v.add_child(bh)
	h.add_child(v)
	panel.add_child(h)
	add_child(panel)
	finger = UIK.icon_rect(Art.icon("upgrade"), 110)
	finger.rotation = PI
	finger.pivot_offset = Vector2(55, 55)
	finger.visible = false
	add_child(finger)
	EventBus.tutorial_event.connect(_on_event)
	EventBus.army_changed.connect(_check_army)
	_enter(step)


func _layout_panel() -> void:
	panel.reset_size()
	var vs := get_viewport_rect().size
	panel.position = Vector2((vs.x - panel.size.x) * 0.5, 112)


func _enter(i: int) -> void:
	step = i
	GameState.data["tutorial"]["step"] = i
	EventBus.state_changed.emit()
	if i >= STEPS.size():
		_finish()
		return
	var s: Dictionary = STEPS[i]
	if _already_done(s):
		_enter.call_deferred(i + 1)
		return
	text_label.text = tr(s["text"])
	next_btn.visible = s["wait"] == "next"
	_target_ctrl = null
	_target_uid = -1
	var tgt: String = s.get("target", "")
	if tgt.begins_with("hud:"):
		var hud: Node = village.hud
		_target_ctrl = hud.badges.get(tgt.substr(4))
	elif tgt.begins_with("building:"):
		var bs := GameState.buildings_of(tgt.substr(9))
		if not bs.is_empty():
			_target_uid = int(bs[0]["uid"])
	if s.get("gift_stored", false):
		for b in GameState.buildings_of("cog_mine"):
			b["stored"] = maxf(float(b.get("stored", 0.0)), 150.0)
			b["last_prod"] = TimeManager.now()
	if s.get("free_speedup", false):
		_free_speed()
	finger.visible = _target_ctrl != null or _target_uid >= 0
	await get_tree().process_frame
	_layout_panel()
	# il dialogo resta in alto al centro, sotto l'HUD, per non coprire il villaggio e i bersagli


## Evita blocchi: se l'obiettivo del passo e' gia' raggiunto (es. vittoria avvenuta nella scena di battaglia), si avanza.
func _already_done(s: Dictionary) -> bool:
	var w: String = s["wait"]
	if w.begins_with("placed_"):
		return GameState.count_of(w.substr(7)) > 0
	if w == "finished_lantern_hall" or w == "upgrade_lantern_hall":
		return GameState.hall_level() >= 2 or (w == "upgrade_lantern_hall" and not GameState.hall().get("job", {}).is_empty())
	if w.begins_with("finished_"):
		return GameState.highest_level(w.substr(9)) >= 1
	if w == "army5":
		return int(GameState.army_troops().get("cogling", 0)) >= 5
	if w == "battle_won":
		return Progression.campaign_stars(1) > 0
	return false


func _free_speed() -> void:
	## Durante il tutorial le prime costruzioni si completano gratis dopo una breve attesa.
	await get_tree().create_timer(2.5).timeout
	for b in GameState.buildings():
		if not b.get("job", {}).is_empty():
			b["job"]["end"] = TimeManager.now()
	EconomyManager.process(TimeManager.now())


func _on_next() -> void:
	if STEPS[step]["wait"] == "next":
		if STEPS[step].has("reward"):
			EconomyManager.add("glimmers", int(STEPS[step]["reward"]))
		_enter(step + 1)


func _on_event(name: String) -> void:
	if step >= STEPS.size():
		return
	var w: String = STEPS[step]["wait"]
	if name == w:
		AudioManager.sfx("reward", 0.0, 0.2, true)
		_enter(step + 1)
		return
	# completa l'addestramento al volo (gratis) per non far aspettare nel tutorial
	if w == "army5" and name.begins_with("trained_"):
		GameState.data["training"]["troops_started"] = TimeManager.now() - 1e6
		EconomyManager.process(TimeManager.now())
		_check_army()


func _check_army() -> void:
	if step < STEPS.size() and STEPS[step]["wait"] == "army5":
		if int(GameState.army_troops().get("cogling", 0)) >= 5:
			_enter(step + 1)


func _process(delta: float) -> void:
	if not finger.visible:
		return
	_bob += delta * 5.0
	var off := Vector2(0, -sin(_bob) * 14.0)
	if _target_ctrl and is_instance_valid(_target_ctrl) and _target_ctrl.is_visible_in_tree():
		var r := _target_ctrl.get_global_rect()
		finger.position = Vector2(r.position.x + r.size.x * 0.5 - 55, r.position.y - 120) + off
		finger.rotation = PI
	elif _target_uid >= 0 and village.views.has(_target_uid):
		var v: Node2D = village.views[_target_uid]
		var sp: Vector2 = village.get_viewport().get_canvas_transform() * (v.position + Vector2(0, -80))
		finger.position = sp - Vector2(55, 180) + off
		finger.rotation = PI


func _skip() -> void:
	var d: Modal = load("res://scripts/ui/confirm_dialog.gd").new()
	d.set("text", tr("tut.skip_confirm"))
	d.set("on_yes", _finish)
	get_parent().add_child(d)


func _finish() -> void:
	GameState.data["tutorial"]["done"] = true
	GameState.data["tutorial"]["step"] = STEPS.size()
	# lo scudo da principiante parte da ora
	GameState.data["shield_until"] = TimeManager.now() + float(Balance.economy["shield"]["newbie_s"])
	GameState.data["next_offline_attack"] = float(GameState.data["shield_until"]) + 4 * 3600.0
	EventBus.state_changed.emit()
	SaveManager.save()
	queue_free()
