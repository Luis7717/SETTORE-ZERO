# Anteprima del calcio che si sta disegnando (setPreview di src/render.js, qui in 2D sopra la vista): puntini del
# volo vero del pallone, linea del fuorigioco e cerchio attorno al compagno che riceve. I punti del campo diventano
# punti dello schermo con world_to_screen della vista. I dati li prepara scripts/partita/gesti.gd (anteprima).
extends Control

const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")

const PUNTO_R := 2.6
const COLORE_VOLO := Color(1, 1, 1, 0.85)
const COLORE_OMBRA := Color(0, 0, 0, 0.35)
const COLORE_FUORIGIOCO := Color(0.45, 0.85, 1.0, 0.75)
const COLORE_RICEVE := Color("#ffe14a")
const TRATTINO := 0.06        # frazione della linea del fuorigioco per ogni trattino

var hud = null                # hud_partita.gd: da lì vista e gesti


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if hud == null or hud.vista == null or hud.gesti == null or not hud.gesti.drawing:
		return
	var v = hud.vista
	var a: Dictionary = hud.gesti.anteprima
	var fy: float = a.fuorigioco
	if is_finite(fy):
		_trattini(v.world_to_screen(-C.HW, fy, 0.0), v.world_to_screen(C.HW, fy, 0.0))
	var punti: Array = a.punti
	for i in punti.size():
		var q: Dictionary = punti[i]
		var s: Vector3 = v.world_to_screen(q.x, q.y, q.h)
		if s.z < 0.5:
			continue
		if q.h > 0.3:
			var o: Vector3 = v.world_to_screen(q.x, q.y, 0.0)
			if o.z > 0.5:
				draw_circle(Vector2(o.x, o.y), PUNTO_R * 0.8, COLORE_OMBRA)
		draw_circle(Vector2(s.x, s.y), PUNTO_R, COLORE_VOLO)
	var r: R.Player = a.ricevitore
	if r != null:
		var s: Vector3 = v.world_to_screen(r.x, r.y, 0.0)
		if s.z > 0.5:
			draw_arc(Vector2(s.x, s.y), 16.0, 0.0, TAU, 32, COLORE_RICEVE, 2.5, true)


func _trattini(a: Vector3, b: Vector3) -> void:
	if a.z < 0.5 or b.z < 0.5:
		return
	var pa := Vector2(a.x, a.y)
	var pb := Vector2(b.x, b.y)
	var t := 0.0
	while t < 1.0:
		draw_line(pa.lerp(pb, t), pa.lerp(pb, minf(1.0, t + TRATTINO * 0.6)), COLORE_FUORIGIOCO, 2.0)
		t += TRATTINO
