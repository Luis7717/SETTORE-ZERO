# "Dito finto" per le prove senza persona (gioco.gd --bot): gioca la squadra 0 SOLO coi gesti veri, cioè posizioni
# sullo schermo passate a scripts/partita/gesti.gd come farebbe un dito (giù, trascina, su). Disegna passaggi e tiri
# (dritti = rasoterra, curvi = alti a effetto), linee di difesa e tuffi del portiere, tiene premuto per muovere il controllato, preme Dribbling nel duello e Scatto
# nella fuga (avversario alla pari o dietro) e gira la visuale nel rallenty. Non è un giocatore bravo: serve a far passare una partita intera da tutti i gesti.
extends RefCounted

const SimRng := preload("res://sim/rng.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")

const PUNTI_LINEA := 12        # fotogrammi (punti) per disegnare una linea
const TIENI_FOTOGRAMMI := 24   # fotogrammi di dito tenuto premuto
const ATTESA_MIN := 6          # fotogrammi tra un gesto e l'altro (più un po' a caso)
const ATTESA_CASO := 10

var r: SimRng
var conti := {"passaggio": 0, "curvo": 0, "tiro": 0, "difesa": 0, "tuffo": 0, "dribbling": 0, "scatto": 0, "visuale": 0, "tieni": 0, "saltati": 0}
var _gesto: Array[Vector2] = []
var _fine_mondo: Variant = null  # Vector3(x, y, h) del campo dove deve finire la linea (si riproietta al rilascio)
var _attesa := 0


func _init(seme: int) -> void:
	r = SimRng.new(seme)


func riassunto() -> String:
	var parti := PackedStringArray()
	for k: String in conti:
		parti.append("%s %d" % [k, conti[k]])
	return "bot: " + ", ".join(parti)


## un fotogramma: continua il gesto in corso o ne sceglie uno nuovo
func passo(g, now: int) -> void:
	var gs = g.gesti
	if not _gesto.is_empty():
		var p: Vector2 = _gesto.pop_front()
		if _gesto.is_empty():
			# la telecamera si muove mentre si disegna: il dito vero segue quello che vede, quindi l'ultimo punto si
			# riproietta sul punto del campo voluto (un tiro che finiva poco prima della porta, nel rallenty, dove ogni
			# linea è un passaggio, diventava un passaggio nel vuoto)
			if _fine_mondo != null:
				var w: Vector3 = _fine_mondo
				var s := _sch(g, w.x, w.y, w.z)
				if _dentro(g, s):
					p = Vector2(s.x, s.y)
				_fine_mondo = null
			gs.move_ev(p, 0) # gesti.up non usa il punto del rilascio: la linea finisce dove il dito si è mosso l'ultima volta
			gs.up(p, now, 0)
		else:
			gs.move_ev(p, 0)
		return
	if gs.dito >= 0:
		return
	if _attesa > 0:
		_attesa -= 1
		return
	_attesa = ATTESA_MIN + int(r.next() * ATTESA_CASO)
	_decidi(g, now)


func _decidi(g, now: int) -> void:
	var m = g.m
	var me: int = g.me
	var c: R.Player = m.ctrl[me]
	var b: R.Ball = m.ball
	var dir := 1.0 if me == 0 else -1.0
	match m.hint(me):
		"dive":
			var s: R.Shot = b.shot
			var gk: R.Player = m.gk(me)
			_linea(g, now, _sch(g, gk.x, gk.y, 1.0), _sch(g, s.cx, -dir * C.HL, s.ch), "tuffo")
		"restart":
			if c != null and b.owner == c and m.restart.t > 0.6:
				_passa(g, now, c)
		"attack":
			if c != null and b.owner == c:
				_attacca(g, now, c, dir)
		"defend", "loose":
			if r.next() < 0.5:
				var p := _piu_vicino(m, me, b.x, b.y)
				if p != null:
					_linea(g, now, _sch(g, p.x, p.y, 0.9), _sch(g, b.x, b.y, 0.0), "difesa")
			else:
				_tieni(g, now, _sch(g, b.x + (r.next() - 0.5) * 6.0, b.y - dir * 3.0, 0.0))


# tocca il tasto in basso (gioco.gd → m.userDribble nel duello, m.userSprint nella fuga) e lo conta
func tocca_tasto(g) -> void:
	var fuga: bool = g.m.fleeFor(g.me)
	g._dribbling()
	if fuga:
		conti.scatto += 1
	else:
		conti.dribbling += 1


func _attacca(g, now: int, c: R.Player, dir: float) -> void:
	var m = g.m
	var me: int = g.me
	var tiro := r.next()
	if m.dribBooked(me):
		return # Dribbling già toccato: il portatore va da solo verso il difensore, il dribbling scatta vicino
	if m.duelFor(me):
		if tiro < 0.35:
			tocca_tasto(g)
		elif tiro < 0.5:
			var w: float = g.gesti.dim.x
			var y0: float = g.gesti.dim.y * 0.3
			_linea(g, now, Vector3(w * 0.15, y0, 1.0), Vector3(w * 0.55, y0 + 10.0, 1.0), "visuale")
		else:
			_passa(g, now, c)
	elif m.fleeFor(me) and tiro < 0.75: # fuga: Scatto o passaggio disegnato
		if tiro < 0.5:
			tocca_tasto(g)
		else:
			_passa(g, now, c)
	elif m.inZone(me):
		if tiro < 0.65:
			var porta := Vector3((r.next() - 0.5) * 5.0, dir * C.HL, 0.4 + r.next() * 1.6)
			_linea(g, now, _sch(g, m.ball.x, m.ball.y, 0.3), _sch(g, porta.x, porta.y, porta.z), "tiro", porta)
		else:
			_passa(g, now, c)
	elif tiro < 0.25: # il portatore corre da solo (IA): ogni tanto un passaggio
		_passa(g, now, c)


# passaggio disegnato dal pallone al compagno più avanti tra i tre più vicini
func _passa(g, now: int, c: R.Player) -> void:
	var m = g.m
	var dir := 1.0 if c.team == 0 else -1.0
	var best: R.Player = null
	var punti := -INF
	for p: R.Player in m.team(c.team):
		if p == c or p.off or p.pos == "P":
			continue
		var d := C.hyp(p.x - c.x, p.y - c.y)
		var v := (p.y - c.y) * dir * 0.5 - d * 0.4 + r.next() * 4.0
		if d < 35.0 and v > punti:
			punti = v
			best = p
	if best != null:
		var a := _sch(g, m.ball.x, m.ball.y, 0.3)
		var b := _sch(g, best.x, best.y, 0.0)
		if r.next() < 0.3:
			_curva(g, now, a, b, 0.3 * (1.0 if r.next() < 0.5 else -1.0), "curvo")
		else:
			_linea(g, now, a, b, "passaggio")


func _piu_vicino(m, me: int, x: float, y: float) -> R.Player:
	var best: R.Player = null
	var bd := INF
	for p: R.Player in m.team(me):
		if p.off or p.pos == "P":
			continue
		var d := C.hyp(p.x - x, p.y - y)
		if d < bd:
			bd = d
			best = p
	return best


func _sch(g, x: float, y: float, h: float) -> Vector3:
	return g.vista.world_to_screen(x, y, h)


func _dentro(g, s: Vector3) -> bool:
	var dim: Vector2 = g.gesti.dim
	return s.z > 0.5 and s.x >= 0.0 and s.y >= 0.0 and s.x <= dim.x and s.y <= dim.y


func _linea(g, now: int, a: Vector3, b: Vector3, tipo: String, fine_mondo: Variant = null) -> void:
	if not _dentro(g, a) or not _dentro(g, b):
		conti.saltati += 1
		return
	_fine_mondo = fine_mondo
	var pa := Vector2(a.x, a.y)
	var pb := Vector2(b.x, b.y)
	g.gesti.down(pa, now, 0)
	_gesto.clear()
	for i in range(1, PUNTI_LINEA + 1):
		_gesto.append(pa.lerp(pb, float(i) / PUNTI_LINEA))
	conti[tipo] += 1


## linea curva da a a b sullo schermo: pancia = frazione della lunghezza (col segno del lato), arco di parabola
func _curva(g, now: int, a: Vector3, b: Vector3, pancia: float, tipo: String, fine_mondo: Variant = null) -> void:
	if not _dentro(g, a) or not _dentro(g, b):
		conti.saltati += 1
		return
	_fine_mondo = fine_mondo
	var pa := Vector2(a.x, a.y)
	var pb := Vector2(b.x, b.y)
	var n := (pb - pa).orthogonal() * pancia
	g.gesti.down(pa, now, 0)
	_gesto.clear()
	for i in range(1, PUNTI_LINEA + 1):
		var u := float(i) / PUNTI_LINEA
		_gesto.append(pa.lerp(pb, u) + n * 4.0 * u * (1.0 - u))
	conti[tipo] += 1


func _tieni(g, now: int, a: Vector3) -> void:
	if not _dentro(g, a):
		conti.saltati += 1
		return
	var pa := Vector2(a.x, a.y)
	g.gesti.down(pa, now, 0)
	_gesto.clear()
	_fine_mondo = null
	for i in range(1, TIENI_FOTOGRAMMI + 1):
		_gesto.append(pa + Vector2(i * 1.0, 0.0))
	conti.tieni += 1
