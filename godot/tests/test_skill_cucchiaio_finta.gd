# Giochetto "Finta col cucchiaio" (skill/cucchiaio_finta.gd), solo grafica: misure sulla traccia di test_skill_finta.gd
# (piedi e pallone nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")


func test_cucchiaio_finta_gamba_caricata_punta_sotto_il_pallone_fermo_e_via_dal_lato_scelto() -> bool:
	# Arrange / Act
	var righe := TF.traccia("cucchiaio_finta")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	# Assert: in corsa, senza piantarsi
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# gamba caricata alta dietro, poi la punta scende dietro e sotto il pallone (caviglia bassa, dietro il pallone)
	var carica := 0.0
	var t_punta := INF
	for r: Dictionary in righe:
		if r.go:
			break
		var s: Vector3 = r.S.p
		var b: Vector2 = r.palla
		if s.z < -0.3:
			carica = maxf(carica, s.y)
		var d := b.y - s.z
		if carica > 0.5 and t_punta == INF and s.y < 0.16 and absf(s.x - b.x) < 0.12 and d > 0.25 and d < 0.5:
			t_punta = float(r.t)
	check(carica > 0.55, "gamba caricata dietro (caviglia a %.2f m)" % carica)
	check(t_punta < tg, "la punta scende sotto il pallone prima dello scatto")
	# il pallone resta fermo sul prato mentre il corpo scivola verso la finta: allo scatto è dal lato scelto
	if t_punta < tg:
		var r0 := TF.riga_a(righe, t_punta)
		var r1 := TF.riga_a(righe, tg - 0.02)
		var p0: Vector2 = (r0.corpo as Vector2) + (r0.palla as Vector2)
		var p1: Vector2 = (r1.corpo as Vector2) + (r1.palla as Vector2)
		check(p0.distance_to(p1) < 0.06, "il pallone resta dov'è sul prato (si sposta di %.2f m)" % p0.distance_to(p1))
		check((r1.corpo as Vector2).x < (r0.corpo as Vector2).x, "il corpo intanto va verso la finta")
	check((TF.riga_a(righe, tg).palla as Vector2).x > 0.2, "allo scatto il pallone è dal lato scelto del corpo")
	var dopo: Vector2 = TF.riga_a(righe, tg + 0.2).palla
	check(dopo.x > 0.15 and dopo.y > 0.25, "l'esterno lo porta via avanti dal lato scelto (%.2f, %.2f)" % [dopo.x, dopo.y])
	return done()


func test_cucchiaio_finta_il_difensore_abbocca_di_lato() -> bool:
	check(String(CD.STILE_DIF.get("cucchiaio_finta", "affondo")) == "affondo", "il difensore si butta dalla parte della finta")
	return done()
