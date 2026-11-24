# Giocatori che non si compenetrano, respiro dopo il recupero palla e passaggio che parte bene (sim/contatti.gd,
# opzione "contatti" della partita, Luis 2026-11-24).
extends "test_base.gd"

const K := preload("../sim/contatti.gd")


# scena con l'opzione "contatti" accesa (o spenta)
static func _scena(on: bool = true, sd: int = 1, human := [true, false]) -> SimMatchScript:
	var m := H.scene(sd, human)
	m.contattiOn = on
	return m


func test_opzione_spenta_di_base() -> bool:
	var m := H.newMatch(1, 150.0, [true, false], H.mkTeam("A", 60.0, 8), H.mkTeam("B", 60.0, 18))
	check(not m.contattiOn, "senza l'opzione il motore resta quello confrontato col JS")
	var s := _scena(false)
	var a: R.Player = s.players[5]
	var b: R.Player = s.players[16]
	H.wake(a, 0.0, 0.0)
	H.wake(b, 0.75, 0.0)
	H.run(s, 0.5)
	near(dist(a, b), 0.75, 0.05, "senza l'opzione due giocatori fermi a 0,75 m restano lì (separazione rigida a 0,7 m)")
	H.disposeAll()
	return done()


func test_due_fermi_vicini_si_allontanano_piano() -> bool:
	var m := _scena()
	var a: R.Player = m.players[5]
	var b: R.Player = m.players[16]
	H.wake(a, 0.0, 0.0)
	H.wake(b, 0.72, 0.0)
	m.step(H.DT)
	var d1 := dist(a, b)
	check(d1 > 0.72 and d1 < K.SEP_R - 0.03, "spinta morbida: dopo un passo un po' più lontani (%.3f m), non di colpo" % d1)
	H.run(m, 0.6)
	check(dist(a, b) >= K.SEP_R - 0.03, "dopo 0,6 s a circa SEP_R (%.2f m)" % dist(a, b))
	H.disposeAll()
	return done()


func test_compagni_si_separano_anche_loro() -> bool:
	var m := _scena()
	var a: R.Player = m.players[5]
	var b: R.Player = m.players[6]
	H.wake(a, 0.0, 0.0)
	H.wake(b, 0.0, 0.7)
	H.run(m, 0.6)
	check(dist(a, b) >= K.SEP_R - 0.03, "due compagni a 0,7 m si separano (%.2f m)" % dist(a, b))
	H.disposeAll()
	return done()


func test_chi_corre_addosso_rallenta_e_non_entra() -> bool:
	var m := _scena()
	var a: R.Player = m.players[5]
	var b: R.Player = m.players[16]
	H.wake(a, 0.0, 0.0)
	H.wake(b, 0.0, 4.0)
	var dmin := 99.0
	var verso := 0.0
	for i in 120:
		b.tx = a.x # b corre verso a e ci vuole andare sopra (movePlayers da solo: niente IA che cambia la meta)
		b.ty = a.y
		a.tx = a.x
		a.ty = a.y
		m.movePlayers(H.DT)
		dmin = minf(dmin, dist(a, b))
		var d := dist(a, b)
		verso = ((a.x - b.x) * b.vx + (a.y - b.y) * b.vy) / d
	check(dmin >= 0.7, "mai sotto la separazione rigida (%.2f m)" % dmin)
	check(dist(a, b) >= K.SEP_R - 0.1, "chi corre addosso si ferma intorno a SEP_R (%.2f m)" % dist(a, b))
	check(verso < 1.0, "e non corre sul posto: velocità verso l'altro %.2f m/s" % verso)
	check(C.hyp(a.vx, a.vy) < 1.0, "e non lo spinge via di corsa (%.2f m/s)" % C.hyp(a.vx, a.vy))
	H.disposeAll()
	return done()


# portatore della persona fermo (dito che lo tiene lì), difensore della CPU che arriva di fronte: rubato entro 3 s?
static func _rubato(on: bool, sd: int) -> bool:
	var m := _scena(on, sd)
	var c: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(c, 0.0, 10.0)
	c.fx = 0.0
	c.fy = 1.0
	H.give(m, c)
	m.ctrl[0] = c
	H.wake(o, 0.0, 13.0)
	var evs := H.run(m, 3.0, func(mm: SimMatchScript) -> void:
		mm.userMove(0, 0.0, 10.0, true))
	return hasEvent(evs, "tackle", func(e: Dictionary) -> bool: return e.p == o)


func test_contrasto_frontale_resta_possibile() -> bool:
	var on := 0
	var off := 0
	for sd in 12:
		on += 1 if _rubato(true, sd + 1) else 0
		off += 1 if _rubato(false, sd + 1) else 0
	check(off >= 9, "senza l'opzione il difensore di fronte ruba il pallone (%d su 12)" % off)
	check(on >= off - 1, "con l'opzione anche (%d su 12, senza %d)" % [on, off])
	H.disposeAll()
	return done()


func test_respiro_dopo_il_recupero_della_persona() -> bool:
	var m := _scena()
	var mio: R.Player = m.players[4]
	var cpu: R.Player = m.players[11 + 9]
	var altro: R.Player = m.players[11 + 8]
	var lontano: R.Player = m.players[11 + 7]
	H.wake(mio, 0.0, 10.0)
	H.wake(cpu, 0.0, 10.9)
	H.wake(altro, 1.5, 11.0)
	H.wake(lontano, 10.0, 20.0)
	cpu.fx = 0.0
	cpu.fy = -1.0
	H.give(m, cpu)
	cpu.aiT = 9.0 # la CPU non passa subito
	m.step(H.DT)
	eq(m.respPoss, 1, "pallone della CPU")
	H.give(m, mio) # recupero (come dopo un contrasto o un passaggio intercettato)
	mio.protect = 0.5
	m.step(H.DT)
	check(hasEvent(m.events, "respiro"), "evento respiro")
	check(mio.protect >= K.RESPIRO_PROTECT - 0.05, "chi ha recuperato è protetto per RESPIRO_PROTECT s (%.2f)" % mio.protect)
	check(cpu.tackleCd >= K.RESPIRO_CD - 0.05 and altro.tackleCd >= K.RESPIRO_CD - 0.05, "chi gli sta addosso non contrasta per RESPIRO_CD s")
	check(lontano.tackleCd <= 0.0, "chi è lontano contrasta come prima")
	H.disposeAll()
	return done()


func test_niente_respiro_per_la_cpu_ne_dopo_una_ripresa() -> bool:
	var m := _scena()
	var mio: R.Player = m.players[4]
	var cpu: R.Player = m.players[11 + 9]
	H.wake(mio, 0.0, 10.0)
	H.wake(cpu, 0.0, 10.9)
	mio.fx = 0.0
	mio.fy = 1.0
	H.give(m, mio)
	m.step(H.DT)
	H.give(m, cpu) # la CPU recupera dalla persona: niente respiro
	m.step(H.DT)
	check(not hasEvent(m.events, "respiro"), "la CPU che recupera non ha il respiro")
	m.events.clear()
	m.setRestart("throw", 0, C.HW, 0.0)
	m.step(H.DT)
	check(m.respPoss == -1, "durante la ripresa il possesso riparte da capo")
	H.disposeAll()
	return done()


# portatore della persona con un avversario "sopra il pallone" (chi l'ha appena perso) e un compagno libero di lato
static func _passaggio(on: bool, sd: int, ox: float, oy: float) -> Array:
	var m := _scena(on, sd)
	var c: R.Player = m.players[9]
	var mate: R.Player = m.players[7]
	var o: R.Player = m.players[11 + 4]
	H.wake(c, 0.0, 10.0)
	c.fx = 0.0
	c.fy = 1.0
	H.give(m, c)
	m.ctrl[0] = c
	H.wake(mate, -12.0, 14.0)
	H.wake(o, ox, 10.0 + oy)
	o.tackleCd = 5.0 # niente contrasto prima del calcio: conta solo il passaggio
	var ok: bool = m.userKick(0, {"type": "ground", "tx": mate.x, "ty": mate.y})
	var preso := false
	for i in 90:
		m.step(H.DT)
		if m.ball.owner == o or hasEvent(m.events, "block", func(e: Dictionary) -> bool: return e.p == o):
			preso = true
		m.events.clear()
	return [ok, preso, m]


func test_passaggio_che_parte_bene_non_lo_prende_chi_e_addosso() -> bool:
	var presi_on := 0
	var presi_off := 0
	for sd in 10:
		var r_on := _passaggio(true, sd + 1, -0.5, 0.75)
		var r_off := _passaggio(false, sd + 1, -0.5, 0.75)
		check(r_on[0] and r_off[0], "il passaggio parte")
		presi_on += 1 if r_on[1] else 0
		presi_off += 1 if r_off[1] else 0
	check(presi_off >= 5, "senza l'opzione chi sta sopra il pallone lo prende quasi sempre (%d su 10)" % presi_off)
	eq(presi_on, 0, "con l'opzione il passaggio gli scivola accanto")
	H.disposeAll()
	return done()


func test_passaggio_addosso_a_chi_sta_sulla_linea_si_intercetta() -> bool:
	var m := _scena()
	var c: R.Player = m.players[9]
	var mate: R.Player = m.players[7]
	var o: R.Player = m.players[11 + 4]
	H.wake(c, 0.0, 10.0)
	c.fx = 0.0
	c.fy = 1.0
	H.give(m, c)
	m.ctrl[0] = c
	H.wake(mate, 0.0, 22.0)
	H.wake(o, 0.0, 12.6) # 2 m davanti al pallone, proprio sulla linea del passaggio
	o.tackleCd = 5.0
	check(m.userKick(0, {"type": "ground", "tx": mate.x, "ty": mate.y}), "il passaggio parte")
	check(m.ball.kick != null and not m.ball.kick.shield.has(o), "chi sta sulla linea più in là non è protetto")
	var preso := false
	for i in 60:
		m.step(H.DT)
		if m.ball.owner == o or hasEvent(m.events, "block", func(e: Dictionary) -> bool: return e.p == o):
			preso = true
		m.events.clear()
	check(preso, "il passaggio addosso a chi sta sulla linea lo prende lui")
	H.disposeAll()
	return done()


func test_scudo_finisce_dopo_pochi_metri() -> bool:
	var m := _scena()
	var c: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 4]
	H.wake(c, 0.0, 10.0)
	c.fx = 0.0
	c.fy = 1.0
	H.give(m, c)
	m.ctrl[0] = c
	H.wake(o, -0.5, 10.75)
	check(m.userKick(0, {"type": "ground", "tx": -12.0, "ty": 14.0}), "il passaggio parte")
	check(m.shielded(o), "subito: protetto")
	m.ball.x = m.ball.kick.sx - (K.SHIELD_D + 0.1)
	check(not m.shielded(o), "oltre SHIELD_D m dal calcio può intercettare di nuovo")
	H.disposeAll()
	return done()


func test_partita_intera_con_contatti() -> bool:
	var sotto := 0
	var dmin := 99.0
	var r := H.playMatch({"seed": 33, "halfLen": 150.0, "extra": {"contatti": true, "rifiniture": true, "portaAuto": true}}, func(m: SimMatchScript) -> void:
		if m.phase != "play":
			return
		for i in 22:
			for j in range(i + 1, 22):
				var a: R.Player = m.players[i]
				var b: R.Player = m.players[j]
				if a.off or b.off or a.state == "dive" or b.state == "dive":
					continue
				var d := dist(a, b)
				dmin = minf(dmin, d)
				if d < 0.69:
					sotto += 1)
	var m: SimMatchScript = r.m
	check(m.contattiOn, "opzione accesa")
	eq(m.phase, "full", "la partita finisce")
	check(not is_nan(m.ball.x) and not is_nan(m.ball.y), "niente NaN")
	eq(sotto, 0, "mai due giocatori sotto 0,7 m (minimo %.2f)" % dmin)
	H.disposeAll()
	return done()
