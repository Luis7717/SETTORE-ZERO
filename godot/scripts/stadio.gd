# Stadio attorno al campo: cartelloni a led con sponsor inventati (scripts/stadio/cartelloni.gd), quattro tribune
# inclinate col pubblico 3D animato (scripts/stadio/pubblico.gd; sotto, i seggiolini; senza pubblico 3D torna il
# pubblico dipinto), tettoie con le travi sulle tribune lunghe, maxischermi col risultato dietro le porte
# (scripts/stadio/maxischermo.gd), quattro torri faro con le lampade accese. Tutto disegnato a codice, originale.
# Il cielo e la luce stanno nella scena (WorldEnvironment e DirectionalLight3D).
#
# Per la vista della partita: squadre(nomi, colori), punteggio(a, b, gol), tifo(tipo, squadra), aggiorna(dt),
# set_pubblico(densità 0..1).
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const Pubblico := preload("res://scripts/stadio/pubblico.gd")
const Cartelloni := preload("res://scripts/stadio/cartelloni.gd")
const Maxischermo := preload("res://scripts/stadio/maxischermo.gd")

const CARTELLONI_X := 5.0        # distanza dei cartelloni dalle linee laterali (m)
const CARTELLONI_Y := 5.5        # ... e dalle linee di porta (dietro la rete, profonda 2 m)
const TRIBUNA_DX := 8.0          # inizio delle tribune lunghe oltre la linea laterale (m)
const TRIBUNA_DY := 18.0         # inizio delle tribune dietro le porte (m): come il web, lascia posto alla telecamera della parata
const TRIBUNA_FONDA := 24.0      # profondità di una tribuna (m)
const TRIBUNA_H := 19.0          # altezza dell'ultima fila (m)
const MURETTO_H := 1.6           # muretto davanti alla prima fila (m)
const FILA := 0.85               # profondità di una fila lungo la pendenza (m)
const POSTO := 0.5               # larghezza di un posto (m)
const TETTO_H := 4.0             # tetto: quanto sta sopra l'ultima fila (m)
const TETTO_FONDO := 14.0        # tetto: quanto copre la tribuna dall'alto (m)
const TETTO_PENDENZA := 4.0      # gradi: il tetto sale un po' verso il campo
const FARO_H := 38.0             # torri faro (m)
const TRAVE_OGNI := 12.0         # una trave della tettoia ogni tanti metri
const SCHERMO_LARGO := 15.0      # maxischermo (m)
# colori del pubblico dipinto (maglie delle due squadre, neutri, posti vuoti)
const PUBBLICO := [Color("#c8102e"), Color("#c8102e"), Color("#f2f2f2"), Color("#1746a2"), Color("#1746a2"),
	Color("#2b2b2b"), Color("#555b66"), Color("#d9c7a0"), Color("#8a5a2b"), Color("#eab308")]
const SEDILE := Color("#2c3e63")

var _rng := RandomNumberGenerator.new()
var _rip_pubblico := Vector2.ONE   # metri coperti da una ripetizione della texture del pubblico (u, v)
var _mat_dipinto: StandardMaterial3D   # tribuna col pubblico dipinto (senza pubblico 3D)
var _mat_sedili: StandardMaterial3D    # tribuna coi soli seggiolini (sotto il pubblico 3D)
var _mat_lampade: StandardMaterial3D
var _rampe: Array[MeshInstance3D] = []
var _tribune: Array = []               # per il pubblico 3D: {a0, b0, a1, b1, tipo, tetto}
var pubblico: Node3D
var cartelloni: Node3D
var maxischermo: Node3D


func _ready() -> void:
	_rng.seed = 20261120
	var mat_muro := _materiale_semplice(Color("#3b4252"))
	var mat_tetto := _materiale_semplice(Color("#d6d9de"))
	var mat_ferro := _materiale_semplice(Color("#5d6672"))
	cartelloni = Cartelloni.new()
	add_child(cartelloni)
	_cartelloni(mat_muro)
	_mat_dipinto = _materiale_pubblico(false)
	_mat_sedili = _materiale_pubblico(true)
	# tribune lunghe (lati x = ±): coprono anche gli angoli
	for s: float in [1.0, -1.0]:
		var x0: float = s * (Coord.HW + TRIBUNA_DX)
		var x1: float = s * (Coord.HW + TRIBUNA_DX + TRIBUNA_FONDA)
		var y_est := Coord.HL + TRIBUNA_DY + TRIBUNA_FONDA
		_tribuna_lato(x0, x1, -y_est, y_est, _mat_sedili, mat_muro)
		_tetto_lato(s, y_est, mat_tetto, mat_ferro)
	# tribune dietro le porte (lati y = ±): curva di casa dietro la porta della squadra 0 (y < 0), ospiti dall'altra
	for s: float in [1.0, -1.0]:
		var y0: float = s * (Coord.HL + TRIBUNA_DY)
		var y1: float = s * (Coord.HL + TRIBUNA_DY + TRIBUNA_FONDA)
		var x_est := Coord.HW + TRIBUNA_DX
		_tribuna_fondo(y0, y1, -x_est, x_est, _mat_sedili, mat_muro, "ospiti" if s > 0.0 else "curva")
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			_faro(sx, sy)
	pubblico = Pubblico.new()
	add_child(pubblico)
	pubblico.costruisci(_tribune)
	maxischermo = Maxischermo.new()
	add_child(maxischermo)
	for s: float in [1.0, -1.0]:
		var y_s: float = s * (Coord.HL + TRIBUNA_DY + TRIBUNA_FONDA - 2.0)
		maxischermo.schermo(Coord.a_godot(0.0, y_s, TRIBUNA_H + 8.5), 0.0 if s > 0.0 else PI, SCHERMO_LARGO, mat_muro)


## nomi delle squadre e colori [maglia, secondo colore] di casa e ospiti: maxischermi e maglie dei tifosi
func squadre(nomi: Array, colori: Array) -> void:
	maxischermo.squadre(nomi, colori)
	pubblico.imposta_colori(colori[0], colori[1])


func punteggio(a: int, b: int, gol: bool) -> void:
	maxischermo.punteggio(a, b, gol)


## reazione del pubblico (vedi scripts/stadio/pubblico.gd): tipo "gol", "occasione", "parata", "palo", "fischio"
func tifo(tipo: String, squadra: int) -> void:
	pubblico.tifo(tipo, squadra)


## a ogni fotogramma, col tempo vero (folla e cartelloni non vanno al rallentatore)
func aggiorna(dt: float) -> void:
	pubblico.aggiorna(dt)
	cartelloni.aggiorna(dt)


## quanto pubblico 3D (0..1). A 0 sparisce e le tribune tornano col pubblico dipinto
func set_pubblico(k: float) -> void:
	pubblico.set_densita(k)
	var mat := _mat_sedili if k > 0.0 else _mat_dipinto
	for r in _rampe:
		r.material_override = mat


func _materiale_semplice(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ---------------------------------------------------------------- cartelloni
# quattro linee a led attorno al campo; le grafiche continuano da una linea all'altra (u in metri)
func _cartelloni(telaio: Material) -> void:
	var cx := Coord.HW + CARTELLONI_X
	var cy := Coord.HL + CARTELLONI_Y
	var giro := 0.0
	for s: float in [1.0, -1.0]:
		cartelloni.linea(Coord.a_godot(s * cx, -s * cy), Coord.a_godot(s * cx, s * cy), Vector3(-s, 0, 0), giro, telaio)
		giro += cy * 2.0
		cartelloni.linea(Coord.a_godot(s * cx, s * cy), Coord.a_godot(-s * cx, s * cy), Vector3(0, 0, s), giro, telaio)
		giro += cx * 2.0


# ---------------------------------------------------------------- tribune
# texture ripetuta del pubblico: ogni spettatore è una macchia di colore (maglia) con la testa sopra;
# solo_sedili = file di seggiolini vuoti (sotto il pubblico 3D)
func _materiale_pubblico(solo_sedili: bool) -> StandardMaterial3D:
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
			if solo_sedili or _rng.randf() < 0.12:     # posto vuoto
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
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_rampe.append(mi)


# parete verticale (muretto, retro) tra i punti a e b (Godot, a terra) alta h
func _parete(a: Vector3, b: Vector3, h0: float, h1: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [a + Vector3(0, h0, 0), b + Vector3(0, h0, 0), b + Vector3(0, h1, 0), a + Vector3(0, h1, 0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
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
	_tribune.append({"a0": a0, "b0": b0, "a1": a1, "b1": b1, "tipo": "lato", "tetto": (TETTO_FONDO - 1.0) / TRIBUNA_FONDA})
	_parete(Coord.a_godot(x0, ya), Coord.a_godot(x0, yb), 0.0, MURETTO_H, muro)
	_parete(Coord.a_godot(x1, ya), Coord.a_godot(x1, yb), 0.0, TRIBUNA_H + 1.2, muro)


func _tribuna_fondo(y0: float, y1: float, xa: float, xb: float, mat: StandardMaterial3D, muro: Material, tipo: String) -> void:
	var a0 := Coord.a_godot(xa, y0, MURETTO_H)
	var b0 := Coord.a_godot(xb, y0, MURETTO_H)
	var a1 := Coord.a_godot(xa, y1, TRIBUNA_H)
	var b1 := Coord.a_godot(xb, y1, TRIBUNA_H)
	_rampa("TribunaFondo", a0, b0, a1, b1, mat)
	_tribune.append({"a0": a0, "b0": b0, "a1": a1, "b1": b1, "tipo": tipo, "tetto": 0.0})
	_parete(Coord.a_godot(xa, y0), Coord.a_godot(xb, y0), 0.0, MURETTO_H, muro)
	_parete(Coord.a_godot(xa, y1), Coord.a_godot(xb, y1), 0.0, TRIBUNA_H + 1.2, muro)


# ---------------------------------------------------------------- tettoie
# tettoia a sbalzo: lastra leggermente inclinata, trave di bordo con una fila di lampade, travi a sbalzo ogni
# TRAVE_OGNI metri appoggiate a colonne dietro l'ultima fila
func _tetto_lato(s: float, y_est: float, mat: Material, ferro: Material) -> void:
	var x_fondo := Coord.HW + TRIBUNA_DX + TRIBUNA_FONDA
	var x_bordo := x_fondo - TETTO_FONDO + 1.0
	var h_fondo := TRIBUNA_H + TETTO_H
	var h_bordo := h_fondo + TETTO_FONDO * tan(deg_to_rad(TETTO_PENDENZA))
	var nodo := Node3D.new()
	nodo.name = "Tettoia"
	add_child(nodo)
	var lastra := _box(nodo, Vector3(TETTO_FONDO, 0.3, y_est * 2.0), Vector3(s * (x_fondo + x_bordo) * 0.5, (h_fondo + h_bordo) * 0.5, 0.0), mat)
	lastra.rotation.z = s * deg_to_rad(-TETTO_PENDENZA)
	_box(nodo, Vector3(0.7, 1.1, y_est * 2.0), Vector3(s * x_bordo, h_bordo - 0.35, 0.0), ferro)
	# fila di lampade sotto la trave di bordo
	var luci := StandardMaterial3D.new()
	luci.albedo_color = Color("#fffbe8")
	luci.emission_enabled = true
	luci.emission = Color("#fff3c4")
	luci.emission_energy_multiplier = 2.2
	_box(nodo, Vector3(0.25, 0.12, y_est * 2.0 - 2.0), Vector3(s * (x_bordo - 0.2), h_bordo - 0.95, 0.0), luci)
	var y := -y_est + 2.0
	while y <= y_est - 1.9:
		var z := -y
		var piede := Vector3(s * (x_fondo + 0.6), 0.0, z)
		var cima := Vector3(s * (x_fondo + 0.6), h_fondo + 0.2, z)
		_trave(nodo, piede, cima, 0.32, ferro)
		_trave(nodo, cima, Vector3(s * x_bordo, h_bordo - 0.2, z), 0.28, ferro)
		_trave(nodo, Vector3(s * (x_fondo + 0.6), h_fondo - 4.5, z), Vector3(s * (x_bordo + 3.5), h_bordo - 0.25, z), 0.16, ferro)
		y += TRAVE_OGNI


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# trave a sezione quadrata da a a b (Godot)
func _trave(parent: Node3D, a: Vector3, b: Vector3, lato: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lato, a.distance_to(b), lato)
	mi.mesh = bm
	mi.material_override = mat
	var asse := (b - a).normalized()
	var x := asse.cross(Vector3.FORWARD if absf(asse.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, asse, x.cross(asse)), (a + b) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ---------------------------------------------------------------- torri faro negli angoli
func _faro(sx: float, sy: float) -> void:
	var x: float = sx * (Coord.HW + TRIBUNA_DX + TRIBUNA_FONDA * 0.55)
	var y: float = sy * (Coord.HL + TRIBUNA_DY + TRIBUNA_FONDA * 0.55)
	var torre := MeshInstance3D.new()
	torre.name = "Faro"
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
	lampade.name = "FaroLampade"
	var b := BoxMesh.new()
	b.size = Vector3(7.0, 3.5, 0.6)
	lampade.mesh = b
	lampade.material_override = _materiale_lampade()
	lampade.position = Coord.a_godot(x, y, FARO_H + 1.5)
	lampade.rotation.y = Coord.yaw_verso(-x, -y)   # rivolte verso il centro del campo
	lampade.rotation.x = deg_to_rad(-25.0)
	lampade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lampade)


# pannello delle lampade: 8 × 4 fari tondi accesi su una griglia scura (col bagliore si accendono)
func _materiale_lampade() -> StandardMaterial3D:
	if _mat_lampade != null:
		return _mat_lampade
	var img := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color("#2a2f36"))
	for j in 4:
		for i in 8:
			var c := Vector2(i * 16 + 8, j * 16 + 8)
			for y in range(j * 16, j * 16 + 16):
				for x in range(i * 16, i * 16 + 16):
					var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / 6.5
					if d < 1.0:
						img.set_pixel(x, y, Color(1.0, 0.97, 0.86).lerp(Color("#d9d4c0"), d * d))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_mat_lampade = StandardMaterial3D.new()
	_mat_lampade.albedo_texture = t
	_mat_lampade.emission_enabled = true
	_mat_lampade.emission_texture = t
	_mat_lampade.emission = Color.WHITE
	_mat_lampade.emission_energy_multiplier = 3.0
	return _mat_lampade
