extends GutTest
## Salvataggio: round-trip cifrato, file non in chiaro, migrazione dello schema, progresso offline al caricamento.

const PATH := "user://test_save.save"
const T0 := 1_900_000_000.0


func before_each() -> void:
	SaveManager.enabled = true
	TimeManager.trusted_max = 0.0
	TimeManager.freeze_at(T0)
	GameState.new_game(false)


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.enabled = false
	TimeManager.unfreeze()
	TimeManager.trusted_max = 0.0


func test_roundtrip() -> void:
	EconomyManager.add("glimmers", 77)
	GameState.data["player"]["name"] = "Tester"
	var p := GameState.find_free_spot("cog_mine")
	EconomyManager.place_new("cog_mine", p.x, p.y)
	assert_true(SaveManager.save(PATH))
	var before := JSON.stringify(GameState.data)
	GameState.new_game(false)
	assert_true(SaveManager.load_game(PATH))
	assert_eq(GameState.data["player"]["name"], "Tester")
	assert_eq(GameState.res("glimmers"), 127.0)
	assert_eq(GameState.count_of("cog_mine"), 1)
	assert_eq(JSON.stringify(GameState.data).length() > 100, true)
	assert_eq(int(GameState.data["schema"]), GameState.SCHEMA_VERSION)
	# gli indici sono ricostruiti
	var mine: Dictionary = GameState.buildings_of("cog_mine")[0]
	assert_false(GameState.get_entity(int(mine["uid"])).is_empty())
	assert_true(before.length() > 0)


func test_file_is_encrypted() -> void:
	GameState.data["player"]["name"] = "SegretoVisibile"
	SaveManager.save(PATH)
	var raw := FileAccess.get_file_as_bytes(PATH)
	assert_gt(raw.size(), 0)
	assert_eq(raw.get_string_from_ascii().find("SegretoVisibile"), -1, "il nome non compare in chiaro")


func test_offline_progress_on_load() -> void:
	var h := GameState.hall()
	EconomyManager.add("cogs", 5000)
	EconomyManager.start_upgrade(int(h["uid"]))
	SaveManager.save(PATH)
	TimeManager.advance(3600)     # il gioco resta chiuso un'ora
	GameState.new_game(false)
	SaveManager.load_game(PATH)
	assert_eq(GameState.hall_level(), 2)


func test_migration_from_v0() -> void:
	var old := {"schema": 0, "cogs": 1234, "sap": 99, "gems": 5, "buildings": [{"uid": 1.0, "id": "lantern_hall", "level": 3.0, "x": 18.0, "y": 18.0, "job": {}}],
		"obstacles": [], "next_uid": 2.0}
	var m := SaveManager.migrate(old)
	assert_eq(int(m["schema"]), GameState.SCHEMA_VERSION)
	assert_eq(float(m["res"]["cogs"]), 1234.0)
	assert_eq(float(m["res"]["glimmers"]), 5.0)
	assert_true(m.has("build_queue"))
	assert_true(m.has("defense_log"))
	assert_true(m.has("progress"), "chiavi mancanti completate dai default")
	assert_eq(typeof(m["buildings"][0]["level"]), TYPE_INT)
	assert_false(m.has("gems"))


func test_corrupted_file_returns_false() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("non e' un salvataggio")
	f.close()
	assert_false(SaveManager.load_game(PATH))
