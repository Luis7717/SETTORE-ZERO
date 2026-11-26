# Foto dei modelli dei giocatori per controllarli a occhio (proporzioni, divisa, viso, capelli): un foglio con una
# riga per giocatore (maniche corte aderente, corte larga, lunghe aderente, lunghe larga, portiere) e per colonna
# corpo intero di fronte, di fianco, da dietro, di tre quarti, e la testa di fronte, di tre quarti e di fianco.
# Uso (finestra vera, non --headless):
#   $G --path godot -s res://tools/foto_modelli.gd -- --file=CARTELLA/nome.png [--corsa=5] [--tagli=2,4,8,15,9]
#   [--solo=N] [--viste=0,1,2] [--tile=300x460]   (--corsa: velocità in m/s, 0 = fermo; --tagli: taglio dei capelli per riga)
extends SceneTree

const Figura := preload("res://scripts/partita/figura.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Coord := preload("res://scripts/coord.gd")

# [posizione della telecamera rispetto al punto guardato, altezza del punto guardato (m del modello), fov]
const VISTE := [
	[Vector3(0, 0.1, 5.2), 0.95, 30.0], [Vector3(5.2, 0.1, 0), 0.95, 30.0], [Vector3(0, 0.1, -5.2), 0.95, 30.0],
	[Vector3(3.4, 0.5, 3.9), 0.95, 30.0],
	[Vector3(0, 0.0, 2.6), 1.64, 13.0], [Vector3(1.7, 0.1, 2.0), 1.64, 13.0], [Vector3(2.6, 0.0, 0), 1.64, 13.0],
]
const RIGHE := [
	{"sleeves": 0, "fit": 0, "skin": 1, "maglia": "#c8102e", "pos": "A"},
	{"sleeves": 0, "fit": 1, "skin": 3, "maglia": "#1746a2", "pos": "A"},
	{"sleeves": 1, "fit": 0, "skin": 5, "maglia": "#f2f2f2", "pos": "D"},
	{"sleeves": 1, "fit": 1, "skin": 2, "maglia": "#1c8a4a", "pos": "D"},
	{"sleeves": 1, "fit": 1, "skin": 6, "maglia": "#f2d21b", "pos": "P"},
]


class Fermo:
	extends RefCounted
	var warn := false
	var vx := 0.0
	var vy := 0.0
	var fx := 0.0
	var fy := 1.0
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
	var palla := false
	var stato := ""


func _initialize() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var p := a.substr(2).split("=", true, 1)
			opz[p[0]] = p[1] if p.size() > 1 else "1"
	_giro.call_deferred(opz)


func _giro(opz: Dictionary) -> void:
	var tile := Vector2i(300, 460)
	if opz.has("tile"):
		var tt := String(opz.tile).split("x")
		tile = Vector2i(int(tt[0]), int(tt[1]))
	var tagli: Array = [2, 4, 8, 15, 9]
	if opz.has("tagli"):
		tagli = Array(String(opz.tagli).split(",")).map(func(x: String) -> int: return int(x))
	var corsa := float(opz.get("corsa", "0"))
	var vp := SubViewport.new()
	vp.size = tile
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#5d7fa8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8c6e0")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 1.3
	sole.shadow_enabled = true
	vp.add_child(sole)
	sole.look_at_from_position(Vector3(3, 6, 4), Vector3.ZERO)
	var prato := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	prato.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3d7a3a")
	prato.material_override = mat
	vp.add_child(prato)
	var righe: Array = range(RIGHE.size())
	if opz.has("solo"):
		righe = [int(opz.solo)]
	var viste: Array = range(VISTE.size())
	if opz.has("viste"):
		viste = Array(String(opz.viste).split(",")).map(func(x: String) -> int: return int(x))
	var foglio := Image.create(tile.x * viste.size(), tile.y * righe.size(), false, Image.FORMAT_RGBA8)
	var ctx := {"t": 0.0, "phase": "menu", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}
	var riga := 0
	for r: int in righe:
		var d: Dictionary = RIGHE[r]
		var fig := Figura.new()
		fig.scale = Vector3.ONE * Coord.SCALE
		vp.add_child(fig)
		var stile := {"fit": d.fit, "sleeves": d.sleeves, "collar": r % 3, "pattern": 0, "shorts": 0, "socks": 0}
		var kit := {"maglia": Color(d.maglia), "calzoncini": Color("#20242c"), "calzettoni": Color(d.maglia), "bordino": Color.WHITE,
			"stile": Asp.stile_figura(stile), "numero": Vector4(0, 0, 0, d.fit)}
		var look := {"skin": d.skin, "hair": int(tagli[r % tagli.size()]), "hairColor": r % 5, "eyes": r % 6, "beard": [0, 1, 0, 5, 0][r % 5], "brows": r % 6}
		fig.prepara(kit, Asp.parametri_figura(look, stile), 0.0, TV.avviso())
		var p := Fermo.new()
		p.pos = d.pos
		p.vy = corsa
		for k in 20:
			fig.posa(p, 1.0 / 30.0, ctx)
		for col in viste.size():
			var v: int = viste[col]
			var vv: Array = VISTE[v]
			var c := Vector3(0, float(vv[1]) * Coord.SCALE, 0)
			cam.fov = vv[2]
			cam.look_at_from_position(c + (vv[0] as Vector3), c)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			foglio.blit_rect(img, Rect2i(Vector2i.ZERO, tile), Vector2i(col * tile.x, riga * tile.y))
		riga += 1
		fig.free()
	var nome := String(opz.get("file", "shots/modelli.png"))
	if nome.is_relative_path():
		nome = ProjectSettings.globalize_path("res://").path_join("..").path_join(nome).simplify_path()
	DirAccess.make_dir_recursive_absolute(nome.get_base_dir())
	foglio.save_png(nome)
	print("modelli → ", nome)
	quit(0)
