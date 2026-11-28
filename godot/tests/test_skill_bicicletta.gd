# Giochetto "Bicicletta" (scripts/partita/mosse/skill/bicicletta.gd), solo grafica: il portatore non si pianta, salta
# col pallone stretto tra i piedi, il pallone sale dietro il polpaccio e parte dal tacco dietro di lui; poi è quello
# staccato del motore (gravità vera) e il portatore lo va a riprendere di corsa.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const Skill := preload("../sim/skill.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")
const ID := "bicicletta"


# motore e coreografia del portatore insieme (come vista.gd); misure fino alla fine della coreografia
static func misura(sd: int) -> Dictionary:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = ID
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	var cp: Coreo = null
	var av := Vector3.ZERO        # verso della corsa all'inizio (mondo)
	var pS := "l"
	var mis := {"id": "", "volo_piedi": 0.0, "h_lancio": 0.0, "dietro_lancio": 0.0, "indietro": 0.0, "scende": 0.0,
		"piede_palla": 0.0, "tacco_palla": INF, "stacco_lancio": INF, "salto": 0.0, "v_min_b": INF, "appoggi_b": 0,
		"h_meta": 0.0, "lancio": false, "go": false}
	var palla_prima := Vector3.INF
	var h_prima := 0.0
	var bacino0 := NAN
	var t_go := INF
	var t_lancio := INF
	var terra_prima := {}
	var tk := float(Skill.trova(ID).tk)
	for i in 300:
		m.step(DT)
		var lanciato := false
		for e: Dictionary in m.events:
			if e.type == "dribble" and e.ok:
				mis.id = String(e.get("skill", ""))
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				av = Basis(Vector3.UP, cp.yaw) * Vector3(0, 0, 1)
				pS = "l" if float(e.side) > 0.0 else "r"
				CD.portatore(cp, ID, float(e.side), float(e.show))
			elif e.type == "dribble_palla":
				lanciato = true
			elif e.type == "dribble_go" and cp != null:
				mis.go = true
				t_go = cp.t
				CD.portatore_go(cp)
		m.events.clear()
		if cp == null:
			continue
		if cp.finito:
			break
		cp.passo(DT, p, m.ball)
		var pb := cp.pallone()
		var ph := cp.pallone_h()
		var corpo := Vector3(p.x, 0.0, -p.y)
		var pd := cp.piedi()
		var N := TC.figura(cp, p)
		var fr := cp.frame(N, pb, ph)
		var bac: float = (N * (fr.pelvis.p as Vector3)).y
		if is_nan(bacino0):
			bacino0 = bac
		if lanciato and not mis.lancio:
			mis.lancio = true
			t_lancio = cp.t
			mis.h_lancio = h_prima
			mis.dietro_lancio = (palla_prima - corpo).dot(av)
			# il pallone che si vede e quello del motore, quando parte
			var f: R.Ball = m.ball.finto
			mis.stacco_lancio = Vector3(palla_prima.x, h_prima, palla_prima.z).distance_to(Vector3(f.x, f.h, -f.y))
			var tacco: Vector3 = (pd[pS].pos as Vector3)
			mis.tacco_palla = tacco.distance_to(Vector3(palla_prima.x, h_prima + Coreo.PALLA_R, palla_prima.z))
		if not mis.lancio:
			if not pd.l.terra and not pd.r.terra and cp.t > 0.12:
				mis.volo_piedi += DT
			mis.salto = maxf(mis.salto, bac - bacino0)
			if palla_prima != Vector3.INF:
				mis.indietro = minf(mis.indietro, (pb - palla_prima).dot(av))
				mis.scende = minf(mis.scende, ph - h_prima)
			# a metà salita il piede dietro è sul pallone (lo porta lui)
			if ph > 0.1 and ph < 0.28:
				var pf: Vector3 = pd["r" if pS == "l" else "l"].pos
				mis.piede_palla = maxf(mis.piede_palla, pf.distance_to(Vector3(pb.x, ph + Coreo.PALLA_R, pb.z)))
				mis.h_meta = ph
		elif cp.t > t_go and cp.t < cp.fine:
			mis.v_min_b = minf(mis.v_min_b, C.hyp(p.vx, p.vy))
			for sd2: String in pd:
				if pd[sd2].terra and terra_prima.has(sd2) and not terra_prima[sd2]:
					mis.appoggi_b += 1
		for sd2: String in pd:
			terra_prima[sd2] = pd[sd2].terra
		palla_prima = pb
		h_prima = ph
	mis["t_lancio"] = t_lancio
	mis["tk"] = tk
	m.dispose()
	return mis


func test_saltello_col_pallone_tra_i_piedi_e_colpo_di_tacco_da_dietro() -> bool:
	# Arrange / Act
	var sd := TD.first_ok_seed()
	var r := misura(sd)
	note("volo %.2f s, salto %.2f m, lancio a %.2f m da terra e %.2f m dietro, stacco %.2f m, tacco-pallone %.2f m" %
		[r.volo_piedi, r.salto, r.h_lancio, -r.dietro_lancio, r.stacco_lancio, r.tacco_palla])
	# Assert
	eq(r.id, ID, "giochetto del motore")
	check(r.lancio and r.go, "il pallone parte e il portatore scatta")
	check(r.volo_piedi >= 0.12, "saltello: tutti e due i piedi in aria per %.2f s" % r.volo_piedi)
	check(r.salto >= 0.1, "saltello: il bacino sale di %.2f m" % r.salto)
	check(r.h_lancio >= 0.45, "il pallone parte già alto (%.2f m): l'ha portato su il polpaccio" % r.h_lancio)
	check(r.dietro_lancio < -0.1, "il pallone parte da dietro il corpo (%.2f m)" % r.dietro_lancio)
	check(r.tacco_palla < 0.4, "il tacco è sul pallone quando parte (caviglia a %.2f m dal centro)" % r.tacco_palla)
	check(r.stacco_lancio < 0.25, "il pallone del motore parte da dove lo ha il tacco (%.2f m)" % r.stacco_lancio)
	return done()


func test_il_pallone_sale_soltanto_e_non_torna_indietro() -> bool:
	var sd := TD.first_ok_seed()
	var r := misura(sd)
	note("passo indietro peggiore %.3f m, discesa peggiore %.3f m, piede dietro a %.2f m dal pallone a metà salita" %
		[r.indietro, r.scende, r.piede_palla])
	check(r.indietro > -0.012, "prima del tacco il pallone non torna indietro (%.3f m in un passo)" % r.indietro)
	check(r.scende > -0.01, "prima del tacco il pallone sale soltanto (%.3f m)" % r.scende)
	check(r.h_meta > 0.0 and r.piede_palla < 0.36, "a metà salita il piede dietro è sul pallone (%.2f m)" % r.piede_palla)
	return done()


func test_dopo_il_tacco_corre_a_riprenderlo() -> bool:
	var sd := TD.first_ok_seed()
	var r := misura(sd)
	var g: Dictionary = TC.gira(sd, true, ID)
	note("dopo lo scatto: velocità minima %.1f m/s, %d appoggi; strada fino alla presa %.1f m" % [r.v_min_b, r.appoggi_b, g.strada])
	check(r.v_min_b >= 1.8, "dopo il tacco non si pianta (minimo %.1f m/s)" % r.v_min_b)
	check(r.appoggi_b >= 2 and r.appoggi_b <= 5, "falcate di corsa, non passettini (%d appoggi)" % r.appoggi_b)
	check(g.presa, "il portatore riprende il pallone")
	check(g.alto > 2.5, "il pallone passa alto (%.2f m)" % g.alto)
	check(g.salto_piede < 1e-4, "piede a terra fermo (%.4f m)" % g.salto_piede)
	check(g.dentro <= TC.DENTRO_MAX, "i due corpi non si compenetrano (%.3f m)" % g.dentro)
	return done()
