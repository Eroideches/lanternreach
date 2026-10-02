extends Modal
## Schermata risultati: vittoria/sconfitta, stelle animate, % distruzione, bottino, trofei, XP, gemme; replay.

var result: Dictionary = {}
var extra: Dictionary = {}
var battle: Node


func _init() -> void:
	super._init(" ", Vector2(1300, 820))
	close_on_dim = false


func _ready() -> void:
	var win := int(result.get("stars", 0)) > 0
	title = tr("results.victory") if win else tr("results.defeat")
	ribbon_color = "ribbon" if win else "ribbon_blue"
	super._ready()


func build() -> void:
	var stars := UIK.hbox(30)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	var icons: Array = []
	for i in 3:
		var s := UIK.icon("star_empty", 150)
		icons.append(s)
		stars.add_child(s)
	content.add_child(stars)
	var pct := UIK.label(tr("battle.destruction") % int(result.get("percent", 0)), 40, true, UIK.INK)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(pct)
	var rows := UIK.hbox(40)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	var loot: Dictionary = extra.get("loot", result.get("loot", {}))
	for r in ["cogs", "sap", "shards"]:
		if float(loot.get(r, 0)) > 0 or r != "shards":
			var h := UIK.hbox(8)
			h.add_child(UIK.icon(r, 70))
			h.add_child(UIK.label(UIK.num(float(loot.get(r, 0))), 38, true, Color.WHITE, 8))
			rows.add_child(h)
	content.add_child(rows)
	var rows2 := UIK.hbox(40)
	rows2.alignment = BoxContainer.ALIGNMENT_CENTER
	if int(extra.get("trophies", 0)) != 0:
		var h2 := UIK.hbox(8)
		h2.add_child(UIK.icon("trophy", 64))
		var td := int(extra["trophies"])
		h2.add_child(UIK.label(("+" if td > 0 else "") + str(td), 38, true, UIK.GREEN if td > 0 else UIK.RED, 8))
		rows2.add_child(h2)
	if int(extra.get("xp", 0)) > 0:
		var h3 := UIK.hbox(8)
		h3.add_child(UIK.icon("xp", 64))
		h3.add_child(UIK.label("+%d" % int(extra["xp"]), 38, true, Color.WHITE, 8))
		rows2.add_child(h3)
	if int(extra.get("gems", 0)) > 0:
		var h4 := UIK.hbox(8)
		h4.add_child(UIK.icon("glimmers", 64))
		h4.add_child(UIK.label("+%d" % int(extra["gems"]), 38, true, Color.WHITE, 8))
		rows2.add_child(h4)
	content.add_child(rows2)
	content.add_child(UIK.spacer(0, 20))
	var btns := UIK.hbox(30)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var home := UIK.button(tr("results.home"), "green", "home", Vector2(400, 116), 32)
	home.pressed.connect(func() -> void: Router.go("village"))
	btns.add_child(home)
	if extra.has("replay"):
		var rp := UIK.button(tr("results.replay"), "blue", "replay", Vector2(360, 116), 32)
		var data: Dictionary = extra["replay"]
		rp.pressed.connect(func() -> void: Router.go("battle", {"mode": "replay", "replay": data}))
		btns.add_child(rp)
	content.add_child(btns)
	_animate_stars(icons)


func _animate_stars(icons: Array) -> void:
	await get_tree().create_timer(0.4).timeout
	for i in int(result.get("stars", 0)):
		var s: TextureRect = icons[i]
		s.texture = Art.icon("star")
		s.pivot_offset = s.size * 0.5
		s.scale = Vector2(1.8, 1.8)
		s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		AudioManager.sfx("star%d" % (i + 1))
		await get_tree().create_timer(0.35).timeout


func close() -> void:
	Router.go("village")
