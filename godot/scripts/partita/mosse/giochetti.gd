# I sei giochetti del dribbling come movimenti calcolati (porting di src/moves/tricks.js: versione "partita" e versione
# "menu", quella del campione sullo sfondo del menu) e la loro scelta (src/tricks.js). Il pallone lo muove il piede (il punto del piede è sul pallone quando lo spinge),
# a terra rotola, in aria vola con la gravità vera. Solo grafica: se il dribbling riesce lo decide il motore.
# Riferimento: x = sinistra del giocatore, y = su, z = avanti, metri del modello. Lato 1 = col destro (per −1 si
# specchia la posa con Mossa.mirror_frame).
extends RefCounted

const Mossa := preload("mossa.gd")
const Corpo := preload("corpo.gd")
const Palleggi := preload("palleggi.gd")

# in ordine di bellezza (src/tricks.js)
const TRICKS := [
	{"id": "finta", "name": "Finta di corpo"},
	{"id": "doppiopasso", "name": "Doppio passo"},
	{"id": "elastico", "name": "Elastico"},
	{"id": "veronica", "name": "Veronica"},
	{"id": "sombrero", "name": "Sombrero"},
	{"id": "arcobaleno", "name": "Bicicletta"},
]
const DRI_FIRST := 35.0   # sotto questo dribbling solo la finta di corpo
const DRI_STEP := 10.0    # ogni 10 punti di dribbling si sblocca un giochetto più bello

# misure dei palleggi (src/moves/juggle.js) usate dai giochetti
const BALL_R := 0.11
const STANCE := {"l": Vector2(0.14, 0.0), "r": Vector2(-0.14, -0.02)}  # piedi a terra (x, z)
const PELVIS := Vector3(0, 0.935, -0.045)
# in partita il pallone a schermo è più grande (raggio 0,21 m = 0,168 nelle misure del modello, scala 1,25)
# e il motore lo tiene 0,6 m davanti al giocatore (0,48 nel modello)
const MATCH_SCALE := 1.25
const MATCH_R := 0.21 / MATCH_SCALE
const MATCH_B := Vector3(0, 0.21 / MATCH_SCALE, 0.6 / MATCH_SCALE)
const PIVOT_OUT := 0.4
const ARMS_WIDE := Vector3(0.42, -0.3, 0.05)
const ARMS_REST := Vector3(0.2, -0.5, 0.05)
const SOMBRERO_H := {"menu": 1.9, "match": 1.6}   # punto più alto del volo (m)
const RAINBOW_H := {"menu": 2.3, "match": 2.3}
# opzioni (opt di src/moves/tricks.js): R raggio del pallone, B pallone fermo all'inizio e alla fine, k lentezza dei
# gesti (i voli no: quelli li decide la gravità), match = in partita (finisce quando il pallone torna giù, niente stop)
const MENU_OPT := {"R": BALL_R, "B": Vector3(0, BALL_R, 0.3), "k": 1.6, "match": false}
const MATCH_OPT := {"R": MATCH_R, "B": MATCH_B, "k": 1.0, "match": true}
const Y := Vector3(0, 1, 0)

static var _cache := {}


## giochetto più bello che il giocatore sa fare (indice in TRICKS)
static func best_trick(dri: float) -> int:
	return clampi(int(floor((dri - DRI_FIRST) / DRI_STEP)), 0, TRICKS.size() - 1)


## scelta: di solito il più bello che sa fare, a volte uno o due più semplici. r in [0, 1)
static func choose_trick(dri: float, r: float) -> Dictionary:
	var down := 0 if r < 0.6 else (1 if r < 0.9 else 2)
	return TRICKS[maxi(0, best_trick(dri) - down)]


## movimento del giochetto `id` (in cache: è sempre lo stesso per le stesse opzioni); opt = MATCH_OPT o MENU_OPT
static func trick_move(id: String, opt: Dictionary = MATCH_OPT) -> Mossa:
	var key := id + (":partita" if opt.match else ":menu")
	if not _cache.has(key):
		var mv: Mossa
		match id:
			"doppiopasso": mv = _doppiopasso(opt)
			"elastico": mv = _elastico(opt)
			"veronica": mv = _veronica(opt)
			"sombrero": mv = _sombrero(opt)
			"arcobaleno": mv = _arcobaleno(opt)
			_: mv = _finta(opt)
		_cache[key] = mv
	return _cache[key]


static func duration(id: String) -> float:
	return trick_move(id).T


## spostamento del pallone rispetto alla posizione vera durante il giochetto (q = avanzamento 0..1):
## Vector3(avanti, di lato verso `side` (col destro è la sinistra del giocatore), altezza) in metri del campo
static func ball_offset(id: String, q: float) -> Vector3:
	var mv := trick_move(id)
	var p: Vector3 = mv.ball_at(clampf(q, 0.0, 1.0) * mv.T)
	return Vector3((p.z - MATCH_B.z) * MATCH_SCALE, (p.x - MATCH_B.x) * MATCH_SCALE, (p.y - MATCH_B.y) * MATCH_SCALE)


static func _n(fq: Quaternion, part: String, side: String) -> Vector3:
	return Corpo.foot_normal(fq, part, side)


# punto `part` del piede che tocca il pallone in `ball`
static func _at(ball: Vector3, fq: Quaternion, part: String, side: String, r: float, gap: float = 0.0) -> Vector3:
	return ball - _n(fq, part, side) * (r + gap)


# col pallone grande della partita la punta (che è curva) entrerebbe nel pallone: la si tiene appena staccata
static func _toe_gap(r: float) -> float:
	return maxf(0.0, r - BALL_R) * 0.35


static func _plant(s: String) -> Vector2:
	return STANCE[s]


static func _base(opt: Dictionary) -> Mossa:
	var m := Mossa.new(float(opt.R))
	m.leg("l", {"t": 0.0, "plant": STANCE.l}).leg("r", {"t": 0.0, "plant": STANCE.r})
	m.pelvis(0.0, PELVIS).bend(0.0, Vector3(0.16, 0, 0)).arm("l", 0.0, ARMS_REST).arm("r", 0.0, ARMS_REST)
	return m


# fine: piedi di nuovo nella posizione di partenza (un piede appoggiato altrove fa un passo, non striscia)
static func _finish(m: Mossa, tt: float, yaw: float = 0.0) -> Mossa:
	for s: String in ["l", "r"]:
		var kk: Array = []
		for x: Dictionary in m.leg_k[s]:
			if x.t < tt - 1e-9:
				kk.append(x)
		Mossa._by_t(kk)
		var st: Vector2 = STANCE[s]
		if not kk.is_empty():
			var last: Dictionary = kk[-1]
			var lp: Vector3 = last.p
			if last.plant and Vector2(lp.x - st.x, lp.z - st.y).length() > 0.02 and tt - float(last.t) > 0.12:
				var mid := lp.lerp(Vector3(st.x, lp.y, st.y), 0.5)
				m.leg(s, {"t": (float(last.t) + tt) / 2.0, "ankle": mid + Vector3(0, 0.07, -0.1), "fq": Corpo.q_axis(Y, yaw)})
		m.leg(s, {"t": tt, "plant": st, "yaw": yaw})
	m.pelvis(tt, PELVIS, yaw).bend(tt, Vector3(0.16, 0, 0))
	m.arm("l", tt, ARMS_REST).arm("r", tt, ARMS_REST)
	return m.done(tt)


# ---------------------------------------------------------------- finta di corpo: peso a sinistra, poi via a destra
static func _finta(opt: Dictionary) -> Mossa:
	var m := _base(opt)
	var k: float = opt.k
	var b: Vector3 = opt.B
	var tt := 0.55 * k
	m.ball_rest(0.0, tt, b)
	m.leg("l", {"t": 0.06 * k, "plant": STANCE.l}).leg("l", {"t": 0.15 * k, "ankle": Vector3(0.24, 0.16, 0.06), "fq": Mossa.foot_q(-0.2, 0.2)})
	m.leg("l", {"t": 0.24 * k, "plant": Vector2(0.33, 0.06), "yaw": -0.3}).leg("l", {"t": 0.36 * k, "plant": Vector2(0.33, 0.06), "yaw": -0.3})
	m.leg("l", {"t": 0.46 * k, "ankle": Vector3(0.22, 0.15, 0.04), "fq": Mossa.foot_q(0, 0.2)})
	m.leg("r", {"t": 0.3 * k, "plant": STANCE.r}).leg("r", {"t": 0.4 * k, "ankle": Vector3(-0.24, 0.15, 0.08), "fq": Mossa.foot_q(0.1, 0.2)})
	m.leg("r", {"t": 0.48 * k, "plant": Vector2(-0.3, 0.1), "yaw": 0.2})
	m.active("l", 0.05 * k, 0.3 * k).active("r", 0.32 * k, 0.5 * k)
	m.pelvis(0.24 * k, Vector3(0.13, 0.88, 0.0), 0.25, 0.08, 0.14).pelvis(0.36 * k, Vector3(0.1, 0.875, 0.0), 0.2, 0.08, 0.12)
	m.pelvis(0.48 * k, Vector3(-0.1, 0.9, 0.05), -0.2, 0.06, -0.1)
	m.bend(0.24 * k, Vector3(0.25, 0.22, 0.25)).bend(0.36 * k, Vector3(0.25, 0.2, 0.2)).bend(0.48 * k, Vector3(0.2, -0.15, -0.2))
	m.arm("l", 0.24 * k, Vector3(0.25, -0.5, 0.1)).arm("r", 0.24 * k, Vector3(0.5, -0.15, 0.05))
	m.arm("l", 0.48 * k, Vector3(0.5, -0.15, 0.0)).arm("r", 0.48 * k, Vector3(0.2, -0.45, 0.15))
	return _finish(m, tt)


# ---------------------------------------------------------------- doppio passo: il destro gira sopra il pallone fermo
static func _doppiopasso(opt: Dictionary) -> Mossa:
	var m := _base(opt)
	var k: float = opt.k
	var b: Vector3 = opt.B
	var r: float = opt.R
	var tt := 0.85 * k
	var over := 2.0 * r + 0.15
	m.ball_rest(0.0, tt, b)
	_step_dp(m, "r", 0.02 * k, k, b, r, over)
	m.leg("r", {"t": 0.5 * k, "plant": Vector2(b.x - (r + 0.15), b.z - 0.22), "yaw": -0.3})
	_step_dp(m, "l", 0.4 * k, k, b, r, over)
	m.leg("r", {"t": 0.75 * k, "plant": Vector2(b.x - (r + 0.15), b.z - 0.22), "yaw": -0.3})
	m.leg("l", {"t": 0.75 * k, "plant": Vector2(b.x + (r + 0.15), b.z - 0.22), "yaw": 0.3})
	return _finish(m, tt)


static func _step_dp(m: Mossa, s: String, t0: float, k: float, b: Vector3, r: float, over: float) -> void:
	var x: float = Corpo.SIDE[s]
	m.leg(s, {"t": t0, "plant": STANCE[s]})
	m.leg(s, {"t": t0 + 0.09 * k, "ankle": Vector3(b.x + 0.12 * x * -1.0, over, b.z - 0.3), "fq": Mossa.foot_q(0.5 * x, 0.2)})
	m.leg(s, {"t": t0 + 0.17 * k, "ankle": Vector3(b.x + 0.0, over + 0.03, b.z - 0.02), "fq": Mossa.foot_q(0.9 * x, 0.15)})
	m.leg(s, {"t": t0 + 0.25 * k, "ankle": Vector3(b.x + x * (r + 0.13), over * 0.6, b.z - 0.1), "fq": Mossa.foot_q(0.4 * x, 0.2)})
	m.leg(s, {"t": t0 + 0.33 * k, "plant": Vector2(b.x + x * (r + 0.15), b.z - 0.22), "yaw": 0.3 * x})
	m.active(s, t0 + 0.02 * k, t0 + 0.33 * k)
	m.pelvis(t0 + 0.17 * k, Vector3(x * 0.04, 0.9, 0.0), 0.25 * x, 0.08, -0.08 * x).pelvis(t0 + 0.33 * k, Vector3(x * 0.1, 0.88, 0.02), 0.2 * x, 0.08, 0.1 * x)
	m.bend(t0 + 0.2 * k, Vector3(0.25, 0.12 * x, 0.2 * x))
	m.arm(s, t0 + 0.2 * k, Vector3(0.45, -0.25, 0.1)).arm("r" if s == "l" else "l", t0 + 0.2 * k, Vector3(0.4, -0.3, -0.05))


# ---------------------------------------------------------------- elastico: esterno del destro fuori, poi interno dentro
static func _elastico(opt: Dictionary) -> Mossa:
	var m := _base(opt)
	var k: float = opt.k
	var b: Vector3 = opt.B
	var r: float = opt.R
	var tt := 0.75 * k
	var out := 0.18 + (r - BALL_R)
	var fq_out := Mossa.foot_q(0.35, 0.05)
	var fq_in := Mossa.foot_q(-0.25, 0.05)
	var t1 := 0.12 * k
	var t2 := 0.3 * k
	var t3 := 0.42 * k
	var t4 := 0.5 * k
	var t_stop := 0.72 * k
	var b_out := Vector3(b.x - out, r, b.z)
	var b_rel := Vector3(b.x - out * 0.55, r, b.z)
	var v_rel := 2.0 * (b.x - b_rel.x) / (t_stop - t4)
	m.ball_rest(0.0, t1, b)
	m.leg("r", {"t": 0.03 * k, "plant": STANCE.r})
	m.leg("r", {"t": 0.06 * k, "ankle": Vector3(b.x + 0.06, 0.16, b.z - r - 0.25), "fq": fq_out})
	m.leg("r", {"t": t1, "part": "outside", "at": _at(b, fq_out, "outside", "r", r), "fq": fq_out})
	m.leg("r", {"t": t2, "part": "outside", "at": _at(b_out, fq_out, "outside", "r", r), "fq": fq_out, "v": Vector3(0.5, 0.6, 0)})
	m.ball_carry(t1, t2, "r", "outside").touch(t1, "r.outside", "carry")
	m.ball_rest(t2, t3, b_out)
	m.leg("r", {"t": t2 + (t3 - t2) * 0.35, "ankle": Vector3(b_out.x + 0.1, 2.0 * r + 0.12, b_out.z + 0.02), "fq": Mossa.foot_q(-0.2, 0.1)})
	m.leg("r", {"t": t2 + (t3 - t2) * 0.7, "ankle": Vector3(b_out.x - r - 0.12, 2.0 * r + 0.06, b_out.z - 0.05), "fq": Mossa.foot_q(-0.25, 0.05)})
	m.leg("r", {"t": t3, "part": "inside", "at": _at(b_out, fq_in, "inside", "r", r), "fq": fq_in})
	m.leg("r", {"t": t4, "part": "inside", "at": _at(b_rel, fq_in, "inside", "r", r), "fq": fq_in, "v": Vector3(v_rel, 0, 0)})
	m.ball_carry(t3, t4, "r", "inside").touch(t3, "r.inside", "carry")
	m.ball_roll(t4, t_stop, b_rel, b, Vector3(v_rel, 0, 0), Vector3.ZERO)
	m.leg("r", {"t": t4 + 0.08 * k, "ankle": Vector3(b_rel.x - r - 0.1, 0.15, b.z - 0.2), "fq": Mossa.foot_q(-0.1, 0.1)})
	m.leg("r", {"t": t_stop, "plant": STANCE.r})
	m.ball_rest(t_stop, tt, b)
	m.active("r", 0.04 * k, t4 + 0.1 * k)
	m.pelvis(t2, Vector3(0.07, 0.9, 0.0), -0.15, 0.08, 0.06).pelvis(t4, Vector3(0.06, 0.9, 0.02), 0.2, 0.08, 0.06)
	m.bend(t2, Vector3(0.24, 0.1, -0.15)).bend(t4, Vector3(0.24, 0.08, 0.15))
	m.arm("l", t2, ARMS_WIDE).arm("r", t2, Vector3(0.35, -0.3, -0.1)).arm("r", t4, ARMS_WIDE)
	return _finish(m, tt)


# rotazione attorno a un perno verticale: punto e giro
static func _rot(p: Vector3, kk: Vector3, a: float) -> Vector3:
	var d := p - kk
	var c := cos(a)
	var s := sin(a)
	return Vector3(kk.x + d.x * c + d.z * s, p.y, kk.z - d.x * s + d.z * c)


# ---------------------------------------------------------------- veronica: suola sul pallone e giro, due mezzi giri
static func _veronica(opt: Dictionary) -> Mossa:
	var m := _base(opt)
	var k: float = opt.k
	var b: Vector3 = opt.B
	var r: float = opt.R
	var tt := 1.0 * k
	var t_on := 0.12 * k
	var t_mid := 0.42 * k
	var t_sw := 0.5 * k
	var t_end2 := 0.8 * k
	var k1 := Vector3(STANCE.l.x, 0, STANCE.l.y)
	var top := b + Vector3(0, r, 0)
	var fq0 := Mossa.foot_q(0, 0.02)
	m.ball_rest(0.0, t_on, b)
	m.leg("r", {"t": 0.03 * k, "plant": STANCE.r}).leg("r", {"t": 0.08 * k, "ankle": Vector3(b.x - 0.06, 2.0 * r + 0.15, b.z - 0.15), "fq": fq0})
	# primo mezzo giro: suola del destro sul pallone, perno sul sinistro
	for i in 7:
		var u := i / 6.0
		var e := u * u * (3.0 - 2.0 * u)
		var a := 0.0 - PI * e
		var t := t_on + (t_mid - t_on) * u
		m.pelvis(t, _rot(PELVIS + Vector3(k1.x * 0.5, -0.03, 0.02), k1, a), a, 0.06, 0.06 * Corpo.SIDE["l"])
		m.leg("r", {"t": t, "part": "sole", "at": _rot(top, k1, a), "fq": Corpo.q_axis(Y, a)})
		m.leg("l", {"t": t, "plant": Vector2(k1.x, k1.z), "yaw": a})
	m.ball_carry(t_on, t_mid, "r", "sole").touch(t_on, "r.sole", "carry")
	# scambio: il destro scende accanto al sinistro, il sinistro sale sul pallone
	var ball_mid := _rot(b, k1, -PI)
	var k2 := Vector3(k1.x + 0.02, 0, k1.z + 0.02)
	m.ball_rest(t_mid, t_sw, ball_mid)
	m.leg("r", {"t": (t_mid + t_sw) / 2.0, "ankle": Vector3(k2.x - 0.05, 0.22, k2.z + 0.06), "fq": Corpo.q_axis(Y, -PI + PIVOT_OUT)})
	m.leg("r", {"t": t_sw, "plant": Vector2(k2.x, k2.z), "yaw": -PI + PIVOT_OUT})
	m.leg("l", {"t": (t_mid + t_sw) / 2.0, "ankle": Vector3(k1.x, 0.2, k1.z).lerp(ball_mid + Vector3(0, r + 0.2, 0), 0.5), "fq": Corpo.q_axis(Y, -PI)})
	var top2 := ball_mid + Vector3(0, r, 0)
	# secondo mezzo giro, sul destro
	for i in 7:
		var u := i / 6.0
		var e := u * u * (3.0 - 2.0 * u)
		var a := -PI - PI * e
		var t := t_sw + (t_end2 - t_sw) * u
		var da := a + PI
		var pc := _rot(_rot(PELVIS + Vector3(k1.x * 0.5, -0.03, 0.02), k1, -PI), k2, da)
		m.pelvis(t, pc, a, 0.06, -0.06)
		m.leg("l", {"t": t, "part": "sole", "at": _rot(top2, k2, da), "fq": Corpo.q_axis(Y, a)})
		m.leg("r", {"t": t, "plant": Vector2(k2.x, k2.z), "yaw": a + PIVOT_OUT})
	m.ball_carry(t_sw, t_end2, "l", "sole").touch(t_sw, "l.sole", "carry")
	# il sinistro lascia il pallone e si rimette dov'era (il pallone torna in B)
	var t_back := t_end2 + 0.08 * k
	m.leg("l", {"t": t_back, "part": "sole", "at": top, "fq": Corpo.q_axis(Y, -2.0 * PI)})
	m.ball_carry(t_end2, t_back, "l", "sole")
	m.ball_rest(t_back, tt, b)
	m.leg("l", {"t": t_back + 0.07 * k, "ankle": top + Vector3(0.08, 0.1, -0.12), "fq": Corpo.q_axis(Y, -2.0 * PI)})
	m.active("r", 0.02 * k, t_sw).active("l", t_mid, t_back + 0.05 * k)
	m.bend(t_on, Vector3(0.2, 0, 0)).bend(t_end2, Vector3(0.2, 0, 0))
	m.arm("l", t_mid, ARMS_WIDE).arm("r", t_mid, ARMS_WIDE)
	return _finish(m, tt, -2.0 * PI)


# ---------------------------------------------------------------- sombrero: suola indietro, punta sotto, pallone alto
static func _sombrero(opt: Dictionary) -> Mossa:
	var m := _base(opt)
	var k: float = opt.k
	var b: Vector3 = opt.B
	var r: float = opt.R
	var h: float = SOMBRERO_H.match if opt.match else SOMBRERO_H.menu
	var t_on := 0.12 * k
	var t_rel := 0.26 * k
	var t_toe := 0.36 * k
	var t_up := 0.46 * k
	var back := b + Vector3(0, 0, -0.1)
	var toe_ball := b + Vector3(-0.02, 0, -0.16)
	var rel := Vector3(b.x - 0.03, r + 0.13, b.z + 0.27)
	var fq_toe := Mossa.foot_q(0, 0.15)
	var fq_rel := Mossa.foot_q(0, -0.25)
	m.ball_rest(0.0, t_on, b)
	m.leg("r", {"t": 0.03 * k, "plant": STANCE.r})
	m.leg("r", {"t": 0.08 * k, "part": "sole", "at": b + Vector3(-0.04, 2.0 * r + 0.06, -0.16), "fq": Mossa.foot_q(0, -0.1)})
	m.leg("r", {"t": t_on, "part": "sole", "at": b + Vector3(0, r, 0), "fq": Mossa.foot_q(0, 0.05)})
	m.leg("r", {"t": t_rel, "part": "sole", "at": back + Vector3(0, r, 0), "fq": Mossa.foot_q(0, 0.05)})
	m.ball_carry(t_on, t_rel, "r", "sole").touch(t_on, "r.sole", "carry")
	m.ball_roll(t_rel, t_toe, back, toe_ball, Vector3(0, 0, (back.z - b.z) / (t_rel - t_on)), Vector3(0, 0, -0.15))
	m.leg("r", {"t": t_rel + 0.05 * k, "ankle": Vector3(b.x - 0.03, 2.0 * r + 0.12, back.z - 0.32), "fq": Mossa.foot_q(0, 0)})
	m.leg("r", {"t": t_toe, "part": "toe", "at": _at(toe_ball, fq_toe, "toe", "r", r), "fq": fq_toe})
	m.leg("r", {"t": t_up, "part": "toe", "at": _at(rel, fq_rel, "toe", "r", r), "fq": fq_rel, "v": Vector3(0, 0.5, 0.4)})
	m.ball_carry(t_toe, t_up, "r", "toe").touch(t_toe, "r.toe", "carry")
	m.leg("r", {"t": t_up + 0.14 * k, "ankle": Vector3(-0.09, 0.12, 0.08), "fq": Mossa.foot_q(0, 0.2)})
	m.active("r", 0.02 * k, t_up + 0.1 * k)
	m.pelvis(t_on, Vector3(0.06, 0.92, -0.04), 0, 0.05, 0.04).pelvis(t_up, Vector3(0.04, 0.9, 0.0), 0, -0.02, 0.04)
	m.arm("l", t_up, ARMS_WIDE).arm("r", t_up, ARMS_WIDE)
	if opt.match: # in partita il pallone ricade davanti (dove il motore lo porta) e lì finisce il giochetto
		var t_l := t_up + Mossa.flight_time(rel.y, h, r)
		m.ball_fly(t_up, t_l, rel, b, Vector3(-8, 0, 0))
		m.leg("r", {"t": t_l, "plant": STANCE.r})
		return _finish(m, t_l)
	# nel menu ricade, rimbalza e il destro lo ferma con la suola
	var plants := Palleggi.start_plants()
	plants.r.append([t_up + 0.3 * k, STANCE.r])
	m.leg("r", {"t": t_up + 0.3 * k, "plant": STANCE.r})
	m.pelvis(t_up + 0.5, PELVIS + Vector3(0, 0.01, 0)).bend(t_up + 0.4, Vector3.ZERO)
	var t_end := Palleggi.land_stop(m, t_up, rel, h, b, plants, "l")
	m.pelvis(t_end, PELVIS).arm("l", t_end, ARMS_REST).arm("r", t_end, ARMS_REST)
	return _finish(m, t_end)


# ---------------------------------------------------------------- arcobaleno: tacco sinistro che lancia il pallone sopra la testa
static func _arcobaleno(opt: Dictionary) -> Mossa:
	var m := _base(opt)
	var k: float = opt.k
	var b: Vector3 = opt.B
	var r: float = opt.R
	var h: float = RAINBOW_H.match if opt.match else RAINBOW_H.menu
	var t_on := 0.12 * k
	var t_a := 0.28 * k
	var t_b := 0.4 * k
	var t_toe := 0.5 * k
	var t_lift := 0.62 * k
	var t_flick := 0.7 * k
	var sl: Vector2 = STANCE.l
	var heel_z := sl.y - 0.056
	var p_a := Vector3(b.x - 0.02, r, sl.y - 0.04 - 1.5 * (r - BALL_R))
	var p_b := Vector3(sl.x - 0.01, r, heel_z - r - 0.03)
	m.ball_rest(0.0, t_on, b)
	m.leg("r", {"t": 0.03 * k, "plant": STANCE.r})
	m.leg("r", {"t": 0.08 * k, "part": "sole", "at": b + Vector3(-0.04, 2.0 * r + 0.06, -0.14), "fq": Mossa.foot_q(0, -0.1)})
	m.leg("r", {"t": t_on, "part": "sole", "at": b + Vector3(0, r, 0), "fq": Mossa.foot_q(0, 0.05)})
	m.leg("r", {"t": t_a, "part": "sole", "at": p_a + Vector3(0, r, 0), "fq": Mossa.foot_q(0.1, 0.05)})
	m.leg("r", {"t": t_b, "part": "sole", "at": p_b + Vector3(0, r, 0), "fq": Mossa.foot_q(0.5, 0.05)})
	m.ball_carry(t_on, t_b, "r", "sole").touch(t_on, "r.sole", "carry")
	m.ball_rest(t_b, t_toe, p_b)
	# il destro scende dietro il pallone con la punta sotto
	var fq_toe := Mossa.foot_q(0.3, 0.35)
	var rise := Vector3(p_b.x + 0.02, r + 0.18, p_b.z - 0.02)
	var fq_rise := Mossa.foot_q(0.3, -0.2)
	m.leg("r", {"t": (t_b + t_toe) / 2.0, "ankle": Vector3(p_b.x - 0.08, 2.0 * r + 0.1, p_b.z - 0.25), "fq": Mossa.foot_q(0.4, 0.2)})
	m.leg("r", {"t": t_toe, "part": "toe", "at": _at(p_b, fq_toe, "toe", "r", r, _toe_gap(r)), "fq": fq_toe})
	m.leg("r", {"t": t_lift, "part": "toe", "at": _at(rise, fq_rise, "toe", "r", r, _toe_gap(r)), "fq": fq_rise})
	m.leg("r", {"t": t_lift + 0.05 * k, "ankle": Vector3(p_b.x - r - 0.1, 0.13, p_b.z - 0.2), "fq": Mossa.foot_q(0.2, 0.1)})
	m.ball_carry(t_toe, t_lift, "r", "toe", _toe_gap(r)).touch(t_toe, "r.toe", "carry")
	m.leg("r", {"t": t_lift + 0.12 * k, "plant": Vector2(STANCE.r.x + 0.05, STANCE.r.y - 0.05)})
	# tacco sinistro: la gamba si piega dietro, il tallone sale sotto il pallone e lo lancia
	var fq_heel := Mossa.foot_q(0, 1.3)
	var heel_ball := Vector3(rise.x, rise.y + 0.06, rise.z + 0.01)
	var h_at := _at(heel_ball, fq_heel, "heel", "l", r)
	m.leg("l", {"t": t_b, "plant": sl}).leg("l", {"t": t_toe + 0.04 * k, "plant": sl})
	m.leg("l", {"t": t_flick, "part": "heel", "at": h_at, "fq": fq_heel, "pole": Vector3(0, -0.3, 1), "v": Vector3(0, 1.6, -0.4)})
	m.ball_roll(t_lift, t_flick, rise, heel_ball, Vector3(0, 0.9, 0), Vector3(0, 0.9, 0.05))
	m.touch(t_flick, "l.heel")
	m.leg("l", {"t": t_flick + 0.18 * k, "plant": Vector2(sl.x, sl.y + 0.12)})
	m.active("r", 0.02 * k, t_lift + 0.06 * k).active("l", t_toe, t_flick + 0.1 * k)
	# busto in avanti mentre il tacco sale, poi indietro a guardarlo scendere
	m.pelvis(t_toe, Vector3(0.05, 0.9, -0.1 - (r - BALL_R)), 0.2, 0.1, 0.05)
	m.pelvis(t_b, Vector3(0.05, 0.92, -0.06), 0.15, 0.08, 0.05).pelvis(t_flick, Vector3(-0.04, 0.88, 0.02), 0, 0.25, -0.08)
	m.bend(t_toe, Vector3(0.25, 0, 0)).bend(t_flick, Vector3(0.4, -0.05, 0)).bend(t_flick + 0.45, Vector3(-0.12, 0, 0))
	m.pelvis(t_flick + 0.6, Vector3(-0.01, 0.91, -0.09), 0, -0.08, 0)
	m.arm("l", t_flick, Vector3(0.45, -0.2, 0.3)).arm("r", t_flick, Vector3(0.45, -0.2, 0.3))
	if opt.match:
		var t_l := t_flick + Mossa.flight_time(heel_ball.y, h, r)
		m.ball_fly(t_flick, t_l, heel_ball, b, Vector3(-10, 0, 0))
		return _finish(m, t_l)
	var plants := Palleggi.start_plants()
	plants.l.append([t_flick + 0.18 * k, Vector2(sl.x, sl.y + 0.12)])
	plants.r.append([t_lift + 0.12 * k, STANCE.r])
	var t_end := Palleggi.land_stop(m, t_flick, heel_ball, h, b, plants, "l")
	m.pelvis(t_end, PELVIS)
	return _finish(m, t_end)
