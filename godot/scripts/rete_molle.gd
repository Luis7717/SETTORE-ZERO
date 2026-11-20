# Rete di una porta con una molla per ogni nodo (porting libero della rete di src/props.js, che la muove a pezzi):
# quattro teli (fondo inclinato, tetto, due fianchi), ognuno una griglia di nodi col bordo fermo (attaccato a pali,
# traversa, sostegni e terreno). Ogni nodo si sposta solo lungo la normale del suo telo (verso fuori) e sente la molla
# verso il riposo, i quattro vicini (il telo teso) e l'attrito. Il pallone spinge i nodi che tocca: dove entra il telo
# si gonfia attorno a lui (al massimo GONFIA_MAX), quando esce ondeggia e torna piano.
# Gli spostamenti finiscono in una piccola texture (un float per nodo, i teli affiancati) che shaders/rete.gdshader
# legge nei vertici (UV2 = posto del vertice nella texture): la mesh resta fine, la fisica gira su pochi nodi.
# Logica pura (niente nodi): provata in tests/test_rete.gd. Coordinate del gioco (x, y, h) del campo NON girato
# (scripts/campo.gd): la porta sta a y = lato · 50.
extends RefCounted

const Coord := preload("res://scripts/coord.gd")

const PALO_R := 0.06
const RETE_FONDO := 2.0
const RETE_ALTO := 1.0
const GONFIA_MAX := 0.45       # il telo si gonfia al massimo così (m)
const K_TESO := 95.0           # 1/s²: quanto i vicini si tirano (telo teso: le onde corrono)
const K_RIPOSO := 28.0         # 1/s²: molla verso la forma di riposo
const ATTRITO := 4.2           # 1/s
const CAMPANA := 0.6          # m²: larghezza della zona spinta dal pallone attorno al punto di contatto
const SPINTA := 0.22           # quanto della velocità del pallone passa al telo al primo contatto
const FERMA := 1e-4            # sotto questo movimento la rete dorme (niente conti né texture)
const PASSO_MAX := 1.0 / 60.0  # passi di al massimo questo tempo (stabile)

# teli: nome, nodi lungo u e lungo v (bordo compreso)
const TELI := [["fondo", 17, 7], ["tetto", 17, 4], ["fianco_s", 6, 7], ["fianco_d", 6, 7]]

var lato := 1.0
var larghezza := 0             # della texture (nodi affiancati)
var altezza := 0
var img: Image
var tex: ImageTexture
var _teli: Array = []          # {nu, nv, off, a, b, c, d (angoli, gioco), n (normale fuori, gioco)}
var _d := PackedFloat32Array() # spostamento di ogni nodo (indice = y · larghezza + x della texture)
var _v := PackedFloat32Array()
var _pos := PackedVector3Array()   # posizione di riposo di ogni nodo (gioco)
var _tocco := false            # il pallone toccava la rete al passo prima
var dorme := true


func _init(lato_: float) -> void:
	lato = 1.0 if lato_ > 0.0 else -1.0
	var hx := Coord.GW / 2.0 + PALO_R
	var gh := Coord.GH + PALO_R
	var gy := lato * Coord.HL
	var y0 := gy + lato * PALO_R
	var yf := gy + lato * RETE_FONDO
	var ya := gy + lato * RETE_ALTO
	var angoli := {
		"fondo": [Vector3(-hx, yf, 0.0), Vector3(hx, yf, 0.0), Vector3(hx, ya, gh), Vector3(-hx, ya, gh)],
		"tetto": [Vector3(-hx, y0, gh), Vector3(hx, y0, gh), Vector3(hx, ya, gh), Vector3(-hx, ya, gh)],
		"fianco_s": [Vector3(-hx, y0, 0.0), Vector3(-hx, yf, 0.0), Vector3(-hx, ya, gh), Vector3(-hx, y0, gh)],
		"fianco_d": [Vector3(hx, y0, 0.0), Vector3(hx, yf, 0.0), Vector3(hx, ya, gh), Vector3(hx, y0, gh)],
	}
	var normali := {
		"fondo": Vector3(0.0, lato * gh, RETE_FONDO - RETE_ALTO).normalized(),
		"tetto": Vector3(0.0, 0.0, 1.0),
		"fianco_s": Vector3(-1.0, 0.0, 0.0),
		"fianco_d": Vector3(1.0, 0.0, 0.0),
	}
	var off := 0
	for t: Array in TELI:
		var q: Array = angoli[t[0]]
		_teli.append({"nome": t[0], "nu": t[1], "nv": t[2], "off": off, "a": q[0], "b": q[1], "c": q[2], "d": q[3], "n": normali[t[0]]})
		off += t[1]
		altezza = maxi(altezza, t[2])
	larghezza = off
	_d.resize(larghezza * altezza)
	_v.resize(larghezza * altezza)
	_pos.resize(larghezza * altezza)
	for tl: Dictionary in _teli:
		for j in tl.nv:
			for i in tl.nu:
				_pos[j * larghezza + tl.off + i] = _punto(tl, float(i) / (tl.nu - 1), float(j) / (tl.nv - 1))
	img = Image.create_empty(larghezza, altezza, false, Image.FORMAT_RF)
	tex = ImageTexture.create_from_image(img)


## telo di nome `nome` (fondo, tetto, fianco_s, fianco_d): angoli a, b, c, d, normale n (gioco), nodi nu × nv, off
func telo(nome: String) -> Dictionary:
	for t: Dictionary in _teli:
		if t.nome == nome:
			return t
	return {}


## posto nella texture (UV2) del punto (u, v) del telo (0..1 lungo a→b e a→d): centro del texel del nodo
func uv2(nome: String, u: float, v: float) -> Vector2:
	var t := telo(nome)
	return Vector2((t.off + u * (t.nu - 1) + 0.5) / larghezza, (v * (t.nv - 1) + 0.5) / altezza)


## spostamento (m, verso fuori) del nodo più vicino al punto (u, v) del telo
func spostamento(nome: String, u: float, v: float) -> float:
	var t := telo(nome)
	return _d[roundi(v * (t.nv - 1)) * larghezza + t.off + roundi(u * (t.nu - 1))]


## spostamento del fondo (m) nel punto davanti al pallone (bilineare tra i nodi): fin dove può stare il pallone
func gonfiore_in(palla: Vector3) -> float:
	var t: Dictionary = _teli[0]
	var a: Vector3 = t.a
	var nrm: Vector3 = t.n
	var proj := palla - nrm * (palla - a).dot(nrm)
	var ab: Vector3 = (t.b as Vector3) - a
	var ad: Vector3 = (t.d as Vector3) - a
	var fu: float = clampf((proj - a).dot(ab) / ab.length_squared(), 0.0, 1.0) * (t.nu - 1)
	var fv: float = clampf((proj - a).dot(ad) / ad.length_squared(), 0.0, 1.0) * (t.nv - 1)
	var i := mini(int(fu), t.nu - 2)
	var j := mini(int(fv), t.nv - 2)
	var x: float = fu - i
	var y: float = fv - j
	var k: int = j * larghezza + t.off + i
	var basso := lerpf(_d[k], _d[k + 1], x)
	var alto := lerpf(_d[k + larghezza], _d[k + larghezza + 1], x)
	return lerpf(basso, alto, y)


## massimo spostamento della rete adesso (m)
func gonfiore() -> float:
	var mx := 0.0
	for x in _d:
		mx = maxf(mx, absf(x))
	return mx


## un passo: dt = tempo di gioco; palla = centro del pallone (gioco, campo non girato), r = raggio,
## vel = velocità del pallone (m/s), dentro = il pallone è nello specchio della porta o nella rete.
## Ritorna true se la texture è cambiata
func passo(dt: float, palla: Vector3, r: float, vel: float, dentro: bool) -> bool:
	if dt <= 0.0:
		return false
	var tocca := dentro and _vicina(palla, r)
	if dorme and not tocca:
		return false
	dorme = false
	var n := maxi(1, ceili(dt / PASSO_MAX))
	var h := dt / n
	var primo := tocca and not _tocco
	for k in n:
		_integra(h)
		if tocca:
			_contatto(palla, r, vel if primo and k == 0 else 0.0)
	_tocco = tocca
	var mosso := 0.0
	for i in _d.size():
		mosso = maxf(mosso, absf(_d[i]) + absf(_v[i]) * 0.05)
	if mosso < FERMA and not tocca:
		_d.fill(0.0)
		_v.fill(0.0)
		dorme = true
	img.set_data(larghezza, altezza, false, Image.FORMAT_RF, _d.to_byte_array())
	tex.update(img)
	return true


# ---------------------------------------------------------------- conti
func _punto(t: Dictionary, u: float, v: float) -> Vector3:
	return (t.a as Vector3).lerp(t.b, u).lerp((t.d as Vector3).lerp(t.c, u), v)


# il pallone è a meno di r da almeno un telo (dal lato di dentro)?
func _vicina(p: Vector3, r: float) -> bool:
	for t: Dictionary in _teli:
		var s: float = (p - (t.a as Vector3)).dot(t.n)
		if s + r > 0.0 and s < GONFIA_MAX + 1.5:
			return true
	return false


func _integra(h: float) -> void:
	var w := larghezza
	for t: Dictionary in _teli:
		var off: int = t.off
		for j in range(1, t.nv - 1):
			var riga := j * w + off
			for i in range(1, t.nu - 1):
				var k := riga + i
				var d := _d[k]
				var lap := _d[k - 1] + _d[k + 1] + _d[k - w] + _d[k + w] - 4.0 * d
				var v := _v[k] + (K_TESO * lap - K_RIPOSO * d - ATTRITO * _v[k]) * h
				_v[k] = v
				_d[k] = d + v * h


# il pallone tiene il telo gonfio attorno a sé: ogni nodo vicino almeno a `pen` (quanto il pallone supera la forma
# di riposo, al massimo GONFIA_MAX) per una campana attorno al punto di contatto; al primo contatto anche una spinta
func _contatto(p: Vector3, r: float, vel: float) -> void:
	var w := larghezza
	for t: Dictionary in _teli:
		var nrm: Vector3 = t.n
		var s := (p - (t.a as Vector3)).dot(nrm)
		var pen := minf(s + r, GONFIA_MAX)
		if pen <= 0.0:
			continue
		var proj := p - nrm * s
		var off: int = t.off
		for j in range(1, t.nv - 1):
			for i in range(1, t.nu - 1):
				var k := j * w + off + i
				var q := _pos[k]
				var rho2 := (q - proj).length_squared()
				if rho2 > CAMPANA * 6.0:
					continue
				var f := exp(-rho2 / CAMPANA)
				var req := pen * f
				if vel > 0.0:
					_v[k] += vel * SPINTA * f
				if _d[k] < req:
					_d[k] = req
					_v[k] = maxf(_v[k], 0.0)
