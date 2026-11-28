# Giochetto "Ponte" (scripts/partita/mosse/skill/ponte.gd + sim/duel.gd dribPallaLancia con `palla_lato` di sim/skill.gd).
# Luis 2026-11-27: il portatore tocca il pallone da un lato del difensore e gli corre dall'altro lato, lo riprende dietro.
# Prima il pallone staccato rasoterra andava verso il centro del difensore (era un tunnel). Qui: il pallone passa accanto
# al difensore, fuori dalla sua portata, dal lato opposto a quello del portatore; i due si ritrovano dietro di lui.
# Niente numeri casuali nuovi, esito uguale; il tunnel (senza `palla_lato`) resta com'era.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const Skill := preload("../sim/skill.gd")
const TC := preload("test_coreo.gd")
const TD := preload("test_dribbling.gd")
const LATO_PALLA_MIN := 0.8    # m: il pallone passa ad almeno tanto dal centro del difensore ...
const CAVIGLIA_MIN := 0.3      # ... e ad almeno tanto da ogni sua caviglia (raggio del pallone 0,16: non lo tocca)
const LATO_PORT_MIN := 1.3     # m: il portatore gli passa ad almeno tanto, dall'altro lato
const CORPI_MIN := 1.2         # m: i due centri mai più vicini di così (figure grandi 1,25)
const DOPO := 0.5              # s dopo il tocco in cui si guarda la partenza


# motore e coreografie insieme come vista.gd; ritorna le misure. Lati rispetto alla corsa del portatore al momento del
# dribbling: positivo = lato scelto (da dove passa il portatore), negativo = lato del pallone
static func gira(sd: int, id: String = "ponte") -> Dictionary:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = id
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	var cp: Coreo = null
	var co: Coreo = null
	var mis := {"ok": false, "go": false, "presa": false, "lato_palla": INF, "lato_port": INF, "caviglia": INF,
		"corpi": INF, "t_presa": 0.0, "v_palla_presa": 0.0, "v_port_presa": 0.0, "stacco": 0.0, "v_port_min": INF,
		"palla_passa": false, "port_passa": false, "t_palla": 0.0, "t_port": 0.0, "dietro": 0.0, "fermo": 0.0,
		"busto": 0.0, "piede_largo": 0.0, "rng": 0, "lato_dif_fine": 0.0}
	var t_go := INF
	var fermo := 0.0
	var u := Vector2.ZERO       # verso della corsa (motore: x, y) e verso il lato scelto
	var n := Vector2.ZERO
	var side := 0.0
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble":
				mis.ok = bool(e.ok)
				mis.rng = m.rng.a
				if not e.ok:
					continue
				side = float(e.side)
				u = Vector2(o.x - p.x, o.y - p.y).normalized()
				n = Vector2(-u.y, u.x) * side
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				co = Coreo.new(o, 1.0, TC.SCALA, TC.caviglie(o), bv, Vector3.ZERO)
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				co.ostacolo = func() -> Vector3: return Vector3(p.x, 0.0, -p.y)
				CD.portatore(cp, String(e.skill), side, float(e.show))
				CD.difensore_vuoto(co, side, float(e.show), func() -> Vector3: return cp.pallone(), String(e.skill))
			elif e.type == "dribble_go" and cp != null:
				mis.go = true
				t_go = cp.t
				CD.portatore_go(cp)
				CD.difensore_go(co)
			elif e.type == "dribble_presa":
				mis.presa = bool(e.ok)
				mis.t_presa = cp.t - t_go
				mis.v_port_presa = C.hyp(p.vx, p.vy)
				mis.dietro = Vector2(p.x - o.x, p.y - o.y).dot(u)
				mis.lato_dif_fine = Vector2(p.x - o.x, p.y - o.y).dot(n)
		var fi: R.Ball = m.ball.finto
		if fi != null:
			mis.v_palla_presa = C.hyp(fi.vx, fi.vy)   # (l'ultima prima della presa)
		m.events.clear()
		if cp == null:
			continue
		for c: Coreo in [cp, co]:
			if not c.finito:
				c.passo(DT, p if c == cp else o, m.ball)
		if not mis.presa:   # (fino alla presa: poi è gioco normale, il difensore torna a contrastare)
			mis.corpi = minf(mis.corpi, C.hyp(p.x - o.x, p.y - o.y))
		var po := Vector2(o.x, o.y)
		if fi != null:
			var pf := Vector2(fi.x, fi.y)
			mis.stacco = maxf(mis.stacco, pf.distance_to(Vector2(p.x, p.y)))
			if not co.finito:
				var od := co.piedi()
				for k: String in ["l", "r"]:
					var a: Vector3 = od[k].pos
					mis.caviglia = minf(mis.caviglia, pf.distance_to(Vector2(a.x, -a.z)))
			if not mis.palla_passa and (pf - po).dot(u) >= 0.0:
				mis.palla_passa = true
				mis.lato_palla = (pf - po).dot(n)
				mis.t_palla = cp.t - t_go
		if mis.go and not mis.port_passa and (Vector2(p.x, p.y) - po).dot(u) >= 0.0:
			mis.port_passa = true
			mis.lato_port = (Vector2(p.x, p.y) - po).dot(n)
			mis.t_port = cp.t - t_go
		if cp.finito or not mis.go:
			continue
		var dt_go: float = cp.t - t_go
		if dt_go > DOPO or cp.t >= cp.fine:
			continue
		# la partenza dopo il tocco
		var pd := cp.piedi()
		mis.v_port_min = minf(mis.v_port_min, C.hyp(p.vx, p.vy))
		fermo = fermo + DT if pd.l.terra and pd.r.terra else 0.0
		mis.fermo = maxf(mis.fermo, fermo)
		var N := TC.figura(cp, p)
		var fr := cp.frame(N, cp.pallone(), cp.pallone_h())
		var su: Vector3 = (fr.rot.spine_03 as Quaternion) * Vector3.UP
		mis.busto = maxf(mis.busto, rad_to_deg(su.angle_to(Vector3.UP)))
	m.dispose()
	return mis


func test_il_pallone_passa_da_un_lato_del_difensore_e_il_portatore_dall_altro() -> bool:
	# Arrange / Act
	var r := gira(TD.first_ok_seed())
	note("pallone a %.2f m dal centro del difensore (%.2f s dopo il tocco), caviglia più vicina a %.2f m; portatore a %.2f m dall'altro lato (%.2f s); corpi mai sotto %.2f m" % [
		r.lato_palla, r.t_palla, r.caviglia, r.lato_port, r.t_port, r.corpi])
	note("stacco %.2f m, presa dopo %.2f s, %.2f m oltre il difensore: pallone %.1f m/s, portatore %.1f m/s" % [
		r.stacco, r.t_presa, r.dietro, r.v_palla_presa, r.v_port_presa])
	# Assert
	check(r.go, "scatto dopo il tocco")
	check(r.palla_passa and r.port_passa, "pallone e portatore arrivano oltre il difensore")
	check(r.lato_palla <= -LATO_PALLA_MIN, "il pallone passa accanto al difensore dal lato opposto (%.2f m dal centro)" % r.lato_palla)
	check(r.caviglia >= CAVIGLIA_MIN, "... fuori dalla sua portata: mai a meno di %.2f m da una sua caviglia (%.2f)" % [CAVIGLIA_MIN, r.caviglia])
	check(r.lato_port >= LATO_PORT_MIN, "il portatore passa dall'altro lato (%.2f m)" % r.lato_port)
	check(r.corpi >= CORPI_MIN, "i due corpi non si toccano (%.2f m)" % r.corpi)
	check(r.stacco > 2.0, "il pallone si allontana dal portatore (%.2f m)" % r.stacco)
	check(r.presa, "il portatore lo riprende")
	check(r.dietro > 1.0, "... dietro al difensore (%.2f m oltre)" % r.dietro)
	check(r.v_port_presa > r.v_palla_presa + 1.0,
		"è il portatore che raggiunge il pallone: lui a %.1f m/s, il pallone a %.1f" % [r.v_port_presa, r.v_palla_presa])
	return done()


func test_vale_per_tutti_e_due_i_lati_e_piu_semi() -> bool:
	var visti := 0
	var lati := {}
	for sd in range(1, 13):
		# Arrange / Act
		var r := gira(sd)
		if not r.ok:
			continue
		visti += 1
		lati[signf(r.lato_port)] = true
		# Assert
		check(r.presa, "seme %d: il portatore riprende il pallone" % sd)
		check(r.lato_palla <= -LATO_PALLA_MIN and r.lato_port >= LATO_PORT_MIN,
			"seme %d: pallone da un lato (%.2f m), portatore dall'altro (%.2f m)" % [sd, r.lato_palla, r.lato_port])
		check(r.caviglia >= CAVIGLIA_MIN, "seme %d: il pallone non tocca il difensore (caviglia a %.2f m)" % [sd, r.caviglia])
		check(r.corpi >= CORPI_MIN, "seme %d: corpi staccati (%.2f m)" % [sd, r.corpi])
	check(visti >= 4, "almeno 4 dribbling riusciti (visti %d)" % visti)
	return done()


func test_dopo_il_tocco_parte_di_scatto_dal_lato_scelto() -> bool:
	# Arrange / Act
	var r := gira(TD.first_ok_seed())
	note("busto %.0f gradi, due piedi a terra insieme al massimo %.2f s, velocità minima %.1f m/s" % [r.busto, r.fermo, r.v_port_min])
	# Assert
	check(r.busto >= 15.0, "busto in avanti nella partenza (%.0f gradi)" % r.busto)
	check(r.fermo <= 0.1, "mai piantato su due piedi dopo il tocco (%.2f s)" % r.fermo)
	check(r.v_port_min >= 1.8, "non si ferma dopo il tocco (minimo %.1f m/s)" % r.v_port_min)
	return done()


func test_esito_e_numeri_casuali_uguali_al_tunnel() -> bool:
	# stesso seme: col ponte o col tunnel l'esito è lo stesso e la sequenza dei numeri casuali è allo stesso punto
	for sd in range(1, 7):
		# Arrange / Act
		var a := TD.book_and_resolve(sd, true, "ponte")
		var b := TD.book_and_resolve(sd, true, "tunnel")
		var c := TD.book_and_resolve(sd, false, "")
		# Assert
		eq(bool(a[3].ok), bool(b[3].ok), "seme %d: stesso esito del tunnel" % sd)
		eq(bool(a[3].ok), bool(c[3].ok), "seme %d: stesso esito senza rifiniture" % sd)
		eq((a[0] as SimMatchScript).rng.a, (b[0] as SimMatchScript).rng.a, "seme %d: stessa sequenza del tunnel" % sd)
		eq((a[0] as SimMatchScript).rng.a, (c[0] as SimMatchScript).rng.a, "seme %d: stessa sequenza senza rifiniture" % sd)
		for r: Array in [a, b, c]:
			(r[0] as SimMatchScript).dispose()
	return done()


func test_il_tunnel_senza_palla_lato_va_ancora_al_centro_del_difensore() -> bool:
	# Arrange / Act
	check(not Skill.trova("tunnel").has("palla_lato"), "il tunnel non ha `palla_lato`")
	check(float(Skill.trova("ponte").get("palla_lato", 0.0)) > 0.0, "il ponte sì")
	var r := gira(TD.first_ok_seed(), "tunnel")
	# Assert
	check(r.presa, "tunnel: il portatore riprende il pallone")
	check(absf(r.lato_palla) < 0.3, "tunnel: il pallone passa ancora sotto il difensore (%.2f m dal centro)" % r.lato_palla)
	return done()
