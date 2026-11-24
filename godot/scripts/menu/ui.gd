# Pezzi comuni delle schermate (testi, pulsanti, chip, pannelli, righe), costruiti a codice come l'HTML di
# src/ui.js. Ogni pulsante si "schiaccia" un po' sotto il dito (:active del web) e chiama al_tocco (suono e
# vibrazione, impostati da MenuSchermata).
class_name MenuUi
extends RefCounted

const T := preload("res://scripts/menu/tema_menu.gd")

const PRESS_SCALE := 0.975
const PRESS_IN := 0.06
const PRESS_OUT := 0.14
const ALTEZZA_BTN := 52.0
const ALTEZZA_GRANDE := 60.0
const ALTEZZA_CHIP := 44.0

static var al_tocco: Callable = Callable()


static func testo(t: String, dim: float = 16.0, colore: Color = T.TXT, peso: int = T.PESO_MEDIO, allinea := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = allinea
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", T.font(peso))
	l.add_theme_font_size_override("font_size", int(round(dim)))
	l.add_theme_color_override("font_color", colore)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## testo su più righe che va a capo da solo
static func paragrafo(t: String, dim: float = 14.0, colore: Color = T.NOTE, peso: int = T.PESO_NORMALE) -> Label:
	var l := testo(t, dim, colore, peso)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 10
	l.add_theme_constant_override("line_spacing", int(round(dim * 0.35)))
	return l


## testo che si taglia coi puntini se non ci sta
static func corto(t: String, dim: float = 16.0, colore: Color = T.TXT, peso: int = T.PESO_MEDIO) -> Label:
	var l := testo(t, dim, colore, peso)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 10
	return l


## testo con parti in grassetto: <b>...</b> del web → grassetto giallo (come .how b), <br> → a capo
static func ricco(html: String, dim: float = 17.0, colore: Color = T.TXT, oro := true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", int(round(dim)))
	r.add_theme_font_size_override("bold_font_size", int(round(dim)))
	r.add_theme_color_override("default_color", colore)
	r.add_theme_constant_override("line_separation", int(round(dim * 0.12)))
	r.text = html_a_bbcode(html, oro)
	return r


## testo già in BBCode ([b], [color=...], [center])
static func bb(bbcode: String, dim: float = 14.0, colore: Color = T.TXT) -> RichTextLabel:
	var r := ricco("", dim, colore, false)
	r.text = bbcode
	return r


## testo libero dentro un BBCode (nomi delle squadre scelti da chi gioca)
static func esc(t: Variant) -> String:
	return str(t).replace("[", "[lb]")


## Carta con lo sfondo sfumato e gli angoli tondi: ritorna [radice da aggiungere, contenitore del contenuto].
## a → b lungo `angolo` (gradi CSS), b raggiunto a `fine` (0..1); ombra sotto come le altre carte.
static func carta_sfumata(a: Color, b: Color, angolo: float, fine: float, raggio: float, margini: Vector4, bordo := Color(1, 1, 1, 0.08), ombra := Color(0, 0, 0, 0.38)) -> Array:
	var radice := MarginContainer.new()
	radice.mouse_filter = Control.MOUSE_FILTER_PASS
	var sotto := Panel.new()
	var st := T.stile(b, int(raggio), Color(0, 0, 0, 0), 0, Vector4.ZERO)
	if ombra.a > 0.0:
		T.con_ombra(st, ombra, 12, Vector2(0, 8))
	sotto.add_theme_stylebox_override("panel", st)
	sotto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(sotto)
	var fondo := ColorRect.new()
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/carta_menu.gdshader")   # load, non preload: lo shader non resta vivo con lo script
	m.set_shader_parameter("colore_a", a)
	m.set_shader_parameter("colore_b", b)
	m.set_shader_parameter("angolo", angolo)
	m.set_shader_parameter("fine", fine)
	m.set_shader_parameter("raggio", raggio)
	m.set_shader_parameter("bordo", bordo)
	fondo.material = m
	fondo.resized.connect(func() -> void: m.set_shader_parameter("misura", fondo.size))
	radice.add_child(fondo)
	var dentro := MarginContainer.new()
	dentro.mouse_filter = Control.MOUSE_FILTER_PASS
	dentro.add_theme_constant_override("margin_left", int(margini.x))
	dentro.add_theme_constant_override("margin_top", int(margini.y))
	dentro.add_theme_constant_override("margin_right", int(margini.z))
	dentro.add_theme_constant_override("margin_bottom", int(margini.w))
	radice.add_child(dentro)
	return [radice, dentro]


## contenuto di un pulsante centrato (icona + testo), al posto del testo del pulsante
static func contenuto_centrato(b: Button, icona: Control, t: String, dim: float, colore: Color, peso: int) -> void:
	b.text = ""
	var h := hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icona != null:
		icona.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(icona)
	h.add_child(testo(t, dim, colore, peso))
	b.add_child(h)


static func html_a_bbcode(html: String, oro := true) -> String:
	var apri := "[color=#ffd93d][b]" if oro else "[b]"
	var chiudi := "[/b][/color]" if oro else "[/b]"
	return html.replace("[", "[lb]").replace("<b>", apri).replace("</b>", chiudi).replace("<br>", "\n").replace("’", "'")


## pulsante; variante = theme_type_variation (BtnGrande, BtnFantasma, Chip, ...)
static func bottone(t: String, variante := "", cb := Callable(), altezza := -1.0) -> Button:
	var b := Button.new()
	b.text = t
	if variante != "":
		b.theme_type_variation = variante
	var h := altezza
	if h < 0.0:
		h = ALTEZZA_GRANDE if variante == "BtnGrande" else (ALTEZZA_CHIP if variante.begins_with("Chip") else ALTEZZA_BTN)
	b.custom_minimum_size.y = h
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS   # il trascinamento passa allo scorrimento
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	premi_effetto(b)
	if cb.is_valid():
		b.pressed.connect(func() -> void:
			if al_tocco.is_valid():
				al_tocco.call()
			cb.call())
	return b


static func chip(t: String, on: bool, cb := Callable()) -> Button:
	var b := bottone(t, "ChipOn" if on else "Chip", cb)
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING   # il chip è largo quanto la scritta
	return b


## pulsante che si rimpicciolisce un po' sotto il dito e torna come prima al rilascio
static func premi_effetto(b: Control) -> void:
	var centra := func() -> void: b.pivot_offset = b.size / 2.0
	b.resized.connect(centra)
	var anima := func(s: float, d: float) -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(s, s), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if b is BaseButton:
		(b as BaseButton).button_down.connect(func() -> void: anima.call(PRESS_SCALE, PRESS_IN))
		(b as BaseButton).button_up.connect(func() -> void: anima.call(1.0, PRESS_OUT))


static func pannello(variante: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variante
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


static func pannello_stile(s: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


static func hbox(sep: float = 10.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(sep))
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


static func vbox(sep: float = 10.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(sep))
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	return v


static func griglia(colonne: int, sep_x: float = 10.0, sep_y: float = 10.0) -> GridContainer:
	var g := GridContainer.new()
	g.columns = colonne
	g.add_theme_constant_override("h_separation", int(sep_x))
	g.add_theme_constant_override("v_separation", int(sep_y))
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	return g


static func spazio(h: float, w: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func riempi() -> Control:
	var c := spazio(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## titoletto di sezione con la riga che continua a destra (h3 del web); `em` = valore in grigio accanto
static func sezione(t: String, em := "") -> Control:
	var h := hbox(10)
	h.custom_minimum_size.y = 20
	var l := testo(t.to_upper(), 12, T.DIM, T.PESO_NERO)
	l.add_theme_constant_override("outline_size", 0)
	h.add_child(l)
	if em != "":
		h.add_child(testo(em, 12, Color("#6b7da0"), T.PESO_FORTE))
	var riga := ColorRect.new()
	riga.color = T.LINE
	riga.custom_minimum_size = Vector2(0, 1)
	riga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(riga)
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_top", 12)
	box.add_theme_constant_override("margin_bottom", 0)
	box.add_theme_constant_override("margin_left", 2)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(h)
	return box


## riquadro colorato col numero della valutazione (.ovr del web: o1..o4, oppure "bad")
static func valutazione(o: int, cls: String, larghezza := 42.0, altezza := 34.0, dim := 17.0) -> PanelContainer:
	var bg: Color = T.OVR_BG.get(cls, Color(1, 1, 1, 0.05))
	var fg: Color = T.OVR.get(cls, T.TXT)
	if cls == "bad":
		bg = Color(1, 0.439, 0.475, 0.16)
		fg = T.BAD
	var p := pannello_stile(T.stile(bg, 10, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	p.custom_minimum_size = Vector2(larghezza, altezza)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := testo(str(o) if o >= 0 else "·", dim, fg, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	return p


## ruolo colorato (POR arancio, DIF blu, CEN verde, ATT rosso)
static func ruolo(pos: String, nome: String, larghezza := 42.0, altezza := 34.0, dim := 11.5) -> PanelContainer:
	var p := pannello_stile(T.stile(T.POS_BG.get(pos, T.PANEL2), 10, Color(0, 0, 0, 0), 0, Vector4(4, 0, 4, 0)))
	p.custom_minimum_size = Vector2(larghezza, altezza)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(testo(nome, dim, Color.WHITE, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER))
	return p


## barra di avanzamento (.prog): frazione 0..1
static func barra(frazione: float, alta := 5.0, colore: Color = T.GOLD, fondo := Color(1, 1, 1, 0.08)) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alta)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r := alta / 2.0
		_rett_tondo(c, Rect2(Vector2.ZERO, c.size), r, fondo)
		var w := c.size.x * clampf(frazione, 0.0, 1.0)
		if w > 0.5:
			_rett_tondo(c, Rect2(0, 0, maxf(w, alta), c.size.y), r, colore))
	return c


static func _rett_tondo(c: CanvasItem, r: Rect2, raggio: float, col: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(int(raggio))
	s.anti_aliasing = true
	c.draw_style_box(s, r)
