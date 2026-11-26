# Giochetto "Finta di tiro" (skill/fintatiro.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_fintatiro_gamba_caricata_dietro_e_taglio_dal_lato_scelto() -> bool:
	# Arrange / Act
	var righe := TF.traccia("fintatiro")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# gamba caricata dietro e in alto, appoggio a terra accanto al pallone; prima dello scatto il pallone non va di lato
	var carica := false
	var lato_a := 0.0
	for r: Dictionary in righe:
		if r.go:
			break
		var f: Vector3 = r.F.p
		if f.z < -0.4 and f.y > 0.5 and r.S.terra:
			carica = true
		lato_a = maxf(lato_a, absf((r.palla as Vector2).x))
	check(carica, "gamba del tiro caricata dietro e alta con l'altro piede a terra")
	check(lato_a < 0.2, "prima dello scatto il pallone non è toccato (%.2f m di lato)" % lato_a)
	var dopo := (TF.riga_a(righe, tg + 0.18).palla as Vector2).x - (TF.riga_a(righe, tg).palla as Vector2).x
	check(dopo >= 0.25, "allo scatto l'interno taglia il pallone dal lato scelto (%.2f m)" % dopo)
	return done()
