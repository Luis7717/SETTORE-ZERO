# Minimappa in alto a destra (drawRadar di src/main.js): campo visto dall'alto con la squadra 0 che attacca verso
# l'alto, aree di rigore, giocatori coi colori della maglia (portieri a parte), il controllato più grande e giallo.
extends Control

const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")

const BORDO := 6.0
const FONDO := Color(0.043, 0.239, 0.122, 0.8)
const RIGHE := Color(1, 1, 1, 0.45)
const AREA_X := 20.0      # mezza larghezza dell'area di rigore disegnata (m, come il web)
const AREA_D := 16.5

var m = null              # SimMatch (senza tipo: arriva da gioco.gd)
var me := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _X(x: float) -> float:
	return (x + C.HW) / (C.HW * 2.0) * (size.x - BORDO * 2.0) + BORDO


func _Y(y: float) -> float:
	return (C.HL - y) / (C.HL * 2.0) * (size.y - BORDO * 2.0) + BORDO


static func colore(n: int) -> Color:
	return Color.hex(n << 8 | 0xff)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = FONDO
	fondo.set_corner_radius_all(8)
	fondo.border_color = Color(1, 1, 1, 0.16)
	fondo.set_border_width_all(1)
	draw_style_box(fondo, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(BORDO, BORDO, w - BORDO * 2.0, h - BORDO * 2.0), RIGHE, false, 1.5)
	draw_line(Vector2(BORDO, h / 2.0), Vector2(w - BORDO, h / 2.0), RIGHE, 1.5)
	draw_rect(Rect2(_X(-AREA_X), BORDO, _X(AREA_X) - _X(-AREA_X), _Y(C.HL - AREA_D) - BORDO), RIGHE, false, 1.5)
	draw_rect(Rect2(_X(-AREA_X), _Y(-C.HL + AREA_D), _X(AREA_X) - _X(-AREA_X), h - BORDO - _Y(-C.HL + AREA_D)), RIGHE, false, 1.5)
	if m == null:
		return
	var c: R.Player = m.ctrl[me]
	for p: R.Player in m.players:
		if p.off:
			continue
		var kit: Dictionary = m.teams[p.team].kit
		var centro := Vector2(_X(p.x), _Y(p.y))
		var r := 3.5 if p == c else 2.5
		draw_circle(centro, r, colore(int(kit.gk.shirt) if p.pos == "P" else int(kit.shirt)))
		var giro := Color("#ffe14a") if p == c else (Color.WHITE if p.team == 0 else Color.BLACK)
		draw_arc(centro, r, 0.0, TAU, 16, giro, 1.5 if p == c else 0.5, true)
	var b: R.Ball = m.ball
	draw_circle(Vector2(_X(b.x), _Y(b.y)), 2.0, Color.WHITE)
	draw_arc(Vector2(_X(b.x), _Y(b.y)), 2.0, 0.0, TAU, 12, Color.BLACK, 0.75, true)
