extends GutTest
## Progressione: XP e livelli, trofei e leghe, obiettivi, missioni giornaliere, login, campagna, clan locale.

const T0 := 1_900_000_000.0


func before_each() -> void:
	SaveManager.enabled = false
	TimeManager.trusted_max = 0.0
	TimeManager.freeze_at(T0)
	GameState.new_game(false)


func after_each() -> void:
	TimeManager.unfreeze()
	TimeManager.trusted_max = 0.0


func test_xp_levels_up() -> void:
	var need := int(Balance.xp_levels[0]["xp_to_next"])
	Progression.add_xp(need + 3)
	assert_eq(int(GameState.data["player"]["level"]), 2)
	assert_eq(int(GameState.data["player"]["xp"]), 3)


func test_trophies_and_leagues() -> void:
	var g := GameState.res("glimmers")
	Progression.change_trophies(650)
	assert_eq(Progression.league()["id"], "ember")
	assert_true("spark" in GameState.data["player"]["leagues_reached"] or "ember" in GameState.data["player"]["leagues_reached"])
	assert_eq(GameState.res("glimmers"), g + 10.0, "ricompensa della prima volta in lega")
	Progression.change_trophies(-10000)
	assert_eq(Progression.trophies(), 0, "i trofei non scendono sotto zero")
	assert_eq(int(GameState.data["player"]["best_trophies"]), 650)


func test_achievement_claim() -> void:
	assert_false(Progression.achievement_state("tidy_up")["ready"])
	Progression.track("obstacles_cleared", 10)
	var s := Progression.achievement_state("tidy_up")
	assert_true(s["ready"])
	var g := GameState.res("glimmers")
	assert_eq(Progression.claim_achievement("tidy_up"), 5)
	assert_eq(GameState.res("glimmers"), g + 5.0)
	assert_false(Progression.achievement_state("tidy_up")["ready"], "il livello successivo non e' ancora pronto")
	assert_eq(Progression.claim_achievement("tidy_up"), 0)


func test_daily_missions() -> void:
	Progression.refresh_daily(T0)
	var ms: Array = GameState.data["progress"]["daily"]["missions"]
	assert_eq(ms.size(), 3)
	var m: Dictionary = ms[0]
	var d := Progression.mission_def(m["id"])
	assert_false(Progression.claim_mission(0))
	Progression.track(d["metric"], float(d["target"]))
	assert_true(Progression.claim_mission(0))
	assert_false(Progression.claim_mission(0), "non si riscuote due volte")
	# stesso giorno: missioni invariate; giorno dopo: nuove
	Progression.refresh_daily(T0 + 60)
	assert_true(GameState.data["progress"]["daily"]["missions"][0]["claimed"])
	Progression.refresh_daily(T0 + 86400 * 2)
	assert_false(GameState.data["progress"]["daily"]["missions"][0]["claimed"])


func test_login_cycle() -> void:
	Progression.refresh_daily(T0)
	assert_true(Progression.login_pending())
	var r := Progression.claim_login()
	assert_eq(r["day"], 1)
	assert_false(Progression.login_pending())
	assert_true(Progression.claim_login().is_empty())
	Progression.refresh_daily(T0 + 86400)
	assert_eq(Progression.claim_login()["day"], 2)


func test_campaign_progress_and_gems() -> void:
	assert_true(Progression.campaign_unlocked(1))
	assert_false(Progression.campaign_unlocked(2))
	var g := GameState.res("glimmers")
	assert_eq(Progression.record_campaign(1, 2), 0)
	assert_true(Progression.campaign_unlocked(2))
	assert_eq(Progression.record_campaign(1, 3), 6, "5 + n gemme alla prima vittoria a 3 stelle")
	assert_eq(Progression.record_campaign(1, 3), 0, "una sola volta")
	assert_eq(GameState.res("glimmers"), g + 6.0)
	assert_eq(Progression.campaign_total_stars(), 3)


func test_clan_local_service() -> void:
	assert_false(ClanService.in_clan())
	assert_eq(ClanService.create("Lumi", 2, "ciao", 0), EconomyManager.Err.NOT_UNLOCKED, "serve la Sala del Clan")
	var b := GameState.add_building("clan_hall", 30, 30, 1)
	EconomyManager.add("cogs", 20000)
	GameState.data["res"]["cogs"] = 20000.0
	assert_eq(ClanService.create("Lumi", 2, "ciao", 0), EconomyManager.Err.OK)
	assert_true(ClanService.in_clan())
	ClanService.post("Ciao a tutti")
	var chat: Array = ClanService.current()["chat"]
	assert_eq(chat.size(), 1, "nessun bot in un clan appena creato")
	ClanService.leave()
	assert_false(ClanService.in_clan())
	var clans := ClanService.browse()
	assert_eq(clans.size(), 8)
	var open: Dictionary = clans[0]
	open["trophy_min"] = 0
	assert_eq(ClanService.join(open), EconomyManager.Err.OK)
	ClanService.post("Eccomi")
	assert_eq(ClanService.current()["chat"].size(), 3, "benvenuto + messaggio + risposta simulata")
	assert_true(b.size() > 0)
