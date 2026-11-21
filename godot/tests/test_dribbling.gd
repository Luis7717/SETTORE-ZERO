# Dribbling prenotato e niente doppio tocco sui calci da fermo: porting di test/unit/dribble-book e
# test/unit/no-double-touch (le parti principali; l'equivalenza bit per bit la controlla test_equivalence.gd).
extends "test_base.gd"

const D := preload("../sim/duel.gd")
const M := preload("../sim/match.gd")


# portatore umano (squadra 0) in (px, 0) verso +y, difensore della squadra 1 davanti a `d` m (spostato di ox);
# un passo col dito fermo: si apre il duello
static func setup(seed_value: int, d: float, px: float = 0.0, ox: float = 0.0) -> Array:
	var m := H.scene(seed_value)
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, px, 0)
	p.fx = 0
	p.fy = 1
	p.st.dri = 85
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, px + ox, d)
	o.fx = 0
	o.fy = -1
	o.st.dif = 40
	m.userMove(0, p.x, p.y, true)
	m.step(DT)
	m.events.clear()
	return [m, p, o]


static func dist(a: R.Player, b: R.Player) -> float:
	return C.hyp(a.x - b.x, a.y - b.y)


func test_tasto_prenota_e_il_dribbling_parte_vicino() -> bool:
	# Arrange
	var s := setup(1, D.DUEL_R - 0.5)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	check(m.duelFor(0), "duello aperto")
	# Act
	eq(m.userDribble(0), true, "tasto toccato")
	# Assert
	check(findEvent(m.events, "dribble") == null, "nessun dribbling subito")
	var bk: Variant = findEvent(m.events, "dribble_book")
	check(bk != null and absf(bk.side) == 1.0, "evento dribble_book con il lato")
	check(m.dribBooked(0), "prenotazione in corso: il tasto sparisce")
	eq(m.userDribble(0), false, "un secondo tocco non fa nulla")
	m.events.clear()
	var at := -1.0
	var t := 0.0
	var e: Variant = null
	for i in 120:
		var d0 := dist(p, o)
		m.step(DT)
		t += DT
		e = findEvent(m.events, "dribble")
		m.events.clear()
		if e != null:
			at = d0
			break
	check(e != null, "il dribbling parte")
	check(at <= D.DRIB_NEAR + 0.4, "parte vicino al difensore: %.2f m" % at)
	check(t < D.DRIB_BOOK_MAX + 0.05, "prima del tempo massimo: %.2f s" % t)
	if e != null and bk != null:
		eq(float(e.side), float(bk.side), "stesso lato della prenotazione")
	check(not m.duelFor(0), "il dribbling chiude il duello")
	return done()


func test_prenotazione_annullata_se_si_perde_palla() -> bool:
	# Arrange
	var s := setup(4, 6.0)
	var m: SimMatchScript = s[0]
	var o: R.Player = s[2]
	m.userDribble(0)
	# Act
	m.ball.owner = o
	m.ball.last = o
	var evs := H.run(m, 1.5)
	# Assert
	check(findEvent(evs, "dribble") == null, "palla persa: niente dribbling")
	eq(findEvent(evs, "duel_end").reason, "palla persa", "motivo")
	check(not m.dribBooked(0), "niente prenotazione")
	return done()


func test_lato_opposto_allo_sbilanciamento_e_verso_il_centro() -> bool:
	# Arrange / Act
	var left := setup(7, 5.0, 0.0, -0.8)
	var right := setup(8, 5.0, 0.0, 0.8)
	var nearR := setup(9, 5.0, C.HW - 3.0, -0.6)
	var nearL := setup(10, 5.0, -(C.HW - 3.0), 0.6)
	for s: Array in [left, right, nearR, nearL]:
		s[0].userDribble(0)
	# Assert (+1 = sinistra del portatore, cioè x minori)
	eq(left[0].duel.side, -1.0, "difensore a sinistra: si passa a destra")
	eq(right[0].duel.side, 1.0, "difensore a destra: si passa a sinistra")
	eq(nearR[0].duel.side, 1.0, "vicino alla linea di destra: verso il centro")
	eq(nearL[0].duel.side, -1.0, "vicino alla linea di sinistra: verso il centro")
	return done()


# calcio da fermo `type` della squadra umana 0, tutti gli altri parcheggiati; il battitore calcia a 3 m e insegue
static func set_piece(type: String, seed_value: int) -> Array:
	var pos := {"throw": [C.HW, 5.0], "corner": [C.HW, C.HL], "freekick": [5.0, -10.0], "goalkick": [5.0, -C.HL], "kickoff": [0.0, 0.0], "penalty": [0.0, 0.0]}
	var m := H.scene(seed_value)
	m.setRestart(type, 0, pos[type][0], pos[type][1])
	var p: R.Player = m.restart.taker
	for k in m.players.size():
		if m.players[k] != p:
			H.park(m.players[k], k)
	m.restart.t = 1.0
	return [m, p]


static func steer(m: SimMatchScript, p: R.Player) -> void:
	m.ctrl[0] = p
	m.switchCd[0] = 9.0
	m.userMove(0, m.ball.x, m.ball.y, true)


func test_calci_da_fermo_il_battitore_non_ritocca() -> bool:
	for type: String in ["throw", "corner", "freekick", "goalkick", "kickoff"]:
		# Arrange
		var s := set_piece(type, 3)
		var m: SimMatchScript = s[0]
		var p: R.Player = s[1]
		var b := m.ball
		var toward: float = C.orf(C.sign_(-b.x), 1.0)
		var fwd := -1.0 if type == "corner" else 1.0
		eq(m.userKick(0, {"type": "ground", "tx": b.x + toward * 2.0, "ty": b.y + fwd * 2.0}), true, type + ": calcio")
		check(b.dbl == p, type + ": battitore segnato")
		# Act
		var touched := false
		for i in 180:
			steer(m, p)
			m.step(DT)
			m.events.clear()
			if b.owner == p:
				touched = true
		# Assert
		check(not touched, type + ": il battitore non tocca il pallone")
		check(C.hyp(b.x - p.x, b.y - p.y) < 1.5, type + ": il battitore è sul pallone ma non lo prende")
		m.dispose()
	return done()


func test_rigore_palo_no_parata_si() -> bool:
	for after: String in ["palo", "parata"]:
		# Arrange
		var s := set_piece("penalty", 6)
		var m: SimMatchScript = s[0]
		var p: R.Player = s[1]
		var b := m.ball
		var gk: R.Player = m.gk(1)
		H.wake(gk, 0, C.HL - 0.4)
		m.userKick(0, {"type": "shot", "tx": C.GW / 2 - 0.5, "ty": C.HL, "th": 0.5})
		if after == "palo":
			b.x = C.GW / 2
			b.y = C.HL - 0.2
			b.h = 1.0
			b.vx = 0.0
			b.vy = 18.0
			b.vh = 0.0
			b.shot = null
			check(findEvent(H.run(m, DT), "post") != null, "palo")
		else:
			m.save(gk, false)
			gk.stun = 99.0
		b.x = p.x + 0.4
		b.y = p.y + 0.4
		b.h = 0.0
		b.vx = 0.0
		b.vy = 0.0
		b.vh = 0.0
		b.ct = 0.0
		b.kick = null
		b.shot = null
		b.noT = 0.0
		# Act
		H.run(m, 1.0, func(mm: SimMatchScript) -> void: steer(mm, p))
		# Assert
		if after == "palo":
			check(b.owner != p, "dopo il palo il rigorista non ritocca")
		else:
			check(b.owner == p, "dopo la parata il rigorista può ribattere")
		m.dispose()
	return done()


func test_dopo_dbl_free_il_battitore_torna_libero() -> bool:
	# Arrange
	var s := set_piece("throw", 7)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	m.userKick(0, {"type": "ground", "tx": m.ball.x - 2.0, "ty": m.ball.y})
	# Act / Assert
	H.run(m, 5.0, func(mm: SimMatchScript) -> void: steer(mm, p))
	check(m.ball.owner != p, "a 5 s ancora no")
	H.run(m, 1.5, func(mm: SimMatchScript) -> void: steer(mm, p))
	check(m.ball.owner == p, "dopo %.0f s la partita non resta bloccata" % M.DBL_FREE)
	m.dispose()
	return done()
