extends Node
## Accesso agli atlas generati da tools/art (regioni, ancore, overlay) e ai fogli animazione delle truppe.

const ATLAS_DIR := "res://assets/atlas/"
const TROOP_DIR := "res://assets/sprites/troops/"

var _atlases: Dictionary = {}     ## nome -> {pages: Array[Texture2D], regions: Dictionary}
var _tex_cache: Dictionary = {}   ## "atlas|key" -> AtlasTexture
var _frames_cache: Dictionary = {}
var _troop_meta: Dictionary = {}
var manifest: Dictionary = {}
var quality_high: bool = true


func _ready() -> void:
	var f := FileAccess.open(ATLAS_DIR + "buildings_manifest.json", FileAccess.READ)
	if f:
		manifest = JSON.parse_string(f.get_as_text())
	var t := FileAccess.open(TROOP_DIR + "troops.json", FileAccess.READ)
	if t:
		_troop_meta = JSON.parse_string(t.get_as_text())


func atlas(name: String) -> Dictionary:
	if _atlases.has(name):
		return _atlases[name]
	var f := FileAccess.open(ATLAS_DIR + name + ".json", FileAccess.READ)
	if f == null:
		push_error("Art: atlas mancante " + name)
		return {}
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var pages: Array = []
	for p in d["pages"]:
		pages.append(load(ATLAS_DIR + p))
	var a := {"pages": pages, "regions": d["regions"]}
	_atlases[name] = a
	return a


func has(atlas_name: String, key: String) -> bool:
	return atlas(atlas_name).get("regions", {}).has(key)


func region(atlas_name: String, key: String) -> Dictionary:
	return atlas(atlas_name)["regions"].get(key, {})


func tex(atlas_name: String, key: String) -> AtlasTexture:
	var ck := atlas_name + "|" + key
	if _tex_cache.has(ck):
		return _tex_cache[ck]
	var a := atlas(atlas_name)
	var r: Dictionary = a["regions"].get(key, {})
	if r.is_empty():
		push_warning("Art: regione mancante %s/%s" % [atlas_name, key])
		return null
	var at := AtlasTexture.new()
	at.atlas = a["pages"][int(r["page"])]
	at.region = Rect2(r["x"], r["y"], r["w"], r["h"])
	_tex_cache[ck] = at
	return at


func icon(key: String) -> AtlasTexture:
	return tex("icons", "icon/" + key)


func tier_for(id: String, level: int) -> int:
	var tl: Array = manifest.get("tier_of_level", {}).get(id, [])
	if tl.is_empty():
		return 1
	return int(tl[clampi(level, 1, tl.size()) - 1])


## Ritorna {tex, anchor: Vector2, overlays: Array} per un edificio al livello dato.
func building_sprite(id: String, level: int, palette: String = "player") -> Dictionary:
	var atl := "buildings_" + palette
	var key := "%s/t%d" % [id, tier_for(id, level)]
	if Balance.category(id) == "obstacle":
		atl = "buildings_player"
		key = id + "/t1"
	var r := region(atl, key)
	if r.is_empty():
		return {}
	return {"tex": tex(atl, key), "anchor": Vector2(r["anchor"][0], r["anchor"][1]), "overlays": r.get("overlays", [])}


func construction_sprite(n: int, palette: String = "player") -> Dictionary:
	var atl := "buildings_" + palette
	var key := "construction/%d" % clampi(n, 1, 4)
	var r := region(atl, key)
	return {"tex": tex(atl, key), "anchor": Vector2(r["anchor"][0], r["anchor"][1]), "overlays": r.get("overlays", [])}


func wall_sprite(level: int, mask: int, palette: String = "player") -> Dictionary:
	var atl := "walls_" + palette
	var key := "wall/t%d/m%d" % [tier_for("wall", level), mask]
	var r := region(atl, key)
	return {"tex": tex(atl, key), "anchor": Vector2(r["anchor"][0], r["anchor"][1])}


## SpriteFrames per un'animazione fx ("explosion", "smoke", ...).
func fx_frames(anim: String) -> SpriteFrames:
	var ck := "fx|" + anim
	if _frames_cache.has(ck):
		return _frames_cache[ck]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation(anim)
	var a := atlas("fx")
	var i := 0
	var fps := 12.0
	while a["regions"].has("%s/%d" % [anim, i]):
		var r: Dictionary = a["regions"]["%s/%d" % [anim, i]]
		fps = float(r.get("fps", 12))
		sf.add_frame(anim, tex("fx", "%s/%d" % [anim, i]))
		i += 1
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, anim.begins_with("flag") or anim in ["smoke", "fire", "fire_small", "bubbles", "sparkle", "spark", "arc"])
	_frames_cache[ck] = sf
	return sf


func troop_meta(id: String) -> Dictionary:
	return _troop_meta.get(id, {})


## SpriteFrames di una truppa con animazioni walk/attack/death _down/_up.
func troop_frames(id: String) -> SpriteFrames:
	var ck := "troop|" + id
	if _frames_cache.has(ck):
		return _frames_cache[ck]
	var meta: Dictionary = troop_meta(id)
	var sheet: Texture2D = load(TROOP_DIR + id + ".png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fw: int = int(meta["frame"][0])
	var fh: int = int(meta["frame"][1])
	for anim in meta["rows"]:
		var row: Dictionary = meta["rows"][anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(row["fps"]))
		sf.set_animation_loop(anim, bool(row["loop"]))
		for f in int(row["frames"]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(f * fw, int(row["row"]) * fh, fw, fh)
			sf.add_frame(anim, at)
	_frames_cache[ck] = sf
	return sf


func troop_origin(id: String) -> Vector2:
	var meta := troop_meta(id)
	return Vector2(meta["origin"][0], meta["origin"][1]) if meta.has("origin") else Vector2.ZERO


func portrait(id: String) -> AtlasTexture:
	return tex("portraits", "portrait/" + id)


func thumb(id: String) -> AtlasTexture:
	return tex("icons", "thumb/" + id)
