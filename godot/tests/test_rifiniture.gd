# Correzioni del controllo del gameplay (2026-11-23), solo con l'opzione "rifiniture" della partita (la accende il gioco;
# spenta nei confronti col JS): respinta in angolo senza "campanile", Scatto in avanti anche se il portatore
# automatico stava proteggendo palla all'indietro. Senza l'opzione il motore resta com'era.
extends "test_base.gd"

const D := preload("../sim/duel.gd")
const MO := preload("../sim/motion.gd")


# tiro della squadra 0 ribattuto da un difensore della squadra 1 a `dist` m dalla porta che difende (+y)
static func respinta(seed_value: int, rif: bool, dist: float) -> Dictionary:
	var m := H.scene(seed_value)
	m.rifiniture = rif
	var dif: R.Player = m.players[11 + 3]
	H.wake(dif, 4.0, C.HL - dist)
	var b := m.ball
	b.x = 4.0
	b.y = C.HL - dist - 0.5
	b.h = 0.3
	b.vx = 0.0
	b.vy = 28.0
	b.vh = 0.0
	b.last = m.players[9]
	m.deflectBehind(dif)
	var hmax := 0.0
	var t := 0.0
	var fuori := false
	while t < 8.0 and not fuori:
		m.step(DT)
		t += DT
		hmax = maxf(hmax, b.h)
		fuori = m.phase == "restart"
	var tipo: String = m.restart.type if m.restart != null else ""
	m.dispose()
	return {"hmax": hmax, "t": t, "fuori": fuori, "tipo": tipo}


func test_respinta_in_angolo_da_lontano_non_va_altissima() -> bool:
	for sd in [1, 2, 3, 4, 5]:
		# Arrange / Act
		var r := respinta(sd, true, 19.0)
		# Assert
		check(r.fuori and r.tipo == "corner", "finisce in angolo (seme %d, %s)" % [sd, r.tipo])
		check(r.hmax < 5.0, "pallone al più 5 m (seme %d: %.1f m)" % [sd, r.hmax])
		check(r.t < MO.DEFLECT_T_MAX + 0.3, "fuori in poco tempo (seme %d: %.1f s)" % [sd, r.t])
	return done()


func test_respinta_senza_rifiniture_resta_com_era() -> bool:
	# Arrange / Act: senza l'opzione (confronti col JS) il volo dura di più e sale molto (com'era)
	var r := respinta(1, false, 19.0)
	# Assert
	check(r.fuori, "finisce fuori")
	check(r.hmax > 8.0, "com'era: campanile (%.1f m)" % r.hmax)
	return done()


func test_respinta_da_vicino_non_cambia() -> bool:
	# a 3 m dalla linea il volo è già corto: stessa traiettoria con e senza rifiniture
	var a := respinta(7, true, 3.0)
	var b := respinta(7, false, 3.0)
	near(a.hmax, b.hmax, 0.001, "stessa altezza")
	near(a.t, b.t, 0.001, "stesso tempo")
	return done()


# portatore umano (squadra 0) che corre all'indietro (verso la propria porta), avversario alla pari di lato: fuga
static func fuga_indietro(seed_value: int, rif: bool, porta_auto: bool) -> Array:
	var m := H.scene(seed_value)
	m.rifiniture = rif
	m.portaAuto = porta_auto
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, 5.0, 10.0)
	p.fx = 0.0
	p.fy = -1.0
	p.vy = -4.0
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, 7.5, 10.0)
	H.run(m, DT, func(_mm: SimMatchScript) -> void: m.userMove(0, p.x, p.y - 10.0, true))
	return [m, p, o]


func test_scatto_va_in_avanti_anche_se_correva_indietro() -> bool:
	# Arrange
	var s := fuga_indietro(3, true, true)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	eq(m.fleeFor(0), true, "fuga aperta")
	var y0 := p.y
	# Act
	var ok := m.userSprint(0)
	H.run(m, D.BURST_T)
	# Assert
	eq(ok, true, "il tasto funziona")
	eq(m.ball.owner, p, "ha ancora il pallone")
	check(p.y - y0 > 4.0, "va verso la porta avversaria (%.1f m)" % (p.y - y0))
	check(p.x < o.x, "in diagonale lontano dall'avversario (x %.1f, avversario %.1f)" % [p.x, o.x])
	m.dispose()
	return done()


func test_scatto_senza_rifiniture_o_senza_porta_auto_come_prima() -> bool:
	for k in 2:
		# Arrange: com'era, lo Scatto segue il verso di corsa (all'indietro)
		var s := fuga_indietro(4, k == 0, k == 1)
		var m: SimMatchScript = s[0]
		var p: R.Player = s[1]
		eq(m.fleeFor(0), true, "fuga aperta (%d)" % k)
		var y0 := p.y
		# Act
		m.userSprint(0)
		H.run(m, D.BURST_T)
		# Assert
		check(p.y < y0, "verso di corsa, indietro (%d: %.1f m)" % [k, p.y - y0])
		m.dispose()
	return done()


func test_scatto_gia_in_avanti_non_cambia() -> bool:
	# corsa già in avanti: burstDir = verso di corsa
	var m := H.scene(5)
	m.rifiniture = true
	m.portaAuto = true
	var p: R.Player = m.players[9]
	H.wake(p, 0.0, 0.0)
	p.vx = 1.0
	p.vy = 5.0
	var rd: PackedFloat64Array = m.burstDir(p, null)
	var rr: PackedFloat64Array = m.runDir(p)
	near(rd[0], rr[0], 1e-9, "x uguale")
	near(rd[1], rr[1], 1e-9, "y uguale")
	m.dispose()
	return done()
