# Carriera, fase B (solo Godot): campione che cresce giocando (crescita.gd + conta_giocatori.gd), obiettivi della
# dirigenza e rivale/derby (dirigenza.gd), forma e infortuni tra le partite (forma.gd), salvataggi vecchi.
extends "test_base.gd"

const JS := preload("res://scripts/carriera/js.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Crescita := preload("res://scripts/carriera/crescita.gd")
const Forma := preload("res://scripts/carriera/forma.gd")
const Dirigenza := preload("res://scripts/carriera/dirigenza.gd")
const Conta := preload("res://scripts/partita/conta_giocatori.gd")
const DIR := "user://prove_carriera/"


func _nuova(nome_file: String, seme: int = 91) -> CarrieraScript:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + nome_file
	Salv.cancella(c.percorso)
	c.create("Prova Fase B", 3, seme)
	return c


static func _campione(c: CarrieraScript) -> Dictionary:
	return c.addChampion({"name": "Campione", "pos": "A", "look": {}, "num": 10})


# ---------------------------------------------------------------- 6. crescita del campione
func test_crescita_lenta_con_tetto_e_eta() -> bool:
	var g := Crescita.progresso({"gol": 10, "tiri": 30, "dribbling": 2}, 20)
	near(g.tir, Crescita.PER_PARTITA_MAX, 1e-9, "tiro: al massimo 0,5 a partita anche con tanti gol")
	near(g.dri, 0.2, 1e-9, "dribbling: 2 riusciti = +0,2")
	check(not g.has("dif"), "niente contrasti = niente difesa")
	var vecchio := Crescita.progresso({"dribbling": 2}, 32)
	check(vecchio.dri < g.dri * 0.5, "a 32 anni si cresce molto meno (%.3f)" % vecchio.dri)
	return done()


func test_crescita_si_accumula_e_sale_di_un_punto() -> bool:
	var p := {"id": 7, "age": 20, "tir": 60, "dri": 98, "pas": 50}
	var pr := {}
	var su := 0
	for i in 3: # 3 partite con 1 gol, 2 in porta e 2 tiri: 3 × (0,25 + 0,16 + 0,06) = 1,41 → Tiro +1
		var righe := Crescita.applica(p, {"gol": 1, "in_porta": 2, "tiri": 2}, pr)
		for r: Dictionary in righe:
			su += int(r.su)
	eq(p.tir, 61, "tiro salito di 1")
	eq(su, 1, "una riga con +1")
	near(float(pr["7"].tir), 0.41, 1e-6, "il resto resta da parte")
	for i in 30:
		Crescita.applica(p, {"dribbling": 9}, pr)
	eq(p.dri, 99, "mai oltre 99")
	eq(Crescita.testo({"nome": "Tiro", "su": 1, "parte": 0.4}), "Tiro +1", "testo col punto")
	eq(Crescita.testo({"nome": "Tiro", "su": 0, "parte": 0.3}), "Tiro +0,3", "testo col progresso")
	return done()


func test_conteggi_dagli_eventi_del_motore() -> bool:
	var a := _gioc(0, 1)
	var b := _gioc(0, 2)
	var o := _gioc(1, 99)
	var gk := _gioc(1, 98)
	var k := Conta.new(0)
	var m := {"players": [a, b, o, gk], "events": [
		{"type": "kick", "p": a, "kind": "ground"}, {"type": "control", "p": b},           # passaggio riuscito di a
		{"type": "kick", "p": b, "kind": "ground"}, {"type": "control", "p": o},           # passaggio di b intercettato
		{"type": "kick", "p": o, "kind": "loft"}, {"type": "control", "p": a},             # a intercetta
		{"type": "dribble", "p": a, "o": o, "ok": true}, {"type": "dribble", "p": a, "o": o, "ok": false},
		{"type": "burst", "p": a, "o": o}, {"type": "tackle", "p": b, "on": o}, {"type": "aerial", "p": b, "o": o},
		{"type": "kick", "p": a, "kind": "shot"}, {"type": "save", "p": gk, "catch": true},  # tiro in porta parato
		{"type": "kick", "p": a, "kind": "header", "clear": true},                         # respinta: niente tiro
		{"type": "kick", "p": a, "kind": "volley"},
		{"type": "goal", "team": 0, "scorer": a, "assist": b, "og": false, "minute": 30}]}
	k.leggi(m)
	a.x += 2.0
	m.events = []
	k.leggi(m)
	var c := k.per_giocatore()
	eq(c["1"].get("passaggi", 0), 1, "passaggi riusciti di a")
	eq(c["1"].get("intercetti", 0), 1, "intercetti di a")
	eq(c["1"].get("dribbling", 0), 1, "solo i dribbling riusciti")
	eq(c["1"].get("scatti", 0), 1, "scatti")
	eq(c["1"].get("tiri", 0), 2, "tiri (la respinta di testa non conta)")
	eq(c["1"].get("in_porta", 0), 2, "in porta: parata + gol")
	eq(c["1"].get("gol", 0), 1, "gol")
	near(float(c["1"].get("km", 0)), 0.002, 1e-9, "2 m corsi")
	eq(c["2"].get("passaggi", 0), 0, "il passaggio intercettato non conta")
	eq(c["2"].get("assist", 0), 1, "assist")
	eq(c["2"].get("contrasti", 0), 1, "contrasti")
	eq(c["2"].get("testa", 0), 1, "contrasti aerei vinti")
	check(not c.has("99") and not c.has("98"), "gli avversari non si contano")
	return done()


static func _gioc(team: int, id: int) -> R.Player:
	var p := R.Player.new()
	p.team = team
	p.src = {"id": id, "name": "G%d" % id}
	return p


func test_dopo_partita_fa_crescere_il_campione() -> bool:
	var c := _nuova("crescita.json")
	var ch := _campione(c)
	var res := c.finishMatch(2, 0, [])
	res = c.dopoPartita(res, {"gol_a": 2, "gol_b": 0, "me": 0, "conteggi": {str(ch.id): {"gol": 2, "in_porta": 3, "tiri": 4, "dribbling": 3}}})
	check(res.has("crescita"), "c'è la crescita nel risultato")
	eq(res.crescita.nome, ch.name, "è il campione")
	var tir: Dictionary = res.crescita.righe.filter(func(r: Dictionary) -> bool: return r.k == "tir")[0]
	near(float(tir.parte), 0.5, 1e-9, "tiro +0,5 (tetto)")
	near(float(c.s.progressi[str(ch.id)].tir), 0.5, 1e-6, "progresso salvato nello stato")
	c.reset()
	return done()


# ---------------------------------------------------------------- 7. obiettivi della dirigenza
func test_obiettivo_dalla_forza_della_squadra() -> bool:
	eq(Dirigenza.tipo_per(2, 1), "promozione", "la più forte in Terza: promozione")
	eq(Dirigenza.tipo_per(1, 4), "meta", "quarta in Seconda: metà classifica")
	eq(Dirigenza.tipo_per(1, 9), "salvezza", "tra le ultime: salvezza")
	eq(Dirigenza.tipo_per(0, 1), "titolo", "la più forte in Prima: titolo")
	eq(Dirigenza.posto_forza(60, [70, 60, 50]), 3, "a pari forza conto prima le altre")
	var ok := Dirigenza.valuta({"tipo": "meta", "posto": 5}, 3, 140, 100)
	check(ok.riuscito and ok.soldi == 420, "metà classifica raggiunta: +3 × 140 (%d)" % ok.soldi)
	var ko := Dirigenza.valuta({"tipo": "promozione", "posto": 2}, 6, 140, 100)
	check(not ko.riuscito and ko.soldi == -100, "mancata: penalità, ma la cassa non va sotto zero (%d)" % ko.soldi)
	var c := _nuova("obiettivo.json")
	var ob := c.obiettivo()
	eq(int(ob.stagione), 1, "obiettivo della prima stagione già alla creazione")
	check(Dirigenza.TIPI.has(ob.tipo), "tipo valido: " + str(ob.get("tipo")))
	c.reset()
	return done()


func test_fine_stagione_premio_o_penalita_e_obiettivo_nuovo() -> bool:
	var c := _nuova("stagione.json")
	var tot_derby := 0
	var res := {}
	for i in CarrieraScript.ROUNDS:
		var nm: Dictionary = c.nextMatch()
		var derby := c.isDerby(nm.opp)
		var soldi_prima: int = c.s.money
		res = c.finishMatch(3, 0, [])
		var dopo_fm: int = c.s.money
		res = c.dopoPartita(res, {"gol_a": 3, "gol_b": 0, "me": 0, "derby": derby})
		if derby:
			tot_derby += 1
			eq(c.s.money - dopo_fm, Dirigenza.premio_derby(CarrieraScript.DIV_INCOME[2], 3, 0) + (int(res.obiettivo.soldi) if res.has("obiettivo") else 0), "premio del derby vinto")
		check(soldi_prima != c.s.money, "soldi cambiati")
	eq(tot_derby, 2, "due derby in stagione (andata e ritorno)")
	check(res.has("season") and res.has("obiettivo"), "a fine stagione c'è il giudizio della dirigenza")
	check(res.season.has("obiettivo"), "anche nel risultato della stagione (schermata di fine stagione)")
	check(res.obiettivo.riuscito and int(res.obiettivo.soldi) > 0, "tutte vinte: obiettivo raggiunto, premio %d" % int(res.obiettivo.soldi))
	eq(int(c.obiettivo().stagione), 2, "obiettivo nuovo per la stagione 2")
	eq(c.div(), 1, "promossi in Seconda")
	check(c.s.divs[1].has(c.s.rivale), "rivale nuova nella nuova divisione: " + str(c.s.rivale))
	c.reset()
	return done()


# ---------------------------------------------------------------- 8. rivalità e derby
func test_rivale_stabile_della_stessa_divisione() -> bool:
	var c := _nuova("rivale.json")
	var riv: String = c.s.rivale
	check(riv != "" and c.s.divs[c.div()].has(riv), "rivale nella mia divisione")
	var teams := {"a": {"rating": 50}, "b": {"rating": 58}, "c": {"rating": 62}}
	eq(Dirigenza.scegli_rivale("", ["a", "b", "c"], teams, 60), "c", "forza più vicina (a pari distanza la più forte)")
	eq(Dirigenza.scegli_rivale("a", ["a", "b", "c"], teams, 60), "a", "quella di prima resta")
	c.novita()
	eq(c.s.rivale, riv, "stabile tra un controllo e l'altro")
	check(c.isDerby(c.team(riv)) and not c.isDerby({"id": "amico"}), "isDerby")
	c.reset()
	return done()


func test_derby_pubblico_e_audio_piu_rumorosi() -> bool:
	var AudioPartita: GDScript = load("res://scripts/partita/audio_partita.gd")
	var a: Node = AudioPartita.new()
	a.folla(0.2)
	var normale: float = a._folla_meta
	a.derby = true
	a.folla(0.2)
	check(a._folla_meta > normale * 1.2, "derby: pubblico più forte (%.3f contro %.3f)" % [a._folla_meta, normale])
	check(a.CORO_OGNI_DERBY.y < a.CORO_OGNI.x, "derby: cori più frequenti")
	a.free()
	var Pubblico: GDScript = load("res://scripts/stadio/pubblico.gd")
	var pb: Node3D = Pubblico.new()
	pb.derby = true
	pb.aggiorna(5.0) # passa il primo coro
	check(pb.stato(0).x > Pubblico.BASE.x, "derby: tifosi più in piedi")
	pb.free()
	return done()


# ---------------------------------------------------------------- 9. forma e infortuni
func test_forma_cala_giocando_e_risale_riposando() -> bool:
	eq(Forma.energia(100), 1.0, "in forma: energia piena")
	eq(Forma.energia(80), 1.0, "fino a 80 niente stanchezza")
	near(Forma.energia(0), Forma.ENERGIA_MIN, 1e-9, "forma 0: energia minima")
	check(Forma.rischio(20) > Forma.rischio(100) * 3, "più rischio da stanchi")
	var squad := [{"id": 1, "name": "A", "fis": 60}, {"id": 2, "name": "B", "fis": 60}]
	var forma := {"1": 70, "2": 70}
	var inf := {}
	Forma.giornata(squad, [1], forma, inf, func() -> float: return 0.99)
	eq(forma["1"], 70 - 11 + Forma.RECUPERO, "chi gioca cala")
	eq(forma["2"], mini(100, 70 + Forma.RECUPERO_RIPOSO + Forma.RECUPERO), "chi riposa risale")
	return done()


func test_infortuni_con_seme_e_durata_in_giornate() -> bool:
	var squad := [{"id": 1, "name": "A", "fis": 60}]
	var inf := {}
	var nuovi := Forma.giornata(squad, [1], {"1": 30}, inf, func() -> float: return 0.0)
	eq(nuovi.size(), 1, "con un numero piccolo si fa male")
	var g := int(inf["1"])
	check(g >= 1 and g <= 2, "durata 1..2 giornate col primo numero (%d)" % g)
	Forma.giornata(squad, [], {"1": 30}, inf, func() -> float: return 0.99)
	eq(int(inf.get("1", 0)), g - 1, "una giornata saltata")
	# due carriere uguali = stessi infortuni
	var a := _stagione_infortuni(31)
	var b := _stagione_infortuni(31)
	eq(str(a), str(b), "stessi infortuni con lo stesso seme")
	note("infortuni in una stagione senza turni di riposo: %d" % a.size())
	return done()


func _stagione_infortuni(seme: int) -> Array:
	var c := _nuova("inf_%d.json" % seme, seme)
	var tutti: Array = []
	for i in CarrieraScript.ROUNDS - 1:
		var res := c.dopoPartita(c.finishMatch(1, 1, []), {"gol_a": 1, "gol_b": 1, "me": 0})
		for x: Dictionary in res.infortuni:
			tutti.append([i, x.id, x.giornate])
	c.reset()
	return tutti


func test_infortunati_fuori_dalla_formazione_e_squadra_stanca() -> bool:
	var c := _nuova("rosa.json")
	var titolare: int = c.s.lineup[9]
	c.s.infortuni[str(titolare)] = 2
	c.s.forma[str(c.s.lineup[3])] = 40
	var cambi := c.schieraSani()
	check(not c.s.lineup.has(titolare), "l'infortunato esce dalla formazione")
	eq(cambi.size(), 1, "un cambio della CPU")
	var lineup_prima: Array = c.s.lineup.duplicate()
	c.swap(c.s.lineup[9], titolare)
	eq(c.s.lineup, lineup_prima, "un infortunato non può entrare con uno scambio")
	check(c.entraInfortunato(c.s.lineup[0], titolare), "entraInfortunato")
	var t := c.squadraPartita()
	eq(t.players.size(), 11, "11 titolari")
	check(t.players.all(func(p: Dictionary) -> bool: return c.infortunio(p.id) == 0), "nessun infortunato in campo")
	check(not t.bench.any(func(p: Dictionary) -> bool: return p.id == titolare), "né in panchina")
	near(float(t.players[3].get("energy0", 1.0)), Forma.energia(40), 1e-9, "chi è giù di forma parte stanco")
	check(not t.players[0].has("energy0"), "chi è in forma no")
	check(not c.player(c.s.lineup[3]).has("energy0"), "lo stato della carriera non cambia (copie)")
	c.autoLineup()
	check(not c.s.lineup.has(titolare), "neanche i Migliori 11 lo schierano")
	c.reset()
	return done()


# ---------------------------------------------------------------- salvataggio
func test_salvataggio_vecchio_senza_campi_nuovi_si_carica() -> bool:
	var c := _nuova("vecchio.json")
	var st: Dictionary = c.s.duplicate(true)
	for k: String in CarrieraScript.CHIAVI_GODOT:
		st.erase(k)
	Salv.scrivi(c.percorso, st) # file versione 1 come prima della fase B
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "il salvataggio vecchio si carica")
	for k: String in CarrieraScript.CHIAVI_GODOT:
		check(c2.s.has(k), "campo nuovo %s con valore predefinito" % k)
	eq(c2.forma_di(c2.s.squad[0].id), 100, "forma piena")
	eq(c2.infortunio(c2.s.squad[0].id), 0, "nessun infortunio")
	check(c2.s.divs[c2.div()].has(c2.s.rivale), "rivale scelta")
	var res := c2.dopoPartita(c2.finishMatch(1, 0, []), {"gol_a": 1, "gol_b": 0, "me": 0})
	check(res.has("infortuni"), "e si gioca come prima")
	c.reset()
	return done()


func test_salva_e_ricarica_coi_campi_nuovi() -> bool:
	var c := _nuova("andata_b.json")
	var ch := _campione(c)
	for i in 5:
		c.dopoPartita(c.finishMatch(2, 1, []), {"gol_a": 2, "gol_b": 1, "me": 0, "conteggi": {str(ch.id): {"dribbling": 2, "km": 6.4}}})
	c.s.infortuni[str(c.s.squad[2].id)] = 3
	c.schieraSani()
	c.save()
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	c2.load()
	eq(JS.diff(c2.s, c.s), "", "stato uguale dopo il caricamento")
	eq(typeof(c2.s.forma.values()[0]), TYPE_INT, "la forma resta intera")
	c.reset()
	return done()


# Luis 2026-11-25: "Il campione parte sempre al 100%, durante la partita si stanca come gli altri ma poi riparte da
# quella dopo al 100%"
func test_campione_sempre_al_100() -> bool:
	var squad := [{"id": 1, "name": "Campione", "fis": 60, "champ": true}, {"id": 2, "name": "Altro", "fis": 60}]
	var forma := {"1": 100, "2": 100}
	for i in 10:
		Forma.giornata(squad, [1, 2], forma, {}, func() -> float: return 0.99)
	eq(forma["1"], Forma.FORMA_MAX, "dopo 10 partite il campione è ancora al 100")
	check(int(forma["2"]) < Forma.ENERGIA_DA, "gli altri si stancano: %d" % int(forma["2"]))
	var c := _nuova("campione_100.json")
	var ch := _campione(c)
	c.s.forma[str(ch.id)] = 20 # salvataggio vecchio col campione stanco
	var t := c.squadraPartita()
	for p: Variant in t.players:
		if p is Dictionary and p.id == ch.id:
			check(not p.has("energy0"), "in partita parte con l'energia piena")
	Salv.cancella(c.percorso)
	return done()


# Luis 2026-11-25: "l'unico che migliora le proprie statistiche a fine partita deve essere il campione"
func test_a_fine_partita_migliora_solo_il_campione() -> bool:
	var c := _nuova("solo_campione.json")
	var ch := _campione(c)
	var prima := {}
	for p: Dictionary in c.s.squad:
		if not p.get("champ", false):
			prima[p.id] = [p.vel, p.fis, p.dri, p.tir, p.dif, p.pas, p.por, p.tes]
	for i in 10:
		var res := c.finishMatch(1, 0, [])
		for nome: Variant in res.get("grown", []):
			eq(nome, ch.name, "nell'elenco dei cresciuti solo il campione")
	for p: Dictionary in c.s.squad:
		if prima.has(p.id):
			eq([p.vel, p.fis, p.dri, p.tir, p.dif, p.pas, p.por, p.tes], prima[p.id], "%s non migliora" % p.name)
	Salv.cancella(c.percorso)
	return done()
