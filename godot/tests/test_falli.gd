# Falli sui contrasti da dietro e in ritardo (sim/falli.gd, opzione "falli" della partita, Luis 2026-11-24).
extends "test_base.gd"

const Falli := preload("../sim/falli.gd")
const Dito := preload("res://tools/dito_motore.gd")
const PARTITE := 12        # partite intere per la frequenza (umano simulato contro IA, durata del gioco)
const TEMPO_GIOCO := 150.0 # durata di un tempo predefinita del gioco (gioco.gd TEMPO_PREDEFINITO)


# scena: portatore della squadra 0 a (x, y) che guarda verso +y, difensore della squadra 1 a (x + ox, y + oy) che
# gli corre addosso a `v` m/s; opzione "falli" accesa
static func _scena(x: float, y: float, ox: float, oy: float, v: float, sd: int = 1, human := [false, false]) -> Array:
	var m := H.scene(sd, human)
	m.falliOn = true
	var c: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 6]
	H.wake(c, x, y)
	c.fx = 0.0
	c.fy = 1.0
	H.give(m, c)
	H.wake(o, x + ox, y + oy)
	var d := C.hyp(ox, oy)
	o.vx = -ox / d * v
	o.vy = -oy / d * v
	return [m, c, o]


func test_senza_opzione_niente_falli() -> bool:
	var falli := 0
	for sd in 3:
		var r := H.playMatch({"seed": 50 + sd, "halfLen": TEMPO_GIOCO}, func(m: SimMatchScript) -> void:
			for e: Dictionary in m.events:
				if e.type == "foul":
					falli += 1)
		check(not (r.m as SimMatchScript).falliOn, "opzione spenta di base")
	eq(falli, 0, "senza l'opzione nessun fallo (come prima)")
	H.disposeAll()
	return done()


func test_contrasto_frontale_sempre_pulito() -> bool:
	var falli := 0
	for sd in 200:
		var s := _scena(0.0, 10.0, 0.2, 0.8, 7.0, sd + 1)
		var m: SimMatchScript = s[0]
		var n0: int = m.rng.a
		if m.foulTackle(s[2], s[1]):
			falli += 1
		check(m.rng.a == n0, "il contrasto frontale non consuma numeri casuali")
	eq(falli, 0, "contrasto frontale: mai fallo")
	H.disposeAll()
	return done()


func test_contrasto_da_dietro_a_volte_fallo() -> bool:
	var n := 600
	var conta := {"dietro": 0, "fianco": 0, "lento": 0, "bravo": 0, "pioggia": 0, "persona": 0}
	var attesi := 0.0
	for sd in n:
		var s := _scena(0.0, 10.0, 0.0, -0.8, 5.0, sd + 1)
		attesi += minf(1.0, Falli.FOUL_P_BEHIND * (s[0] as SimMatchScript).foulK(s[2]))
		if s[0].foulTackle(s[2], s[1]):
			conta.dietro += 1
		s = _scena(0.0, 10.0, -0.8, -0.1, 5.0, sd + 1)
		if s[0].foulTackle(s[2], s[1]):
			conta.fianco += 1
		s = _scena(0.0, 10.0, 0.0, -0.8, 1.5, sd + 1)
		if s[0].foulTackle(s[2], s[1]):
			conta.lento += 1
		s = _scena(0.0, 10.0, 0.0, -0.8, 5.0, sd + 1)
		(s[2] as R.Player).st.dif = 90.0
		if s[0].foulTackle(s[2], s[1]):
			conta.bravo += 1
		s = _scena(0.0, 10.0, 0.0, -0.8, 5.0, sd + 1)
		(s[0] as SimMatchScript).meteo = "pioggia"
		if s[0].foulTackle(s[2], s[1]):
			conta.pioggia += 1
		s = _scena(0.0, 10.0, 0.0, -0.8, 5.0, sd + 1, [false, true]) # il difensore è della persona
		if s[0].foulTackle(s[2], s[1]):
			conta.persona += 1
		H.disposeAll()
	note("falli su %d contrasti: %s" % [n, str(conta)])
	check(absf(conta.dietro - attesi) < 0.2 * attesi + 10.0, "da dietro %d, attesi %.0f" % [conta.dietro, attesi])
	check(conta.dietro > 0 and conta.dietro > conta.fianco * 2, "da dietro più falli che di fianco")
	check(conta.fianco > 0, "di fianco qualche fallo")
	check(conta.lento < conta.dietro, "più lento meno falli")
	check(conta.bravo < conta.dietro, "difensore più bravo meno falli")
	check(conta.pioggia > conta.dietro, "pioggia più falli")
	check(conta.persona < conta.dietro, "squadra della persona meno falli")
	return done()


func test_fallo_da_dietro_nel_gioco_ferma_il_contrasto() -> bool:
	# contrasto vero (contacts): difensore incollato alle spalle del portatore fermo nella metà campo avversaria
	var falli := 0
	var puliti := 0
	for sd in 120:
		# portatore della CPU tenuto fermo e senza calciare (niente falli in ritardo); col portatore della persona il
		# difensore alle spalle non contrasta (fuga, tasto Scatto)
		var s := _scena(-10.0, -20.0, 0.0, -0.5, 5.0, sd + 1)
		var m: SimMatchScript = s[0]
		var c: R.Player = s[1]
		var o: R.Player = s[2]
		var evs := H.run(m, 1.5, func(mm: SimMatchScript) -> void:
			c.aiT = 1.0
			c.fx = 0.0 # guarda sempre verso la porta avversaria ...
			c.fy = 1.0
			c.vx = 0.0
			c.vy = 0.0
			c.tx = c.x
			c.ty = c.y
			if o.stun <= 0.0: # ... e il difensore resta incollato al suo fianco, un po' dietro, di corsa verso di lui
				# (il contatto si misura dal pallone, che il portatore tiene ~1 m davanti: da dietro non ci arriva)
				o.x = c.x + 0.55
				o.y = c.y - 0.1
				o.vx = -3.0
				o.vy = 4.0)
		var f: Variant = findEvent(evs, "foul")
		if f != null:
			falli += 1
			check(f.on == c and f.by == s[2], "fallo del difensore sul portatore")
			check(f.how == "dietro" or f.how == "fianco", "fallo da contrasto: %s" % f.how)
			check(hasEvent(evs, "restart", func(e: Dictionary) -> bool: return e.kind == "freekick" and e.team == 0) and not hasEvent(evs, "advantage"),
				"punizione per chi ha subito (nella propria metà niente vantaggio)")
		elif hasEvent(evs, "tackle"):
			puliti += 1
		H.disposeAll()
	note("contrasti da dietro: falli %d, puliti %d" % [falli, puliti])
	check(falli > 10 and puliti > falli, "falli %d, puliti %d" % [falli, puliti])
	return done()


func test_vantaggio_dopo_fallo_da_dietro() -> bool:
	# metà campo avversaria, nessun altro avversario vicino: si lascia correre e chi ha fatto fallo si ferma
	var visto := false
	for sd in 200:
		var s := _scena(0.0, 15.0, 0.0, -0.8, 5.0, sd + 1)
		var m: SimMatchScript = s[0]
		var o: R.Player = s[2]
		if not m.foulTackle(o, s[1]):
			H.disposeAll()
			continue
		visto = true
		eq(m.phase, "play", "si gioca")
		check(hasEvent(m.events, "advantage"), "vantaggio")
		check(o.stun > 0.0 and o.tackleCd > 0.0, "chi ha fatto fallo si ferma un attimo")
		eq(m.ball.owner, s[1], "il pallone resta al portatore")
		H.disposeAll()
		break
	check(visto, "almeno un fallo in 200 prove")
	return done()


func test_fallo_in_ritardo() -> bool:
	# il portatore passa a un compagno; un avversario gli arriva addosso di corsa subito dopo
	var falli := 0
	var prove := 400
	for sd in prove:
		var s := _scena(-5.0, 25.0, 0.0, 0.9, 6.0, sd + 1)
		var m: SimMatchScript = s[0]
		var c: R.Player = s[1]
		var mate: R.Player = m.players[8]
		H.wake(mate, 10.0, 30.0)
		m.kick(c, {"type": "ground", "tx": mate.x, "ty": mate.y})
		var o: R.Player = s[2]
		o.vx = 0.0
		o.vy = -6.0
		var evs := H.run(m, 0.25)
		var f: Variant = findEvent(evs, "foul")
		if f != null:
			falli += 1
			eq(f.how, "ritardo", "fallo in ritardo")
			check(not f.pen, "mai rigore")
			check(hasEvent(evs, "advantage"), "vantaggio: il passaggio è della squadra che ha subito")
		H.disposeAll()
		# lo stesso più indietro (nella propria metà): punizione subito
		s = _scena(-5.0, -15.0, 0.0, 0.9, 6.0, sd + 1)
		m = s[0]
		mate = m.players[8]
		H.wake(mate, 10.0, -10.0)
		m.kick(s[1], {"type": "ground", "tx": mate.x, "ty": mate.y})
		(s[2] as R.Player).vx = 0.0
		(s[2] as R.Player).vy = -6.0
		evs = H.run(m, 0.25)
		if hasEvent(evs, "foul"):
			check(not hasEvent(evs, "advantage") and m.phase == "restart" and m.restart.type == "freekick", "nella propria metà punizione")
		H.disposeAll()
	note("falli in ritardo %d su %d" % [falli, prove])
	check(falli > 0 and falli < prove * 0.35, "falli in ritardo %d su %d" % [falli, prove])
	return done()


func test_in_ritardo_mai_sul_tiro_in_area_rigore() -> bool:
	var rigori := 0
	var sospesi := 0
	for sd in 300:
		# tiro da fuori area: mai fallo in ritardo
		var s := _scena(0.0, C.HL - 25.0, 0.0, 0.9, 6.0, sd + 1)
		var m: SimMatchScript = s[0]
		m.kick(s[1], {"type": "shot", "tx": 2.0, "ty": C.HL, "th": 1.0})
		(s[2] as R.Player).vy = -6.0
		var evs := H.run(m, 0.25)
		check(not hasEvent(evs, "foul"), "niente fallo in ritardo sul tiro da fuori (seme %d)" % sd)
		H.disposeAll()
		# tiro in area che va fuori: il fallo resta in sospeso (vantaggio), poi rigore
		s = _scena(0.0, C.HL - 10.0, 0.0, 0.9, 6.0, sd + 1)
		m = s[0]
		m.kick(s[1], {"type": "shot", "tx": 9.0, "ty": C.HL, "th": 1.0})
		(s[2] as R.Player).vy = -6.0
		evs = H.run(m, 0.25)
		var fs: Variant = findEvent(evs, "foul")
		if fs != null:
			sospesi += 1
			check(not fs.pen and hasEvent(evs, "advantage"), "tiro in area: si lascia andare")
			evs = H.run(m, 3.0)
			check(hasEvent(evs, "restart", func(e: Dictionary) -> bool: return e.kind == "penalty" and e.team == 0), "tiro fuori dopo il fallo: rigore")
		H.disposeAll()
		# passaggio in area: il fallo in ritardo è rigore
		s = _scena(0.0, C.HL - 10.0, 0.0, 0.9, 6.0, sd + 1)
		m = s[0]
		H.wake(m.players[8], 8.0, C.HL - 6.0)
		m.kick(s[1], {"type": "ground", "tx": 8.0, "ty": C.HL - 6.0})
		(s[2] as R.Player).vy = -6.0
		evs = H.run(m, 0.25)
		var f: Variant = findEvent(evs, "foul")
		if f != null:
			rigori += 1
			check(f.pen and m.phase == "restart" and m.restart.type == "penalty", "in area: rigore")
		H.disposeAll()
	note("rigori dopo un passaggio %d, falli in sospeso sul tiro %d (su 300)" % [rigori, sospesi])
	check(rigori > 0 and sospesi > 0, "almeno un rigore e un fallo sul tiro in 300 prove")
	return done()


func test_rigore_e_punizione_ripartono() -> bool:
	# fallo in area: rigore battuto dall'IA, il pallone va verso la porta
	var s := _scena(3.0, C.HL - 8.0, 0.0, -0.8, 5.0, 3)
	var m: SimMatchScript = s[0]
	m.foulCall(s[2], s[1], false, "dietro")
	eq(m.phase, "restart", "gioco fermo")
	eq(m.restart.type, "penalty", "rigore")
	eq(m.restart.team, 0, "per chi attacca")
	var evs := H.run(m, 4.0)
	check(hasEvent(evs, "kick", func(e: Dictionary) -> bool: return e.kind == "shot"), "rigore calciato")
	check(m.phase != "restart" or m.restart.type != "penalty", "il rigore è stato battuto")
	H.disposeAll()
	# fallo a 22 m dalla porta: punizione con barriera, poi si gioca
	s = _scena(4.0, C.HL - 22.0, 0.0, -0.8, 5.0, 4)
	m = s[0]
	H.wake(m.players[11 + 2], 2.0, C.HL - 12.0)
	H.wake(m.players[11 + 3], 0.0, C.HL - 12.0)
	H.wake(m.players[11 + 4], -2.0, C.HL - 14.0)
	H.wake(m.players[11 + 5], 6.0, C.HL - 18.0)
	H.wake(m.players[11 + 7], 4.0, C.HL - 20.5) # avversario addosso: niente vantaggio
	m.foulCall(s[2], s[1], false, "dietro")
	eq(m.restart.type, "freekick", "punizione")
	check(m.restart.wallSide != 0.0, "barriera")
	var inBarriera := 0
	for p: R.Player in m.players:
		if p.wall != null:
			inBarriera += 1
			check(C.hyp(p.x - m.ball.x, p.y - m.ball.y) > 8.5, "barriera a 9 m")
	check(inBarriera >= 2, "in barriera %d" % inBarriera)
	evs = H.run(m, 4.0)
	check(hasEvent(evs, "kick"), "punizione battuta")
	H.disposeAll()
	return done()


func test_secondo_giallo_rosso() -> bool:
	var s := _scena(0.0, -20.0, 0.0, -0.8, 5.0, 5)
	var m: SimMatchScript = s[0]
	var by: R.Player = s[2]
	m.foulCall(by, s[1], true, "dietro")
	check(hasEvent(m.events, "foul", func(e: Dictionary) -> bool: return e.card == "yellow"), "primo giallo")
	m.events.clear()
	m.phase = "play"
	m.restart = null
	H.give(m, s[1])
	m.foulCall(by, s[1], true, "dietro")
	check(hasEvent(m.events, "foul", func(e: Dictionary) -> bool: return e.card == "red"), "secondo giallo = rosso")
	check(by.off, "espulso")
	eq(m.stats.yellows[1], 2, "gialli")
	eq(m.stats.reds[1], 1, "rossi")
	eq(m.restart.type, "freekick", "punizione")
	H.run(m, 3.0)
	check(by.off and absf(by.x) > C.HW, "resta fuori dal campo")
	H.disposeAll()
	return done()


# con la persona simulata del controllo del gameplay (tools/dito_motore.gd, gesti veri) e le opzioni del gioco
func test_frequenza_su_partite_intere() -> bool:
	var tot := {"falli": 0, "gialli": 0, "rossi": 0, "rigori": 0, "dietro": 0, "fianco": 0, "ritardo": 0, "vantaggi": 0}
	for sd in PARTITE:
		var ta := H.mkTeam("A", 60.0, (sd + 1) * 7 + 1)
		var tb := H.mkTeam("B", 60.0, (sd + 1) * 13 + 5)
		var m := H.newMatch(sd + 1, TEMPO_GIOCO, [true, false], ta, tb, "", {"falli": true, "portaAuto": true, "testa": true, "rifiniture": true})
		var dito = Dito.new((sd + 1) * 31 + 7)
		var steps := 0
		while m.phase != "full" and steps < 60 * 60 * 20:
			dito.passo(m, DT, DT)
			m.step(DT)
			steps += 1
			if m.phase == "half":
				m.startSecondHalf()
			if m.headFor(0) and m.headWin.age > 0.5:
				m.headExpire()
			for e: Dictionary in m.events:
				if e.type == "foul":
					tot.falli += 1
					tot[e.how] += 1
					if e.card == "yellow":
						tot.gialli += 1
					elif e.card == "red":
						tot.rossi += 1
				elif e.type == "advantage":
					tot.vantaggi += 1
				elif e.type == "restart" and e.kind == "penalty":
					tot.rigori += 1
			m.events.clear()
		eq(m.phase, "full", "partita finita (seme %d)" % (sd + 1))
		H.disposeAll()
	var n := float(PARTITE)
	note("su %d partite da 2×%.0f s: %s · falli a partita %.2f" % [PARTITE, TEMPO_GIOCO, str(tot), tot.falli / n])
	check(tot.falli / n >= 1.0 and tot.falli / n <= 4.5, "falli a partita %.2f (circa 2-3)" % (tot.falli / n))
	check(tot.gialli > 0 and tot.gialli < tot.falli, "qualche giallo: %d" % tot.gialli)
	check(tot.rigori <= PARTITE / 3, "rigori rari: %d" % tot.rigori)
	return done()


func test_ripetibile_col_seme() -> bool:
	var firme: Array = []
	for k in 2:
		var ta := H.mkTeam("A", 60.0, 8)
		var tb := H.mkTeam("B", 60.0, 18)
		var m := H.newMatch(77, 60.0, [false, false], ta, tb, "pioggia", {"falli": true})
		var firma: Array = []
		while m.phase != "full":
			m.step(DT)
			if m.phase == "half":
				m.startSecondHalf()
			for e: Dictionary in m.events:
				if e.type == "foul" or e.type == "goal" or e.type == "tackle":
					firma.append("%s %.3f" % [e.type, m.time])
			m.events.clear()
		firma.append(str(m.score))
		firme.append(firma)
		H.disposeAll()
	eq(firme[0], firme[1], "stessa partita con lo stesso seme")
	return done()
