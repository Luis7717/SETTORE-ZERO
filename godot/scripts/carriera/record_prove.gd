# Record dell'allenamento libero (scripts/partita/prove_tiro.gd) nel salvataggio della carriera (tag_save_v1).
# Campo facoltativo `prove` = {tiri: int, punizioni: int, rigori: int}: nei salvataggi vecchi manca e ogni record
# vale 0 (nessun record); un valore rotto (non numero, negativo) conta come 0. Si scrive solo un record migliore.
extends RefCounted

const CAMPO := "prove"
const PROVE := ["tiri", "punizioni", "rigori"]


## record della prova (0 = nessuno), anche da un salvataggio vecchio senza il campo
static func record(s: Dictionary, prova: String) -> int:
	var r: Variant = s.get(CAMPO)
	if not r is Dictionary:
		return 0
	var v: Variant = (r as Dictionary).get(prova)
	if not (v is int or v is float):
		return 0
	return maxi(0, int(v))


## punteggio di una prova finita: se batte il record lo scrive in s e ritorna true (nuovo record)
static func aggiorna(s: Dictionary, prova: String, punti: int) -> bool:
	if not PROVE.has(prova) or punti <= record(s, prova):
		return false
	var r: Variant = s.get(CAMPO)
	var nuovo: Dictionary = (r as Dictionary).duplicate() if r is Dictionary else {}
	nuovo[prova] = punti
	s[CAMPO] = nuovo
	return true
