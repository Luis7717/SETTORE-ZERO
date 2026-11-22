# "Dito finto" dell'allenamento guidato (gioco.gd --allenamento --bot): supera ogni lezione SOLO coi gesti veri,
# cioè posizioni sullo schermo passate a gesti.gd come farebbe un dito (giù, trascina, su), più il tasto Dribbling / Scatto e
# "Prova (3 volte)" sulla scheda. Usa gli aiuti di bot_dito.gd (linee disegnate nel tempo di più fotogrammi).
#   Passaggio rasoterra / a effetto: linea dritta / curva dal pallone al compagno
#   Tiro rasoterra / a giro: linea dritta / curva dal pallone dentro la porta
#   Recupera palla: linea dal proprio giocatore al portatore · Dribbling: aspetta il duello (il difensore viene incontro), poi il tasto
#   Scatto: con l'avversario alle spalle si apre la fuga, poi il tasto
#   Portiere: linea dal portiere al punto della porta dove arriva il tiro
extends "res://scripts/partita/bot_dito.gd"

const DRIB_ATTESA := 0.5      # s veri di duello (o di fuga) prima di toccare il tasto (come una persona)
const PANCIA := 0.3           # linee curve: pancia pari a tanta parte della lunghezza sullo schermo
const PORTA_H := 1.0          # altezza a cui finisce la linea del tiro (m)
const PROFONDITA_MIN := 0.05  # m davanti alla telecamera sotto cui un punto non si proietta

var _duello_ms := 0


func _decidi(g, now: int) -> void:
	var t = g.allenamento
	if t == null or t.card or t.finished or t.done > 0.0:
		return
	var m = g.m
	var c: R.Player = m.ctrl[0]
	var b: R.Ball = m.ball
	var titolo: String = t.lesson().title
	if m.hint(0) == "dive":
		var s: R.Shot = b.shot
		var gk: R.Player = m.gk(0)
		_linea(g, now, _sch(g, gk.x, gk.y, 1.0), _sch(g, s.cx, -C.HL, s.ch), "tuffo")
		return
	if not m.duelFor(0) and not m.fleeFor(0):
		_duello_ms = 0
	match titolo:
		"Passaggio rasoterra", "Passaggio a effetto":
			if c != null and b.owner == c:
				var q: R.Player = m.players[9]
				var a := _sch(g, b.x, b.y, 0.3)
				var z := _sch(g, q.x, q.y, 0.0)
				if t.lesson().id == "passaggio_alto":
					_curva(g, now, a, z, PANCIA, "curvo")
				else:
					_linea(g, now, a, z, "passaggio")
		"Tiro rasoterra", "Tiro a giro":
			if c != null and b.owner == c:
				var porta := Vector3(1.5, C.HL, PORTA_H)
				var a := _sch(g, b.x, b.y, 0.3)
				var z := _sch(g, porta.x, porta.y, porta.z)
				if t.lesson().id == "tiro_giro":
					_curva(g, now, a, z, PANCIA, "tiro", porta)
				else:
					_linea(g, now, a, z, "tiro", porta)
		"Recupera palla":
			if c != null and b.owner != null and b.owner.team == 1 and m.runOf(c) == null:
				_linea(g, now, _sch(g, c.x, c.y, 0.9), _sch(g, b.x, b.y, 0.0), "difesa")
		"Dribbling":
			if c == null or b.owner != c:
				return
			if m.duelFor(0):
				_tasto_dopo_attesa(g, now)
		"Scatto": # l'avversario è già alle spalle: la fuga si apre da sola
			if c != null and b.owner == c and m.fleeFor(0):
				_tasto_dopo_attesa(g, now)


# tocca il tasto in basso dopo DRIB_ATTESA s veri di duello o di fuga, una volta sola
func _tasto_dopo_attesa(g, now: int) -> void:
	if _duello_ms == 0:
		_duello_ms = now
	elif now - _duello_ms > DRIB_ATTESA * 1000.0:
		tocca_tasto(g)
		_duello_ms = now + 100000 # una volta per duello


# come bot_dito, ma un punto alla stessa profondità della telecamera (o dietro) non si proietta: si salta il gesto
# (subito dopo che una prova si rimette a posto la telecamera può essere ancora lontana)
func _sch(g, x: float, y: float, h: float) -> Vector3:
	var v = g.vista
	if "cam" in v and v.cam != null:
		var w := Vector3(v.flip * x, h, -v.flip * y)
		var vicino: Vector3 = (v.cam as Camera3D).global_transform.affine_inverse() * w
		if vicino.z > -PROFONDITA_MIN:
			return Vector3(-1.0, -1.0, 0.0)
	return super(g, x, y, h)
