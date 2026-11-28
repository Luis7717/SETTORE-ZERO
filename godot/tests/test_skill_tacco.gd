# Giochetto "Colpo di tacco" (skill/tacco.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_tacco_il_piede_scavalca_il_pallone_e_il_tacco_lo_manda_indietro() -> bool:
	# Arrange / Act
	var righe := TF.traccia("tacco")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# ginocchio alto sopra il pallone, poi il piede è davanti al pallone e il pallone va indietro sotto il corpo;
	# dopo lo scatto il piede dietro lo calcia in avanti (con un piccolo arco)
	var alto := 0.0
	var davanti := false
	for r: Dictionary in righe:
		if r.go:
			break
		var f: Vector3 = r.F.p
		alto = maxf(alto, f.y)
		if f.y < 0.4 and f.z > (r.palla as Vector2).y + 0.1:
			davanti = true
	check(alto > 0.5, "ginocchio alto nello scavalcare (caviglia a %.2f m)" % alto)
	check(davanti, "il piede scende davanti al pallone (tacco verso il pallone)")
	var dietro := INF
	for r: Dictionary in righe:
		if r.go and float(r.t) < tg + 0.15:
			dietro = minf(dietro, (r.palla as Vector2).y)
	check(dietro < 0.0, "il tacco manda il pallone indietro, sotto il corpo (%.2f m)" % dietro)
	# Luis 2026-11-27: "il contatto di tacco non si vede da dietro": il pallone non resta nascosto sotto il corpo.
	# Prima del tacco sta dal lato della finta (davanti al piede che lo scavalca), poi esce dietro dal lato scelto
	var lato_prima := 0.0
	var lato_dietro := 0.0
	var piu_dietro := 0.0
	for r: Dictionary in righe:
		var pb: Vector2 = r.palla
		if not r.go:
			lato_prima = minf(lato_prima, pb.x)
		if float(r.t) < tg + 0.15 and pb.y < piu_dietro:
			piu_dietro = pb.y
			lato_dietro = pb.x
	check(lato_prima < -0.12, "prima del tacco il pallone è dal lato della finta, fuori da sotto il corpo (%.2f m)" % lato_prima)
	check(piu_dietro < -0.25, "il pallone va dietro il corpo abbastanza da vedersi da dietro (%.2f m)" % piu_dietro)
	check(lato_dietro > 0.2, "... ed esce dal lato scelto, dietro la gamba d'appoggio (%.2f m)" % lato_dietro)
	check((TF.riga_a(righe, tg + 0.3).palla as Vector2).y > 0.5, "poi il pallone torna davanti, calciato dal piede dietro")
	return done()
