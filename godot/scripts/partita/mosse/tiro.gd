# Tiro del campione sullo sfondo del menu e pallone nuovo che arriva rotolando per i palleggi del giro dopo
# (porting di src/moves/shot.js). Tiro: passo col sinistro accanto al pallone, destro indietro, collo pieno (piede
# disteso) sul dietro del pallone, accompagnamento. Il pallone parte con la velocità del tiro e vola con la gravità
# vera (ed effetto all'indietro). Riferimento: x = sinistra del giocatore, y = su, z = avanti, metri del modello.
extends RefCounted

const Mossa := preload("mossa.gd")
const Corpo := preload("corpo.gd")
const Palleggi := preload("palleggi.gd")

const SHOT_BALL := Vector3(0, Palleggi.BALL_R, 0.62)   # dove la corsa lascia il pallone prima del tiro
const SHOT_V := Vector3(0.4, 5.2, 21)                  # m/s: velocità del pallone appena calciato
const SHOT_SPIN := Vector3(-14, 0, 0)                  # rad/s: effetto all'indietro
const T_HIT := 0.56                                    # s: contatto
const T_END := 1.05                                    # s: fine del gesto
const DRIVE_DOWN := 1.07                               # piede disteso: la normale del collo guarda avanti
const ROLL_FROM := Vector3(-2.6, Palleggi.BALL_R, -1.2)   # pallone nuovo: da dietro a destra...
const ROLL_T := 1.7                                    # ... in tanti secondi
const ARMS_REST := Vector3(0.2, -0.5, 0.05)
const ARMS_END := Vector3(0.3, -0.4, 0.05)


static func shot_move(r: float = Palleggi.BALL_R) -> Mossa:
	var m := Mossa.new(r)
	var b := SHOT_BALL
	var pl := Vector2(0.2, b.z - 0.12)
	var stl: Vector2 = Palleggi.STANCE.l
	var str_: Vector2 = Palleggi.STANCE.r
	# gambe: sinistro a terra accanto al pallone, destro indietro e poi a colpire
	m.leg("l", {"t": 0.0, "plant": stl}).leg("l", {"t": 0.08, "plant": stl})
	m.leg("l", {"t": 0.22, "ankle": Vector3(0.18, 0.2, 0.25), "fq": Mossa.foot_q(0, 0.2)})
	m.leg("l", {"t": 0.38, "plant": pl, "yaw": -0.15}).leg("l", {"t": T_END, "plant": pl, "yaw": -0.15})
	var drive_fq := Mossa.foot_q(0, DRIVE_DOWN)
	var hit_at := b - (drive_fq * (Corpo.FOOT_PTS.instep[1] as Vector3)) * r
	m.leg("r", {"t": 0.0, "plant": str_}).leg("r", {"t": 0.2, "plant": str_})
	m.leg("r", {"t": 0.4, "ankle": Vector3(-0.13, 0.5, -0.32), "fq": Mossa.foot_q(0, 0.9), "pole": Vector3(0, -0.2, 1)})
	m.leg("r", {"t": T_HIT, "part": "instep", "at": hit_at, "fq": drive_fq, "v": Vector3(0.1, 1.2, 6.5)})
	m.leg("r", {"t": T_HIT + 0.16, "ankle": Vector3(-0.02, 0.62, 0.95), "fq": Mossa.foot_q(0, 0.6)})
	m.leg("r", {"t": T_END, "plant": Vector2(-0.12, 0.52)})
	m.touch(T_HIT, "r.instep")
	# bacino: avanti sopra il piede d'appoggio, giro col destro indietro e poi avanti
	m.pelvis(0.0, Palleggi.PELVIS).pelvis(0.38, Vector3(0.06, 0.91, 0.18), 0.3, 0.05, 0.08).pelvis(T_HIT, Vector3(0.06, 0.9, 0.26), -0.1, 0.08, 0.1)
	m.pelvis(T_HIT + 0.2, Vector3(0.03, 0.93, 0.38), -0.3, 0.02, 0.02).pelvis(T_END, Vector3(0, 0.93, 0.3), -0.1)
	m.bend(0.0, Vector3(0.16, 0, 0)).bend(T_HIT, Vector3(0.22, 0.12, -0.1)).bend(T_END, Vector3(0.05, 0, 0))
	m.arm("l", 0.0, ARMS_REST).arm("l", T_HIT, Vector3(0.55, -0.1, 0.15)).arm("l", T_END, ARMS_END)
	m.arm("r", 0.0, ARMS_REST).arm("r", T_HIT, Vector3(0.3, -0.35, -0.2)).arm("r", T_END, ARMS_END)
	# pallone: fermo, poi il volo del tiro fino a ritoccare terra (lontano, ormai invisibile)
	m.ball_rest(0.0, T_HIT, b)
	var fly := 2.0 * SHOT_V.y / Mossa.G
	var p1 := Vector3(b.x + SHOT_V.x * fly, b.y + SHOT_V.y * fly - Mossa.G * fly * fly / 2.0, b.z + SHOT_V.z * fly)
	m.ball_fly(T_HIT, T_HIT + fly, b, p1, SHOT_SPIN)
	return m.done(maxf(T_END, T_HIT + fly))


## pallone nuovo che arriva rotolando da dietro a destra e si ferma davanti ai piedi (decelerazione costante);
## intanto il giocatore torna fermo nella posizione dei palleggi (parte da come finisce il tiro)
static func roll_in_move(r: float = Palleggi.BALL_R) -> Mossa:
	var m := Mossa.new(r)
	var tt := ROLL_T
	var b := Vector3(0, r, Palleggi.BASE.z)
	var fl := Vector2(0.2, 0.5)
	var fr := Vector2(-0.12, 0.52)
	var stl: Vector2 = Palleggi.STANCE.l
	var str_: Vector2 = Palleggi.STANCE.r
	m.leg("l", {"t": 0.0, "plant": fl}).leg("l", {"t": 0.15, "plant": fl}).leg("l", {"t": 0.45, "ankle": Vector3(0.16, 0.18, 0.25), "fq": Mossa.foot_q(0, 0.2)}).leg("l", {"t": 0.7, "plant": stl})
	m.leg("r", {"t": 0.0, "plant": fr}).leg("r", {"t": 0.55, "plant": fr}).leg("r", {"t": 0.8, "ankle": Vector3(-0.13, 0.18, 0.3), "fq": Mossa.foot_q(0, 0.2)}).leg("r", {"t": 1.05, "plant": str_})
	m.leg("l", {"t": tt, "plant": stl}).leg("r", {"t": tt, "plant": str_})
	m.pelvis(0.0, Vector3(0, 0.93, 0.3), -0.1).pelvis(0.7, Vector3(0.03, 0.93, 0.1)).pelvis(1.1, Palleggi.PELVIS).pelvis(tt, Palleggi.PELVIS)
	m.bend(0.0, Vector3(0.05, 0, 0)).bend(tt, Vector3(0.16, 0, 0))
	m.arm("l", 0.0, ARMS_END).arm("r", 0.0, ARMS_END).arm("l", tt, ARMS_REST).arm("r", tt, ARMS_REST)
	m.ball_roll(0.0, tt, ROLL_FROM, b, (b - ROLL_FROM) * (2.0 / tt), Vector3.ZERO)
	return m.done(tt)
