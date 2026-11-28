# Giochetto "Elastico inverso" (skill/elastico_inv.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco) e fluidità del gesto
# (test_skill_elastico.gd `onda`).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")
const TE := preload("test_skill_elastico.gd")


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
	check(fuori >= 0.5, "l'esterno lo riporta fuori (%.2f m in 0,16 s)" % fuori)
	return done()


func test_elastico_inverso_un_gesto_solo_senza_pause_ne_scatti() -> bool:
	# Act
	var r := TE.onda("elastico_inv")
	# Assert
	check(float(r.tg) < INF, "arriva lo scatto")
	TE.controlla_fluido(self, "elastico_inv", r)
	eq((r.estremi as Array).size(), 1, "un solo cambio di verso: dentro con l'interno, fuori con l'esterno")
	check(float(r.fuori) <= -0.35 and float(r.dopo) >= 0.05, "dentro verso la finta (%.2f m) e poi fuori dal lato scelto (%.2f m)" % [r.fuori, r.dopo])
	return done()
