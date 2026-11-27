# Ruoli specifici e moduli (Luis 2026-11-26, sim/ruoli.gd):
# - tabella dei ruoli per posto: ogni modulo ha 11 ruoli, del gruppo giusto e dal lato giusto del campo;
# - compatibilità e malus fuori ruolo (Ruoli.fattore, C.effStats): chi non ha `ruolo` gioca come prima;
# - salvataggio vecchio (giocatori senza `ruolo`): ruolo e seconda scelta assegnati, statistiche e titolari intatti;
# - giocatori generati (rosa nuova, CPU, campione): statistiche coerenti col ruolo, valutazione uguale a prima;
# - autoLineup mette ognuno nel suo ruolo; il 3-5-2 nuovo solo nelle squadre del gioco ("moduli").
extends "test_base.gd"

const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const Ruoli := preload("res://sim/ruoli.gd")
const Sotto := preload("res://sim/sottostat.gd")
const JS := preload("res://scripts/carriera/js.gd")
const DIR := "user://test_ruoli/"
const LUIS := {
	"4-4-2": "TS DC DC TD ES CC CC ED ATT ATT",
	"4-3-3": "TS DC DC TD CC CC CC AS ATT AD",
	"3-5-2": "DC DC DC ES CDC COC CDC ED ATT ATT",
	"4-2-3-1": "TS DC DC TD CDC CDC ES COC ED ATT",
	"4-5-1": "TS DC DC TD ES CC CDC CC ED ATT",
	"3-4-3": "DC DC DC ES CC CC ED AS ATT AD",
	"5-3-2": "TS DC DC DC TD CC CDC CC ATT ATT",
	"4-1-4-1": "TS DC DC TD CDC ES CC CC ED ATT",
	"4-2-4": "TS DC DC TD CC CC AS ATT ATT AD",
	"4-3-2-1": "TS DC DC TD CC CC CC ATT ATT ATT",
	"4-2-2-2": "TS DC DC TD CDC CDC COC COC ATT ATT",
	"4-3-3 offensivo": "TS DC DC TD CC CC COC AS ATT AD",
	"4-3-3 difensivo": "TS DC DC TD CDC CC CC AS ATT AD",
	"4-1-2-1-2 largo": "TS DC DC TD CDC ES ED COC ATT ATT",
}


func _nuova(nome_file: String, coi_ruoli := true, seme := 77) -> CarrieraScript:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.ruoli = coi_ruoli
	c.percorso = DIR + nome_file
	Salv.cancella(c.percorso)
	c.create("Prova Ruoli", 2, seme)
	return c


func _gioc(ruolo: String, ruolo2 := "") -> Dictionary:
	var p := {"id": 1, "name": "X", "pos": Ruoli.gruppo(ruolo), "ruolo": ruolo, "age": 25,
		"vel": 60, "tir": 60, "pas": 60, "dri": 60, "dif": 60, "fis": 60, "por": 12, "tes": 60}
	if ruolo2 != "":
		p["ruolo2"] = ruolo2
	return p


func test_tabella_dei_moduli() -> bool:
	eq(C.FORMATIONS.size(), 14, "14 moduli")
	for f: String in C.FORMATIONS:
		check(Ruoli.POSTI.has(f), f + ": ha i ruoli per posto")
		check(LUIS.has(f), f + ": è nella tabella di Luis")
		if not Ruoli.POSTI.has(f) or not LUIS.has(f):
			continue
		var rr: Array = Ruoli.POSTI[f]
		eq(rr.size(), 11, f + ": 11 ruoli")
		eq(" ".join(PackedStringArray(rr.slice(1))), LUIS[f], f + ": i ruoli chiesti da Luis")
		for schema: Array in [C.schema(f, false), C.schema(f, true)]:
			eq(schema.size(), 11, f + ": 11 posti")
			for i in 11:
				var slot: Array = schema[i]
				eq(Ruoli.gruppo(rr[i]), slot[0], "%s posto %d: %s è del gruppo %s" % [f, i, rr[i], slot[0]])
				check(absf(slot[1]) <= 1.0 and slot[2] > 0.0 and slot[2] < 0.75, "%s posto %d dentro il campo" % [f, i])
				var lato := int(Ruoli.LATO.get(rr[i], 0))
				if lato != 0:
					check(slot[1] * lato > 0.3, "%s posto %d: %s dal suo lato (x %.2f)" % [f, i, rr[i], slot[1]])
			for a in 11:
				for b in range(a + 1, 11):
					check(absf(schema[a][1] - schema[b][1]) > 0.15 or absf(schema[a][2] - schema[b][2]) > 0.04, "%s: posti %d e %d non sovrapposti" % [f, a, b])
	eq(C.schema_ruoli("4-2-3-1")[7][0], "ES", "schema_ruoli: ruolo al posto del gruppo")
	return done()


func test_352_nuovo_solo_nel_gioco() -> bool:
	eq(C.schema("3-5-2", false), C.FORMATIONS["3-5-2"], "confronti col JS: il 3-5-2 di sempre")
	var g: Array = C.schema("3-5-2", true)
	check(g[5][2] < C.FORMATIONS["3-5-2"][5][2] and g[7][2] < C.FORMATIONS["3-5-2"][7][2], "gioco: i due mediani più bassi")
	check(g[6][2] > g[4][2] and g[6][2] > C.FORMATIONS["3-5-2"][6][2], "gioco: il trequartista più alto degli esterni")
	var a := H.mkTeam("A", 62, 3, "3-5-2")
	var b := H.mkTeam("B", 62, 5, "3-5-2")
	b["moduli"] = true
	var m := H.newMatch(4, 10.0, [false, false], a, b)
	eq(m.players[6].by, C.FORMATIONS["3-5-2"][6][2], "squadra senza \"moduli\": posti del web")
	eq(m.players[11 + 6].by, g[6][2], "squadra del gioco: posti nuovi")
	eq(m.players[11 + 6].ruolo, "COC", "il posto sa il suo ruolo")
	H.disposeAll()
	return done()


func test_compatibili_e_malus() -> bool:
	for coppia: Array in [["TS", "ES"], ["TD", "ED"], ["ES", "AS"], ["ED", "AD"], ["ATT", "COC"], ["DC", "CDC"]]:
		eq(Ruoli.fattore(_gioc(coppia[0]), coppia[1]), Ruoli.F_COMPATIBILE, "%s fa %s" % coppia)
		eq(Ruoli.fattore(_gioc(coppia[1]), coppia[0]), Ruoli.F_COMPATIBILE, "%s fa %s" % [coppia[1], coppia[0]])
	eq(Ruoli.fattore(_gioc("CC"), "COC"), Ruoli.F_COMPATIBILE, "il CC può fare il COC")
	eq(Ruoli.fattore(_gioc("COC"), "CC"), Ruoli.F_GRUPPO, "il COC non fa il CC")
	for coppia: Array in [["TS", "AS"], ["TS", "AD"], ["TD", "AD"], ["TD", "AS"], ["AS", "TS"], ["AD", "TD"], ["AS", "TD"]]:
		eq(Ruoli.fattore(_gioc(coppia[0]), coppia[1]), Ruoli.F_LONTANO, "%s non fa mai %s: malus da linea lontana" % coppia)
		check(Ruoli.vietato(_gioc(coppia[0]), coppia[1]), "%s su %s: vietato" % coppia)
	eq(Ruoli.fattore(_gioc("TS", "AS"), "AS"), Ruoli.F_LONTANO, "terzino con l'ala come seconda (salvataggio di prima): niente sconto")
	check(not Ruoli.vietato(_gioc("TS"), "ES") and not Ruoli.vietato(_gioc("AS"), "ES"), "l'esterno sì")
	eq(Ruoli.fattore(_gioc("DC"), "DC"), 1.0, "nel suo ruolo niente malus")
	eq(Ruoli.fattore(_gioc("DC", "TD"), "TD"), Ruoli.F_SECONDA, "seconda scelta: quasi niente")
	eq(Ruoli.fattore(_gioc("TS"), "TD"), Ruoli.F_SPECCHIO, "altra fascia")
	eq(Ruoli.fattore(_gioc("AS"), "DC"), Ruoli.F_LONTANO, "ala in difesa centrale: molto penalizzata")
	eq(Ruoli.fattore(_gioc("ATT"), "P"), Ruoli.F_PORTIERE, "in porta come prima")
	check(Ruoli.F_SECONDA > Ruoli.F_COMPATIBILE and Ruoli.F_COMPATIBILE > Ruoli.F_FUORI and Ruoli.F_FUORI > Ruoli.F_SPECCHIO
		and Ruoli.F_SPECCHIO > Ruoli.F_GRUPPO and Ruoli.F_GRUPPO > Ruoli.F_VICINO and Ruoli.F_VICINO > Ruoli.F_LONTANO
		and Ruoli.F_LONTANO > Ruoli.F_PORTIERE, "malus in ordine di distanza")
	for r: String in Ruoli.TUTTI:
		if r == "P":
			continue
		check(Ruoli.SECONDE.has(r) and not (Ruoli.SECONDE[r] as Array).has(r), r + ": ha seconde scelte diverse da sé")
		for r2: String in Ruoli.SECONDE[r]:
			check(not (Ruoli.VIETATI.get(r, []) as Array).has(r2), "%s: mai %s come seconda scelta" % [r, r2])
		var somma := 0.0
		for k: String in Ruoli._pesi(r):
			somma += float(Ruoli._pesi(r)[k])
		near(somma, 1.0, 1e-9, r + ": i pesi della valutazione sommano 1")
	# nel motore
	var ala := _gioc("AS", "ES")
	eq(C.effStats(ala, "A", "AS").dri, 60.0, "motore: nel suo ruolo statistiche piene")
	eq(C.effStats(ala, "C", "ES").dri, 60.0 * Ruoli.F_SECONDA, "motore: seconda scelta")
	eq(C.effStats(ala, "D", "DC").dif, 60.0 * Ruoli.F_LONTANO, "motore: ala in difesa centrale")
	eq(C.effStats(ala, "D", "DC").vel, 60.0, "motore: la velocità non ha malus")
	eq(C.effStats(ala, "P", "P").por, 12.0, "motore: in porta al massimo 25")
	var vecchio := {"pos": "A", "vel": 60, "tir": 60, "pas": 60, "dri": 60, "dif": 60, "fis": 60, "por": 12}
	eq(C.effStats(vecchio, "D", "DC").dif, 60.0 * 0.82, "senza `ruolo`: il malus di sempre (POSPEN)")
	eq(C.effStats(vecchio, "A", "AS").tir, 60.0, "senza `ruolo`: nel suo gruppo niente malus")
	eq(CarrieraScript.overallAs(vecchio, "AS"), CarrieraScript.overallAs(vecchio, "A"), "senza `ruolo`: valutazione del gruppo")
	return done()


func test_salvataggio_vecchio_riceve_i_ruoli() -> bool:
	var vecchia := _nuova("vecchio.json", false)
	vecchia.addChampion({"name": "Campione", "pos": "C", "look": {}, "num": 10})
	vecchia.s.formation = "4-3-3"
	vecchia.autoLineup()
	var foto := {}
	for p: Dictionary in vecchia.s.squad:
		check(not p.has("ruolo"), "carriera senza ruoli: nessun campo `ruolo`")
		p.erase("sub") # salvataggio di prima delle statistiche dettagliate
		foto[p.id] = {"o": CarrieraScript.overall(p), "pot": int(p.pot), "v": CarrieraScript.value(p)}
		for k: String in CarrieraScript.STAT_KEYS + ["tes", "pos", "age"]:
			foto[p.id][k] = p[k]
	var titolari: Array = vecchia.s.lineup.duplicate()
	check(vecchia.save(), "salvato")
	var c := CarrieraScript.new()
	c.percorso = vecchia.percorso
	check(c.load(), "il salvataggio vecchio si carica")
	eq(c.s.lineup, titolari, "titolari intatti")
	var FR: Array = Ruoli.POSTI["4-3-3"]
	var scarto := 0.0
	var massimo := 0
	var visti := {}
	for p: Dictionary in c.s.squad:
		var f: Dictionary = foto[p.id]
		check(Ruoli.valido(p.get("ruolo")) and Ruoli.gruppo(p.ruolo) == p.pos, "%s: ruolo del suo gruppo (%s, %s)" % [p.name, p.get("ruolo"), p.pos])
		visti[p.get("ruolo")] = true
		if p.pos == "P":
			check(not p.has("ruolo2"), "il portiere non ha seconda scelta")
		else:
			check(Ruoli.valido(p.get("ruolo2")) and p.ruolo2 != p.ruolo and p.ruolo2 != "P", "%s: seconda scelta diversa dal ruolo" % p.name)
		for k: String in CarrieraScript.STAT_KEYS + ["tes", "pos", "age"]:
			eq(p[k], f[k], "%s: %s non cambia" % [p.name, k])
		var i: int = titolari.find(p.id)
		if i >= 0 and Ruoli.gruppo(FR[i]) == p.pos:
			eq(p.ruolo, FR[i], "%s: titolare, prende il ruolo del suo posto" % p.name)
		var d: int = CarrieraScript.overall(p) - int(f.o)
		scarto += d
		massimo = maxi(massimo, absi(d))
		eq(int(p.pot) - CarrieraScript.overall(p), int(f.pot) - int(f.o), "%s: stesso margine di crescita" % p.name)
		check(CarrieraScript.value(p) < int(f.v) * 2 and CarrieraScript.value(p) * 2 > int(f.v), "%s: il valore non si stravolge" % p.name)
	scarto /= c.s.squad.size()
	note("valutazione dopo la migrazione: scarto medio %.2f, massimo %d" % [scarto, massimo])
	check(absf(scarto) <= 1.5, "valutazione media della rosa quasi uguale (%.2f)" % scarto)
	check(massimo <= 6, "nessuna valutazione stravolta (massimo %d)" % massimo)
	check(visti.size() >= 8, "rosa assortita: %s" % str(visti.keys()))
	# ricaricando non cambia più niente
	var ruoli_ora := {}
	for p: Dictionary in c.s.squad:
		ruoli_ora[p.id] = [p.ruolo, p.get("ruolo2")]
	check(c.save(), "salvato coi ruoli")
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "ricaricato")
	for p: Dictionary in c2.s.squad:
		eq([p.ruolo, p.get("ruolo2")], ruoli_ora[p.id], "%s: ruoli stabili" % p.name)
	# ruolo sbagliato nel file: si rimette a posto
	c2.s.squad[3]["ruolo"] = "XYZ"
	c2.s.squad[4]["ruolo"] = "P" if c2.s.squad[4].pos != "P" else "DC"
	c2.save()
	var c3 := CarrieraScript.new()
	c3.percorso = c.percorso
	check(c3.load(), "ricaricato col ruolo sbagliato")
	for i: int in [3, 4]:
		var p: Dictionary = c3.s.squad[i]
		check(Ruoli.valido(p.get("ruolo")) and Ruoli.gruppo(p.ruolo) == p.pos, "ruolo sbagliato corretto (%s)" % p.get("ruolo"))
	vecchia.reset()
	return done()


func test_rosa_nuova_coi_ruoli() -> bool:
	var c := _nuova("nuova.json")
	var web := _nuova("nuova_web.json", false)
	var conta := {}
	for i in c.s.squad.size():
		var p: Dictionary = c.s.squad[i]
		conta[p.ruolo] = int(conta.get(p.ruolo, 0)) + 1
		eq(Ruoli.gruppo(p.ruolo), p.pos, "%s: gruppo dal ruolo" % p.name)
		eq(CarrieraScript.overall(p), CarrieraScript.overall(web.s.squad[i]), "%s (%s): valutazione uguale a quella del web" % [p.name, p.ruolo])
		eq(int(p.pot), int(web.s.squad[i].pot), "%s: potenziale uguale" % p.name)
	for r: String in ["P", "TS", "TD", "DC", "CDC", "CC", "ES", "ED", "COC", "AS", "AD", "ATT"]:
		check(int(conta.get(r, 0)) >= 1, "in rosa c'è almeno un %s" % r)
	eq(c.s.formation, "4-4-2", "si parte col 4-4-2")
	var FR: Array = Ruoli.POSTI["4-4-2"]
	for i in 11:
		eq(c.player(c.s.lineup[i]).ruolo, FR[i], "titolare %d nel suo ruolo" % i)
	eq(c.s.money, web.s.money, "soldi come nel web")
	eq(c.s.seed, web.s.seed, "numeri casuali della carriera non toccati")
	var ch: Dictionary = c.addChampion({"name": "Ala", "ruolo": "AS", "look": {}, "num": 11})
	eq([ch.pos, ch.ruolo], ["A", "AS"], "campione: ruolo scelto nell'editor")
	check(Ruoli.valido(ch.get("ruolo2")) and ch.ruolo2 != "AS", "campione: seconda scelta")
	check(c.s.lineup.has(ch.id), "campione titolare")
	var ch2: Dictionary = c.addChampion({"name": "Vecchio modo", "pos": "D", "look": {}, "num": 4})
	eq(ch2.ruolo, "DC", "campione col solo gruppo: ruolo predefinito")
	c.reset()
	web.reset()
	return done()


func test_cpu_coi_ruoli_e_statistiche_coerenti() -> bool:
	var c := _nuova("cpu.json")
	var somme := {}
	var quanti := {}
	var moduli := {}
	for stagione in [1, 2, 3]:
		c.s.season = stagione
		for id: String in c.s.teams:
			if id == "me":
				continue
			var t: Dictionary = c.s.teams[id]
			var f := c.formazioneDi(t)
			moduli[f] = true
			var grezza: Dictionary = c.aiMatchTeam(t, f)
			var sq: Dictionary = c.squadraCpu(t)
			var FR: Array = Ruoli.POSTI[f]
			for i in 11:
				var p: Dictionary = sq.players[i]
				eq(p.get("ruolo"), FR[i], "%s posto %d: ruolo del posto" % [f, i])
				if i > 0:
					check(Ruoli.valido(p.get("ruolo2")) and (Ruoli.SECONDE[p.ruolo] as Array).has(p.ruolo2), "%s posto %d: seconda scelta sensata" % [f, i])
				check(absi(CarrieraScript.overall(p) - CarrieraScript.overall(grezza.players[i])) <= 1, "%s posto %d (%s): valutazione come prima (%d, era %d)" % [f, i, FR[i], CarrieraScript.overall(p), CarrieraScript.overall(grezza.players[i])])
				eq(C.effStats(p, p.pos, FR[i]).dri, float(p.dri), "nel suo posto niente malus")
				var r: String = Ruoli.SPECCHIO.get(p.ruolo, p.ruolo) if int(Ruoli.LATO.get(p.ruolo, 0)) > 0 else p.ruolo
				if not somme.has(r):
					somme[r] = {}
					quanti[r] = 0
				quanti[r] += 1
				for k: String in ["acc", "vmax", "cro", "frz", "int", "ctr", "drb", "fin", "lon", "res", "pco", "tes"]:
					somme[r][k] = float(somme[r].get(k, 0.0)) + (float(p.tes) if k == "tes" else Sotto.valore(p, k)) - float(CarrieraScript.overall(p))
	eq(moduli.size(), 14, "la CPU usa tutti e 14 i moduli: " + str(moduli.keys()))
	var m := func(r: String, k: String) -> float: return float(somme[r][k]) / float(quanti[r])
	for r: String in somme:
		var riga := ""
		for k: String in somme[r]:
			riga += " %s %+.0f" % [k, m.call(r, k)]
		note("%s (%d):%s" % [r, quanti[r], riga])
	# medie rispetto alla valutazione: ogni ruolo ha le statistiche che gli servono
	check(m.call("TS", "cro") > m.call("DC", "cro") + 5.0 and m.call("TS", "vmax") > m.call("DC", "vmax") + 3.0, "terzini: più cross e velocità dei centrali")
	check(m.call("DC", "frz") > m.call("TS", "frz") + 3.0 and m.call("DC", "tes") > m.call("TS", "tes") + 5.0, "centrali: più forza e colpo di testa dei terzini")
	check(m.call("CDC", "int") > m.call("COC", "int") + 8.0 and m.call("CDC", "ctr") > m.call("CC", "ctr") + 4.0, "mediano: intercetti e contrasto")
	check(m.call("COC", "drb") > m.call("CDC", "drb") + 5.0 and m.call("COC", "lon") > m.call("CDC", "lon") + 4.0, "trequartista: dribbling e tiro da lontano")
	check(m.call("CC", "pco") > m.call("ES", "cro") - 20.0 and m.call("CC", "res") > m.call("COC", "res") + 3.0, "centrocampista: passaggio e resistenza")
	check(m.call("ES", "cro") > m.call("CC", "cro") + 4.0 and m.call("ES", "vmax") > m.call("CC", "vmax") + 2.0, "esterni: cross e velocità")
	check(m.call("AS", "drb") > m.call("ATT", "drb") + 3.0 and m.call("AS", "cro") > m.call("ATT", "cro") + 8.0, "ali: dribbling e cross")
	check(m.call("ATT", "fin") > m.call("AS", "fin") + 3.0 and m.call("ATT", "tes") > m.call("AS", "tes") + 8.0 and m.call("ATT", "frz") > m.call("AS", "frz") + 6.0, "punta: finalizzazione, testa e forza")
	# in partita: ruoli e posti del gioco
	var t0: Dictionary = c.s.teams[c.s.divs[2][1]]
	var sq0: Dictionary = c.avversarioPartita(t0)
	check(sq0.get("moduli", false), "avversario: posti dei moduli del gioco")
	check(c.squadraPartita().get("moduli", false), "la mia squadra: posti dei moduli del gioco")
	check(not c.myMatchTeam().has("moduli") and not c.aiMatchTeam(t0).has("moduli"), "squadre del web: come prima")
	check(not c.aiMatchTeam(t0).players[3].has("ruolo"), "aiMatchTeam (confronti col JS) senza ruoli")
	c.reset()
	return done()


## Luis 2026-11-27: "i terzini non possono mai fare le ali, al massimo gli esterni come dicevamo"
func test_terzini_mai_ali() -> bool:
	# seconda scelta vietata (salvataggi di prima): diventa l'esterno dello stesso lato
	for caso: Array in [["TS", "AS", "ES"], ["TS", "AD", "ES"], ["TD", "AD", "ED"], ["TD", "AS", "ED"], ["AS", "TS", "ES"], ["AD", "TD", "ED"]]:
		var p := _gioc(caso[0], caso[1])
		Ruoli.sistema_seconda(p)
		eq(p.ruolo2, caso[2], "%s con seconda %s → %s" % caso)
	var ok := _gioc("TS", "DC")
	Ruoli.sistema_seconda(ok)
	eq(ok.ruolo2, "DC", "seconda scelta permessa: resta")
	# giocatori generati e seconde scelte calcolate: mai tra terzini e ali
	for r: String in ["TS", "TD", "AS", "AD"]:
		for k in 40:
			var g := _gioc(r)
			var semi := [0.1, 0.6, 0.9]
			var x: float = semi[k % 3]
			Sotto.crea(g, JS.rng32(1000 + k))
			Ruoli.modella(g, r, func() -> float: return x)
			check(not Ruoli.vietato({"ruolo": r}, g.ruolo2), "%s generato: seconda %s" % [r, g.ruolo2])
	# migrazione al caricamento: un terzino con l'ala come seconda torna esterno
	var c := _nuova("migra.json")
	var td: Variant = null
	for p: Dictionary in c.s.squad:
		if p.get("ruolo") == "TD":
			td = p
			break
	check(td != null, "la rosa nuova ha un terzino destro")
	td["ruolo2"] = "AD"
	c.save()
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	c2.load()
	eq(c2.player(td.id).ruolo2, "ED", "caricato: il TD con seconda AD ora ha ED")
	# campione creato con una seconda scelta vietata
	var ch: Dictionary = c2.addChampion({"name": "Terzino", "ruolo": "TS", "ruolo2": "AS", "look": {}, "num": 3})
	eq(ch.ruolo2, "ES", "campione terzino: l'ala come seconda diventa esterno")
	# formazione automatica: tutti i difensori diventano terzini fortissimi (7 per 4 posti di difesa), centrocampisti
	# centrali forti, esterni e attaccanti scarsi: senza il divieto i terzini in più andrebbero sulle ali (99 × 0,72
	# contro 30), col divieto no (in attacco al centro sì: non è vietato)
	c2.s.formation = "4-3-3"
	var n_terzini := 0
	for p: Dictionary in c2.s.squad:
		if p.pos == "D":
			p["ruolo"] = "TS" if n_terzini % 2 == 0 else "TD"
			p["ruolo2"] = "DC"
			n_terzini += 1
		var forte: bool = p.pos == "D" or p.get("ruolo") in ["CC", "CDC"]
		if forte or p.get("ruolo") in ["AS", "AD", "ATT", "ES", "ED", "COC"]:
			for k: String in ["vel", "tir", "pas", "dri", "dif", "fis"]:
				p[k] = 99 if forte else 30
			p["tes"] = 99 if forte else 30
			p.erase("sub")
	c2.autoLineup()
	var FR := c2.ruoliPosti()
	for i in 11:
		var p: Dictionary = c2.player(c2.s.lineup[i])
		check(not Ruoli.vietato(p, FR[i]), "autoLineup 4-3-3: %s non va sul posto %s" % [p.ruolo, FR[i]])
	# fixLineup: buco su un'ala, in panchina un terzino fortissimo (99 × 0,72 = 71) e attaccanti scarsi (30) → non il
	# terzino (senza il divieto lo sceglierebbe)
	var i_as := FR.find("AS")
	var nuovo: Dictionary = c2.player(c2.s.lineup[1]).duplicate(true)
	nuovo["id"] = 99999
	nuovo["ruolo"] = "TS"
	nuovo.erase("champ")
	c2.s.squad.append(nuovo)
	check(c2._punti_posto(nuovo, "AS") < c2._punti_posto(c2.player(c2.s.lineup[i_as]), "AS"), "punti: terzino sull'ala sotto chiunque")
	var via: Variant = c2.s.lineup[i_as] # chi era sull'ala se ne va (venduto): restano terzini forti e attaccanti scarsi
	c2.s.squad = c2.s.squad.filter(func(p: Dictionary) -> bool: return p.id != via)
	c2.fixLineup()
	var preso: Dictionary = c2.player(c2.s.lineup[i_as])
	check(not Ruoli.vietato(preso, "AS"), "fixLineup: niente terzino sull'ala (preso %s)" % preso.ruolo)
	c2.reset()
	c.reset()
	return done()


func test_auto_lineup_mette_ognuno_nel_suo_ruolo() -> bool:
	var c := _nuova("auto.json")
	for f: String in C.FORMATIONS:
		c.s.formation = f
		c.autoLineup()
		var FR := c.ruoliPosti()
		eq(FR, Ruoli.POSTI[f], f + ": ruoli dei posti")
		var visti := {}
		var fuori := 0
		var somma := 0
		for i in 11:
			var p: Dictionary = c.player(c.s.lineup[i])
			check(not visti.has(p.id), f + ": nessun doppione")
			visti[p.id] = true
			eq(p.pos == "P", FR[i] == "P", f + ": in porta il portiere e solo lui")
			if Ruoli.fattore(p, FR[i]) < Ruoli.F_FUORI:
				fuori += 1
			somma += CarrieraScript.overallAs(p, FR[i])
		check(fuori <= 2, "%s: al massimo 2 fuori ruolo con la rosa iniziale (%d)" % [f, fuori])
		eq(c.myRating(), int(floor(somma / 11.0 + 0.5)), f + ": forza squadra dai ruoli dei posti")
		for a in 11:
			for b in range(a + 1, 11):
				var pa: Dictionary = c.player(c.s.lineup[a])
				var pb: Dictionary = c.player(c.s.lineup[b])
				check(CarrieraScript.overallAs(pa, FR[b]) + CarrieraScript.overallAs(pb, FR[a]) <= CarrieraScript.overallAs(pa, FR[a]) + CarrieraScript.overallAs(pb, FR[b]),
					"%s: scambiare i posti %d e %d non migliora" % [f, a, b])
	c.s.formation = "4-4-2"
	c.autoLineup()
	var FR442: Array = Ruoli.POSTI["4-4-2"]
	for i in 11:
		eq(c.player(c.s.lineup[i]).ruolo, FR442[i], "4-4-2: posto %d al giocatore di quel ruolo" % i)
	# fuori ruolo vale meno che nel suo
	var td: Dictionary = c.player(c.s.lineup[4])
	check(CarrieraScript.overallAs(td, "DC") < CarrieraScript.overallAs(td, "TD") or Ruoli.valuta(td, "DC") > Ruoli.valuta(td, "TD"), "terzino al centro: col malus")
	check(CarrieraScript.overallAs(td, "ATT") < CarrieraScript.overallAs(td, "TD"), "terzino in attacco: molto peggio")
	c.reset()
	return done()
