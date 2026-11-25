# Maglia di casa e da trasferta (scripts/carriera/divise.gd, Luis 2026-11-24): le due squadre in campo sono sempre ben
# distinguibili; in casa si veste la maglia di casa, l'ospite cambia solo se si confonde.
extends "test_base.gd"

const Dv := preload("res://scripts/carriera/divise.gd")
const Car := preload("res://scripts/carriera/carriera.gd")


func kit_di(k: int) -> Dictionary:
	var c: Array = Car.KITS[k]
	return {"shirt": c[1], "shorts": c[2], "socks": c[1], "crest": {"c1": c[1], "c2": c[2]}}


func test_ogni_squadra_ha_casa_e_trasferta_diverse() -> bool:
	eq(Dv.TRASFERTA.size(), Car.KITS.size(), "una trasferta per ogni colore")
	for k in Car.KITS.size():
		check(not Dv.simili(Dv.casa(k)[0], Dv.trasferta(k)[0]), "%s: trasferta ben diversa dalla maglia di casa" % Car.KITS[k][0])
	return done()


func test_tutte_le_coppie_si_distinguono() -> bool:
	for a in Car.KITS.size():
		for b in Car.KITS.size():
			for casa_mia: bool in [true, false]:
				var mia := {"kit": kit_di(a)}
				var avv := {"kit": kit_di(b)}
				Dv.assegna(mia, a, avv, b, casa_mia)
				var ka: Array = [mia.kit.shirt, mia.kit.shorts, mia.kit.socks]
				var kb: Array = [avv.kit.shirt, avv.kit.shorts, avv.kit.socks]
				check(not Dv.confuse(ka, kb), "%s contro %s (%s): divise che non si confondono (distacco %.0f)" % [Car.KITS[a][0], Car.KITS[b][0], "casa" if casa_mia else "fuori", Dv.distacco(ka, kb)])
				var casa_k: Dictionary = mia.kit if casa_mia else avv.kit
				var casa_i: int = a if casa_mia else b
				eq(casa_k.shirt, Dv.casa(casa_i)[0], "la squadra di casa veste la maglia di casa")
	return done()


func test_ospite_cambia_solo_se_serve() -> bool:
	var mia := {"kit": kit_di(0)} # Rosso
	var avv := {"kit": kit_di(1)} # Blu: si distingue
	Dv.assegna(mia, 0, avv, 1, true)
	eq(avv.kit.shirt, Dv.casa(1)[0], "Blu contro Rosso: in maglia di casa")
	var avv2 := {"kit": kit_di(9)} # Granata: si confonde col rosso
	Dv.assegna(mia, 0, avv2, 9, true)
	check(avv2.kit.shirt != Dv.casa(9)[0], "Granata contro Rosso: cambia maglia")
	eq(avv2.kit.shirt, Dv.NERO, "e non la bianca a righe granata (colori scambiati della biancorossa): la nera")
	var mia3 := {"kit": kit_di(0)}
	var avv3 := {"kit": kit_di(9)}
	Dv.assegna(mia3, 0, avv3, 9, false)
	eq(avv3.kit.shirt, Dv.casa(9)[0], "fuori casa: il Granata padrone di casa in maglia di casa")
	check(mia3.kit.shirt != Dv.casa(0)[0], "e io (Rosso) cambio maglia")
	eq(Dv.indice_di(kit_di(7)), 7, "colore ricavato dallo stemma")
	return done()


# Luis 2026-11-25: "mi trovo contro una squadra biancarossa e la mia seconda maglia è bianca-arancione"
func test_conta_anche_il_secondo_colore() -> bool:
	check(Dv.confuse([0xc8102e, 0xffffff, 0xc8102e], [0xf4f4f4, 0xc8102e, 0xf4f4f4]), "rossa-bianca e bianca-rossa si confondono")
	check(not Dv.confuse([0xc8102e, 0xffffff, 0xc8102e], [0x16161c, 0xe8e8e8, 0x16161c]), "rossa-bianca e nera si distinguono")
	var mia := {"kit": kit_di(0)} # Rosso fuori casa contro il Rosso
	var avv := {"kit": kit_di(0)}
	Dv.assegna(mia, 0, avv, 0, false)
	check(not Dv.simili(mia.kit.shirt, Dv.BIANCO), "contro la biancorossa non vesto bianco a righe rosse")
	check(not Dv.confuse([mia.kit.shirt, mia.kit.shorts], [avv.kit.shirt, avv.kit.shorts]), "e le divise si distinguono")
	return done()
