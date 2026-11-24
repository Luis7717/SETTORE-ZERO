# Piccole texture disegnate a codice per la vista della partita (come i canvas di src/render.js e src/props.js):
# bordo dei nastri, ombre morbide, anello del controllato, segnalino, mirino del tiro, avviso, puntino.
extends RefCounted

const GIALLO := Color("#ffe14a")


static func _tex(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## di traverso al nastro: bordo scuro morbido, anima chiara (il colore del materiale tinge l'anima)
static func nastro() -> ImageTexture:
	var w := 64
	var img := Image.create(w, 4, false, Image.FORMAT_RGBA8)
	# fermate del gradiente (posizione, colore) da 0 a 0,5; l'altra metà è speculare
	var st := [[0.0, Color(0, 0, 0, 0)], [0.06, Color(0, 0, 0, 0.3)], [0.15, Color(15 / 255.0, 20 / 255.0, 25 / 255.0, 0.55)],
		[0.2, Color(1, 1, 1, 1)], [0.5, Color(1, 1, 1, 1)]]
	for x in w:
		var u := (x + 0.5) / w
		u = minf(u, 1.0 - u)
		var c: Color = st[-1][1]
		for i in st.size() - 1:
			if u <= st[i + 1][0]:
				c = (st[i][1] as Color).lerp(st[i + 1][1], (u - st[i][0]) / (st[i + 1][0] - st[i][0]))
				break
		for y in 4:
			img.set_pixel(x, y, c)
	return _tex(img)


## macchia scura rotonda e morbida (ombre a terra): alpha al centro `a0`
static func ombra(lato: int = 64, a0: float = 0.55) -> ImageTexture:
	var img := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
	var c := lato / 2.0
	for y in lato:
		for x in lato:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / (c * 0.94)
			img.set_pixel(x, y, Color(0, 0, 0, a0 * clampf(1.0 - d, 0.0, 1.0)))
	return _tex(img)


## ombre dei fari di notte (2026-11-24): la macchia di ombra() più quattro scie leggere verso gli angoli, come
## sotto le quattro torri faro (ombre a stella delle partite in notturna). Si legge anche senza luci vere in più.
## dir = verso di una scia (le altre sono i suoi simmetrici); a0 = scuro della macchia, scia = scuro delle scie
static var _ombra_fari: ImageTexture = null   # fatta una volta sola (il disegno costa sul telefono)


## a fine programma (Uscita.libera_cache_grafiche): lascia la texture condivisa (si rifà se serve ancora)
static func libera_condivisi() -> void:
	_ombra_fari = null


static func ombra_fari(lato: int = 96, a0: float = 0.42, scia: float = 0.2, dir := Vector2(0.55, 0.83)) -> ImageTexture:
	if _ombra_fari != null:
		return _ombra_fari
	var img := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
	var c := lato / 2.0
	var dirs := [dir, Vector2(-dir.x, dir.y), -dir, Vector2(dir.x, -dir.y)]
	for y in lato:
		for x in lato:
			var p := Vector2(x + 0.5 - c, y + 0.5 - c) / c   # -1..1
			var a := a0 * clampf(1.0 - p.length() / 0.36, 0.0, 1.0)   # macchia: un terzo del lato
			for d: Vector2 in dirs:
				var lungo := p.dot(d)                     # 0 al centro, 1 al bordo
				var largo := absf(p.dot(Vector2(-d.y, d.x)))
				if lungo > 0.0:
					var w := 0.07 + 0.05 * lungo           # la scia si allarga un po' andando via
					a = maxf(a, scia * clampf(1.0 - lungo / 0.95, 0.0, 1.0) * clampf(1.0 - largo / w, 0.0, 1.0))
			img.set_pixel(x, y, Color(0, 0, 0, a))
	_ombra_fari = _tex(img)
	return _ombra_fari


## anello (contorno di un cerchio) di spessore `sp` su 128 px
static func anello(col: Color = GIALLO, raggio: float = 52.0, sp: float = 12.0) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := absf(Vector2(x + 0.5 - 64.0, y + 0.5 - 64.0).length() - raggio)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(sp / 2.0 + 0.5 - d, 0.0, 1.0)))
	return _tex(img)


## mirino del tiro: cerchio con quattro tacche
static func mirino() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var p := Vector2(x + 0.5 - 64.0, y + 0.5 - 64.0)
			var a := clampf(5.0 - absf(p.length() - 46.0), 0.0, 1.0)
			if (absf(p.x) < 4.5 and absf(p.y) > 24.0 and absf(p.y) < 60.0) or (absf(p.y) < 4.5 and absf(p.x) > 24.0 and absf(p.x) < 60.0):
				a = 1.0
			img.set_pixel(x, y, Color(GIALLO.r, GIALLO.g, GIALLO.b, a))
	return _tex(img)


## segnalino sopra il controllato: triangolo giallo a punta in giù con bordo nero
static func segnalino() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var a := Vector2(8, 10)
	var b := Vector2(56, 10)
	var c := Vector2(32, 54)
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := minf(_dist_seg(p, a, b), minf(_dist_seg(p, b, c), _dist_seg(p, c, a)))
			var dentro := _in_tri(p, a, b, c)
			var col := Color(0, 0, 0, 0)
			if dentro:
				col = GIALLO
			if d < 1.5:
				col = Color(0, 0, 0, 1)
			img.set_pixel(x, y, col)
	return _tex(img)


## avviso (cartellino in arrivo): cerchio rosso con il punto esclamativo
static func avviso() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5 - 32.0, y + 0.5 - 32.0)
			var a := clampf(28.5 - p.length(), 0.0, 1.0)
			var col := Color(1.0, 0.23, 0.19, a)
			if (absf(p.x) < 4.0 and p.y > -18.0 and p.y < 6.0) or Vector2(p.x, p.y - 13.0).length() < 4.5:
				col = Color(1, 1, 1, a)
			img.set_pixel(x, y, col)
	return _tex(img)


## puntino dell'anteprima: anima chiara con bordo scuro morbido
static func puntino() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() / 15.5
			var col := Color(1, 1, 1, 1) if d < 0.5 else Color(10 / 255.0, 25 / 255.0, 40 / 255.0, 0.75 * clampf((1.0 - d) / 0.38, 0.0, 1.0))
			if d >= 0.5 and d < 0.62:
				col = Color(1, 1, 1, 1).lerp(Color(10 / 255.0, 25 / 255.0, 40 / 255.0, 0.75), (d - 0.5) / 0.12)
			img.set_pixel(x, y, col)
	return _tex(img)


static func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p - b).cross(a - b)
	var d2 := (p - c).cross(b - c)
	var d3 := (p - a).cross(c - a)
	var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (neg and pos)


## materiale "sopra a tutto" per segni a terra e nastri: senza luce, trasparente, senza prova di profondità
static func materiale_segno(tex: Texture2D, col: Color, priorita: int, sopra: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = sopra
	m.render_priority = priorita
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## pallone bianco con 12 macchie scure ai vertici di un icosaedro (texture equirettangolare, come scripts/prova_campo.gd)
static func palla() -> ImageTexture:
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var vertici: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-phi, phi]:
			vertici.append(Vector3(0, a, b).normalized())
			vertici.append(Vector3(a, b, 0).normalized())
			vertici.append(Vector3(b, 0, a).normalized())
	for y in h:
		var lat := PI * (0.5 - (y + 0.5) / h)
		for x in w:
			var lon := TAU * (x + 0.5) / w
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var vicino := 0.0
			for v in vertici:
				vicino = maxf(vicino, d.dot(v))
			img.set_pixel(x, y, Color(0.08, 0.08, 0.1) if vicino > 0.93 else Color(0.96, 0.96, 0.96))
	return _tex(img)
