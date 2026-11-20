# Allenamento del campione sullo sfondo del menu (porting di src/menu-routine.js): sequenza che si ripete (palleggi,
# giochetto, corsa palla al piede, tiro, pallone nuovo che arriva rotolando). Funzione pura del tempo, senza grafica:
# la usa scripts/menu/sfondo_menu.gd e la provano i test (tests/test_sfondo_menu.gd). Palleggi, giochetti e tiro sono
# movimenti calcolati (scripts/partita/mosse/*): la posa del corpo (frame) e il pallone con la fisica vera; la corsa
# resta quella del clip, col pallone che rimbalza davanti ai piedi.
# Riferimento: x = sinistra del giocatore, y = su, z = avanti (metri del modello, prima della scala 1,25).
extends RefCounted

const Mossa := preload("res://scripts/partita/mosse/mossa.gd")
const Corpo := preload("res://scripts/partita/mosse/corpo.gd")
const Palleggi := preload("res://scripts/partita/mosse/palleggi.gd")
const Giochetti := preload("res://scripts/partita/mosse/giochetti.gd")
const Tiro := preload("res://scripts/partita/mosse/tiro.gd")

const RUN_T := 2.4            # corsa sul posto palla al piede (clip)
const RUN_V := 6.5            # velocità finta della corsa (solo per l'animazione)
const BLEND_T := 0.25         # s: passaggio dalla posa calcolata alla corsa del clip e ritorno
const FAR := 18.0             # m: oltre, il pallone del tiro sparisce (è un puntino)
const RUN_STEP := 9.0         # rad/s: ritmo del pallone nella corsa
const RUN_EASE := 0.35        # s: il pallone della corsa parte e arriva dolcemente

static var _moves := {}       # costruiti una volta sola (i palleggi costano qualche millisecondo)


## movimenti del menu: {juggle, shot, roll, tricks: [Mossa per ogni giochetto, nell'ordine di Giochetti.TRICKS]}
static func moves() -> Dictionary:
	if _moves.is_empty():
		var tr: Array = []
		for tk: Dictionary in Giochetti.TRICKS:
			tr.append(Giochetti.trick_move(tk.id, Giochetti.MENU_OPT))
		_moves = {"juggle": Palleggi.juggle_move(), "shot": Tiro.shot_move(), "roll": Tiro.roll_in_move(), "tricks": tr}
	return _moves


static func juggle_time() -> float:
	return (moves().juggle as Mossa).T


## durata di un giro col giochetto k
static func cycle_length(k: int) -> float:
	var m := moves()
	return (m.juggle as Mossa).T + (m.tricks[k] as Mossa).T + RUN_T + (m.shot as Mossa).T + (m.roll as Mossa).T


# pallone nella corsa: parte da dove l'ha lasciato il giochetto, va avanti e rimbalza davanti ai piedi, finisce dove
# parte il tiro; ruota come rotola (angolo = strada / raggio)
static func _run_ball(u: float) -> Dictionary:
	var a := minf(1.0, u / RUN_EASE)
	var b := minf(1.0, (RUN_T - u) / RUN_EASE)
	var k := a * a * (3.0 - 2.0 * a)
	var e := b * b * (3.0 - 2.0 * b)
	var z0 := Palleggi.BASE.z + (0.75 - Palleggi.BASE.z) * k
	var z := z0 + (Tiro.SHOT_BALL.z - z0) * (1.0 - e) + 0.15 * sin(u * RUN_STEP) * k * e
	var h := Palleggi.BALL_R + 0.05 * absf(sin(u * RUN_STEP)) * k * e
	return {"p": Vector3(0, h, z), "q": Corpo.q_axis(Vector3(1, 0, 0), (z - Palleggi.BASE.z) / Palleggi.BALL_R), "vis": true}


static func _out(seg: String, mv: Mossa, tt: float, k: int, trick: Variant = null) -> Dictionary:
	var fr := mv.at(tt)
	var ball: Dictionary = fr.ball
	ball["vis"] = true
	return {"seg": seg, "vx": 0.0, "frame": fr, "w": 1.0, "ball": ball, "cycle": k, "trick": trick}


## t = secondi dall'inizio; ogni giro usa il giochetto successivo. Ritorna {seg ("juggle", "trick", "run", "shot",
## "rest"), vx, frame (posa calcolata o null), w (quanto pesa la posa calcolata sul clip), ball {p, q, vis}, cycle, trick}
static func at(t: float) -> Dictionary:
	var m := moves()
	var n: int = Giochetti.TRICKS.size()
	var k := 0
	var u := maxf(0.0, t)
	while u >= cycle_length(k):
		u -= cycle_length(k)
		k = (k + 1) % n
	var jg: Mossa = m.juggle
	if u < jg.T:
		return _out("juggle", jg, u, k)
	u -= jg.T
	var tr: Mossa = m.tricks[k]
	if u < tr.T:
		return _out("trick", tr, u, k, {"id": Giochetti.TRICKS[k].id, "q": u / tr.T, "side": 1})
	u -= tr.T
	var shot: Mossa = m.shot
	if u < RUN_T:
		# corsa del clip; all'inizio e alla fine la posa calcolata (fine del giochetto, inizio del tiro) sfuma
		var w_in := maxf(0.0, 1.0 - u / BLEND_T)
		var w_out := maxf(0.0, 1.0 - (RUN_T - u) / BLEND_T)
		var frame: Variant = tr.at(tr.T) if w_in > 0.0 else (shot.at(0.0) if w_out > 0.0 else null)
		return {"seg": "run", "vx": RUN_V, "frame": frame, "w": maxf(w_in, w_out), "ball": _run_ball(u), "cycle": k, "trick": null}
	u -= RUN_T
	if u < shot.T:
		var o := _out("shot", shot, u, k)
		o.ball.vis = (o.ball.p as Vector3).z < FAR
		return o
	u -= shot.T
	return _out("rest", m.roll, u, k)
