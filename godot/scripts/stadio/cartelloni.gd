# Cartelloni a led a bordo campo con sponsor inventati (porting di src/stadium-ads.js): una texture 1024×1024 con 16
# righe (una per sponsor), ognuna con due grafiche da 512×64 (marchio e slogan), disegnata una volta sola da una
# SubViewport (testi col carattere di Godot) e poi copiata in una texture con le mipmap. shaders/led.gdshader sceglie
# lo sponsor: come negli stadi veri girano tutti insieme, ogni tanto a mosaico; il cambio scorre lungo la linea.
extends Node3D

const SHADER := preload("res://shaders/led.gdshader")

const AD_M := 7.6              # metri di cartellone per una grafica (512 × 64 px su ~0,9 m)
const U_PER_M := 0.5 / AD_M    # u per metro (una riga della texture contiene due grafiche)
const ALTO := 0.92             # altezza del cartellone (m)
const SPESSO := 0.14
const FERMO := 7.0             # secondi fermi e durata del cambio
const CAMBIO := 0.9
const W := 512
const H := 64
# [nome, slogan, colore, colore 2, icona] — tutti inventati (gli stessi del web)
const MARCHI := [
	["TIRO A GIRO", "IL CALCIO A UN DITO", "#0b3d91", "#ffd43b", "ball"],
	["CAFFÈ BORGO", "IL CAFFÈ DEL QUARTIERE", "#5a2f17", "#f2d1a0", "cup"],
	["GELATERIA STELLA", "GUSTO DA CAMPIONI", "#d6336c", "#fff0f6", "star"],
	["FORNO DEL CORSO", "PANE FRESCO OGNI GIORNO", "#c77700", "#fff4d6", "loaf"],
	["RADIO CURVA", "LA VOCE DELLO STADIO", "#5b2a86", "#e9d8ff", "waves"],
	["PIZZERIA DA NINO", "FORNO A LEGNA DAL 1987", "#b3122b", "#ffe8a3", "slice"],
	["OFFICINA ROSSI", "RIPARAZIONI IN GIORNATA", "#14606e", "#d3f2f7", "gear"],
	["PASTA MONTI", "TRAFILATA AL BRONZO", "#e0a100", "#1d2a6b", "peaks"],
	["BICI LAMPO", "PEDALA PIÙ VELOCE", "#0f7a55", "#d9ffef", "bolt"],
	["ACQUA LIMPIDELLA", "L'ACQUA DEI CAMPIONI", "#1d7fc4", "#e3f4ff", "drop"],
	["MOBILI GIRARDI", "CASA TUA, STILE TUO", "#7a4e2d", "#f5e6d3", "square"],
	["FERRAMENTA BRUNO", "TUTTO PER IL FAI DA TE", "#c44e00", "#ffffff", "gear"],
	["LATTERIA ALPINA", "LATTE DI MONTAGNA", "#2b7bb9", "#ffffff", "peaks"],
	["TAXI 777", "SEMPRE IN ORARIO", "#e5b800", "#111111", "check"],
	["CARTOLERIA LUNA", "QUADERNI E SOGNI", "#3a3f9e", "#ffe9a8", "moon"],
	["AUTO CORTI", "GUIDA SICURA", "#a11d1d", "#ffffff", "wheel"],
]

var _mat: ShaderMaterial
var _t := 0.0


func _init() -> void:
	name = "Cartelloni"
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("grafiche", _provvisoria())


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_disegna_grafiche()


## una linea di cartelloni da a a b (Godot, a terra), con la faccia verso `verso` (orizzontale, verso il campo);
## inizio = metri già percorsi dalla linea (le grafiche continuano da un pezzo all'altro)
func linea(a: Vector3, b: Vector3, verso: Vector3, inizio: float, telaio: Material) -> void:
	var lungo := a.distance_to(b)
	var dir := (b - a) / lungo
	var avanti := verso.normalized() * (SPESSO * 0.5 + 0.005)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := inizio * U_PER_M
	var u1 := (inizio + lungo) * U_PER_M
	# le scritte si leggono da sinistra a destra guardando dal campo: u cresce verso la destra di chi guarda
	if dir.dot((-verso).cross(Vector3.UP)) < 0.0:
		var x := u0
		u0 = u1
		u1 = x
	var p := [a + avanti + Vector3(0, 0.04, 0), b + avanti + Vector3(0, 0.04, 0), b + avanti + Vector3(0, ALTO - 0.04, 0), a + avanti + Vector3(0, ALTO - 0.04, 0)]
	var uv := [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)]
	# la faccia deve guardare verso il campo: ordine dei vertici secondo il verso
	var ord := [0, 1, 2, 0, 2, 3] if dir.cross(Vector3.UP).dot(verso) < 0.0 else [0, 2, 1, 0, 3, 2]
	st.set_normal(verso.normalized())
	for i: int in ord:
		st.set_uv(uv[i])
		st.add_vertex(p[i])
	var mi := MeshInstance3D.new()
	mi.name = "Led"
	mi.mesh = st.commit()
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# telaio scuro dietro i led
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lungo, ALTO, SPESSO)
	box.mesh = bm
	box.material_override = telaio
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box.transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), (a + b) * 0.5 + Vector3(0, ALTO * 0.5, 0))
	add_child(box)


## giro degli sponsor (tempo vero): il giro k mostra lo sponsor (5k mod 16); un giro su quattro è a mosaico
func aggiorna(dt: float) -> void:
	_t += dt
	var giro := FERMO + CAMBIO
	var k := int(_t / giro)
	var f := fmod(_t, giro) / CAMBIO
	var cambiando := k > 0 and f < 1.0
	var a := k - 1 if cambiando else k
	_mat.set_shader_parameter("riga_a", float((a * 5) % 16))
	_mat.set_shader_parameter("mosaico_a", 1.0 if a % 4 == 3 else 0.0)
	_mat.set_shader_parameter("riga_b", float((k * 5) % 16))
	_mat.set_shader_parameter("mosaico_b", 1.0 if k % 4 == 3 else 0.0)
	_mat.set_shader_parameter("cambio", f if cambiando else 0.0)


func set_forza(k: float) -> void:
	_mat.set_shader_parameter("forza", k)


# texture semplice (righe di colore) finché le grafiche vere non sono pronte, o senza schermo
func _provvisoria() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for r in 16:
		var m: Array = MARCHI[r]
		img.fill_rect(Rect2i(0, r * 4, 32, 4), Color(m[2]))
		img.fill_rect(Rect2i(32, r * 4, 32, 4), Color("#0c0f16"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _disegna_grafiche() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(W * 2, H * 16)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	var d := _Disegno.new()
	d.size = Vector2(vp.size)
	vp.add_child(d)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	_mat.set_shader_parameter("grafiche", ImageTexture.create_from_image(img))


# disegno delle 32 grafiche (drawAd del web)
class _Disegno:
	extends Control

	var _font: Font
	var _grasso: FontVariation

	func _init() -> void:
		_font = ThemeDB.fallback_font
		_grasso = FontVariation.new()
		_grasso.base_font = _font
		_grasso.variation_embolden = 0.9

	func _draw() -> void:
		for r in 16:
			_grafica(Vector2(0, r * H), MARCHI[r], 0)
			_grafica(Vector2(W, r * H), MARCHI[r], 1)

	func _grafica(o: Vector2, m: Array, variante: int) -> void:
		var c1 := Color(m[2])
		var c2 := Color(m[3])
		var fondo := c1 if variante == 0 else Color("#0c0f16")
		var testo := c2 if variante == 0 else (c1 if c1.get_luminance() > 0.45 else c1.lightened(0.35))
		# fondo con una sfumatura verticale (tre fasce)
		draw_rect(Rect2(o, Vector2(W, H)), fondo)
		draw_rect(Rect2(o, Vector2(W, H * 0.3)), fondo.lightened(0.12))
		draw_rect(Rect2(o + Vector2(0, H * 0.7), Vector2(W, H * 0.3)), fondo.darkened(0.25))
		if variante == 0:
			draw_colored_polygon(PackedVector2Array([o + Vector2(330, 0), o + Vector2(400, 0), o + Vector2(350, H), o + Vector2(280, H)]), Color(1, 1, 1, 0.08))
			_icona(m[4], o + Vector2(52, 33), 21.0, testo, fondo)
			_testo(m[0], o + Vector2(92, 35), 400.0, 40, testo, false)
		else:
			draw_rect(Rect2(o, Vector2(14, H)), c1)
			draw_rect(Rect2(o + Vector2(W - 14, 0), Vector2(14, H)), c1)
			_icona(m[4], o + Vector2(46, 33), 17.0, testo, fondo)
			_testo(m[1], o + Vector2(270, 25), 400.0, 22, Color.WHITE, true)
			_testo(m[0], o + Vector2(270, 48), 400.0, 16, testo, true)
		draw_rect(Rect2(o, Vector2(W, 2)), Color("#040507"))
		draw_rect(Rect2(o + Vector2(0, H - 2), Vector2(W, 2)), Color("#040507"))

	# testo centrato in verticale su y, ridotto finché non sta in larghezza
	func _testo(s: String, p: Vector2, larghezza: float, misura: int, col: Color, centro: bool) -> void:
		var fs := misura
		var w := _grasso.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while w > larghezza and fs > 8:
			fs -= 1
			w = _grasso.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var asc := _grasso.get_ascent(fs)
		var desc := _grasso.get_descent(fs)
		var x := p.x - w * 0.5 if centro else p.x
		draw_string(_grasso, Vector2(x, p.y + (asc - desc) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _stella(c: Vector2, n: int, ro: float, ri: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in n * 2:
			var a := k * PI / n - PI / 2.0
			pts.append(c + Vector2(cos(a), sin(a)) * (ri if k % 2 == 1 else ro))
		draw_colored_polygon(pts, col)

	func _icona(tipo: String, c: Vector2, r: float, col: Color, fondo: Color) -> void:
		match tipo:
			"ball":
				draw_circle(c + Vector2(r * 0.25, -r * 0.2), r * 0.55, col)
				draw_arc(c + Vector2(-r * 0.2, r * 0.4), r * 0.9, PI * 1.05, PI * 1.7, 12, col, r * 0.22)
			"cup":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.3), c + Vector2(r * 0.5, -r * 0.3), c + Vector2(r * 0.35, r * 0.7), c + Vector2(-r * 0.55, r * 0.7)]), col)
				draw_arc(c + Vector2(r * 0.55, r * 0.1), r * 0.28, -1.5, 1.5, 8, col, r * 0.2)
			"star":
				_stella(c, 5, r, r * 0.42, col)
			"loaf":
				_ellisse(c, Vector2(r, r * 0.55), col)
			"waves":
				draw_circle(c + Vector2(-r * 0.6, 0), r * 0.18, col)
				for k: float in [0.5, 0.9]:
					draw_arc(c + Vector2(-r * 0.6, 0), r * k * 1.2, -0.8, 0.8, 10, col, r * 0.2)
			"slice":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.6), c + Vector2(0, -r * 0.9), c + Vector2(r * 0.8, -r * 0.6)]), col)
			"gear":
				_stella(c, 8, r, r * 0.72, col)
				draw_circle(c, r * 0.3, fondo)
			"peaks":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.7), c + Vector2(-r * 0.3, -r * 0.6), c + Vector2(0.05 * r, 0), c + Vector2(r * 0.4, -r * 0.8), c + Vector2(r, r * 0.7)]), col)
			"bolt":
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.55, r * 0.15), c + Vector2(-r * 0.05, r * 0.15), c + Vector2(-r * 0.25, r), c + Vector2(r * 0.55, -r * 0.15), c + Vector2(r * 0.05, -r * 0.15)]), col)
			"drop":
				draw_circle(c + Vector2(0, r * 0.35), r * 0.6, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, r * 0.2), c + Vector2(-r * 0.55, r * 0.2)]), col)
			"square":
				draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.7), Vector2(r * 0.6, r * 0.6)), col)
				draw_rect(Rect2(c + Vector2(r * 0.1, -r * 0.7), Vector2(r * 0.6, r * 0.6)), col)
				draw_rect(Rect2(c + Vector2(-r * 0.7, r * 0.1), Vector2(r * 1.4, r * 0.6)), col)
			"check":
				for i in 3:
					for j in 3:
						if (i + j) % 2 == 0:
							draw_rect(Rect2(c + Vector2(-r + i * r * 0.66, -r + j * r * 0.66), Vector2(r * 0.66, r * 0.66)), col)
			"moon":
				draw_circle(c, r * 0.85, col)
				draw_circle(c + Vector2(r * 0.4, -r * 0.2), r * 0.7, fondo)
			_:
				draw_arc(c, r * 0.85, 0.0, TAU, 20, col, r * 0.22)
				draw_circle(c, r * 0.25, col)

	func _ellisse(c: Vector2, rr: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 24:
			var a := k * TAU / 24.0
			pts.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
		draw_colored_polygon(pts, col)
