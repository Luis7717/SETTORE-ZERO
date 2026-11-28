# Giochetto "Veronica di classe" (scripts/partita/mosse/skill/veronica_classe.gd), solo grafica: una roulette che si
# distingue dalla veronica: giro più stretto e veloce, saltello vero a metà giro, busto dritto e braccia alte, pallone
# coperto dal corpo e uscita di corsa; gambe mai deformate (anche alla fine del giro).
extends "test_base.gd"

const TD := preload("test_dribbling.gd")
const TGT := preload("test_skill_giro_tocco.gd")
const ID := "veronica_classe"


func test_giro_intero_continuo_e_piu_veloce_della_veronica() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := TGT.traccia(ID, TD.first_ok_seed(), lato)
		var base := TGT.traccia("veronica", TD.first_ok_seed(), lato)
		check(not tr.is_empty() and not base.is_empty(), "dribbling riuscito")
		var m := TGT.misura(tr)
		var mb := TGT.misura(base)
		note("lato %+d: giro %.0f gradi in %.2f s (veronica %.2f s), velocità del giro da %.1f a %.1f rad/s" % [int(lato),
			rad_to_deg(m.tot), m.dur, mb.dur, m.w_min, m.w_max])
		check(m.tot > deg_to_rad(320.0) and m.tot < deg_to_rad(400.0), "un giro intero (%.0f gradi)" % rad_to_deg(m.tot))
		check(m.indietro < 0.02, "sempre nello stesso verso")
		check(m.w_min > 8.0, "nessuna pausa nel giro (minimo %.1f rad/s)" % m.w_min)
		check(m.w_max < 14.0, "non una trottola (massimo %.1f rad/s)" % m.w_max)
		check(m.dur < 0.8 * float(mb.dur), "giro più veloce della veronica (%.2f contro %.2f s)" % [m.dur, mb.dur])
	return done()


func test_saltello_busto_dritto_e_braccia_alte_si_distingue_dalla_veronica() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := TGT.traccia(ID, TD.first_ok_seed(), lato)
		var base := TGT.traccia("veronica", TD.first_ok_seed(), lato)
		var alto := {"c": 0.0, "v": 0.0}
		var mani := {"c": 0.0, "v": 0.0}
		for k: String in ["c", "v"]:
			var t: Array = tr if k == "c" else base
			var m := TGT.misura(t)
			for i in t.size():
				var g: float = m.giri[i]
				if g > deg_to_rad(40.0) and g < deg_to_rad(300.0):
					alto[k] = maxf(alto[k], t[i].bacino_h)
					mani[k] = maxf(mani[k], t[i].mani)
		note("lato %+d: bacino fino a %.2f m (veronica %.2f), mani fino a %.2f m sopra il bacino (veronica %.2f)" % [int(lato),
			alto.c, alto.v, mani.c, mani.v])
		check(float(alto.c) > 0.96, "saltello a metà giro (bacino a %.2f m)" % alto.c)
		check(float(alto.c) > float(alto.v) + 0.08, "più alta della veronica, che gira accovacciata")
		check(float(mani.c) > float(mani.v) + 0.1, "braccia più alte della veronica")
	return done()


func test_pallone_coperto_a_meta_giro_e_lasciato_avanti() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := TGT.traccia(ID, TD.first_ok_seed(), lato)
		var m := TGT.misura(tr)
		var coperto := 0
		var meta := 0
		var appoggi := 0
		var prima := {"l": true, "r": true}
		for i in tr.size():
			var c: Dictionary = tr[i]
			var g: float = m.giri[i]
			if g > deg_to_rad(150.0) and g < deg_to_rad(210.0):
				meta += 1
				if (c.palla as Vector3).distance_to(c.dif) > (c.pos as Vector3).distance_to(c.dif):
					coperto += 1
			for s: String in ["l", "r"]:
				var terra: bool = c.piedi[s].terra
				if terra and not prima[s] and g > 0.3 and g < TAU - 0.5:
					appoggi += 1
				prima[s] = terra
		check(meta > 0 and coperto * 10 >= meta * 7, "a metà giro il corpo copre il pallone (%d su %d)" % [coperto, meta])
		check(appoggi >= 2, "i piedi appoggiano durante il giro (%d)" % appoggi)
	return done()


func test_in_corsa_corpi_staccati_e_pallone_che_torna_al_motore() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := TGT.traccia(ID, TD.first_ok_seed(), lato)
		var v_min := INF
		var dentro := 0.0
		var salto := 0.0
		var scivola := 0.0
		for i in range(1, tr.size()):
			var c: Dictionary = tr[i]
			if c.t > 0.2 and c.go < 0.5:
				v_min = minf(v_min, (c.vel as Vector3).length())
			dentro = maxf(dentro, c.dentro)
			salto = maxf(salto, (c.palla as Vector3).distance_to(tr[i - 1].palla) / DT - (c.vel as Vector3).length())
			for s: String in ["l", "r"]:
				if c.piedi[s].terra and tr[i - 1].piedi[s].terra:
					scivola = maxf(scivola, (c.piedi[s].pos as Vector3).distance_to(tr[i - 1].piedi[s].pos))
		var u: Dictionary = tr.back()
		check(v_min >= 1.8, "non si ferma mai (minimo %.1f m/s)" % v_min)
		check(dentro <= 0.06, "corpi staccati (%.2f m)" % dentro)
		check(salto < 14.0, "il pallone non salta (%.1f m/s oltre il corpo)" % salto)
		check(scivola < 0.01, "i piedi a terra non scivolano (%.3f m)" % scivola)
		check((u.palla as Vector3).distance_to(u.palla_moto) < 0.05, "alla fine il pallone è quello del motore")
	return done()


func test_gambe_mai_deformate() -> bool:
	var male := TGT.gambe_male(ID)
	check(male.is_empty(), "gambe a posto: %s" % str(male))
	return done()
