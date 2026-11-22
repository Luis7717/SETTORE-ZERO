# Anteprima del calcio che si sta disegnando (setPreview di src/render.js, qui in 2D sopra la vista): puntini del
# volo vero del pallone, linea del fuorigioco e cerchio attorno al compagno che riceve. I punti del campo diventano
# punti dello schermo con world_to_screen della vista. I dati li prepara scripts/partita/gesti.gd (anteprima).
# In più: linea tratteggiata del calcio di prima che aspetta il pallone (gesti.attesa_viva()).
extends Control

const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")

const PUNTO_R := 2.6
const COLORE_VOLO := Color(1, 1, 1, 0.85)
const COLORE_OMBRA := Color(0, 0, 0, 0.35)
const COLORE_FUORIGIOCO := Color(0.45, 0.85, 1.0, 0.75)
const COLORE_RICEVE := Color("#ffe14a")
const TRATTINO := 0.06        # frazione della linea del fuorigioco per ogni trattino
const COLORE_ATTESA_TIRO := Color("#ffe14a")         # ... gialla se è un tiro
const COLORE_ATTESA := Color(0.49, 1.0, 0.69, 0.9)   # linea del calcio di prima in attesa (verde chiaro, tratteggiata)
const ATTESA_TRATTO_PX := 10.0
const ATTESA_VUOTO_PX := 8.0

var hud = null                # hud_partita.gd: da lì vista e gesti


var _extra := false            # all'ultimo disegno c'era la linea in attesa (per toglierla un fotogramma dopo)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## la linea in attesa si muove anche quando gioco.gd non chiede di ridisegnare (pallone in volo)
func _process(_dt: float) -> void:
	if hud == null or hud.gesti == null:
		return
	var ora: bool = not hud.gesti.attesa_viva().is_empty()
	if ora or _extra:
		queue_redraw()
	_extra = ora


func _draw() -> void:
	if hud == null or hud.vista == null or hud.gesti == null:
		return
	_disegna_attesa()
	if not hud.gesti.drawing:
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


## calcio di prima in attesa: linea tratteggiata dal compagno che riceve, cerchio che pulsa su di lui
func _disegna_attesa() -> void:
	var a: Dictionary = hud.gesti.attesa_viva()
	if a.is_empty():
		return
	var v = hud.vista
	var r: R.Player = a.p
	var schermo: PackedVector2Array = []
	for i in a.punti.size():
		var q: Dictionary = a.punti[i]
		var s: Vector3 = v.world_to_screen(r.x, r.y, 0.0) if i == 0 else v.world_to_screen(q.x, q.y, q.h)
		if s.z > 0.5:
			schermo.append(Vector2(s.x, s.y))
	var col: Color = COLORE_ATTESA_TIRO if a.tiro else COLORE_ATTESA
	_tratteggio(schermo, col)
	if schermo.size() > 0:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_arc(schermo[0], 14.0 + 5.0 * k, 0.0, TAU, 32, Color(col, 0.5 + 0.4 * k), 2.5, true)


func _tratteggio(punti: PackedVector2Array, col: Color) -> void:
	var pieno := true
	var resto := ATTESA_TRATTO_PX
	for i in range(1, punti.size()):
		var a := punti[i - 1]
		var b := punti[i]
		var lung := a.distance_to(b)
		var fatto := 0.0
		while fatto < lung:
			var passo := minf(resto, lung - fatto)
			if pieno:
				draw_line(a.lerp(b, fatto / lung), a.lerp(b, (fatto + passo) / lung), col, 3.0, true)
			fatto += passo
			resto -= passo
			if resto <= 0.0:
				pieno = not pieno
				resto = ATTESA_TRATTO_PX if pieno else ATTESA_VUOTO_PX

