extends Modal
## Costruttori: lavori in corso (con accelerazione), coda pianificata, acquisto del costruttore successivo.

var village: Node


func _init() -> void:
	super._init(" ", Vector2(1300, 820))


func _ready() -> void:
	title = tr("builders.title")
	super._ready()


func build() -> void:
	var nb := int(GameState.data["builders"])
	content.add_child(UIK.label(tr("builders.count") % [EconomyManager.free_builders(), nb], 32, true, UIK.INK))
	var list := UIK.vbox(8)
	for lst in [GameState.data["buildings"], GameState.data["obstacles"]]:
		for e in lst:
			if e.get("job", {}).is_empty():
				continue
			var row := UIK.panel("panel_inset", Vector4(14, 8, 14, 8))
			var h := UIK.hbox(14)
			h.add_child(UIK.icon_rect(Art.thumb(e["id"]), 80))
			var v := UIK.vbox(2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(UIK.label(tr("building." + str(e["id"])), 28, true, UIK.INK))
			v.add_child(UIK.label(TimeManager.format_duration(EconomyManager.remaining(e)), 24))
			h.add_child(v)
			var uid := int(e["uid"])
			var sp := UIK.button("%d" % EconomyManager.speedup_cost_for(e), "purple", "glimmers", Vector2(200, 92), 28)
			sp.pressed.connect(func() -> void:
				if EconomyManager.speedup(uid):
					rebuild()
				else:
					toast(tr("err.no_glimmers"), "error"))
			h.add_child(sp)
			row.add_child(h)
			list.add_child(row)
	var q: Array = GameState.data["build_queue"]
	if not q.is_empty():
		list.add_child(UIK.label(tr("builders.queue") % q.size(), 26))
	content.add_child(scroll(list))
	var price := EconomyManager.next_builder_price()
	if price > 0:
		var b := UIK.button(tr("builders.buy") % (nb + 1), "purple", "builder", Vector2(520, 116), 30)
		var cr := UIK.cost_row({"glimmers": float(price)}, 26)
		b.add_child(cr)
		cr.position = Vector2(380, 66)
		b.pressed.connect(func() -> void:
			if EconomyManager.buy_builder():
				AudioManager.sfx("reward")
				rebuild()
			else:
				toast(tr("err.no_glimmers"), "error"))
		content.add_child(b)
	else:
		content.add_child(UIK.label(tr("builders.max"), 28))
