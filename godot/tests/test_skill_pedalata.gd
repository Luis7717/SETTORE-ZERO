# Giochetto "Pedalata" (scripts/partita/mosse/skill/pedalata.gd), solo grafica: una serie di giri alternati del piede
# intorno al davanti del pallone MENTRE il portatore avanza di corsa, a gambe larghe e col busto che oscilla, senza mai
# toccare il pallone; poi l'esterno lo porta via dal lato scelto. E si distingue dal doppio passo (due giri, quasi fermo).
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")

const DAVANTI := 0.08      # m: il piede in volo conta "davanti al pallone" da tanto oltre il suo centro
const GIRI_MIN := 4        # giri del piede prima dello scatto
const LARGO_MIN := 0.75    # m: larghezza massima tra i piedi (di lato) durante la pedalata
const STRADA_MIN := 1.8    # m: strada fatta dal portatore durante la pedalata
const PALLA_LATO_MAX := 0.2 # m: il pallone resta davanti al corpo (di lato) finché non lo tocca l'esterno
const OSCILLA_MIN := 0.12  # m del modello: il bacino va di qua e di là almeno tanto


# fa andare motore e coreografia del portatore come vista.gd; misure fino allo scatto (e lato del pallone dopo)
static func misura(sd: int, id: String) -> Dictionary:
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
	var mis := {"ok": false, "go": false, "giri": [], "largo": 0.0, "strada": 0.0, "palla_lato": 0.0, "bacino_min": INF,
		"bacino_max": -INF, "side": 0.0, "palla_dopo": 0.0, "volo_alto": 0.0, "show": 0.0}
	var av := Vector3.ZERO
	var sx := Vector3.ZERO
	var p0 := Vector3.ZERO
	var b0 := Vector3.ZERO
	var davanti := {"l": false, "r": false}
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble":
				mis.ok = bool(e.ok)
				mis.side = float(e.side)
				mis.show = float(e.show)
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				av = Basis(Vector3.UP, cp.yaw) * Vector3(0, 0, 1)
				sx = Basis(Vector3.UP, cp.yaw) * Vector3(1, 0, 0)
				p0 = Vector3(p.x, 0.0, -p.y)
				b0 = bv
				if e.ok:
					CD.portatore(cp, String(e.skill), float(e.side), float(e.show))
			elif e.type == "dribble_go" and cp != null:
				mis.go = true
				var fatto := Vector3(p.x, 0.0, -p.y) - p0
				mis.strada = fatto.length()
				# di lato rispetto alla strada fatta durante i giri (il portatore arriva già un po' di traverso)
				var d := fatto.normalized()
				sx = (sx - d * sx.dot(d)).normalized()
				b0 = cp.pallone()
				CD.portatore_go(cp)
		m.events.clear()
		if cp == null:
			continue
		cp.passo(DT, p, m.ball)
		if cp.finito:
			break
		var pb := cp.pallone()
		if mis.go:
			mis.palla_dopo = maxf(mis.palla_dopo, (pb - b0).dot(sx) * float(mis.side))
			continue
		mis.palla_lato = maxf(mis.palla_lato, absf((pb - Vector3(p.x, 0.0, -p.y)).dot(sx)))
		var pd := cp.piedi()
		for sd2: String in pd:
			var f: Dictionary = pd[sd2]
			var ora: bool = (not f.terra) and ((f.pos as Vector3) - pb).dot(av) > DAVANTI
			if ora and not davanti[sd2]:
				(mis.giri as Array).append(sd2)
			if ora:
				mis.volo_alto = maxf(mis.volo_alto, (f.pos as Vector3).y)
			davanti[sd2] = ora
		mis.largo = maxf(mis.largo, absf(((pd.l.pos as Vector3) - (pd.r.pos as Vector3)).dot(sx)))
		var fr := cp.frame(TC.figura(cp, p), pb, 0.0)
		var bx: float = (fr.pelvis.p as Vector3).x
		mis.bacino_min = minf(mis.bacino_min, bx)
		mis.bacino_max = maxf(mis.bacino_max, bx)
	m.dispose()
	return mis


func test_serie_di_giri_alternati_intorno_al_pallone() -> bool:
	# Arrange / Act
	var r := misura(TD.first_ok_seed(), "pedalata")
	var giri: Array = r.giri
	# Assert
	check(r.ok and r.go, "pedalata riuscita e scatto arrivato")
	check(giri.size() >= GIRI_MIN, "almeno %d giri del piede davanti al pallone (%d: %s)" % [GIRI_MIN, giri.size(), str(giri)])
	for i in range(1, giri.size()):
		check(giri[i] != giri[i - 1], "giri alternati: un piede e poi l'altro (%s)" % str(giri))
	# l'ultimo giro è del piede della finta: l'esterno dell'altro porta via il pallone dal lato scelto
	var p_finta := "r" if float(r.side) > 0.0 else "l"
	check(not giri.is_empty() and giri.back() == p_finta, "l'ultimo giro è dalla parte della finta (%s)" % str(giri))
	check(r.volo_alto > 0.25, "il piede passa alto davanti al pallone (%.2f m)" % r.volo_alto)
	note("giri %s, piede alto %.2f m" % [str(giri), r.volo_alto])
	return done()


func test_in_corsa_gambe_larghe_e_busto_che_oscilla() -> bool:
	var r := misura(TD.first_ok_seed(), "pedalata")
	check(r.strada >= STRADA_MIN, "avanza mentre pedala (%.2f m in %.2f s)" % [r.strada, r.show])
	check(r.largo >= LARGO_MIN, "gambe larghe (%.2f m tra i piedi)" % r.largo)
	check(r.bacino_max >= OSCILLA_MIN * 0.5 and r.bacino_min <= -OSCILLA_MIN * 0.5 and r.bacino_max - r.bacino_min >= OSCILLA_MIN,
		"il corpo oscilla di qua e di là (bacino da %.2f a %.2f)" % [r.bacino_min, r.bacino_max])
	note("strada %.2f m, piedi larghi %.2f m, bacino da %.2f a %.2f" % [r.strada, r.largo, r.bacino_min, r.bacino_max])
	return done()


func test_il_pallone_resta_davanti_e_poi_esce_dal_lato_scelto() -> bool:
	var r := misura(TD.first_ok_seed(), "pedalata")
	check(r.palla_lato <= PALLA_LATO_MAX, "durante i giri il pallone non viene toccato: resta davanti al corpo (di lato %.2f m)" % r.palla_lato)
	check(r.palla_dopo > 0.3, "dopo lo scatto il pallone è dal lato scelto (%.2f m)" % r.palla_dopo)
	return done()


func test_si_distingue_dal_doppio_passo() -> bool:
	var sd := TD.first_ok_seed()
	var pe := misura(sd, "pedalata")
	var dp := misura(sd, "doppiopasso")
	check((pe.giri as Array).size() >= (dp.giri as Array).size() + 2,
		"più giri del doppio passo (%d contro %d)" % [(pe.giri as Array).size(), (dp.giri as Array).size()])
	check(pe.strada >= dp.strada * 1.5, "fa più strada del doppio passo (%.2f contro %.2f m)" % [pe.strada, dp.strada])
	note("pedalata: %d giri, %.2f m; doppio passo: %d giri, %.2f m" % [(pe.giri as Array).size(), pe.strada, (dp.giri as Array).size(), dp.strada])
	return done()


func test_misure_comuni_delle_coreografie() -> bool:
	var r := TC.gira(TD.first_ok_seed(), true, "pedalata")
	check(r.salto_piede < 1e-4, "piede a terra fermo (%.4f m)" % r.salto_piede)
	check(r.salto_palla < TC.V_PALLA_MAX, "pallone senza salti (%.1f m/s)" % r.salto_palla)
	check(r.dentro <= TC.DENTRO_MAX, "i due corpi non si compenetrano (%.3f m)" % r.dentro)
	check(r.v_min >= 3.0, "non si pianta: minimo %.1f m/s durante la pedalata" % r.v_min)
	near(r.fine_palla, 0.0, 1e-3, "alla fine il pallone è quello del motore")
	return done()
