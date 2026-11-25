# Crescita della rosa coi voti in pagella e metà stagione (crescita_voti.gd, Luis 2026-11-25).
extends "test_base.gd"

const CV := preload("res://scripts/carriera/crescita_voti.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const JS := preload("res://scripts/carriera/js.gd")
const DIR := "user://prove_carriera/"


static func _somma(p: Dictionary) -> int:
	var t := 0
	for k: String in ["vel", "fis", "dri", "tir", "dif", "pas", "por"]:
		t += int(p.get(k, 0))
	return t


static func _gioc(id: int, eta: int, pos := "C") -> Dictionary:
	return {"id": id, "name": "G%d" % id, "pos": pos, "age": eta, "vel": 60, "fis": 60, "dri": 60, "tir": 60,
		"dif": 60, "pas": 60, "por": 12}


func test_sopra_6_cresce_sotto_cala_6_niente() -> bool:
	check(CV.progresso(7.0, 20) > 0.0, "7 = cresce")
	check(CV.progresso(5.0, 20) < 0.0, "5 = cala")
	near(CV.progresso(6.0, 20), 0.0, 1e-9, "6 = niente")
	check(CV.progresso(7.0, 20) > CV.progresso(7.0, 32) * 3.0, "il giovane cresce molto più del vecchio")
	check(absf(CV.progresso(5.0, 33)) > absf(CV.progresso(5.0, 20)) * 2.0, "il vecchio cala di più col voto basso")
	return done()


func test_dopo_partita_muove_le_statistiche_e_salta_il_campione() -> bool:
	var bravo := _gioc(1, 20)
	var scarso := _gioc(2, 32)
	var champ := _gioc(3, 20)
	champ["champ"] = true
	var rosa := [bravo, scarso, champ]
	var voti := {}
	var prog := {}
	var r := JS.rng32(5)
	var prima := [_somma(bravo), _somma(scarso), _somma(champ)]
	for _i in 6:
		CV.dopo_partita(rosa, [{"id": 1, "voto": 8.0}, {"id": 2, "voto": 4.5}, {"id": 3, "voto": 9.0}], voti, prog, r)
	check(_somma(bravo) > prima[0], "voto 8 per 6 partite: sale (%d → %d)" % [prima[0], _somma(bravo)])
	check(_somma(scarso) < prima[1], "voto 4,5 a 32 anni: scende (%d → %d)" % [prima[1], _somma(scarso)])
	eq(_somma(champ), prima[2], "il campione non si muove coi voti")
	near(float(CV.media(voti, 1)), 8.0, 1e-9, "media dei voti")
	check(CV.media(voti, 3) == null, "niente voti del campione")
	check(CV.media(voti, 99) == null, "chi non ha giocato: null")
	return done()


func test_meta_stagione_eta_e_media() -> bool:
	var giovane := _gioc(1, 19)
	var vecchio := _gioc(2, 33)
	var champ := _gioc(3, 25)
	champ["champ"] = true
	var voti := {"1": [21.0, 3], "2": [15.0, 3]}
	var prima := [_somma(giovane), _somma(vecchio), _somma(champ)]
	var righe := CV.meta_stagione([giovane, vecchio, champ], voti, JS.rng32(9))
	eq(giovane.age, 20, "giovane +1 anno")
	eq(vecchio.age, 34, "vecchio +1 anno")
	eq(champ.age, 25, "il campione non cambia età")
	check(_somma(giovane) > prima[0], "giovane con media 7 sale")
	check(_somma(vecchio) < prima[1], "vecchio con media 5 scende")
	eq(_somma(champ), prima[2], "campione invariato")
	eq(righe.size(), 2, "righe solo per gli altri")
	check(voti.is_empty(), "voti azzerati per la metà dopo")
	check(CV.punti_meta(6.0, 20) > 0 and CV.punti_meta(6.0, 34) < 0, "con la media 6 decide l'età")
	return done()


func test_carriera_meta_stagione_alla_nona_giornata() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + "crescita_voti.json"
	Salv.cancella(c.percorso)
	c.create("Prova Voti", 3, 77)
	var ch: Dictionary = c.addChampion({"name": "Campione", "pos": "A", "look": {}, "num": 10})
	var eta_ch: int = ch.age
	var altro: Dictionary = c.s.squad[0] if not c.s.squad[0].get("champ", false) else c.s.squad[1]
	var eta_altro: int = altro.age
	var meta_vista := 0
	for g in CarrieraScript.ROUNDS:
		var gioc: Array = []
		for id: Variant in c.s.lineup:
			var p: Dictionary = c.player(id)
			gioc.append({"id": p.id, "name": p.name, "pos": p.pos, "champ": p.get("champ", false), "conti": {"passaggi": 10}})
		var res := c.finishMatch(1, 0)
		res = c.dopoPartita(res, {"gol_a": 1, "gol_b": 0, "me": 0, "conteggi": {}, "tabellino": {"giocatori": gioc}})
		if res.has("meta_stagione"):
			meta_vista += 1
			eq(g, CarrieraScript.ROUNDS / 2 - 1, "metà stagione dopo la 9ª partita")
		check(res.has("voti_crescita"), "voti della partita registrati")
	eq(meta_vista, 1, "una sola metà stagione a stagione")
	eq(int(ch.age), eta_ch, "il campione non invecchia nemmeno a fine stagione")
	eq(int(altro.age), eta_altro + 1, "gli altri: +1 anno a stagione (a metà, non anche alla fine)")
	return done()
