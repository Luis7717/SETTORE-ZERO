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


# --- giochetto del dribbling prenotato (solo con "rifiniture", Luis 2026-11-24: "falli vedere bene")

# tasto Dribbling col duello aperto (difensore a 5 m) e passi finché arriva l'esito: [m, p, o, evento dribble]
static func book_and_resolve(seed_value: int, rif: bool) -> Array:
	var s := setup(seed_value, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = rif
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	var e: Variant = findEvent(H.tapDribble(m), "dribble")
	return [m, p, o, e]


# primo seme (da 1) in cui il dribbling riesce
static func first_ok_seed() -> int:
	for sd in range(1, 30):
		var r := book_and_resolve(sd, true)
		if r[3] != null and r[3].ok:
			return sd
	return -1


func test_esito_uguale_con_e_senza_rifiniture() -> bool:
	# Arrange / Act: stessi semi, con e senza il giochetto (la probabilità non cambia: stesso numero casuale)
	var diversi := 0
	var riusciti := 0
	for sd in range(1, 21):
		var a := book_and_resolve(sd, true)
		var b := book_and_resolve(sd, false)
		if a[3] == null or b[3] == null or bool(a[3].ok) != bool(b[3].ok):
			diversi += 1
		elif a[3].ok:
			riusciti += 1
	# Assert
	eq(diversi, 0, "stesso esito con e senza rifiniture")
	check(riusciti > 0, "almeno un dribbling riuscito")
	return done()


func test_giochetto_frena_poi_scatta_oltre_il_difensore() -> bool:
	# Arrange
	var sd := first_ok_seed()
	check(sd > 0, "un seme col dribbling riuscito")
	var r := book_and_resolve(sd, true)
	var m: SimMatchScript = r[0]
	var p: R.Player = r[1]
	var o: R.Player = r[2]
	var e: Dictionary = r[3]
	# Assert: il giochetto parte, il tempo del motore lo dice alla grafica
	near(float(e.show), D.DRIB_SHOW_T, 1e-6, "evento dribble con la durata del giochetto")
	check(m.dribShow != null and m.dribShow.p == p, "giochetto in corso")
	# Act: durante il giochetto
	var vmax := 0.0
	var dmin := 99.0
	var go: Variant = null
	var t := 0.0
	var side: float = e.side
	var x0 := p.x
	for i in 90:
		m.step(DT)
		t += DT
		go = findEvent(m.events, "dribble_go")
		m.events.clear()
		if go != null:
			break
		if t > 0.2: # dopo la frenata
			vmax = maxf(vmax, C.hyp(p.vx, p.vy))
		dmin = minf(dmin, dist(p, o))
		check(m.ball.owner == p, "il pallone resta al portatore")
	# Assert
	check(go != null, "poi lo scatto (dribble_go)")
	near(t, D.DRIB_SHOW_T, 2.0 * DT, "lo scatto dopo DRIB_SHOW_T")
	check(vmax <= D.DRIB_SHOW_V + 0.3, "durante il giochetto va piano: %.2f m/s" % vmax)
	check(dmin >= D.DRIB_SHOW_GAP - 0.5, "non finisce addosso al difensore: %.2f m" % dmin)
	check((p.x - x0) * side > 0.0, "la finta va dal lato opposto a quello scelto (+1 = sinistra = x minori)")
	check(m.dribShow == null, "giochetto finito")
	check(C.hyp(p.vx, p.vy) > 5.0, "accelera: %.2f m/s" % C.hyp(p.vx, p.vy))
	check(p.vx * -side > 0.0, "cambia direzione verso il lato scelto")
	# Act / Assert: supera il difensore col pallone
	H.run(m, 1.2)
	check(p.y > o.y + 0.5, "oltre il difensore")
	check(m.ball.owner == p, "col pallone")
	m.dispose()
	return done()


func test_senza_rifiniture_corsa_subito() -> bool:
	# Arrange / Act
	var sd := first_ok_seed()
	var r := book_and_resolve(sd, false)
	var m: SimMatchScript = r[0]
	# Assert: come prima (e come il JS): niente giochetto, corsa subito
	check(r[3] != null and r[3].ok, "riuscito")
	near(float(r[3].show), 0.0, 1e-9, "show = 0")
	check(m.dribShow == null, "niente giochetto")
	check(C.hyp(r[1].vx, r[1].vy) > 5.0, "corre subito")
	m.dispose()
	return done()


func test_giochetto_finisce_se_il_gioco_si_ferma() -> bool:
	# Arrange
	var r := book_and_resolve(first_ok_seed(), true)
	var m: SimMatchScript = r[0]
	check(m.dribShow != null, "giochetto in corso")
	# Act
	m.setRestart("throw", 1, C.HW, 0.0)
	H.run(m, 0.6)
	# Assert
	check(m.dribShow == null, "giochetto annullato")
	check(findEvent(m.events, "dribble_go") == null, "niente scatto")
	m.dispose()
	return done()


func test_dribbling_fallito_frena_davanti_al_difensore() -> bool:
	# Arrange / Act: difensore fortissimo, si cerca un fallito
	var trovato := false
	for sd in range(1, 30):
		var s := setup(sd, 5.0)
		var m: SimMatchScript = s[0]
		m.rifiniture = true
		var p: R.Player = s[1]
		var o: R.Player = s[2]
		p.st.dri = 1
		o.st.dif = 99
		var e: Variant = findEvent(H.tapDribble(m), "dribble")
		if e != null and not e.ok:
			trovato = true
			var o_dir := Vector2(o.x - p.x, o.y - p.y).normalized()
			# Assert
			check(Vector2(p.vx, p.vy).dot(o_dir) <= D.DRIB_SHOW_V + 1e-6, "frena: non corre addosso al difensore")
			check(m.dribShow == null, "niente giochetto")
			m.dispose()
			break
		m.dispose()
	check(trovato, "un dribbling fallito")
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


# Luis 2026-11-25: "dopo una skill riuscita il giocatore si ferma, come prima con lo scatto"
func test_dopo_il_dribbling_riuscito_non_si_ferma() -> bool:
	var sd := first_ok_seed()
	var r := book_and_resolve(sd, true)
	var m: SimMatchScript = r[0]
	var p: R.Player = r[1]
	m.portaAuto = true
	check(r[3] != null and r[3].ok, "dribbling riuscito")
	var go: Variant = null
	for i in 90:
		m.step(DT)
		go = findEvent(m.events, "dribble_go")
		m.events.clear()
		if go != null:
			break
	check(go != null, "parte lo scatto dopo il giochetto")
	var vmin := 99.0
	var y0 := p.y
	var fuga := false
	var t := 0.0
	while t < 3.0:
		m.step(DT)
		t += DT
		if t > 0.3:
			vmin = minf(vmin, C.hyp(p.vx, p.vy))
		fuga = fuga or m.flee != null
		if m.ball.owner != p:
			break
	check(m.ball.owner == p, "ha ancora il pallone")
	check(vmin > 4.5, "non frena dopo il dribbling: velocità minima %.2f m/s (prima ~2, poi ~3,7 finito lo scatto)" % vmin)
	check(p.slancio > 0.0, "slancio ancora attivo dopo 3 s (DRIB_SLANCIO)")
	check(not fuga, "la fuga col difensore battuto non riapre il rallenty")
	check(p.y - y0 > 10.0, "va avanti: %.1f m in 3 s" % (p.y - y0))
	m.dispose()
	return done()
