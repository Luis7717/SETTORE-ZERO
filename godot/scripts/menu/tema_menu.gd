# Tema dei menu: colori, caratteri e stili dei pannelli e dei pulsanti (porting di src/ui-style.js).
# Il tema vero è assets/tema/tema.tres, generato da tools/crea_tema.gd con crea_tema() qui sotto: chi cambia un
# colore lo cambia qui e rigenera il file. Le varianti (theme_type_variation) hanno i nomi delle classi del web:
# BtnGrande (.btn.big), BtnFantasma (.btn.ghost), Chip / ChipOn, Tile, Indietro (.back), Carta (.card), ...
#
# Caratteri: il web usa quello di sistema (-apple-system / San Francisco sull'iPhone, Segoe UI su Windows):
# qui lo stesso con SystemFont, niente file da includere né licenze.
class_name MenuTema
extends RefCounted

const PERCORSO := "res://assets/tema/tema.tres"

# colori (--bg0, --panel, --gold, ... di ui-style.js)
const BG0 := Color("#050912")
const BG1 := Color("#0b1426")
const BG_MID := Color("#0a1224")
const PANEL := Color("#111c31")
const PANEL2 := Color("#18263f")
const CARD_TOP := Color("#14213a")
const CARD_BOTTOM := Color("#101a2f")
const TILE := Color("#13203a")
const LINE := Color(1, 1, 1, 0.078)
const LINE2 := Color(1, 1, 1, 0.149)
const TXT := Color("#eef3fb")
const DIM := Color("#93a4c3")
const NOTE := Color("#a3b4d2")
const GOLD := Color("#ffd93d")
const GOLD_LIGHT := Color("#ffe45e")
const GOLD2 := Color("#c9a410")
const GOOD := Color("#4aeb9f")
const BAD := Color("#ff7079")
const WARN := Color("#ff4d58")
const INK := Color("#15130a")      # testo sui pulsanti gialli
const GHOST_TXT := Color("#cbd7ee")
const CHIP_TXT := Color("#d6e1f4")
const OVR := {"o1": Color("#c4cddd"), "o2": Color("#8fd3ff"), "o3": Color("#4aeb9f"), "o4": Color("#1a1405")}
const OVR_BG := {"o1": Color(0.718, 0.761, 0.839, 0.11), "o2": Color(0.561, 0.827, 1.0, 0.12), "o3": Color(0.29, 0.922, 0.624, 0.125), "o4": Color("#ffd23a")}
const STAT := {"o1": Color("#b7c2d6"), "o2": Color("#8fd3ff"), "o3": Color("#4aeb9f"), "o4": Color("#ffd93d")}
const POS_BG := {"P": Color("#c27b12"), "D": Color("#2672b5"), "C": Color("#1f8a52"), "A": Color("#b8373f")}
const R := 18                       # --r: angoli delle carte

const PESO_NORMALE := 500
const PESO_MEDIO := 650
const PESO_FORTE := 750
const PESO_NERO := 880

const NOMI_FONT := [".AppleSystemUIFont", "SF Pro Text", "SF Pro Display", "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"]

static var _font := {}


## carattere di sistema col peso dato (100..999); corsivo per il logo
static func font(peso: int = PESO_MEDIO, corsivo := false) -> Font:
	var key := "%d%s" % [peso, "i" if corsivo else ""]
	if _font.has(key):
		return _font[key]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(NOMI_FONT)
	f.font_weight = peso
	f.font_italic = corsivo
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.multichannel_signed_distance_field = false
	f.generate_mipmaps = false
	_font[key] = f
	return f


## pannello a tinta unita con angoli, bordo e ombra
static func stile(fondo: Color, raggio: int = R, bordo: Color = Color(0, 0, 0, 0), spessore: int = 1, margini := Vector4(14, 12, 14, 12)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.set_corner_radius_all(raggio)
	s.corner_detail = 6
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.8
	if bordo.a > 0.0:
		s.border_color = bordo
		s.set_border_width_all(spessore)
	s.content_margin_left = margini.x
	s.content_margin_top = margini.y
	s.content_margin_right = margini.z
	s.content_margin_bottom = margini.w
	return s


static func con_ombra(s: StyleBoxFlat, colore: Color, grandezza: int, spostamento := Vector2(0, 6)) -> StyleBoxFlat:
	s.shadow_color = colore
	s.shadow_size = grandezza
	s.shadow_offset = spostamento
	return s


## colore della squadra mescolato allo sfondo (var(--k1m<p>-<base>) del web)
static func mix(k1: Color, percento: float, base: Color) -> Color:
	return base.lerp(k1, percento / 100.0)


# ---------------------------------------------------------------- pulsanti
static func _btn(t: Theme, tipo: String, normale: StyleBox, premuto: StyleBox, testo: Color, dim: int, peso: int, base := "Button") -> void:
	if tipo != base:
		t.set_type_variation(tipo, base)
	t.set_stylebox("normal", tipo, normale)
	t.set_stylebox("hover", tipo, normale)
	t.set_stylebox("pressed", tipo, premuto)
	t.set_stylebox("hover_pressed", tipo, premuto)
	t.set_stylebox("disabled", tipo, normale)
	t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, tipo, testo)
	t.set_color("font_disabled_color", tipo, Color(testo, 0.45))
	t.set_font("font", tipo, font(peso))
	t.set_font_size("font_size", tipo, dim)
	t.set_constant("h_separation", tipo, 10)
	t.set_constant("icon_max_width", tipo, 24)


static func _premuto(s: StyleBoxFlat, piu: float = 0.07) -> StyleBoxFlat:
	var p := s.duplicate() as StyleBoxFlat
	p.bg_color = s.bg_color.lightened(piu) if s.bg_color.a > 0.5 else Color(s.bg_color, minf(1.0, s.bg_color.a + 0.08))
	return p


static func stile_grande(premuto := false) -> StyleBoxFlat:
	var s := stile(GOLD, 16, Color(0, 0, 0, 0), 0, Vector4(18, 16, 18, 16))
	s.border_color = GOLD2
	s.border_width_bottom = 1 if premuto else 5
	if premuto:
		s.expand_margin_top = -4.0
		s.content_margin_top = 20
	return con_ombra(s, Color(1, 0.851, 0.239, 0.19), 10 if not premuto else 5, Vector2(0, 8 if not premuto else 3))


static func crea_tema() -> Theme:
	var t := Theme.new()
	t.default_font = font(PESO_MEDIO)
	t.default_font_size = 16
	t.default_base_scale = 1.0

	# testi
	t.set_color("font_color", "Label", TXT)
	t.set_font("font", "Label", font(PESO_MEDIO))
	t.set_constant("line_spacing", "Label", 2)
	t.set_color("default_color", "RichTextLabel", TXT)
	t.set_font("normal_font", "RichTextLabel", font(PESO_NORMALE))
	t.set_font("bold_font", "RichTextLabel", font(PESO_FORTE))
	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)
	t.set_constant("line_separation", "RichTextLabel", 6)

	# pulsanti (.btn e varianti)
	var b := stile(PANEL2, 16, LINE2, 1, Vector4(16, 14, 16, 14))
	_btn(t, "Button", b, _premuto(b), TXT, 16, PESO_FORTE)
	_btn(t, "BtnGrande", stile_grande(), stile_grande(true), INK, 18, PESO_NERO)
	var gh := stile(Color(1, 1, 1, 0.03), 16, LINE2, 1, Vector4(16, 14, 16, 14))
	_btn(t, "BtnFantasma", gh, _premuto(gh), GHOST_TXT, 16, PESO_FORTE)
	var wa := stile(WARN, 16, WARN, 1, Vector4(16, 14, 16, 14))
	_btn(t, "BtnAvviso", wa, _premuto(wa), Color.WHITE, 16, PESO_FORTE)
	var vai := stile(GOLD, 14, Color(0, 0, 0, 0), 0, Vector4(12, 10, 12, 10))
	vai.border_color = GOLD2
	vai.border_width_bottom = 3
	_btn(t, "BtnVai", vai, _premuto(vai), INK, 15, PESO_NERO)
	var ch := stile(PANEL, 999, LINE2, 1, Vector4(16, 10, 16, 10))
	_btn(t, "Chip", ch, _premuto(ch), CHIP_TXT, 15, PESO_FORTE)
	var con := con_ombra(stile(GOLD, 999, GOLD, 1, Vector4(16, 10, 16, 10)), Color(1, 0.851, 0.239, 0.19), 6, Vector2(0, 4))
	_btn(t, "ChipOn", con, con, INK, 15, PESO_FORTE)
	var bk := stile(PANEL2, 14, LINE2, 1, Vector4(0, 0, 0, 4))
	_btn(t, "Indietro", bk, _premuto(bk), Color.WHITE, 30, PESO_MEDIO)
	var ti := con_ombra(stile(TILE, R, LINE, 1, Vector4(14, 14, 12, 14)), Color(0, 0, 0, 0.25), 6, Vector2(0, 4))
	_btn(t, "Tile", ti, _premuto(ti, 0.05), TXT, 16, PESO_FORTE)
	var tab := stile(PANEL, 12, LINE2, 1, Vector4(4, 10, 4, 10))
	_btn(t, "Scheda", tab, _premuto(tab), GHOST_TXT, 14, PESO_NERO)
	var tabon := stile(GOLD, 12, GOLD, 1, Vector4(4, 10, 4, 10))
	_btn(t, "SchedaOn", tabon, tabon, INK, 14, PESO_NERO)
	var op := stile(PANEL, 14, LINE2, 2, Vector4(4, 8, 4, 6))
	_btn(t, "Opzione", op, _premuto(op), GHOST_TXT, 11, PESO_FORTE)
	var opon := con_ombra(stile(Color("#1b2a47"), 14, GOLD, 2, Vector4(4, 8, 4, 6)), Color(1, 0.851, 0.239, 0.13), 3, Vector2.ZERO)
	_btn(t, "OpzioneOn", opon, opon, GHOST_TXT, 11, PESO_FORTE)
	var kit := stile(Color("#0a1424"), 14, Color(0, 0, 0, 0), 2, Vector4(2, 2, 2, 2))
	kit.border_color = Color(0, 0, 0, 0)
	kit.set_border_width_all(2)
	_btn(t, "Kit", kit, _premuto(kit), TXT, 14, PESO_FORTE)
	var kiton := con_ombra(stile(Color("#1b2a47"), 14, GOLD, 2, Vector4(2, 2, 2, 2)), Color(1, 0.851, 0.239, 0.13), 3, Vector2.ZERO)
	_btn(t, "KitOn", kiton, kiton, TXT, 14, PESO_FORTE)
	var riga := stile(Color("#13203a"), 14, LINE, 1, Vector4(8, 6, 10, 6))
	_btn(t, "Riga", riga, _premuto(riga, 0.04), TXT, 15, PESO_FORTE)
	var rsel := con_ombra(stile(Color("#1f3052"), 14, GOLD, 1, Vector4(8, 6, 10, 6)), Color(1, 0.851, 0.239, 0.11), 3, Vector2.ZERO)
	_btn(t, "RigaSel", rsel, rsel, TXT, 15, PESO_FORTE)
	var x := stile(PANEL2, 12, LINE2, 1, Vector4(0, 0, 0, 2))
	_btn(t, "Chiudi", x, _premuto(x), Color.WHITE, 22, PESO_MEDIO)
	var sw := StyleBoxEmpty.new()
	_btn(t, "Vuoto", sw, sw, TXT, 14, PESO_MEDIO)

	# pannelli (.card, .pcard, .top, ...)
	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	var pann := func(nome: String, s: StyleBox) -> void:
		t.set_type_variation(nome, "PanelContainer")
		t.set_stylebox("panel", nome, s)
	pann.call("Carta", con_ombra(stile(Color("#121e35"), R, LINE, 1, Vector4(16, 16, 16, 16)), Color(0, 0, 0, 0.38), 12, Vector2(0, 8)))
	pann.call("Pannello", con_ombra(stile(Color("#132038"), 16, Color(1, 0.851, 0.239, 0.4), 1, Vector4(14, 14, 14, 14)), Color(0, 0, 0, 0.42), 14, Vector2(0, 10)))
	pann.call("PannelloRosa", con_ombra(stile(Color("#132038"), 16, Color(1, 0.851, 0.239, 0.4), 1, Vector4(10, 8, 10, 8)), Color(0, 0, 0, 0.42), 11, Vector2(0, 8)))
	pann.call("Barra", stile(Color(0.039, 0.071, 0.141, 0.91), 0, Color(0, 0, 0, 0), 0, Vector4(16, 10, 16, 10)))
	pann.call("Flash", stile(GOLD, 14, Color(0, 0, 0, 0), 0, Vector4(14, 12, 14, 12)))
	pann.call("Pillola", stile(Color(1, 1, 1, 0.07), 999, Color(0, 0, 0, 0), 0, Vector4(10, 4, 10, 4)))
	pann.call("PillolaOro", stile(Color(1, 0.851, 0.239, 0.125), 999, Color(0, 0, 0, 0), 0, Vector4(10, 4, 10, 4)))
	pann.call("Soldi", stile(Color("#102c1f"), 999, Color(0.275, 0.922, 0.624, 0.25), 1, Vector4(13, 6, 13, 6)))
	pann.call("Claim", stile(Color(1, 1, 1, 0.047), 999, LINE2, 1, Vector4(12, 6, 12, 6)))
	pann.call("Stat", stile(Color(1, 1, 1, 0.03), 10, Color(0, 0, 0, 0), 0, Vector4(10, 7, 10, 8)))
	pann.call("StatPiccola", stile(Color(1, 1, 1, 0.03), 8, Color(0, 0, 0, 0), 0, Vector4(0, 3, 0, 4)))
	pann.call("RigaTab", stile(PANEL, 12, Color(0, 0, 0, 0), 0, Vector4(0, 0, 4, 0)))
	pann.call("RigaTabMe", stile(Color("#302d12"), 12, Color(0, 0, 0, 0), 0, Vector4(0, 0, 4, 0)))
	pann.call("Riquadro", stile(Color(1, 1, 1, 0.024), 8, Color(0, 0, 0, 0), 0, Vector4(4, 2, 4, 2)))

	# campo di testo (input)
	var le := stile(Color("#08101f"), 14, LINE2, 2, Vector4(14, 12, 14, 12))
	var lef := con_ombra(stile(Color("#08101f"), 14, GOLD, 2, Vector4(14, 12, 14, 12)), Color(1, 0.851, 0.239, 0.13), 4, Vector2.ZERO)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_font("font", "LineEdit", font(PESO_MEDIO))
	t.set_font_size("font_size", "LineEdit", 18)
	t.set_color("font_color", "LineEdit", TXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.7))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(1, 0.851, 0.239, 0.3))
	t.set_constant("minimum_character_width", "LineEdit", 4)

	# scorrimento: barre invisibili (si scorre col dito)
	var vuoto := StyleBoxEmpty.new()
	for sb in ["VScrollBar", "HScrollBar"]:
		for k in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
			t.set_stylebox(k, sb, vuoto)
	t.set_stylebox("panel", "ScrollContainer", vuoto)
	t.set_stylebox("focus", "ScrollContainer", vuoto)
	return t
