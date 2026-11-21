# Conteggi per giocatore della partita (per la crescita del campione in carriera): si leggono dagli eventi del
# motore e dalle posizioni, senza toccare il motore. La scena della partita (gioco.gd) chiama leggi(m) a ogni
# fotogramma prima di consumare m.events; per_giocatore() va nell'esito della partita.
# Si contano solo i giocatori della squadra `squadra` (la persona), per id del giocatore sorgente (p.src.id).
#   gol, assist, tiri, in_porta (gol o parata dopo il suo tiro), passaggi (riusciti: il pallone arriva a un
#   compagno), intercetti (passaggio avversario preso, o tiro/passaggio respinto), contrasti, dribbling (riusciti),
#   scatti (tasto Scatto), testa (contrasti aerei vinti), parate, km (corsa)
extends RefCounted

const R := preload("res://sim/records.gd")
const C := preload("res://sim/core.gd")
const TIRI := ["shot", "volley", "header"]
const SALTO_MAX := 3.0          # m in un fotogramma: oltre è uno spostamento d'ufficio (rimesse), non corsa
const CHIAVI := ["gol", "assist", "tiri", "in_porta", "passaggi", "intercetti", "contrasti", "dribbling", "scatti",
	"testa", "parate", "km"]

var squadra := 0
var _conti := {}                # id (testo) → {chiave: numero}
var _passaggio: R.Player = null # ultimo passaggio in volo (di qualunque squadra)
var _tiro: R.Player = null      # ultimo tiro in volo
var _ultimo := {}               # giocatore → [x, y] del fotogramma prima


func _init(squadra_: int = 0) -> void:
	squadra = squadra_


## a ogni fotogramma, prima che gli eventi vengano consumati
func leggi(m: Variant) -> void:
	for e: Dictionary in m.events:
		_evento(e)
	for p: R.Player in m.players:
		if p.team != squadra:
			continue
		var prima: Variant = _ultimo.get(p)
		if prima != null:
			var d := C.hyp(p.x - prima[0], p.y - prima[1])
			if d < SALTO_MAX:
				_somma(p, "km", d / 1000.0)
		_ultimo[p] = [p.x, p.y]


func _evento(e: Dictionary) -> void:
	match e.type:
		"kick":
			var p: R.Player = e.p
			if e.get("clear", false):
				_passaggio = null
			elif TIRI.has(e.get("kind", "")):
				_somma(p, "tiri")
				_tiro = p
				_passaggio = null
			else:
				_passaggio = p
		"control":
			var q: R.Player = e.p
			if _passaggio != null:
				if q.team == _passaggio.team and q != _passaggio:
					_somma(_passaggio, "passaggi")
				elif q.team != _passaggio.team:
					_somma(q, "intercetti")
			_passaggio = null
		"save":
			var gk: R.Player = e.p
			_somma(gk, "parate")
			if _tiro != null and _tiro.team != gk.team:
				_somma(_tiro, "in_porta")
			_tiro = null
		"goal":
			var sc: Variant = e.get("scorer")
			if sc != null and not e.get("og", false):
				_somma(sc, "gol")
				_somma(sc, "in_porta")
			var asx: Variant = e.get("assist")
			if asx != null:
				_somma(asx, "assist")
			_tiro = null
			_passaggio = null
		"tackle":
			_somma(e.p, "contrasti")
		"block":
			_somma(e.p, "intercetti")
		"dribble":
			if e.get("ok", false):
				_somma(e.p, "dribbling")
		"burst":
			_somma(e.p, "scatti")
		"aerial":
			_somma(e.p, "testa")


func _somma(p: Variant, k: String, quanto: float = 1.0) -> void:
	if not p is R.Player or (p as R.Player).team != squadra:
		return
	var id: Variant = (p as R.Player).src.get("id")
	if id == null:
		return
	var key := str(id)
	if not _conti.has(key):
		_conti[key] = {}
	_conti[key][k] = _conti[key].get(k, 0) + (quanto if k == "km" else int(quanto))


## {id: {gol, tiri, ...}} (solo le chiavi con almeno 1; km arrotondati ai metri)
func per_giocatore() -> Dictionary:
	var out := {}
	for key: String in _conti:
		var c: Dictionary = _conti[key].duplicate()
		if c.has("km"):
			c.km = snappedf(c.km, 0.001)
		out[key] = c
	return out
