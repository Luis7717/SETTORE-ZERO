# Prove a schermo dei menu (schermate 390×844, tocchi simulati, scorrimento, FPS). Serve la finestra (no --headless).
#   $G --path godot res://tests/prova_menu.tscn -- --tutte=shots/menu            tutte le schermate in una cartella
#   $G --path godot res://tests/prova_menu.tscn -- --schermata=rosa --foto=shots/rosa.png [--dopo=1]
#       [--azioni="tocca:200,400;aspetta:0.5;foto:shots/b.png;trascina:200,700,200,200,300"]
#   $G --path godot res://tests/prova_menu.tscn -- --fps=hub        FPS mentre si scorre su e giù col dito finto
# Carriera: quella vera (Carriera) caricata da tests/fixtures/carriera_menu.json, una carriera del web con
# 3 giornate giocate (godot/tools/dati_menu_web.mjs); salva in user://prova_menu.json, mai sul salvataggio vero.
# Opzioni: --senza-carriera, --tacca=47,34 (area sicura di un iPhone con la tacca).
extends Node

const JS := preload("res://scripts/carriera/js.gd")
const FIXTURE := "res://tests/fixtures/carriera_menu.json"
const SALVA_PROVA := "user://prova_menu.json"
const CARTELLA := "res://scenes/menu/%s.tscn"
const ATTESA := 0.9              # s: entrata finita e texture pronte
const LIMITE := 90.0             # s: oltre, la prova si chiude da sola (--limite=SEC)

# [nome file, schermata, argomento, azioni dopo l'apertura]
const TUTTE := [
	["01_principale", "principale", null, ""],
	["02_nuova_carriera", "nuova_carriera", {"kit": 3, "club": "Atletico Sole"}, ""],
	["03_editor_stemma", "editor", {"flow": "new", "club": "Atletico Sole", "kit": 3}, ""],
	["04_editor_campione", "editor", {"flow": "new", "club": "Atletico Sole", "kit": 3, "mode": "champ"}, ""],
	["05_editor_capelli", "editor", {"flow": "new", "club": "Atletico Sole", "kit": 3, "mode": "champ", "tab": "hair"}, ""],
	["06_editor_nome", "editor", {"flow": "new", "club": "Atletico Sole", "kit": 3, "mode": "champ", "tab": "me"}, ""],
	["07_hub", "hub", null, ""],
	["08_rosa", "rosa", null, ""],
	["08_rosa_formazione", "rosa", {"menu": "formazione"}, ""],
	["08_rosa_formazione_sotto", "rosa", {"menu": "formazione"}, "trascina:195,700,195,200,500;aspetta:0.6"],
	["09_rosa_scelto", "rosa", {"sel": "titolare:9"}, ""],
	["10_rosa_confronto", "rosa", {"sel": "titolare:9", "tgt": "panchina:0"}, ""],
	["10_rosa_statistiche", "rosa", {"sel": "titolare:9", "statistiche": true}, ""],
	["10_rosa_statistiche_sotto", "rosa", {"sel": "titolare:9", "statistiche": true}, "trascina:195,700,195,150,500;aspetta:0.6"],
	["10_rosa_statistiche_portiere", "rosa", {"sel": "titolare:0", "statistiche": true}, ""],
	["11_mercato", "mercato", null, ""],
	["12_mercato_aperto", "mercato", {"aperto": 0, "filtro": "A"}, ""],
	["12_mercato_statistiche", "mercato", {"aperto": 0, "filtro": "A", "statistiche": true}, ""],
	["12_mercato_offerte", "mercato", {"scheda": "offerte"}, ""],
	["13_classifica", "classifica", null, ""],
	["14_classifica_prima", "classifica", {"div": 0}, ""],
	["15_calendario", "calendario", null, ""],
	["16_amichevole", "amichevole", null, ""],
	["17_impostazioni", "impostazioni", null, ""],
	["18_come_si_gioca", "come_si_gioca", 0, ""],
	["19_come_si_gioca_5", "come_si_gioca", 4, ""],
	["20_dopo_partita", "dopo_partita", "PROVA", ""],
	["21_fine_stagione", "fine_stagione", {"pos": 2, "prize": 504, "bonus": 210, "outcome": "up", "div": 2, "newDiv": 1}, ""],
	["22_editor_aspetto", "editor", {"flow": "look", "id": "campione"}, ""],
	["23_editor_divisa", "editor", {"flow": "kit"}, ""],
	["24_uno_contro_uno", "uno_contro_uno", null, ""],
	["25_statistiche", "statistiche", "STATISTICHE", ""],
	["26_statistiche_pagella", "statistiche", "STATISTICHE", "trascina:195,760,195,90,500;aspetta:0.6"],
]

var carriera: Object = null
var ultimo_risultato: Variant = null
var schermo: Node = null
var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# se qualcosa si blocca (errore di script in una schermata) la prova esce lo stesso
	get_tree().create_timer(float(_args.get("limite", LIMITE))).timeout.connect(func() -> void:
		push_error("prova_menu: tempo scaduto")
		get_tree().quit(2))
	_carriera_nuova()
	await get_tree().process_frame
	if _args.has("controlli"):
		get_tree().quit(_controlli())
		return
	if _args.has("tutte"):
		await _tutte(_args.tutte)
	elif _args.has("fps"):
		await _fps(_args.fps)
	elif _args.has("schermata"):
		var a: Variant = JSON.parse_string(_args.arg) if _args.has("arg") else null
		await apri(_args.schermata, a)
		await aspetta(float(_args.get("dopo", ATTESA)))
		if _args.has("azioni"):
			await azioni(_args.azioni)
		if _args.has("foto"):
			foto(_args.foto)
	get_tree().quit()


## tests/controlli_menu.gd: ogni metodo test_* con le schermate nell'albero; 0 se tutti verdi
func _controlli() -> int:
	var falliti := 0
	var fatti := 0
	var obj: Object = (load("res://tests/controlli_menu.gd") as GDScript).new()
	for m in obj.get_method_list():
		var n: String = m.name
		if not n.begins_with("test_"):
			continue
		obj.failures.clear()
		var ok: Variant = obj.call(n)
		var verde: bool = ok == true and obj.failures.is_empty()
		fatti += 1
		if not verde:
			falliti += 1
		print("%s controlli_menu :: %s" % ["ok      " if verde else "FALLITO ", n])
		for f: String in obj.failures:
			print("         ", f)
	print("controlli menu: %d passati, %d falliti" % [fatti - falliti, falliti])
	return 0 if falliti == 0 else 1


func _carriera_nuova() -> void:
	carriera = null if _args.has("senza-carriera") else carriera_di_prova()
	MenuSchermata.carriera_prova = carriera
	var app := get_node_or_null("/root/App")
	if app != null and app.get("carriera") != null:
		app.set("carriera", carriera)


## carriera vera (Carriera) con lo stato della carriera di prova del web; salva su un file a parte
func carriera_di_prova() -> Carriera:
	var dati: Dictionary = JS.int_numbers(JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)))
	var c := Carriera.new()
	c.percorso = SALVA_PROVA
	c.s = c.completa(dati.s)
	ultimo_risultato = dati.lastRes
	return c


## apre una schermata come farebbe App.vai (scena + apri(arg))
func apri(nome: String, a: Variant) -> void:
	if schermo != null:
		schermo.queue_free()
		schermo = null
		await get_tree().process_frame
	MenuSvg.svuota()
	var sc := load(CARTELLA % nome) as PackedScene
	schermo = sc.instantiate()
	if schermo.has_method("apri"):
		schermo.apri(_risolvi(a))
	add_child(schermo)


# argomenti delle prove: "PROVA" per la fine partita, "rosa:N" = id dell'N-esimo giocatore, ...
func _risolvi(a: Variant) -> Variant:
	if a is String and a == "PROVA":
		return risultato_prova()
	if a is String and a == "STATISTICHE":
		return statistiche_prova(carriera.s if carriera != null else {})
	if a is Dictionary:
		var out := {}
		for k: String in a:
			out[k] = _risolvi_valore(a[k])
		return out
	if a is float:
		return int(a)
	return a


func _risolvi_valore(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if not (v is String) or carriera == null:
		return v
	var s: Dictionary = carriera.s
	if v == "campione":
		var ch: Variant = carriera.campione()
		return ch.id if ch != null else s.squad[0].id
	if v.begins_with("rosa:"):
		return s.squad[int(v.substr(5))].id
	if v.begins_with("titolare:"):
		return s.lineup[int(v.substr(9))]
	if v.begins_with("panchina:"):
		var b: Array = MenuRosa.bench_order(carriera.bench())
		return b[int(v.substr(9))].id
	return v


## fine partita di prova: stesso formato di G.res del web ({m, res, title})
func risultato_prova() -> Dictionary:
	var s: Dictionary = carriera.s if carriera != null else {}
	var mio := {"short": "ATL", "kit": {"crest": {"shape": 2, "pattern": 3, "icon": 6, "c1": 0xf2c200, "c2": 0x1b1b1b}}}
	var loro := {"short": "VAL", "kit": {"crest": {"shape": 0, "pattern": 1, "icon": 2, "c1": 0x0b7a3e, "c2": 0xffffff}}}
	var m := {
		"score": [2, 1], "teams": [mio, loro],
		"goalsLog": [{"team": 0, "name": "L. Mancini", "minute": 23}, {"team": 1, "name": "D. Okoye", "minute": 51}, {"team": 0, "name": "M. Ferri", "minute": 77}],
		"stats": {"shots": [9, 5], "onT": [5, 2], "poss": [61.0, 39.0], "corners": [4, 2], "fouls": [3, 6]},
	}
	var res: Variant = ultimo_risultato if carriera != null else null
	return {"m": m, "res": res, "title": "Terza Divisione · Giornata %d" % int(s.get("day", 3))}


## statistiche di prova (arg della schermata "statistiche"): la fine partita di prova più un tabellino inventato
## con gli undici titolari della carriera (o nomi finti senza carriera); il campione è il numero 9 in campo
static func statistiche_prova(s: Dictionary) -> Dictionary:
	var pos := ["P", "D", "D", "D", "D", "C", "C", "C", "C", "A", "A"]
	var conti := [{"parate": 3, "subiti": 1}, {"contrasti": 2, "subiti": 1}, {"contrasti": 4, "subiti": 1, "perse": 1},
		{"subiti": 1, "perse": 3}, {"intercetti": 2, "subiti": 1}, {"passaggi": 14, "perse": 2}, {"assist": 1, "passaggi": 9},
		{"dribbling": 2, "perse": 4}, {"passaggi": 6}, {"gol": 2, "dribbling": 3, "tiri": 4}, {"tiri": 2, "perse": 1}]
	var squad := {}
	for p: Dictionary in s.get("squad", []):
		squad[p.id] = p
	var lineup: Array = s.get("lineup", [])
	var gioc: Array = []
	for i in 11:
		var p: Dictionary = squad.get(lineup[i], {}) if i < lineup.size() else {}
		gioc.append({"id": p.get("id", "p%d" % i), "name": p.get("name", "Giocatore %d" % (i + 1)), "pos": pos[i],
			"champ": i == 9, "num": i + 1, "conti": conti[i]})
	var tiri := [{"team": 0, "x": 4.0, "y": 38.0, "esito": "gol"}, {"team": 0, "x": -8.0, "y": 31.0, "esito": "parato"},
		{"team": 0, "x": 12.0, "y": 27.0, "esito": "fuori"}, {"team": 0, "x": -2.0, "y": 44.0, "esito": "gol"},
		{"team": 0, "x": 18.0, "y": 36.0, "esito": "respinto"}, {"team": 0, "x": 0.5, "y": 22.0, "esito": "fuori"},
		{"team": 1, "x": 3.0, "y": -40.0, "esito": "gol"}, {"team": 1, "x": -14.0, "y": -30.0, "esito": "parato"},
		{"team": 1, "x": 9.0, "y": -25.0, "esito": "fuori"}]
	var mio := {"short": "ATL", "kit": {"crest": {"shape": 2, "pattern": 3, "icon": 6, "c1": 0xf2c200, "c2": 0x1b1b1b}}}
	var loro := {"short": "VAL", "kit": {"crest": {"shape": 0, "pattern": 1, "icon": 2, "c1": 0x0b7a3e, "c2": 0xffffff}}}
	var m := {"score": [2, 1], "teams": [mio, loro], "goalsLog": [],
		"stats": {"shots": [6, 3], "onT": [3, 2], "poss": [61.0, 39.0], "corners": [4, 2], "fouls": [3, 6], "saves": [1, 1]}}
	var tab := {"me": 0, "passaggi": [[212, 251], [131, 170]], "km": [52.4, 49.8], "tiri": tiri, "giocatori": gioc}
	return {"m": m, "tabellino": tab, "title": "Terza Divisione · Giornata 4", "dopo": "PROVA"}


func aspetta(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func foto(percorso: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := percorso if percorso.is_absolute_path() or percorso.begins_with("res://") else "res://" + percorso
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	img.save_png(p)
	print("foto: ", p)


## azioni separate da ";": tocca:x,y  trascina:x0,y0,x1,y1,ms  aspetta:s  foto:percorso
func azioni(testo: String) -> void:
	for a in testo.split(";", false):
		var kv := a.split(":", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"tocca":
				var p := v.split(",")
				await tocca(Vector2(float(p[0]), float(p[1])))
			"trascina":
				var p := v.split(",")
				await trascina(Vector2(float(p[0]), float(p[1])), Vector2(float(p[2]), float(p[3])), float(p[4]) / 1000.0)
			"aspetta":
				await aspetta(float(v))
			"foto":
				await foto(v)


func tocca(p: Vector2) -> void:
	var giu := InputEventMouseButton.new()
	giu.button_index = MOUSE_BUTTON_LEFT
	giu.pressed = true
	giu.position = p
	giu.global_position = p
	get_viewport().push_input(giu)
	await get_tree().process_frame
	var su := giu.duplicate() as InputEventMouseButton
	su.pressed = false
	get_viewport().push_input(su)
	await get_tree().process_frame
	await get_tree().process_frame


func trascina(a: Vector2, b: Vector2, durata: float) -> void:
	var giu := InputEventMouseButton.new()
	giu.button_index = MOUSE_BUTTON_LEFT
	giu.pressed = true
	giu.position = a
	giu.global_position = a
	get_viewport().push_input(giu)
	var passi := maxi(2, int(durata * 60.0))
	var prima := a
	for i in passi:
		await get_tree().process_frame
		var p := a.lerp(b, float(i + 1) / passi)
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		mv.relative = p - prima
		mv.velocity = (p - prima) * 60.0
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(mv)
		prima = p
	var su := giu.duplicate() as InputEventMouseButton
	su.pressed = false
	su.position = b
	su.global_position = b
	get_viewport().push_input(su)
	await get_tree().process_frame


func _tutte(cartella: String) -> void:
	var solo: String = _args.get("solo", "")
	for voce: Array in TUTTE:
		if solo != "" and not str(voce[0]).contains(solo):
			continue
		_carriera_nuova()
		await apri(voce[1], voce[2])
		await aspetta(ATTESA)
		if voce[3] != "":
			await azioni(voce[3])
		await foto(cartella.path_join(voce[0] + ".png"))


# FPS mentre si scorre: 3 trascinamenti su e giù, poi la media dei fotogrammi
func _fps(nome: String) -> void:
	await apri(nome, null)
	await aspetta(ATTESA)
	var t0 := Time.get_ticks_usec()
	var f0 := Engine.get_frames_drawn()
	var peggiore := 0.0
	var prima := t0
	var sc: Variant = schermo.get("scorri")
	var massimo := 0
	for k in 3:
		await trascina(Vector2(200, 700), Vector2(200, 200), 0.35)
		if sc != null:
			massimo = maxi(massimo, sc.scroll_vertical)
		for i in 30:
			await get_tree().process_frame
			var ora := Time.get_ticks_usec()
			peggiore = maxf(peggiore, (ora - prima) / 1000.0)
			prima = ora
		await trascina(Vector2(200, 200), Vector2(200, 700), 0.35)
		for i in 30:
			await get_tree().process_frame
			var ora := Time.get_ticks_usec()
			peggiore = maxf(peggiore, (ora - prima) / 1000.0)
			prima = ora
	var sec := (Time.get_ticks_usec() - t0) / 1e6
	print("FPS %s: %.1f medi, fotogramma peggiore %.1f ms, scorrimento col dito fino a %d px, alla fine %s" % [nome, (Engine.get_frames_drawn() - f0) / sec, peggiore, massimo, str(sc.scroll_vertical) if sc != null else "-"])
