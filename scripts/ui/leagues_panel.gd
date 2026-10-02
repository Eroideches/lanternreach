extends Modal
## Leghe: intervalli di trofei, ricompensa alla prima promozione, bonus bottino; lega attuale evidenziata.

var village: Node


func _init() -> void:
	super._init(" ", Vector2(1300, 900))


func _ready() -> void:
	title = tr("leagues.title")
	super._ready()


func build() -> void:
	var cur: String = Progression.league()["id"]
	content.add_child(UIK.label(tr("leagues.your") % UIK.num(Progression.trophies()), 30, true, UIK.INK))
	var list := UIK.vbox(8)
	var ls: Array = Balance.leagues.duplicate()
	ls.reverse()
	for l in ls:
		var row := UIK.panel("slot_selected" if l["id"] == cur else "panel_inset", Vector4(14, 6, 14, 6))
		var h := UIK.hbox(16)
		h.add_child(UIK.icon_rect(Art.tex("icons", "league/" + str(l["id"])), 90))
		var v := UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIK.label(tr("league." + str(l["id"])), 32, true, UIK.INK))
		var hi := int(l["trophies_max"])
		v.add_child(UIK.label("%s - %s" % [UIK.num(int(l["trophies_min"])), UIK.num(hi) if hi < 99999 else "+"], 24))
		h.add_child(v)
		if int(l["first_reach_gems"]) > 0:
			h.add_child(UIK.icon("glimmers", 46))
			h.add_child(UIK.label(str(l["first_reach_gems"]), 26, true, Color.WHITE, 6))
		if float(l["win_loot_bonus"]) > 0:
			h.add_child(UIK.label(tr("leagues.bonus") % int(float(l["win_loot_bonus"]) * 100), 24, true, UIK.INK))
		row.add_child(h)
		list.add_child(row)
	content.add_child(scroll(list))
