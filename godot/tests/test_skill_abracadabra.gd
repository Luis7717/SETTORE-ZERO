# Giochetto "Abracadabra" (skill/abracadabra.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e
# pallone nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")


func test_abracadabra_il_pallone_passa_dietro_la_gamba_d_appoggio_e_torna_dal_lato_scelto() -> bool:
	# Arrange / Act
	var righe := TF.traccia("abracadabra")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	# Assert: in corsa, senza piantarsi
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# il pallone parte dal lato scelto del piede d'appoggio (quello della finta), gli passa DIETRO il tallone e
	# spunta dall'altra parte; il piede che lo porta incrocia dietro la gamba d'appoggio
	var prima := false          # visto dal lato scelto del piede d'appoggio, col piede a terra
	var dietro := INF           # quanto dietro la caviglia d'appoggio passa (m, negativo = dietro)
	var fuori := 0.0            # quanto spunta dall'altra parte (m, negativo = lato della finta)
	var incrocio := false
	var dx_prima := 0.0
	for r: Dictionary in righe:
		if r.go:
			break
		if not r.F.terra:
			continue
		var f: Vector3 = r.F.p
		var b: Vector2 = r.palla
		var dx := b.x - f.x
		if dx > 0.15:
			prima = true
		if prima and dx_prima > 0.0 and dx <= 0.0:
			dietro = b.y - f.z
		dx_prima = dx
		if prima:
			fuori = minf(fuori, dx)
		var s: Vector3 = r.S.p
		if prima and s.x < f.x - 0.1 and s.z < f.z - 0.1 and not r.S.terra:
			incrocio = true
	check(prima, "il pallone arriva accanto al piede d'appoggio, dal lato scelto")
	check(dietro < -0.2, "il pallone passa dietro il tallone d'appoggio (%.2f m)" % dietro)
	check(fuori < -0.3, "il pallone spunta dall'altra parte della gamba d'appoggio (%.2f m)" % fuori)
	check(incrocio, "il piede che porta il pallone incrocia dietro la gamba d'appoggio")
	# allo scatto l'esterno lo riporta dal lato scelto, davanti
	var al_go: Vector2 = TF.riga_a(righe, tg).palla
	var dopo: Vector2 = TF.riga_a(righe, tg + 0.15).palla
	check(al_go.x < -0.15, "allo scatto il pallone è dal lato della finta (%.2f m)" % al_go.x)
	check(dopo.x > 0.1 and dopo.y > 0.25, "l'esterno lo fa schizzare avanti dal lato scelto (%.2f, %.2f)" % [dopo.x, dopo.y])
	return done()
