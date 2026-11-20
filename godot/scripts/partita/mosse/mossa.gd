# Movimento calcolato (porting di src/moves/core.js): una funzione pura del tempo che dà, nel riferimento del giocatore
# fermo (x = sua sinistra, y = su, z = avanti; metri del modello), dove vanno bacino, busto, testa, mani e caviglie e
# dove sta il pallone. Il pallone segue la fisica: a terra rotola, in aria vola con la gravità vera, a contatto viaggia
# col punto del piede che lo spinge. Chi disegna (figura.gd) mette le ossa in quella posa con la IK (ik.gd).
# Costruzione: var m := Mossa.new(R), poi pelvis/bend/leg/ball*/arm..., infine m.done(T); posa con m.at(t).
extends RefCounted

const Corpo := preload("corpo.gd")

const G := 9.81            # gravità (m/s²)
const SPIN_DT := 1.0 / 240.0   # passo con cui si integra la rotazione del pallone
const ACT_EASE := 0.08     # s: entrata e uscita della gamba "attiva" (in partita)
const LOOK_UP := 0.7       # rad: quanto in alto può guardare (collo + testa)
const Y := Vector3(0, 1, 0)
const X := Vector3(1, 0, 0)


## tempo di volo da un'altezza y0 a una y1 passando per il punto più alto H
static func flight_time(y0: float, h: float, y1: float) -> float:
	return sqrt(2.0 * maxf(0.0, h - y0) / G) + sqrt(2.0 * maxf(0.0, h - y1) / G)


## rotazione del piede: giro (punta verso +x), punta in giù (> 0), piede inclinato (> 0: il collo guarda verso +x)
static func foot_q(yaw: float = 0.0, down: float = 0.0, roll: float = 0.0) -> Quaternion:
	return Corpo.q_body(yaw, down, roll)


# ---------------------------------------------------------------- curve per punti (Hermite, tangenti alle differenze)
class Curva:
	extends RefCounted
	var t: PackedFloat64Array = PackedFloat64Array()
	var p: Array[Vector3] = []
	var m: Array[Vector3] = []

	## keys: [{t, p: Vector3, v?: Vector3}] in ordine di tempo; chiavi uguali in fila = fermo (tangente nulla)
	func _init(keys: Array) -> void:
		for k: Dictionary in keys:
			t.append(k.t)
			p.append(k.p)
		var n := keys.size()
		for i in n:
			var k: Dictionary = keys[i]
			if k.get("v") != null:
				m.append(k.v)
				continue
			if i == 0 or i == n - 1 or _same(p[i], p[i - 1]) or _same(p[i], p[i + 1]):
				m.append(Vector3.ZERO)
			else:
				m.append((p[i + 1] - p[i - 1]) / (t[i + 1] - t[i - 1]))

	static func _same(a: Vector3, b: Vector3) -> bool:
		return absf(a.x - b.x) + absf(a.y - b.y) + absf(a.z - b.z) < 1e-6

	func at(x: float) -> Vector3:
		var n := t.size()
		if x <= t[0]:
			return p[0]
		if x >= t[n - 1]:
			return p[n - 1]
		var i := 0
		while t[i + 1] < x:
			i += 1
		var dt := t[i + 1] - t[i]
		return hermite(p[i], m[i], p[i + 1], m[i + 1], dt, (x - t[i]) / dt)

	static func hermite(a: Vector3, ma: Vector3, b: Vector3, mb: Vector3, dt: float, s: float) -> Vector3:
		var s2 := s * s
		var s3 := s2 * s
		return a * (2.0 * s3 - 3.0 * s2 + 1.0) + ma * (dt * (s3 - 2.0 * s2 + s)) + b * (-2.0 * s3 + 3.0 * s2) + mb * (dt * (s3 - s2))


## quaternioni: slerp addolcito tra una chiave e l'altra
class QCurva:
	extends RefCounted
	var t: PackedFloat64Array = PackedFloat64Array()
	var q: Array[Quaternion] = []

	func _init(keys: Array) -> void:
		for k: Dictionary in keys:
			t.append(k.t)
			q.append(k.q)

	func at(x: float) -> Quaternion:
		var n := t.size()
		if x <= t[0]:
			return q[0]
		if x >= t[n - 1]:
			return q[n - 1]
		var i := 0
		while t[i + 1] < x:
			i += 1
		return Corpo.q_slerp(q[i], q[i + 1], Corpo.smooth((x - t[i]) / (t[i + 1] - t[i])))


var R := 0.11
var T := 0.0
var touches: Array = []
var segs: Array = []
var pelvis_k: Array = []
var bend_k: Array = []
var head_k: Array = []
var leg_k := {"l": [], "r": []}
var arm_k := {"l": [], "r": []}
var act_k := {"l": [], "r": []}
var spin: Array[Quaternion] = []
# curve pronte (prep)
var _pelvis_p: Curva
var _pelvis_a: Array = []   # Curva di yaw, pitch, roll (nella componente x)
var _bend_c: Curva = null
var _head_c: Curva = null
var _leg_c := {}
var _arm_c := {}


func _init(r: float) -> void:
	R = r


# una chiave nuova allo stesso istante di una vecchia la sostituisce
static func _put(list: Array, k: Dictionary) -> void:
	for i in list.size():
		if absf(float(list[i].t) - float(k.t)) < 1e-9:
			list.remove_at(i)
			break
	list.append(k)


# ordina per tempo mantenendo l'ordine dei pari (come Array.sort del JS)
static func _by_t(a: Array, key: String = "t") -> Array:
	for i in range(1, a.size()):
		var e: Dictionary = a[i]
		var j := i - 1
		while j >= 0 and float(a[j][key]) > float(e[key]):
			a[j + 1] = a[j]
			j -= 1
		a[j + 1] = e
	return a


## bacino: posizione e rotazione (giro, avanti, lato)
func pelvis(t: float, p: Vector3, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> Object:
	_put(pelvis_k, {"t": t, "p": p, "yaw": yaw, "pitch": pitch, "roll": roll})
	return self


## curva del busto (avanti, lato, giro) in rad
func bend(t: float, b: Vector3) -> Object:
	_put(bend_k, {"t": t, "b": b})
	return self


## testa: (in giù, giro) in più rispetto allo sguardo verso il pallone
func head(t: float, h: Vector2) -> Object:
	_put(head_k, {"t": t, "h": h})
	return self


## caviglia: {t, ankle, fq, pole} oppure {t, part, at, fq, pole} oppure {t, plant: Vector2(x, z), yaw}
func leg(side: String, k: Dictionary) -> Object:
	var plant: bool = k.has("plant")
	var fq: Quaternion = Corpo.q_axis(Y, float(k.get("yaw", 0.0))) if plant else k.get("fq", Quaternion.IDENTITY)
	var ankle: Vector3
	if plant:
		var pl: Vector2 = k.plant
		ankle = Vector3(pl.x, Corpo.ANKLE_H, pl.y)
	elif k.has("part"):
		ankle = Corpo.ankle_for(side, k.at, fq, k.part)
	else:
		ankle = k.ankle
	var pole: Variant = k.get("pole")
	_put(leg_k[side], {"t": k.t, "p": ankle, "q": fq, "pole": pole if pole != null else _knee_dir(fq), "v": k.get("v"), "plant": plant})
	return self


# verso del ginocchio se non è dato: davanti al piede (avanti + su del piede, in orizzontale), così gira col corpo
static func _knee_dir(fq: Quaternion) -> Vector3:
	var f := fq * Vector3(0, 0, 1)
	var u := fq * Vector3(0, 1, 0)
	var x := f.x + u.x
	var z := f.z + u.z
	var h := sqrt(x * x + z * z)
	if h == 0.0:
		h = 1.0
	return Vector3(x / h, 0.15, z / h)


## gamba "attiva" (in partita solo questa segue il movimento calcolato; l'altra resta nella corsa)
func active(side: String, t0: float, t1: float) -> Object:
	act_k[side].append(Vector2(t0, t1))
	return self


## mano rispetto alla spalla, nel riferimento del petto (x verso l'esterno, y su, z avanti)
func arm(side: String, t: float, off: Vector3) -> Object:
	_put(arm_k[side], {"t": t, "p": off})
	return self


func ball_rest(t0: float, t1: float, p: Vector3, spin_: Vector3 = Vector3.ZERO) -> Object:
	segs.append({"k": "rest", "t0": t0, "t1": t1, "p": p, "spin": spin_})
	return self


func ball_roll(t0: float, t1: float, p0: Vector3, p1: Vector3, v0: Vector3 = Vector3.ZERO, v1: Vector3 = Vector3.ZERO) -> Object:
	segs.append({"k": "roll", "t0": t0, "t1": t1, "p0": p0, "p1": p1, "v0": v0, "v1": v1})
	return self


func ball_fly(t0: float, t1: float, p0: Vector3, p1: Vector3, spin_: Vector3 = Vector3.ZERO) -> Object:
	var tt := t1 - t0
	var vy := (p1.y - p0.y + G * tt * tt / 2.0) / tt
	segs.append({"k": "fly", "t0": t0, "t1": t1, "p0": p0, "p1": p1, "vy": vy, "spin": spin_})
	return self


## pallone portato dal piede: punto `part` + normale·(R + gap)
func ball_carry(t0: float, t1: float, side: String, part: String, gap: float = 0.0) -> Object:
	segs.append({"k": "carry", "t0": t0, "t1": t1, "side": side, "part": part, "gap": gap})
	return self


func touch(t: float, part: String, kind: String = "hit") -> Object:
	touches.append({"t": t, "part": part, "kind": kind})
	return self


func done(tt: float) -> Object:
	prep(tt)
	_spin_tab()
	return self


## curve pronte (senza la rotazione del pallone)
func prep(tt: float) -> Object:
	T = tt
	_by_t(pelvis_k)
	_by_t(bend_k)
	_by_t(head_k)
	_by_t(segs, "t0")
	_pelvis_p = Curva.new(pelvis_k)
	_pelvis_a = []
	for n: String in ["yaw", "pitch", "roll"]:
		var keys: Array = []
		for k: Dictionary in pelvis_k:
			keys.append({"t": k.t, "p": Vector3(k[n], 0, 0)})
		_pelvis_a.append(Curva.new(keys))
	if not bend_k.is_empty():
		var bk: Array = []
		for k: Dictionary in bend_k:
			bk.append({"t": k.t, "p": k.b})
		_bend_c = Curva.new(bk)
	if not head_k.is_empty():
		var hk: Array = []
		for k: Dictionary in head_k:
			hk.append({"t": k.t, "p": Vector3(k.h.x, k.h.y, 0)})
		_head_c = Curva.new(hk)
	for s: String in ["l", "r"]:
		var kk: Array = _by_t(leg_k[s])
		if kk.is_empty():
			_leg_c[s] = null
		else:
			var poles: Array = []
			for k: Dictionary in kk:
				poles.append({"t": k.t, "p": k.pole})
			_leg_c[s] = {"p": Curva.new(kk), "q": QCurva.new(kk), "pole": Curva.new(poles)}
		var ak: Array = _by_t(arm_k[s])
		_arm_c[s] = Curva.new(ak) if not ak.is_empty() else null
	return self


# ---------------------------------------------------------------- valutazione
func pelvis_at(t: float) -> Dictionary:
	var yaw: float = _pelvis_a[0].at(t).x
	var pitch: float = _pelvis_a[1].at(t).x
	var roll: float = _pelvis_a[2].at(t).x
	return {"p": _pelvis_p.at(t), "q": Corpo.q_body(yaw, pitch, roll), "yaw": yaw}


func bend_at(t: float) -> Vector3:
	return _bend_c.at(t) if _bend_c != null else Vector3.ZERO


func head_at(t: float) -> Vector3:
	return _head_c.at(t) if _head_c != null else Vector3.ZERO


func trunk_at(t: float) -> Dictionary:
	var pp := pelvis_at(t)
	return Corpo.trunk(pp.p, pp.q, bend_at(t))


func foot_at(side: String, t: float) -> Dictionary:
	var c: Dictionary = _leg_c[side]
	return {"ankle": c.p.at(t), "fq": c.q.at(t), "pole": (c.pole.at(t) as Vector3).normalized()}


func foot_pt(side: String, t: float, part: String) -> Array:
	var f := foot_at(side, t)
	return Corpo.foot_point(side, f.ankle, f.fq, part)


func seg(t: float) -> Dictionary:
	var s: Dictionary = segs[0]
	for x: Dictionary in segs:
		if x.t0 <= t:
			s = x
	return s


func ball_at(t: float) -> Vector3:
	var s := seg(t)
	var tt: float = s.t1 - s.t0
	var u := clampf(t - s.t0, 0.0, tt)
	match s.k:
		"rest":
			return s.p
		"roll":
			if u >= tt:
				return s.p1
			return Curva.hermite(s.p0, s.v0, s.p1, s.v1, tt, u / tt) if u > 0.0 else s.p0
		"fly":
			var k := u / tt
			var p0: Vector3 = s.p0
			var p1: Vector3 = s.p1
			return Vector3(p0.x + (p1.x - p0.x) * k, p0.y + s.vy * u - G * u * u / 2.0, p0.z + (p1.z - p0.z) * k)
		"carry":   # il piede che preme non porta il pallone sotto terra
			var f := foot_pt(s.side, s.t0 + u, s.part)
			var p: Vector3 = f[0] + (f[1] as Vector3) * (R + float(s.gap))
			p.y = maxf(p.y, R)
			return p
	return Vector3(0, R, 0)


# rotazione del pallone, integrata una volta: rotola senza strisciare a terra o portato, giro costante in volo
func _spin_tab() -> void:
	var n := int(ceil(T / SPIN_DT)) + 2
	spin.resize(n)
	var q := Quaternion.IDENTITY
	var prev := ball_at(0.0)
	for i in n:
		spin[i] = q
		var t := (i + 1) * SPIN_DT
		var p := ball_at(t)
		var s := seg(t - SPIN_DT / 2.0)
		var w: Vector3
		if s.k == "fly" or s.k == "rest":
			w = s.get("spin", Vector3.ZERO)
		else:
			w = Y.cross((p - prev) / SPIN_DT) / R
		var a := w.length() * SPIN_DT
		if a > 1e-9:
			q = (Corpo.q_axis(w, a) * q).normalized()
		prev = p


func ball_q(t: float) -> Quaternion:
	var x := clampf(t, 0.0, T) / SPIN_DT
	var i := int(floor(x))
	i = mini(i, spin.size() - 1)
	return Corpo.q_slerp(spin[i], spin[mini(spin.size() - 1, i + 1)], x - i)


func active_w(side: String, t: float) -> float:
	var w := 0.0
	for ab: Vector2 in act_k[side]:
		w = maxf(w, Corpo.smooth((t - ab.x + ACT_EASE) / ACT_EASE) * Corpo.smooth((ab.y + ACT_EASE - t) / ACT_EASE))
	return w


## busto con lo sguardo verso il pallone: giro e inclinazione rispetto al petto, metà al collo e metà alla testa
func trunk_look(t: float, ball: Vector3) -> Dictionary:
	var pp := pelvis_at(t)
	var bend_v := bend_at(t)
	var tr0 := Corpo.trunk(pp.p, pp.q, bend_v)
	var to_b: Vector3 = Corpo.q_conj(tr0.q.spine_03) * (ball - ((tr0.p.Head as Vector3) + Vector3(0, 0.08, 0)))
	var hx := head_at(t)
	var hz := sqrt(to_b.x * to_b.x + to_b.z * to_b.z)
	var yaw := clampf(atan2(to_b.x, to_b.z), -0.9, 0.9) * Corpo.smooth(hz / 0.25) + hx.y
	var pitch := clampf(atan2(-to_b.y, hz), -LOOK_UP, 0.9) + hx.x
	var half := Corpo.q_axis(Y, yaw / 2.0) * Corpo.q_axis(X, pitch / 2.0)
	return {"P": pp, "tr": Corpo.trunk(pp.p, pp.q, bend_v, half, half)}


## posa completa al tempo t (0..T), nel riferimento del giocatore:
## {t, pelvis: {p, q}, yaw, rot: {osso: Quaternion}, legs: {l/r: {ankle, fq, pole, w}}, arms: {l/r: {hand, pole}}, ball: {p, q}}
func at(t: float) -> Dictionary:
	t = clampf(t, 0.0, T)
	var ball := ball_at(t)
	var tl := trunk_look(t, ball)
	var tr: Dictionary = tl.tr
	var pp: Dictionary = tl.P
	var legs := {}
	var arms := {}
	var q3: Quaternion = tr.q.spine_03
	for s: String in ["l", "r"]:
		if _leg_c[s] != null:
			var f := foot_at(s, t)
			legs[s] = {"ankle": f.ankle, "fq": f.fq, "pole": f.pole, "w": active_w(s, t)}
		var off: Vector3 = _arm_c[s].at(t) if _arm_c[s] != null else Vector3(0.2, -0.5, 0.05)
		var x: float = Corpo.SIDE[s]
		arms[s] = {"hand": Corpo.shoulder(tr, s) + q3 * Vector3(off.x * x, off.y, off.z), "pole": q3 * Vector3(0.35 * x, -0.25, -1)}
	return {"t": t, "pelvis": {"p": pp.p, "q": pp.q}, "yaw": pp.yaw, "rot": tr.q, "legs": legs, "arms": arms,
		"ball": {"p": ball, "q": ball_q(t)}}


## posa specchiata (sinistra <-> destra): lo stesso giochetto fatto con l'altro piede
static func mirror_frame(fr: Dictionary) -> Dictionary:
	var rot := {}
	for k: String in fr.rot:
		rot[k] = _mq(fr.rot[k])
	var legs := {}
	var arms := {}
	var o := {"l": "r", "r": "l"}
	for s: String in ["l", "r"]:
		var l: Variant = fr.legs.get(o[s])
		var a: Variant = fr.arms.get(o[s])
		if l != null:
			legs[s] = {"ankle": _mp(l.ankle), "fq": _mq(l.fq), "pole": _mp(l.pole), "w": l.w}
		if a != null:
			arms[s] = {"hand": _mp(a.hand), "pole": _mp(a.pole)}
	return {"t": fr.t, "pelvis": {"p": _mp(fr.pelvis.p), "q": _mq(fr.pelvis.q)}, "yaw": -float(fr.yaw), "rot": rot,
		"legs": legs, "arms": arms, "ball": {"p": _mp(fr.ball.p), "q": _mq(fr.ball.q)}}


static func _mp(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, p.z)


static func _mq(q: Quaternion) -> Quaternion:
	return Quaternion(q.x, -q.y, -q.z, q.w)
