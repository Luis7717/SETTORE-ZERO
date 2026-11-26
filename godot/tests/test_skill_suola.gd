# Giochetto "Suola" (skill/suola.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_suola_in_corsa_il_pallone_rotola_sotto_la_suola_fino_al_lato_scelto() -> bool:
	# Arrange / Act
	var righe := TF.traccia("suola")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# la suola (piede della finta alto sul pallone) lo porta dal lato scelto
	var su := 0
	for r: Dictionary in righe:
		if not r.go and (r.F.p as Vector3).y > 0.3 and Vector2((r.F.p as Vector3).x, (r.F.p as Vector3).z).distance_to(r.palla) < 0.3:
			su += 1
	check(su >= 6, "la suola sta sul pallone mentre rotola (%d passi)" % su)
	var lato := (TF.riga_a(righe, tg).palla as Vector2).x - (TF.riga_a(righe, 0.5 * tg).palla as Vector2).x
	check(lato >= 0.4, "il pallone rotola di lato verso il lato scelto (%.2f m)" % lato)
	return done()
