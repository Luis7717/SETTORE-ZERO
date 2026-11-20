# Attacco della squadra umana e scatto: porting di test/unit/attack-spacing e test/unit/sprint
# (tranne il test dell'animazione sprintMix, che è grafica).
extends "test_base.gd"

const F := preload("../sim/fmath.gd")


# portatore umano a (0, y0) fermo col pallone, compagni ammucchiati intorno a lui, avversari ai loro posti
static func spacingScene(seed_value: int, y0: float = -12.0) -> Array:
	var m := H.newMatch(seed_value, 99999.0, [true, false], H.mkTeam("A", 60, seed_value), H.mkTeam("B", 60, seed_value + 50))
	m.phase = "play"
	m.restart = null
	var c: R.Player = m.players[7]
	m.place(c, 0, y0)
	c.fx = 0
	c.fy = 1
	m.ball.owner = c
	m.ctrl[0] = c
	m.att = 0
	var k := 0
	for p: R.Player in m.team(0):
		if p.pos != "P" and p != c:
			m.place(p, F.cos_(k) * 4, y0 + F.sin_(k) * 4)
			k += 1
	for o: R.Player in m.team(1):
		var a := m.anchor(o)
		m.place(o, a[0], a[1])
	return [m, c]


static func hold(m: SimMatchScript, c: R.Player) -> void:
	for o: R.Player in m.team(1):
		o.stun = 0.2
	m.ball.owner = c
	c.stun = 0.2
	m.move[0] = null


static func mates(m: SimMatchScript, c: R.Player) -> Array:
	return m.team(0).filter(func(p: R.Player) -> bool: return p.pos != "P" and p != c)


# distanza media di ogni compagno senza palla dal compagno più vicino
static func spacing(m: SimMatchScript, c: R.Player) -> float:
	var ms := mates(m, c)
	var s := 0.0
	for q: R.Player in ms:
		var best := INF
		for r: R.Player in ms:
			if r != q:
				best = minf(best, C.hyp(r.x - q.x, r.y - q.y))
		s += best
	return s / ms.size()


func test_compagni_allargati_niente_grappoli() -> bool:
	var sum := 0.0
	var n := 0
	var pairs := 0
	for sd in [1, 2, 3, 4, 5]:
		var sc := spacingScene(sd)
		var m: SimMatchScript = sc[0]
		var c: R.Player = sc[1]
		for i in 8 * 60:
			hold(m, c)
			m.step(DT)
			m.events.clear()
			if i >= 5 * 60:
				sum += spacing(m, c)
				n += 1
				var ms := mates(m, c)
				for a in ms.size():
					for b in range(a + 1, ms.size()):
						if C.hyp(ms[a].x - ms[b].x, ms[a].y - ms[b].y) < 6:
							pairs += 1
	check(sum / n > 12, "distanza media dal compagno più vicino %.1f m" % (sum / n))
	check(float(pairs) / n < 0.3, "coppie di compagni a meno di 6 m: %.2f in media" % (float(pairs) / n))
	note("distanza media %.1f m, coppie vicine %.2f" % [sum / n, float(pairs) / n])
	return done()


func test_nessun_compagno_addosso_al_portatore() -> bool:
	for sd in [1, 2, 3]:
		var sc := spacingScene(sd)
		var m: SimMatchScript = sc[0]
		var c: R.Player = sc[1]
		for i in 8 * 60:
			hold(m, c)
			m.step(DT)
			m.events.clear()
		var nearN := mates(m, c).filter(func(p: R.Player) -> bool: return C.hyp(p.x - c.x, p.y - c.y) < 6).size()
		eq(nearN, 0, "seme %d: compagni entro 6 m dal portatore" % sd)
	return done()


func test_punte_sulla_linea_del_fuorigioco() -> bool:
	var sc := spacingScene(2, -22)
	var m: SimMatchScript = sc[0]
	var c: R.Player = sc[1]
	for i in 8 * 60:
		hold(m, c)
		m.step(DT)
		m.events.clear()
	var line: float = m.offLine[0]
	var deep := m.team(0).filter(func(p: R.Player) -> bool: return p.pos == "A" and p.y > line - 4)
	check(deep.size() >= 1, "punte vicino alla linea del fuorigioco (%.1f)" % line)
	check(m.team(0).all(func(p: R.Player) -> bool: return p.y <= line + 0.5), "nessuno in fuorigioco")
	return done()


# ------------------------------------------------------------ scatto (sprint)
# portatore della squadra 0 che corre in avanti per 2 s tenendo il dito 20 m davanti
static func runFor(sprint: bool, energy: float) -> Dictionary:
	var m := H.scene(3)
	var p: R.Player = m.players[9]
	H.wake(p, 0, -30)
	p.fx = 0
	p.fy = 1
	p.energy = energy
	H.give(m, p)
	var y0 := p.y
	var e0 := p.energy
	H.run(m, 2, func(mm: SimMatchScript) -> void: mm.userMove(0, p.x, p.y + 20, true, sprint))
	return {"dist": p.y - y0, "used": e0 - p.energy}


func test_scatto_piu_veloce_e_consuma_di_piu() -> bool:
	var corsa := runFor(false, 1)
	var scatto := runFor(true, 1)
	check(scatto.dist > corsa.dist * 1.08, "scatto %.2f m, corsa %.2f m" % [scatto.dist, corsa.dist])
	check(scatto.used > corsa.used * 2, "energia scatto %s, corsa %s" % [scatto.used, corsa.used])
	return done()


func test_scatto_a_energia_bassa_rende_meno() -> bool:
	var pieno: float = runFor(true, 1).dist / runFor(false, 1).dist
	var stanco: float = runFor(true, 0.3).dist / runFor(false, 0.3).dist
	check(pieno > stanco + 0.02, "guadagno a energia piena %.3f, stanco %.3f" % [pieno, stanco])
	return done()


func test_da_fermi_l_energia_si_recupera() -> bool:
	var m := H.scene(4)
	var p: R.Player = m.players[9]
	H.wake(p, 0, -30)
	p.energy = 0.5
	H.give(m, p)
	H.run(m, 3, func(mm: SimMatchScript) -> void: mm.userMove(0, p.x, p.y, true))
	check(p.energy > 0.505, "energia %s" % p.energy)
	return done()


func test_scatto_solo_col_dito_lontano() -> bool:
	var m := H.scene(5)
	var p: R.Player = m.players[9]
	H.wake(p, 0, -30)
	H.give(m, p)
	m.updateCtrl(0)
	m.userMove(0, p.x + 2, p.y + 3, true)
	eq(m.move[0].sprint, false, "dito vicino: niente scatto")
	m.userMove(0, p.x, p.y + 15, true)
	eq(m.move[0].sprint, true, "dito lontano: scatto")
	m.userMove(0, p.x, p.y + 15, false)
	eq(m.move[0].sprint, false, "un tocco singolo non è uno scatto")
	return done()


static func pathSpeed(path: bool) -> Dictionary:
	var m := H.scene(3)
	var p: R.Player = m.players[9]
	H.wake(p, 0, -30)
	p.fx = 0
	p.fy = 1
	H.give(m, p)
	m.updateCtrl(0)
	if path:
		var pts: Array = []
		for k in range(1, 41):
			pts.append({"x": 0.0, "y": -30.0 + k})
		m.userPath(0, pts)
	H.run(m, 2.5, func(mm: SimMatchScript) -> void:
		if not path:
			mm.userMove(0, p.x, p.y + 20, true, true))
	return {"v": C.hyp(p.vx, p.vy), "sprint": p.sprint}


func test_scatto_lungo_una_strada_disegnata() -> bool:
	var strada := pathSpeed(true)
	var dito := pathSpeed(false)
	eq(strada.sprint, true, "con tanta strada davanti scatta")
	check(strada.v > dito.v * 0.97, "strada %.2f m/s, scatto col dito %.2f m/s" % [strada.v, dito.v])
	return done()


func test_scatto_differenza_chiara_con_la_corsa() -> bool:
	var corsa := runFor(false, 1)
	var scatto := runFor(true, 1)
	check(scatto.dist > corsa.dist * 1.17, "scatto %.2f m, corsa %.2f m in 2 s" % [scatto.dist, corsa.dist])
	return done()
