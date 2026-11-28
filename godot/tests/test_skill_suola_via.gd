# Giochetto "Suola indietro e via" (skill/suola_via.gd), solo grafica: misure sulla traccia di test_skill_finta.gd
# (piedi e pallone nel riferimento del portatore all'inizio: x = verso il lato scelto, y/z = avanti; m del gioco).
# Il gesto: in corsa la suola tira indietro il pallone (una L: indietro e in fuori dal lato scelto), il corpo si apre da
# quella parte e lo stesso piede lo spinge via.
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")
const TS := preload("test_skill_suola.gd")
const ID := "suola_via"


func test_la_suola_tira_indietro_il_pallone_e_il_corpo_si_apre() -> bool:
	# Arrange / Act
	var righe := TF.traccia(ID)
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	# Assert: la suola del piede del lato scelto sta sul pallone mentre lo tira
	var su := TS.suola_sul_pallone(righe, "S")
	check(su >= 8, "la suola sta sul pallone mentre lo tira (%d passi)" % su)
	# il pallone parte davanti al corpo e finisce accanto, dal lato scelto
	var z_max := -INF
	var y_max := -INF   # sul prato: il punto più avanti
	for r: Dictionary in righe:
		if not r.go:
			z_max = maxf(z_max, (r.palla as Vector2).y)
			y_max = maxf(y_max, ((r.corpo as Vector2) + (r.palla as Vector2)).y)
	var fine := TF.riga_a(righe, tg)
	check(z_max >= 0.7, "la suola prende il pallone ben davanti al corpo (%.2f m)" % z_max)
	check((fine.palla as Vector2).y <= 0.15, "... e lo tira fino accanto al corpo (%.2f m davanti)" % (fine.palla as Vector2).y)
	check((fine.palla as Vector2).x >= 0.3, "... in fuori, dal lato scelto (%.2f m)" % (fine.palla as Vector2).x)
	var indietro: float = y_max - ((fine.corpo as Vector2) + (fine.palla as Vector2)).y
	check(indietro >= 0.1, "sul prato il pallone torna davvero indietro (%.2f m)" % indietro)
	check(float(fine.yaw) >= 0.5, "il corpo si apre verso il lato scelto (%.2f rad)" % float(fine.yaw))
	return done()


func test_non_si_pianta_e_il_pallone_riparte_col_portatore() -> bool:
	var righe := TF.traccia(ID)
	var tg := TF.t_go(righe)
	check(TF.appoggi(righe) >= 2, "passi durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	var v_min := INF
	var lontana := 0.0
	for r: Dictionary in righe:
		if not r.go and float(r.t) > 0.2:
			v_min = minf(v_min, float(r.vel))
		if r.go:
			lontana = maxf(lontana, (r.palla as Vector2).length())
	check(v_min >= 1.8, "rallenta ma non si ferma (minimo %.1f m/s)" % v_min)
	check(lontana <= 1.2, "dopo lo scatto il pallone resta col portatore (%.2f m al massimo)" % lontana)
	var dopo := TF.riga_a(righe, tg + 0.3)
	check((dopo.corpo as Vector2).y > (TF.riga_a(righe, tg).corpo as Vector2).y + 1.5, "dopo lo scatto riparte di corsa")
	return done()
