# Calci d'angolo e parate (Luis 2026-11-22): "la CPU segna al 100% dagli angoli perché il portiere esce" e
# "i portieri non tengono mai la palla". Il portiere esce sul cross solo se arriva prima degli attaccanti vicino alla
# porta (e lì vince il contrasto aereo quasi sempre), altrimenti resta tra i pali; i difensori della squadra umana vanno
# a colpire il cross di testa; sulle parate blocca i tiri lenti e centrali, respinge lontano e verso l'esterno gli altri.
# Numeri completi con: godot --headless --path godot -s res://tests/angoli.gd (e tests/parate.gd).
extends "test_base.gd"

const Lab := preload("corner_lab.gd")
const N_ANGOLI := 60
const GOL_MAX := 0.15      # gol da angolo: mai sopra il 15%


func test_angoli_della_cpu_contro_di_noi() -> bool:
	var r := Lab.misura({"n": N_ANGOLI, "seed": 3, "cpu_batte": true})
	note(Lab.riga("CPU batte", r))
	check(float(r.gol) / r.angoli <= GOL_MAX, "troppi gol da angolo: %d su %d" % [r.gol, r.angoli])
	eq(r.porta_vuota, 0, "gol a porta vuota")
	check(r.uscite_mancate <= 1, "uscite a vuoto del portiere: %d" % r.uscite_mancate)
	check(r.respinte_testa > r.teste, "i nostri difensori vanno di testa sul cross: respinte %d, teste attaccanti %d" % [r.respinte_testa, r.teste])
	return done()


func test_angoli_nostri_contro_la_cpu() -> bool:
	var r := Lab.misura({"n": N_ANGOLI, "seed": 5, "cpu_batte": false})
	note(Lab.riga("noi battiamo", r))
	check(float(r.gol) / r.angoli <= GOL_MAX, "troppi gol da angolo: %d su %d" % [r.gol, r.angoli])
	eq(r.porta_vuota, 0, "gol a porta vuota")
	return done()


# scena: solo il nostro portiere, il battitore della CPU sulla bandierina e (se c'è) un attaccante; cross verso (tx, ty)
func _cross(sd: int, tx: float, ty: float, att: Variant) -> Dictionary:
	var m := H.scene(sd, [true, false])
	var g: R.Player = m.gk(0)
	H.wake(g, 0.0, -C.HL + 0.6)
	var k: R.Player = m.players[11 + 7]
	H.wake(k, C.HW - 0.5, -C.HL + 0.5)
	k.fx = -1.0
	k.fy = 0.0
	var a: R.Player = null
	if att != null:
		a = m.players[11 + 9]
		H.wake(a, att.x, att.y)
	H.give(m, k)
	m.kick(k, {"type": "loft", "tx": tx, "ty": ty})
	var far := 0.0
	var evs: Array = []
	for i in 60 * 4:
		m.step(DT)
		if m.ball.kick != null and m.ball.kick.type == "loft":
			far = maxf(far, g.y + C.HL)
		evs.append_array(m.events)
		m.events.clear()
		if m.phase != "play":
			break
	return {"m": m, "g": g, "a": a, "far": far, "evs": evs}


func test_il_portiere_esce_e_prende_se_arriva_prima() -> bool:
	var prese := 0
	for sd in 10:
		var r := _cross(sd + 1, -1.0, -C.HL + 5.0, null)
		var g: R.Player = r.g
		if hasEvent(r.evs, "control", func(e: Dictionary) -> bool: return e.p == g):
			prese += 1
		check(not hasEvent(r.evs, "goal"), "seme %d: gol" % (sd + 1))
	note("cross in area piccola senza attaccanti: il portiere lo blocca %d volte su 10" % prese)
	check(prese >= 9, "prese %d su 10" % prese)
	return done()


func test_il_portiere_resta_in_porta_se_l_attaccante_arriva_prima() -> bool:
	for sd in 10:
		var r := _cross(sd + 1, 0.0, -C.HL + 10.0, Vector2(0.5, -C.HL + 10.0))
		check(r.far <= 2.0, "seme %d: il portiere è uscito di %.1f m con l'attaccante già sotto il pallone" % [sd + 1, r.far])
	return done()


func test_contrasto_aereo_col_portiere() -> bool:
	# attaccante e portiere sotto un pallone alto (2,5 m) nell'area piccola: di solito vince il portiere
	var gkWins := 0
	var n := 40
	for sd in n:
		var m := H.scene(sd + 1, [true, false])
		var g: R.Player = m.gk(0)
		H.wake(g, 0.0, -C.HL + 3.4)
		var a: R.Player = m.players[11 + 9]
		H.wake(a, 0.3, -C.HL + 4.4)
		var k: R.Player = m.players[11 + 7]
		var b := m.ball
		b.x = 0.15
		b.y = -C.HL + 4.2
		b.h = 2.5
		b.vx = 0.0
		b.vy = -1.0
		b.vh = 0.0
		b.kick = R.Kick.make(1, k, "loft", 1.0)
		m.contacts(DT)
		if b.owner == g or hasEvent(m.events, "punch"):
			gkWins += 1
	note("portiere contro attaccante sul pallone alto: vince il portiere %d volte su %d" % [gkWins, n])
	check(gkWins >= n * 0.55 and gkWins <= n * 0.95, "vittorie del portiere %d su %d" % [gkWins, n])
	return done()


func test_presa_o_respinta() -> bool:
	var m := H.scene(1, [true, false])
	var g: R.Player = m.gk(0)
	var lento: float = m.catchChance(g, 14.0, true, 1.0)
	var forte: float = m.catchChance(g, 30.0, true, 1.0)
	var angolato: float = m.catchChance(g, 30.0, false, 1.0)
	var alto: float = m.catchChance(g, 30.0, false, 2.3)
	note("presa: lento centrale %.2f, forte centrale %.2f, forte angolato %.2f, forte angolato alto %.2f" % [lento, forte, angolato, alto])
	check(lento >= 0.9, "tiro lento e centrale: si blocca")
	check(forte > angolato and angolato > alto, "più forte, angolato e alto = meno prese")
	check(angolato < 0.5, "tiro forte e angolato: di solito si respinge")
	var por := g.st.por
	g.st.por = por + 20
	check(m.catchChance(g, 30.0, false, 1.0) > angolato, "portiere più bravo, più prese")
	g.st.por = por
	return done()


func test_respinta_lontano_e_verso_l_esterno() -> bool:
	for sd in 30:
		var m := H.scene(sd + 1, [true, false])
		var g: R.Player = m.gk(0)
		H.wake(g, 1.0, -C.HL + 0.6)
		var b := m.ball
		b.x = 2.5
		b.y = -C.HL + 0.8
		b.h = 1.0
		b.vx = 0.0
		b.vy = -30.0
		b.vh = 0.0
		m.save(g, false)
		if b.owner != null or hasEvent(m.events, "save", func(e: Dictionary) -> bool: return e.get("out", false)):
			continue # presa o respinta in angolo
		check(b.vx > 0.0 and b.vy > 0.0, "seme %d: respinta verso la porta o verso il centro (%.1f, %.1f)" % [sd + 1, b.vx, b.vy])
		check(C.hyp(b.vx, b.vy) >= 8.0, "seme %d: respinta troppo debole" % (sd + 1))
	return done()


func test_percentuale_prese() -> bool:
	# tiri come nelle partite misurate con tests/parate.gd (su 100 parate: ~85 tiri forti a 30 m/s, ~15 lenti a 14-18 m/s;
	# ~30 vicino al corpo, ~15 sopra i 2 m), portieri da 60 a 75 di "por": indicativamente si blocca il 45-60%
	var m := H.scene(1, [true, false])
	var g: R.Player = m.gk(0)
	var n := 400
	var prese := 0
	for i in n:
		g.st.por = 60 + (i * 7) % 16
		var b := m.ball
		b.owner = null
		b.x = 0.0
		b.y = -C.HL + 0.8
		b.h = 2.3 if i % 7 == 0 else 0.8
		b.vx = 0.0
		b.vy = -(30.0 if i % 20 >= 3 else 16.0)
		b.vh = 0.0
		m.save(g, i % 10 < 3)
		if b.owner == g:
			prese += 1
		m.phase = "play"
		m.events.clear()
	var f := float(prese) / n
	note("prese %d su %d (%.0f%%)" % [prese, n, f * 100.0])
	check(f >= 0.4 and f <= 0.65, "prese %.0f%%" % (f * 100.0))
	return done()
