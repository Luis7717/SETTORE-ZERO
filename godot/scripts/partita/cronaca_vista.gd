# Riga della cronaca scritta (cronaca.gd) in alto a sinistra, sotto il tasto della pausa e il punteggio, a fianco
# della minimappa: non copre punteggio, orologio, minimappa né i tasti in basso. Una frase alla volta: compare,
# resta qualche secondo e sparisce. Va messa dentro l'HUD della partita (CanvasLayer), sotto i suoi menu.
extends Control

const MARGINE := 12.0
const SOTTO := 96.0            # punti sotto il bordo alto dell'area sicura (punteggio e scritta della visuale sopra)
const MAPPA := 78.0 + 10.0 + 8.0  # larghezza della minimappa a destra, col suo margine e uno spazio
const DURATA := 3.6            # s di una frase
const DURATA_GOL := 5.0
const DISSOLVENZA := 0.25
const GIALLO := Color("#ffe14a")
const FONDO := Color(0.039, 0.063, 0.125, 0.78)
const Hud := preload("hud_partita.gd")

var _l: Label
var _fino := 0.0
var _t := 0.0
var _tw: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_l = Label.new()
	_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.5
	_l.add_theme_font_override("font", f)
	_l.add_theme_font_size_override("font_size", 14)
	var s := StyleBoxFlat.new()
	s.bg_color = FONDO
	s.set_corner_radius_all(10)
	s.border_color = Color(1, 1, 1, 0.13)
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	_l.add_theme_stylebox_override("normal", s)
	_l.modulate.a = 0.0
	add_child(_l)


func _process(delta: float) -> void:
	_t += delta
	if _fino > 0.0 and _t >= _fino:
		_fino = 0.0
		_dissolvi(0.0)


## mostra una frase; forte = gol (gialla e un po' più a lungo)
func mostra(testo: String, forte: bool = false) -> void:
	if testo == "":
		return
	_l.text = testo
	var st: StyleBoxFlat = _l.get_theme_stylebox("normal")
	st.border_color = GIALLO if forte else Color(1, 1, 1, 0.35)
	_l.add_theme_color_override("font_color", GIALLO if forte else Color.WHITE)
	_disponi()
	_fino = _t + (DURATA_GOL if forte else DURATA)
	_dissolvi(1.0)


## via la frase subito (pausa, fine partita)
func nascondi() -> void:
	_fino = 0.0
	_l.modulate.a = 0.0


func testo() -> String:
	return _l.text if _fino > 0.0 else ""


func _dissolvi(a: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_l, "modulate:a", a, DISSOLVENZA)


# larga quanto il testo, al massimo fino alla minimappa; oltre va a capo tra le parole (a mano, come le pillole
# dell'HUD: una Label con autowrap calcola l'altezza prima di sapere la larghezza)
func _disponi() -> void:
	var s := area_sicura(get_viewport())
	var largo_max := maxf(120.0, s.size.x - MARGINE - MAPPA)
	var font := _l.get_theme_font("font")
	var dim := _l.get_theme_font_size("font_size")
	_l.text = Hud._a_capo(_l.text, font, dim, largo_max - 28.0)
	_l.size = Vector2.ZERO
	_l.reset_size()
	_l.position = Vector2(s.position.x + MARGINE, s.position.y + SOTTO)


## area sicura in punti logici (tacca in alto, barra home in basso), come hud_partita.gd (la usa anche replay.gd)
static func area_sicura(vp: Viewport) -> Rect2:
	var vista_px := vp.get_visible_rect().size
	var sicura := Rect2(Vector2.ZERO, vista_px)
	if OS.has_feature("mobile"):
		var schermo := Vector2(DisplayServer.screen_get_size())
		var a := DisplayServer.get_display_safe_area()
		if schermo.x > 0 and schermo.y > 0:
			var k := vista_px / schermo
			sicura = Rect2(Vector2(a.position) * k, Vector2(a.size) * k)
	return sicura
