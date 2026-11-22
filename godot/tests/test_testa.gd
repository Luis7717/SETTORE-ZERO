# Colpo di testa controllato (sim/testa.gd) e durata del fermatempo in secondi veri (scripts/partita/fermatempo_testa.gd).
extends "test_base.gd"

const FT := preload("res://scripts/partita/fermatempo_testa.gd")
const SimRngScript := preload("res://sim/rng.gd")
const CROSS_ZONA := 14.0 # umano simulato: crossa a un compagno entro tanti metri dal centro della porta


## cross dalla destra verso l'attaccante p in area; difesa parcheggiata tranne il portiere avversario.
## Ritorna [m, p, crossatore]. testa = opzione del colpo di testa controllato.
func cross(sd: int, testa: bool = true, tes: float = 70.0) -> Array:
	var m := H.scene(sd, [true, false])
	m.headCtl = testa
	var p: R.Player = m.team(0)[9]
	var k: R.Player = m.team(0)[7]
	H.wake(p, 1.0, C.HL - 9.0)
	H.wake(k, 24.0, C.HL - 12.0)
	H.wake(m.gk(1), 0.0, C.HL - 0.8)
	p.st.tes = tes
	H.give(m, k)
	m.ctrl[0] = k
	m.kick(k, {"type": "loft", "tx": p.x - 1.5, "ty": p.y + 1.0})
	m.events.clear()
	return [m, p, k]


## passi fino al primo evento `tipo` (al massimo `sec` s); ritorna l'evento o null; `ogni` chiamata a ogni passo
func fino_a(m: SimMatchScript, tipo: String, sec: float, ogni: Callable = Callable()) -> Variant:
	for i in int(sec * 60.0):
		if ogni.is_valid():
			ogni.call(m)
		m.step(DT)
		var e: Variant = findEvent(m.events, tipo)
		m.events.clear()
		if e != null:
			return e
	return null


func test_cross_apre_il_fermatempo_e_passa_il_controllo() -> bool:
	var a := cross(1)
	var m: SimMatchScript = a[0]
	var p: R.Player = a[1]
	var e: Variant = fino_a(m, "head_win", 3.0)
	check(e != null, "fermatempo aperto sul cross")
	if e == null:
		return done()
	eq(e.p, p, "colpisce l'attaccante in area")
	check(m.headFor(0), "headFor(0) mentre si aspetta la linea")
	eq(m.ctrl[0], p, "il controllo passa a chi colpisce")
	check(m.headLeft() >= m.HEAD_WIN_MIN and m.headLeft() <= m.HEAD_WIN_T, "colpo previsto tra %s e %s s (%s)" % [m.HEAD_WIN_MIN, m.HEAD_WIN_T, m.headLeft()])
	check(m.headWin.h >= m.HEAD_LO and m.headWin.h <= m.HEAD_HI, "ad altezza di testa (%s m)" % m.headWin.h)
	return done()


# Luis 2026-11-22: nel fermatempo, senza linea niente colpo automatico: il pallone è perso
func test_senza_linea_il_pallone_e_perso() -> bool:
	var persi := 0
	for sd in range(1, 9):
		var a := cross(sd)
		var m: SimMatchScript = a[0]
		var p: R.Player = a[1]
		if fino_a(m, "head_win", 3.0) == null:
			continue
		var evs := H.run(m, 2.0)
		check(not hasEvent(evs, "kick", func(e: Dictionary) -> bool: return e.p.team == 0 and e.kind in ["header", "volley"]), "seme %d: nessun colpo di testa automatico" % sd)
		check(not hasEvent(evs, "control", func(e: Dictionary) -> bool: return e.p == p), "seme %d: chi doveva colpire non lo controlla" % sd)
		eq(m.stats.headers[0], 0, "seme %d: nessun colpo di testa contato" % sd)
		var fine: Variant = findEvent(evs, "head_end")
		check(fine != null and fine.reason != "colpito", "seme %d: fermatempo chiuso senza colpo" % sd)
		check(m.headWin == null, "seme %d: niente fermatempo rimasto aperto" % sd)
		if fine != null:
			persi += 1
	check(persi >= 6, "fermatempo chiuso col pallone perso in %d casi su 8" % persi)
	return done()


func test_senza_opzione_resta_il_colpo_automatico() -> bool:
	var colpi := 0
	for sd in range(1, 9):
		var a := cross(sd, false)
		var m: SimMatchScript = a[0]
		var evs := H.run(m, 3.0)
		check(not hasEvent(evs, "head_win"), "seme %d: senza l'opzione niente fermatempo" % sd)
		if hasEvent(evs, "kick", func(e: Dictionary) -> bool: return e.p.team == 0 and e.kind in ["header", "volley"]):
			colpi += 1
	check(colpi >= 6, "colpo automatico come prima in %d casi su 8" % colpi)
	return done()


## colpo con la linea verso la porta in (tx, th): ritorna l'evento kick guidato e il punto previsto in porta [cx, ch]
func colpo_mirato(sd: int, tx: float, th: float, tes: float = 70.0) -> Array:
	var a := cross(sd, true, tes)
	var m: SimMatchScript = a[0]
	if fino_a(m, "head_win", 3.0) == null:
		return []
	check(m.userHeader(0, {"goal": true, "tx": tx, "th": th}), "linea accettata")
	check(not m.userHeader(0, {"goal": true, "tx": tx, "th": th}), "una seconda linea non vale")
	var k: Variant = fino_a(m, "kick", 2.0)
	if k == null or not k.get("guidato", false):
		return []
	var s := m.ball.shot
	return [k, s.cx if s != null else NAN, s.ch if s != null else NAN]


func test_linea_in_porta_rispettata() -> bool:
	var giusti := 0
	var colpi := 0
	for sd in range(1, 21):
		var lato := 1.0 if sd % 2 else -1.0
		var r := colpo_mirato(sd, lato * 2.6, 1.0)
		if r.is_empty():
			continue
		colpi += 1
		eq(r[0].kind, "header", "seme %d: colpo di testa" % sd)
		if not is_nan(r[1]) and signf(r[1]) == lato:
			giusti += 1
	check(colpi >= 16, "colpi di testa guidati %d su 20" % colpi)
	check(giusti >= int(colpi * 0.8), "dalla parte scelta %d volte su %d" % [giusti, colpi])
	note("linea in porta: %d colpi, %d dalla parte scelta" % [colpi, giusti])
	return done()


func test_precisione_secondo_tes() -> bool:
	var err := {}
	for tes in [95.0, 30.0]:
		var tot := 0.0
		var n := 0
		for sd in range(1, 31):
			var r := colpo_mirato(100 + sd, 1.5, 1.0, tes)
			if r.is_empty() or is_nan(r[1]):
				continue
			tot += absf(r[1] - 1.5)
			n += 1
		err[tes] = tot / maxi(1, n)
	check(err[95.0] < err[30.0], "più tes = più preciso (errore %.2f m con 95, %.2f m con 30)" % [err[95.0], err[30.0]])
	return done()


func test_sponda_verso_il_compagno() -> bool:
	var a := cross(5)
	var m: SimMatchScript = a[0]
	var q: R.Player = m.team(0)[10]
	H.wake(q, -7.0, C.HL - 14.0)
	if not check(fino_a(m, "head_win", 3.0) != null, "fermatempo aperto"):
		return done()
	m.userHeader(0, {"goal": false, "tx": q.x, "ty": q.y})
	var k: Variant = fino_a(m, "kick", 2.0)
	check(k != null and k.get("sponda", false), "sponda di testa")
	if k == null:
		return done()
	var b := m.ball
	var ux: float = q.x - b.x
	var uy: float = q.y - b.y
	var cosa: float = (b.vx * ux + b.vy * uy) / (C.hyp(b.vx, b.vy) * C.hyp(ux, uy))
	check(cosa > 0.9, "verso il compagno (coseno %.2f)" % cosa)
	check(b.shot == null, "una sponda non è un tiro")
	return done()


# Luis 2026-11-22: anche il cross lo decide la forma del tratto (dritto = rasoterra, curvo = alto a effetto)
func test_cross_disegnato_lo_decide_la_forma_del_tratto() -> bool:
	var m := H.scene(2, [true, false])
	var k: R.Player = m.team(0)[7]
	H.wake(k, 25.0, C.HL - 10.0)
	H.give(m, k)
	eq(m.launch(k, {"type": "auto", "tx": 1.0, "ty": C.HL - 8.0, "curve": 0.5, "tratto": true}, false).type, "ground", "cross dritto = rasoterra")
	eq(m.launch(k, {"type": "auto", "tx": 1.0, "ty": C.HL - 8.0, "curve": 6.0, "tratto": true}, false).type, "loft", "cross curvo = pallone alto")
	return done()


func test_cross_curvo_disegnato_apre_il_fermatempo() -> bool:
	var aperti := 0
	for sd in range(1, 5):
		var a := cross(sd)
		var m: SimMatchScript = a[0]
		var p: R.Player = a[1]
		var k: R.Player = a[2]
		# rifà il cross come lo disegna la persona: linea curva dalla fascia all'attaccante
		H.give(m, k)
		m.ball.kick = null
		m.ball.x = k.x
		m.ball.y = k.y + 0.6
		m.ball.h = 0.0
		m.ball.vh = 0.0
		k.stun = 0.0
		check(m.userKick(0, {"type": "auto", "tx": p.x - 1.5, "ty": p.y + 1.0, "curve": -5.0, "tratto": true}), "seme %d: cross partito" % sd)
		m.events.clear()
		if fino_a(m, "head_win", 3.0) != null:
			aperti += 1
	check(aperti >= 3, "il cross curvo apre il fermatempo del colpo di testa (%d su 4)" % aperti)
	return done()


# Luis 2026-11-22: il pallone arriva alla testa TESTA_FERMATEMPO_S secondi veri dopo l'apertura (3 s)
func test_fermatempo_dura_tre_secondi_veri() -> bool:
	eq(FT.TESTA_FERMATEMPO_S, 3.0, "durata del fermatempo")
	near(FT.velocita(0.6, 3.0), 0.2, 1e-9, "0,6 s di volo in 3 s veri = tempo al 20%")
	eq(FT.velocita(0.6, 0.0), 1.0, "tempo scaduto: velocità normale")
	near(FT.frazione(1.5), 0.5, 1e-9, "a metà il cerchio è pieno a metà")
	var misure: Array = []
	for sd in range(1, 7):
		var a := cross(sd)
		var m: SimMatchScript = a[0]
		if fino_a(m, "head_win", 3.0) == null:
			continue
		# ciclo come gioco.gd: fotogrammi da 1/60 s veri, motore a passi non più lunghi di 1/60 s di partita
		var reale := 0.0
		var dt := 1.0 / 60.0
		while m.headFor(0) and m.headLeft() > 0.0 and reale < 6.0:
			var v := FT.velocita(m.headLeft(), FT.TESTA_FERMATEMPO_S - reale)
			var sdt := dt * v
			var n := maxi(1, ceili(sdt / DT))
			for i in n:
				m.step(sdt / n)
			m.events.clear()
			reale += dt
		misure.append(reale)
		near(reale, FT.TESTA_FERMATEMPO_S, 2.0 / 60.0, "seme %d: pallone alla testa dopo %.3f s veri" % [sd, reale])
	check(misure.size() >= 4, "fermatempi misurati: %d" % misure.size())
	note("secondi veri dall'apertura al colpo: %s" % str(misure))
	return done()


# Luis 2026-11-22: i cross ben fatti verso un compagno in area devono dare occasioni vere di colpo di testa e il
# portiere non le annulla (esce solo se arriva prima dell'attaccante: regola dei calci d'angolo). 24 cross curvi dalla
# fascia (tratto curvo = pallone alto) a un attaccante a 8-12 m dalla porta marcato da un difensore, con un secondo
# difensore sul secondo palo e il portiere.
# La persona disegna la linea verso la porta appena si apre il fermatempo.
func test_cross_ben_fatti_danno_occasioni_vere() -> bool:
	var n := cross_in_area(8.0, 12.0)
	note("cross curvi ben fatti: %d, fermatempi %d, colpi di testa %d (in porta %d), presi dal portiere %d" % [n.cross, n.fermi, n.colpi, n.porta, n.portiere])
	check(n.fermi >= n.cross * 0.6, "fermatempi su cross ben fatti: %d su %d" % [n.fermi, n.cross])
	check(n.colpi >= n.cross * 0.4, "colpi di testa: %d su %d" % [n.colpi, n.cross])
	check(n.portiere <= n.cross * 0.25, "il portiere non annulla i colpi di testa: ne prende %d su %d" % [n.portiere, n.cross])
	return done()


## 24 cross curvi verso un attaccante a da..a metri dalla linea di porta (vedi sopra); conteggi
func cross_in_area(da: float, a_: float) -> Dictionary:
	var n := {"cross": 0, "fermi": 0, "colpi": 0, "portiere": 0, "porta": 0}
	for sd in range(1, 25):
		var m := H.scene(300 + sd, [true, false])
		m.headCtl = true
		var rg := SimRngScript.new(sd)
		var lato: float = 1.0 if sd % 2 else -1.0
		var p: R.Player = m.team(0)[9]
		var k: R.Player = m.team(0)[7]
		var d1: R.Player = m.team(1)[4]
		var d2: R.Player = m.team(1)[3]
		H.wake(p, (rg.next() - 0.5) * 8.0, C.HL - da - rg.next() * (a_ - da))
		H.wake(d1, p.x + (rg.next() - 0.5) * 2.0, p.y + 1.0 + rg.next() * 1.0) # marcatore tra lui e la porta
		H.wake(d2, -lato * 6.0, C.HL - 6.0)
		H.wake(m.gk(1), 0.0, C.HL - 0.8)
		H.wake(k, lato * (20.0 + rg.next() * 8.0), C.HL - 10.0 - rg.next() * 10.0)
		H.give(m, k)
		m.ctrl[0] = k
		m.userKick(0, {"type": "auto", "tx": p.x, "ty": p.y, "curve": 6.0 * lato, "tratto": true})
		m.events.clear()
		n.cross += 1
		for i in 240:
			if m.headFor(0):
				var g := m.gk(1)
				m.userHeader(0, {"goal": true, "tx": (-1.0 if g.x > 0.0 else 1.0) * 2.5, "th": 1.0})
			m.step(DT)
			for e: Dictionary in m.events:
				if e.type == "head_win":
					n.fermi += 1
				elif e.type == "kick" and e.get("guidato", false):
					n.colpi += 1
					if m.ball.shot != null and m.ball.shot.on:
						n.porta += 1
				elif e.type in ["control", "punch"] and e.p == m.gk(1) and n.colpi == 0:
					n.portiere += 1
			m.events.clear()
			if m.ball.owner != null or m.phase != "play":
				break
		m.dispose()
	return n


# umano simulato (harness: disegna la linea verso la porta) che crossa dalla fascia con un tratto curvo (= pallone alto,
# come lo disegnerebbe Luis): i cross ben fatti danno occasioni vere di colpo di testa. 4 partite da 2×150 s: con 3
# partite da 2×90 s i cross erano così pochi che il numero dipendeva da un paio di episodi.
func test_frequenza_con_umano_simulato() -> bool:
	var tot := {"win": 0, "testa": 0, "gol": 0}
	for sd in range(1, 5):
		var crossato := {"p": null}
		var ultimo := {"testa": false}
		var conta := func(m: SimMatchScript) -> void:
			_cross(m, crossato)
			for e: Dictionary in m.events:
				if e.type == "head_win" and e.team == 0:
					tot.win += 1
				elif e.type == "kick":
					ultimo.testa = e.p.team == 0 and e.kind == "header" and e.get("guidato", false) and not e.get("sponda", false)
					if ultimo.testa:
						tot.testa += 1
				elif e.type == "goal" and e.team == 0 and ultimo.testa:
					tot.gol += 1
		var res := H.playMatch({"seed": sd, "mode": "bot", "halfLen": 150.0, "testa": true}, conta)
		res.m.dispose()
	note("4 partite da 2×150 s: %d fermatempi, %d colpi di testa guidati verso la porta, %d gol di testa" % [tot.win, tot.testa, tot.gol])
	check(tot.win >= 4, "fermatempi del colpo di testa: %d" % tot.win)
	check(tot.testa >= 2, "colpi di testa guidati verso la porta: %d" % tot.testa)
	return done()


# persona simulata che crossa: portatore della squadra 0 sulla fascia negli ultimi 28 m, compagno in area = linea a lui
static func _cross(m: SimMatchScript, fatto: Dictionary) -> void:
	var c: R.Player = m.ctrl[0]
	var b := m.ball
	if fatto.p != null and b.owner != null and b.owner != fatto.p:
		fatto.p = null # nuovo possesso: si può crossare di nuovo
	if c == null or b.owner != c or m.phase != "play" or fatto.p == c:
		return
	if absf(c.x) < 14.0 or c.y < C.HL - 28.0:
		return
	# cross ben fatto: al compagno in area più vicino alla porta, dentro la zona del colpo di testa (sotto i 14 m dal
	# centro della porta). Prima andava anche a chi stava al limite dell'area, troppo lontano per colpire di testa
	var q := _bersaglio(m, c)
	if q == null:
		return
	fatto.p = c
	# linea curva (il cross alto si disegna curvo: forma del tratto, Luis 2026-11-22)
	m.userKick(0, {"type": "auto", "tx": q.x + q.vx * 0.6, "ty": q.y + q.vy * 0.6, "curve": 6.0 * signf(c.x), "tratto": true})


static func _bersaglio(m: SimMatchScript, c: R.Player) -> R.Player:
	var best: R.Player = null
	var bd := CROSS_ZONA
	for q: R.Player in m.team(0):
		if q == c or q.off or q.pos == "P":
			continue
		var d := C.hyp(q.x, q.y - C.HL)
		if d < bd:
			bd = d
			best = q
	return best
