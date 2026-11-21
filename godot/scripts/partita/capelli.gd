# Capelli del giocatore come mesh a parte (2026-11-21). Prima erano i vertici della testa gonfiati dallo shader della
# divisa: con la testa del modello (pochi vertici) venivano a gradini e "a punte", e i tagli lunghi erano dipinti
# sul collo. Ora ogni taglio è una mesh costruita qui, una volta sola, e condivisa da tutti i giocatori con quel
# taglio (con la barba di barbe.gd nella stessa mesh: un solo disegno in più per giocatore). Materiale unico
# (shaders/capelli.gdshader), colore dei capelli e della pelle per istanza.
#
# Calotta: dal centro della testa (lo stesso di shaders/divisa.gdshader) si misura, per ogni direzione (azimut,
# elevazione), a che distanza esce la pelle della testa del modello (mappa dei raggi, un raggio per direzione contro
# i triangoli della testa). I capelli sono una griglia azimut × elevazione appoggiata su quella pelle (ammorbidita)
# più lo spessore del taglio: volumi tondi che seguono il cranio. L'attaccatura vera la taglia lo shader per pixel
# (CUSTOM0.x = quanto si è dentro il taglio, con un po' di rumore: niente bordo a scalini). I tagli lunghi sotto
# l'orecchio cadono in verticale invece di seguire il collo. Pezzi a parte: cresta, punte, coda, chignon.
#
# Coordinate: posa di riposo del modello (come CUSTOM0 della divisa); la mesh va sotto l'osso "Head" con la
# trasformazione di legame della pelle (attacca()), così segue la testa come la pelle vera.
extends RefCounted

const Barbe := preload("barbe.gd")
const SHADER := preload("res://shaders/capelli.gdshader")

const N_TAGLI := 17
const MAP_AZ := 72              # mappa dei raggi: un raggio ogni 5° di azimut...
const MAP_EL := 61              # ... e ogni 3° di elevazione (da −90° a +90°)
const N_AZ := 32                # griglia dei capelli: colonne (11,25° l'una)...
const EL_PASSO := 6.0           # ... e righe ogni 6° di elevazione
const STACCO := 0.0012          # m: i capelli più sottili stanno comunque così sopra la pelle (niente sfarfallio)
const GRADO_M := 0.0019         # m di cuoio capelluto per grado (raggio della testa ~0,11 m)
const BORDO_M := 0.005          # m: fascia oltre l'attaccatura tenuta nella mesh (lo shader la taglia col rumore)
const CADUTA_EL := 2.0          # gradi: sotto questa elevazione i tagli lunghi cadono in verticale
const DIETRO_C := 0.075         # m: centro della testa dietro al piano degli occhi (come testa_dir dello shader)

# tipo di ciocca per lo shader (CUSTOM0.y)
const LISCI := 0.0
const RICCI := 1.0
const TRECCE := 2.0
const BARBA := 3.0
const ELASTICO := 4.0
const LUCIDI := 5.0
const RIGA := 6.0

# attaccatura sul cranio (gradi di elevazione davanti, ai lati, dietro: come TAGLI in divisa.gdshader) e fine dei
# capelli (lati, dietro) per i tagli che scendono sotto l'attaccatura; spessore (m); rampa (gradi) dal bordo al pieno
const LINEA := [
	Vector3(95, 95, 95), Vector3(42, 6, -38), Vector3(38, 8, -34), Vector3(40, 10, -32), Vector3(36, 8, -34),
	Vector3(36, 6, -36), Vector3(42, 6, -38), Vector3(38, 8, -34), Vector3(34, 4, -38), Vector3(30, -2, -42),
	Vector3(32, 2, -32), Vector3(32, 2, -32), Vector3(36, 6, -30), Vector3(36, 6, -30), Vector3(34, -2, -40),
	Vector3(14, 4, -38), Vector3(40, 10, -34),
]
const FINE := {9: Vector2(-14.0, -38.0), 10: Vector2(-34.0, -44.0), 11: Vector2(-48.0, -44.0)}
const CADE := [10, 11]          # tagli che sotto l'orecchio cadono in verticale
const SPESSORE := [0.0, 0.0, 0.009, 0.007, 0.009, 0.01, 0.0, 0.008, 0.02, 0.0, 0.013, 0.014, 0.0075, 0.0075, 0.006, 0.011, 0.009]
const RAMPA := [1.0, 1.0, 12.0, 12.0, 8.0, 12.0, 1.0, 12.0, 14.0, 30.0, 10.0, 10.0, 10.0, 10.0, 6.0, 5.0, 12.0]
# frazione dello spessore che resta proprio sul bordo (il resto cresce lungo la rampa)
const BORDO_K := [0.0, 0.0, 0.12, 0.1, 0.12, 0.12, 0.0, 0.12, 0.2, 0.05, 0.5, 0.5, 0.3, 0.3, 0.6, 0.45, 0.15]

static var _pronto := false
static var _c := Vector3.ZERO           # centro della testa
static var _f := Vector3(0, 0, 1)       # davanti
static var _l := Vector3(1, 0, 0)       # lato (azimut positivo)
static var _r := PackedFloat32Array()   # raggi della pelle (MAP_EL × MAP_AZ)
static var _rm := PackedFloat32Array()  # raggi ammorbiditi (base dei capelli)
static var _cache := {}                 # taglio * 8 + barba → ArrayMesh
static var _parti := {}                 # taglio → array dei soli capelli (si riusano con ogni barba)
static var _materiale: ShaderMaterial


## misura la testa del modello (una volta): mesh in posa di riposo, centro dell'occhio sinistro, verso del viso
static func prepara(mesh: ArrayMesh, occhi: Vector3, davanti: Vector2) -> void:
	if _pronto:
		return
	_pronto = true
	_f = Vector3(davanti.x, 0.0, davanti.y).normalized()
	_l = Vector3(_f.z, 0.0, -_f.x)
	_c = Vector3(0.0, occhi.y, 0.0) + _f * (occhi.x * _f.x + occhi.z * _f.z - DIETRO_C)
	var a := mesh.surface_get_arrays(0)
	_mappa_raggi(a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_INDEX], occhi.y - 0.2)
	Barbe.prepara(a, occhi, _f, _l)
	_materiale = ShaderMaterial.new()
	_materiale.shader = SHADER


## mesh di capelli + barba (null se non c'è niente: calvo o rasato senza barba vera)
static func mesh_per(taglio: int, barba: int) -> ArrayMesh:
	taglio = clampi(taglio, 0, N_TAGLI - 1)
	barba = clampi(barba, 0, 6)
	var k := taglio * 8 + barba
	if _cache.has(k):
		return _cache[k]
	var parti: Array = []   # [Dictionary di array] da unire
	if not _parti.has(taglio):
		_parti[taglio] = _capelli(taglio)
	var cap: Dictionary = _parti[taglio]
	if not cap.is_empty():
		parti.append(cap)
	var bb := Barbe.parte(barba)
	if not bb.is_empty():
		parti.append(bb)
	var m: ArrayMesh = _unisci(parti) if not parti.is_empty() else null
	_cache[k] = m
	return m


## nodo da mettere sotto lo scheletro: BoneAttachment3D sull'osso della testa con dentro la mesh dei capelli
static func attacca(scheletro: Skeleton3D, pelle: Skin) -> MeshInstance3D:
	var att := BoneAttachment3D.new()
	att.name = "Testa"
	att.bone_name = "Head"
	scheletro.add_child(att)
	var mi := MeshInstance3D.new()
	mi.name = "Capelli"
	mi.material_override = _materiale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var osso := scheletro.find_bone("Head")
	mi.transform = scheletro.get_bone_global_rest(osso).affine_inverse()
	if pelle != null:
		for i in pelle.get_bind_count():
			if pelle.get_bind_name(i) == "Head" or pelle.get_bind_bone(i) == osso:
				mi.transform = pelle.get_bind_pose(i)
				break
	att.add_child(mi)
	return mi


# ---------------------------------------------------------------- direzioni e mappa dei raggi
## direzione dal centro della testa: az (gradi, 0 = davanti, + verso il lato _l), el (gradi)
static func dir(az: float, el: float) -> Vector3:
	var a := deg_to_rad(az)
	var e := deg_to_rad(el)
	return (_f * cos(a) + _l * sin(a)) * cos(e) + Vector3.UP * sin(e)


static func az_el(p: Vector3) -> Vector2:
	var d := p - _c
	var r := maxf(d.length(), 1e-6)
	return Vector2(rad_to_deg(atan2(d.dot(_l), d.dot(_f))), rad_to_deg(asin(clampf(d.y / r, -1.0, 1.0))))


static func _mappa_raggi(v: PackedVector3Array, idx: PackedInt32Array, y_min: float) -> void:
	_r.resize(MAP_EL * MAP_AZ)
	_r.fill(INF)
	for t in range(0, idx.size(), 3):
		var p0 := v[idx[t]]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		if minf(p0.y, minf(p1.y, p2.y)) < y_min or maxf(absf(p0.x), maxf(absf(p1.x), absf(p2.x))) > 0.14:
			continue
		var e0 := az_el(p0)
		var e1 := az_el(p1)
		var e2 := az_el(p2)
		var el_lo := minf(e0.y, minf(e1.y, e2.y))
		var el_hi := maxf(e0.y, maxf(e1.y, e2.y))
		var j0 := int(ceil((el_lo + 90.0) / 3.0))
		var j1 := mini(int(floor((el_hi + 90.0) / 3.0)), MAP_EL - 1)
		var az := [e0.x, e1.x, e2.x]
		if maxf(e0.x, maxf(e1.x, e2.x)) - minf(e0.x, minf(e1.x, e2.x)) > 180.0:
			for k in 3:
				if az[k] < 0.0:
					az[k] += 360.0
		var i0 := int(ceil((minf(az[0], minf(az[1], az[2])) + 180.0) / 5.0))
		var i1 := int(floor((maxf(az[0], maxf(az[1], az[2])) + 180.0) / 5.0))
		if el_hi > 84.0:
			i0 = 0
			i1 = MAP_AZ - 1
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var ii := posmod(i, MAP_AZ)
				var d := dir(-180.0 + ii * 5.0, -90.0 + j * 3.0)
				var hit := _raggio_triangolo(_c, d, p0, p1, p2)
				if hit > 0.0 and hit < _r[j * MAP_AZ + ii]:
					_r[j * MAP_AZ + ii] = hit
	# buchi (sotto il collo, triangoli troppo piccoli): dal vicino più vicino nella stessa colonna
	for i in MAP_AZ:
		for pass_ in 2:
			var ultimo := INF
			var rng: Array = range(MAP_EL) if pass_ == 0 else range(MAP_EL - 1, -1, -1)
			for j: int in rng:
				var k := j * MAP_AZ + i
				if _r[k] < INF:
					ultimo = _r[k]
				elif ultimo < INF:
					_r[k] = ultimo
	for k in _r.size():
		if _r[k] == INF:
			_r[k] = 0.1
	# base dei capelli: raggi ammorbiditi (via orecchie e piccole gobbe), mai sotto la pelle vera
	_rm = _r.duplicate()
	for giro in 3:
		var tmp := _rm.duplicate()
		for j in MAP_EL:
			for i in MAP_AZ:
				var s := 0.0
				var w := 0.0
				for dj in [-1, 0, 1]:
					var jj: int = clampi(j + dj, 0, MAP_EL - 1)
					for di in [-1, 0, 1]:
						var peso := (2.0 if dj == 0 else 1.0) * (2.0 if di == 0 else 1.0)
						s += tmp[jj * MAP_AZ + posmod(i + di, MAP_AZ)] * peso
						w += peso
				_rm[j * MAP_AZ + i] = s / w
	for k in _rm.size():
		_rm[k] = maxf(_rm[k], _r[k])


# Möller–Trumbore: distanza lungo d dal punto o al triangolo (−1 se non lo tocca)
static func _raggio_triangolo(o: Vector3, d: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var e1 := b - a
	var e2 := c - a
	var p := d.cross(e2)
	var det := e1.dot(p)
	if absf(det) < 1e-12:
		return -1.0
	var inv := 1.0 / det
	var s := o - a
	var u := s.dot(p) * inv
	if u < -1e-6 or u > 1.0 + 1e-6:
		return -1.0
	var q := s.cross(e1)
	var vv := d.dot(q) * inv
	if vv < -1e-6 or u + vv > 1.0 + 1e-6:
		return -1.0
	return e2.dot(q) * inv


## raggio (m) della pelle (morbido = base dei capelli) nella direzione az, el (gradi), interpolato
static func raggio(az: float, el: float, morbido: bool = true) -> float:
	var m := _rm if morbido else _r
	var x := (wrapf(az + 180.0, 0.0, 360.0)) / 5.0
	var y := clampf((el + 90.0) / 3.0, 0.0, MAP_EL - 1.001)
	var i0 := int(floor(x))
	var j0 := int(floor(y))
	var fx := x - i0
	var fy := y - j0
	var a := lerpf(m[j0 * MAP_AZ + posmod(i0, MAP_AZ)], m[j0 * MAP_AZ + posmod(i0 + 1, MAP_AZ)], fx)
	var b := lerpf(m[(j0 + 1) * MAP_AZ + posmod(i0, MAP_AZ)], m[(j0 + 1) * MAP_AZ + posmod(i0 + 1, MAP_AZ)], fx)
	return lerpf(a, b, fy)


# ---------------------------------------------------------------- forma dei tagli
static func linea(taglio: int, az: float) -> float:
	var t: Vector3 = LINEA[taglio]
	var a := absf(az)
	return lerpf(t.x, t.y, smoothstep(25.0, 95.0, a)) if a < 95.0 else lerpf(t.y, t.z, smoothstep(100.0, 170.0, a))


## dove finiscono i capelli (gradi di elevazione): l'attaccatura, o più giù per i tagli che scendono
static func fine(taglio: int, az: float) -> float:
	var l := linea(taglio, az)
	if not FINE.has(taglio):
		return l
	var f: Vector2 = FINE[taglio]
	var a := absf(az)
	var giu := lerpf(f.x, f.y, smoothstep(100.0, 170.0, a))
	# davanti resta libero il viso: la caduta comincia dietro la tempia
	return lerpf(l, minf(l, giu), smoothstep(42.0, 78.0, a))


static func _gauss(x: float, s: float) -> float:
	return exp(-(x * x) / (s * s))


# piccole gobbe lisce (ricci, afro) in funzione della direzione: niente punte, solo rilievi tondi
static func _gobbe(d: Vector3, f: float) -> float:
	return (sin(d.x * f + 1.3) * sin(d.y * f * 0.9 + 0.4) * sin(d.z * f * 1.1 + 2.1)
		+ 0.5 * sin(d.x * f * 2.1 - d.z * f * 1.3) * sin(d.y * f * 1.9 + 0.7))


## spessore (m) del taglio nella direzione az, el (sul cranio, prima della rampa dell'attaccatura)
static func spessore(taglio: int, az: float, el: float) -> float:
	var t: float = SPESSORE[taglio]
	var a := absf(az)
	var d := dir(az, el)
	var su := smoothstep(5.0, 60.0, el)   # 0 ai lati, 1 sopra
	match taglio:
		2, 7, 16:   # corti: lati sfumati, sopra più pieni
			t *= lerpf(0.4, 1.15, su)
			if taglio == 16:
				t += 0.008 * smoothstep(90.0, 165.0, a) * smoothstep(-30.0, 20.0, el)   # spinti indietro
		3:          # spazzola: lati corti, sopra alta e piatta (taglia la parte alta più sotto)
			t = lerpf(0.0035, 0.024, smoothstep(26.0, 58.0, el))
			var cima := _c.y + 0.14
			var y := _c.y + d.y * (raggio(az, el) + t)
			if y > cima and d.y > 0.2:
				t -= (y - cima) / d.y
		4:          # ciuffo: alto davanti, alzato sulla fronte
			t *= lerpf(0.4, 1.1, su)
			t += 0.024 * _gauss(az, 34.0) * smoothstep(28.0, 42.0, el) * (1.0 - 0.6 * smoothstep(55.0, 85.0, el))
		5:          # riga di lato: più volume dal lato opposto alla riga
			t *= lerpf(0.45, 1.1, su)
			t += 0.004 * smoothstep(0.0, -60.0, az) * smoothstep(20.0, 60.0, el) * _gauss(a - 40.0, 60.0)
		8:          # ricci: gobbe tonde
			t *= lerpf(0.7, 1.15, su)
			t += 0.005 * _gobbe(d, 9.0)
		9:          # afro: un ellissoide un po' schiacciato sopra la testa, con gobbe larghe
			t = maxf(0.012, _ellissoide(d, _c + Vector3(0, 0.03, 0) - _f * 0.015, Vector3(0.132, 0.148, 0.145)) - raggio(az, el))
			t += 0.005 * _gobbe(d, 7.0)
		10, 11:     # caschetto, lunghi: volume pieno; sopra le orecchie un po' di più (le coprono senza bozzi)
			t *= lerpf(0.85, 1.0, su)
			t += 0.004 * _gauss(a - 95.0, 28.0) * _gauss(el + 2.0, 18.0)
		12, 13:     # coda, chignon: tirati indietro, aderenti
			t *= lerpf(0.7, 1.0, su)
		14:         # treccine (trecce attaccate alla testa): spessore uniforme, i solchi li fa lo shader
			pass
		15:         # frangia: sulla fronte un bordo netto
			t *= lerpf(0.75, 1.1, su)
			t += 0.004 * _gauss(az, 50.0) * smoothstep(10.0, 30.0, el)
	return maxf(t, 0.0)


# distanza dal centro della testa, lungo d, alla superficie dell'ellissoide (centro e, semiassi lato/su/davanti)
static func _ellissoide(d: Vector3, e: Vector3, rag: Vector3) -> float:
	var o := _c - e
	var o2 := Vector3(o.dot(_l) / rag.x, o.y / rag.y, o.dot(_f) / rag.z)
	var d2 := Vector3(d.dot(_l) / rag.x, d.y / rag.y, d.dot(_f) / rag.z)
	var a := d2.dot(d2)
	var b := o2.dot(d2)
	var c := o2.dot(o2) - 1.0
	return (-b + sqrt(maxf(b * b - a * c, 0.0))) / a


static func _tipo(taglio: int) -> float:
	match taglio:
		8, 9:
			return RICCI
		14:
			return TRECCE
		16, 12, 13:
			return LUCIDI
		5:
			return RIGA
	return LISCI


# ---------------------------------------------------------------- costruzione
## array (vertici, normali, tangenti, uv, custom0, indici) dei capelli del taglio; {} se non ci sono
static func _capelli(taglio: int) -> Dictionary:
	if taglio <= 1:
		return {}
	var g := Griglia.new()
	if taglio != 6:
		_calotta(g, taglio)
	match taglio:
		6:
			_cresta(g)
		7:
			_punte(g)
		12:
			_coda(g)
		13:
			_chignon(g)
	return g.arrays()


# calotta: griglia azimut × elevazione sopra il cranio, dal bordo più basso del taglio fino alla cima
static func _calotta(g: Griglia, taglio: int) -> void:
	var tipo := _tipo(taglio)
	var el_min := 90.0
	for i in N_AZ:
		el_min = minf(el_min, fine(taglio, -180.0 + i * 360.0 / N_AZ))
	el_min -= EL_PASSO
	var righe := int(ceil((90.0 - el_min) / EL_PASSO))
	var passo := (90.0 - el_min) / righe
	var cols := N_AZ + 1
	var base := g.v.size()
	var marg := PackedFloat32Array()
	# in cima tutte le colonne finiscono nello stesso punto: lo spessore lassù è la media (niente stella di punte)
	var t_cima := 0.0
	for i in 12:
		t_cima += spessore(taglio, -180.0 + i * 30.0, 90.0) / 12.0
	for j in righe + 1:
		var el := el_min + j * passo
		for i in cols:
			var az := -180.0 + i * 360.0 / N_AZ
			var bordo := fine(taglio, az)
			var m := (el - bordo) * GRADO_M
			if CADE.has(taglio) and el < linea(taglio, az) - 4.0:
				# punte delle ciocche lunghe di lunghezze diverse (non un taglio dritto col righello)
				var ar := deg_to_rad(az)
				m += (2.6 * sin(ar * 7.0) + 1.6 * sin(ar * 13.0 + 1.0)) * GRADO_M
			var p := _punto_calotta(taglio, az, el, bordo, t_cima)
			g.aggiungi(p, Vector2(deg_to_rad(az) * 0.11, deg_to_rad(el) * 0.11), Vector4(m, tipo, p.distance_to(_c) - raggio(az, el), 0.0))
			marg.append(m)
	# quadrati con almeno un angolo dentro (la fascia fuori la taglia lo shader)
	for j in righe:
		for i in N_AZ:
			var a := j * cols + i
			var b := a + 1
			var c := a + cols + 1
			var d := a + cols
			if maxf(maxf(marg[a], marg[b]), maxf(marg[c], marg[d])) < -BORDO_M:
				continue
			g.quad(base + a, base + b, base + c, base + d, _c)
	# saldature: l'ultima colonna è la prima (stessa posizione, uv diverse) e la cima è un punto solo
	var salda := {}
	for j in righe + 1:
		salda[base + j * cols + N_AZ] = base + j * cols
	for i in range(1, cols):
		salda[base + righe * cols + i] = base + righe * cols
	g.salda(salda)


static func _punto_calotta(taglio: int, az: float, el: float, bordo: float, t_cima: float) -> Vector3:
	var rampa: float = RAMPA[taglio]
	var cade := CADE.has(taglio) and el < CADUTA_EL
	var el_cr := maxf(el, CADUTA_EL) if cade else el
	var k := smoothstep(bordo - 1.0, bordo + rampa, el)
	if cade:   # le ciocche che cadono restano piene, si assottigliano solo sulle punte
		k = lerpf(0.55, 1.0, smoothstep(bordo, bordo + 8.0, el))
	var sp := lerpf(spessore(taglio, az, el_cr), t_cima, smoothstep(68.0, 90.0, el_cr))
	var t := STACCO + sp * lerpf(BORDO_K[taglio], 1.0, k)
	if el >= 89.99:
		return _c + Vector3.UP * (raggio(0.0, 90.0) + t)
	var p := _c + dir(az, el) * (raggio(az, el) + t)
	if not cade:
		return p
	# capelli che cadono: dal punto all'altezza CADUTA_EL scendono dritti (un filo verso l'interno); la curva gira
	# dolce da "sul cranio" a "giù dritto" mescolando i due punti, e non entra mai nella pelle
	var alto := _c + dir(az, el_cr) * (raggio(az, el_cr) + t)
	var giu := deg_to_rad(el_cr - el) * 0.115
	var dritto := alto - Vector3(0, giu, 0)
	var oriz := Vector3(dritto.x - _c.x, 0.0, dritto.z - _c.z)
	dritto -= oriz * (0.1 * giu / 0.1)
	p = p.lerp(dritto, smoothstep(0.0, 22.0, el_cr - el))
	for prova in 3:
		var ae := az_el(p)
		if ae.y < -70.0:
			break
		var minimo := raggio(ae.x, ae.y, false) + t * 0.8
		var dd := p - _c
		if dd.length() < minimo:
			p = _c + dd.normalized() * minimo
	return p


# cresta: pinna tonda lungo la riga di mezzo, dalla fronte alla nuca (i lati sono rasati, dipinti dalla divisa)
static func _cresta(g: Griglia) -> void:
	var passi := 20
	var lati := 8
	var base := g.v.size()
	var basi: Array = []
	for s in passi + 1:
		var u := float(s) / passi
		var th := lerpf(50.0, -118.0, u)   # gradi dalla verticale verso il davanti
		var az := 0.0 if th >= 0.0 else 180.0
		var el := 90.0 - absf(th)
		var d := dir(az, el)
		var pb := _c + d * (raggio(az, el) - 0.002)
		basi.append(pb)
		var avanti := (dir(az, el + 1.0) - dir(az, el - 1.0)).normalized() * (1.0 if th >= 0.0 else -1.0)
		var lato := d.cross(avanti).normalized()
		var env := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.82, 1.0, u))
		var h := 0.004 + 0.036 * env * (1.0 - 0.25 * u)
		var w := 0.006 + 0.008 * env
		for k in lati + 1:
			var a := PI * float(k) / lati
			var p := pb + lato * (w * cos(a)) + d * (h * sin(a))
			var m := minf(u, 1.0 - u) * 0.12 + 0.002
			g.aggiungi(p, Vector2(cos(a) * 0.02, u * 0.3), Vector4(m, LISCI, h * sin(a), 0.0))
	for s in passi:
		for k in lati:
			var a := base + s * (lati + 1) + k
			g.quad(a, a + 1, a + lati + 2, a + lati + 1, ((basi[s] as Vector3) + (basi[s + 1] as Vector3)) * 0.5)


# punte: ciuffi a cono sopra un taglio corto, piegati un po' indietro
static func _punte(g: Griglia) -> void:
	# posti (azimut, elevazione) a file sfalsate, dalla fronte alla corona
	var posti: Array = []
	for fila in 4:
		var el := 50.0 + fila * 11.0
		var n := 8 - fila
		for k in n:
			var az := lerpf(-150.0, 150.0, (k + 0.5 * (fila % 2)) / maxf(n - 0.5, 1.0))
			posti.append([az, el])
	posti.append([0.0, 88.0])
	for ps: Array in posti:
		var az: float = ps[0]
		var el: float = ps[1]
		var d := dir(az, el)
		var pb := _c + d * (raggio(az, el) + 0.008)
		var ax := (d + Vector3.UP * 0.25 - _f * 0.5).normalized()
		var h := 0.03 + 0.007 * sin(az * 0.37 + el * 1.3)
		_cono(g, pb, ax, 0.02, h, 6)


static func _cono(g: Griglia, pb: Vector3, ax: Vector3, rag: float, h: float, lati: int) -> void:
	# ciuffo a punta smussata: base, anello a metà (già stretto), punta
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := ax.cross(u)
	var base := g.v.size()
	var anelli := [[0.0, rag], [h * 0.55, rag * 0.5]]
	for an: Array in anelli:
		for k in lati + 1:
			var a := TAU * float(k) / lati
			var p := pb + (u * cos(a) + w * sin(a)) * float(an[1]) + ax * float(an[0])
			g.aggiungi(p, Vector2(float(k) / lati * 0.04, float(an[0]) * 3.0), Vector4(0.01, LISCI, 0.01, 0.0))
	var cima := g.v.size()
	g.aggiungi(pb + ax * h, Vector2(0.02, h * 3.0), Vector4(0.01, LISCI, 0.01, 0.0))
	for k in lati:
		g.quad(base + k, base + k + 1, base + lati + 2 + k, base + lati + 1 + k, pb)
		g.tri(base + lati + 1 + k, base + lati + 2 + k, cima, pb)


# tubo morbido lungo una curva (coda, ciuffi): punti, raggi, tipo per segmento
static func _tubo(g: Griglia, punti: Array, raggi: Array, tipi: Array, lati: int) -> void:
	var base := g.v.size()
	var n := punti.size()
	var lung := 0.0
	for s in n:
		var p: Vector3 = punti[s]
		var avanti: Vector3 = ((punti[mini(s + 1, n - 1)] as Vector3) - (punti[maxi(s - 1, 0)] as Vector3)).normalized()
		var u := avanti.cross(_l).normalized()
		if u.length() < 0.5:
			u = avanti.cross(_f).normalized()
		var w := avanti.cross(u)
		if s > 0:
			lung += p.distance_to(punti[s - 1])
		for k in lati + 1:
			var a := TAU * float(k) / lati
			var q := p + (u * cos(a) + w * sin(a)) * float(raggi[s])
			var m := 0.02 if s < n - 1 else 0.0005
			g.aggiungi(q, Vector2(float(k) / lati * 0.06, lung), Vector4(m, float(tipi[s]), float(raggi[s]), 0.0))
	for s in n - 1:
		for k in lati:
			var a := base + s * (lati + 1) + k
			g.quad(a, a + 1, a + lati + 2, a + lati + 1, ((punti[s] as Vector3) + (punti[s + 1] as Vector3)) * 0.5)
	# chiusura della punta
	var fine_c: Vector3 = punti[n - 1]
	var tip := g.v.size()
	g.aggiungi(fine_c + ((punti[n - 1] as Vector3) - (punti[n - 2] as Vector3)).normalized() * float(raggi[n - 1]), Vector2(0.03, lung), Vector4(0.0005, float(tipi[n - 1]), 0.0, 0.0))
	for k in lati:
		var a := base + (n - 1) * (lati + 1) + k
		g.tri(a, a + 1, tip, fine_c - ((punti[n - 1] as Vector3) - (punti[n - 2] as Vector3)).normalized() * 0.05)


# coda di cavallo: dall'alto della nuca scende dietro, con l'elastico scuro
static func _coda(g: Griglia) -> void:
	var a := _c + dir(180.0, 8.0) * (raggio(180.0, 8.0) + 0.004)
	var dietro := -_f
	var punti := [a - dietro * 0.012, a + dietro * 0.01, a + dietro * 0.03 + Vector3(0, -0.012, 0),
		a + dietro * 0.05 + Vector3(0, -0.045, 0), a + dietro * 0.058 + Vector3(0, -0.09, 0),
		a + dietro * 0.052 + Vector3(0, -0.14, 0), a + dietro * 0.04 + Vector3(0, -0.185, 0)]
	var raggi := [0.017, 0.015, 0.02, 0.022, 0.019, 0.014, 0.006]
	var tipi := [ELASTICO, ELASTICO, LUCIDI, LUCIDI, LUCIDI, LUCIDI, LUCIDI]
	_tubo(g, punti, raggi, tipi, 10)


# chignon: una palla di capelli raccolti dietro, in alto
static func _chignon(g: Griglia) -> void:
	var az := 180.0
	var el := 30.0
	var d := dir(az, el)
	var cen := _c + d * (raggio(az, el) + 0.024)
	var rag := Vector3(0.04, 0.036, 0.034)
	var anelli := 8
	var lati := 12
	var base := g.v.size()
	for j in anelli + 1:
		var v := PI * float(j) / anelli
		for k in lati + 1:
			var u := TAU * float(k) / lati
			var n := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			var p := cen + _l * (n.x * rag.x) + Vector3.UP * (n.y * rag.y) + _f * (n.z * rag.z)
			# un filo di torsione nelle ciocche
			g.aggiungi(p, Vector2(u * 0.04 + v * 0.02, v * 0.04), Vector4(0.02, LUCIDI, 0.01, 0.0))
	for j in anelli:
		for k in lati:
			var a := base + j * (lati + 1) + k
			g.quad(a, a + 1, a + lati + 2, a + lati + 1, cen)
	# elastico alla base
	_tubo(g, [cen + d * -0.02, cen + d * -0.012], [0.021, 0.021], [ELASTICO, ELASTICO], 10)


# unisce le parti (Dictionary di array di Griglia.arrays()) in una mesh sola
static func _unisci(parti: Array) -> ArrayMesh:
	var g := Griglia.new()
	for p: Dictionary in parti:
		g.unisci(p)
	var arr := g.arrays()
	var m := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = arr.v
	a[Mesh.ARRAY_NORMAL] = arr.n
	a[Mesh.ARRAY_TANGENT] = arr.t
	a[Mesh.ARRAY_TEX_UV] = arr.uv
	a[Mesh.ARRAY_CUSTOM0] = arr.c0
	a[Mesh.ARRAY_INDEX] = arr.i
	# livelli di dettaglio (meshoptimizer di Godot): da lontano in partita bastano molti meno triangoli
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, null, "", Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## griglia di vertici in costruzione: normali lisce calcolate alla fine, tangente = verso delle ciocche (dalla
## cima verso il basso, in uv: v che scende)
class Griglia:
	extends RefCounted
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var i := PackedInt32Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var _salda := {}

	func aggiungi(p: Vector3, u: Vector2, c: Vector4) -> void:
		v.append(p)
		uv.append(u)
		c0.append_array([c.x, c.y, c.z, c.w])

	# triangolo con la faccia rivolta lontano dal punto `dentro` (Vector3.INF = come sono)
	func tri(a: int, b: int, c: int, dentro: Vector3) -> void:
		if dentro != Vector3.INF:
			var nn := (v[b] - v[a]).cross(v[c] - v[a])
			var verso := (v[a] + v[b] + v[c]) / 3.0 - dentro
			if nn.dot(verso) > 0.0:   # Godot: davanti = giro orario visto da fuori
				var x := b
				b = c
				c = x
		i.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int, dentro: Vector3) -> void:
		tri(a, b, c, dentro)
		tri(a, c, d, dentro)

	func salda(m: Dictionary) -> void:
		_salda.merge(m, true)

	func unisci(p: Dictionary) -> void:
		var o := v.size()
		v.append_array(p.v)
		uv.append_array(p.uv)
		c0.append_array(p.c0)
		n.append_array(p.n)
		t.append_array(p.t)
		for k: int in p.i:
			i.append(k + o)

	func arrays() -> Dictionary:
		if i.is_empty():
			return {}
		if n.size() != v.size():
			_normali()
		return {"v": v, "uv": uv, "c0": c0, "i": i, "n": n, "t": t}

	func _normali() -> void:
		var acc := PackedVector3Array()
		acc.resize(v.size())
		for k in range(0, i.size(), 3):
			var a: int = _salda.get(i[k], i[k])
			var b: int = _salda.get(i[k + 1], i[k + 1])
			var c: int = _salda.get(i[k + 2], i[k + 2])
			var fn := (v[i[k + 2]] - v[i[k]]).cross(v[i[k + 1]] - v[i[k]])   # verso fuori (giro orario)
			acc[a] += fn
			acc[b] += fn
			acc[c] += fn
		n.resize(v.size())
		for k in v.size():
			var s: int = _salda.get(k, k)
			var nn := acc[s]
			n[k] = nn.normalized() if nn.length_squared() > 1e-20 else Vector3.UP
		# tangente: dove scende v delle uv (verso delle ciocche), resa perpendicolare alla normale
		var tg := PackedVector3Array()
		tg.resize(v.size())
		for k in range(0, i.size(), 3):
			var a := i[k]
			var b := i[k + 1]
			var c := i[k + 2]
			var e1 := v[b] - v[a]
			var e2 := v[c] - v[a]
			var d1 := uv[b] - uv[a]
			var d2 := uv[c] - uv[a]
			var det := d1.x * d2.y - d2.x * d1.y
			if absf(det) < 1e-12:
				continue
			var dir_v := (e2 * d1.x - e1 * d2.x) / det   # derivata della posizione lungo v
			for x in [a, b, c]:
				tg[x] += -dir_v
		t.resize(v.size() * 4)
		for k in v.size():
			var tt := tg[k] - n[k] * n[k].dot(tg[k])
			tt = tt.normalized() if tt.length_squared() > 1e-20 else n[k].cross(Vector3.RIGHT).normalized()
			t[k * 4] = tt.x
			t[k * 4 + 1] = tt.y
			t[k * 4 + 2] = tt.z
			t[k * 4 + 3] = 1.0
