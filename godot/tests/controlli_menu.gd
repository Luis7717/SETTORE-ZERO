# Schermate dei menu senza finestra, con la carriera vera (tests/fixtures/carriera_menu.json, salvata su un file di
# prova): ogni schermata si costruisce, e i gesti principali cambiano la carriera come nel web (scambio in Rosa,
# acquisto in due tocchi, impostazioni salvate, nuova squadra dall'editor, ritorno da dopo_partita).
# Navigazione e partite passano da MenuSchermata.deviazione, così nessuna scena cambia davvero.
# Servono le schermate dentro l'albero (_ready), che il runner dei test (run_tests.gd, tutto in _init) non ha:
# si lanciano con  $G --headless --path godot res://tests/prova_menu.tscn -- --controlli  (uscita 0 = tutto verde).
extends "res://tests/test_base.gd"

const JS := preload("res://scripts/carriera/js.gd")
const FIXTURE := "res://tests/fixtures/carriera_menu.json"
const SALVA := "user://test_menu_schermate.json"
const SCHERMATE := ["principale", "nuova_carriera", "hub", "rosa", "mercato", "classifica", "calendario", "amichevole",
	"uno_contro_uno", "impostazioni", "come_si_gioca", "editor", "dopo_partita", "fine_stagione", "statistiche"]
const ProvaMenu := preload("res://tests/prova_menu.gd")
const Stili := preload("res://sim/stili.gd")
const MercatoSquadre := preload("res://scripts/carriera/mercato_squadre.gd")
const Sotto := preload("res://sim/sottostat.gd")

var _andate: Array = []
var _app_carriera: Variant = null


func _carriera() -> Carriera:
	var dati: Dictionary = JS.int_numbers(JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)))
	var c := Carriera.new()
	c.percorso = SALVA
	c.s = c.completa(dati.s)
	return c


# prepara carriera e deviazione; se c'è l'autoload App la sua carriera si mette da parte (mai il salvataggio vero)
func _inizia(c: Object) -> void:
	_andate = []
	MenuSchermata.carriera_prova = c
	MenuSchermata.deviazione = func(nome: String, a: Variant) -> void: _andate.append([nome, a])
	var app := _root().get_node_or_null("App")
	if app != null and "carriera" in app:
		_app_carriera = app.carriera
		app.carriera = c


func _finisci(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.get_parent().remove_child(n)
		n.free()
	MenuSchermata.deviazione = Callable()
	MenuSchermata.carriera_prova = null
	var app := _root().get_node_or_null("App")
	if app != null and _app_carriera != null:
		app.carriera = _app_carriera
	_app_carriera = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SALVA))


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _apri(nome: String, a: Variant = null) -> MenuSchermata:
	var n := (load("res://scenes/menu/%s.tscn" % nome) as PackedScene).instantiate() as MenuSchermata
	n.apri(a)
	_root().add_child(n)   # _ready subito: prepara + costruisci
	return n


func test_ogni_schermata_si_costruisce() -> bool:
	_inizia(_carriera())
	for nome: String in SCHERMATE:
		var a: Variant = null
		if nome == "dopo_partita":
			a = {"esito": {"gol_a": 2, "gol_b": 1, "marcatori": [{"team": 0, "name": "L. Mancini", "minute": 23}], "me": 0,
				"statistiche": {"shots": [5, 3], "onT": [3, 1], "poss": [60.0, 40.0], "corners": [2, 1], "fouls": [1, 2]},
				"abbandonata": false, "tipo": "amichevole"}, "res": null, "titolo": "Amichevole", "tipo": "amichevole"}
		elif nome == "statistiche":
			a = ProvaMenu.statistiche_prova(MenuSchermata.carriera_prova.s)
		elif nome == "fine_stagione":
			a = {"pos": 1, "prize": 300, "bonus": 100, "outcome": "up", "div": 2, "newDiv": 1}
		var n := _apri(nome, a)
		check(n.corpo.get_child_count() > 0 or n.fisso_sopra.get_child_count() > 0, "%s: schermata vuota" % nome)
		_finisci(n)
		_inizia(MenuSchermata.carriera_prova if MenuSchermata.carriera_prova != null else _carriera())
	_finisci(null)
	return done()


func test_rosa_due_tocchi_scambiano_titolare_e_panchina() -> bool:
	var c := _carriera()
	_inizia(c)
	var n := _apri("rosa")
	var posto := 9 if not c.player(c.s.lineup[9]).get("champ", false) else 10   # il campione non va in panchina
	var titolare: Variant = c.s.lineup[posto]
	var riserva: Variant = MenuRosa.bench_order(c.bench())[0].id
	n._tocca(titolare)
	eq(n.sel, titolare, "primo tocco: scelto")
	n._tocca(riserva)
	eq(n.tgt, riserva, "secondo tocco: confronto")
	n._tocca(riserva)   # terzo tocco sullo stesso = scambia (come il web)
	eq(c.s.lineup[posto], riserva, "la riserva entra al posto del titolare")
	check(not c.s.lineup.has(titolare), "il titolare va in panchina")
	_finisci(n)
	return done()


# Luis 2026-11-24: si modifica solo il campione creato all'inizio. Nella Rosa il tasto Aspetto c'è solo per lui;
# l'editor non apre l'aspetto degli altri giocatori
func test_aspetto_solo_del_campione() -> bool:
	var c := _carriera()
	_inizia(c)
	var ch: Variant = c.campione()
	check(ch != null, "la carriera di prova ha il campione")
	var altro: Variant = null
	for p: Dictionary in c.s.squad:
		if not p.get("champ", false):
			altro = p
			break
	for caso: Array in [[ch, true, "campione"], [altro, false, "altro giocatore"]]:
		var n := _apri("rosa", {"sel": caso[0].id})
		eq(_bottoni_con(n, "Aspetto"), 1 if caso[1] else 0, "%s: tasto Aspetto" % caso[2])
		_finisci(n)
		_inizia(c)
		var e := _apri("editor", {"flow": "look", "id": caso[0].id})
		eq(e.mode == "look", caso[1], "%s: editor dell'aspetto" % caso[2])
		_finisci(e)
		_inizia(c)
	_finisci(null)
	return done()


# Rosa e tattica dalla pausa (modo partita): niente Aspetto né Vendi (neanche sul campione), "Torna alla partita",
# cambi rimasti in alto, chi è uscito non rientra
func test_rosa_in_partita_senza_aspetto_e_vendi() -> bool:
	var c := _carriera()
	_inizia(c)
	var cambi = load("res://scripts/partita/cambi_partita.gd").new()
	var ch: Variant = c.campione()
	var tornata := [false]
	for chi: Variant in [ch.id, c.s.lineup[9]]:
		var n := _apri("rosa", {"in_partita": true, "cambi": cambi, "carriera": c, "sel": chi})
		eq(_bottoni_con(n, "Aspetto"), 0, "in partita niente Aspetto")
		var vendi := 0
		for b: Node in n.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Vendi"):
				vendi += 1
		eq(vendi, 0, "in partita niente Vendi")
		eq(_bottoni_con(n, "Torna alla partita"), 1, "c'è Torna alla partita")
		eq(n.pillola, "Cambi 5/5", "cambi rimasti in alto")
		_finisci(n)
		_inizia(c)
	var n := _apri("rosa", {"in_partita": true, "cambi": cambi, "carriera": c})
	n.chiusa.connect(func() -> void: tornata[0] = true)
	var tit: Variant = c.s.lineup[9]
	var riserva: Variant = MenuRosa.bench_order(c.bench())[0].id
	n._tocca(tit)
	n._tocca(riserva)
	n._tocca(riserva)
	eq(c.s.lineup[9], riserva, "sostituzione fatta")
	eq(n.pillola, "Cambi 4/5", "un cambio in meno")
	n._tocca(tit)
	eq(n.sel, null, "chi è uscito non si sceglie")
	check(not c.s.lineup.has(tit), "e non rientra")
	if ch != null and c.s.lineup.has(ch.id):
		var r2: Variant = MenuRosa.bench_order(c.bench())[1].id
		n._tocca(ch.id)
		n._tocca(r2)
		n._tocca(r2)
		check(not c.s.lineup.has(ch.id), "in partita il campione si può sostituire")
	for b: Node in n.find_children("*", "Button", true, false):
		if (b as Button).text == "Torna alla partita":
			(b as Button).pressed.emit()
	check(tornata[0], "Torna alla partita chiude")
	_finisci(n)
	return done()


# Luis 2026-11-24: nella Rosa del menu il campione non va in panchina (scambi tra titolari sì)
func test_rosa_menu_campione_resta_in_campo() -> bool:
	var c := _carriera()
	_inizia(c)
	var ch: Variant = c.campione()
	check(ch != null and c.s.lineup.has(ch.id), "il campione è titolare")
	var n := _apri("rosa")
	var riserva: Variant = MenuRosa.bench_order(c.bench())[0].id
	n._tocca(ch.id)
	n._tocca(riserva)
	n._tocca(riserva)
	check(c.s.lineup.has(ch.id) and not c.s.lineup.has(riserva), "non va in panchina")
	var altro: Variant = c.s.lineup[0] if c.s.lineup[0] != ch.id else c.s.lineup[1]
	var i_ch: int = c.s.lineup.find(ch.id)
	n._tocca(ch.id)
	n._tocca(altro)
	n._tocca(altro)
	check(c.s.lineup.find(ch.id) != i_ch and c.s.lineup.has(ch.id), "tra titolari cambia posto")
	_finisci(n)
	return done()


func _bottoni_con(n: Node, testo: String) -> int:
	var k := 0
	for b: Node in n.find_children("*", "Button", true, false):
		if (b as Button).text == testo:
			k += 1
	return k


# Calci piazzati (Luis 2026-11-26): 5 scelte, ognuna apre la lista dei titolari; la scelta si salva e si torna alle 5
func test_rosa_calci_piazzati() -> bool:
	var c := _carriera()
	_inizia(c)
	var n := _apri("rosa")
	check(_bottoni_con(n, "Calci piazzati  ▾") == 1, "tasto Calci piazzati nella Rosa")
	n._apri_menu("piazzati")
	var voci := _bottoni(n._velo)
	eq(voci.size(), 1 + 5, "× più le 5 scelte")
	voci[1].pressed.emit()   # Rigorista
	eq(n._menu, "piazzati:rig", "si apre la scelta del rigorista")
	var scelte := _bottoni(n._velo)
	eq(scelte.size(), 1 + 1 + 10, "×, Automatico e i 10 titolari di movimento")
	scelte[2].pressed.emit()   # il primo titolare dopo il portiere
	eq(c.piazzati().rig, c.s.lineup[1], "rigorista scelto e salvato")
	eq(n._menu, "piazzati", "si torna alle 5 scelte")
	n._apri_menu("piazzati:rig")
	_bottoni(n._velo)[1].pressed.emit()   # Automatico
	eq(c.piazzati().rig, null, "di nuovo automatico")
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SALVA))
	check(dati.carriera.piazzati is Dictionary and dati.carriera.piazzati.size() == 5, "salvato su file nel campo nuovo `piazzati`")
	_finisci(n)
	return done()


# i tre tasti in alto (Formazione, Attacco, Difesa) aprono il loro menu; una scelta si salva e chiude il menu
func test_rosa_menu_formazione_e_stili() -> bool:
	var c := _carriera()
	_inizia(c)
	var n := _apri("rosa")
	check(n._velo == null, "all'inizio nessun menu aperto")
	n._apri_menu("formazione")
	check(n._velo != null and is_instance_valid(n._velo), "Formazione apre il menu")
	var voci := _bottoni(n._velo)
	eq(voci.size(), 1 + C.FORMATIONS.size(), "× più una voce per formazione")
	voci[1 + C.FORMATIONS.keys().find("5-3-2")].pressed.emit()
	eq(c.s.formation, "5-3-2", "formazione scelta")
	eq(c.s.lineup.size(), 11, "11 titolari")
	eq(n._menu, "", "menu chiuso dopo la scelta")
	n._apri_menu("attacco")
	_bottoni(n._velo)[1 + Stili.ATTACCO.find("contropiede")].pressed.emit()
	eq(c.stileAtt(), "contropiede", "stile offensivo scelto")
	n._apri_menu("difesa")
	_bottoni(n._velo)[1 + Stili.DIFESA.find("catenaccio")].pressed.emit()
	eq(c.stileDif(), "catenaccio", "stile difensivo scelto")
	eq(c.stileAtt(), "contropiede", "l'attacco resta")
	n._apri_menu("difesa")
	_bottoni(n._velo)[0].pressed.emit()   # ×
	eq(n._menu, "", "la × chiude")
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SALVA))
	eq([dati.carriera.formation, dati.carriera.stileAtt, dati.carriera.stileDif], ["5-3-2", "contropiede", "catenaccio"], "salvato su file con le chiavi di sempre")
	_finisci(n)
	return done()


# Statistiche dettagliate (Luis 2026-11-25, "come su FIFA"): dalla Rosa il tasto Statistiche c'è per tutti (campione
# compreso), apre la vista coi gruppi (portiere: PORTIERE per primo), nomi e valori delle sotto-statistiche; la ×
# chiude. Anche dal Mercato, sulla scheda di un giocatore delle altre squadre.
func test_statistiche_dalla_rosa_e_dal_mercato() -> bool:
	var c := _carriera()
	_inizia(c)
	var ch: Variant = c.campione()
	var altro: Variant = null
	var portiere: Variant = null
	for p: Dictionary in c.s.squad:
		if not p.get("champ", false) and p.pos != "P" and altro == null:
			altro = p
		if p.pos == "P" and portiere == null:
			portiere = p
	for caso: Array in [[ch, "campione"], [altro, "altro giocatore"], [portiere, "portiere"]]:
		var p: Dictionary = caso[0]
		var n := _apri("rosa", {"sel": p.id})
		var tasti := _bottoni(n).filter(func(b: Button) -> bool: return b.text == "Statistiche")
		eq(tasti.size(), 1, "%s: tasto Statistiche" % caso[1])
		if p.get("champ", false):
			eq(_bottoni_con(n, "Aspetto"), 1, "campione: Aspetto resta")
		else:
			eq(_bottoni_con(n, "Cerca acquirenti"), 1, "%s: Cerca acquirenti resta" % caso[1])
		if tasti.is_empty():
			_finisci(n)
			_inizia(c)
			continue
		(tasti[0] as Button).pressed.emit()
		var v: Control = n._stat_velo
		check(v != null and is_instance_valid(v), "%s: la vista si apre" % caso[1])
		if v == null:
			_finisci(n)
			_inizia(c)
			continue
		var testi: Array = v.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text)
		for g: String in ["VELOCITÀ", "TIRO", "PASSAGGI", "DRIBBLING", "DIFESA", "FISICO"]:
			check(testi.has(g), "%s: gruppo %s" % [caso[1], g])
		var gk: bool = p.pos == "P"
		eq(testi.has("PORTIERE"), gk, "%s: gruppo PORTIERE solo per il portiere" % caso[1])
		var gruppi: Array = v.find_children("Gruppo_*", "", true, false)
		eq(gruppi.size(), 7 if gk else 6, "%s: numero di gruppi" % caso[1])
		if not gruppi.is_empty():
			eq(str(gruppi[0].name), "Gruppo_por" if gk else "Gruppo_vel", "%s: primo gruppo" % caso[1])
		for k: String in ["acc", "fin", "pco", "drb", "ctr", "frz", "tes"]:
			check(testi.has(Sotto.NOMI[k]), "%s: nome %s" % [caso[1], Sotto.NOMI[k]])
		if gk:
			check(testi.has(Sotto.NOMI["rif"]), "portiere: Riflessi")
		# valori: il numero grande della Velocità e quello della Finalizzazione
		var vel: Array = v.find_children("Gruppo_vel", "", true, false)
		if not vel.is_empty():
			var grande: Node = (vel[0] as Node).find_child("Valore", true, false)
			eq((grande as Label).text if grande is Label else "", str(int(p.vel)), "%s: valore della Velocità" % caso[1])
		var fin_v := str(int(roundf(Sotto.valore(p, "fin"))))
		var riga_fin: Variant = null
		for l: Node in v.find_children("*", "Label", true, false):
			if (l as Label).text == Sotto.NOMI["fin"]:
				riga_fin = l
		check(riga_fin != null and (riga_fin.get_parent().get_child(1) as Label).text == fin_v, "%s: valore della Finalizzazione %s" % [caso[1], fin_v])
		_bottoni(v)[0].pressed.emit()   # ×
		check(n._stat_velo == null, "%s: la × chiude" % caso[1])
		_finisci(n)
		_inizia(c)
	# Mercato: la scheda aperta ha Statistiche, che apre la stessa vista
	var m := _apri("mercato", {"aperto": 0, "filtro": "T"})
	var tm := _bottoni(m).filter(func(b: Button) -> bool: return b.text == "Statistiche")
	eq(tm.size(), 1, "mercato: tasto Statistiche nella scheda")
	if not tm.is_empty():
		(tm[0] as Button).pressed.emit()
		check(m._stat_velo != null and is_instance_valid(m._stat_velo), "mercato: la vista si apre")
		if m._stat_velo != null:
			check(m._stat_velo.find_children("Gruppo_*", "", true, false).size() >= 6, "mercato: gruppi mostrati")
	_finisci(m)
	return done()


static func _bottoni(n: Node) -> Array:
	var out: Array = []
	for k in n.get_children():
		if k is Button:
			out.append(k)
		out.append_array(_bottoni(k))
	return out


func test_mercato_offerta_alla_squadra() -> bool:
	var c := _carriera()
	_inizia(c)
	c.s.money = 100000
	var n := _apri("mercato", {"aperto": 0, "filtro": "T"})
	var k: Variant = n.aperto
	check(k is String, "scheda aperta sul primo giocatore")
	var parti: PackedStringArray = str(k).split(":")
	var g: Variant = MercatoSquadre.trova(c, parti[0], int(parti[1]))
	check(g != null, "giocatore di una squadra della CPU")
	var soldi: int = c.s.money
	var n0: int = c.s.squad.size()
	n._passo(-0.05)
	n._passo(-0.05)
	near(n.parte, 0.9, 1e-6, "due passi in giù = 90%")
	n._offri(parti[0], int(parti[1]), MercatoSquadre.importo(g.prezzo, n.parte), str(g.p.name))
	eq(c.s.money, soldi, "al 90% controfferta: niente spesa")
	eq(MercatoSquadre.trattativa(c.s, parti[0], int(parti[1])).esito, "contro", "controfferta registrata")
	eq(MercatoSquadre.accetta_contro(c, parti[0], int(parti[1])), "", "controfferta accettata")
	eq(c.s.squad.size(), n0 + 1, "il giocatore è in rosa")
	eq(c.s.money, soldi - int(g.prezzo), "pagato il prezzo chiesto")
	_finisci(n)
	# scheda delle offerte: Accetta vende
	var p: Dictionary = c.s.squad[4]
	c.s.offerte = [{"id": p.id, "squadra": parti[0], "soldi": 321, "scade": MercatoSquadre.giorno(c.s) + 2}]
	_inizia(c) # _finisci ha tolto la carriera di prova
	var n2 := _apri("mercato", {"scheda": "offerte"})
	eq(n2.vista, "offerte", "si apre sulle offerte")
	var soldi2: int = c.s.money
	n2._accetta(0, str(p.name))
	eq(c.s.money, soldi2 + 321, "offerta accettata: incassato")
	check(c.player(p.id) == null, "venduto")
	_finisci(n2)
	# dopo la partita: riga dell'offerta e tasto per andare a vederle
	_inizia(c)
	var q: Dictionary = c.s.squad[5]
	var dp := _apri("dopo_partita", {"esito": {"gol_a": 1, "gol_b": 0, "me": 0}, "res": null, "titolo": "Prova"})
	var carta: Variant = dp._offerte_mercato({"offerte": [{"id": q.id, "squadra": parti[0], "soldi": 222, "scade": 99}]})
	check(carta is Control, "c'è la carta delle offerte")
	if carta is Control:
		var testi := (carta as Control).find_children("*", "RichTextLabel", true, false).map(func(l: Node) -> String: return (l as RichTextLabel).get_parsed_text())
		check(str(testi).contains("offre") and str(testi).contains(str(q.name)), "riga dell'offerta: %s" % str(testi))
		check(_bottoni(carta).any(func(x: Button) -> bool: return x.text == "Vedi le offerte"), "tasto Vedi le offerte")
		(carta as Control).free()
	check(dp._offerte_mercato({}) == null, "senza offerte niente carta")
	_finisci(dp)
	return done()


func test_impostazioni_salvate_subito() -> bool:
	var c := _carriera()
	_inizia(c)
	var n := _apri("impostazioni")
	n._imposta("vibra", false)
	n._imposta("half", 240)
	eq(c.s.settings.vibra, false, "vibrazione spenta")
	eq(c.s.settings.half, 240, "tempo da 4:00")
	eq(c.s.settings.get("nomi"), "tutti", "nomi sopra i giocatori: predefinito Tutti")
	n._imposta("nomi", "pallone")
	eq(c.s.settings.nomi, "pallone", "nomi: solo pallone e controllato")
	check(FileAccess.file_exists(SALVA), "salvato su file")
	_finisci(n)
	return done()


func test_editor_nuova_squadra_crea_la_carriera_e_va_all_allenamento() -> bool:
	var c := Carriera.new()
	c.percorso = SALVA
	_inizia(c)
	var n := _apri("editor", {"flow": "new", "club": "Prova Menu", "kit": 2})
	eq(n.mode, "crest", "prima lo stemma")
	n._imposta("crest.icon", 5)
	n._conferma()
	eq(n.mode, "champ", "poi il campione")
	n._imposta("ruolo", "COC")
	n._numero(1)
	n._conferma()
	check(c.s is Dictionary, "carriera creata")
	if c.s is Dictionary:
		eq(c.s.club, "Prova Menu", "nome della squadra")
		eq(int(c.s.crest.icon), 5, "stemma scelto")
		var champ: Array = c.s.squad.filter(func(p: Dictionary) -> bool: return p.get("champ", false))
		eq(champ.size(), 1, "un campione in rosa")
		if champ.size() == 1:
			eq([champ[0].pos, champ[0].get("ruolo")], ["C", "COC"], "ruolo del campione (specifico, col suo gruppo)")
			eq(int(champ[0].num), 10, "numero 9 + 1")
	eq(_andate.back()[0] if not _andate.is_empty() else "", "gioca:allenamento", "parte l'allenamento guidato")
	_finisci(n)
	return done()


func test_dopo_partita_continua_porta_alla_fine_stagione() -> bool:
	_inizia(_carriera())
	var stagione := {"pos": 2, "prize": 140, "bonus": 70, "outcome": "up", "div": 2, "newDiv": 1}
	var n := _apri("dopo_partita", {"esito": {"gol_a": 1, "gol_b": 0, "marcatori": [], "statistiche": {}, "me": 0},
		"res": {"income": 70, "wages": 20, "grown": [], "others": [], "season": stagione}, "titolo": "Giornata 18", "tipo": "campionato"})
	var ultimo: Button = null
	for b in n.corpo.find_children("*", "Button", true, false):
		ultimo = b
	check(ultimo != null and ultimo.text == "CONTINUA", "c'è Continua")
	if ultimo != null:
		ultimo.pressed.emit()
	eq(_andate.back()[0] if not _andate.is_empty() else "", "fine_stagione", "a fine stagione si va al riepilogo")
	_finisci(n)
	return done()


# Luis 2026-11-25: riepilogo a metà stagione (statistiche che cambiano solo lì, anche per gli avversari)
func test_meta_stagione_riepilogo() -> bool:
	_inizia(_carriera())
	var meta := {"rosa": [{"id": 5, "nome": "M. Rossi", "pos": "C", "eta": 24, "media": 6.8, "punti": 2, "prima": 64, "dopo": 66,
		"cambi": {"pco": 2, "agi": 1, "res": -1}}, {"id": 6, "nome": "L. Bianchi", "pos": "D", "eta": 33, "media": null,
		"punti": -2, "prima": 70, "dopo": 69, "cambi": {"acc": -2}}],
		"cpu": [{"id": "x", "name": "Atletico Prova", "short": "ATL", "media": 6.6, "div": 2}]}
	var n := _apri("dopo_partita", {"esito": {"gol_a": 1, "gol_b": 0, "marcatori": [], "statistiche": {}, "me": 0},
		"res": {"income": 70, "wages": 20, "grown": [], "others": [], "meta_stagione": meta}, "titolo": "Giornata 9", "tipo": "campionato"})
	var ultimo: Button = null
	for bt in n.corpo.find_children("*", "Button", true, false):
		ultimo = bt
	if ultimo != null:
		ultimo.pressed.emit()
	eq(_andate.back()[0] if not _andate.is_empty() else "", "meta_stagione", "a metà stagione Continua apre il riepilogo")
	_finisci(n)
	var r := _apri("meta_stagione", meta)
	var testi := ""
	for l in r.corpo.find_children("*", "RichTextLabel", true, false):
		testi += (l as RichTextLabel).text
	check(testi.contains("M. Rossi") and testi.contains("64 → "), "riga del giocatore con prima → dopo")
	check(testi.contains("Passaggio corto"), "sotto-statistiche cambiate")
	check(testi.contains("non ha giocato"), "chi non ha giocato")
	var bottoni: Array = r.corpo.find_children("*", "Button", true, false)
	eq((bottoni.back() as Button).text if not bottoni.is_empty() else "", "AVANTI", "tasto Avanti")
	_finisci(r)
	return done()


func test_dopo_partita_apre_le_statistiche_e_torna_indietro() -> bool:
	_inizia(_carriera())
	var tab: Dictionary = ProvaMenu.statistiche_prova(MenuSchermata.carriera_prova.s).tabellino
	var a := {"esito": {"gol_a": 2, "gol_b": 1, "marcatori": [], "statistiche": {"shots": [6, 3]}, "me": 0, "tabellino": tab},
		"res": null, "titolo": "Amichevole", "tipo": "amichevole"}
	var n := _apri("dopo_partita", a)
	var bottoni: Array = n.corpo.find_children("*", "Button", true, false)
	var stats: Button = null
	for b: Button in bottoni:
		if b.text == "STATISTICHE E PAGELLE":
			stats = b
	check(stats != null, "c'è il tasto delle statistiche")
	eq((bottoni.back() as Button).text if not bottoni.is_empty() else "", "CONTINUA", "Continua resta l'ultimo")
	if stats != null:
		stats.pressed.emit()
	var andata: Array = _andate.back() if not _andate.is_empty() else ["", null]
	eq(andata[0], "statistiche", "si apre la schermata delle statistiche")
	_finisci(n)
	if andata[0] != "statistiche":
		return done()
	_inizia(_carriera())
	var s := _apri("statistiche", andata[1])
	var pagella := s.corpo.find_children("*", "RichTextLabel", true, false).filter(func(l: RichTextLabel) -> bool:
		return l.text.contains("MIGLIORE IN CAMPO"))
	eq(pagella.size(), 1, "un solo migliore in campo")
	s.torna_indietro()
	eq(_andate.back()[0], "dopo_partita", "‹ torna al dopo partita")
	check(_andate.back()[1] == a, "con lo stesso esito")
	_finisci(s)
	var senza := a.duplicate(true)
	senza.esito.erase("tabellino")
	_inizia(_carriera())
	var n2 := _apri("dopo_partita", senza)
	check(n2.corpo.find_children("*", "Button", true, false).all(func(b: Button) -> bool: return b.text != "STATISTICHE E PAGELLE"),
		"senza tabellino (vecchio esito) niente tasto")
	_finisci(n2)
	return done()
