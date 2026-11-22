# Schermata tra un'azione e l'altra dei momenti chiave (momenti.gd): risultato, minuto, com'è finita l'azione,
# cronaca scritta del resto simulato ("23' Tiro di ..."), prossima azione e "Tocca per continuare".
# Un tocco ovunque (o il tasto) emette `continua`. Sta sopra l'HUD della partita (layer più alto).
extends CanvasLayer

signal continua

const Hud := preload("hud_partita.gd")
const CronacaVista := preload("cronaca_vista.gd")
const GIALLO := Color("#ffe14a")
const ROSSO := Color("#ff6b6b")
const VERDE := Color("#4aeb9f")
const TENUE := Color("#a9b8d6")
const RIGHE_MAX := 9           # righe di cronaca mostrate (le ultime; i gol ci sono sempre)
const TOCCO_DOPO_MS := 450     # un tocco appena aperta la schermata non conta (era il dito dell'azione)

var _fondo: ColorRect
var _box: VBoxContainer
var _font: FontVariation
var _aperta_ms := 0


func _ready() -> void:
	layer = 8
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = Hud.FONT_GRASSETTO
	_fondo = ColorRect.new()
	_fondo.color = Color(0.027, 0.043, 0.078, 0.93)
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_fondo.gui_input.connect(_tocco)
	_fondo.visible = false
	add_child(_fondo)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.add_child(_box)
	get_viewport().size_changed.connect(_disponi)
	_disponi()


func aperta() -> bool:
	return _fondo.visible


func nascondi() -> void:
	_fondo.visible = false


## d = {titolo, colore (facoltativo), sotto, sigle, colori, gol, minuto, righe: [{minuto, testo, forte}], prossima, tasto}
func mostra(d: Dictionary) -> void:
	for n in _box.get_children():
		_box.remove_child(n)
		n.queue_free()
	_aperta_ms = Time.get_ticks_msec()
	_fondo.visible = true
	_spazio(6)
	_etichetta("MOMENTI CHIAVE", 13, GIALLO)
	_box.add_child(_risultato(d))
	_etichetta("%d'" % int(d.get("minuto", 0)), 15, TENUE)
	if String(d.get("titolo", "")) != "":
		_spazio(4)
		_etichetta(d.titolo, 26, d.get("colore", Color.WHITE))
	if String(d.get("sotto", "")) != "":
		_etichetta(d.sotto, 14, TENUE, false)
	_spazio(6)
	var righe: Array = d.get("righe", [])
	if not righe.is_empty():
		_etichetta("Intanto…", 14, TENUE).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var lista := VBoxContainer.new()
		lista.add_theme_constant_override("separation", 5)
		lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for rg: Dictionary in _ultime(righe):
			var l := _etichetta_in(lista, "%d'  %s" % [int(rg.minuto), rg.testo], 15, GIALLO if rg.get("forte", false) else Color.WHITE, rg.get("forte", false))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_box.add_child(lista)
	else:
		_etichetta("Niente di importante nel frattempo.", 14, TENUE, false)
	var riempi := Control.new()
	riempi.size_flags_vertical = Control.SIZE_EXPAND_FILL
	riempi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(riempi)
	if String(d.get("prossima", "")) != "":
		_etichetta(d.prossima, 17, Color.WHITE)
	_box.add_child(_tasto(String(d.get("tasto", "Continua"))))
	_etichetta("Tocca per continuare", 12, TENUE, false)


# le ultime RIGHE_MAX righe, tenendo sempre i gol
static func _ultime(righe: Array) -> Array:
	if righe.size() <= RIGHE_MAX:
		return righe
	var gol := righe.filter(func(r: Dictionary) -> bool: return r.get("forte", false))
	var altre := righe.filter(func(r: Dictionary) -> bool: return not r.get("forte", false))
	var posto := maxi(0, RIGHE_MAX - gol.size())
	var tenute := altre.slice(maxi(0, altre.size() - posto)) + gol
	tenute.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return righe.find(a) < righe.find(b))
	return tenute


func _tocco(e: InputEvent) -> void:
	var giu := (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed) or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed)
	if giu and _fondo.visible and Time.get_ticks_msec() - _aperta_ms > TOCCO_DOPO_MS:
		premi()


## come il tocco (anche per il dito finto delle prove)
func premi() -> void:
	if not _fondo.visible:
		return
	_fondo.visible = false
	continua.emit()


func _disponi() -> void:
	var s := CronacaVista.area_sicura(get_viewport())
	_box.position = Vector2(s.position.x + 20.0, s.position.y + 16.0)
	_box.size = Vector2(s.size.x - 40.0, s.size.y - 30.0)


func _risultato(d: Dictionary) -> HBoxContainer:
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	riga.add_theme_constant_override("separation", 14)
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sigle: Array = d.get("sigle", ["", ""])
	var colori: Array = d.get("colori", [Color.WHITE, Color.WHITE])
	var gol: Array = d.get("gol", [0, 0])
	for k in 3:
		if k == 1:
			_etichetta_in(riga, "%d – %d" % [gol[0], gol[1]], 44, GIALLO).autowrap_mode = TextServer.AUTOWRAP_OFF
			continue
		var t := 0 if k == 0 else 1
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kc := ColorRect.new()
		kc.color = colori[t]
		kc.custom_minimum_size = Vector2(26, 8)
		kc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		kc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(kc)
		_etichetta_in(box, str(sigle[t]), 20, Color.WHITE).autowrap_mode = TextServer.AUTOWRAP_OFF
		riga.add_child(box)
	return riga


func _tasto(testo: String) -> Button:
	var b := Button.new()
	b.text = testo
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#ffd93d").darkened(0.12 if st == "pressed" else 0.0)
		sb.set_corner_radius_all(16)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("#15130a"))
	b.pressed.connect(premi)
	return b


func _spazio(h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(s)


func _etichetta(testo: String, dim: int, colore: Color, forte: bool = true) -> Label:
	return _etichetta_in(_box, testo, dim, colore, forte)


func _etichetta_in(dove: Control, testo: String, dim: int, colore: Color, forte: bool = true) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	if forte:
		l.add_theme_font_override("font", _font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dove.add_child(l)
	return l
