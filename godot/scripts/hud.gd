# Contatore in alto a sinistra: FPS, tempo del fotogramma peggiore, memoria, chiamate di disegno, risoluzione 3D.
# Serve a Luis per vedere se il telefono è al limite. In basso una riga d'aiuto sui tocchi.
# Tutto dentro l'area sicura dell'iPhone (tacca / Dynamic Island in alto, barra home in basso).
extends CanvasLayer

const AGGIORNA_OGNI := 0.5     # secondi tra un aggiornamento del testo e l'altro
const MARGINE := 8.0           # punti dal bordo dell'area sicura
const AIUTO := "Tocca un giocatore per sceglierlo · tocca il campo per mandarlo lì\nTrascina per spostare la visuale"

var _etichetta: Label
var _aiuto: Label
var _sfondo: PanelContainer
var _t := 0.0
var _peggiore_ms := 0.0
var _fotogrammi := 0
var _somma_fps := 0.0
var _campioni := 0


func _ready() -> void:
	_sfondo = PanelContainer.new()
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(0, 0, 0, 0.45)
	stile.set_corner_radius_all(6)
	stile.content_margin_left = 6
	stile.content_margin_right = 6
	stile.content_margin_top = 3
	stile.content_margin_bottom = 3
	_sfondo.add_theme_stylebox_override("panel", stile)
	_sfondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sfondo)
	_etichetta = Label.new()
	_etichetta.add_theme_font_size_override("font_size", 11)
	_etichetta.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_etichetta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sfondo.add_child(_etichetta)

	_aiuto = Label.new()
	_aiuto.text = AIUTO
	_aiuto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aiuto.add_theme_font_size_override("font_size", 11)
	_aiuto.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_aiuto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_aiuto.add_theme_constant_override("outline_size", 4)
	_aiuto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aiuto)
	get_viewport().size_changed.connect(_disponi)
	_disponi()
	_scrivi()


func _process(delta: float) -> void:
	_t += delta
	_fotogrammi += 1
	_peggiore_ms = maxf(_peggiore_ms, delta * 1000.0)
	if _t >= AGGIORNA_OGNI:
		_scrivi()
		_t = 0.0
		_fotogrammi = 0
		_peggiore_ms = 0.0


## media degli FPS letti finora (per le prove da riga di comando)
func fps_medi() -> float:
	return _somma_fps / maxi(1, _campioni)


func _scrivi() -> void:
	var fps := Engine.get_frames_per_second()
	if _fotogrammi > 0:
		_somma_fps += fps
		_campioni += 1
	var chiamate := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var vp := get_viewport()
	var res := Vector2(vp.get_visible_rect().size) * vp.get_final_transform().get_scale() * vp.scaling_3d_scale
	_etichetta.text = "FPS %d · peggiore %.1f ms\n%s\ndisegni %d · 3D %d×%d" % [
		fps, _peggiore_ms, testo_memoria(), chiamate, int(res.x), int(res.y)]


## memoria in una riga. Nell'app (build "release") Godot non conta la sua memoria (get_static_memory_usage = 0):
## si mostrano la memoria video usata e la RAM ancora libera del telefono secondo il sistema (OS.get_memory_info).
## Se la RAM libera scende molto mentre si gioca, iOS può chiudere l'app.
static func testo_memoria() -> String:
	var video_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var parti := PackedStringArray()
	var motore_mb := OS.get_static_memory_usage() / 1048576.0
	if motore_mb > 0.5:
		parti.append("motore %.0f MB" % motore_mb)
	parti.append("video %.0f MB" % video_mb)
	var info := OS.get_memory_info()
	var libera: int = info.get("available", -1)
	if libera < 0:
		libera = info.get("free", -1)
	if libera >= 0:
		parti.append("RAM libera %.0f MB" % (libera / 1048576.0))
	return " · ".join(parti)


# posiziona le scritte dentro l'area sicura (in punti logici, come tutta l'interfaccia)
func _disponi() -> void:
	var vista := get_viewport().get_visible_rect().size
	var sicura := Rect2(Vector2.ZERO, vista)
	if OS.has_feature("mobile"):
		var schermo := Vector2(DisplayServer.screen_get_size())
		var s := DisplayServer.get_display_safe_area()
		if schermo.x > 0 and schermo.y > 0:
			var k := vista / schermo
			sicura = Rect2(Vector2(s.position) * k, Vector2(s.size) * k)
	_sfondo.position = sicura.position + Vector2(MARGINE, MARGINE)
	_aiuto.size = Vector2(sicura.size.x, 0)
	_aiuto.position = Vector2(sicura.position.x, sicura.end.y - MARGINE - _aiuto.get_combined_minimum_size().y)
