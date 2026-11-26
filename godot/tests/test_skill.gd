# Giochetti del dribbling della persona nel motore (sim/skill.gd, sim/duel.gd; solo con "rifiniture"): il motore
# sceglie il giochetto senza toccare la sequenza dei numeri casuali della partita, ognuno dura il suo tempo, l'esito
# non cambia, e i due corpi restano staccati (riuscito e fallito).
extends "test_base.gd"

const D := preload("../sim/duel.gd")
const Skill := preload("../sim/skill.gd")
const TD := preload("test_dribbling.gd")


func test_scelta_secondo_il_dribbling() -> bool:
	# Arrange / Act: tutti i numeri casuali, per un giocatore scarso e uno fortissimo
	var scarso := {}
	var forte := {}
	var di_lato := {}
	for k in 400:
		var r := (k + 0.5) / 400.0
		scarso[String(Skill.scegli(20.0, r).id)] = true
		forte[String(Skill.scegli(99.0, r).id)] = true
		di_lato[String(Skill.scegli(99.0, r, 1.2).id)] = true
	# Assert
	eq(scarso.size(), 2, "con poco dribbling solo i giochetti semplici: %s" % str(scarso.keys()))
	check(scarso.has("finta") and scarso.has("stopgo"), "finta di corpo e stop e via")
	eq(forte.size(), Skill.LISTA.size(), "con tanto dribbling li sa fare tutti (%d)" % forte.size())
	for id: String in Skill.DAVANTI:
		check(not di_lato.has(id), "%s solo col difensore davanti" % id)
	eq(String(Skill.scegli(10.0, 0.3, 0.0, "veronica").id), "veronica", "giochetto fisso per le prove")
	check(String(Skill.scegli(10.0, 0.3, 0.0, "non_esiste").id) in ["finta", "stopgo"], "giochetto fisso sconosciuto: si sceglie come sempre")
	# i più difficili escono più spesso dei più facili (tra quelli che sa fare)
	var conta := {}
	for k in 4000:
		var id := String(Skill.scegli(99.0, (k + 0.5) / 4000.0).id)
		conta[id] = int(conta.get(id, 0)) + 1
	check(int(conta.bicicletta) > 2 * int(conta.finta), "bicicletta %d volte, finta %d" % [conta.bicicletta, conta.finta])
	return done()


func test_sedici_giochetti_con_i_campi_giusti() -> bool:
	eq(Skill.LISTA.size(), 16, "16 giochetti")
	var visti := {}
	var prima := -1.0
	for s: Dictionary in Skill.LISTA:
		check(not visti.has(s.id), "id unico: %s" % s.id)
		visti[s.id] = true
		check(float(s.show) >= 0.3 and float(s.show) <= 0.6, "%s: durata sensata (%.2f s)" % [s.id, s.show])
		check(float(s.dri) >= prima, "%s: in ordine di difficoltà" % s.id)
		prima = float(s.dri)
		check(String(s.name) != "", "%s: nome a schermo" % s.id)
	return done()


func test_il_giochetto_non_tocca_i_numeri_casuali() -> bool:
	# Arrange / Act: stesso seme, giochetto scelto dal motore o fisso, con e senza rifiniture
	var sd := TD.first_ok_seed()
	var a := TD.book_and_resolve(sd, true, "")
	var b := TD.book_and_resolve(sd, true, "pedalata")
	var c := TD.book_and_resolve(sd, false, "")
	# Assert: la sequenza della partita è allo stesso punto, l'esito è lo stesso
	eq((a[0] as SimMatchScript).rng.a, (b[0] as SimMatchScript).rng.a, "stessa sequenza con un giochetto o l'altro")
	eq((a[0] as SimMatchScript).rng.a, (c[0] as SimMatchScript).rng.a, "stessa sequenza con e senza rifiniture")
	eq(bool(a[3].ok), bool(c[3].ok), "stesso esito")
	check(String(a[3].skill) != "", "il motore dice il giochetto: %s" % a[3].skill)
	eq(String(b[3].skill), "pedalata", "giochetto fisso")
	eq(String(c[3].skill), "", "senza rifiniture niente giochetto")
	eq(float(c[3].show), 0.0, "... e niente attesa")
	check((c[0] as SimMatchScript).dribGap == null, "... e nessuna distanza tenuta")
	# stesso seme = stesso giochetto (ripetibile)
	var a2 := TD.book_and_resolve(sd, true, "")
	eq(String(a2[3].skill), String(a[3].skill), "stesso seme, stesso giochetto")
	for r: Array in [a, b, c, a2]:
		(r[0] as SimMatchScript).dispose()
	return done()


func test_ogni_giochetto_dura_il_suo_tempo_e_poi_scatta() -> bool:
	var sd := TD.first_ok_seed()
	for s: Dictionary in Skill.LISTA:
		# Arrange
		var r := TD.book_and_resolve(sd, true, String(s.id))
		var m: SimMatchScript = r[0]
		var p: R.Player = r[1]
		var o: R.Player = r[2]
		var e: Dictionary = r[3]
		eq(bool(e.ok), true, "%s: riuscito" % s.id)
		near(float(e.show), float(s.show), 1e-6, "%s: durata nell'evento" % s.id)
		# Act
		var t := 0.0
		var go := false
		var dmin_a := INF
		var dmin_b := INF
		for i in 150:
			m.step(DT)
			t += DT
			if not go and findEvent(m.events, "dribble_go") != null:
				go = true
				near(t, float(s.show), 2.0 * DT, "%s: scatto dopo la sua durata" % s.id)
			m.events.clear()
			var d := TD.dist(p, o)
			if go:
				dmin_b = minf(dmin_b, d)
			elif t > 0.25:
				dmin_a = minf(dmin_a, d)
		# Assert
		check(go, "%s: lo scatto arriva" % s.id)
		# (il portatore ora avanza durante il giochetto e il difensore indietreggia davanti a lui: la distanza resta un
		# po' sotto DRIB_GAP; che i corpi non si compenetrino lo controlla test_coreo.gd)
		check(dmin_a >= D.DRIB_GAP - 0.5, "%s: durante il giochetto restano staccati (%.2f m)" % [s.id, dmin_a])
		# tunnel e pallonetti: il difensore non viene spostato (il pallone gli passa tra le gambe o sopra la testa)
		var gap_go: float = (D.DRIB_CHASE_GAP - 0.25) if s.has("palla") else (D.DRIB_GAP_GO - 0.4)
		check(dmin_b >= gap_go, "%s: nel sorpasso non si toccano (%.2f m)" % [s.id, dmin_b])
		check(p.y > o.y + 0.5, "%s: oltre il difensore" % s.id)
		check(m.ball.owner == p, "%s: col pallone" % s.id)
		m.dispose()
	return done()


func test_dribbling_fallito_corpi_staccati_e_portatore_fermo() -> bool:
	# Arrange: un seme in cui il dribbling fallisce (statistiche al contrario)
	var trovato := false
	for sd in range(1, 30):
		var s := TD.setup(sd, 5.0)
		var m: SimMatchScript = s[0]
		m.rifiniture = true
		var p: R.Player = s[1]
		var o: R.Player = s[2]
		p.st.dri = 1
		o.st.dif = 99
		var e: Variant = findEvent(H.tapDribble(m), "dribble")
		if e == null or e.ok:
			m.dispose()
			continue
		trovato = true
		# Assert: fermo a lungo (cade), e il difensore non gli finisce addosso
		check(p.stun >= D.DRIB_KO_STUN - 1e-6, "il portatore resta fermo %.2f s" % p.stun)
		var px := p.x
		var py := p.y
		var dmin := INF
		for i in 54:
			m.step(DT)
			if i > 12:
				dmin = minf(dmin, TD.dist(p, o))
		check(dmin >= D.DRIB_GAP_KO_R - 0.3, "restano staccati: %.2f m" % dmin)
		check(C.hyp(p.x - px, p.y - py) < 1.2, "il portatore non viene spostato: %.2f m" % C.hyp(p.x - px, p.y - py))
		m.dispose()
		break
	check(trovato, "un seme col dribbling fallito")
	return done()

