# Interfaccia della partita (come #hud di src/index.tpl.html e le funzioni di src/main.js): punteggio con sigle e
# colori, tempo, minimappa, suggerimenti in basso, tasto Dribbling, tasto pausa, scritte grandi ("Gol!", "Calcio
# d'angolo"...), frecce e scritta della visuale girata nel rallenty, bordo scuro del rallenty, anteprima del calcio,
# menu di pausa / intervallo / fine partita, contatore FPS piccolo. Tutto dentro l'area sicura dell'iPhone.
# Non decide niente: scripts/partita/gioco.gd la aggiorna e ascolta i segnali dei tasti.
extends CanvasLayer

signal pausa_premuta
signal dribbling_premuto
signal riprendi
signal secondo_tempo
signal esci
signal nuova_partita

const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const SHADER_RALLENTY := preload("res://shaders/rallenty.gdshader")
const Minimappa := preload("res://scripts/partita/minimappa.gd")
const Anteprima := preload("res://scripts/partita/anteprima.gd")

const MARGINE := 10.0
const GIALLO := Color("#ffe14a")
const ROSSO := Color("#ff6b6b")
const FONDO := Color(0.039, 0.063, 0.125, 0.85)
const BORDO := Color(1, 1, 1, 0.13)
const FPS_OGNI := 0.5             # secondi tra un aggiornamento del contatore e l'altro
const BIG_TOP := 0.27             # la scritta grande sta a questa frazione dell'altezza (come #big del web)
const FADE_DA := 0.85             # nero del taglio di scena (ripartenza lontana), poi sparisce in FADE_S
const FADE_S := 0.35
const RALLENTY_K := 10.0          # 1/s: il bordo del rallenty si accende e si spegne in ~0,15 s
const TESTO_CAM := "‹ › Trascina il campo per girare la visuale"
const FONT_GRASSETTO := 0.7      # quanto si ingrossa il carattere per titoli, punteggio e tasti

var vista = null                  # per l'anteprima del calcio e per niente altro (world_to_screen)
var gesti = null

var _font_forte: FontVariation
var _sicura := Rect2()
var _rallenty: ColorRect
var _rallenty_mat: ShaderMaterial
var _rallenty_on := false
var _anteprima: Control
var _segnapunti: PanelContainer
var _k0: ColorRect
var _k1: ColorRect
var _tn0: Label
var _tn1: Label
var _sc: Label
var _pausa: Button
var _orologio: PanelContainer
var _orologio_l: Label
var _fps: Label
var _mappa: Control
var _big: Label
var _big_fino := 0
var _big_tween: Tween = null
var _suggerimento: PanelContainer
var _suggerimento_l: Label
var _dribbling: Button
var _cam_tip: PanelContainer
var _frecce: Array[Label] = []
var _fade: ColorRect
var _overlay: ColorRect
var _overlay_box: VBoxContainer
var _fps_t := 0.0
var _peggiore_ms := 0.0
var _hint_testo := "-"
var _hint_caldo := false


func _ready() -> void:
	layer = 5
	# carattere di Godot ingrossato: uguale su PC e iPhone (un carattere di sistema cambierebbe misure e simboli)
	_font_forte = FontVariation.new()
	_font_forte.base_font = ThemeDB.fallback_font
	_font_forte.variation_embolden = FONT_GRASSETTO
	_crea_rallenty()
	_anteprima = Anteprima.new()
	_anteprima.hud = self
	_anteprima.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_anteprima)
	_crea_segnapunti()
	_crea_angoli()
	_crea_centro()
	_crea_basso()
	_crea_overlay()
	get_viewport().size_changed.connect(_disponi)
	_disponi()


func _process(delta: float) -> void:
	_fps_t += delta
	_peggiore_ms = maxf(_peggiore_ms, delta * 1000.0)
	if _fps_t >= FPS_OGNI:
		_fps.text = "FPS %d · %.1f ms" % [Engine.get_frames_per_second(), _peggiore_ms]
		_fps_t = 0.0
		_peggiore_ms = 0.0
	var f: float = _rallenty_mat.get_shader_parameter("forza")
	f += ((1.0 if _rallenty_on else 0.0) - f) * minf(1.0, delta * RALLENTY_K)
	_rallenty_mat.set_shader_parameter("forza", f)
	if _big_fino > 0 and Time.get_ticks_msec() > _big_fino:
		_big_fino = 0
		_nuovo_tween_big().tween_property(_big, "modulate:a", 0.0, 0.18)


# ---------------------------------------------------------------- costruzione
func _stile(fondo: Color, raggio: int, bordo: Color = BORDO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.set_corner_radius_all(raggio)
	s.border_color = bordo
	s.set_border_width_all(1 if bordo.a > 0.0 else 0)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _etichetta(dim: int, colore: Color = Color.WHITE, forte: bool = true) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	if forte:
		l.add_theme_font_override("font", _font_forte)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ombra(l: Label, spessore: int = 6) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", spessore)


func _crea_rallenty() -> void:
	_rallenty = ColorRect.new()
	_rallenty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rallenty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rallenty_mat = ShaderMaterial.new()
	_rallenty_mat.shader = SHADER_RALLENTY
	_rallenty_mat.set_shader_parameter("forza", 0.0)
	_rallenty.material = _rallenty_mat
	add_child(_rallenty)


func _crea_segnapunti() -> void:
	_segnapunti = PanelContainer.new()
	_segnapunti.add_theme_stylebox_override("panel", _stile(FONDO, 12))
	_segnapunti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 10)
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_k0 = _colore_kit()
	_tn0 = _etichetta(15)
	_sc = _etichetta(20, GIALLO)
	_sc.custom_minimum_size.x = 54
	_sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tn1 = _etichetta(15)
	_k1 = _colore_kit()
	for n: Control in [_k0, _tn0, _sc, _tn1, _k1]:
		riga.add_child(n)
	_segnapunti.add_child(riga)
	add_child(_segnapunti)


func _colore_kit() -> ColorRect:
	var k := ColorRect.new()
	k.custom_minimum_size = Vector2(10, 14)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return k


func _crea_angoli() -> void:
	_pausa = Button.new()
	_pausa.text = "II"
	_pausa.focus_mode = Control.FOCUS_NONE
	_pausa.custom_minimum_size = Vector2(42, 42)
	_pausa.add_theme_font_override("font", _font_forte)
	_pausa.add_theme_font_size_override("font_size", 15)
	for st in ["normal", "hover", "pressed", "focus"]:
		_pausa.add_theme_stylebox_override(st, _stile(Color(0.039, 0.063, 0.125, 0.8), 12, Color(1, 1, 1, 0.19)))
	_pausa.pressed.connect(func() -> void: pausa_premuta.emit())
	add_child(_pausa)
	_fps = _etichetta(10, Color(0.85, 1.0, 0.85, 0.85), false)
	_ombra(_fps, 3)
	add_child(_fps)
	_orologio = PanelContainer.new()
	var so := _stile(FONDO, 10)
	so.content_margin_left = 9
	so.content_margin_right = 9
	_orologio.add_theme_stylebox_override("panel", so)
	_orologio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orologio_l = _etichetta(14)
	_orologio_l.custom_minimum_size.x = 30
	_orologio_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_orologio.add_child(_orologio_l)
	add_child(_orologio)
	_mappa = Minimappa.new()
	_mappa.size = Vector2(78, 118)
	add_child(_mappa)


func _crea_centro() -> void:
	_big = _etichetta(46)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_big.add_theme_constant_override("outline_size", 10)
	_big.modulate.a = 0.0
	add_child(_big)
	_cam_tip = _pillola()
	_cam_tip.get_child(0).text = TESTO_CAM
	_cam_tip.visible = false
	add_child(_cam_tip)
	for k in ["‹", "›"]:
		var f := _etichetta(30, Color(1, 1, 1, 0.38), false)
		f.text = k
		_ombra(f, 4)
		f.visible = false
		add_child(f)
		_frecce.append(f)


func _pillola() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _stile(Color(0.039, 0.063, 0.125, 0.77), 999))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _etichetta(13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _crea_basso() -> void:
	_suggerimento = _pillola()
	_suggerimento_l = _suggerimento.get_child(0)
	_suggerimento.visible = false
	add_child(_suggerimento)
	_dribbling = Button.new()
	_dribbling.text = "Dribbling"
	_dribbling.focus_mode = Control.FOCUS_NONE
	_dribbling.custom_minimum_size = Vector2(170, 58)
	_dribbling.add_theme_font_override("font", _font_forte)
	_dribbling.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "pressed", "focus"]:
		var s := _stile(GIALLO if st != "pressed" else GIALLO.darkened(0.15), 999, Color(0, 0, 0, 0))
		s.shadow_color = Color("#b39400")
		s.shadow_offset = Vector2(0, 0 if st == "pressed" else 6)
		s.shadow_size = 1
		_dribbling.add_theme_stylebox_override(st, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_dribbling.add_theme_color_override(c, Color("#141414"))
	_dribbling.visible = false
	_dribbling.pressed.connect(func() -> void: dribbling_premuto.emit())
	add_child(_dribbling)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func _crea_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.027, 0.043, 0.078, 0.9)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay_box = VBoxContainer.new()
	_overlay_box.add_theme_constant_override("separation", 12)
	_overlay.add_child(_overlay_box)
	add_child(_overlay)


# area sicura in punti logici (tacca / Dynamic Island in alto, barra home in basso), come scripts/hud.gd
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
	var tutto := get_viewport().get_visible_rect().size
	_sicura = _area_sicura()
	var s := _sicura
	_rallenty_mat.set_shader_parameter("dim", tutto)
	var top := s.position.y + 8.0
	_pausa.position = Vector2(s.position.x + MARGINE, top)
	_segnapunti.reset_size()
	_segnapunti.position = Vector2(s.position.x + (s.size.x - _segnapunti.size.x) / 2.0, top)
	_orologio.reset_size()
	_orologio.position = Vector2(s.end.x - MARGINE - _orologio.size.x, top + 4.0)
	_mappa.position = Vector2(s.end.x - MARGINE - _mappa.size.x, top + 46.0)
	_fps.position = Vector2(s.end.x - MARGINE - _mappa.size.x, top + 46.0 + _mappa.size.y + 3.0)
	_big.size = Vector2(tutto.x, 0)
	_big.position = Vector2(0, tutto.y * BIG_TOP)
	_big.pivot_offset = Vector2(tutto.x / 2.0, 30.0)
	_adatta_pillola(_cam_tip, s.size.x - 12.0 - 96.0)
	_cam_tip.position = Vector2(s.position.x + 12.0 + (s.size.x - 108.0 - _cam_tip.size.x) / 2.0, top + 52.0)
	_frecce[0].position = Vector2(s.position.x + 6.0, tutto.y * 0.46)
	_frecce[1].position = Vector2(s.end.x - 6.0 - _frecce[1].get_combined_minimum_size().x, tutto.y * 0.46)
	_metti_suggerimento()
	_overlay_box.position = Vector2(s.position.x + 18.0, s.position.y + 26.0)
	_overlay_box.size = Vector2(s.size.x - 36.0, s.size.y - 50.0)


func _metti_suggerimento() -> void:
	var s := _sicura
	_adatta_pillola(_suggerimento, s.size.x - 24.0)
	_suggerimento.position = Vector2(s.position.x + (s.size.x - _suggerimento.size.x) / 2.0, s.end.y - 14.0 - _suggerimento.size.y)
	# tasto Dribbling 62 punti sopra il fondo come nel web, ma sempre sopra il suggerimento (che può andare a capo)
	_dribbling.reset_size()
	var fondo := s.end.y - 62.0
	if _suggerimento.visible:
		fondo = minf(fondo, _suggerimento.position.y - 10.0)
	_dribbling.position = Vector2(s.position.x + (s.size.x - _dribbling.size.x) / 2.0, fondo - _dribbling.size.y)


# una pillola larga quanto il suo testo, al massimo `largo` punti: oltre, il testo va a capo tra le parole
# (a mano: le Label con autowrap dentro un contenitore calcolano l'altezza prima di sapere la larghezza)
func _adatta_pillola(p: PanelContainer, largo: float) -> void:
	var l: Label = p.get_child(0)
	if not l.has_meta("testo"):
		l.set_meta("testo", l.text)
	var font := l.get_theme_font("font")
	var dim := l.get_theme_font_size("font_size")
	var spazio := largo - 24.0 # meno i margini della pillola
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text = _a_capo(String(l.get_meta("testo")), font, dim, spazio)
	l.custom_minimum_size = Vector2.ZERO
	p.size = Vector2.ZERO
	p.reset_size()


static func _a_capo(testo: String, font: Font, dim: int, spazio: float) -> String:
	var righe := PackedStringArray()
	var riga := ""
	for parola in testo.split(" ", false):
		var prova := parola if riga == "" else riga + " " + parola
		if riga != "" and font.get_string_size(prova, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x > spazio:
			righe.append(riga)
			riga = parola
		else:
			riga = prova
	if riga != "":
		righe.append(riga)
	return "\n".join(righe)


# ---------------------------------------------------------------- aggiornamenti dal gioco
## sigle e colori delle due squadre (una volta a inizio partita)
func imposta_squadre(sigla0: String, colore0: Color, sigla1: String, colore1: Color) -> void:
	_tn0.text = sigla0
	_tn1.text = sigla1
	_k0.color = colore0
	_k1.color = colore1
	_disponi()


## punteggio, minuto e minimappa (ogni 100 ms)
func aggiorna(m, me: int) -> void:
	_sc.text = "%d – %d" % [m.score[0], m.score[1]]
	_orologio_l.text = "%d'" % m.minute()
	_mappa.m = m
	_mappa.me = me
	_mappa.queue_redraw()


## testo in basso; caldo = giallo e grande (parata, rigore)
func suggerimento(testo: String, caldo: bool) -> void:
	if testo == _hint_testo and caldo == _hint_caldo:
		return
	_hint_testo = testo
	_hint_caldo = caldo
	_suggerimento.visible = testo != ""
	_suggerimento_l.text = testo
	_suggerimento_l.set_meta("testo", testo)
	_suggerimento.add_theme_stylebox_override("panel", _stile(GIALLO if caldo else Color(0.039, 0.063, 0.125, 0.77), 999, GIALLO if caldo else BORDO))
	_suggerimento_l.add_theme_color_override("font_color", Color("#141414") if caldo else Color.WHITE)
	_suggerimento_l.add_theme_font_size_override("font_size", 16 if caldo else 13)
	_metti_suggerimento()


func mostra_dribbling(si: bool) -> void:
	_dribbling.visible = si


func rallenty(si: bool) -> void:
	_rallenty_on = si


## visuale girata col dito: "" = niente, "tip" = scritta + frecce, "arr" = solo frecce
func aiuto_visuale(chiave: String) -> void:
	_cam_tip.visible = chiave == "tip"
	for f in _frecce:
		f.visible = chiave != ""


## scritta grande al centro (big() del web); classe "g" = gialla, "b" = rossa
func big(testo: String, classe: String = "", ms: int = 1400, piccolo: String = "") -> void:
	_big.text = testo + ("\n" + piccolo if piccolo != "" else "")
	_big.add_theme_color_override("font_color", GIALLO if classe == "g" else (ROSSO if classe == "b" else Color.WHITE))
	_big_fino = Time.get_ticks_msec() + ms
	_big.modulate.a = 0.0
	_big.scale = Vector2(0.8, 0.8)
	var tw := _nuovo_tween_big().set_parallel()
	tw.tween_property(_big, "modulate:a", 1.0, 0.18)
	tw.tween_property(_big, "scale", Vector2.ONE, 0.18)


# un solo tween alla volta sulla scritta grande: una scritta nuova durante la dissolvenza della vecchia resterebbe invisibile
func _nuovo_tween_big() -> Tween:
	if _big_tween != null and _big_tween.is_valid():
		_big_tween.kill()
	_big_tween = create_tween()
	return _big_tween


func testo_big() -> String:
	return _big.text if _big_fino > 0 else ""


## taglio di scena (ripartenza lontana): nero che sparisce
func fade() -> void:
	_fade.color.a = FADE_DA
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, FADE_S)


func aggiorna_anteprima() -> void:
	_anteprima.queue_redraw()


## il punto dello schermo cade su un tasto o su un menu aperto? (allora non è un gesto sul campo)
func tocca_hud(p: Vector2) -> bool:
	if _overlay.visible:
		return true
	for b: Control in [_pausa, _dribbling]:
		if b.visible and b.get_global_rect().grow(6.0).has_point(p):
			return true
	return false


func overlay_aperto() -> bool:
	return _overlay.visible


# ---------------------------------------------------------------- menu (pausa, intervallo, fine)
func _svuota_overlay() -> void:
	for n in _overlay_box.get_children():
		_overlay_box.remove_child(n)
		n.queue_free()
	_overlay.visible = true


func _titolo(testo: String, dim: int = 30, colore: Color = Color.WHITE) -> Label:
	var l := _etichetta(dim, colore)
	l.text = testo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_box.add_child(l)
	return l


func _tasto(testo: String, grande: bool, azione: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 60 if grande else 52)
	b.add_theme_font_override("font", _font_forte)
	b.add_theme_font_size_override("font_size", 18 if grande else 16)
	var fondo := Color("#ffd93d") if grande else Color(1, 1, 1, 0.04)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, _stile(fondo.darkened(0.12) if st == "pressed" else fondo, 16, Color(0, 0, 0, 0) if grande else Color(1, 1, 1, 0.2)))
	var testo_c := Color("#15130a") if grande else Color("#cbd7ee")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, testo_c)
	if azione.is_valid():
		b.pressed.connect(azione)
	_overlay_box.add_child(b)
	return b


func _spazio(h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_box.add_child(s)


func _nota(testo: String) -> void:
	var l := _etichetta(14, Color("#a9b8d6"), false)
	l.text = testo
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(l)


func nascondi_overlay() -> void:
	_overlay.visible = false


## menu di pausa: riprendi, esci (con conferma: "Tocca di nuovo per confermare", come nel web)
func mostra_pausa(testo_esci: String) -> void:
	_svuota_overlay()
	_spazio(_sicura.size.y * 0.06)
	_titolo("Pausa")
	_spazio(8)
	_tasto("Riprendi", true, func() -> void: riprendi.emit())
	var b_esci := _tasto(testo_esci, false, Callable())
	b_esci.pressed.connect(func() -> void:
		if b_esci.get_meta("ok", false):
			esci.emit()
		else:
			b_esci.set_meta("ok", true)
			b_esci.text = "Tocca di nuovo per confermare")
	_spazio(10)
	_nota("Attacco: disegna la strada dal giocatore per correre, una linea in porta per tirare, fino a un compagno per passare.\nDifesa: disegna linee dai tuoi giocatori, oppure tieni premuto per muovere il difensore.\nPortiere: tira una linea dal portiere al punto della porta.")


func mostra_intervallo(gol0: int, gol1: int) -> void:
	_svuota_overlay()
	_spazio(_sicura.size.y * 0.06)
	_titolo("Intervallo")
	_titolo("%d – %d" % [gol0, gol1], 40, GIALLO)
	_spazio(8)
	_tasto("Secondo tempo", true, func() -> void: secondo_tempo.emit())


## schermata di fine partita: d = {titolo, sigle, colori, gol, marcatori: [[squadra, testo]], statistiche: [[nome, a, b]],
## tasto (facoltativo: testo del tasto in fondo, predefinito "Nuova partita")}
func mostra_fine(d: Dictionary) -> void:
	_svuota_overlay()
	_spazio(_sicura.size.y * 0.03)
	_titolo(d.titolo, 16, Color("#a9b8d6"))
	_titolo("Fine partita", 30)
	_overlay_box.add_child(_riga_risultato(d))
	var esito: String = d.esito
	_titolo(esito, 20, GIALLO if esito == "Vittoria!" else (ROSSO if esito == "Sconfitta" else Color.WHITE))
	for mk: Array in d.marcatori:
		var l := _etichetta(14, Color.WHITE, false)
		l.text = mk[1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if mk[0] == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_overlay_box.add_child(l)
	_spazio(6)
	var griglia := GridContainer.new()
	griglia.columns = 3
	griglia.add_theme_constant_override("h_separation", 12)
	griglia.add_theme_constant_override("v_separation", 4)
	for st: Array in d.statistiche:
		for k in 3:
			var l := _etichetta(14, Color("#cbd7ee") if k == 1 else Color.WHITE, k != 1)
			l.text = str(st[[1, 0, 2][k]])
			l.horizontal_alignment = [HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_LEFT][k]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			griglia.add_child(l)
	_overlay_box.add_child(griglia)
	_spazio(10)
	_tasto(String(d.get("tasto", "Nuova partita")), true, func() -> void: nuova_partita.emit())


func _riga_risultato(d: Dictionary) -> HBoxContainer:
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	riga.add_theme_constant_override("separation", 12)
	for k in 3:
		if k == 1:
			var l := _etichetta(44, GIALLO)
			l.text = "%d – %d" % [d.gol[0], d.gol[1]]
			riga.add_child(l)
			continue
		var t := 0 if k == 0 else 1
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var kc := ColorRect.new()
		kc.color = d.colori[t]
		kc.custom_minimum_size = Vector2(26, 8)
		kc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(kc)
		var l := _etichetta(20)
		l.text = d.sigle[t]
		box.add_child(l)
		riga.add_child(box)
	return riga
