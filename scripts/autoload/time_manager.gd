extends Node
## Tempo di gioco basato su timestamp reali (UNIX, secondi).
## Protezione orologio: il tempo "fidato" non torna mai indietro. Se l'utente sposta l'orologio indietro,
## il gioco resta fermo all'ultimo istante visto finche' l'orologio reale non lo supera di nuovo.
## I salti in avanti sono accettati (i timer devono avanzare a gioco chiuso).

var trusted_max: float = 0.0     ## massimo istante osservato (persistito nel salvataggio)
var debug_offset: float = 0.0    ## usato solo dai test / strumenti di debug
var _frozen: bool = false        ## test: tempo congelato
var _frozen_value: float = 0.0
var rollback_detected: bool = false


func system_now() -> float:
	if _frozen:
		return _frozen_value
	return Time.get_unix_time_from_system() + debug_offset


func now() -> float:
	var t := system_now()
	if t < trusted_max:
		rollback_detected = true
		return trusted_max
	trusted_max = t
	return t


## Test: imposta un orologio di sistema fittizio.
func freeze_at(t: float) -> void:
	_frozen = true
	_frozen_value = t


func advance(seconds: float) -> void:
	if _frozen:
		_frozen_value += seconds
	else:
		debug_offset += seconds


func unfreeze() -> void:
	_frozen = false


static func format_duration(seconds: float) -> String:
	var s := int(ceil(maxf(0.0, seconds)))
	var d := s / 86400
	var h := (s % 86400) / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if d > 0:
		return "%d%s %d%s" % [d, TranslationServer.translate("time.d"), h, TranslationServer.translate("time.h")]
	if h > 0:
		return "%d%s %d%s" % [h, TranslationServer.translate("time.h"), m, TranslationServer.translate("time.m")]
	if m > 0:
		return "%d%s %d%s" % [m, TranslationServer.translate("time.m"), sec, TranslationServer.translate("time.s")]
	return "%d%s" % [sec, TranslationServer.translate("time.s")]


static func day_key(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t + Time.get_time_zone_from_system().get("bias", 0) * 60))
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]
