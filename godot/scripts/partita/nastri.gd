# Linee a terra della vista (porting di makeRibbon/fillRibbon di src/props.js e di setPath/showRuns/setPreview di
# src/render.js): la linea che il dito sta disegnando (nastro bianco con la freccia; giallo col mirino nel tiro),
# l'anello verde sul compagno che riceve, le linee di difesa/corsa già assegnate (azzurre, resta il tratto da fare),
# i puntini dell'anteprima del volo con la loro ombra e la linea rossa del fuorigioco.
# Coordinate del gioco in ingresso; flip = 1 o −1 (la squadra umana attacca sempre "in su" sullo schermo).
extends Node3D

const TV := preload("texture_vista.gd")
const Coord := preload("res://scripts/coord.gd")

const PATH_MAX := 160          # punti al massimo della linea disegnata
const RUN_PTS := 64            # punti al massimo di una linea di difesa
const RUN_COLOR := Color("#7dd3ff")
const SHOT_COLOR := Color("#ffe14a")
const RECV_COLOR := Color("#7dffb0")
const OFFSIDE_COLOR := Color(1.0, 0.353, 0.353, 0.85)
const PREVIEW_MAX := 80
const PREVIEW_SIZE := 0.62     # m: lato di un puntino dell'anteprima
const LIFT := 0.08             # m: i nastri stanno appena sopra l'erba

var flip := 1.0
var _path_mesh: ImmediateMesh
var _path_mi: MeshInstance3D
var _path_mat: StandardMaterial3D
var _runs_mesh: ImmediateMesh
var _runs_mi: MeshInstance3D
var _target: Sprite3D
var _recv: MeshInstance3D
var _offside: MeshInstance3D
var _dots: MultiMeshInstance3D
var _dot_sh: MultiMeshInstance3D


func _ready() -> void:
	var tex := TV.nastro()
	_path_mesh = ImmediateMesh.new()
	_path_mat = TV.materiale_segno(tex, Color(1, 1, 1, 0.95), 15)
	_path_mi = _mi("LineaDisegnata", _path_mesh, _path_mat)
	_runs_mesh = ImmediateMesh.new()
	_runs_mi = _mi("LineeDifesa", _runs_mesh, TV.materiale_segno(tex, Color(RUN_COLOR, 0.92), 13))
	_target = Sprite3D.new()
	_target.name = "Mirino"
	_target.texture = TV.mirino()
	_target.pixel_size = 1.7 / 128.0
	_target.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_target.no_depth_test = true
	_target.render_priority = 21
	_target.visible = false
	add_child(_target)
	var q := PlaneMesh.new()
	q.size = Vector2(1.6, 1.6)
	_recv = _mi("Ricevitore", q, TV.materiale_segno(TV.anello(), Color(RECV_COLOR, 1.0), 12, false))
	var o := PlaneMesh.new()
	o.size = Vector2(Coord.W, 0.4)
	var om := StandardMaterial3D.new()
	om.albedo_color = OFFSIDE_COLOR
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.no_depth_test = true
	om.render_priority = 14
	_offside = _mi("Fuorigioco", o, om)
	_dots = _punti("Anteprima", TV.puntino(), RUN_COLOR, 17, PREVIEW_SIZE, true)
	_dot_sh = _punti("OmbraAnteprima", TV.ombra(32, 0.55), Color.WHITE, 12, 0.5, false)


func _mi(nome: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0   # nastri ricostruiti a ogni fotogramma: mai tagliati fuori schermo per errore
	mi.visible = false
	add_child(mi)
	return mi


func _punti(nome: String, tex: Texture2D, col: Color, prio: int, lato: float, billboard: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q: Mesh
	if billboard:
		q = QuadMesh.new()
		(q as QuadMesh).size = Vector2(lato, lato)
	else:
		q = PlaneMesh.new()
		(q as PlaneMesh).size = Vector2(lato, lato)
	mm.mesh = q
	mm.instance_count = PREVIEW_MAX
	mm.visible_instance_count = 0
	var mat := TV.materiale_segno(tex, col, prio)
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nome
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)
	return mmi


func _g(x: float, y: float, h: float) -> Vector3:
	return Vector3(flip * x, h, -flip * y)


## riempie il nastro: pts = Array di Vector3(x, y, h) del gioco; wd = Callable(i, n) → mezza larghezza (m);
## arrow = lunghezza della punta (0 = senza). Aggiunge i triangoli alla superficie aperta di `im`.
func _nastro(im: ImmediateMesh, pts: Array, n: int, wd: Callable, arrow: float) -> void:
	if n < 2:
		return
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var tx := 0.0
	var ty := 1.0
	var p := Vector3.ZERO
	for i in n:
		var a: Vector3 = pts[maxi(0, i - 1)]
		var c: Vector3 = pts[mini(n - 1, i + 1)]
		p = pts[i]
		var dx := c.x - a.x
		var dy := c.y - a.y
		var l := sqrt(dx * dx + dy * dy)
		if l > 1e-6:
			tx = dx / l
			ty = dy / l
		var w: float = wd.call(i, n)
		left.append(_g(p.x - ty * w, p.y + tx * w, p.z))
		right.append(_g(p.x + ty * w, p.y - tx * w, p.z))
	if arrow > 0.0:
		var w: float = wd.call(n - 1, n) * 2.5
		left.append(_g(p.x - ty * w, p.y + tx * w, p.z))      # base della punta (giunto di area zero)
		right.append(_g(p.x + ty * w, p.y - tx * w, p.z))
		var tip := _g(p.x + tx * arrow, p.y + ty * arrow, p.z)  # punta
		left.append(tip)
		right.append(tip)
	for i in left.size() - 1:
		_vert(im, left[i], 0.0)
		_vert(im, right[i], 1.0)
		_vert(im, left[i + 1], 0.0)
		_vert(im, right[i], 1.0)
		_vert(im, right[i + 1], 1.0)
		_vert(im, left[i + 1], 0.0)


static func _vert(im: ImmediateMesh, v: Vector3, u: float) -> void:
	im.surface_set_uv(Vector2(u, 0.5))
	im.surface_add_vertex(v)


## linea disegnata dal dito. kind: "run" (strada da correre), "pass", "shot" (gialla col mirino, end_h = altezza
## del punto in porta), "replay" (gialla come il tiro ma senza mirino: nel replay del gol il mirino finiva sul portiere), "def" (linea di difesa). recv = Vector2 del compagno che riceve (anello verde) o null.
func mostra_linea(points: PackedVector2Array, kind: String, end_h: float, recv: Variant) -> void:
	var n := mini(points.size(), PATH_MAX)
	if n < 2:
		nascondi_linea()
		return
	var shot := kind == "shot" or kind == "replay"
	var pts: Array = []
	for i in n:
		var h := LIFT
		if shot and i == n - 1:
			h += end_h
		pts.append(Vector3(points[i].x, points[i].y, h))
	_path_mesh.clear_surfaces()
	_path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_nastro(_path_mesh, pts, n, func(i: int, nn: int) -> float: return (0.3 + 0.16 * (float(i) / nn)) * minf(1.0, 0.4 + i * 0.2), 0.0 if shot else 1.5)
	_path_mesh.surface_end()
	_path_mat.albedo_color = Color(SHOT_COLOR, 0.95) if shot else Color(1, 1, 1, 0.95)
	_path_mi.visible = true
	_target.visible = kind == "shot"
	if _target.visible:
		var e := points[n - 1]
		_target.position = _g(e.x, e.y, end_h)
	_recv.visible = recv != null
	if recv != null:
		var r: Vector2 = recv
		_recv.position = _g(r.x, r.y, 0.04)


func nascondi_linea() -> void:
	_path_mi.visible = false
	_target.visible = false
	_recv.visible = false
	_dots.multimesh.visible_instance_count = 0
	_dot_sh.multimesh.visible_instance_count = 0
	_offside.visible = false


## anteprima del volo vero: pts = Array di Vector3(x, y, h) (da m.predictKick); offside_y = y della linea del
## fuorigioco, NAN = niente linea
func mostra_anteprima(pts: Array, offside_y: float) -> void:
	var n := mini(pts.size(), PREVIEW_MAX)
	for i in n:
		var p: Vector3 = pts[i]
		_dots.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _g(p.x, p.y, p.z + 0.12)))
		_dot_sh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _g(p.x, p.y, 0.03)))
	_dots.multimesh.visible_instance_count = n if n > 1 else 0
	_dot_sh.multimesh.visible_instance_count = n if n > 1 else 0
	_offside.visible = not is_nan(offside_y)
	if _offside.visible:
		_offside.position = _g(0.0, offside_y, 0.05)


## linee di difesa che i giocatori stanno seguendo (m.runs[me]): resta solo il tratto ancora da fare
func mostra_corse(runs: Array) -> void:
	_runs_mesh.clear_surfaces()
	if runs.is_empty():
		_runs_mi.visible = false
		return
	_runs_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for r: Object in runs:
		var path: Array = r.path
		var n := mini(RUN_PTS, 1 + maxi(0, path.size() - r.i))
		if n < 2:
			continue
		var pts: Array = [Vector3(r.p.x, r.p.y, LIFT)]
		for i in range(1, n):
			var q: Dictionary = path[r.i + i - 1]
			pts.append(Vector3(q.x, q.y, LIFT))
		_nastro(_runs_mesh, pts, n, func(i: int, _nn: int) -> float: return 0.2 * minf(1.0, 0.45 + i * 0.25), 0.75)
		any = true
	if any:
		_runs_mesh.surface_end()
	else:
		_runs_mesh.clear_surfaces()
	_runs_mi.visible = any
