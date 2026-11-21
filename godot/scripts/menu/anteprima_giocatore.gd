# Anteprima 3D del giocatore nell'editor (Preview di src/editor.js): il giocatore della partita (Figura) fermo
# in posa, che gira piano su sé stesso e si gira col dito; inquadratura del corpo o da vicino sulla testa (lì
# oscilla davanti invece di girare). Mondo 3D a parte in una SubViewport, disegnata alla risoluzione dello schermo
# (al massimo 2 pixel per punto: basta e non pesa). Si spegne da sola quando la schermata si chiude.
# Esultanza (scheda Esultanza del campione): mostra_esultanza(id) la fa vedere di fronte, inquadratura più larga,
# ripetuta con una pausa; la telecamera segue il bacino (scivolata, capriola, corsa) così resta inquadrato.
class_name MenuAnteprima
extends Control

const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Esult := preload("res://scripts/partita/mosse/esultanza.gd")
const Coord := preload("res://scripts/coord.gd")

const SPIN := 0.45               # rad/s: rotazione lenta (come il web)
const TRASCINA := 0.012          # rad per px di dito
const SCALA_MAX := 2.0           # pixel per punto della SubViewport
const CAM_BODY := {"y": 1.3, "z": 5.6, "look": 1.2}
const CAM_HEAD := {"y": 2.13, "z": 1.45, "look": 2.07}
const CAM_ESULTANZA := {"y": 1.45, "z": 8.2, "look": 1.05}
const FOV := 30.0
const ES_ENTRA := 0.25           # s: entrata nella posa dell'esultanza
const ES_ESCE := 0.4             # s: alla fine torna fermo...
const ES_PAUSA := 1.1            # s: ... e dopo questa pausa la rifà

var vicino := false:             # inquadratura della testa (schede Viso e Capelli)
	set(v):
		vicino = v
		_goal = CAM_HEAD if v else CAM_BODY
		if _es_id != "":
			_goal = CAM_ESULTANZA

var _vp: SubViewport
var _tex: TextureRect
var _cam: Camera3D
var _fig: Node3D
var _mesh: MeshInstance3D
var _cur := CAM_BODY.duplicate()
var _goal := CAM_BODY
var _yaw := 0.5
var _t := 0.0
var _drag := NAN
var _drag_yaw := 0.0
var _fermo := Fermo.new()
var _es_id := ""                 # esultanza in mostra ("" = nessuna)
var _es_t := 0.0
var _segui := Vector3.ZERO       # punto seguito dalla telecamera sul prato (bacino durante l'esultanza)
var _ctx := {"t": 0.0, "phase": "menu", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}


## giocatore fermo per la posa (STILL del web): i campi che Figura.posa legge
class Fermo:
	extends RefCounted
	var warn := false
	var vx := 0.0
	var vy := 0.0
	var x := 0.0
	var y := 0.0
	var state := "play"
	var cele := 0.0
	var kickAnim := 0.0
	var sprint := false
	var pos := "A"
	var i := 0
	var dive: Variant = null
	var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb2d6")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 1.5
	sole.position = Vector3(2, 4, 3)
	_vp.add_child(sole)
	sole.look_at(Vector3.ZERO)
	var dietro := DirectionalLight3D.new()
	dietro.light_color = Color("#9ec5ff")
	dietro.light_energy = 0.7
	dietro.position = Vector3(-3, 2, -3)
	_vp.add_child(dietro)
	dietro.look_at(Vector3.ZERO)
	var disco := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.85
	cm.bottom_radius = 0.85
	cm.height = 0.002
	cm.radial_segments = 40
	disco.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0, 0, 0, 0.28)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disco.material_override = dm
	_vp.add_child(disco)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.05
	_cam.far = 50.0
	_vp.add_child(_cam)
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	resized.connect(_misura)
	_misura()
	_cur = _goal.duplicate()


func _misura() -> void:
	if _vp == null or size.x < 2.0 or size.y < 2.0:
		return
	var k := minf(MenuSvg.scala_schermo(), SCALA_MAX)
	_vp.size = Vector2i(int(size.x * k), int(size.y * k))


## giocatore da mostrare: kit = {maglia, calzoncini, calzettoni, bordino (Color), stile, numero (Vector4)},
## aspetto = Aspetto.parametri_figura (pelle, capelli, iride, scarpe, stile2 con taglio, barba e sopracciglia)
func metti(kit: Dictionary, aspetto: Dictionary) -> void:
	if _fig == null:
		_fig = Figura.new()
		_fig.scale = Vector3.ONE * Coord.SCALE
		_vp.add_child(_fig)
		_fig.prepara(kit, aspetto, 0.0, TV.avviso())
		_mesh = _fig.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		return
	# stesso modello: si cambiano solo i colori (un materiale per tutti, colori per istanza)
	for k: String in kit:
		_mesh.set_instance_shader_parameter(k, kit[k])
	for k: String in aspetto:
		_mesh.set_instance_shader_parameter(k, aspetto[k])


## esultanza da mostrare ("" = nessuna, il giocatore torna fermo); un id nuovo riparte da capo
func mostra_esultanza(id: String) -> void:
	if id == _es_id:
		return
	_es_id = id
	_es_t = 0.0
	vicino = vicino   # ricalcola l'inquadratura
	if id == "" and _fig != null:
		_fig.esultanza = null


## rifà l'esultanza da capo (tocco sulla stessa scelta)
func riparti() -> void:
	_es_t = 0.0


## esultanza in mostra e a che punto è (per le prove)
func esultanza_in_mostra() -> Dictionary:
	return {"id": _es_id, "t": _es_t}


func _esultanza(dt: float) -> void:
	var c: Esult.Coreografia = Esult.coreografia(_es_id)
	_es_t = fmod(_es_t + dt, c.T + ES_PAUSA)
	var t := minf(_es_t, c.T)
	var w := minf(_es_t / ES_ENTRA, 1.0 - clampf((_es_t - c.T) / ES_ESCE, 0.0, 1.0))
	var po := c.posa(t)
	po["w"] = smoothstep(0.0, 1.0, w)
	_fig.esultanza = po
	# di fronte alla telecamera
	_yaw = wrapf(_yaw, -PI, PI)
	_yaw += (0.0 - _yaw) * minf(1.0, dt * 6.0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.position.x if ev.pressed else NAN
		_drag_yaw = _yaw
		accept_event()
	elif ev is InputEventMouseMotion and not is_nan(_drag):
		_yaw = _drag_yaw + (ev.position.x - _drag) * TRASCINA
		accept_event()


func _process(dt: float) -> void:
	if _fig == null or not is_visible_in_tree():
		return
	dt = minf(dt, 0.05)
	_t += dt
	if _es_id != "":
		_esultanza(dt)
	else:
		if is_nan(_drag):
			_yaw = _yaw + (0.55 * sin(_t * 0.7) - _yaw) * minf(1.0, dt * 2.0) if vicino else _yaw + dt * SPIN
	var k := minf(1.0, dt * 6.0)
	for n: String in ["y", "z", "look"]:
		_cur[n] += (_goal[n] - _cur[n]) * k
	_fig.rotation.y = _yaw
	_ctx.t = _t
	_fig.posa(_fermo, dt, _ctx)
	var segui := Vector3.ZERO
	if _es_id != "":
		segui = _fig.corpo.to_global(Vector3(0, 0.9, 0))
		segui.y = 0.0
	_segui = _segui.lerp(segui, minf(1.0, dt * 9.0))
	_cam.position = _segui + Vector3(0, _cur.y, _cur.z)
	_cam.look_at(_segui + Vector3(0, _cur.look, 0))
