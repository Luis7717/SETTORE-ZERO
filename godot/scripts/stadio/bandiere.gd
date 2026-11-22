# Bandiere dei tifosi (Luis 2026-11-22: "ai tifosi dai anche delle bandiere da sventolare"). Tante bandiere coi colori
# delle squadre sparse tra il pubblico: tante nella curva di casa, un gruppo nel settore ospiti, qualcuna sui lati
# lunghi. Tutte in un solo MultiMesh (una chiamata di disegno, poche centinaia di vertici per bandiera); il movimento
# (asta che va da una parte all'altra, telo che ondeggia, più foga quando il pubblico si alza) è tutto nel vertex
# shader (shaders/bandiere.gdshader), niente fisica. Figlio di Pubblico: si nasconde e si sfoltisce con lui e prende
# la stessa luce del meteo (uniform `luce`).
extends MultiMeshInstance3D

const SHADER := preload("res://shaders/bandiere.gdshader")

const ASTA := 2.3              # lunghezza dell'asta (m), dalle mani in su
const ASTA_SOTTO := 0.35       # quanto spunta sotto le mani (m)
const ASTA_LARGA := 0.06
const TELO_LUNGO := 1.7        # telo (m)
const TELO_ALTO := 1.1
const TELO_PEZZI := Vector2i(8, 3)   # suddivisioni del telo (per le onde)
const MANI := 1.45             # altezza delle mani sopra il posto (tifoso in piedi) (m)
# quante bandiere per tipo di tribuna (vedi scripts/stadio/pubblico.gd)
const QUANTE := {"curva": 30, "ospiti": 14, "lato": 9}
const OSPITI_MEZZO := 22.0     # settore ospiti: metri dal centro della tribuna (come pubblico.gd)
const FILE_MIN := 0.08         # tra che frazioni della pendenza (davanti → in fondo)
const FILE_MAX := 0.8

var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _squadra: PackedFloat32Array = []   # tifoseria di ogni bandiera (0 casa, 1 ospiti)
var _seme: PackedFloat32Array = []      # numero casuale di ogni bandiera (fase e disegno, nello shader)
var _pose: Array[Transform3D] = []      # dove sta ogni bandiera (copia: col server grafico finto non si rilegge)
var _colori := [[Color("#c8102e"), Color("#ffffff")], [Color("#1746a2"), Color("#ffffff")]]


func _init() -> void:
	name = "Bandiere"
	_rng.seed = 5150
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("telo_lungo", TELO_LUNGO)
	material_override = _mat


## tribune come in pubblico.gd: Array di {a0, b0, a1, b1 (Vector3 Godot), tipo}
func costruisci(tribune: Array) -> void:
	var dati: Array = []   # [Transform3D, tifoseria]
	for t: Dictionary in tribune:
		var n: int = QUANTE.get(String(t.tipo), QUANTE.lato)
		for i in n:
			dati.append(_posa(t))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh_bandiera()
	mm.instance_count = dati.size()
	_squadra.resize(dati.size())
	_seme.resize(dati.size())
	_pose.clear()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in dati.size():
		var tr: Transform3D = dati[i][0]
		mm.set_instance_transform(i, tr)
		_pose.append(tr)
		_squadra[i] = dati[i][1]
		_seme[i] = _rng.randf()
		lo = lo.min(tr.origin)
		hi = hi.max(tr.origin)
	multimesh = mm
	var m := ASTA + TELO_ALTO
	custom_aabb = AABB(lo - Vector3(m, m, m), hi - lo + Vector3(m, m, m) * 2.0)
	imposta_colori(_colori[0], _colori[1])


## colori [maglia, secondo colore] di casa e ospiti
func imposta_colori(casa: Array, ospiti: Array) -> void:
	_colori = [casa, ospiti]
	if multimesh == null:
		return
	for i in multimesh.instance_count:
		var c := colori_bandiera(i)
		multimesh.set_instance_color(i, c[0])
		multimesh.set_instance_custom_data(i, c[1])


## colore dell'istanza (primo colore + tifoseria in alpha) e dati in più (secondo colore + numero casuale) della
## bandiera i, come li riceve lo shader
func colori_bandiera(i: int) -> Array[Color]:
	var sq: Array = _colori[1 if _squadra[i] > 0.5 else 0]
	var c1: Color = sq[0]
	var c2: Color = sq[1]
	return [Color(c1.r, c1.g, c1.b, _squadra[i]), Color(c2.r, c2.g, c2.b, _seme[i])]


## dove sta la bandiera i (base dell'asta = mani del tifoso)
func posa(i: int) -> Transform3D:
	return _pose[i]


## stato delle tifoserie (come Pubblico.stato) e tempo (s): a ogni fotogramma
func aggiorna(stato_casa: Vector4, stato_ospiti: Vector4, tempo: float) -> void:
	_mat.set_shader_parameter("stato_casa", stato_casa)
	_mat.set_shader_parameter("stato_ospiti", stato_ospiti)
	_mat.set_shader_parameter("tempo", tempo)


## quante bandiere mostrare (0..1), come la densità del pubblico
func set_densita(k: float) -> void:
	if multimesh != null:
		multimesh.visible_instance_count = int(multimesh.instance_count * k) if k < 1.0 else -1


func quante() -> int:
	return multimesh.instance_count if multimesh != null else 0


## tifoseria di una bandiera (0 casa, 1 ospiti)
func squadra(i: int) -> float:
	return _squadra[i]


# posto di una bandiera su una tribuna: mani di un tifoso in piedi, telo lungo la fila (piano rivolto al campo)
func _posa(t: Dictionary) -> Array:
	var a0: Vector3 = t.a0
	var b0: Vector3 = t.b0
	var a1: Vector3 = t.a1
	var b1: Vector3 = t.b1
	var lungo := a0.distance_to(b0)
	var tipo := String(t.tipo)
	var u := _rng.randf_range(0.04, 0.96)
	var sq := 0.0
	if tipo == "ospiti":
		u = 0.5 + _rng.randf_range(-1.0, 1.0) * OSPITI_MEZZO / lungo   # nel settore ospiti
		sq = 1.0
	elif tipo == "lato" and _rng.randf() < 0.25:
		sq = 1.0
	var w := _rng.randf_range(FILE_MIN, FILE_MAX)
	var p := a0.lerp(b0, u).lerp(a1.lerp(b1, u), w) + Vector3(0.0, MANI, 0.0)
	var x := (b0 - a0).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
	var y := Vector3.UP
	var z := x.cross(y)
	var sc := _rng.randf_range(0.85, 1.12)
	return [Transform3D(Basis(x, y, z).scaled(Vector3.ONE * sc), p), sq]


## mesh di una bandiera (spazio locale): asta lungo +Y (UV.x < 0), telo da X = 0 a TELO_LUNGO in cima all'asta
static func mesh_bandiera() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := ASTA_LARGA * 0.5
	var asta := [Vector3(-h, -ASTA_SOTTO, 0), Vector3(h, -ASTA_SOTTO, 0), Vector3(h, ASTA, 0), Vector3(-h, ASTA, 0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(-1.0, 0.0))
		st.add_vertex(asta[i])
	var nx := TELO_PEZZI.x
	var ny := TELO_PEZZI.y
	for j in ny:
		for i in nx:
			var q: Array[Vector2] = [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var uv := Vector2(q[k].x / nx, q[k].y / ny)
				st.set_uv(uv)
				st.add_vertex(Vector3(uv.x * TELO_LUNGO, ASTA - uv.y * TELO_ALTO, 0.0))
	return st.commit()
