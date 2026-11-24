# Cronaca scritta (fase C): dagli eventi del motore (m.events, quelli che gioco.gd legge in _eventi) a frasi brevi
# in italiano, con i nomi dei giocatori. Solo logica: niente nodi, si prova da sola (tests/test_cronaca.gd).
# La mostra cronaca_vista.gd.
#
# Il caso è della grafica (un RandomNumberGenerator suo), MAI quello del motore: le partite restano ripetibili.
# Poche frasi: il gol si dice sempre; parata, palo, tiro fuori, occasione, rigore e cartellini se dall'ultima frase
# sono passati PAUSA_FORTE s; dribbling, contrasti, angoli e falli semplici solo dopo PAUSA s e non sempre.
#
#   var c := Cronaca.new(seme, ["Rossi", "Blu"])   seme 0 = a caso
#   c.leggi(evento, ora_s) → frase ("" = niente da dire); c.categoria = di che tipo era l'ultima frase
extends RefCounted

const Coord := preload("res://scripts/coord.gd")

const PAUSA := 4.0             # s veri tra una frase qualunque e una frase "piccola"
const PAUSA_FORTE := 2.0       # s veri tra una frase e una importante (il gol non aspetta)
const TIRO_RICORDO := 3.0      # s: un tiro si ricorda per dire com'è finito (parata, palo, fuori, respinta)
const CAMBI_INSIEME := 1.0     # s veri: cambi così vicini vanno nella stessa riga
const ZONA_TIRO := 20.0        # m dalla porta: un colpo di testa o al volo da qui è un tiro
# probabilità di dire qualcosa per le cose piccole (passata la pausa)
const PROB := {"dribbling": 0.9, "contrasto": 0.55, "angolo": 0.85, "fallo": 0.8}
const IMPORTANZA := {"gol": 3, "autogol": 3, "parata": 2, "palo": 2, "fuori": 2, "occasione": 2, "rigore": 2,
	"rosso": 2, "giallo": 2, "dribbling": 1, "contrasto": 1, "angolo": 1, "fallo": 1}

# {n} giocatore, {o} l'altro giocatore, {a} chi ha fatto l'assist, {s} la sua squadra, {z} l'altra squadra, {m} minuto
const FRASI := {
	"gol": ["GOL di {n} al {m}'!", "Rete! {n} non perdona.", "{n} la mette dentro! {s} esulta.",
		"Che gol di {n}!", "{n} insacca: palla in fondo al sacco!", "Gol! {n} fa esplodere lo stadio."],
	"gol_assist": ["{n} segna su assist di {a}!", "Assist di {a}, gol di {n}!", "{a} serve {n}: è gol!"],
	"autogol": ["Autogol! Sfortuna per {z}.", "Autorete: regalo per {s}!", "Che sfortuna: autogol, punto per {s}."],
	"parata": ["Parata di {o} sul tiro di {n}!", "{o} dice di no a {n}!", "Grande intervento di {o} su {n}!",
		"{n} calcia, {o} c'è!"],
	"parata_sola": ["Parata di {o}!", "{o} salva la porta!", "Grande intervento di {o}!"],
	"palo": ["Palo di {n}!", "{n} colpisce il palo!", "Legno! {n} sfiora il gol.", "Che sfortuna per {n}: palo!"],
	"palo_solo": ["Palo!", "Colpito il legno!", "Il pallone sbatte sul palo!"],
	"fuori": ["Tiro di {n}: fuori di poco.", "{n} ci prova, palla a lato.", "Niente da fare per {n}: il tiro esce.",
		"{n} calcia, ma la porta è lontana."],
	"occasione": ["Occasione per {n}, respinta da {o}!", "{n} calcia, {o} si oppone!",
		"Pericolo! Il tiro di {n} è murato da {o}.", "Che occasione per {n}! Chiude {o}."],
	"dribbling": ["{n} salta {o} con un dribbling.", "Che numero di {n} su {o}!", "{n} se ne va: {o} è saltato.",
		"Dribbling di {n}, {o} resta lì."],
	"contrasto": ["Contrasto vinto da {n} su {o}.", "{n} ruba palla a {o}.", "Recupero di {n} su {o}.",
		"Bel contrasto di {n}."],
	"angolo": ["Calcio d'angolo per {s}.", "Angolo per {s}.", "{s} guadagna un calcio d'angolo."],
	"fallo": ["Fallo di {n} su {o}: punizione.", "{n} stende {o}, punizione per {z}.",
		"Punizione per {z}: fallo di {n}."],
	"giallo": ["Ammonito {n} per il fallo su {o}.", "Cartellino giallo per {n}.", "Giallo a {n}: entrata in ritardo."],
	"rosso": ["Espulso {n}! {s} in dieci.", "Rosso per {n}!", "Cartellino rosso: {n} lascia il campo."],
	"rigore": ["Rigore per {z}! Fallo di {n} su {o}.", "Calcio di rigore! {n} atterra {o}.",
		"L'arbitro indica il dischetto: rigore per {z}!"],
}

var rng := RandomNumberGenerator.new()
var squadre: Array = ["Casa", "Ospiti"]
## di che tipo era l'ultima frase detta ("gol", "parata", ...; "" = nessuna)
var categoria := ""

var _ultima := -INF            # quando è stata detta l'ultima frase (s veri)
var _tiro: Dictionary = {}     # ultimo tiro: {p, ora}
var _ultimo_cambio := ""      # ultima riga dei cambi (più cambi insieme si aggiungono)
var _ultimo_indice := {}       # categoria → ultima frase usata (per non ripeterla subito)


func _init(seme: int = 0, nomi: Array = []) -> void:
	if seme == 0:
		rng.randomize()
	else:
		rng.seed = seme
	if nomi.size() == 2:
		squadre = nomi.duplicate()


## un evento del motore → la frase da mostrare, o "" se non c'è niente da dire adesso. ora = secondi veri
func leggi(e: Dictionary, ora: float) -> String:
	var t: String = e.get("type", "")
	match t:
		"kick":
			if e_tiro(e):
				_tiro = {"p": e.get("p"), "ora": ora}
			return ""
		"goal":
			_tiro = {}
			var chi: Object = e.get("scorer")
			var sq := int(e.get("team", 0))
			if chi == null or e.get("og", false):
				return _di("autogol", "autogol", {"s": _sq(sq), "z": _sq(1 - sq)}, ora)
			var assist: Object = e.get("assist")
			var dati := {"n": chi.name, "s": _sq(sq), "z": _sq(1 - sq), "m": str(e.get("minute", ""))}
			if assist != null and rng.randf() < 0.5:
				dati["a"] = assist.name
				return _di("gol", "gol_assist", dati, ora)
			return _di("gol", "gol", dati, ora)
		"save":
			var gk: Object = e.get("p")
			var tiratore: Object = _tiratore(ora)
			_tiro = {}
			if gk == null:
				return ""
			if tiratore != null:
				return _di("parata", "parata", {"n": tiratore.name, "o": gk.name}, ora)
			return _di("parata", "parata_sola", {"o": gk.name}, ora)
		"post":
			var tiratore: Object = _tiratore(ora)
			if tiratore != null:
				return _di("palo", "palo", {"n": tiratore.name}, ora)
			return _di("palo", "palo_solo", {}, ora)
		"out":
			var tiratore: Object = _tiratore(ora)
			_tiro = {}
			if tiratore != null and e.get("kind", "") == "goalkick":
				return _di("fuori", "fuori", {"n": tiratore.name}, ora)
			return ""
		"block":
			var tiratore: Object = _tiratore(ora)
			var chi: Object = e.get("p")
			if tiratore == null or chi == null or chi.team == tiratore.team:
				return ""
			_tiro = {}
			return _di("occasione", "occasione", {"n": tiratore.name, "o": chi.name}, ora)
		"dribble":
			var p: Object = e.get("p")
			var o: Object = e.get("o")
			if not e.get("ok", false) or p == null or o == null:
				return ""
			return _di("dribbling", "dribbling", {"n": p.name, "o": o.name}, ora)
		"tackle":
			var p: Object = e.get("p")
			var su: Object = e.get("on")
			if p == null or su == null: # contrasto a vuoto: niente da dire
				return ""
			return _di("contrasto", "contrasto", {"n": p.name, "o": su.name}, ora)
		"restart":
			if e.get("kind", "") == "corner":
				return _di("angolo", "angolo", {"s": _sq(int(e.get("team", 0)))}, ora)
			return ""
		"foul":
			return _fallo(e, ora)
		"sub":
			return _cambio(e, ora)
	return ""


# sostituzione (Rosa e tattica dalla pausa): si dice sempre; più cambi insieme in una riga sola
func _cambio(e: Dictionary, ora: float) -> String:
	var p: Object = e.get("p")
	if p == null:
		return ""
	var frase := "entra %s, esce %s" % [p.name, String(e.get("fuori", "?"))]
	if categoria == "cambio" and ora - _ultima < CAMBI_INSIEME and _ultimo_cambio != "":
		_ultimo_cambio += " · " + frase
	else:
		_ultimo_cambio = "Cambio: " + frase
	categoria = "cambio"
	_ultima = ora
	return _ultimo_cambio


## il calcio è un tiro? (tiro vero, o colpo di testa / al volo vicino alla porta avversaria, non un rinvio)
static func e_tiro(e: Dictionary) -> bool:
	var k: String = e.get("kind", "")
	if k == "shot":
		return true
	if (k != "header" and k != "volley") or e.get("clear", false) or e.get("sponda", false):
		return false
	var p: Object = e.get("p")
	if p == null:
		return false
	var porta_y := Coord.HL if p.team == 0 else -Coord.HL   # la squadra 0 attacca verso +y
	return absf(porta_y - p.y) < ZONA_TIRO


func _fallo(e: Dictionary, ora: float) -> String:
	var by: Object = e.get("by")
	var on: Object = e.get("on")
	if by == null:
		return ""
	var dati := {"n": by.name, "o": on.name if on != null else "l'avversario", "s": _sq(by.team), "z": _sq(1 - by.team)}
	var card: Variant = e.get("card")
	if card == "red":
		return _di("rosso", "rosso", dati, ora)
	if e.get("pen", false):
		return _di("rigore", "rigore", dati, ora)
	if card == "yellow":
		return _di("giallo", "giallo", dati, ora)
	return _di("fallo", "fallo", dati, ora)


# frase della categoria `cat` (testi da FRASI[chiave]) se il ritmo lo permette
func _di(cat: String, chiave: String, dati: Dictionary, ora: float) -> String:
	var imp: int = IMPORTANZA.get(cat, 1)
	var passato := ora - _ultima
	if imp == 2 and passato < PAUSA_FORTE:
		return ""
	if imp <= 1:
		if passato < PAUSA:
			return ""
		if rng.randf() >= float(PROB.get(cat, 1.0)):
			return ""
	var frasi: Array = FRASI[chiave]
	var i := rng.randi_range(0, frasi.size() - 1)
	if frasi.size() > 1 and i == int(_ultimo_indice.get(chiave, -1)):
		i = (i + 1 + rng.randi_range(0, frasi.size() - 2)) % frasi.size()
	_ultimo_indice[chiave] = i
	_ultima = ora
	categoria = cat
	return String(frasi[i]).format(dati)


# chi ha tirato da poco (null se non c'è un tiro recente)
func _tiratore(ora: float) -> Object:
	if _tiro.is_empty() or ora - float(_tiro.ora) > TIRO_RICORDO:
		return null
	return _tiro.p


func _sq(k: int) -> String:
	return str(squadre[clampi(k, 0, 1)])
