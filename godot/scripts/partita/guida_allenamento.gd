# Linea guida dell'allenamento guidato per passaggi e tiri: la linea da seguire col dito (dritta = rasoterra,
# curva = a effetto e alta), tratteggiata sopra il campo, con un "dito" che la percorre ogni GIRO_S secondi.
# I punti del campo li dà allenamento.gd (guida()); la vista li porta sullo schermo (world_to_screen).
# Figlia di allenamento_hud.gd, sotto il riquadro e la scheda.
extends Control

const GIRO_S := 1.6                       # secondi per percorrere la linea col dito finto
const PAUSA_S := 0.5                      # ... più una pausa a fine linea
const COLORE := Color(1.0, 1.0, 1.0, 0.8)
const COLORE_DITO := Color(1.0, 0.882, 0.29, 0.9)   # #ffe14a
const TRATTO_PX := 12.0
const VUOTO_PX := 8.0
const SPESSORE := 3.5
const DITO_R := 13.0

var vista = null          # vista.gd (world_to_screen)
var allenamento = null    # allenamento.gd (guida())
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(dt: float) -> void:
	_t = fmod(_t + dt, GIRO_S + PAUSA_S)
	queue_redraw()


## punti della guida sullo schermo (vuoto se manca qualcosa o un punto è dietro la telecamera)
func punti_schermo() -> PackedVector2Array:
	var out: PackedVector2Array = []
	if vista == null or allenamento == null:
		return out
	for w: Vector3 in allenamento.guida():
		var s: Vector3 = vista.world_to_screen(w.x, w.y, w.z)
		if s.z < 0.5:
			return PackedVector2Array()
		out.append(Vector2(s.x, s.y))
	return out


func _draw() -> void:
	var pts := punti_schermo()
	if pts.size() < 2:
		return
	var pieno := true
	var resto := TRATTO_PX
	var lunghezze: Array[float] = [0.0]
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var l := a.distance_to(b)
		lunghezze.append(lunghezze[-1] + l)
		var fatto := 0.0
		while fatto < l:
			var passo := minf(resto, l - fatto)
			if pieno:
				draw_line(a.lerp(b, fatto / l), a.lerp(b, (fatto + passo) / l), COLORE, SPESSORE, true)
			fatto += passo
			resto -= passo
			if resto <= 0.0:
				pieno = not pieno
				resto = TRATTO_PX if pieno else VUOTO_PX
	draw_circle(pts[-1], 5.0, COLORE)
	# dito finto che percorre la linea
	var u := minf(1.0, _t / GIRO_S) * lunghezze[-1]
	for i in range(1, pts.size()):
		if u <= lunghezze[i]:
			var k := (u - lunghezze[i - 1]) / maxf(1e-6, lunghezze[i] - lunghezze[i - 1])
			var p := pts[i - 1].lerp(pts[i], k)
			draw_circle(p, DITO_R, Color(COLORE_DITO, 0.35))
			draw_arc(p, DITO_R, 0.0, TAU, 28, COLORE_DITO, 2.5, true)
			break
