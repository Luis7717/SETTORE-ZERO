# Palleggi del campione sullo sfondo del menu (porting di src/moves/juggle.js): il pallone parte fermo a terra, il
# destro lo tira indietro con la suola e lo alza con la punta, poi collo del piede (destro e sinistro), coscia e un
# colpo di testa, infine lo stop di suola. Fra un tocco e l'altro il pallone vola con la gravità vera: tempo di volo =
# salita + discesa fino al tocco dopo (Mossa.flight_time). Il piede va a incontrare il pallone nel punto e nell'istante
# del contatto. Qui ci sono anche land_stop e kick, che usano i giochetti del menu (sombrero, arcobaleno).
# Riferimento: x = sinistra del giocatore, y = su, z = avanti, metri del modello.
extends RefCounted

const Mossa := preload("mossa.gd")
const Corpo := preload("corpo.gd")

const BALL_R := 0.11                                        # raggio vero del pallone (m)
const BASE := Vector3(0, BALL_R, 0.3)                       # pallone fermo davanti ai piedi
const STANCE := {"l": Vector2(0.14, 0.0), "r": Vector2(-0.14, -0.02)}   # piedi a terra (x, z)
const PELVIS := Vector3(0, 0.935, -0.045)                   # bacino in piedi, ginocchia appena piegate
const BEND := 0.16                  # busto in avanti a guardare il pallone (rad)
const INSTEP_Y := 0.31              # centro del pallone al tocco di collo (destro: x negativa): gamba quasi tesa e
const INSTEP_X := 0.085             # piede avanti, così lo stinco resta lontano dal pallone
const INSTEP_Z := 0.5
const KICK_UP := 0.3                # s: il piede parte da terra prima del tocco...
const KICK_DOWN := 0.32             # ... e ci torna dopo
const KICK_V := Vector3(0, 0.7, 0.15)   # m/s: il piede sale ancora quando tocca il pallone
const SPIN_HARD := -9.0             # rad/s attorno a x: effetto all'indietro (collo; coscia e testa)
const SPIN_SOFT := -3.0
const SHIFT := 0.055                # m: il bacino va sul piede d'appoggio
const THIGH_EL := 0.2               # coscia appena sotto l'orizzontale...
const THIGH_KNEE := 1.75            # ... ginocchio piegato...
const THIGH_UP := 0.38              # ... s di salita
const LIFT_H := 1.05                # m: alzata iniziale con la punta del destro
const SOLE_GAP := 0.012             # la suola della scarpa è più spessa del punto misurato sullo scheletro
const BOUNCE := 0.5                 # rimbalzo sull'erba: velocità in su / velocità in giù
const BOUNCE_LOW := 0.16            # sotto i 16 cm di rimbalzo, lo stop
const STOP_TOE := 0.6               # rad: punta in su nello stop di suola
const HEAD_DOWN := 0.28             # rad: nel colpo di testa la testa guarda meno in alto (fronte sul pallone)
const HEAD_ITER := 8                # volte in cui si cerca il punto del colpo di testa
const ARMS_REST := Vector3(0.2, -0.5, 0.05)

# tocchi dopo la prima alzata: chi tocca e punto più alto del volo che segue (m da terra)
const JUGGLE_SEQ := [
	["l.instep", 1.0], ["r.instep", 1.1], ["l.instep", 0.95], ["r.instep", 1.4], ["r.thigh", 1.45],
	["l.instep", 1.0], ["r.instep", 2.55], ["head", 2.25], ["l.thigh", 1.45], ["r.instep", 1.0], ["l.instep", 0.62],
]


# variazione fissa per tocco (niente numeri casuali)
static func _jit(i: int, k: int) -> float:
	return sin(i * 12.9898 + k * 78.233) * 0.5


# normale del punto del piede (uguale per i due lati in y, z)
static func _nrm(fq: Quaternion, part: String) -> Vector3:
	return fq * (Corpo.FOOT_PTS[part][1] as Vector3)


static func _side(s: String) -> float:
	return Corpo.SIDE[s]


## appoggi dei piedi all'inizio (per kick e land_stop)
static func start_plants() -> Dictionary:
	return {"l": [[0.0, STANCE.l]], "r": [[0.0, STANCE.r]]}


## i palleggi interi (11 s circa)
static func juggle_move(r: float = BALL_R) -> Mossa:
	var m := Mossa.new(r)
	var b0 := Vector3(0, r, BASE.z)
	var plants := start_plants()
	m.leg("l", {"t": 0.0, "plant": STANCE.l}).leg("r", {"t": 0.0, "plant": STANCE.r})
	m.bend(0.0, Vector3(BEND, 0, 0)).arm("l", 0.0, ARMS_REST).arm("r", 0.0, ARMS_REST)
	# ---- prima alzata: suola sul pallone, lo tira indietro; lasciato, rotola sulla punta che lo alza
	var t_on := 0.35
	var t_rel := 0.62
	var t_toe := 0.9
	var t_up := 1.06
	var back := Vector3(0, r, b0.z - 0.1)
	var toe_ball := Vector3(-0.02, r, b0.z - 0.17)
	var rel_ball := Vector3(-0.04, 0.28, b0.z + 0.2)
	var fq_toe := Mossa.foot_q(0, 0.18)
	var fq_rel := Mossa.foot_q(0, -0.15)
	m.ball_rest(0.0, t_on, b0)
	m.leg("r", {"t": 0.08, "plant": STANCE.r})
	m.leg("r", {"t": 0.22, "part": "sole", "at": b0 + Vector3(-0.04, 2.0 * r + 0.07, -0.16), "fq": Mossa.foot_q(0, -0.1)}) # su e dietro, poi sopra
	m.leg("r", {"t": t_on, "part": "sole", "at": b0 + Vector3(0, r, 0), "fq": Mossa.foot_q(0, 0.05), "v": Vector3(0, -0.3, 0.2)})
	m.leg("r", {"t": t_rel, "part": "sole", "at": back + Vector3(0, r, 0), "fq": Mossa.foot_q(0, 0.05)})
	m.ball_carry(t_on, t_rel, "r", "sole").touch(t_on, "r.sole", "carry")
	m.ball_roll(t_rel, t_toe, back, toe_ball, Vector3(0, 0, (back.z - b0.z) / (t_rel - t_on)), Vector3(0, 0, -0.2))
	# il piede si alza (la punta passa sopra il pallone), va dietro e appoggia la punta sulla strada del pallone
	m.leg("r", {"t": t_rel + 0.1, "ankle": Vector3(-0.03, 0.34, back.z - 0.32), "fq": Mossa.foot_q(0, 0)})
	m.leg("r", {"t": t_rel + 0.19, "ankle": Vector3(-0.03, 0.1, back.z - 0.37), "fq": Mossa.foot_q(0, 0.25)})
	m.leg("r", {"t": t_toe, "part": "toe", "at": toe_ball - _nrm(fq_toe, "toe") * r, "fq": fq_toe})
	m.leg("r", {"t": t_up, "part": "toe", "at": rel_ball - _nrm(fq_rel, "toe") * r, "fq": fq_rel, "v": Vector3(0, 0.8, 0.6)})
	m.leg("r", {"t": t_up + 0.12, "ankle": Vector3(-0.07, 0.13, 0.06), "fq": Mossa.foot_q(0, 0.2)})  # giù e indietro
	m.ball_carry(t_toe, t_up, "r", "toe").touch(t_toe, "r.toe", "carry")
	m.leg("r", {"t": t_up + KICK_DOWN, "plant": STANCE.r})
	plants.r.append([t_up + KICK_DOWN, STANCE.r])
	m.pelvis(0.0, PELVIS).pelvis(t_on, PELVIS + Vector3(SHIFT, -0.02, 0), 0, 0, 0.03).pelvis(t_up, PELVIS + Vector3(SHIFT * 0.8, -0.01, 0))
	var t := t_up
	var from := rel_ball
	var h := LIFT_H
	var soft := false
	var last := "r"
	# ---- tocchi
	for i in JUGGLE_SEQ.size():
		var who: String = JUGGLE_SEQ[i][0]
		var next_h: float = JUGGLE_SEQ[i][1]
		var head := who == "head"
		var s := "" if head else who.substr(0, 1)
		var part := "head" if head else who.substr(2)
		var tc: float
		var ball: Vector3
		if part == "instep":
			ball = Vector3(_side(s) * (INSTEP_X + 0.012 * _jit(i, 1)), INSTEP_Y + 0.02 * _jit(i, 2), INSTEP_Z + 0.03 * _jit(i, 3))
			tc = t + Mossa.flight_time(from.y, h, ball.y)
			var fq_in := Mossa.foot_q(0, -0.3)   # caviglia bloccata, punta un po' su: la normale del collo va in alto
			kick(m, s, tc, {"part": "instep", "at": ball - _nrm(fq_in, "instep") * r, "fq": fq_in, "v": KICK_V}, plants, last, KICK_UP)
			m.pelvis(tc, PELVIS + Vector3(-_side(s) * SHIFT, -0.025, 0), 0, 0, -_side(s) * 0.03)
		elif part == "thigh":
			# coscia alzata: il pallone cade sul davanti della coscia; la gamba è data da anca e angoli (nessuna stima)
			var pel := PELVIS + Vector3(-_side(s) * SHIFT, -0.01, -0.02)
			var pq := Corpo.q_body(0, -0.06, -_side(s) * 0.04)
			var hip := Corpo.hip(Corpo.trunk(pel, pq), s)
			var d := Vector3(0, -sin(THIGH_EL), cos(THIGH_EL))
			var hh := Vector3(1, 0, 0)
			var knee := hip + d * Corpo.THIGH_L
			var ankle := knee + (Corpo.q_axis(hh, THIGH_KNEE) * d) * Corpo.CALF_L
			var tp := Corpo.thigh_point(hip, d, hh)
			ball = (tp[0] as Vector3) + (tp[1] as Vector3) * r
			tc = t + Mossa.flight_time(from.y, h, ball.y)
			m.pelvis(tc, pel, 0, -0.06, -_side(s) * 0.04)
			kick(m, s, tc, {"ankle": ankle, "fq": Mossa.foot_q(0, 0.55), "pole": (knee - hip.lerp(ankle, 0.5)).normalized(), "v": Vector3(0, 1.0, 0.25)}, plants, last, THIGH_UP)
			m.bend(tc - 0.25, Vector3(BEND, 0, 0)).bend(tc, Vector3(0.05, 0, 0)).bend(tc + 0.3, Vector3(BEND, 0, 0))
		else:
			# testa: sotto il pallone, le gambe si distendono, busto dritto e sguardo in alto. La testa al contatto
			# dipende dallo sguardo (che segue il pallone): si cerca il punto qualche volta
			var guess := Vector3(0, 1.97, 0.1)
			tc = t + Mossa.flight_time(from.y, h, guess.y)
			var k0 := [m.pelvis_k.size(), m.bend_k.size(), m.head_k.size()]
			for it in HEAD_ITER:
				m.pelvis_k.resize(k0[0])
				m.bend_k.resize(k0[1])
				m.head_k.resize(k0[2])
				m.pelvis(tc - 0.28, PELVIS + Vector3(0, -0.045, 0.02)).pelvis(tc, PELVIS + Vector3(0, 0.012, 0.04)).pelvis(tc + 0.28, PELVIS + Vector3(0, -0.02, 0))
				m.bend(tc - 0.3, Vector3(BEND, 0, 0)).bend(tc, Vector3(0.02, 0, 0)).bend(tc + 0.4, Vector3(BEND, 0, 0))
				m.head(tc - 0.3, Vector2(0, 0)).head(tc, Vector2(HEAD_DOWN, 0)).head(tc + 0.3, Vector2(0, 0))
				m.prep(tc + 1.0)
				var hp := Corpo.head_pt(m.trunk_look(tc, guess).tr)
				guess = (hp[0] as Vector3) + (hp[1] as Vector3) * r
				tc = t + Mossa.flight_time(from.y, h, guess.y)
			ball = guess
			m.arm("l", tc, Vector3(0.38, -0.25, 0.1)).arm("r", tc, Vector3(0.38, -0.25, 0.1))
		m.touch(tc, "head" if head else who)
		m.ball_fly(t, tc, from, ball, Vector3(SPIN_SOFT if soft else SPIN_HARD, 0, 0))
		if s != "":
			m.arm(s, tc, Vector3(0.28, -0.42, 0.14)).arm("r" if s == "l" else "l", tc, Vector3(0.46, -0.3, 0.02))
		t = tc
		from = ball
		h = maxf(next_h, ball.y + 0.15)
		soft = part != "instep"
		last = s if s != "" else "head"
		# a metà volo: bacino al centro, braccia rilassate
		var tn := t + Mossa.flight_time(ball.y, h, INSTEP_Y) * 0.5
		if part != "head":
			m.pelvis(tn, PELVIS + Vector3(0, 0.005, 0))
		m.arm("l", tn, Vector3(0.3, -0.42, 0.06)).arm("r", tn, Vector3(0.3, -0.42, 0.06))
	var t_end := land_stop(m, t, from, h, Vector3(0, r, BASE.z), plants, last)
	m.pelvis(t_end, PELVIS)
	m.arm("l", t_end, ARMS_REST).arm("r", t_end, ARMS_REST)
	return m.done(t_end)


## Fine di un volo alto: il pallone scende, rimbalza (il terreno gli toglie metà della velocità) finché sale meno di
## BOUNCE_LOW e il destro lo ferma con la suola quando ritocca terra in `stop`. La suola è inclinata (punta in su):
## arriva da dietro e chiude il pallone contro il terreno. Ritorna il tempo in cui il destro è di nuovo a terra.
static func land_stop(m: Mossa, t: float, from: Vector3, h: float, stop: Vector3, plants: Dictionary, last: String) -> float:
	var r := m.R
	var t_b := t + Mossa.flight_time(from.y, h, r)
	var p := Vector3(stop.x + from.x * 0.2, r, stop.z + 0.1)
	var v := BOUNCE * sqrt(2.0 * Mossa.G * (h - r))
	var tt := t_b
	m.ball_fly(t, t_b, from, p, Vector3(SPIN_HARD, 0, 0)).touch(t_b, "ground", "bounce")
	while v * v / (2.0 * Mossa.G) > BOUNCE_LOW:
		var q := p.lerp(stop, 0.5)
		var tn := tt + 2.0 * v / Mossa.G
		m.ball_fly(tt, tn, p, q, Vector3(SPIN_SOFT, 0, 0)).touch(tn, "ground", "bounce")
		p = q
		tt = tn
		v *= BOUNCE
	var t_land := tt + 2.0 * v / Mossa.G
	m.ball_fly(tt, t_land, p, stop, Vector3(SPIN_SOFT, 0, 0))
	var fq_stop := Mossa.foot_q(0, -STOP_TOE)
	var s_at := stop - (fq_stop * (Corpo.FOOT_PTS.sole[1] as Vector3)) * (r + SOLE_GAP)
	kick(m, "r", t_land, {"part": "sole", "at": s_at, "fq": fq_stop, "v": Vector3(0, -0.3, 0.6)}, plants, last, 0.36, true)
	m.leg("r", {"t": t_land - 0.15, "part": "sole", "at": s_at + Vector3(-0.02, 0.05, -0.2), "fq": fq_stop})
	m.leg("r", {"t": t_land + 0.28, "part": "sole", "at": s_at, "fq": fq_stop})
	m.touch(t_land, "r.sole", "stop")
	m.leg("r", {"t": t_land + 0.42, "part": "sole", "at": s_at + Vector3(-0.04, 0.06, -0.2), "fq": fq_stop}) # su e indietro
	var t_end := t_land + 0.28 + KICK_DOWN + 0.08
	m.leg("r", {"t": t_end, "plant": STANCE.r})
	m.leg("l", {"t": t_end, "plant": last_plant(plants.l, t_end)})
	m.ball_rest(t_land, t_end, stop)
	m.pelvis(t_land, PELVIS + Vector3(SHIFT, -0.03, 0), 0, 0, 0.03)
	return t_end


## ultimo appoggio del piede prima del tempo t (list = [[t, Vector2], ...])
static func last_plant(list: Array, t: float) -> Vector2:
	var pl: Vector2 = list[0][1]
	for e: Array in list:
		if float(e[0]) <= t:
			pl = e[1]
	return pl


## Gamba che tocca: parte da terra `up` secondi prima, arriva al contatto `hit` (con la sua velocità), torna a terra
## KICK_DOWN dopo vicino a dove era. Se la stessa gamba ha appena toccato non torna a terra in mezzo (resta su).
## hold = dopo il contatto il piede resta lì (lo stop): niente ritorno a terra qui
static func kick(m: Mossa, s: String, tc: float, hit: Dictionary, plants: Dictionary, last: String, up: float, hold: bool = false) -> void:
	var kk: Array = m.leg_k[s]
	if last == s and not kk.is_empty() and float(kk[-1].t) > tc - up:
		kk.pop_back() # toglie il ritorno a terra appena messo: la gamba passa da un tocco all'altro
		plants[s].pop_back()
		var mid := (float(kk[-1].t) + tc) / 2.0
		m.leg(s, {"t": mid, "ankle": Vector3(STANCE[s].x, 0.16, 0.12), "fq": Mossa.foot_q(0, 0.3), "pole": Vector3(0, 0.2, 1)})
	else:
		m.leg(s, {"t": tc - up, "plant": last_plant(plants[s], tc - up)})
	var k := hit.duplicate()
	k["t"] = tc
	m.leg(s, k)
	if hold:
		return
	# dopo il tocco il piede scende e torna indietro: la gamba si distende e il ginocchio resta fuori dalla strada
	if hit.get("part", "") == "instep":
		m.leg(s, {"t": tc + 0.1, "ankle": (m.leg_k[s][-1].p as Vector3) + Vector3(0, -0.1, -0.12), "fq": Mossa.foot_q(0, 0)})
	var n: int = plants[s].size()
	var st: Vector2 = STANCE[s]
	var p1 := Vector2(st.x + 0.02 * _jit(n, 5), st.y + 0.03 * _jit(n, 6))
	m.leg(s, {"t": tc + KICK_DOWN, "plant": p1})
	plants[s].append([tc + KICK_DOWN, p1])
