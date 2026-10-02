class_name ClanService
extends RefCounted
## Servizio clan LOCALE (GDD §12): stessa interfaccia che avra' un futuro RemoteClanService online.
## Dati: Clan{id, name, badge, description, trophy_min, members[], chat[], created_at}
##       Member{id, name, role, trophies, donated, received}  ChatMessage{id, author, text, ts}

const BOT_NAMES := ["Pip", "Marlo", "Tessa", "Brindle", "Oona", "Fennick", "Quilla", "Rook", "Sable", "Wren", "Juniper", "Halden", "Ivo", "Lark"]
const BADGES := 12


static func current() -> Dictionary:
	return GameState.data.get("clan", {})


static func in_clan() -> bool:
	return not current().is_empty()


## Elenco di clan "pubblici" generati in modo deterministico (ricerca).
static func browse(count: int = 8) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in count:
		var name := BaseGenerator.random_name(rng)
		var members := _bots(rng, rng.randi_range(5, 18))
		out.append({"id": "c%d" % i, "name": name, "badge": rng.randi_range(0, BADGES - 1),
			"description": "clan.desc.%d" % (i % 4), "trophy_min": rng.randi_range(0, 8) * 100, "members": members, "chat": [], "created_at": 0})
	return out


static func _bots(rng: RandomNumberGenerator, n: int) -> Array:
	var m: Array = []
	for k in n:
		m.append({"id": "b%d" % k, "name": BOT_NAMES[(k + rng.randi_range(0, 13)) % BOT_NAMES.size()],
			"role": "leader" if k == 0 else ("co" if k < 3 else "member"),
			"trophies": rng.randi_range(100, 2600), "donated": rng.randi_range(0, 400), "received": rng.randi_range(0, 300)})
	return m


static func _me() -> Dictionary:
	var p: Dictionary = GameState.data["player"]
	var nm: String = p.get("name", "")
	return {"id": "me", "name": nm if nm != "" else TranslationServer.translate("player.default_name"), "role": "member",
		"trophies": int(p["trophies"]), "donated": 0, "received": 0}


static func create(name: String, badge: int, description: String, trophy_min: int) -> int:
	if in_clan():
		return EconomyManager.Err.BUSY
	var cost := float(Balance.economy["clan"]["create_cost_cogs"])
	if GameState.count_of("clan_hall") == 0:
		return EconomyManager.Err.NOT_UNLOCKED
	if not EconomyManager.spend({"cogs": cost}):
		return EconomyManager.Err.NO_RESOURCES
	var me := _me()
	me["role"] = "leader"
	GameState.data["clan"] = {"id": "own", "name": name.strip_edges().left(18), "badge": badge, "description": description.left(120),
		"trophy_min": trophy_min, "members": [me], "chat": [], "created_at": TimeManager.now()}
	Progression.track("clan_joined", 1)
	EventBus.state_changed.emit()
	return EconomyManager.Err.OK


static func join(clan: Dictionary) -> int:
	if in_clan():
		return EconomyManager.Err.BUSY
	if GameState.count_of("clan_hall") == 0:
		return EconomyManager.Err.NOT_UNLOCKED
	if Progression.trophies() < int(clan["trophy_min"]):
		return EconomyManager.Err.NOT_UNLOCKED
	var c := clan.duplicate(true)
	c["members"].append(_me())
	GameState.data["clan"] = c
	Progression.track("clan_joined", 1)
	post_system("clan.chat.welcome")
	EventBus.state_changed.emit()
	return EconomyManager.Err.OK


static func leave() -> void:
	GameState.data["clan"] = {}
	EventBus.state_changed.emit()


static func post(text: String) -> void:
	var c := current()
	if c.is_empty() or text.strip_edges() == "":
		return
	_append(c, {"author": _me()["name"], "text": text.strip_edges().left(200), "ts": TimeManager.now(), "me": true})
	# risposta simulata di un membro (testo localizzato, deterministica sul numero di messaggi)
	var bots: Array = []
	for m in c["members"]:
		if m["id"] != "me":
			bots.append(m)
	if not bots.is_empty():
		var k: int = c["chat"].size()
		var who: Dictionary = bots[k % bots.size()]
		_append(c, {"author": who["name"], "text": "clan.bot.%d" % (k % 8), "ts": TimeManager.now() + 1.0, "key": true})
	EventBus.state_changed.emit()


static func post_system(key: String) -> void:
	var c := current()
	if c.is_empty():
		return
	_append(c, {"author": "", "text": key, "ts": TimeManager.now(), "key": true, "system": true})


static func _append(c: Dictionary, msg: Dictionary) -> void:
	var chat: Array = c["chat"]
	msg["id"] = chat.size()
	chat.append(msg)
	while chat.size() > int(Balance.economy["clan"]["chat_history"]):
		chat.pop_front()
