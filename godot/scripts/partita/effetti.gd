# Effetti della partita (solo grafica, figli di PartitaVista): scia del pallone sui tiri forti, sbuffo d'erba sul
# calcio, coriandoli sul gol. Tutto in coordinate di Godot; la vista dice dove e quando.
#   scia(pos, attiva, cam)      a ogni fotogramma: punto del pallone a schermo, se la scia deve crescere
#   sbuffo(pos)                 calcio: zolle e fili d'erba che saltano (dove c'era il pallone)
#   coriandoli(squadra, colori, flip)   gol: pioggia di coriandoli coi colori di chi segna sopra la porta
#   rallenty(k)                 velocità delle particelle (tempo di gioco / tempo vero)
#   set_quantita(k)             0..1, per i livelli di qualità (meno coriandoli, niente sbuffi a 0)
extends Node3D

const Coord := preload("res://scripts/coord.gd")

const SCIA_N := 16             # punti della scia
const SCIA_W := 0.17           # larghezza della scia vicino al pallone (m)
const SCIA_PASSO := 0.12       # distanza minima tra due punti della scia (m)
const SBUFFI := 3              # emettitori di sbuffi che si alternano
const CORIANDOLI := 900

var _scia_mesh: ImmediateMesh
var _scia: MeshInstance3D
var _punti: Array[Vector3] = []
var _spegni := 0.0             # la scia svanisce in questo tempo dopo l'ultimo tiro (s)
var _sbuffi: Array[GPUParticles3D] = []
var _prossimo := 0
var _cori: GPUParticles3D
var _cori_mat: ParticleProcessMaterial
var _quantita := 1.0
var scia_on := true
var sbuffi_on := true


func _ready() -> void:
	name = "Effetti"
	_crea_scia()
	for i in SBUFFI:
		_sbuffi.append(_crea_sbuffo())
	_crea_coriandoli()
	_scalda.call_deferred()


# fa partire una volta coriandoli e sbuffi quasi vuoti all'avvio: gli shader delle particelle si preparano adesso,
# non al primo gol (sul PC il primo gol faceva un intoppo di ~150 ms)
func _scalda() -> void:
	for e: GPUParticles3D in [_cori, _sbuffi[0]]:
		e.amount_ratio = 0.002
		e.global_position = Vector3(0.0, 0.05, 0.0)
		e.restart()
	await get_tree().create_timer(0.3).timeout
	_cori.amount_ratio = _quantita
	_sbuffi[0].amount_ratio = 1.0

## scia: pos = centro del pallone (Godot), attiva = tiro forte in corso, cam = posizione della telecamera
func scia(pos: Vector3, attiva: bool, cam: Vector3, dt_real: float) -> void:
	if not scia_on:
		_scia.visible = false
		_punti.clear()
		return
	if attiva:
		_spegni = 0.35
		if _punti.is_empty() or _punti[0].distance_to(pos) > SCIA_PASSO:
			_punti.push_front(pos)
			if _punti.size() > SCIA_N:
				_punti.pop_back()
	else:
		_spegni -= dt_real
		if _spegni <= 0.0:
			_punti.clear()
	_scia.visible = _punti.size() >= 3
	if not _scia.visible:
		return
	var a0 := clampf(_spegni / 0.35, 0.0, 1.0)
	_scia_mesh.clear_surfaces()
	_scia_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _punti.size()
	for i in n:
		var p: Vector3 = pos if i == 0 else _punti[i]
		var q: Vector3 = _punti[mini(i + 1, n - 1)] if i < n - 1 else _punti[i - 1] * 2.0 - _punti[i - 2]
		var dir := (p - q).normalized() if i < n - 1 else (_punti[i - 1] - p).normalized()
		var lato := dir.cross((cam - p).normalized()).normalized()
		var k := 1.0 - float(i) / (n - 1)
		var w := SCIA_W * (0.25 + 0.75 * k)
		var c := Color(1.0, 0.97, 0.85, 0.55 * k * k * a0)
		_scia_mesh.surface_set_color(c)
		_scia_mesh.surface_add_vertex(p + lato * w)
		_scia_mesh.surface_set_color(c)
		_scia_mesh.surface_add_vertex(p - lato * w)
	_scia_mesh.surface_end()


## sbuffo d'erba al calcio
func sbuffo(pos: Vector3) -> void:
	if not sbuffi_on:
		return
	var e := _sbuffi[_prossimo]
	_prossimo = (_prossimo + 1) % _sbuffi.size()
	e.global_position = Vector3(pos.x, 0.03, pos.z)
	e.restart()


## coriandoli sopra la porta dove ha segnato `squadra` (0 attacca verso y = +50 del motore); colori = [maglia, 2°]
func coriandoli(squadra: int, colori: Array, flip: float) -> void:
	if _quantita <= 0.0:
		return
	var gy := (Coord.HL if squadra == 0 else -Coord.HL) + (8.0 if squadra == 0 else -8.0)
	_cori.global_position = Vector3(0.0, 15.0, -flip * gy)
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.72, 0.88])
	g.colors = PackedColorArray([colori[0], colori[1], colori[0].lightened(0.25), Color("#ffd43b")])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	_cori_mat.color_initial_ramp = gt
	_cori.amount_ratio = _quantita
	_cori.restart()


## velocità delle particelle (1 = normale; nel rallenty più lente, come il gioco)
func rallenty(k: float) -> void:
	var s := clampf(k, 0.0, 1.0)
	for e in _sbuffi:
		e.speed_scale = s
	_cori.speed_scale = maxf(s, 0.35) if s > 0.0 else 0.0   # nel rallenty i coriandoli cadono lo stesso; in pausa si fermano


func set_quantita(k: float) -> void:
	_quantita = clampf(k, 0.0, 1.0)


# ---------------------------------------------------------------- costruzione
func _crea_scia() -> void:
	_scia_mesh = ImmediateMesh.new()
	_scia = MeshInstance3D.new()
	_scia.name = "Scia"
	_scia.mesh = _scia_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_fog = true
	_scia.material_override = m
	_scia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scia.extra_cull_margin = 16384.0
	_scia.visible = false
	add_child(_scia)


func _crea_sbuffo() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.name = "Sbuffo"
	e.amount = 22
	e.lifetime = 0.7
	e.one_shot = true
	e.explosiveness = 0.92
	e.emitting = false
	e.local_coords = false
	e.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 50.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -9.0, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0.36, 0.6, 0.24, 1.0), Color(0.3, 0.52, 0.2, 0.9), Color(0.3, 0.5, 0.2, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var g2 := Gradient.new()
	g2.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g2.offsets = PackedFloat32Array([0.0, 0.7])
	g2.colors = PackedColorArray([Color(0.62, 0.85, 0.45), Color(0.55, 0.42, 0.28)])   # fili d'erba e un po' di terra
	var gt2 := GradientTexture1D.new()
	gt2.gradient = g2
	pm.color_initial_ramp = gt2
	e.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	e.draw_pass_1 = q
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(e)
	return e


func _crea_coriandoli() -> void:
	_cori = GPUParticles3D.new()
	_cori.name = "Coriandoli"
	_cori.amount = CORIANDOLI
	_cori.lifetime = 6.5
	_cori.one_shot = true
	_cori.explosiveness = 0.75
	_cori.emitting = false
	_cori.local_coords = false
	_cori.visibility_aabb = AABB(Vector3(-45, -20, -30), Vector3(90, 40, 60))
	_cori_mat = ParticleProcessMaterial.new()
	_cori_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_cori_mat.emission_box_extents = Vector3(26.0, 4.0, 14.0)
	_cori_mat.direction = Vector3(0, 1, 0)
	_cori_mat.spread = 180.0
	_cori_mat.initial_velocity_min = 1.0
	_cori_mat.initial_velocity_max = 5.0
	_cori_mat.gravity = Vector3(0.4, -1.5, 0.0)
	_cori_mat.damping_min = 0.6
	_cori_mat.damping_max = 1.2
	_cori_mat.angle_min = 0.0
	_cori_mat.angle_max = 360.0
	_cori_mat.angular_velocity_min = -540.0
	_cori_mat.angular_velocity_max = 540.0
	_cori_mat.scale_min = 0.7
	_cori_mat.scale_max = 1.3
	_cori_mat.turbulence_enabled = true
	_cori_mat.turbulence_noise_strength = 1.6
	_cori_mat.turbulence_noise_scale = 6.0
	_cori_mat.turbulence_influence_min = 0.05
	_cori_mat.turbulence_influence_max = 0.15
	var fine := Gradient.new()
	fine.offsets = PackedFloat32Array([0.0, 0.85, 1.0])
	fine.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fine
	_cori_mat.color_ramp = ft
	_cori.process_material = _cori_mat
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	_cori.draw_pass_1 = q
	_cori.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cori)
