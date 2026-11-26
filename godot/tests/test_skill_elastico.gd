# Giochetto "Elastico" (skill/elastico.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_elastico_esterno_fuori_e_interno_di_scatto_dal_lato_scelto() -> bool:
	# Arrange / Act
	var righe := TF.traccia("elastico")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# l'esterno porta il pallone fuori dal lato della finta, allo scatto l'interno lo riporta di là in un attimo
	var fuori := 0.0
	for r: Dictionary in righe:
		if not r.go:
			fuori = minf(fuori, (r.palla as Vector2).x)
	check(fuori <= -0.5, "il pallone va fuori dal lato della finta (%.2f m)" % fuori)
	var rientro := (TF.riga_a(righe, tg + 0.16).palla as Vector2).x - fuori
	check(rientro >= 0.7, "l'interno lo riporta di scatto attraverso il corpo (%.2f m in 0,16 s)" % rientro)
	return done()
