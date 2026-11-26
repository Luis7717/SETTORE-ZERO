# Giochetto "Elastico inverso" (skill/elastico_inv.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_elastico_inverso_interno_dentro_e_esterno_di_scatto_fuori() -> bool:
	# Arrange / Act
	var righe := TF.traccia("elastico_inv")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# l'interno del piede del lato scelto porta il pallone dentro (verso la finta), allo scatto l'esterno lo riporta fuori
	var dentro := 0.0
	for r: Dictionary in righe:
		if not r.go:
			dentro = minf(dentro, (r.palla as Vector2).x)
	check(dentro <= -0.35, "il pallone va dentro, verso la finta (%.2f m)" % dentro)
	var fuori := (TF.riga_a(righe, tg + 0.16).palla as Vector2).x - dentro
	check(fuori >= 0.6, "l'esterno lo riporta fuori di scatto (%.2f m in 0,16 s)" % fuori)
	return done()
