# Giochetto "Suola e giro" (skill/suola_180.gd), solo grafica: misure sulla traccia di test_skill_finta.gd
# (piedi e pallone nel riferimento del portatore all'inizio: x = verso il lato scelto, y/z = avanti; m del gioco).
# Il gesto: corre di lato verso la finta portando il pallone con la suola, la suola lo ferma e lo tira indietro nel
# verso opposto, il corpo si gira di netto e riparte dal lato scelto.
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")
const TS := preload("test_skill_suola.gd")
const ID := "suola_180"


# {x_min (pallone sul prato, punto più verso la finta), t_min, x_go, yaw_min, yaw_fine, corpo_min, corpo_fine}
static func misure(righe: Array) -> Dictionary:
	var m := {"x_min": INF, "t_min": 0.0, "x_go": 0.0, "yaw_min": INF, "yaw_fine": 0.0, "corpo_go": 0.0, "corpo_fine": 0.0,
		"lontana": 0.0}
	var tg := TF.t_go(righe)
	for r: Dictionary in righe:
		var x: float = ((r.corpo as Vector2) + (r.palla as Vector2)).x
		if not r.go:
			if x < float(m.x_min):
				m.x_min = x
				m.t_min = r.t
			m.yaw_min = minf(float(m.yaw_min), float(r.yaw))
		else:
			m.lontana = maxf(float(m.lontana), (r.palla as Vector2).length())
	var go := TF.riga_a(righe, tg)
	m.x_go = ((go.corpo as Vector2) + (go.palla as Vector2)).x
	m.corpo_go = (go.corpo as Vector2).x
	m.yaw_fine = (righe.back() as Dictionary).yaw
	m.corpo_fine = ((righe.back() as Dictionary).corpo as Vector2).x
	return m


func test_va_verso_la_finta_poi_la_suola_tira_indietro_e_si_gira() -> bool:
	# Arrange / Act
	var righe := TF.traccia(ID)
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	var m := misure(righe)
	# Assert: prima corre di lato verso la finta, girato da quella parte, col pallone sotto la suola
	check(float(m.corpo_go) <= -0.5, "il corpo va verso la finta (%.2f m)" % float(m.corpo_go))
	check(float(m.yaw_min) <= -1.0, "girato verso la finta (%.2f rad)" % float(m.yaw_min))
	check(float(m.x_min) <= -0.6, "il pallone rotola verso la finta (%.2f m)" % float(m.x_min))
	var su := TS.suola_sul_pallone(righe, "S")
	check(su >= 14, "la suola sta sul pallone (%d passi)" % su)
	# poi la suola lo ferma e lo tira indietro, prima dello scatto
	check(float(m.t_min) < tg - 0.1, "la suola ferma il pallone prima dello scatto (a %.2f s)" % float(m.t_min))
	check(float(m.x_go) - float(m.x_min) >= 0.25, "... e lo tira indietro sul prato (%.2f m)" % (float(m.x_go) - float(m.x_min)))
	# giro netto e ripartenza dall'altra parte
	check(float(m.yaw_fine) - float(m.yaw_min) >= deg_to_rad(80.0), "il corpo si gira di %.0f gradi" % rad_to_deg(float(m.yaw_fine) - float(m.yaw_min)))
	check(float(m.corpo_fine) > float(m.corpo_go) + 0.3, "dopo lo scatto riparte verso il lato scelto (%.2f m)" % (float(m.corpo_fine) - float(m.corpo_go)))
	return done()


func test_non_si_pianta_e_il_pallone_resta_col_portatore() -> bool:
	var righe := TF.traccia(ID)
	check(TF.appoggi(righe) >= 2, "passi durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	var v_min := INF
	for r: Dictionary in righe:
		if not r.go and float(r.t) > 0.2:
			v_min = minf(v_min, float(r.vel))
	check(v_min >= 1.8, "non si ferma (minimo %.1f m/s)" % v_min)
	check(float(misure(righe).lontana) <= 1.2, "dopo lo scatto il pallone resta col portatore (%.2f m)" % float(misure(righe).lontana))
	return done()


# le tre suole sono movimenti diversi: rotolata di lato a petto in avanti, tirata indietro, inversione col giro
func test_le_tre_suole_sono_diverse() -> bool:
	var giro := {}
	var lato := {}
	var avanti := {}
	for id: String in ["suola", "suola_via", "suola_180"]:
		var righe := TF.traccia(id)
		var tg := TF.t_go(righe)
		var y_min := INF
		var y_max := -INF
		for r: Dictionary in righe:
			if not r.go:
				y_min = minf(y_min, float(r.yaw))
				y_max = maxf(y_max, float(r.yaw))
		giro[id] = y_max - y_min
		lato[id] = (TF.riga_a(righe, tg).corpo as Vector2).x
		avanti[id] = (TF.riga_a(righe, tg).palla as Vector2).y
	check(float(giro.suola) < 0.2 and float(giro.suola_via) > 0.5 and float(giro.suola_180) > 1.3,
		"giro del corpo: suola %.2f, suola_via %.2f, suola_180 %.2f rad" % [giro.suola, giro.suola_via, giro.suola_180])
	check(float(lato.suola_180) < float(lato.suola) - 0.4, "suola_180 va dalla parte opposta della suola (%.2f e %.2f m)" % [lato.suola_180, lato.suola])
	check(float(avanti.suola_via) < float(avanti.suola) - 0.3, "suola_via tira il pallone indietro, la suola lo tiene davanti (%.2f e %.2f m)" % [avanti.suola_via, avanti.suola])
	return done()
