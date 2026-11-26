# Croqueta (scripts/partita/mosse/skill/croqueta.gd), solo grafica. Luis 2026-11-26: "non si capisce cosa cerchi di
# fare". Deve leggersi: due tocchi d'interno (piede della finta, poi l'altro), pallone che attraversa netto di lato
# verso il lato scelto, gambe larghe sulla ricezione, e dopo lo scatto il pallone resta dal lato scelto (non torna
# davanti al difensore).
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")

const LATO_MIN := 0.8          # m: il pallone si sposta di lato almeno tanto tra il primo tocco e lo scatto
const LARGHE_MIN := 0.75       # m: piedi distanti almeno tanto sulla ricezione
const V_LATO_MIN := 3.0        # m/s: il passaggio di lato è netto (velocità di traverso del pallone)
const DIF_MIN := 0.9           # m: dopo lo scatto il pallone passa almeno a tanto dal difensore


# motore e coreografia insieme (come vista.gd), col lato scelto fisso; misure nel riferimento della linea
# portatore → difensore all'inizio: `lato` = verso il lato scelto
static func misura(lato: float) -> Dictionary:
	var s := TD.setup(TD.first_ok_seed(), 6.5, 4.0, 0.6)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = "croqueta"
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 1
	var cp: Coreo = null
	var org := Vector3.ZERO
	var nn := Vector3.ZERO
	var prenotato := false
	var palla_prima := INF
	var rel_prima := INF
	var t_go := INF
	var mis := {"esito": null, "go": false, "palla_min": INF, "palla_max": -INF, "v_lato": 0.0, "larghe": 0.0,
		"dif_dopo": INF, "palla_go": 0.0, "corpo_go": 0.0, "indietro": 0.0, "v_min": INF}
	for i in 900:
		m.step(DT)
		if not prenotato and m.duelFor(0):
			m.userDribble(0)
			m.duel.side = lato
			prenotato = true
		for e: Dictionary in m.events:
			if e.type == "dribble":
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				mis.esito = e.ok
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				org = Vector3(p.x, 0.0, -p.y)
				var u := (Vector3(o.x, 0.0, -o.y) - org).normalized()
				nn = Basis(Vector3.UP, cp.yaw) * Vector3(1, 0, 0) * float(e.side)
				nn = (nn - u * nn.dot(u)).normalized()
				if e.ok:
					CD.portatore(cp, String(e.skill), float(e.side), float(e.show))
			elif e.type == "dribble_go" and cp != null:
				mis.go = true
				t_go = cp.t
				mis.palla_go = (cp.pallone() - org).dot(nn)
				mis.corpo_go = (Vector3(p.x, 0.0, -p.y) - org).dot(nn)
				CD.portatore_go(cp)
		m.events.clear()
		if cp == null or mis.esito != true:
			continue
		cp.passo(DT, p, m.ball)
		if cp.finito:
			break
		var pl := (cp.pallone() - org).dot(nn)
		if not mis.go:
			mis.palla_min = minf(mis.palla_min, pl)
			mis.palla_max = maxf(mis.palla_max, pl)
			if palla_prima != INF:
				mis.v_lato = maxf(mis.v_lato, (pl - palla_prima) / DT)
			var pd := cp.piedi()
			mis.larghe = maxf(mis.larghe, absf(((pd.l.pos as Vector3) - (pd.r.pos as Vector3)).dot(nn)))
			if cp.t > 0.2:
				mis.v_min = minf(mis.v_min, C.hyp(p.vx, p.vy))
		elif cp.t < t_go + 0.3:
			mis.dif_dopo = minf(mis.dif_dopo, Vector2(cp.pallone().x - o.x, cp.pallone().z + o.y).length())
			# quanto torna verso il lato vecchio rispetto al corpo (m/s): prima era un colpo di frusta (10 m/s)
			var rel := pl - (Vector3(p.x, 0.0, -p.y) - org).dot(nn)
			if rel_prima != INF:
				mis.indietro = maxf(mis.indietro, (rel_prima - rel) / DT)
			rel_prima = rel
		palla_prima = pl
	m.dispose()
	return mis


func test_due_tocchi_e_pallone_netto_di_lato() -> bool:
	for lato: float in [1.0, -1.0]:
		# Act
		var r := misura(lato)
		var nome := "lato %+d" % int(lato)
		# Assert
		eq(r.esito, true, nome + ": dribbling riuscito")
		check(r.go, nome + ": scatto dopo il giochetto")
		var corsa: float = r.palla_max - r.palla_min
		check(corsa >= LATO_MIN, nome + ": il pallone si sposta di lato di %.2f m" % corsa)
		check(r.v_lato >= V_LATO_MIN, nome + ": passaggio di lato netto (%.1f m/s)" % r.v_lato)
		check(r.palla_go - r.corpo_go >= 0.4, nome + ": allo scatto il pallone è dal lato scelto (%.2f m dal corpo)" % (r.palla_go - r.corpo_go))
	return done()


func test_gambe_larghe_sulla_ricezione() -> bool:
	for lato: float in [1.0, -1.0]:
		var r := misura(lato)
		check(r.larghe >= LARGHE_MIN, "lato %+d: piedi larghi %.2f m" % [int(lato), r.larghe])
	return done()


func test_dopo_lo_scatto_il_pallone_non_torna_davanti_al_difensore() -> bool:
	for lato: float in [1.0, -1.0]:
		var r := misura(lato)
		var nome := "lato %+d" % int(lato)
		check(r.dif_dopo >= DIF_MIN, nome + ": il pallone passa a %.2f m dal difensore" % r.dif_dopo)
		check(r.indietro <= 5.0, nome + ": il pallone non torna di colpo davanti al corpo (%.1f m/s)" % r.indietro)
	return done()


func test_arriva_in_corsa_e_corpi_staccati() -> bool:
	# Arrange / Act: le misure comuni di test_coreo.gd
	var r := TC.gira(TD.first_ok_seed(), true, "croqueta")
	# Assert
	eq(r.id, "croqueta", "giochetto del motore")
	check(r.v_min >= 1.8, "non si pianta: minimo %.1f m/s durante il giochetto" % r.v_min)
	check(r.salto_piede < 1e-4, "piede a terra fermo (%.4f m)" % r.salto_piede)
	check(r.salto_palla < TC.V_PALLA_MAX, "pallone senza salti (%.1f m/s)" % r.salto_palla)
	check(r.dentro <= TC.DENTRO_MAX, "corpi staccati (%.3f m)" % r.dentro)
	near(r.fine_palla, 0.0, 1e-3, "alla fine il pallone è quello del motore")
	return done()
