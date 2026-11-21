# Statistiche a fine partita: voti in pagella (scripts/partita/voti.gd), mappa dei tiri (mappa_tiri.gd) e
# tabellino raccolto dagli eventi del motore (conta_giocatori.gd), senza toccare il motore.
extends "res://tests/test_base.gd"

const Voti := preload("res://scripts/partita/voti.gd")
const Mappa := preload("res://scripts/partita/mappa_tiri.gd")
const Conta := preload("res://scripts/partita/conta_giocatori.gd")


func test_voto_base_sei() -> bool:
	eq(Voti.voto("C", {}, 1, 1), 6.0, "centrocampista senza fatti, pareggio 1-1")
	eq(Voti.voto("A", {}, 0, 0), 6.0, "attaccante, 0-0: niente porta inviolata per lui")
	eq(Voti.voto("P", {}, 0, 0), 6.5, "portiere, 0-0: porta inviolata +0,5")
	return done()


func test_voto_sale_con_gol_assist_dribbling_contrasti_parate() -> bool:
	eq(Voti.voto("A", {"gol": 2}, 2, 0), 8.5, "doppietta e vittoria 2-0: 6 + 0,5 + 2")
	eq(Voti.voto("C", {"assist": 1, "dribbling": 2}, 1, 0), 7.5, "assist e 2 dribbling, vittoria: 6,5 + 0,6 + 0,4")
	eq(Voti.voto("D", {"contrasti": 4, "subiti": 0}, 1, 0), 8.0, "4 contrasti e porta inviolata: 6,5 + 1 + 0,3 = 7,8")
	eq(Voti.voto("P", {"parate": 3, "subiti": 1}, 1, 1), 6.5, "3 parate e un gol subito, pareggio: 6 + 1,2 − 0,5 = 6,7")
	check(Voti.voto("A", {"gol": 1}, 1, 0) > Voti.voto("A", {}, 1, 0), "un gol alza il voto")
	return done()


func test_voto_scende_con_gol_subiti_e_palle_perse() -> bool:
	eq(Voti.voto("P", {"subiti": 3, "parate": 2}, 0, 3), 5.0, "portiere 0-3 con 2 parate: 6 − 0,5 − 1,5 + 0,8 = 4,8")
	eq(Voti.voto("D", {"subiti": 2}, 1, 2), 5.0, "difensore, 2 gol subiti, sconfitta: 6 − 0,5 − 0,6 = 4,9")
	eq(Voti.voto("A", {"subiti": 2}, 1, 2), 5.5, "l'attaccante non paga i gol subiti")
	eq(Voti.voto("C", {"perse": 5}, 1, 1), 5.5, "5 palle perse: 6 − 0,5")
	check(Voti.punti("C", {"perse": 2}, 1, 1) < Voti.punti("C", {}, 1, 1), "le palle perse tolgono punti")
	return done()


func test_voto_fra_4_e_10_a_mezzi_punti_con_tetti() -> bool:
	eq(Voti.voto("P", {"subiti": 6}, 0, 6), 4.0, "mai sotto 4")
	eq(Voti.voto("A", {"gol": 5, "assist": 2}, 5, 0), 10.0, "mai sopra 10")
	near(Voti.punti("C", {"dribbling": 30}, 1, 1) - Voti.punti("C", {}, 1, 1), 1.0, 0.0001, "dribbling al massimo +1")
	near(Voti.punti("D", {"contrasti": 30}, 1, 1) - Voti.punti("D", {}, 1, 1), 1.25, 0.0001, "contrasti al massimo +1,25")
	near(Voti.punti("P", {"parate": 30}, 1, 1) - Voti.punti("P", {}, 1, 1), 2.0, 0.0001, "parate al massimo +2")
	near(Voti.punti("C", {"perse": 40}, 1, 1) - Voti.punti("C", {}, 1, 1), -1.5, 0.0001, "palle perse al massimo −1,5")
	for p in [3.9, 4.2, 6.24, 6.26, 6.74, 7.76, 9.9, 11.0]:
		var v := Voti.da_punti(p)
		check(v >= 4.0 and v <= 10.0 and is_equal_approx(v * 2.0, roundf(v * 2.0)), "voto %s da %s: tra 4 e 10 a mezzi punti" % [v, p])
	eq(Voti.da_punti(6.26), 6.5, "6,26 → 6,5")
	eq(Voti.da_punti(6.24), 6.0, "6,24 → 6")
	return done()


func test_risultato_conta_un_po() -> bool:
	near(Voti.punti("C", {}, 2, 1) - Voti.punti("C", {}, 1, 1), 0.5, 0.0001, "vittoria +0,5 sul pareggio")
	near(Voti.punti("A", {}, 0, 1) - Voti.punti("A", {}, 1, 1), -0.5, 0.0001, "sconfitta −0,5 sul pareggio")
	return done()


func test_migliore_in_campo_e_campione() -> bool:
	var gioc := [
		{"id": "a", "name": "Uno", "pos": "P", "champ": false, "conti": {"parate": 2}},
		{"id": "b", "name": "Due", "pos": "A", "champ": true, "conti": {"gol": 1, "assist": 1}},
		{"id": "c", "name": "Tre", "pos": "A", "champ": false, "conti": {"gol": 2}},
		{"id": "d", "name": "Quattro", "pos": "C", "champ": false},
	]
	var v := Voti.calcola(gioc, 3, 0)
	eq(v.size(), 4, "un voto per giocatore")
	var migliori := v.filter(func(g: Dictionary) -> bool: return g.migliore)
	eq(migliori.size(), 1, "un solo migliore in campo")
	eq(migliori[0].id, "c", "migliore: la doppietta (8,5 punti contro 8,1)")
	check(v[1].champ, "il campione resta segnato")
	eq(v[0].id, "a", "l'ordine resta quello dato")
	eq(v[3].voto, 6.5, "senza conteggi: base 6 + vittoria")
	check(not gioc[0].has("voto"), "i dati di partenza non cambiano")
	eq(Voti.calcola([], 1, 0).size(), 0, "elenco vuoto: niente voti, niente errori")
	var pari := Voti.calcola([{"id": "x", "pos": "C"}, {"id": "y", "pos": "C"}], 0, 0)
	check(pari[0].migliore and not pari[1].migliore, "a pari punti il primo in elenco")
	eq(Voti.testo(6.5), "6,5", "voto scritto")
	eq(Voti.testo(7.0), "7", "voto intero")
	return done()


func test_mappa_punto_e_squadra_che_attacca_in_alto() -> bool:
	var r := Rect2(10, 20, 64, 100)
	var porta_su := {"team": 0, "x": 0.0, "y": 50.0}
	eq(Mappa.punto(porta_su, 0, r), Vector2(42, 20), "me = 0: la porta avversaria (y = 50) in alto al centro")
	eq(Mappa.punto(porta_su, 1, r), Vector2(42, 120), "me = 1: si gira, y = 50 va in basso")
	eq(Mappa.punto({"x": -32.0, "y": -50.0}, 0, r), Vector2(10, 120), "angolo in basso a sinistra")
	eq(Mappa.punto({"x": 32.0, "y": -50.0}, 1, r), Vector2(10, 20), "me = 1: anche la x si gira")
	eq(Mappa.punto({"x": 99.0, "y": 99.0}, 0, r), Vector2(74, 20), "fuori dal campo: sul bordo")
	var q := Mappa.rettangolo(Vector2(300, 330))
	near(q.size.x / q.size.y, 0.64, 0.0001, "proporzioni vere del campo")
	near(q.size.y, 330.0, 0.0001, "alto quanto lo spazio")
	near(q.position.x, (300.0 - q.size.x) / 2.0, 0.0001, "centrato")
	check(Mappa.pieno({"esito": "gol"}) and not Mappa.pieno({"esito": "parato"}) and not Mappa.pieno({"esito": "fuori"}), "pieno solo il gol")
	var c := Mappa.conta([{"team": 0, "esito": "gol"}, {"team": 0, "esito": "parato"}, {"team": 1, "esito": "fuori"}, {"team": 0, "esito": "boh"}], 0)
	eq(c, {"gol": 1, "parato": 1, "respinto": 0, "fuori": 1, "tiri": 3}, "conta i tiri di una squadra")
	return done()


# giocatore finto per gli eventi scritti a mano
static func _gioc(team: int, i: int, pos: String, x: float = 0.0, y: float = 0.0, champ: bool = false) -> R.Player:
	var p := R.Player.new()
	p.team = team
	p.i = i
	p.pos = pos
	p.name = "G%d%d" % [team, i]
	p.src = {"id": "t%d_%d" % [team, i], "champ": champ, "num": i + 1}
	p.x = x
	p.y = y
	return p


func test_tabellino_dagli_eventi() -> bool:
	var a := _gioc(0, 9, "A", 3.0, 35.0, true)
	var b := _gioc(0, 5, "C", -4.0, 10.0)
	var dif := _gioc(0, 2, "D", 0.0, -30.0)
	var gk := _gioc(1, 0, "P", 0.0, 49.0)
	var o := _gioc(1, 7, "C", 2.0, 20.0)
	var m := {"players": [a, b, dif, gk, o], "events": []}
	var c := Conta.new(0)
	var giro := func(evs: Array) -> void:
		m.events = evs
		c.leggi(m)
	giro.call([{"type": "kick", "p": b, "kind": "pass"}])
	giro.call([{"type": "control", "p": a}])                                   # passaggio riuscito
	giro.call([{"type": "kick", "p": a, "kind": "shot"}, {"type": "save", "p": gk, "catch": true}, {"type": "control", "p": gk}])
	giro.call([{"type": "kick", "p": gk, "kind": "pass"}, {"type": "control", "p": o}])
	giro.call([{"type": "kick", "p": o, "kind": "shot"}, {"type": "goal", "team": 1, "scorer": o, "assist": null, "og": false}])
	giro.call([{"type": "restart", "kind": "kickoff", "team": 0}, {"type": "kick", "p": b, "kind": "pass"}, {"type": "control", "p": o}])  # passaggio preso
	giro.call([{"type": "tackle", "p": dif, "on": o}, {"type": "tackle", "p": o, "on": a}])
	giro.call([{"type": "kick", "p": a, "kind": "volley"}, {"type": "goal", "team": 0, "scorer": a, "assist": b, "og": false}])
	giro.call([{"type": "kick", "p": b, "kind": "header"}, {"type": "out", "kind": "goalkick"}])
	var t := c.tabellino()
	var tiri: Array = t.tiri
	eq(tiri.size(), 4, "quattro tiri sulla mappa")
	eq(tiri.map(func(x: Dictionary) -> String: return x.esito), ["parato", "gol", "gol", "fuori"], "esiti dei tiri")
	eq(tiri[0].team, 0, "squadra di chi tira")
	near(tiri[0].x, 3.0, 0.001, "x di chi tira")
	near(tiri[0].y, 35.0, 0.001, "y di chi tira")
	eq(t.passaggi, [[1, 2], [1, 1]], "passaggi riusciti / tentati per squadra")
	eq(t.me, 0, "squadra della persona")
	var per_id := {}
	for g: Dictionary in t.giocatori:
		per_id[g.id] = g
	eq(per_id.size(), 3, "solo i giocatori della persona")
	check(per_id["t0_9"].champ and per_id["t0_9"].name == "G09" and per_id["t0_9"].pos == "A", "nome, ruolo e campione")
	eq(int(per_id["t0_9"].conti.get("perse", 0)), 1, "contrasto subito = palla persa")
	eq(int(per_id["t0_5"].conti.get("perse", 0)), 1, "passaggio preso dall'avversario = palla persa")
	eq(int(per_id["t0_2"].conti.get("subiti", 0)), 1, "gol subito mentre era in campo")
	eq(int(per_id["t0_2"].conti.get("contrasti", 0)), 1, "contrasto vinto")
	eq(int(per_id["t0_5"].conti.get("assist", 0)), 1, "assist")
	var pg := c.per_giocatore()
	check(not pg.get("t0_9", {}).has("perse") and not pg.get("t0_2", {}).has("subiti"), "per_giocatore (crescita) senza le chiavi nuove")
	eq(int(pg["t0_9"].gol), 1, "per_giocatore conta ancora i gol")
	return done()


func test_tabellino_espulso_non_paga_i_gol_dopo() -> bool:
	var d1 := _gioc(0, 2, "D")
	var d2 := _gioc(0, 3, "D")
	var o := _gioc(1, 9, "A")
	var m := {"players": [d1, d2, o], "events": [{"type": "goal", "team": 1, "scorer": o}]}
	var c := Conta.new(0)
	c.leggi(m)
	d1.off = true
	m.events = [{"type": "goal", "team": 1, "scorer": o}]
	c.leggi(m)
	var g: Array = c.tabellino().giocatori
	eq(int(g[0].conti.get("subiti", 0)), 1, "espulso: solo il gol prima")
	eq(int(g[1].conti.get("subiti", 0)), 2, "in campo: tutti e due")
	return done()


# partita vera del motore: ogni tiro degli eventi finisce sulla mappa con un esito valido, i km crescono
func test_tabellino_partita_vera() -> bool:
	var mt := H.newMatch(31, 60.0, [false, false], H.mkTeam("Casa", 70, 3), H.mkTeam("Fuori", 66, 4))
	var c := Conta.new(0)
	var tiri_eventi := 0
	var gol := [0, 0]
	var guardia := 0
	while mt.half <= 2 and mt.phase != "full" and guardia < 60 * 400:
		mt.step(DT)
		for e: Dictionary in mt.events:
			if e.type == "kick" and Conta.TIRI.has(e.get("kind", "")) and not e.get("clear", false):
				tiri_eventi += 1
			if e.type == "goal":
				gol[int(e.team)] += 1
		c.leggi(mt)
		mt.events.clear()
		guardia += 1
	var t := c.tabellino()
	eq(t.tiri.size(), tiri_eventi, "un punto per ogni tiro")
	var ok := true
	for x: Dictionary in t.tiri:
		ok = ok and Mappa.ESITI.has(x.esito) and absf(x.x) <= 40.0 and absf(x.y) <= 56.0
	check(ok, "esiti e posizioni validi")
	check(Mappa.conta(t.tiri, 0).gol <= gol[0] and Mappa.conta(t.tiri, 1).gol <= gol[1], "gol sulla mappa non più dei gol veri")
	check(float(t.km[0]) > 1.0 and float(t.km[1]) > 1.0, "km corsi per squadra (%s)" % str(t.km))
	eq(t.giocatori.size() >= 11, true, "almeno gli undici della persona")
	check(int(t.passaggi[0][1]) >= int(t.passaggi[0][0]), "riusciti non più dei tentati")
	note("tiri %d, gol %s, passaggi %s, km %s" % [t.tiri.size(), str(gol), str(t.passaggi), str(t.km)])
	return done()
