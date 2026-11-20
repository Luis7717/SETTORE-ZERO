# Campo da gioco: erba a strisce con le righe (calcolate per pixel da shaders/erba.gdshader), terreno intorno,
# porte con rete, bandierine. Misure e coordinate da scripts/coord.gd (le stesse del gioco web, src/pitch.js).
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const SHADER_ERBA := preload("res://shaders/erba.gdshader")
const SHADER_RETE := preload("res://shaders/rete.gdshader")
const SHADER_BANDIERINA := preload("res://shaders/bandierina.gdshader")
const ReteMolle := preload("res://scripts/rete_molle.gd")

const MX := 10.0               # margine d'erba oltre le linee laterali (m)
const MY := 12.0               # margine d'erba oltre le linee di porta (m)
const ERBA_FUORI := Color("#2c6428")   # terreno oltre i margini
const GRANA_LATO := 256         # lato della texture di grana dell'erba (px)
const PALO_R := 0.06            # raggio di pali e traversa (m)
const RETE_FONDO := 2.0         # profondità della rete a terra (m)
const RETE_ALTO := 1.0          # profondità della rete all'altezza della traversa (m)
const RETE_MAGLIA := 0.14       # lato di una maglia della rete (m)
const BANDIERINA_H := 1.5       # altezza dell'asta della bandierina (m)
const RETE_CELLA := 0.3         # lato dei quadratini in cui è divisa la rete, per farla gonfiare (m)

var _reti := {}                 # lato (1 / −1) → ShaderMaterial della rete
var _molle := {}                # lato (1 / −1) → rete a molle (scripts/rete_molle.gd)


func _ready() -> void:
	_costruisci_erba()
	for lato in [1.0, -1.0]:
		_costruisci_porta(lato)
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			_costruisci_bandierina(sx, sy)


# ---------------------------------------------------------------- erba e righe
func _costruisci_erba() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_ERBA
	mat.set_shader_parameter("grana", _texture_grana())
	var piano := PlaneMesh.new()
	piano.size = Vector2(Coord.W + MX * 2.0, Coord.L + MY * 2.0)
	var erba := MeshInstance3D.new()
	erba.name = "Erba"
	erba.mesh = piano
	erba.material_override = mat
	erba.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(erba)

	# terreno oltre i margini (sotto l'erba, fino alle tribune)
	var fuori := MeshInstance3D.new()
	fuori.name = "TerrenoFuori"
	var pf := PlaneMesh.new()
	pf.size = Vector2(260.0, 300.0)
	fuori.mesh = pf
	var mf := StandardMaterial3D.new()
	mf.albedo_color = ERBA_FUORI
	mf.roughness = 1.0
	fuori.material_override = mf
	fuori.position.y = -0.02
	fuori.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fuori)


func _texture_grana() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	noise.seed = 1234
	var img := noise.get_seamless_image(GRANA_LATO, GRANA_LATO)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- porte
func _costruisci_porta(lato: float) -> void:
	var porta := Node3D.new()
	porta.name = "Porta%s" % ("Nord" if lato > 0 else "Sud")
	add_child(porta)
	var bianco := StandardMaterial3D.new()
	bianco.albedo_color = Color(0.96, 0.96, 0.96)
	bianco.roughness = 0.35
	var gy: float = lato * Coord.HL
	var hx := Coord.GW / 2.0 + PALO_R
	var gh := Coord.GH + PALO_R
	# pali e traversa (sul bordo esterno della linea di porta)
	var sul := gy + lato * PALO_R
	_tubo(porta, Coord.a_godot(-hx, sul, 0.0), Coord.a_godot(-hx, sul, gh), PALO_R, bianco)
	_tubo(porta, Coord.a_godot(hx, sul, 0.0), Coord.a_godot(hx, sul, gh), PALO_R, bianco)
	_tubo(porta, Coord.a_godot(-hx - PALO_R, sul, gh), Coord.a_godot(hx + PALO_R, sul, gh), PALO_R, bianco)
	# sostegni della rete dietro la porta
	var sottile := PALO_R * 0.45
	var fondo := gy + lato * RETE_FONDO
	var alto := gy + lato * RETE_ALTO
	for x in [-hx, hx]:
		_tubo(porta, Coord.a_godot(x, sul, gh), Coord.a_godot(x, alto, gh), sottile, bianco)
		_tubo(porta, Coord.a_godot(x, alto, gh), Coord.a_godot(x, fondo, 0.0), sottile, bianco)
	_tubo(porta, Coord.a_godot(-hx, fondo, 0.02), Coord.a_godot(hx, fondo, 0.02), sottile, bianco)
	# rete: mesh fine, spostamenti dalla rete a molle (una texture letta nei vertici)
	var molle := ReteMolle.new(lato)
	_molle[lato] = molle
	var rete := MeshInstance3D.new()
	rete.name = "Rete"
	rete.mesh = _mesh_rete(molle)
	var mat := _materiale_rete()
	mat.set_shader_parameter("spostamenti", molle.tex)
	_reti[lato] = mat
	rete.material_override = mat
	rete.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	porta.add_child(rete)


# cilindro tra due punti (Godot)
func _tubo(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = a.distance_to(b)
	m.radial_segments = 10
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	var asse := (b - a).normalized()
	var su := Vector3.UP if absf(asse.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	# il cilindro di Godot è lungo Y: costruisce una base con Y lungo il tubo
	var x := su.cross(asse).normalized()
	var z := x.cross(asse).normalized()
	mi.transform = Transform3D(Basis(x, asse, z), (a + b) / 2.0)
	parent.add_child(mi)


# i quattro teli della rete a molle (fondo inclinato, tetto, due fianchi), ognuno diviso in quadratini
func _mesh_rete(molle: RefCounted) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for nome: String in ["fondo", "tetto", "fianco_s", "fianco_d"]:
		_quad(st, molle, nome)
	return st.commit()


# telo diviso in quadratini (punti del gioco x, y, h): UV in metri / maglia, UV2 = posto nella texture degli
# spostamenti, NORMAL = verso fuori dal telo (dove lo spinge il pallone)
func _quad(st: SurfaceTool, molle: RefCounted, nome: String) -> void:
	var t: Dictionary = molle.telo(nome)
	var a: Vector3 = t.a
	var b: Vector3 = t.b
	var c: Vector3 = t.c
	var d: Vector3 = t.d
	var lu := maxf(a.distance_to(b), d.distance_to(c))
	var lv := maxf(a.distance_to(d), b.distance_to(c))
	var nu := maxi(1, ceili(lu / RETE_CELLA))
	var nv := maxi(1, ceili(lv / RETE_CELLA))
	var u_dir: Vector3 = (b - a).normalized()
	var v_dir: Vector3 = (d - a).normalized()
	var n: Vector3 = t.n
	var normale := Coord.a_godot(n.x, n.y, n.z)
	for j in nv:
		for i in nu:
			var ids := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
			for q: Array in ids:
				var u := float(q[0]) / nu
				var v := float(q[1]) / nv
				var p: Vector3 = a.lerp(b, u).lerp(d.lerp(c, u), v)
				st.set_normal(normale)
				st.set_uv(Vector2((p - a).dot(u_dir), (p - a).dot(v_dir)) / RETE_MAGLIA)
				st.set_uv2(molle.uv2(nome, u, v))
				st.add_vertex(Coord.a_godot(p.x, p.y, p.z))


func _materiale_rete() -> ShaderMaterial:
	var lato := 16
	var img := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	img.fill_rect(Rect2i(0, 0, lato, 2), Color(1, 1, 1, 1))
	img.fill_rect(Rect2i(0, 0, 2, lato), Color(1, 1, 1, 1))
	img.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = SHADER_RETE
	m.set_shader_parameter("maglia", ImageTexture.create_from_image(img))
	m.set_shader_parameter("colore", Color(0.95, 0.95, 0.95, 0.9))
	return m


## materiale della rete della porta a y = lato·50 (lato 1 o −1), per cambiarne la trasparenza
func materiale_rete(lato: float) -> ShaderMaterial:
	return _reti.get(1.0 if lato > 0.0 else -1.0)


## rete a molle della porta a y = lato·50 (scripts/rete_molle.gd): chi disegna la partita la fa avanzare col pallone
func rete_molle(lato: float) -> RefCounted:
	return _molle.get(1.0 if lato > 0.0 else -1.0)


# ---------------------------------------------------------------- bandierine
func _costruisci_bandierina(sx: float, sy: float) -> void:
	var b := Node3D.new()
	b.name = "Bandierina"
	b.position = Coord.a_godot(sx * Coord.HW, sy * Coord.HL)
	add_child(b)
	var asta_mat := StandardMaterial3D.new()
	asta_mat.albedo_color = Color(0.95, 0.95, 0.95)
	_tubo(b, Vector3.ZERO, Vector3(0, BANDIERINA_H, 0), 0.022, asta_mat)
	var telo := MeshInstance3D.new()
	telo.name = "Telo"
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 0.3)
	q.subdivide_width = 8
	q.subdivide_depth = 2
	telo.mesh = q
	var tm := ShaderMaterial.new()
	tm.shader = SHADER_BANDIERINA
	tm.set_shader_parameter("colore", Color("#ffcc1a"))
	telo.material_override = tm
	telo.position = Vector3(-sx * 0.21, BANDIERINA_H - 0.15, 0.0)
	b.add_child(telo)
	telo.set_instance_shader_parameter("asta", sx * 0.21)   # il lato attaccato all'asta (x locale)
	telo.set_instance_shader_parameter("fase", (sx + 2.0 * sy) * 1.7)
