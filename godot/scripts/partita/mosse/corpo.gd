# Misure del corpo per i movimenti calcolati (porting di src/moves/body.js + la matematica di src/moves/vec.js):
# ossa del modello atleta in posa di legame nel riferimento del corpo (x = sinistra del giocatore, y = su,
# z = avanti; metri del modello, prima della scala del gioco), punti di contatto col pallone sul piede e la catena
# bacino → busto → testa. Numeri del gioco web (misurati sul modello con le proporzioni di PROPORZIONI.md): servono
# a calcolare i movimenti identici al web; chi mette le ossa in posa (figura.gd) usa le misure vere dello scheletro.
# Vettori = Vector3, rotazioni = Quaternion (stesso prodotto di Hamilton di vec.js).
extends RefCounted

const REST := {
	"pelvis": Vector3(0, 0.9673, -0.0434), "spine_01": Vector3(0, 1.0913, -0.007), "spine_02": Vector3(0, 1.1981, 0.0039),
	"spine_03": Vector3(0, 1.3324, 0.007), "neck_01": Vector3(0, 1.5439, -0.0418), "Head": Vector3(0, 1.6239, -0.0176),
	"clavicle_l": Vector3(0.0317, 1.5184, 0.0338), "upperarm_l": Vector3(0.1641, 1.4783, -0.066),
	"lowerarm_l": Vector3(0.4608, 1.4783, -0.0737), "hand_l": Vector3(0.7368, 1.4783, -0.066),
	"clavicle_r": Vector3(-0.0317, 1.5184, 0.0338), "upperarm_r": Vector3(-0.1641, 1.4783, -0.066),
	"lowerarm_r": Vector3(-0.4608, 1.4783, -0.0737), "hand_r": Vector3(-0.7368, 1.4783, -0.066),
	"thigh_l": Vector3(0.1153, 0.9896, -0.0363), "calf_l": Vector3(0.1153, 0.4715, -0.0364),
	"foot_l": Vector3(0.1153, 0.0805, -0.0883), "ball_l": Vector3(0.1153, 0.0207, 0.0497),
	"thigh_r": Vector3(-0.1153, 0.9896, -0.0363), "calf_r": Vector3(-0.1153, 0.4715, -0.0364),
	"foot_r": Vector3(-0.1153, 0.0805, -0.0883), "ball_r": Vector3(-0.1153, 0.0207, 0.0497),
}
const ANKLE_H := 0.0805                    # altezza della caviglia col piede piatto a terra
const SIDE := {"l": 1.0, "r": -1.0}        # da che parte sta ogni lato (x)

# punti del piede rispetto alla caviglia (lat = verso l'esterno, su, avanti) con la normale uscente
const FOOT_PTS := {
	"instep": [Vector3(0.017, -0.01, 0.125), Vector3(0, 0.876, 0.482)],
	"sole": [Vector3(0.017, -0.081, 0.07), Vector3(0, -1, 0)],
	"toe": [Vector3(0.017, -0.035, 0.205), Vector3(0, 0.45, 0.89)],
	"inside": [Vector3(-0.028, -0.045, 0.1), Vector3(-1, 0, 0)],
	"outside": [Vector3(0.062, -0.045, 0.11), Vector3(1, 0, 0)],
	"heel": [Vector3(0.015, -0.05, -0.056), Vector3(0, 0, -1)],
}

const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)


# ---------------------------------------------------------------- matematica (vec.js)
static func smooth(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func q_axis(ax: Vector3, ang: float) -> Quaternion:
	var n := ax.normalized()
	var s := sin(ang / 2.0)
	return Quaternion(n.x * s, n.y * s, n.z * s, cos(ang / 2.0))


## giro (attorno a y), poi inclinazione in avanti (pitch > 0: la testa va verso +z), poi di lato (roll > 0: verso +x)
static func q_body(yaw: float, pitch: float = 0.0, roll: float = 0.0) -> Quaternion:
	return q_axis(Y, yaw) * (q_axis(X, pitch) * q_axis(Z, -roll))


static func q_conj(q: Quaternion) -> Quaternion:
	return Quaternion(-q.x, -q.y, -q.z, q.w)


## slerp come vec.js (quasi uguali: interpolazione lineare normalizzata)
static func q_slerp(a: Quaternion, b: Quaternion, t: float) -> Quaternion:
	var c := a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
	var bb := b
	if c < 0.0:
		c = -c
		bb = Quaternion(-b.x, -b.y, -b.z, -b.w)
	if c > 0.9995:
		return Quaternion(a.x + (bb.x - a.x) * t, a.y + (bb.y - a.y) * t, a.z + (bb.z - a.z) * t, a.w + (bb.w - a.w) * t).normalized()
	var th := acos(c)
	var s := sin(th)
	var ka := sin((1.0 - t) * th) / s
	var kb := sin(t * th) / s
	return Quaternion(a.x * ka + bb.x * kb, a.y * ka + bb.y * kb, a.z * ka + bb.z * kb, a.w * ka + bb.w * kb)


## rotazione che porta la coppia (a1, b1) su (a2, b2): a esatto, b il più vicino possibile (Gram-Schmidt)
static func q_align(a1: Vector3, b1: Vector3, a2: Vector3, b2: Vector3) -> Quaternion:
	return _q_frame(a2, b2) * _q_frame(a1, b1).inverse()


static func _q_frame(a: Vector3, b: Vector3) -> Quaternion:
	var x := a.normalized()
	var z := x.cross(b).normalized()
	var y := z.cross(x)
	return Basis(x, y, z).get_rotation_quaternion()


# ---------------------------------------------------------------- corpo (body.js)
## punto del piede (lato side) nel riferimento del corpo: [punto, normale]
static func foot_point(side: String, ankle: Vector3, fq: Quaternion, part: String) -> Array:
	var fp: Array = FOOT_PTS[part]
	var s: float = SIDE[side]
	var p: Vector3 = fp[0]
	var n: Vector3 = fp[1]
	return [ankle + fq * Vector3(p.x * s, p.y, p.z), fq * Vector3(n.x * s, n.y, n.z)]


## caviglia che mette il punto `part` del piede in `at`
static func ankle_for(side: String, at: Vector3, fq: Quaternion, part: String) -> Vector3:
	var p: Vector3 = FOOT_PTS[part][0]
	var s: float = SIDE[side]
	return at - fq * Vector3(p.x * s, p.y, p.z)


## normale del punto `part` del piede ruotato di fq
static func foot_normal(fq: Quaternion, part: String, side: String) -> Vector3:
	var n: Vector3 = FOOT_PTS[part][1]
	return fq * Vector3(n.x * SIDE[side], n.y, n.z)


static func _off(a: String, b: String) -> Vector3:
	return (REST[b] as Vector3) - (REST[a] as Vector3)


## catena del busto: bacino in pp con rotazione pq, curva bend = (avanti, lato, giro) divisa sulle tre vertebre,
## collo e testa. Ritorna {q: rotazioni, p: posizioni, pq, pp}: le anche e le spalle con hip()/shoulder().
static func trunk(pp: Vector3, pq: Quaternion, bend: Vector3 = Vector3.ZERO, neck: Quaternion = Quaternion.IDENTITY,
		head: Quaternion = Quaternion.IDENTITY) -> Dictionary:
	var q1 := pq * _part(bend, 0.3)
	var q2 := q1 * _part(bend, 0.35)
	var q3 := q2 * _part(bend, 0.35)
	var qn := q3 * neck
	var qh := qn * head
	var p1 := pp + pq * _off("pelvis", "spine_01")
	var p2 := p1 + q1 * _off("spine_01", "spine_02")
	var p3 := p2 + q2 * _off("spine_02", "spine_03")
	var pn := p3 + q3 * _off("spine_03", "neck_01")
	var ph := pn + qn * _off("neck_01", "Head")
	return {
		"q": {"pelvis": pq, "spine_01": q1, "spine_02": q2, "spine_03": q3, "neck_01": qn, "Head": qh},
		"p": {"pelvis": pp, "spine_01": p1, "spine_02": p2, "spine_03": p3, "neck_01": pn, "Head": ph},
	}


static func _part(bend: Vector3, k: float) -> Quaternion:
	return q_axis(Y, bend.z * k) * (q_axis(X, bend.x * k) * q_axis(Z, -bend.y * k))


## anca del lato s
static func hip(tr: Dictionary, s: String) -> Vector3:
	return (tr.p.pelvis as Vector3) + (tr.q.pelvis as Quaternion) * _off("pelvis", "thigh_" + s)


## spalla (attacco del braccio) del lato s
static func shoulder(tr: Dictionary, s: String) -> Vector3:
	var q3: Quaternion = tr.q.spine_03
	return (tr.p.spine_03 as Vector3) + q3 * _off("spine_03", "clavicle_" + s) + q3 * _off("clavicle_" + s, "upperarm_" + s)
