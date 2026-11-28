# Giochetto "Triplo elastico" (skill/elastico3.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e
# pallone nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco) e fluidità del gesto
# (test_skill_elastico.gd `onda`).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")
const TE := preload("test_skill_elastico.gd")
const Skill := preload("res://sim/skill.gd")

const FUORI_MIN := 0.35       # m: a ogni cambio il pallone va almeno tanto verso la finta ...
const ONDA_MIN := 0.3         # ... e tra un cambio e l'altro torna indietro di almeno tanto


func test_triplo_elastico_in_corsa_senza_piedi_piantati() -> bool:
	# Arrange / Act
	var righe := TF.traccia("elastico3")
	var tg := TF.t_go(righe)
	# Assert
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 3, "il piede d'appoggio saltella durante i tre cambi (%d appoggi)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	var v_min := INF
	for r: Dictionary in righe:
		if not r.go and float(r.t) > 0.2:
			v_min = minf(v_min, float(r.vel))
	check(v_min >= 1.5, "il portatore non si ferma (%.1f m/s)" % v_min)
	var dopo := TF.riga_a(righe, tg + 0.25)
	check((dopo.corpo as Vector2).x > (TF.riga_a(righe, tg).corpo as Vector2).x, "dopo lo scatto va dal lato scelto")
	return done()


func test_triplo_elastico_tre_cambi_di_fila_senza_pause_ne_scatti() -> bool:
	# Act
	var r := TE.onda("elastico3")
	# Assert
	check(float(r.tg) < INF, "arriva lo scatto")
	TE.controlla_fluido(self, "elastico3", r)
	# fuori, dentro, fuori, dentro, fuori (e poi via dal lato scelto): cinque cambi di verso
	var e: Array = r.estremi
	eq(e.size(), 5, "tre volte fuori e due rientri prima dell'ultimo cambio (%s)" % str(e))
	if e.size() == 5:
		for i in [0, 2, 4]:
			check(float(e[i]) <= -FUORI_MIN, "cambio %d: il pallone va fuori verso la finta (%.2f m)" % [i / 2 + 1, e[i]])
		for i in [1, 3]:
			check(float(e[i]) - float(e[i - 1]) >= ONDA_MIN, "rientro %d: torna verso il corpo (%.2f m)" % [i / 2 + 1, float(e[i]) - float(e[i - 1])])
	check(float(r.dopo) >= 0.05, "alla fine il pallone è dal lato scelto (%.2f m)" % r.dopo)
	return done()


func test_triplo_elastico_facile_e_di_durata_sensata() -> bool:
	var s := Skill.trova("elastico3")
	check(float(s.dri) < 50.0, "è tra i facili (Dribbling %d)" % int(s.dri))
	check(float(s.show) >= 0.6 and float(s.show) <= 0.7, "dura abbastanza per tre cambi (%.2f s)" % s.show)
	return done()
