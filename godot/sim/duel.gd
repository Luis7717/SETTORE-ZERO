# Duello col difensore, dribbling, fuga con lo Scatto e calo delle statistiche per l'uso (porting di src/sim/duel.js).
extends "base.gd"

# Regolazioni (misurate con test/diag-flow.mjs e i test in test/unit/duel.test.mjs)
const DUEL_R := 7.0       # un avversario davanti più vicino di così al portatore apre il duello (m)
const DUEL_FRONT := 0.35  # "davanti": coseno minimo tra verso di corsa e direzione dell'avversario (~70°)
const DUEL_END_R := 9.5   # il duello si chiude ("lontano") se l'avversario si allontana oltre (m)
const DUEL_BEHIND := -0.2 # ... o se resta alle spalle (coseno sotto questo valore)
const DUEL_GUARD := 0.6   # per questo tempo di partita il difensore del duello non può rubare palla (s)
const DUEL_MAX := 2.5     # durata massima del duello (s)
const DUEL_CD := 1.0      # dopo la fine, lo stesso portatore non apre un nuovo duello per questo tempo (s)
const DRIB_BASE := 0.5    # probabilità di riuscita a pari dribbling e difesa
const DRIB_SKILL := 1.2   # quanto pesa la differenza dribbling - difesa (per punto / 100)
const DRIB_MIN := 0.15    # limiti della probabilità di riuscita
const DRIB_MAX := 0.85
const DRIB_STUN := 0.8    # dribbling riuscito: il difensore resta sbilanciato (fermo) per questo tempo da quando il portatore lo raggiunge (s)
const DRIB_REACH := 1.0   # ... "raggiunto" = portatore arrivato a questa distanza dal difensore (m)
const DRIB_BEAT := 1.2    # finito lo sbilanciamento, il difensore saltato resta ancora "saltato" per questo tempo (s;
                          # sbilanciato + saltato = 2 s, quanto il giochetto più lungo della grafica, l'arcobaleno):
const DRIB_BEAT_SPD := 0.5 # ... corre a questa frazione della velocità, non contrasta chi l'ha saltato e non gli riapre il duello
const DRIB_PROTECT := 0.35 # ... e il portatore non può essere contrastato da nessuno per questo tempo (s)
const DRIB_PAST := 3.0    # il portatore punta a questa distanza oltre il difensore (m)
const DRIB_SIDE := 2.5    # ... spostato di lato di tanto (m)
const DRIB_STEAL_R := 2.0 # dribbling fallito: entro questa distanza il difensore può prendere il pallone (m)
const DRIB_STEAL := 0.6   # ... e lo prende con questa probabilità (altrimenti lo devia)
const DRIB_CD := 1.2      # tempo tra due tentativi di dribbling dello stesso giocatore (s)
const AI_DRIB_R := 3.2    # l'IA tenta il dribbling solo con l'avversario davanti entro questa distanza (m)
const AI_DRIB_TRY := 0.22 # probabilità di tentare a pari dribbling e difesa (cresce col vantaggio)
const WEAR_DRI := 0.03    # ogni dribbling riuscito: -3% di dribbling, fino all'80%
const WEAR_DRI_MIN := 0.8
const ZONE_DIST := 20.0   # negli ultimi metri prima della porta avversaria: area di tiro (rallenty, si può passare)
const WEAR_TES := 0.02    # ogni colpo di testa vinto: -2% di colpi di testa, fino all'85%
const WEAR_TES_MIN := 0.85
# Davanti o dietro "per linee" (Luis 2026-11-21): si divide il campo in linee parallele alle linee di porta. L'avversario
# è davanti solo se sta su una linea più avanti (verso la porta avversaria) di almeno LEVEL_TOL; altrimenti è alla pari o
# dietro. Davanti = duello (Dribbling o passaggio disegnato); alla pari o dietro = fuga (Scatto o passaggio disegnato).
const LEVEL_TOL := 0.5    # "alla pari": fino a tanto più avanti del portatore conta ancora come stessa linea (m)
const FLEE_R := 4.0       # avversario alla pari o dietro più vicino di così al portatore apre la fuga (m)
const FLEE_END_R := 7.0   # la fuga si chiude se l'avversario si allontana oltre (m)
const FLEE_MAX := 2.5     # durata massima della fuga (s)
const FLEE_CD := 1.5      # dopo la fine, lo stesso portatore non apre una nuova fuga per questo tempo (s)
const BURST_T := 1.2      # Scatto: per questo tempo il portatore corre più veloce (s)
const BURST_SPD := 1.15   # ... di questo fattore (sopra lo scatto normale)
const BURST_SHAKE := 0.6  # ... e l'avversario resta indietro: corre piano e non lo contrasta per questo tempo (s)
const BURST_RUN := 14.0   # ... poi il portatore prosegue dritto fino a questa distanza (m)


func duelFor(tm: int) -> bool:
	return duel != null and duel.team == tm


# area di tiro: il portatore controllato della squadra umana T è negli ultimi ZONE_DIST m prima della porta avversaria
func inZone(tm: int) -> bool:
	var c := ball.owner
	if c == null or c.team != tm or not human[tm] or ctrl[tm] != c or phase != "play" or c.state != "play":
		return false
	return (HL - c.y if tm == 0 else c.y + HL) <= ZONE_DIST


# si può passare (duello col difensore, fuga o area di tiro)
func passFor(tm: int) -> bool:
	return duelFor(tm) or fleeFor(tm) or inZone(tm)


# il difensore del duello non può ancora rubare palla
func duelGuard(o: R.Player) -> bool:
	var d := duel
	return d != null and d.o == o and d.t < DUEL_GUARD


# o è stato saltato col dribbling da c e non si è ancora ripreso: non può contrastarlo né riaprirgli il duello
func beaten(o: R.Player, c: R.Player) -> bool:
	return o.beat > 0.0 and o.beatBy == c


# verso di corsa del portatore (fermo: verso cui guarda)
func runDir(c: R.Player) -> PackedFloat64Array:
	var v: float = C.hyp(c.vx, c.vy)
	return PackedFloat64Array([c.vx / v, c.vy / v]) if v > 1.5 else PackedFloat64Array([c.fx, c.fy])


func frontDot(c: R.Player, o: R.Player) -> float:
	var rd := runDir(c)
	var dx: float = o.x - c.x
	var dy: float = o.y - c.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	return (dx * rd[0] + dy * rd[1]) / d


# o sta su una linea più avanti di c (verso la porta che attacca c) di almeno LEVEL_TOL
func aheadLine(c: R.Player, o: R.Player) -> bool:
	return (o.y - c.y) * (1.0 if c.team == 0 else -1.0) > LEVEL_TOL


# avversario più vicino davanti al portatore entro `Rr` (lines: anche più avanti "per linee", per il duello della persona)
func frontOpp(c: R.Player, Rr: float, lines: bool = false) -> R.Player:
	var best: R.Player = null
	var bd: float = Rr
	for o: R.Player in players:
		if o.team == c.team or o.off or o.stun > 0.0 or beaten(o, c) or (o.state != "play" and o.state != "prep"):
			continue
		var d: float = C.hyp(o.x - c.x, o.y - c.y)
		if d < bd and frontDot(c, o) > DUEL_FRONT and (not lines or aheadLine(c, o)):
			bd = d
			best = o
	return best


# apre e chiude il duello del portatore della squadra umana (chiamato a ogni passo prima dei contrasti)
func updateDuel(dt: float) -> void:
	for tm in 2:
		if duelCd[tm] > 0.0:
			duelCd[tm] -= dt
	var b := ball
	var d := duel
	if d != null:
		d.t += dt
		var why := ""
		if phase != "play":
			why = "gioco fermo"
		elif b.owner != d.p:
			why = "passaggio" if (b.owner == null and b.kick != null and b.kick.kicker == d.p) else "palla persa"
		elif d.o.off or C.hyp(d.o.x - d.p.x, d.o.y - d.p.y) > DUEL_END_R or frontDot(d.p, d.o) < DUEL_BEHIND or not aheadLine(d.p, d.o):
			why = "lontano"
		elif d.t >= DUEL_MAX:
			why = "tempo"
		if why != "":
			endDuel(why)
		return
	if phase != "play":
		return
	var c := b.owner
	if c == null or not human[c.team] or ctrl[c.team] != c or c.state != "play":
		return
	if duelCd[c.team] > 0.0 and duelCdP[c.team] == c:
		return
	var o := frontOpp(c, DUEL_R, true)
	if o == null:
		return
	duel = R.Duel.new()
	duel.team = c.team
	duel.p = c
	duel.o = o
	duel.t = 0.0
	ev("duel_start", {"p": c, "o": o})


func endDuel(reason: String) -> void:
	var d := duel
	if d == null:
		return
	duel = null
	duelCd[d.team] = DUEL_CD
	duelCdP[d.team] = d.p
	ev("duel_end", {"p": d.p, "o": d.o, "reason": reason})


func fleeFor(tm: int) -> bool:
	return flee != null and flee.team == tm


# avversario più vicino alla pari o dietro il portatore (per linee) entro `Rr`
func sideOpp(c: R.Player, Rr: float) -> R.Player:
	var best: R.Player = null
	var bd: float = Rr
	for o: R.Player in players:
		if o.team == c.team or o.off or o.stun > 0.0 or beaten(o, c) or o.state != "play":
			continue
		var d: float = C.hyp(o.x - c.x, o.y - c.y)
		if d < bd and not aheadLine(c, o):
			bd = d
			best = o
	return best


# apre e chiude la fuga del portatore della squadra umana (dopo updateDuel: il duello ha la precedenza)
func updateFlee(dt: float) -> void:
	for tm in 2:
		if fleeCd[tm] > 0.0:
			fleeCd[tm] -= dt
	var b := ball
	var f := flee
	if f != null:
		f.t += dt
		var why := ""
		if phase != "play":
			why = "gioco fermo"
		elif b.owner != f.p:
			why = "passaggio" if (b.owner == null and b.kick != null and b.kick.kicker == f.p) else "palla persa"
		elif duel != null:
			why = "duello"
		elif f.o.off or f.o.stun > 0.0 or C.hyp(f.o.x - f.p.x, f.o.y - f.p.y) > FLEE_END_R or aheadLine(f.p, f.o):
			why = "lontano"
		elif f.t >= FLEE_MAX:
			why = "tempo"
		if why != "":
			endFlee(why)
		return
	if phase != "play" or duel != null:
		return
	var c := b.owner
	if c == null or not human[c.team] or ctrl[c.team] != c or c.state != "play" or c.burst > 0.0:
		return
	if fleeCd[c.team] > 0.0 and fleeCdP[c.team] == c:
		return
	var o := sideOpp(c, FLEE_R)
	if o == null:
		return
	flee = R.Duel.new()
	flee.team = c.team
	flee.p = c
	flee.o = o
	flee.t = 0.0
	ev("flee_start", {"p": c, "o": o})


func endFlee(reason: String) -> void:
	var f := flee
	if f == null:
		return
	flee = null
	fleeCd[f.team] = FLEE_CD
	fleeCdP[f.team] = f.p
	ev("flee_end", {"p": f.p, "o": f.o, "reason": reason})


# Scatto: il portatore si stacca dall'avversario e prosegue dritto nel verso di corsa
func burst(p: R.Player, o: R.Player) -> void:
	var tm := p.team
	var rd := runDir(p)
	var rx: float = rd[0]
	var ry: float = rd[1]
	var tx: float = C.clamp_(p.x + rx * BURST_RUN, -HW + 1.0, HW - 1.0)
	var ty: float = C.clamp_(p.y + ry * BURST_RUN, -HL + 1.0, HL - 1.0)
	var sp: float = vmax(p)
	p.burst = BURST_T
	p.fx = rx
	p.fy = ry
	if p.vx * rx + p.vy * ry < sp: # parte subito, senza la rincorsa
		p.vx = rx * sp
		p.vy = ry * sp
	if o != null and o.state == "play":
		o.beat = maxf(o.beat, BURST_SHAKE)
		o.beatBy = p
	if human[tm] and ctrl[tm] == p:
		var mv := R.Move.new()
		mv.x = tx
		mv.y = ty
		mv.ttl = BURST_T + 1.0
		mv.held = false
		mv.sprint = true
		move[tm] = mv
	ev("burst", {"p": p, "o": o})


func dribbleChance(p: R.Player, o: R.Player) -> float:
	return C.clamp_(DRIB_BASE + DRIB_SKILL * (p.st.dri - o.st.dif) / 100.0, DRIB_MIN, DRIB_MAX)


# Tentativo di dribbling del portatore p contro o (stessa regola per umano e IA). Ritorna true se riesce.
func dribble(p: R.Player, o: R.Player) -> bool:
	var b := ball
	var tm := p.team
	var ok: bool = rnd() < dribbleChance(p, o)
	p.dribCd = DRIB_CD
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	var ux: float = dx / d
	var uy: float = dy / d
	if ok:
		# di lato verso il centro se si è vicini alla linea laterale, altrimenti a caso
		var side: float
		if absf(p.x) > HW - 8.0:
			side = -C.sign_(p.x) * C.sign_(C.orf(uy, 1.0))
		else:
			side = -1.0 if rnd() < 0.5 else 1.0
		var nx: float = -uy * side
		var ny: float = ux * side
		var tx: float = C.clamp_(p.x + ux * (d + DRIB_PAST) + nx * DRIB_SIDE, -HW + 1.0, HW - 1.0)
		var ty: float = C.clamp_(p.y + uy * (d + DRIB_PAST) + ny * DRIB_SIDE, -HL + 1.0, HL - 1.0)
		var wx: float = tx - p.x
		var wy: float = ty - p.y
		var wn: float = C.orf(C.hyp(wx, wy), 1.0)
		var sp: float = vmax(p) * 1.05
		p.vx = wx / wn * sp
		p.vy = wy / wn * sp
		p.fx = wx / wn
		p.fy = wy / wn
		p.tx = tx
		p.dx = tx
		p.ty = ty
		p.dy = ty
		p.aiT = maxf(p.aiT, 0.35)
		p.protect = maxf(p.protect, DRIB_PROTECT)
		# il tasto si può toccare appena si apre il duello (difensore a 7 m): lo sbilanciamento conta da quando il portatore
		# arriva addosso al difensore, altrimenti finiva prima e il difensore, ancora davanti, gli si attaccava addosso
		o.stun = DRIB_STUN + maxf(0.0, d - DRIB_REACH) / sp
		o.contact = 0.0
		o.vx *= 0.3
		o.vy *= 0.3
		o.beat = o.stun + DRIB_BEAT
		o.beatBy = p
		if o.state == "prep":
			o.state = "play"
			o.warn = false
		wearDown(p, "dri", WEAR_DRI, WEAR_DRI_MIN)
		if human[tm] and ctrl[tm] == p:
			var mv := R.Move.new()
			mv.x = tx
			mv.y = ty
			mv.ttl = maxf(0.6, wn / sp + 0.15) # la corsa dura finché il portatore non arriva oltre il difensore
			move[tm] = mv
	else:
		p.stun = maxf(p.stun, 0.35)
		p.tackleCd = 0.6
		if human[tm] and ctrl[tm] == p:
			move[tm] = null
		if d < DRIB_STEAL_R and rnd() < DRIB_STEAL:
			b.owner = o
			b.prev = b.last
			b.last = o
			b.kick = null
			lastPass = null
			o.protect = 0.5
			o.contact = 0.0
			o.aiT = 0.25
			o.dx = o.x
			o.dy = o.y
			o.holdN = 0
			ev("tackle", {"p": o, "on": p, "dribble": true})
		else:
			# deviato: il pallone schizza verso il difensore, un po' di lato
			var a: float = F.atan2_(uy, ux) + (rnd() - 0.5) * 1.4
			var v: float = 5.0 + rnd() * 3.0
			b.owner = null
			b.vx = F.cos_(a) * v
			b.vy = F.sin_(a) * v
			b.vh = 0.8
			b.h = 0.05
			b.ct = 0.0
			b.kick = null
			b.shot = null
			b.noP = p
			b.noT = 0.4
			lastPass = null
			predT = 0.0
	ev("dribble", {"p": p, "o": o, "ok": ok})
	if duel != null and duel.p == p:
		endDuel("dribbling" if ok else "palla persa")
	return ok


# l'IA (e l'umano simulato) col pallone e un avversario davanti a volte prova il dribbling
func aiDribble(p: R.Player) -> bool:
	if p.dribCd > 0.0 or p.stun > 0.0:
		return false
	var o := frontOpp(p, AI_DRIB_R)
	if o == null:
		return false
	if rnd() >= C.clamp_(AI_DRIB_TRY + (p.st.dri - o.st.dif) / 100.0, 0.05, 0.6):
		return false
	dribble(p, o)
	return true


# calo per l'uso di una statistica dentro la partita (p.wear[key] da 1 fino a `mn`); torna pieno alla partita dopo
func wearDown(p: R.Player, key: String, step_: float, mn: float) -> void:
	var old: float = p.wear[key]
	var nw: float = maxf(mn, old - step_)
	if nw >= old:
		return
	p.st.set(key, float(p.st.get(key)) * (nw / old))
	p.wear[key] = nw
