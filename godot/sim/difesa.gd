# Fase difensiva della CPU e dei compagni CPU della persona (solo Godot, opzione "rifiniture" della partita; senza,
# motore identico al JS e agli stili di prima). Luis 2026-11-24: "fai tutte le modifiche che ritieni sensate" dopo lo
# studio degli stili (tools/studio_stili.gd). Misure prima/dopo in DECISIONI.md.
# - Rientri: con il pallone nella propria metà gli esterni rientrano (defAnchor): i quinti del 3-5-2 fino alla linea
#   dei difensori (difesa a cinque), le ali del 4-3-3 (e gli esterni alti) fino alla linea dei centrocampisti.
# - A uomo (uomoPos, _uomoAbbina): abbinamenti per zona e ruolo rifatti di continuo (difensori sulle punte,
#   centrocampisti sui centrocampisti, nessuno sui difensori avversari), un difensore libero dietro, si sta
#   sull'avversario meno di prima e mai troppo lontano dal proprio posto, difensori dietro la palla.
# - Fuorigioco (offStepUp): linea più alta e che sale tutta insieme, di corsa, quando il pallone va avanti.
# - Pressing (press2Pos): il secondo pressatore raddoppia finché il primo non è addosso al portatore, poi chiude la
#   linea di passaggio verso il compagno più vicino; esce prima (Stili.PRESS_FROM_R).
# Le linee disegnate dalla persona e il suo dito hanno sempre la precedenza (ai.gd assign): qui si cambiano solo i
# posti di chi muove la CPU. Niente numeri casuali.
extends "angoli.gd"

const RIENTRO_BF := 0.5        # pallone più vicino di così alla propria porta (frazione del campo): gli esterni rientrano ...
const RIENTRO_FULL := 0.25     # ... del tutto da qui in giù
const RIENTRO_WIDE := 0.6      # esterno = |bx| del posto sopra questo
const RIENTRO_BACK5_BY := 0.2  # quinti della difesa a tre: rientrano fino a questa profondità del posto (linea dei difensori)
const RIENTRO_MID_BY := 0.42   # ali ed esterni alti: fino alla linea dei centrocampisti

var back3: Array = [false, false]  # squadra con tre difensori (i quinti rientrano a cinque)
var libero: Array = [-1, -1]       # a uomo: indice del difensore libero (senza uomo)


## posto difensivo del giocatore: anchor() più i rientri degli esterni vicino alla propria area (solo "rifiniture")
func defAnchor(p: R.Player) -> PackedFloat64Array:
	var an := anchor(p)
	if not rifiniture or p.pos == "P" or absf(p.bx) <= RIENTRO_WIDE or att == p.team:
		return an
	var dir: float = -1.0 if p.team else 1.0
	var bf: float = C.clamp_((ball.y * dir + HL) / L, 0.0, 1.0)
	var k: float = C.clamp_((RIENTRO_BF - bf) / (RIENTRO_BF - RIENTRO_FULL), 0.0, 1.0)
	if k <= 0.0:
		return an
	var to: float = p.by
	if p.pos == "C" and back3[p.team]:
		to = RIENTRO_BACK5_BY
	elif p.pos == "A" or (p.pos == "C" and p.by > RIENTRO_MID_BY):
		to = RIENTRO_MID_BY
	if to >= p.by:
		return an
	# stessa scala di anchor in difesa (by × 0,55)
	an[1] -= (p.by - to) * 0.55 * k * L * dir
	return an


## ogni 0,1 s (computeLines): quante punte ha la difesa e, a uomo, gli abbinamenti
func defLinesUpdate(tm: int) -> void:
	var nd: int = 0
	for p: R.Player in players:
		if p.team == tm and not p.off and p.pos == "D":
			nd += 1
	back3[tm] = nd == 3
	if stD[tm].uomo:
		_uomoAbbina(tm)


# a uomo: il libero è il difensore più centrale; gli altri difensori e i centrocampisti si abbinano agli avversari
# di movimento che non sono difensori, la coppia più vicina per prima (posto difensivo contro posizione dell'avversario),
# con le penalità di ruolo e un premio alla coppia di prima. Chi resta senza avversario sta a zona.
func _uomoAbbina(tm: int) -> void:
	var lib: int = int(libero[tm])
	if lib < 0 or players[lib].off:
		lib = -1
		var bx: float = 9.0
		for p: R.Player in players:
			if p.team == tm and not p.off and p.pos == "D" and absf(p.bx) < bx:
				bx = absf(p.bx)
				lib = tm * 11 + p.i
		libero[tm] = lib
	var old: Dictionary = marks[tm]
	var mk := {}
	var taken := {}
	# prima i difensori sulle punte, poi i centrocampisti sui centrocampisti, poi gli avanzi (con la penalità di ruolo)
	for fase in 3:
		var pairs: Array = []
		for p: R.Player in players:
			var kp: int = tm * 11 + p.i
			if p.team != tm or p.off or not (p.pos == "D" or p.pos == "C") or kp == lib or mk.has(kp):
				continue
			var an := defAnchor(p)
			for o: R.Player in players:
				var ko: int = o.team * 11 + o.i
				if o.team == tm or o.off or o.pos == "P" or o.pos == "D" or taken.has(ko):
					continue
				var same: bool = (p.pos == "D") == (o.pos == "A")
				if fase < 2 and (not same or (fase == 0) != (p.pos == "D")):
					continue
				var c: float = C.hyp(o.x - an[0], o.y - an[1]) + (0.0 if same else Stili.UOMO_ROLE)
				if old.get(kp, -1) == ko:
					c -= Stili.UOMO_KEEP
				pairs.append([c, kp, ko])
		pairs = stableSort(pairs, func(q: Array) -> float: return q[0])
		for q: Array in pairs:
			if mk.has(q[1]) or taken.has(q[2]):
				continue
			mk[q[1]] = q[2]
			taken[q[2]] = true
	marks[tm] = mk


## a uomo con "rifiniture": posto del giocatore (tx, ty) dato il suo posto difensivo (ax, ay)
func uomoPos(p: R.Player, ax: float, ay: float, tx: float, ty: float) -> PackedFloat64Array:
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var key: int = tm * 11 + p.i
	var b := ball
	if key == int(libero[tm]):
		# il libero: centrale, dietro il proprio posto e dietro l'attaccante avversario più avanzato
		var lo: float = ay * dir - Stili.UOMO_LIBERO
		for o: R.Player in players:
			if o.team != tm and not o.off and o.pos != "P":
				lo = minf(lo, o.y * dir - Stili.UOMO_LIBERO * 0.5)
		tx = ax * 0.5 + b.x * 0.2
		ty = maxf(lo, -HL + 5.0) * dir
	elif marks[tm].has(key):
		var o: R.Player = players[marks[tm][key]]
		if not o.off and o != b.owner:
			var ux: float = -o.x
			var uy: float = -dir * HL - o.y
			var n: float = C.orf(C.hyp(ux, uy), 1.0)
			tx = ax * (1.0 - Stili.UOMO_K_R) + (o.x + ux / n * Stili.UOMO_GAP) * Stili.UOMO_K_R
			ty = ay * (1.0 - Stili.UOMO_K_R) + (o.y + uy / n * Stili.UOMO_GAP) * Stili.UOMO_K_R
			var dx: float = tx - ax
			var dy: float = ty - ay
			var d: float = C.hyp(dx, dy)
			if d > Stili.UOMO_LEASH:
				tx = ax + dx / d * Stili.UOMO_LEASH
				ty = ay + dy / d * Stili.UOMO_LEASH
	# difensori dietro la palla, centrocampisti mai molto davanti
	if p.pos == "D" or p.pos == "C":
		var lim: float = b.y * dir - (Stili.UOMO_BEHIND_D if p.pos == "D" else Stili.UOMO_BEHIND_C)
		if ty * dir > lim:
			ty = maxf(lim, -HL + 4.0) * dir
	return PackedFloat64Array([tx, ty])


## fuorigioco con "rifiniture": la linea (nel verso d'attacco di tm) sale di OFF_STEP_M quando il pallone va avanti
func offStepUp(tm: int, line: float) -> float:
	var b := ball
	var dir: float = -1.0 if tm else 1.0
	var vy: float = (b.owner.vy if b.owner != null else b.vy) * dir
	if vy > Stili.OFF_STEP_V and b.owner != null and b.owner.team == tm:
		return line # il pallone è nostro: la linea non insegue chi attacca
	if vy > Stili.OFF_STEP_V:
		line += Stili.OFF_STEP_M
	return C.clamp_(minf(line, b.y * dir - Stili.OFF_BALL_R), -HL + 6.0, 0.0)


## pressing con "rifiniture": il secondo pressatore (p) raddoppia sul portatore c finché il primo non gli è addosso,
## poi chiude la linea di passaggio verso il compagno del portatore più vicino
func press2Pos(p: R.Player, c: R.Player, first: R.Player) -> PackedFloat64Array:
	var b := ball
	var on: PackedFloat64Array = PackedFloat64Array([b.x + c.vx * 0.25, b.y + c.vy * 0.25])
	if first == null or first == p or C.hyp(first.x - c.x, first.y - c.y) > Stili.PRESS2_ENGAGED:
		return on
	var q: R.Player = null
	var qd: float = Stili.PRESS2_LANE_R
	for o: R.Player in players:
		if o.team == c.team and o != c and not o.off and o.pos != "P":
			var d: float = C.hyp(o.x - c.x, o.y - c.y)
			if d < qd:
				qd = d
				q = o
	if q == null:
		return on
	var k: float = maxf(Stili.PRESS2_LANE_K, Stili.PRESS2_LANE_MIN / C.orf(qd, 1.0))
	k = minf(k, 0.8)
	return PackedFloat64Array([c.x + (q.x - c.x) * k, c.y + (q.y - c.y) * k])


## raggio entro cui chi difende a zona prende in consegna l'avversario più vicino al proprio posto (catenaccio: di più)
func defMarkR(tm: int, base: float) -> float:
	return Stili.CAT_MARK_R if rifiniture and stD[tm].catenaccio else base
