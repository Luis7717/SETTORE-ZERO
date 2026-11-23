# Riprese senza teletrasporto (sim/riprese.gd, opzione "riprese"): rimessa, rinvio dal fondo e calcio d'angolo come
# scena (il battitore va a prendere il pallone, lo porta al posto, nel rinvio e nell'angolo lo appoggia e fa la rincorsa).
extends "test_base.gd"

const SALTO_GIOCATORE := 0.5 # m in un passo da 1/60 s: oltre è un teletrasporto (correndo si fanno ~0,15 m)
const SALTO_PALLONE := 1.0   # m in un passo per il pallone


## partita CPU contro CPU (o con la squadra 0 umana) giocata per 3 s, poi pallone libero che rotola da (x, y) a
## velocità (vx, vy), toccato per ultimo dalla squadra `ultimo`
func uscita(sd: int, x: float, y: float, vx: float, vy: float, ultimo: int, riprese := true, umano := false) -> SimMatchScript:
	var m := H.newMatch(sd, 9999.0, [umano, false], H.mkTeam("A", 65.0, sd * 7 + 1), H.mkTeam("B", 65.0, sd * 13 + 5), "", {"riprese": riprese})
	H.run(m, 3.0)
	m.phase = "play"
	m.restart = null
	var b := m.ball
	b.owner = null
	b.kick = null
	b.shot = null
	b.x = x
	b.y = y
	b.h = 0.0
	b.vx = vx
	b.vy = vy
	b.vh = 0.0
	b.last = m.team(ultimo)[5]
	m.events.clear()
	return m


## passi fino alla fine della scena (al massimo sec s); ritorna {ok, salto, salto_b, tempo, fasi, eventi}
## ok = la ripresa è partita come scena e la scena è finita; salto = spostamento più grande di un giocatore in un passo
func fino_a_fine_scena(m: SimMatchScript, sec: float) -> Dictionary:
	var prima: Array = []
	for p: R.Player in m.players:
		prima.append(Vector2(p.x, p.y))
	var bp := Vector2(m.ball.x, m.ball.y)
	var salto := 0.0
	var salto_b := 0.0
	var fasi: Array = []
	var evs: Array = []
	var iniziata := false
	var tempo := 0.0
	for i in int(sec * 60.0):
		m.step(DT)
		evs.append_array(m.events)
		m.events.clear()
		for k in m.players.size():
			var p: R.Player = m.players[k]
			var q := Vector2(p.x, p.y)
			salto = maxf(salto, q.distance_to(prima[k]))
			prima[k] = q
		var bq := Vector2(m.ball.x, m.ball.y)
		salto_b = maxf(salto_b, bq.distance_to(bp))
		bp = bq
		if m.phase == "restart" and m.restart.scena != "":
			iniziata = true
			tempo += DT
			if fasi.is_empty() or fasi.back() != m.restart.scena:
				fasi.append(m.restart.scena)
		elif iniziata:
			return {"ok": true, "salto": salto, "salto_b": salto_b, "tempo": tempo, "fasi": fasi, "eventi": evs}
	return {"ok": false, "salto": salto, "salto_b": salto_b, "tempo": tempo, "fasi": fasi, "eventi": evs}


func test_rimessa_il_battitore_va_a_prendere_il_pallone() -> bool:
	var m := uscita(1, 30.0, 10.0, 9.0, 1.0, 0)
	var r := fino_a_fine_scena(m, 10.0)
	check(r.ok, "la rimessa è una scena e finisce")
	var e: Variant = findEvent(r.eventi, "restart")
	check(e != null and e.kind == "throw" and not e.cut, "rimessa senza taglio di scena")
	check(r.salto < SALTO_GIOCATORE, "nessun giocatore teletrasportato (salto più grande %.2f m)" % r.salto)
	check(r.salto_b < SALTO_PALLONE, "pallone senza salti (%.2f m)" % r.salto_b)
	eq(r.fasi.slice(0, 3), ["va", "raccogli", "porta"], "va, raccoglie, porta (%s)" % str(r.fasi))
	check(r.tempo > 1.0 and r.tempo < 5.0, "scena breve: %.1f s" % r.tempo)
	var tk: R.Player = m.restart.taker
	eq(tk.team, 1, "batte la squadra che non l'ha toccato per ultima")
	near(absf(tk.x), C.HW - 0.3, 0.3, "il battitore è sulla linea laterale")
	near(tk.y, 10.0, m.THROW_SLIDE + 1.5, "vicino al punto d'uscita")
	eq(m.ball.owner, tk, "col pallone in mano")
	check(not m.restart.rinc, "nella rimessa niente rincorsa")
	note("rimessa: %.1f s, fasi %s" % [r.tempo, str(r.fasi)])
	var evs := H.run(m, 3.0)
	check(hasEvent(evs, "kick", func(k: Dictionary) -> bool: return k.p == tk), "poi la CPU batte la rimessa")
	return done()


func test_rinvio_dal_fondo_appoggia_e_rincorsa() -> bool:
	# pallone che esce lontano dall'area piccola: lo rimanda il raccattapalle
	var m := uscita(2, 22.0, C.HL - 3.0, 2.0, 9.0, 0)
	var r := fino_a_fine_scena(m, 12.0)
	check(r.ok, "il rinvio è una scena e finisce")
	var e: Variant = findEvent(r.eventi, "restart")
	check(e != null and e.kind == "goalkick" and not e.cut, "rinvio senza taglio di scena")
	check(hasEvent(r.eventi, "ballboy"), "pallone lontano: lo rimanda il raccattapalle")
	check(r.salto < SALTO_GIOCATORE, "nessun giocatore teletrasportato (salto più grande %.2f m)" % r.salto)
	check(r.salto_b < SALTO_PALLONE, "pallone senza salti (%.2f m)" % r.salto_b)
	check(r.fasi.has("porta") and r.fasi.has("posa") and r.fasi.has("indietro"), "porta, appoggia, indietreggia (%s)" % str(r.fasi))
	check(r.tempo > 1.5 and r.tempo < 6.0, "scena breve: %.1f s" % r.tempo)
	var rs: R.Restart = m.restart
	var gk: R.Player = rs.taker
	eq(gk, m.gk(1), "batte il portiere")
	check(rs.posato and rs.rinc, "pallone appoggiato, portiere pronto alla rincorsa")
	near(m.ball.x, rs.kx, 0.01, "pallone sul posto del rinvio (x)")
	near(m.ball.y, rs.ky, 0.01, "... (y)")
	near(absf(m.ball.y), C.HL - C.SIX_D, 0.6, "sulla linea dell'area piccola")
	var dietro: float = Vector2(gk.x - m.ball.x, gk.y - m.ball.y).length()
	check(dietro > m.RUNUP_M - 0.2, "portiere qualche passo dietro il pallone (%.1f m)" % dietro)
	note("rinvio: %.1f s, fasi %s" % [r.tempo, str(r.fasi)])
	# la CPU calcia: prima la rincorsa (il portiere arriva sul pallone), poi il calcio
	var da := Vector2(gk.x, gk.y)
	var evs := H.run(m, 3.0)
	var k: Variant = findEvent(evs, "kick")
	check(k != null and k.p == gk, "il portiere rinvia")
	check(Vector2(gk.x, gk.y).distance_to(da) > 1.0, "dopo aver preso la rincorsa")
	return done()


func test_angolo_va_alla_bandierina() -> bool:
	var m := uscita(3, 30.0, C.HL - 2.0, 1.0, 9.0, 1)
	for k in [7, 9, 10]: # in attacco: qualcuno è vicino all'area
		H.wake(m.team(0)[k], 12.0 - k, C.HL - 14.0)
	var r := fino_a_fine_scena(m, 14.0)
	check(r.ok, "l'angolo è una scena e finisce")
	var e: Variant = findEvent(r.eventi, "restart")
	check(e != null and e.kind == "corner" and not e.cut, "angolo senza taglio di scena")
	check(r.salto < SALTO_GIOCATORE, "nessun giocatore teletrasportato (salto più grande %.2f m)" % r.salto)
	check(r.salto_b < SALTO_PALLONE, "pallone senza salti (%.2f m)" % r.salto_b)
	check(r.fasi.has("posa") and r.fasi.has("indietro"), "appoggia e indietreggia (%s)" % str(r.fasi))
	var rs: R.Restart = m.restart
	near(m.ball.x, rs.kx, 0.01, "pallone sul posto dell'angolo")
	check(Vector2(absf(m.ball.x) - C.HW, absf(m.ball.y) - C.HL).length() < 1.2, "alla bandierina (%.1f, %.1f)" % [m.ball.x, m.ball.y])
	eq(rs.taker.team, 0, "batte chi attacca")
	note("angolo: %.1f s, fasi %s" % [r.tempo, str(r.fasi)])
	var evs := H.run(m, 3.0)
	check(hasEvent(evs, "kick", func(k: Dictionary) -> bool: return k.p == rs.taker), "poi la CPU batte l'angolo")
	return done()


func test_persona_batte_solo_a_scena_finita() -> bool:
	var m := uscita(4, -30.0, -6.0, -9.0, 0.0, 1, true, true)
	var provati := 0
	var rifiutati := 0
	for i in 600:
		m.step(DT)
		m.events.clear()
		if m.phase == "restart" and m.restart.scena != "":
			provati += 1
			if not m.userKick(0, {"type": "ground", "tx": 0.0, "ty": 0.0}):
				rifiutati += 1
			if i % 60 == 0:
				eq(m.hint(0), "wait", "durante la scena niente gesti di ripresa")
		elif provati > 0:
			break
	check(provati > 0 and rifiutati == provati, "durante la scena il calcio non parte (%d/%d)" % [rifiutati, provati])
	eq(m.hint(0), "restart", "finita la scena tocca alla persona")
	H.run(m, 0.4)
	m.ctrl[0] = m.restart.taker
	check(m.userKick(0, {"type": "ground", "tx": m.restart.taker.x * 0.5, "ty": -6.0}), "poi la rimessa si batte")
	return done()


func test_senza_opzione_come_prima() -> bool:
	var m := uscita(1, 30.0, 10.0, 9.0, 1.0, 0, false)
	for i in 30:
		m.step(DT)
		if m.phase == "restart":
			break
	check(m.phase == "restart", "rimessa")
	eq(m.restart.scena, "", "senza l'opzione niente scena")
	near(absf(m.restart.taker.x), C.HW - 0.3, 0.01, "battitore subito sulla linea (come sempre)")
	return done()


func test_scena_ripetibile() -> bool:
	var a := uscita(5, 25.0, C.HL - 1.0, 3.0, 8.0, 1)
	var b := uscita(5, 25.0, C.HL - 1.0, 3.0, 8.0, 1)
	H.run(a, 6.0)
	H.run(b, 6.0)
	var uguali := true
	for k in a.players.size():
		if a.players[k].x != b.players[k].x or a.players[k].y != b.players[k].y:
			uguali = false
	check(uguali and a.ball.x == b.ball.x and a.ball.y == b.ball.y, "stesso seme, stessa scena")
	return done()
