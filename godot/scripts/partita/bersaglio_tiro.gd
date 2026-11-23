# Bersaglio del tiro avversario durante il fermatempo della parata (sim/parata.gd, Luis 2026-11-23: "per il portiere
# non si capisce dove va il tiro"). In 2D sopra la vista, come l'anteprima del calcio: un'ellisse rosso-arancione
# semitrasparente sul piano della linea di porta (contiene il punto vero, ma il centro non coincide) e la scia
# tratteggiata del volo previsto dal pallone al centro del bersaglio. I punti del campo diventano punti dello schermo con
# world_to_screen della vista, a ogni fotogramma (durante il fermatempo la telecamera si sposta dietro la porta).
# I dati li prepara scripts/partita/parata_regia.gd.
extends Control

const PUNTI := 40
const RIEMPI := Color(1.0, 0.35, 0.1, 0.28)
const BORDO := Color(1.0, 0.45, 0.15, 0.95)
const OMBRA := Color(0, 0, 0, 0.45)
const CENTRO_R := 3.5
const SCIA := Color(1.0, 0.55, 0.25, 0.9)
const SCIA_TRATTO_PX := 9.0
const SCIA_VUOTO_PX := 7.0
const SCIA_SPESSORE := 3.0

var hud = null                 # hud_partita.gd: da lì la vista
var dati := {}                 # {x, h, rx, rh, gy, volo: Array di {x, y, h}}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func imposta(d: Dictionary) -> void:
	dati = d
	visible = not d.is_empty()
	if visible:
		queue_redraw()


func _process(_dt: float) -> void:
	if visible:
		queue_redraw() # la telecamera si muove anche col tempo fermo


func _draw() -> void:
	if dati.is_empty() or hud == null or hud.vista == null:
		return
	var v = hud.vista
	_scia(v)
	var gy: float = dati.gy
	var bordo: PackedVector2Array = []
	for i in PUNTI + 1:
		var a := TAU * float(i) / float(PUNTI)
		var s: Vector3 = v.world_to_screen(float(dati.x) + cos(a) * float(dati.rx), gy, maxf(0.0, float(dati.h) + sin(a) * float(dati.rh)))
		if s.z < 0.5:
			return
		bordo.append(Vector2(s.x, s.y))
	draw_colored_polygon(bordo.slice(0, PUNTI), RIEMPI)
	draw_polyline(bordo, OMBRA, 4.5, true)
	draw_polyline(bordo, BORDO, 2.5, true)
	var c: Vector3 = v.world_to_screen(float(dati.x), gy, maxf(0.0, float(dati.h)))
	if c.z > 0.5:
		draw_circle(Vector2(c.x, c.y), CENTRO_R, BORDO)


## scia tratteggiata del volo previsto
func _scia(v) -> void:
	var volo: Array = dati.get("volo", [])
	var punti: PackedVector2Array = []
	for q: Dictionary in volo:
		var s: Vector3 = v.world_to_screen(float(q.x), float(q.y), float(q.h))
		if s.z > 0.5:
			punti.append(Vector2(s.x, s.y))
	var pieno := true
	var resto := SCIA_TRATTO_PX
	for i in range(1, punti.size()):
		var a := punti[i - 1]
		var b := punti[i]
		var lung := a.distance_to(b)
		var fatto := 0.0
		while fatto < lung:
			var passo := minf(resto, lung - fatto)
			if pieno:
				draw_line(a.lerp(b, fatto / lung), a.lerp(b, (fatto + passo) / lung), SCIA, SCIA_SPESSORE, true)
			fatto += passo
			resto -= passo
			if resto <= 0.0:
				pieno = not pieno
				resto = SCIA_TRATTO_PX if pieno else SCIA_VUOTO_PX
