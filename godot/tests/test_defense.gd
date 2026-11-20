# Difesa della squadra umana: porting di test/unit/defense-help, defense-runs e defense-shape.
# Linee di difesa corte, contrasto "magnetico", intercetto, raggio difensivo, CPU che rientra e pressa.
extends "test_base.gd"


static func newM(seed_value: int = 4) -> SimMatchScript:
	return H.newMatch(seed_value, 99999.0, [true, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))


static func pathLen(x0: float, y0: float, pts: Array) -> float:
	var l := 0.0
	var px := x0
	var py := y0
	for q: Dictionary in pts:
		l += C.hyp(q.x - px, q.y - py)
		px = q.x
		py = q.y
	return l


static func tackledBy(m: SimMatchScript, d: R.Player) -> bool:
	return hasEvent(m.events, "tackle", func(e: Dictionary) -> bool: return e.p == d)


# squadra 1 (computer) col pallone in c; la squadra 0 (umana) difende
static func runsScene() -> Array:
	var m := newM()
	m.phase = "play"
	m.restart = null
	var c: R.Player = m.players[18]
	m.place(c, 0, 20)
	m.ball.owner = c
	m.att = 1
	return [m, c]


static func hold(m: SimMatchScript, c: R.Player) -> void:
	for o: R.Player in m.team(1):
		o.stun = 0.2
	m.ball.owner = c


static func outfield(m: SimMatchScript) -> Array:
	return m.team(0).filter(func(p: R.Player) -> bool: return p.pos != "P")


# ------------------------------------------------------------ linee di difesa corte (defense-help)
func test_linea_tagliata_alla_lunghezza_massima() -> bool:
	var m := newM()
	m.phase = "play"
	m.restart = null
	m.ball.owner = m.players[18]
	var d: R.Player = m.players[3]
	m.place(d, -20, -20)
	var pts: Array = []
	for k in range(1, 41):
		pts.append({"x": -20.0 + k, "y": -20.0})
	check(m.userRun(0, d, pts), "linea accettata")
	var path: Array = m.runOf(d).path
	var l := pathLen(d.x, d.y, path)
	var e: Dictionary = path[path.size() - 1]
	near(l, SimMatchScript.RUN_MAX_LEN, 0.01, "lunghezza della linea")
	check(absf(e.x - (-20.0 + SimMatchScript.RUN_MAX_LEN)) < 0.01 and e.y == -20.0, "l'ultimo punto è sulla linea disegnata")
	return done()


func test_clipLen() -> bool:
	var corta := [{"x": 3.0, "y": 0.0}, {"x": 3.0, "y": 4.0}]
	eq(str(SimMatchScript.clipLen(0, 0, corta, 14)), str(corta), "linea corta intatta")
	var cut := SimMatchScript.clipLen(0, 0, [{"x": 10.0, "y": 0.0}, {"x": 10.0, "y": 10.0}], 14)
	eq(str(cut), str([{"x": 10.0, "y": 0.0}, {"x": 10.0, "y": 4.0}]), "linea lunga tagliata")
	return done()


func test_finita_la_linea_torna_alla_cpu() -> bool:
	var m := newM()
	m.phase = "play"
	m.restart = null
	var c: R.Player = m.players[18]
	m.place(c, 0, -15)
	m.ball.owner = c
	m.att = 1
	var d: R.Player = m.team(0).filter(func(p: R.Player) -> bool: return p.pos == "D")[0]
	m.place(d, 10, 20)
	m.userRun(0, d, [{"x": 10.0, "y": 30.0}])
	var i := 0
	while i < 5 * 60 and m.runOf(d) != null:
		for o: R.Player in m.team(1):
			o.stun = 0.2
		c.protect = 1
		m.move[0] = null
		m.step(DT)
		m.events.clear()
		i += 1
	var y1 := d.y
	for k in 90:
		for o: R.Player in m.team(1):
			o.stun = 0.2
		c.protect = 1
		m.move[0] = null
		m.step(DT)
		m.events.clear()
	check(y1 - d.y > 6, "rientra verso la sua porta (da y %.1f a %.1f)" % [y1, d.y])
	return done()


# ------------------------------------------------------------ contrasto "magnetico"
func brush(human: Array) -> bool:
	var m := H.scene(6, human)
	var T: int = 0 if human[0] else 1
	var D: int = 1 - T
	var c: R.Player = m.players[D * 11 + 9]
	var d: R.Player = m.players[T * 11 + 4]
	H.wake(c, 0, 0)
	c.fx = 0
	c.fy = 1
	H.give(m, c)
	c.stun = 999
	H.wake(d, -7, -2.2)
	d.st.dif = 60
	m.ctrl[T] = d
	for i in 3 * 60:
		if human[T]:
			m.userMove(T, 8, -2.2, true, false)
		else:
			d.tx = 8
			d.ty = -2.2
		m.step(DT)
		var tk := tackledBy(m, d)
		m.events.clear()
		if tk:
			return true
	return false


func test_contrasto_magnetico() -> bool:
	check(brush([true, false]), "passando vicino al portatore il controllato ruba palla")
	return done()


func reachRun(humanDef: bool) -> bool:
	var m := H.scene(7, [true, false])
	var T: int = 0 if humanDef else 1
	var c: R.Player = m.players[(1 - T) * 11 + 9]
	var d: R.Player = m.players[T * 11 + 4]
	H.wake(c, 0, 0)
	H.give(m, c)
	c.stun = 999
	H.wake(d, 1.15 + c.fx * 0.6, c.fy * 0.6)
	d.st.dif = 60
	m.ctrl[T] = d
	for i in 60:
		d.tx = d.x
		d.ty = d.y
		d.vx = 0
		d.vy = 0
		m.contacts(DT)
		var tk := hasEvent(m.events, "tackle")
		m.events.clear()
		if tk:
			return true
	return false


func test_raggio_di_contrasto_piu_largo_per_chi_muove_la_persona() -> bool:
	eq(reachRun(true), true, "squadra umana: preso")
	eq(reachRun(false), false, "IA: stesso raggio di prima, non preso")
	return done()


# ------------------------------------------------------------ intercetto in corsa
func intercept(seed_value: int, humanDef: bool) -> bool:
	var m := H.scene(seed_value, [true, false])
	var T: int = 0 if humanDef else 1
	var k: R.Player = m.players[(1 - T) * 11 + 7]
	var d: R.Player = m.players[T * 11 + 3]
	H.wake(k, 0, 20)
	H.wake(d, 0, 0)
	d.st.dif = 70
	k.st.pas = 50
	var b := m.ball
	b.owner = null
	b.x = 0
	b.y = 8
	b.h = 0
	b.vh = 0
	b.vx = 0
	b.vy = -15
	b.cax = 0
	b.cay = 0
	b.ct = 0
	b.shot = null
	b.kick = R.Kick.make(1 - T, k, "ground", 0.5)
	var i := 0
	while i < 90 and b.owner == null and b.kick != null:
		d.vx = 0
		d.vy = 6
		m.contacts(DT)
		m.updateBall(DT)
		if b.kick != null:
			b.kick.age = maxf(b.kick.age, 0.5)
		i += 1
	return b.owner == d


func test_intercetto_in_corsa_umano() -> bool:
	for s in range(1, 13):
		eq(intercept(s, true), true, "seme %d: pallone controllato" % s)
	return done()


func test_intercetto_in_corsa_ia_a_volte_devia() -> bool:
	var kept := 0
	for s in range(1, 13):
		if intercept(s, false):
			kept += 1
	check(kept < 12, "IA: %d/12 controllati" % kept)
	return done()


# ------------------------------------------------------------ linee di difesa (defense-runs)
func test_corre_lungo_la_linea_disegnata() -> bool:
	var sc := runsScene()
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	var d: R.Player = m.players[3]
	m.place(d, -10, -10)
	var pts: Array = []
	for k in range(1, 13):
		pts.append({"x": -10.0 + k, "y": -10.0 + k * 0.5})
	check(m.userRun(0, d, pts), "linea accettata")
	var k2 := 0
	while k2 < 6 * 60 and m.runOf(d) != null:
		hold(m, c)
		m.step(DT)
		m.events.clear()
		k2 += 1
	check(C.hyp(d.x - 2, d.y + 4) < 2, "arrivato in fondo alla linea (%.1f, %.1f)" % [d.x, d.y])
	check(m.runOf(d) == null, "linea finita")
	return done()


func test_linee_per_tutti_tranne_il_portiere() -> bool:
	var m: SimMatchScript = runsScene()[0]
	var of := outfield(m)
	for k in of.size():
		eq(m.userRun(0, of[k], [{"x": -20.0 + k * 4, "y": -20.0}]), true, "linea del giocatore %d" % k)
	eq(m.runs[0].size(), 10, "dieci linee")
	eq(m.userRun(0, m.gk(0), [{"x": 0.0, "y": -40.0}]), false, "il portiere no")
	m.userRun(0, of[1], [{"x": 0.0, "y": -30.0}])
	eq(m.runs[0].size(), 10, "una nuova linea dello stesso giocatore sostituisce la sua")
	return done()


func test_linee_cancellate_quando_si_prende_palla() -> bool:
	var m: SimMatchScript = runsScene()[0]
	m.userRun(0, m.players[3], [{"x": 0.0, "y": -30.0}])
	m.ball.owner = m.players[7]
	m.step(DT)
	eq(m.runs[0].size(), 0, "linee cancellate")
	return done()


func test_raggio_difensivo() -> bool:
	var m: SimMatchScript = runsScene()[0]
	var d: R.Player = m.players[3]
	var k: R.Player = m.players[18]
	m.ball.kick = R.Kick.make(1, k, "ground", 0)
	d.st.dif = 80
	k.st.pas = 40
	var wide := m.reachOf(d)
	d.st.dif = 50
	k.st.pas = 85
	var narrow := m.reachOf(d)
	d.st.dif = 60
	k.st.pas = 60
	var even := m.reachOf(d)
	check(wide > even and even > narrow, "%s > %s > %s" % [wide, even, narrow])
	m.ball.kick.type = "shot"
	check(m.reachOf(d) < even, "sui tiri vale il raggio dei tiri")
	return done()


func passAt(dif: float, pas: float) -> bool:
	var sc := runsScene()
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	var d: R.Player = m.players[3]
	for o: R.Player in m.players:
		if o != c and o != d:
			m.place(o, 30.0 if o.team else -30.0, o.i * 4 - 40)
	m.place(d, 1.15, 10)
	d.st.dif = dif
	c.st.pas = pas
	m.kick(c, {"type": "ground", "tx": 0.0, "ty": 0.0, "curve": 0.0})
	var b := m.ball
	b.x = 0
	b.y = c.y - 0.6
	b.vx = 0
	b.vy = -14
	b.cax = 0
	b.cay = 0
	b.ct = 0
	var i := 0
	while i < 120 and b.owner == null and b.kick != null:
		d.vx = 0
		d.vy = 0
		m.contacts(DT)
		m.updateBall(DT)
		i += 1
	return b.owner == d or b.last == d


func test_stesso_passaggio_preso_o_no_secondo_le_abilita() -> bool:
	eq(passAt(85, 40), true, "difensore forte contro passaggio scarso: preso")
	eq(passAt(45, 90), false, "difensore debole contro passaggio preciso: passa")
	return done()


func test_chi_ha_la_linea_la_segue_gli_altri_li_muove_la_cpu() -> bool:
	var sc := runsScene()
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	var d: R.Player = m.players[3]
	var start: Array = outfield(m).map(func(p: R.Player) -> Array: return [p, p.x, p.y])
	var end := {"x": d.x + 6, "y": d.y}
	m.userRun(0, d, [end])
	var off := 0.0
	var reached := 99.0
	for i in 120:
		hold(m, c)
		m.step(DT)
		m.events.clear()
		if m.runOf(d) != null:
			off = maxf(off, absf(d.y - end.y))
		reached = minf(reached, C.hyp(d.x - end.x, d.y - end.y))
	check(reached < 1, "chi ha la linea arriva in fondo")
	check(m.runOf(d) == null, "linea finita: il giocatore torna alla CPU")
	check(off < 0.8, "resta sulla sua linea (scarto %.2f m)" % off)
	var moved := 0
	for s: Array in start:
		var p: R.Player = s[0]
		if p != d and C.hyp(p.x - s[1], p.y - s[2]) > 1:
			moved += 1
	check(moved >= 3, "la CPU muove gli altri (%d si sono mossi)" % moved)
	return done()


func test_controllato_segue_il_dito() -> bool:
	var sc := runsScene()
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	var k: R.Player = m.ctrl[0]
	if not check(k != null, "c'è un controllato"):
		return done()
	var x0 := k.x
	var y0 := k.y
	for i in 60:
		hold(m, c)
		m.userMove(0, x0 + 8, y0, true)
		m.step(DT)
		m.events.clear()
	check(C.hyp(k.x - x0, k.y - y0) > 3, "il controllato segue il dito")
	return done()


func test_linea_sull_avversario_porta_al_contrasto() -> bool:
	var sc := runsScene()
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	var d: R.Player = m.players[3]
	m.place(d, c.x - 6, c.y - 6)
	d.st.dif = 70
	m.userRun(0, d, [{"x": c.x - 3, "y": c.y - 3}, {"x": c.x, "y": c.y}])
	var won := false
	var i := 0
	while i < 6 * 60 and not won:
		hold(m, c)
		c.stun = 0
		c.vx = 0
		c.vy = 0
		m.step(DT)
		won = tackledBy(m, d)
		m.events.clear()
		i += 1
	check(won, "il difensore arriva sull'avversario e contrasta")
	return done()


func test_nessuna_scivolata_in_partita() -> bool:
	var cnt := {"slides": 0}
	for s in [1, 2]:
		H.playMatch({"seed": s, "mode": "ai"}, func(m: SimMatchScript) -> void: cnt.slides += countEvents(m.events, "slide"))
	eq(cnt.slides, 0, "scivolate dell'IA")
	return done()


# ------------------------------------------------------------ forma della squadra (defense-shape)
static func shapeScene(x: float, y: float, seed_value: int = 4) -> Array:
	var m := newM(seed_value)
	m.phase = "play"
	m.restart = null
	var c: R.Player = m.players[18]
	m.place(c, x, y)
	m.ball.owner = c
	m.att = 1
	for p: R.Player in m.team(0):
		if p.pos != "P":
			m.place(p, p.bx * 25, 20 + p.i)
	return [m, c]


static func shapeHold(m: SimMatchScript, c: R.Player) -> void:
	for o: R.Player in m.team(1):
		o.stun = 0.2
	m.ball.owner = c
	m.move[0] = null
	c.protect = 1


static func play(m: SimMatchScript, c: R.Player, sec: float) -> void:
	for i in int(sec * 60):
		shapeHold(m, c)
		m.step(DT)
		m.events.clear()


static func nearBall(m: SimMatchScript, c: R.Player, r: float) -> Array:
	return outfield(m).filter(func(p: R.Player) -> bool: return C.hyp(p.x - c.x, p.y - c.y) < r)


func test_rientrano_dietro_la_palla() -> bool:
	var sc := shapeScene(4, -15)
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	play(m, c, 7)
	var pressing := nearBall(m, c, 3)
	for p: R.Player in outfield(m):
		if pressing.has(p):
			continue
		if p.pos == "D":
			check(p.y < c.y - 1, "difensore %d dietro la palla (y %.1f, palla %.1f)" % [p.i, p.y, c.y])
		if p.pos == "C":
			check(p.y < c.y + 1.5, "centrocampista %d non davanti alla palla (y %.1f)" % [p.i, p.y])
		var a := m.anchor(p)
		check(C.hyp(p.x - a[0], p.y - a[1]) < 10, "giocatore %d vicino al suo posto (%.1f m)" % [p.i, C.hyp(p.x - a[0], p.y - a[1])])
	return done()


func test_rientro_di_corsa_con_lo_scatto() -> bool:
	var sc := shapeScene(0, -10)
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	var d: R.Player = outfield(m).filter(func(p: R.Player) -> bool: return p.pos == "D")[0]
	shapeHold(m, c)
	m.step(DT)
	eq(d.sprint, true, "il difensore rimasto in attacco rientra scattando")
	return done()


func test_pressing_uno_solo_a_centrocampo() -> bool:
	var sc := shapeScene(0, 8)
	play(sc[0], sc[1], 5)
	eq(nearBall(sc[0], sc[1], 2.5).size(), 1, "uno solo sul portatore")
	return done()


func test_pressing_in_due_nella_nostra_trequarti() -> bool:
	var sc := shapeScene(6, -24)
	play(sc[0], sc[1], 9)
	eq(nearBall(sc[0], sc[1], 3).size(), 2, "due sul portatore")
	return done()


func test_la_cpu_pressa_davvero() -> bool:
	var m: SimMatchScript = shapeScene(0, 0)[0]
	var tackle := false
	var i := 0
	while i < 12 * 60 and not tackle:
		for o: R.Player in m.team(1):
			o.stun = 0.2
		m.move[0] = null
		m.step(DT)
		tackle = hasEvent(m.events, "tackle", func(e: Dictionary) -> bool: return e.p.team == 0)
		m.events.clear()
		i += 1
	check(tackle, "palla rubata dal pressing")
	return done()


func test_la_linea_vale_piu_del_pressing() -> bool:
	var sc := shapeScene(0, 8)
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	var of := outfield(m)
	of.sort_custom(func(a: R.Player, b: R.Player) -> bool: return C.hyp(a.x - c.x, a.y - c.y) < C.hyp(b.x - c.x, b.y - c.y))
	var d: R.Player = of[0]
	m.place(d, c.x + 3, c.y + 3)
	var end := {"x": d.x - 10, "y": d.y + 2}
	check(m.userRun(0, d, [end]), "linea accettata")
	var maxOff := 0.0
	var i := 0
	while i < 4 * 60 and m.runOf(d) != null:
		shapeHold(m, c)
		m.step(DT)
		m.events.clear()
		maxOff = maxf(maxOff, absf(d.y - (c.y + 3 + (d.x - (c.x + 3)) * (2.0 / -10.0))))
		i += 1
	check(m.runOf(d) == null, "linea finita")
	check(C.hyp(d.x - end.x, d.y - end.y) < 1, "arrivato in fondo alla linea")
	check(maxOff < 1.5, "rimasto sulla linea (scarto massimo %.2f m)" % maxOff)
	play(m, c, 3)
	check(nearBall(m, c, 2.5).any(func(p: R.Player) -> bool: return p != d), "intanto un altro pressa il portatore")
	return done()


func test_pallone_vagante_ci_va_il_piu_rapido() -> bool:
	var m: SimMatchScript = shapeScene(0, 0)[0]
	var b := m.ball
	b.owner = null
	b.kick = null
	b.x = -3
	b.y = 5
	b.vx = 0
	b.vy = 0
	b.h = 0
	b.vh = 0
	for o: R.Player in m.team(1):
		m.place(o, o.x, 45)
	var got := false
	var i := 0
	while i < 4 * 60 and not got:
		m.move[0] = null
		for o: R.Player in m.team(1):
			o.stun = 0.2
		m.step(DT)
		got = b.owner != null and b.owner.team == 0
		m.events.clear()
		i += 1
	check(got, "un nostro giocatore prende il pallone")
	return done()


func test_recupera_palla_senza_autodef_restano_fermi() -> bool:
	var sc := shapeScene(0, 8)
	var m: SimMatchScript = sc[0]
	m.autoDef[0] = false
	var start: Array = outfield(m).map(func(p: R.Player) -> Array: return [p, p.x, p.y])
	play(m, sc[1], 2)
	for s: Array in start:
		var p: R.Player = s[0]
		check(C.hyp(p.x - s[1], p.y - s[2]) < 1, "giocatore %d fermo" % p.i)
	return done()
