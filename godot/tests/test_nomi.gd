# Nomi sopra i giocatori (scripts/partita/nomi_giocatori.gd, Luis 2026-11-26): nomi brevi, scelta delle scritte
# (portatore e controllato prima, niente sovrapposizioni né pallone coperto), regola del modo "tutti" (rallenty: i
# miei; in gioco: solo il portatore, Luis 2026-11-27), impostazione salvata e letta.
extends "test_base.gd"

const Nomi := preload("res://scripts/partita/nomi_giocatori.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const PERCORSO := "user://prove_carriera/nomi.json"


# vista finta vista dall'alto: 8 px per metro, centro dello schermo sul centro del campo
class VistaAlto:
	extends RefCounted
	func world_to_screen(x: float, y: float, h: float) -> Vector3:
		return Vector3(195.0 + x * 8.0, 422.0 - y * 8.0 - h * 8.0, 1.0)


func test_nomi_brevi_cognome_e_iniziale_se_doppio() -> bool:
	var g := [{"name": "L. Ferrante", "team": 0}, {"name": "M. Ferrante", "team": 0}, {"name": "A. Ferrante", "team": 1},
		{"name": "G. Neri", "team": 0}, {"name": "Rossi", "team": 1}, {"name": "Massimiliano Bartolomei", "team": 1}]
	var n := Nomi.nomi_brevi(g)
	eq(n[0], "L. Ferrante", "due Ferrante nella stessa squadra: iniziale")
	eq(n[1], "M. Ferrante", "... anche l'altro")
	eq(n[2], "Ferrante", "un Ferrante solo nell'altra squadra: solo il cognome")
	eq(n[3], "Neri", "cognome")
	eq(n[4], "Rossi", "nome di una parola")
	eq(n[5], "Bartolomei", "nome lungo senza iniziale: l'ultima parola")
	return done()


func test_modo_valido_e_predefinito() -> bool:
	eq(Nomi.modo_valido("pallone"), "pallone", "pallone")
	eq(Nomi.modo_valido("nessuno"), "nessuno", "nessuno")
	eq(Nomi.modo_valido(null), "tutti", "mancante: tutti")
	eq(Nomi.modo_valido("boh"), "tutti", "strano: tutti")
	eq(CarrieraScript.SETTINGS_DEFAULT.get("nomi"), "tutti", "chiave nuova del salvataggio, predefinita tutti")
	return done()


func _c(testo: String, x: float, y: float, rango: int, dist: float, team: int = 0, portatore: bool = false) -> Dictionary:
	return {"testo": testo, "pos": Vector2(x, y), "dim": 11.0, "larg": 50.0, "rango": rango, "dist": dist, "alfa": 1.0,
		"col": Color.RED, "team": team, "portatore": portatore}


func _testi(v: Array) -> Array:
	return v.map(func(c: Dictionary) -> String: return c.testo)


func test_scegli_rispetta_modo_sovrapposizioni_e_pallone() -> bool:
	var cand := [_c("Altro", 100, 200, 2, 20.0), _c("Vicino", 110, 203, 1, 3.0), _c("Portatore", 300, 200, 0, 0.0, 0, true),
		_c("Sopra", 305, 205, 2, 1.0), _c("Lontano", 100, 400, 2, 30.0), _c("Sulpallone", 200, 600, 1, 2.0)]
	var palla := Rect2(190, 590, 12, 12)
	var tutti := Nomi.scegli(cand, "tutti", palla, true, 0)
	eq(_testi(tutti), ["Portatore", "Vicino", "Lontano"], "rallenty: prima il portatore, poi chi è vicino al pallone; saltati chi si sovrappone e chi copre il pallone")
	var solo := Nomi.scegli(cand, "pallone", palla, false, 0)
	eq(solo.size(), 1, "solo pallone e controllato: una scritta")
	eq(solo[0].testo, "Portatore", "... quella del portatore")
	eq(Nomi.scegli(cand, "nessuno", palla, true, 0), [], "nessuno: niente scritte")
	var doppio := [_c("Portatore", 100, 200, 0, 0.0, 0, true), _c("Controllato", 102, 201, 0, 1.0)]
	eq(Nomi.scegli(doppio, "tutti", Rect2(), true, 0).size(), 2, "rallenty: portatore e controllato si scrivono sempre")
	eq(Nomi.scegli(doppio, "pallone", Rect2(), false, 0).size(), 2, "solo pallone e controllato: anche fuori dal rallenty")
	return done()


func test_tutti_rallenty_solo_i_miei_in_gioco_solo_il_portatore() -> bool:
	var cand := [_c("Mio", 100, 200, 2, 20.0, 0), _c("MioCtrl", 100, 300, 0, 5.0, 0), _c("Loro", 300, 200, 2, 8.0, 1),
		_c("LoroPort", 300, 400, 0, 0.0, 1, true), _c("Mio2", 200, 500, 1, 4.0, 0)]
	eq(_testi(Nomi.scegli(cand, "tutti", Rect2(), true, 0)), ["MioCtrl", "Mio2", "Mio"], "rallenty: solo i giocatori della mia squadra")
	eq(_testi(Nomi.scegli(cand, "tutti", Rect2(), true, 1)), ["LoroPort", "Loro"], "rallenty con l'altra squadra come me: i suoi")
	eq(_testi(Nomi.scegli(cand, "tutti", Rect2(), false, 0)), ["LoroPort"], "in gioco: solo il portatore, anche avversario")
	var senza := cand.filter(func(c: Dictionary) -> bool: return not c.portatore)
	eq(Nomi.scegli(senza, "tutti", Rect2(), false, 0), [], "in gioco col pallone di nessuno: nessun nome")
	eq(_testi(Nomi.scegli(cand, "pallone", Rect2(), false, 0)), ["LoroPort", "MioCtrl"], "solo pallone e controllato: sempre tutti e due")
	return done()


func test_in_partita_nomi_presenti_o_assenti_secondo_la_scelta() -> bool:
	var m := H.newMatch(3, 150.0, [true, false], H.mkTeam("A", 60.0, 8), H.mkTeam("B", 60.0, 18))
	var v := VistaAlto.new()
	var n := Nomi.new()
	n.modo = "tutti"
	n.aggiorna(m, 0, v, null, true)
	var voci: Array = n.voci()
	check(voci.size() >= 6, "rallenty: molti nomi (%d)" % voci.size())
	check(voci.all(func(c: Dictionary) -> bool: return c.team == 0), "rallenty: solo la mia squadra")
	var ctrl: Object = m.ctrl[0]
	var nome_ctrl := Nomi.cognome(str(ctrl.src.get("name", ctrl.name)) if ctrl.src is Dictionary else str(ctrl.name))
	check(voci.any(func(c: Dictionary) -> bool: return str(c.testo).ends_with(nome_ctrl) and c.rango == 0), "c'è il nome del controllato (%s)" % nome_ctrl)
	for i in voci.size():
		for j in range(i + 1, voci.size()):
			if voci[i].rango > 0 or voci[j].rango > 0:
				check(not Nomi.rettangolo(voci[i]).intersects(Nomi.rettangolo(voci[j])), "nomi che non si sovrappongono: %s / %s" % [voci[i].testo, voci[j].testo])
	# in gioco normale: solo il portatore (di qualunque squadra), niente se il pallone non è di nessuno
	var portatore: Object = m.players[15]
	m.ball.owner = portatore
	n.aggiorna(m, 0, v, null, false)
	eq(n.voci().size(), 1, "in gioco: un nome solo")
	if n.voci().size() == 1:
		check(n.voci()[0].portatore and n.voci()[0].team == int(portatore.team), "... quello del portatore (squadra %d)" % portatore.team)
	m.ball.owner = null
	n.aggiorna(m, 0, v, null, false)
	eq(n.voci().size(), 0, "in gioco col pallone di nessuno: nessun nome")
	m.ball.owner = portatore
	n.modo = "pallone"
	n.aggiorna(m, 0, v)
	eq(n.voci().size(), 2, "solo pallone e controllato: portatore e controllato (%d)" % n.voci().size())
	n.modo = "nessuno"
	n.aggiorna(m, 0, v, null, true)
	eq(n.voci().size(), 0, "nessuno: niente nomi")
	n.free()
	return done()


func test_impostazione_salvata_e_letta() -> bool:
	DirAccess.make_dir_recursive_absolute("user://prove_carriera/")
	var c := CarrieraScript.new()
	c.percorso = PERCORSO
	c.create("Prova", 1, 4242)
	eq(c.s.settings.get("nomi"), "tutti", "carriera nuova: tutti")
	c.s.settings.nomi = "pallone"
	c.save()
	var c2 := CarrieraScript.new()
	c2.percorso = PERCORSO
	c2.load()
	eq(c2.s.settings.get("nomi"), "pallone", "scelta salvata e riletta")
	# salvataggio vecchio, senza la chiave: torna il predefinito
	var dati: Dictionary = JSON.parse_string(Salv.leggi_file(PERCORSO))
	(dati.carriera.settings as Dictionary).erase("nomi")
	var f := FileAccess.open(PERCORSO, FileAccess.WRITE)
	f.store_string(JSON.stringify(dati))
	f.close()
	var c3 := CarrieraScript.new()
	c3.percorso = PERCORSO
	c3.load()
	eq(c3.s.settings.get("nomi"), "tutti", "salvataggio vecchio: tutti")
	c.reset()
	return done()
