# Portiere sui tiri da lontano e sui lanci lunghi (Luis 2026-11-26: "con i cross da lontano o tiri da lontano il
# portiere si butta a vuoto molto prima e la palla va in rete"). Con l'opzione "parata" il tuffo (automatico, della
# CPU o manuale) parte solo quando il pallone è abbastanza vicino da arrivare mentre il portiere è ancora in volo
# (PARA_DIVE_WIN), prima si sposta a passi laterali; sui lanci alti che non sono tiri non si tuffa finché un
# attaccante può ancora toccare il pallone, e se ci arriva prima esce a prenderlo.
extends "test_base.gd"

const ParataScript := preload("res://sim/parata.gd")
const DIVE_T := 0.8 # durata del tuffo in motion.gd diveStep (poi il portiere è a terra)


## tiro verso la porta della squadra `def` da (sx, dist m dalla porta) al punto (tx, th); spec in più (tratto, curve)
func tiro(sd: int, def: int, sx: float, dist: float, tx: float, th: float, extra: Dictionary = {}, auto: bool = true, por: float = 70.0) -> Array:
	var m := H.scene(sd, [true, false])
	m.paraCtl = true
	m.rifiniture = true
	m.paraSeed = sd
	m.autoGk = [auto, false]
	var att: int = 1 - def
	var dir: float = 1.0 if att == 0 else -1.0
	var gy: float = dir * C.HL
	for p: R.Player in m.players:
		H.wake(p, (p.i % 11 - 5) * 5.0, -dir * 30.0 + (p.team - 0.5) * 2.0)
	var k: R.Player = m.team(att)[9]
	H.wake(k, sx, gy - dir * dist)
	k.fx = 0.0
	k.fy = dir
	k.st.tir = 75.0
	var g := m.gk(def)
	H.wake(g, 0.0, gy - dir * 0.6)
	g.st.por = por
	H.give(m, k)
	var sp := {"type": "shot", "tx": tx, "ty": gy, "th": th, "human": att == 0}
	sp.merge(extra, true)
	m.kick(k, sp)
	m.events.clear()
	return [m, k, g]


## segue il tiro: {esito: parata|gol|fuori, anticipo: s tra l'inizio del tuffo e il pallone sulla linea del portiere (-1 = niente tuffo)}
func segui(m: SimMatchScript, g: R.Player, manuale_scade: bool = false) -> Dictionary:
	var dir: float = -1.0 if g.team else 1.0 # verso dove attacca la squadra del portiere
	var t0 := -1.0
	var ant := -1.0
	var esito := "fuori"
	for i in 270:
		if manuale_scade and m.paraFor(g.team):
			m.paraExpire(g.team)
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dive" and e.p == g and t0 < 0.0:
				t0 = m.time
			if e.type == "save" and e.p == g:
				esito = "parata"
			elif e.type == "goal":
				esito = "gol"
		m.events.clear()
		var b := m.ball
		if t0 >= 0.0 and ant < 0.0 and ((b.y - g.y) * dir <= 0.0 or absf(b.y) >= C.HL):
			ant = m.time - t0
		if esito != "fuori" or m.phase != "play" or b.owner != null:
			break
	if t0 >= 0.0 and ant < 0.0:
		ant = m.time - t0
	return {"esito": esito, "anticipo": ant if t0 >= 0.0 else -1.0}


func _conta_lontano(def: int, extra: Dictionary, th: float, dist: float, auto: bool, manuale_scade: bool) -> Dictionary:
	var st := {"n": 0, "parate": 0, "gol": 0, "presto": 0, "peggiore": 0.0}
	for sd in range(1, 25):
		var tx: float = [-3.1, -2.2, -1.2, 1.2, 2.2, 3.1][sd % 6]
		var ex := extra.duplicate()
		if ex.has("curve"):
			ex.curve = float(ex.curve) * (1.0 if sd % 2 == 0 else -1.0)
		var a := tiro(sd, def, float(sd % 5 - 2) * 4.0, dist, tx, th, ex, auto)
		var m: SimMatchScript = a[0]
		var s: R.Shot = m.ball.shot
		if s == null or not s.on:
			continue
		st.n += 1
		var r := segui(m, a[2], manuale_scade)
		if r.esito == "parata":
			st.parate += 1
		elif r.esito == "gol":
			st.gol += 1
		if float(r.anticipo) > DIVE_T - 0.02:
			st.presto += 1
		st.peggiore = maxf(st.peggiore, float(r.anticipo))
	return st


# tiri da 30-45 m della CPU contro il nostro portiere automatico: il tuffo non finisce mai prima del pallone
func test_tiro_da_lontano_il_nostro_automatico_non_si_tuffa_a_vuoto() -> bool:
	for dist: float in [30.0, 40.0]:
		var st := _conta_lontano(0, {}, 1.2, dist, true, false)
		note("da %d m, nostro automatico: parate %d gol %d su %d, tuffi finiti prima del pallone %d (peggiore %.2f s)" % [dist, st.parate, st.gol, st.n, st.presto, st.peggiore])
		check(st.n >= 12, "abbastanza tiri in porta (%d)" % st.n)
		eq(st.presto, 0, "da %d m nessun tuffo a vuoto troppo presto" % dist)
		check(st.parate >= int(st.n * 0.7), "da %d m il portiere para quasi tutto (%d/%d)" % [dist, st.parate, st.n])
	return done()


# tiri a giro e rasoterra della persona da 25-45 m contro il portiere della CPU
func test_tiro_a_giro_da_lontano_il_portiere_cpu_aspetta() -> bool:
	for c: Array in [[35.0, {"tratto": true, "curve": 6.0}, 1.8], [45.0, {"tratto": true, "curve": 8.0}, 1.5], [35.0, {"tratto": true, "curve": 0.0}, 0.0]]:
		var st := _conta_lontano(1, c[1], c[2], c[0], false, false)
		note("da %d m %s, portiere CPU: parate %d gol %d su %d, tuffi a vuoto %d (peggiore %.2f s)" % [c[0], str(c[1]), st.parate, st.gol, st.n, st.presto, st.peggiore])
		check(st.n >= 8, "abbastanza tiri in porta (%d)" % st.n)
		eq(st.presto, 0, "nessun tuffo a vuoto troppo presto")
	return done()


# portiere manuale col fermatempo scaduto (fa da solo): stessa regola
func test_tiro_da_lontano_manuale_scaduto() -> bool:
	var st := _conta_lontano(0, {}, 1.2, 38.0, false, true)
	note("da 38 m, manuale scaduto: parate %d gol %d su %d, tuffi a vuoto %d (peggiore %.2f s)" % [st.parate, st.gol, st.n, st.presto, st.peggiore])
	eq(st.presto, 0, "nessun tuffo a vuoto troppo presto")
	return done()


# da vicino non cambia niente: i tiri forti all'angolo restano spesso gol
func test_da_vicino_i_tiri_angolati_restano_gol() -> bool:
	var gol := 0
	var n := 0
	for sd in range(1, 31):
		var tx: float = [-3.3, -3.0, 3.0, 3.3][sd % 4]
		var a := tiro(sd, 0, float(sd % 3 - 1) * 3.0, 14.0 + float(sd % 3) * 2.0, tx, [0.4, 1.8][sd % 2], {}, true)
		var m: SimMatchScript = a[0]
		var s: R.Shot = m.ball.shot
		if s == null or not s.on:
			continue
		n += 1
		if segui(m, a[2]).esito == "gol":
			gol += 1
	note("da 14-18 m all'angolo, nostro automatico: gol %d/%d" % [gol, n])
	check(n >= 15, "abbastanza tiri in porta (%d)" % n)
	check(gol >= int(n * 0.3), "tiri forti e angolati da vicino restano gol (%d/%d)" % [gol, n])
	return done()


# lancio alto della CPU da 38 m che finirebbe verso la porta (rilevato come tiro): il nostro portiere automatico non si
# tuffa finché mancano più di PARA_DIVE_WIN all'arrivo (prima lo faceva fino a 2 s prima e restava a terra)
func test_lancio_lungo_niente_tuffo_anticipato() -> bool:
	var visti := 0
	var sd := 0
	# lanci da 30-40 m, dal centro o dalle fasce, con punto di caduta tra 2 e 20 m dalla porta: si provano quelli che dopo
	# il rimbalzo vanno verso la porta (rilevati come tiro)
	for kx: float in [0.0, 12.0, -20.0]:
		for dist: float in [30.0, 40.0]:
			for fy: float in [2.0, 5.0, 8.0, 11.0, 14.0, 17.0, 20.0]:
				for fx: float in [-2.0, 2.0]:
					sd += 1
					var m := H.scene(sd, [true, false])
					m.paraCtl = true
					m.rifiniture = true
					m.paraSeed = sd
					m.autoGk = [true, false]
					for p: R.Player in m.players:
						H.wake(p, (p.i % 11 - 5) * 5.0, 30.0 + p.team * 2.0)
					var k: R.Player = m.team(1)[9]
					H.wake(k, kx, -C.HL + dist)
					k.fx = 0.0
					k.fy = -1.0
					var g := m.gk(0)
					H.wake(g, 0.0, -C.HL + 0.6)
					H.give(m, k)
					m.kick(k, {"type": "loft", "tx": fx, "ty": -C.HL + fy})
					m.events.clear()
					if m.ball.shot == null:
						continue
					visti += 1
					for i in 300:
						m.step(DT)
						var e: Variant = findEvent(m.events, "dive", func(ev: Dictionary) -> bool: return ev.p == g)
						m.events.clear()
						if e != null:
							check(m.paraLeft() <= ParataScript.PARA_DIVE_WIN + 0.05, "lancio da (%d, %d m) a %d m: tuffo quando al pallone mancano %.2f s" % [kx, dist, fy, m.paraLeft()])
							break
						if m.phase != "play" or m.ball.owner != null or m.ball.shot == null:
							break
	note("lanci lunghi rilevati come tiro: %d su %d" % [visti, sd])
	check(visti >= 4, "abbastanza lanci verso la porta (%d)" % visti)
	return done()
