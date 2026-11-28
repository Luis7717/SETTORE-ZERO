# Giochetto "Suola" (skill/suola.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
# Luis: "malino", "si ferma sul posto prima di farla": rotolata laterale in corsa, il corpo scivola di lato col pallone.
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


## passi (prima dello scatto) in cui la suola del piede `nome` sta sul pallone: piede alto e sopra il pallone
static func suola_sul_pallone(righe: Array, nome: String) -> int:
	var su := 0
	for r: Dictionary in righe:
		var f: Vector3 = r[nome].p
		if not r.go and f.y > 0.3 and Vector2(f.x, f.z).distance_to(r.palla) < 0.3:
			su += 1
	return su


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
	var su := suola_sul_pallone(righe, "F")
	check(su >= 12, "la suola sta sul pallone mentre rotola (%d passi)" % su)
	var x_min := INF
	for r: Dictionary in righe:
		if not r.go:
			x_min = minf(x_min, (r.palla as Vector2).x)
	var lato := (TF.riga_a(righe, tg).palla as Vector2).x - x_min
	check(x_min <= -0.12, "la suola prende il pallone dalla parte della finta (%.2f m)" % x_min)
	check(lato >= 0.5, "il pallone rotola davanti al corpo fino al lato scelto (%.2f m)" % lato)
	return done()


func test_suola_non_si_ferma_e_resta_di_fronte() -> bool:
	var righe := TF.traccia("suola")
	var tg := TF.t_go(righe)
	var v_min := INF
	var giro := 0.0
	for r: Dictionary in righe:
		if not r.go:
			v_min = minf(v_min, float(r.vel))
			giro = maxf(giro, absf(float(r.yaw)))
	check(v_min >= 2.5, "durante la rotolata continua a correre (minimo %.1f m/s)" % v_min)
	check(giro <= 0.2, "il petto resta verso il difensore (giro massimo %.2f rad)" % giro)
	# scivola di lato insieme al pallone: il pallone sul prato va verso il lato scelto
	var a := TF.riga_a(righe, 0.12)
	var b := TF.riga_a(righe, tg)
	var palla_mondo: float = ((b.corpo as Vector2) + (b.palla as Vector2)).x - ((a.corpo as Vector2) + (a.palla as Vector2)).x
	check(palla_mondo >= 0.4, "sul prato il pallone si sposta verso il lato scelto (%.2f m)" % palla_mondo)
	return done()
