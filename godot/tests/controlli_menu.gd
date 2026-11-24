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
	var titolare: Variant = c.s.lineup[9]
	var riserva: Variant = MenuRosa.bench_order(c.bench())[0].id
	n._tocca(titolare)
	eq(n.sel, titolare, "primo tocco: scelto")
	n._tocca(riserva)
	eq(n.tgt, riserva, "secondo tocco: confronto")
	n._tocca(riserva)   # terzo tocco sullo stesso = scambia (come il web)
	eq(c.s.lineup[9], riserva, "la riserva entra al posto del titolare")
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


func _bottoni_con(n: Node, testo: String) -> int:
	var k := 0
	for b: Node in n.find_children("*", "Button", true, false):
		if (b as Button).text == testo:
			k += 1
	return k


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


static func _bottoni(n: Node) -> Array:
	var out: Array = []
	for k in n.get_children():
		if k is Button:
			out.append(k)
		out.append_array(_bottoni(k))
	return out


func test_mercato_compra_al_secondo_tocco() -> bool:
	var c := _carriera()
	_inizia(c)
	var n := _apri("mercato", {"aperto": 0, "filtro": "T"})
	var id: Variant = n.aperto
	var soldi: int = c.s.money
	var p: Dictionary = c.s.market.filter(func(q: Dictionary) -> bool: return q.id == id)[0]
	var prezzo := int(p.price)   # buy toglie il campo price
	var b := n._bottone_compra(p, c.s) as Button
	check(b != null, "c'è il pulsante Compra")
	b.pressed.emit()
	eq(b.text, "Conferma", "primo tocco: chiede conferma")
	eq(c.s.money, soldi, "primo tocco: niente spesa")
	b.pressed.emit()
	eq(c.s.money, soldi - prezzo, "secondo tocco: pagato")
	check(c.player(id) != null, "il giocatore è in rosa")
	b.free()
	_finisci(n)
	return done()


func test_impostazioni_salvate_subito() -> bool:
	var c := _carriera()
	_inizia(c)
	var n := _apri("impostazioni")
	n._imposta("vibra", false)
	n._imposta("half", 240)
	eq(c.s.settings.vibra, false, "vibrazione spenta")
	eq(c.s.settings.half, 240, "tempo da 4:00")
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
	n._imposta("pos", "C")
	n._numero(1)
	n._conferma()
	check(c.s is Dictionary, "carriera creata")
	if c.s is Dictionary:
		eq(c.s.club, "Prova Menu", "nome della squadra")
		eq(int(c.s.crest.icon), 5, "stemma scelto")
		var champ: Array = c.s.squad.filter(func(p: Dictionary) -> bool: return p.get("champ", false))
		eq(champ.size(), 1, "un campione in rosa")
		if champ.size() == 1:
			eq(champ[0].pos, "C", "ruolo del campione")
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
