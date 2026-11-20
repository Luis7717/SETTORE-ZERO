# Regole e palla inattiva: porting di test/unit/out-of-play (portiere e respinte, spazzata, contrasto),
# advantage, wall, path, preview, sanity e air (tranne il conteggio su 6 partite intere).
extends "test_base.gd"

const SimRngScript := preload("../sim/rng.gd")


# partita senza giocatori umani, già in gioco e col pallone libero
static func newM(seed_value: int) -> SimMatchScript:
	var m := H.newMatch(seed_value, 9999.0, [false, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))
	m.phase = "play"
	m.restart = null
	m.ball.owner = null
	return m


# lascia correre il pallone (senza giocatori che lo tocchino) finché esce o passano `sec` secondi
static func runBall(m: SimMatchScript, sec: float = 3.0) -> Array:
	for p: R.Player in m.players:
		p.x = 0
		p.y = 0
		p.state = "down"
		p.t = 99
	var evs: Array = []
	var i := 0
	while i < sec * 60 and m.phase == "play":
		m.updateBall(1.0 / 60.0)
		evs.append_array(m.events)
		m.events.clear()
		i += 1
	return evs


# ------------------------------------------------------------ portiere e palla fuori (out-of-play)
func test_deflectBehind_mai_in_porta() -> bool:
	var r := SimRngScript.new(7)
	for k in 200:
		var m := newM(100 + k)
		var gk := m.gk(0)
		var b := m.ball
		b.x = (r.next() - 0.5) * C.GW * 1.4
		b.y = -C.HL + 0.3 + r.next() * 5
		b.h = r.next() * 2.4
		b.vx = (r.next() - 0.5) * 20
		b.vy = -5 - r.next() * 20
		b.vh = 0
		m.deflectBehind(gk)
		var evs := runBall(m)
		if not check(not hasEvent(evs, "goal"), "gol al tentativo %d" % k):
			break
		if not eq(m.phase, "restart", "palla non uscita al tentativo %d" % k):
			break
		eq(m.restart.type, "corner", "calcio d'angolo")
		eq(m.restart.team, 1, "per la squadra che attacca")
	return done()


func test_save_parte_delle_respinte_in_angolo() -> bool:
	var corners := 0
	var N := 60
	for k in N:
		var m := newM(300 + k)
		var gk := m.gk(1)
		var b := m.ball
		gk.x = 0
		gk.y = C.HL - 0.6
		b.x = 2.5
		b.y = C.HL - 0.8
		b.h = 1
		b.vx = 2
		b.vy = 28
		b.vh = 0
		b.last = m.players[9]
		m.save(gk, false)
		runBall(m)
		if m.phase == "restart" and m.restart.type == "corner":
			corners += 1
	check(corners >= N * 0.3 and corners <= N * 0.8, "angoli %d su %d" % [corners, N])
	return done()


func test_spazzata_del_difensore_pressato() -> bool:
	var longN := 0
	var N := 20
	for k in N:
		var m := newM(700 + k)
		var d: R.Player = m.players[13]
		var b := m.ball
		var mates := m.team(1)
		var opps := m.team(0)
		for i in mates.size():
			var p: R.Player = mates[i]
			p.x = -24 + i * 4.8
			p.y = C.HL - 30
			p.vx = 0
			p.vy = 0
			p.state = "play"
		for i in opps.size():
			var o: R.Player = opps[i]
			var p: R.Player = mates[i]
			o.x = p.x
			o.y = p.y - 0.8
			o.vx = 0
			o.vy = 0
			o.state = "play"
		d.x = 5
		d.y = C.HL - 10
		d.fx = 0
		d.fy = -1
		b.owner = d
		d.protect = 9
		d.aiT = 0
		b.x = d.x
		b.y = d.y - 0.6
		var att: R.Player = m.players[9]
		att.x = d.x
		att.y = d.y - 1.4
		att.tackleCd = 9
		var kick: Variant = null
		var i := 0
		while i < 90 and kick == null:
			m.dtT = 1.0 / 60.0
			m.carrierAI(d)
			kick = findEvent(m.events, "kick")
			m.events.clear()
			i += 1
		var flight := C.hyp(b.vx, b.vy) * 2 * b.vh / 11.5
		if kick != null and kick.kind == "loft" and b.vy < 0 and flight > 18:
			longN += 1
	check(longN >= N * 0.7, "spazzate lunghe %d su %d" % [longN, N])
	return done()


func test_contrasto_a_volte_palla_vagante() -> bool:
	var cnt := {"loose": 0, "clean": 0}
	for g in 10:
		H.playMatch({"seed": 40 + g, "mode": "ai", "halfLen": 90.0}, func(m: SimMatchScript) -> void:
			for e: Dictionary in m.events:
				if e.type == "tackle" and not e.get("slide", false):
					if e.get("loose", false):
						cnt.loose += 1
					else:
						cnt.clean += 1)
	var frac := float(cnt.loose) / maxi(1, cnt.loose + cnt.clean)
	check(frac > 0.15 and frac < 0.45, "contrasti con palla vagante %d su %d" % [cnt.loose, cnt.loose + cnt.clean])
	note("contrasti con palla vagante %d su %d" % [cnt.loose, cnt.loose + cnt.clean])
	return done()


# ------------------------------------------------------------ vantaggio (advantage)
# fallo da dietro (scivolata) della squadra 1 sul portatore della squadra 0 nel punto (x, y)
static func foulAt(x: float, y: float, extra: bool = false, seed_value: int = 1) -> Array:
	var m := H.scene(seed_value, [false, false])
	var on: R.Player = m.players[9]
	var by: R.Player = m.players[11 + 6]
	H.wake(on, x, y)
	on.fx = 0
	on.fy = 1
	H.give(m, on)
	H.wake(by, x, y - 0.5)
	by.sdx = 0
	by.sdy = 1
	by.state = "slide"
	if extra:
		H.wake(m.players[11 + 7], x + 1.5, y + 1)
	m.foul(by, on)
	return [m, on, by]


func test_vantaggio_il_gioco_continua() -> bool:
	var s := foulAt(0, 12)
	var m: SimMatchScript = s[0]
	var on: R.Player = s[1]
	eq(m.phase, "play", "si gioca")
	check(hasEvent(m.events, "advantage", func(e: Dictionary) -> bool: return e.team == 0 and e.p == on), "vantaggio segnalato")
	check(hasEvent(m.events, "foul"), "il fallo resta segnato")
	eq(m.stats.fouls[1], 1, "falli della squadra 1")
	return done()


func test_vantaggio_palla_persa_si_torna_alla_punizione() -> bool:
	var m: SimMatchScript = foulAt(-4, 12)[0]
	var thief: R.Player = m.players[11 + 8]
	H.wake(thief, 10, 20)
	H.run(m, 1)
	H.give(m, thief)
	var evs := H.run(m, 1.0 / 60.0)
	check(hasEvent(evs, "advantage_back"), "si torna indietro")
	eq(m.phase, "restart", "palla inattiva")
	eq(m.restart.type, "freekick", "punizione")
	eq(m.restart.team, 0, "per chi ha subito il fallo")
	check(C.hyp(m.restart.x + 4, m.restart.y - 12) < 1.5, "punizione in (%.1f, %.1f)" % [m.restart.x, m.restart.y])
	return done()


func test_vantaggio_finito_dopo_2_5_s() -> bool:
	var m: SimMatchScript = foulAt(0, 12)[0]
	var evs := H.run(m, 2.7)
	check(hasEvent(evs, "advantage_over"), "vantaggio finito")
	check(m.advantage == null, "nessun vantaggio in corso")
	eq(m.phase, "play", "si gioca")
	return done()


func test_vantaggio_no_nella_propria_meta_o_con_avversario_addosso() -> bool:
	for c: Array in [[0.0, -20.0, false], [0.0, 15.0, true]]:
		var m: SimMatchScript = foulAt(c[0], c[1], c[2])[0]
		eq(m.phase, "restart", "(%s, %s)" % [c[0], c[1]])
		eq(m.restart.type, "freekick", "punizione subito")
		check(not hasEvent(m.events, "advantage"), "niente vantaggio")
	return done()


func test_vantaggio_chiuso_da_un_tiro() -> bool:
	var s := foulAt(0, 25)
	var m: SimMatchScript = s[0]
	m.aiShoot(s[1])
	check(m.advantage == null, "vantaggio chiuso")
	check(hasEvent(m.events, "advantage_over"), "vantaggio sfruttato")
	return done()


# ------------------------------------------------------------ barriera (wall)
static func wallM(seed_value: int = 1) -> SimMatchScript:
	return H.newMatch(seed_value, 9999.0, [false, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))


static func wallOf(m: SimMatchScript) -> Array:
	return m.team(1).filter(func(p: R.Player) -> bool: return p.wall != null)


func test_barriera_su_punizione_vicina() -> bool:
	for xy: Array in [[0.0, C.HL - 20], [-8.0, C.HL - 24], [12.0, C.HL - 27], [-22.0, C.HL - 12]]:
		var m := wallM()
		m.setRestart("freekick", 0, xy[0], xy[1])
		var b := m.ball
		var w := wallOf(m)
		check(w.size() >= 2 and w.size() <= 5, "(%s, %s): %d in barriera" % [xy[0], xy[1], w.size()])
		for p: R.Player in w:
			var d := C.hyp(p.x - b.x, p.y - b.y)
			check(absf(d - 9.15) < 1.2, "distanza %.2f" % d)
			check(p.y > b.y, "tra palla e porta")
			check(p.pos != "P", "non il portiere")
	return done()


func test_barriera_punizione_lontana_nessuna() -> bool:
	var m := wallM()
	m.setRestart("freekick", 0, 0, 0)
	eq(wallOf(m).size(), 0, "nessuno in barriera")
	return done()


func test_barriera_ferma_poi_si_scioglie() -> bool:
	var m := wallM(3)
	m.setRestart("freekick", 0, 0, C.HL - 22)
	var w := wallOf(m)
	var pos: Array = w.map(func(p: R.Player) -> Array: return [p.x, p.y])
	for i in 48:
		m.step(1.0 / 60.0)
		m.events.clear()
	eq(m.phase, "restart", "non ancora battuta")
	for k in w.size():
		check(C.hyp(w[k].x - pos[k][0], w[k].y - pos[k][1]) < 0.3, "barriera ferma")
	m.setRestart("throw", 1, 32, 0)
	eq(wallOf(m).size(), 0, "barriera sciolta dalla ripartenza nuova")
	return done()


func test_barriera_respinge_un_tiro_basso() -> bool:
	var blocked := 0
	for sd in 10:
		var m := wallM(10 + sd)
		m.setRestart("freekick", 0, 0, C.HL - 22)
		var taker: R.Player = m.restart.taker
		var w := wallOf(m)
		var mid: R.Player = w[w.size() / 2]
		var k := (C.HL - m.ball.y) / (mid.y - m.ball.y)
		m.kick(taker, {"type": "shot", "tx": m.ball.x + (mid.x - m.ball.x) * k, "ty": C.HL, "th": 0.3})
		var evs: Array = []
		for i in 60:
			m.step(1.0 / 60.0)
			evs.append_array(m.events)
			m.events.clear()
		if hasEvent(evs, "block"):
			blocked += 1
	check(blocked >= 7, "respinti %d/10" % blocked)
	return done()


func test_barriera_il_computer_tira_dal_lato_scoperto() -> bool:
	var m := wallM(5)
	m.setRestart("freekick", 0, 6, C.HL - 21)
	var side: float = m.restart.wallSide
	m.aiRestart()
	check(side != 0, "lato coperto")
	var t := (C.HL - m.ball.y) / m.ball.vy
	var xg := m.ball.x + m.ball.vx * t
	check(signf(xg) == -side or absf(xg) < C.GW / 4, "lato coperto %s, palla verso x=%.2f" % [side, xg])
	return done()


# ------------------------------------------------------------ strada disegnata (path)
static func pathScene() -> Array:
	var m := H.newMatch(3, 99999.0, [true, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))
	m.phase = "play"
	m.restart = null
	var c: R.Player = m.players[7]
	m.place(c, 0, -10)
	c.fx = 0
	c.fy = 1
	m.ball.owner = c
	m.ctrl[0] = c
	m.att = 0
	for o: R.Player in m.team(1):
		m.place(o, 0.0 if o.pos == "P" else -28.0 + o.i, 49.0 if o.pos == "P" else 45.0)
	return [m, c]


static func freeze(m: SimMatchScript) -> void:
	for o: R.Player in m.team(1):
		o.stun = 0.2


func test_strada_disegnata_con_curva() -> bool:
	var s := pathScene()
	var m: SimMatchScript = s[0]
	var c: R.Player = s[1]
	var pts: Array = []
	for k in range(0, 11):
		pts.append({"x": 0.0, "y": -10.0 + k})
	for k in range(1, 11):
		pts.append({"x": float(k), "y": 0.0})
	eq(m.userPath(0, pts), true, "strada accettata")
	var nearCorner := false
	var k2 := 0
	while k2 < 8 * 60 and m.move[0] != null:
		freeze(m)
		m.step(DT)
		m.events.clear()
		if C.hyp(c.x, c.y) < 2:
			nearCorner = true
		k2 += 1
	check(nearCorner, "è passato dall'angolo della strada")
	check(C.hyp(c.x - 10, c.y) < 2, "arrivato in fondo (%.1f, %.1f)" % [c.x, c.y])
	check(m.ball.owner == c, "pallone tenuto")
	check(m.move[0] == null, "strada finita")
	return done()


func test_strada_lunga_scatta_ultimo_tratto_no() -> bool:
	var s := pathScene()
	var m: SimMatchScript = s[0]
	var c: R.Player = s[1]
	var pts: Array = []
	for k in range(0, 31):
		pts.append({"x": 0.0, "y": -10.0 + k})
	m.userPath(0, pts)
	freeze(m)
	m.step(DT)
	eq(c.sprint, true, "con tanta strada davanti scatta")
	var k2 := 0
	while k2 < 10 * 60 and m.move[0] != null:
		freeze(m)
		m.step(DT)
		if m.move[0] != null and absf(c.y - 20) < 4:
			eq(c.sprint, false, "sull'ultimo tratto no")
			break
		k2 += 1
	return done()


func test_strada_senza_pallone_non_vale() -> bool:
	var s := pathScene()
	var m: SimMatchScript = s[0]
	var c: R.Player = s[1]
	m.ball.owner = null
	eq(m.userPath(0, [{"x": 0.0, "y": 0.0}]), false, "senza pallone niente strada")
	m.ball.owner = c
	m.userPath(0, [{"x": 0.0, "y": 10.0}])
	m.ball.owner = m.players[15]
	freeze(m)
	m.step(DT)
	check(m.move[0] == null, "strada cancellata quando si perde palla")
	return done()


# ------------------------------------------------------------ anteprima del calcio (preview)
# partita identica senza errore di mira (gauss = 0)
class NoNoise:
	extends "../sim/match.gd"

	func gauss() -> float:
		return 0.0


const SPECS := [
	{"type": "ground", "tx": 8.0, "ty": 22.0, "curve": 0.0},
	{"type": "loft", "tx": 15.0, "ty": 35.0, "curve": 3.0},
	{"type": "shot", "tx": 2.5, "ty": 50.0, "th": 1.2, "curve": -2.0},
	{"type": "auto", "tx": -10.0, "ty": 25.0, "curve": 1.5},
]


static func previewSetup(m: SimMatchScript) -> R.Player:
	m.phase = "play"
	m.restart = null
	for q: R.Player in m.players:
		if q != m.players[9]:
			q.x = 30
			q.y = 40.0 if q.team else -40.0
	var c: R.Player = m.players[9]
	c.x = -4
	c.y = 10
	c.fx = 0
	c.fy = 1
	m.ball.owner = c
	m.ball.x = c.x
	m.ball.y = c.y + 0.6
	m.ctrl[0] = c
	return c


# partita creata qui (non da H.newMatch): la si registra perché il runner la chiuda alla fine
static func track(m: SimMatchScript) -> SimMatchScript:
	H.live.append(m)
	return m


static func previewOpts(seed_value: int) -> Dictionary:
	return {"seed": seed_value, "halfLen": 9999.0, "human": [true, false], "teams": [H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2)]}


func test_predictKick_coincide_col_volo_vero() -> bool:
	for spec: Dictionary in SPECS:
		var m := track(SimMatchScript.new(previewOpts(5)))
		var c := previewSetup(m)
		var pts := m.predictKick(c, spec.duplicate())
		var m2 := track(NoNoise.new(previewOpts(5)))
		var c2 := previewSetup(m2)
		m2.kick(c2, spec.duplicate())
		var s := m2.ball.physCopy()
		var t := 0.0
		var bad := 0
		for p: Dictionary in pts:
			while t < p.t - 1e-9:
				C.ballPhys(s, 1.0 / 60.0)
				t += 1.0 / 60.0
			if not (absf(s.x - p.x) < 1e-6 and absf(s.y - p.y) < 1e-6 and absf(s.h - p.h) < 1e-6):
				bad += 1
		eq(bad, 0, "%s: punti dell'anteprima fuori dal volo vero" % spec.type)
		check(pts.size() >= 5, "%s: almeno 5 punti" % spec.type)
	return done()


func test_predictKick_non_consuma_numeri_casuali() -> bool:
	var m := track(SimMatchScript.new(previewOpts(9)))
	var c := previewSetup(m)
	var twin := track(SimMatchScript.new(previewOpts(9)))
	previewSetup(twin)
	var bx := m.ball.x
	m.predictKick(c, SPECS[1].duplicate())
	eq(m.rnd(), twin.rnd(), "stesso numero casuale dopo l'anteprima")
	eq(m.ball.x, bx, "pallone fermo")
	check(m.ball.owner == c, "pallone ancora al portatore")
	return done()


func test_offsideY() -> bool:
	var m := track(SimMatchScript.new(previewOpts(3)))
	previewSetup(m)
	for q: R.Player in m.team(1):
		q.x = 0
		q.y = 45
	m.gk(1).y = 49
	m.players[12].y = 20
	m.players[13].y = 30
	for q: R.Player in m.team(1):
		if q.pos != "P" and q != m.players[12] and q != m.players[13]:
			q.y = 35
	eq(m.offsideY(0), 35, "penultimo difensore")
	m.ball.owner = null
	m.ball.y = 40
	eq(m.offsideY(0), 40, "pallone più avanti della linea")
	for q: R.Player in m.team(1):
		q.y = -10
	m.ball.y = -20
	eq(m.offsideY(0), 0, "tutti nella propria metà: metà campo")
	for q: R.Player in m.team(0):
		q.y = -30
	m.gk(0).y = -49
	m.ball.y = 0
	eq(m.offsideY(1), -30, "squadra 1: coordinata negativa")
	return done()


# ------------------------------------------------------------ partita intera (sanity)
func test_partita_completa_senza_nan_e_senza_palla_ferma() -> bool:
	var acc := {"nan": 0, "stall": 0, "maxStall": 0, "lx": 0.0, "ly": 0.0}
	var res := H.playMatch({"seed": 42, "mode": "ai", "halfLen": 90.0}, func(mm: SimMatchScript) -> void:
		var b := mm.ball
		if not is_finite(b.x + b.y + b.h + b.vx + b.vy):
			acc.nan += 1
		for p: R.Player in mm.players:
			if not is_finite(p.x + p.y + p.fx + p.fy):
				acc.nan += 1
		if mm.phase == "play" and C.hyp(b.x - acc.lx, b.y - acc.ly) < 0.01:
			acc.stall += 1
			acc.maxStall = maxi(acc.maxStall, acc.stall)
		else:
			acc.stall = 0
		acc.lx = b.x
		acc.ly = b.y)
	eq(res.m.phase, "full", "partita finita")
	eq(acc.nan, 0, "valori non finiti")
	check(acc.maxStall < 6 * 60, "palla ferma per %d passi" % acc.maxStall)
	return done()


# ------------------------------------------------------------ colpi di testa e al volo (air)
static func airKick(m: SimMatchScript, tm: int, kicker: R.Player, off: Array = []) -> R.Kick:
	return R.Kick.make(tm, kicker, "loft", 1, off)


func test_colpo_di_testa_su_cross_alto() -> bool:
	var ok := 0
	for sd in 20:
		var m := H.scene(40 + sd, [false, false])
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
		b.last = m.players[5]
		b.kick = airKick(m, 0, m.players[5])
		m.contacts(1.0 / 60.0)
		var e: Variant = findEvent(m.events, "kick")
		check(e != null and e.kind == "header" and e.p == p, "seme %d: colpo di testa" % sd)
		var t := (C.HL - b.y) / b.vy
		var xg := b.x + b.vx * t
		if b.vy > 0 and absf(xg) < C.GW / 2 + 3:
			ok += 1
	check(ok >= 16, "colpi verso la porta %d/20" % ok)
	return done()


func test_colpo_di_testa_cross_vero_dalla_fascia() -> bool:
	var ok := 0
	for sd in 10:
		var m := H.scene(60 + sd, [false, false])
		var q: R.Player = m.players[5]
		var p: R.Player = m.players[9]
		H.wake(q, -24, C.HL - 14)
		q.fx = 1
		q.fy = 0
		H.give(m, q)
		H.wake(p, 1, C.HL - 9)
		H.wake(m.gk(1), 0, C.HL - 0.6)
		m.kick(q, {"type": "loft", "tx": p.x, "ty": p.y})
		m.events.clear()
		var e: Variant = null
		var i := 0
		while i < 180 and e == null:
			m.step(1.0 / 60.0)
			e = findEvent(m.events, "kick")
			m.events.clear()
			i += 1
		if e != null and e.p == p and (e.kind == "header" or e.kind == "volley") and m.ball.vy > 0:
			ok += 1
	check(ok >= 8, "colpi verso la porta %d/10" % ok)
	return done()


func test_tiro_al_volo() -> bool:
	var m := H.scene(8, [false, false])
	var p: R.Player = m.players[9]
	H.wake(p, -2, C.HL - 11)
	var b := m.ball
	b.x = p.x
	b.y = p.y - 0.4
	b.h = 0.9
	b.vx = 0
	b.vy = 10
	b.vh = -2
	b.ct = 0
	b.kick = airKick(m, 0, m.players[5])
	m.contacts(1.0 / 60.0)
	var e: Variant = findEvent(m.events, "kick")
	eq(e.kind if e != null else null, "volley", "tiro al volo")
	check(b.vy > 10, "parte forte verso la porta")
	eq(m.stats.volleys[0], 1, "statistica volleys")
	eq(m.stats.shots[0], 1, "statistica shots")
	return done()


func test_colpo_di_testa_del_difensore_respinge_lontano() -> bool:
	var m := H.scene(9, [false, false])
	var d: R.Player = m.players[2]
	H.wake(d, 0, -C.HL + 12)
	var b := m.ball
	b.x = d.x
	b.y = d.y + 0.4
	b.h = 2.0
	b.vx = 0
	b.vy = -12
	b.vh = -1
	b.ct = 0
	b.kick = airKick(m, 1, m.players[16])
	m.contacts(1.0 / 60.0)
	var e: Variant = findEvent(m.events, "kick")
	check(e != null and e.kind == "header" and e.get("clear", false), "respinta di testa")
	check(b.vy > 5, "respinta verso l'avanti: vy %s" % b.vy)
	check(m.ball.kick == null, "calcio finito")
	return done()


func test_pallone_alto_lontano_dalle_porte_ingiocabile() -> bool:
	var m := H.scene(10, [false, false])
	var p: R.Player = m.players[7]
	H.wake(p, 0, 0)
	var b := m.ball
	b.x = 0
	b.y = 0.3
	b.h = 2.0
	b.vx = 0
	b.vy = 10
	b.vh = -1
	b.kick = airKick(m, 0, m.players[5])
	m.contacts(1.0 / 60.0)
	eq(m.events.size(), 0, "nessun evento")
	return done()


func test_colpo_di_testa_in_fuorigioco() -> bool:
	var m := H.scene(11, [false, false])
	var p: R.Player = m.players[9]
	H.wake(p, 1, C.HL - 9)
	var b := m.ball
	b.x = p.x
	b.y = p.y
	b.h = 1.8
	b.vx = 9
	b.vy = 0
	b.vh = -1
	b.kick = airKick(m, 0, m.players[5], [p])
	m.contacts(1.0 / 60.0)
	check(hasEvent(m.events, "offside"), "fuorigioco fischiato")
	eq(m.restart.type, "freekick", "punizione")
	eq(m.restart.team, 1, "per la difesa")
	return done()
