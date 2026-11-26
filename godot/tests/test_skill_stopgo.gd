# Giochetto "Stop e via" (skill/stopgo.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_stopgo_si_ferma_sul_pallone_e_riparte() -> bool:
	# Arrange / Act
	var righe := TF.traccia("stopgo")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	# si ferma apposta: il pallone resta sul prato sotto la suola e il corpo gli arriva sopra, poi lo scatto
	check(float(TF.riga_a(righe, tg - 0.05).vel) < 1.5, "prima dello scatto è quasi fermo")
	var prima := (TF.riga_a(righe, 0.15).palla as Vector2).y
	var allo_scatto := (TF.riga_a(righe, tg).palla as Vector2).y
	check(prima - allo_scatto >= 0.2, "il corpo arriva sopra il pallone fermo (%.2f → %.2f m)" % [prima, allo_scatto])
	var su := 0
	for r: Dictionary in righe:
		if not r.go and (r.S.p as Vector3).y > 0.3:
			su += 1
	check(su >= 10, "la suola resta sul pallone (%d passi)" % su)
	check(float(TF.riga_a(righe, tg + 0.1).vel) > 6.0, "riparte di scatto")
	check(not bool(TF.riga_a(righe, tg - 0.05).F.terra) or (TF.riga_a(righe, tg - 0.05).F.p as Vector3).z > -0.3,
		"il piede che regge si è rimesso sotto il corpo")
	return done()
