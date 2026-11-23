# Riprese senza teletrasporto (Luis 2026-11-23: "quando la palla esce non fare il teletrasporto, fai un giocatore che
# va a prendere la palla"). Rimessa laterale, rinvio dal fondo e calcio d'angolo: il pallone esce e si ferma poco fuori
# (cartelloni), il battitore va a prenderlo di corsa, si china, lo raccoglie e lo porta al posto della ripresa. Se il
# pallone è lontano dal posto glielo rimanda un raccattapalle con un pallonetto, che il battitore prende al volo (o
# raccoglie se arriva tardi). Nel rinvio e nell'angolo il battitore appoggia il pallone e fa qualche passo indietro per
# la rincorsa; al calcio corre sul pallone e calcia. Gli altri vanno di corsa leggera ai posti che setRestart darebbe loro.
# Finché la scena dura (restart.scena != "") non si batte; finita, la ripresa è quella di sempre (r.t, wait, aiRestart).
# Solo con l'opzione "riprese" della partita (la mette il gioco): senza, il motore resta identico (confronti col JS).
extends "testa.gd"

const SCENE_TYPES := ["throw", "goalkick", "corner"]
const SCENE_DAMP := 2.5        # 1/s: frenata in più del pallone libero durante la scena (erba fuori dal campo)
const SCENE_OUT_X := HW + 2.6  # il pallone fuori si ferma entro qui (più in là ci sono i cartelloni, a 5 m) ...
const SCENE_OUT_Y := HL + 2.2  # ... e dietro le porte: il battitore ci arriva (lui resta entro HW + 3, HL + 2,5)
const FETCH_NEAR := 9.0        # pallone entro tanti metri dal posto della ripresa: il battitore va a prenderlo (m)
const FETCH_GAP := 0.55        # si ferma a tanto dal pallone per raccoglierlo (m)
const PICK_R := 0.3            # ... con questa tolleranza (m)
const PICK_V := 2.5            # pallone abbastanza lento da raccogliere (m/s)
const PICK_S := 0.45           # tempo per chinarsi e raccoglierlo (s)
const TURN_S := 0.25           # arrivato al posto si gira verso il campo (s) ...
const TURN_K := 12.0           # ... con questa rapidità (1/s)
const PLACE_S := 0.4           # rinvio e angolo: tempo per chinarsi e appoggiare il pallone (s)
const SPOT_R := 0.35           # arrivato al posto (m)
const RUN_SPD := 1.0           # corsa verso il pallone (frazione della velocità massima) ...
const SPRINT_FAR := 12.0       # ... scattando se è più lontano di così (m)
const CARRY_SPD := 0.5         # col pallone in mano verso il posto
const BACK_SPD := 0.3          # passi indietro della rincorsa (camminando)
const OTHERS_SPD := 0.8        # gli altri verso il loro posto
const RUNUP_SPD := 0.7         # rincorsa verso il pallone al momento del calcio
const RUNUP_M := 2.0           # rinvio e angolo: passi indietro per la rincorsa (m) ...
const RUNUP_ANG := 0.5         # ... un po' di lato (rad), verso l'esterno: il pallone resta a vista della telecamera
const RUNUP_HIT := 0.6         # il calcio parte col battitore a tanto dal pallone (m)
const RUNUP_MAX_S := 2.0       # sicurezza: la rincorsa più lunga di così calcia lo stesso (s)
const THROW_SLIDE := 3.0       # rimessa: si batte dove il battitore raccoglie, al massimo tanto dal punto d'uscita (m)
const LOB_V := 13.0            # pallonetto del raccattapalle: velocità media (m/s) ...
const LOB_T_MIN := 0.8         # ... volo di almeno tanti secondi ...
const LOB_T_MAX := 1.6         # ... e al massimo tanti
const LOB_H := 1.1             # ... arriva al battitore a quest'altezza (m)
const CATCH_R := 1.0           # il battitore prende al volo il pallonetto entro tanto (m) ...
const CATCH_H := 2.4           # ... sotto quest'altezza
const BALL_REST_V := 0.6       # pallone fermo sotto questa velocità (m/s)
const SCENE_MAX := 9.0         # sicurezza: scena più lunga di così = tutti al loro posto subito (s)
const SCENE_WAIT := 0.5        # finita la scena la CPU batte dopo così (s): l'attesa l'ha già fatta la scena
const CORNER_PAS_M := 0.3      # angolo: un punto di passaggio in più vale tanti metri di distanza dalla bandierina

var riprese: bool = false      # opzione "riprese" della partita
var sceneNoCut: bool = false   # setRestart chiamato per una scena: niente taglio di scena (evento "restart" senza cut)


## la ripresa `type` (uscita del pallone) diventa una scena
func sceneWanted(type: String) -> bool:
	return riprese and SCENE_TYPES.has(type)


## posizioni e velocità di giocatori e pallone prima di setRestart
func sceneSnap() -> Array:
	var ps: Array = []
	for p: R.Player in players:
		ps.append(PackedFloat64Array([p.x, p.y, p.vx, p.vy, p.fx, p.fy]))
	var b := ball
	return [ps, PackedFloat64Array([b.x, b.y, b.h, b.vx, b.vy, b.vh])]


## dopo setRestart: tutti tornano dov'erano (con la loro velocità) e i posti di setRestart diventano le mete
func sceneStart(snap: Array) -> void:
	var r := restart
	var tk := r.taker
	r.scena = "va"
	r.st = 0.0
	r.sT = 0.0
	r.sx = tk.x
	r.sy = tk.y
	r.sfx = tk.fx
	r.sfy = tk.fy
	r.kx = r.x
	r.ky = r.y
	r.wait = minf(r.wait, SCENE_WAIT)
	var ps: Array = snap[0]
	for k in players.size():
		var p: R.Player = players[k]
		if p.off:
			continue
		var s: PackedFloat64Array = ps[k]
		p.rgo = p != tk and C.hyp(p.x - s[0], p.y - s[1]) > 0.05
		p.rtx = p.x
		p.rty = p.y
		p.x = s[0]
		p.y = s[1]
		p.vx = s[2]
		p.vy = s[3]
		p.fx = s[4]
		p.fy = s[5]
		p.tx = p.x
		p.ty = p.y
	var b := ball
	var bs: PackedFloat64Array = snap[1]
	b.owner = null
	b.x = bs[0]
	b.y = bs[1]
	b.h = bs[2]
	b.vx = bs[3]
	b.vy = bs[4]
	b.vh = bs[5]


## mete durante la scena (da assign): true se il giocatore è sistemato qui
func sceneAssign(p: R.Player) -> bool:
	var r := restart
	if p == r.taker:
		_sceneTaker(p, r)
		return true
	if r.scena != "" and p.rgo:
		p.tx = p.rtx
		p.ty = p.rty
		p.spdF = OTHERS_SPD
		return true
	return false


func _sceneTaker(p: R.Player, r: R.Restart) -> void:
	var b := ball
	p.tx = p.x
	p.ty = p.y
	match r.scena:
		"va":
			p.spdF = RUN_SPD
			if r.rimando and b.h > 0.0:
				p.tx = r.sx # pallonetto in volo: lo aspetta al posto
				p.ty = r.sy
			elif _sceneFetch(r):
				var d: float = C.hyp(b.x - p.x, b.y - p.y)
				if d > FETCH_GAP:
					p.tx = b.x - (b.x - p.x) / d * FETCH_GAP
					p.ty = b.y - (b.y - p.y) / d * FETCH_GAP
			else:
				p.tx = r.sx
				p.ty = r.sy
			p.sprint = C.hyp(p.tx - p.x, p.ty - p.y) > SPRINT_FAR # da lontano scatta
		"porta":
			p.spdF = CARRY_SPD
			p.tx = r.sx
			p.ty = r.sy
		"indietro":
			var bk := runupBack(r)
			p.spdF = BACK_SPD
			p.tx = bk.x
			p.ty = bk.y
		"":
			if r.pend != null:
				var h := runupHit(r)
				p.spdF = RUNUP_SPD
				p.tx = h.x
				p.ty = h.y


## dove il battitore aspetta per la rincorsa: RUNUP_M dietro il posto, girato di RUNUP_ANG verso la linea laterale vicina
func runupBack(r: R.Restart) -> Vector2:
	var a: float = RUNUP_ANG * (1.0 if r.kx >= 0.0 else -1.0) * (1.0 if r.sfy >= 0.0 else -1.0)
	var bx: float = -r.sfx
	var by: float = -r.sfy
	return Vector2(r.sx + (bx * cos(a) - by * sin(a)) * RUNUP_M, r.sy + (bx * sin(a) + by * cos(a)) * RUNUP_M)


## il battitore va lui a prendere il pallone (vicino al posto della ripresa)
func _sceneFetch(r: R.Restart) -> bool:
	return C.hyp(ball.x - r.sx, ball.y - r.sy) < FETCH_NEAR


## punto da cui parte il calcio dopo la rincorsa: dietro il pallone, sulla linea del calcio chiesto
func runupHit(r: R.Restart) -> Vector2:
	var spec: Dictionary = r.pend
	var ux: float = float(spec.tx) - r.kx
	var uy: float = float(spec.ty) - r.ky
	var n: float = C.hyp(ux, uy)
	if n < 0.5:
		ux = r.sfx
		uy = r.sfy
		n = 1.0
	return Vector2(r.kx - ux / n * RUNUP_HIT, r.ky - uy / n * RUNUP_HIT)


## rincorsa finita: il battitore è sul punto del calcio (o è passato troppo tempo)
func runupDone() -> bool:
	var r := restart
	var h := runupHit(r)
	return C.hyp(r.taker.x - h.x, r.taker.y - h.y) < SPOT_R + 0.1 or r.st > RUNUP_MAX_S


## pallone libero durante la scena (da updateBall): frena e si ferma prima dei cartelloni
func sceneBall(dt: float) -> void:
	var b := ball
	var r := restart
	if b.owner != null:
		return
	if not (r.rimando and b.h > 0.0): # il pallonetto del raccattapalle vola libero
		var k: float = maxf(0.0, 1.0 - SCENE_DAMP * dt)
		b.vx *= k
		b.vy *= k
	if absf(b.x) > SCENE_OUT_X:
		b.x = C.sign_(b.x) * SCENE_OUT_X
		b.vx = 0.0
	if absf(b.y) > SCENE_OUT_Y:
		b.y = C.sign_(b.y) * SCENE_OUT_Y
		b.vy = 0.0


## un passo della scena (da step, dopo il movimento): raccolta, presa al volo, arrivo, appoggio, passi indietro
func sceneStep(dt: float) -> void:
	var r := restart
	var b := ball
	var p := r.taker
	r.st += dt
	r.sT += dt
	if r.sT > SCENE_MAX:
		sceneSkip()
		return
	match r.scena:
		"va":
			_sceneGo(r, b, p)
		"raccogli":
			faceTo(p, b.x, b.y)
			if r.st >= PICK_S:
				r.posato = false
				_sceneStage(r, "porta")
		"porta":
			if C.hyp(p.x - r.sx, p.y - r.sy) < SPOT_R:
				_sceneStage(r, "posa")
		"posa":
			_sceneTurn(p, r, dt)
			if r.type == "throw":
				if r.st >= TURN_S:
					_sceneEnd(r)
			elif r.st >= TURN_S and not r.posato:
				r.posato = true
				p.fx = r.sfx
				p.fy = r.sfy
				b.x = r.kx
				b.y = r.ky
				b.h = 0.0
			elif r.st >= TURN_S + PLACE_S:
				_sceneStage(r, "indietro")
		"indietro":
			faceTo(p, b.x, b.y)
			var bk := runupBack(r)
			if C.hyp(p.x - bk.x, p.y - bk.y) < SPOT_R:
				r.rinc = true
				_sceneEnd(r)


func _sceneGo(r: R.Restart, b: R.Ball, p: R.Player) -> void:
	var d: float = C.hyp(b.x - p.x, b.y - p.y)
	# presa al volo del pallonetto del raccattapalle
	if r.rimando and b.h > 0.25 and b.h < CATCH_H and b.vh < 0.0 and d < CATCH_R:
		b.owner = p
		b.h = 0.0
		b.vh = 0.0
		_sceneStage(r, "porta")
		return
	if b.h < 0.3 and C.hyp(b.vx, b.vy) < PICK_V and d < FETCH_GAP + PICK_R:
		b.vx = 0.0
		b.vy = 0.0
		b.vh = 0.0
		b.h = 0.0
		b.owner = p
		r.posato = true # fermo dov'è finché non si è chinato
		faceTo(p, b.x, b.y)
		if r.type == "throw":
			_throwSpot(r, b.y)
		_sceneStage(r, "raccogli")
		return
	if not r.rimando and not _sceneFetch(r) and b.h <= 0.0 and C.hyp(b.vx, b.vy) < BALL_REST_V:
		var tx: float = r.sx + r.sfx * 0.4
		var ty: float = r.sy + r.sfy * 0.4
		var T: float = C.clamp_(C.hyp(tx - b.x, ty - b.y) / LOB_V, LOB_T_MIN, LOB_T_MAX)
		# il raccattapalle lancia quando il battitore arriva al posto più o meno insieme al pallone
		if C.hyp(p.x - r.sx, p.y - r.sy) <= vmax(p) * T:
			_sceneLob(tx, ty, T)


## pallonetto del raccattapalle dal punto in cui il pallone si è fermato fino al battitore
func _sceneLob(tx: float, ty: float, T: float) -> void:
	var b := ball
	b.vx = (tx - b.x) / T
	b.vy = (ty - b.y) / T
	b.h = 0.02
	b.vh = (LOB_H - b.h + 0.5 * G * T * T) / T
	restart.rimando = true
	ev("ballboy", {"team": restart.team})


## rimessa: si batte dove il battitore ha raccolto il pallone (vicino al punto d'uscita), dal bordo del campo
func _throwSpot(r: R.Restart, y: float) -> void:
	var dir: float = -1.0 if r.team else 1.0
	var y2: float = C.clamp_(C.clamp_(y, r.sy - THROW_SLIDE, r.sy + THROW_SLIDE), -HL + 1.0, HL - 1.0)
	var fx: float = -r.sx
	var fy: float = dir * 6.0
	var n: float = C.orf(C.hyp(fx, fy), 1.0)
	r.sy = y2
	r.sfx = fx / n
	r.sfy = fy / n
	r.kx = C.clamp_(r.sx + r.sfx * 0.6, -HW + 0.2, HW - 0.2)
	r.ky = C.clamp_(y2 + r.sfy * 0.6, -HL + 0.2, HL - 0.2)
	r.x = r.kx
	r.y = r.ky


func _sceneTurn(p: R.Player, r: R.Restart, dt: float) -> void:
	var k: float = minf(1.0, dt * TURN_K)
	var fx: float = p.fx + (r.sfx - p.fx) * k
	var fy: float = p.fy + (r.sfy - p.fy) * k
	var n: float = C.hyp(fx, fy)
	if n < 1e-3: # girato di mezzo giro esatto: si gira da un lato
		fx = -p.fy
		fy = p.fx
		n = 1.0
	p.fx = fx / n
	p.fy = fy / n


func _sceneStage(r: R.Restart, s: String) -> void:
	r.scena = s
	r.st = 0.0


func _sceneEnd(r: R.Restart) -> void:
	r.scena = ""
	r.st = 0.0
	r.t = 0.0
	for p: R.Player in players:
		p.rgo = false
	ball.owner = r.taker
	if r.type == "throw":
		r.taker.fx = r.sfx
		r.taker.fy = r.sfy
	ev("restart_ready", {"kind": r.type, "team": r.team})


## sicurezza (scena troppo lunga): tutti al loro posto subito, come la ripresa di sempre
func sceneSkip() -> void:
	var r := restart
	var b := ball
	var tk := r.taker
	for p: R.Player in players:
		if p.rgo and not p.off:
			place(p, p.rtx, p.rty)
	place(tk, r.sx, r.sy)
	tk.fx = r.sfx
	tk.fy = r.sfy
	b.owner = tk
	b.x = r.kx
	b.y = r.ky
	b.h = 0.0
	b.vx = 0.0
	b.vy = 0.0
	b.vh = 0.0
	r.posato = r.type != "throw"
	r.rinc = false
	_sceneEnd(r)


## battitore dell'angolo nella scena: il più vicino alla bandierina, ma uno più bravo nei passaggi può stare più lontano
## (CORNER_PAS_M metri per punto); come sempre niente difensori, se ce ne sono altri
func sceneCornerTaker(outf: Array, x: float, y: float) -> R.Player:
	var best: R.Player = null
	var bs: float = 1e9
	for p: R.Player in outf:
		if p.pos == "D":
			continue
		var s: float = C.hyp(p.x - x, p.y - y) - p.st.pas * CORNER_PAS_M
		if s < bs:
			bs = s
			best = p
	return best if best != null else outf[0]
