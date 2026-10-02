extends Node
## Bus di eventi globale: disaccoppia logica (autoload/core) e presentazione (scene/UI).

signal resources_changed(res: String, value: float)
signal state_changed                        ## qualunque modifica persistente (innesca l'autosalvataggio)
signal building_added(uid: int)
signal building_removed(uid: int)
signal building_moved(uid: int)
signal building_job_started(uid: int)
signal building_job_finished(uid: int, new_level: int)
signal obstacle_spawned(uid: int)
signal obstacle_removed(uid: int, gems: int)
signal resource_collected(uid: int, res: String, amount: int)
signal army_changed
signal research_finished(troop_id: String, level: int)
signal xp_changed(xp: int, level: int)
signal level_up(level: int)
signal trophies_changed(trophies: int)
signal league_reached(league_id: String)
signal achievement_ready(id: String, tier: int)
signal daily_updated
signal battle_finished(result: Dictionary)
signal defense_logged(entry: Dictionary)
signal toast(text: String, kind: String)
signal tutorial_event(name: String)
signal settings_changed
signal language_changed
signal panel_opened(name: String)
signal panel_closed(name: String)
