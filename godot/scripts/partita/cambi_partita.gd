# Cambi a partita in corso (Luis 2026-11-24: "nella pausa si deve poter modificare la rosa, formazione e tattiche").
# Dalla pausa (o dall'intervallo) il tasto "Rosa e tattica" apre la Rosa del menu in modo partita (rosa.gd con
# {"in_partita": true, "cambi": questo oggetto}). Qui solo la logica, niente nodi (tests/test_cambi_partita.gd):
# - regole: al massimo MAX_CAMBI sostituzioni (titolare ⇄ panchina) a partita, intervallo compreso; chi è uscito non
#   rientra; l'espulso non si sostituisce e non si sposta. Scambi tra titolari, formazione e stili: liberi;
# - formazione nuova in partita: gli stessi 11 ridistribuiti nei posti nuovi (formazione_stessi_11), non autoLineup
#   (che farebbe entrare gente dalla panchina);
# - applica(m, me, c): porta nel motore (SimMatch.cambiaSquadra) titolari, posti della formazione e stili della
#   carriera; chi entra ha energia piena (copia col fisico, senza energy0). Ritorna i cambi per la scena del cambio
#   (cambio_regia.gd) e li tiene in `da_mostrare` finché la scena non li mostra.
# - cambi in attesa (Luis 2026-11-27: "per fare i cambi aspetta che la palla esca"): dalla pausa a gioco in corso le
#   sostituzioni non vanno subito nel motore. `attesa` = decise (la carriera ha già i titolari nuovi) e da portare
#   nel motore alla prima interruzione (gioco_fermo: pallone fuori, fallo, gol prima del calcio d'inizio) o
#   all'intervallo. Si contano subito nei 5 (fatti = confermati + entrati in attesa) e finché aspettano si possono
#   disfare: chi doveva uscire ed è ancora in campo può rientrare (`usciti` = solo chi è uscito davvero). Se la partita
#   finisce prima, in quella partita non entrano più, ma restano nella carriera (Luis 2026-11-28: "se modifico il
#   modulo durante la partita, dopo la partita torna a quello base; stessa cosa per le tattiche e i giocatori"):
#   `annulla` toglie solo l'attesa, titolari, modulo e stili scelti restano per la partita dopo.
extends RefCounted

const C := preload("res://sim/core.gd")
const Fisico := preload("res://scripts/carriera/fisico.gd")

const MAX_CAMBI := 5
const ORDINE_RUOLI := "PADC"   # come Carriera.autoLineup: prima il portiere, poi attacco, difesa, centrocampo

var fatti := 0                 # sostituzioni di questa partita: confermati + in attesa
var confermati := 0            # sostituzioni già portate nel motore
var usciti: Array = []         # id di chi è uscito davvero dal campo (non rientra)
var in_campo: Array = []       # id dei giocatori nel motore (leggi_in_campo; [] = presi dai titolari al primo scambio)
var attesa := false            # cambi decisi in pausa, nel motore alla prima interruzione (gioco_fermo) o all'intervallo
var base := {}                 # la squadra della carriera com'è nel motore (ricorda), per annullare i cambi in attesa
var espulsi: Array = []        # id degli espulsi della persona (leggi_espulsi)
var da_mostrare: Array = []    # cambi applicati al motore e non ancora mostrati dalla scena del cambio
var energie := {}              # energia in partita (0..100) per id, letta all'apertura della Rosa (leggi_energie)


func restano() -> int:
	return maxi(0, MAX_CAMBI - fatti)


## id dei giocatori in campo nel motore per la squadra me (anche l'espulso)
func leggi_in_campo(m: Object, me: int) -> void:
	in_campo = []
	for p: Object in m.team(me):
		if p.src is Dictionary and p.src.has("id"):
			in_campo.append(p.src.id)


## titolari di `lineup` che nel motore non ci sono ancora (sostituzioni in attesa)
func entrati_in_attesa(lineup: Array) -> Array:
	return lineup.filter(func(id: Variant) -> bool: return not _dentro(in_campo, id))


## i titolari di `lineup` chiedono una sostituzione rispetto al motore? (sì = in pausa a gioco in corso si aspetta)
func serve_attesa(lineup: Array) -> bool:
	return not entrati_in_attesa(lineup).is_empty()


## il gioco è fermo per un'interruzione, quindi i cambi in attesa possono entrare? Ripresa (rimessa, rinvio, angolo,
## punizione, rigore, calcio d'inizio dopo il gol) non ancora battuta: anche durante la scena del battitore che va a
## prendere il pallone (riprese.gd), non a rincorsa partita (r.pend) né col pallone in mano al portiere ("gk")
static func gioco_fermo(m: Object) -> bool:
	if m.phase != "restart" or m.restart == null:
		return false
	return m.restart.type != "gk" and m.restart.pend == null


## ricorda la squadra della carriera com'è nel motore (da chiamare a cambi non in attesa, all'apertura della Rosa)
func ricorda(c: Object) -> void:
	var s: Dictionary = c.s
	base = {"lineup": (s.lineup as Array).duplicate(), "formation": str(s.formation), "stileAtt": c.stileAtt(), "stileDif": c.stileDif()}


## la partita finisce coi cambi in attesa: in partita non entrano più, ma la carriera tiene titolari, modulo e stili
## scelti nella pausa (Luis 2026-11-28; prima tornava alla squadra in campo e a Luis sembrava che il modulo tornasse
## quello base). `base` resta per sapere cosa c'era in campo
func annulla(c: Object) -> void:
	if not attesa:
		return
	attesa = false
	fatti = confermati
	if c != null and c.has_method("save"):
		c.save()

## espulsi della squadra me (p.off nel motore), per id del giocatore sorgente
func leggi_espulsi(m: Object, me: int) -> void:
	espulsi = []
	for p: Object in m.team(me):
		if p.off and p.src is Dictionary and p.src.has("id"):
			espulsi.append(p.src.id)


## energia attuale nel motore dei giocatori in campo della squadra me (Luis 2026-11-25: "non capisco se si sono
## rigenerate"): la Rosa della pausa mostra questa, non la forma tra le partite
func leggi_energie(m: Object, me: int) -> void:
	energie = {}
	for p: Object in m.team(me):
		if p.src is Dictionary and p.src.has("id"):
			energie[str(p.src.id)] = clampi(int(round(float(p.energy) * 100.0)), 0, 100)


## energia da mostrare per id in partita: quella del motore per chi è in campo, piena per chi è in panchina
func energia(id: Variant) -> int:
	return int(energie.get(str(id), 100))


func uscito(id: Variant) -> bool:
	return _dentro(usciti, id)


func espulso(id: Variant) -> bool:
	return _dentro(espulsi, id)


## lo scambio a ⇄ b si può fare in partita? "" = sì, altrimenti il motivo (scritta gialla della Rosa).
## nome(id) → nome del giocatore
func errore_scambio(lineup: Array, a: Variant, b: Variant, nome: Callable) -> String:
	for id: Variant in [a, b]:
		if espulso(id):
			return "%s è espulso: non si può cambiare" % nome.call(id)
	var ta := _dentro(lineup, a)
	var tb := _dentro(lineup, b)
	if ta == tb:
		return "" # due titolari: libero (panchina ⇄ panchina non arriva qui)
	var entra: Variant = b if ta else a
	if uscito(entra):
		return "%s è già uscito: non può rientrare" % nome.call(entra)
	_base_in_campo(lineup)
	var dopo := entrati_in_attesa(_scambiata(lineup, a, b)).size()
	if dopo > entrati_in_attesa(lineup).size() and confermati + dopo > MAX_CAMBI:
		return "Hai già fatto %d cambi" % MAX_CAMBI
	return ""


## da chiamare quando lo scambio a ⇄ b è stato fatto davvero (lineup = titolari di prima dello scambio)
## (chi esce diventa "uscito" solo quando il cambio va nel motore, in applica)
func registra(lineup: Array, a: Variant, b: Variant) -> void:
	if _dentro(lineup, a) == _dentro(lineup, b):
		return
	_base_in_campo(lineup)
	fatti = confermati + entrati_in_attesa(_scambiata(lineup, a, b)).size()


# senza lettura dal motore: in campo ci sono i titolari di prima del primo scambio
func _base_in_campo(lineup: Array) -> void:
	if in_campo.is_empty():
		in_campo = lineup.duplicate()


static func _scambiata(lineup: Array, a: Variant, b: Variant) -> Array:
	var out: Array = []
	for id: Variant in lineup:
		out.append(b if _stesso(id, a) else (a if _stesso(id, b) else id))
	return out


## nuova formazione F per gli stessi titolari: l'espulso resta al suo posto (nell'indice), il portiere in porta se
## c'è un posto P all'indice 0, gli altri posti (portiere, attacco, difesa, centrocampo) al migliore nel ruolo.
## valuta(id, ruolo) → valutazione; ruoli (facoltativo) = ruolo specifico di ogni posto, passato a valuta al posto
## del gruppo (sim/ruoli.gd). Ritorna la nuova lista dei titolari (stessi id).
func formazione_stessi_11(F: Array, lineup: Array, valuta: Callable, ruoli: Array = []) -> Array:
	var nuova: Array = []
	nuova.resize(F.size())
	var liberi: Array = []
	for i in lineup.size():
		var id: Variant = lineup[i]
		if espulso(id) and i < F.size():
			nuova[i] = id
		else:
			liberi.append(id)
	var ordine: Array = range(F.size())
	ordine.sort_custom(func(x: int, y: int) -> bool:
		var rx := ORDINE_RUOLI.find(str(F[x][0]))
		var ry := ORDINE_RUOLI.find(str(F[y][0]))
		return rx < ry if rx != ry else x < y)
	for i: int in ordine:
		if nuova[i] != null or liberi.is_empty():
			continue
		var best := 0
		var bo := -INF
		for k in liberi.size():
			var o := float(valuta.call(liberi[k], ruoli[i] if i < ruoli.size() else F[i][0]))
			if o > bo:
				bo = o
				best = k
		nuova[i] = liberi[best]
		liberi.remove_at(best)
	return nuova


## porta nel motore la squadra della carriera c (titolari, formazione, stili). Chi è già in campo resta lui (stesso
## src del motore); chi entra = copia col fisico (fisico.gd), senza energy0 = energia piena. Ritorna i cambi
## [{i, p, fuori, fuoriSrc, x, y}] (anche aggiunti a da_mostrare), [] se non è cambiato nessuno, null se non va.
func applica(m: Object, me: int, c: Object) -> Variant:
	var s: Dictionary = c.s
	var lineup: Array = s.lineup
	var srcs: Array = []
	for id: Variant in lineup:
		var src: Variant = null
		for p: Object in m.team(me):
			if p.src is Dictionary and _stesso(p.src.get("id"), id):
				src = p.src
				break
		if src == null:
			var q: Variant = c.player(id)
			if not q is Dictionary:
				return null
			src = Fisico.applica(q)
			(src as Dictionary).erase("energy0")
		# istruzioni scelte nella pausa (sim/istruzioni.gd): valgono subito, anche per chi è già in campo
		var ist: Dictionary = c.istruzioni(id) if c.has_method("istruzioni") else {}
		if ist.is_empty():
			(src as Dictionary).erase("istr")
		else:
			src["istr"] = ist
		srcs.append(src)
	m.teams[me]["piazzati"] = c.piazzati() # battitori dei calci piazzati scelti nella pausa
	var fatti_ora: Variant = m.cambiaSquadra(me, srcs, str(s.formation), c.stileAtt(), c.stileDif())
	if fatti_ora is Array:
		da_mostrare.append_array(fatti_ora)
		for x: Dictionary in fatti_ora:
			var fs: Variant = x.get("fuoriSrc")
			if fs is Dictionary and fs.has("id") and not uscito(fs.id):
				usciti.append(fs.id)
		confermati += (fatti_ora as Array).size()
		fatti = confermati
		attesa = false
		leggi_in_campo(m, me)
		ricorda(c)
	return fatti_ora


static func _stesso(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return int(a) == int(b)
	return a == b


static func _dentro(lista: Array, id: Variant) -> bool:
	for x: Variant in lista:
		if _stesso(x, id):
			return true
	return false
