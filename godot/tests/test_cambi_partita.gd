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
		if cambi.uscito(q.id) or c.infortunio(q.id) > 0:
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
	var F: Array = C.FORMATIONS["3-5-2"]
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
