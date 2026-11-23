# Inquadratura calcolata: conti puri (niente nodi, gira anche con `godot -s`) per mettere dei punti del campo
# dentro il campo visivo della telecamera, con margine. Porting di src/camfit.js (stessi nomi e stessi numeri).
# Usata dalla visuale della parata, da quella larga del rallenty in attacco e dal calcio d'angolo (telecamera_partita.gd).
#
# Spazio "orientato": punti Vector3(x, h, y) con x = larghezza, h = altezza, y = lunghezza, già girati in modo che la
# squadra umana attacchi verso +y (la propria porta è a y = −HL). Nel mondo di Godot: X = x, Y = h, Z = −y.
extends RefCounted

const Coord := preload("res://scripts/coord.gd")

const HL := Coord.HL
const GW := Coord.GW
const GH := Coord.GH
const SIX_W := Coord.SIX_W
const SIX_D := Coord.SIX_D

# Parata: telecamera dietro la propria porta, girata in parte verso chi tira; si allontana (e poi allarga il campo
# visivo) quanto serve perché porta intera, portiere e pallone stiano a schermo.
const SAVE_BACK := 7.0        # distanza minima dietro la linea di porta (m)
const SAVE_H := 2.4           # altezza di partenza (m)
const SAVE_PITCH := 0.07      # inclinazione verso il basso (rad, ~4°)
const SAVE_YAW_K := 0.8       # si gira verso il pallone di questa frazione dell'angolo del tiro...
const SAVE_YAW_MAX := 0.95    # ... al massimo di tanto (rad, ~54°)
const SAVE_MAX_BACK := 15.0   # non oltre tanti metri dietro la porta (la tribuna di fondo è a 18 m)
const SAVE_FOV_MAX := 96.0    # campo visivo verticale massimo (gradi)
const SAVE_PAD := 0.9         # margine intorno ai pali (m)
const SAVE_PAD_TOP := 0.7     # margine sopra la traversa (m)
const SAVE_MARGIN := {"l": 0.06, "r": 0.06, "t": 0.17, "b": 0.2}  # frazioni di mezzo schermo: punteggio in alto, suggerimento in basso

# Rallenty in attacco (duello, area di tiro, disegno): visuale più alta e più indietro che tiene a schermo i compagni.
const WIDE_PITCH := 0.66      # inclinazione verso il basso (rad, ~38°)
const WIDE_AHEAD := 13.0      # guarda tanti metri davanti al portatore
const WIDE_MIN_DIST := 22.0   # distanza minima dal punto guardato (m)
const WIDE_MAX_DIST := 36.0   # ... massima: oltre il portatore diventa troppo piccolo
const WIDE_FOV_MAX := 88.0    # campo visivo verticale massimo (gradi)
const WIDE_GOAL_GAP := 6.0    # nell'area di tiro guarda al massimo fino a tanti metri prima della porta
const WIDE_CARRIER_PAD := 2.5 # metri d'aria a destra e a sinistra del portatore
const WIDE_R := 35.0          # compagni entro tanti metri dal portatore...
const WIDE_BEHIND := 5.0      # ... davanti o di fianco (al massimo tanti metri dietro)
const WIDE_MARGIN := {"l": 0.08, "r": 0.08, "t": 0.2, "b": 0.3}
const HEAD_AHEAD := 9.0       # colpo di testa: guarda tanti metri davanti a chi colpisce (la porta resta in alto)

# Calcio d'angolo: telecamera alle spalle del battitore, girata verso il centro dell'area.
const CORNER_BACK := 4.0       # distanza dietro la bandierina (m)
const CORNER_H := 9.0          # altezza di partenza (m)
const CORNER_PITCH := 0.62     # inclinazione verso il basso (rad, ~30°)
const CORNER_AIM := 4.0        # guarda verso il punto a tanti metri dalla linea di porta, al centro
const CORNER_MAX_BACK := 9.0   # non oltre tanti metri all'indietro (le tribune sono vicine)
const CORNER_GOAL_YAW := 0.35  # girata col dito: fino a tanto (rad) si passa piano dalla visuale con la porta a quella col solo battitore
const CORNER_RUNUP := 1.5      # il battitore prende la rincorsa tanti metri dietro il pallone
const CORNER_FOV_MAX := 90.0   # campo visivo verticale massimo (gradi)
const CORNER_MARGIN := {"l": 0.06, "r": 0.06, "t": 0.2, "b": 0.3}

# Rimessa laterale della squadra della persona (Luis 2026-11-23): come nel calcio d'angolo, telecamera alle spalle del
# battitore, fuori dalla linea laterale, girata verso il campo e un po' verso la porta avversaria; si gira col dito.
const THROW_BACK := 3.5        # distanza dietro il battitore (m)
const THROW_H := 6.5           # altezza di partenza (m)
const THROW_PITCH := 0.5       # inclinazione verso il basso (rad, ~29°)
const THROW_AIM_IN := 16.0     # guarda verso il punto a tanti metri dentro il campo ...
const THROW_AIM_FWD := 9.0     # ... e tanti metri più avanti, verso la porta avversaria
const THROW_TURN_MAX := 1.45   # girata col dito: al massimo tanto (rad, ~83°) dalla perpendicolare alla linea laterale (mai verso le tribune)
const THROW_MAX_BACK := 7.0    # non oltre tanti metri all'indietro (le tribune sono vicine)
const THROW_FOV_MAX := 80.0    # campo visivo verticale massimo (gradi)
const THROW_MARGIN := {"l": 0.08, "r": 0.08, "t": 0.2, "b": 0.42}  # in basso più aria: anello e piedi del battitore a schermo

const NEAR := 1.0   # ogni punto almeno a tanti metri davanti alla telecamera


## assi della telecamera girata di yaw (0 = verso +y, + = verso +x) e inclinata in giù di pitch: [avanti, destra, su]
static func basis(yaw: float, pitch: float) -> Array:
	var sy := sin(yaw)
	var cy := cos(yaw)
	var sp := sin(pitch)
	var cp := cos(pitch)
	return [Vector3(sy * cp, -sp, cy * cp), Vector3(cy, 0.0, -sy), Vector3(sy * sp, cp, cy * sp)]


## punto p visto dalla telecamera in pos: (x, y) normalizzati (−1..1 = bordo dello schermo) e profondità z
static func project(pos: Vector3, yaw: float, pitch: float, tan_v: float, aspect: float, p: Vector3) -> Vector3:
	var b := basis(yaw, pitch)
	var d := p - pos
	var z: float = d.dot(b[0])
	return Vector3(d.dot(b[1]) / (z * tan_v * aspect), d.dot(b[2]) / (z * tan_v), z)


# t minimo (arretramento lungo l'asse) perché i punti Q (coordinate della telecamera) stiano dentro con le pendenze date
static func _need_t(q: Array, a: float, b: float, c: float, d: float) -> float:
	var t := -INF
	for p: Vector3 in q:
		t = maxf(t, NEAR - p.z)
	for i in q.size():
		var p: Vector3 = q[i]
		for j in q.size():
			if i == j:
				continue
			var r: Vector3 = q[j]
			t = maxf(t, maxf((p.x - r.x - b * p.z - a * r.z) / (a + b), (p.y - r.y - d * p.z - c * r.z) / (c + d)))
	return t


# tangente verticale minima perché i punti stiano dentro con l'arretramento t fissato
static func _need_tan(q: Array, t: float, aspect: float, m: Dictionary) -> float:
	var k := 0.0
	for i in q.size():
		var p: Vector3 = q[i]
		if p.z + t < NEAR:
			return INF
		for j in q.size():
			if i == j:
				continue
			var r: Vector3 = q[j]
			var zp := p.z + t
			var zr := r.z + t
			k = maxf(k, maxf((p.x - r.x) / (aspect * ((1.0 - m.r) * zp + (1.0 - m.l) * zr)), (p.y - r.y) / ((1.0 - m.t) * zp + (1.0 - m.b) * zr)))
	return k


# spostamento laterale (i = 0) o verticale (i = 1) ammesso: [min, max] con pendenze a (sinistra/giù) e b (destra/su)
static func _range(q: Array, t: float, i: int, a: float, b: float) -> Vector2:
	var lo := -INF
	var hi := INF
	for p: Vector3 in q:
		lo = maxf(lo, p[i] - b * (p.z + t))
		hi = minf(hi, p[i] + a * (p.z + t))
	return Vector2(lo, hi)


static func _solve(q: Array, o: Dictionary, tan0: float, tan_max: float) -> Dictionary:
	var m: Dictionary = o.m
	var th: float = tan0 * o.aspect
	var t := maxf(float(o.get("tMin", 0.0)), _need_t(q, th * (1.0 - m.l), th * (1.0 - m.r), tan0 * (1.0 - m.b), tan0 * (1.0 - m.t)))
	var tn := tan0
	if t > o.tMax:
		t = o.tMax
		tn = maxf(tan0, _need_tan(q, t, o.aspect, m))
	return {"Q": q, "t": t, "tan": tn, "ok": tn <= tan_max + 1e-9}


static func _pick(lo: float, hi: float, center: bool) -> float:
	return (lo + hi) / 2.0 if (lo > hi or center) else clampf(0.0, lo, hi)


## Telecamera con orientamento fisso (yaw, pitch) che parte da c0 e si sposta di lato, in alto e all'indietro lungo
## l'asse (t tra tMin e tMax) finché tutti i punti stanno nel riquadro coi margini m; se non basta allarga il campo
## visivo fino a fovMax; se nemmeno così toglie i gruppi di punti dal fondo (i primi `keep` restano sempre).
## o = {c0, yaw, pitch, groups: Array di Array di Vector3, keep, aspect, fov, fovMax, tMin, tMax, m, centerX}
## Ritorna {pos, look, fov, t, used, ok, yaw, pitch}.
static func fit_view(o: Dictionary) -> Dictionary:
	var b := basis(o.yaw, o.pitch)
	var f: Vector3 = b[0]
	var r: Vector3 = b[1]
	var u: Vector3 = b[2]
	var m: Dictionary = o.m
	var keep: int = int(o.get("keep", 1))
	if keep <= 0:
		keep = 1
	var tan0 := tan(deg_to_rad(o.fov / 2.0))
	var tan_max := tan(deg_to_rad(o.fovMax / 2.0))
	var c0: Vector3 = o.c0
	var groups: Array = o.groups
	var g: Array = []
	for grp: Array in groups:
		var cg: Array = []
		for p: Vector3 in grp:
			var d := p - c0
			cg.append(Vector3(d.dot(r), d.dot(u), d.dot(f)))
		g.append(cg)
	var used := mini(keep, g.size())
	var first: Array = []
	for i in used:
		first.append_array(g[i])
	var s := _solve(first, o, tan0, tan_max)
	var i := used
	while i < g.size() and s.ok:
		var tq: Array = (s.Q as Array).duplicate()
		tq.append_array(g[i])
		var tr := _solve(tq, o, tan0, tan_max)
		if tr.ok:
			s = tr
			used += 1
		i += 1
	var q: Array = s.Q
	var t: float = s.t
	var tn := minf(s.tan, tan_max)
	var th: float = tn * o.aspect
	var xr := _range(q, t, 0, th * (1.0 - m.l), th * (1.0 - m.r))
	var yr := _range(q, t, 1, tn * (1.0 - m.b), tn * (1.0 - m.t))
	var ox := _pick(xr.x, xr.y, o.get("centerX", true) != false) if not q.is_empty() else 0.0
	var oy := _pick(yr.x, yr.y, false) if not q.is_empty() else 0.0
	var pos := c0 + r * ox + u * oy - f * t
	var z0 := maxf(NEAR, (g[0][0] as Vector3).z + t) if not q.is_empty() else 10.0
	return {"pos": pos, "look": pos + f * z0, "fov": rad_to_deg(2.0 * atan(tn)), "t": t, "used": used, "ok": s.ok,
		"yaw": o.yaw, "pitch": o.pitch}


## punti della porta a y = gy coi margini: i quattro angoli dello specchio allargato
static func goal_corners(gy: float = -HL, pad: float = SAVE_PAD, top: float = SAVE_PAD_TOP) -> Array:
	var x := GW / 2.0 + pad
	var h := GH + top
	return [Vector3(-x, 0, gy), Vector3(x, 0, gy), Vector3(-x, h, gy), Vector3(x, h, gy)]


## Visuale della parata (propria porta a y = −HL): porta intera sempre, poi portiere, poi pallone.
## ball = Vector3(x, h, y), keeper = Vector2(x, y)
static func save_view(ball: Vector3, keeper: Vector2, aspect: float, fov: float) -> Dictionary:
	var gy := -HL
	var ang := atan2(ball.x, maxf(0.5, ball.z - gy))
	var yaw := clampf(ang * SAVE_YAW_K, -SAVE_YAW_MAX, SAVE_YAW_MAX)
	var c0 := Vector3(-sin(yaw) * SAVE_BACK, SAVE_H, gy - cos(yaw) * SAVE_BACK)
	return fit_view({
		"c0": c0, "yaw": yaw, "pitch": SAVE_PITCH, "aspect": aspect, "fov": fov, "fovMax": maxf(fov, SAVE_FOV_MAX),
		"m": SAVE_MARGIN, "tMin": 0.0, "tMax": (SAVE_MAX_BACK - SAVE_BACK) / cos(SAVE_PITCH), "keep": 2, "centerX": true,
		"groups": [goal_corners(gy), [Vector3(keeper.x, 0, keeper.y), Vector3(keeper.x, 2, keeper.y)],
			[Vector3(ball.x, maxf(0.0, ball.y), ball.z), Vector3(ball.x, 0, ball.z)]],
	})


## Visuale larga del rallenty in attacco (si attacca verso +y). carrier = Vector2(x, y); mates = Array di Vector2 (tutti
## i compagni: si tengono quelli entro WIDE_R davanti o di fianco); goal = tiene a schermo anche la porta avversaria.
static func wide_view(carrier: Vector2, yaw: float, mates: Array, goal: bool, aspect: float, fov: float) -> Dictionary:
	var cx := carrier.x
	var cy := carrier.y
	var hx := sin(yaw)
	var hy := cos(yaw)
	var f: Vector3 = basis(yaw, WIDE_PITCH)[0]
	# nell'area di tiro non guarda oltre la porta (sopra resterebbero solo le tribune)
	var ahead := maxf(0.0, minf(WIDE_AHEAD, (HL - WIDE_GOAL_GAP - cy) / maxf(0.3, hy))) if goal else WIDE_AHEAD
	var look := Vector3(cx + hx * ahead, 0, cy + hy * ahead)
	var c0 := look - f * WIDE_MIN_DIST
	# portatore con un po' d'aria ai lati
	var px := hy * WIDE_CARRIER_PAD
	var py := -hx * WIDE_CARRIER_PAD
	var groups: Array = [[Vector3(cx, 0, cy), Vector3(cx, 2.3, cy), Vector3(cx - px, 0, cy - py), Vector3(cx + px, 0, cy + py)]]
	if goal:
		groups.append(goal_corners(HL, 0.5, 0.3))
	var near: Array = []
	for p: Vector2 in mates:
		var dx := float(p.x) - cx
		var dy := float(p.y) - cy
		var d := sqrt(dx * dx + dy * dy)
		var a := dx * hx + dy * hy
		if d > 0.5 and d <= WIDE_R and a >= -WIDE_BEHIND:
			near.append([d, p])
	_stable_sort_by_first(near)
	for e: Array in near:
		var p: Vector2 = e[1]
		groups.append([Vector3(p.x, 0, p.y), Vector3(p.x, 1.9, p.y)])
	return fit_view({
		"c0": c0, "yaw": yaw, "pitch": WIDE_PITCH, "aspect": aspect, "fov": fov, "fovMax": maxf(fov, WIDE_FOV_MAX),
		"m": WIDE_MARGIN, "tMin": 0.0, "tMax": WIDE_MAX_DIST - WIDE_MIN_DIST, "keep": 2 if goal else 1, "centerX": true,
		"groups": groups,
	})


## Visuale del colpo di testa controllato (Luis 2026-11-23: "deve zoomarsi come il passaggio o il tiro"): stessa
## inclinazione e distanza minima della visuale dell'area di tiro, con chi colpisce grande nella parte bassa e la porta
## sopra. Non si allarga per i compagni. head = Vector2(x, y) di chi colpisce, yaw = visuale girata col dito (rad).
static func head_view(head: Vector2, yaw: float, fov: float) -> Dictionary:
	var f: Vector3 = basis(yaw, WIDE_PITCH)[0]
	var look := Vector3(head.x + sin(yaw) * HEAD_AHEAD, 0, head.y + cos(yaw) * HEAD_AHEAD)
	return {"pos": look - f * WIDE_MIN_DIST, "look": look, "fov": fov}


## Visuale del calcio d'angolo. ball = Vector2(x, y) della bandierina da cui si batte; yaw = visuale girata col dito
## (rad, + = guarda verso destra): gira intorno al battitore
static func corner_view(ball: Vector2, yaw: float, aspect: float, fov: float) -> Dictionary:
	var bx := ball.x
	var by := ball.y
	var sy := 1.0 if by >= 0.0 else -1.0
	var gy := sy * HL
	var ay := gy - sy * CORNER_AIM
	var turn := yaw
	var cy := atan2(0.0 - bx, ay - by) + turn
	var hx := sin(cy)
	var hy := cos(cy)
	var c0 := Vector3(bx - hx * CORNER_BACK, CORNER_H, by - hy * CORNER_BACK)
	var kx := bx - hx * CORNER_RUNUP
	var ky := by - hy * CORNER_RUNUP
	var kicker := [Vector3(bx, 0, by), Vector3(bx, 2, by), Vector3(kx, 0, ky), Vector3(kx, 2, ky)]
	var base := {
		"c0": c0, "yaw": cy, "pitch": CORNER_PITCH, "aspect": aspect, "fov": fov, "fovMax": maxf(fov, CORNER_FOV_MAX),
		"m": CORNER_MARGIN, "tMin": 0.0, "tMax": CORNER_MAX_BACK - CORNER_BACK, "centerX": false,
	}
	var full_o := base.duplicate()
	full_o.keep = 2
	# l'area di rigore intera non si chiede (in verticale spingerebbe la telecamera di lato): basta l'area piccola
	full_o.groups = [kicker, goal_corners(gy, 0.5, 0.3),
		[Vector3(-SIX_W / 2.0, 0, gy - sy * SIX_D), Vector3(SIX_W / 2.0, 0, gy - sy * SIX_D)]]
	var full := fit_view(full_o)
	# visuale girata col dito: battitore in basso al centro senza inseguire la porta; in mezzo si passa con dolcezza
	var w := minf(1.0, absf(turn) / CORNER_GOAL_YAW)
	if w <= 0.0:
		return full
	var free_o := base.duplicate()
	free_o.keep = 1
	free_o.groups = [kicker]
	var free := fit_view(free_o)
	var out := full.duplicate()
	out.pos = (full.pos as Vector3).lerp(free.pos, w)
	out.look = (full.look as Vector3).lerp(free.look, w)
	out.fov = full.fov + (free.fov - full.fov) * w
	return out


## Visuale della rimessa laterale. ball = Vector2(x, y) del punto della rimessa (spazio orientato), yaw = visuale girata
## col dito (rad, + = guarda verso destra): gira intorno al battitore, che resta in basso al centro (tenendo a schermo
## anche i compagni vicini il battitore finiva nell'angolo dello schermo, mezzo tagliato).
static func throw_view(ball: Vector2, yaw: float, aspect: float, fov: float) -> Dictionary:
	var sx := 1.0 if ball.x >= 0.0 else -1.0
	var inward := -sx * PI / 2.0 # verso il centro del campo, perpendicolare alla linea laterale
	var a := atan2(-sx * THROW_AIM_IN, THROW_AIM_FWD) + yaw
	a = clampf(a, inward - THROW_TURN_MAX, inward + THROW_TURN_MAX)
	var h := Vector2(sin(a), cos(a))
	var c0 := Vector3(ball.x - h.x * THROW_BACK, THROW_H, ball.y - h.y * THROW_BACK)
	var kicker := [Vector3(ball.x, 0, ball.y), Vector3(ball.x, 2.3, ball.y)]
	return fit_view({
		"c0": c0, "yaw": a, "pitch": THROW_PITCH, "aspect": aspect, "fov": fov, "fovMax": maxf(fov, THROW_FOV_MAX),
		"m": THROW_MARGIN, "tMin": 0.0, "tMax": THROW_MAX_BACK - THROW_BACK, "centerX": true, "keep": 1,
		"groups": [kicker],
	})


# ordina [[chiave, valore], ...] per chiave crescente mantenendo l'ordine dei pari (come Array.sort del JS)
static func _stable_sort_by_first(a: Array) -> void:
	for i in range(1, a.size()):
		var e: Array = a[i]
		var j := i - 1
		while j >= 0 and float(a[j][0]) > float(e[0]):
			a[j + 1] = a[j]
			j -= 1
		a[j + 1] = e
