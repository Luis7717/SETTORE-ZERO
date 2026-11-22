# Foto da vicino di pettinature e barbe, per controllarle a occhio (giocatore della partita, Figura, fermo in posa).
# Fogli: capelli_1..3.png (6 tagli per foglio: righe = tagli, colonne = di fronte, tre quarti, di lato, da dietro) e
# barbe_1..2.png (righe = barbe, colonne = di fronte, tre quarti, di lato, dal basso), più lontano.png (tutti i tagli
# da ~12 m, come in partita). Ogni riga ha una pelle e un colore di capelli diversi (si cambia con --giro=n).
# Uso (finestra vera, non --headless):
#   $G --path godot -s res://tests/foto_capelli.gd [-- --cartella=shots/capelli --giro=0 --tagli=10,11 --barbe=5,6]
# (--tagli / --barbe: solo quei tipi, foto grandi in un foglio dettaglio.png, niente fogli normali)
# --volti: solo volti.png (righe = combinazioni di taglio, barba, occhi e colori come nell'editor; di fronte molto
# vicino, tre quarti, di lato)
# --viso: fogli per sopracciglia, barbe e colletto (sopracciglia.png: righe = Caschetto e Rasato, colonne = i 6 tipi,
# di fronte molto vicino; barbe_viso.png: le 7 barbe, di fronte e tre quarti; colletto.png: girocollo, V, polo)
# Scrive CARTELLA/*.png (cartella relativa a quella che contiene godot/).
extends SceneTree

const Figura := preload("res://scripts/partita/figura.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Coord := preload("res://scripts/coord.gd")

var TILE := Vector2i(256, 256)
const PER_FOGLIO := 6
const DIST := 0.85          # m dalla testa (già scalata), inquadratura stretta
# viste: [angolo attorno alla testa (0 = di fronte), alzata della telecamera (m)]
const VISTE_CAPELLI := [[0.0, 0.08], [0.75, 0.12], [1.5708, 0.05], [3.1416, 0.12]]
const VISTE_BARBE := [[0.0, 0.0], [0.65, 0.0], [1.5708, -0.02], [0.35, -0.3]]
# coppie [pelle, colore dei capelli] (indici in Aspetto.SKINS / HAIR_COLORS), una per riga
# combinazioni per --volti: [taglio, barba, forma occhi, colore occhi, pelle, colore capelli, sopracciglia]
const VOLTI := [[9, 6, 3, 0, 6, 0, 4], [12, 0, 1, 4, 0, 5, 1], [2, 5, 2, 3, 3, 2, 0], [11, 2, 5, 1, 1, 7, 5], [7, 1, 0, 6, 4, 1, 2], [5, 4, 4, 5, 2, 9, 3]]
const VISTE_VOLTI := [[0.0, 0.03], [0.6, 0.03], [1.5708, 0.0]]
const COLORI := [[1, 0], [6, 0], [0, 5], [3, 2], [7, 1], [2, 7], [4, 9], [5, 3], [0, 6], [2, 8], [6, 10]]


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
var _vp: SubViewport
var _cam: Camera3D
var _fermo := Fermo.new()
var _ctx := {"t": 0.0, "phase": "menu", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}
var _giro := 0
var _dettaglio: Array = []   # [taglio, barba] da fotografare grandi
var _volti := false
var _viso := false


func _initialize() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var p := a.substr(2).split("=", true, 1)
			opz[p[0]] = p[1] if p.size() > 1 else "1"
	var cartella: String = opz.get("cartella", "shots/capelli")
	_giro = int(opz.get("giro", "0"))
	_volti = opz.has("volti")
	_viso = opz.has("viso")
	if opz.has("tagli") or opz.has("barbe"):
		TILE = Vector2i(480, 480)
		for x in String(opz.get("tagli", "")).split(",", false):
			_dettaglio.append([int(x), 0])
		for x in String(opz.get("barbe", "")).split(",", false):
			_dettaglio.append([2, int(x)])
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	# luci come l'anteprima dell'editor (anteprima_giocatore.gd)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2b3a55")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb2d6")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 1.5
	sole.shadow_enabled = true
	_vp.add_child(sole)
	sole.look_at_from_position(Vector3(2, 4, 3), Vector3.ZERO)
	var dietro := DirectionalLight3D.new()
	dietro.light_color = Color("#9ec5ff")
	dietro.light_energy = 0.7
	_vp.add_child(dietro)
	dietro.look_at_from_position(Vector3(-3, 2, -3), Vector3.ZERO)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.05
	_vp.add_child(_cam)
	_fig = Figura.new()
	_fig.scale = Vector3.ONE * Coord.SCALE
	_vp.add_child(_fig)
	var kit := {"maglia": Color("#1746a2"), "calzoncini": Color.WHITE, "calzettoni": Color("#1746a2"), "bordino": Color.WHITE,
		"stile": Asp.stile_figura(null), "numero": Vector4(0, 0, 0, 0)}
	_fig.prepara(kit, Asp.parametri_figura(null), 0.0, TV.avviso())
	_lavora.call_deferred(cartella)


func _aspetto(hair: int, beard: int, riga: int) -> void:
	var c: Array = COLORI[(riga + _giro) % COLORI.size()]
	var look := {"skin": c[0], "hairColor": c[1], "hair": hair, "beard": beard, "brows": 0}
	if hair < 0:   # riga di VOLTI
		var v: Array = VOLTI[beard]
		look = {"hair": v[0], "beard": v[1], "eyes": v[2], "eyeColor": v[3], "skin": v[4], "hairColor": v[5], "brows": v[6]}
	var asp := Asp.parametri_figura(look)
	if _fig.has_method("metti_aspetto"):
		_fig.metti_aspetto(asp)
	else:
		var mi: MeshInstance3D = _fig.get("_mesh")
		for k: String in asp:
			mi.set_instance_shader_parameter(k, asp[k])


# centro della testa (mondo) nella posa del momento
func _testa() -> Vector3:
	var sk: Skeleton3D = _fig.get("_scheletro")
	var b := sk.find_bone("Head")
	var t := sk.global_transform * sk.get_bone_global_pose(b)
	return t.origin + Vector3(0, 0.1 * Coord.SCALE, 0)


var _mira_y := 0.0   # m: si guarda più in basso del centro della testa (--viso)


func _scatta(vista: Array, dist: float) -> Image:
	var c := _testa() - Vector3(0, _mira_y, 0)
	var a: float = vista[0]
	# il giocatore guarda +Z (Figura: +Z locale = avanti)
	var o := Vector3(sin(a) * dist, vista[1], cos(a) * dist)
	_cam.look_at_from_position(c + o, c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _foglio(righe: Array, viste: Array, nome: String, dist: float) -> void:
	var foglio := Image.create(TILE.x * viste.size(), TILE.y * righe.size(), false, Image.FORMAT_RGBA8)
	for r in righe.size():
		var hb: Array = righe[r]
		_aspetto(hb[0], hb[1], r)
		for k in 3:   # qualche fotogramma perché la posa si assesti
			_fig.posa(_fermo, 1.0 / 30.0, _ctx)
			await process_frame
		for v in viste.size():
			var img: Image = await _scatta(viste[v], dist)
			foglio.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(v * TILE.x, r * TILE.y))
	foglio.save_png(nome)
	print("foto → ", nome)


func _lavora(cartella: String) -> void:
	var base := ProjectSettings.globalize_path("res://").path_join("..").path_join(cartella).simplify_path()
	DirAccess.make_dir_recursive_absolute(base)
	if _viso:
		await _fogli_viso(base)
		quit(0)
		return
	if _volti:
		TILE = Vector2i(360, 360)
		_vp.size = TILE
		var righe: Array = []
		for k in VOLTI.size():
			righe.append([-1, k])
		await _foglio(righe, VISTE_VOLTI, base.path_join("volti.png"), DIST * 0.55)
		quit(0)
		return
	if not _dettaglio.is_empty():
		await _foglio(_dettaglio, VISTE_CAPELLI, base.path_join("dettaglio.png"), DIST * 0.85)
		quit(0)
		return
	var n := Asp.HAIR_STYLES.size()
	var f := 1
	for da in range(0, n, PER_FOGLIO):
		var righe: Array = []
		for h in range(da, mini(da + PER_FOGLIO, n)):
			righe.append([h, 0])
		await _foglio(righe, VISTE_CAPELLI, base.path_join("capelli_%d.png" % f), DIST)
		f += 1
	# barbe: con un taglio corto, la barba 0 come confronto
	var barbe: Array = []
	for b in Asp.BEARDS.size():
		barbe.append([2, b])
	await _foglio(barbe.slice(0, 4), VISTE_BARBE, base.path_join("barbe_1.png"), DIST * 0.8)
	await _foglio(barbe.slice(4), VISTE_BARBE, base.path_join("barbe_2.png"), DIST * 0.8)
	# da lontano (~12 m, come la telecamera della partita): tutti i tagli, 4 per riga, tre quarti
	var lontano := Image.create(TILE.x * 6, TILE.y * 3, false, Image.FORMAT_RGBA8)
	_cam.fov = 4.0
	for h in n + 1:
		var beard := 6 if h == n else (5 if h % 4 == 1 else 0)
		_aspetto(h if h < n else 9, beard, h)
		for k in 3:
			_fig.posa(_fermo, 1.0 / 30.0, _ctx)
			await process_frame
		var img: Image = await _scatta([0.6, 5.0], 12.0)
		lontano.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((h % 6) * TILE.x, (h / 6) * TILE.y))
	lontano.save_png(base.path_join("lontano.png"))
	print("foto → ", base.path_join("lontano.png"))
	quit(0)


# --viso: un look completo (Dictionary del look) in una foto; colletto = stile della divisa (0, 1, 2)
func _foto_look(look: Dictionary, vista: Array, dist: float, colletto := 0) -> Image:
	var asp := Asp.parametri_figura(look)
	asp["stile"] = Asp.stile_figura({"collar": colletto})
	asp["bordino"] = Color(0.05, 0.05, 0.06)   # bordino scuro: si vedono meglio gli scalini
	_fig.metti_aspetto(asp)
	for k in 3:
		_fig.posa(_fermo, 1.0 / 30.0, _ctx)
		await process_frame
	return await _scatta(vista, dist)


func _fogli_viso(base: String) -> void:
	TILE = Vector2i(300, 300)
	_vp.size = TILE
	_mira_y = 0.035 * Coord.SCALE
	var f := Image.create(TILE.x * 6, TILE.y * 2, false, Image.FORMAT_RGBA8)
	for r in 2:
		for b in 6:
			var look := {"hair": [10, 1][r], "beard": 0, "eyes": 0, "eyeColor": 1, "skin": 1, "hairColor": 0, "brows": b}
			var img: Image = await _foto_look(look, [0.0, 0.0], DIST * 0.5)
			f.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(b * TILE.x, r * TILE.y))
	f.save_png(base.path_join("sopracciglia.png"))
	# occhi da vicino: le 6 forme
	var o := Image.create(TILE.x * 3, TILE.y * 2, false, Image.FORMAT_RGBA8)
	for e in 6:
		var look := {"hair": 2, "beard": 0, "eyes": e, "eyeColor": [1, 4, 3][e % 3], "skin": [1, 3, 6][e % 3], "hairColor": 0, "brows": 0}
		_mira_y = 0.025 * Coord.SCALE
		var img: Image = await _foto_look(look, [0.0, 0.0], DIST * 0.36)
		o.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((e % 3) * TILE.x, (e / 3) * TILE.y))
	o.save_png(base.path_join("occhi.png"))
	_mira_y = 0.035 * Coord.SCALE
	_mira_y = 0.085 * Coord.SCALE
	var g := Image.create(TILE.x * 7, TILE.y * 2, false, Image.FORMAT_RGBA8)
	for b in 7:
		for v in 2:
			var look := {"hair": 2, "beard": b, "eyes": 0, "eyeColor": 1, "skin": [1, 3][v], "hairColor": 0, "brows": 0}
			var img: Image = await _foto_look(look, [[0.0, -0.02], [0.6, -0.02]][v], DIST * 0.45)
			g.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(b * TILE.x, v * TILE.y))
	g.save_png(base.path_join("barbe_viso.png"))
	var h := Image.create(TILE.x * 3, TILE.y, false, Image.FORMAT_RGBA8)
	for c in 3:
		var look := {"hair": 2, "beard": 0, "eyes": 0, "eyeColor": 1, "skin": 1, "hairColor": 0, "brows": 0}
		_mira_y = 0.22 * Coord.SCALE
		var img: Image = await _foto_look(look, [0.25, 0.02], DIST * 0.6, c)
		h.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, 0))
	h.save_png(base.path_join("colletto.png"))
	# V da vicino, grande
	TILE = Vector2i(600, 600)
	_vp.size = TILE
	var look2 := {"hair": 2, "beard": 0, "eyes": 0, "eyeColor": 1, "skin": 1, "hairColor": 0, "brows": 0}
	_mira_y = 0.26 * Coord.SCALE
	var iv: Image = await _foto_look(look2, [0.0, 0.0], DIST * 0.45, 1)
	iv.save_png(base.path_join("colletto_v.png"))
	# tutte le barbe con pelli e colori dei capelli diversi (righe = combinazioni [pelle, capelli, taglio])
	TILE = Vector2i(220, 220)
	_vp.size = TILE
	_mira_y = 0.085 * Coord.SCALE
	var combo := [[0, 6, 2], [1, 5, 10], [3, 0, 1], [5, 1, 8], [7, 0, 2], [6, 10, 0], [2, 7, 11], [4, 9, 15]]
	var m := Image.create(TILE.x * 7, TILE.y * combo.size(), false, Image.FORMAT_RGBA8)
	var muti: Array = []
	for r in combo.size():
		var nessuna: Image = null
		for b in 7:
			var look := {"hair": combo[r][2], "beard": b, "eyes": 0, "eyeColor": 1, "skin": combo[r][0], "hairColor": combo[r][1], "brows": 0}
			var img: Image = await _foto_look(look, [0.3, -0.02], DIST * 0.5)
			m.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(b * TILE.x, r * TILE.y))
			if b == 0:
				nessuna = img
			elif _differenza(nessuna, img) < 0.004:
				muti.append("pelle %d capelli %d barba %d" % [combo[r][0], combo[r][1], b])
	m.save_png(base.path_join("barbe_combinazioni.png"))
	print("barbe che non cambiano il viso: ", muti)
	if not muti.is_empty():
		push_error("barbe invisibili: %s" % [muti])
	# colori nuovi: [pelle, taglio, colore capelli, barba, colore barba, colore occhi]
	TILE = Vector2i(260, 260)
	_vp.size = TILE
	_mira_y = 0.03 * Coord.SCALE
	var colori := [[1, 4, 13, 0, 0, 7], [3, 11, 14, 5, 2, 8], [0, 10, 15, 0, 0, 9], [5, 8, 16, 6, 0, 10], [2, 2, 17, 4, 1, 11],
		[6, 9, 18, 6, 6, 3], [1, 11, 19, 0, 0, 4], [4, 14, 20, 5, 3, 2], [0, 10, 21, 1, 4, 10], [7, 2, 11, 6, 5, 7]]
	var fc := Image.create(TILE.x * 5, TILE.y * 2, false, Image.FORMAT_RGBA8)
	for k in colori.size():
		var q: Array = colori[k]
		var look := {"skin": q[0], "hair": q[1], "hairColor": q[2], "beard": q[3], "beardColor": q[4], "eyeColor": q[5], "eyes": 0, "brows": 0}
		var img: Image = await _foto_look(look, [0.35, 0.04], DIST * 0.75)
		fc.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((k % 5) * TILE.x, (k / 5) * TILE.y))
	fc.save_png(base.path_join("colori.png"))
	print("foto viso → ", base)


# differenza media (0..1) tra due foto
func _differenza(a: Image, b: Image) -> float:
	var s := 0.0
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			s += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 1
	return s / (3.0 * n)
