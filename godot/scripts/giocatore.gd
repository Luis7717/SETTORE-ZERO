# Un giocatore a schermo: modello athlete.glb (Quaternius, CC0) con divisa colorata dallo shader
# shaders/divisa.gdshader e animazioni fermo / corsa / scatto mescolate in base alla velocità (AnimationTree).
# Solo grafica: dove sta e quanto corre lo decide chi lo usa (oggi la scena di prova, domani il motore).
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const MODELLO := preload("res://assets/models/athlete.glb")
const SHADER_DIVISA := preload("res://shaders/divisa.gdshader")
const Capelli := preload("res://scripts/partita/capelli.gd")
const Viso := preload("res://scripts/partita/viso.gd")
const MASCHERE_VISO := preload("res://assets/textures/viso_maschere.png")
const Vestibilita := preload("res://scripts/partita/vestibilita.gd")

const RUN_REF := 4.2       # m/s: velocità a cui il clip di corsa gira a velocità 1 (come src/athlete3d.js)
const SPRINT_REF := 8.0    # m/s: idem per lo scatto
const BLEND_K := 8.0       # 1/s: quanto in fretta la miscela delle animazioni insegue la velocità
const GIRA_K := 10.0       # 1/s: quanto in fretta il giocatore si gira verso dove corre
const FERMO_V := 0.25      # m/s: sotto questa velocità non si gira
const CLIP_IN_LOOP := ["idle", "run", "sprint"]
const PARAM_MOTO := &"parameters/moto/blend_position"   # StringName: niente conversione da stringa a ogni fotogramma
const PARAM_TEMPO := &"parameters/tempo/scale"

# risorse condivise tra tutti i giocatori (costruite una volta)
static var _mesh_divisa: ArrayMesh
static var _materiale: ShaderMaterial
static var _albero: AnimationNodeBlendTree
static var _yaw_modello := 0.0
## peso dell'osso della testa per vertice della mesh del corpo (riferimento dei capelli, misure del viso)
static var _peso_testa := PackedFloat32Array()


static var _contorno := Color(1.0, 0.97, 0.9, 0.5)


## contorno di luce dei giocatori (uniform contorno di shaders/divisa.gdshader): rgb colore, a forza. Vale per tutti
## (un solo materiale); se il materiale non c'è ancora si usa quando nasce
static func set_contorno(c: Color) -> void:
	_contorno = c
	if _materiale != null:
		_materiale.set_shader_parameter("contorno", c)


## a fine programma (App._exit_tree): lascia le risorse condivise prima che si spenga il server grafico
static func libera_condivisi() -> void:
	_mesh_divisa = null
	_materiale = null
	_albero = null

var _modello: Node3D
var _mesh: MeshInstance3D
var _albero_anim: AnimationTree
var _v_blend := 0.0
var _yaw := 0.0


## kit: Dictionary con maglia, calzoncini, calzettoni, bordino (Color); aspetto: pelle, capelli (Color)
func prepara(kit: Dictionary, aspetto: Dictionary, sfasa: float) -> void:
	_modello = MODELLO.instantiate() as Node3D
	_modello.name = "Modello"
	add_child(_modello)
	_mesh = _modello.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var scheletro := _modello.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := _modello.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if _mesh_divisa == null:
		_prepara_condivisi(_mesh, scheletro, player)
	_mesh.mesh = _mesh_divisa
	_mesh.material_override = _materiale
	for k in ["maglia", "calzoncini", "calzettoni", "bordino"]:
		_mesh.set_instance_shader_parameter(k, kit[k])
	for k in ["pelle", "capelli"]:
		_mesh.set_instance_shader_parameter(k, aspetto[k])
	# capelli corti di base (taglio 2, come stile2 predefinito dello shader), mesh a parte sull'osso della testa
	var cap := Capelli.attacca(scheletro, _mesh.skin)
	cap.mesh = Capelli.mesh_per(2)
	cap.set_instance_shader_parameter(&"colore", aspetto["capelli"])
	cap.set_instance_shader_parameter(&"pelle", aspetto["pelle"])
	_modello.scale = Vector3.ONE * Coord.SCALE
	_modello.rotation.y = _yaw_modello

	_albero_anim = AnimationTree.new()
	_albero_anim.name = "Animazioni"
	_modello.add_child(_albero_anim)
	_albero_anim.anim_player = _albero_anim.get_path_to(player)
	_albero_anim.tree_root = _albero
	_albero_anim.active = true
	_albero_anim.advance(sfasa)    # i giocatori non corrono tutti col passo uguale


## pos: punto del gioco (x, y); vel: velocità nel gioco (m/s); dt: secondi
func aggiorna(pos: Vector2, vel: Vector2, dt: float) -> void:
	position = Coord.a_godot(pos.x, pos.y)
	var v := vel.length()
	if v > FERMO_V:
		var meta := Coord.yaw_verso(vel.x, vel.y)
		_yaw = lerp_angle(_yaw, meta, minf(1.0, dt * GIRA_K))
	rotation.y = _yaw
	_v_blend = lerpf(_v_blend, v, minf(1.0, dt * BLEND_K))
	_albero_anim.set(PARAM_MOTO, _v_blend)
	_albero_anim.set(PARAM_TEMPO, _scala_tempo(_v_blend))


## guarda subito verso la direzione del gioco (dx, dy)
func guarda(dx: float, dy: float) -> void:
	_yaw = Coord.yaw_verso(dx, dy)
	rotation.y = _yaw


# velocità del clip: a passo lento la corsa rallenta un po', allo scatto accelera (piedi che scivolano meno)
func _scala_tempo(v: float) -> float:
	var ref := RUN_REF if v < RUN_REF else lerpf(RUN_REF, SPRINT_REF, clampf((v - RUN_REF) / (SPRINT_REF - RUN_REF), 0.0, 1.0))
	return clampf(v / ref, 0.75, 1.3)


# ---------------------------------------------------------------- risorse condivise
static func _prepara_condivisi(mi: MeshInstance3D, scheletro: Skeleton3D, player: AnimationPlayer) -> void:
	_mesh_divisa = _mesh_con_riposo(mi.mesh as ArrayMesh, _nomi_ossa(mi.skin, scheletro))
	_materiale = ShaderMaterial.new()
	_materiale.shader = SHADER_DIVISA
	var osso := func(nome: String) -> Vector3:
		var i := scheletro.find_bone(nome)
		return scheletro.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO
	_materiale.set_shader_parameter("anca_y", (osso.call("thigh_l").y + osso.call("thigh_r").y) / 2.0)
	_materiale.set_shader_parameter("caviglia_y", (osso.call("foot_l").y + osso.call("foot_r").y) / 2.0)
	_materiale.set_shader_parameter("collo_y", osso.call("neck_01").y)
	_materiale.set_shader_parameter("spalla_x", absf(osso.call("upperarm_l").x))
	_materiale.set_shader_parameter("gomito_x", absf(osso.call("lowerarm_l").x))
	_materiale.set_shader_parameter("testa", osso.call("Head"))
	_materiale.set_shader_parameter("testa_alto", _mesh_divisa.get_aabb().end.y)
	_materiale.set_shader_parameter("collo_z", osso.call("neck_01").z)
	_materiale.set_shader_parameter("petto_y", osso.call("spine_03").y + 0.07)
	_materiale.set_shader_parameter("polso_x", absf(osso.call("hand_l").x))
	_materiale.set_shader_parameter("occhi", _centro_occhio(_mesh_divisa))
	# verso del modello: dalla caviglia alla punta del piede; lo si gira perché guardi verso −Z (il "davanti" di Godot)
	var punta: Vector3 = osso.call("ball_r") - osso.call("foot_r")
	_yaw_modello = -atan2(-punta.x, -punta.z)
	_materiale.set_shader_parameter("davanti", Vector2(punta.x, punta.z).normalized())
	# capelli e viso come il web: riferimento della testa, cute, barba, sopracciglia, labbra, occhi
	var arr := _mesh_divisa.surface_get_arrays(0)
	var t := Capelli.prepara(arr, _peso_testa)
	Capelli.applica(_materiale)
	Viso.misura(arr, _peso_testa, t.c, t.occhio_l, t.occhio_r)
	Viso.applica(_materiale)
	_materiale.set_shader_parameter("viso_maschere", MASCHERE_VISO)
	_materiale.set_shader_parameter("contorno", _contorno)
	for nome in CLIP_IN_LOOP:
		if player.has_animation(nome):
			player.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	_albero = _costruisci_albero()


# centro dell'occhio sinistro (x > 0) in posa di riposo: i vertici col tassello degli occhi nelle UV (come il web)
static func _centro_occhio(mesh: ArrayMesh) -> Vector3:
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var somma := Vector3.ZERO
	var n := 0
	for i in v.size():
		if uv[i].x >= 0.875 and uv[i].y >= 0.875 and v[i].x > 0.0:
			somma += v[i]
			n += 1
	return somma / n if n > 0 else Vector3(0.034, 1.698, 0.07)


# nome dell'osso per ogni indice di legame della pelle (gli indici delle ossa nella mesh sono quelli della pelle)
static func _nomi_ossa(pelle: Skin, scheletro: Skeleton3D) -> PackedStringArray:
	var out := PackedStringArray()
	if pelle == null:
		for i in scheletro.get_bone_count():
			out.append(scheletro.get_bone_name(i))
		return out
	for i in pelle.get_bind_count():
		var n := String(pelle.get_bind_name(i))
		if n.is_empty() and pelle.get_bind_bone(i) >= 0:
			n = scheletro.get_bone_name(pelle.get_bind_bone(i))
		out.append(n)
	return out


# copia della mesh con, per ogni vertice, la posizione di riposo in CUSTOM0.xyz e la normale di riposo in CUSTOM1.xyz
# (per lo shader della divisa); CUSTOM0.w = 1 se l'osso che lo muove di più è la testa, CUSTOM1.w = 1 se è il collo
# (come le classi dei texel del web); CUSTOM2.x = profondità della valle (Vestibilita: maglia larga / aderente).
# Riempie anche _peso_testa.
static func _mesh_con_riposo(src: ArrayMesh, ossa: PackedStringArray) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var vertici: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normali: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bi: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var bw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per := bi.size() / maxi(1, vertici.size())
		var riposo := PackedFloat32Array()
		riposo.resize(vertici.size() * 4)
		var nr := PackedFloat32Array()
		nr.resize(vertici.size() * 4)
		var pt := PackedFloat32Array()
		pt.resize(vertici.size())
		for i in vertici.size():
			var testa := 0.0
			var migliore := ""
			var mp := -1.0
			for k in per:
				var j := bi[i * per + k]
				var w := bw[i * per + k]
				var nome := ossa[j] if j >= 0 and j < ossa.size() else ""
				if w > mp:
					mp = w
					migliore = nome
				if nome == "Head":
					testa += w
			pt[i] = testa
			riposo[i * 4] = vertici[i].x
			riposo[i * 4 + 1] = vertici[i].y
			riposo[i * 4 + 2] = vertici[i].z
			riposo[i * 4 + 3] = 1.0 if migliore == "Head" else 0.0
			var n := normali[i] if i < normali.size() else Vector3.UP
			nr[i * 4] = n.x
			nr[i * 4 + 1] = n.y
			nr[i * 4 + 2] = n.z
			nr[i * 4 + 3] = 1.0 if migliore == "neck_01" else 0.0
		if s == 0:
			_peso_testa = pt
		arrays[Mesh.ARRAY_CUSTOM0] = riposo
		arrays[Mesh.ARRAY_CUSTOM1] = nr
		arrays[Mesh.ARRAY_CUSTOM2] = Vestibilita.valli(vertici, normali, arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array())
		var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) 			| (Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
		if src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return out


# fermo → corsa → scatto secondo la velocità, poi la velocità del clip
static func _costruisci_albero() -> AnimationNodeBlendTree:
	var moto := AnimationNodeBlendSpace1D.new()
	var punti := {"idle": 0.0, "run": RUN_REF, "sprint": SPRINT_REF}
	for nome: String in punti:
		var clip := AnimationNodeAnimation.new()
		clip.animation = nome
		moto.add_blend_point(clip, punti[nome], -1, nome)
	moto.min_space = 0.0
	moto.max_space = 10.0
	moto.sync = true
	var albero := AnimationNodeBlendTree.new()
	albero.add_node("moto", moto, Vector2(0, 0))
	albero.add_node("tempo", AnimationNodeTimeScale.new(), Vector2(200, 0))
	albero.connect_node("tempo", 0, "moto")
	albero.connect_node("output", 0, "tempo")
	return albero
