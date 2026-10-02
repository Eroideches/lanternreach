class_name Hud
extends Control
## HUD del villaggio (layout ART_DIRECTION §8.2): XP/nome/trofei in alto a sinistra, costruttori e scudo al centro,
## risorse in alto a destra (contatori animati 400 ms), ATTACCA in basso a sinistra, negozio/esercito/obiettivi
## in basso a destra, barra azioni contestuale in basso al centro.

signal action(name: String)

var res_bars: Dictionary = {}       ## res -> {bar, label, shown}
var lbl_level: Label
var lbl_name: Label
var xp_bar: Control
var lbl_trophies: Label
var league_icon: TextureRect
var lbl_builders: Label
var lbl_shield: Label
var shield_box: Control
var action_bar: HBoxContainer
var action_title: Label
var action_panel: PanelContainer
var badges: Dictionary = {}
var _shown: Dictionary = {}
# nodi da posizionare in _layout() (in base alla dimensione reale della finestra)
var _top_left: Control
var _top_center: Control
var _res_box: Control
var _attack: Control
var _right: Control
var _left: Control
var _settings: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_top_center()
	_build_resources()
	_build_buttons()
	_build_action_bar()
	EventBus.resources_changed.connect(func(_r, _v): _refresh_resources())
	EventBus.xp_changed.connect(func(_x, _l): _refresh_player())
	EventBus.trophies_changed.connect(func(_t): _refresh_player())
	EventBus.state_changed.connect(_refresh_badges)
	EventBus.daily_updated.connect(_refresh_badges)
	EventBus.language_changed.connect(_relabel)
	_refresh_player()
	for r in res_bars:
		_shown[r] = GameState.res(r)
	_refresh_resources(true)
	_refresh_badges()
	_layout.call_deferred()
	get_viewport().size_changed.connect(_layout)


## Posizionamento degli elementi rispetto ai bordi dello schermo (layout ART_DIRECTION §8.2).
func _layout() -> void:
	var vs := get_viewport_rect().size
	for c in [_top_center, _right, _left]:
		(c as Control).reset_size()
	_top_left.position = Vector2(18, 12)
	_top_center.position = Vector2((vs.x - _top_center.size.x) * 0.5, 14)
	_res_box.position = Vector2(vs.x - 430, 18)
	_attack.position = Vector2(22, vs.y - _attack.custom_minimum_size.y - 22)
	_right.position = Vector2(vs.x - _right.size.x - 24, vs.y - _right.size.y - 18)
	_left.position = Vector2(22, _attack.position.y - _left.size.y - 26)
	_settings.position = Vector2(vs.x - _settings.custom_minimum_size.x - 24, 470)
	_place_actions()


func _corner(ctrl: Control, _preset: int, _pos: Vector2) -> void:
	add_child(ctrl)


func _build_top_left() -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(420, 220)
	_corner(box, Control.PRESET_TOP_LEFT, Vector2(18, 12))
	_top_left = box
	var xp := UIK.icon("xp", 104)
	box.add_child(xp)
	lbl_level = UIK.hud_label("1", 38)
	lbl_level.position = Vector2(0, 30)
	lbl_level.size = Vector2(104, 44)
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl_level)
	lbl_name = UIK.hud_label("", 34)
	lbl_name.position = Vector2(112, 6)
	box.add_child(lbl_name)
	xp_bar = UIK.bar(0.0, "bar_xp", Vector2(240, 30))
	xp_bar.position = Vector2(114, 56)
	box.add_child(xp_bar)
	var tb := Button.new()
	tb.flat = true
	tb.focus_mode = Control.FOCUS_NONE
	tb.position = Vector2(0, 104)
	tb.custom_minimum_size = Vector2(300, 110)
	for st in ["normal", "hover", "pressed", "focus"]:
		tb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	tb.pressed.connect(func(): action.emit("leagues"))
	box.add_child(tb)
	league_icon = UIK.icon_rect(Art.tex("icons", "league/wick"), 100)
	league_icon.position = Vector2(2, 0)
	tb.add_child(league_icon)
	lbl_trophies = UIK.hud_label("0", 42)
	lbl_trophies.position = Vector2(110, 26)
	tb.add_child(lbl_trophies)


func _build_top_center() -> void:
	var h := UIK.hbox(26)
	_corner(h, Control.PRESET_CENTER_TOP, Vector2(-330, 14))
	_top_center = h
	var bb := Button.new()
	bb.focus_mode = Control.FOCUS_NONE
	bb.custom_minimum_size = Vector2(250, 76)
	bb.add_theme_stylebox_override("normal", UIK.style("res_bar", Vector4(60, 4, 18, 4)))
	bb.add_theme_stylebox_override("hover", UIK.style("res_bar", Vector4(60, 4, 18, 4)))
	bb.add_theme_stylebox_override("pressed", UIK.style("res_bar", Vector4(60, 4, 18, 4)))
	bb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	bb.pressed.connect(func(): action.emit("builders"))
	h.add_child(bb)
	var bi := UIK.icon("builder", 76)
	bi.position = Vector2(-10, -4)
	bb.add_child(bi)
	lbl_builders = UIK.hud_label("0/0", 36)
	lbl_builders.position = Vector2(84, 14)
	bb.add_child(lbl_builders)
	shield_box = Control.new()
	shield_box.custom_minimum_size = Vector2(290, 76)
	var sb := UIK.nine("res_bar")
	sb.set_anchors_preset(Control.PRESET_FULL_RECT)
	shield_box.add_child(sb)
	var si := UIK.icon("shield", 76)
	si.position = Vector2(-10, -4)
	shield_box.add_child(si)
	lbl_shield = UIK.hud_label("", 32)
	lbl_shield.position = Vector2(80, 16)
	shield_box.add_child(lbl_shield)
	h.add_child(shield_box)


func _build_resources() -> void:
	var v := UIK.vbox(26)
	_corner(v, Control.PRESET_TOP_RIGHT, Vector2(-430, 18))
	_res_box = v
	for r in ["cogs", "sap", "shards", "glimmers"]:
		var row := Control.new()
		row.custom_minimum_size = Vector2(400, 70)
		var bg := UIK.nine("res_bar")
		bg.position = Vector2(30, 6)
		bg.size = Vector2(370, 60)
		row.add_child(bg)
		var fill := UIK.nine("bar_" + {"cogs": "cogs", "sap": "sap", "shards": "shards", "glimmers": "build"}[r])
		fill.position = Vector2(86, 20)
		fill.size = Vector2(200, 30)
		row.add_child(fill)
		var ic := UIK.icon(r, 84)
		ic.position = Vector2(-6, -6)
		row.add_child(ic)
		var l := UIK.hud_label("0", 34)
		l.position = Vector2(100, 10)
		l.size = Vector2(286, 44)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
		var cap := UIK.label("", 20, true, LIGHT_CAP, 5)
		cap.position = Vector2(92, 58)
		row.add_child(cap)
		v.add_child(row)
		res_bars[r] = {"fill": fill, "label": l, "cap": cap, "row": row}
		if r == "shards":
			row.visible = GameState.hall_level() >= 5 or GameState.res("shards") > 0

const LIGHT_CAP := Color(1, 0.95, 0.84)


func _build_buttons() -> void:
	var atk := UIK.button("", "red", "", Vector2(210, 210))
	atk.custom_minimum_size = Vector2(210, 210)
	var ai := UIK.icon("attack", 130)
	ai.position = Vector2(40, 18)
	atk.add_child(ai)
	var al := UIK.label(tr("hud.attack"), 40, true, Color.WHITE, 10)
	al.name = "Lbl"
	al.position = Vector2(0, 148)
	al.size = Vector2(210, 50)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk.add_child(al)
	atk.pressed.connect(func(): action.emit("attack"))
	_corner(atk, Control.PRESET_BOTTOM_LEFT, Vector2(22, -232))
	_attack = atk
	badges["attack"] = atk
	var right := UIK.hbox(18)
	right.alignment = BoxContainer.ALIGNMENT_END
	_corner(right, Control.PRESET_BOTTOM_RIGHT, Vector2(-720, -214))
	_right = right
	for def in [["quests", "purple", "quests", 150], ["army", "blue", "army", 170], ["shop", "gold", "shop", 196]]:
		var b := _round(def[0], def[1], def[2], def[3])
		right.add_child(b)
	var left := UIK.vbox(16)
	_corner(left, Control.PRESET_CENTER_LEFT, Vector2(22, -40))
	_left = left
	left.add_child(_round("clan", "blue", "clan", 134))
	left.add_child(_round("log", "blue", "log", 134))
	var set_b := _round("settings", "blue", "settings", 134)
	_corner(set_b, Control.PRESET_CENTER_RIGHT, Vector2(-156, 30))
	_settings = set_b


func _round(key: String, color: String, icon_key: String, s: float) -> Button:
	var b := UIK.button("", color, "", Vector2(s, s))
	b.custom_minimum_size = Vector2(s, s)
	var ic := UIK.icon(icon_key, s * 0.62)
	ic.position = Vector2(s * 0.19, 6)
	b.add_child(ic)
	var l := UIK.label(tr("hud." + key), 26, true, Color.WHITE, 8)
	l.name = "Lbl"
	l.position = Vector2(-20, s - 48)
	l.size = Vector2(s + 40, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.pressed.connect(func(): action.emit(key))
	badges[key] = b
	return b


func _relabel() -> void:
	for k in badges:
		var b: Control = badges[k]
		if b.has_node("Lbl"):
			(b.get_node("Lbl") as Label).text = tr("hud." + k)


func _build_action_bar() -> void:
	action_panel = UIK.panel("panel_dark", Vector4(24, 14, 24, 18))
	var v := UIK.vbox(6)
	action_title = UIK.label("", 32, true, Color.WHITE, 8)
	action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(action_title)
	action_bar = UIK.hbox(14)
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(action_bar)
	action_panel.add_child(v)
	action_panel.visible = false
	add_child(action_panel)


## Mostra la barra azioni: items = [{key, text, color, icon, enabled, cost, w}]
func show_actions(title: String, items: Array) -> void:
	for c in action_bar.get_children():
		action_bar.remove_child(c)
		c.queue_free()
	action_title.text = title
	for it in items:
		var b: Button
		if it.has("cost"):
			# pulsante con icona + testo sulla prima riga e costi sulla seconda (contenuto personalizzato)
			b = UIK.button("", it.get("color", "blue"), "", Vector2(it.get("w", 200), 132), 28)
			var v := UIK.vbox(2)
			v.alignment = BoxContainer.ALIGNMENT_CENTER
			v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			v.offset_bottom = -12
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var top_row := UIK.hbox(8)
			top_row.alignment = BoxContainer.ALIGNMENT_CENTER
			if it.get("icon", "") != "":
				top_row.add_child(UIK.icon(it["icon"], 46))
			top_row.add_child(UIK.label(it.get("text", ""), 28, true, Color.WHITE, 8))
			v.add_child(top_row)
			var cr := UIK.cost_row(it["cost"], 24)
			cr.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_child(cr)
			b.add_child(v)
		else:
			b = UIK.button(it.get("text", ""), it.get("color", "blue"), it.get("icon", ""), Vector2(it.get("w", 200), 110), 28)
		b.disabled = not it.get("enabled", true)
		var key: String = it["key"]
		b.pressed.connect(func(): action.emit(key))
		action_bar.add_child(b)
	action_panel.visible = true
	action_panel.modulate.a = 0.0
	action_panel.create_tween().tween_property(action_panel, "modulate:a", 1.0, 0.12)
	_place_actions.call_deferred()


func _place_actions() -> void:
	if not is_instance_valid(action_panel):
		return
	action_panel.reset_size()
	var vs := get_viewport_rect().size
	action_panel.position = Vector2((vs.x - action_panel.size.x) * 0.5, vs.y - action_panel.size.y - 20)


func hide_actions() -> void:
	action_panel.visible = false


func set_main_buttons_visible(v: bool) -> void:
	for k in badges:
		(badges[k] as Control).visible = v


# --------------------------------------------------------------- refresh
func _refresh_player() -> void:
	var li := Progression.level_info()
	lbl_level.text = str(li["level"])
	var nm: String = GameState.data["player"].get("name", "")
	lbl_name.text = nm if nm != "" else tr("player.default_name")
	UIK.set_bar(xp_bar, 1.0 if li["max"] else float(li["xp"]) / maxf(1.0, float(li["need"])))
	lbl_trophies.text = UIK.num(Progression.trophies())
	league_icon.texture = Art.tex("icons", "league/" + Progression.league()["id"])


func _refresh_resources(instant: bool = false) -> void:
	for r in res_bars:
		var target := GameState.res(r)
		var cap := EconomyManager.storage_cap(r)
		var row: Dictionary = res_bars[r]
		(row["cap"] as Label).text = "" if r == "glimmers" else tr("hud.max") + " " + UIK.num(cap)
		var fill: Control = row["fill"]
		var frac := 1.0 if r == "glimmers" else clampf(target / maxf(1.0, cap), 0.0, 1.0)
		fill.size.x = maxf(26.0, 280.0 * frac)
		fill.visible = frac > 0.005
		if r == "shards":
			(row["row"] as Control).visible = GameState.hall_level() >= 5 or target > 0
		if instant:
			_shown[r] = target
			(row["label"] as Label).text = UIK.num(target)
		else:
			var from := float(_shown.get(r, target))
			_shown[r] = target
			var l: Label = row["label"]
			var tw := l.create_tween()
			tw.tween_method(func(v: float) -> void: l.text = UIK.num(v), from, target, 0.4)
			if target > from:
				l.pivot_offset = l.size * Vector2(1.0, 0.5)
				var t2 := l.create_tween()
				t2.tween_property(l, "scale", Vector2(1.12, 1.12), 0.08)
				t2.tween_property(l, "scale", Vector2.ONE, 0.08)


func resource_screen_pos(r: String) -> Vector2:
	if not res_bars.has(r):
		return Vector2(1700, 60)
	var row: Control = res_bars[r]["row"]
	return row.global_position + Vector2(40, 36)


func _process(_delta: float) -> void:
	lbl_builders.text = "%d/%d" % [EconomyManager.free_builders(), int(GameState.data["builders"])]
	var sh := float(GameState.data.get("shield_until", 0.0)) - TimeManager.now()
	shield_box.visible = sh > 0
	if sh > 0:
		lbl_shield.text = TimeManager.format_duration(sh)


func _refresh_badges() -> void:
	_badge("quests", Progression.ready_achievements() > 0 or Progression.login_pending() or _missions_ready())
	var unseen := false
	for e in GameState.data.get("defense_log", []):
		if not e.get("seen", true):
			unseen = true
	_badge("log", unseen)


func _missions_ready() -> bool:
	for m in GameState.data["progress"]["daily"].get("missions", []):
		var d := Progression.mission_def(m["id"])
		if not m["claimed"] and float(m["progress"]) >= float(d.get("target", 1e9)):
			return true
	return false


func _badge(key: String, on: bool) -> void:
	if not badges.has(key):
		return
	var b: Control = badges[key]
	var dot: Node = b.get_node_or_null("Badge")
	if on and dot == null:
		var d := UIK.icon_rect(Art.tex("icons", "icon/close"), 44)
		d.name = "Badge"
		d.modulate = Color(1, 1, 1)
		var lb := UIK.label("!", 30, true, Color.WHITE, 6)
		lb.position = Vector2(14, 2)
		d.add_child(lb)
		d.position = Vector2(b.custom_minimum_size.x - 34, -8)
		d.texture = Art.tex("icons", "icon/minus")
		d.modulate = Color(1, 0.85, 0.85)
		b.add_child(d)
	elif not on and dot != null:
		dot.queue_free()
