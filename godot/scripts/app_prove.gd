# Prove automatiche del flusso dell'app (le aggiunge App.avvio quando ci sono queste opzioni dopo "--"):
#   --stagione-bot            gioca col dito finto tutte le partite di campionato fino alla fine della stagione
#                             (da usare con --app --bot --veloce=K --tempo=SEC), poi salva, ricarica il file e
#                             controlla che la carriera ricaricata sia identica; stampa il riassunto ed esce
#                             (codice 0 se tutto bene, 1 se no). Senza carriera ne crea una (seme fisso 4242).
#   --app-schermate=CARTELLA  schermate 390×844 del giro menu → impostazioni → editor (taglio afro e chignon) →
#                             partita → fine partita → dopo partita → menu
#                             (da usare con --app --bot --veloce=K --tempo=SEC, finestra vera, non --headless)
#   --prova-uscite            "Esci" dalla pausa: in campionato sconfitta 0-3 registrata, in amichevole niente
#                             cambia e si torna al menu; stampa i controlli ed esce (codice 0 se tutti veri)
extends Node

const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const JS := preload("res://scripts/carriera/js.gd")
const ATTESA_MENU := 0.6
const ATTESA_PARTITA := 3.0

var _app: Node
var _giornate := 0
var _t0 := 0
var _scatti := 0


func _ready() -> void:
	_app = get_parent()
	_t0 = Time.get_ticks_msec()
	if _app.opzioni.has("app-schermate"):
		_giro_schermate.call_deferred()
		return
	_nuova_carriera_se_manca()
	if _app.opzioni.has("prova-uscite"):
		_prova_uscite.call_deferred()
		return
	_app.schermata_cambiata.connect(_stagione)


func _nuova_carriera_se_manca() -> bool:
	if _app.carriera.s != null:
		return false
	_app.carriera.create("FC Prova Bot", 1, 4242)
	print("prove: carriera nuova (seme 4242)")
	return true


# ---------------------------------------------------------------- stagione intera col dito finto
func _stagione(nome: String) -> void:
	if nome == "partita":
		return
	var u: Dictionary = _app.ultimo_esito
	if not u.is_empty() and u.res is Dictionary:
		var e: Dictionary = u.esito
		var c: CarrieraScript = _app.carriera
		_giornate += 1
		print("giornata %d: %d-%d (%s) · soldi %s · %d s" % [c.s.day if c.s.day > 0 else 18, e.gol_a, e.gol_b,
			"abbandonata" if e.abbandonata else "%d tiri" % int(e.statistiche.shots[0]), CarrieraScript.fmtMoney(c.s.money),
			(Time.get_ticks_msec() - _t0) / 1000])
		if u.res.has("season"):
			_fine_stagione(u.res.season)
			return
	await get_tree().create_timer(0.2).timeout
	_app.gioca_campionato()


func _fine_stagione(st: Dictionary) -> void:
	var c: CarrieraScript = _app.carriera
	var salvato := c.save()
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	var letto := c2.load()
	var diff := JS.diff(c2.s, c.s) if letto else "non si ricarica"
	var tab: Array = c.table(st.newDiv)
	print("fine stagione: %d giornate, posto %d in %s, esito %s, premio %s, bonus %s" % [_giornate, st.pos,
		CarrieraScript.DIV_NAMES[st.div], st.outcome, CarrieraScript.fmtMoney(st.prize), CarrieraScript.fmtMoney(st.bonus)])
	print("nuova stagione %d in %s, %d squadre in classifica, soldi %s" % [c.s.season, CarrieraScript.DIV_NAMES[st.newDiv], tab.size(), CarrieraScript.fmtMoney(c.s.money)])
	print("salvato %s · ricaricato dal file %s · uguale: %s" % [salvato, c2.fonte, "sì" if diff == "" else "NO " + diff])
	get_tree().quit(0 if salvato and diff == "" and _giornate == CarrieraScript.ROUNDS else 1)


# ---------------------------------------------------------------- uscite dalla pausa
func _prova_uscite() -> void:
	var c: CarrieraScript = _app.carriera
	var ok := true
	await _attendi(0.3)
	var giorno: int = c.s.day
	var persi: int = c.s.tab.me.l
	_app.gioca_campionato()
	await _attendi(1.5)
	_app.partita._mostra_pausa()
	_app.partita._esci_dalla_pausa()
	await _attendi(0.3)
	var u: Dictionary = _app.ultimo_esito
	ok = _controlla(u.get("esito", {}).get("abbandonata", false), "campionato: esito abbandonata") and ok
	ok = _controlla(u.esito.gol_a == 0 and u.esito.gol_b >= 3, "campionato: 0-3 a tavolino (%d-%d)" % [u.esito.gol_a, u.esito.gol_b]) and ok
	ok = _controlla(c.s.day == giorno + 1 and c.s.tab.me.l == persi + 1, "campionato: sconfitta in classifica, giornata avanti") and ok
	ok = _controlla(_app.schermata == _app.DOPO_PARTITA, "campionato: schermata dopo partita") and ok
	var soldi: int = c.s.money
	var giorno2: int = c.s.day
	_app.gioca_amichevole()
	await _attendi(1.5)
	_app.partita._mostra_pausa()
	_app.partita._esci_dalla_pausa()
	await _attendi(0.3)
	ok = _controlla(_app.schermata == _app.PRINCIPALE, "amichevole: di nuovo al menu principale") and ok
	ok = _controlla(c.s.money == soldi and c.s.day == giorno2, "amichevole: soldi e giornata invariati") and ok
	get_tree().quit(0 if ok else 1)


func _controlla(cond: bool, testo: String) -> bool:
	print("%s %s" % ["ok     " if cond else "FALLITO", testo])
	return cond


# ---------------------------------------------------------------- schermate del giro
func _giro_schermate() -> void:
	var dir: String = _app.opzioni["app-schermate"]
	await _attendi(ATTESA_MENU)
	if _nuova_carriera_se_manca(): # prima la schermata senza carriera, poi quella con la carriera nuova
		await _scatto(dir, "senza_carriera")
		_app.vai(_app.PRINCIPALE)
		await _attendi(ATTESA_MENU)
	await _scatto(dir, "menu")
	await _giro_impostazioni_editor(dir)
	_app.gioca_campionato()
	await _attendi(ATTESA_PARTITA)
	await _scatto(dir, "partita")
	while _app.partita != null and _app.partita.stato != "fine":
		await get_tree().process_frame
	await _attendi(0.7)
	await _scatto(dir, "fine")
	while _app.schermata != _app.DOPO_PARTITA:
		await get_tree().process_frame
	await _attendi(ATTESA_MENU)
	await _scatto(dir, "dopo")
	_app.vai(_app.PRINCIPALE)
	await _attendi(ATTESA_MENU)
	await _scatto(dir, "menu_dopo")
	get_tree().quit(0)


# Impostazioni (con controllo dell'audio spento / acceso) e editor dell'aspetto con un taglio vistoso, da vicino
# (scheda Capelli) e da lontano (scheda Scarpe). Il look provato non si salva.
func _giro_impostazioni_editor(dir: String) -> void:
	var st: Dictionary = _app.carriera.s.settings
	var suono: bool = st.get("sound", true)
	_app.vai("impostazioni")
	await _attendi(ATTESA_MENU)
	await _scatto(dir, "impostazioni")
	var master := AudioServer.get_bus_index("Master")
	st.sound = false
	_app.impostazioni()
	_controlla(AudioServer.is_bus_mute(master), "audio spento: bus principale muto")
	st.sound = true
	_app.impostazioni()
	_controlla(not AudioServer.is_bus_mute(master), "audio acceso: bus principale attivo")
	st.sound = suono
	_app.impostazioni()
	var p: Dictionary = _app.carriera.s.squad[0]
	for prova: Array in [["hair", 9, "editor_capelli"], ["boots", 13, "editor_corpo"]]:
		_app.vai("editor", {"flow": "look", "id": p.id, "tab": prova[0]})
		var ed: Node = get_tree().current_scene
		ed.d.look = ed.d.look.duplicate()
		ed.d.look.hair = prova[1]   # 9 afro, 13 chignon
		ed.d.look.beard = 6
		ed.mostra(false)
		await _attendi(1.2)
		await _scatto(dir, prova[2])
	_app.vai(_app.PRINCIPALE)
	await _attendi(ATTESA_MENU)


func _attendi(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _scatto(dir: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_scatti += 1
	var percorso := dir.path_join("%d_%s.png" % [_scatti, nome])
	if percorso.is_relative_path(): # relativo alla cartella del repo (quella che contiene godot/)
		percorso = ProjectSettings.globalize_path("res://").path_join("..").path_join(percorso).simplify_path()
	DirAccess.make_dir_recursive_absolute(percorso.get_base_dir())
	var err := img.save_png(percorso)
	print("schermata %s %dx%d errore=%d" % [percorso, img.get_width(), img.get_height(), err])
