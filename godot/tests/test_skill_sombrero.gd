# Sombrero (scripts/partita/mosse/skill/sombrero.gd): solo grafica. Il pallone lo alza la punta del piede (dopo la suola
# che lo tira indietro), vola con la gravità del motore sopra il difensore, e il portatore gli gira intorno di corsa.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const Skill := preload("../sim/skill.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")


# motore e coreografia insieme (come vista.gd); una riga ogni `ogni` passi dal dribbling in poi
static func traccia(sd: int, ogni: int = 3) -> Array:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = "sombrero"
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	var cp: Coreo = null
	var righe: Array = []
	var S := 1.0
	var n := 0
	for i in 420:
		m.step(DT)
		var evs := ""
		for e: Dictionary in m.events:
			if e.type == "dribble":
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), Vector3(m.ball.x, 0, -m.ball.y), Vector3(m.ball.vx, 0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				S = float(e.side)
				CD.portatore(cp, String(e.skill), S, float(e.show))
			elif e.type == "dribble_go" and cp != null:
				CD.portatore_go(cp)
			if String(e.type).begins_with("dribble"):
				evs += " " + String(e.type)
		m.events.clear()
		if cp == null:
			continue
		cp.passo(DT, p, m.ball)
		n += 1
		var fi: R.Ball = m.ball.finto
		var pd := cp.piedi()
		if n % ogni == 0 or evs != "":
			righe.append({"t": cp.t, "px": p.x * S, "py": p.y, "v": C.hyp(p.vx, p.vy), "ox": o.x * S, "oy": o.y,
				"fx": fi.x * S if fi != null else NAN, "fy": fi.y if fi != null else NAN, "fh": fi.h if fi != null else NAN,
				"bx": cp.pallone().x * S, "by": -cp.pallone().z, "bh": cp.pallone_h(), "att": cp.pallone_attivo(),
				"duel": m.duel != null, "flee": m.get("flee") != null, "ev": evs, "peso": cp.peso,
				"l": pd.l, "r": pd.r, "S": S, "yaw": cp.yaw})
		if cp.finito and fi == null and cp.t > 1.0:
			break
	m.dispose()
	return righe


func test_traccia() -> bool:
	if OS.get_environment("SOMBRERO_TRACCIA") == "":
		return done()
	for r: Dictionary in traccia(TD.first_ok_seed()):
		print("t%.2f p(%.2f %.2f) v%.1f o(%.2f %.2f) finto(%.2f %.2f h%.2f) palla(%.2f %.2f h%.2f)%s%s%s w%.1f L%s%.2f R%s%.2f%s" % [r.t, r.px, r.py, r.v, r.ox, r.oy,
			r.fx, r.fy, r.fh, r.bx, r.by, r.bh, " A" if r.att else "", " DUEL" if r.duel else "", " FLEE" if r.flee else "", r.peso,
			"_" if r.l.terra else "^", (r.l.pos as Vector3).y, "_" if r.r.terra else "^", (r.r.pos as Vector3).y, r.ev])
	return done()


static func _piede(r: Dictionary, s: String) -> Vector3:
	return r[s].pos


# distanza in pianta tra la caviglia del piede s e il pallone mostrato (m)
static func _dist_piede(r: Dictionary, s: String) -> float:
	var q := _piede(r, s)
	return Vector2(q.x * float(r.S) - float(r.bx), -q.z - float(r.by)).length()


func test_la_suola_tira_indietro_e_la_punta_alza() -> bool:
	# Arrange / Act
	var tr := traccia(TD.first_ok_seed(), 1)
	var avanti_max := -INF    # pallone davanti al corpo (lungo la corsa, m) prima del lancio: massimo ...
	var avanti_dopo := INF    # ... e minimo dopo quel massimo (la suola lo ha tirato sotto il corpo)
	var lancio := {}
	for r: Dictionary in tr:
		if String(r.ev).contains("dribble_palla"):
			lancio = r
			break
		var av: float = float(r.by) - float(r.py)
		if av > avanti_max:
			avanti_max = av
			avanti_dopo = av
		avanti_dopo = minf(avanti_dopo, av)
	# Assert
	check(not lancio.is_empty(), "il pallone si stacca")
	check(avanti_max - avanti_dopo >= 0.25, "la suola tira il pallone verso il corpo di %.2f m" % (avanti_max - avanti_dopo))
	var pS := "l" if float(lancio.S) > 0.0 else "r"
	var pF := "r" if pS == "l" else "l"
	check(not lancio[pS].terra, "il piede che alza il pallone è staccato da terra")
	check(lancio[pF].terra, "l'altro piede è in appoggio quando la punta alza il pallone")
	check(_dist_piede(lancio, pS) < 0.45, "la punta è sotto il pallone quando parte (caviglia a %.2f m)" % _dist_piede(lancio, pS))
	check(float(lancio.bh) < 0.15, "parte da terra (%.2f m)" % float(lancio.bh))
	return done()


func test_il_pallone_vola_da_solo_sopra_il_difensore() -> bool:
	var tr := traccia(TD.first_ok_seed(), 1)
	var t_lancio := -1.0
	var sopra := -1.0
	var scarto := 0.0
	for r: Dictionary in tr:
		if String(r.ev).contains("dribble_palla"):
			t_lancio = float(r.t)
		if is_nan(float(r.fx)) or t_lancio < 0.0:
			continue
		if sopra < 0.0 and float(r.fy) >= float(r.oy):
			sopra = float(r.fh)
		# passato il raccordo col piede (coreo.FINTO_ENTRA) il pallone a schermo è proprio quello del motore
		if float(r.t) > t_lancio + Coreo.FINTO_ENTRA + 0.02:
			scarto = maxf(scarto, Vector3(float(r.bx) - float(r.fx), float(r.bh) - float(r.fh), float(r.by) - float(r.fy)).length())
	check(sopra > 2.4, "sopra il difensore il pallone è alto %.2f m (figura alta 2,3)" % sopra)
	check(scarto < 1e-3, "in volo il pallone a schermo è quello del motore, niente correzioni (%.4f m)" % scarto)
	return done()


func test_il_portatore_parte_di_corsa_e_lo_controlla_col_piede() -> bool:
	var tr := traccia(TD.first_ok_seed(), 1)
	var t_go := -1.0
	var t_presa := -1.0
	var v_min := INF
	var fermo_max := 0.0       # appoggio più lungo di un piede durante la corsa con la coreografia attiva (s)
	var da := {"l": -1.0, "r": -1.0}
	var vicino := INF
	var fine: Dictionary = tr.back()
	for r: Dictionary in tr:
		if String(r.ev).contains("dribble_go"):
			t_go = float(r.t)
		if String(r.ev).contains("dribble_presa"):
			t_presa = float(r.t)
		if t_go < 0.0:
			continue
		if t_presa < 0.0:
			v_min = minf(v_min, float(r.v))
			for s: String in ["l", "r"]:
				if r[s].terra and float(r.peso) > 0.5 and float(r.t) > t_go + 0.1:
					if float(da[s]) < 0.0:
						da[s] = float(r.t)
					fermo_max = maxf(fermo_max, float(r.t) - float(da[s]))
				else:
					da[s] = -1.0
		elif float(r.t) <= t_presa + 0.2:
			vicino = minf(vicino, minf(_dist_piede(r, "l"), _dist_piede(r, "r")))
	check(t_presa > t_go and t_go > 0.0, "scatto e poi presa")
	check(t_presa - t_go > 1.0, "lo raggiunge dopo il volo (%.2f s), non torna da lui" % (t_presa - t_go))
	check(v_min >= 2.0, "non si ferma mai mentre lo insegue (minimo %.1f m/s)" % v_min)
	check(fermo_max <= 0.3, "parte a falcate: nessun piede resta a terra più di %.2f s" % fermo_max)
	check(vicino < 0.4, "ripreso: un piede va sul pallone (caviglia a %.2f m)" % vicino)
	check(not fine.att, "alla fine il pallone è di nuovo quello del motore")
	return done()
