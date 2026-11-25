# Mercato con le squadre (solo Godot, Luis 2026-11-25): "comprare e vendere giocatori alle altre squadre invece
# che un mercato generico. Bisogna fare offerte e riceverò offerte per i miei. Soprattutto se il giocatore sta
# facendo bene."
#
# Comprare: i giocatori in vendita sono gli 11 di ogni squadra della CPU in questa stagione (aiMatchTeam con
# formazioneDi, gli stessi che si incontrano in partita), identificati da [id squadra, indice]. Prezzo chiesto =
# valore × importanza (il migliore della squadra ×1,4, gli altri ×1,15). Offerta ≥ prezzo = accetta; tra l'85% e il
# prezzo = controfferta al prezzo chiesto; sotto = rifiuta. Una offerta per giocatore a giornata.
# Chi si compra lascia la sua squadra per la stagione (s.ceduti): in partita il posto lo prende un rimpiazzo un po'
# più scarso (rimpiazza, chiamata da Carriera.avversarioPartita dopo aiMatchTeam, che resta identica al JS).
#
# Vendere: dopo ogni partita di campionato una squadra può fare un'offerta per un mio giocatore (mai il campione),
# più spesso e più alta per chi ha una buona media voti (Carriera.media_voti). "Cerca acquirenti" nella Rosa mette
# il giocatore in s.inVendita: alla giornata dopo arriva di sicuro un'offerta per lui.
#
# Stato nella carriera (chiavi solo Godot, Carriera.CHIAVI_GODOT, pulite da pulisci() in Carriera.novita()):
#   s.ceduti     = {id squadra: [indici]} giocatori comprati in questa stagione (azzerato a fine stagione)
#   s.trattative = {"id squadra:indice": {giorno, esito: "rifiuta"|"contro", prezzo}} offerte fatte oggi
#   s.offerte    = [{id, squadra, soldi, scade}] offerte ricevute (scade = giornata assoluta, vedi giorno())
#   s.inVendita  = [id] giocatori messi in vendita dalla Rosa
# Logica pura sullo stato (niente nodi); numeri casuali solo con seme (Carriera._rng_novita). Prove:
# tests/test_mercato_squadre.gd.
extends RefCounted

const JS := preload("res://scripts/carriera/js.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const C := preload("res://sim/core.gd")

## prezzo chiesto = valore × importanza
const IMPORTANZA_MIGLIORE := 1.4
const IMPORTANZA_ALTRI := 1.15
## offerte possibili: da −20% a +20% del prezzo chiesto, a passi del 5%
const OFFERTA_MIN := 0.8
const OFFERTA_MAX := 1.2
const OFFERTA_PASSO := 0.05
## sotto questa parte del prezzo la squadra rifiuta; da qui al prezzo fa la controfferta
const SOGLIA_CONTRO := 0.85
## rimpiazzo di chi è stato comprato: livello della squadra meno questo
const RIMPIAZZO_CALO := 4.0
## offerte ricevute: probabilità a partita, più questo per ogni punto di media sopra MEDIA_BRAVO (fino a +1,5)
const OFFERTA_P := 0.25
const OFFERTA_P_BRAVO := 0.15
const MEDIA_BRAVO := 6.5
## importo = valore × (OFFERTA_BASE + (media − 6) × OFFERTA_PER_PUNTO + caso), almeno OFFERTA_MINIMA × valore
const OFFERTA_BASE := 0.9
const OFFERTA_PER_PUNTO := 0.25
const OFFERTA_CASO := 0.1
const OFFERTA_MINIMA := 0.7
## le offerte ricevute durano 2 giornate; al massimo 3 aperte (quelle chieste con "Cerca acquirenti" in più)
const SCADENZA := 2
const MAX_OFFERTE := 3


# ---------------------------------------------------------------- tempo
## giornata assoluta: stagione × 18 + giornate giocate (continua: l'ultima giornata e l'inizio della stagione dopo
## coincidono, così un'offerta arrivata a fine stagione dura anche d'estate)
static func giorno(s: Dictionary) -> int:
	return int(s.get("season", 1)) * 18 + int(s.get("day", 0))


static func chiave(tid: String, i: int) -> String:
	return "%s:%d" % [tid, i]


# ---------------------------------------------------------------- giocatori delle squadre
## gli 11 della squadra t in questa stagione: [{p, i, prezzo, migliore}] (senza chi è già stato comprato)
static func giocatori(c: RefCounted, t: Dictionary) -> Array:
	var players: Array = c.aiMatchTeam(t, c.formazioneDi(t)).players
	var best := -1
	var bo := -1
	for i in players.size():
		var o: int = c.overall(players[i])
		if o > bo:
			bo = o
			best = i
	var ceduti: Array = ceduti_di(c.s, str(t.id))
	var out: Array = []
	for i in players.size():
		if ceduti.has(i):
			continue
		out.append({"p": players[i], "i": i, "migliore": i == best, "prezzo": prezzo(c, players[i], i == best)})
	return out


static func prezzo(c: RefCounted, p: Dictionary, migliore: bool) -> int:
	return JS.jround(c.value(p) * (IMPORTANZA_MIGLIORE if migliore else IMPORTANZA_ALTRI))


static func ceduti_di(s: Dictionary, tid: String) -> Array:
	var ced: Variant = s.get("ceduti")
	if ced is Dictionary and ced.get(tid) is Array:
		return ced[tid]
	return []


## giocatori in vendita della divisione d (squadre della CPU), [{p, i, prezzo, migliore, squadra}]
static func lista(c: RefCounted, d: int) -> Array:
	var out: Array = []
	for tid: String in c.s.divs[clampi(d, 0, 2)]:
		if tid == "me" or not c.s.teams.has(tid):
			continue
		var t: Dictionary = c.s.teams[tid]
		for g: Dictionary in giocatori(c, t):
			g["squadra"] = t
			out.append(g)
	return out


## un giocatore della squadra tid all'indice i ({p, i, prezzo, migliore, squadra}) o null
static func trova(c: RefCounted, tid: String, i: int) -> Variant:
	var t: Variant = c.s.teams.get(tid)
	if tid == "me" or not t is Dictionary:
		return null
	for g: Dictionary in giocatori(c, t):
		if g.i == i:
			g["squadra"] = t
			return g
	return null


# ---------------------------------------------------------------- offerte fatte da me
## offerta già fatta oggi per questo giocatore ({giorno, esito, prezzo}) o null
static func trattativa(s: Dictionary, tid: String, i: int) -> Variant:
	var tr: Variant = s.get("trattative")
	var x: Variant = tr.get(chiave(tid, i)) if tr is Dictionary else null
	if x is Dictionary and int(x.get("giorno", -1)) == giorno(s):
		return x
	return null


## risposta della squadra a un'offerta: "accetta", "contro" (controfferta al prezzo chiesto) o "rifiuta"
static func risposta(offerta: int, chiesto: int) -> String:
	if offerta >= chiesto:
		return "accetta"
	if offerta >= chiesto * SOGLIA_CONTRO:
		return "contro"
	return "rifiuta"


## importo da offrire per una parte del prezzo chiesto (0,8 .. 1,2)
static func importo(chiesto: int, parte: float) -> int:
	return maxi(1, JS.jround(chiesto * clampf(parte, OFFERTA_MIN, OFFERTA_MAX)))


## fa un'offerta di `soldi` per il giocatore i della squadra tid. Ritorna {esito, prezzo, errore}: esito
## "accetta" (comprato), "contro" (la squadra chiede `prezzo`: accetta_contro) o "rifiuta"; errore "" se tutto bene
static func offri(c: RefCounted, tid: String, i: int, soldi: int) -> Dictionary:
	var s: Dictionary = c.s
	var g: Variant = trova(c, tid, i)
	if g == null:
		return {"esito": "", "prezzo": 0, "errore": "Giocatore non più disponibile"}
	if trattativa(s, tid, i) != null:
		return {"esito": "", "prezzo": 0, "errore": "Hai già fatto un'offerta oggi: riprova alla prossima giornata"}
	var err := _puo_comprare(s, soldi)
	if err != "":
		return {"esito": "", "prezzo": 0, "errore": err}
	var es := risposta(soldi, int(g.prezzo))
	if es == "accetta":
		_compra(c, g, soldi)
		return {"esito": es, "prezzo": soldi, "errore": ""}
	if not s.get("trattative") is Dictionary:
		s["trattative"] = {}
	s.trattative[chiave(tid, i)] = {"giorno": giorno(s), "esito": es, "prezzo": int(g.prezzo)}
	c.save()
	return {"esito": es, "prezzo": int(g.prezzo), "errore": ""}


## accetta la controfferta di oggi (paga il prezzo chiesto): "" se comprato, altrimenti il motivo
static func accetta_contro(c: RefCounted, tid: String, i: int) -> String:
	var tr: Variant = trattativa(c.s, tid, i)
	if tr == null or tr.get("esito") != "contro":
		return "Nessuna controfferta da accettare"
	var g: Variant = trova(c, tid, i)
	if g == null:
		return "Giocatore non più disponibile"
	var err := _puo_comprare(c.s, int(tr.prezzo))
	if err != "":
		return err
	_compra(c, g, int(tr.prezzo))
	return ""


static func _puo_comprare(s: Dictionary, soldi: int) -> String:
	if s.squad.size() >= 24: # Carriera.SQUAD_MAX
		return "Rosa al completo (massimo 24)"
	if int(s.money) < soldi:
		return "Soldi insufficienti"
	return ""


## il giocatore entra in rosa con un id nuovo (aspetto, fisico e numero come gli altri della rosa: dall'id)
static func _compra(c: RefCounted, g: Dictionary, soldi: int) -> void:
	var s: Dictionary = c.s
	var p: Dictionary = g.p.duplicate(true)
	p.erase("look")
	p.erase("num")
	p.id = int(s.nextId)
	s.nextId = int(s.nextId) + 1
	p.goals = 0
	p.assists = 0
	p.apps = 0
	s.money = int(s.money) - soldi
	s.squad.append(p)
	var tid := str(g.squadra.id)
	if not s.get("ceduti") is Dictionary:
		s["ceduti"] = {}
	if not s.ceduti.get(tid) is Array:
		s.ceduti[tid] = []
	s.ceduti[tid].append(int(g.i))
	if s.get("trattative") is Dictionary:
		s.trattative.erase(chiave(tid, int(g.i)))
	c.ensureNums()
	c.save()


## squadra della CPU per la partita (da aiMatchTeam, cambiata qui): chi è stato comprato è sostituito da un
## rimpiazzo dello stesso ruolo, un po' più scarso, generato con un seme diverso (stessa squadra = stesso rimpiazzo)
static func rimpiazza(c: RefCounted, t: Dictionary, sq: Dictionary) -> Dictionary:
	var ced: Array = ceduti_di(c.s, str(t.get("id", "")))
	if ced.is_empty():
		return sq
	var F: Array = C.FORMATIONS[sq.formation]
	for i: Variant in ced:
		var k := int(i)
		if k < 0 or k >= sq.players.size():
			continue
		var r := JS.rng32(Asp.hash32("rimpiazzo", int(t.seed), int(c.s.season), k))
		var p: Dictionary = c.genPlayer(r, F[k][0], float(t.rating) - RIMPIAZZO_CALO, -k - 1)
		p["look"] = Asp.lookCasuale(Asp.hash32("rimpiazzo", int(t.seed), k))
		p["num"] = k + 1
		sq.players[k] = p
	return sq


# ---------------------------------------------------------------- offerte ricevute
## peso di un giocatore nella scelta di chi riceve l'offerta: media sopra 6,5 pesa molto di più
static func peso(media: Variant) -> float:
	if media == null:
		return 1.0
	var m := float(media)
	if m < 6.0:
		return 0.5
	if m < MEDIA_BRAVO:
		return 1.0 + (m - 6.0) * 2.0
	return 2.0 + (m - MEDIA_BRAVO) * 8.0


## probabilità che dopo una partita arrivi un'offerta, data la media più alta della rosa (null = nessuno ha voti)
static func probabilita(media_max: Variant) -> float:
	var extra := 0.0
	if media_max != null:
		extra = clampf(float(media_max) - MEDIA_BRAVO, 0.0, 1.5) * OFFERTA_P_BRAVO
	return OFFERTA_P + extra


## soldi offerti per un giocatore di valore `valore` con quella media (null = 6); caso in 0..1
static func importo_offerta(valore: int, media: Variant, caso: float) -> int:
	var m := 6.0 if media == null else float(media)
	var f := OFFERTA_BASE + (m - 6.0) * OFFERTA_PER_PUNTO + (caso - 0.5) * OFFERTA_CASO
	return maxi(JS.jround(valore * OFFERTA_MINIMA), JS.jround(valore * f))


static func aperte(s: Dictionary) -> Array:
	return s.get("offerte") if s.get("offerte") is Array else []


static func _ha_offerta(s: Dictionary, id: int) -> bool:
	for o: Dictionary in aperte(s):
		if int(o.id) == id:
			return true
	return false


## dopo una partita di campionato: toglie le offerte scadute, fa arrivare quelle per chi è in vendita e forse una
## nuova (r = numeri casuali con seme). Ritorna le offerte nuove [{id, squadra, soldi, scade}]
static func ricevi(c: RefCounted, r: Callable) -> Array:
	var s: Dictionary = c.s
	pulisci(s)
	var oggi := giorno(s)
	s.offerte = s.offerte.filter(func(o: Dictionary) -> bool: return int(o.scade) > oggi)
	var squadre: Array = []
	for tid: String in s.teams.keys():
		if tid != "me":
			squadre.append(tid)
	squadre.sort() # ordine fisso: stessi numeri casuali = stessa squadra
	var nuove: Array = []
	if squadre.is_empty():
		return nuove
	# chi è in vendita: un'offerta sicura (anche oltre il massimo di 3)
	for id: Variant in s.inVendita.duplicate():
		var p: Variant = c.player(id)
		if p == null or p.get("champ", false):
			continue
		if not _ha_offerta(s, int(id)):
			nuove.append(_nuova(c, p, squadre, r, oggi))
		s.inVendita.erase(id)
	# un'offerta a caso, più probabile se qualcuno sta giocando bene
	var cand: Array = []
	var pesi: Array = []
	var media_max: Variant = null
	for p: Dictionary in s.squad:
		if p.get("champ", false) or _ha_offerta(s, int(p.id)) or nuove.any(func(o: Dictionary) -> bool: return int(o.id) == int(p.id)):
			continue
		var m: Variant = c.media_voti(p.id)
		if m != null and (media_max == null or float(m) > float(media_max)):
			media_max = m
		cand.append(p)
		pesi.append(peso(m))
	var tiro := r.call() as float
	if not cand.is_empty() and s.offerte.size() + nuove.size() < MAX_OFFERTE and tiro < probabilita(media_max):
		var tot := 0.0
		for w: float in pesi:
			tot += w
		var x := (r.call() as float) * tot
		var k := 0
		while k < cand.size() - 1 and x >= float(pesi[k]):
			x -= float(pesi[k])
			k += 1
		nuove.append(_nuova(c, cand[k], squadre, r, oggi))
	s.offerte.append_array(nuove)
	return nuove


static func _nuova(c: RefCounted, p: Dictionary, squadre: Array, r: Callable, oggi: int) -> Dictionary:
	var tid: String = squadre[int(floor((r.call() as float) * squadre.size()))]
	var soldi := importo_offerta(c.value(p), c.media_voti(p.id), r.call() as float)
	return {"id": int(p.id), "squadra": tid, "soldi": soldi, "scade": oggi + SCADENZA}


## accetta l'offerta numero k di s.offerte: vende il giocatore a quel prezzo con le regole di Carriera.sell
## (minimo 14 in rosa, almeno un portiere, mai il campione). "" se venduto, altrimenti il motivo
static func accetta(c: RefCounted, k: int) -> String:
	var s: Dictionary = c.s
	var lista_: Array = aperte(s)
	if k < 0 or k >= lista_.size():
		return "Offerta non più valida"
	var o: Dictionary = lista_[k]
	var err: String = c.motivoNonVendibile(int(o.id))
	if err != "":
		return err
	var id := int(o.id)
	s.money = int(s.money) + int(o.soldi)
	s.squad = s.squad.filter(func(q: Dictionary) -> bool: return q.id != id)
	c.fixLineup()
	pulisci(s)
	c.save()
	return ""


## rifiuta l'offerta numero k: sparisce
static func rifiuta(c: RefCounted, k: int) -> void:
	var lista_: Array = aperte(c.s)
	if k >= 0 and k < lista_.size():
		lista_.remove_at(k)
		c.save()


## mette in vendita (o toglie dalla vendita) un mio giocatore; il campione mai. Ritorna true se ora è in vendita
static func cerca_acquirenti(c: RefCounted, id: int, si: bool) -> bool:
	var s: Dictionary = c.s
	var p: Variant = c.player(id)
	pulisci(s)
	if p == null or p.get("champ", false):
		return false
	if si and not s.inVendita.has(id):
		s.inVendita.append(id)
	elif not si:
		s.inVendita.erase(id)
	c.save()
	return s.inVendita.has(id)


static func in_vendita(s: Dictionary, id: Variant) -> bool:
	return s.get("inVendita") is Array and s.inVendita.has(id)


## fine stagione: le squadre si riprendono i giocatori (rose nuove) e le trattative si azzerano
static func nuova_stagione(s: Dictionary) -> void:
	s["ceduti"] = {}
	s["trattative"] = {}


# ---------------------------------------------------------------- salvataggio
## chiavi mancanti o rotte → valori predefiniti; via le offerte per giocatori che non ci sono più (o il campione),
## per squadre che non esistono, e le trattative di altri giorni
static func pulisci(s: Dictionary) -> void:
	var ids := {}
	var campione := -1
	for p: Dictionary in s.squad:
		ids[int(p.id)] = true
		if p.get("champ", false):
			campione = int(p.id)
	var ced: Dictionary = {}
	if s.get("ceduti") is Dictionary:
		for tid: Variant in s.ceduti.keys():
			if s.teams.has(tid) and tid != "me" and s.ceduti[tid] is Array:
				var v: Array = []
				for i: Variant in s.ceduti[tid]:
					if JS.is_integer(i) and int(i) >= 0 and not v.has(int(i)):
						v.append(int(i))
				ced[str(tid)] = v
	s["ceduti"] = ced
	var tr: Dictionary = {}
	var oggi := giorno(s)
	if s.get("trattative") is Dictionary:
		for k: Variant in s.trattative.keys():
			var x: Variant = s.trattative[k]
			if x is Dictionary and JS.is_integer(x.get("giorno")) and int(x.giorno) == oggi \
					and x.get("esito") in ["rifiuta", "contro"] and JS.is_integer(x.get("prezzo")):
				tr[str(k)] = x
	s["trattative"] = tr
	var off: Array = []
	if s.get("offerte") is Array:
		for o: Variant in s.offerte:
			if o is Dictionary and JS.is_integer(o.get("id")) and ids.has(int(o.id)) and int(o.id) != campione \
					and o.get("squadra") is String and s.teams.has(o.squadra) and o.squadra != "me" \
					and JS.is_integer(o.get("soldi")) and JS.is_integer(o.get("scade")):
				off.append(o)
	s["offerte"] = off
	var inv: Array = []
	if s.get("inVendita") is Array:
		for id: Variant in s.inVendita:
			if JS.is_integer(id) and ids.has(int(id)) and int(id) != campione and not inv.has(int(id)):
				inv.append(int(id))
	s["inVendita"] = inv
