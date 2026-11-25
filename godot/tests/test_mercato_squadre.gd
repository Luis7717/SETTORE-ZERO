# Mercato con le squadre (scripts/carriera/mercato_squadre.gd, Luis 2026-11-25): prezzo chiesto e risposta della
# squadra, acquisto e rimpiazzo nell'avversario, offerte ricevute (più probabili con la media voti alta), accetta,
# rifiuta, scadenza, "Cerca acquirenti", campione mai in offerta, salvataggi vecchi senza le chiavi nuove.
extends "test_base.gd"

const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Mercato := preload("res://scripts/carriera/mercato_squadre.gd")
const JS := preload("res://scripts/carriera/js.gd")
const DIR := "user://prove_carriera/"


func _nuova(nome_file: String, seme: int = 77) -> CarrieraScript:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + nome_file
	Salv.cancella(c.percorso)
	c.create("Prova Mercato", 2, seme)
	return c


static func _campione(c: CarrieraScript) -> Dictionary:
	return c.addChampion({"name": "Campione", "pos": "A", "look": {}, "num": 10})


static func _prima_squadra(c: CarrieraScript) -> Dictionary:
	for tid: String in c.s.divs[c.div()]:
		if tid != "me":
			return c.s.teams[tid]
	return {}


## voti finti: id → [somma, partite] con quella media su 5 partite
static func _media(c: CarrieraScript, id: int, m: float) -> void:
	c.s.voti[str(id)] = [m * 5.0, 5]


# ---------------------------------------------------------------- prezzo e risposta
func test_prezzo_chiesto_migliore_e_altri() -> bool:
	var c := _nuova("prezzo.json")
	var t := _prima_squadra(c)
	var gs := Mercato.giocatori(c, t)
	eq(gs.size(), 11, "gli 11 della squadra in vendita")
	var migliori := 0
	for g: Dictionary in gs:
		var v := CarrieraScript.value(g.p)
		if g.migliore:
			migliori += 1
			eq(g.prezzo, JS.jround(v * 1.4), "il migliore costa valore × 1,4")
		else:
			eq(g.prezzo, JS.jround(v * 1.15), "gli altri valore × 1,15")
	eq(migliori, 1, "un solo migliore")
	# sono gli stessi giocatori che si incontrano in partita
	var sq := c.aiMatchTeam(t, c.formazioneDi(t))
	eq(gs[3].p.name, sq.players[3].name, "stessi giocatori di aiMatchTeam")
	var lista := Mercato.lista(c, c.div())
	eq(lista.size(), 9 * 11, "nella mia divisione: 9 squadre × 11")
	check(lista.all(func(g: Dictionary) -> bool: return g.squadra.id != "me"), "nessuno della mia squadra")
	c.reset()
	return done()


func test_risposta_alle_offerte() -> bool:
	eq(Mercato.risposta(100, 100), "accetta", "al prezzo chiesto accetta")
	eq(Mercato.risposta(120, 100), "accetta", "sopra accetta")
	eq(Mercato.risposta(85, 100), "contro", "all'85% controfferta")
	eq(Mercato.risposta(99, 100), "contro", "poco sotto controfferta")
	eq(Mercato.risposta(84, 100), "rifiuta", "sotto l'85% rifiuta")
	eq(Mercato.importo(100, 0.5), 80, "mai sotto −20%")
	eq(Mercato.importo(100, 2.0), 120, "mai sopra +20%")
	return done()


func test_rifiuto_e_una_offerta_a_giornata() -> bool:
	var c := _nuova("rifiuto.json")
	c.s.money = 100000
	var t := _prima_squadra(c)
	var g: Dictionary = Mercato.giocatori(c, t)[2]
	var r := Mercato.offri(c, t.id, g.i, Mercato.importo(g.prezzo, 0.8))
	eq(r.esito, "rifiuta", "all'80% rifiuta")
	var r2 := Mercato.offri(c, t.id, g.i, g.prezzo)
	check(r2.errore != "", "seconda offerta lo stesso giorno: no (%s)" % r2.errore)
	c.finishMatch(1, 1, [])
	var r3 := Mercato.offri(c, t.id, g.i, g.prezzo)
	eq(r3.esito, "accetta", "la giornata dopo si riprova")
	c.reset()
	return done()


func test_controfferta_si_accetta() -> bool:
	var c := _nuova("contro.json")
	c.s.money = 100000
	var t := _prima_squadra(c)
	var g: Dictionary = Mercato.giocatori(c, t)[4]
	var soldi: int = c.s.money
	var r := Mercato.offri(c, t.id, g.i, Mercato.importo(g.prezzo, 0.9))
	eq(r.esito, "contro", "al 90% controfferta")
	eq(r.prezzo, g.prezzo, "chiede il prezzo pieno")
	eq(c.s.money, soldi, "niente spesa per ora")
	eq(Mercato.accetta_contro(c, t.id, g.i), "", "controfferta accettata")
	eq(c.s.money, soldi - int(g.prezzo), "pagato il prezzo chiesto")
	c.reset()
	return done()


# ---------------------------------------------------------------- acquisto e rimpiazzo
func test_acquisto_e_rimpiazzo_nell_avversario() -> bool:
	var c := _nuova("acquisto.json")
	c.s.money = 100000
	var t := _prima_squadra(c)
	var gs := Mercato.giocatori(c, t)
	var g: Dictionary = gs[5]
	var n0: int = c.s.squad.size()
	var id_atteso: int = c.s.nextId
	var r := Mercato.offri(c, t.id, g.i, g.prezzo)
	eq(r.esito, "accetta", "al prezzo chiesto: comprato")
	eq(c.s.squad.size(), n0 + 1, "un giocatore in più")
	var p: Variant = c.player(id_atteso)
	check(p != null, "id nuovo dalla carriera")
	if p != null:
		eq(p.name, g.p.name, "è lui")
		check(not p.has("look"), "niente aspetto della vecchia squadra (si calcola dall'id)")
		check(p.has("num") and int(p.num) >= 1, "numero di maglia dalla rosa")
	eq(Mercato.ceduti_di(c.s, t.id), [g.i], "la squadra lo perde")
	eq(Mercato.giocatori(c, t).size(), 10, "non è più in vendita")
	var sq := c.avversarioPartita(t)
	var nuovo: Dictionary = sq.players[g.i]
	check(nuovo.name != g.p.name, "al suo posto un rimpiazzo")
	eq(nuovo.pos, g.p.pos, "stesso ruolo")
	eq(nuovo.id, -g.i - 1, "id come gli altri avversari")
	var web := c.aiMatchTeam(t, c.formazioneDi(t))
	eq(web.players[g.i].name, g.p.name, "aiMatchTeam resta identica")
	# il rimpiazzo è più scarso in media (su tante squadre)
	var somma_r := 0.0
	var somma_o := 0.0
	for tid: String in c.s.teams.keys():
		if tid == "me":
			continue
		var tt: Dictionary = c.s.teams[tid]
		var orig: Array = c.aiMatchTeam(tt, c.formazioneDi(tt)).players
		var sqq := {"formation": c.formazioneDi(tt), "players": orig.duplicate()}
		c.s.ceduti[tid] = [3]
		Mercato.rimpiazza(c, tt, sqq)
		somma_r += CarrieraScript.overall(sqq.players[3])
		somma_o += CarrieraScript.overall(orig[3])
	note("valutazione media: titolari %.1f, rimpiazzi %.1f" % [somma_o / 29.0, somma_r / 29.0])
	check(somma_r < somma_o, "i rimpiazzi sono più scarsi")
	c.reset()
	return done()


func test_acquisto_rispetta_soldi_e_rosa_piena() -> bool:
	var c := _nuova("limiti.json")
	var t := _prima_squadra(c)
	var g: Dictionary = Mercato.giocatori(c, t)[0]
	c.s.money = int(g.prezzo) - 1
	var r := Mercato.offri(c, t.id, g.i, g.prezzo)
	eq(r.errore, "Soldi insufficienti", "senza soldi no")
	c.s.money = 100000
	while c.s.squad.size() < CarrieraScript.SQUAD_MAX:
		var q: Dictionary = c.s.squad[1].duplicate()
		q.id = c.s.nextId
		c.s.nextId += 1
		c.s.squad.append(q)
	r = Mercato.offri(c, t.id, g.i, g.prezzo)
	eq(r.errore, "Rosa al completo (massimo 24)", "rosa piena no")
	c.reset()
	return done()


func test_a_fine_stagione_le_squadre_si_riprendono_i_giocatori() -> bool:
	var c := _nuova("estate.json")
	c.s.money = 100000
	var t := _prima_squadra(c)
	var g: Dictionary = Mercato.giocatori(c, t)[1]
	Mercato.offri(c, t.id, g.i, g.prezzo)
	check(not c.s.ceduti.is_empty(), "ceduto")
	var res := {}
	for i in CarrieraScript.ROUNDS:
		res = c.dopoPartita(c.finishMatch(1, 0, []), {"gol_a": 1, "gol_b": 0, "me": 0})
	check(res.get("season") is Dictionary, "stagione finita")
	check(c.s.ceduti.is_empty(), "ceduti azzerati")
	c.reset()
	return done()


# ---------------------------------------------------------------- offerte ricevute
func test_offerte_piu_probabili_con_media_alta() -> bool:
	near(Mercato.probabilita(null), 0.25, 1e-9, "circa il 25% a partita")
	check(Mercato.probabilita(7.5) > Mercato.probabilita(6.4), "di più con la media alta")
	check(Mercato.peso(7.0) > 2.0 * Mercato.peso(6.2), "sopra 6,5 pesa molto di più")
	check(Mercato.peso(5.5) < Mercato.peso(null), "chi gioca male pesa meno")
	var v := 1000
	eq(Mercato.importo_offerta(v, 6.0, 0.5), 900, "media 6: 0,9 × valore")
	eq(Mercato.importo_offerta(v, 8.0, 0.5), 1400, "media 8: 1,4 × valore")
	eq(Mercato.importo_offerta(v, 3.0, 0.0), 700, "mai sotto 0,7 × valore")
	# su tante giornate: il giocatore con media alta riceve molte più offerte degli altri
	var c := _nuova("probabili.json")
	var bravo: int = c.s.squad[3].id
	var conta := 0
	var bravo_n := 0
	for k in 300:
		c.s.offerte = []
		for p: Dictionary in c.s.squad:
			_media(c, p.id, 6.0)
		_media(c, bravo, 7.5)
		var nuove := Mercato.ricevi(c, JS.rng32(1000 + k))
		conta += nuove.size()
		for o: Dictionary in nuove:
			if int(o.id) == bravo:
				bravo_n += 1
	note("300 giornate: %d offerte, %d per il giocatore con media 7,5 (su 18)" % [conta, bravo_n])
	check(conta > 60 and conta < 160, "circa 1 partita su 3 con un bravo in rosa (%d)" % conta)
	check(bravo_n * 4 > conta, "il bravo prende più di un quarto delle offerte, gli altri 17 il resto (%d su %d)" % [bravo_n, conta])
	c.reset()
	return done()


func test_campione_mai_in_offerta() -> bool:
	var c := _nuova("campione.json")
	var ch := _campione(c)
	_media(c, ch.id, 9.5)
	for k in 200:
		c.s.offerte = []
		for o: Dictionary in Mercato.ricevi(c, JS.rng32(7 + k)):
			check(int(o.id) != int(ch.id), "offerta per il campione")
	check(not Mercato.cerca_acquirenti(c, ch.id, true), "il campione non si mette in vendita")
	c.s.offerte = [{"id": ch.id, "squadra": _prima_squadra(c).id, "soldi": 999, "scade": Mercato.giorno(c.s) + 2}]
	Mercato.pulisci(c.s)
	eq(c.s.offerte.size(), 0, "un'offerta per il campione nel salvataggio sparisce")
	c.reset()
	return done()


func test_accetta_rifiuta_e_scadenza() -> bool:
	var c := _nuova("accetta.json")
	var t := _prima_squadra(c)
	var p: Dictionary = c.s.squad[5]
	var oggi := Mercato.giorno(c.s)
	c.s.offerte = [{"id": p.id, "squadra": t.id, "soldi": 777, "scade": oggi + 2},
		{"id": c.s.squad[6].id, "squadra": t.id, "soldi": 500, "scade": oggi + 2}]
	var soldi: int = c.s.money
	eq(Mercato.accetta(c, 0), "", "accettata")
	eq(c.s.money, soldi + 777, "incassato il prezzo dell'offerta")
	check(c.player(p.id) == null, "il giocatore se n'è andato")
	eq(c.s.offerte.size(), 1, "resta l'altra offerta")
	Mercato.rifiuta(c, 0)
	eq(c.s.offerte.size(), 0, "rifiutata: sparisce")
	# scadenza: dopo 2 giornate
	var q: Dictionary = c.s.squad[7]
	c.s.offerte = [{"id": q.id, "squadra": t.id, "soldi": 400, "scade": Mercato.giorno(c.s) + Mercato.SCADENZA}]
	c.s.inVendita = []
	c.finishMatch(0, 0, [])
	Mercato.ricevi(c, func() -> float: return 0.99) # 0,99 = niente offerta nuova
	eq(c.s.offerte.size(), 1, "dopo una giornata c'è ancora")
	c.finishMatch(0, 0, [])
	Mercato.ricevi(c, func() -> float: return 0.99)
	eq(c.s.offerte.size(), 0, "dopo due giornate è scaduta")
	c.reset()
	return done()


func test_accetta_con_le_regole_di_sell() -> bool:
	var c := _nuova("regole.json")
	var t := _prima_squadra(c)
	var portieri: Array = c.s.squad.filter(func(p: Dictionary) -> bool: return p.pos == "P")
	c.s.squad = c.s.squad.filter(func(p: Dictionary) -> bool: return p.id != portieri[1].id)
	c.fixLineup()
	c.s.offerte = [{"id": portieri[0].id, "squadra": t.id, "soldi": 300, "scade": Mercato.giorno(c.s) + 2}]
	eq(Mercato.accetta(c, 0), "Serve almeno un portiere", "l'ultimo portiere no")
	while c.s.squad.size() > CarrieraScript.SQUAD_MIN:
		c.s.squad.pop_back()
	c.fixLineup()
	var altro: Dictionary = c.s.squad.filter(func(p: Dictionary) -> bool: return p.pos != "P")[0]
	c.s.offerte = [{"id": altro.id, "squadra": t.id, "soldi": 300, "scade": Mercato.giorno(c.s) + 2}]
	eq(Mercato.accetta(c, 0), "Servono almeno 14 giocatori in rosa", "minimo 14")
	c.reset()
	return done()


func test_cerca_acquirenti_offerta_sicura() -> bool:
	var c := _nuova("vendita.json")
	var p: Dictionary = c.s.squad[8]
	check(Mercato.cerca_acquirenti(c, p.id, true), "messo in vendita")
	check(Mercato.in_vendita(c.s, p.id), "in lista")
	var res := c.dopoPartita(c.finishMatch(1, 0, []), {"gol_a": 1, "gol_b": 0, "me": 0})
	var per_lui: Array = res.offerte.filter(func(o: Dictionary) -> bool: return int(o.id) == int(p.id))
	eq(per_lui.size(), 1, "alla giornata dopo arriva l'offerta")
	check(not Mercato.in_vendita(c.s, p.id), "tolto dalla lista")
	check(int(per_lui[0].soldi) >= JS.jround(CarrieraScript.value(p) * 0.7), "almeno 0,7 × valore")
	# toglierlo dalla vendita
	var q: Dictionary = c.s.squad[9]
	Mercato.cerca_acquirenti(c, q.id, true)
	check(not Mercato.cerca_acquirenti(c, q.id, false), "tolto dalla vendita")
	c.reset()
	return done()


func test_al_massimo_tre_offerte_aperte() -> bool:
	var c := _nuova("tre.json")
	for k in 40:
		Mercato.ricevi(c, JS.rng32(55 + k))
		check(c.s.offerte.size() <= Mercato.MAX_OFFERTE, "mai più di 3 (%d)" % c.s.offerte.size())
	c.reset()
	return done()


# ---------------------------------------------------------------- salvataggio
func test_salvataggio_vecchio_senza_chiavi_del_mercato() -> bool:
	var c := _nuova("vecchio_mercato.json")
	var st: Dictionary = c.s.duplicate(true)
	for k: String in ["ceduti", "trattative", "offerte", "inVendita"]:
		st.erase(k)
	Salv.scrivi(c.percorso, st)
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "si carica")
	eq(c2.s.ceduti, {}, "ceduti vuoto")
	eq(c2.s.trattative, {}, "trattative vuote")
	eq(c2.s.offerte, [], "nessuna offerta")
	eq(c2.s.inVendita, [], "nessuno in vendita")
	check(c2.s.market is Array and c2.s.market.size() == CarrieraScript.MARKET_SIZE, "il vecchio mercato resta")
	var res := c2.dopoPartita(c2.finishMatch(1, 0, []), {"gol_a": 1, "gol_b": 0, "me": 0})
	check(res.has("offerte"), "e si gioca come prima")
	c.reset()
	return done()


func test_salvataggio_con_dati_rotti_si_pulisce() -> bool:
	var c := _nuova("rotto_mercato.json")
	var t := _prima_squadra(c)
	c.s.ceduti = {t.id: [2, "x", -1, 2], "nessuna": [1], "me": [0]}
	c.s.trattative = {"a": 5, "b": {"giorno": Mercato.giorno(c.s), "esito": "rifiuta", "prezzo": 100},
		"vecchia": {"giorno": Mercato.giorno(c.s) - 1, "esito": "rifiuta", "prezzo": 100}}
	c.s.offerte = [{"id": 99999, "squadra": t.id, "soldi": 1, "scade": 999}, "x",
		{"id": c.s.squad[2].id, "squadra": t.id, "soldi": 50, "scade": 999}]
	c.s.inVendita = [c.s.squad[3].id, 99999, "y"]
	c.save()
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "si carica")
	eq(c2.s.ceduti, {t.id: [2]}, "ceduti puliti")
	eq(c2.s.trattative.keys(), ["b"], "solo la trattativa di oggi")
	eq(c2.s.offerte.size(), 1, "solo l'offerta valida")
	eq(c2.s.inVendita, [c.s.squad[3].id], "solo chi c'è ancora")
	c.reset()
	return done()
