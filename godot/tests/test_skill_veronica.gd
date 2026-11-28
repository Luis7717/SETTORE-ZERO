# Giochetto "Veronica" (roulette, scripts/partita/mosse/skill/veronica.gd), solo grafica: giro continuo senza pause e a
# velocità vera, piedi che appoggiano davvero durante il giro, le due suole sul pallone, schiena al difensore col
# pallone coperto dal corpo, uscita di corsa dal lato scelto.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")
const SCALA := Vector3(1.25, 1.25, 1.25)


# motore e coreografia insieme come vista.gd; lato = lato forzato (0 = quello del motore). Ritorna i campioni di ogni
# passo del portatore: {t, go (s dallo scatto, <0 prima), pos, vel, yaw, moto (verso del motore), piedi, palla, dif,
# bacino (mondo), dentro}
static func traccia(sd: int, lato: float = 0.0) -> Array:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = "veronica"
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	if lato != 0.0 and m.duel != null:
		m.duel.side = lato
	var cp: Coreo = null
	var co: Coreo = null
	var out: Array = []
	var t_go := INF
	var side := 0.0
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble":
				if not e.ok:
					m.dispose()
					return []
				side = float(e.side)
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				co = Coreo.new(o, 1.0, SCALA, TC.caviglie(o), bv, Vector3.ZERO)
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				co.ostacolo = func() -> Vector3: return Vector3(p.x, 0.0, -p.y)
				CD.portatore(cp, String(e.skill), side, float(e.show))
				CD.difensore_vuoto(co, side, float(e.show), func() -> Vector3: return cp.pallone(), String(e.skill))
			elif e.type == "dribble_go" and cp != null:
				t_go = cp.t
				CD.portatore_go(cp)
				CD.difensore_go(co)
		m.events.clear()
		if cp == null:
			continue
		for c: Coreo in [cp, co]:
			if not c.finito:
				c.passo(DT, p if c == cp else o, m.ball)
		if cp.finito:
			break
		var N := TC.figura(cp, p)
		var attivo := cp.pallone_attivo()
		var pb := cp.pallone() if attivo else Vector3(m.ball.x, 0.0, -m.ball.y)
		var fr := cp.frame(N, pb, 0.0)
		var dentro := 0.0
		if not co.finito:
			var No := TC.figura(co, o)
			dentro = Coreo.compenetrazione(Coreo.segmenti(N, fr), Coreo.segmenti(No, co.frame(No, pb, 0.0)))
		out.append({"t": cp.t, "go": cp.t - t_go if t_go < INF else -1.0, "pos": Vector3(p.x, 0.0, -p.y),
			"vel": Vector3(p.vx, 0.0, -p.vy), "yaw": cp.yaw, "moto": cp.yaw_motore(), "piedi": cp.piedi(), "palla": pb,
			"palla_moto": Vector3(m.ball.x, 0.0, -m.ball.y), "attivo": attivo, "dif": Vector3(o.x, 0.0, -o.y),
			"bacino": N * (fr.pelvis.p as Vector3), "dentro": dentro, "side": side, "peso": cp.peso, "fine": cp.fine,
			"cav_l": N * (fr.legs.l.ankle as Vector3), "cav_r": N * (fr.legs.r.ankle as Vector3)})
	m.dispose()
	return out


# misure del giro su una traccia: giro totale (rad, nel verso del giro), velocità massima e minima del giro (rad/s, su
# finestre di 0,1 s tra 20° e 330°), giro all'indietro più grande (rad), appoggi dei piedi durante il giro
static func misura(tr: Array) -> Dictionary:
	var G: float = -float(tr[0].side)
	var tot := 0.0
	var yp: float = tr[0].yaw
	var giri: Array = []
	var indietro := 0.0
	var appoggi := {"l": 0, "r": 0}
	var prima := {"l": true, "r": true}
	for c: Dictionary in tr:
		var d := wrapf(float(c.yaw) - yp, -PI, PI) * G
		yp = c.yaw
		tot += d
		indietro = maxf(indietro, -d)
		giri.append(tot)
		for s: String in ["l", "r"]:
			var terra: bool = c.piedi[s].terra
			if terra and not prima[s] and tot > 0.3 and tot < TAU - 0.5:
				appoggi[s] += 1
			prima[s] = terra
	var w_max := 0.0
	var w_min := INF
	for i in range(6, giri.size()):
		var w: float = (float(giri[i]) - float(giri[i - 6])) / (6.0 * DT)
		if float(giri[i - 6]) > deg_to_rad(20.0) and float(giri[i]) < deg_to_rad(330.0):
			w_max = maxf(w_max, w)
			w_min = minf(w_min, w)
	return {"tot": tot, "w_max": w_max, "w_min": w_min, "indietro": indietro, "appoggi": appoggi, "giri": giri}


# Luis 2026-11-26: "si ferma, rotea in modo innaturale e prosegue": un giro solo, continuo, a velocità vera
func test_giro_intero_continuo_senza_pause() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(TD.first_ok_seed(), lato)
		check(not tr.is_empty(), "dribbling riuscito")
		var m := misura(tr)
		note("lato %+d: giro %.0f gradi, velocità del giro da %.1f a %.1f rad/s" % [int(lato), rad_to_deg(m.tot), m.w_min, m.w_max])
		check(m.tot > deg_to_rad(320.0) and m.tot < deg_to_rad(400.0), "un giro intero (%.0f gradi)" % rad_to_deg(m.tot))
		check(m.indietro < 0.02, "sempre nello stesso verso")
		check(m.w_min > 6.0, "nessuna pausa nel giro (minimo %.1f rad/s)" % m.w_min)
		check(m.w_max < 11.0, "non una trottola (massimo %.1f rad/s)" % m.w_max)
	return done()


func test_i_piedi_appoggiano_davvero_durante_il_giro() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(TD.first_ok_seed(), lato)
		var m := misura(tr)
		var n: int = int(m.appoggi.l) + int(m.appoggi.r)
		check(n >= 3, "almeno tre appoggi durante il giro (%d)" % n)
		# un piede appoggiato resta fermo sul prato
		var salto := 0.0
		var prima := {}
		for c: Dictionary in tr:
			for s: String in ["l", "r"]:
				if c.piedi[s].terra and prima.has(s) and prima[s].terra:
					salto = maxf(salto, (c.piedi[s].pos as Vector3).distance_to(prima[s].pos))
			prima = c.piedi
		check(salto < 0.01, "i piedi a terra non scivolano (%.3f m)" % salto)
	return done()


# la prima suola frena il pallone: resta quasi fermo sul prato mentre il corpo gli passa accanto; a metà giro (schiena
# al difensore) il pallone è dietro il corpo, più lontano dal difensore del portatore
func test_pallone_frenato_e_coperto_dal_corpo() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(TD.first_ok_seed(), lato)
		var m := misura(tr)
		var coperto := 0
		var meta := 0
		var palla_strada := 0.0
		var corpo_strada := 0.0
		for i in range(1, tr.size()):
			var c: Dictionary = tr[i]
			var g: float = m.giri[i]
			if g > deg_to_rad(60.0) and g < deg_to_rad(150.0):
				palla_strada += (c.palla as Vector3).distance_to(tr[i - 1].palla)
				corpo_strada += (c.pos as Vector3).distance_to(tr[i - 1].pos)
			if g > deg_to_rad(150.0) and g < deg_to_rad(210.0):
				meta += 1
				if (c.palla as Vector3).distance_to(c.dif) > (c.pos as Vector3).distance_to(c.dif):
					coperto += 1
		note("lato %+d: tra 60 e 150 gradi il pallone fa %.2f m, il corpo %.2f m" % [int(lato), palla_strada, corpo_strada])
		check(palla_strada < 0.6 * corpo_strada, "il pallone frenato dalla suola resta indietro")
		check(meta > 0 and coperto * 10 >= meta * 7, "a metà giro il corpo copre il pallone (%d su %d)" % [coperto, meta])
	return done()


func test_in_corsa_corpi_staccati_e_pallone_che_torna_al_motore() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(TD.first_ok_seed(), lato)
		var v_min := INF
		var dentro := 0.0
		var salto := 0.0
		for i in range(1, tr.size()):
			var c: Dictionary = tr[i]
			if c.t > 0.2:
				v_min = minf(v_min, (c.vel as Vector3).length())
			dentro = maxf(dentro, c.dentro)
			salto = maxf(salto, (c.palla as Vector3).distance_to(tr[i - 1].palla) / DT - (c.vel as Vector3).length())
		var u: Dictionary = tr.back()
		check(v_min >= 1.8, "non si ferma mai (minimo %.1f m/s)" % v_min)
		check(dentro <= 0.06, "corpi staccati (%.2f m)" % dentro)
		check(salto < 14.0, "il pallone non salta (%.1f m/s oltre il corpo)" % salto)
		check((u.palla as Vector3).distance_to(u.palla_moto) < 0.05, "alla fine il pallone è quello del motore")
	return done()
