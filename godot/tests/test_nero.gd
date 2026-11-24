# "Tutto nero" (Luis 2026-11-24, iPhone, calcio d'angolo della CPU al 49'): il pallone si è fermato nel fondo della
# rete (riprese.gd lo spinge a HL + NET_D + NET_OUT, ancora dentro HL + NET_Y), la meta del raccattapalle restava dentro
# il rettangolo della rete, lui arrivava al punto di giro dietro la rete e il passo divideva per 0: raccattapalle NaN,
# poi pallone NaN tra le sue mani, poi cx/cy della telecamera NaN per sempre (scena 3D nera, HUD e minimappa a posto).
# Trovato con tools/controllo_telecamera.gd: seme 101, fotogramma 6278 (20', angolo della squadra 1 a y = −49,4,
# pallone fermo a (0,70, −52,12)); stesso caso col seme 105 al 27'.
extends "test_base.gd"

const Telecamera := preload("res://scripts/partita/telecamera_partita.gd")


func partita() -> SimMatchScript:
	var m := H.newMatch(3, 9999.0, [false, false], H.mkTeam("A", 65.0, 22), H.mkTeam("B", 65.0, 44), "", {"riprese": true})
	H.run(m, 2.0)
	return m


func finito(bb: R.Raccatta) -> bool:
	return is_finite(bb.x) and is_finite(bb.y) and is_finite(bb.fx) and is_finite(bb.fy)


func test_meta_del_raccattapalle_mai_dentro_la_rete() -> bool:
	var m := partita()
	var bx: float = m.NET_X + m.NET_PATH
	var fondo: float = C.HL + m.NET_Y + m.NET_PATH
	var dentro := 0
	for k in 2:
		var bb: R.Raccatta = m.raccatte[k]
		var s: float = C.sign_(bb.hy)
		for i in 41:
			for j in 31:
				m.ball.x = -6.0 + i * 0.3
				m.ball.y = s * (C.HL - 1.0 + j * 0.15)
				var t: Vector2 = m.raccattaMeta(bb)
				if absf(t.x) < bx and t.y * s > C.HL and t.y * s < fondo:
					dentro += 1
	eq(dentro, 0, "mete dentro il rettangolo della rete")
	m.dispose()
	return done()


func test_raccattapalle_sul_punto_di_giro_resta_finito() -> bool:
	# il caso del 49': fermo esatto sul punto di giro dietro la rete, meta (vecchia) dentro la rete
	var m := partita()
	var bb: R.Raccatta = m.raccatte[0]
	var via := Vector2(m.NET_X + m.NET_PATH + m.BB_NET_OUT, -(C.HL + m.NET_Y + m.NET_PATH + m.BB_NET_OUT))
	bb.x = via.x
	bb.y = via.y
	m._bbMuovi(bb, 1.2, -(C.HL + m.BB_MIN_OUT), m.BB_RUN, DT)
	check(finito(bb), "posizione finita (%s, %s)" % [bb.x, bb.y])
	m.dispose()
	return done()


func test_pallone_nel_fondo_della_rete_sull_angolo() -> bool:
	# pallone fermo nel fondo della rete durante la scena dell'angolo (come al 49'): il raccattapalle lo prende e lo
	# rimanda, sempre con posizione finita, e il pallone resta finito
	var m := partita()
	m.phase = "play"
	m.restart = null
	var b := m.ball
	b.owner = null
	b.kick = null
	b.shot = null
	b.x = 1.3
	b.y = -(C.HL - 1.0)
	b.h = 3.4
	b.vx = -1.0
	b.vy = -4.3
	b.vh = 0.0
	b.last = m.team(0)[5] # l'ultimo tocco è della squadra che difende quella porta: angolo per la squadra 1
	m.events.clear()
	var bb: R.Raccatta = m.raccatte[0]
	var sempre_finito := true
	var lancio := false
	var angolo := false
	var nel_fondo := false
	for i in 60 * 14:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "ballboy":
				lancio = true
		m.events.clear()
		if m.phase == "restart" and m.restart != null and m.restart.type == "corner":
			angolo = true
		if absf(b.x) < C.GW / 2.0 and absf(b.y) > C.HL + 1.5 and absf(b.y) < C.HL + m.NET_Y and b.h < 0.3:
			nel_fondo = true
		if not (finito(bb) and is_finite(b.x) and is_finite(b.y) and is_finite(b.h)):
			sempre_finito = false
			break
	check(angolo, "calcio d'angolo")
	check(nel_fondo, "il pallone si ferma nel fondo della rete")
	check(sempre_finito, "raccattapalle e pallone sempre finiti")
	check(lancio, "il raccattapalle rimanda il pallone")
	m.dispose()
	return done()


func test_raccattapalle_non_finito_torna_a_casa() -> bool:
	var m := partita()
	var bb: R.Raccatta = m.raccatte[1]
	bb.x = NAN
	bb.y = NAN
	m.raccattaStep(DT)
	check(finito(bb), "sicurezza: torna finito")
	near(bb.y, bb.hy, 0.01, "al suo posto")
	m.dispose()
	return done()


func test_posa_valida() -> bool:
	var ok := {"pos": Vector3(0, 10, -20), "look": Vector3(0, 0, 0), "fov": 70.0}
	check(Telecamera.posa_valida(ok), "posa normale valida")
	check(not Telecamera.posa_valida({"pos": Vector3(NAN, 10, -20), "look": Vector3.ZERO, "fov": 70.0}), "NaN non valida")
	check(not Telecamera.posa_valida({"pos": Vector3(0, 10, 0), "look": Vector3(0, 0, 0), "fov": 70.0}), "punto guardato sotto la telecamera: non valida")
	check(not Telecamera.posa_valida({"pos": Vector3(0, 10, -20), "look": Vector3.ZERO, "fov": INF}), "campo visivo infinito non valido")
	return done()


func test_telecamera_non_resta_nera_dopo_un_pallone_nan() -> bool:
	# un fotogramma col pallone NaN (prima della correzione: raccattapalle NaN) non deve lasciare la telecamera NaN
	var cam: Camera3D = Telecamera.new() # fuori dall'albero: schermo dell'iPhone in verticale
	var m := partita()
	var b := m.ball
	cam.reset(b.x, b.y)
	for i in 30:
		cam.aggiorna(m, 0, DT, DT, false, false, 0.0)
	var x := b.x
	b.x = NAN
	b.y = NAN
	for i in 5:
		cam.aggiorna(m, 0, DT, DT, false, false, NAN)
	check(cam.transform.origin.is_finite() and cam.transform.basis.is_finite(), "col pallone NaN la telecamera resta finita")
	b.x = x
	b.y = 0.0
	for i in 30:
		cam.aggiorna(m, 0, DT, DT, false, false, 0.0)
	var t := cam.transform
	check(t.origin.is_finite() and t.basis.is_finite(), "poi la telecamera è finita")
	check(is_finite(cam.cx) and is_finite(cam.cy), "punto seguito finito")
	check(absf(t.basis.determinant()) > 0.5, "base della telecamera non degenere")
	# stato inseguito NaN (visuale dell'angolo): si butta e si torna alla posa normale
	cam._corner_p = {"pos": Vector3(NAN, NAN, NAN), "look": Vector3.ZERO, "fov": 70.0}
	cam._corn_k = 1.0
	cam.aggiorna(m, 0, DT, DT, false, false, 0.0)
	check(cam.transform.origin.is_finite(), "visuale dell'angolo NaN scartata")
	check(cam._corner_p == null, "stato inseguito dell'angolo buttato")
	cam.free()
	m.dispose()
	return done()
