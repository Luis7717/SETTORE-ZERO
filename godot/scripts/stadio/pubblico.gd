# Pubblico 3D delle tribune (riferimento: src/stadium-crowd.js del web). Migliaia di tifosi, ognuno un'istanza di
# un MultiMesh (un cartoncino col disegno di una persona, shaders/pubblico.gdshader): colori delle due squadre,
# curva di casa dietro una porta, settore ospiti dietro l'altra, neutri sui lati lunghi. Si alzano, alzano le braccia
# e saltano secondo lo stato delle due tifoserie, che cambia con tifo() (gol, occasione, parata, palo, fischio).
#
# Le tribune sono divise in pezzi da ~30 m (un MultiMesh ciascuno): Godot scarta quelli fuori dall'inquadratura.
# Densità (0..1) per i livelli di qualità: si mostrano solo i primi tifosi di ogni pezzo (sono in ordine casuale,
# quindi la tribuna si sfoltisce in modo uniforme).
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const SHADER := preload("res://shaders/pubblico.gdshader")

const POSTO := 0.68            # distanza tra due tifosi lungo la fila (m)
const FILA := 1.02             # distanza tra due file lungo la pendenza (m)
const CARTA_W := 0.66          # cartoncino di un tifoso (m)
const CARTA_H := 1.32
const PEZZO := 30.0            # lunghezza di un pezzo di tribuna (un MultiMesh)
const PIENO := 0.9             # posti occupati (settore ospiti un po' meno)
const CELLA_W := 32            # una persona nell'atlante (px)
const CELLA_H := 64
# stato di base delle tifoserie (in piedi, braccia, salti, applauso) e quanto in fretta lo si insegue (1/s)
const BASE := Vector4(0.12, 0.0, 0.0, 0.0)
const SALE := 7.0
const SCENDE := 1.6
# reazioni: [durata (s), stato di chi tifa per la squadra dell'evento, stato degli altri]
const REAZIONI := {
	"gol": [6.5, Vector4(1.0, 1.0, 1.0, 0.0), Vector4(0.0, 0.0, 0.0, 0.0)],
	"occasione": [1.8, Vector4(1.0, 0.65, 0.15, 0.0), Vector4(0.85, 0.25, 0.0, 0.0)],
	"palo": [2.2, Vector4(1.0, 0.8, 0.1, 0.0), Vector4(1.0, 0.5, 0.0, 0.0)],
	"parata": [2.4, Vector4(0.8, 0.35, 0.0, 0.85), Vector4(0.9, 0.3, 0.0, 0.0)],
	"fischio": [1.2, Vector4(0.45, 0.1, 0.0, 0.0), Vector4(0.55, 0.15, 0.0, 0.0)],
}
const NEUTRI := [Color("#22252c"), Color("#2c313b"), Color("#363b46"), Color("#1d2a40"), Color("#3a2f28"), Color("#c9ccd2"), Color("#e4e6ea"), Color("#9aa0aa"), Color("#b7a98c")]

var _mat: ShaderMaterial
var _pezzi: Array[MultiMeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
var _colori := [[Color("#c8102e"), Color("#ffffff")], [Color("#1746a2"), Color("#ffffff")]]
var _stato := [BASE, BASE]
var _impulsi: Array = []       # {squadra (0/1), stato, fine}
var _t := 0.0
var _densita := 1.0
var n_tifosi := 0


func _init() -> void:
	name = "Pubblico"
	_rng.seed = 7071
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("atlante", _atlante())


## costruisce i tifosi. tribune = Array di {a0, b0, a1, b1 (Vector3 Godot: bordo basso e alto), tipo, tetto (0..1:
## parte alta coperta dal tetto)}; tipo = "lato", "curva" (casa) o "ospiti" (settore ospiti al centro)
func costruisci(tribune: Array) -> void:
	for t: Dictionary in tribune:
		_tribuna(t)
	_applica_colori()


## colori delle squadre: casa e ospiti = [maglia, secondo colore]; i tifosi già seduti cambiano maglia
func imposta_colori(casa: Array, ospiti: Array) -> void:
	_colori = [casa, ospiti]
	for mmi in _pezzi:
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var cd := mm.get_instance_custom_data(i)
			var c := mm.get_instance_color(i)
			mm.set_instance_color(i, _maglia(cd.r, cd.g, c.a))
	_applica_colori()


## reazione della folla: tipo "gol", "occasione", "parata", "palo", "fischio"; squadra 0 = casa, 1 = ospiti
## (quella che segna, che ha l'occasione o che para)
func tifo(tipo: String, squadra: int) -> void:
	var r: Variant = REAZIONI.get(tipo)
	if r == null:
		return
	var s := clampi(squadra, 0, 1)
	_impulsi.append({"squadra": s, "stato": r[1], "fine": _t + r[0]})
	_impulsi.append({"squadra": 1 - s, "stato": r[2], "fine": _t + r[0], "giu": tipo == "gol"})


## a ogni fotogramma (dt = tempo vero: la folla non va al rallentatore)
func aggiorna(dt: float) -> void:
	_t += dt
	for i in range(_impulsi.size() - 1, -1, -1):
		if _impulsi[i].fine <= _t:
			_impulsi.remove_at(i)
	for s in 2:
		var meta := BASE
		var giu := false
		for im: Dictionary in _impulsi:
			if im.squadra == s:
				if im.get("giu", false):
					giu = true
				else:
					meta = Vector4(maxf(meta.x, im.stato.x), maxf(meta.y, im.stato.y), maxf(meta.z, im.stato.z), maxf(meta.w, im.stato.w))
		if giu:
			meta = Vector4.ZERO   # delusi: tutti seduti
		var cur: Vector4 = _stato[s]
		for k in 4:
			var v := cur[k]
			var rate := SALE if meta[k] > v else SCENDE
			cur[k] = v + (meta[k] - v) * minf(1.0, dt * rate)
		_stato[s] = cur
	_mat.set_shader_parameter("stato_casa", _stato[0])
	_mat.set_shader_parameter("stato_ospiti", _stato[1])
	_mat.set_shader_parameter("tempo", _t)


## quanti tifosi mostrare (0..1): 0 = nessuno (si vede il pubblico dipinto delle tribune)
func set_densita(k: float) -> void:
	_densita = clampf(k, 0.0, 1.0)
	visible = _densita > 0.0
	for mmi in _pezzi:
		var mm := mmi.multimesh
		mm.visible_instance_count = int(mm.instance_count * _densita) if _densita < 1.0 else -1


func densita() -> float:
	return _densita


func stato(squadra: int) -> Vector4:
	return _stato[clampi(squadra, 0, 1)]


# ---------------------------------------------------------------- costruzione
func _tribuna(t: Dictionary) -> void:
	var a0: Vector3 = t.a0
	var b0: Vector3 = t.b0
	var a1: Vector3 = t.a1
	var b1: Vector3 = t.b1
	var lungo := a0.distance_to(b0)
	var pendenza := a0.distance_to(a1)
	var file := int(pendenza / FILA)
	var posti := int(lungo / POSTO)
	var n_pezzi := maxi(1, roundi(lungo / PEZZO))
	for k in n_pezzi:
		var u0 := float(k) / n_pezzi
		var u1 := float(k + 1) / n_pezzi
		var dati: Array = []
		for f in file:
			var w := (f + 0.5) / file
			for i in posti:
				var u := (i + 0.5 + _rng.randf_range(-0.12, 0.12)) / posti
				if u < u0 or u >= u1:
					continue
				var tipo := _tifoseria(t.tipo, u, lungo)
				if _rng.randf() > (PIENO - 0.08 if tipo > 0.75 else PIENO):
					continue
				var p := a0.lerp(b0, u).lerp(a1.lerp(b1, u), w)
				p.y -= 0.12
				var sotto_tetto: bool = w > 1.0 - float(t.get("tetto", 0.0))
				var luce := _rng.randf_range(0.82, 1.0) * (0.62 if sotto_tetto else 1.0)
				dati.append([p, tipo, luce])
		if dati.is_empty():
			continue
		_mescola(dati)
		_pezzo(dati)


# tifoseria di un posto: 0 casa, 0,1 curva di casa, 0,5 neutri, 1 ospiti
func _tifoseria(tipo: String, u: float, lungo: float) -> float:
	var r := _rng.randf()
	match tipo:
		"curva":
			return 0.1 if r < 0.88 else 0.5
		"ospiti":
			var centro := absf(u - 0.5) * lungo < 22.0
			if centro:
				return 1.0 if r < 0.85 else 0.5
			return 0.0 if r < 0.45 else 0.5
		_:
			return 0.0 if r < 0.42 else (1.0 if r < 0.5 else 0.5)


func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var x: Variant = a[i]
		a[i] = a[j]
		a[j] = x


func _pezzo(dati: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(CARTA_W, CARTA_H)
	q.center_offset = Vector3(0.0, CARTA_H * 0.5, 0.0)
	mm.mesh = q
	mm.instance_count = dati.size()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in dati.size():
		var d: Array = dati[i]
		var p: Vector3 = d[0]
		var sc := _rng.randf_range(0.9, 1.08)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), p))
		var n := _rng.randf()
		var tipo := _rng.randi_range(0, 3)
		if d[1] < 0.15 and d[1] > 0.05 and _rng.randf() < 0.5:
			tipo = 1   # in curva più sciarpe
		var cd := Color(d[1], n, _pelle(), d[2])
		mm.set_instance_custom_data(i, cd)
		mm.set_instance_color(i, _maglia(d[1], n, (tipo + 0.5) / 4.0))
		lo = lo.min(p)
		hi = hi.max(p)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tifosi%d" % _pezzi.size()
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(lo - Vector3(1, 1, 1), hi - lo + Vector3(2, 3, 2))
	add_child(mmi)
	_pezzi.append(mmi)
	n_tifosi += dati.size()


func _pelle() -> float:
	var r := _rng.randf()
	return r * r * 0.9


# maglia del tifoso (alpha = tipo di disegno, già scelto): colori della sua squadra, a volte neutri
func _maglia(tifoseria: float, n: float, a: float) -> Color:
	var c: Color
	var h := fmod(n * 7919.0, 1.0)
	if tifoseria > 0.75 or tifoseria < 0.25:
		var sq: Array = _colori[1 if tifoseria > 0.75 else 0]
		var quota := 0.72 if (tifoseria > 0.05 and tifoseria < 0.15) or tifoseria > 0.75 else 0.5
		c = sq[0] if h < quota else (sq[1] if h < quota + 0.14 else NEUTRI[int(h * 97.0) % NEUTRI.size()])
	else:
		c = NEUTRI[int(h * 97.0) % NEUTRI.size()]
	c = c.darkened(fmod(n * 131.0, 1.0) * 0.22)
	c.a = a
	return c


func _applica_colori() -> void:
	_mat.set_shader_parameter("casa2", _colori[0][1])
	_mat.set_shader_parameter("ospiti2", _colori[1][1])


# ---------------------------------------------------------------- atlante dei disegni (4 tipi × 2 pose)
# tipi: 0 semplice, 1 sciarpa, 2 battimani (mani davanti), 3 cappello. Riga 0 braccia giù, riga 1 braccia su.
static func _atlante() -> ImageTexture:
	var img := Image.create(CELLA_W * 4, CELLA_H * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for tipo in 4:
		for posa in 2:
			_persona(img, tipo * CELLA_W, posa * CELLA_H, tipo, posa == 1)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, luce: float, g: float, b: float) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, Color(clampf(luce, 0.0, 1.0), g, b, 1.0))


static func _persona(img: Image, ox: int, oy: int, tipo: int, su: bool) -> void:
	var cx := CELLA_W / 2.0
	# busto con le spalle tonde: più chiaro in alto, scuro ai lati e in basso
	for y in range(27, CELLA_H):
		for x in range(6, CELLA_W - 6):
			var dx := absf(x + 0.5 - cx)
			var spalla := 27.0 + maxf(0.0, dx - 6.0) * 0.6
			if y < spalla:
				continue
			var luce := 1.0 - (y - 27.0) / 60.0 - pow(dx / 10.0, 4.0) * 0.25
			_px(img, ox + x, oy + y, luce, 1.0, 0.0)
	# collo e testa (capelli sopra, o cappello)
	for y in range(22, 28):
		for x in range(14, 18):
			_px(img, ox + x, oy + y, 0.8, 0.0, 1.0)
	for y in range(8, 24):
		for x in range(9, 23):
			var d := Vector2((x + 0.5 - cx) / 6.2, (y + 0.5 - 16.0) / 7.6)
			if d.length() > 1.0:
				continue
			var capelli := y < 13 or (y < 16 and absf(x + 0.5 - cx) > 4.5)
			if tipo == 3 and y < 13:
				_px(img, ox + x, oy + y, 0.95, 0.5, 0.0)
			elif capelli:
				_px(img, ox + x, oy + y, 0.9, 0.0, 0.0)
			else:
				_px(img, ox + x, oy + y, 1.0 - d.x * d.x * 0.25, 0.0, 1.0)
	if tipo == 3:   # visiera
		for x in range(8, 24):
			_px(img, ox + x, oy + 12, 0.7, 0.5, 0.0)
	# braccia
	if su:
		for k in 2:
			var s := -1.0 if k == 0 else 1.0
			for y in range(4, 32):
				var xc := cx + s * (11.0 + (31.0 - y) * 0.12)
				for x in range(int(xc) - 2, int(xc) + 2):
					if y < 9:
						_px(img, ox + x, oy + y, 0.95, 0.0, 1.0)   # mani
					else:
						_px(img, ox + x, oy + y, 0.85, 1.0, 0.0)
		if tipo == 1:   # sciarpa tesa sopra la testa
			for y in range(3, 7):
				for x in range(5, CELLA_W - 5):
					_px(img, ox + x, oy + y, 0.95 if (x / 3) % 2 == 0 else 0.7, 0.5, 0.0)
	else:
		for k in 2:
			var x0 := 4 if k == 0 else CELLA_W - 8
			for y in range(29, 50):
				for x in range(x0, x0 + 4):
					_px(img, ox + x, oy + y, 0.72, 1.0, 0.0)
			for y in range(50, 54):
				for x in range(x0, x0 + 4):
					_px(img, ox + x, oy + y, 0.85, 0.0, 1.0)
		if tipo == 1:   # sciarpa al collo
			for y in range(27, 31):
				for x in range(9, 23):
					_px(img, ox + x, oy + y, 0.95, 0.5, 0.0)
			for y in range(31, 46):
				for x in range(14, 18):
					_px(img, ox + x, oy + y, 0.9 if (y / 3) % 2 == 0 else 0.7, 0.5, 0.0)
		elif tipo == 2:   # mani davanti al petto (battimani)
			for y in range(36, 41):
				for x in range(13, 19):
					_px(img, ox + x, oy + y, 0.95, 0.0, 1.0)
