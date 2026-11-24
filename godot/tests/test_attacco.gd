# Fase d'attacco della CPU con l'opzione "attacco" (sim/attacco.gd, studio degli stili del 2026-11-24):
# attacchi all'area e cross verso chi arriva, taglio anticipato (qualche fuorigioco), contropiede basso in difesa,
# fasce (sovrapposizione, mezzala dentro, esterni sfalsati), contropiede palla a terra e lanci più alti.
# Con l'opzione spenta il motore resta quello di prima.
extends "test_base.gd"

const Stili := preload("../sim/stili.gd")


static func _impronta(m: SimMatchScript) -> float:
	var h: float = m.ball.x * 3.0 + m.ball.y * 7.0 + m.ball.h * 11.0
	for p: R.Player in m.players:
		h = h * 1.0000001 + p.x * 13.0 + p.y * 17.0 + p.vx * 19.0 + p.vy * 23.0
	return h


func _traccia(extra: Dictionary, sec: float, sd: int) -> Array:
	var ta := H.mkTeam("A", 62, sd * 7 + 1, "4-3-3")
	var tb := H.mkTeam("B", 62, sd * 13 + 5)
	ta["stileAtt"] = "fasce"
	tb["stileAtt"] = "contropiede"
	var m := H.newMatch(sd, 60.0, [false, false], ta, tb, "", extra)
	var out: Array = []
	for i in int(sec * 60.0):
		m.step(DT)
		out.append(_impronta(m))
		m.events.clear()
	out.append(m.score.duplicate())
	return out


func test_spenta_come_prima_accesa_cambia() -> bool:
	var base := _traccia({}, 40.0, 6)
	eq(_traccia({"attacco": false}, 40.0, 6), base, "opzione spenta = come senza opzione")
	check(_traccia({"attacco": true}, 40.0, 6) != base, "opzione accesa: la partita cambia")
	return done()


# scena: la squadra 0 (CPU) col pallone sulla fascia destra vicino all'area avversaria; difesa della squadra 1 schierata
func _scena_fascia(on: bool, bx: float = 24.0, by: float = 37.0) -> SimMatchScript:
	var m := H.scene(5, [false, false])
	m.attaccoOn = on
	var t0 := m.team(0)
	var t1 := m.team(1)
	H.wake(t0[0], 0.0, -45.0)
	for k in range(1, 5):
		H.wake(t0[k], -18.0 + (k - 1) * 12.0, -2.0)
	H.wake(t0[5], -20.0, 18.0)
	H.wake(t0[6], -6.0, 16.0)
	H.wake(t0[7], 6.0, 20.0)
	var c: R.Player = t0[8]
	H.wake(c, bx, by)
	H.wake(t0[9], -3.0, 32.5)
	H.wake(t0[10], 4.0, 32.0)
	H.wake(t1[0], 0.0, 49.0)
	for k in range(1, 5):
		H.wake(t1[k], -15.0 + (k - 1) * 9.0, 36.0)
	for k in range(5, 9):
		H.wake(t1[k], -15.0 + (k - 5) * 10.0, 18.0)
	H.wake(t1[9], -5.0, 0.0)
	H.wake(t1[10], 5.0, 0.0)
	H.give(m, c)
	c.aiT = 99.0 # il portatore non decide da solo durante la scena
	m.think(DT)
	return m


func test_corse_in_area_primo_e_secondo_palo() -> bool:
	var m := _scena_fascia(true)
	var rs: Array = m.boxRun[0]
	eq(rs.size(), 2, "pallone sulla fascia vicino all'area: due compagni attaccano l'area")
	for q: R.Player in rs:
		check(q.pos == "A" or q.pos == "C", "corre in area una punta o un centrocampista")
		check(q != m.ball.owner, "non il portatore")
	# quando parte il cross i due vanno ai pali (dentro l'area), uno sul primo e uno sul secondo
	var c := m.ball.owner
	m.kick(c, {"type": "loft", "tx": 0.0, "ty": 44.0})
	var xs: Array = []
	for q: R.Player in rs:
		m.support(q) # (chi va a prendere il pallone segue chase, qui si guarda la corsa)
		check(q.ty > C.HL - 10.0 and absf(q.tx) < 6.0, "dentro l'area vicino alla porta (%.1f, %.1f)" % [q.tx, q.ty])
		xs.append(q.tx)
	check(xs.size() == 2 and (xs[0] > 0.0) != (xs[1] > 0.0), "uno sul primo palo (lato del pallone) e uno sul secondo")
	var off := _scena_fascia(false)
	eq(off.boxRun[0].size(), 0, "opzione spenta: nessuna corsa in area")
	return done()


func test_pallone_lontano_niente_corse() -> bool:
	var m := _scena_fascia(true, 0.0, -10.0)
	eq(m.boxRun[0].size(), 0, "pallone nella propria metà: nessuno attacca l'area")
	return done()


func test_cross_verso_chi_arriva() -> bool:
	var m := _scena_fascia(true)
	var c := m.ball.owner
	var o: Variant = m.passOptions(c)
	check(o != null and o.get("cross", false), "cross verso chi sta arrivando in area")
	if o != null and o.get("cross", false):
		check(o.ty > C.HL - C.BOX_D and absf(o.tx) < C.BOX_W / 2.0, "il cross va in area")
		check(m.boxRun[0].has(o.m), "verso uno di quelli che corrono")
	var off := _scena_fascia(false)
	var o2: Variant = off.passOptions(off.ball.owner)
	check(o2 == null or not o2.get("cross", false), "opzione spenta: nessuno in area, niente cross")
	return done()


func test_taglio_anticipato_e_fuorigioco_lento() -> bool:
	# il taglio anticipato porta l'attaccante oltre la linea e il filtrante a volte parte lo stesso
	var m := _scena_fascia(true, 0.0, 15.0)
	var a: R.Player = m.team(0)[10]
	m.gambleT[a.i] = 1.0
	m.support(a)
	check(a.ty > m.offLine[0], "nel taglio anticipato la meta è oltre la linea del fuorigioco")
	# partite intere CPU contro CPU: qualche fuorigioco, non troppi
	var cnt := {"n": 0}
	var partite := 3
	for k in partite:
		H.playMatch({"seed": 40 + k, "halfLen": 150.0, "mode": "ai", "extra": {"attacco": true, "rifiniture": true}}, func(mm: SimMatchScript) -> void:
			for e: Dictionary in mm.events:
				if e.type == "offside":
					cnt.n += 1
		)
	var n: int = cnt.n
	note("fuorigioco in %d partite CPU contro CPU: %d" % [partite, n])
	check(n >= 1, "almeno un fuorigioco")
	check(n <= partite * 5, "pochi fuorigioco (al massimo 5 a partita)")
	return done()


# posto di un giocatore con la squadra in attacco o in difesa
func _posto(m: SimMatchScript, p: R.Player, attacca: bool) -> PackedFloat64Array:
	m.att = p.team if attacca else 1 - p.team
	return m.anchor(p)


func _scena(form: String, att: Variant, on: bool, bx: float = 0.0, by: float = 0.0) -> SimMatchScript:
	var m := H.newMatch(3, 9999.0, [false, false], H.mkTeam("A", 60, 22, form), H.mkTeam("B", 60, 44))
	m.phase = "play"
	m.restart = null
	m.ball.x = bx
	m.ball.y = by
	m.stA[0] = Stili.att(att)
	m.attaccoOn = on
	return m


func test_contropiede_basso_in_difesa_non_in_attacco() -> bool:
	var eqm := _scena("4-4-2", null, true)
	var con := _scena("4-4-2", "contropiede", true)
	var vec := _scena("4-4-2", "contropiede", false)
	for i in range(1, 11):
		var pe: R.Player = eqm.team(0)[i]
		var pc: R.Player = con.team(0)[i]
		var pv: R.Player = vec.team(0)[i]
		check(_posto(con, pc, false)[1] < _posto(eqm, pe, false)[1] - 3.0, "contropiede in difesa più basso: " + pc.pos)
		if pc.pos == "C":
			check(_posto(con, pc, true)[1] > _posto(vec, pv, true)[1] + 3.0, "in attacco il centrocampista non resta più basso")
			near(_posto(con, pc, true)[1], _posto(eqm, pe, true)[1], 0.01, "in attacco come l'equilibrato")
	var a := absf(_posto(con, con.team(0)[5], false)[0])
	check(a < absf(_posto(eqm, eqm.team(0)[5], false)[0]), "in difesa più stretto")
	return done()


func test_esterni_sfalsati() -> bool:
	for form: String in ["4-4-2", "4-2-3-1"]:
		var m := _scena(form, null, true)
		var d: R.Player = m.team(0)[4]   # terzino destro
		var e: R.Player = null
		for q: R.Player in m.team(0):
			if q.pos == "C" and q.bx > 0.6:
				e = q
		var xd := _posto(m, d, true)[0]
		var xe := _posto(m, e, true)[0]
		check(xe > xd + 4.0, "%s: l'esterno sulla riga, il terzino più dentro (%.1f / %.1f)" % [form, xe, xd])
		var v := _scena(form, null, false)
		near(_posto(v, v.team(0)[4], true)[0], _posto(v, e, true)[0], 0.01, form + ": prima erano sulla stessa riga")
	return done()


func test_fasce_mezzala_433_resta_dentro() -> bool:
	var m := _scena("4-3-3", "fasce", true)
	var v := _scena("4-3-3", "fasce", false)
	for i in [5, 7]:
		var x := absf(_posto(m, m.team(0)[i], true)[0])
		check(x < C.HW * 0.7, "mezzala non sulla riga (%.1f)" % x)
		check(absf(_posto(v, v.team(0)[i], true)[0]) > C.HW * 0.85, "prima andava sulla riga")
	return done()


func test_fasce_sovrapposizione_del_terzino() -> bool:
	# pallone sulla fascia sinistra nella metà avversaria: il terzino sinistro sale largo, l'esterno si stringe
	var m := _scena("4-4-2", "fasce", true, -24.0, 15.0)
	var v := _scena("4-4-2", "fasce", false, -24.0, 15.0)
	var d: R.Player = m.team(0)[1]
	var e: R.Player = m.team(0)[5]
	var pd := _posto(m, d, true)
	var pe := _posto(m, e, true)
	check(pd[1] > _posto(v, v.team(0)[1], true)[1] + 15.0, "il terzino sale")
	check(pd[1] >= pe[1] - 1.0, "il terzino arriva all'altezza dell'esterno o oltre")
	check(pd[0] < pe[0] - 4.0, "il terzino è più largo dell'esterno, che si stringe")
	# dall'altra parte niente sovrapposizione: terzino destro più dentro
	check(_posto(m, m.team(0)[4], true)[0] < _posto(m, m.team(0)[8], true)[0] - 4.0, "lato opposto sfalsato")
	return done()


func test_contropiede_palla_a_terra_lanci_alti() -> bool:
	var m := _scena("4-4-2", "contropiede", true)
	var c: R.Player = m.team(0)[8]
	H.give(m, c)
	m.possT0[0] = m.time
	var con: Stili.Att = Stili.att("contropiede")
	var lan: Stili.Att = Stili.att("lanci")
	var g_on := m._styleScore(con, 0, 30.0, 20.0, 0.5, "ground", false)
	var l_on := m._styleScore(con, 0, 30.0, 20.0, 0.5, "loft", false)
	check(l_on < g_on - 0.5, "contropiede: il pallonetto vale meno del passaggio a terra")
	var ll_on := m._styleScore(lan, 0, 30.0, 20.0, 0.5, "loft", false)
	m.attaccoOn = false
	check(is_equal_approx(m._styleScore(con, 0, 30.0, 20.0, 0.5, "loft", false), g_on), "prima pallonetto e passaggio a terra pari")
	check(ll_on > m._styleScore(lan, 0, 30.0, 20.0, 0.5, "loft", false) + 0.2, "lanci lunghi: il lancio alto vale di più")
	return done()
