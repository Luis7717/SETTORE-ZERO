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
extends RefCounted

const C := preload("res://sim/core.gd")
const Fisico := preload("res://scripts/carriera/fisico.gd")

const MAX_CAMBI := 5
const ORDINE_RUOLI := "PADC"   # come Carriera.autoLineup: prima il portiere, poi attacco, difesa, centrocampo

var fatti := 0                 # sostituzioni fatte in questa partita
var usciti: Array = []         # id di chi è uscito (non rientra)
var espulsi: Array = []        # id degli espulsi della persona (leggi_espulsi)
var da_mostrare: Array = []    # cambi applicati al motore e non ancora mostrati dalla scena del cambio
var energie := {}              # energia in partita (0..100) per id, letta all'apertura della Rosa (leggi_energie)


func restano() -> int:
	return maxi(0, MAX_CAMBI - fatti)


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
	if restano() <= 0:
		return "Hai già fatto %d cambi" % MAX_CAMBI
	return ""


## da chiamare quando lo scambio a ⇄ b è stato fatto davvero (lineup = titolari di prima dello scambio)
func registra(lineup: Array, a: Variant, b: Variant) -> void:
	var ta := _dentro(lineup, a)
	if ta == _dentro(lineup, b):
		return
	fatti += 1
	usciti.append(a if ta else b)


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
		srcs.append(src)
	m.teams[me]["piazzati"] = c.piazzati() # battitori dei calci piazzati scelti nella pausa
	var fatti_ora: Variant = m.cambiaSquadra(me, srcs, str(s.formation), c.stileAtt(), c.stileDif())
	if fatti_ora is Array:
		da_mostrare.append_array(fatti_ora)
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
