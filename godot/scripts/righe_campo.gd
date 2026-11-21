# Righe bianche del campo come geometria vera (una sola mesh piatta poco sopra l'erba, shaders/righe.gdshader).
#
# Prima le righe erano calcolate per pixel nello shader dell'erba: sul PC si vedevano, sull'iPhone no. Con la
# geometria non dipendono più dai calcoli per pixel (derivate, precisione) del telefono: sono triangoli bianchi.
# Lo shader allarga ogni riga quando da lontano diventerebbe più sottile di ~1,5 pixel, così non sparisce mai.
#
# Misure come godot/sim/core.gd (= src/sim/core.js); righe larghe 12 cm (regolamento), centrate sul bordo delle
# aree come nel gioco web. Coordinate del gioco (x, y) → Godot (X = x, Z = −y), scripts/coord.gd.
#
# Vertici: tutti sulla linea di mezzo della riga; lo shader li sposta di lato. Per ogni vertice:
#   UV.x            mezza larghezza vera (m)
#   CUSTOM0.xy      direzione di lato in Godot (X, Z), segno compreso (0 = non si sposta, centro dei dischetti)
#   CUSTOM0.zw      direzione di allungamento alle estremità dei segmenti (chiude gli angoli), 0 altrove
extends RefCounted

const C := preload("res://sim/core.gd")

const LARGHEZZA := 0.12        # m, larghezza di una riga (regolamento: al massimo 12 cm)
const ALTEZZA := 0.012         # m sopra l'erba (niente lotta di profondità, ombre dei giocatori comprese)
const PUNTO_R := 0.11          # raggio del dischetto del rigore e del punto del centro (m)
const ANGOLO_R := 1.0          # raggio degli archi d'angolo (m)
const PASSO_ARCO := 0.5        # lunghezza massima di un pezzo dritto negli archi (m)


## i pezzi del disegno, in coordinate del gioco:
##   {tipo: "linea", a: Vector2, b: Vector2}
##   {tipo: "arco", c: Vector2, r: float, da: float, a: float}   (angoli in rad, da < a, 0 = verso +x)
##   {tipo: "punto", c: Vector2, r: float}
static func pezzi() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hw := C.HW
	var hl := C.HL
	# bordo del campo: linee laterali e di fondo
	out.append(_linea(-hw, -hl, hw, -hl))
	out.append(_linea(hw, -hl, hw, hl))
	out.append(_linea(hw, hl, -hw, hl))
	out.append(_linea(-hw, hl, -hw, -hl))
	# metà campo, cerchio e punto del centro
	out.append(_linea(-hw, 0.0, hw, 0.0))
	out.append({"tipo": "arco", "c": Vector2.ZERO, "r": C.CIRCLE, "da": 0.0, "a": TAU})
	out.append({"tipo": "punto", "c": Vector2.ZERO, "r": PUNTO_R})
	# le due metà: aree di rigore e di porta, dischetto, lunetta
	var lunetta := acos((C.BOX_D - C.PEN_D) / C.CIRCLE)   # mezzo angolo dell'arco fuori dall'area
	for s: float in [1.0, -1.0]:
		var fondo := s * hl
		for misure: Vector2 in [Vector2(C.BOX_W, C.BOX_D), Vector2(C.SIX_W, C.SIX_D)]:
			var mx := misure.x / 2.0
			var dentro := s * (hl - misure.y)
			out.append(_linea(-mx, fondo, -mx, dentro))
			out.append(_linea(-mx, dentro, mx, dentro))
			out.append(_linea(mx, dentro, mx, fondo))
		var dischetto := Vector2(0.0, s * (hl - C.PEN_D))
		out.append({"tipo": "punto", "c": dischetto, "r": PUNTO_R})
		var verso_centro := -PI / 2.0 if s > 0.0 else PI / 2.0
		out.append({"tipo": "arco", "c": dischetto, "r": C.CIRCLE, "da": verso_centro - lunetta, "a": verso_centro + lunetta})
	# archi d'angolo (un quarto di cerchio dentro il campo)
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			var dentro := atan2(-sy, -sx)   # direzione dall'angolo verso il centro del campo
			out.append({"tipo": "arco", "c": Vector2(sx * hw, sy * hl), "r": ANGOLO_R, "da": dentro - PI / 4.0, "a": dentro + PI / 4.0})
	return out


static func _linea(ax: float, ay: float, bx: float, by: float) -> Dictionary:
	return {"tipo": "linea", "a": Vector2(ax, ay), "b": Vector2(bx, by)}


## la mesh di tutte le righe (coordinate di Godot, nodo non spostato né girato)
static func mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for p: Dictionary in pezzi():
		match p.tipo:
			"linea":
				_mesh_linea(st, p.a, p.b)
			"arco":
				_mesh_arco(st, p.c, p.r, p.da, p.a)
			"punto":
				_mesh_punto(st, p.c, p.r)
	return st.commit()


# un vertice: punto del gioco q, spostamento di lato `lato` e allungamento `fine` (direzioni del gioco)
static func _vertice(st: SurfaceTool, q: Vector2, lato: Vector2, fine: Vector2, mezza: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(mezza, 0.0))
	st.set_custom(0, Color(lato.x, -lato.y, fine.x, -fine.y))   # y del gioco → −Z di Godot
	st.add_vertex(Vector3(q.x, ALTEZZA, -q.y))


# quadrilatero tra i punti a e b della linea di mezzo, con le direzioni di lato na (in a) e nb (in b)
static func _quad(st: SurfaceTool, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, fa: Vector2, fb: Vector2, mezza: float) -> void:
	var v := [[a, na, fa], [b, nb, fb], [b, -nb, fb], [a, na, fa], [b, -nb, fb], [a, -na, fa]]
	for x: Array in v:
		_vertice(st, x[0], x[1], x[2], mezza)


static func _mesh_linea(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	_quad(st, a, b, n, n, -d, d, LARGHEZZA / 2.0)


static func _mesh_arco(st: SurfaceTool, c: Vector2, r: float, da: float, a: float) -> void:
	var n := maxi(6, ceili((a - da) * r / PASSO_ARCO))
	for i in n:
		var t0 := da + (a - da) * i / n
		var t1 := da + (a - da) * (i + 1) / n
		var u0 := Vector2(cos(t0), sin(t0))
		var u1 := Vector2(cos(t1), sin(t1))
		_quad(st, c + u0 * r, c + u1 * r, u0, u1, Vector2.ZERO, Vector2.ZERO, LARGHEZZA / 2.0)


# dischetto: ventaglio di triangoli dal centro (che non si sposta) al bordo (spostato del raggio)
static func _mesh_punto(st: SurfaceTool, c: Vector2, r: float) -> void:
	var n := 12
	for i in n:
		var u0 := Vector2.from_angle(TAU * i / n)
		var u1 := Vector2.from_angle(TAU * (i + 1) / n)
		_vertice(st, c, Vector2.ZERO, Vector2.ZERO, 0.0)
		_vertice(st, c, u0, Vector2.ZERO, r)
		_vertice(st, c, u1, Vector2.ZERO, r)
