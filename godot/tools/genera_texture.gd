# Genera le texture HD della partita (disegni originali del progetto, CC0 come tutto il resto):
#   assets/textures/pallone.png    1024×512  pallone a 32 spicchi (12 pentagoni neri, 20 esagoni bianchi) con le cuciture,
#                                  proiezione equirettangolare (come le UV di SphereMesh)
#   assets/textures/pallone_n.png  1024×512  rilievo delle cuciture (normal map)
#   assets/textures/erba_n.png     512×512   fili d'erba visti da vicino (normal map ripetibile senza giunte)
# Uso: $G --headless --path godot -s res://tools/genera_texture.gd   (qualche secondo; i file si importano dopo con --import)
extends SceneTree

const CARTELLA := "res://assets/textures/"
const PALLA_W := 1024
const PALLA_H := 512
const ERBA := 512
const PESO_PENTAGONO := 0.075   # rad: i pentagoni sono più piccoli degli esagoni (diagramma pesato)
const CUCITURA := 0.012         # rad: mezza larghezza di una cucitura


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARTELLA))
	_pallone()
	_erba()
	print("texture generate in ", CARTELLA)
	quit()


# ---------------------------------------------------------------- pallone
# centri degli spicchi: i 12 vertici dell'icosaedro (pentagoni) e i centri delle sue 20 facce (esagoni)
func _centri() -> Array:
	var f := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = []
	for a: float in [-1.0, 1.0]:
		for b: float in [-f, f]:
			v.append(Vector3(0, a, b).normalized())
			v.append(Vector3(a, b, 0).normalized())
			v.append(Vector3(b, 0, a).normalized())
	var facce: Array[Vector3] = []
	var minimo := INF
	for i in v.size():
		for j in range(i + 1, v.size()):
			minimo = minf(minimo, v[i].angle_to(v[j]))
	for i in v.size():
		for j in range(i + 1, v.size()):
			if absf(v[i].angle_to(v[j]) - minimo) > 1e-3:
				continue
			for k in range(j + 1, v.size()):
				if absf(v[i].angle_to(v[k]) - minimo) < 1e-3 and absf(v[j].angle_to(v[k]) - minimo) < 1e-3:
					facce.append((v[i] + v[j] + v[k]).normalized())
	return [v, facce]


func _pallone() -> void:
	var c := _centri()
	var pent: Array[Vector3] = c[0]
	var esa: Array[Vector3] = c[1]
	var img := Image.create(PALLA_W, PALLA_H, false, Image.FORMAT_RGB8)
	var alt := PackedFloat32Array()
	alt.resize(PALLA_W * PALLA_H)
	for y in PALLA_H:
		var th := (y + 0.5) / PALLA_H * PI
		for x in PALLA_W:
			var ph := (x + 0.5) / PALLA_W * TAU
			var d := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
			# distanza pesata dallo spicchio più vicino e dal secondo
			var d1 := INF
			var d2 := INF
			var nero := false
			for p in pent:
				var a := d.angle_to(p) + PESO_PENTAGONO
				if a < d1:
					d2 = d1
					d1 = a
					nero = true
				elif a < d2:
					d2 = a
			for e in esa:
				var a := d.angle_to(e)
				if a < d1:
					d2 = d1
					d1 = a
					nero = false
				elif a < d2:
					d2 = a
			var bordo := (d2 - d1) * 0.5          # distanza (rad) dalla cucitura
			var cuc := clampf(1.0 - bordo / CUCITURA, 0.0, 1.0)
			var base := Color(0.07, 0.075, 0.09) if nero else Color(0.95, 0.95, 0.93)
			# un filo di sfumatura verso il bordo (pannelli imbottiti) e la cucitura scura
			var cuscino := clampf(bordo / 0.09, 0.0, 1.0)
			base = base.darkened((1.0 - cuscino) * 0.12)
			img.set_pixel(x, y, base.lerp(Color(0.18, 0.18, 0.2), cuc * 0.85))
			alt[y * PALLA_W + x] = sqrt(cuscino) * (1.0 - cuc * 0.6)
	img.generate_mipmaps()
	img.save_png(CARTELLA + "pallone.png")
	_normali(alt, PALLA_W, PALLA_H, 3.0, false).save_png(CARTELLA + "pallone_n.png")


# ---------------------------------------------------------------- erba
# rilievo: tanti fili corti in tutte le direzioni (visti dall'alto) sopra una grana fine, ripetibile
func _erba() -> void:
	var alt := PackedFloat32Array()
	alt.resize(ERBA * ERBA)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 2
	var grana := noise.get_seamless_image(ERBA, ERBA)
	for i in alt.size():
		alt[i] = grana.get_pixel(i % ERBA, i / ERBA).r * 0.35
	for n in 9000:
		var p := Vector2(rng.randf() * ERBA, rng.randf() * ERBA)
		var ang := rng.randf() * TAU
		var dir := Vector2(cos(ang), sin(ang) * 0.6).normalized()   # un po' più lunghi nel verso del taglio
		var lungo := rng.randf_range(5.0, 12.0)
		var alto := rng.randf_range(0.5, 1.0)
		for s in int(lungo * 2.0):
			var q := p + dir * (s * 0.5)
			var k := float(s) / (lungo * 2.0)
			var xi := posmod(int(q.x), ERBA)
			var yi := posmod(int(q.y), ERBA)
			var idx := yi * ERBA + xi
			alt[idx] = maxf(alt[idx], 0.35 + alto * (1.0 - k) * 0.65)
	_normali(alt, ERBA, ERBA, 2.2, true).save_png(CARTELLA + "erba_n.png")


# normal map (verde verso l'alto, come vuole Godot) dal rilievo; giro = i bordi si toccano (texture ripetibile)
func _normali(alt: PackedFloat32Array, w: int, h: int, forza: float, giro: bool) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var xl := posmod(x - 1, w) if giro else maxi(x - 1, 0)
			var xr := posmod(x + 1, w) if giro else mini(x + 1, w - 1)
			var yu := posmod(y - 1, h) if giro else maxi(y - 1, 0)
			var yd := posmod(y + 1, h) if giro else mini(y + 1, h - 1)
			var dx := (alt[y * w + xr] - alt[y * w + xl]) * forza
			var dy := (alt[yd * w + x] - alt[yu * w + x]) * forza
			var n := Vector3(-dx, dy, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	return img
