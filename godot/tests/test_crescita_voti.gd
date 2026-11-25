# Crescita della rosa coi voti in pagella e metà stagione (crescita_voti.gd, Luis 2026-11-25).
extends "test_base.gd"

const CV := preload("res://scripts/carriera/crescita_voti.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const JS := preload("res://scripts/carriera/js.gd")
const Sotto := preload("res://sim/sottostat.gd")
const DIR := "user://prove_carriera/"


static func _somma(p: Dictionary) -> int:
	var t := 0
	for k: String in ["vel", "fis", "dri", "tir", "dif", "pas", "por"]:
		t += int(p.get(k, 0))
	return t


static func _gioc(id: int, eta: int, pos := "C") -> Dictionary:
	return {"id": id, "name": "G%d" % id, "pos": pos, "age": eta, "vel": 60, "fis": 60, "dri": 60, "tir": 60,
		"dif": 60, "pas": 60, "por": 12}


func test_dopo_partita_solo_voti_niente_statistiche() -> bool:
	var bravo := _gioc(1, 20)
	var champ := _gioc(3, 20)
	champ["champ"] = true
	var voti := {}
	var prima := [_somma(bravo), _somma(champ)]
	for _i in 6:
		CV.dopo_partita([bravo, champ], [{"id": 1, "voto": 8.0}, {"id": 3, "voto": 9.0}], voti)
	eq(_somma(bravo), prima[0], "le statistiche non cambiano dopo la partita (solo a metà stagione)")
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
	var righe := CV.meta_stagione([giovane, vecchio, champ], voti, JS.rng32(9), func(p: Dictionary) -> int: return _somma(p))
	eq(giovane.age, 20, "giovane +1 anno")
	eq(vecchio.age, 34, "vecchio +1 anno")
	eq(champ.age, 25, "il campione non cambia età")
	check(_somma(giovane) > prima[0], "giovane con media 7 sale")
	check(_somma(vecchio) < prima[1], "vecchio con media 5 scende")
	eq(_somma(champ), prima[2], "campione invariato")
	eq(righe.size(), 2, "righe solo per gli altri")
	check(int(righe[0].dopo) > int(righe[0].prima), "riga: valutazione prima e dopo")
	check(not (righe[0].cambi as Dictionary).is_empty(), "riga: sotto-statistiche cambiate")
	check(Sotto.ha(giovane), "sotto-statistiche create")
	check(voti.is_empty(), "voti azzerati per la metà dopo")
	check(CV.punti_meta(6.0, 20) > 0 and CV.punti_meta(6.0, 34) < 0, "con la media 6 decide l'età")
	return done()


func test_sotto_statistiche_media_uguale_alla_grande() -> bool:
	for sd in 30:
		var p := _gioc(sd, 25, ["P", "D", "C", "A"][sd % 4])
		p["tir"] = 40 + sd
		p["por"] = 70 if p.pos == "P" else 12
		var grandi := {}
		for g: String in Sotto.GRUPPI:
			grandi[g] = p[g]
		Sotto.crea(p, JS.rng32(sd))
		var diverse := false
		for g: String in Sotto.GRUPPI:
			var somma := 0
			for k: String in Sotto.GRUPPI[g]:
				somma += int(p.sub[k])
				diverse = diverse or int(p.sub[k]) != int(grandi[g])
			eq(somma, int(grandi[g]) * (Sotto.GRUPPI[g] as Array).size(), "somma esatta %s (seme %d)" % [g, sd])
		check(diverse, "le sotto-statistiche non sono tutte uguali")
		Sotto.ricalcola(p)
		for g: String in Sotto.GRUPPI:
			eq(int(p[g]), int(grandi[g]), "la grande non cambia (%s)" % g)
	return done()


func test_carriera_meta_stagione_alla_nona_giornata() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + "crescita_voti.json"
	Salv.cancella(c.percorso)
	c.create("Prova Voti", 3, 77)
	var ch: Dictionary = c.addChampion({"name": "Campione", "pos": "A", "look": {}, "num": 10})
	c.novita()
	var eta_ch: int = ch.age
	var altro: Dictionary = c.s.squad[0] if not c.s.squad[0].get("champ", false) else c.s.squad[1]
	var eta_altro: int = altro.age
	var avv_id: String = c.s.divs[c.div()][0] if c.s.divs[c.div()][0] != "me" else c.s.divs[c.div()][1]
	var avv_prima: Dictionary = c.squadraCpu(c.team(avv_id)).players[3].duplicate(true)
	var meta_vista := 0
	for g in CarrieraScript.ROUNDS:
		var gioc: Array = []
		for id: Variant in c.s.lineup:
			var p: Dictionary = c.player(id)
			gioc.append({"id": p.id, "name": p.name, "pos": p.pos, "champ": p.get("champ", false), "conti": {"passaggi": 10}})
		var stat_prima := _somma(altro)
		var res := c.finishMatch(1, 0)
		res = c.dopoPartita(res, {"gol_a": 1, "gol_b": 0, "me": 0, "conteggi": {}, "tabellino": {"giocatori": gioc}})
		if res.has("meta_stagione"):
			meta_vista += 1
			eq(g, CarrieraScript.ROUNDS / 2 - 1, "metà stagione dopo la 9ª partita")
			check(not (res.meta_stagione.cpu as Array).is_empty(), "anche gli avversari")
			var avv_dopo: Dictionary = c.squadraCpu(c.team(avv_id)).players[3]
			eq(int(avv_dopo.age), int(avv_prima.age) + 1, "avversario: +1 anno dal girone di ritorno")
		elif g > 0:
			eq(_somma(altro), stat_prima, "fuori dalla metà stagione le statistiche non cambiano (giornata %d)" % (g + 1))
	eq(meta_vista, 1, "una sola metà stagione a stagione")
	eq(int(ch.age), eta_ch, "il campione non invecchia nemmeno a fine stagione")
	eq(int(altro.age), eta_altro + 1, "gli altri: +1 anno a stagione (a metà, non anche alla fine)")
	return done()
