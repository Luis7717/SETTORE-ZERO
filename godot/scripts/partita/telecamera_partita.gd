# Telecamera della partita (porting della parte telecamera di View.update in src/render.js): dietro l'azione, vicino
# alla porta avversaria scende e si avvicina, senza palla più alta e larga, nel duello più bassa; visuali calcolate
# (camfit.gd) per il rallenty largo, il calcio d'angolo e la parata; visuale girata dalla persona (user_yaw).
# Lavora nello spazio "orientato" (la squadra umana attacca verso +y): Godot = (x, h, −y). Tutto col tempo vero,
# tranne il duello (come nel web).
extends Camera3D

const Coord := preload("res://scripts/coord.gd")
const CF := preload("camfit.gd")
const CU := preload("camuser.gd")

const HL := Coord.HL
const POSE_K := 5.0            # visuali calcolate: quanto in fretta inseguono l'inquadratura giusta (1/s)
const POSE_K_DRAG := 14.0      # ... mentre il dito gira la visuale
const WIDE_IN := 4.0           # rallenty largo: velocità di entrata e uscita (1/s)
const CAM_BACK := 16.0         # distanza dietro il pallone (m), schermo verticale
const CAM_H := 10.5            # altezza (m)
const NEAR_X0 := 4.0           # vicino alla porta: da |x| > 4 m la telecamera si avvicina meno...
const NEAR_XW := 8.0           # ... da 12 m per niente
const DEF_BACK := 6.0          # senza palla: più indietro,
const DEF_UP := 6.0            # più alta,
const DEF_LOOK := 12.0         # e guarda verso la propria porta (m)
const CAM_SNAP := 12.0         # oltre questo salto del pallone (m) la telecamera va subito lì
const DUEL_LOW := 0.3          # quanto si abbassa nel duello (0 = niente, 1 = a terra)
const DUEL_BACK := 0.12        # nel duello si allontana di questa frazione della distanza normale
const FOLLOW_K := 4.5          # 1/s: quanto in fretta insegue il pallone
const ZOOM_K := 7.0            # 1/s: zoom (più larga senza palla e mentre si disegna)
const MIN_Y := -HL - 15.5      # la telecamera non va oltre questo punto dietro la propria porta

var base_fov := 70.0
var cx := 0.0
var cy := -20.0
var _near := 0.0
var _zoom := 0.0
var _duel_k := 0.0
var _def_w := 0.0
var _wide_k := 0.0
var _wide_p: Variant = null     # {pos, look, fov} inseguita
var _corn_k := 0.0
var _corner_p: Variant = null
var _gk_k := 0.0
var _save_p: Variant = null


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_HEIGHT
	near = 0.5
	far = 600.0
	fov = base_fov


## nuova partita: la telecamera parte sul pallone
func reset(x: float, y: float) -> void:
	cx = x
	cy = y
	_near = 0.0
	_wide_k = 0.0
	_wide_p = null
	_corn_k = 0.0
	_corner_p = null
	_gk_k = 0.0
	_save_p = null


func _aspect() -> float:
	var r := get_viewport().get_visible_rect().size
	return r.x / maxf(1.0, r.y)


## a ogni fotogramma dopo il passo del motore. dt = tempo di gioco, rdt = tempo vero (s); zoom_t = zoom voluto dal
## gioco (setZoom del web), < 0 = calcolato qui con le stesse regole di src/main.js
func aggiorna(m: Object, me: int, dt: float, rdt: float, drawing: bool, cam_drag: bool, user_yaw: float, zoom_t: float = -1.0) -> void:
	var b: Object = m.ball
	var size := get_viewport().get_visible_rect().size
	var port := size.x < size.y
	base_fov = 70.0 if port else 42.0   # le visuali calcolate lo allargano solo quando serve
	var restart_on: bool = m.phase == "restart" and m.restart != null
	var mine_ball: bool = b.owner != null and b.owner.team == me
	var my_restart: bool = restart_on and m.restart.team == me
	if zoom_t < 0.0:
		zoom_t = 1.0 if (drawing or my_restart or not mine_ball) else (0.5 if m.phase == "restart" else 0.4)
	_zoom += (zoom_t - _zoom) * minf(1.0, rdt * ZOOM_K)
	var duel: bool = m.duelFor(me)
	_duel_k += ((1.0 if duel else 0.0) - _duel_k) * minf(1.0, dt * 5.0)
	var dir := -1.0 if me == 1 else 1.0
	var fx: float = b.x
	var fy: float = b.y
	if restart_on:
		fx = m.restart.x
		fy = m.restart.y
	var k := minf(1.0, rdt * FOLLOW_K)
	if Vector2(fx - cx, fy - cy).length() > CAM_SNAP:
		cx = fx
		cy = fy
		_near = 0.0
	else:
		cx += (fx - cx) * k
		cy += (fy - cy) * k
	# vicino alla porta avversaria scende e si avvicina, ma solo col pallone verso il centro
	var mine: bool = mine_ball and m.phase != "goal"
	var wide := clampf(1.0 - (absf(cx) - NEAR_X0) / NEAR_XW, 0.0, 1.0)
	var near_t := clampf((cy * dir - 14.0) / 18.0, 0.0, 1.0) * wide if mine else 0.0
	_near += (near_t - _near) * minf(1.0, rdt * 3.0)
	var a := _near
	var z := _zoom * (1.0 - 0.75 * a)
	var back := ((CAM_BACK if port else 26.0) + z * 6.0) * (1.0 - 0.3 * a)
	var hgt := ((CAM_H if port else 13.0) + z * 5.0) * (1.0 - 0.4 * a)
	var ahead := 9.0 + z * 4.0 + a * 9.0
	# senza palla: più alta e più indietro, guarda verso la propria porta dove stanno i difensori
	var def_t := 1.0 if (not mine and m.phase == "play") else 0.0
	_def_w += (def_t - _def_w) * minf(1.0, rdt * 2.5)
	var dw := _def_w
	var cam_y := cy * dir - back - DEF_BACK * dw
	var hh := hgt + DEF_UP * dw
	var look_y := cy * dir + ahead - DEF_LOOK * dw
	if cam_y < MIN_Y:
		hh += minf(6.0, (MIN_Y - cam_y) * 0.35)
		cam_y = MIN_Y
	# duello: più bassa e più avanti
	var du := _duel_k
	hh *= 1.0 - DUEL_LOW * du
	cam_y += back * (0.3 - DUEL_BACK) * du
	look_y += 8.0 * du
	var px := cx * dir * (0.82 - 0.3 * a)
	var py := cam_y
	var lx := cx * dir * (0.9 - 0.45 * a)
	var ly := look_y
	# la visuale gira intorno al portatore dell'angolo scelto dalla persona
	if absf(user_yaw) > 1e-3:
		var ox := cx * dir
		var oy := cy * dir
		var cs := cos(user_yaw)
		var sn := sin(user_yaw)
		var p2 := Vector2(ox + (px - ox) * cs + (py - oy) * sn, oy - (px - ox) * sn + (py - oy) * cs)
		var l2 := Vector2(ox + (lx - ox) * cs + (ly - oy) * sn, oy - (lx - ox) * sn + (ly - oy) * cs)
		px = p2.x
		py = p2.y
		lx = l2.x
		ly = l2.y
	var pose := {"pos": Vector3(px, hh, py), "look": Vector3(lx, 0, ly), "fov": base_fov}
	var pk := minf(1.0, rdt * POSE_K)
	var pk_drag := minf(1.0, rdt * POSE_K_DRAG) if cam_drag else pk
	var wk := _wide_step(m, me, mine, duel, rdt, pk_drag, drawing, user_yaw)
	if wk > 1e-3:
		pose = _mix(pose, _wide_p, wk)
	var ck := _corner_step(m, dir, rdt, pk_drag, user_yaw)
	if ck > 1e-3:
		pose = _mix(pose, _corner_p, ck)
	var gk := _save_step(m, me, dir, rdt, pk)
	if gk > 1e-3:
		pose = _mix(pose, _save_p, gk)
	var pos: Vector3 = pose.pos
	var look: Vector3 = pose.look
	look_at_from_position(Vector3(pos.x, pos.y, -pos.z), Vector3(look.x, look.y, -look.z), Vector3.UP)
	if absf(fov - float(pose.fov)) > 0.01:
		fov = pose.fov


# rallenty in attacco (duello, fuga, area di tiro, disegno col pallone, colpo di testa): visuale larga coi compagni davanti e di fianco
func _wide_step(m: Object, me: int, mine: bool, duel: bool, rdt: float, pk: float, drawing: bool, user_yaw: float) -> float:
	var c: Object = m.ball.owner
	var zone: bool = not duel and m.inZone(me)
	var flee: bool = m.fleeFor(me)
	var on: bool = mine and c != null and m.phase == "play" and (duel or zone or flee or drawing)
	# colpo di testa controllato: visuale vicina come nel tiro, solo chi colpisce e la porta (Luis 2026-11-23: i
	# compagni lontani, come chi ha crossato, allargherebbero troppo l'inquadratura)
	var testa: bool = m.headFor(me)
	if testa:
		c = m.headWin.p
		zone = true
		on = true
	_wide_k += ((1.0 if on else 0.0) - _wide_k) * minf(1.0, rdt * WIDE_IN)
	if _wide_k < 1e-3 and not on:
		_wide_k = 0.0
		_wide_p = null
		return 0.0
	if on:
		var dir := -1.0 if me == 1 else 1.0
		var mates: Array = []
		for p: Object in m.players:
			if not testa and p.team == me and not p.off and p != c and p.pos != "P":
				mates.append(Vector2(p.x * dir, p.y * dir))
		var v := CF.head_view(Vector2(c.x * dir, c.y * dir), user_yaw, base_fov) if testa else CF.wide_view(Vector2(c.x * dir, c.y * dir), user_yaw, mates, CU.keep_goal(zone, user_yaw), _aspect(), base_fov)
		_wide_p = _smooth(_wide_p, v, pk)
	return _wide_k if _wide_p != null else 0.0


# calcio d'angolo (di chiunque): alle spalle del battitore, verso l'area; dopo il calcio torna piano alla normale
func _corner_step(m: Object, dir: float, rdt: float, pk: float, user_yaw: float) -> float:
	var r: Object = m.restart
	var on: bool = m.phase == "restart" and r != null and r.type == "corner"
	_corn_k += ((1.0 if on else 0.0) - _corn_k) * minf(1.0, rdt * (4.0 if on else 1.5))
	if _corn_k < 1e-3 and not on:
		_corn_k = 0.0
		_corner_p = null
		return 0.0
	if on:
		_corner_p = _smooth(_corner_p, CF.corner_view(Vector2(r.x * dir, r.y * dir), user_yaw, _aspect(), base_fov), pk)
	return _corn_k if _corner_p != null else 0.0


## la visuale della parata resta: mentre si può parare (diveWin, come il web) e poi finché il nostro portiere è in
## tuffo col tiro ancora in volo (2026-11-21: prima, alzato il dito, la telecamera se ne andava subito e il tuffo non
## si vedeva, "sembra che non si tuffi")
static func parata_in_vista(m: Object, me: int) -> bool:
	if m.autoGk[me]:
		return false
	if m.diveWin(me):
		return true
	var b: Object = m.ball
	var g: Object = m.gk(me)
	return m.phase == "play" and g.state == "dive" and b.shot != null and b.shot.team != me and b.owner == null


# parata: dietro la propria porta, porta intera + portiere + pallone sempre a schermo
func _save_step(m: Object, me: int, dir: float, rdt: float, pk: float) -> float:
	var on: bool = parata_in_vista(m, me)
	_gk_k += ((1.0 if on else 0.0) - _gk_k) * minf(1.0, rdt * 6.0)
	if _gk_k < 1e-3 and not on:
		_gk_k = 0.0
		_save_p = null
		return 0.0
	if on:
		var b: Object = m.ball
		var g: Object = m.gk(me)
		_save_p = _smooth(_save_p, CF.save_view(Vector3(b.x * dir, b.h, b.y * dir), Vector2(g.x * dir, g.y * dir), _aspect(), base_fov), pk)
	return _gk_k if _save_p != null else 0.0


# insegue l'inquadratura calcolata v; la prima volta ci va subito
static func _smooth(s: Variant, v: Dictionary, k: float) -> Dictionary:
	if s == null:
		return {"pos": v.pos, "look": v.look, "fov": v.fov}
	return {"pos": (s.pos as Vector3).lerp(v.pos, k), "look": (s.look as Vector3).lerp(v.look, k), "fov": lerpf(s.fov, v.fov, k)}


static func _mix(p: Dictionary, q: Dictionary, w: float) -> Dictionary:
	return {"pos": (p.pos as Vector3).lerp(q.pos, w), "look": (p.look as Vector3).lerp(q.look, w), "fov": lerpf(p.fov, q.fov, w)}
