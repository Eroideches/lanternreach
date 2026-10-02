extends Node2D
## Scena villaggio: mondo isometrico + HUD + pannelli.
## Modalita': "normal" (tap = seleziona/raccogli, long-press = modifica), "edit" (sposta/ribalta un edificio),
## "place" (nuovo edificio dal negozio; per le mura il trascinamento traccia una linea di segmenti).

const PANELS := {
	"shop": "res://scripts/ui/shop_panel.gd", "army": "res://scripts/ui/army_panel.gd", "lab": "res://scripts/ui/lab_panel.gd",
	"attack": "res://scripts/ui/attack_panel.gd", "quests": "res://scripts/ui/quests_panel.gd", "settings": "res://scripts/ui/settings_panel.gd",
	"clan": "res://scripts/ui/clan_panel.gd", "log": "res://scripts/ui/defense_log_panel.gd", "builders": "res://scripts/ui/builders_panel.gd",
	"leagues": "res://scripts/ui/leagues_panel.gd",
}

var cam: IsoCamera
var ground: IsoGround
var entities: Node2D
var fx: FxLayer
var ui_layer: CanvasLayer
var hud: Hud
var views: Dictionary = {}
var selected := -1
var mode := "normal"
var edit_uid := -1
var edit_cell := Vector2i()
var edit_orig := Vector2i()
var edit_flip := false
var place_id := ""
var ghost: BuildingView
var wall_ghosts: Array = []
var wall_cells: Array = []
var _grab := Vector2i()
var _tick := 0.0
var tutorial: Node
var current_panel: Node


func _ready() -> void:
	AudioManager.play_music("village_theme")
	ground = IsoGround.new()
	add_child(ground)
	ground.setup("player")
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	fx = FxLayer.new()
	fx.z_index = 20
	add_child(fx)
	cam = IsoCamera.new()
	add_child(cam)
	cam.position = Iso.footprint_center(int(GameState.hall().get("x", 18)), int(GameState.hall().get("y", 18)), 4)
	cam.tapped.connect(_on_tap)
	cam.long_pressed.connect(_on_long_press)
	cam.drag_started.connect(_on_drag_start)
	cam.drag_moved.connect(_on_drag_move)
	cam.drag_ended.connect(_on_drag_end)
	cam.grab_check = _grab_check
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = Hud.new()
	ui_layer.add_child(hud)
	hud.action.connect(_on_action)
	for e in GameState.buildings():
		_make_view(e)
	for o in GameState.data["obstacles"]:
		_make_view(o)
	_update_wall_masks()
	EventBus.building_added.connect(_on_added)
	EventBus.obstacle_spawned.connect(_on_added)
	EventBus.building_removed.connect(_on_removed)
	EventBus.building_moved.connect(_on_moved)
	EventBus.building_job_started.connect(_on_job_started)
	EventBus.building_job_finished.connect(_on_job_finished)
	EventBus.resource_collected.connect(_on_collected)
	EventBus.obstacle_removed.connect(_on_obstacle_removed)
	EventBus.level_up.connect(func(l): UIK.toast(ui_layer, tr("toast.level_up") % l))
	EventBus.league_reached.connect(func(id): UIK.toast(ui_layer, tr("toast.league") % tr("league." + id)))
	EventBus.research_finished.connect(func(t, l): UIK.toast(ui_layer, tr("toast.research_done") % [tr("troop." + t), l]))
	if not GameState.data["tutorial"].get("done", false):
		tutorial = load("res://scripts/ui/tutorial.gd").new()
		tutorial.village = self
		ui_layer.add_child(tutorial)
	else:
		_welcome_popups()


func _welcome_popups() -> void:
	await get_tree().create_timer(0.6).timeout
	var unseen := 0
	for e in GameState.data["defense_log"]:
		if not e.get("seen", true):
			unseen += 1
	if unseen > 0:
		open_panel("log")
	elif Progression.login_pending():
		open_panel("quests")


# =========================================================== viste
func _make_view(e: Dictionary) -> BuildingView:
	var v := BuildingView.new()
	v.uid = int(e["uid"])
	v.flip = bool(e.get("flip", false))
	entities.add_child(v)
	v.setup(e["id"], maxi(1, int(e.get("level", 1))), int(e["x"]), int(e["y"]), "player", "village")
	views[v.uid] = v
	_refresh_view(v, e)
	return v


func _refresh_view(v: BuildingView, e: Dictionary) -> void:
	v.level = maxi(1, int(e.get("level", 1)))
	var under := int(e.get("level", 1)) == 0
	v.refresh(under)
	if Balance.category(e["id"]) == "trap":
		v.modulate = Color(1, 1, 1) if e.get("armed", true) else Color(0.6, 0.6, 0.65)


func _update_wall_masks() -> void:
	var walls := {}
	for b in GameState.buildings():
		if b["id"] == "wall":
			walls[Vector2i(int(b["x"]), int(b["y"]))] = int(b["uid"])
	for c in walls:
		var m := 0
		if walls.has(c + Vector2i(1, 0)): m |= 1
		if walls.has(c + Vector2i(0, 1)): m |= 2
		if walls.has(c + Vector2i(-1, 0)): m |= 4
		if walls.has(c + Vector2i(0, -1)): m |= 8
		var v: BuildingView = views.get(walls[c])
		if v and v.wall_mask != m:
			v.wall_mask = m
			v.refresh()


func _on_added(uid: int) -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty() or views.has(uid):
		return
	var v := _make_view(e)
	if e["id"] == "wall":
		_update_wall_masks()
	v.pop()


func _on_removed(uid: int) -> void:
	if views.has(uid):
		var v: BuildingView = views[uid]
		views.erase(uid)
		v.queue_free()
	if uid == selected:
		_deselect()
	_update_wall_masks()


func _on_moved(uid: int) -> void:
	var e := GameState.get_entity(uid)
	if views.has(uid):
		var v: BuildingView = views[uid]
		v.set_cell(int(e["x"]), int(e["y"]))
		v.flip = bool(e.get("flip", false))
		_refresh_view(v, e)
	_update_wall_masks()


func _on_job_started(uid: int) -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty() or not views.has(uid):
		return
	var v: BuildingView = views[uid]
	_refresh_view(v, e)
	if e.get("job", {}).is_empty():
		return
	fx.play("dust", v.position, 1.2)
	AudioManager.sfx("build_start")
	if uid == selected:
		_show_actions_for(uid)


func _on_job_finished(uid: int, lvl: int) -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty() or not views.has(uid):
		return
	var v: BuildingView = views[uid]
	_refresh_view(v, e)
	v.clear_progress()
	v.pop()
	if e["id"] != "wall":
		fx.play("shock", v.position, 1.4)
		fx.burst("star_pop", v.position + Vector2(0, -60), 6, 70, 0.6)
		AudioManager.sfx("upgrade_complete" if lvl > 1 else "build_complete")
		UIK.toast(ui_layer, tr("toast.built") % [tr("building." + str(e["id"])), lvl])
	if e["id"] == "wall":
		_update_wall_masks()
	if uid == selected:
		_show_actions_for(uid)


func _on_collected(uid: int, res: String, amount: int) -> void:
	if not views.has(uid):
		return
	var v: BuildingView = views[uid]
	var key: String = {"cogs": "coin_cog", "sap": "drop_sap", "shards": "gem_shard"}.get(res, "coin_cog")
	var target := cam.screen_to_world(hud.resource_screen_pos(res))
	fx.fly_to(key, v.position + Vector2(0, -60), target, clampi(amount / 40, 6, 10))
	fx.text_pop(v.position + Vector2(0, -90), "+" + UIK.num(amount), Color(1, 0.95, 0.7))
	AudioManager.sfx("collect_" + res if res != "shards" else "collect_shard")
	v.show_bubble("")


func _on_obstacle_removed(uid: int, gems: int) -> void:
	if views.has(uid):
		var v: BuildingView = views[uid]
		fx.burst("debris_wood", v.position, 8, 50, 0.6)
		fx.play("dust", v.position, 1.3)
		if gems > 0:
			fx.text_pop(v.position + Vector2(0, -80), "+%d" % gems, Color(0.6, 0.95, 1.0))
			fx.burst("gem_glimmer", v.position + Vector2(0, -40), gems, 50, 0.6)
			AudioManager.sfx("collect_gem")
		AudioManager.sfx("obstacle_clear")


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.2:
		return
	_tick = 0.0
	var now := TimeManager.now()
	for uid in views:
		var e := GameState.get_entity(uid)
		if e.is_empty():
			continue
		var v: BuildingView = views[uid]
		var job: Dictionary = e.get("job", {})
		if not job.is_empty():
			var total := maxf(1.0, float(job["end"]) - float(job["start"]))
			v.set_progress(clampf((now - float(job["start"])) / total, 0.0, 1.0), TimeManager.format_duration(float(job["end"]) - now))
		else:
			v.clear_progress()
		if Balance.category(e["id"]) == "economy" and int(e["level"]) > 0 and job.is_empty():
			var stored := float(e.get("stored", 0.0)) + EconomyManager.production_rate(e) * maxf(0.0, now - float(e.get("last_prod", now)))
			var cap := EconomyManager.extractor_capacity(e)
			v.show_bubble(EconomyManager.extractor_resource(e["id"]) if stored >= maxf(1.0, cap * 0.05) else "")
	if selected >= 0 and mode == "normal" and not GameState.get_entity(selected).is_empty():
		var e2 := GameState.get_entity(selected)
		if not e2.get("job", {}).is_empty():
			hud.action_title.text = _title_for(e2) + "  -  " + TimeManager.format_duration(EconomyManager.remaining(e2))


# ============================================================ input
func _sprite_contains(v: BuildingView, world: Vector2) -> bool:
	if v.sprite == null or v.sprite.texture == null:
		return false
	var r := Rect2(v.position + v.sprite.offset, v.sprite.texture.get_size())
	return r.has_point(world)


## Selezione per sagoma: per ogni edificio si usa il volume "rombo di base estruso fino alla cima dello sprite"
## (esagono a schermo); se piu' edifici contengono il punto vince quello piu' avanti (profondita' x + y + n).
func pick(world: Vector2) -> int:
	var best := -1
	var best_depth := -INF
	for uid in views:
		var v: BuildingView = views[uid]
		if v.sprite == null or v.sprite.texture == null:
			continue
		var n := float(v.n)
		var c0 := Iso.to_world(Vector2(v.cell))
		var top_c := c0                                           # vertice alto del rombo
		var left_c := Iso.to_world(Vector2(v.cell) + Vector2(0, n))
		var right_c := Iso.to_world(Vector2(v.cell) + Vector2(n, 0))
		var bottom_c := Iso.to_world(Vector2(v.cell) + Vector2(n, n))
		var sprite_top := v.position.y + v.sprite.offset.y
		var h := maxf(0.0, top_c.y - sprite_top)
		var poly := PackedVector2Array([left_c, bottom_c, right_c, right_c - Vector2(0, h), top_c - Vector2(0, h), left_c - Vector2(0, h)])
		if Geometry2D.is_point_in_polygon(world, poly):
			var depth := float(v.cell.x + v.cell.y) + n
			if depth > best_depth:
				best_depth = depth
				best = int(uid)
	return best


func _on_tap(world: Vector2) -> void:
	if current_panel != null and is_instance_valid(current_panel):
		return
	if mode == "place" or mode == "edit":
		var cell := Iso.cell_of(world)
		var id := place_id if mode == "place" else str(GameState.get_entity(edit_uid)["id"])
		var n := Balance.footprint(id)
		_move_ghost(cell - Vector2i(n / 2, n / 2))
		return
	var uid := pick(world)
	if uid < 0:
		_deselect()
		return
	var e := GameState.get_entity(uid)
	if Balance.category(e["id"]) == "economy" and e.get("job", {}).is_empty():
		if EconomyManager.collect(uid) > 0:
			_select(uid)
			return
	_select(uid)


func _on_long_press(world: Vector2) -> void:
	if mode != "normal" or (current_panel != null and is_instance_valid(current_panel)):
		return
	var uid := pick(world)
	if uid < 0 or GameState.is_obstacle(GameState.get_entity(uid)):
		return
	start_edit(uid)


func _grab_check(world: Vector2) -> bool:
	var cell := Iso.cell_of(world)
	var id := place_id if mode == "place" else str(GameState.get_entity(edit_uid).get("id", ""))
	if id == "":
		return false
	var n := Balance.footprint(id)
	var origin := edit_cell
	var inside := cell.x >= origin.x - 1 and cell.y >= origin.y - 1 and cell.x <= origin.x + n and cell.y <= origin.y + n
	if inside:
		_grab = cell - origin
		if mode == "place" and place_id == "wall":
			_grab = Vector2i.ZERO
	return inside


func _on_drag_start(_world: Vector2) -> void:
	if mode == "place" and place_id == "wall":
		wall_cells = [edit_cell]


func _on_drag_move(world: Vector2) -> void:
	var cell := Iso.cell_of(world) - _grab
	if mode == "place" and place_id == "wall":
		_wall_line_to(cell)
	else:
		_move_ghost(cell)


func _on_drag_end(_world: Vector2) -> void:
	pass


# ===================================================== selezione/azioni
func _select(uid: int) -> void:
	if selected >= 0 and views.has(selected):
		(views[selected] as BuildingView).set_selected(false)
	selected = uid
	if views.has(uid):
		(views[uid] as BuildingView).set_selected(true)
	AudioManager.click()
	_show_actions_for(uid)


func _deselect() -> void:
	if selected >= 0 and views.has(selected):
		(views[selected] as BuildingView).set_selected(false)
	selected = -1
	hud.hide_actions()


func _title_for(e: Dictionary) -> String:
	var nm := tr("building." + str(e["id"]))
	if GameState.is_obstacle(e):
		return nm
	return "%s  %s %d" % [nm, tr("ui.lv"), maxi(1, int(e.get("level", 1)))]


func _show_actions_for(uid: int) -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty():
		hud.hide_actions()
		return
	var items: Array = []
	var id: String = e["id"]
	if GameState.is_obstacle(e):
		if e.get("job", {}).is_empty():
			items.append({"key": "remove", "text": tr("act.remove"), "color": "green", "cost": EconomyManager.obstacle_cost(e), "w": 240})
		else:
			items.append({"key": "speedup", "text": "%d" % EconomyManager.speedup_cost_for(e), "color": "purple", "icon": "glimmers"})
		hud.show_actions(_title_for(e), items)
		return
	items.append({"key": "info", "text": tr("act.info"), "color": "blue", "icon": "info", "w": 170})
	if not e.get("job", {}).is_empty():
		items.append({"key": "speedup", "text": "%d" % EconomyManager.speedup_cost_for(e), "color": "purple", "icon": "glimmers"})
		items.append({"key": "cancel_job", "text": tr("act.cancel"), "color": "red", "w": 170})
	else:
		var lvl := int(e["level"])
		if lvl < Balance.max_level(id):
			var next_cost := EconomyManager.cost_for(id, lvl + 1)
			items.append({"key": "upgrade", "text": tr("act.upgrade"), "color": "green", "icon": "upgrade", "cost": next_cost, "w": 250})
		if Balance.category(id) == "economy" and lvl > 0:
			items.append({"key": "collect", "text": tr("act.collect"), "color": "gold", "icon": EconomyManager.extractor_resource(id), "w": 200})
		match id:
			"barracks", "army_camp":
				items.append({"key": "army", "text": tr("act.train"), "color": "gold", "icon": "army", "w": 200})
			"spell_forge":
				items.append({"key": "army", "text": tr("act.spells"), "color": "gold", "icon": "spells", "w": 200})
			"laboratory":
				items.append({"key": "lab", "text": tr("act.research"), "color": "gold", "icon": "lab", "w": 220})
			"clan_hall":
				items.append({"key": "clan", "text": tr("act.clan"), "color": "gold", "icon": "clan", "w": 200})
			"wall":
				if lvl < Balance.max_level("wall"):
					items.append({"key": "walls_all", "text": tr("act.walls_all"), "color": "gold", "w": 260})
		if Balance.category(id) == "trap" and not e.get("armed", true):
			items.append({"key": "rearm", "text": tr("act.rearm"), "color": "gold", "cost": {"cogs": OfflineAttacks.rearm_cost()}, "w": 240})
	items.append({"key": "move", "text": "", "color": "blue", "icon": "move", "w": 120})
	hud.show_actions(_title_for(e), items)


func _on_action(key: String) -> void:
	if PANELS.has(key):
		open_panel(key)
		return
	match key:
		"confirm":
			_confirm_edit()
		"cancel":
			_cancel_edit()
		"rotate":
			if mode == "edit":
				edit_flip = not edit_flip
				ghost.flip = edit_flip
				ghost.refresh()
		"move":
			if selected >= 0:
				start_edit(selected)
		"info", "upgrade":
			if selected >= 0:
				open_building_panel(selected)
		"collect":
			if selected >= 0:
				EconomyManager.collect_all(str(GameState.get_entity(selected)["id"]))
		"speedup":
			_ask_speedup(selected)
		"cancel_job":
			var e := GameState.get_entity(selected)
			confirm(tr("dlg.cancel_job"), func() -> void:
				EconomyManager.cancel_job(selected)
				_show_actions_for(selected))
		"remove":
			var err := EconomyManager.remove_obstacle(selected)
			if err != EconomyManager.Err.OK:
				UIK.toast(ui_layer, EconomyManager.err_text(err), "error")
			else:
				_show_actions_for(selected)
		"rearm":
			if OfflineAttacks.rearm_all():
				for uid in views:
					var e := GameState.get_entity(uid)
					if Balance.category(e.get("id", "")) == "trap":
						_refresh_view(views[uid], e)
				_show_actions_for(selected)
			else:
				UIK.toast(ui_layer, tr("err.no_resources"), "error")
		"walls_all":
			_upgrade_wall_row()


func _ask_speedup(uid: int) -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty():
		return
	var c := EconomyManager.speedup_cost_for(e)
	confirm(tr("dlg.speedup") % c, func() -> void:
		if not EconomyManager.speedup(uid):
			UIK.toast(ui_layer, tr("err.no_glimmers"), "error")
		else:
			AudioManager.sfx("speedup"))


func _upgrade_wall_row() -> void:
	var e := GameState.get_entity(selected)
	var lvl := int(e["level"])
	var n := 0
	for b in GameState.buildings_of("wall"):
		if int(b["level"]) == lvl and EconomyManager.start_upgrade(int(b["uid"])) == EconomyManager.Err.OK:
			n += 1
	UIK.toast(ui_layer, tr("toast.walls_upgraded") % n if n > 0 else tr("err.no_resources"), "info" if n > 0 else "error")
	_show_actions_for(selected)


func open_panel(key: String, arg: Variant = null) -> Node:
	if current_panel != null and is_instance_valid(current_panel):
		current_panel.queue_free()
	hud.hide_actions()
	var p: Node = load(PANELS[key]).new()
	if arg != null and p.has_method("set_arg"):
		p.set_arg(arg)
	p.set("village", self)
	ui_layer.add_child(p)
	current_panel = p
	if p.has_signal("closed"):
		p.closed.connect(func() -> void:
			if current_panel == p:
				current_panel = null
				if selected >= 0:
					_show_actions_for(selected))
	if p.has_signal("chosen"):
		p.chosen.connect(start_place)
	return p


func open_building_panel(uid: int) -> void:
	if current_panel != null and is_instance_valid(current_panel):
		current_panel.queue_free()
	var p: Modal = load("res://scripts/ui/building_panel.gd").new()
	p.set("uid", uid)
	p.set("village", self)
	ui_layer.add_child(p)
	current_panel = p
	hud.hide_actions()
	p.closed.connect(func() -> void:
		if current_panel == p:
			current_panel = null
			if selected >= 0:
				_show_actions_for(selected))


func confirm(text: String, on_yes: Callable) -> void:
	var d: Modal = load("res://scripts/ui/confirm_dialog.gd").new()
	d.set("text", text)
	d.set("on_yes", on_yes)
	ui_layer.add_child(d)


# ==================================================== modifica/posizionamento
func start_edit(uid: int) -> void:
	var e := GameState.get_entity(uid)
	if e.is_empty():
		return
	_deselect()
	mode = "edit"
	edit_uid = uid
	edit_orig = Vector2i(int(e["x"]), int(e["y"]))
	edit_cell = edit_orig
	edit_flip = bool(e.get("flip", false))
	ghost = views[uid]
	ghost.z_index = 5
	ghost.set_ghost("valid")
	cam.dragging_object = true
	hud.set_main_buttons_visible(false)
	hud.show_actions(tr("act.move_title"), [
		{"key": "cancel", "text": "", "color": "red", "icon": "close", "w": 140},
		{"key": "rotate", "text": "", "color": "blue", "icon": "rotate", "w": 140},
		{"key": "confirm", "text": "", "color": "green", "icon": "check", "w": 140}])
	EventBus.tutorial_event.emit("edit_mode")


func start_place(id: String) -> void:
	_deselect()
	var spot := GameState.find_free_spot(id, Iso.cell_of(cam.position))
	if spot.x < 0:
		UIK.toast(ui_layer, tr("err.no_space_map"), "error")
		return
	mode = "place"
	place_id = id
	edit_cell = spot
	ghost = BuildingView.new()
	entities.add_child(ghost)
	ghost.setup(id, 1, spot.x, spot.y, "player", "village")
	ghost.z_index = 5
	ghost.set_ghost("valid")
	wall_cells = [spot]
	cam.dragging_object = true
	hud.set_main_buttons_visible(false)
	var title := tr("building." + id)
	if id == "wall":
		title += "  -  " + tr("act.wall_hint")
	hud.show_actions(title, [
		{"key": "cancel", "text": "", "color": "red", "icon": "close", "w": 140},
		{"key": "confirm", "text": "", "color": "green", "icon": "check", "w": 140, "cost": EconomyManager.cost_for(id, 1)}])
	_move_ghost(spot)


func _move_ghost(cell: Vector2i) -> void:
	if ghost == null:
		return
	var id := place_id if mode == "place" else str(GameState.get_entity(edit_uid)["id"])
	var n := Balance.footprint(id)
	cell.x = clampi(cell.x, GameState.BUILD_MIN, GameState.BUILD_MAX - n + 1)
	cell.y = clampi(cell.y, GameState.BUILD_MIN, GameState.BUILD_MAX - n + 1)
	edit_cell = cell
	ghost.set_cell(cell.x, cell.y)
	var ok := GameState.can_place(id, cell.x, cell.y, edit_uid if mode == "edit" else -1)
	ghost.set_ghost("valid" if ok else "invalid")
	if mode == "place" and place_id == "wall":
		_clear_wall_ghosts()
		wall_cells = [cell]


func _wall_line_to(cell: Vector2i) -> void:
	var start: Vector2i = wall_cells[0] if not wall_cells.is_empty() else edit_cell
	var d := cell - start
	var cells: Array = []
	var limit := Balance.count_allowed("wall", GameState.hall_level()) - GameState.count_of("wall")
	var unit := float(EconomyManager.cost_for("wall", 1).get("cogs", 1))
	limit = mini(limit, int(GameState.res("cogs") / maxf(1.0, unit)))
	if absi(d.x) >= absi(d.y):
		var s := signi(d.x) if d.x != 0 else 1
		for i in absi(d.x) + 1:
			cells.append(start + Vector2i(i * s, 0))
	else:
		var s2 := signi(d.y)
		for i in absi(d.y) + 1:
			cells.append(start + Vector2i(0, i * s2))
	cells = cells.slice(0, maxi(1, limit))
	wall_cells = cells
	_clear_wall_ghosts()
	var occ := GameState.occupancy()
	for i in cells.size():
		var c: Vector2i = cells[i]
		var ok := GameState.can_place("wall", c.x, c.y, -1, occ)
		if i == 0:
			ghost.set_cell(c.x, c.y)
			ghost.set_ghost("valid" if ok else "invalid")
			continue
		var g := BuildingView.new()
		entities.add_child(g)
		g.setup("wall", 1, c.x, c.y, "player", "village")
		g.set_ghost("valid" if ok else "invalid")
		wall_ghosts.append(g)


func _clear_wall_ghosts() -> void:
	for g in wall_ghosts:
		g.queue_free()
	wall_ghosts.clear()


func _confirm_edit() -> void:
	if mode == "edit":
		var e := GameState.get_entity(edit_uid)
		if not GameState.can_place(e["id"], edit_cell.x, edit_cell.y, edit_uid):
			UIK.toast(ui_layer, tr("err.invalid_place"), "error")
			return
		GameState.move_building(edit_uid, edit_cell.x, edit_cell.y, edit_flip)
		ghost.set_ghost("")
		ghost.z_index = 0
		_end_edit()
		AudioManager.sfx("toggle")
	elif mode == "place":
		var placed := 0
		var err := EconomyManager.Err.OK
		var cells: Array = wall_cells if place_id == "wall" else [edit_cell]
		for c in cells:
			err = EconomyManager.place_new(place_id, c.x, c.y)
			if err == EconomyManager.Err.OK:
				placed += 1
			elif place_id != "wall":
				break
		if placed == 0:
			UIK.toast(ui_layer, EconomyManager.err_text(err), "error")
			if err == EconomyManager.Err.NO_RESOURCES:
				_offer_buy_missing(EconomyManager.cost_for(place_id, 1))
			return
		ghost.queue_free()
		_clear_wall_ghosts()
		_end_edit()


func _offer_buy_missing(costs: Dictionary) -> void:
	var miss := EconomyManager.missing(costs)
	if miss.has("glimmers") or miss.is_empty():
		return
	var gems := 0
	for r in miss:
		gems += Formulas.resource_gem_cost(float(miss[r]), Balance.economy["resource_to_gem_points"])
	confirm(tr("dlg.buy_missing") % gems, func() -> void:
		if EconomyManager.spend({"glimmers": gems}):
			for r in miss:
				EconomyManager.add(r, float(miss[r]), true)
		else:
			UIK.toast(ui_layer, tr("err.no_glimmers"), "error"))


func _cancel_edit() -> void:
	if mode == "edit" and ghost:
		ghost.set_cell(edit_orig.x, edit_orig.y)
		ghost.flip = bool(GameState.get_entity(edit_uid).get("flip", false))
		ghost.refresh()
		ghost.set_ghost("")
		ghost.z_index = 0
	elif mode == "place" and ghost:
		ghost.queue_free()
		_clear_wall_ghosts()
	_end_edit()


func _end_edit() -> void:
	mode = "normal"
	ghost = null
	edit_uid = -1
	place_id = ""
	cam.dragging_object = false
	hud.set_main_buttons_visible(true)
	hud.hide_actions()


func world_pos_of(uid: int) -> Vector2:
	return (views[uid] as BuildingView).position if views.has(uid) else Vector2.ZERO
