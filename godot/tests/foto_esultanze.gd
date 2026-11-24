# Foto delle esultanze del campione (mosse/esultanza.gd) per controllarle a occhio: per ognuna un foglio con 6
# istanti (colonne) da due lati (riga 1 di tre quarti davanti, riga 2 di fianco), giocatore della partita su un prato.
# Uso (finestra vera, non --headless):
#   $G --path godot -s res://tests/foto_esultanze.gd [-- --cartella=shots/esultanze --solo=id1,id2 --istanti=0.8,1.0,...
#   --busto --zoom=2 --guarda=1.85]  (--busto: da vicino su braccia e mani, davanti e di fianco, anche se il giocatore
#   si è girato; --zoom: ancora più vicino; --guarda: altezza in m del punto guardato)
# (--istanti: secondi delle 6 foto, per guardare da vicino un tratto; senza, 6 istanti distribuiti su tutta l'esultanza)
# Scrive CARTELLA/<id>.png (cartella relativa a quella che contiene godot/).
extends SceneTree

const Figura := preload("res://scripts/partita/figura.gd")
const E := preload("res://scripts/partita/mosse/esultanza.gd")
const Esultanze := preload("res://scripts/partita/esultanze.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Coord := preload("res://scripts/coord.gd")

const TILE := Vector2i(300, 400)
const COLONNE := 6
const PASSO := 1.0 / 30.0
const VISTE := [Vector3(2.2, 1.5, 5.2), Vector3(5.6, 1.3, 0.0)]   # rispetto al giocatore (davanti = +Z)
## --busto: da vicino sul busto (braccia e mani), riga 1 davanti un po' di lato, riga 2 di fianco (lato destro)
const VISTE_BUSTO := [Vector3(0.5, 0.15, 2.3), Vector3(-2.3, 0.15, 0.25)]
const ALTEZZA_BUSTO := 1.6     # m veri: punto guardato da vicino (petto e testa)


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


var _fig: Node3D
var _istanti: Array = []
var _vps: Array[SubViewport] = []
var _cams: Array[Camera3D] = []
var _busto := false
var _altezza := ALTEZZA_BUSTO


func _initialize() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var p := a.substr(2).split("=", true, 1)
			opz[p[0]] = p[1] if p.size() > 1 else "1"
	var cartella: String = opz.get("cartella", "shots/esultanze")
	_busto = opz.has("busto") or opz.has("zoom")
	_altezza = float(opz.get("guarda", ALTEZZA_BUSTO))
	if opz.has("istanti"):
		for x in String(opz.istanti).split(","):
			_istanti.append(float(x))
	var solo: Array = Esultanze.ids() if not opz.has("solo") else Array(String(opz.solo).split(","))
	var mondo := Node3D.new()
	root.add_child(mondo)
	var w3 := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#22324f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb2d6")
	env.ambient_light_energy = 0.6
	w3.environment = env
	for v in VISTE.size():
		var vp := SubViewport.new()
		vp.size = TILE
		vp.world_3d = w3
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 40.0 / maxf(1.0, float(opz.get("zoom", "1")))
		vp.add_child(cam)
		_vps.append(vp)
		_cams.append(cam)
	var scena := Node3D.new()
	_vps[0].add_child(scena)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 1.4
	sole.shadow_enabled = true
	scena.add_child(sole)
	sole.look_at_from_position(Vector3(3, 6, 4), Vector3.ZERO)
	var prato := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	prato.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3d7a3a")
	prato.material_override = mat
	scena.add_child(prato)
	for i in 13: # righe ogni metro: si vede se un piede va sotto terra o scivola
		var riga := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(30, 0.004, 0.03)
		riga.mesh = bm
		riga.position = Vector3(0, 0.002, -6 + i)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(1, 1, 1, 0.6)
		riga.material_override = rm
		scena.add_child(riga)
	_fig = Figura.new()
	_fig.scale = Vector3.ONE * Coord.SCALE
	scena.add_child(_fig)
	var kit := {"maglia": Color("#1746a2"), "calzoncini": Color.WHITE, "calzettoni": Color("#1746a2"), "bordino": Color.WHITE,
		"stile": Asp.stile_figura(null), "numero": Vector4(0, 0, 0, 0)}
	_fig.prepara(kit, Asp.parametri_figura({"skin": 3, "hair": 4}), 0.0, TV.avviso())
	_giro.call_deferred(solo, cartella)


func _giro(ids: Array, cartella: String) -> void:
	var fermo := Fermo.new()
	var ctx := {"t": 0.0, "phase": "menu", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}
	var base := ProjectSettings.globalize_path("res://").path_join("..").path_join(cartella).simplify_path()
	DirAccess.make_dir_recursive_absolute(base)
	for id: String in ids:
		var tt := E.durata(id)
		var istanti: Array = []
		for k in COLONNE:
			istanti.append(tt * (k + 0.6) / COLONNE)
		if _istanti.size() == COLONNE:
			istanti = _istanti
		var foglio := Image.create(TILE.x * COLONNE, TILE.y * VISTE.size(), false, Image.FORMAT_RGBA8)
		var t := 0.0
		var col := 0
		while col < COLONNE:
			_fig.esultanza = E.posa(id, t)
			_fig.posa(fermo, PASSO, ctx)
			var c: Vector3 = _fig.corpo.to_global(Vector3(0, 0.9, 0))   # bacino (anche capovolto)
			c.y = _altezza if _busto else 1.0
			for v in VISTE.size():
				if _busto:
					# davanti al giocatore anche quando si è girato o spostato (verso del corpo)
					var b: Basis = _fig.corpo.global_transform.basis.orthonormalized()
					var fw := b * Vector3(0, 0, 1)
					fw.y = 0.0
					var yaw := atan2(fw.x, fw.z) if fw.length() > 0.1 else 0.0
					var ob: Vector3 = Basis(Vector3.UP, yaw) * (VISTE_BUSTO[v] as Vector3)
					_cams[v].look_at_from_position(c + ob, c)
					continue
				var o: Vector3 = VISTE[v]
				_cams[v].look_at_from_position(c + o - Vector3(0, 1.0, 0), c)
			if t >= istanti[col] - 1e-4:
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				for v in VISTE.size():
					var img := _vps[v].get_texture().get_image()
					img.convert(Image.FORMAT_RGBA8)
					foglio.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, v * TILE.y))
				col += 1
			else:
				await process_frame
			t += PASSO
		var nome := base.path_join(id + ".png")
		foglio.save_png(nome)
		print("esultanza %s (%.1f s) → %s" % [id, tt, nome])
	quit(0)
