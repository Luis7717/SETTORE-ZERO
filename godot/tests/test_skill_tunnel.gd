# Giochetto "Tunnel" (scripts/partita/mosse/skill/tunnel.gd), solo grafica. Luis 2026-11-26: "la palla che
# magneticamente torna al mio non va bene, deve essere naturale e lui va a prenderla"; "subito dopo il calcio la posa
# sembrava ferma e dritta". Qui: il pallone passa tra le caviglie del difensore, si allontana dal portatore e rallenta
# da solo; il portatore dopo il calcio parte di scatto (falcate vere, busto in avanti) e lo raggiunge lui.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TC := preload("test_coreo.gd")
const TD := preload("test_dribbling.gd")
const DOPO := 0.5              # s dopo il calcio in cui si guarda la partenza (il rallenty della regia dura 0,4 s)
const FALCATA_MIN := 0.6       # m: distanza tra le caviglie (lungo la corsa) che fa una falcata e non un passettino
const BUSTO_MIN := 20.0        # gradi: busto in avanti nella partenza
const FERMO_MAX := 0.1         # s: mai più di tanto coi due piedi a terra insieme dopo il calcio
const GAMBA_MIN := 0.2         # m: il pallone passa ad almeno tanto da ogni caviglia del difensore (raggio 0,16)


# motore e coreografie insieme come vista.gd; ritorna le misure del tunnel
static func gira(sd: int) -> Dictionary:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = "tunnel"
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	var cp: Coreo = null
	var co: Coreo = null
	var mis := {"go": false, "presa": false, "falcata": 0.0, "busto": 0.0, "fermo": 0.0, "bacino_min": INF,
		"stacco": 0.0, "v_palla_presa": 0.0, "v_port_presa": 0.0, "gamba_sx": INF, "gamba_dx": INF, "passato": false,
		"t_presa": 0.0, "v_port_min": INF, "ginocchio": 0.0, "centro": INF, "t_passa": 0.0}
	var t_go := INF
	var fermo := 0.0
	var dir := Vector3.ZERO     # verso del pallone lanciato (mondo delle figure)
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble" and e.ok:
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				co = Coreo.new(o, 1.0, TC.SCALA, TC.caviglie(o), bv, Vector3.ZERO)
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				co.ostacolo = func() -> Vector3: return Vector3(p.x, 0.0, -p.y)
				CD.portatore(cp, String(e.skill), float(e.side), float(e.show))
				CD.difensore_vuoto(co, float(e.side), float(e.show), func() -> Vector3: return cp.pallone(), String(e.skill))
			elif e.type == "dribble_go" and cp != null:
				mis.go = true
				t_go = cp.t
				CD.portatore_go(cp)
				CD.difensore_go(co)
			elif e.type == "dribble_presa":
				mis.presa = bool(e.ok)
				mis.t_presa = cp.t - t_go
				mis.v_port_presa = C.hyp(p.vx, p.vy)
		var fi: R.Ball = m.ball.finto
		if fi != null:
			mis.v_palla_presa = C.hyp(fi.vx, fi.vy)   # (l'ultima prima della presa)
		m.events.clear()
		if cp == null:
			continue
		for c: Coreo in [cp, co]:
			if not c.finito:
				c.passo(DT, p if c == cp else o, m.ball)
		if cp.finito:
			break
		var pb := cp.pallone()
		var pp := Vector3(p.x, 0.0, -p.y)
		var pd := cp.piedi()
		if not mis.go:
			# prima del calcio: quanto sale la caviglia del piede in volo (il ginocchio su)
			for sd2: String in pd:
				mis.ginocchio = maxf(mis.ginocchio, (pd[sd2].pos as Vector3).y)
			continue
		var dt_go: float = cp.t - t_go
		if fi != null:
			mis.stacco = maxf(mis.stacco, pb.distance_to(pp))
			if dir == Vector3.ZERO:
				dir = Vector3(fi.vx, 0.0, -fi.vy).normalized()
			# il pallone passa adesso sulla linea del difensore: dove stanno le sue caviglie rispetto alla linea
			var po := Vector3(o.x, 0.0, -o.y)
			if not mis.passato and (pb - po).dot(dir) >= 0.0 and not co.finito:
				mis.passato = true
				var lato := Vector3(dir.z, 0.0, -dir.x)
				var od := co.piedi()
				var a: float = ((od.l.pos as Vector3) - pb).dot(lato)
				var b: float = ((od.r.pos as Vector3) - pb).dot(lato)
				mis.centro = (po - pb).dot(lato)
				mis.t_passa = dt_go
				mis.gamba_sx = minf(a, b)
				mis.gamba_dx = maxf(a, b)
		if dt_go > DOPO or cp.t >= cp.fine:
			continue
		# la partenza dopo il calcio
		var v := Vector3(p.vx, 0.0, -p.vy)
		mis.v_port_min = minf(mis.v_port_min, v.length())
		if v.length() > 0.5:
			mis.falcata = maxf(mis.falcata, absf(((pd.l.pos as Vector3) - (pd.r.pos as Vector3)).dot(v.normalized())))
		fermo = fermo + DT if pd.l.terra and pd.r.terra else 0.0
		mis.fermo = maxf(mis.fermo, fermo)
		var N := TC.figura(cp, p)
		var fr := cp.frame(N, pb, cp.pallone_h())
		var su: Vector3 = (fr.rot.spine_03 as Quaternion) * Vector3.UP
		mis.busto = maxf(mis.busto, rad_to_deg(su.angle_to(Vector3.UP)))
		mis.bacino_min = minf(mis.bacino_min, (fr.pelvis.p as Vector3).y)
	m.dispose()
	return mis


func test_il_pallone_passa_tra_le_gambe_e_il_portatore_lo_va_a_prendere() -> bool:
	# Arrange / Act
	var r := gira(TD.first_ok_seed())
	note("centro del difensore a %.2f m dalla linea, passa %.2f s dopo il calcio" % [r.centro, r.t_passa])
	note("stacco %.2f m, presa dopo %.2f s: pallone %.1f m/s, portatore %.1f m/s; caviglie del difensore a %.2f e %.2f m dalla linea" % [
		r.stacco, r.t_presa, r.v_palla_presa, r.v_port_presa, r.gamba_sx, r.gamba_dx])
	# Assert
	check(r.go, "scatto dopo il calcio")
	check(r.passato, "il pallone arriva oltre il difensore")
	# (dove stanno le caviglie del difensore lo decide coreo_dribbling.gd, stile "gambe": qui si misura soltanto, vedi
	# la nota; il pallone deve passare sotto di lui, vicino al suo centro)
	check(absf(r.centro) < 0.3, "il pallone passa sotto il difensore (a %.2f m dal suo centro)" % r.centro)
	if not (r.gamba_sx <= -GAMBA_MIN and r.gamba_dx >= GAMBA_MIN):
		note("ATTENZIONE: il pallone non passa in mezzo alle caviglie del difensore (servono almeno %.2f m per parte)" % GAMBA_MIN)
	check(r.stacco > 2.0, "il pallone si allontana dal portatore (%.2f m)" % r.stacco)
	check(r.presa, "il portatore lo riprende")
	check(r.v_port_presa > r.v_palla_presa + 1.0,
		"è il portatore che raggiunge il pallone: lui a %.1f m/s, il pallone a %.1f" % [r.v_port_presa, r.v_palla_presa])
	return done()


func test_dopo_il_calcio_parte_di_scatto_non_resta_fermo_e_dritto() -> bool:
	# Arrange / Act
	var r := gira(TD.first_ok_seed())
	note("falcata %.2f m, busto %.0f gradi, bacino %.2f, due piedi a terra insieme al massimo %.2f s, velocità minima %.1f m/s, caviglia su %.2f m prima del calcio" % [
		r.falcata, r.busto, r.bacino_min, r.fermo, r.v_port_min, r.ginocchio])
	# Assert
	check(r.falcata >= FALCATA_MIN, "falcate vere dopo il calcio (%.2f m tra le caviglie)" % r.falcata)
	check(r.busto >= BUSTO_MIN, "busto in avanti nella partenza (%.0f gradi)" % r.busto)
	check(r.bacino_min < 0.88, "bacino basso nella spinta (%.2f)" % r.bacino_min)
	check(r.fermo <= FERMO_MAX, "mai piantato su due piedi dopo il calcio (%.2f s)" % r.fermo)
	check(r.v_port_min >= 1.8, "non si ferma dopo il calcio (minimo %.1f m/s)" % r.v_port_min)
	check(r.ginocchio > 0.3, "prima del calcio il ginocchio sale (caviglia a %.2f m)" % r.ginocchio)
	return done()
