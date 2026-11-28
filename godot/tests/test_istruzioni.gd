# Istruzioni ai giocatori (Luis 2026-11-28): dati (sim/istruzioni.gd), carriera (s.istruzioni → istr della copia del
# giocatore), squadre della CPU e motore (sim/istruzioni_gioco.gd).
extends "res://tests/test_base.gd"

const Istr := preload("res://sim/istruzioni.gd")
const SALVA := "user://test_istruzioni.json"


func _carriera() -> Carriera:
	var c := Carriera.new()
	c.percorso = SALVA
	c.create("Prova", 1, 4321)
	return c


func _fine() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SALVA))


func _partita(mia: Dictionary, avv: Dictionary) -> SimMatchScript:
	return SimMatchScript.new({"seed": 9, "halfLen": 150, "human": [false, false], "teams": [mia, avv], "kickoff": 0,
		"rifiniture": true, "riprese": true, "falli": true, "contatti": true, "testa": true, "attacco": true})


# indice del primo posto col ruolo r nella squadra 0, -1 se non c'è
func _posto(m: SimMatchScript, r: String) -> int:
	for p: R.Player in m.team(0):
		if p.ruolo == r:
			return p.i
	return -1


# posto in campo (anchor) del giocatore i della squadra 0 con le istruzioni ist, a pallone fermo in (bx, by) e squadra
# che attacca `att`
func _anchor(c: Carriera, i: int, ist: Dictionary, bx: float, by: float, att: int) -> PackedFloat64Array:
	var mia := c.squadraPartita()
	var avv := c.avversarioPartita(c.team(c.s.divs[2][1]))
	if not ist.is_empty():
		mia.players[i]["istr"] = ist
	var m := _partita(mia, avv)
	m.ball.x = bx
	m.ball.y = by
	m.att = att
	var a := m.anchor(m.team(0)[i])
	m.dispose()
	return a


func test_dati_di_ogni_ruolo() -> bool:
	for r: String in ["P", "TD", "TS", "DC", "CDC", "CC", "ED", "ES", "COC", "ATT", "AD", "AS"]:
		check(not Istr.del_ruolo(r).is_empty(), "%s ha almeno un'istruzione" % r)
		for k: String in Istr.del_ruolo(r):
			eq(Istr.scelte(k).size(), 3, "%s: tre scelte" % k)
			check(Istr.nome(k) != "" and Istr.base(k) != "", "%s: nome e scelta di mezzo" % k)
	eq(Istr.pulisci({"spinta": "equilibrato", "fascia": "largo", "x": "y", "ala": "boh"}), {"fascia": "largo"}, "pulisci tiene solo le scelte vere e diverse da quella di mezzo")
	eq(Istr.verso({"spinta": "offensivo"}, "spinta"), 1, "offensivo = +1")
	eq(Istr.verso({"spinta": "difensivo"}, "spinta"), -1, "difensivo = -1")
	eq(Istr.verso({}, "spinta"), 0, "niente = 0")
	return done()


func test_carriera_salva_e_passa_al_motore() -> bool:
	var c := _carriera()
	var id: Variant = c.s.lineup[1]
	check(c.setIstruzione(id, "spinta", "offensivo"), "istruzione data")
	check(not c.setIstruzione(id, "spinta", "a caso"), "scelta sconosciuta rifiutata")
	eq(c.istruzioni(id), {"spinta": "offensivo"}, "letta")
	var c2 := Carriera.new()
	c2.percorso = SALVA
	c2.load()
	eq(c2.istruzioni(id), {"spinta": "offensivo"}, "ricaricata dal salvataggio")
	var t := c2.squadraPartita()
	var trovato := false
	for q: Dictionary in t.players:
		if str(q.get("id")) == str(id):
			eq(q.get("istr"), {"spinta": "offensivo"}, "nella copia per la partita")
			trovato = true
		elif q.has("istr"):
			check(false, "%s: niente istruzioni non date" % q.get("name"))
	check(trovato, "giocatore in squadra")
	check(c2.setIstruzione(id, "spinta", "equilibrato"), "tornato a come sempre")
	eq(c2.istruzioni(id), {}, "come sempre = niente salvato")
	check(not (c2.s.istruzioni as Dictionary).has(str(id)), "voce tolta dal salvataggio")
	_fine()
	return done()


func test_squadre_della_cpu_secondo_lo_stile() -> bool:
	var ruoli := ["P", "TS", "DC", "DC", "TD", "ES", "CC", "CC", "ED", "ATT", "ATT"]
	var piu := 0
	var tot := 0
	for seme in 40:
		var a := Istr.per_squadra("fasce", "equilibrata", ruoli, seme)
		eq(a, Istr.per_squadra("fasce", "equilibrata", ruoli, seme), "stesse istruzioni con lo stesso seme")
		for i in [1, 4]:
			tot += 1
			if Istr.di(a[i], "spinta") == "offensivo":
				piu += 1
	check(piu > tot / 2, "gioco sulle fasce: terzini quasi sempre offensivi (%d su %d)" % [piu, tot])
	var c := _carriera()
	var avv := c.avversarioPartita(c.team(c.s.divs[2][1]))
	var con := 0
	for q: Variant in avv.players:
		if q is Dictionary and q.has("istr"):
			con += 1
	check(con > 0, "la CPU dà istruzioni ai suoi giocatori (%d)" % con)
	_fine()
	return done()


func test_senza_istruzioni_motore_identico() -> bool:
	var c := _carriera()
	var mia := c.squadraPartita()
	var avv := c.avversarioPartita(c.team(c.s.divs[2][1]))
	for q: Variant in avv.players:
		if q is Dictionary:
			q.erase("istr")
	var m1 := _partita(mia.duplicate(true), avv.duplicate(true))
	var mia2: Dictionary = mia.duplicate(true)
	for q: Variant in mia2.players: # scelte di mezzo = come niente
		if q is Dictionary:
			q["istr"] = {"spinta": "equilibrato", "movimento": "equilibrato", "uscite": "equilibrato"}
	var m2 := _partita(mia.duplicate(true), avv.duplicate(true))
	var m3 := _partita(mia2, avv.duplicate(true))
	for i in 1800:
		m1.step(DT)
		m2.step(DT)
		m3.step(DT)
	var ok := true
	for k in 22:
		var a: R.Player = m1.players[k]
		for mm: SimMatchScript in [m2, m3]:
			var b: R.Player = mm.players[k]
			if a.x != b.x or a.y != b.y:
				ok = false
	check(ok, "stesse posizioni dopo 30 s (niente istruzioni e scelte di mezzo)")
	eq(m3.score, m1.score, "stesso risultato")
	for mm: SimMatchScript in [m1, m2, m3]:
		mm.dispose()
	_fine()
	return done()


func test_ogni_istruzione_sposta_nel_verso_giusto() -> bool:
	var c := _carriera()
	var m0 := _partita(c.squadraPartita(), c.avversarioPartita(c.team(c.s.divs[2][1])))
	var ts := _posto(m0, "TS")
	var dc := _posto(m0, "DC")
	var att := _posto(m0, "ATT")
	var mid := _posto(m0, "CC")
	m0.dispose()
	check(ts >= 0 and dc >= 0 and att >= 0 and mid >= 0, "posti trovati")
	# attacco (squadra 0 verso +y), pallone a centrocampo sulla sinistra
	var y0 := _anchor(c, ts, {}, -15.0, 5.0, 0)[1]
	check(_anchor(c, ts, {"spinta": "offensivo"}, -15.0, 5.0, 0)[1] > y0 + 5.0, "terzino offensivo più alto")
	check(_anchor(c, ts, {"spinta": "difensivo"}, -15.0, 5.0, 0)[1] < y0 - 5.0, "terzino difensivo più basso")
	var m_y := _anchor(c, mid, {}, 0.0, 5.0, 0)[1]
	check(_anchor(c, mid, {"mezzala": "avanzato"}, 0.0, 5.0, 0)[1] > m_y + 3.0, "centrocampista avanzato più alto")
	check(_anchor(c, mid, {"mezzala": "difensivo"}, 0.0, 5.0, 0)[1] < m_y - 3.0, "centrocampista difensivo più basso")
	# istruzione di un altro ruolo: non conta
	eq(_anchor(c, mid, {"spinta": "offensivo"}, 0.0, 5.0, 0)[1], m_y, "istruzione di un altro ruolo ignorata")
	# difesa: attaccante che resta su
	var a_y := _anchor(c, att, {}, 0.0, -10.0, 1)[1]
	check(_anchor(c, att, {"pressione": "resta"}, 0.0, -10.0, 1)[1] > a_y + 5.0, "attaccante che resta su più alto in difesa")
	var d_y := _anchor(c, dc, {}, 0.0, -10.0, 1)[1]
	check(_anchor(c, dc, {"marcatura": "copre"}, 0.0, -10.0, 1)[1] < d_y - 1.5, "centrale che copre più basso")
	_fine()
	return done()


func test_in_partita_si_vede() -> bool:
	# terzini offensivi contro difensivi: in 3 minuti di partita i primi stanno in media più avanti
	var c := _carriera()
	var medie := []
	for scelta: String in ["difensivo", "offensivo"]:
		var mia := c.squadraPartita()
		var avv := c.avversarioPartita(c.team(c.s.divs[2][1]))
		for q: Variant in avv.players:
			if q is Dictionary:
				q.erase("istr")
		var m := _partita(mia, avv)
		var ter: Array = []
		for p: R.Player in m.team(0):
			if p.ruolo == "TS" or p.ruolo == "TD":
				p.src["istr"] = {"spinta": scelta}
				ter.append(p)
		var somma := 0.0
		var n := 0
		for i in 10800:
			m.step(DT)
			if i % 30 == 0 and m.att == 0:
				for p: R.Player in ter:
					somma += p.y
					n += 1
		medie.append(somma / maxi(n, 1))
		m.dispose()
	note("terzini in attacco, y media: difensivi %.1f, offensivi %.1f" % medie)
	check(medie[1] > medie[0] + 6.0, "terzini offensivi più avanti dei difensivi")
	_fine()
	return done()
