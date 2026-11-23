# Raccattapalle (Luis 2026-11-23: "un raccattapalle vero e visibile"). Uno dietro ogni porta, davanti ai cartelloni:
# quando il pallone del rinvio o dell'angolo si ferma lontano dal posto della ripresa (o dietro la rete) la scena
# (riprese.gd) lo chiama: lui corre al pallone restando sempre fuori dal campo e girando intorno alla rete, si china,
# lo raccoglie, si gira verso il battitore e glielo lancia con le due mani sopra la testa (il pallonetto parte dalle sue
# mani); poi torna camminando al suo posto. Non è un giocatore della partita: niente contrasti, niente numeri casuali,
# il pallone lo tiene solo durante la scena. Solo con l'opzione "riprese" (senza, `raccatte` resta vuoto).
extends "testa.gd"

const BB_HOME_Y := HL + 4.0    # posto: dietro la porta (rete profonda 2 m), davanti ai cartelloni (a HL + 5,5)
const BB_MIN_OUT := 0.6        # mai più vicino di così alla linea di porta (m): resta sempre fuori dal campo
const BB_MAX_X := HW + 3.2     # ... e mai più in là di così di lato (il pallone si ferma entro HW + 2,6)
const BB_RUN := 7.0            # corsa verso il pallone (m/s): un ragazzino veloce, un po' più lento dei giocatori
const BB_WALK := 1.3            # ritorno al posto camminando (m/s)
const BB_ACC := 10.0           # accelerazione e frenata (m/s²)
const BB_BRAKE_K := 5.0        # vicino alla meta rallenta: al massimo tanti m/s per metro che manca
const BB_ARRIVE := 0.15        # arrivato alla meta (m)
const BB_GAP := 0.5            # si ferma a tanto dal pallone, dalla parte di fuori, per raccoglierlo (m)
const BB_REACH := 0.9          # raccoglie il pallone entro tanto (m) ...
const BB_PICK_V := 1.5         # ... se va più piano di così (m/s)
const BB_PICK_S := 0.4         # tempo per chinarsi e raccoglierlo (s)
const BB_REST_S := 0.55        # dopo il lancio resta fermo (fine del movimento) prima di tornare (s)
const BB_KICK_T := 0.35        # durata del gesto del lancio (come kickAnim dei giocatori)
const BB_CHEST_H := 1.0        # pallone in mano davanti al petto (m) ...
const BB_HAND_D := 0.35        # ... a tanto davanti a lui (m)
const BB_THROW_H := 1.9        # ... e sopra la testa prima del lancio (m)
const BB_TURN_K := 9.0         # rapidità con cui si gira (1/s)
const NET_D := 2.0             # profondità della rete dietro la linea di porta (m), come la vista
const NET_X := GW / 2.0 + 0.15 # il raccattapalle non entra in questo rettangolo (rete + il suo corpo) ...
const NET_Y := NET_D + 0.15    # ... profondo tanto dalla linea di porta
const NET_PATH := 0.25         # ... e ci gira intorno con questo margine in più (m)

var raccatte: Array = []       # R.Raccatta: [0] dietro la porta in basso (y < 0), [1] in alto


## i due raccattapalle al loro posto (dalla partita, solo con l'opzione "riprese")
func raccattaPrepara() -> void:
	raccatte.clear()
	for k in 2:
		var bb := R.Raccatta.new()
		var s: float = -1.0 if k == 0 else 1.0
		bb.i = k
		bb.hx = 0.0
		bb.hy = s * BB_HOME_Y
		bb.x = bb.hx
		bb.y = bb.hy
		bb.fx = 0.0
		bb.fy = -s
		raccatte.append(bb)


## raccattapalle del fondo dalla parte di y
func raccattaDi(y: float) -> R.Raccatta:
	return raccatte[0 if y < 0.0 else 1]


## manda il raccattapalle a prendere il pallone
func raccattaChiama(bb: R.Raccatta) -> void:
	_bbStato(bb, "va")


## un raccattapalle ha il pallone in mano
func raccattaHaPalla() -> bool:
	for bb: R.Raccatta in raccatte:
		if bb.palla:
			return true
	return false


## un passo di tutti e due (da step, sempre: finita la scena tornano al posto)
func raccattaStep(dt: float) -> void:
	for bb: R.Raccatta in raccatte:
		bb.st += dt
		bb.t += dt
		bb.kickAnim = maxf(0.0, bb.kickAnim - dt)
		if bb.palla and not _bbScena():
			bb.palla = false # scena finita senza lancio (sicurezza): il pallone l'ha già sistemato la scena
			_bbStato(bb, "torna")
		match bb.stato:
			"va":
				_bbVa(bb, dt)
			"raccogli":
				_bbFerma(bb)
				_bbGira(bb, ball.x - bb.x, ball.y - bb.y, dt)
				if bb.st >= BB_PICK_S:
					bb.palla = true
					_bbStato(bb, "mira")
			"mira", "lancia":
				_bbFerma(bb)
			"dopo":
				_bbFerma(bb)
				if bb.st >= BB_REST_S:
					_bbStato(bb, "torna")
			"torna":
				if _bbMuovi(bb, bb.hx, bb.hy, BB_WALK, dt):
					_bbStato(bb, "fermo")
			_:
				_bbFerma(bb)
				_bbGira(bb, 0.0, -C.sign_(bb.hy), dt)
		_bbFuori(bb)
		if bb.palla:
			_bbTieni(bb)


## scena della ripresa in cui il pallone è del raccattapalle e non è ancora stato lanciato
func _bbScena() -> bool:
	return phase == "restart" and restart != null and restart.scena != "" and restart.raccatta and not restart.rimando


func _bbVa(bb: R.Raccatta, dt: float) -> void:
	if not _bbScena():
		_bbStato(bb, "torna")
		return
	var m := raccattaMeta(bb)
	var arrivato := _bbMuovi(bb, m.x, m.y, BB_RUN, dt)
	var b := ball
	if (arrivato or C.hyp(b.x - bb.x, b.y - bb.y) < BB_GAP) and b.h < 0.3 and C.hyp(b.vx, b.vy) < BB_PICK_V \
			and C.hyp(b.x - bb.x, b.y - bb.y) < BB_REACH:
		b.vx = 0.0
		b.vy = 0.0
		b.vh = 0.0
		_bbStato(bb, "raccogli")


## dove si mette per raccogliere il pallone: dalla parte di fuori, a BB_GAP; accanto alla rete, di lato
func raccattaMeta(bb: R.Raccatta) -> Vector2:
	var b := ball
	var s: float = C.sign_(bb.hy)
	var tx: float = b.x
	var ty: float = b.y + s * BB_GAP
	if absf(b.x) < NET_X + BB_GAP and absf(b.y) < HL + NET_Y:
		tx = b.x + (1.0 if b.x >= 0.0 else -1.0) * BB_GAP # pallone accanto alla rete: lo prende di lato
		ty = b.y
	tx = C.clamp_(tx, -BB_MAX_X, BB_MAX_X)
	if absf(ty) < HL + BB_MIN_OUT or ty * s < 0.0:
		ty = s * (HL + BB_MIN_OUT)
	return Vector2(tx, ty)


## passo verso (tx, ty) con velocità massima vmx, girando intorno alla rete; true se è arrivato
func _bbMuovi(bb: R.Raccatta, tx: float, ty: float, vmx: float, dt: float) -> bool:
	var via := _bbVia(bb, tx, ty)
	var dx: float = via.x - bb.x
	var dy: float = via.y - bb.y
	var d: float = C.hyp(dx, dy)
	var finale: bool = via.x == tx and via.y == ty
	if finale and d < BB_ARRIVE:
		_bbFerma(bb)
		return true
	var vw: float = minf(vmx, d * BB_BRAKE_K) if finale else vmx
	bb.spd = move_toward(bb.spd, vw, BB_ACC * dt)
	var step: float = minf(bb.spd * dt, d)
	bb.vx = dx / d * bb.spd
	bb.vy = dy / d * bb.spd
	bb.x += dx / d * step
	bb.y += dy / d * step
	bb.sprint = vmx >= BB_RUN and bb.spd > BB_WALK * 2.0
	_bbGira(bb, dx, dy, dt)
	return false


## punto intermedio per non attraversare la rete: l'angolo dietro la rete dalla parte giusta (o la meta stessa)
func _bbVia(bb: R.Raccatta, tx: float, ty: float) -> Vector2:
	var s: float = C.sign_(bb.hy)
	var bx: float = NET_X + NET_PATH
	var y0: float = s * HL
	var y1: float = s * (HL + NET_Y + NET_PATH)
	if not segBox(bb.x, bb.y, tx, ty, -bx, bx, minf(y0, y1), maxf(y0, y1)):
		return Vector2(tx, ty)
	var dietro: bool = absf(bb.y) >= HL + NET_Y + NET_PATH - 0.01
	var lato: float = C.sign_(tx if dietro else bb.x)
	if lato == 0.0:
		lato = 1.0
	return Vector2(lato * (bx + 0.1), s * (HL + NET_Y + NET_PATH + 0.1))


## il segmento (x0, y0)-(x1, y1) tocca il rettangolo [minx, maxx] × [miny, maxy] (Liang-Barsky)
static func segBox(x0: float, y0: float, x1: float, y1: float, minx: float, maxx: float, miny: float, maxy: float) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var dx := x1 - x0
	var dy := y1 - y0
	var ps := [-dx, dx, -dy, dy]
	var qs := [x0 - minx, maxx - x0, y0 - miny, maxy - y0]
	for k in 4:
		var pp: float = ps[k]
		var q: float = qs[k]
		if absf(pp) < 1e-9:
			if q < 0.0:
				return false
			continue
		var r: float = q / pp
		if pp < 0.0:
			if r > t1:
				return false
			t0 = maxf(t0, r)
		else:
			if r < t0:
				return false
			t1 = minf(t1, r)
	return t0 <= t1


## sicurezza: sempre fuori dal campo, dietro la sua linea di porta, e mai dentro la rete
func _bbFuori(bb: R.Raccatta) -> void:
	var s: float = C.sign_(bb.hy)
	bb.x = C.clamp_(bb.x, -BB_MAX_X, BB_MAX_X)
	if bb.y * s < HL + BB_MIN_OUT:
		bb.y = s * (HL + BB_MIN_OUT)


## pallone tra le mani: davanti al petto, sopra la testa mentre prende la mira per il lancio
func _bbTieni(bb: R.Raccatta) -> void:
	var b := ball
	b.owner = null
	b.x = bb.x + bb.fx * BB_HAND_D
	b.y = bb.y + bb.fy * BB_HAND_D
	b.h = BB_THROW_H if bb.stato == "lancia" else BB_CHEST_H
	b.vx = 0.0
	b.vy = 0.0
	b.vh = 0.0


## si gira verso (dx, dy) con rapidità BB_TURN_K
func _bbGira(bb: R.Raccatta, dx: float, dy: float, dt: float) -> void:
	var n: float = C.hyp(dx, dy)
	if n < 1e-3:
		return
	var k: float = minf(1.0, dt * BB_TURN_K)
	var fx: float = bb.fx + (dx / n - bb.fx) * k
	var fy: float = bb.fy + (dy / n - bb.fy) * k
	var m: float = C.hyp(fx, fy)
	if m < 1e-3: # mezzo giro esatto: si gira da un lato
		fx = -bb.fy
		fy = bb.fx
		m = 1.0
	bb.fx = fx / m
	bb.fy = fy / m


func _bbFerma(bb: R.Raccatta) -> void:
	bb.spd = 0.0
	bb.vx = 0.0
	bb.vy = 0.0
	bb.sprint = false


func _bbStato(bb: R.Raccatta, s: String) -> void:
	bb.stato = s
	bb.st = 0.0
