# Cronaca scritta (scripts/partita/cronaca.gd): evento del motore → frase o niente. Nomi giusti, frasi varie,
# ritmo (poche frasi), esito dei tiri, caso della grafica (seme proprio, il motore non c'entra).
extends "test_base.gd"

const Cronaca := preload("res://scripts/partita/cronaca.gd")


static func _g(nome: String, squadra: int, y: float = 0.0) -> R.Player:
	var p := R.Player.new()
	p.name = nome
	p.team = squadra
	p.y = y
	return p


func test_gol_sempre_col_nome() -> bool:
	var c := Cronaca.new(3, ["Rossi FC", "Blu United"])
	var p := _g("L. Bianchi", 0)
	for i in 10:
		var f := c.leggi({"type": "goal", "team": 0, "scorer": p, "assist": null, "og": false, "minute": 12}, float(i) * 0.1)
		check(f.contains("L. Bianchi"), "gol col nome del marcatore: %s" % f)
		check(not f.contains("{"), "niente segnaposto rimasti: %s" % f)
	eq(c.categoria, "gol", "categoria")
	var a := c.leggi({"type": "goal", "team": 1, "scorer": null, "assist": null, "og": true, "minute": 30}, 50.0)
	eq(c.categoria, "autogol", "autogol")
	check(a.contains("Blu United") or a.contains("Rossi FC"), "autogol con la squadra: %s" % a)
	return done()


func test_esito_dei_tiri() -> bool:
	var c := Cronaca.new(5)
	var tir := _g("M. Verdi", 0, 30.0)
	var gk := _g("P. Neri", 1)
	var dif := _g("D. Gialli", 1)
	c.leggi({"type": "kick", "p": tir, "kind": "shot", "v": 25.0}, 0.0)
	var f := c.leggi({"type": "save", "p": gk, "catch": false}, 0.5)
	check(f.contains("P. Neri"), "parata col portiere: %s" % f)
	eq(c.categoria, "parata", "parata")
	c.leggi({"type": "kick", "p": tir, "kind": "shot", "v": 25.0}, 10.0)
	f = c.leggi({"type": "out", "kind": "goalkick"}, 10.8)
	check(f.contains("M. Verdi"), "tiro fuori col tiratore: %s" % f)
	eq(c.categoria, "fuori", "fuori")
	eq(c.leggi({"type": "out", "kind": "goalkick"}, 30.0), "", "rinvio dal fondo senza tiro: niente")
	c.leggi({"type": "kick", "p": tir, "kind": "shot", "v": 25.0}, 40.0)
	f = c.leggi({"type": "block", "p": dif, "hard": true}, 40.3)
	check(f.contains("M. Verdi") and f.contains("D. Gialli"), "occasione respinta: %s" % f)
	c.leggi({"type": "kick", "p": tir, "kind": "shot", "v": 25.0}, 60.0)
	f = c.leggi({"type": "post"}, 60.4)
	check(f.contains("M. Verdi"), "palo col tiratore: %s" % f)
	f = c.leggi({"type": "save", "p": gk, "catch": true}, 90.0)
	check(f.contains("P. Neri") and not f.contains("M. Verdi"), "parata senza tiro ricordato: %s" % f)
	return done()


func test_colpo_di_testa_vicino_alla_porta_e_un_tiro() -> bool:
	check(Cronaca.e_tiro({"kind": "header", "p": _g("A", 0, 42.0)}), "testa vicino alla porta avversaria (squadra 0)")
	check(Cronaca.e_tiro({"kind": "volley", "p": _g("A", 1, -40.0)}), "al volo vicino alla porta avversaria (squadra 1)")
	check(not Cronaca.e_tiro({"kind": "header", "p": _g("A", 0, -42.0)}), "testa nella propria area: no")
	check(not Cronaca.e_tiro({"kind": "header", "clear": true, "p": _g("A", 0, 42.0)}), "rinvio di testa: no")
	check(not Cronaca.e_tiro({"kind": "ground", "p": _g("A", 0, 42.0)}), "passaggio: no")
	return done()


func test_poche_frasi() -> bool:
	var c := Cronaca.new(7)
	var a := _g("A. Uno", 0)
	var b := _g("B. Due", 1)
	# un dribbling riuscito ogni mezzo secondo per un minuto: al massimo una frase ogni PAUSA s
	var n := 0
	for i in 120:
		if c.leggi({"type": "dribble", "p": a, "o": b, "ok": true}, i * 0.5) != "":
			n += 1
	note("dribbling: %d frasi in 60 s" % n)
	check(n >= 3 and n <= int(60.0 / Cronaca.PAUSA) + 1, "poche frasi (%d)" % n)
	# subito dopo una frase, le cose piccole aspettano; quelle importanti dopo PAUSA_FORTE
	var c2 := Cronaca.new(8)
	c2.leggi({"type": "goal", "team": 0, "scorer": a, "assist": null, "og": false, "minute": 3}, 0.0)
	eq(c2.leggi({"type": "dribble", "p": a, "o": b, "ok": true}, 1.0), "", "piccola subito dopo: niente")
	eq(c2.leggi({"type": "post"}, 1.0), "", "importante troppo presto: niente")
	check(c2.leggi({"type": "post"}, Cronaca.PAUSA_FORTE + 0.1) != "", "importante dopo la pausa corta")
	eq(c.leggi({"type": "dribble", "p": a, "o": b, "ok": false}, 999.0), "", "dribbling fallito: niente")
	eq(c.leggi({"type": "tackle", "p": a, "slide": true}, 999.0), "", "contrasto a vuoto: niente")
	return done()


func test_frasi_varie_e_mai_uguali_di_fila() -> bool:
	var c := Cronaca.new(11)
	var p := _g("R. Tessari", 0)
	var viste := {}
	var prima := ""
	for i in 40:
		var f := c.leggi({"type": "goal", "team": 0, "scorer": p, "assist": null, "og": false, "minute": i}, i * 10.0)
		viste[f] = true
		check(f != prima, "due volte di fila la stessa frase: %s" % f)
		prima = f
	check(viste.size() >= 4, "almeno 4 frasi diverse per il gol (%d)" % viste.size())
	# stesso seme → stesse frasi (il caso è della cronaca, non del motore)
	var x := Cronaca.new(99)
	var y := Cronaca.new(99)
	for i in 10:
		var e := {"type": "goal", "team": 0, "scorer": p, "assist": null, "og": false, "minute": i}
		eq(x.leggi(e, i * 10.0), y.leggi(e, i * 10.0), "stesso seme, stessa frase")
	return done()


func test_falli_e_cartellini() -> bool:
	var c := Cronaca.new(13, ["Casa", "Ospiti"])
	var a := _g("F. Duro", 1)
	var b := _g("G. Svelto", 0)
	var f := c.leggi({"type": "foul", "by": a, "on": b, "card": "red", "pen": false}, 0.0)
	check(f.contains("F. Duro"), "rosso: %s" % f)
	eq(c.categoria, "rosso", "rosso")
	f = c.leggi({"type": "foul", "by": a, "on": b, "card": null, "pen": true}, 10.0)
	eq(c.categoria, "rigore", "rigore")
	check(f.contains("Casa") or f.contains("F. Duro"), "rigore: %s" % f)
	f = c.leggi({"type": "foul", "by": a, "on": b, "card": "yellow", "pen": false}, 20.0)
	eq(c.categoria, "giallo", "giallo")
	return done()


func test_cronaca_di_una_partita_vera() -> bool:
	# IA contro IA per 4 minuti di gioco: eventi veri del motore, frasi pulite e non troppe
	var m := H.newMatch(21, 9999.0, [false, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))
	var c := Cronaca.new(4, ["Squadra A", "Squadra B"])
	var frasi: Array = []
	var cat := {}
	for i in 60 * 240:
		m.step(DT)
		for e: Dictionary in m.events:
			var f := c.leggi(e, m.time)
			if f != "":
				frasi.append(f)
				cat[c.categoria] = int(cat.get(c.categoria, 0)) + 1
		m.events.clear()
	note("%d frasi in 240 s: %s" % [frasi.size(), cat])
	check(frasi.size() >= 4, "qualcosa si dice")
	check(frasi.size() <= 240 / 2, "non una frase ogni secondo")
	for f: String in frasi:
		check(not f.contains("{") and f.strip_edges() != "", "frase pulita: %s" % f)
	return done()


# Rosa e tattica: "Cambio: entra X, esce Y", più cambi insieme nella stessa riga
func test_cambio() -> bool:
	var c := Cronaca.new(3, ["Rossi", "Blu"])
	var p := R.Player.new()
	p.name = "Lodi"
	var q := R.Player.new()
	q.name = "Neri"
	eq(c.leggi({"type": "sub", "p": p, "fuori": "Pedretti"}, 10.0), "Cambio: entra Lodi, esce Pedretti", "un cambio")
	eq(c.leggi({"type": "sub", "p": q, "fuori": "Bianchi"}, 10.0), "Cambio: entra Lodi, esce Pedretti · entra Neri, esce Bianchi", "due cambi insieme")
	eq(c.leggi({"type": "sub", "p": q, "fuori": "Verdi"}, 30.0), "Cambio: entra Neri, esce Verdi", "un cambio dopo")
	return done()
