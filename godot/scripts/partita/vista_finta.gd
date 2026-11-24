# Vista FINTA della partita, solo per provare il gioco finché la vista vera (scenes/vista_partita.tscn, altro lavoro)
# non c'è: cilindri colorati su un campo, telecamera dall'alto inclinata dietro il pallone. NON va nella scena finale:
# scripts/partita/gioco.gd la usa solo se scenes/vista_partita.tscn manca (o con --vista-finta).
# Ha gli stessi metodi e le stesse variabili del contratto della vista (class_name PartitaVista):
#   setup(m, me) · update_view(dt_game, dt_real) · world_to_screen(x, y, h) -> Vector3(x_px, y_px, visibile)
#   screen_to_field(p) -> Vector2 · show_path(punti, kind) · clear_path() · trick(p) · dispose()
#   user_yaw, cam_drag, drawing
# più screen_to_goal(p, gy) -> Vector3(x, h, 1/0), facoltativo (scripts/partita/gesti.gd lo usa se c'è).
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const SimMatchScript := preload("res://sim/match.gd")
const R := preload("res://sim/records.gd")
const VD := preload("res://scripts/partita/visuale_dito.gd")
const Campo := preload("res://scripts/campo.gd")

const CAM_DIETRO := 30.0     # m dietro il pallone
const CAM_ALTA := 36.0       # m di altezza
const CAM_AVANTI := 8.0      # lo sguardo cade così avanti al pallone (m)
const CAM_FOV := 55.0
const CAM_SEGUI := 3.0       # 1/s: quanto in fretta segue il pallone
const YAW_RITORNO := 2.5     # 1/s: fuori dal rallenty la visuale girata torna dritta (come CAM_USER_RETURN del web)
const LINEA_LARGA := 0.45    # larghezza della linea disegnata (m)
const COLORI_LINEA := {"run": Color(1, 1, 1, 0.85), "pass": Color(1.0, 0.88, 0.29, 0.9), "shot": Color(1.0, 0.36, 0.3, 0.95), "def": Color(0.4, 0.85, 1.0, 0.9)}
const GIOCHETTI := ["Finta di corpo", "Doppio passo", "Elastico", "Veronica", "Sombrero", "Colpo dell'arcobaleno"] # src/tricks.js

var user_yaw := 0.0
var cam_drag := false
var drawing := false
var dribbling_cam := {}   # (visuale del dribbling: la vista finta non la usa)

var _m: SimMatchScript = null
var _me := 0
var _cam: Camera3D
var _figure: Array[MeshInstance3D] = []
var _palla: MeshInstance3D
var _anello: MeshInstance3D
var _linea: MeshInstance3D
var _linea_mesh: ImmediateMesh
var _fuoco := Vector2.ZERO
var _primo := true


func setup(m: SimMatchScript, me: int) -> void:
	_m = m
	_me = me
	_crea_mondo()
	for p: R.Player in m.players:
		var kit: Dictionary = m.teams[p.team].kit
		var colore := Color.hex((int(kit.gk.shirt) if p.pos == "P" else int(kit.shirt)) << 8 | 0xff)
		var f := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.45
		cil.bottom_radius = 0.45
		cil.height = 2.2
		f.mesh = cil
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colore
		f.material_override = mat
		add_child(f)
		_figure.append(f)
	_palla = _sfera(0.35, Color.WHITE)
	_anello = MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.8
	toro.outer_radius = 1.05
	_anello.mesh = toro
	_anello.material_override = _mat_piatto(Color(1.0, 0.88, 0.29))
	add_child(_anello)
	_linea_mesh = ImmediateMesh.new()
	_linea = MeshInstance3D.new()
	_linea.mesh = _linea_mesh
	var ml := _mat_piatto(Color.WHITE)
	ml.vertex_color_use_as_albedo = true
	ml.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ml.cull_mode = BaseMaterial3D.CULL_DISABLED
	_linea.material_override = ml
	add_child(_linea)
	update_view(0.0, 0.0)


func _crea_mondo() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.47, 0.64, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 1.1
	add_child(sole)
	sole.look_at_from_position(Vector3(-0.42, 0.78, -0.46) * 60.0, Vector3.ZERO, Vector3.UP)
	var campo := Node3D.new()
	campo.set_script(Campo)
	add_child(campo)
	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 0.5
	_cam.far = 400.0
	add_child(_cam)
	_cam.current = true


func _mat_piatto(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _sfera(r: float, c: Color) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	s.mesh = sm
	s.material_override = _mat_piatto(c)
	add_child(s)
	return s


func update_view(_dt_game: float, dt_real: float) -> void:
	if _m == null:
		return
	for i in _m.players.size():
		var p: R.Player = _m.players[i]
		_figure[i].visible = not p.off
		_figure[i].position = Coord.a_godot(p.x, p.y, 1.1)
	var b := _m.ball
	_palla.position = Coord.a_godot(b.x, b.y, b.h + 0.35)
	var c: R.Player = _m.ctrl[_me]
	_anello.visible = c != null and not c.off
	if c != null:
		_anello.position = Coord.a_godot(c.x, c.y, 0.05)
	# visuale girata: resta nel rallenty o mentre si disegna, fuori torna dritta (relaxYaw di src/camuser.js)
	if not (VD.user_cam_on(_m, _me) or drawing or cam_drag):
		user_yaw *= exp(-YAW_RITORNO * maxf(0.0, dt_real))
		if absf(user_yaw) < 1e-3:
			user_yaw = 0.0
	var meta := Vector2(b.x * 0.6, b.y)
	if _primo:
		_fuoco = meta
		_primo = false
	else:
		_fuoco = _fuoco.lerp(meta, minf(1.0, dt_real * CAM_SEGUI))
	var s := 1.0 if _me == 0 else -1.0
	var d := Vector2(sin(user_yaw), cos(user_yaw)) * s
	var guarda := _fuoco + d * CAM_AVANTI
	var pos := _fuoco - d * CAM_DIETRO
	_cam.look_at_from_position(Coord.a_godot(pos.x, pos.y, CAM_ALTA), Coord.a_godot(guarda.x, guarda.y, 0.0), Vector3.UP)


func world_to_screen(x: float, y: float, h: float) -> Vector3:
	var q := Coord.a_godot(x, y, h)
	if _cam.is_position_behind(q):
		return Vector3(0.0, 0.0, 0.0)
	var s := _cam.unproject_position(q)
	return Vector3(s.x, s.y, 1.0)


func screen_to_field(p: Vector2) -> Vector2:
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	if d.y > -0.001:
		return Vector2(INF, INF)
	var g := Coord.da_godot(o + d * (-o.y / d.y))
	return g


func screen_to_goal(p: Vector2, gy: float) -> Vector3:
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	var z := -gy
	if absf(d.z) < 1e-6:
		return Vector3.ZERO
	var t := (z - o.z) / d.z
	if t <= 0.0:
		return Vector3.ZERO
	var q := o + d * t
	return Vector3(q.x, q.y, 1.0)


func show_path(punti: PackedVector2Array, kind: String) -> void:
	_linea_mesh.clear_surfaces()
	if punti.size() < 2:
		return
	var col: Color = COLORI_LINEA.get(kind, Color.WHITE)
	_linea_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, punti.size()):
		var a := punti[i - 1]
		var b := punti[i]
		var dir := b - a
		if dir.length() < 1e-4:
			continue
		var n := Vector2(-dir.y, dir.x).normalized() * LINEA_LARGA * 0.5
		var v := [Coord.a_godot(a.x + n.x, a.y + n.y, 0.08), Coord.a_godot(a.x - n.x, a.y - n.y, 0.08),
			Coord.a_godot(b.x + n.x, b.y + n.y, 0.08), Coord.a_godot(b.x - n.x, b.y - n.y, 0.08)]
		for k in [0, 1, 2, 2, 1, 3]:
			_linea_mesh.surface_set_color(col)
			_linea_mesh.surface_add_vertex(v[k])
	_linea_mesh.surface_end()


func clear_path() -> void:
	if _linea_mesh != null:
		_linea_mesh.clear_surfaces()


## dribbling tentato da p: nome del giochetto (più bello col dribbling alto, come chooseTrick di src/tricks.js)
func trick(p: R.Player, _r: float = -1.0, _side: float = 0.0, _dur: float = -1.0) -> Dictionary:
	var top := clampi(int(floor((p.st.dri - 35.0) / 10.0)), 0, GIOCHETTI.size() - 1)
	var r := randf()
	var giu := 0 if r < 0.6 else (1 if r < 0.9 else 2)
	var k := maxi(0, top - giu)
	return {"id": k, "name": GIOCHETTI[k]}


## posa di reazione al dribbling: la vista finta non la disegna
func reazione(_p: R.Player, _tipo: String, _lato: float, _dur: float) -> void:
	pass


func dispose() -> void:
	_m = null
	for f in _figure:
		f.queue_free()
	_figure.clear()
