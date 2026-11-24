# Base di tutte le schermate dei menu (UI.show / redraw / toast / head di src/ui.js).
# Ogni schermata estende questa classe e riempie `corpo` in costruisci(); ridisegna() la ricostruisce tenendo lo
# scorrimento (come redraw del web). Pensa a: sfondo coi colori della squadra, aree sicure dell'iPhone, barra in
# alto con "indietro" e soldi, scorrimento col dito, entrata leggera degli elementi, scritta gialla (toast).
#
# Collegamenti (vedi godot/README.md, "Menu"): la carriera è App.carriera (autoload App, altro lavoro), si cambia
# schermata con App.vai(nome, arg) e si gioca con App.gioca_campionato() / gioca_amichevole(forza) / allenamento().
# Senza App (prove dei menu) si usa MenuSchermata.carriera_prova e le scene si aprono da sole.
class_name MenuSchermata
extends Control

const T := preload("res://scripts/menu/tema_menu.gd")
const U := preload("res://scripts/menu/ui.gd")
const D := preload("res://scripts/menu/menu_dati.gd")
# shader caricati con load() quando servono, non con preload in una costante: una costante tiene lo shader vivo
# finché vive lo script, cioè fino a dopo lo spegnimento della grafica ("DummyShader leaked" sul Mac della build)
const SHADER_SFONDO_PATH := "res://shaders/sfondo_menu.gdshader"
const SFONDO_3D := "res://scenes/menu/sfondo_menu.tscn"
const CARTELLA := "res://scenes/menu/%s.tscn"

const LARGHEZZA_MAX := 520.0     # .scr{max-width:520px}
const LATO := 16.0               # margine ai lati
const SOPRA := 14.0              # spazio sopra il contenuto (oltre l'area sicura)
const SOTTO := 32.0              # spazio sotto il contenuto (oltre l'area sicura)
const ENTRATA := 0.38            # s: animazione d'entrata (uiUp)
const ENTRATA_PASSO := 0.04      # s: ritardo tra un elemento e il successivo
const ENTRATA_MAX := 0.2
const ENTRATA_SALTO := 12.0      # px: da quanto più in basso entrano gli elementi
const FLASH_DURATA := 2.8
const VIBRAZIONE_MS := 12

## carriera da usare quando non c'è l'autoload App (prove dei menu, test)
static var carriera_prova: Object = null
## argomento per la prossima schermata aperta senza App (change_scene non passa argomenti)
static var prossimo_arg: Variant = null
## messaggio da mostrare in alto nella prossima schermata ("Stemma salvato")
static var prossimo_msg := ""
## se valida, vai() e gioca() chiamano questa (nome, arg) invece di App o del cambio di scena (test)
static var deviazione: Callable = Callable()
## ultima schermata pronta (per le prove)
static var ultima: MenuSchermata = null

var arg: Variant = null
var msg := ""                    # scritta gialla da mostrare al prossimo disegno (toast)
var ferma := false               # true = niente scorrimento (Rosa): il contenuto riempie lo schermo
var con_testata := true
var titolo := ""
var indietro := "hub"            # dove porta il pulsante ‹ ("" = niente pulsante)
var con_3d := false              # dietro c'è lo sfondo 3D del menu (principale e casa della carriera)
var velo_3d := 0.0               # velo scuro sopra lo sfondo 3D (0 = niente) perché i pannelli si leggano
var sfondo_3d: Node = null       # res://scenes/menu/sfondo_menu.tscn se c'è
var soldi := true                # soldi a destra nella barra in alto
var pillola := ""                # scritta a destra nella barra in alto al posto dei soldi ("1 di 2")

var sicura := Rect2()            # area sicura in punti dell'interfaccia
var sfondo: Control
var colonna: VBoxContainer
var testata: PanelContainer
var fisso_sopra: VBoxContainer   # sotto la barra, fuori dallo scorrimento (anteprima e schede dell'editor)
var fisso_sotto: VBoxContainer   # in fondo, fuori dallo scorrimento (pulsanti dell'editor)
var scorri: ScrollContainer
var margine: MarginContainer
var corpo: VBoxContainer
var _flash: PanelContainer
var _costruita := false
var _arg_dato := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


## chiamata da App.vai (o da chi apre la schermata) prima di aggiungerla all'albero, oppure dopo: ridisegna
func apri(a: Variant = null) -> void:
	if _costruita and typeof(a) == typeof(arg) and a == arg:
		return   # App.vai: arg già letto dal meta in _ready, niente doppia costruzione
	arg = a
	_arg_dato = true
	if _costruita:
		prepara()
		mostra(true)


func _ready() -> void:
	theme = load(T.PERCORSO) if ResourceLoader.exists(T.PERCORSO) else T.crea_tema()
	if not _arg_dato and has_meta("arg"):
		arg = get_meta("arg")   # App.vai mette l'argomento nel meta prima di aggiungere la scena
		_arg_dato = true
	elif not _arg_dato and prossimo_arg != null:
		arg = prossimo_arg
	prossimo_arg = null
	if prossimo_msg != "":
		msg = prossimo_msg
		prossimo_msg = ""
	U.al_tocco = _tocco
	prepara()
	_monta()
	_costruita = true
	get_viewport().size_changed.connect(_area_cambiata)
	mostra(true)
	ultima = self


## da ridefinire: impostazioni prima di costruire (titolo, ferma, con_testata, indietro)
func prepara() -> void:
	pass


## da ridefinire: riempie `corpo` (e se serve la testata)
func costruisci() -> void:
	pass


# ---------------------------------------------------------------- carriera e collegamenti
func app() -> Node:
	return get_node_or_null("/root/App") if is_inside_tree() else null


func carriera() -> Object:
	var a := app()
	if a != null:
		var c: Variant = a.get("carriera")
		if c is Object:
			return c
	return carriera_prova


## stato della carriera (c.s del web) o {} se non c'è
func stato() -> Dictionary:
	var c := carriera()
	if c == null:
		return {}
	var s: Variant = c.get("s")
	return s if s is Dictionary else {}


func vai(nome: String, a: Variant = null) -> void:
	if deviazione.is_valid():
		deviazione.call(nome, a)
		return
	var ap := app()
	if ap != null and ap.has_method("vai"):
		ap.vai(nome, a)
		return
	prossimo_arg = a
	var percorso := CARTELLA % nome
	if ResourceLoader.exists(percorso):
		get_tree().change_scene_to_file(percorso)
	else:
		push_warning("Menu: schermata %s non trovata" % nome)


## partite: "campionato", "amichevole" (v = forza avversario), "allenamento"
func gioca(tipo: String, v: Variant = null) -> void:
	if deviazione.is_valid():
		deviazione.call("gioca:" + tipo, v)
		return
	var ap := app()
	var metodo: String = {"campionato": "gioca_campionato", "amichevole": "gioca_amichevole", "allenamento": "allenamento"}.get(tipo, "")
	if ap != null and ap.has_method(metodo):
		if v != null:
			ap.call(metodo, v)
		else:
			ap.call(metodo)
		return
	print("Menu: partita %s %s (senza App: si apre la partita di prova)" % [tipo, str(v) if v != null else ""])
	if ResourceLoader.exists("res://scenes/partita.tscn") and not OS.get_cmdline_user_args().has("--resta"):
		get_tree().change_scene_to_file("res://scenes/partita.tscn")


func salva() -> void:
	var c := carriera()
	if c != null and c.has_method("save"):
		c.save()


# suono e vibrazione a ogni tocco (api.click del web): App.clic() se c'è, vibrazione se è accesa
func _tocco() -> void:
	var ap := app()
	if ap != null and ap.has_method("clic"):
		ap.clic()
	var st: Dictionary = stato().get("settings", {})
	if st.get("vibra", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(VIBRAZIONE_MS)


# ---------------------------------------------------------------- costruzione
func _monta() -> void:
	sfondo = crea_sfondo()
	add_child(sfondo)
	colonna = VBoxContainer.new()
	colonna.set_anchors_preset(Control.PRESET_FULL_RECT)
	colonna.add_theme_constant_override("separation", 0)
	colonna.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(colonna)
	testata = U.pannello("Barra")
	testata.visible = con_testata
	colonna.add_child(testata)
	fisso_sopra = U.vbox(0)
	colonna.add_child(fisso_sopra)
	margine = MarginContainer.new()
	margine.mouse_filter = Control.MOUSE_FILTER_PASS
	margine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo = U.vbox(12)
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margine.add_child(corpo)
	if ferma:
		colonna.add_child(margine)
	else:
		scorri = ScrollContainer.new()
		scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scorri.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scorri.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scorri.follow_focus = false
		scorri.scroll_deadzone = 8
		scorri.mouse_filter = Control.MOUSE_FILTER_PASS
		scorri.add_child(margine)
		colonna.add_child(scorri)
	fisso_sotto = U.vbox(0)
	colonna.add_child(fisso_sotto)
	_area_cambiata()


## sfondo a sfumatura coi colori della squadra; con con_3d il campione che palleggia (sfondo_menu.tscn) con la
## divisa e l'aspetto del campione della carriera, e la sfumatura solo se il 3D manca
func crea_sfondo() -> Control:
	if con_3d and ResourceLoader.exists(SFONDO_3D) and not OS.get_cmdline_user_args().has("--senza-3d"):
		var sc := load(SFONDO_3D) as PackedScene
		sfondo_3d = sc.instantiate() if sc != null else null
	if sfondo_3d == null:
		return _sfumatura()
	var box := Control.new()
	box.name = "Sfondo"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sfondo_3d.has_method("imposta_giocatore"):
		var g := giocatore_sfondo()
		sfondo_3d.imposta_giocatore(g[0], g[1])
	box.add_child(sfondo_3d)
	if velo_3d > 0.0:
		var velo := ColorRect.new()
		velo.color = Color(T.BG0, velo_3d)
		velo.set_anchors_preset(Control.PRESET_FULL_RECT)
		velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(velo)
	return box


## divisa {shirt, shorts, socks} e aspetto {skin, hair} del campione (o del primo della rosa) per lo sfondo 3D
func giocatore_sfondo() -> Array:
	var s := stato()
	if s.is_empty():
		var k0 := D.kit(kit_scelto())
		return [{"shirt": int(k0[1]), "shorts": int(k0[2]), "socks": int(k0[1])}, {}]
	var p: Variant = null
	for q: Dictionary in s.squad:
		if q.get("champ", false):
			p = q
			break
	if p == null and not s.squad.is_empty():
		p = s.squad[0]
	var k := D.kit(s.kit)
	var l := D.look_of(p)
	return [{"shirt": int(k[1]), "shorts": int(k[2]), "socks": int(k[1])},
		{"skin": D.SKINS[l.skin][1], "hair": D.HAIR_COLORS[l.hairColor][1]}]


func _sfumatura() -> Control:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_SFONDO_PATH)
	r.material = m
	return r


func colori_squadra() -> Array:
	var s := stato()
	var k := D.kit(s.get("kit", 1) if not s.is_empty() else kit_scelto())
	return [D.colore(int(k[1])), D.colore(int(k[2]))]


## colori della maglia scelta quando la carriera non c'è ancora (nuova carriera)
func kit_scelto() -> int:
	return 1


func _colora_sfondo() -> void:
	if sfondo != null and sfondo.material is ShaderMaterial:
		(sfondo.material as ShaderMaterial).set_shader_parameter("centro", T.mix(colori_squadra()[0], 38, Color("#0b1426")))


func _area_cambiata() -> void:
	sicura = area_sicura()
	if margine == null:
		return
	var vis := get_viewport_rect().size
	var lato := maxf(LATO, (vis.x - LARGHEZZA_MAX) / 2.0)
	margine.add_theme_constant_override("margin_left", int(lato + sicura.position.x))
	margine.add_theme_constant_override("margin_right", int(lato + vis.x - sicura.end.x))
	var alto := sicura.position.y
	margine.add_theme_constant_override("margin_top", int((8.0 if con_testata else SOPRA + alto)))
	margine.add_theme_constant_override("margin_bottom", int((10.0 if ferma else SOTTO) + vis.y - sicura.end.y))


## area sicura dell'iPhone (tacca, isola, barra in basso) in punti dell'interfaccia
func area_sicura() -> Rect2:
	var vis := get_viewport_rect().size
	var r := Rect2(Vector2.ZERO, vis)
	var schermo := Vector2(DisplayServer.window_get_size())
	if OS.has_feature("mobile") and schermo.x > 0.0 and schermo.y > 0.0:
		var s := DisplayServer.get_display_safe_area()
		var k := vis / schermo
		r = Rect2(Vector2(s.position) * k, Vector2(s.size) * k)
	var finta := _area_finta()
	if finta.size.x > 0.0:
		r = finta
	return r


# --tacca=47,34 sulla riga di comando: simula l'area sicura di un iPhone con la tacca (alto, basso) per le prove
func _area_finta() -> Rect2:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tacca="):
			var v := a.substr(8).split(",")
			var vis := get_viewport_rect().size
			var top := float(v[0])
			var bot := float(v[1]) if v.size() > 1 else 0.0
			return Rect2(0, top, vis.x, vis.y - top - bot)
	return Rect2()


## (ri)costruisce tutto; fresco = con l'animazione d'entrata
func mostra(fresco: bool) -> void:
	_colora_sfondo()
	for n in corpo.get_children():
		corpo.remove_child(n)
		n.queue_free()
	for box: Control in [testata, fisso_sopra, fisso_sotto]:
		for n in box.get_children():
			box.remove_child(n)
			if not n.has_meta("resta"):   # resta = nodo che la schermata rimette (anteprima 3D dell'editor)
				n.queue_free()
	testata.visible = con_testata
	if con_testata:
		_costruisci_testata()
	costruisci()
	_area_cambiata()
	if msg != "":
		_mostra_flash(msg)
		msg = ""
	if fresco:
		_entra()


## ricostruisce tenendo lo scorrimento (redraw del web)
func ridisegna() -> void:
	var sc := scorri.scroll_vertical if scorri != null else 0
	mostra(false)
	if scorri != null:
		await get_tree().process_frame
		if is_instance_valid(scorri):
			scorri.scroll_vertical = sc


## scritta gialla in alto (toast del web)
func toast(m: String) -> void:
	msg = m
	ridisegna()


# barra in alto: indietro, titolo, soldi (head del web)
func _costruisci_testata() -> void:
	var col := U.vbox(0)
	var riga := U.hbox(12)
	riga.custom_minimum_size.y = 46
	if indietro != "":
		var b := U.bottone("‹", "Indietro", func() -> void: torna_indietro(), 46)
		b.custom_minimum_size.x = 46
		riga.add_child(b)
	var t := U.corto(titolo, 21, T.TXT, T.PESO_NERO)
	riga.add_child(t)
	var s := stato()
	if pillola != "":
		var pl := U.pannello("Pillola")
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pl.add_child(U.testo(pillola.to_upper(), 11.5, Color("#c9d6ee"), T.PESO_NERO))
		riga.add_child(pl)
	elif soldi and s.has("money"):
		var box := U.pannello("Soldi")
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(U.testo(D.fmt_money(float(s.money)), 14, T.GOOD, T.PESO_NERO))
		riga.add_child(box)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(sicura.position.y))
	m.add_child(riga)
	col.add_child(m)
	testata.add_child(col)
	# riga coi colori della squadra sotto la barra (.top::after)
	var cs := colori_squadra()
	var linea := Control.new()   # posizione e misura a mano (sotto la barra, oltre i margini)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linea.draw.connect(func() -> void:
		var w := linea.size.x
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w * 0.6, 0), Vector2(w, 0), Vector2(w, 2), Vector2(w * 0.6, 2), Vector2(0, 2)])
		var cols := PackedColorArray([cs[0], cs[1], Color(cs[1], 0), Color(cs[1], 0), cs[1], cs[0]])
		linea.draw_rect(Rect2(0, -1, w, 1), T.LINE)
		linea.draw_polygon(pts, cols))
	testata.add_child(linea)
	testata.resized.connect(func() -> void:
		linea.position = Vector2(-16, testata.size.y - 2)
		linea.size = Vector2(testata.size.x + 32, 2)
		linea.queue_redraw())


## pulsante ‹ (le schermate possono ridefinirlo)
func torna_indietro() -> void:
	vai(indietro)


func _mostra_flash(t: String) -> void:
	if _flash != null and is_instance_valid(_flash):
		_flash.queue_free()
	_flash = U.pannello("Flash")
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := U.paragrafo(t, 15, T.INK, T.PESO_NERO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_child(l)
	add_child(_flash)
	var vis := get_viewport_rect().size
	_flash.size = Vector2(minf(vis.x - 32.0, LARGHEZZA_MAX), 0)
	_flash.position = Vector2((vis.x - _flash.size.x) / 2.0, sicura.position.y + (68.0 if con_testata else 14.0))
	_flash.modulate.a = 0.0
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "modulate:a", 1.0, 0.2)
	tw.tween_interval(FLASH_DURATA - 0.6)
	tw.tween_property(_flash, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_flash.queue_free)


# entrata: ogni elemento sale di 12 px e compare, uno dopo l'altro (uiUp del web)
func _entra() -> void:
	var figli := corpo.get_children()
	for n in figli:
		(n as CanvasItem).modulate.a = 0.0
	if testata.visible:
		testata.modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if testata.visible:
		testata.create_tween().tween_property(testata, "modulate:a", 1.0, 0.25)
	for i in figli.size():
		if not is_instance_valid(figli[i]):   # ridisegnata nel frattempo (due mostra() nello stesso fotogramma)
			continue
		var n := figli[i] as Control
		if n == null:
			continue
		var y := n.position.y
		n.position.y = y + ENTRATA_SALTO
		var tw := n.create_tween().set_parallel(true)
		var ritardo := minf(i * ENTRATA_PASSO, ENTRATA_MAX)
		tw.tween_property(n, "modulate:a", 1.0, ENTRATA).set_delay(ritardo)
		tw.tween_property(n, "position:y", y, ENTRATA).set_delay(ritardo).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
