# Cerchio del colpo di testa controllato: intorno al giocatore che deve colpire, si svuota mentre passano i secondi del
# fermatempo (fermatempo_testa.gd), con la scritta piccola "Di testa!" sopra. Discreto ma leggibile sul telefono.
# Lo muove l'HUD (hud_partita.gd → cerchio_testa()) con la posizione sullo schermo del giocatore.
extends Control

const RAGGIO := 30.0           # raggio del cerchio (punti logici)
const SPESSORE := 5.0          # spessore dell'arco che resta
const COLORE := Color("#ffe14a")
const FONDO := Color(1, 1, 1, 0.28)   # cerchio intero, sottile, sotto l'arco
const OMBRA := Color(0, 0, 0, 0.45)
const PUNTI := 48
const TESTO := "Di testa!"
const TESTO_DIM := 15
const TESTO_SU := 30.0         # punti tra il cerchio e la scritta: sopra il triangolo del giocatore controllato

var centro := Vector2.ZERO
var frazione := 1.0            # 1 = pieno, 0 = vuoto
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func mostra(c: Vector2, f: float) -> void:
	centro = c
	frazione = clampf(f, 0.0, 1.0)
	visible = true
	queue_redraw()


func nascondi() -> void:
	if visible:
		visible = false


func _draw() -> void:
	draw_arc(centro, RAGGIO, 0.0, TAU, PUNTI, OMBRA, SPESSORE + 3.0, true)
	draw_arc(centro, RAGGIO, 0.0, TAU, PUNTI, FONDO, 2.0, true)
	if frazione > 0.0:
		# parte dall'alto e si svuota in senso orario
		var a0 := -PI / 2.0
		draw_arc(centro, RAGGIO, a0, a0 + TAU * frazione, maxi(4, int(PUNTI * frazione)), COLORE, SPESSORE, true)
	var w := _font.get_string_size(TESTO, HORIZONTAL_ALIGNMENT_LEFT, -1, TESTO_DIM).x
	var p := centro + Vector2(-w / 2.0, -RAGGIO - TESTO_SU)
	draw_string_outline(_font, p, TESTO, HORIZONTAL_ALIGNMENT_LEFT, -1, TESTO_DIM, 4, OMBRA)
	draw_string(_font, p, TESTO, HORIZONTAL_ALIGNMENT_LEFT, -1, TESTO_DIM, COLORE)
