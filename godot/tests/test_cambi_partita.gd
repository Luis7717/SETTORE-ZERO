# Rosa e tattica nella pausa (Luis 2026-11-24): cambi a partita in corso (scripts/partita/cambi_partita.gd →
# SimMatch.cambiaSquadra) e campione sempre titolare fuori partita (Carriera.swap / tieniCampione).
extends "res://tests/test_base.gd"

const CambiPartita := preload("res://scripts/partita/cambi_partita.gd")
const Stili := preload("res://sim/stili.gd")
const SALVA := "user://test_cambi_partita.json"


func _carriera() -> Carriera:
	var c := Carriera.new()
	c.percorso = SALVA
	c.create("Prova", 1, 777)
	return c


func _partita(c: Carriera) -> SimMatchScript:
	var avv: Dictionary = c.team(c.s.divs[2][1])
	return SimMatchScript.new({"seed": 5, "halfLen": 150, "human": [true, false], "teams": [c.squadraPartita(), c.avversarioPartita(avv)],
		"rifiniture": true, "riprese": true, "falli": true, "contatti": true, "testa": true, "attacco": true})


func _fine() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SALVA))


# un panchinaro sano non ancora uscito (del ruolo `pos` se c'è)
func _panchinaro(c: Carriera, cambi: CambiPartita, pos: String = "") -> Variant:
	var scelto: Variant = null
	for q: Dictionary in c.bench():
		if cambi.uscito(q.id) or cambi.in_campo.has(q.id) or c.infortunio(q.id) > 0: # (in_campo: aspetta di uscire)
			continue
		if q.pos == pos:
			return q.id
		if scelto == null:
			scelto = q.id
	return scelto


# sostituzione come la fa la Rosa in partita: controllo, scambio, registrazione
func _sostituisci(c: Carriera, cambi: CambiPartita, tit: Variant, entra: Variant) -> String:
	var err := cambi.errore_scambio(c.s.lineup, tit, entra, func(x: Variant) -> String: return str(c.player(x).name))
	if err != "":
		return err
	var prima: Array = c.s.lineup.duplicate()
	c.swap(tit, entra, true)
	if c.s.lineup != prima:
		cambi.registra(prima, tit, entra)
	return ""


func test_sostituzione_va_nel_motore() -> bool:
	var c := _carriera()
	var m := _partita(c)
	for i in 300:
		m.step(DT)
	var cambi := CambiPartita.new()
	var tit: Variant = c.s.lineup[9]
	var vecchio: R.Player = m.team(0)[9]
	vecchio.energy = 0.5
	var x0 := vecchio.x
	var entra: Variant = _panchinaro(c, cambi, "A")
	eq(_sostituisci(c, cambi, tit, entra), "", "sostituzione permessa")
	m.events.clear()
	var fatti: Variant = cambi.applica(m, 0, c)
	check(fatti is Array and (fatti as Array).size() == 1, "un cambio fatto")
	var p: R.Player = m.team(0)[9]
	eq(p.src.id, entra, "al posto 9 c'è chi entra")
	eq(p.name, str(c.player(entra).name), "nome di chi entra")
	eq(p.energy, 1.0, "chi entra ha energia piena")
	eq(p.x, x0, "entra dove stava chi esce")
	eq(p.pos, C.FORMATIONS[c.s.formation][9][0], "ruolo del posto")
	var e: Variant = findEvent(m.events, "sub")
	check(e != null and e.get("fuori", "") == str(c.player(tit).name), "evento sub con chi esce")
	eq(cambi.fatti, 1, "un cambio contato")
	check(cambi.uscito(tit), "chi esce è segnato uscito")
	eq(cambi.da_mostrare.size(), 1, "un cambio da mostrare nella scena")
	# chi è uscito non rientra
	check(cambi.errore_scambio(c.s.lineup, c.s.lineup[3], tit, func(x: Variant) -> String: return "x") != "", "chi è uscito non rientra")
	# la partita continua senza errori
	for i in 1800:
		m.step(DT)
	eq(m.team(0).size(), 11, "11 giocatori")
	check(m.time > 30.0, "la partita va avanti")
	m.dispose()
	_fine()
	return done()


func test_al_massimo_cinque_cambi() -> bool:
	var c := _carriera()
	var m := _partita(c)
	var cambi := CambiPartita.new()
	for k in CambiPartita.MAX_CAMBI:
		var tit: Variant = c.s.lineup[1 + k]
		eq(_sostituisci(c, cambi, tit, _panchinaro(c, cambi)), "", "cambio %d" % (k + 1))
	eq(cambi.restano(), 0, "nessun cambio rimasto")
	var err := _sostituisci(c, cambi, c.s.lineup[8], _panchinaro(c, cambi))
	check(err.contains("5 cambi"), "il sesto no: " + err)
	var prima: Array = c.s.lineup.duplicate()
	eq(_sostituisci(c, cambi, c.s.lineup[8], c.s.lineup[9]), "", "scambio tra titolari sempre libero")
	check(c.s.lineup != prima, "scambio tra titolari fatto")
	eq(cambi.fatti, 5, "lo scambio tra titolari non conta")
	var fatti: Variant = cambi.applica(m, 0, c)
	eq((fatti as Array).size(), 5, "5 cambi nel motore")
	for i in 11:
		eq(m.team(0)[i].src.id, c.s.lineup[i], "posto %d come la carriera" % i)
	m.dispose()
	_fine()
	return done()


func test_espulso_non_si_sostituisce() -> bool:
	var c := _carriera()
	var m := _partita(c)
	var cambi := CambiPartita.new()
	m.team(0)[4].off = true
	cambi.leggi_espulsi(m, 0)
	var esp: Variant = c.s.lineup[4]
	check(cambi.espulso(esp), "espulso letto dal motore")
	check(cambi.errore_scambio(c.s.lineup, esp, _panchinaro(c, cambi), func(x: Variant) -> String: return "x").contains("espulso"), "non si sostituisce")
	check(cambi.errore_scambio(c.s.lineup, esp, c.s.lineup[6], func(x: Variant) -> String: return "x").contains("espulso"), "non si sposta")
	# nel motore: togliere l'espulso non va (null, niente cambiato)
	var srcs: Array = m.team(0).map(func(p: R.Player) -> Dictionary: return p.src)
	srcs[4] = {"id": 999, "name": "Nuovo", "pos": "D", "vel": 60, "tir": 50, "pas": 50, "dri": 50, "dif": 60, "fis": 60, "por": 10}
	eq(m.cambiaSquadra(0, srcs, c.s.formation), null, "il motore rifiuta")
	check(m.team(0)[4].off and m.team(0)[4].src.id == esp, "l'espulso resta lui")
	# formazione nuova: l'espulso resta al suo posto
	var nuova := cambi.formazione_stessi_11(C.FORMATIONS["3-5-2"], c.s.lineup, func(id: Variant, r: String) -> int: return Carriera.overallAs(c.player(id), r))
	eq(nuova[4], esp, "l'espulso non si sposta col cambio di formazione")
	m.dispose()
	_fine()
	return done()


func test_formazione_e_stili_nel_motore() -> bool:
	var c := _carriera()
	var m := _partita(c)
	for i in 200:
		m.step(DT)
	var cambi := CambiPartita.new()
	var prima: Array = c.s.lineup.duplicate()
	var oggetti := {}
	for p: R.Player in m.team(0):
		oggetti[p.src.id] = p
	c.s.lineup = cambi.formazione_stessi_11(C.FORMATIONS["3-5-2"], c.s.lineup, func(id: Variant, r: String) -> int: return Carriera.overallAs(c.player(id), r))
	c.s.formation = "3-5-2"
	c.setStili("contropiede", "catenaccio")
	var a := prima.duplicate()
	var b: Array = c.s.lineup.duplicate()
	a.sort()
	b.sort()
	eq(b, a, "stessi 11 giocatori")
	eq(c.s.lineup[0], prima[0], "il portiere resta in porta")
	var fatti: Variant = cambi.applica(m, 0, c)
	eq((fatti as Array).size(), 0, "nessuna sostituzione")
	eq(cambi.fatti, 0, "la formazione non conta come cambio")
	var F: Array = C.schema("3-5-2") # posti del gioco (squadraPartita ha "moduli": due mediani bassi, trequartista alto)
	for i in 11:
		var p: R.Player = m.team(0)[i]
		eq([p.pos, p.bx, p.by, p.i], [F[i][0], F[i][1], F[i][2], i], "posto %d della formazione nuova" % i)
		check(is_same(p, oggetti[c.s.lineup[i]]), "posto %d: stesso giocatore (posizione ed energia tenute)" % i)
	check(m.gk(0).pos == "P", "portiere al posto 0")
	eq(m.teams[0].formation, "3-5-2", "formazione della squadra")
	check(m.stA[0].contro and m.stD[0].catenaccio, "stili nuovi nel motore")
	for i in 1200:
		m.step(DT)
	check(m.time > 20.0, "la partita va avanti")
	m.dispose()
	_fine()
	return done()


# Luis 2026-11-28: "se modifico il modulo durante la partita, dopo la partita torna a quello base; stessa cosa per
# le tattiche e i giocatori": formazione, stili e sostituzione decisi nella pausa restano nella carriera dopo la
# partita (fine partita, registrazione del risultato, salvataggio e ricaricamento)
# Luis 2026-11-28: "tutto quello che modifico in partita non deve salvarsi, deve tornare tutto come prima della
# partita": modulo, tattiche, titolari, posti, istruzioni e calci piazzati cambiati nella pausa tornano com'erano
func test_dopo_la_partita_torna_la_squadra_di_prima() -> bool:
	var c := _carriera()
	c.addChampion({"name": "Campione", "ruolo": "ATT", "look": {}, "num": 10})
	c.save()
	var m := _partita(c)
	var cambi := CambiPartita.new()
	cambi.ricorda_prima(c) # come gioco.gd all'inizio della partita
	var lineup0: Array = c.s.lineup.duplicate()
	var form0 := str(c.s.formation)
	var stili0 := [c.stileAtt(), c.stileDif()]
	var istr0: Dictionary = (c.s.get("istruzioni", {}) as Dictionary).duplicate(true)
	var pz0: Dictionary = c.piazzati().duplicate(true)
	for i in 200:
		m.step(DT)
	cambi.leggi_in_campo(m, 0)
	cambi.ricorda(c)
	var nuovo := "4-3-3" if c.s.formation != "4-3-3" else "3-5-2"
	c.s.lineup = cambi.formazione_stessi_11(C.schema(nuovo), c.s.lineup, func(id: Variant, r: String) -> int: return Carriera.overallAs(c.player(id), r), c.ruoliPosti(nuovo))
	c.s.formation = nuovo
	c.setStili("contropiede" if stili0[0] != "contropiede" else "possesso", "catenaccio" if stili0[1] != "catenaccio" else "pressing")
	c.setIstruzione(c.s.lineup[1], "spinta", "sovrapposizione")
	c.setPiazzato("rig", c.s.lineup[5])
	var ch: Variant = c.campione().id
	var tit: Variant = null
	for id: Variant in c.s.lineup.slice(1):
		if not _stesso(id, ch):
			tit = id
			break
	var entra: Variant = _panchinaro(c, cambi)
	eq(_sostituisci(c, cambi, tit, entra), "", "sostituzione permessa")
	check(cambi.applica(m, 0, c) is Array, "cambi nel motore")
	check(c.s.formation == nuovo and c.s.lineup.has(entra), "in partita valgono le scelte della pausa")
	for i in 600:
		m.step(DT)
	m.dispose()
	# fine partita come gioco.gd (_perdi_cambi_in_attesa) e app.gd
	cambi.ripristina(c)
	eq(c.s.lineup, lineup0, "titolari e posti di prima")
	var res := c.finishMatch(1, 0, [])
	if not res.is_empty():
		c.dopoPartita(res, {"me": 0, "gol_a": 1, "gol_b": 0})
	c.tieniCampione()
	c.save()
	for giro in 2:
		var q: String = ["dopo la partita", "ricaricato"][giro]
		eq(c.s.formation, form0, "%s: il modulo di prima" % q)
		eq([c.stileAtt(), c.stileDif()], stili0, "%s: le tattiche di prima" % q)
		eq(c.s.get("istruzioni", {}), istr0, "%s: le istruzioni di prima" % q)
		eq(c.piazzati(), pz0, "%s: i calci piazzati di prima" % q)
		check(not c.s.lineup.has(entra) or lineup0.has(entra), "%s: chi è entrato in partita non resta titolare" % q)
		var c2 := Carriera.new()
		c2.percorso = SALVA
		c2.load()
		c = c2
	_fine()
	return done()


static func _stesso(a: Variant, b: Variant) -> bool:
	return str(a) == str(b)


# Luis 2026-11-24: il campione fuori partita non va in panchina; in partita sì, e alla partita dopo è di nuovo titolare
func test_campione_sempre_titolare_fuori_partita() -> bool:
	var c := _carriera()
	var ch := c.addChampion({"pos": "A", "name": "Campione"})
	c.autoLineup()
	check(c.s.lineup.has(ch.id), "autoLineup: il campione è titolare")
	var panca: Variant = c.bench()[0].id
	c.swap(ch.id, panca)
	check(c.s.lineup.has(ch.id), "nella Rosa del menu non va in panchina")
	c.swap(panca, ch.id)
	check(c.s.lineup.has(ch.id), "neanche toccando prima il panchinaro")
	var altro: Variant = c.s.lineup[1] if c.s.lineup[1] != ch.id else c.s.lineup[2]
	var i_ch: int = c.s.lineup.find(ch.id)
	c.swap(ch.id, altro)
	check(c.s.lineup.find(ch.id) != i_ch and c.s.lineup.has(ch.id), "tra titolari può cambiare posto")
	c.s.formation = "5-3-2"
	c.autoLineup()
	check(c.s.lineup.has(ch.id), "con un'altra formazione resta titolare")
	# in partita si può sostituire ...
	c.swap(ch.id, panca, true)
	check(not c.s.lineup.has(ch.id), "in partita si sostituisce")
	# ... e alla partita dopo torna titolare (squadraPartita all'avvio)
	var t := c.squadraPartita()
	check(c.s.lineup.has(ch.id), "all'avvio della partita dopo è titolare")
	check(t.players.any(func(p: Variant) -> bool: return p is Dictionary and p.id == ch.id), "ed è in campo nella squadra della partita")
	# salvataggio vecchio col campione in panchina: al caricamento torna titolare
	c.swap(ch.id, panca, true)
	c.save()
	var d := Carriera.new()
	d.percorso = SALVA
	check(d.load(), "salvataggio letto")
	check(d.s.lineup.has(ch.id), "caricato: il campione è titolare")
	var ids := {}
	for id: Variant in d.s.lineup:
		ids[id] = true
	eq(ids.size(), 11, "11 titolari diversi")
	_fine()
	return done()


# Luis 2026-11-25: "Ovviamente il campione non deve essere venduto"
func test_campione_non_si_vende() -> bool:
	var c := _carriera()
	var ch := c.addChampion({"pos": "A", "name": "Campione"})
	var soldi: int = c.s.money
	var n: int = c.s.squad.size()
	check(c.sell(ch.id) != "", "la vendita del campione viene rifiutata")
	check(c.player(ch.id) != null and c.s.squad.size() == n and c.s.money == soldi, "il campione resta e i soldi non cambiano")
	var altro: Variant = c.bench()[0].id
	check(c.sell(altro) == "", "gli altri si vendono ancora")
	_fine()
	return done()


# Luis 2026-11-25 "non capisco se si sono rigenerate": la Rosa della pausa mostra l'energia vera del motore
func test_energie_in_partita_dal_motore() -> bool:
	var c := _carriera()
	var m := _partita(c)
	var cp := CambiPartita.new()
	var p: Object = m.team(0)[5]
	p.energy = 0.63
	cp.leggi_energie(m, 0)
	eq(cp.energia(p.src.id), 63, "energia del motore in percentuale")
	eq(cp.energia(-999), 100, "chi non è in campo (panchina): piena")
	m.dispose()
	return done()


# Luis 2026-11-27 "per fare i cambi aspetta che la palla esca": le sostituzioni in attesa si contano subito nei 5,
# chi deve uscire non è ancora "uscito" (resta in campo nel motore) e finché aspettano si possono disfare
func test_cambi_in_attesa_si_contano_e_si_disfano() -> bool:
	var c := _carriera()
	var m := _partita(c)
	var cambi := CambiPartita.new()
	cambi.leggi_in_campo(m, 0)
	cambi.ricorda(c)
	var tit: Variant = c.s.lineup[9]
	var entra: Variant = _panchinaro(c, cambi, "A")
	eq(_sostituisci(c, cambi, tit, entra), "", "sostituzione decisa")
	eq(cambi.fatti, 1, "conta subito")
	eq(cambi.restano(), 4, "ne restano 4")
	check(cambi.serve_attesa(c.s.lineup), "c'è un cambio da aspettare")
	check(not cambi.uscito(tit), "chi deve uscire non è ancora uscito")
	eq(m.team(0)[9].src.id, tit, "nel motore non è cambiato niente")
	# ci si ripensa: chi doveva uscire rientra, il cambio non conta più
	eq(_sostituisci(c, cambi, entra, tit), "", "il cambio in attesa si disfa")
	eq(cambi.fatti, 0, "nessun cambio")
	check(not cambi.serve_attesa(c.s.lineup), "niente da aspettare")
	# catena: A esce per B, poi B (mai entrato) esce per C = una sola sostituzione
	eq(_sostituisci(c, cambi, tit, entra), "", "A per B")
	var terzo: Variant = _panchinaro(c, cambi)
	eq(_sostituisci(c, cambi, entra, terzo), "", "B per C")
	eq(cambi.fatti, 1, "una sola sostituzione")
	# al limite: 5 in attesa, il sesto no, disfarne uno sì
	for k in 4:
		eq(_sostituisci(c, cambi, c.s.lineup[1 + k], _panchinaro(c, cambi)), "", "cambio %d" % (k + 2))
	eq(cambi.fatti, 5, "5 in attesa")
	check(_sostituisci(c, cambi, c.s.lineup[6], _panchinaro(c, cambi)).contains("5 cambi"), "il sesto no")
	var fuori1: Variant = cambi.in_campo.filter(func(id: Variant) -> bool: return not c.s.lineup.has(id))[0]
	var dentro1: Variant = cambi.entrati_in_attesa(c.s.lineup)[0]
	eq(_sostituisci(c, cambi, dentro1, fuori1), "", "al limite si può disfare")
	eq(cambi.fatti, 4, "4 in attesa")
	m.dispose()
	_fine()
	return done()


func test_cambi_in_attesa_entrano_nel_motore() -> bool:
	var c := _carriera()
	var m := _partita(c)
	var cambi := CambiPartita.new()
	cambi.leggi_in_campo(m, 0)
	cambi.ricorda(c)
	var tit: Variant = c.s.lineup[9]
	var entra: Variant = _panchinaro(c, cambi, "A")
	_sostituisci(c, cambi, tit, entra)
	cambi.attesa = true
	var fatti: Variant = cambi.applica(m, 0, c)
	eq((fatti as Array).size(), 1, "un cambio nel motore")
	check(not cambi.attesa, "non più in attesa")
	eq(cambi.confermati, 1, "confermato")
	check(cambi.uscito(tit), "ora è uscito davvero")
	check(cambi.in_campo.has(entra) and not cambi.in_campo.has(tit), "in campo letti dal motore")
	check(cambi.errore_scambio(c.s.lineup, entra, tit, func(x: Variant) -> String: return "x") != "", "non rientra più")
	eq(cambi.base.lineup, c.s.lineup, "la squadra ricordata è quella in campo")
	m.dispose()
	_fine()
	return done()


# la partita finisce coi cambi in attesa: si perdono, la carriera torna alla squadra in campo
func test_cambi_in_attesa_a_fine_partita() -> bool:
	var c := _carriera()
	var m := _partita(c)
	var cambi := CambiPartita.new()
	cambi.ricorda_prima(c)
	cambi.leggi_in_campo(m, 0)
	cambi.ricorda(c)
	var prima: Array = c.s.lineup.duplicate()
	var form: String = str(c.s.formation)
	var att := c.stileAtt()
	_sostituisci(c, cambi, c.s.lineup[9], _panchinaro(c, cambi, "A"))
	c.s.lineup = cambi.formazione_stessi_11(C.FORMATIONS["3-5-2"], c.s.lineup, func(id: Variant, r: String) -> int: return Carriera.overallAs(c.player(id), r))
	c.s.formation = "3-5-2"
	c.setStili("contropiede" if att != "contropiede" else "possesso", null)
	cambi.attesa = true
	cambi.ripristina(c)
	eq(c.s.lineup, prima, "titolari di prima")
	eq(c.s.formation, form, "formazione di prima")
	eq(c.stileAtt(), att, "stile di prima")
	eq(cambi.fatti, 0, "nessun cambio")
	check(not cambi.attesa, "niente in attesa")
	var d := Carriera.new()
	d.percorso = SALVA
	check(d.load() and d.s.lineup == prima and d.s.formation == form, "salvato com'era")
	m.dispose()
	_fine()
	return done()


# quando possono entrare: ripresa non ancora battuta (anche durante la scena del battitore), non in gioco, non col
# portiere che tiene il pallone, non a rincorsa partita, non durante la festa del gol (dopo, al calcio d'inizio sì)
func test_gioco_fermo_alle_interruzioni() -> bool:
	var c := _carriera()
	var m := _partita(c)
	check(CambiPartita.gioco_fermo(m), "calcio d'inizio")
	var n := 0
	while m.phase != "play" and n < 3000:
		m.step(DT)
		n += 1
	check(not CambiPartita.gioco_fermo(m), "palla in gioco")
	m.ball.last = m.team(1)[9]
	m.out(C.HW + 0.6, 10.0, 0.0)
	check(m.phase == "restart" and m.restart.type == "throw", "rimessa")
	check(CambiPartita.gioco_fermo(m), "rimessa: fermo (scena %s)" % m.restart.scena)
	m.restart.pend = {}
	check(not CambiPartita.gioco_fermo(m), "rincorsa partita: no")
	m.restart.pend = null
	m.setRestart("gk", 0, 0.0, -45.0, m.gk(0))
	check(not CambiPartita.gioco_fermo(m), "pallone in mano al portiere: no")
	m.setRestart("freekick", 0, 0.0, 0.0)
	check(CambiPartita.gioco_fermo(m), "punizione")
	m.goal(0)
	check(not CambiPartita.gioco_fermo(m), "festa del gol: no")
	n = 0
	while m.phase == "goal" and n < 600:
		m.step(DT)
		n += 1
	check(m.phase == "restart" and m.restart.type == "kickoff", "calcio d'inizio dopo il gol")
	check(CambiPartita.gioco_fermo(m), "prima del calcio d'inizio: fermo")
	m.dispose()
	_fine()
	return done()
