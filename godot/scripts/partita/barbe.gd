# Barbe del giocatore come guscio sottile sopra il viso (2026-11-21, prima erano solo dipinte, piatte, a blocchi).
# Il guscio è fatto coi triangoli veri del viso del modello, spostati in fuori lungo la normale: aderisce a
# mascella, mento e labbro senza buchi. La forma (pizzetto, baffi, barba corta o piena) è un campo con segno in
# metri (> 0 dentro): la mesh tiene i triangoli vicini al bordo, lo shader dei capelli taglia per pixel dove il campo
# va sotto zero, con un po' di rumore (bordo di peli, non a scalini). L'"Ombra" resta solo dipinta (divisa.gdshader).
# Coordinate come capelli.gd: posa di riposo del modello. Le misure del viso sono quelle di barba() nello shader della
# divisa (rispetto al centro dell'occhio: y in su, ax di lato, fr in avanti dal piano degli occhi).
extends RefCounted

const ALZA_BOCCA := -0.058      # bocca rispetto agli occhi (m), come in divisa.gdshader
const STACCO := 0.0012
const DENTRO_M := -0.004        # m: triangoli tenuti anche un po' fuori dal bordo (li taglia lo shader)
const BARBA := 3.0              # tipo di ciocca nello shader (capelli.gd)
# spessore (m) per barba: 0 nessuna, 1 ombra (solo dipinta), 2 pizzetto, 3 baffi, 4 baffi e pizzetto, 5 corta, 6 piena
const SPESSORE := [0.0, 0.0, 0.0045, 0.004, 0.0042, 0.003, 0.0065]

static var _v := PackedVector3Array()   # vertici del viso (saldati: un vertice per posizione)
static var _n := PackedVector3Array()   # normali medie
static var _i := PackedInt32Array()     # triangoli del viso
static var _occhi := Vector3.ZERO
static var _f := Vector3(0, 0, 1)
static var _l := Vector3(1, 0, 0)
static var _cache := {}


## prende i triangoli del viso dalla mesh del corpo (array di surface_get_arrays) in posa di riposo
static func prepara(a: Array, occhi: Vector3, f: Vector3, l: Vector3) -> void:
	_occhi = occhi
	_f = f
	_l = l
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var fr_occhi := occhi.dot(f)
	var dove := {}   # posizione arrotondata → indice saldato
	var mappa := {}  # indice originale → indice saldato
	for t in range(0, idx.size(), 3):
		var ok := true
		for k in 3:
			var p := v[idx[t + k]]
			var q := uv[idx[t + k]]
			if p.y < occhi.y - 0.2 or p.y > occhi.y + 0.03 or absf(p.dot(l)) > 0.1 or p.dot(f) - fr_occhi < -0.12 \
					or (q.x >= 0.875 and q.y >= 0.875):
				ok = false
				break
		if not ok:
			continue
		for k in 3:
			var o := idx[t + k]
			if not mappa.has(o):
				var key := Vector3i((v[o] * 100000.0).round())
				if not dove.has(key):
					dove[key] = _v.size()
					_v.append(v[o])
					_n.append(Vector3.ZERO)
				mappa[o] = dove[key]
			_n[mappa[o]] += nr[o]
			_i.append(mappa[o])
	for k in _n.size():
		_n[k] = _n[k].normalized()


## campo con segno (m, > 0 dentro) della barba `b` nel punto p
static func campo(b: int, p: Vector3) -> float:
	var y := p.y - _occhi.y
	var ax := absf(p.dot(_l))
	var fr := p.dot(_f) - _occhi.dot(_f)
	var bocca := y - ALZA_BOCCA
	var labbra := (sqrt(pow(ax / 0.025, 2.0) + pow(bocca / 0.0078, 2.0)) - 1.0) * 0.008   # > 0 fuori dalle labbra
	var baffi := minf(minf(bocca - 0.0048 + 0.3 * maxf(ax - 0.016, 0.0), 0.0172 - bocca - 0.1 * ax), minf(0.032 - ax, fr + 0.02))
	var pizzetto := minf(minf(-0.0078 - bocca, 0.021 - ax + 0.08 * minf(bocca + 0.02, 0.0)), fr + 0.03)
	match b:
		2:
			return minf(pizzetto, labbra)
		3:
			return minf(baffi, labbra)
		4:
			return minf(maxf(baffi, pizzetto), labbra)
		5, 6:
			var piena := b == 6
			# guance: il bordo parte dall'angolo della bocca e sale in diagonale verso la basetta (naso e zigomi liberi)
			var guancia := lerpf(ALZA_BOCCA + 0.004, -0.028 if not piena else -0.02, smoothstep(0.022, 0.058, ax))
			guancia = maxf(guancia, lerpf(-0.1, 0.004 if not piena else 0.012, smoothstep(-0.045, -0.072, fr))) - y
			var orecchio := fr + (0.078 if not piena else 0.082)
			var collo := y + (0.15 if not piena else 0.165)
			var nuca := fr + 0.072 + 0.25 * (y + 0.1)
			var s := minf(minf(guancia, orecchio), minf(collo, nuca))
			return minf(maxf(s, baffi), labbra)
	return -1.0


static func _spessore(b: int, p: Vector3, s: float) -> float:
	var t: float = SPESSORE[b]
	if b == 6 or b == 2 or b == 4:   # più folta sul mento
		t += 0.0025 * smoothstep(-0.075, -0.115, p.y - _occhi.y) * smoothstep(0.03, 0.0, absf(p.dot(_l)))
	return STACCO + t * lerpf(0.15, 1.0, smoothstep(0.0, 0.01, s))


## array (come capelli.gd Griglia.arrays) della barba `b`; {} se non ha mesh (nessuna, ombra)
static func parte(b: int) -> Dictionary:
	if b <= 1 or b > 6:
		return {}
	if _cache.has(b):
		return _cache[b]
	var campi := PackedFloat32Array()
	campi.resize(_v.size())
	for k in _v.size():
		campi[k] = campo(b, _v[k])
	var nuovo := {}   # indice del viso → indice nella barba
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var ii := PackedInt32Array()
	for t in range(0, _i.size(), 3):
		if maxf(campi[_i[t]], maxf(campi[_i[t + 1]], campi[_i[t + 2]])) < DENTRO_M:
			continue
		for k in 3:
			var o := _i[t + k]
			if not nuovo.has(o):
				nuovo[o] = v.size()
				var s := campi[o]
				var sp := _spessore(b, _v[o], s)
				v.append(_v[o] + _n[o] * sp)
				n.append(_n[o])
				uv.append(Vector2(_v[o].dot(_l), _v[o].y))
				c0.append_array([s, BARBA, sp, 0.0])
			ii.append(nuovo[o])
	if ii.is_empty():
		return {}
	# tangente: verso il basso lungo il viso (i peli scendono)
	var tg := PackedFloat32Array()
	tg.resize(v.size() * 4)
	for k in v.size():
		var t := Vector3.DOWN - n[k] * n[k].dot(Vector3.DOWN)
		t = t.normalized() if t.length_squared() > 1e-8 else _f
		tg[k * 4] = t.x
		tg[k * 4 + 1] = t.y
		tg[k * 4 + 2] = t.z
		tg[k * 4 + 3] = 1.0
	var out := {"v": v, "uv": uv, "c0": c0, "i": ii, "n": n, "t": tg}
	_cache[b] = out
	return out
