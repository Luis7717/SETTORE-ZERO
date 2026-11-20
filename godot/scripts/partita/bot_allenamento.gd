# "Dito finto" dell'allenamento guidato (gioco.gd --allenamento --bot): supera ogni lezione SOLO coi gesti veri,
# cioè posizioni sullo schermo passate a gesti.gd come farebbe un dito (giù, trascina, su), più il tasto Dribbling e
# "Prova (3 volte)" sulla scheda. Usa gli aiuti di bot_dito.gd (linee disegnate nel tempo di più fotogrammi).
#   Passaggio: strada verso il difensore, poi nel duello linea dal pallone al compagno
#   Tiro: linea dal pallone dentro la porta · Corsa e scatto: strada in avanti, verso la fascia, lunga
#   Recupera palla: linea dal proprio giocatore al portatore · Dribbling: strada verso il difensore, poi il tasto
#   Portiere: linea dal portiere al punto della porta dove arriva il tiro
extends "res://scripts/partita/bot_dito.gd"

const DRIB_ATTESA := 0.5      # s veri di duello prima di toccare Dribbling (come una persona)
const CORSA_K := [Vector2(0, 16), Vector2(14, 6), Vector2(0, 22)]   # strade della lezione Corsa (dx, dy) per prova
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
	if not m.duelFor(0):
		_duello_ms = 0
	match titolo:
		"Passaggio":
			if c == null or b.owner != c:
				return
			if m.duelFor(0):
				var q: R.Player = m.players[9]
				_linea(g, now, _sch(g, b.x, b.y, 0.3), _sch(g, q.x, q.y, 0.0), "passaggio")
			else:
				_verso(g, now, c, t.st.o)
		"Tiro":
			if c != null and b.owner == c:
				_linea(g, now, _sch(g, b.x, b.y, 0.3), _sch(g, 1.5, C.HL, PORTA_H), "tiro")
		"Corsa e scatto":
			if c != null and b.owner == c and m.move[0] == null:
				var d: Vector2 = CORSA_K[t.k]
				_linea(g, now, _sch(g, b.x, b.y, 0.3), _sch(g, c.x + d.x, c.y + d.y, 0.0), "strada")
		"Recupera palla":
			if c != null and b.owner != null and b.owner.team == 1 and m.runOf(c) == null:
				_linea(g, now, _sch(g, c.x, c.y, 0.9), _sch(g, b.x, b.y, 0.0), "difesa")
		"Dribbling":
			if c == null or b.owner != c:
				return
			if m.duelFor(0):
				if _duello_ms == 0:
					_duello_ms = now
				elif now - _duello_ms > DRIB_ATTESA * 1000.0:
					g._dribbling()
					conti.dribbling += 1
					_duello_ms = now + 100000 # una volta per duello
			else:
				_verso(g, now, c, t.st.o)


# strada dal portatore verso un avversario (fino a 2 m prima)
func _verso(g, now: int, c: R.Player, o: R.Player) -> void:
	var dx := o.x - c.x
	var dy := o.y - c.y
	var d := maxf(0.1, sqrt(dx * dx + dy * dy))
	var k := maxf(0.0, d - 2.0) / d
	_linea(g, now, _sch(g, g.m.ball.x, g.m.ball.y, 0.3), _sch(g, c.x + dx * k, c.y + dy * k, 0.0), "strada")


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
