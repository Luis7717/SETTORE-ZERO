# Stadio semplice attorno al campo: cartelloni a bordo campo, quattro tribune inclinate con un pubblico dipinto
# (texture: il pubblico 3D vero arriverà in una fase successiva), tetti sulle tribune lunghe, quattro torri faro.
# Il cielo e la luce stanno nella scena (WorldEnvironment e DirectionalLight3D di scenes/prova_campo.tscn).
extends Node3D

const Coord := preload("res://scripts/coord.gd")

const CARTELLONI_X := 5.0        # distanza dei cartelloni dalle linee laterali (m)
const CARTELLONI_Y := 5.5        # ... e dalle linee di porta (dietro la rete, profonda 2 m)
const CARTELLONE_H := 0.9        # altezza (m)
const CARTELLONE_LUNGO := 6.0    # lunghezza di un pannello (m)
const TRIBUNA_DX := 8.0          # inizio delle tribune lunghe oltre la linea laterale (m)
const TRIBUNA_DY := 9.0          # inizio delle tribune dietro le porte (m)
const TRIBUNA_FONDA := 24.0      # profondità di una tribuna (m)
const TRIBUNA_H := 19.0          # altezza dell'ultima fila (m)
const MURETTO_H := 1.6           # muretto davanti alla prima fila (m)
const FILA := 0.85               # profondità di una fila lungo la pendenza (m)
const POSTO := 0.5               # larghezza di un posto (m)
const TETTO_H := 4.0             # tetto: quanto sta sopra l'ultima fila (m)
const TETTO_FONDO := 14.0        # tetto: quanto copre la tribuna dall'alto (m)
const FARO_H := 38.0             # torri faro (m)
# colori dei cartelloni (sponsor inventati: solo blocchi di colore per ora)
const SPONSOR := [Color("#1d4ed8"), Color("#f59e0b"), Color("#dc2626"), Color("#16a34a"), Color("#f8fafc"), Color("#7c3aed"), Color("#0f172a")]
# colori del pubblico (maglie delle due squadre, neutri, posti vuoti)
const PUBBLICO := [Color("#c8102e"), Color("#c8102e"), Color("#f2f2f2"), Color("#1746a2"), Color("#1746a2"),
	Color("#2b2b2b"), Color("#555b66"), Color("#d9c7a0"), Color("#8a5a2b"), Color("#eab308")]
const SEDILE := Color("#2c3e63")

var _rng := RandomNumberGenerator.new()
var _rip_pubblico := Vector2.ONE   # metri coperti da una ripetizione della texture del pubblico (u, v)


func _ready() -> void:
	_rng.seed = 20261120
	_cartelloni()
	var mat_tribuna := _materiale_pubblico()
	var mat_muro := _materiale_semplice(Color("#3b4252"))
	var mat_tetto := _materiale_semplice(Color("#d6d9de"))
	# tribune lunghe (lati x = ±): coprono anche gli angoli
	for s in [1.0, -1.0]:
		var x0: float = s * (Coord.HW + TRIBUNA_DX)
		var x1: float = s * (Coord.HW + TRIBUNA_DX + TRIBUNA_FONDA)
		var y_est := Coord.HL + TRIBUNA_DY + TRIBUNA_FONDA
		_tribuna_lato(x0, x1, -y_est, y_est, mat_tribuna, mat_muro)
		_tetto_lato(s, y_est, mat_tetto)
	# tribune dietro le porte (lati y = ±)
	for s in [1.0, -1.0]:
		var y0: float = s * (Coord.HL + TRIBUNA_DY)
		var y1: float = s * (Coord.HL + TRIBUNA_DY + TRIBUNA_FONDA)
		var x_est := Coord.HW + TRIBUNA_DX
		_tribuna_fondo(y0, y1, -x_est, x_est, mat_tribuna, mat_muro)
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			_faro(sx, sy)


func _materiale_semplice(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ---------------------------------------------------------------- cartelloni
func _cartelloni() -> void:
	var nodo := Node3D.new()
	nodo.name = "Cartelloni"
	add_child(nodo)
	var mats := []
	for c: Color in SPONSOR:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6
		m.emission_enabled = true          # i led dei cartelloni: un filo di luce propria
		m.emission = c
		m.emission_energy_multiplier = 0.25
		mats.append(m)
	var cx := Coord.HW + CARTELLONI_X
	var cy := Coord.HL + CARTELLONI_Y
	var i := 0
	# lati lunghi
	for s in [1.0, -1.0]:
		var y := -cy
		while y < cy - 0.01:
			var lungo := minf(CARTELLONE_LUNGO, cy - y)
			_pannello(nodo, Vector3(s * cx, CARTELLONE_H / 2.0, -(y + lungo / 2.0)), Vector3(0.12, CARTELLONE_H, lungo), mats[i % mats.size()])
			y += lungo
			i += 1
	# dietro le porte
	for s in [1.0, -1.0]:
		var x := -cx
		while x < cx - 0.01:
			var lungo := minf(CARTELLONE_LUNGO, cx - x)
			_pannello(nodo, Vector3(x + lungo / 2.0, CARTELLONE_H / 2.0, -s * cy), Vector3(lungo, CARTELLONE_H, 0.12), mats[i % mats.size()])
			x += lungo
			i += 1


func _pannello(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ---------------------------------------------------------------- tribune
# texture ripetuta del pubblico: ogni spettatore è una macchia di colore (maglia) con la testa sopra
func _materiale_pubblico() -> StandardMaterial3D:
	var posti := 64
	var file := 16
	var pp := 4                       # pixel per posto (larghezza) e per fila (altezza)
	var img := Image.create(posti * pp, file * pp, false, Image.FORMAT_RGB8)
	img.fill(Color("#1f2633"))
	var pelle := [Color("#f1c9a5"), Color("#d9a47a"), Color("#a9744f"), Color("#6b4630")]
	for f in file:
		for p in posti:
			var x := p * pp
			var y := f * pp
			img.fill_rect(Rect2i(x, y + pp - 1, pp, 1), SEDILE.darkened(0.3))
			if _rng.randf() < 0.12:     # posto vuoto
				img.fill_rect(Rect2i(x, y + 1, pp - 1, pp - 2), SEDILE)
				continue
			var maglia: Color = PUBBLICO[_rng.randi() % PUBBLICO.size()]
			maglia = maglia.darkened(_rng.randf() * 0.25)
			img.fill_rect(Rect2i(x, y + 2, pp - 1, pp - 3), maglia)
			img.fill_rect(Rect2i(x + 1, y, pp - 2, 2), pelle[_rng.randi() % pelle.size()])
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# UV in "ripetizioni": u lungo la tribuna, v lungo la pendenza (vedi _rampa)
	_rip_pubblico = Vector2(posti * POSTO, file * FILA)
	return m


# rampa inclinata: bordo basso a0-b0 (all'altezza del muretto), bordo alto a1-b1 (all'ultima fila); punti in Godot
func _rampa(nome: String, a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3, mat: StandardMaterial3D) -> void:
	var rip := _rip_pubblico
	var lungo := a0.distance_to(b0)
	var pendenza := a0.distance_to(a1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [a0, b0, b1, a1]
	var uvs := [Vector2(0, pendenza / rip.y), Vector2(lungo / rip.x, pendenza / rip.y), Vector2(lungo / rip.x, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# parete verticale (muretto, retro) tra i punti a e b (Godot, a terra) alta h
func _parete(a: Vector3, b: Vector3, h0: float, h1: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [a + Vector3(0, h0, 0), b + Vector3(0, h0, 0), b + Vector3(0, h1, 0), a + Vector3(0, h1, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(pts[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _tribuna_lato(x0: float, x1: float, ya: float, yb: float, mat: StandardMaterial3D, muro: Material) -> void:
	var a0 := Coord.a_godot(x0, ya, MURETTO_H)
	var b0 := Coord.a_godot(x0, yb, MURETTO_H)
	var a1 := Coord.a_godot(x1, ya, TRIBUNA_H)
	var b1 := Coord.a_godot(x1, yb, TRIBUNA_H)
	_rampa("TribunaLato", a0, b0, a1, b1, mat)
	_parete(Coord.a_godot(x0, ya), Coord.a_godot(x0, yb), 0.0, MURETTO_H, muro)
	_parete(Coord.a_godot(x1, ya), Coord.a_godot(x1, yb), 0.0, TRIBUNA_H + 1.2, muro)


func _tribuna_fondo(y0: float, y1: float, xa: float, xb: float, mat: StandardMaterial3D, muro: Material) -> void:
	var a0 := Coord.a_godot(xa, y0, MURETTO_H)
	var b0 := Coord.a_godot(xb, y0, MURETTO_H)
	var a1 := Coord.a_godot(xa, y1, TRIBUNA_H)
	var b1 := Coord.a_godot(xb, y1, TRIBUNA_H)
	_rampa("TribunaFondo", a0, b0, a1, b1, mat)
	_parete(Coord.a_godot(xa, y0), Coord.a_godot(xb, y0), 0.0, MURETTO_H, muro)
	_parete(Coord.a_godot(xa, y1), Coord.a_godot(xb, y1), 0.0, TRIBUNA_H + 1.2, muro)


func _tetto_lato(s: float, y_est: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Tetto"
	var b := BoxMesh.new()
	b.size = Vector3(TETTO_FONDO, 0.5, y_est * 2.0)
	mi.mesh = b
	mi.material_override = mat
	var x_fondo := Coord.HW + TRIBUNA_DX + TRIBUNA_FONDA
	mi.position = Vector3(s * (x_fondo - TETTO_FONDO / 2.0 + 1.0), TRIBUNA_H + TETTO_H, 0.0)
	mi.rotation.z = s * deg_to_rad(-4.0)   # leggermente inclinato verso il campo
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- torri faro negli angoli
func _faro(sx: float, sy: float) -> void:
	var x: float = sx * (Coord.HW + TRIBUNA_DX + TRIBUNA_FONDA * 0.55)
	var y: float = sy * (Coord.HL + TRIBUNA_DY + TRIBUNA_FONDA * 0.55)
	var torre := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.9
	c.height = FARO_H
	c.radial_segments = 8
	torre.mesh = c
	torre.material_override = _materiale_semplice(Color("#9aa3ad"))
	torre.position = Coord.a_godot(x, y, FARO_H / 2.0)
	torre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(torre)
	var lampade := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(7.0, 3.5, 0.6)
	lampade.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#f8fafc")
	m.emission_enabled = true
	m.emission = Color("#fff6d8")
	m.emission_energy_multiplier = 2.0
	lampade.material_override = m
	lampade.position = Coord.a_godot(x, y, FARO_H + 1.5)
	lampade.rotation.y = Coord.yaw_verso(-x, -y)   # rivolte verso il centro del campo
	lampade.rotation.x = deg_to_rad(-25.0)
	lampade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lampade)
