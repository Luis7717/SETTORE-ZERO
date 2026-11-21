# Capelli del giocatore (2026-11-21, seconda versione): porting di src/hair3d.js, i capelli del gioco web.
# Ogni taglio è fatto di "calotte" lisce appoggiate su una base che avvolge la testa (per ogni direzione il raggio
# massimo della testa vera, allargato e ammorbidito: makeRadialBase), con il bordo che segue una curva morbida
# (l'attaccatura), normali lisce e un risvolto interno scuro che chiude il bordo. Pezzi in più: coda (tubo curvo con
# l'elastico), chignon (tornito), punte (cunei), cresta (striscia sopra la testa rasata). Stesse forme e numeri del web.
# La tinta è quella del web (paintHairTex): assets/textures/capelli_tinta.png, una cella per taglio, mescolata per
# giocatore da shaders/capelli.gdshader (colore dei capelli e della pelle per istanza, un materiale per tutti).
# Sotto i capelli la pelle prende la tinta della cute (scalpPaint del web) in shaders/divisa.gdshader, con lo stesso
# riferimento della testa (applica()).
#
# Riferimento della testa (headFrame di src/athlete3d.js): centro all'altezza delle sopracciglia, un po' inclinato
# all'indietro. Coordinate locali in raggi R: x = destra, y = su, z = avanti; el/az in gradi (az 0 = viso, 90 = destra).
# La mesh va sotto l'osso "Head" con la trasformazione di legame della pelle (attacca()), segue la testa come la pelle.
extends RefCounted

const SHADER := preload("res://shaders/capelli.gdshader")
const TINTA := preload("res://assets/textures/capelli_tinta.png")

const N_TAGLI := 17
const HAIR_TILT := 10.0          # gradi: inclinazione all'indietro del riferimento dei capelli
const HAIR_DROP := -0.35         # centro spostato (in raggi; negativo = più in alto)
const RB_STEP := 5               # gradi per cella della base radiale
# cella della tinta (come tools/make-godot-tex.mjs): zona 200 × 92 del web, margine, scala, colonne
const TINTA_W := 200.0
const TINTA_H := 92.0
const TINTA_PAD := 8.0
const TINTA_SCALA := 2.0
const TINTA_COLONNE := 4

# ---------------------------------------------------------------- dati dei tagli (HAIR di src/hair3d.js)
const SHORT := [Vector2(0, 31), Vector2(45, 25), Vector2(85, 8), Vector2(105, 5), Vector2(180, -20)]
const BUZZ := [Vector2(0, 30), Vector2(45, 24), Vector2(85, 8), Vector2(105, 5), Vector2(180, -20)]
const CODA := [Vector2(0, 30), Vector2(45, 24), Vector2(85, 7), Vector2(105, 5), Vector2(180, -18)]
## per taglio: line (attaccatura, nodi [|az|, el]), cols, rows, hang/drop/flare (tagli lunghi che cadono),
## taper (spessore al bordo, larghezza), part (riga), extra (tail, bun, spikes), strip (cresta), buzz (rasato dipinto)
const HAIR := [
	{},                                                                                          # 0 calvo
	{"buzz": BUZZ},                                                                              # 1 rasato
	{"line": SHORT, "taper": Vector2(0.5, 0.2)},                                                 # 2 corti
	{"line": [Vector2(0, 33), Vector2(45, 27), Vector2(85, 9), Vector2(105, 6), Vector2(180, -18)], "taper": Vector2(0.5, 0.2)},  # 3 spazzola
	{"line": SHORT},                                                                             # 4 ciuffo
	{"line": [Vector2(0, 28), Vector2(45, 22), Vector2(85, 6), Vector2(105, 3), Vector2(180, -20)], "part": -38.0, "cols": 44},  # 5 riga
	{"buzz": BUZZ, "strip": true},                                                               # 6 cresta
	{"line": SHORT, "extra": "spikes"},                                                          # 7 a punte
	{"line": [Vector2(0, 27), Vector2(45, 21), Vector2(85, 2), Vector2(110, -2), Vector2(180, -26)], "cols": 40, "rows": 12, "taper": Vector2(0.55, 0.3)},  # 8 ricci
	{"line": [Vector2(0, 23), Vector2(45, 17), Vector2(85, -6), Vector2(110, -9), Vector2(180, -30)], "cols": 40, "rows": 12, "taper": Vector2(0.25, 0.4)},  # 9 afro
	{"line": [Vector2(0, 19), Vector2(34, 18), Vector2(64, -32), Vector2(120, -36), Vector2(180, -38)], "hang": -4.0, "drop": 1.0, "flare": 0.1, "cols": 44, "taper": Vector2(0.45, 0.25)},  # 10 caschetto
	{"line": [Vector2(0, 26), Vector2(30, 22), Vector2(66, -44), Vector2(120, -62), Vector2(180, -70)], "hang": -4.0, "drop": 1.15, "flare": 0.14, "cols": 44, "rows": 11, "part": 0.0, "taper": Vector2(0.5, 0.2)},  # 11 lunghi
	{"line": CODA, "extra": "tail"},                                                             # 12 coda
	{"line": CODA, "extra": "bun"},                                                              # 13 chignon
	{"line": [Vector2(0, 26), Vector2(30, 22), Vector2(66, -38), Vector2(120, -56), Vector2(180, -62)], "hang": -4.0, "drop": 1.1, "flare": 0.05, "cols": 60, "rows": 10, "taper": Vector2(0.7, 0.15)},  # 14 treccine
	{"line": [Vector2(0, 4), Vector2(32, 6), Vector2(68, -6), Vector2(100, -8), Vector2(180, -22)], "cols": 44, "taper": Vector2(0.6, 0.15)},  # 15 frangia
	{"line": [Vector2(0, 37), Vector2(45, 30), Vector2(85, 10), Vector2(105, 7), Vector2(180, -18)], "taper": Vector2(0.5, 0.25)},  # 16 indietro
]
const SHELL_COLS := 40
const SHELL_ROWS := 9
const SKIRT_IN := -0.06          # il risvolto del bordo entra sotto la base (in R)
const TUCK := 0.07               # il bordo rientra verso la testa: niente visiera
const BORDO_FUORI := 0.75        # quanto la normale del bordo si gira verso fuori (niente riga buia all'attaccatura)
const TEX_SHELL := Vector2(0.01, 0.77)
const TEX_TOP := 0.02
const TEX_EDGE := 0.86
const TEX_UNDER := 0.95
const TEX_EXTRA := Vector2(0.84, 0.98)
const LUMP_K := [Vector3(0.62, 0.55, 0.56), Vector3(-0.7, 0.3, 0.65), Vector3(0.2, -0.85, 0.48), Vector3(0.5, 0.45, -0.74), Vector3(-0.3, -0.4, -0.86), Vector3(-0.85, 0.5, -0.1)]
const AFRO_C := Vector3(0, 0.2, -0.2)
const AFRO_R := 1.24
const AFRO_MIN := 0.17
const STRIP_W := 17.0
const STRIP_FROM := 34.0
const STRIP_TO := 200.0
const TAIL_T := [0.0, 0.07, 0.13, 0.22, 0.34, 0.48, 0.62, 0.76, 0.88, 0.96, 1.0]
const BUN := [Vector3(0.16, -0.08, 0), Vector3(0.165, 0.02, 0.08), Vector3(0.155, 0.07, 0.12), Vector3(0.25, 0.11, 0.22), Vector3(0.32, 0.24, 0.42), Vector3(0.3, 0.38, 0.6), Vector3(0.22, 0.48, 0.78), Vector3(0.1, 0.54, 0.92), Vector3(0, 0.555, 1)]
const SPIKES := [[84, 0, 0.35], [68, -26, 0.35], [68, 26, 0.35], [66, 90, 0.29], [66, -90, 0.29], [70, 160, 0.26], [62, 135, 0.25], [62, -135, 0.25],
	[50, 0, 0.32], [48, -45, 0.29], [48, 45, 0.29], [44, 110, 0.22], [44, -110, 0.22], [46, 180, 0.20], [34, -20, 0.23], [34, 20, 0.23], [30, 70, 0.17], [30, -70, 0.17]]

## riferimento della testa: {c, up, fwd, right, R} (posa di riposo)
static var testa := {}
static var _grid := PackedFloat32Array()   # base radiale (NE × NA)
static var _cache := {}                    # taglio → ArrayMesh (null per calvo e rasato)
static var _materiale: ShaderMaterial


# ---------------------------------------------------------------- riferimento della testa e base radiale
## misura la testa (una volta): a = surface_get_arrays del corpo, testa_w = peso dell'osso Head per vertice.
## Ritorna {c (media dei punti della testa), occhio_l, occhio_r} per le misure del viso.
static func prepara(a: Array, testa_w: PackedFloat32Array) -> Dictionary:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var c := Vector3.ZERO
	var el := Vector3.ZERO
	var er := Vector3.ZERO
	var nh := 0
	var nl := 0
	var nr := 0
	var pts := PackedVector3Array()
	for i in v.size():
		if uv[i].x >= 0.875 and uv[i].y >= 0.875:
			if v[i].x > 0.0:
				el += v[i]
				nl += 1
			else:
				er += v[i]
				nr += 1
			continue
		if testa_w[i] > 0.5:
			c += v[i]
			nh += 1
			pts.append(v[i])
	c /= maxf(nh, 1)
	el /= maxf(nl, 1)
	er /= maxf(nr, 1)
	var occhi := (el + er) * 0.5
	var fwd0 := Vector3(occhi.x - c.x, 0.0, occhi.z - c.z).normalized()
	var right := Vector3.UP.cross(fwd0).normalized()
	var up := Vector3.UP.rotated(right, -deg_to_rad(HAIR_TILT))
	var fwd := right.cross(up).normalized()
	var r0m := _mediana_dist(pts, c)
	var hc := c + up * (-HAIR_DROP * r0m) + fwd * (-0.006)
	var R := _mediana_dist(pts, hc)
	testa = {"c": hc, "up": up, "fwd": fwd, "right": right, "R": R}
	# base dei capelli: testa tonda, senza orecchie (sporgono di lato e gonfierebbero tutti i tagli) e senza viso
	var libera := PackedVector3Array()
	for p in pts:
		var d := p - hc
		var lx := absf(d.dot(right)) / R
		var ly := d.dot(up) / R
		var lz := d.dot(fwd) / R
		if (lx > 0.72 and ly < 0.3 and ly > -0.75 and lz < 0.35 and lz > -0.45) or (ly < -0.1 and lz > 0.2) or (ly < -0.3 and lz > -0.25):
			continue
		libera.append(p)
	_base_radiale(libera)
	_cache.clear()
	_materiale = ShaderMaterial.new()
	_materiale.shader = SHADER
	_materiale.set_shader_parameter("tinta", TINTA)
	return {"c": c, "occhio_l": el, "occhio_r": er}


## riferimento della testa nel materiale della divisa (tinta della cute sotto i capelli)
static func applica(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("cap_c", testa.c)
	mat.set_shader_parameter("cap_up", testa.up)
	mat.set_shader_parameter("cap_fwd", testa.fwd)
	mat.set_shader_parameter("cap_right", testa.right)


static func _mediana_dist(pts: PackedVector3Array, c: Vector3) -> float:
	var d := PackedFloat32Array()
	for p in pts:
		d.append(p.distance_to(c))
	d.sort()
	return d[d.size() >> 1] if d.size() > 0 else 0.1


static func _cella(e: int, a: int) -> int:
	return e * (360 / RB_STEP) + posmod(a, 360 / RB_STEP)


# makeRadialBase di src/hair3d.js: raggio massimo per cella elevazione × giro, celle vuote dai vicini, allargata di
# una cella e ammorbidita due volte
static func _base_radiale(pts: PackedVector3Array) -> void:
	var NE := 180 / RB_STEP + 1
	var NA := 360 / RB_STEP
	var g := PackedFloat32Array()
	g.resize(NE * NA)
	g.fill(-1.0)
	var c: Vector3 = testa.c
	var R: float = testa.R
	for p in pts:
		var l := locale(p)
		var r := l.length()
		if r < 1e-6:
			continue
		var e := rad_to_deg(asin(clampf(l.y / r, -1.0, 1.0)))
		var az := rad_to_deg(atan2(l.x, l.z))
		var i := _cella(roundi((e + 90.0) / RB_STEP), roundi((az + 180.0) / RB_STEP))
		if r > g[i]:
			g[i] = r
	for it in 200:
		var add: Array = []
		var vuote := 0
		for e in NE:
			for a in NA:
				var i := _cella(e, a)
				if g[i] >= 0.0:
					continue
				vuote += 1
				var s := 0.0
				var n := 0
				for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ee := e + dd.x
					if ee < 0 or ee >= NE:
						continue
					var q := g[_cella(ee, a + dd.y)]
					if q >= 0.0:
						s += q
						n += 1
				if n > 0:
					add.append(i)
					add.append(s / n)
		for k in range(0, add.size(), 2):
			g[add[k]] = add[k + 1]
		if vuote == 0:
			break
	for i in g.size():
		if g[i] < 0.0:
			g[i] = 1.0
	_grid = g
	_passa(true)
	_passa(false)
	_passa(false)


static func _passa(massimo: bool) -> void:
	var NE := 180 / RB_STEP + 1
	var NA := 360 / RB_STEP
	var out := PackedFloat32Array()
	out.resize(_grid.size())
	for e in NE:
		for a in NA:
			var m := -INF
			var s := 0.0
			for de in range(-1, 2):
				var ee := clampi(e + de, 0, NE - 1)
				for da in range(-1, 2):
					var q := _grid[_cella(ee, a + da)]
					m = maxf(m, q)
					s += q
			out[_cella(e, a)] = m if massimo else s / 9.0
	_grid = out


## raggio della base (in R) nella direzione L (locale, non serve normalizzata)
static func base(L: Vector3) -> float:
	var NE := 180 / RB_STEP + 1
	var r := L.length()
	if r == 0.0:
		r = 1.0
	var el := rad_to_deg(asin(clampf(L.y / r, -1.0, 1.0)))
	var az := rad_to_deg(atan2(L.x, L.z))
	var fe := clampf((el + 90.0) / RB_STEP, 0.0, NE - 1.001)
	var fa := (az + 180.0) / RB_STEP
	var e0 := int(floor(fe))
	var a0 := int(floor(fa))
	var te := fe - e0
	var ta := fa - a0
	var e1 := mini(NE - 1, e0 + 1)
	var lo := lerpf(_grid[_cella(e0, a0)], _grid[_cella(e0, a0 + 1)], ta)
	var hi := lerpf(_grid[_cella(e1, a0)], _grid[_cella(e1, a0 + 1)], ta)
	return 1.015 * lerpf(lo, hi, te)


## punto della posa di riposo → coordinate locali della testa (in R)
static func locale(p: Vector3) -> Vector3:
	var d: Vector3 = p - testa.c
	return Vector3(d.dot(testa.right), d.dot(testa.up), d.dot(testa.fwd)) / float(testa.R)


## coordinate locali della testa (in R) → posa di riposo
static func mondo(l: Vector3) -> Vector3:
	return testa.c + (testa.right * l.x + testa.up * l.y + testa.fwd * l.z) * float(testa.R)


# ---------------------------------------------------------------- mesh dei tagli
## mesh del taglio (null per calvo e rasato: solo dipinti), costruita alla prima richiesta e condivisa
static func mesh_per(taglio: int) -> ArrayMesh:
	taglio = clampi(taglio, 0, N_TAGLI - 1)
	if _cache.has(taglio):
		return _cache[taglio]
	var pc := pezzi(taglio)
	var m: ArrayMesh = null
	if not pc.ind.is_empty():
		m = _mesh(taglio, pc)
	_cache[taglio] = m
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
	var osso := scheletro.find_bone("Head")
	mi.transform = scheletro.get_bone_global_rest(osso).affine_inverse()
	if pelle != null:
		for i in pelle.get_bind_count():
			if pelle.get_bind_name(i) == "Head" or pelle.get_bind_bone(i) == osso:
				mi.transform = pelle.get_bind_pose(i)
				break
	att.add_child(mi)
	return mi


# geometria nello spazio della mesh: posizioni e normali dalla testa, uv nella cella del taglio, uv2 = uv del web
static func _mesh(taglio: int, pc: Pezzi) -> ArrayMesh:
	var n: int = pc.pos.size()
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	v.resize(n)
	nr.resize(n)
	uv.resize(n)
	uv2.resize(n)
	var cx := float(taglio % TINTA_COLONNE)
	var cy := float(taglio / TINTA_COLONNE)
	var cw := (TINTA_W + 2.0 * TINTA_PAD) * TINTA_SCALA
	var ch := (TINTA_H + 2.0 * TINTA_PAD) * TINTA_SCALA
	var atl := Vector2(cw * TINTA_COLONNE, ch * ceili(float(N_TAGLI) / TINTA_COLONNE))
	for i in n:
		var p: Vector3 = pc.pos[i]
		var q: Vector3 = pc.nrm[i]
		var t: Vector2 = pc.uv[i]
		v[i] = mondo(p)
		# bordo della calotta e risvolto (rientrano verso la testa): normale girata verso fuori, se no il bordo
		# viene buio e sulla fronte si vede una riga scura
		if t.x < TEX_EXTRA.x - 0.03 and t.y > TEX_EDGE - 0.01:
			q = q.lerp(p.normalized(), BORDO_FUORI).normalized()
		nr[i] = (testa.right * q.x + testa.up * q.y + testa.fwd * q.z).normalized()
		uv2[i] = t
		uv[i] = Vector2(cx * cw + (TINTA_PAD + t.x * TINTA_W) * TINTA_SCALA, cy * ch + (TINTA_PAD + t.y * TINTA_H) * TINTA_SCALA) / atl
	# Godot: davanti = giro orario visto da fuori (nel web è antiorario): si gira ogni triangolo
	var ind: PackedInt32Array = pc.ind.duplicate()
	for k in range(0, ind.size(), 3):
		var x := ind[k + 1]
		ind[k + 1] = ind[k + 2]
		ind[k + 2] = x
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nr
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_TEX_UV2] = uv2
	a[Mesh.ARRAY_INDEX] = ind
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## geometria di un taglio in coordinate locali della testa (in R), come hairPieces del web:
## Pezzi: pos, nrm (Vector3), uv (Vector2, nella zona della tinta del web), ind
static func pezzi(taglio: int) -> Pezzi:
	var out := Pezzi.new()
	var st: Dictionary = HAIR[clampi(taglio, 0, N_TAGLI - 1)]
	if st.has("line"):
		_shell(out, taglio, st)
	if st.has("strip"):
		_strip(out)
	match st.get("extra", ""):
		"tail":
			_tail(out)
		"bun":
			_bun(out)
		"spikes":
			_spikes(out)
	return out


# ---------------------------------------------------------------- forme (src/hair3d.js)
static func _sm(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func dir_l(el: float, az: float) -> Vector3:
	var ce := cos(deg_to_rad(el))
	return Vector3(ce * sin(deg_to_rad(az)), sin(deg_to_rad(el)), ce * cos(deg_to_rad(az)))


## attaccatura: elevazione in funzione del giro, da nodi [|az|, el] raccordati in modo morbido
static func prof(az: float, k: Array) -> float:
	var a := minf(180.0, absf(az))
	for i in k.size() - 1:
		if a <= (k[i + 1] as Vector2).x:
			return lerpf(k[i].y, k[i + 1].y, _sm(k[i].x, k[i + 1].x, a))
	return (k[k.size() - 1] as Vector2).y


static func _lumps(L: Vector3, f: float) -> float:
	var s := 0.0
	for i in LUMP_K.size():
		s += sin(f * (LUMP_K[i] as Vector3).dot(L) + i * 1.7)
	return s / LUMP_K.size()


static func _soft_min(a: float, b: float, k: float) -> float:
	return (a + b - sqrt((a - b) * (a - b) + k * k)) / 2.0


static func _quiff(el: float, az: float) -> float:
	return _sm(70.0, 5.0, absf(az - 6.0)) * _sm(30.0, 60.0, el) * (1.0 - 0.75 * _sm(72.0, 92.0, el))


static func _afro_t(L: Vector3) -> float:
	var d := L.dot(AFRO_C)
	return d + sqrt(maxf(0.0, d * d - AFRO_C.length_squared() + AFRO_R * AFRO_R))


# spessore in R (th del web): v = 0 sul bordo, 1 in cima; b = raggio della base
static func _th(taglio: int, el: float, az: float, b: float, L: Vector3) -> float:
	match taglio:
		2:
			return 0.04 + 0.03 * _sm(20, 70, el)
		3:
			return 0.05 + 0.2 * _sm(22, 66, el)
		4:
			return 0.05 + 0.025 * _sm(20, 70, el) + 0.3 * _quiff(el, az)
		5:
			return 0.07 + 0.07 * _sm(-40, 70, az) * _sm(10, 60, el) - 0.05 * exp(-pow((az + 38.0) / 9.0, 2.0)) * _sm(32, 52, el) * (1.0 - _sm(80, 90, el))
		7:
			return 0.06 + 0.02 * _sm(20, 70, el)
		8:
			return 0.12 + 0.05 * _sm(0, 60, el) + 0.07 * _lumps(L, 7.0)
		9:
			return -_soft_min(-AFRO_MIN, b - _afro_t(L), 0.08) + 0.025 * _lumps(L, 9.0)
		10:
			return 0.085 + 0.025 * _sm(20, 70, el)
		11:
			return 0.08 + 0.015 * _sm(20, 70, el)
		12, 13:
			return 0.042 + 0.018 * _sm(10, 70, el)
		14:
			return 0.06 + 0.045 * pow(absf(sin(deg_to_rad(6.0 * az))), 0.6) * _sm(30, 10, el) + 0.02 * _sm(30, 80, el)
		15:
			return 0.085 + 0.025 * _sm(30, 80, el)
		16:
			return 0.035 + 0.05 * _sm(40, 150, absf(az)) * _sm(-10, 60, el) + 0.015 * _sm(50, 90, el)
	return 0.05


# ritocco del punto (post del web): spazzola piatta sopra, ciuffo in avanti
static func _post(taglio: int, p: Vector3, el: float, az: float) -> Vector3:
	if taglio == 3:
		p.y = _soft_min(p.y, base(Vector3.UP) + 0.14, 0.06)
	elif taglio == 4:
		var q := _quiff(el, az)
		p.z += 0.16 * q
		p.y += 0.05 * q
	return p


static func _shell_point(taglio: int, st: Dictionary, el: float, az: float, v: float, t_fisso: float = NAN) -> Vector3:
	var hanging := st.has("hang") and el < float(st.hang)
	var he: float = st.get("hang", 0.0)
	var e0 := he - (he - el) * 0.12 if hanging else el
	var L := dir_l(e0, az)
	var b := base(L)
	var t := t_fisso
	if is_nan(t_fisso):
		t = _th(taglio, el, az, b, L)
		var tp: Vector2 = st.get("taper", Vector2(0.4, 0.25))
		var e := _sm(0.0, tp.y, v)
		t = t * (tp.x + (1.0 - tp.x) * e) - TUCK * (1.0 - e)
	var p := L * (b + t)
	if hanging:
		var drop := (sin(deg_to_rad(he)) - sin(deg_to_rad(el))) * float(st.get("drop", 1.0))
		var hn := Vector2(L.x, L.z).length()
		if hn == 0.0:
			hn = 1.0
		var fl := float(st.get("flare", 0.0)) * drop
		p.y -= drop
		p.x += L.x / hn * fl
		p.z += L.z / hn * fl
	return _post(taglio, p, el, az)


static func _shell(out: Pezzi, taglio: int, st: Dictionary) -> void:
	var C: int = st.get("cols", SHELL_COLS)
	var Rw: int = st.get("rows", SHELL_ROWS)
	var line: Array = st.line
	var az := func(j: int) -> float: return -180.0 + 360.0 * j / C
	var lin := func(j: int) -> float: return prof(az.call(j), line)
	var u := func(j: int) -> float: return lerpf(TEX_SHELL.x, TEX_SHELL.y, float(j) / C)
	var pt := func(i: int, j: int) -> Vector3:
		var l: float = lin.call(j)
		var e := 90.0 if i == Rw else l + (90.0 - l) * (float(i) / Rw)
		return _shell_point(taglio, st, e, az.call(j), float(i) / Rw)
	var tx := func(i: int, j: int) -> Vector2: return Vector2(u.call(j), lerpf(TEX_EDGE, TEX_TOP, float(i) / Rw))
	_grid_out(out, Rw, C, pt, tx, true, func(_i: int) -> Vector3: return Vector3.ZERO, Rw)
	# risvolto: dal bordo esterno verso l'interno, sotto la base (tinta scura)
	var pt2 := func(i: int, j: int) -> Vector3:
		if i == 0:
			return _shell_point(taglio, st, lin.call(j), az.call(j), 0.0, SKIRT_IN)
		return _shell_point(taglio, st, lin.call(j), az.call(j), 0.0)
	var tx2 := func(i: int, j: int) -> Vector2: return Vector2(u.call(j), 0.99 if i == 0 else TEX_UNDER)
	_grid_out(out, 1, C, pt2, tx2, true, func(_i: int) -> Vector3: return Vector3.ZERO)


# cresta: striscia lungo il centro della testa (ph = 0 avanti, 90 in cima, 180 dietro), bordi dentro la base
static func _strip(out: Pezzi) -> void:
	var rows := 8
	var cols := 22
	var pt := func(i: int, j: int) -> Vector3:
		var w := (-1.0 + 2.0 * i / rows) * STRIP_W
		var ph := lerpf(STRIP_FROM, STRIP_TO, float(j) / cols)
		var cw := cos(deg_to_rad(w))
		var L := Vector3(sin(deg_to_rad(w)), sin(deg_to_rad(ph)) * cw, cos(deg_to_rad(ph)) * cw)
		var pr := pow(maxf(0.0, cos((w / STRIP_W) * PI / 2.0)), 0.55)
		var h := 0.08 + 0.3 * _sm(34, 75, ph) * _sm(200, 125, ph)
		var t := h * pr + SKIRT_IN * (1.0 - pr)
		var p := L * (base(L) + t)
		p.z += 0.05 * pr * _sm(60, 120, ph)
		return p
	var tx := func(i: int, j: int) -> Vector2: return Vector2(lerpf(TEX_SHELL.x, TEX_SHELL.y, float(j) / cols), lerpf(TEX_EDGE, TEX_TOP, sin(PI * i / rows)))
	_grid_out(out, rows, cols, pt, tx, false, func(_i: int) -> Vector3: return Vector3.ZERO)


static func _catmull(P: Array, t: float) -> Vector3:
	var n := P.size() - 1
	var x := minf(n - 1e-6, t * n)
	var i := int(floor(x))
	var f := x - i
	var p0: Vector3 = P[maxi(0, i - 1)]
	var p1: Vector3 = P[i]
	var p2: Vector3 = P[i + 1]
	var p3: Vector3 = P[mini(n, i + 2)]
	var f2 := f * f
	var f3 := f2 * f
	return 0.5 * (2.0 * p1 + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f3)


# coda di cavallo: tubo lungo una curva dietro la nuca, con l'elastico (strozzatura vicino alla radice)
static func _tail(out: Pezzi) -> void:
	var L0 := dir_l(14, 180)
	var root := L0 * (base(L0) - 0.05)
	var ctrl := [root, root + Vector3(0, -0.02, -0.3), root + Vector3(0, -0.32, -0.52), root + Vector3(0, -0.82, -0.48), root + Vector3(0, -1.18, -0.36)]
	var rad := func(t: float) -> float:
		if t < 0.07:
			return 0.18
		if t < 0.15:
			return 0.135
		return lerpf(0.27, 0.05, _sm(0.25, 1.0, t)) * (1.0 - 0.4 * _sm(0.15, 0.05, t))
	var cols := 10
	var rows := TAIL_T.size() - 1
	var pt := func(i: int, j: int) -> Vector3:
		var t: float = TAIL_T[i]
		var c := _catmull(ctrl, t)
		var T := (_catmull(ctrl, minf(1.0, t + 0.02)) - _catmull(ctrl, maxf(0.0, t - 0.02))).normalized()
		var B := Vector3(1, 0, 0)
		var N := B.cross(T).normalized()
		var a := TAU * j / cols
		var r: float = 0.0 if i == rows else rad.call(t)
		return c + (B * cos(a) + N * sin(a)) * r
	var tx := func(i: int, j: int) -> Vector2: return Vector2(lerpf(TEX_EXTRA.x, TEX_EXTRA.y, float(j) / cols), TAIL_T[i])
	_grid_out(out, rows, cols, pt, tx, true, func(i: int) -> Vector3: return _catmull(ctrl, TAIL_T[i]))


# crocchia: tornita attorno a un asse che esce dalla testa in alto dietro, con l'elastico alla base
static func _bun(out: Pezzi) -> void:
	var L := dir_l(52, 180)
	var o := L * base(L)
	var ax := (L + Vector3(0, 0.3, 0)).normalized()
	var B := ax.cross(Vector3(1, 0, 0)).normalized()
	var A := B.cross(ax).normalized()
	var cols := 12
	var pt := func(i: int, j: int) -> Vector3:
		var rh: Vector3 = BUN[i]
		var a := TAU * j / cols
		var sq := 1.0 + 0.12 * cos(2.0 * a)
		return o + ax * rh.y + A * (rh.x * sq * cos(a)) + B * (rh.x * sin(a))
	var tx := func(i: int, j: int) -> Vector2: return Vector2(lerpf(TEX_EXTRA.x, TEX_EXTRA.y, float(j) / cols), (BUN[i] as Vector3).z)
	_grid_out(out, BUN.size() - 1, cols, pt, tx, true, func(i: int) -> Vector3: return o + ax * (BUN[i] as Vector3).y)


# punte: ciuffetti a cuneo (sezione schiacciata, punta che piega all'indietro), appoggiati sulla base
static func _spikes(out: Pezzi) -> void:
	var cols := 5
	for k in SPIKES.size():
		var s: Array = SPIKES[k]
		var L := dir_l(s[0], s[1])
		var root := L * (base(L) - 0.03)
		var ax := (L + Vector3(0, 0.55, 0) + Vector3(0, 0, -1) * 0.22).normalized()
		var B := ax.cross(Vector3(0, 1, 0) if absf(ax.x) > 0.9 else Vector3(1, 0, 0)).normalized()
		var A := B.cross(ax)
		var tw := 0.6 + 0.25 * sin(k * 2.3)
		var ln: float = s[2]
		var anelli := [Vector3(0, 0.2, 0), Vector3(ln * 0.45, 0.1, 0.04), Vector3(ln, 0, 0.12)]   # h, r, piega
		var pt := func(i: int, j: int) -> Vector3:
			var an: Vector3 = anelli[i]
			var a := TAU * j / cols
			return root + ax * an.x + A * (an.y * cos(a)) + B * (an.y * tw * sin(a)) + Vector3(0, 0, -1) * an.z
		var tx := func(i: int, j: int) -> Vector2: return Vector2(lerpf(TEX_EXTRA.x, TEX_EXTRA.y, float(j) / cols), lerpf(0.2, 1.0, i / 2.0))
		_grid_out(out, 2, cols, pt, tx, true, func(_i: int) -> Vector3: return root)


# griglia con normali morbide (grid del web): pt(i, j) → punto; tx(i, j) → uv; wrap: l'ultima colonna ripete la
# prima; inner(i) → punto dentro il pezzo (per girare i triangoli verso l'esterno). Le righe in un punto si uniscono.
static func _grid_out(out: Pezzi, rows: int, cols: int, pt: Callable, tx: Callable, wrap: bool, inner: Callable, pole: int = -1) -> void:
	var nc := cols + 1
	var P := PackedVector3Array()
	var U := PackedVector2Array()
	var I := PackedInt32Array()
	for i in rows + 1:
		var row := PackedVector3Array()
		for j in nc:
			row.append(pt.call(i, 0 if wrap and j == cols else j))
		var span := 0.0
		for p in row:
			span = maxf(span, p.distance_to(row[0]))
		if span < 1e-4 or i == pole:
			var m := Vector3.ZERO
			for p in row:
				m += p / nc
			row.fill(m)
		for j in nc:
			P.append(row[j])
			U.append(tx.call(i, j))
	var sgn := 0.0
	for i in rows:
		for j in cols:
			var a := i * nc + j
			var b := a + 1
			var c := a + nc + 1
			var d := a + nc
			I.append_array([a, b, d, b, c, d])
			sgn += (P[b] - P[a]).cross(P[d] - P[a]).dot(P[a] - (inner.call(i) as Vector3))
	if sgn < 0.0:
		for t in range(0, I.size(), 3):
			var x := I[t + 1]
			I[t + 1] = I[t + 2]
			I[t + 2] = x
	var Nn := PackedVector3Array()
	Nn.resize(P.size())
	for t in range(0, I.size(), 3):
		var n := (P[I[t + 1]] - P[I[t]]).cross(P[I[t + 2]] - P[I[t]])
		for k in 3:
			Nn[I[t + k]] += n
	for i in rows + 1:
		var r0 := i * nc
		if P[r0].is_equal_approx(P[r0 + (cols >> 1)]) and P[r0].is_equal_approx(P[r0 + cols]):
			var m := Vector3.ZERO
			for j in nc:
				m += Nn[r0 + j]
			for j in nc:
				Nn[r0 + j] = m
		elif wrap:
			var m := Nn[r0] + Nn[r0 + cols]
			Nn[r0] = m
			Nn[r0 + cols] = m
	var base_i: int = out.pos.size()
	for k in P.size():
		out.pos.append(P[k])
		var nn := Nn[k]
		out.nrm.append(nn.normalized() if nn.length_squared() > 0.0 else Vector3.UP)
		out.uv.append(U[k])
	for x in I:
		out.ind.append(base_i + x)


## geometria di un taglio in costruzione (coordinate locali della testa)
class Pezzi:
	extends RefCounted
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var ind := PackedInt32Array()
