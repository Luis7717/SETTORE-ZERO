# Salvataggio della carriera (scripts/carriera/salvataggio.gd + Carriera.load/save/completa):
# andata e ritorno identici, scrittura sicura con copia .bak, file rotti (ripiego sulla copia o sul temporaneo,
# altrimenti nessuna carriera), campi mancanti riempiti coi predefiniti, una stagione intera salvata e ricaricata.
extends "test_base.gd"

const JS := preload("res://scripts/carriera/js.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const DIR := "user://prove_carriera/"


func _nuova(nome_file: String, seme: int = 77) -> CarrieraScript:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + nome_file
	Salv.cancella(c.percorso)
	for extra: String in [".rotto"]:
		if FileAccess.file_exists(c.percorso + extra):
			DirAccess.remove_absolute(c.percorso + extra)
	c.create("Prova Salvataggio", 2, seme)
	return c


func _ricarica(percorso: String) -> CarrieraScript:
	var c := CarrieraScript.new()
	c.percorso = percorso
	c.load()
	return c


static func _scrivi_testo(percorso: String, testo: String) -> void:
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	f.store_string(testo)
	f.close()


func test_salva_e_ricarica_identico_con_numeri_interi() -> bool:
	var c := _nuova("andata.json")
	var d := c.load()
	check(d, "il salvataggio appena scritto si legge")
	var c2 := _ricarica(c.percorso)
	eq(c2.fonte, "principale", "letto dal file principale")
	eq(JS.diff(c2.s, c.s), "", "stato uguale dopo il caricamento")
	eq(typeof(c2.s.money), TYPE_INT, "i soldi restano interi")
	eq(typeof(c2.s.squad[0].id), TYPE_INT, "gli id restano interi")
	check(c2.s.lineup.has(c2.s.squad[0].id) or c2.bench().size() > 0, "lineup e rosa coerenti")
	var testo := Salv.leggi_file(c.percorso)
	var dati: Dictionary = JSON.parse_string(testo)
	eq(int(dati.versione), Salv.VERSIONE, "campo versione nel file")
	check(dati.carriera is Dictionary, "stato sotto la chiave carriera")
	c.reset()
	check(not FileAccess.file_exists(c.percorso), "reset cancella il file")
	return done()


func test_seconda_scrittura_lascia_la_copia_bak_e_niente_temporaneo() -> bool:
	var c := _nuova("bak.json")
	var primo := Salv.leggi_file(c.percorso)
	c.s.money = 999
	c.save()
	check(FileAccess.file_exists(c.percorso + ".bak"), "c'è la copia .bak")
	check(not FileAccess.file_exists(c.percorso + ".tmp"), "il temporaneo è stato rinominato")
	eq(Salv.leggi_file(c.percorso + ".bak"), primo, "la copia è il salvataggio di prima")
	eq(int(_ricarica(c.percorso).s.money), 999, "il principale è quello nuovo")
	c.reset()
	return done()


func test_file_rotto_ripiega_sulla_copia() -> bool:
	var c := _nuova("rotto.json")
	c.s.money = 1234
	c.save() # ora .bak = carriera appena creata, principale = soldi 1234
	var testo := Salv.leggi_file(c.percorso)
	_scrivi_testo(c.percorso, testo.left(testo.length() / 2)) # scrittura interrotta a metà
	var c2 := _ricarica(c.percorso)
	check(c2.s != null, "carriera ripescata")
	eq(c2.fonte, "copia", "dalla copia .bak")
	eq(int(c2.s.money), 250, "è la versione della copia")
	check(FileAccess.file_exists(c.percorso + ".rotto"), "il file rotto è messo da parte")
	eq(Salv.leggi(c.percorso).fonte, "principale", "dopo il ripiego il principale è di nuovo buono")
	c.reset()
	return done()


func test_temporaneo_rimasto_si_usa_se_manca_il_principale() -> bool:
	var c := _nuova("tmp.json")
	var testo := Salv.leggi_file(c.percorso)
	Salv.cancella(c.percorso)
	_scrivi_testo(c.percorso + ".tmp", testo) # app chiusa tra le due rinomine
	var c2 := _ricarica(c.percorso)
	eq(c2.fonte, "temporaneo", "letto dal temporaneo")
	eq(c2.s.club, "Prova Salvataggio", "carriera giusta")
	c.reset()
	return done()


func test_tutto_rotto_nessuna_carriera() -> bool:
	var c := _nuova("tutto_rotto.json")
	_scrivi_testo(c.percorso, "{ questo non è JSON")
	_scrivi_testo(c.percorso + ".bak", "[1, 2, 3]")
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(not c2.load(), "load ritorna false")
	check(c2.s == null, "nessuna carriera (il menu propone di crearne una)")
	check(FileAccess.file_exists(c.percorso + ".rotto"), "il principale rotto è messo da parte")
	var c3 := CarrieraScript.new()
	c3.percorso = DIR + "mai_esistito.json"
	Salv.cancella(c3.percorso)
	check(not c3.load() and c3.fonte == "", "senza file: nessuna carriera")
	c.reset()
	return done()


func test_struttura_sbagliata_e_rifiutata() -> bool:
	var c := _nuova("struttura.json")
	var dati: Dictionary = JSON.parse_string(Salv.leggi_file(c.percorso))
	dati.carriera.divs[0].pop_back() # 9 squadre invece di 10
	check(Salv.estrai(JSON.stringify(dati)) == null, "divisione da 9 squadre rifiutata")
	dati = JSON.parse_string(Salv.leggi_file(c.percorso))
	dati.carriera.squad = []
	check(Salv.estrai(JSON.stringify(dati)) == null, "rosa vuota rifiutata")
	check(Salv.estrai("") == null and Salv.estrai("null") == null and Salv.estrai("{}") == null, "vuoti rifiutati")
	c.reset()
	return done()


func test_campi_mancanti_riempiti_coi_predefiniti() -> bool:
	var c := _nuova("mancanti.json")
	var dati: Dictionary = JSON.parse_string(Salv.leggi_file(c.percorso))
	var s: Dictionary = dati.carriera
	s.settings.erase("music")
	s.settings.erase("diff")
	s.erase("market")
	s.erase("fix")
	s.erase("history")
	s.erase("nextId")
	s.squad[0].erase("goals")
	s.squad[1].erase("vel")
	s.lineup.pop_back()
	s.formation = "9-9-9"
	_scrivi_testo(c.percorso, JSON.stringify(dati))
	var c2 := _ricarica(c.percorso)
	check(c2.s != null, "caricata")
	eq(c2.s.settings.music, true, "music predefinita")
	eq(c2.s.settings.diff, 1, "diff predefinita")
	eq(c2.s.history, [], "history vuota")
	eq(c2.s.formation, "4-4-2", "formazione valida")
	eq(c2.s.lineup.size(), 11, "formazione completa")
	eq(c2.s.squad[0].goals, 0, "gol predefiniti")
	check(JS.is_integer(c2.s.squad[1].vel), "statistica mancante riempita")
	eq(c2.s.fix.size(), 3, "calendario rifatto")
	check(c2.nextMatch() != null, "c'è una prossima partita")
	var max_id := 0
	for p: Dictionary in c2.s.squad:
		max_id = maxi(max_id, p.id)
	check(c2.s.nextId > max_id, "nextId oltre l'id più alto")
	c2.refreshMarket(20)
	eq(c2.s.market.size(), 20, "il mercato si riempie")
	c.reset()
	return done()


func test_stagione_intera_salvata_e_ricaricata_uguale() -> bool:
	var c := _nuova("stagione.json", 4242)
	var res: Dictionary = {}
	var giornate := 0
	while not res.has("season"):
		var nm: Dictionary = c.nextMatch()
		c.myMatchTeam()
		c.aiMatchTeam(nm.opp)
		var sc := c.simScore(c.myRating(), nm.opp.rating)
		res = c.finishMatch(sc[0], sc[1], [])
		giornate += 1
	eq(giornate, 18, "18 giornate")
	eq(c.s.season, 2, "stagione 2")
	eq(c.s.day, 0, "calendario nuovo")
	var su := 0
	for d in 3:
		check(c.s.divs[d].size() == 10, "divisione %d da 10" % d)
	for h: Dictionary in c.s.history:
		su += 1
	eq(su, 1, "una stagione nello storico")
	var c2 := _ricarica(c.percorso)
	eq(JS.diff(c2.s, c.s), "", "ricaricata uguale")
	# e continua uguale: stessa giornata dopo il caricamento
	var a := c.finishMatch(1, 0, [])
	var b := c2.finishMatch(1, 0, [])
	eq(JS.diff(b, a), "", "giornata dopo il caricamento uguale")
	eq(JS.diff(c2.s, c.s), "", "stato dopo la giornata uguale")
	note("stagione: esito %s, posto %d, soldi %s" % [res.season.outcome, res.season.pos, CarrieraScript.fmtMoney(c.s.money)])
	c.reset()
	return done()
