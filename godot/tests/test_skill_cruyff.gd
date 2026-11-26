# Giochetto "Finta e giro" (scripts/partita/mosse/skill/cruyff.gd), solo grafica. Luis 2026-11-26: "non capisco manco
# cosa fa". Il movimento vero: in corsa, finta di calciare ben caricata (gamba che calcia alta dietro, braccia larghe,
# corpo girato verso il bersaglio finto); invece di calciare il piede passa davanti al pallone e l'interno lo trascina
# DIETRO la gamba d'appoggio; il corpo si gira e riparte dall'altra parte (cambio netto).
# Misure nel riferimento dell'inizio del giochetto: `av` = avanti (verso il difensore), `lato` = dal lato scelto (m).
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TC := preload("test_coreo.gd")
const TD := preload("test_dribbling.gd")
const ID := "cruyff"


# fa andare motore e coreografia come vista.gd; ritorna {S, go, righe: [{t, corpo, yaw, palla, pS, pF, mani, dif}]}
# (punti Vector2(lato, av) in m; yaw in rad dal verso dell'inizio, + = verso il lato scelto; piedi {p, h, terra})
static func traccia(sd: int, lato: float = 0.0) -> Dictionary:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = ID
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	if lato != 0.0 and m.duel != null:
		m.duel.side = lato
	var cp: Coreo = null
	var co: Coreo = null
	var out := {"S": 0.0, "go": INF, "righe": [], "dentro": 0.0}
	var orig := Vector3.ZERO
	var av := Vector3.ZERO
	var lt := Vector3.ZERO
	var S := 0.0
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble" and e.ok:
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				co = Coreo.new(o, 1.0, TC.SCALA, TC.caviglie(o), bv, Vector3.ZERO)
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				co.ostacolo = func() -> Vector3: return Vector3(p.x, 0.0, -p.y)
				S = float(e.side)
				out.S = S
				orig = Vector3(p.x, 0.0, -p.y)
				av = Basis(Vector3.UP, cp.yaw) * Vector3(0, 0, 1)
				lt = Basis(Vector3.UP, cp.yaw) * Vector3(1, 0, 0) * S
				CD.portatore(cp, String(e.skill), S, float(e.show))
				CD.difensore_vuoto(co, S, float(e.show), func() -> Vector3: return cp.pallone(), String(e.skill))
			elif e.type == "dribble_go" and cp != null:
				out.go = cp.t
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
		var loc := func(q: Vector3) -> Vector2: return Vector2((q - orig).dot(lt), (q - orig).dot(av))
		var pd := cp.piedi()
		var N := TC.figura(cp, p)
		var pb := cp.pallone() if cp.pallone_attivo() else Vector3(m.ball.x, 0.0, -m.ball.y)
		var fr := cp.frame(N, pb, 0.0)
		var piede := func(k: String) -> Dictionary:
			return {"p": loc.call(pd[k].pos), "h": float((pd[k].pos as Vector3).y), "terra": bool(pd[k].terra)}
		var kS := "l" if S > 0.0 else "r"
		var kF := "r" if S > 0.0 else "l"
		if not co.finito:
			var sb := Coreo.segmenti(TC.figura(co, o), co.frame(TC.figura(co, o), pb, 0.0))
			out.dentro = maxf(float(out.dentro), Coreo.compenetrazione(Coreo.segmenti(N, fr), sb))
		out.righe.append({"t": cp.t, "corpo": loc.call(Vector3(p.x, 0.0, -p.y)),
			"yaw": wrapf(cp.yaw - cp.yaw0, -PI, PI) * S, "palla": loc.call(pb), "pS": piede.call(kS), "pF": piede.call(kF),
			"mani": ((N * (fr.arms.l.hand as Vector3)) - (N * (fr.arms.r.hand as Vector3))).length(),
			"dif": loc.call(Vector3(o.x, 0.0, -o.y)), "peso": cp.peso})
	m.dispose()
	return out


# punto q nel riferimento del corpo com'è nella riga r: Vector2(di lato verso il lato scelto, avanti) in m
static func nel_corpo(r: Dictionary, q: Vector2) -> Vector2:
	var d: Vector2 = q - (r.corpo as Vector2)
	var a: float = r.yaw
	# verso del corpo nel riferimento (lato, av): girato di `a` verso il lato scelto
	var fw := Vector2(sin(a), cos(a))
	var sx := Vector2(cos(a), -sin(a))
	return Vector2(d.dot(sx), d.dot(fw))


# misure della traccia: {S, go, t_carica, h_carica, dietro_carica, mani_carica, yaw_finta, carica_dur, t_davanti,
# t_dietro, giro, giro_dur, cambio, v_palla_max, palla_lontana, dentro}
static func misure(tr: Dictionary) -> Dictionary:
	var m := {"S": tr.S, "go": tr.go, "dentro": tr.dentro, "t_carica": -1.0, "h_carica": 0.0, "dietro_carica": 0.0,
		"mani_carica": 0.0, "yaw_finta": 0.0, "carica_dur": 0.0, "t_davanti": -1.0, "t_dietro": -1.0, "giro": 0.0,
		"giro_dur": 0.0, "cambio": 0.0, "v_palla_max": 0.0, "palla_lontana": 0.0, "appoggio_a_terra": false}
	var righe: Array = tr.righe
	var go: float = tr.go
	var yaw_min := INF
	var prima: Dictionary = {}
	var dir_prima := Vector2.ZERO
	var dir_dopo := Vector2.ZERO
	# caricamento: il piede che calcia al punto più alto prima dello scatto
	for r: Dictionary in righe:
		if float(r.t) > go:
			break
		if float(r.pF.h) > float(m.h_carica):
			m.h_carica = r.pF.h
			m.t_carica = r.t
			m.dietro_carica = -nel_corpo(r, r.pF.p).y
			m.mani_carica = r.mani
			m.yaw_finta = r.yaw
		if float(r.pF.h) > 0.5:
			m.carica_dur = float(m.carica_dur) + DT
	for r: Dictionary in righe:
		var t: float = r.t
		var b := nel_corpo(r, r.palla)
		var fS := nel_corpo(r, r.pS.p)
		var fF := nel_corpo(r, r.pF.p)
		if t <= go:
			yaw_min = minf(yaw_min, r.yaw)
			if dir_prima == Vector2.ZERO and t >= float(m.t_carica) and not prima.is_empty():   # dove rotola mentre carica
				dir_prima = ((r.palla as Vector2) - (prima.palla as Vector2)).normalized()
			# dopo il caricamento il piede scende e passa davanti al pallone (più avanti del pallone, basso)
			if float(m.t_carica) > 0.0 and t > float(m.t_carica) and float(m.t_davanti) < 0.0 and fF.y > b.y + 0.05 and float(r.pF.h) < 0.45:
				m.t_davanti = t
				m.appoggio_a_terra = r.pS.terra
		# il pallone dietro il piede d'appoggio (a terra), già dalla parte del lato scelto
		if float(m.t_davanti) > 0.0 and float(m.t_dietro) < 0.0 and bool(r.pS.terra) and b.y < fS.y - 0.12 and b.x > fS.x - 0.12:
			m.t_dietro = t
			dir_dopo = ((r.palla as Vector2) - (prima.palla as Vector2)).normalized()   # dove lo porta il trascinamento
		if t > go:
			if float(m.giro_dur) == 0.0 and float(r.yaw) - yaw_min >= 0.9 * (float(righe.back().yaw) - yaw_min):
				m.giro_dur = t - go
			m.palla_lontana = maxf(float(m.palla_lontana), ((r.palla as Vector2) - (r.corpo as Vector2)).length())
		if not prima.is_empty():
			m.v_palla_max = maxf(float(m.v_palla_max), ((r.palla as Vector2) - (prima.palla as Vector2)).length() / DT)
		prima = r
	m.giro = float(righe.back().yaw) - yaw_min
	m.cambio = absf(dir_prima.angle_to(dir_dopo))
	return m


func test_finta_di_calcio_ben_caricata() -> bool:
	# Arrange / Act
	var m := misure(traccia(TD.first_ok_seed()))
	# Assert: prima dello scatto la gamba che calcia va alta dietro, a braccia larghe, girato verso la finta
	check(float(m.t_carica) > 0.0 and float(m.t_carica) < float(m.go), "caricamento prima dello scatto (%.2f s)" % m.t_carica)
	check(float(m.h_carica) >= 0.6, "caviglia della gamba che calcia alta (%.2f m)" % m.h_carica)
	check(float(m.dietro_carica) >= 0.35, "... e dietro il corpo (%.2f m)" % m.dietro_carica)
	check(float(m.mani_carica) >= 1.4, "braccia larghe (mani a %.2f m)" % m.mani_carica)
	check(float(m.yaw_finta) <= -deg_to_rad(60.0), "corpo girato verso la finta (%.0f gradi)" % rad_to_deg(m.yaw_finta))
	check(float(m.carica_dur) >= 0.07, "la gamba resta caricata abbastanza da vederla (%.2f s di partita)" % m.carica_dur)
	return done()


func test_il_piede_passa_davanti_e_trascina_il_pallone_dietro_l_appoggio() -> bool:
	var m := misure(traccia(TD.first_ok_seed()))
	check(float(m.t_davanti) > float(m.t_carica), "dopo il caricamento il piede scende davanti al pallone (%.2f s)" % m.t_davanti)
	check(bool(m.appoggio_a_terra), "... col piede d'appoggio piantato")
	check(float(m.t_dietro) > float(m.t_davanti), "poi il pallone passa dietro il piede d'appoggio (%.2f s)" % m.t_dietro)
	check(float(m.t_dietro) <= float(m.go) + 0.02, "... prima dello scatto: allo scatto va già nel verso nuovo")
	return done()


func test_giro_netto_e_pallone_che_non_resta_indietro() -> bool:
	var m := misure(traccia(TD.first_ok_seed()))
	check(float(m.giro) >= deg_to_rad(95.0), "il corpo si gira di %.0f gradi" % rad_to_deg(m.giro))
	check(float(m.giro_dur) > 0.0 and float(m.giro_dur) <= 0.22, "... in fretta dopo lo scatto (%.2f s)" % m.giro_dur)
	check(float(m.cambio) >= deg_to_rad(95.0), "il trascinamento porta il pallone a %.0f gradi da dove rotolava" % rad_to_deg(m.cambio))
	check(float(m.v_palla_max) <= 10.0, "nessuno strappo del pallone (%.1f m/s al massimo)" % m.v_palla_max)
	check(float(m.palla_lontana) <= 1.1, "dopo lo scatto il pallone resta col portatore (%.2f m al massimo)" % m.palla_lontana)
	check(float(m.dentro) <= TC.DENTRO_MAX, "i due corpi non si compenetrano (%.3f m)" % m.dentro)
	return done()


func test_uguale_dai_due_lati() -> bool:
	# Arrange / Act: lato scelto a sinistra e a destra
	var sd := TD.first_ok_seed()
	var a := misure(traccia(sd, 1.0))
	var b := misure(traccia(sd, -1.0))
	# Assert: stesso movimento allo specchio
	eq(float(a.S), 1.0, "lato sinistro")
	eq(float(b.S), -1.0, "lato destro")
	for k: String in ["h_carica", "dietro_carica", "mani_carica", "yaw_finta", "giro"]:
		near(float(a[k]), float(b[k]), 0.12, "%s uguale dai due lati (%.2f e %.2f)" % [k, a[k], b[k]])
	check(float(b.cambio) >= deg_to_rad(95.0), "anche a destra il trascinamento porta il pallone a %.0f gradi da dove rotolava" % rad_to_deg(b.cambio))
	check(float(b.t_dietro) > 0.0 and float(b.t_dietro) <= float(b.go) + 0.02, "anche a destra il pallone passa dietro l'appoggio")
	return done()
