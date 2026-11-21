# Duello, dribbling, colpi di testa, stanchezza, area di tiro: porting di test/unit/duel e test/unit/dribble-beat
# (tranne le parti che usano career.js o tutorial.js: genPlayer e la lezione "Dribbling" dell'allenamento).
extends "test_base.gd"

const D := preload("../sim/duel.gd")


# portatore umano (squadra 0) fermo a centrocampo verso +y, difensore della squadra 1 davanti a `dist` m
static func setup(seed_value: int, dist_: float = 3.0, dri: float = 60.0, dif: float = 60.0, ox: float = 0.0) -> Array:
	var m := H.scene(seed_value)
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, 0, 0)
	p.fx = 0
	p.fy = 1
	p.st.dri = dri
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, ox, dist_)
	o.st.dif = dif
	return [m, p, o]


# dito fermo sul portatore: resta dov'è
static func hold(m: SimMatchScript, p: R.Player) -> Callable:
	return func(_mm: SimMatchScript) -> void: m.userMove(0, p.x, p.y, true)


static func reasonOf(evs: Array) -> Variant:
	var e: Variant = findEvent(evs, "duel_end")
	return e.reason if e != null else null


func test_duello_si_apre_solo_per_la_squadra_umana() -> bool:
	var s := setup(1, 6.5)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	var evs := H.run(m, 1.0 / 60.0, hold(m, p))
	var st: Variant = findEvent(evs, "duel_start")
	check(st != null and st.p == p and st.o == o, "duel_start col portatore e il difensore")
	eq(m.duelFor(0), true, "duello della squadra 0")
	eq(m.duelFor(1), false, "nessun duello per la squadra 1")
	eq(m.hint(0), "attack", "si può ancora disegnare il passaggio")
	return done()


func test_duello_non_si_apre_alle_spalle_o_lontano() -> bool:
	var a := setup(2, -3)
	var b := setup(3, D.DUEL_R + 1.5)
	H.run(a[0], 0.2, hold(a[0], a[1]))
	H.run(b[0], 0.05, hold(b[0], b[1]))
	eq(a[0].duelFor(0), false, "alle spalle")
	eq(b[0].duelFor(0), false, "lontano")
	return done()


func test_duello_si_chiude_per_tempo_lontananza_passaggio() -> bool:
	var s := setup(4, 3)
	var m: SimMatchScript = s[0]
	H.run(m, 1.0 / 60.0, hold(m, s[1]))
	s[2].stun = 999
	eq(reasonOf(H.run(m, D.DUEL_MAX + 0.1, hold(m, s[1]))), "tempo", "chiuso per tempo")
	eq(m.duelFor(0), false, "duello chiuso")
	s = setup(5, 3)
	m = s[0]
	H.run(m, 1.0 / 60.0, hold(m, s[1]))
	s[2].x = 20
	s[2].y = 20
	s[2].stun = 999
	eq(reasonOf(H.run(m, 2.0 / 60.0, hold(m, s[1]))), "lontano", "chiuso per lontananza")
	s = setup(6, 3)
	m = s[0]
	H.run(m, 1.0 / 60.0, hold(m, s[1]))
	s[1].stun = 0
	eq(m.userKick(0, {"type": "ground", "tx": -15.0, "ty": -5.0}), true, "passaggio accettato")
	eq(reasonOf(H.run(m, 2.0 / 60.0)), "passaggio", "chiuso col passaggio")
	return done()


func test_duello_finestra_di_protezione() -> bool:
	var s := setup(7, 1.0, 20, 99)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	var early := H.run(m, D.DUEL_GUARD - 0.05, hold(m, p))
	var ownerAfterGuard: R.Player = m.ball.owner
	var late := H.run(m, 1.5, hold(m, p))
	check(hasEvent(early, "duel_start"), "duello aperto")
	check(not hasEvent(early, "tackle"), "nessun contrasto nella finestra di protezione")
	check(ownerAfterGuard == p, "pallone ancora al portatore")
	check(hasEvent(late, "tackle", func(e: Dictionary) -> bool: return e.p == o), "dopo la finestra il difensore ruba palla")
	eq(reasonOf(late), "palla persa", "motivo della chiusura")
	return done()


func test_dribbling_riuscito() -> bool:
	for sd in 20:
		var s := setup(20 + sd, 2.5, 85, 40)
		var m: SimMatchScript = s[0]
		var p: R.Player = s[1]
		var o: R.Player = s[2]
		H.run(m, 1.0 / 60.0, hold(m, p))
		var evs := H.tapDribble(m)
		check(findEvent(evs, "dribble_book") != null, "tasto Dribbling: dribbling prenotato")
		var d: Dictionary = findEvent(evs, "dribble")
		if not d.ok:
			continue
		H.run(m, 0.6)
		check(o.stun > 0, "difensore ancora sbilanciato")
		check(m.ball.owner == p, "pallone al portatore")
		check(p.y > o.y, "portatore oltre il difensore: %.1f contro %.1f" % [p.y, o.y])
		eq(reasonOf(evs), "dribbling", "motivo della chiusura")
		eq(m.userDribble(0), false, "senza duello aperto non si dribbla")
		return done()
	check(false, "nessun dribbling riuscito in 20 prove")
	return done()


func rate(dri: float, dif: float) -> Dictionary:
	var ok := 0
	var lost := 0
	for sd in 120:
		var s := setup(200 + sd, 1.5, dri, dif)
		var m: SimMatchScript = s[0]
		H.run(m, 1.0 / 60.0, hold(m, s[1]))
		var d: Dictionary = findEvent(H.tapDribble(m), "dribble")
		if d.ok:
			ok += 1
		elif m.ball.owner != s[1]:
			lost += 1
	return {"ok": ok / 120.0, "lost": float(lost) / (120 - ok if 120 - ok > 0 else 1)}


func test_dribbling_riuscita_secondo_le_abilita() -> bool:
	var bravo := rate(85, 45)
	var pari := rate(60, 60)
	var scarso := rate(45, 85)
	check(bravo.ok > pari.ok + 0.15 and pari.ok > scarso.ok + 0.15, "riuscita %s / %s / %s" % [bravo.ok, pari.ok, scarso.ok])
	eq(scarso.lost, 1.0, "ogni dribbling fallito fa perdere il pallone")
	return done()


func test_dribbling_anche_l_ia() -> bool:
	var n := 0
	for sd in 30:
		var m := H.scene(300 + sd, [false, false])
		var p: R.Player = m.players[9]
		var o: R.Player = m.players[11 + 3]
		H.wake(p, 0, 10)
		p.fx = 0
		p.fy = 1
		H.give(m, p)
		p.aiT = 0
		H.wake(o, 0, 12.5)
		for q: R.Player in m.team(0):
			if q != p:
				q.off = true
		if hasEvent(H.run(m, 0.5), "dribble", func(e: Dictionary) -> bool: return e.p == p):
			n += 1
	check(n >= 3, "dribbling tentati dall'IA: %d/30" % n)
	return done()


func test_calo_per_uso() -> bool:
	var m := H.scene(9)
	var p: R.Player = m.players[9]
	var dri0 := p.st.dri
	var tes0 := p.st.tes
	m.wearDown(p, "dri", 0.03, 0.8)
	check(absf(p.wear.dri - 0.97) < 1e-9 and absf(p.st.dri - dri0 * 0.97) < 1e-9, "un dribbling: -3%")
	for k in 20:
		m.wearDown(p, "dri", 0.03, 0.8)
		m.wearDown(p, "tes", 0.02, 0.85)
	check(absf(p.wear.dri - 0.8) < 1e-9 and absf(p.st.dri - dri0 * 0.8) < 1e-9, "minimo 80%")
	check(absf(p.wear.tes - 0.85) < 1e-9 and absf(p.st.tes - tes0 * 0.85) < 1e-9, "minimo 85%")
	m.substitute(0, 9, p.src)
	eq(str(p.wear), str({"dri": 1.0, "tes": 1.0}), "il nuovo entrato è fresco")
	eq(p.st.dri, dri0, "dribbling di nuovo pieno")
	return done()


func test_calo_per_uso_dal_dribbling_riuscito() -> bool:
	var p: R.Player = null
	var sd := 0
	while sd < 20 and p == null:
		var s := setup(40 + sd, 2.5, 85, 40)
		H.run(s[0], 1.0 / 60.0, hold(s[0], s[1]))
		if findEvent(H.tapDribble(s[0]), "dribble").ok:
			p = s[1]
		sd += 1
	check(p != null and absf(p.wear.dri - 0.97) < 1e-9 and absf(p.st.dri - 85 * 0.97) < 1e-9, "calo applicato")
	var again := H.newMatch(1, 150, [true, false], H.mkTeam("A", 60, 8), H.mkTeam("B", 60, 18))
	for q: R.Player in again.players:
		eq(str(q.wear), str({"dri": 1.0, "tes": 1.0}), "partita nuova da pieno")
	return done()


func test_colpo_di_testa_usa_e_consuma_tes() -> bool:
	var m := H.scene(41, [false, false])
	var p: R.Player = m.players[9]
	H.wake(p, 1, C.HL - 9)
	H.wake(m.gk(1), 0, C.HL - 0.6)
	var b := m.ball
	b.x = p.x - 0.5
	b.y = p.y
	b.h = 1.9
	b.vx = 9
	b.vy = 0
	b.vh = -1
	b.ct = 0
	b.kick = R.Kick.make(0, m.players[5], "loft", 1)
	var tes0 := p.st.tes
	m.contacts(1.0 / 60.0)
	var k: Variant = findEvent(m.events, "kick")
	eq(k.kind if k != null else null, "header", "colpo di testa")
	check(absf(p.st.tes - tes0 * 0.98) < 1e-9 and absf(p.wear.tes - 0.98) < 1e-9, "tes consumato del 2%")
	return done()


func aerialRate(tA: float, tD: float) -> float:
	var a := 0
	var n := 0
	for sd in 100:
		var m := H.scene(500 + sd, [false, false])
		var p: R.Player = m.players[9]
		var d: R.Player = m.players[11 + 2]
		H.wake(p, 0.5, C.HL - 9)
		H.wake(d, -0.5, C.HL - 9)
		p.st.tes = tA
		d.st.tes = tD
		var b := m.ball
		b.x = 0
		b.y = C.HL - 9
		b.h = 2.0
		b.vx = 0
		b.vy = 6
		b.vh = -1
		b.ct = 0
		b.kick = R.Kick.make(0, m.players[5], "loft", 1)
		m.contacts(1.0 / 60.0)
		var e: Variant = findEvent(m.events, "aerial")
		if e != null:
			n += 1
			if e.p == p:
				a += 1
	return float(a) / n


func test_contrasto_aereo_vince_chi_ha_piu_tes() -> bool:
	var alto := aerialRate(85, 45)
	var basso := aerialRate(45, 85)
	check(alto > 0.7 and basso < 0.3, "attaccante vince %s (tes alto) / %s (tes basso)" % [alto, basso])
	return done()


# parte di "tes" senza genPlayer (career.js): giocatore di un vecchio salvataggio senza tes
func test_tes_ricavato_per_i_salvataggi_vecchi() -> bool:
	var old := {"id": 3, "name": "L. Rossi", "pos": "D", "age": 25, "vel": 60, "tir": 40, "pas": 55, "dri": 50, "dif": 70, "fis": 72, "por": 12, "goals": 0, "assists": 0, "apps": 3, "pot": 66}
	var copy := JSON.stringify(old)
	var st := C.effStats(old, "D")
	check(st.tes >= 18 and st.tes <= 99 and is_finite(st.tes), "tes ricavato: %s" % st.tes)
	eq(JSON.stringify(old), copy, "il salvataggio non cambia")
	eq(C.effStats(old, "D").tes, st.tes, "sempre lo stesso valore")
	var gk := old.duplicate()
	gk.pos = "P"
	check(C.headingOf(old) > C.headingOf(gk), "il ruolo conta")
	var withTes := old.duplicate()
	withTes.tes = 90
	eq(C.effStats(withTes, "D").tes, 90.0, "tes scritto: si usa quello (nel suo ruolo)")
	var m := H.newMatch(3, 150, [true, false], H.mkTeam("A", 60, 8), H.mkTeam("B", 60, 18))
	for p: R.Player in m.players:
		check(is_finite(p.st.tes), "tes finito")
	for i in 600:
		m.step(1.0 / 60.0)
	return done()


func test_stanchezza() -> bool:
	var m := H.scene(11, [false, false])
	var a: R.Player = m.players[5]
	var c: R.Player = m.players[6]
	H.wake(a, -10, 0)
	H.wake(c, 10, 0)
	a.st.fis = 90
	c.st.fis = 30
	a.st.vel = 70
	c.st.vel = 70
	var v0 := m.vmax(a)
	for i in 200 * 60:
		var k := -1.0 if (i / 300) % 2 else 1.0
		for p: R.Player in [a, c]:
			p.tx = p.x
			p.ty = k * 40
		m.movePlayers(1.0 / 60.0)
	check(a.energy < 1 and c.energy < a.energy, "energia: fis 90 %.2f, fis 30 %.2f" % [a.energy, c.energy])
	check(m.vmax(c) < m.vmax(a) and m.vmax(a) < v0, "velocità massima calata")
	return done()


func test_area_di_tiro_ultimi_20_m() -> bool:
	var s := setup(30, -5)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	p.y = C.HL - D.ZONE_DIST - 2
	eq(m.inZone(0), false, "a 22 m dalla porta")
	eq(m.passFor(0), false, "niente passaggio fuori dall'area di tiro")
	p.y = C.HL - D.ZONE_DIST + 1
	eq(m.inZone(0), true, "a 19 m dalla porta")
	eq(m.passFor(0), true, "passaggio nell'area di tiro")
	eq(m.inZone(1), false, "non per la squadra avversaria")
	m.human[0] = false
	eq(m.inZone(0), false, "solo per la squadra umana")
	return done()


func test_area_di_tiro_solo_porta_avversaria_e_col_pallone() -> bool:
	var s := setup(31, -5)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	p.y = -C.HL + 5
	eq(m.inZone(0), false, "vicino alla propria porta")
	p.y = C.HL - 5
	m.ball.owner = null
	eq(m.inZone(0), false, "pallone libero")
	return done()


# ------------------------------------------------------------ difensore saltato (dribble-beat)
static func duelScene(seed_value: int, d: float) -> Array:
	var m := H.scene(seed_value)
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, 0, 0)
	p.fx = 0
	p.fy = 1
	p.st.dri = 85
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, 0, d)
	o.fx = 0
	o.fy = -1
	o.st.dif = 40
	return [m, p, o]


# cerca un seme in cui il dribbling (toccato appena si apre il duello) riesce
func dribbledAt(d: float) -> Array:
	for sd in 30:
		var st := duelScene(500 + sd, d)
		var m: SimMatchScript = st[0]
		H.run(m, DT)
		if not m.duelFor(0):
			continue
		var e: Variant = findEvent(H.tapDribble(m), "dribble")
		if e != null and e.ok:
			return st
	check(false, "nessun dribbling riuscito in 30 prove")
	return []


func test_saltato_appena_aperto_il_duello_non_si_attacca() -> bool:
	var st := dribbledAt(D.DUEL_R - 0.3)
	if st.is_empty():
		return done()
	var m: SimMatchScript = st[0]
	var p: R.Player = st[1]
	var o: R.Player = st[2]
	var acc := {"minAfterPast": 99.0, "past": false, "d2": 0.0, "t": 0.0}
	var evs := H.run(m, 3, func(_mm: SimMatchScript) -> void:
		if p.y > o.y + 0.5:
			acc.past = true
		if acc.past:
			acc.minAfterPast = minf(acc.minAfterPast, dist(o, p))
		acc.t += DT
		if acc.t <= 2:
			acc.d2 = dist(o, p))
	eq(countEvents(evs, "tackle", func(e: Dictionary) -> bool: return e.p == o), 0, "il difensore saltato non contrasta")
	eq(countEvents(evs, "duel_start", func(e: Dictionary) -> bool: return e.o == o), 0, "non si riapre il duello con lo stesso difensore")
	check(m.ball.owner == p, "il portatore ha ancora il pallone")
	check(acc.past, "portatore oltre il difensore: %.1f contro %.1f" % [p.y, o.y])
	check(acc.minAfterPast > 1.2, "superato, il difensore resta staccato: minimo %.2f m" % acc.minAfterPast)
	check(acc.d2 > 3.5, "vantaggio vero dopo 2 s: %.1f m" % acc.d2)
	return done()


func test_saltato_sbilanciato_non_contrasta_e_corre_piano() -> bool:
	var st := dribbledAt(2.5)
	if st.is_empty():
		return done()
	var m: SimMatchScript = st[0]
	var p: R.Player = st[1]
	var o: R.Player = st[2]
	o.stun = 0
	o.tackleCd = 0
	p.protect = 0
	check(o.beat > 0.3, "resta \"saltato\" dopo lo sbilanciamento")
	o.x = m.ball.x
	o.y = m.ball.y + 0.3
	var acc := {"vmax": 0.0}
	var evs := H.run(m, 0.3, func(_mm: SimMatchScript) -> void:
		p.vx = 0
		p.vy = 0
		p.tx = p.x
		p.ty = p.y
		acc.vmax = maxf(acc.vmax, C.hyp(o.vx, o.vy)))
	eq(countEvents(evs, "tackle"), 0, "nessun contrasto")
	check(m.ball.owner == p, "pallone al portatore")
	check(acc.vmax <= m.vmax(o) * D.DRIB_BEAT_SPD + 0.05, "velocità %.2f contro massimo %.2f" % [acc.vmax, m.vmax(o) * D.DRIB_BEAT_SPD])
	return done()


func test_saltato_poi_torna_normale() -> bool:
	var st := dribbledAt(2.5)
	if st.is_empty():
		return done()
	var m: SimMatchScript = st[0]
	var p: R.Player = st[1]
	var o: R.Player = st[2]
	o.stun = 0
	o.beat = 0
	o.tackleCd = 0
	p.protect = 0
	o.x = m.ball.x
	o.y = m.ball.y + 0.3
	var evs := H.run(m, 1.5, func(_mm: SimMatchScript) -> void:
		p.vx = 0
		p.vy = 0
		p.tx = p.x
		p.ty = p.y
		o.tx = m.ball.x
		o.ty = m.ball.y)
	check(hasEvent(evs, "tackle", func(e: Dictionary) -> bool: return e.p == o), "il contrasto torna possibile")
	return done()
