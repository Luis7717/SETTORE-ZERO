# Difesa sui calci d'angolo con l'opzione "rifiniture" (sim/angoli.gd, 2026-11-24: "la CPU segna troppo dagli angoli",
# obiettivo 3-8% degli angoli): marcatura degli attaccanti più pericolosi, contesa aerea un po' più larga e un po'
# favorevole a chi difende in area, portiere più deciso sotto il cross. Senza l'opzione il motore resta quello del JS.
# Numeri completi: godot --headless --path godot -s res://tools/banco_angoli.gd -- --angoli=100
extends "test_base.gd"

const Lab := preload("corner_lab.gd")
const N_ANGOLI := 60
const GOL_MAX := 0.10      # con la difesa nuova: gol da angolo della CPU al massimo il 10% (nel laboratorio)
const ATT := 11 + 9        # attaccante della CPU (squadra 1) usato nelle scene


# partita con l'angolo della CPU contro di noi appena assegnato (la CPU attacca verso -y)
func _angolo(sd: int, rif: bool) -> SimMatchScript:
	var m := H.newMatch(sd, 9999.0, [true, false], H.mkTeam("A", 60.0, sd * 7 + 1), H.mkTeam("B", 60.0, sd * 13 + 5), "", {"rifiniture": rif})
	m.phase = "play"
	m.setRestart("corner", 1, C.HW, -C.HL)
	m.events.clear()
	return m


func test_senza_rifiniture_niente_di_nuovo() -> bool:
	var m := _angolo(1, false)
	for i in 30:
		m.step(DT)
	check(m.cornerMarks.is_empty(), "marcature senza l'opzione")
	check(not m.cornerLive(), "angolo riconosciuto senza l'opzione")
	near(m.airDuelR(m.players[3]), 0.95, 1e-9, "raggio della contesa aerea")
	near(m.gkClaimBonus(m.gk(0)), 0.0, 1e-9, "bonus del portiere")
	return done()


func test_si_marca_l_attaccante_piu_pericoloso() -> bool:
	for sd in 6:
		var m := _angolo(sd + 1, true)
		# l'attaccante della CPU più vicino alla porta (non il battitore) diventa il più forte di testa: deve avere un marcatore
		var a: R.Player = null
		for q: R.Player in m.team(1):
			if q.pos != "P" and q != m.restart.taker and (a == null or C.hyp(q.x, q.y + C.HL) < C.hyp(a.x, a.y + C.HL)):
				a = q
		a.st.tes = 99
		m.cornerMarks.clear()
		m.step(DT)
		var marker: R.Player = null
		for k: int in m.cornerMarks:
			if m.players[m.cornerMarks[k]] == a:
				marker = m.players[k]
		check(marker != null and marker.team == 0, "seme %d: nessuno marca l'attaccante più bravo di testa" % (sd + 1))
		if marker == null:
			continue
		for i in 72: # 1,2 s di ripresa (l'angolo si batte dopo almeno 1,6 s)
			m.step(DT)
		check(m.phase == "restart", "seme %d: l'angolo è già stato battuto" % (sd + 1))
		var d: float = C.hyp(marker.x - a.x, marker.y - a.y)
		check(d < 2.0, "seme %d: il marcatore è a %.1f m dall'attaccante" % [sd + 1, d])
		check(C.hyp(marker.x, marker.y + C.HL) < C.hyp(a.x, a.y + C.HL), "seme %d: il marcatore non sta dal lato della porta" % (sd + 1))
	return done()


func test_sui_nostri_angoli_la_cpu_resta_a_zona() -> bool:
	# CORNER_MARK_CPU = false: i gol della persona da angolo restano come prima (misurati col banco)
	var m := H.newMatch(1, 9999.0, [true, false], H.mkTeam("A", 60.0, 8), H.mkTeam("B", 60.0, 18), "", {"rifiniture": true})
	m.phase = "play"
	m.setRestart("corner", 0, C.HW, C.HL)
	m.step(DT)
	check(m.cornerLive(), "angolo nostro non riconosciuto")
	check(m.cornerMarks.is_empty(), "la CPU marca a uomo sui nostri angoli")
	return done()


func test_la_marcatura_finisce_dopo_la_seconda_palla() -> bool:
	var m := _angolo(2, true)
	var battuto := false
	for i in 60 * 8:
		m.step(DT)
		if m.phase == "play":
			battuto = true
		if battuto and m.ball.kick == null:
			break
	check(battuto, "l'angolo non è stato battuto")
	m.step(DT)
	check(m.cornerKick == null and not m.cornerLive(), "cross ancora in volo")
	for i in int(60 * (m.CORNER_SECOND_T + 0.3)):
		m.step(DT)
	check(m.cornerMarks.is_empty(), "marcatura ancora attiva %.1f s dopo il cross" % (m.CORNER_SECOND_T + 0.3))
	return done()


# pallone alto del cross d'angolo in area: attaccante a 0,3 m, difensore a 1,3 m (oltre gli 0,95 m di prima)
func _contesa(sd: int, rif: bool) -> int:
	var m := H.scene(sd, [true, false])
	m.rifiniture = rif
	var a: R.Player = m.players[ATT]
	var d: R.Player = m.players[3]
	var k: R.Player = m.players[11 + 7]
	H.wake(a, 0.3, -C.HL + 8.0)
	H.wake(d, 0.0, -C.HL + 6.7)
	var b := m.ball
	b.x = 0.0
	b.y = -C.HL + 8.0
	b.h = 2.0
	b.kick = R.Kick.make(1, k, "loft", 1.0)
	m.cornerKick = b.kick
	var w: R.Player = m.aerialDuel(a)
	return 1 if w == d else 0


func test_contesa_aerea_piu_larga_sul_cross_dell_angolo() -> bool:
	var vinte := 0
	var prima := 0
	var n := 60
	for sd in n:
		vinte += _contesa(sd + 1, true)
		prima += _contesa(sd + 1, false)
	note("difensore a 1,3 m dal pallone sul cross d'angolo: vince %d contese su %d (senza l'opzione %d)" % [vinte, n, prima])
	eq(prima, 0, "senza l'opzione il difensore a 1,3 m non si contende il pallone")
	check(vinte >= n * 0.2 and vinte <= n * 0.6, "contese vinte dal difensore %d su %d" % [vinte, n])
	return done()


func test_portiere_piu_forte_sotto_il_cross_dell_angolo() -> bool:
	var m := H.scene(1, [true, false])
	m.rifiniture = true
	var k: R.Player = m.players[11 + 7]
	m.ball.kick = R.Kick.make(1, k, "loft", 1.0)
	near(m.gkClaimBonus(m.gk(0)), 0.0, 1e-9, "cross qualunque: niente bonus")
	m.cornerKick = m.ball.kick
	check(m.gkClaimBonus(m.gk(0)) > 0.0, "cross dell'angolo: bonus del portiere")
	return done()


func test_angoli_della_cpu_con_la_difesa_nuova() -> bool:
	var r := Lab.misura({"n": N_ANGOLI, "seed": 3, "cpu_batte": true, "rifiniture": true})
	note(Lab.riga("CPU batte (rifiniture)", r))
	check(float(r.gol) / r.angoli <= GOL_MAX, "troppi gol da angolo: %d su %d" % [r.gol, r.angoli])
	eq(r.porta_vuota, 0, "gol a porta vuota")
	check(r.uscite_mancate <= 2, "uscite a vuoto del portiere: %d" % r.uscite_mancate)
	return done()


# Nel laboratorio i nostri angoli li batte l'IA (cross a caso in area, spesso preso dal portiere): è solo un controllo
# che restino giocati. I numeri veri, col cross disegnato dalla persona simulata, li dà tools/banco_angoli.gd.
func test_i_nostri_angoli_restano_giocati() -> bool:
	var r := Lab.misura({"n": N_ANGOLI, "seed": 5, "cpu_batte": false, "rifiniture": true})
	note(Lab.riga("noi battiamo (rifiniture)", r))
	check(r.teste + r.gol >= 1, "nessun colpo di testa né gol dei nostri su %d angoli" % r.angoli)
	check(r.prese <= r.angoli / 4, "il portiere della CPU prende troppi cross: %d su %d" % [r.prese, r.angoli])
	eq(r.porta_vuota, 0, "gol a porta vuota")
	return done()
