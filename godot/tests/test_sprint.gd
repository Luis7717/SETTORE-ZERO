# Fuga e tasto Scatto (Luis 2026-11-21): porting di test/unit/flee.test.mjs. Avversario vicino alla pari o dietro
# "per linee" (linee parallele alle linee di porta) = niente duello, rallenty e tasto Scatto. Davanti per linee =
# duello col Dribbling e il passaggio disegnato.
# (Lo scatto della corsa, tenendo il dito lontano, è in test_attack.gd.)
extends "test_base.gd"

const D := preload("../sim/duel.gd")


# portatore umano (squadra 0) a centrocampo che corre verso +y, avversario della squadra 1 in (ox, oy) rispetto a lui
static func setup(seed_value: int, ox: float = 0.0, oy: float = -2.5) -> Array:
	var m := H.scene(seed_value)
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, 0, 0)
	p.fx = 0
	p.fy = 1
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, ox, oy)
	o.fx = 0
	o.fy = 1
	return [m, p, o]


# dito fermo sul portatore: resta dov'è
static func hold(m: SimMatchScript, p: R.Player) -> Callable:
	return func(_mm: SimMatchScript) -> void: m.userMove(0, p.x, p.y, true)


func test_fuga_si_apre_alle_spalle_o_alla_pari_non_e_un_duello() -> bool:
	for off: Array in [[0.0, -2.5], [2.5, 0.0], [-2.0, -1.5], [3.0, D.LEVEL_TOL * 0.8]]:
		# Arrange
		var s := setup(1, off[0], off[1])
		var m: SimMatchScript = s[0]
		var p: R.Player = s[1]
		var o: R.Player = s[2]
		# Act
		var evs := H.run(m, 1.0 / 60.0, hold(m, p))
		# Assert
		var st: Variant = findEvent(evs, "flee_start")
		check(st != null and st.p == p and st.o == o, "avversario in %s" % str(off))
		eq(m.fleeFor(0), true, "fuga aperta (%s)" % str(off))
		eq(m.duelFor(0), false, "niente duello")
		eq(m.passFor(0), true, "nella fuga si può passare (Luis 2026-11-21)")
		m.dispose()
	return done()


func test_fuga_non_si_apre_davanti_lontano_o_per_la_cpu() -> bool:
	# Arrange / Act
	var a := setup(2, 0.0, 3.0)
	var b := setup(3, 0.0, -(D.FLEE_R + 1.0))
	H.run(a[0], 1.0 / 60.0, hold(a[0], a[1]))
	H.run(b[0], 1.0 / 60.0, hold(b[0], b[1]))
	# Assert
	eq(a[0].fleeFor(0), false, "davanti: niente fuga")
	eq(a[0].duelFor(0), true, "davanti = duello")
	eq(b[0].fleeFor(0), false, "lontano")
	eq(a[0].fleeFor(1), false, "squadra della CPU")
	a[0].dispose()
	b[0].dispose()
	return done()


func test_fuga_si_chiude_per_tempo_e_non_si_riapre_subito() -> bool:
	# Arrange
	var s := setup(4)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	H.run(m, 1.0 / 60.0, hold(m, p))
	o.beat = 0.0
	o.vx = 0.0
	o.vy = 0.0
	# Act: avversario immobile (tenuto fermo alle spalle)
	var evs := H.run(m, D.FLEE_MAX + 0.1, func(_mm: SimMatchScript) -> void:
		m.userMove(0, p.x, p.y, true)
		o.x = p.x
		o.y = p.y - 2.5
		o.vx = 0.0
		o.vy = 0.0)
	# Assert
	var end: Variant = findEvent(evs, "flee_end")
	eq(end.reason if end != null else null, "tempo", "chiusa per tempo")
	eq(m.fleeFor(0), false, "pausa prima di riaprirla")
	m.dispose()
	return done()


func test_scatto_si_stacca_e_corre_dritto_senza_contrasti() -> bool:
	# Arrange
	var s := setup(5, 0.8, -1.2)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.vy = 4
	H.run(m, 1.0 / 60.0, func(_mm: SimMatchScript) -> void: m.userMove(0, p.x, p.y + 10.0, true))
	eq(m.fleeFor(0), true, "fuga aperta")
	var y0 := p.y
	var gap0 := dist(o, p)
	# Act
	var ok := m.userSprint(0)
	var evs := H.run(m, D.BURST_T)
	# Assert
	eq(ok, true, "il tasto funziona")
	eq(m.fleeFor(0), false, "la fuga si chiude con lo scatto")
	eq(m.ball.owner, p, "ha ancora il pallone")
	check(not hasEvent(evs, "tackle"), "nessun contrasto")
	check(p.y - y0 > 6.0, "prosegue dritto in avanti (%.1f m)" % (p.y - y0))
	check(absf(p.x) < 1.5, "dritto, non di lato (x %.1f)" % p.x)
	check(dist(o, p) > gap0 + 2.0, "si è staccato (%.1f contro %.1f m)" % [dist(o, p), gap0])
	var mv: R.Move = m.move[0]
	check(mv == null or C.hyp(mv.x - p.x, mv.y - (y0 + D.BURST_RUN)) < D.BURST_RUN, "meta dritta davanti")
	m.dispose()
	return done()


func test_scatto_fuori_dalla_fuga_non_fa_niente() -> bool:
	var s := setup(6, 0.0, -(D.FLEE_R + 3.0))
	var m: SimMatchScript = s[0]
	H.run(m, 1.0 / 60.0, hold(m, s[1]))
	eq(m.userSprint(0), false, "il tasto non fa niente")
	eq((s[1] as R.Player).burst, 0.0, "niente scatto")
	m.dispose()
	return done()


func test_per_linee_avversario_davanti_di_lato_e_duello() -> bool:
	# Arrange: avversario più avanti di 2 m, spostato di 2 m: dentro il cono del duello
	var s := setup(7, 2.0, 2.0)
	var m: SimMatchScript = s[0]
	# Act
	H.run(m, 1.0 / 60.0, hold(m, s[1]))
	# Assert
	eq(m.duelFor(0), true, "davanti = duello")
	eq(m.fleeFor(0), false, "niente fuga")
	eq(m.userDribble(0), true, "nel duello il tasto è Dribbling")
	m.dispose()
	return done()


func test_per_linee_corsa_di_lato_verso_avversario_alla_pari_e_fuga() -> bool:
	# Arrange: il portatore corre verso +x, l'avversario gli sta davanti nel verso di corsa ma sulla stessa linea
	var s := setup(8, 3.0, 0.0)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.fx = 1
	p.fy = 0
	o.fx = -1
	o.fy = 0
	# Act
	H.run(m, 1.0 / 60.0, func(_mm: SimMatchScript) -> void: m.userMove(0, p.x + 10.0, p.y, true))
	# Assert
	eq(m.duelFor(0), false, "alla pari: niente duello")
	eq(m.fleeFor(0), true, "alla pari: Scatto")
	m.dispose()
	return done()


func test_per_linee_duello_si_chiude_alla_pari_e_si_apre_la_fuga() -> bool:
	# Arrange
	var s := setup(9, 1.5, 3.0)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	H.run(m, 1.0 / 60.0, hold(m, p))
	eq(m.duelFor(0), true, "duello aperto")
	# Act: l'avversario scivola alla pari del portatore
	var evs := H.run(m, 1.0 / 30.0, func(_mm: SimMatchScript) -> void:
		m.userMove(0, p.x, p.y, true)
		o.y = p.y
		o.x = p.x + 2.0
		o.vx = 0.0
		o.vy = 0.0)
	# Assert
	var end: Variant = findEvent(evs, "duel_end")
	eq(end.reason if end != null else null, "lontano", "duello chiuso")
	eq(m.duelFor(0), false, "niente duello")
	eq(m.fleeFor(0), true, "si apre la fuga")
	m.dispose()
	return done()


func test_squadra_1_dietro_vale_al_contrario() -> bool:
	# Arrange: portatore umano della squadra 1 che corre verso -y, avversario 2 m più in alto (= alle sue spalle)
	var m := H.scene(10, [false, true])
	var p: R.Player = m.players[11 + 9]
	var o: R.Player = m.players[3]
	H.wake(p, 0, 0)
	p.fx = 0
	p.fy = -1
	H.give(m, p)
	m.updateCtrl(1)
	H.wake(o, 0.5, 2)
	o.fx = 0
	o.fy = -1
	# Act
	H.run(m, 1.0 / 60.0, func(_mm: SimMatchScript) -> void: m.userMove(1, p.x, p.y, true))
	# Assert
	eq(m.fleeFor(1), true, "fuga per la squadra 1")
	eq(m.duelFor(1), false, "niente duello")
	m.dispose()
	return done()


# in più rispetto al JS: aheadLine segue la porta che attacca il portatore, con la tolleranza LEVEL_TOL
func test_per_linee_davanti_solo_oltre_level_tol() -> bool:
	var s := setup(11)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	o.y = D.LEVEL_TOL * 0.9
	eq(m.aheadLine(p, o), false, "poco più avanti = alla pari")
	o.y = D.LEVEL_TOL * 1.1
	eq(m.aheadLine(p, o), true, "oltre la tolleranza = davanti")
	p.team = 1 # stessa posizione vista da chi attacca verso -y: è dietro
	eq(m.aheadLine(p, o), false, "squadra 1: più in alto = dietro")
	p.team = 0
	m.dispose()
	return done()


# in più rispetto al JS: nella fuga si può passare (Luis 2026-11-21); la fuga si chiude con 'passaggio'
func test_fuga_passaggio_disegnato_chiude_con_passaggio() -> bool:
	# Arrange
	var s := setup(12)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var q: R.Player = m.players[7]
	H.wake(q, -12.0, 6.0)
	H.run(m, 1.0 / 60.0, hold(m, p))
	eq(m.fleeFor(0), true, "fuga aperta")
	eq(m.passFor(0), true, "si può passare")
	# Act
	eq(m.userKick(0, {"type": "ground", "tx": q.x, "ty": q.y}), true, "passaggio accettato")
	var evs := H.run(m, 1.0 / 30.0)
	# Assert
	var end: Variant = findEvent(evs, "flee_end")
	eq(end.reason if end != null else null, "passaggio", "fuga chiusa dal passaggio")
	eq(m.fleeFor(0), false, "niente più fuga")
	m.dispose()
	return done()
