# Tastiera del gioco per il nome del campione (Luis 2026-11-27: "se clicco Nome crasha l'app").
# Nell'editor del campione il nome non si scrive più in un LineEdit con la tastiera di iOS: la scheda Nome mostra
# il nome in un tasto e toccandolo si apre questa tastiera, fatta solo di tasti del menu (niente tastiera di
# sistema, niente LineEdit). Velo scuro su tutto lo schermo; sopra il nome che si sta scrivendo, sotto le lettere
# (QWERTY, lettere accentate, apostrofo, punto, trattino), Maiuscolo, Spazio, Cancella e Fatto. La prima lettera e
# quella dopo spazio, punto, apostrofo o trattino sono maiuscole da sole. Toccando fuori si chiude senza cambiare.
class_name MenuTastiera
extends ColorRect

const T := preload("res://scripts/menu/tema_menu.gd")
const U := preload("res://scripts/menu/ui.gd")

const RIGHE := ["QWERTYUIOP", "ASDFGHJKL'", "ZXCVBNM.-", "ÀÈÉÌÒÙ"]
const ALTEZZA_TASTO := 46.0
const SPAZIO_TASTI := 4.0
const MARGINE := 12.0
const VELO := Color(0.02, 0.035, 0.07, 0.82)
const DOPO_MAIUSCOLA := [" ", ".", "'", "-"]   # dopo questi la lettera è maiuscola da sola

var testo := ""
var max_lunghezza := 20
var maiuscolo := true
var _fatto: Callable
var _chiudi: Callable
var _schermo: Label
var _tasti_lettere: Array[Button] = []
var _tasto_maiusc: Button
var _riquadro: PanelContainer
var _area := Rect2()


## tastiera col nome di partenza; fatto(nome) quando si tocca Fatto, chiudi() quando si tocca fuori.
## area = area sicura dello schermo (la tastiera sta in fondo, sopra la barra dell'iPhone)
static func nuova(iniziale: String, lunghezza: int, area: Rect2, fatto: Callable, chiudi: Callable) -> MenuTastiera:
	var k := MenuTastiera.new()
	k.testo = iniziale.left(lunghezza)
	k.maiuscolo = k.testo == "" or DOPO_MAIUSCOLA.has(k.testo.right(1))
	k.max_lunghezza = lunghezza
	k._fatto = fatto
	k._chiudi = chiudi
	k._area = area
	k._costruisci()
	return k


func _costruisci() -> void:
	color = VELO
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_tocco_fuori)
	_riquadro = U.pannello("PannelloRosa")
	_riquadro.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := U.vbox(SPAZIO_TASTI + 2.0)
	_riquadro.add_child(v)
	var testa := U.hbox(8)
	var tit := U.testo("NOME DEL CAMPIONE", 13, T.TXT, T.PESO_NERO)
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testa.add_child(tit)
	var x := U.bottone("×", "Chiudi", func() -> void: _chiudi.call(), 38)
	x.custom_minimum_size.x = 38
	testa.add_child(x)
	v.add_child(testa)
	var campo := U.pannello_stile(T.stile(Color("#0a1424"), 12, T.GOLD, 1, Vector4(12, 8, 12, 8)))
	_schermo = U.testo("", 22, T.TXT, T.PESO_FORTE)
	_schermo.clip_text = true
	_schermo.custom_minimum_size.y = 34
	campo.add_child(_schermo)
	v.add_child(campo)
	for riga: String in RIGHE:
		var h := U.hbox(SPAZIO_TASTI)
		for i in riga.length():
			var lettera := riga[i]
			var b := _tasto(lettera, _scrivi.bind(lettera))
			if lettera.to_lower() != lettera:
				_tasti_lettere.append(b)
			h.add_child(b)
		v.add_child(h)
	var fondo := U.hbox(SPAZIO_TASTI)
	_tasto_maiusc = _tasto("Aa", _cambia_maiuscolo)
	_tasto_maiusc.size_flags_stretch_ratio = 1.4
	fondo.add_child(_tasto_maiusc)
	var spazio := _tasto("spazio", _scrivi.bind(" "))
	spazio.size_flags_stretch_ratio = 3.6
	fondo.add_child(spazio)
	var canc := _tasto("Cancella", _cancella)
	canc.size_flags_stretch_ratio = 1.4
	fondo.add_child(canc)
	for b: Button in [_tasto_maiusc, spazio, canc]:
		b.add_theme_font_size_override("font_size", 14)
	v.add_child(fondo)
	var ok := U.bottone("Fatto", "BtnGrande", _conferma, 52)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ok)
	add_child(_riquadro)
	resized.connect(_metti_in_fondo)
	_riquadro.minimum_size_changed.connect(_metti_in_fondo)
	_aggiorna()


func _tasto(t: String, cb: Callable) -> Button:
	var b := U.bottone(t, "Scheda", cb, ALTEZZA_TASTO)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = 0
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.add_theme_font_size_override("font_size", 17)
	return b


# in fondo all'area sicura, largo quanto lo schermo meno i margini
func _metti_in_fondo() -> void:
	var area := _area if _area.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	var w := area.size.x - 2.0 * MARGINE
	_riquadro.size = Vector2(w, _riquadro.get_combined_minimum_size().y)
	_riquadro.position = Vector2(area.position.x + MARGINE, area.end.y - _riquadro.size.y - MARGINE)


func _tocco_fuori(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and not ev.pressed) or (ev is InputEventScreenTouch and not ev.pressed):
		_chiudi.call()


func _scrivi(lettera: String) -> void:
	if testo.length() >= max_lunghezza:
		return
	if lettera == " " and (testo == "" or testo.ends_with(" ")):
		return   # niente spazi all'inizio né doppi
	testo += lettera if maiuscolo else lettera.to_lower()
	maiuscolo = DOPO_MAIUSCOLA.has(lettera)
	_aggiorna()


func _cancella() -> void:
	testo = testo.left(testo.length() - 1)
	maiuscolo = testo == "" or DOPO_MAIUSCOLA.has(testo.right(1))
	_aggiorna()


func _cambia_maiuscolo() -> void:
	maiuscolo = not maiuscolo
	_aggiorna()


func _conferma() -> void:
	_fatto.call(testo.strip_edges())


func _aggiorna() -> void:
	_schermo.text = testo + "|"
	for b: Button in _tasti_lettere:
		b.text = b.text.to_upper() if maiuscolo else b.text.to_lower()
	_tasto_maiusc.theme_type_variation = "SchedaOn" if maiuscolo else "Scheda"
