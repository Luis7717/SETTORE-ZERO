# La partita: stato, rimesse, calci, pallone, uscite, gol, tempo e comandi umani (porting di src/sim/match.js).
# Uso: var m := SimMatch.new({"seed": 1, "halfLen": 150, "human": [true, false], "teams": [squadraA, squadraB]})
#      m.step(1.0 / 60.0) a ogni fotogramma; m.events = eventi del passo (da svuotare dopo averli letti).
# Squadra: {"name", "formation", "skill", "players": [11 giocatori {name, pos, vel, tir, pas, dri, dif, fis, por, tes?}]}.
#          Facoltativi: "stileAtt" e "stileDif" = stile di gioco (stili.gd); senza, motore identico a prima.
# Opzione "portaAuto" (predefinita true): il portatore della squadra umana senza strada si muove da solo (ai.gd
# humanCarrierAuto); false = come prima (avanza piano e dritto), lo usano i test confrontati col JS.
# Opzione "riprese" (predefinita false, la accende il gioco): rimessa, rinvio dal fondo e angolo senza teletrasporto,
# il battitore va a prendere il pallone (riprese.gd).
# Opzione "rifiniture" (predefinita false, il gioco la accende): correzioni di gameplay solo Godot (motion.gd
# deflectBehind: niente "campanili" sulle respinte in angolo da lontano; duel.gd burstDir: Scatto in avanti).
# Opzione "falli" (predefinita false, la accende il gioco): i contrasti da dietro e in ritardo a volte sono fallo
# (falli.gd): punizioni, vantaggio, cartellini, qualche rigore.
# Opzione "parata" (predefinita false, la accende il gioco): fermatempo della parata col bersaglio sulla porta e il punto
# scelto rispettato (parata.gd).
class_name SimMatch
extends "parata.gd"

# Calci da fermo (Luis 2026-11-21): chi batte non può toccare il pallone una seconda volta finché non l'ha toccato un altro.
const DBL_FREE := 6.0 # sicurezza: dopo tanto tempo di pallone libero senza che nessun altro lo tocchi, il battitore può riprenderlo (s)
# Meteo: campo facoltativo "meteo" delle opzioni della partita ("sereno" | "nuvoloso" | "pioggia" | "neve").
# Senza il campo (o sereno, nuvoloso, valori sconosciuti) il motore resta identico a prima. Come src/sim/match.js.
const RAIN_ROLL := 0.75  # pioggia: attrito del rotolamento ×0,75 = palla più veloce sull'erba bagnata
const RAIN_SLIDE := 1.3  # pioggia: la scivolata dura (e scorre) ×1,3
const RAIN_STUN := 1.25  # pioggia: chi perde un contrasto resta fermo ×1,25 (scivola sull'erba bagnata)
const SNOW_ROLL := 1.35  # neve: attrito del rotolamento ×1,35 = palla più lenta
const ENERGY_MIN := 0.2 # energia più bassa possibile (come il calo in partita, motion.gd)
const PREVIEW_SEC := 2.4 # durata massima dell'anteprima della traiettoria (s)
const SHOT_V0 := 22.0 # velocità base del tiro (m/s), più la bravura del tiratore
# Forma del tratto disegnato (spec.tratto, Luis 2026-11-22): dritto = rasoterra, curvo = a effetto e alto.
# Curvatura = quanto la linea si allontana dalla corda tra inizio e fine (spec.curve, m, col segno del lato).
const CURVE_MIN_M := 1.2      # sotto tanti metri di curvatura il tratto è dritto (un passaggio di 2-3 m un po' storto resta rasoterra) ...
const CURVE_MIN_FRAC := 0.15  # ... e anche sotto il 15% della lunghezza
const CURVE_FULL_FRAC := 0.3  # curvatura pari al 30% della lunghezza = effetto pieno (k = 1)
const CURVE_T_MIN := 1.25     # passaggio curvo: volo di almeno tanti secondi (punta oltre 2 m: scavalca chi sta in mezzo) ...
const CURVE_T_EXTRA := 0.5    # ... più tanti secondi a effetto pieno (più alto)
const CURL_APEX_MIN := 1.4    # tiro a giro: punto più alto del volo (m) con poco effetto ...
const CURL_APEX_MAX := 2.6    # ... e con effetto pieno
const CURL_V_MIN := 0.75      # tiro a giro: almeno tanto della velocità del tiro normale (Luis 2026-11-24: era troppo lento,
                              # il portiere ci arrivava); da vicino la parabola si abbassa da sola
const GROUND_ARRIVE := 5.0    # passaggio rasoterra: velocità con cui arriva al compagno (m/s)
const GROUND_ARRIVE_SPACE := 1.0 # ... e nello spazio, dove si deve quasi fermare (m/s)
const TRATTO_LOFT_M := 25.0  # tratto dritto più lungo di così (o con un avversario sulla linea) = pallone alto ma dritto (Luis 2026-11-23)
const MATE_AT_END := 5.0      # c'è un compagno entro tanti metri dalla fine della linea = passaggio a lui (m)
const FIRST_SIG := 1.15      # di prima (spec.first): errore di mira ×1,15 ...
const FIRST_SIG_STAT := 0.008 # ... più 0,008 per ogni punto che manca a 100 (tiro per i tiri, passaggio per il resto)
const GK_REACT := 0.42 # tempo di reazione base del portiere del computer (s), meno la sua bravura
const WALL_RANGE := 30.0 # punizione entro questa distanza dalla porta: barriera (m)
const WALL_DIST := 9.15 # distanza della barriera dal pallone (m)
const WALL_GAP := 0.75 # spazio tra i giocatori in barriera (m)
const ADV_FREE := 3.0 # vantaggio solo se nessun altro avversario è più vicino di così al portatore (m)
const ADV_MIN_Y := -5.0 # ... e solo da qui in avanti (m nel verso d'attacco, 0 = metà campo)
const PATH_STEP := 1.2   # distanza minima tra due punti della strada disegnata (m)
const PATH_REACH := 1.3  # punto raggiunto quando il portatore è più vicino di così (m)
const RUN_END_REACH := 0.4  # linea di difesa: l'ultimo punto va raggiunto davvero (così una linea fin sull'avversario arriva al contrasto) (m)
const PATH_SPRINT := 6.0 # scatta finché davanti resta più strada di così (m)
const PATH_TTL := 20.0   # durata massima di una strada disegnata (s)
const PATH_LOOK := 3.0   # il giocatore punta a un punto della strada almeno così avanti: un punto troppo vicino lo frenava e lo scatto non si vedeva (m)
const RUN_MAX_LEN := 14.0 # lunghezza massima di una linea di difesa, misurata dal giocatore: il resto si taglia (m)
const SPRINT_DIST := 6.0 # dito più lontano di così dal giocatore controllato (m) = scatto
var queued: Array = [null, null] # di prima: calcio preparato per squadra {p, spec, kick} (userQueue / fireQueued)
const CORNER_ATT := [[-3.0, 7.0], [3.0, 8.5], [0.0, 11.5], [-6.0, 10.0], [6.0, 12.5], [-2.0, 19.0], [9.0, 22.0], [-10.0, 46.0], [8.0, 50.0], [0.0, 44.0]]
const CORNER_DEF := [[-2.6, 5.5], [2.6, 5.5], [0.0, 8.0], [-5.0, 8.5], [5.0, 9.5], [0.0, 13.0], [-3.0, 3.0], [-7.0, 20.0], [8.0, 21.0], [0.0, 38.0]]


## Effetti del meteo sul motore: roll = attrito del rotolamento del pallone (m/s²), slide = durata della scivolata,
## stun = tempo da fermo di chi perde un contrasto (moltiplicatori; 1 = come sempre). Come weatherFx di src/sim/match.js.
static func weatherFx(m: Variant) -> Dictionary:
	if m is String and m == "pioggia":
		return {"roll": ROLL * RAIN_ROLL, "slide": RAIN_SLIDE, "stun": RAIN_STUN}
	if m is String and m == "neve":
		return {"roll": ROLL * SNOW_ROLL, "slide": 1.0, "stun": 1.0}
	return {"roll": ROLL, "slide": 1.0, "stun": 1.0}


## Energia a inizio partita (o all'ingresso dalla panchina): il campo facoltativo `energy0` del giocatore sorgente
## (carriera: chi arriva stanco dalle partite prima), tra ENERGY_MIN e 1; senza il campo 1, come sempre.
## Come startEnergy di src/sim/match.js.
static func startEnergy(src: Variant) -> float:
	if not src is Dictionary:
		return 1.0
	var e: Variant = (src as Dictionary).get("energy0")
	if (typeof(e) != TYPE_FLOAT and typeof(e) != TYPE_INT) or is_nan(float(e)) or is_inf(float(e)):
		return 1.0
	return minf(1.0, maxf(ENERGY_MIN, float(e)))


# Taglia una linea che parte da (x0, y0) e passa per pts alla lunghezza max (m): l'ultimo punto cade esattamente a max.
# pts = Array di {x, y}; il risultato ha copie dei punti (come `{ ...q }` in JS).
static func clipLen(x0: float, y0: float, pts: Array, mx: float) -> Array:
	var out: Array = []
	var px: float = x0
	var py: float = y0
	var left: float = mx
	for q: Dictionary in pts:
		var d: float = C.hyp(q.x - px, q.y - py)
		if d >= left:
			var k: float = left / d if d > 0.0 else 0.0
			var cut: Dictionary = q.duplicate()
			cut.x = px + (q.x - px) * k
			cut.y = py + (q.y - py) * k
			out.append(cut)
			return out
		out.append(q)
		left -= d
		px = q.x
		py = q.y
	return out


# indice del primo punto della strada (da i in poi) lontano almeno PATH_LOOK da (x, y); l'ultimo se nessuno lo è
static func lookAhead(path: Array, i: int, x: float, y: float) -> int:
	var j: int = i
	while j < path.size() - 1 and C.hyp(path[j].x - x, path[j].y - y) < PATH_LOOK:
		j += 1
	return j


func _init(o: Dictionary) -> void:
	var sd: int = int(o.get("seed", 1))
	rng = SimRngScript.new(sd if sd != 0 else 1)
	var hl: float = float(o.get("halfLen", 0.0))
	halfLen = hl if hl != 0.0 else 180.0
	human = o.get("human", [true, false])
	autoGk = o.get("autoGk", [false, false])
	portaAuto = bool(o.get("portaAuto", true))
	rifiniture = bool(o.get("rifiniture", false))
	teams = o.teams
	var wx := weatherFx(o.get("meteo"))
	var mt: Variant = o.get("meteo")
	meteo = mt if mt is String else ""
	headCtl = bool(o.get("testa", false))
	paraCtl = bool(o.get("parata", false))
	paraSeed = sd
	riprese = bool(o.get("riprese", false))
	falliOn = bool(o.get("falli", false))
	if riprese:
		raccattaPrepara() # raccattapalle dietro le porte (raccatta.gd)
	roll = wx.roll
	slideK = wx.slide
	stunK = wx.stun
	# forza dei passaggi rasoterra: sul bagnato si calcia come all'asciutto (il pallone corre di più), sulla neve più forte
	rollKick = maxf(ROLL, roll)
	players = []
	for tt in 2:
		var tmd: Dictionary = teams[tt]
		var F: Array = C.FORMATIONS.get(tmd.get("formation", ""), C.FORMATIONS["4-4-2"])
		if not tmd.has("skill"):
			tmd.skill = 0.5
		stA[tt] = Stili.att(tmd.get("stileAtt"))
		stD[tt] = Stili.dif(tmd.get("stileDif"))
		for i in 11:
			players.append(mk(tt, i, tmd.players[i], F[i]))
	ball = R.Ball.new()
	score = [0, 0]
	half = 1
	t = 0.0
	time = 0.0
	phase = "play"
	events = []
	stats = {"shots": [0, 0], "onT": [0, 0], "poss": [0.0, 0.0], "fouls": [0, 0], "yellows": [0, 0], "reds": [0, 0], "corners": [0, 0], "saves": [0, 0], "headers": [0, 0], "volleys": [0, 0]}
	var ko: Variant = o.get("kickoff")
	kickoffTeam = int(ko) if typeof(ko) != TYPE_NIL else (0 if rnd() < 0.5 else 1)
	setupKickoff(kickoffTeam)


func mk(tm: int, i: int, src: Dictionary, slot: Array) -> R.Player:
	var p := R.Player.new()
	p.team = tm
	p.i = i
	p.src = src
	p.name = String(src.get("name", ""))
	p.pos = slot[0]
	p.bx = slot[1]
	p.by = slot[2]
	p.st = C.effStats(src, slot[0])
	p.energy = startEnergy(src)
	p.fy = -1.0 if tm else 1.0
	p.phase = rnd() * 6.0
	p.soT = rnd()
	p.look = lookFor(src)
	return p


# aspetto del giocatore (solo grafica, in JS lookOf di src/looks.js): il numero casuale si consuma lo stesso,
# così le partite a seme fisso restano identiche al JS
func lookFor(_src: Dictionary) -> Variant:
	rnd()
	return null


func _nearest(list: Array, x: float, y: float) -> R.Player:
	var best: R.Player = null
	var bd: float = 1e9
	for p: R.Player in list:
		if p.pos == "P":
			continue
		var d: float = C.hyp(p.x - x, p.y - y)
		if d < bd:
			bd = d
			best = p
	return best


func setRestart(type: String, tm: int, x: float, y: float, taker: R.Player = null) -> void:
	var b := ball
	var dir: float = -1.0 if tm else 1.0
	var own: float = -dir * HL
	var opp: int = 1 - tm
	b.owner = null
	b.vx = 0.0
	b.vy = 0.0
	b.vh = 0.0
	b.h = 0.0
	b.kick = null
	b.shot = null
	b.ct = 0.0
	b.noT = 0.0
	b.dbl = null
	b.dblT = 0.0
	endDuel("gioco fermo")
	endFlee("gioco fermo")
	endHead("gioco fermo")
	phase = "restart"
	move = [null, null]
	runs = [[], []]
	lastPass = null
	advantage = null
	resetStates()
	var cut := false
	var wallSide: float = 0.0
	var mine: Array = team(tm).filter(func(p: R.Player) -> bool: return not p.off)
	var theirs: Array = team(opp).filter(func(p: R.Player) -> bool: return not p.off)
	if type == "kickoff":
		cut = true
		x = 0.0
		y = 0.0
		for p: R.Player in players:
			if p.off:
				continue
			var d: float = -1.0 if p.team else 1.0
			place(p, p.bx * HW * 0.9, d * (-HL + p.by * 0.68 * L))
			p.fx = 0.0
			p.fy = d
		taker = null
		var bd: float = 9.0
		for p: R.Player in mine:
			if p.pos != "P":
				var s: float = absf(p.bx) - p.by
				if s < bd:
					bd = s
					taker = p
		place(taker, 0.0, -dir * 0.6)
		pushAway(opp, 0.0, 0.0, CIRCLE)
	elif type == "throw":
		x = C.clamp_(x, -HW + 0.3, HW - 0.3)
		y = C.clamp_(y, -HL + 1.0, HL - 1.0)
		taker = _nearest(mine, x, y)
		place(taker, x, y)
		pushAway(opp, x, y, 5.0)
	elif type == "freekick":
		x = C.clamp_(x, -HW + 1.0, HW - 1.0)
		y = C.clamp_(y, -HL + 1.0, HL - 1.0)
		taker = _nearest(mine, x, y)
		place(taker, x - 0.0, y - dir * 0.3)
		pushAway(opp, x, y, 8.5)
		wallSide = buildWall(tm, x, y)
	elif type == "gk":
		for o: R.Player in theirs:
			if absf(o.x) < BOX_W / 2.0 + 1.0 and o.y * dir < -HL + BOX_D + 1.0:
				o.y = dir * (-HL + BOX_D + 2.0)
				o.vx = 0.0
				o.vy = 0.0
	elif type == "goalkick":
		cut = true
		x = (1.0 if x > 0.0 else -1.0) * 3.0
		y = own + dir * SIX_D
		taker = gk(tm)
		b.x = x
		b.y = y
		att = tm
		for p: R.Player in players:
			if not p.off and p != taker:
				var an := anchor(p)
				var px: float = an[0] + (rnd() - 0.5)
				place(p, px, an[1] + (rnd() - 0.5))
		place(taker, x, y - dir * 0.5)
		for o: R.Player in theirs:
			if absf(o.x) < BOX_W / 2.0 + 1.0 and o.y * dir < -HL + BOX_D + 1.0:
				o.y = dir * (-HL + BOX_D + 2.0)
	elif type == "corner":
		cut = true
		var sx: float = 1.0 if x > 0.0 else -1.0
		x = sx * (HW - 0.4)
		y = dir * (HL - 0.4)
		var gy: float = dir * HL
		var outf: Array = mine.filter(func(p: R.Player) -> bool: return p.pos != "P")
		taker = null
		var bp: float = -1.0
		for p: R.Player in outf:
			if p.pos != "D" and p.st.pas > bp:
				bp = p.st.pas
				taker = p
		if sceneNoCut: # scena (riprese.gd): batte uno bravo e vicino, che alla bandierina ci va di corsa
			taker = sceneCornerTaker(outf, x, y)
		var tk := taker
		var order: Array = stableSort(outf.filter(func(p: R.Player) -> bool: return p != tk), func(p: R.Player) -> float: return float("ACD".find(p.pos)))
		for k in order.size():
			var s: Array = CORNER_ATT[k] if k < CORNER_ATT.size() else [0.0, 45.0]
			place(order[k], s[0], gy - dir * s[1])
		place(gk(tm), 0.0, own + dir * 12.0)
		var defs: Array = theirs.filter(func(p: R.Player) -> bool: return p.pos != "P")
		for k in defs.size():
			var s2: Array = CORNER_DEF[k] if k < CORNER_DEF.size() else [0.0, 30.0]
			place(defs[k], s2[0], gy - dir * s2[1])
		place(gk(opp), 0.0, gy - dir * 0.6)
		place(taker, x, y)
		stats.corners[tm] += 1
	elif type == "penalty":
		cut = true
		x = 0.0
		y = dir * (HL - PEN_D)
		taker = null
		var bt: float = -1.0
		for p: R.Player in mine:
			if p.pos != "P" and p.st.tir > bt:
				bt = p.st.tir
				taker = p
		var k: int = 0
		for p: R.Player in players:
			if p.off or p == taker or p.pos == "P":
				continue
			place(p, -19.0 + (k % 10) * 4.2 + (2.0 if k >= 10 else 0.0), dir * (HL - BOX_D - 2.5 - (2.5 if k >= 10 else 0.0)))
			k += 1
		place(gk(opp), 0.0, dir * (HL - 0.4))
		place(gk(tm), 0.0, own + dir * 14.0)
		place(taker, 0.0, y - dir * 0.9)
	if type != "gk":
		var fx: float = 0.0 if type == "penalty" else C.clamp_(x * 0.3, -10.0, 10.0)
		var fy: float
		if type == "penalty":
			fy = dir * HL
		elif type == "throw" or type == "corner":
			fy = y - dir * (8.0 if type == "corner" else -2.0)
		else:
			fy = y + dir * 20.0
		faceTo(taker, fx, fy)
		if type == "throw":
			faceTo(taker, 0.0, y + dir * 6.0)
		b.x = taker.x + taker.fx * 0.6
		b.y = taker.y + taker.fy * 0.6
		if type == "throw" or type == "corner":
			b.x = C.clamp_(b.x, -HW + 0.2, HW - 0.2)
			b.y = C.clamp_(b.y, -HL + 0.2, HL - 0.2)
	b.owner = taker
	b.last = taker
	b.prev = null
	taker.vx = 0.0
	taker.vy = 0.0
	for p: R.Player in players:
		if not p.off and p != taker:
			faceTo(p, b.x, b.y)
	att = tm
	var rs := R.Restart.new()
	rs.type = type
	rs.team = tm
	rs.taker = taker
	rs.x = b.x
	rs.y = b.y
	rs.t = 0.0
	rs.wait = 1.1 + rnd() * 0.7 + (0.8 if type == "penalty" else 0.0) + (0.5 if cut else 0.0) + (0.6 if wallSide != 0.0 else 0.0)
	rs.wallSide = wallSide
	restart = rs
	predT = 0.0
	updateCtrl(0.0, true)
	ev("restart", {"kind": type, "team": tm, "cut": cut and not sceneNoCut, "scena": sceneNoCut})


# Barriera della squadra che difende sulla punizione di `tm` dal punto (x, y): 2-5 giocatori a 9,15 m,
# sulla linea tra pallone e palo vicino. Ritorna il lato coperto (-1/1), 0 se la punizione è troppo lontana.
func buildWall(tm: int, x: float, y: float) -> float:
	var dir: float = -1.0 if tm else 1.0
	var gy: float = dir * HL
	var dg: float = C.hyp(x, gy - y)
	if dg > WALL_RANGE or y * dir > HL - 1.0:
		return 0.0
	var side: float = C.sign_(x) if absf(x) > 2.0 else (-1.0 if rnd() < 0.5 else 1.0)
	var n: int = 2 if absf(x) > 20.0 else (5 if dg < 20.0 else (4 if dg < 25.0 else 3))
	var ax: float = side * GW / 4.0
	var ux0: float = ax - x
	var uy0: float = gy - y
	var un: float = C.orf(C.hyp(ux0, uy0), 1.0)
	var ux: float = ux0 / un
	var uy: float = uy0 / un
	var cx: float = x + ux * WALL_DIST
	var cy: float = y + uy * WALL_DIST
	var nx: float = -uy
	var ny: float = ux
	var cand: Array = team(1 - tm).filter(func(p: R.Player) -> bool: return not p.off and p.pos != "P")
	var pool: Array = stableSort(cand, func(p: R.Player) -> float: return C.hyp(p.x - cx, p.y - cy)).slice(0, n)
	for k in pool.size():
		var p: R.Player = pool[k]
		var o: float = (k - (n - 1) / 2.0) * WALL_GAP
		place(p, cx + nx * o, cy + ny * o)
		faceTo(p, x, y)
		p.wall = {"x": p.x, "y": p.y}
	return side


func setupKickoff(tm: int) -> void:
	setRestart("kickoff", tm, 0.0, 0.0)


# ------------------------------------------------------------ calci
# Parametri di lancio del pallone, senza toccare la partita.
# noise = true: errore casuale di direzione e di altezza con gauss() (in partita); false: nessun errore (anteprima).
func launch(p: R.Player, spec: Dictionary, noise: bool) -> Dictionary:
	var b := ball
	var tm := p.team
	var sx: float = b.x if b.owner == p else p.x + p.fx * 0.6
	var sy: float = b.y if b.owner == p else p.y + p.fy * 0.6
	var type: String = spec.type
	var th: float = float(spec.get("th", 0.0))
	var dx: float = spec.tx - sx
	var dy: float = spec.ty - sy
	var D: float = C.hyp(dx, dy)
	if D < 1.0:
		dx = p.fx
		dy = p.fy
		D = 1.0
	var tratto: bool = spec.get("tratto", false)
	var c: float = C.clamp_(float(spec.get("curve", 0.0)), -D * 0.3, D * 0.3)
	var curved := tratto and curveIsCurved(D, c)
	var k := curveK(D, c) if curved else 0.0
	if tratto and not curved:
		c = 0.0 # tratto dritto: dritto anche il pallone
	if type == "auto":
		if tratto:
			# curvo = alto a effetto; dritto = rasoterra se corto e con la linea libera, altrimenti alto ma dritto
			# (Luis 2026-11-23: il lancio lungo dall'altra parte partiva rasoterra e veniva intercettato)
			type = "loft" if (curved or D > TRATTO_LOFT_M or blocked(sx, sy, spec.tx, spec.ty, tm)) else "ground"
		else:
			type = "loft" if (D > 30.0 or blocked(sx, sy, spec.tx, spec.ty, tm)) else "ground"
	var press: float = nearOpp(p.x, p.y, tm)
	var sig: float
	if type == "shot":
		sig = (0.5 + (100.0 - p.st.tir) * 0.04) * (1.5 if press < 2.0 else 1.0)
	else:
		sig = (0.3 + (100.0 - p.st.pas) * 0.025) * (1.4 if type == "loft" else 1.0)
	if spec.get("human", false):
		sig *= 0.75
	if spec.get("first", false):
		sig *= FIRST_SIG + (100.0 - (p.st.tir if type == "shot" else p.st.pas)) * FIRST_SIG_STAT
	var a: float = (gauss() if noise else 0.0) * sig * PI / 180.0
	var ca: float = F.cos_(a)
	var sa: float = F.sin_(a)
	var ux: float = dx / D
	var uy: float = dy / D
	var rx: float = ux * ca - uy * sa
	var ry: float = ux * sa + uy * ca
	ux = rx
	uy = ry
	var nx: float = -uy
	var ny: float = ux
	var v0: float
	var Tt: float
	var vh: float = 0.0
	if type == "ground":
		var rl: float = roll
		var arrive: float = GROUND_ARRIVE
		if tratto and mateNear(tm, p, spec.tx, spec.ty, MATE_AT_END) == null:
			arrive = GROUND_ARRIVE_SPACE
		v0 = minf(17.0 + p.st.pas * 0.13, sqrt(arrive * arrive + 2.0 * rollKick * D))
		var disc: float = v0 * v0 - 2.0 * rl * D
		Tt = (v0 - sqrt(disc)) / rl if disc > 0.0 else v0 / rl
	elif type == "loft":
		var vm: float = 15.0 + p.st.pas * 0.11
		Tt = C.clamp_(D / 14.0, 0.75, 2.6)
		if curved:
			Tt = C.clamp_(D / 14.0, CURVE_T_MIN, 2.6) + CURVE_T_EXTRA * k
		if D / Tt > vm:
			D = vm * Tt
		v0 = D / Tt
		vh = G * Tt / 2.0
	else:
		v0 = SHOT_V0 + p.st.tir * 0.14
		Tt = D / v0
		th = maxf(0.05, th + (gauss() if noise else 0.0) * sig * 0.017 * D)
		vh = (th + 0.5 * G * Tt * Tt) / Tt
		if tratto and not curved:
			# tiro rasoterra: rotola fino alla porta (stessa velocità, niente salita)
			var disc2: float = v0 * v0 - 2.0 * roll * D
			Tt = (v0 - sqrt(disc2)) / roll if disc2 > 0.0 else v0 / roll
			th = 0.0
			vh = 0.0
		elif curved:
			# tiro a giro: sale fino a un punto più alto se l'effetto è forte e arriva in porta all'altezza mirata
			var apex: float = maxf(lerpf(CURL_APEX_MIN, CURL_APEX_MAX, k), th + 0.3)
			var vu: float = sqrt(2.0 * G * apex)
			var T2: float = (vu + sqrt(maxf(0.0, vu * vu - 2.0 * G * th))) / G
			if D / T2 < v0:
				v0 = D / T2
				Tt = T2
				vh = vu
			var vmin: float = CURL_V_MIN * (SHOT_V0 + p.st.tir * 0.14)
			if v0 < vmin:
				# troppo lento per arrivare in porta così in alto: più veloce e parabola più bassa, sempre all'altezza mirata
				v0 = vmin
				Tt = D / v0
				vh = (th + 0.5 * G * Tt * Tt) / Tt
	Tt = maxf(Tt, 0.15)
	var ac: float = C.clamp_(-8.0 * c / (Tt * Tt), -14.0, 14.0)
	var lv: float = -ac * Tt / 2.0
	return {"type": type, "sx": sx, "sy": sy, "v0": v0, "vx": ux * v0 + nx * lv, "vy": uy * v0 + ny * lv, "vh": vh, "cax": nx * ac, "cay": ny * ac, "ct": Tt if ac != 0.0 else 0.0, "curved": curved}


## il tratto (curvatura c su lunghezza D, in m) è curvo? Sotto la soglia conta come dritto
static func curveIsCurved(D: float, c: float) -> bool:
	return absf(c) >= maxf(CURVE_MIN_M, CURVE_MIN_FRAC * D)


## forza dell'effetto 0..1 (0 alla soglia, 1 con curvatura pari a CURVE_FULL_FRAC della lunghezza)
static func curveK(D: float, c: float) -> float:
	var lo := maxf(CURVE_MIN_M, CURVE_MIN_FRAC * D)
	var hi := maxf(lo + 0.5, CURVE_FULL_FRAC * D)
	return C.clamp_((absf(c) - lo) / (hi - lo), 0.0, 1.0)


## compagno di p (non p) entro r metri dal punto (x, y)
func mateNear(tm: int, p: R.Player, x: float, y: float, r: float) -> R.Player:
	for m: R.Player in players:
		if m.team == tm and m != p and not m.off and C.hyp(m.x - x, m.y - y) < r:
			return m
	return null


# Anteprima del volo del pallone per il calcio `spec`, senza errore di mira e senza cambiare la partita.
# Punti ogni 1/30 s: {t, x, y, h}.
func predictKick(p: R.Player, spec: Dictionary, sec: float = PREVIEW_SEC) -> Array:
	var Lc := launch(p, spec, false)
	var s := R.Ball.new()
	s.x = Lc.sx
	s.y = Lc.sy
	s.h = 0.02
	s.vx = Lc.vx
	s.vy = Lc.vy
	s.vh = Lc.vh
	s.cax = Lc.cax
	s.cay = Lc.cay
	s.ct = Lc.ct
	var pts: Array = [{"t": 0.0, "x": s.x, "y": s.y, "h": s.h}]
	var k: int = 1
	while k <= sec * 60.0:
		C.ballPhys(s, 1.0 / 60.0, roll)
		if k % 2 == 0:
			pts.append({"t": k / 60.0, "x": s.x, "y": s.y, "h": s.h})
		if absf(s.x) > HW + 1.0 or absf(s.y) > HL + 1.0 or (s.h == 0.0 and C.hyp(s.vx, s.vy) < 0.3):
			break
		k += 1
	return pts


func kick(p: R.Player, spec: Dictionary) -> void:
	var b := ball
	if phase == "restart" and restart.rinc and restart.pend == null and p == restart.taker:
		# scena della ripresa: il battitore è qualche passo indietro, prima prende la rincorsa (riprese.gd)
		restart.pend = spec.duplicate()
		restart.st = 0.0
		return
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	# stesso ordine di estrazione dei numeri casuali: prima la direzione, poi (solo nei tiri) l'altezza
	var Lc := launch(p, spec, true)
	var type: String = Lc.type
	b.owner = null
	b.x = Lc.sx
	b.y = Lc.sy
	b.h = 0.02
	b.vx = Lc.vx
	b.vy = Lc.vy
	b.vh = Lc.vh
	b.cax = Lc.cax
	b.cay = Lc.cay
	b.ct = Lc.ct
	b.noP = p
	b.noT = 0.35
	if b.last != p:
		b.prev = b.last
		b.last = p
	var exempt := false
	# calcio da fermo (il portiere che rilancia dalle mani no): il battitore non può ritoccare il pallone (dblBan)
	b.dbl = p if (phase == "restart" and restart.type != "gk") else null
	b.dblT = 0.0
	if phase == "restart":
		exempt = restart.type in ["throw", "goalkick", "corner"]
		phase = "play"
		restart = null
	var off: Array = []
	if not exempt:
		computeLines()
		var line: float = offLine[tm]
		var sy: float = Lc.sy
		for m: R.Player in players:
			if m.team == tm and m != p and not m.off and m.y * dir > line + 0.3 and m.y * dir > sy * dir + 0.3 and m.y * dir > 0.0:
				off.append(m)
	b.kick = R.Kick.make(tm, p, type, 0.0, off, bool(spec.get("human", false)))
	b.shot = null
	detectShot()
	if b.shot != null and b.shot.team == tm:
		stats.shots[tm] += 1
		if b.shot.on:
			stats.onT[tm] += 1
	elif type == "shot":
		stats.shots[tm] += 1
	p.kickAnim = 0.35
	p.stun = maxf(p.stun, 0.12)
	predT = 0.0
	if type == "shot":
		useAdvantage(tm)
	ev("kick", {"p": p, "kind": type, "v": Lc.v0, "curvo": Lc.curved, "prima": bool(spec.get("first", false))})


func detectShot() -> void:
	var b := ball
	var s := b.physCopy()
	var dt: float = 1.0 / 60.0
	for i in 200:
		var py: float = s.y
		var px: float = s.x
		var ph: float = s.h
		C.ballPhys(s, dt, roll)
		if absf(s.y) >= HL:
			var f: float = (HL - absf(py)) / C.orf(absf(s.y) - absf(py), 1e-6)
			var cx: float = px + (s.x - px) * f
			var ch: float = ph + (s.h - ph) * f
			var defT: int = 1 if s.y > 0.0 else 0
			if absf(cx) < GW / 2.0 + 1.6 and ch < GH + 1.3 and C.hyp(s.vx, s.vy) > 5.0:
				var g := gk(defT)
				var sh := R.Shot.new()
				sh.team = 1 - defT
				sh.cx = cx
				sh.ch = ch
				sh.tc = i * dt
				sh.on = absf(cx) < GW / 2.0 and ch < GH
				sh.gx0 = g.x
				if paraCtl:
					paraMark(sh) # bersaglio sulla porta (parata.gd)
				b.shot = sh
				g.reactT = maxf(0.06, GK_REACT - g.st.por * 0.0026) * (1.25 - 0.35 * float(teams[defT].skill))
				g.decided = false
			return
		if absf(s.x) > HW + 2.0:
			return


# ------------------------------------------------------------ palla
func updateBall(dt: float) -> void:
	var b := ball
	if b.noT > 0.0:
		b.noT -= dt
	if b.owner != null:
		if phase == "restart" and restart.posato: # scena della ripresa: pallone a terra (da raccogliere o appoggiato)
			b.vx = 0.0
			b.vy = 0.0
			b.vh = 0.0
			b.h = 0.0
			return
		var o := b.owner
		b.x = o.x + o.fx * 0.6
		b.y = o.y + o.fy * 0.6
		b.h = 0.0
		b.vx = o.vx
		b.vy = o.vy
		b.vh = 0.0
		if phase == "play" and (absf(b.x) > HW or absf(b.y) > HL):
			out(b.x, b.y, 0.0)
		return
	# un altro ha toccato il pallone dopo il calcio da fermo: il battitore torna libero (anche dopo DBL_FREE s, per sicurezza)
	if b.dbl != null:
		var freed: bool = b.last != b.dbl
		if not freed and phase == "play":
			b.dblT += dt
			freed = b.dblT >= DBL_FREE
		if freed:
			b.dbl = null
	var px: float = b.x
	var py: float = b.y
	var ph: float = b.h
	C.ballPhys(b, dt, roll)
	if phase != "play":
		if phase == "goal":
			b.vx *= 0.92
			b.vy *= 0.9
			b.x = C.clamp_(b.x, -GW / 2.0 + 0.2, GW / 2.0 - 0.2)
			b.y = C.clamp_(b.y, -HL - 1.9, HL + 1.9)
		elif phase == "restart" and restart.scena != "":
			sceneBall(dt)
		return
	if b.shot != null and b.kick != null and b.kick.age > b.shot.tc + 0.35:
		b.shot = null
	if absf(b.y) > HL:
		var f: float = (HL - absf(py)) / C.orf(absf(b.y) - absf(py), 1e-6)
		var cx: float = px + (b.x - px) * f
		var ch: float = ph + (b.h - ph) * f
		if ch < GH + 0.13 and absf(absf(cx) - GW / 2.0) < 0.13:
			b.y = C.sign_(b.y) * (HL - 0.05)
			b.vy = -b.vy * 0.5
			b.vx += C.sign_(cx) * (3.0 if absf(cx) > GW / 2.0 else -3.0)
			b.ct = 0.0
			b.shot = null
			predT = 0.0
			ev("post")
			return
		if absf(cx) < GW / 2.0 and absf(ch - GH) < 0.13:
			b.y = C.sign_(b.y) * (HL - 0.05)
			b.vy = -b.vy * 0.45
			b.vh = -absf(b.vh) * 0.4 - 1.0
			b.ct = 0.0
			b.shot = null
			predT = 0.0
			ev("post")
			return
		out(cx, b.y, ch)
	elif absf(b.x) > HW:
		out(b.x, b.y, b.h)


func out(x: float, y: float, h: float) -> void:
	var b := ball
	var lt: int = b.last.team if b.last != null else 0
	if absf(y) > HL:
		var defT: int = 1 if y > 0.0 else 0
		if absf(x) < GW / 2.0 and h < GH:
			goal(1 - defT)
			return
		ev("out", {"kind": "corner" if lt == defT else "goalkick"})
		if lt == defT:
			restartFromOut("corner", 1 - defT, x, y)
		else:
			restartFromOut("goalkick", defT, x, y)
	else:
		ev("out", {"kind": "throw"})
		restartFromOut("throw", 1 - lt, C.sign_(x) * HW, y)


# ripresa dopo un'uscita: con l'opzione "riprese" diventa una scena (il battitore va a prendere il pallone, riprese.gd)
func restartFromOut(type: String, tm: int, x: float, y: float) -> void:
	if not sceneWanted(type):
		setRestart(type, tm, x, y)
		return
	var snap := sceneSnap()
	sceneNoCut = true
	setRestart(type, tm, x, y)
	sceneNoCut = false
	sceneStart(snap)


func goal(forT: int) -> void:
	var b := ball
	score[forT] += 1
	var s := b.last
	var og: bool = s == null or s.team != forT
	var scorer: R.Player = null if og else s
	var assist: R.Player = null
	if scorer != null and lastPass != null and lastPass.to == scorer and lastPass.from != scorer:
		assist = lastPass.from
	if og and b.prev != null and b.prev.team == forT:
		scorer = b.prev
	var mnt: int = mini(90, int(floor((half - 1) * 45 + t / halfLen * 45.0)) + 1)
	goalsLog.append({"team": forT, "name": scorer.name if scorer != null else "Autogol", "minute": mnt, "scorer": scorer.src if scorer != null else null, "assist": assist.src if assist != null else null})
	endDuel("gioco fermo")
	endFlee("gioco fermo")
	endHead("gioco fermo")
	advantage = null
	phase = "goal"
	goalT = 3.2
	nextKick = 1 - forT
	b.owner = null
	b.shot = null
	b.kick = null
	b.ct = 0.0
	for p: R.Player in players:
		if not p.off:
			p.cele = 1 if p.team == forT else -1
			if p.state != "play":
				p.state = "play"
				p.dive = null
	ev("goal", {"team": forT, "scorer": scorer, "assist": assist, "og": og and scorer == null, "minute": mnt})


# ------------------------------------------------------------ ciclo
func step(dt: float) -> void:
	var b := ball
	time += dt
	if phase == "full" or phase == "half":
		return
	for tm in 2:
		var m: R.Move = move[tm]
		if m != null:
			m.ttl -= dt
			if m.ttl <= 0.0:
				move[tm] = null
		switchCd[tm] -= dt
	if phase == "goal":
		goalT -= dt
		for p: R.Player in players:
			p.tx = p.x
			p.ty = p.y
		movePlayers(dt)
		updateBall(dt)
		if goalT <= 0.0:
			setupKickoff(nextKick)
		return
	think(dt)
	movePlayers(dt)
	updateBall(dt)
	updateDuel(dt)
	if dribShow != null:
		dribShowStep(dt) # giochetto del dribbling prenotato (solo con "rifiniture")
	updateFlee(dt)
	updateCalm(dt)
	updateHead(dt)
	updatePara(dt)
	if falliOn:
		falliStep(dt) # rigore in sospeso dopo un fallo in ritardo sul tiro (falli.gd)
	if phase == "play":
		contacts(dt)
		if phase == "play":
			checkAdvantage(dt)
		if phase == "play":
			t += dt
			if att >= 0:
				stats.poss[att] += dt
			if t >= halfLen and b.shot == null:
				endHalf()
	elif phase == "restart":
		var r := restart
		if r.scena != "":
			sceneStep(dt)
		elif r.pend != null:
			r.st += dt
			if runupDone(): # rincorsa finita: parte il calcio chiesto
				var spec: Dictionary = r.pend
				r.pend = null
				r.rinc = false
				faceTo(r.taker, float(spec.tx), float(spec.ty))
				kick(r.taker, spec)
		else:
			r.t += dt
			if (r.t >= r.wait) if not human[r.team] else (r.t > 14.0):
				aiRestart()
	if riprese:
		raccattaStep(dt) # raccattapalle (raccatta.gd): fuori dal campo, anche a scena finita torna al posto
	fireQueued()
	updateCtrl(dt)


# ------------------------------------------------------------ vantaggio
# Fallo su `on`: si lascia correre se la sua squadra ha ancora il pallone fuori dalla propria metà e nessun altro avversario addosso.
func advantageOk(on: R.Player, by: R.Player) -> bool:
	var b := ball
	var dir: float = -1.0 if on.team else 1.0
	if b.owner != on or on.y * dir < ADV_MIN_Y:
		return false
	for o: R.Player in players:
		if o.team != on.team and o != by and not o.off and C.hyp(o.x - on.x, o.y - on.y) < ADV_FREE:
			return false
	return true


func checkAdvantage(dt: float) -> void:
	var a := advantage
	if a == null:
		return
	var o := ball.owner
	if o != null and o.team != a.team:
		advantage = null
		ev("advantage_back", {"team": a.team})
		setRestart("freekick", a.team, a.x, a.y)
		return
	a.t -= dt
	if a.t <= 0.0:
		advantage = null
		ev("advantage_over", {"team": a.team})


# un tiro della squadra che ha il vantaggio lo chiude: il vantaggio è stato sfruttato
func useAdvantage(tm: int) -> void:
	if advantage != null and advantage.team == tm:
		advantage = null
		ev("advantage_over", {"team": tm})


func endHalf() -> void:
	endDuel("gioco fermo")
	endFlee("gioco fermo")
	resetStates()
	ball.shot = null
	if half == 1:
		phase = "half"
		ev("half")
	else:
		phase = "full"
		ev("full")


func startSecondHalf() -> void:
	if phase != "half":
		return
	half = 2
	t = 0.0
	setupKickoff(1 - kickoffTeam)


func minute() -> int:
	return mini(45 if half == 1 else 90, int(floor((half - 1) * 45 + t / halfLen * 45.0)))


func _nearestCtrl(tm: int) -> R.Player:
	var b := ball
	var n: R.Player = null
	var bd: float = 1e9
	for p: R.Player in players:
		if p.team == tm and not p.off and p.pos != "P":
			var d: float = C.hyp(p.x - b.x, p.y - b.y) + (6.0 if p.state != "play" else 0.0)
			if d < bd:
				bd = d
				n = p
	return n


func updateCtrl(_dt: float, force: bool = false) -> void:
	var b := ball
	for tm in 2:
		if not human[tm]:
			ctrl[tm] = null
			continue
		var c: R.Player = ctrl[tm]
		if c != null and c.off:
			c = null
		if b.owner != null and b.owner.team == tm:
			c = b.owner
		elif headWin != null and headWin.team == tm:
			c = headWin.p # colpo di testa controllato: comanda chi deve colpire
		elif phase == "restart" or phase == "goal":
			if c == null or c.pos == "P" or force:
				c = _nearestCtrl(tm)
		elif b.owner == null:
			var ch: R.Chase = chase[tm]
			if ch != null and ch.p2 != null and (switchCd[tm] <= 0.0 or c == null or c.pos == "P") and c != ch.p2:
				c = ch.p2
				switchCd[tm] = 0.6
			if c == null or c.pos == "P":
				c = _nearestCtrl(tm)
		else:
			var n := _nearestCtrl(tm)
			if c == null or c.pos == "P":
				c = n
			elif n != null and n != c and switchCd[tm] <= 0.0 and C.hyp(c.x - b.x, c.y - b.y) - C.hyp(n.x - b.x, n.y - b.y) > 3.5:
				c = n
				switchCd[tm] = 0.8
		if c != ctrl[tm]:
			ctrl[tm] = c
			var m: R.Move = move[tm]
			if m != null and not m.held:
				move[tm] = null


# ------------------------------------------------------------ comandi umani
func userKick(tm: int, spec: Dictionary) -> bool:
	var p: R.Player = ctrl[tm]
	var b := ball
	if p == null or b.owner != p or p.stun > 0.0:
		return false
	if phase == "restart":
		if restart.taker != p or restart.t < 0.35 or restart.scena != "" or restart.pend != null:
			return false
	elif phase != "play":
		return false
	spec.human = true
	move[tm] = null
	kick(p, spec)
	return true


# Di prima: mentre un passaggio della squadra tm viaggia, la persona prepara il calcio successivo (spec, come userKick)
# per il compagno p. Appena p controlla il pallone lo calcia subito, senza stop (fireQueued, a ogni passo).
# Il calcio in attesa si annulla se il pallone lo prende un altro, cambia volo (deviazione, colpo di testa) o il gioco si ferma.
func userQueue(tm: int, p: R.Player, spec: Dictionary) -> bool:
	var b := ball
	var k := b.kick
	if phase != "play" or not human[tm] or p == null or p.team != tm or p.off or b.owner != null:
		return false
	if k == null or k.team != tm or k.type == "shot" or k.kicker == p:
		return false
	queued[tm] = {"p": p, "spec": spec, "kick": k}
	return true


func fireQueued() -> void:
	var b := ball
	for tm in 2:
		var q: Variant = queued[tm]
		if q == null:
			continue
		if phase != "play":
			queued[tm] = null
		elif b.owner == q.p:
			queued[tm] = null
			var spec: Dictionary = q.spec.duplicate()
			spec.human = true
			spec.first = true
			ctrl[tm] = q.p
			move[tm] = null
			kick(q.p, spec)
		elif b.owner != null or b.kick != q.kick:
			queued[tm] = null


# punti della linea disegnata, nel campo e a distanza PATH_STEP l'uno dall'altro; l'ultimo punto c'è sempre
func _cleanPath(pts: Array) -> Array:
	var path: Array = []
	for q: Dictionary in pts:
		var x: float = C.clamp_(q.x, -HW + 0.5, HW - 0.5)
		var y: float = C.clamp_(q.y, -HL + 0.5, HL - 0.5)
		if path.is_empty() or C.hyp(x - path[-1].x, y - path[-1].y) >= PATH_STEP:
			path.append({"x": x, "y": y})
	var e: Dictionary = pts[-1]
	var ex: float = C.clamp_(e.x, -HW + 0.5, HW - 0.5)
	var ey: float = C.clamp_(e.y, -HL + 0.5, HL - 0.5)
	if not path.is_empty() and (path[-1].x != ex or path[-1].y != ey):
		path.append({"x": ex, "y": ey})
	return path


# corsa lungo una strada disegnata dal giocatore col pallone: pts = [{x, y}, ...] in metri.
# Il portatore segue i punti uno dopo l'altro; scatta finché davanti ha ancora più di PATH_SPRINT metri di strada.
func userPath(tm: int, pts: Array) -> bool:
	var c: R.Player = ctrl[tm]
	if c == null or ball.owner != c or pts.size() < 1:
		return false
	var path := _cleanPath(pts)
	if path.is_empty():
		return false
	var mv := R.Move.new()
	mv.x = path[0].x
	mv.y = path[0].y
	mv.ttl = PATH_TTL
	mv.path = path
	mv.i = 0
	mv.owner = c
	move[tm] = mv
	return true


# lunghezza della strada che resta da (p.x, p.y) passando per path[i], path[i+1], ...
func _pathLeft(p: R.Player, path: Array, i: int) -> float:
	var q: Dictionary = path[i]
	var left: float = C.hyp(q.x - p.x, q.y - p.y)
	for k in range(i + 1, path.size()):
		left += C.hyp(path[k].x - path[k - 1].x, path[k].y - path[k - 1].y)
	return left


# chiamata da assign(): avanza lungo la strada e aggiorna il punto da raggiungere
func followPath(p: R.Player, mv: R.Move) -> void:
	var tm := p.team
	if ball.owner != mv.owner or p != mv.owner:
		move[tm] = null
		return
	var path: Array = mv.path
	while mv.i < path.size() - 1 and C.hyp(path[mv.i].x - p.x, path[mv.i].y - p.y) < PATH_REACH:
		mv.i += 1
	var a: Dictionary = path[lookAhead(path, mv.i, p.x, p.y)]
	mv.x = a.x
	mv.y = a.y
	var left := _pathLeft(p, path, mv.i)
	mv.sprint = left > PATH_SPRINT
	if mv.i == path.size() - 1 and left < PATH_REACH:
		move[tm] = null


# Difesa: linea disegnata da un proprio giocatore senza palla, che corre lungo quella strada.
# Tutti i giocatori di movimento possono avere la loro linea (il portiere no); una nuova linea dello stesso giocatore sostituisce la sua.
func userRun(tm: int, p: R.Player, pts: Array) -> bool:
	if p == null or p.team != tm or p.off or p.pos == "P" or ball.owner == p or phase != "play" or pts.is_empty():
		return false
	pts = clipLen(p.x, p.y, pts, RUN_MAX_LEN)
	var path := _cleanPath(pts)
	if path.is_empty():
		return false
	var rs: Array = runs[tm].filter(func(r: R.Run) -> bool: return r.p != p)
	var run := R.Run.new()
	run.p = p
	run.path = path
	run.i = 0
	run.ttl = PATH_TTL
	rs.append(run)
	runs[tm] = rs
	return true


# chiamata da assign(): punto da raggiungere lungo la linea; false quando la linea è finita o non vale più
func followRun(p: R.Player, r: R.Run) -> bool:
	var b := ball
	if (b.owner != null and b.owner.team == p.team) or p.state != "play":
		runs[p.team] = runs[p.team].filter(func(q: R.Run) -> bool: return q != r)
		return false
	r.ttl -= dtT
	while r.i < r.path.size() - 1 and C.hyp(r.path[r.i].x - p.x, r.path[r.i].y - p.y) < PATH_REACH:
		r.i += 1
	var q: Dictionary = r.path[r.i]
	if r.ttl <= 0.0 or (r.i == r.path.size() - 1 and C.hyp(q.x - p.x, q.y - p.y) < RUN_END_REACH):
		runs[p.team] = runs[p.team].filter(func(z: R.Run) -> bool: return z != r)
		runEnded(p)
		return false
	var a: Dictionary = r.path[lookAhead(r.path, r.i, p.x, p.y)]
	p.tx = a.x
	p.ty = a.y
	p.sprint = _pathLeft(p, r.path, r.i) > PATH_SPRINT
	return true


# sprint: true/false dal telefono; se manca (null), scatto quando il dito tenuto premuto è lontano dal giocatore controllato
func userMove(tm: int, x: float, y: float, held: bool = false, sprint: Variant = null) -> void:
	var spr: bool
	if sprint == null:
		var c: R.Player = ctrl[tm]
		spr = held and c != null and C.hyp(x - c.x, y - c.y) > SPRINT_DIST
	else:
		spr = bool(sprint)
	var mv := R.Move.new()
	mv.x = C.clamp_(x, -HW - 1.0, HW + 1.0)
	mv.y = C.clamp_(y, -HL - 1.0, HL + 1.0)
	mv.ttl = 0.3 if held else 1.8
	mv.held = held
	mv.sprint = held and spr
	move[tm] = mv


func userStop(tm: int) -> void:
	move[tm] = null


func userSlide(tm: int, dx: float, dy: float) -> bool:
	var p: R.Player = ctrl[tm]
	var b := ball
	if p == null or phase != "play" or p.state != "play" or p.stun > 0.0 or p.pos == "P":
		return false
	if b.owner != null and b.owner.team == tm:
		return false
	var n: float = C.hyp(dx, dy)
	if n < 1e-6:
		return false
	p.state = "slide"
	p.t = 0.0
	p.sdx = dx / n
	p.sdy = dy / n
	p.hit = false
	p.fx = p.sdx
	p.fy = p.sdy
	move[tm] = null
	ev("slide", {"p": p})
	return true


# diveWin e userDive stanno in parata.gd (con l'opzione "parata": fermatempo e bersaglio)


func userSwitch(tm: int, p: R.Player) -> bool:
	var b := ball
	if p == null or p.team != tm or p.off or p.pos == "P" or (b.owner != null and b.owner.team == tm) or phase != "play":
		return false
	ctrl[tm] = p
	switchCd[tm] = 2.0
	move[tm] = null
	return true


# dribbling nel duello aperto per la squadra T (tasto in basso). Ritorna true se il dribbling è stato prenotato:
# il portatore corre verso il difensore dal lato scelto (evento 'dribble_book' {p, o, side}) e il dribbling vero
# parte quando gli arriva vicino (duel.gd → dribBookStep); l'esito arriva con l'evento 'dribble' {p, o, ok, side}.
# Se intanto il duello finisce (palla persa, difensore lontano, passaggio) la prenotazione si annulla con lui.
func userDribble(tm: int) -> bool:
	var d := duel
	if d == null or d.team != tm or phase != "play" or d.side != 0.0:
		return false
	var p := d.p
	# niente attesa tra due tentativi (p.dribCd vale per l'IA): fra due duelli passa già DUEL_CD, e nel rallenty
	# l'attesa durava molti secondi veri col tasto in vista che non faceva nulla
	if ball.owner != p or p.stun > 0.0 or p.state != "play":
		return false
	d.side = dribSide(p, d.o)
	d.bt = 0.0
	ev("dribble_book", {"p": p, "o": d.o, "side": d.side})
	dribBookStep(d, 0.0) # già vicino: parte subito
	return true


# Scatto nella fuga aperta per la squadra T (avversario alla pari o dietro, tasto in basso). Ritorna true se è partito.
func userSprint(tm: int) -> bool:
	var f := flee
	if f == null or f.team != tm or phase != "play":
		return false
	var p := f.p
	if ball.owner != p or p.stun > 0.0 or p.state != "play":
		return false
	burst(p, f.o)
	endFlee("scatto")
	if portaAuto and rifiniture:
		fleeCd[tm] = BURST_FLEE_CD # dopo lo Scatto il portatore corre da solo, senza un'altra fuga appena ripreso
	return true


# Rallenty scaduto (Luis 2026-11-23): il gioco lo chiama quando il rallenty col pallone (duello, fuga, area di tiro) è
# durato RALLENTY_MAX_S secondi veri senza linea né tasto. Chiude duello e fuga della squadra T e per lo stesso
# portatore non li riapre per CALM_CD s di partita; se è nell'area di tiro, quella non rallenta più finché ha il
# pallone. Il portatore continua da solo (portaAuto). Ritorna true se ha fatto qualcosa.
func userCalm(tm: int) -> bool:
	var c := ball.owner
	if c == null or c.team != tm or not human[tm] or phase != "play":
		return false
	if dribBooked(tm):
		return false # dribbling prenotato: il tempo è già normale
	if duelFor(tm):
		endDuel("scaduto")
	if fleeFor(tm):
		endFlee("scaduto")
	calmP[tm] = c
	calmT[tm] = CALM_CD
	calmZone[tm] = zoneDist(c) <= ZONE_DIST
	ev("calm", {"p": c})
	return true


func hint(tm: int) -> String:
	var b := ball
	if phase == "restart":
		return "restart" if restart.team == tm and restart.scena == "" and restart.pend == null else "wait"
	if phase != "play":
		return ""
	if diveWin(tm):
		return "dive"
	# nel duello resta 'attack' (così l'input lascia disegnare il passaggio): per il duello c'è duelFor(T)
	if b.owner != null and b.owner.team == tm:
		return "attack"
	if b.owner != null:
		return "defend"
	return "loose"


func substitute(tm: int, idx: int, src: Dictionary) -> bool:
	var tl := team(tm)
	if idx < 0 or idx >= tl.size():
		return false
	var p: R.Player = tl[idx]
	if p.off:
		return false
	p.src = src
	p.name = String(src.get("name", ""))
	p.st = C.effStats(src, p.pos)
	p.energy = startEnergy(src)
	p.wear = {"dri": 1.0, "tes": 1.0}
	p.dribCd = 0.0
	p.yellow = 0
	p.look = lookFor(src)
	if duel != null and (duel.p == p or duel.o == p):
		endDuel("gioco fermo")
	if flee != null and (flee.p == p or flee.o == p):
		endFlee("gioco fermo")
	ev("sub", {"p": p})
	return true


# Fine partita: rompe i riferimenti circolari tra giocatori (supC, beatBy) che il conteggio dei riferimenti
# di Godot non libera da solo. Da chiamare quando la partita non serve più (in JS ci pensa il garbage collector).
func dispose() -> void:
	queued = [null, null]
	calmP = [null, null]
	cornerTaker = null
	cornerKick = null
	for p: R.Player in players:
		p.supC = null
		p.beatBy = null
		p.claim = null
