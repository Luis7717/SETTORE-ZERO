# Giochetto "Doppio passo" (skill/doppiopasso.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_doppiopasso_due_giri_del_piede_intorno_al_pallone_senza_toccarlo() -> bool:
	# Arrange / Act
	var righe := TF.traccia("doppiopasso")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# due giri (prima il piede del lato scelto, poi l'altro) davanti al pallone, che intanto va dritto
	var t_s := -1.0
	var t_f := -1.0
	var lato := 0.0
	for r: Dictionary in righe:
		if r.go:
			break
		var b: Vector2 = r.palla
		lato = maxf(lato, absf(b.x))
		if t_s < 0.0 and not r.S.terra and (r.S.p as Vector3).z > b.y + 0.1:
			t_s = float(r.t)
		if t_s >= 0.0 and not r.F.terra and (r.F.p as Vector3).z > b.y + 0.1:
			t_f = float(r.t)
	check(t_s >= 0.0, "primo giro: il piede del lato scelto passa davanti al pallone")
	check(t_f > t_s, "secondo giro: poi l'altro piede")
	check(lato < 0.15, "il pallone va dritto, non toccato (%.2f m di lato)" % lato)
	var dopo := (TF.riga_a(righe, tg + 0.3).corpo as Vector2).y - (TF.riga_a(righe, tg).corpo as Vector2).y
	check(dopo > 1.5, "dopo i giri scatta via")
	return done()
