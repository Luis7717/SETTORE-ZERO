# Conteggi per giocatore della partita (per la crescita del campione in carriera): si leggono dagli eventi del
# motore e dalle posizioni, senza toccare il motore. La scena della partita (gioco.gd) chiama leggi(m) a ogni
# fotogramma prima di consumare m.events; per_giocatore() va nell'esito della partita.
# Si contano solo i giocatori della squadra `squadra` (la persona), per id del giocatore sorgente (p.src.id).
#   gol, assist, tiri, in_porta (gol o parata dopo il suo tiro), passaggi (riusciti: il pallone arriva a un
#   compagno), intercetti (passaggio avversario preso, o tiro/passaggio respinto), contrasti, dribbling (riusciti),
#   scatti (tasto Scatto), testa (contrasti aerei vinti), parate, km (corsa)
# In più, per la schermata delle statistiche (tabellino(), anche questo nell'esito):
#   per squadra passaggi tentati e riusciti e km corsi; la mappa dei tiri (posizione di chi tira ed esito: gol,
#   parato, respinto, fuori); per i giocatori della persona palle perse (contrasto subito o passaggio preso
#   dall'avversario) e gol subiti mentre erano in campo, e l'elenco di chi è sceso in campo (anche chi entra con
#   un cambio) con nome, ruolo, numero e campione.
extends RefCounted

const R := preload("res://sim/records.gd")
const C := preload("res://sim/core.gd")
const TIRI := ["shot", "volley", "header"]
const SALTO_MAX := 3.0          # m in un fotogramma: oltre è uno spostamento d'ufficio (rimesse), non corsa
const CHIAVI := ["gol", "assist", "tiri", "in_porta", "passaggi", "intercetti", "contrasti", "dribbling", "scatti",
	"testa", "parate", "km"]

var squadra := 0
var _conti := {}                # chiave del giocatore (id in testo) → {conteggio: numero}
var _passaggio: R.Player = null # ultimo passaggio in volo (di qualunque squadra)
var _tiro: R.Player = null      # ultimo tiro in volo
var _ultimo := {}               # giocatore → [x, y] del fotogramma prima
var _pass_tot := [0, 0]         # passaggi tentati per squadra
var _pass_ok := [0, 0]          # ... e arrivati a un compagno
var _km := [0.0, 0.0]           # km corsi per squadra
var _tiri: Array = []           # mappa dei tiri: {team, x, y, kind, esito, nome}
var _tiro_aperto := {}          # tiro in volo non ancora finito (è anche una voce di _tiri)
var _in_campo: Array = []       # chiavi dei giocatori della persona in campo in questo fotogramma
var _schierati := {}            # chiave → {id, name, pos, champ, num} di chi è sceso in campo
var _ordine: Array = []         # chiavi nell'ordine in cui sono comparse (titolari, poi i cambi)


func _init(squadra_: int = 0) -> void:
	squadra = squadra_


## a ogni fotogramma, prima che gli eventi vengano consumati
func leggi(m: Variant) -> void:
	_segna_in_campo(m.players)
	for e: Dictionary in m.events:
		_evento(e)
	for p: R.Player in m.players:
		var prima: Variant = _ultimo.get(p)
		if prima != null:
			var d := C.hyp(p.x - prima[0], p.y - prima[1])
			if d < SALTO_MAX:
				_km[p.team] += d / 1000.0
				_somma(p, "km", d / 1000.0)
		_ultimo[p] = [p.x, p.y]


# chi della persona è in campo adesso (dopo un cambio p.src è il giocatore entrato; espulso = p.off)
func _segna_in_campo(players: Array) -> void:
	_in_campo = []
	for p: R.Player in players:
		if p.team != squadra or p.off:
			continue
		var k := _chiave(p)
		_in_campo.append(k)
		if not _schierati.has(k):
			_schierati[k] = {"id": p.src.get("id", k), "name": p.name, "pos": p.pos,
				"champ": bool(p.src.get("champ", false)), "num": int(p.src.get("num", 0))}
			_ordine.append(k)


func _evento(e: Dictionary) -> void:
	match e.type:
		"kick":
			var p: R.Player = e.p
			_chiudi_tiro("respinto" if e.get("clear", false) else "fuori")
			if e.get("clear", false):
				_passaggio = null
			elif TIRI.has(e.get("kind", "")):
				_somma(p, "tiri")
				_tiro = p
				_passaggio = null
				_tiro_aperto = {"team": p.team, "x": snappedf(p.x, 0.1), "y": snappedf(p.y, 0.1),
					"kind": str(e.kind), "esito": "fuori", "nome": p.name}
				_tiri.append(_tiro_aperto)
			else:
				_passaggio = p
				_pass_tot[p.team] += 1
		"control":
			var q: R.Player = e.p
			var presa := q.pos == "P" and not _tiro_aperto.is_empty() and q.team != int(_tiro_aperto.team)
			_chiudi_tiro("parato" if presa else "respinto")
			if _passaggio != null:
				if q.team == _passaggio.team and q != _passaggio:
					_somma(_passaggio, "passaggi")
					_pass_ok[q.team] += 1
				elif q.team != _passaggio.team:
					_somma(q, "intercetti")
					_somma(_passaggio, "perse")
			_passaggio = null
		"save":
			var gk: R.Player = e.p
			_somma(gk, "parate")
			if _tiro != null and _tiro.team != gk.team:
				_somma(_tiro, "in_porta")
			_tiro = null
			_chiudi_tiro("parato")
		"out", "half", "full", "restart":
			_chiudi_tiro("fuori")
		"goal":
			var tiro_gol := not _tiro_aperto.is_empty() and int(_tiro_aperto.team) == int(e.team)
			_chiudi_tiro("gol" if tiro_gol else "fuori")
			if int(e.team) != squadra:
				for k: String in _in_campo:
					_somma_chiave(k, "subiti")
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
			_somma(e.get("on"), "perse")
		"block":
			_somma(e.p, "intercetti")
			_chiudi_tiro("respinto")
		"dribble":
			if e.get("ok", false):
				_somma(e.p, "dribbling")
		"burst":
			_somma(e.p, "scatti")
		"aerial":
			_somma(e.p, "testa")


# il tiro in volo finisce con questo esito (vale il primo che arriva)
func _chiudi_tiro(esito: String) -> void:
	if _tiro_aperto.is_empty():
		return
	_tiro_aperto.esito = esito
	_tiro_aperto = {}


# chiave del giocatore: il suo id; senza id (squadre di prova) "#" + numero in squadra
static func _chiave(p: R.Player) -> String:
	var id: Variant = p.src.get("id")
	return str(id) if id != null else "#%d" % p.i


func _somma(p: Variant, k: String, quanto: float = 1.0) -> void:
	if not p is R.Player or (p as R.Player).team != squadra:
		return
	_somma_chiave(_chiave(p), k, quanto)


func _somma_chiave(key: String, k: String, quanto: float = 1.0) -> void:
	if not _conti.has(key):
		_conti[key] = {}
	_conti[key][k] = _conti[key].get(k, 0) + (quanto if k == "km" else int(quanto))


## {id: {gol, tiri, ...}} (solo le chiavi con almeno 1; km arrotondati ai metri). Come prima del tabellino: solo i
## conteggi della crescita (CHIAVI) e solo i giocatori con un id vero
func per_giocatore() -> Dictionary:
	var out := {}
	for key: String in _conti:
		if key.begins_with("#"):
			continue
		var c := {}
		for k: String in _conti[key]:
			if CHIAVI.has(k):
				c[k] = _conti[key][k]
		if c.is_empty():
			continue
		if c.has("km"):
			c.km = snappedf(c.km, 0.001)
		out[key] = c
	return out


## dati per la schermata delle statistiche: {me, passaggi: [[riusciti, tentati], [..]], km: [a, b],
## tiri: [{team, x, y, kind, esito, nome}], giocatori: [{id, name, pos, champ, num, conti: {gol, ..., perse, subiti}}]}
func tabellino() -> Dictionary:
	var gioc: Array = []
	for k: String in _ordine:
		var g: Dictionary = _schierati[k].duplicate()
		var c: Dictionary = _conti.get(k, {}).duplicate()
		if c.has("km"):
			c.km = snappedf(c.km, 0.001)
		g["conti"] = c
		gioc.append(g)
	return {"me": squadra, "passaggi": [[_pass_ok[0], _pass_tot[0]], [_pass_ok[1], _pass_tot[1]]],
		"km": [snappedf(_km[0], 0.01), snappedf(_km[1], 0.01)], "tiri": _tiri.duplicate(true), "giocatori": gioc}
