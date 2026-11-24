# Campo da gioco: erba col suo taglio (shaders/erba.gdshader, tagli in scripts/tagli_campo.gd), righe bianche come
# mesh (scripts/righe_campo.gd + shaders/righe.gdshader), terreno intorno, porte con rete, bandierine.
# Misure e coordinate da scripts/coord.gd (le stesse del gioco web, src/pitch.js).
#   set_taglio(i)    taglio dell'erba (indice di Tagli.NOMI); `--campo=<nome>` sulla riga di comando vince sempre
#   set_ciuffi_3d(on) ciuffi d'erba in rilievo vicino alla telecamera bassa (shaders/erba_ciuffi.gdshader); la vista
#                    li accende solo a qualità alta; `--senza-ciuffi` li spegne sempre (prove)
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const SHADER_ERBA := preload("res://shaders/erba.gdshader")
const SHADER_CIUFFI := preload("res://shaders/erba_ciuffi.gdshader")
const SHADER_RIGHE := preload("res://shaders/righe.gdshader")
const SHADER_RETE := preload("res://shaders/rete.gdshader")
const SHADER_BANDIERINA := preload("res://shaders/bandierina.gdshader")
const ReteMolle := preload("res://scripts/rete_molle.gd")
const Tagli := preload("res://scripts/tagli_campo.gd")
const RigheCampo := preload("res://scripts/righe_campo.gd")

const MX := 10.0               # margine d'erba oltre le linee laterali (m)
const MY := 12.0               # margine d'erba oltre le linee di porta (m)
const ERBA_FUORI := Color("#2c6428")   # terreno oltre i margini
const ERBA_FILI := "res://assets/textures/erba_fili.png"   # fili d'erba: normale + altezza (tools/genera_texture.gd)
const GRANA_LATO := 256         # lato della texture di grana dell'erba (px)
const PALO_R := 0.06            # raggio di pali e traversa (m)
const RETE_FONDO := 2.0         # profondità della rete a terra (m)
const RETE_ALTO := 1.0          # profondità della rete all'altezza della traversa (m)
const RETE_MAGLIA := 0.14       # lato di una maglia della rete (m)
const BANDIERINA_H := 1.5       # altezza dell'asta della bandierina (m)
const RETE_CELLA := 0.3         # lato dei quadratini in cui è divisa la rete, per farla gonfiare (m)
# ciuffi in rilievo: strati piatti sopra il prato, solo davanti alla telecamera quando è bassa (replay, esultanza,
# primi piani). Quote lontane da quella delle righe (1,2 cm) per non sfarfallare con loro.
const CIUFFI_QUOTE: Array[float] = [0.007, 0.015, 0.022, 0.029]   # m sopra il prato
const CIUFFI_LATO := 20.0       # lato del quadrato di strati (m); lo shader li sfuma entro CIUFFI_RAGGIO
const CIUFFI_RAGGIO := 9.0      # m dalla telecamera
const CIUFFI_CAM_MAX := 4.5     # m: telecamera più alta di così = niente ciuffi (da lassù non si vedrebbero)
const CIUFFI_AVANTI := 0.55     # il quadrato sta davanti alla telecamera di CIUFFI_LATO × questo
const CIUFFI_RIGHE_MAX := 8     # pezzi di riga passati allo shader dei ciuffi (come RIGHE_MAX dello shader)

var _reti := {}                 # lato (1 / −1) → ShaderMaterial della rete
var _molle := {}                # lato (1 / −1) → rete a molle (scripts/rete_molle.gd)
var _mat_erba: ShaderMaterial
var _mat_ciuffi: ShaderMaterial
var _ciuffi: MeshInstance3D
var _ciuffi_on := true          # set_ciuffi_3d: la vista li spegne con la qualità bassa
var _senza_ciuffi := false      # --senza-ciuffi: spenti sempre
var _righe_ciuffi: Array[Dictionary] = []   # pezzi di riga per lo shader dei ciuffi: {a, b: Vector4, box: Rect2}
var _righe_scelte := PackedInt32Array([-1])  # pezzi passati l'ultima volta (per non ripassarli a ogni fotogramma)
var _taglio := Tagli.CLASSICO
var _taglio_forzato := -1       # da --campo=<nome>: vince su set_taglio
var _manto := Tagli.MANTO_CLASSICO
var _manto_forzato := -1        # da --manto=<nome>: vince su set_manto


func _ready() -> void:
	_taglio_forzato = Tagli.da_riga_comando()
	_manto_forzato = Tagli.manto_da_riga_comando()
	_senza_ciuffi = OS.get_cmdline_user_args().has("--senza-ciuffi")   # per confrontare costo e aspetto
	_costruisci_erba()
	_costruisci_righe()
	set_taglio(_taglio)
	set_manto(_manto)
	for lato in [1.0, -1.0]:
		_costruisci_porta(lato)
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			_costruisci_bandierina(sx, sy)


# ---------------------------------------------------------------- erba, taglio e righe
func _costruisci_erba() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_ERBA
	_mat_erba = mat
	_mat_ciuffi = ShaderMaterial.new()
	_mat_ciuffi.shader = SHADER_CIUFFI
	_mat_ciuffi.set_shader_parameter("raggio", CIUFFI_RAGGIO)
	_param("grana", _texture_grana())
	_param("ciuffi_tex", _texture_ciuffi())
	if ResourceLoader.exists(ERBA_FILI):
		_param("fili", load(ERBA_FILI))
	var piano := PlaneMesh.new()
	piano.size = Vector2(Coord.W + MX * 2.0, Coord.L + MY * 2.0)
	var erba := MeshInstance3D.new()
	erba.name = "Erba"
	erba.mesh = piano
	erba.material_override = mat
	erba.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(erba)
	_costruisci_ciuffi()

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


# ciuffi in rilievo: tutti gli strati in una mesh sola (una chiamata di disegno), COLOR.r = quale strato (0..1);
# triangoli in senso orario visti dall'alto (il davanti, per Godot)
func _costruisci_ciuffi() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := CIUFFI_LATO / 2.0
	for i in CIUFFI_QUOTE.size():
		var h: float = CIUFFI_QUOTE[i]
		var c := Color(float(i) / maxf(1.0, CIUFFI_QUOTE.size() - 1.0), 0.0, 0.0)
		for v: Vector2 in [Vector2(-m, -m), Vector2(m, -m), Vector2(m, m), Vector2(-m, -m), Vector2(m, m), Vector2(-m, m)]:
			st.set_color(c)
			st.set_normal(Vector3.UP)
			st.set_uv(v)
			st.add_vertex(Vector3(v.x, h, v.y))
	st.generate_tangents()
	_ciuffi = MeshInstance3D.new()
	_ciuffi.name = "CiuffiErba"
	_ciuffi.mesh = st.commit()
	_ciuffi.material_override = _mat_ciuffi
	_ciuffi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ciuffi.visible = false
	add_child(_ciuffi)
	_righe_ciuffi = righe_per_ciuffi()


## pezzi delle righe (scripts/righe_campo.gd) nel formato dello shader dei ciuffi, coordinate del gioco:
## linea a = (ax, ay, bx, by), b.w = 0; arco a = (cx, cy, r, cos mezza apertura), b = (verso di mezzo, 0, 1);
## punto a = (cx, cy, r, 0), b.w = 2. box = rettangolo che lo contiene (con la mezza larghezza)
static func righe_per_ciuffi() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m := RigheCampo.LARGHEZZA / 2.0
	for p: Dictionary in RigheCampo.pezzi():
		match p.tipo:
			"linea":
				var a: Vector2 = p.a
				var b: Vector2 = p.b
				out.append({"a": Vector4(a.x, a.y, b.x, b.y), "b": Vector4.ZERO,
					"box": Rect2(a, Vector2.ZERO).expand(b).grow(m)})
			"arco":
				var c: Vector2 = p.c
				var mezzo := (float(p.a) + float(p.da)) / 2.0
				var apertura := (float(p.a) - float(p.da)) / 2.0
				out.append({"a": Vector4(c.x, c.y, p.r, cos(minf(apertura, PI))),
					"b": Vector4(cos(mezzo), sin(mezzo), 0.0, 1.0),
					"box": Rect2(c - Vector2.ONE * p.r, Vector2.ONE * p.r * 2.0).grow(m)})
			"punto":
				var c: Vector2 = p.c
				out.append({"a": Vector4(c.x, c.y, p.r, 0.0), "b": Vector4(0.0, 0.0, 0.0, 2.0),
					"box": Rect2(c - Vector2.ONE * p.r, Vector2.ONE * p.r * 2.0)})
	return out


## indici dei pezzi di riga che toccano il quadrato dei ciuffi (centro in coordinate del gioco), al massimo `quanti`
static func righe_vicine(pezzi: Array[Dictionary], centro: Vector2, lato: float, quanti: int) -> PackedInt32Array:
	var zona := Rect2(centro - Vector2.ONE * lato / 2.0, Vector2.ONE * lato)
	var scelti := PackedInt32Array()
	for i in pezzi.size():
		if scelti.size() >= quanti:
			break
		var box: Rect2 = pezzi[i].box
		if zona.intersects(box, true):
			scelti.append(i)
	return scelti


# i ciuffi seguono la telecamera (solo se è bassa): il quadrato sta un po' avanti, nel verso in cui guarda.
# Lo shader usa le coordinate del mondo, quindi spostarli non fa scivolare i fili.
func _process(_delta: float) -> void:
	if _ciuffi == null:
		return
	var cam := get_viewport().get_camera_3d()
	var acceso := _ciuffi_on and not _senza_ciuffi and cam != null and cam.global_position.y < CIUFFI_CAM_MAX
	_ciuffi.visible = acceso
	if not acceso:
		return
	var avanti := -cam.global_basis.z
	var piatto := Vector2(avanti.x, avanti.z)
	piatto = piatto.normalized() if piatto.length() > 0.01 else Vector2.ZERO
	var centro := Vector2(cam.global_position.x, cam.global_position.z) + piatto * CIUFFI_LATO * CIUFFI_AVANTI
	_ciuffi.global_position = Vector3(centro.x, global_position.y, centro.y)
	_passa_righe(Vector2(centro.x, -centro.y))


# pezzi di riga sotto i ciuffi allo shader (solo quando cambiano): lì i fili sono bianchi
func _passa_righe(centro_gioco: Vector2) -> void:
	var scelti := righe_vicine(_righe_ciuffi, centro_gioco, CIUFFI_LATO, CIUFFI_RIGHE_MAX)
	if scelti == _righe_scelte:
		return
	_righe_scelte = scelti
	var va: Array[Vector4] = []
	var vb: Array[Vector4] = []
	for k in CIUFFI_RIGHE_MAX:
		var i := scelti[k] if k < scelti.size() else -1
		va.append(_righe_ciuffi[i].a if i >= 0 else Vector4.ZERO)
		vb.append(_righe_ciuffi[i].b if i >= 0 else Vector4.ZERO)
	_mat_ciuffi.set_shader_parameter("righe_a", va)
	_mat_ciuffi.set_shader_parameter("righe_b", vb)
	_mat_ciuffi.set_shader_parameter("righe_n", scelti.size())


## ciuffi d'erba in rilievo accesi o spenti (la vista li tiene solo a qualità alta)
func set_ciuffi_3d(on: bool) -> void:
	_ciuffi_on = on


# stesso parametro all'erba e ai ciuffi in rilievo (colore, taglio, meteo e texture devono essere uguali)
func _param(nome: String, valore: Variant) -> void:
	_mat_erba.set_shader_parameter(nome, valore)
	_mat_ciuffi.set_shader_parameter(nome, valore)


# righe bianche: una mesh sola (poche migliaia di vertici), un materiale solo
func _costruisci_righe() -> void:
	var righe := MeshInstance3D.new()
	righe.name = "Righe"
	righe.mesh = RigheCampo.mesh()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RIGHE
	righe.material_override = mat
	righe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# lo shader allarga le righe lontane: la scatola per il taglio fuori schermo deve tenerne conto
	righe.extra_cull_margin = 1.0
	add_child(righe)


## taglio dell'erba (indice di Tagli.NOMI); con --campo=<nome> resta quello della riga di comando
func set_taglio(i: int) -> void:
	_taglio = clampi(i, 0, Tagli.NOMI.size() - 1)
	if _mat_erba != null:
		_param("taglio", taglio())


## manto dell'erba (indice di Tagli.MANTI: colore e tipo d'erba); con --manto=<nome> resta quello della riga di comando
func set_manto(i: int) -> void:
	_manto = clampi(i, 0, Tagli.MANTI.size() - 1)
	if _mat_erba == null:
		return
	var c := Tagli.colori_manto(manto())
	_param("chiara", c[0])
	_param("scura", c[1])
	_param("chiara_bordo", c[2])
	_param("scura_bordo", c[3])


## meteo sull'erba (scripts/partita/meteo.gd): bagnato 0..1 (pioggia: più scura e lucida), neve 0..1 (chiazze bianche)
func set_meteo(bagnato: float, neve: float) -> void:
	if _mat_erba == null:
		return
	_param("bagnato", clampf(bagnato, 0.0, 1.0))
	_param("neve", clampf(neve, 0.0, 1.0))


## notte: quanto si scurisce l'erba fuori dalle linee (0 = niente; uniform buio_fuori di shaders/erba_comune.gdshaderinc)
func set_notte(k: float) -> void:
	if _mat_erba == null:
		return
	_param("buio_fuori", clampf(k, 0.0, 1.0))


func manto() -> int:
	return _manto_forzato if _manto_forzato >= 0 else _manto


## taglio in uso
func taglio() -> int:
	return _taglio_forzato if _taglio_forzato >= 0 else _taglio


# grana fitta per i ciuffi d'erba (rumore fine, senza giunture)
func _texture_ciuffi() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	noise.seed = 4321
	var img := noise.get_seamless_image(GRANA_LATO, GRANA_LATO)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


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
