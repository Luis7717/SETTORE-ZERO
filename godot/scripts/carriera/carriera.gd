# Carriera: squadre, giocatori, campionato a tre divisioni, mercato, soldi, salvataggio.
# Porting 1:1 di src/career.js: stessi nomi di metodi e campi, stato in `c.s` (Dictionary con le stesse chiavi del
# JS), stessi numeri casuali (a parità di seme la carriera è identica al web: tests/test_carriera.gd la confronta con
# tests/fixtures/carriera.json scritto da `node test/export-carriera.mjs`). Chi scrive i menu può leggere career.js.
#
# Differenze dal JS:
# - `create(name, kit, seme)`: il seme si può passare (prove); senza, viene dall'orologio come nel web.
# - `load()`/`save()`/`reset()` usano il file `user://salvataggio.json` (salvataggio.gd), non localStorage;
#   `load()` sopporta file rotti (ripiega sul temporaneo o sulla copia .bak) e riempie i campi mancanti (completa).
# - Dove il JS ritorna `null` per "tutto bene" (buy, sell) qui si ritorna "" (stringa vuota = falsa in un `if`).
# - Impostazioni in `s.settings` come nel web, più `music` e `vibra` (nuove, predefinite true).
# - Numeri: gli interi restano int anche dopo il caricamento (JSON di Godot li legge come float: js.gd → int_numbers).
# - Le funzioni libere di career.js (overall, value, fmtMoney, genPlayer, ...) sono funzioni statiche:
#   `Carriera.overall(p)`, `Carriera.fmtMoney(k)`; le costanti `Carriera.DIV_NAMES`, `Carriera.KITS`, ...
#
# Novità solo Godot (fase B, in fondo al file; il web non le ha): campione che cresce giocando (crescita.gd),
# obiettivi della dirigenza e rivale/derby (dirigenza.gd), forma e infortuni tra le partite (forma.gd).
# Stanno in chiavi nuove dello stato (CHIAVI_GODOT) e passano da dopoPartita()/squadraPartita(), chiamate da
# scripts/app.gd: le funzioni portate dal JS (finishMatch, endSeason, ...) restano identiche al web.
class_name Carriera
extends RefCounted

const JS := preload("res://scripts/carriera/js.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const Stemma := preload("res://scripts/carriera/stemma_dati.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const C := preload("res://sim/core.gd")
const Crescita := preload("res://scripts/carriera/crescita.gd")
const Forma := preload("res://scripts/carriera/forma.gd")
const Dirigenza := preload("res://scripts/carriera/dirigenza.gd")
const Esultanze := preload("res://scripts/partita/esultanze.gd")

const FORMATIONS := C.FORMATIONS
const DIV_NAMES := ["Prima Divisione", "Seconda Divisione", "Terza Divisione"]
const DIV_LVL := [[70, 82], [60, 70], [50, 60]]
const DIV_INCOME := [300, 140, 70]
## abilità in più della squadra del computer per divisione (oltre a quella che viene dalla forza dei giocatori)
const DIV_SKILL := [0.08, 0.04, 0.0]
const POS_NAME := {"P": "POR", "D": "DIF", "C": "CEN", "A": "ATT"}
## [nome, colore principale, colore secondario] (0xRRGGBB)
const KITS := [
	["Rosso", 0xc8102e, 0xffffff], ["Blu", 0x1746a2, 0xffffff], ["Verde", 0x0b7a3e, 0xffffff], ["Giallo", 0xf2c200, 0x1b1b1b], ["Nero", 0x1c1c22, 0xe8e8e8],
	["Bianco", 0xf2f2f2, 0x1b2a5c], ["Arancio", 0xe8650a, 0x1b1b1b], ["Viola", 0x5b2a86, 0xffffff], ["Celeste", 0x4aa3df, 0xffffff], ["Granata", 0x7a1230, 0xf0d9a0],
]
const NOMI := ["Luca", "Marco", "Matteo", "Andrea", "Davide", "Simone", "Paolo", "Stefano", "Fabio", "Giorgio", "Nicola", "Pietro", "Tommaso", "Elia", "Samuele", "Enrico", "Dario", "Michele", "Riccardo", "Daniele", "Emanuele", "Cristian", "Alessio", "Filippo", "Gabriele", "Lorenzo", "Mattia", "Edoardo", "Jacopo", "Vittorio", "Omar", "Karim", "Diego", "Rui", "Milan", "Yann", "Kofi", "Ivan", "Jonas", "Mateo", "Thiago", "Emre", "Luka", "Sven", "Nuno", "Abdou"]
const COGNOMI := ["Ferrante", "Morandi", "Castoldi", "Bellucci", "Rinaldi", "Sartori", "Galvani", "Pedretti", "Zanella", "Corradi", "Mazzoleni", "Tessari", "Bonfanti", "Carrara", "Negri", "Valsecchi", "Lodi", "Fumagalli", "Brambilla", "Ronchi", "Pagani", "Stella", "Orlandi", "Vitali", "Marchetti", "Donati", "Ferri", "Gatti", "Monti", "Pellegrini", "Barone", "Serra", "Fontana", "Basile", "Caruso", "Rizzi", "Santoro", "Diallo", "Novak", "Petrov", "Silva", "Moreau", "Jansen", "Kovac", "Mensah", "Okoye", "Yilmaz", "Lindqvist", "Duarte", "Benali"]
const PRE := ["Atletico", "Sporting", "Real", "Virtus", "Olimpia", "Dinamo", "Unione", "Pro", "Fortitudo", "Aurora", "Audace", "Robur", "Libertas", "Polisportiva", "Città di"]
const TOWN := ["Borgoalto", "Roccamarina", "Valdoro", "Monteluce", "Pietrafina", "Castelvento", "Fontechiara", "Portosole", "Collebruno", "Torrelunga", "Rivabianca", "Selvascura", "Pontenero", "Campofiore", "Acquadolce", "Vignarossa", "Poggiosereno", "Lagoverde", "Serralta", "Montefalco Nuovo", "Pratolungo", "Casalbruna", "Villastella", "Costadoro", "Fiumechiaro", "Roveredo Alto", "Sassoforte", "Terranova Ligure", "Marebello", "Querciagrande", "Boscofermo", "Pianoro Sole"]
## campione creato nell'editor: un buon giovane della Terza Divisione (le squadre lì stanno tra 50 e 60)
const CHAMP_LEVEL := 62
const SETTINGS_DEFAULT := {"half": 150, "diff": 1, "sound": true, "autoGk": false, "music": true, "vibra": true}
const ROUNDS := 18           # giornate di una stagione (10 squadre, andata e ritorno)
const SQUAD_MAX := 24
const SQUAD_MIN := 14
const MARKET_SIZE := 20
const STAT_KEYS := ["vel", "fis", "dri", "tir", "dif", "pas", "por"]
## chiavi dello stato che ha solo la versione Godot (fase B): semeB = seme dei numeri casuali delle novità,
## forma/infortuni/progressi = per id del giocatore (testo), obiettivo = {stagione, div, tipo, posto}, rivale = id
const CHIAVI_GODOT := ["semeB", "forma", "infortuni", "progressi", "obiettivo", "rivale"]

## stato della carriera (null = nessuna carriera): stesse chiavi di `career.s` nel web
var s: Variant = null
## file del salvataggio (le prove ne usano un altro)
var percorso := Salv.PERCORSO
## obiettivo della stagione appena chiusa da endSeason (per il giudizio in dopoPartita; non si salva)
var _obiettivo_finito := {}
## da dove è venuto l'ultimo caricamento: "principale", "temporaneo", "copia" o "" (nessuno)
var fonte := ""


# ---------------------------------------------------------------- funzioni libere di career.js
static func clamp_(v: float, a: float, b: float) -> float:
	return a if v < a else (b if v > b else v)


static func pick(r: Callable, a: Array) -> Variant:
	return a[int(floor(r.call() * a.size()))]


static func randomName(r: Callable) -> String:
	var nome: String = pick(r, NOMI)
	return nome.left(1) + ". " + String(pick(r, COGNOMI))


static func overallAs(p: Dictionary, pos: String) -> int:
	var pp: String = p.pos
	var pen := 1.0
	if pp != pos:
		if (pp == "P") != (pos == "P"):
			pen = 0.55
		elif pp + pos == "DA" or pp + pos == "AD":
			pen = 0.82
		else:
			pen = 0.92
	var o: float
	if pos == "P":
		o = p.por * 0.72 + p.fis * 0.14 + p.pas * 0.14
	elif pos == "D":
		o = p.dif * 0.45 + p.fis * 0.2 + p.vel * 0.15 + p.pas * 0.1 + p.dri * 0.1
	elif pos == "C":
		o = p.pas * 0.35 + p.dri * 0.25 + p.dif * 0.12 + p.vel * 0.12 + p.tir * 0.16
	else:
		o = p.tir * 0.4 + p.vel * 0.22 + p.dri * 0.23 + p.pas * 0.1 + p.fis * 0.05
	return JS.jround(o * pen)


static func overall(p: Dictionary) -> int:
	return overallAs(p, p.pos)


static func value(p: Dictionary) -> int:
	var o := overall(p)
	var a: int = p.age
	var af := 1.35 if a <= 21 else (1.2 if a <= 25 else (1.0 if a <= 29 else (0.75 if a <= 31 else (0.5 if a <= 33 else 0.3))))
	return maxi(5, JS.jround(30.0 * pow(1.115, o - 50) * af))


static func fmtMoney(k: float) -> String:
	if absf(k) >= 1000.0:
		return JS.thousands_fixed2(k).replace(".", ",") + " M€"
	return str(JS.jround(k)) + " k€"


static func genPlayer(r: Callable, pos: String, level: float, id: int, young: bool = false) -> Dictionary:
	var g: float = (r.call() + r.call() + r.call() - 1.5) * 2.0
	var b: float = level + g * 3.5
	var v := func(d: float) -> int: return JS.jround(clamp_(b + d + (r.call() - 0.5) * 8.0, 18.0, 99.0))
	var p := {"id": id}
	p["name"] = randomName(r)
	p["pos"] = pos
	p["age"] = (17 + int(floor(r.call() * 5))) if young else (18 + int(floor(r.call() * 16)))
	p["goals"] = 0
	p["assists"] = 0
	p["apps"] = 0
	var keys: Array
	var deltas: Array
	if pos == "P":
		keys = ["por", "pas", "fis", "vel", "tir", "dri", "dif"]
		deltas = [5, -12, -2, -12, -30, -22, -22]
	elif pos == "D":
		keys = ["dif", "fis", "vel", "pas", "dri", "tir"]
		deltas = [5, 3, -2, -6, -10, -18]
	elif pos == "C":
		keys = ["pas", "dri", "vel", "dif", "tir", "fis"]
		deltas = [5, 1, -2, -6, -5, -2]
	else:
		keys = ["tir", "vel", "dri", "pas", "fis", "dif"]
		deltas = [5, 2, 2, -6, -3, -22]
	for i in keys.size(): # nello stesso ordine del JS: conta l'ordine delle chiamate a r()
		p[keys[i]] = v.call(float(deltas[i]))
	if pos != "P":
		p["por"] = 12
	p["tes"] = int(C.headingOf(p)) # colpi di testa: stessa formula dei giocatori senza `tes` (nessun numero casuale)
	var extra := 0
	if p.age < 22:
		extra = 4 + int(floor(r.call() * 12))
	elif p.age < 26:
		extra = int(floor(r.call() * 6))
	p["pot"] = overall(p) + extra
	return p


static func roundRobin(ids: Array) -> Array:
	var n := ids.size()
	var a := ids.duplicate()
	var rounds: Array = []
	for r in n - 1:
		var m: Array = []
		for i in n / 2:
			m.append([a[n - 1 - i], a[i]] if r % 2 else [a[i], a[n - 1 - i]])
		rounds.append(m)
		a.insert(1, a.pop_back())
	var ritorno: Array = []
	for m: Array in rounds:
		var mm: Array = []
		for hw: Array in m:
			mm.append([hw[1], hw[0]])
		ritorno.append(mm)
	return rounds + ritorno


static func colorDist(a: int, b: int) -> int:
	return absi((a >> 16) - (b >> 16)) + absi(((a >> 8) & 255) - ((b >> 8) & 255)) + absi((a & 255) - (b & 255))


static func canSwap(lineup: Array, a: Variant, b: Variant) -> bool:
	return a != b and (lineup.has(a) or lineup.has(b))


static func swapLineup(lineup: Array, a: Variant, b: Variant) -> Array:
	var out: Array = []
	for id: Variant in lineup:
		out.append(b if id == a else (a if id == b else id))
	return out


# ---------------------------------------------------------------- salvataggio
## legge il salvataggio; true se c'è una carriera (anche ripescata dalla copia), false = nessuna (menu "nuova")
func load() -> bool:
	var letto := Salv.leggi(percorso)
	fonte = letto.fonte
	if letto.stato == null:
		for p: String in letto.rotti:
			Salv.metti_da_parte(p)
		return false
	if fonte != "principale" and FileAccess.file_exists(percorso):
		Salv.metti_da_parte(percorso) # il principale è rotto: lo si tiene da parte, non diventa la copia .bak
	s = completa(letto.stato)
	upgrade()
	if fonte != "principale":
		save()
	return true


## campi mancanti o sbagliati → valori predefiniti (salvataggi vecchi o scritti a metà). Ritorna lo stato corretto.
func completa(st: Dictionary) -> Dictionary:
	s = st
	var def := {"v": 1, "club": "FC Tiro a Giro", "kit": 0, "money": 250, "season": 1, "day": 0, "market": [],
		"tut": 0, "history": [], "last": null, "formation": "4-4-2", "lineup": []}
	for k: String in def:
		if not st.has(k) or typeof(st[k]) != typeof(def[k]) and def[k] != null:
			st[k] = def[k] if not (def[k] is Array) else []
	if not JS.is_integer(st.get("seed")):
		st["seed"] = Asp.hash32("club", st.club)
	st.kit = clampi(st.kit, 0, KITS.size() - 1)
	if not FORMATIONS.has(st.formation):
		st.formation = "4-4-2"
	var sett: Dictionary = st.get("settings") if st.get("settings") is Dictionary else {}
	for k: String in SETTINGS_DEFAULT:
		if not sett.has(k) or typeof(sett[k]) != typeof(SETTINGS_DEFAULT[k]):
			sett[k] = SETTINGS_DEFAULT[k]
	st["settings"] = sett
	var me: Dictionary = st.teams.me
	me.merge({"id": "me", "name": st.club, "short": "MIA", "kit": st.kit, "rating": 0})
	for id: Variant in st.teams.keys():
		if not st.teams[id] is Dictionary:
			st.teams.erase(id)
			continue
		var t: Dictionary = st.teams[id]
		t.merge({"id": id, "name": "Squadra " + str(id), "short": str(id).left(3).to_upper(), "kit": 0, "rating": 55})
		if id != "me" and not JS.is_integer(t.get("seed")):
			t["seed"] = Asp.hash32(id, t.name)
		if not JS.is_integer(t.kit) or t.kit < 0 or t.kit >= KITS.size():
			t.kit = 0
		if not JS.is_integer(t.rating):
			t.rating = 55
	st.market = st.market.filter(func(p: Variant) -> bool: return p is Dictionary and JS.is_integer(p.get("id")) and JS.is_integer(p.get("price")))
	var max_id := 0
	for p: Dictionary in st.squad + st.market:
		_completa_giocatore(p)
		max_id = maxi(max_id, int(p.id))
	if not JS.is_integer(st.get("nextId")) or st.nextId <= max_id:
		st["nextId"] = max_id + 1
	for d: Array in st.divs:
		for id: String in d:
			if not st.teams.has(id):
				st.teams[id] = {"id": id, "name": "Squadra " + id, "short": id.left(3).to_upper(), "kit": 0, "rating": 55, "seed": Asp.hash32(id)}
	st.day = clampi(st.day, 0, ROUNDS)
	sett.half = clampi(int(sett.half), 30, 99999)
	sett.diff = clampi(int(sett.diff), 0, 2)
	if not _calendario_valido(st):
		newSeason(true)
	if st.lineup.size() != FORMATIONS[st.formation].size():
		st.lineup = []
		autoLineup()
	else:
		fixLineup()
	if st.day >= ROUNDS: # stagione finita ma non chiusa (salvataggio a metà): la si chiude adesso
		endSeason()
	novita()
	return st


func _completa_giocatore(p: Dictionary) -> void:
	p.merge({"name": "Giocatore", "pos": "C", "age": 25, "goals": 0, "assists": 0, "apps": 0})
	if not p.pos is String or not "PDCA".contains(p.pos) or p.pos.length() != 1:
		p.pos = "C"
	for k: String in ["age", "goals", "assists", "apps"]:
		if not JS.is_integer(p[k]):
			p[k] = 25 if k == "age" else 0
	if not p.name is String:
		p.name = JS.js_str(p.name)
	for k: String in STAT_KEYS:
		if not JS.is_integer(p.get(k)):
			p[k] = 12 if k == "por" and p.pos != "P" else 40
	if not JS.is_integer(p.get("pot")):
		p["pot"] = overall(p)


func _calendario_valido(st: Dictionary) -> bool:
	if not st.get("fix") is Array or st.fix.size() != 3 or not st.get("tab") is Dictionary:
		return false
	for d in 3:
		if not st.fix[d] is Array or st.fix[d].size() != ROUNDS:
			return false
		for giornata: Variant in st.fix[d]: # ogni giornata: 5 partite [casa, ospiti] tra squadre della divisione
			if not giornata is Array or giornata.size() != 5:
				return false
			for hw: Variant in giornata:
				if not hw is Array or hw.size() != 2 or not st.divs[d].has(hw[0]) or not st.divs[d].has(hw[1]):
					return false
		for id: String in st.divs[d]:
			if not st.tab.get(id) is Dictionary:
				return false
			for k: String in ["p", "w", "d", "l", "gf", "ga", "pts"]:
				if not JS.is_integer(st.tab[id].get(k)):
					return false
	if not st.get("res") is Array:
		st["res"] = []
	return true


## salvataggi vecchi: numeri di maglia mancanti assegnati (senza doppioni). Stile della divisa, stemma e aspetto
## dei giocatori non si scrivono: se mancano si calcolano sempre uguali (kitStyle(), crest(), lookOf()).
func upgrade() -> void:
	if s is Dictionary and s.get("squad") is Array:
		ensureNums()


func ensureNums() -> void:
	var nums := Asp.squadNumbers(s.squad)
	for p: Dictionary in s.squad:
		p["num"] = nums[p.id]


func save() -> bool:
	if not s is Dictionary:
		return false
	return Salv.scrivi(percorso, s)


func reset() -> void:
	Salv.cancella(percorso)
	s = null


func rnd() -> float:
	s.seed = (int(s.seed) * 1664525 + 1013904223) & JS.M32
	return s.seed / 4294967296.0


# ---------------------------------------------------------------- nuova carriera
func create(name: String, kit: int, seme: int = -1) -> void:
	var seed_value: int = seme if seme >= 0 else (int(Time.get_unix_time_from_system() * 1000.0) ^ randi()) & JS.M32
	var r := JS.rng32(seed_value)
	s = {"v": 1, "seed": seed_value, "club": name, "kit": kit, "crest": Stemma.crestFromSeed(seed_value),
		"kitStyle": Asp.normalizeKitStyle(null), "money": 250, "season": 1, "day": 0, "nextId": 1, "teams": {},
		"divs": [[], [], []], "squad": [], "market": [], "settings": SETTINGS_DEFAULT.duplicate(), "tut": 0,
		"history": [], "last": null}
	var towns: Array = JS.v8_sort(TOWN.duplicate(), func(_a: Variant, _b: Variant) -> float: return r.call() - 0.5)
	var k := 0
	for d in 3:
		for i in 10:
			if d == 2 and i == 0:
				s.teams.me = {"id": "me", "name": name, "short": _sigla(name, "[^A-Za-zÀ-ú]", "MIA"), "kit": kit, "rating": 0}
				s.divs[d].append("me")
				continue
			var id := "t%d" % k
			var town: String = towns[k]
			k += 1
			var lo: int = DIV_LVL[d][0]
			var hi: int = DIV_LVL[d][1]
			var kk := int(floor(r.call() * KITS.size()))
			var t := {"id": id}
			t["name"] = String(pick(r, PRE)) + " " + town
			t["short"] = _sigla(town, "[^A-Za-z]", "")
			t["kit"] = kk
			t["rating"] = JS.jround(lo + r.call() * (hi - lo))
			t["seed"] = int(floor(r.call() * 1e9))
			s.teams[id] = t
			s.divs[d].append(id)
	for pn: Array in [["P", 2], ["D", 6], ["C", 6], ["A", 4]]:
		var n: int = pn[1]
		for i in n:
			var id: int = s.nextId
			s.nextId += 1
			s.squad.append(genPlayer(r, pn[0], 54 + (2 if i < 2 else -1), id, i >= n - 1))
	ensureNums()
	s["formation"] = "4-4-2"
	s["lineup"] = []
	autoLineup()
	s.teams.me.rating = myRating()
	newSeason(true)
	refreshMarket(MARKET_SIZE)
	novita()
	save()


## sigla di 3 lettere: testo senza i caratteri di `togli`, in maiuscolo (o `riserva` se resta vuoto)
static func _sigla(testo: String, togli: String, riserva: String) -> String:
	var re := RegEx.create_from_string(togli)
	var t := re.sub(testo, "", true).left(3).to_upper()
	return t if t != "" else riserva


# ---------------------------------------------------------------- stile della divisa, stemma, aspetto, campione
func kitStyle() -> Dictionary:
	return Asp.normalizeKitStyle(s.get("kitStyle"))


func setKitStyle(st: Variant) -> void:
	s.kitStyle = Asp.normalizeKitStyle(st)
	save()


func crest() -> Dictionary:
	return Stemma.normalizeCrest(s.get("crest"), Stemma.crestFromSeed(Asp.hash32("club", s.club)))


func setCrest(c: Variant) -> void:
	s.crest = Stemma.normalizeCrest(c)
	save()


## stemma di qualunque squadra: la mia, oppure deterministico dal seme (stessa squadra = stesso stemma)
func teamCrest(t: Variant) -> Dictionary:
	if not t is Dictionary or t.get("id") == "me":
		return crest()
	var seme: Variant = t.seed if t.has("seed") else Asp.hash32(t.get("id", "undefined"), t.get("name", "undefined"))
	return Stemma.normalizeCrest(t.get("crest"), Stemma.crestFromSeed(seme))


func setLook(id: int, look: Variant) -> bool:
	var p: Variant = player(id)
	if p == null:
		return false
	p.look = Asp.normalizeLook(look)
	save()
	return true


## campione dell'editor: entra in rosa con ruolo, aspetto e numero scelti; se il numero era di un altro,
## l'altro ne riceve uno libero. opz = {name, pos, look, num}
func addChampion(opz: Dictionary) -> Dictionary:
	var id: int = s.nextId
	s.nextId += 1
	var p := genPlayer(func() -> float: return rnd(), String(opz.get("pos", "A")), CHAMP_LEVEL, id, true)
	var nome: Variant = opz.get("name")
	var testo := (JS.js_str(nome) if nome != null and nome != "" else "").strip_edges().left(20)
	if testo != "":
		p.name = testo
	p["look"] = Asp.normalizeLook(opz.get("look"))
	p["champ"] = true
	var num: Variant = opz.get("num")
	if JS.is_integer(num) and num >= 1 and num <= 99:
		for q: Dictionary in s.squad:
			if q.get("num") == int(num):
				q.erase("num")
		p["num"] = int(num)
	s.squad.insert(0, p)
	ensureNums()
	autoLineup()
	s.teams.me.rating = myRating()
	save()
	return p


func div() -> int:
	for d in s.divs.size():
		if s.divs[d].has("me"):
			return d
	return -1


func team(id: String) -> Variant:
	return s.teams.get(id)


func player(id: Variant) -> Variant:
	for p: Dictionary in s.squad:
		if p.id == id:
			return p
	return null


# ---------------------------------------------------------------- stagione
func newSeason(first: bool = false) -> void:
	s["day"] = 0
	s["fix"] = []
	s["tab"] = {}
	s["res"] = []
	for d in 3:
		var ids: Array = JS.v8_sort(s.divs[d].duplicate(), func(_a: Variant, _b: Variant) -> float: return rnd() - 0.5)
		s.fix.append(roundRobin(ids))
		for id: String in ids:
			s.tab[id] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	if not first:
		for p: Dictionary in s.squad:
			p.goals = 0
			p.assists = 0
			p.apps = 0


## classifica della divisione d: [{id, p, w, d, l, gf, ga, pts}] dal primo all'ultimo
func table(d: int) -> Array:
	var rows: Array = []
	for id: String in s.divs[d]:
		var row := {"id": id}
		row.merge(s.tab[id])
		rows.append(row)
	return JS.v8_sort(rows, func(a: Dictionary, b: Dictionary) -> float:
		var x: int = b.pts - a.pts
		if x == 0:
			x = (b.gf - b.ga) - (a.gf - a.ga)
		if x == 0:
			x = b.gf - a.gf
		if x == 0:
			x = -1 if String(a.id) < String(b.id) else 1
		return float(x))


func myRating() -> int:
	var F: Array = FORMATIONS[s.formation]
	var t := 0
	for i in s.lineup.size():
		var p: Variant = player(s.lineup[i])
		t += overallAs(p, F[i][0]) if p != null else 30
	return JS.jround(t / 11.0)


## prossima partita: {home, opp (squadra), day (1..18), div}; null a stagione finita
func nextMatch() -> Variant:
	var d := div()
	if s.day >= ROUNDS:
		return null
	var m: Array = []
	for x: Array in s.fix[d][s.day]:
		if x[0] == "me" or x[1] == "me":
			m = x
			break
	if m.is_empty():
		return null
	var home: bool = m[0] == "me"
	return {"home": home, "opp": team(m[1] if home else m[0]), "day": s.day + 1, "div": d}


func autoLineup() -> void:
	var F: Array = FORMATIONS[s.formation]
	var used := {}
	var l: Array = []
	l.resize(F.size())
	var order: Array = range(F.size())
	JS.v8_sort(order, func(a: int, b: int) -> float: return float("PADC".find(F[a][0]) - "PADC".find(F[b][0])))
	for i: int in order:
		var best: Variant = null
		var bo := -1
		for p: Dictionary in s.squad:
			if not used.has(p.id):
				var o := overallAs(p, F[i][0])
				if o > bo:
					bo = o
					best = p
		l[i] = best.id
		used[best.id] = true
	s.lineup = l
	schieraSani()


## dopo vendite e acquisti: riempie i buchi della formazione
func fixLineup() -> void:
	var ids := {}
	for p: Dictionary in s.squad:
		ids[p.id] = true
	var used := {}
	var nuova: Array = []
	for id: Variant in s.lineup:
		if id != null and ids.has(id) and not used.has(id):
			used[id] = true
			nuova.append(id)
		else:
			nuova.append(null)
	s.lineup = nuova
	var F: Array = FORMATIONS[s.formation]
	for i in s.lineup.size():
		if s.lineup[i] != null:
			continue
		var best: Variant = null
		var bo := -1
		for p: Dictionary in s.squad:
			if not used.has(p.id):
				var o := overallAs(p, F[i][0])
				if o > bo:
					bo = o
					best = p
		if best != null:
			s.lineup[i] = best.id
			used[best.id] = true
	schieraSani()


func bench() -> Array:
	var out: Array = []
	for p: Dictionary in s.squad:
		if not s.lineup.has(p.id):
			out.append(p)
	return out


## scambia due giocatori (titolare/titolare o titolare/panchina)
func swap(a: int, b: int) -> void:
	if not canSwap(s.lineup, a, b) or entraInfortunato(a, b):
		return
	s.lineup = swapLineup(s.lineup, a, b)
	save()


# ---------------------------------------------------------------- mercato
func refreshMarket(n: int) -> void:
	var d := div()
	var lvl: float = (DIV_LVL[d][0] + DIV_LVL[d][1]) / 2.0
	var r := func() -> float: return rnd()
	s.market = s.market.slice(mini(n, s.market.size()))
	while s.market.size() < MARKET_SIZE:
		var pos: String = pick(r, ["P", "D", "D", "D", "C", "C", "C", "A", "A"])
		var level: float = lvl - 5 + r.call() * 16
		var id: int = s.nextId
		s.nextId += 1
		var young: bool = r.call() < 0.3
		var p := genPlayer(r, pos, level, id, young)
		p["price"] = JS.jround(value(p) * (1.1 + r.call() * 0.25))
		s.market.append(p)


## compra dal mercato: "" se fatto, altrimenti il motivo
func buy(id: int) -> String:
	var i := -1
	for k in s.market.size():
		if s.market[k].id == id:
			i = k
			break
	if i < 0:
		return "Giocatore non più disponibile"
	var p: Dictionary = s.market[i]
	if s.squad.size() >= SQUAD_MAX:
		return "Rosa al completo (massimo 24)"
	if s.money < p.price:
		return "Soldi insufficienti"
	s.money -= p.price
	s.market.remove_at(i)
	p.erase("price")
	s.squad.append(p)
	ensureNums()
	save()
	return ""


func sellPrice(p: Dictionary) -> int:
	return JS.jround(value(p) * 0.8)


## vende un giocatore della rosa: "" se fatto, altrimenti il motivo
func sell(id: int) -> String:
	var p: Variant = player(id)
	if p == null:
		return "Giocatore non trovato"
	if s.squad.size() <= SQUAD_MIN:
		return "Servono almeno 14 giocatori in rosa"
	if p.pos == "P":
		var portieri := 0
		for q: Dictionary in s.squad:
			if q.pos == "P":
				portieri += 1
		if portieri <= 1:
			return "Serve almeno un portiere"
	s.money += sellPrice(p)
	s.squad = s.squad.filter(func(q: Dictionary) -> bool: return q.id != id)
	fixLineup()
	save()
	return ""


# ---------------------------------------------------------------- squadre per la partita
func skillOf(rating: float, d: int = 2) -> float:
	var extra: float = DIV_SKILL[d] if d >= 0 and d < DIV_SKILL.size() else 0.0
	return clamp_((rating - 42) / 48.0 + (s.settings.diff - 1) * 0.15 + extra, 0.1, 0.95)


## divisione di una squadra; per chi non è in campionato (amichevoli) la mia
func divOf(t: Variant) -> int:
	var d := -1
	if t is Dictionary and t.get("id", "") != "":
		for x in s.divs.size():
			if s.divs[x].has(t.id):
				d = x
				break
	return d if d >= 0 else div()


## colori della divisa {shirt, shorts, socks, gk: {...}} (0xRRGGBB); alt = divisa di riserva
func kitOf(k: Variant, alt: bool = false) -> Dictionary:
	var c: Array = KITS[int(k)] if JS.is_integer(k) and int(k) >= 0 and int(k) < KITS.size() else KITS[0]
	if alt:
		return {"shirt": c[2], "shorts": c[1], "socks": c[2], "gk": {"shirt": 0x2ad17a, "shorts": 0x15803d, "socks": 0x15803d}}
	return {"shirt": c[1], "shorts": c[2], "socks": c[1], "gk": {"shirt": 0xffa41c, "shorts": 0x222222, "socks": 0xffa41c}}


## aggiunge alla divisa lo stile (maglia, maniche, colletto, motivo, calzettoni) e lo stemma coi colori della squadra
func dress(kit: Dictionary, k: Variant, style: Dictionary, crest_: Dictionary, gk: bool = false) -> Dictionary:
	var c: Array = KITS[int(k)] if JS.is_integer(k) and int(k) >= 0 and int(k) < KITS.size() else KITS[0]
	var st := style.duplicate()
	if gk:
		st.merge({"sleeves": 1, "pattern": 0, "collar": 0}, true)
	kit["style"] = st
	var cr := crest_.duplicate()
	cr["c1"] = c[1]
	cr["c2"] = c[2]
	kit["crest"] = cr
	if gk:
		kit["gloves"] = true
	return kit


## la mia squadra per SimMatch: {name, short, formation, players, bench, skill, kit}
func myMatchTeam() -> Dictionary:
	var kit := dress(kitOf(s.kit), s.kit, kitStyle(), crest())
	kit["gk"] = dress({"shirt": 0x27e0c0, "shorts": 0x0c5c52, "socks": 0x27e0c0}, s.kit, kitStyle(), crest(), true)
	var players: Array = []
	for id: Variant in s.lineup:
		players.append(player(id))
	return {"name": s.club, "short": s.teams.me.short, "formation": s.formation, "players": players, "bench": bench(), "skill": 0.6, "kit": kit}


## squadra del computer per SimMatch (giocatori generati dal seme della squadra e dalla stagione)
func aiMatchTeam(t: Dictionary) -> Dictionary:
	var r := JS.rng32(int(t.seed) + int(s.season) * 977)
	var fs: Array = FORMATIONS.keys()
	var formation: String = fs[int(floor(r.call() * fs.size()))]
	var F: Array = FORMATIONS[formation]
	var players: Array = []
	for i in F.size():
		players.append(genPlayer(r, F[i][0], float(t.rating), -i - 1))
	# aspetto e numero degli avversari: dal seme della squadra, senza consumare i numeri casuali di r
	for i in players.size():
		players[i]["look"] = Asp.lookFromSeed(Asp.hash32(t.seed, i))
		players[i]["num"] = i + 1
	var same: bool = t.kit == s.kit or absi(colorDist(KITS[t.kit][1], KITS[s.kit][1])) < 110
	var kit := kitOf(t.kit, same)
	var st := Asp.kitStyleFromSeed(t.seed)
	var cr := teamCrest(t)
	dress(kit, t.kit, st, cr)
	dress(kit.gk, t.kit, st, cr, true)
	return {"name": t.name, "short": t.short, "formation": formation, "players": players, "skill": skillOf(t.rating, divOf(t)), "kit": kit}


# ---------------------------------------------------------------- risultati
func record(h: String, a: String, gh: int, ga: int) -> void:
	var H: Dictionary = s.tab[h]
	var A: Dictionary = s.tab[a]
	H.p += 1
	A.p += 1
	H.gf += gh
	H.ga += ga
	A.gf += ga
	A.ga += gh
	if gh > ga:
		H.w += 1
		A.l += 1
		H.pts += 3
	elif gh < ga:
		A.w += 1
		H.l += 1
		A.pts += 3
	else:
		H.d += 1
		A.d += 1
		H.pts += 1
		A.pts += 1


## gol a caso (Poisson) tra due squadre di forza rh e ra: [gol casa, gol ospiti]
func simScore(rh: float, ra: float) -> Array:
	var d: float = (rh + 2 - ra) / 13.0
	var gh := _poisson(1.35 * exp(d * 0.5))
	var ga := _poisson(1.2 * exp(-d * 0.5))
	return [gh, ga]


func _poisson(l: float) -> int:
	var k := 0
	var p := exp(-l)
	var s2 := p
	var u := rnd()
	while u > s2 and k < 8:
		k += 1
		p *= l / k
		s2 += p
	return k


## applica il risultato della partita giocata e simula il resto della giornata.
## log = marcatori della partita ([{team, scorer: {id}, assist: {id}}], come m.goalsLog del motore).
## Ritorna {income, wages, others: [[sigla, gol, gol, sigla]], grown: [nomi], season: (fine stagione, se c'è)};
## {} se non c'è una partita da registrare (nel JS sarebbe un errore)
func finishMatch(my: int, opp: int, log: Array = []) -> Dictionary:
	var d := div()
	if nextMatch() == null:
		return {} # stagione già finita: niente da registrare
	var nm: Dictionary = nextMatch()
	var res := {"income": 0, "wages": 0, "others": [], "grown": []}
	s.teams.me.rating = myRating()
	for dd in 3:
		for hw: Array in s.fix[dd][s.day]:
			var h: String = hw[0]
			var a: String = hw[1]
			if h == "me" or a == "me":
				record(h, a, my if h == "me" else opp, opp if h == "me" else my)
				continue
			var sc := simScore(s.teams[h].rating, s.teams[a].rating)
			record(h, a, sc[0], sc[1])
			if dd == d:
				res.others.append([s.teams[h].short, sc[0], sc[1], s.teams[a].short])
	var base: int = DIV_INCOME[d]
	var vinto := base * 0.5 if my > opp else (base * 0.2 if my == opp else 0.0)
	res.income = JS.jround(base * (1.0 if nm.home else 0.6) + vinto + my * base * 0.05)
	var tot := 0
	for p: Dictionary in s.squad:
		tot += value(p)
	res.wages = JS.jround(tot * 0.014)
	s.money += res.income - res.wages
	for id: Variant in s.lineup:
		var p: Variant = player(id)
		if p != null:
			p.apps += 1
	for g: Variant in log:
		if not g is Dictionary or g.get("team") != 0:
			continue
		var p: Variant = player(g.scorer.id) if g.get("scorer") is Dictionary else null
		if p != null:
			p.goals += 1
		var q: Variant = player(g.assist.id) if g.get("assist") is Dictionary else null
		if q != null:
			q.assists += 1
	_crescita(res)
	if s.res.size() < s.day:
		s.res.resize(s.day)
	if s.res.size() == s.day:
		s.res.append([my, opp])
	else:
		s.res[s.day] = [my, opp]
	s.last = {"opp": nm.opp.name, "my": my, "op": opp, "day": s.day + 1}
	s.day += 1
	refreshMarket(5)
	if s.day >= ROUNDS:
		res["season"] = endSeason()
	save()
	return res


# crescita dei giovani che giocano
func _crescita(res: Dictionary) -> void:
	var r := func() -> float: return rnd()
	for p: Dictionary in s.squad:
		var played: bool = s.lineup.has(p.id)
		if overall(p) < p.pot and rnd() < (0.3 if played else 0.08):
			var keys: Array
			if p.pos == "P":
				keys = ["por", "fis", "pas"]
			elif p.pos == "D":
				keys = ["dif", "fis", "vel", "pas"]
			elif p.pos == "C":
				keys = ["pas", "dri", "tir", "vel", "dif"]
			else:
				keys = ["tir", "vel", "dri", "pas"]
			var k1: String = pick(r, keys)
			p[k1] = mini(99, p[k1] + 1)
			var k2: String = pick(r, keys)
			p[k2] = mini(99, p[k2] + 1)
			res.grown.append(p.name)


## fine stagione: premi, promozioni e retrocessioni, età e calo dei vecchi, nuovo calendario e mercato.
## Ritorna {pos, prize, bonus, outcome: "up"|"down"|"stay"|"champ", div, newDiv, retired}
func endSeason() -> Dictionary:
	var d := div()
	var tabs: Array = [table(0), table(1), table(2)]
	var pos := 0
	for i in tabs[d].size():
		if tabs[d][i].id == "me":
			pos = i + 1
	var prize := JS.jround(DIV_INCOME[d] * (11 - pos) * 0.6)
	var outcome := "stay"
	var nd: Array = [[], [], []]
	for x in 3:
		for i in tabs[x].size():
			var t: Dictionary = tabs[x][i]
			var to := x
			if i < 2 and x > 0:
				to = x - 1
			elif i >= 8 and x < 2:
				to = x + 1
			nd[to].append(t.id)
			if t.id == "me":
				outcome = "up" if to < x else ("down" if to > x else ("champ" if x == 0 and i == 0 else "stay"))
			else:
				var tm: Dictionary = s.teams[t.id]
				var lo: int = DIV_LVL[to][0]
				var hi: int = DIV_LVL[to][1]
				var spinta := 4 if to < x else (-4 if to > x else 0)
				tm.rating = JS.jround(clamp_(tm.rating + (rnd() - 0.5) * 6 + spinta, lo - 2, hi + 2))
	var bonus: int = DIV_INCOME[d] * 3 if outcome == "up" else (2000 if outcome == "champ" else 0)
	s.money += prize + bonus
	s.history.append({"season": s.season, "div": d, "pos": pos, "outcome": outcome})
	s.divs = nd
	s.season += 1
	for p: Dictionary in s.squad:
		p.age += 1
		if p.age > 30:
			for k: String in STAT_KEYS:
				if rnd() < 0.5:
					p[k] = maxi(15, p[k] - 1 - (1 if p.age > 33 else 0))
	newSeason(false)
	s.market = []
	refreshMarket(MARKET_SIZE)
	_obiettivo_finito = obiettivo().duplicate() if s.get("obiettivo") is Dictionary else {}
	novita() # solo Godot: obiettivo e rivale della stagione nuova (niente numeri casuali)
	return {"pos": pos, "prize": prize, "bonus": bonus, "outcome": outcome, "div": d, "newDiv": div(), "retired": []}


# ---------------------------------------------------------------- novità solo Godot (fase B)
## chiavi nuove con valori predefiniti (carriere nuove e salvataggi vecchi); obiettivo e rivale della stagione
## corrente se mancano o sono di un'altra stagione / divisione. Niente numeri casuali di `s.seed`.
func novita() -> void:
	if not s is Dictionary or not s.get("squad") is Array:
		return
	if not JS.is_integer(s.get("semeB")):
		s["semeB"] = Asp.hash32("novita", s.club, s.get("seed", 0))
	for k: String in ["forma", "infortuni", "progressi"]:
		if not s.get(k) is Dictionary:
			s[k] = {}
	var ids := {}
	for p: Dictionary in s.squad:
		ids[str(p.id)] = true
	for k: Variant in s.forma.keys():
		if not ids.has(k) or not JS.is_integer(s.forma[k]):
			s.forma.erase(k)
		else:
			s.forma[k] = clampi(s.forma[k], 0, Forma.FORMA_MAX)
	for k: Variant in s.infortuni.keys():
		if not ids.has(k) or not JS.is_integer(s.infortuni[k]) or s.infortuni[k] <= 0:
			s.infortuni.erase(k)
	for k: Variant in s.progressi.keys():
		if not ids.has(k) or not s.progressi[k] is Dictionary:
			s.progressi.erase(k)
	var d := div()
	if d < 0:
		return
	var altre: Array = []
	var ids_div: Array = []
	for id: String in s.divs[d]:
		if id != "me" and s.teams.has(id):
			altre.append(int(s.teams[id].rating))
			ids_div.append(id)
	var mia := myRating()
	s["rivale"] = Dirigenza.scegli_rivale(s.get("rivale"), ids_div, s.teams, mia)
	var ob: Variant = s.get("obiettivo")
	if not ob is Dictionary or not JS.is_integer(ob.get("stagione")) or int(ob.stagione) != int(s.season) \
			or not Dirigenza.TIPI.has(ob.get("tipo")) or not JS.is_integer(ob.get("posto")):
		s["obiettivo"] = Dirigenza.nuovo(int(s.season), d, mia, altre)


## esultanza del giocatore p (campo "esultanza" del campione, fase C): senza campo, o sbagliato, la predefinita.
## Il campo si scrive solo con setEsultanza (editor): addChampion resta identico al JS, i salvataggi vecchi vanno.
static func esultanza_di(p: Variant) -> String:
	return Esultanze.valida(p.get("esultanza") if p is Dictionary else null)


## sceglie l'esultanza del campione (solo lui ne ha una); false se id non è il campione
func setEsultanza(id: Variant, e: Variant) -> bool:
	var p: Variant = player(id)
	if not p is Dictionary or not p.get("champ", false):
		return false
	p["esultanza"] = Esultanze.valida(e)
	save()
	return true


## numeri casuali delle novità per questa giornata (stessa carriera = stessi numeri)
func _rng_novita(nome: String) -> Callable:
	return JS.rng32(Asp.hash32(s.get("semeB", 0), nome, s.season, s.day))


## il giocatore principale (creato nell'editor iniziale), o null
func campione() -> Variant:
	for p: Dictionary in s.squad:
		if p.get("champ", false):
			return p
	return null


func forma_di(id: Variant) -> int:
	var f: Variant = s.get("forma", {}).get(str(id), Forma.FORMA_MAX) if s.get("forma") is Dictionary else Forma.FORMA_MAX
	return int(f)


## giornate di infortunio che restano (0 = sano)
func infortunio(id: Variant) -> int:
	var inf: Variant = s.get("infortuni")
	return int(inf.get(str(id), 0)) if inf is Dictionary else 0


func _ha_infortunati() -> bool:
	return s is Dictionary and s.get("infortuni") is Dictionary and not s.infortuni.is_empty()


## lo scambio a⇄b farebbe entrare in campo un infortunato?
func entraInfortunato(a: Variant, b: Variant) -> bool:
	if s.lineup.has(a) and not s.lineup.has(b):
		return infortunio(b) > 0
	if s.lineup.has(b) and not s.lineup.has(a):
		return infortunio(a) > 0
	return false


## titolari infortunati → il miglior sostituto sano per quel posto (la CPU fa i cambi). Ritorna [{fuori, dentro}]
func schieraSani() -> Array:
	var cambi: Array = []
	if not _ha_infortunati():
		return cambi
	var F: Array = FORMATIONS[s.formation]
	for i in s.lineup.size():
		var id: Variant = s.lineup[i]
		if id == null or infortunio(id) <= 0:
			continue
		var best: Variant = null
		var bo := -1
		for p: Dictionary in s.squad:
			if s.lineup.has(p.id) or infortunio(p.id) > 0:
				continue
			var o := overallAs(p, F[i][0])
			if o > bo:
				bo = o
				best = p
		if best != null:
			var fuori: Variant = player(id)
			cambi.append({"fuori": fuori.name if fuori != null else "?", "dentro": best.name})
			s.lineup[i] = best.id
	return cambi


## la mia squadra per la partita (al posto di myMatchTeam): niente infortunati, e chi è giù di forma parte
## stanco (energia iniziale `energy0` del motore). I giocatori sono copie: lo stato della carriera non cambia.
func squadraPartita() -> Dictionary:
	schieraSani()
	var t := myMatchTeam()
	var gioc: Array = []
	for p: Variant in t.players:
		if not p is Dictionary:
			gioc.append(p)
			continue
		var q: Dictionary = p.duplicate()
		var e := Forma.energia(forma_di(p.id))
		if e < 1.0:
			q["energy0"] = e
		gioc.append(q)
	t.players = gioc
	t.bench = t.bench.filter(func(p: Dictionary) -> bool: return infortunio(p.id) <= 0)
	return t


func rivale() -> Variant:
	var id: Variant = s.get("rivale")
	return team(id) if id is String and id != "" else null


## la partita contro questa squadra è un derby?
func isDerby(t: Variant) -> bool:
	return t is Dictionary and t.get("id", "") != "" and t.get("id") == s.get("rivale")


func obiettivo() -> Dictionary:
	var ob: Variant = s.get("obiettivo")
	return ob if ob is Dictionary else {}


## dopo finishMatch (partita di campionato): premio del derby, crescita del campione, forma e infortuni,
## e a fine stagione l'obiettivo della dirigenza (premio o penalità) e quello nuovo. Aggiunge a res:
## derby (soldi), crescita {nome, righe}, infortuni [{id, name, giornate}], cambi [{fuori, dentro}],
## obiettivo {tipo, testo, riuscito, soldi, messaggio} (anche in res.season). esito = quello della partita
## ({gol_a, gol_b, me, derby, conteggi}). Ritorna res.
func dopoPartita(res: Dictionary, esito: Dictionary) -> Dictionary:
	if res.is_empty() or not s is Dictionary:
		return res
	var stagione: Variant = res.get("season")
	# obiettivo della stagione giocata: a fine stagione endSeason l'ha già sostituito con quello nuovo
	var ob: Dictionary = _obiettivo_finito if stagione is Dictionary else obiettivo().duplicate()
	_obiettivo_finito = {}
	novita()
	var d: int = int(stagione.div) if stagione is Dictionary else div()
	var base: int = DIV_INCOME[clampi(d, 0, 2)]
	var me := int(esito.get("me", 0))
	var mie := int(esito.get("gol_a", 0)) if me == 0 else int(esito.get("gol_b", 0))
	var loro := int(esito.get("gol_b", 0)) if me == 0 else int(esito.get("gol_a", 0))
	if esito.get("derby", false):
		var premio := Dirigenza.premio_derby(base, mie, loro)
		res["derby"] = premio
		s.money += premio
	var ch: Variant = campione()
	var cont: Variant = esito.get("conteggi", {})
	if ch != null and cont is Dictionary and cont.get(str(ch.id)) is Dictionary:
		res["crescita"] = {"nome": ch.name, "righe": Crescita.applica(ch, cont[str(ch.id)], s.progressi)}
		s.teams.me.rating = myRating()
	if stagione is Dictionary:
		Forma.estate(s.forma, s.infortuni)
		if not ob.is_empty() and int(ob.get("stagione", -1)) == int(s.season) - 1:
			var val := Dirigenza.valuta(ob, int(stagione.pos), base, int(s.money))
			s.money += int(val.soldi)
			res["obiettivo"] = val
			stagione["obiettivo"] = val
		novita() # obiettivo e rivale della stagione nuova
	else:
		res["infortuni"] = Forma.giornata(s.squad, s.lineup.duplicate(), s.forma, s.infortuni, _rng_novita("infortuni"))
		res["cambi"] = schieraSani()
	save()
	return res
