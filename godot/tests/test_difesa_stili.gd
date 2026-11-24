# Fase difensiva con l'opzione "rifiniture" (sim/difesa.gd, 2026-11-24): portiere sul rinvio avversario, rientri
# degli esterni, marcatura a uomo per zona e ruolo, linea del fuorigioco alta che sale, secondo pressatore.
# Senza "rifiniture" tutto resta come prima (test_stili.gd, test_equivalence.gd).
extends "test_base.gd"

const Stili := preload("../sim/stili.gd")


# la squadra 1 ha il pallone in (cx, cy); difende la squadra 0 (formazione form, stile dif)
func _difesa(dif: Variant, cx: float, cy: float, rif: bool = true, form: String = "4-4-2") -> SimMatchScript:
	var m := H.newMatch(5, 9999.0, [false, false], H.mkTeam("A", 60, 36, form), H.mkTeam("B", 60, 70), "", {"rifiniture": rif})
	m.stD[0] = Stili.dif(dif)
	m.phase = "play"
	m.restart = null
	var c: R.Player = m.players[20]
	H.wake(c, cx, cy)
	c.fy = -1.0
	H.give(m, c)
	m.att = 1
	m.dtT = DT
	m.computeChasers()
	m.computeLines()
	return m


func test_portiere_resta_in_porta_sul_rinvio_avversario() -> bool:
	for rif: bool in [true, false]:
		var m := H.newMatch(4, 9999.0, [false, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2), "", {"rifiniture": rif})
		m.setRestart("goalkick", 0, 5.0, -C.HL)
		var g1: R.Player = m.gk(1)
		var fuori: float = C.HL - g1.y # la squadra 1 difende la porta in y = +HL
		if rif:
			check(fuori < 3.0, "con rifiniture il portiere avversario resta in porta (%.1f m)" % fuori)
			check(absf(g1.x) < 1.0, "al centro della porta")
		else:
			check(fuori > 15.0, "senza rifiniture come prima (%.1f m)" % fuori)
	return done()


func test_rientro_dei_quinti_e_delle_ali() -> bool:
	# 3-5-2: pallone vicino alla nostra area, il quinto sinistro (C, bx -0,85) rientra alla linea dei difensori
	var m := _difesa(null, -20.0, -35.0, true, "3-5-2")
	var q: R.Player = m.players[4]
	var d: R.Player = m.players[1]
	var yq: float = m.defAnchor(q)[1]
	var yd: float = m.defAnchor(d)[1]
	check(absf(yq - yd) < 2.0, "difesa a cinque: quinto %.1f, difensore %.1f" % [yq, yd])
	check(yq < m.anchor(q)[1] - 8.0, "il quinto è sceso rispetto al posto di prima")
	# pallone nella metà avversaria: niente rientro
	var lontano := _difesa(null, -20.0, 20.0, true, "3-5-2")
	near(lontano.defAnchor(lontano.players[4])[1], lontano.anchor(lontano.players[4])[1], 1e-9, "lontano dalla nostra area resta su")
	# 4-3-3: l'ala (A, bx -0,72) scende fino alla linea dei centrocampisti
	var m4 := _difesa(null, -20.0, -35.0, true, "4-3-3")
	var ala: R.Player = m4.players[8]
	var mez: R.Player = m4.players[5]
	check(absf(m4.defAnchor(ala)[1] - m4.defAnchor(mez)[1]) < 1.5, "l'ala è alla linea dei centrocampisti")
	# senza rifiniture come prima
	var vec := _difesa(null, -20.0, -35.0, false, "3-5-2")
	near(vec.defAnchor(vec.players[4])[1], vec.anchor(vec.players[4])[1], 1e-9, "senza rifiniture nessun rientro")
	return done()


func test_uomo_per_zona_e_ruolo_con_libero() -> bool:
	var m := _difesa("uomo", 0.0, 10.0)
	var mk: Dictionary = m.marks[0]
	var lib: int = int(m.libero[0])
	check(lib >= 0 and m.players[lib].pos == "D", "c'è un difensore libero")
	check(not mk.has(lib), "il libero non ha un uomo")
	var visti := {}
	for k: int in mk:
		var o: R.Player = m.players[mk[k]]
		check(o.team == 1 and o.pos != "P" and o.pos != "D", "nessuno marca un difensore avversario o il portiere")
		check(not visti.has(mk[k]), "nessun avversario marcato da due")
		visti[mk[k]] = true
		if o.pos == "A":
			eq(m.players[k].pos, "D", "le punte le marcano i difensori")
	eq(mk.size(), 6, "6 avversari da marcare (4 centrocampisti e 2 punte)")
	# posti: nessuno lontano dal proprio posto oltre UOMO_LEASH, difensori dietro la palla, libero il più arretrato
	var ylib: float = 0.0
	var ymin_d: float = 999.0
	for i in range(1, 9):
		var p: R.Player = m.players[i]
		if p == m.presser[0] or p == m.cover[0]:
			continue
		m.assign(p)
		var an := m.defAnchor(p)
		if i != lib:
			check(C.hyp(p.tx - an[0], p.ty - an[1]) <= Stili.UOMO_LEASH + 1e-6, "vicino al proprio posto (%d)" % i)
		if p.pos == "D":
			check(p.ty <= m.ball.y - Stili.UOMO_BEHIND_D + 1e-6, "difensore dietro la palla (%d)" % i)
			if i == lib:
				ylib = p.ty
			else:
				ymin_d = minf(ymin_d, p.ty)
	check(ylib < ymin_d, "il libero sta dietro gli altri difensori (%.1f < %.1f)" % [ylib, ymin_d])
	return done()


func test_uomo_riabbina_quando_gli_avversari_si_scambiano() -> bool:
	var m := _difesa("uomo", 0.0, 10.0)
	# i due centrocampisti esterni avversari entrano nella nostra metà, uno per fascia
	var a1: R.Player = m.players[16]
	var a2: R.Player = m.players[19]
	H.wake(a1, -20.0, -15.0)
	H.wake(a2, 20.0, -15.0)
	m.computeLines()
	var k1: int = -1
	for k: int in m.marks[0]:
		if m.marks[0][k] == 16:
			k1 = k
	check(k1 >= 0 and m.players[k1].bx < 0.0, "marcato da uno della sua fascia")
	# si scambiano di fascia: chi li marca si scambia l'uomo invece di attraversare il campo
	H.wake(a1, 20.0, -15.0)
	H.wake(a2, -20.0, -15.0)
	m.computeLines()
	eq(int(m.marks[0].get(k1, -1)), 19, "riabbinato per zona")
	return done()


func test_fuorigioco_linea_alta_che_sale() -> bool:
	var vec := _difesa("fuorigioco", 0.0, 10.0, false)
	var m := _difesa("fuorigioco", 0.0, 10.0)
	var l0: float = vec.offLineD[0]
	var l1: float = m.offLineD[0]
	check(l1 > l0 + 3.0, "linea più alta con rifiniture (%.1f → %.1f)" % [l0, l1])
	# il portatore torna indietro (verso la sua porta = verso +y): la linea sale di OFF_STEP_M
	var c: R.Player = m.ball.owner
	c.vy = 5.0
	m.computeLines()
	near(float(m.offLineD[0]), minf(l1 + Stili.OFF_STEP_M, m.ball.y - Stili.OFF_BALL_R), 1e-9, "la linea sale insieme")
	check(m.ball.y - float(m.offLineD[0]) >= Stili.OFF_BALL_R - 1e-9, "sempre dietro il pallone")
	# i difensori ci vanno di corsa
	var d: R.Player = null
	for i in range(1, 5):
		if m.players[i] != m.presser[0] and m.players[i] != m.cover[0]:
			d = m.players[i]
	m.assign(d)
	near(d.ty, float(m.offLineD[0]), 1e-9, "il difensore va sulla linea")
	check(d.sprint, "di corsa")
	return done()


func test_secondo_pressatore_chiude_la_linea() -> bool:
	var m := _difesa("pressing", 0.0, 10.0)
	var c: R.Player = m.ball.owner
	var p1: R.Player = m.presser[0]
	var p2: R.Player = m.presser2[0]
	check(p2 != null and p2 != p1, "c'è il secondo pressatore")
	# primo pressatore lontano: il secondo raddoppia sul portatore
	H.wake(p1, c.x + 8.0, c.y - 8.0)
	m.assign(p2)
	check(C.hyp(p2.tx - c.x, p2.ty - c.y) < 2.0, "raddoppio sul portatore")
	# primo pressatore addosso: il secondo si mette sulla linea verso il compagno più vicino
	H.wake(p1, c.x, c.y - 1.5)
	m.assign(p2)
	var q: R.Player = null
	var qd: float = 1e9
	for o: R.Player in m.players:
		if o.team == 1 and o != c and o.pos != "P" and C.hyp(o.x - c.x, o.y - c.y) < qd:
			qd = C.hyp(o.x - c.x, o.y - c.y)
			q = o
	var seg := C.segInfo(p2.tx, p2.ty, c.x, c.y, q.x, q.y)
	check(seg[0] < 0.01, "sulla linea portatore-compagno (%.2f m)" % seg[0])
	check(C.hyp(p2.tx - c.x, p2.ty - c.y) >= Stili.PRESS2_LANE_MIN - 1e-6, "non addosso al portatore")
	# esce prima: portatore a 20 m dalla metà campo nella sua metà
	var alto := _difesa("pressing", 0.0, 20.0)
	alto.assign(alto.presser2[0])
	check(C.hyp(alto.presser2[0].tx - alto.ball.x, alto.presser2[0].ty - alto.ball.y) < 2.0, "pressa già a 20 m nella metà avversaria")
	return done()


func test_tiro_non_stoppato_dal_compagno_davanti() -> bool:
	for rif: bool in [true, false]:
		var m := H.newMatch(6, 9999.0, [false, false], H.mkTeam("A", 60, 3), H.mkTeam("B", 60, 4), "", {"rifiniture": rif})
		m.phase = "play"
		m.restart = null
		var p: R.Player = m.players[9]
		var q: R.Player = m.players[10]
		H.wake(p, 0.0, 25.0)
		H.wake(q, 0.0, 25.6) # il compagno è proprio davanti, sulla linea del tiro
		p.fy = 1.0
		H.give(m, p)
		m.att = 0
		m.kick(p, {"type": "shot", "tx": 0.0, "ty": C.HL, "th": 0.5, "curve": 0.0})
		for i in 3:
			m.step(DT)
		if rif:
			check(m.ball.owner != q, "con rifiniture il compagno non stoppa il tiro")
		else:
			eq(m.ball.owner, q, "senza rifiniture come prima (il compagno lo stoppa)")
	return done()
