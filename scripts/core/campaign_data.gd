class_name CampaignData
extends RefCounted
## Livelli della campagna: layout disegnati a mano (data/campaign_layouts.json, da tools/campaign_maps.py)
## + composizione/bottino (data/campaign.json). Livelli difese: max consentito dalla Hall - 1 (boss: max).

static var _layouts: Dictionary = {}


static func layouts() -> Dictionary:
	if _layouts.is_empty():
		var f := FileAccess.open("res://data/campaign_layouts.json", FileAccess.READ)
		if f:
			_layouts = JSON.parse_string(f.get_as_text())
	return _layouts


static func load_level(n: int) -> Dictionary:
	var lv: Dictionary = Balance.campaign_level(n)
	var hall := int(lv["hall_level"])
	var boss := bool(lv["boss"])
	var list: Array = []
	for b in layouts()[str(n)]["buildings"]:
		var id: String = b["id"]
		var mx := Balance.max_level_at_hall(id, hall) if id != "lantern_hall" else hall
		var lvl := mx if (boss or id == "lantern_hall") else maxi(1, mx - 1)
		list.append({"id": id, "level": maxi(1, lvl), "x": int(b["x"]), "y": int(b["y"])})
	return {
		"buildings": list, "hall_level": hall, "palette": "gloom", "campaign": n,
		"name": tr_name(n), "hall_hp_mult": 1.3 if n == Balance.campaign.size() else 1.0,
		"hp_mult": float(lv.get("difficulty", 1.0)), "dmg_mult": float(lv.get("difficulty", 1.0)),
		"loot": {"cogs": float(lv["loot_cogs"]), "sap": float(lv["loot_sap"]), "shards": float(lv["loot_shards"])},
	}


static func tr_name(n: int) -> String:
	var key := "campaign.%02d.name" % n
	var t := TranslationServer.translate(key)
	return t if t != key else String(Balance.campaign_level(n)["name_en"])
