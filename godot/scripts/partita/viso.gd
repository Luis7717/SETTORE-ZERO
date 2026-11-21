# Misure del viso per lo shader della divisa (2026-11-21), come le prende il web (src/athlete3d.js headFrame,
# src/body/testa.js headMarks e faceMarks, src/body/occhi.js buildEyeTable). Si calcolano una volta, dalla mesh del
# corpo in posa di riposo, e diventano parametri di shaders/divisa.gdshader:
#   - proiezione della "zona viso" del web (640 × 440 px, FACE di src/players3d.js) sul viso vero: barbe, sopracciglia
#     e labbra dipinte nel web su quella zona stanno in assets/textures/viso_maschere.png (tools/make-godot-tex.mjs);
#   - mento (dove la barba sfuma sotto la mascella), toni della pelle (guance, naso, orecchie, sotto la mascella),
#     centro e raggio degli occhi (linea delle ciglia);
#   - finestra dell'occhio: la parte del bulbo che si vede davvero (dal web: le UV del bulbo sono ruotate, e dipingere
#     l'iride al centro del tassello la nascondeva sotto le palpebre). Lo shader dipinge apertura, palpebre e iride in
#     millimetri dentro questa finestra, per le 6 forme dell'editor.
# Coordinate: posa di riposo del modello (come CUSTOM0 della divisa), y in su, +z avanti (come il web).
extends RefCounted

const OCCHI_UV := 0.875          # tassello degli occhi nelle UV (896/1024, come EYE_PX del web)
const RES := 128                 # celle per lato del tassello per cercare la finestra visibile (web: 256, passo 4)
const PASSO := 2                 # passo della prova di visibilità (celle)
const VERSO := Vector3(0, -0.1, 1)   # verso la camera (VIEW_DIR del web)
const VICINO := 0.03             # m: triangoli della testa che possono coprire il bulbo
const FACE_X := 320.0            # zona viso del web (FACE di src/players3d.js)
const FACE_EYE_Y := 222.0
const EAR_X := 0.064             # attaccatura delle orecchie (src/body/testa.js)

## misure (Dictionary): proiezione, mento, toni, occhi, finestra; vuoto prima di misura()
static var dati := {}


## a = surface_get_arrays della mesh del corpo; testa_w = peso dell'osso Head per vertice; c = centro della testa
## (media dei vertici della testa, come il web); occhio_l / occhio_r = centri degli occhi
static func misura(a: Array, testa_w: PackedFloat32Array, c: Vector3, occhio_l: Vector3, occhio_r: Vector3) -> Dictionary:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var occhio := PackedByteArray()
	occhio.resize(v.size())
	for i in v.size():
		occhio[i] = 1 if uv[i].x >= OCCHI_UV and uv[i].y >= OCCHI_UV else 0
	# mento per la proiezione (LM.chinY): il punto più basso della testa davanti al centro
	var mento_y := INF
	var cima := -INF
	for i in v.size():
		if testa_w[i] > 0.5 and occhio[i] == 0:
			cima = maxf(cima, v[i].y)
			if v[i].z > c.z:
				mento_y = minf(mento_y, v[i].y)
	# mento vero (headMarks): il punto più basso della linea di mezzo davanti (il collo sotto il mento sta più indietro)
	var collo_z := -INF
	for i in v.size():
		if absf(v[i].x) < 0.012 and v[i].y > cima - 0.29 and v[i].y < cima - 0.25:
			collo_z = maxf(collo_z, v[i].z)
	var mento := INF
	for i in v.size():
		if testa_w[i] > 0.3 and absf(v[i].x) < 0.012 and v[i].z > collo_z + 0.025 and v[i].y < cima - 0.12:
			mento = minf(mento, v[i].y)
	if mento == INF:
		mento = mento_y
	var occhi := (occhio_l + occhio_r) * 0.5
	var eye_dx := absf(occhio_l.x - occhio_r.x) * 0.5
	var fx := 36.0 / eye_dx
	var fy := 52.0 / maxf(0.03, (occhi.y - mento_y) * 0.58)
	dati = {
		# u = FACE_X + (x − mid_x) · fx, v = FACE_EYE_Y + (eye_y − y) · fy (px della zona viso del web)
		"proiezione": Vector4((occhio_l.x + occhio_r.x) * 0.5, occhi.y, fx, fy),
		"mento": mento,
		# toni: guance (x, y dagli occhi, raggio), naso (y, raggio), orecchie (x, z)
		"guance": Vector4(eye_dx * 1.15, -0.032, 0.018, -0.03),
		"naso_orecchie": Vector4(0.012, EAR_X + 0.006, occhi.z - 0.06, eye_dx),
		"occhio": Vector4(occhio_l.x, occhio_l.y, occhio_l.z, _raggio_apertura(v, occhio, occhio_l)),
	}
	var fin := _finestra(v, uv, idx, occhio)
	dati["occhio_f"] = fin[0]
	dati["occhio_finestra"] = fin[1]
	return dati


## mette le misure nel materiale della divisa
static func applica(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("viso_proiezione", dati.proiezione)
	mat.set_shader_parameter("viso_mento", dati.mento)
	mat.set_shader_parameter("viso_guance", dati.guance)
	mat.set_shader_parameter("viso_naso_orecchie", dati.naso_orecchie)
	mat.set_shader_parameter("viso_occhio", dati.occhio)
	mat.set_shader_parameter("occhio_f", dati.occhio_f)
	mat.set_shader_parameter("occhio_finestra", dati.occhio_finestra)


# raggio dell'apertura dell'occhio: distanza dal centro dei vertici della testa più vicini (faceMarks del web)
static func _raggio_apertura(v: PackedVector3Array, occhio: PackedByteArray, c: Vector3) -> float:
	var ds: Array = []
	for i in v.size():
		if occhio[i] == 0:
			var d := v[i].distance_to(c)
			if d < 0.03:
				ds.append(d)
	ds.sort()
	return ds[mini(ds.size() - 1, 3)] if not ds.is_empty() else 0.012


# finestra visibile del bulbo sinistro (buildEyeTable di src/body/occhi.js): [F = punto più avanti del bulbo,
# Vector4(cx, cy, W, H) in mm rispetto a F: centro, semilarghezza, semialtezza]
static func _finestra(v: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array, occhio: PackedByteArray) -> Array:
	var front := -1
	for i in v.size():
		if occhio[i] == 1 and v[i].x > 0.0 and (front < 0 or v[i].z > v[front].z):
			front = i
	if front < 0:
		return [Vector3(0.034, 1.7, 0.08), Vector4(0, 0, 13, 5)]
	var F := v[front]
	# UV del bulbo → punto sul bulbo, per ogni cella del tassello
	var pos := PackedVector3Array()
	pos.resize(RES * RES)
	var ha := PackedByteArray()
	ha.resize(RES * RES)
	var sc := float(RES) / 128.0
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var d := idx[t + 2]
		if occhio[a] == 0 or occhio[b] == 0 or occhio[d] == 0 or v[a].x <= 0.0:
			continue
		var pa := (uv[a] * 1024.0 - Vector2(896, 896)) * sc
		var pb := (uv[b] * 1024.0 - Vector2(896, 896)) * sc
		var pd := (uv[d] * 1024.0 - Vector2(896, 896)) * sc
		var det := (pb.y - pd.y) * (pa.x - pd.x) + (pd.x - pb.x) * (pa.y - pd.y)
		if absf(det) < 1e-9:
			continue
		var x0 := maxi(0, int(floor(minf(pa.x, minf(pb.x, pd.x)))))
		var x1 := mini(RES - 1, int(ceil(maxf(pa.x, maxf(pb.x, pd.x)))))
		var y0 := maxi(0, int(floor(minf(pa.y, minf(pb.y, pd.y)))))
		var y1 := mini(RES - 1, int(ceil(maxf(pa.y, maxf(pb.y, pd.y)))))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var px := x + 0.5
				var py := y + 0.5
				var l1 := ((pb.y - pd.y) * (px - pd.x) + (pd.x - pb.x) * (py - pd.y)) / det
				var l2 := ((pd.y - pa.y) * (px - pd.x) + (pa.x - pd.x) * (py - pd.y)) / det
				var l3 := 1.0 - l1 - l2
				if l1 < -0.02 or l2 < -0.02 or l3 < -0.02:
					continue
				var i := y * RES + x
				ha[i] = 1
				pos[i] = v[a] * l1 + v[b] * l2 + v[d] * l3
	# triangoli della testa vicino all'occhio (palpebre, orbita)
	var tris := PackedVector3Array()
	for t in range(0, idx.size(), 3):
		var ok := true
		for k in 3:
			var q := idx[t + k]
			if occhio[q] == 1 or v[q].distance_to(F) >= VICINO:
				ok = false
				break
		if ok:
			tris.append_array([v[idx[t]], v[idx[t + 1]], v[idx[t + 2]]])
	var dir := VERSO.normalized()
	var vis: Array = []   # [lx, ly] in mm da F
	for y in range(0, RES, PASSO):
		for x in range(0, RES, PASSO):
			var i := y * RES + x
			if ha[i] == 0 or pos[i].z < F.z - 0.008:
				continue
			if not _colpisce(pos[i], dir, tris):
				vis.append(Vector2(pos[i].x - F.x, pos[i].y - F.y) * 1000.0)
	if vis.is_empty():
		return [F, Vector4(0, 0, 13, 5)]
	var xa := INF
	var xb := -INF
	for q: Vector2 in vis:
		xa = minf(xa, q.x)
		xb = maxf(xb, q.x)
	var cx := (xa + xb) * 0.5
	var W := (xb - xa) * 0.5
	var tops: Array = []
	var bots: Array = []
	var s := -0.5
	while s <= 0.5:
		var top := -INF
		var bot := INF
		for q: Vector2 in vis:
			if absf(q.x - (cx + s * W)) < W * 0.07:
				top = maxf(top, q.y)
				bot = minf(bot, q.y)
		if top > bot:
			tops.append(top)
			bots.append(bot)
		s += 0.125
	tops.sort()
	bots.sort()
	var tm: float = tops[tops.size() >> 1] if not tops.is_empty() else 0.0
	var bm: float = bots[bots.size() >> 1] if not bots.is_empty() else 0.0
	return [F, Vector4(cx, (tm + bm) * 0.5, W, maxf(2.0, (tm - bm) * 0.5))]


# raggio contro triangoli (Möller–Trumbore): vero se colpisce davanti all'origine
static func _colpisce(o: Vector3, d: Vector3, tris: PackedVector3Array) -> bool:
	for k in range(0, tris.size(), 3):
		var e1 := tris[k + 1] - tris[k]
		var e2 := tris[k + 2] - tris[k]
		var h := d.cross(e2)
		var det := e1.dot(h)
		if absf(det) < 1e-14:
			continue
		var f := 1.0 / det
		var s := o - tris[k]
		var u := f * s.dot(h)
		if u < 0.0 or u > 1.0:
			continue
		var q := s.cross(e1)
		var w := f * d.dot(q)
		if w < 0.0 or u + w > 1.0:
			continue
		if f * e2.dot(q) > 1e-5:
			return true
	return false
