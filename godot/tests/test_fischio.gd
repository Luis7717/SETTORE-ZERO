# Fischio di fine tempo (Luis 2026-11-25, opzione "rifiniture"): "fine primo tempo e fine partita non possono essere
# fischiati nell'ultimo quarto di campo avversario (sia per me che per l'avversario): bisogna poter finire l'azione".
# A tempo scaduto, col pallone in gioco entro FISCHIO_ZONA (25 m) da una delle due porte, il fischio aspetta finché
# il pallone esce dalla zona, il portiere lo tiene, il gioco si ferma (fuori, fallo, gol) o passano FISCHIO_MAX s.
extends "test_base.gd"


# tutti fermi lontano (H.scene); il portatore della squadra tm a 10 m dalla porta avversaria, tempo appena scaduto
func _scena(tm: int, rif := true, half := 1) -> Dictionary:
	var m := H.scene(5, [false, false])
	m.rifiniture = rif
	m.halfLen = 60.0
	m.half = half
	m.t = m.halfLen - 0.01
	var dir: float = -1.0 if tm else 1.0
	var p: R.Player = m.team(tm)[9]
	H.wake(p, 0.0, dir * 40.0)
	p.fx = 0.0
	p.fy = dir
	H.give(m, p)
	p.stun = 999.0 # resta fermo col pallone: l'azione resta nell'ultimo quarto
	return {"m": m, "p": p}


func _passi(m: SimMatchScript, sec: float) -> void:
	for i in int(round(sec * 60.0)):
		if m.phase == "half" or m.phase == "full":
			return
		m.step(DT)
		m.events.clear()


func test_niente_fischio_nell_ultimo_quarto() -> bool:
	for tm in 2:
		for half in [1, 2]:
			var s := _scena(tm, true, half)
			var m: SimMatchScript = s.m
			_passi(m, 3.0)
			eq(m.phase, "play", "squadra %d, tempo %d: col pallone a 10 m dalla porta il fischio aspetta" % [tm, half])
			check(m.fischioAtteso, "squadra %d, tempo %d: si sta lasciando finire l'azione" % [tm, half])
			check(m.t >= m.halfLen, "squadra %d: il tempo è scaduto" % tm)
			# il pallone esce dalla zona (portatore a centrocampo): fischio
			var p: R.Player = s.p
			var dir: float = -1.0 if tm else 1.0
			H.wake(p, 0.0, dir * 10.0)
			p.stun = 999.0
			H.give(m, p)
			_passi(m, 0.1)
			eq(m.phase, "half" if half == 1 else "full", "squadra %d, tempo %d: pallone fuori dalla zona = fischio" % [tm, half])
			check(not m.fischioAtteso, "squadra %d: finita l'attesa" % tm)
	return done()


func test_fuori_dalla_zona_fischio_subito() -> bool:
	for tm in 2:
		var s := _scena(tm)
		var m: SimMatchScript = s.m
		var p: R.Player = s.p
		H.wake(p, 0.0, (-1.0 if tm else 1.0) * 20.0) # a 30 m dalla porta: non è l'ultimo quarto
		p.stun = 999.0
		H.give(m, p)
		_passi(m, 0.1)
		eq(m.phase, "half", "squadra %d: a 30 m dalla porta si fischia subito" % tm)
	return done()


func test_anche_vicino_alla_propria_porta() -> bool:
	var s := _scena(0)
	var m: SimMatchScript = s.m
	var p: R.Player = s.p
	H.wake(p, 0.0, -40.0) # squadra 0 a 10 m dalla propria porta: l'avversario sta attaccando lì
	p.stun = 999.0
	H.give(m, p)
	_passi(m, 1.0)
	eq(m.phase, "play", "ultimo quarto della propria porta: il fischio aspetta")
	return done()


func test_gioco_fermo_e_portiere_finiscono_l_azione() -> bool:
	# pallone fuori dal campo: al gioco fermo si fischia
	var s := _scena(0)
	var m: SimMatchScript = s.m
	_passi(m, 0.5)
	eq(m.phase, "play", "prima: azione in corso")
	m.setRestart("goalkick", 1, 0.0, 44.0)
	_passi(m, 0.1)
	eq(m.phase, "half", "pallone fuori: fischio")
	# il portiere tiene il pallone: fischio
	var s2 := _scena(1)
	var m2: SimMatchScript = s2.m
	_passi(m2, 0.5)
	var g: R.Player = m2.gk(0)
	H.wake(g, 0.0, -45.0)
	g.stun = 999.0
	H.give(m2, g)
	_passi(m2, 0.1)
	eq(m2.phase, "half", "il portiere ha il pallone: fischio")
	return done()


func test_tetto_di_sicurezza() -> bool:
	var s := _scena(1)
	var m: SimMatchScript = s.m
	_passi(m, SimMatchScript.FISCHIO_MAX - 1.0)
	eq(m.phase, "play", "prima del tetto l'azione continua")
	_passi(m, 1.5)
	eq(m.phase, "half", "dopo %.0f s in più si fischia comunque" % SimMatchScript.FISCHIO_MAX)
	return done()


func test_senza_rifiniture_come_prima() -> bool:
	var s := _scena(0, false)
	var m: SimMatchScript = s.m
	_passi(m, 0.1)
	eq(m.phase, "half", "senza rifiniture il fischio arriva allo scadere")
	return done()


# dopo il fischio atteso l'intervallo e il secondo tempo vanno come sempre, e la partita finisce
func test_intervallo_e_secondo_tempo() -> bool:
	var s := _scena(0)
	var m: SimMatchScript = s.m
	_passi(m, 1.0)
	m.setRestart("goalkick", 1, 0.0, 44.0)
	_passi(m, 0.1)
	eq(m.phase, "half", "fine del primo tempo")
	m.startSecondHalf()
	eq(m.half, 2, "secondo tempo")
	eq(m.t, 0.0, "cronometro da capo")
	eq(m.phase, "restart", "calcio d'inizio")
	eq(m.minute(), 45, "minuto 45")
	m.t = m.halfLen - 0.01
	m.restart = null
	m.phase = "play"
	m.ball.owner = null
	m.ball.x = 0.0
	m.ball.y = 0.0
	_passi(m, 0.2)
	eq(m.phase, "full", "fine partita a centrocampo")
	eq(m.minute(), 90, "minuto 90")
	return done()
