# Giochetto "Trottola" (skill/waka.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone nel
# riferimento del portatore all'inizio: x = verso il lato scelto, y/z = avanti; m del gioco; yaw = giro del corpo
# verso il lato scelto).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")
const SUOLA_H := 0.3          # m: caviglia almeno così alta = piede sopra il pallone
const SUOLA_D := 0.25         # m: ... ed entro tanto dal pallone, in pianta


static func _sul_pallone(r: Dictionary, nome: String) -> bool:
	var f: Vector3 = r[nome].p
	var b: Vector2 = r.palla
	return not r[nome].terra and f.y >= SUOLA_H and Vector2(f.x, f.z).distance_to(b) <= SUOLA_D


func test_trottola_giro_intero_verso_il_lato_scelto_con_due_suole() -> bool:
	# Arrange / Act
	var righe := TF.traccia("waka")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	# Assert: in corsa, senza piantarsi
	check(TF.appoggi(righe) >= 3, "i piedi appoggiano durante il giro (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# un giro intero, sempre nello stesso verso (verso il lato scelto)
	var giro := 0.0
	var indietro := 0.0
	var prima := 0.0
	var giro_s1 := -1.0         # giro fatto alla prima e alla seconda suola
	var giro_s2 := -1.0
	for r: Dictionary in righe:
		var d := wrapf(float(r.yaw) - prima, -PI, PI)
		prima = float(r.yaw)
		giro += d
		indietro = minf(indietro, d)
		if giro_s1 < 0.0 and _sul_pallone(r, "F"):
			giro_s1 = giro
		if giro_s2 < 0.0 and giro > 2.6 and _sul_pallone(r, "S"):
			giro_s2 = giro
	check(giro > TAU - 0.5 and giro < TAU + 0.9, "un giro intero verso il lato scelto (%.0f°)" % rad_to_deg(giro))
	check(indietro > -0.03, "mai all'indietro (%.2f rad in un passo)" % indietro)
	check(giro_s1 >= 0.0 and giro_s1 < 1.2, "prima suola (piede della finta) all'inizio del giro (%.0f°)" % rad_to_deg(giro_s1))
	check(giro_s2 > 2.4 and giro_s2 < 5.2, "seconda suola (piede del lato scelto) di schiena (%.0f°)" % rad_to_deg(giro_s2))
	# di schiena il pallone è dietro la corsa (coperto dal corpo); dopo lo scatto è davanti, dal lato scelto
	var coperto := INF
	for r: Dictionary in righe:
		if not r.go:
			coperto = minf(coperto, (r.palla as Vector2).y)
	check(coperto < -0.1, "a metà giro il pallone resta dietro, coperto dal corpo (%.2f m)" % coperto)
	var dopo: Vector2 = TF.riga_a(righe, tg + 0.25).palla
	check(dopo.y > 0.3 and dopo.x > 0.0, "all'uscita il pallone è davanti, dal lato scelto (%.2f, %.2f)" % [dopo.x, dopo.y])
	return done()
