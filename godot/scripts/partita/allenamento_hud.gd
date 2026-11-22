# Interfaccia dell'allenamento guidato (showTut e showLesson di src/main.js): riquadro in alto sotto il punteggio con
# la lezione, la prova e cosa fare ("Bravo!" in verde quando riesce), e la scheda di spiegazione di ogni meccanica a
# partita ferma ("Prova (3 volte)", "Salta l'allenamento"). È l'oggetto `ui` di allenamento.gd: text() e card().
# I testi delle lezioni hanno <b>...</b> come nel web: qui diventano gialli e in grassetto.
extends CanvasLayer

signal prova          # "Prova (3 volte)": si chiude la scheda e si gioca
signal salta          # "Salta l'allenamento"
signal scheda(aperta: bool)   # scheda aperta (la partita va fermata) o chiusa
signal finito         # tutte le lezioni superate

const GIALLO := Color("#ffe14a")
const VERDE := Color("#5ee08f")
const FONDO := Color(0.039, 0.063, 0.125, 0.9)          # #0a1020e6
const FONDO_BENE := Color(0.051, 0.165, 0.102, 0.9)     # #0d2a1ae6
const SPAZIO_MAPPA := 96.0     # il riquadro lascia libera la minimappa a destra (come #tut del web)
const SOTTO_PUNTEGGIO := 60.0  # punti sotto il bordo dell'area sicura
const MARGINE := 12.0
const FONT_GRASSETTO := 0.7
const GuidaAllenamento := preload("res://scripts/partita/guida_allenamento.gd")

var _font_forte: FontVariation
var _riquadro: PanelContainer
var _testo: RichTextLabel
var _scheda: ColorRect
var _box: VBoxContainer
var _sicura := Rect2()
var _ultimo := ["", "", 0, 0, false]
var guida: Control       # linea guida di passaggi e tiri (guida_allenamento.gd), sotto riquadro e scheda


## da chiamare quando ci sono vista e allenamento: la linea guida li usa per disegnarsi
func collega(vista, allenamento) -> void:
	guida.vista = vista
	guida.allenamento = allenamento


func _ready() -> void:
	layer = 6
	_font_forte = FontVariation.new()
	_font_forte.base_font = ThemeDB.fallback_font
	_font_forte.variation_embolden = FONT_GRASSETTO
	guida = GuidaAllenamento.new()
	add_child(guida)
	_riquadro = PanelContainer.new()
	_riquadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_testo = _rich(14)
	_riquadro.add_child(_testo)
	_riquadro.visible = false
	add_child(_riquadro)
	_scheda = ColorRect.new()
	_scheda.color = Color(0.027, 0.043, 0.078, 0.9)
	_scheda.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scheda.mouse_filter = Control.MOUSE_FILTER_STOP
	_scheda.visible = false
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_scheda.add_child(_box)
	add_child(_scheda)
	get_viewport().size_changed.connect(_disponi)
	_disponi()


## riquadro in alto: titolo della lezione, prova `prova+1` di `prove`, testo; bene = "Bravo!" (verde). testo "" = via
func text(titolo: String, testo: String, prova: int, prove: int, bene: bool) -> void:
	_ultimo = [titolo, testo, prova, prove, bene]
	if testo == "":
		_riquadro.visible = false
		return
	_riquadro.visible = true
	_riquadro.add_theme_stylebox_override("panel", _stile(FONDO_BENE if bene else FONDO, 14, VERDE if bene else Color(GIALLO, 0.4)))
	var bb := ""
	if titolo != "":
		bb = "[font_size=11][color=#ffe14a][b]%s · PROVA %d DI %d[/b][/color][/font_size]\n" % [titolo.to_upper(), mini(prova + 1, prove), prove]
	_testo.text = bb + bbcode(testo)
	_disponi()


## scheda della meccanica (lezione = Dictionary di Allenamento.LESSONS) a partita ferma; null = allenamento finito
func card(lezione: Variant, i: int, n: int) -> void:
	text("", "", 0, 0, false)
	if lezione == null:
		_scheda.visible = false
		scheda.emit(false)
		finito.emit()
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_spazio(_sicura.size.y * 0.05)
	var su := _etichetta(13, GIALLO)
	su.text = "ALLENAMENTO · %d DI %d" % [i + 1, n]
	_box.add_child(su)
	var tit := _etichetta(30, Color.WHITE)
	tit.text = lezione.title
	_box.add_child(tit)
	var pannello := PanelContainer.new()
	var st := _stile(Color(1, 1, 1, 0.05), 16, Color(1, 1, 1, 0.13))
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	st.content_margin_left = 16
	st.content_margin_right = 16
	pannello.add_theme_stylebox_override("panel", st)
	var spiega := _rich(16)
	spiega.add_theme_constant_override("line_separation", 4)
	spiega.custom_minimum_size.x = _box.size.x - 32.0
	spiega.text = bbcode(lezione.text)
	pannello.add_child(spiega)
	_box.add_child(pannello)
	_spazio(4)
	_tasto("Prova (%d volte)" % preload("allenamento.gd").REPS, true, premi_prova)
	_tasto("Salta l'allenamento", false, premi_salta)
	_scheda.visible = true
	scheda.emit(true)


func scheda_aperta() -> bool:
	return _scheda.visible


## testo del riquadro adesso (per le prove): "" se nascosto
func testo_riquadro() -> String:
	return _testo.get_parsed_text() if _riquadro.visible else ""


## via tutto (allenamento finito o abbandonato)
func chiudi() -> void:
	_riquadro.visible = false
	_scheda.visible = false


## "Prova (3 volte)" (anche dal dito finto delle prove)
func premi_prova() -> void:
	_chiudi_scheda()
	prova.emit()


func premi_salta() -> void:
	_chiudi_scheda()
	salta.emit()


func _chiudi_scheda() -> void:
	_scheda.visible = false
	scheda.emit(false)


## <b>...</b> del web → grassetto giallo
static func bbcode(html: String) -> String:
	return html.replace("[", "(").replace("]", ")").replace("<b>", "[color=#ffe14a][b]").replace("</b>", "[/b][/color]")


# ---------------------------------------------------------------- costruzione
func _rich(dim: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", dim)
	r.add_theme_font_size_override("bold_font_size", dim)
	r.add_theme_font_override("normal_font", _font_semi())
	r.add_theme_font_override("bold_font", _font_forte)
	return r


# testo normale un po' più pieno (font-weight 600 del web)
func _font_semi() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.25
	return f


func _stile(fondo: Color, raggio: int, bordo: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.set_corner_radius_all(raggio)
	s.border_color = bordo
	s.set_border_width_all(1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s


func _etichetta(dim: int, colore: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	l.add_theme_font_override("font", _font_forte)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spazio(h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(s)


# tasti come quelli del menu di pausa (hud_partita.gd): grande giallo, piccolo trasparente
func _tasto(testo: String, grande: bool, azione: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 60 if grande else 52)
	b.add_theme_font_override("font", _font_forte)
	b.add_theme_font_size_override("font_size", 18 if grande else 16)
	var fondo := Color("#ffd93d") if grande else Color(1, 1, 1, 0.04)
	for s in ["normal", "hover", "pressed", "focus"]:
		var sb := _stile(fondo.darkened(0.12) if s == "pressed" else fondo, 16, Color(0, 0, 0, 0) if grande else Color(1, 1, 1, 0.2))
		sb.set_border_width_all(0 if grande else 1)
		b.add_theme_stylebox_override(s, sb)
	var tc := Color("#15130a") if grande else Color("#cbd7ee")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, tc)
	b.pressed.connect(azione)
	_box.add_child(b)
	return b


# area sicura in punti logici (tacca in alto, barra home in basso), come hud_partita.gd
func _area_sicura() -> Rect2:
	var vista_px := get_viewport().get_visible_rect().size
	var sicura := Rect2(Vector2.ZERO, vista_px)
	if OS.has_feature("mobile"):
		var schermo := Vector2(DisplayServer.screen_get_size())
		var s := DisplayServer.get_display_safe_area()
		if schermo.x > 0 and schermo.y > 0:
			var k := vista_px / schermo
			sicura = Rect2(Vector2(s.position) * k, Vector2(s.size) * k)
	return sicura


func _disponi() -> void:
	_sicura = _area_sicura()
	var s := _sicura
	var largo := s.size.x - MARGINE - SPAZIO_MAPPA
	_testo.custom_minimum_size.x = largo - 24.0
	_riquadro.size = Vector2(largo, 0)
	_riquadro.reset_size()
	_riquadro.position = Vector2(s.position.x + MARGINE, s.position.y + SOTTO_PUNTEGGIO)
	_box.position = Vector2(s.position.x + 18.0, s.position.y + 26.0)
	_box.size = Vector2(s.size.x - 36.0, s.size.y - 50.0)
