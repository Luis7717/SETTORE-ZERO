# Telecamera verticale come quella del gioco web (src/render.js, schermo verticale): dietro l'azione, dalla parte
# della squadra che attacca verso +y, alta 10,5 m e 16 m indietro, guarda 9 m davanti al punto seguito.
# Il punto seguito lo dà la scena (il pallone); trascinando il dito la visuale si sposta (spostamento in m).
extends Camera3D

const Coord := preload("res://scripts/coord.gd")

const CAM_BACK := 16.0       # distanza dietro il punto seguito (m)
const CAM_H := 10.5          # altezza (m)
const AHEAD := 9.0           # lo sguardo cade così avanti al punto seguito (m)
const FOV_VERTICALE := 70.0  # gradi, come baseFov del web in verticale
const SEGUI_K := 4.5         # 1/s: quanto in fretta insegue il punto
const SALTO := 12.0          # oltre questo salto (m) non insegue: va subito lì
const RIENTRO_K := 0.6       # 1/s: lo spostamento fatto col dito torna piano a zero
const MIN_Y := -Coord.HL - 15.5   # la telecamera non va oltre questo punto dietro la propria porta
const SPOSTAMENTO_MAX := 40.0     # m: quanto lontano dal pallone si può spostare la visuale col dito

var spostamento := Vector2.ZERO   # spostamento della visuale deciso col dito (m, coordinate del gioco)
var _c := Vector2(0.0, -20.0)     # punto seguito, già addolcito
var _primo := true


func _ready() -> void:
	fov = FOV_VERTICALE
	keep_aspect = Camera3D.KEEP_HEIGHT
	near = 0.5
	far = 600.0


## segue il punto del gioco (fx, fy); dt in secondi (tempo vero)
func segui(f: Vector2, dt: float, dito_giu: bool) -> void:
	spostamento = spostamento.limit_length(SPOSTAMENTO_MAX)
	var meta := f + spostamento
	if _primo or (_c.distance_to(meta) > SALTO and not dito_giu):
		_c = meta
		_primo = false
	else:
		_c = _c.lerp(meta, minf(1.0, dt * SEGUI_K))
	if not dito_giu:
		spostamento = spostamento.lerp(Vector2.ZERO, minf(1.0, dt * RIENTRO_K))
	var cam_y := _c.y - CAM_BACK
	var h := CAM_H
	if cam_y < MIN_Y:
		h += minf(6.0, (MIN_Y - cam_y) * 0.35)
		cam_y = MIN_Y
	var pos := Coord.a_godot(_c.x * 0.82, cam_y, h)
	var guarda := Coord.a_godot(_c.x * 0.9, _c.y + AHEAD, 0.0)
	look_at_from_position(pos, guarda, Vector3.UP)


## punto del campo (x, y del gioco) sotto il punto dello schermo; null se lo schermo guarda il cielo
func punto_campo(schermo: Vector2) -> Variant:
	var o := project_ray_origin(schermo)
	var d := project_ray_normal(schermo)
	if d.y > -0.001:
		return null
	var t := -o.y / d.y
	return Coord.da_godot(o + d * t)
