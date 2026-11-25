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
const DRIB_WIDE := 1.5    # ... ma di più se serve per passare accanto al difensore ad almeno tanto di lato (m; da vicino
                          # la linea dritta verso il punto oltre gli passava addosso)
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
const BURST_FWD_MIN := 0.5 # con portaAuto e rifiniture: corsa meno in avanti di così (coseno) = lo Scatto va in avanti in diagonale ...
const BURST_SIDE := 0.6    # ... con tanto di lato per metro in avanti (~31°), lontano dall'avversario
# Dopo lo Scatto (Luis 2026-11-23: "dopo lo scatto il giocatore si blocca"): con portaAuto e rifiniture la corsa dritta
# dura quanto lo scatto (non BURST_T + 1 s fino a fermarsi sulla meta), poi il portatore torna subito alla guida
# automatica secondo lo stile; e la fuga non si riapre per BURST_FLEE_CD s di partita (prima tornava dopo FLEE_CD,
# quando il portatore fermo sulla meta veniva ripreso, e il rallenty lo lasciava lì).
const BURST_FLEE_CD := 3.5
const DRIB_CARRY := 6.0   # dopo il giochetto (portaAuto) la corsa punta così più avanti, per non frenare (m)
# Rallenty scaduto (userCalm: il gioco lo chiama dopo 10 s veri senza linea né tasto): per lo stesso portatore duello e
# fuga non si riaprono per tanto tempo di partita (s); l'area di tiro, se è scaduta lì, finché non perde il pallone.
const CALM_CD := 4.0
# Dribbling prenotato (Luis 2026-11-21: "il dribbling lo deve fare vicino all'avversario"): il tasto non decide subito,
# il portatore corre verso il difensore puntando il lato scelto e il dribbling vero scatta solo quando gli arriva vicino.
const DRIB_NEAR := 2.0    # il dribbling prenotato scatta quando il portatore arriva a questa distanza dal difensore (m)
const DRIB_BOOK_MAX := 1.2 # ... o comunque dopo questo tempo di partita dal tocco, anche se non si è avvicinato (s)
const DRIB_AIM := 1.2     # ... intanto corre verso il difensore puntando un punto spostato di tanto dal lato scelto (m)
const SIDE_LEAN := 1.5    # scelta del lato: peso dello sbilanciamento del difensore rispetto alla linea di corsa (per m)
const SIDE_LEAN_T := 0.3  # ... in cui conta anche dove sta andando il difensore (velocità di lato per questo tempo, s)
const SIDE_FREE := 0.25   # ... peso dello spazio libero da altri avversari oltre il difensore (per m)
const SIDE_FREE_MAX := 8.0 # ... spazio contato fino a tanto (m)
const SIDE_EDGE := 8.0    # ... entro tanto dalla linea laterale si va sempre verso il centro (m)
# Giochetto del dribbling prenotato riuscito (Luis 2026-11-24: "falli vedere bene"), solo con "rifiniture" e solo per
# il tasto della persona: invece di partire subito di corsa oltre il difensore, il portatore rallenta col pallone al
# piede, sposta peso e pallone dal lato opposto (la finta: il difensore si sbilancia da quella parte) e dopo
# DRIB_SHOW_T cambia direzione e scatta dal lato scelto (la corsa di prima). L'esito è già deciso: stessa probabilità.
const DRIB_SHOW_T := 0.35   # durata del giochetto prima dello scatto (s di partita)
const DRIB_SHOW_V := 2.5    # ... il portatore va a questa velocità (m/s) ...
const DRIB_SHOW_DEC := 24.0 # ... frenando così (m/s²: da uno scatto pieno in ~0,25 s)
const DRIB_FEINT := 1.0     # ... di lato verso il lato opposto a quello scelto (la finta) ...
const DRIB_FEINT_FWD := 0.45 # ... e un po' in avanti, ma solo finché resta lontano dal difensore più di DRIB_SHOW_GAP
const DRIB_SHOW_GAP := 1.5  # (m: più vicino i due corpi a schermo si compenetrerebbero)
const DRIB_LEAN_V := 1.2    # il difensore si sbilancia verso la finta a questa velocità (m/s), poi resta fermo


func duelFor(tm: int) -> bool:
	return duel != null and duel.team == tm


# la squadra T ha toccato Dribbling e il portatore sta andando verso il difensore (il tasto non serve più)
func dribBooked(tm: int) -> bool:
	return duel != null and duel.team == tm and duel.side != 0.0


# area di tiro: il portatore controllato della squadra umana T è negli ultimi ZONE_DIST m prima della porta avversaria
func inZone(tm: int) -> bool:
	var c := ball.owner
	if c == null or c.team != tm or not human[tm] or ctrl[tm] != c or phase != "play" or c.state != "play":
		return false
	if calmZone[tm] and calmP[tm] == c:
		return false # rallenty dell'area di tiro scaduto per questo portatore (userCalm)
	return zoneDist(c) <= ZONE_DIST


# metri tra il portatore c e la linea della porta che attacca
func zoneDist(c: R.Player) -> float:
	return HL - c.y if c.team == 0 else c.y + HL


# rallenty scaduto per il portatore c (userCalm): duello e fuga non si riaprono ancora
func calmed(c: R.Player) -> bool:
	return calmP[c.team] == c and calmT[c.team] > 0.0


# passo del "rallenty scaduto": finisce quando il portatore perde il pallone (il tempo di CALM_CD scorre a parte)
func updateCalm(dt: float) -> void:
	for tm in 2:
		if calmP[tm] == null:
			continue
		calmT[tm] -= dt
		if ball.owner != calmP[tm]:
			calmP[tm] = null
			calmT[tm] = 0.0
			calmZone[tm] = false


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
		elif d.t >= DUEL_MAX and d.side == 0.0: # col dribbling prenotato decide DRIB_BOOK_MAX
			why = "tempo"
		if why != "":
			endDuel(why) # anche la prenotazione del dribbling finisce qui (palla persa, difensore lontano, ...)
		elif d.side != 0.0:
			dribBookStep(d, dt)
		return
	if phase != "play":
		return
	var c := b.owner
	if c == null or not human[c.team] or ctrl[c.team] != c or c.state != "play":
		return
	if duelCd[c.team] > 0.0 and duelCdP[c.team] == c:
		return
	if calmed(c) or (dribShow != null and dribShow.p == c):
		return # (giochetto del dribbling in corso: niente duello nuovo finché non è passato)
	var o := frontOpp(c, DUEL_R, true)
	if o == null:
		return
	duel = R.Duel.new()
	duel.team = c.team
	duel.p = c
	duel.o = o
	duel.t = 0.0
	duel.side = 0.0 # 0 = niente dribbling prenotato, ±1 = prenotato da quel lato (bt = tempo dal tocco)
	duel.bt = 0.0
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
	if (fleeCd[c.team] > 0.0 and fleeCdP[c.team] == c) or calmed(c) or (dribShow != null and dribShow.p == c):
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
	var rd := burstDir(p, o)
	var rx: float = rd[0]
	var ry: float = rd[1]
	var tx: float = C.clamp_(p.x + rx * BURST_RUN, -HW + 1.0, HW - 1.0)
	var ty: float = C.clamp_(p.y + ry * BURST_RUN, -HL + 1.0, HL - 1.0)
	var sp: float = vmax(p)
	var auto: bool = portaAuto and rifiniture and human[tm]
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
		mv.ttl = BURST_T if auto else BURST_T + 1.0 # portaAuto: finito lo scatto riprende subito la guida automatica
		mv.held = false
		mv.sprint = true
		move[tm] = mv
	if auto:
		p.aiT = 0.0 # la guida automatica, ripresa, sceglie subito una direzione nuova (non quella di prima dello scatto)
	ev("burst", {"p": p, "o": o})


# Verso dello Scatto: quello di corsa. Col portatore umano automatico (portaAuto, con "rifiniture") che protegge palla, si correva
# spesso di lato o all'indietro (1 Scatto su 4 verso la propria porta, controllo del gameplay 2026-11-23): lì si
# scatta in avanti in diagonale, lontano dall'avversario (verso il centro vicino alla linea laterale).
func burstDir(p: R.Player, o: R.Player) -> PackedFloat64Array:
	var rd := runDir(p)
	var dir: float = -1.0 if p.team else 1.0
	if not (portaAuto and rifiniture) or not human[p.team] or rd[1] * dir >= BURST_FWD_MIN:
		return rd
	var side: float = C.sign_(p.x - o.x) if (o != null and absf(p.x - o.x) > 0.3) else -C.sign_(p.x)
	if absf(p.x) > HW - SIDE_EDGE:
		side = -C.sign_(p.x)
	var bx: float = side * BURST_SIDE
	var n: float = C.hyp(bx, 1.0)
	return PackedFloat64Array([bx / n, dir / n])


# Lato del dribbling di p su o: +1 = alla sinistra di p (guardando il difensore), -1 = alla destra. Dalla parte opposta
# allo sbilanciamento del difensore rispetto alla linea di corsa, verso lo spazio libero da altri avversari, e verso il
# centro se si è vicini alla linea laterale. Niente numeri casuali: a parità vince la sinistra.
func dribSide(p: R.Player, o: R.Player) -> float:
	var rd := runDir(p)
	var rx: float = rd[0]
	var ry: float = rd[1]
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	var ux: float = dx / d
	var uy: float = dy / d
	# > 0: il difensore sta (o si sposta) a sinistra della linea di corsa del portatore
	var lean: float = (dx * -ry + dy * rx) + (o.vx * -ry + o.vy * rx) * SIDE_LEAN_T
	var best: float = 1.0
	var bs: float = -1e9
	for s: float in [1.0, -1.0]:
		var nx: float = -uy * s
		var ny: float = ux * s
		var qx: float = o.x + ux * DRIB_PAST + nx * DRIB_SIDE
		var qy: float = o.y + uy * DRIB_PAST + ny * DRIB_SIDE
		var free: float = SIDE_FREE_MAX
		for q: R.Player in players:
			if q.team != p.team and q != o and not q.off:
				free = minf(free, C.hyp(q.x - qx, q.y - qy))
		var sc: float = -s * lean * SIDE_LEAN + free * SIDE_FREE
		if absf(p.x) > HW - SIDE_EDGE and nx * p.x > 0.0:
			sc -= 100.0 # verso la linea laterale vicina: mai
		if sc > bs:
			bs = sc
			best = s
	return best


# dribbling prenotato dal tasto (d = duello con d.side scelto): il portatore corre verso il difensore puntando il lato
# scelto; arrivato a DRIB_NEAR (o passato DRIB_BOOK_MAX) parte il dribbling vero. Chiamato a ogni passo da updateDuel.
func dribBookStep(d: R.Duel, dt: float) -> void:
	var p := d.p
	var o := d.o
	var tm := d.team
	d.bt += dt
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var dist: float = C.hyp(dx, dy)
	if dist <= DRIB_NEAR or d.bt >= DRIB_BOOK_MAX:
		dribble(p, o, d.side)
		return
	var ux: float = dx / C.orf(dist, 1.0)
	var uy: float = dy / C.orf(dist, 1.0)
	var x: float = C.clamp_(o.x - uy * d.side * DRIB_AIM, -HW + 0.5, HW - 0.5)
	var y: float = C.clamp_(o.y + ux * d.side * DRIB_AIM, -HL + 0.5, HL - 0.5)
	if human[tm] and ctrl[tm] == p:
		var mv := R.Move.new()
		mv.x = x
		mv.y = y
		mv.ttl = 0.3
		mv.held = false
		mv.sprint = true
		move[tm] = mv


func dribbleChance(p: R.Player, o: R.Player) -> float:
	return C.clamp_(DRIB_BASE + DRIB_SKILL * (p.st.dri - o.st.dif) / 100.0, DRIB_MIN, DRIB_MAX)


# Tentativo di dribbling del portatore p contro o (stessa regola per umano e IA). Ritorna true se riesce.
# side_: lato già scelto (dribbling prenotato dal tasto), altrimenti lo sceglie dribSide.
func dribble(p: R.Player, o: R.Player, side_: float = 0.0) -> bool:
	var tm := p.team
	var side: float = side_
	var ok: bool = rnd() < dribbleChance(p, o)
	p.dribCd = DRIB_CD
	# dribbling prenotato dal tasto della persona, con "rifiniture": frena davanti al difensore (riuscito: giochetto e poi
	# scatto; fallito: non gli finisce addosso)
	var booked: bool = rifiniture and side_ != 0.0 and human[tm] and ctrl[tm] == p
	var show: bool = ok and booked
	if booked:
		dribBrake(p, o)
	if show:
		dribShowStart(p, o, side)
	elif ok:
		side = dribbleRun(p, o, side)
	else:
		dribbleLost(p, o)
	if ok:
		wearDown(p, "dri", WEAR_DRI, WEAR_DRI_MIN)
	# side va anche alla grafica: il giochetto va da quel lato (+1 = sinistra del portatore)
	# show = durata del giochetto prima dello scatto (dribShowStart), 0 = corsa subito (IA, o senza "rifiniture")
	ev("dribble", {"p": p, "o": o, "ok": ok, "side": side if side != 0.0 else dribSide(p, o), "show": DRIB_SHOW_T if show else 0.0})
	if duel != null and duel.p == p:
		endDuel("dribbling" if ok else "palla persa")
	return ok


# dribbling riuscito: il portatore corre oltre il difensore dal lato `side` (0 = lo sceglie dribSide), il difensore
# resta sbilanciato. Ritorna il lato usato.
func dribbleRun(p: R.Player, o: R.Player, side_: float) -> float:
	var tm := p.team
	var side: float = side_
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	var ux: float = dx / d
	var uy: float = dy / d
	if side == 0.0:
		side = dribSide(p, o)
	var nx: float = -uy * side
	var ny: float = ux * side
	var lat: float = maxf(DRIB_SIDE, DRIB_WIDE * (d + DRIB_PAST) / d)
	var tx: float = C.clamp_(p.x + ux * (d + DRIB_PAST) + nx * lat, -HW + 1.0, HW - 1.0)
	var ty: float = C.clamp_(p.y + uy * (d + DRIB_PAST) + ny * lat, -HL + 1.0, HL - 1.0)
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
	if human[tm] and ctrl[tm] == p:
		var mv := R.Move.new()
		mv.x = tx
		mv.y = ty
		mv.ttl = maxf(0.6, wn / sp + 0.15) # la corsa dura finché il portatore non arriva oltre il difensore
		move[tm] = mv
	return side


# dribbling fallito: il portatore resta fermo un attimo; il difensore vicino prende il pallone, sennò lo devia
func dribbleLost(p: R.Player, o: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	var ux: float = dx / d
	var uy: float = dy / d
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


# giochetto del dribbling prenotato riuscito (solo con "rifiniture"): il difensore, già battuto, si sbilancia verso la
# finta (lato opposto a `side`) e resta fermo; il portatore è protetto finché non è passato. Lo scatto lo fa dribShowStep.
func dribShowStart(p: R.Player, o: R.Player, side: float) -> void:
	var f := R.Duel.new()
	f.team = p.team
	f.p = p
	f.o = o
	f.side = side
	f.t = DRIB_SHOW_T
	dribShow = f
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	# verso la finta: alla destra del portatore se il lato scelto è la sinistra (+1), e viceversa
	var lx: float = dy / d * side
	var ly: float = -dx / d * side
	o.stun = DRIB_SHOW_T + DRIB_STUN
	o.contact = 0.0
	o.vx = lx * DRIB_LEAN_V
	o.vy = ly * DRIB_LEAN_V
	o.beat = o.stun + DRIB_BEAT
	o.beatBy = p
	if o.state == "prep":
		o.state = "play"
		o.warn = false
	p.protect = maxf(p.protect, DRIB_SHOW_T + DRIB_PROTECT)
	p.aiT = maxf(p.aiT, DRIB_SHOW_T + 0.35)
	dribShowSteer(f, 0.0)


# frenata davanti al difensore: della corsa verso di lui resta al massimo DRIB_SHOW_V (il giochetto a schermo parte adesso)
func dribBrake(p: R.Player, o: R.Player) -> void:
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	var ux: float = dx / d
	var uy: float = dy / d
	var vu: float = p.vx * ux + p.vy * uy
	if vu > DRIB_SHOW_V:
		p.vx -= ux * (vu - DRIB_SHOW_V)
		p.vy -= uy * (vu - DRIB_SHOW_V)


# a ogni passo durante il giochetto: il portatore frena e va piano verso la finta; finito il tempo cambia direzione e
# scatta oltre il difensore dal lato scelto (dribbleRun). Se perde il pallone o il gioco si ferma, finisce lì.
func dribShowStep(dt: float) -> void:
	var f := dribShow
	var p := f.p
	if phase != "play" or ball.owner != p or p.off or p.state != "play" or f.o.off:
		dribShow = null
		return
	f.t -= dt
	if f.t > 0.0:
		dribShowSteer(f, dt)
		return
	dribShow = null
	f.o.stun = 0.0 # dribbleRun lo rimette: sbilanciato da adesso fino a quando il portatore lo ha superato
	dribbleRun(p, f.o, f.side)
	# lo scatto dopo il giochetto è più veloce (come lo Scatto, BURST_SPD per BURST_T): recupera il tempo del giochetto,
	# altrimenti gli altri difensori arrivavano a chiudere (controllo del gameplay: gol della persona da 0,9 a 0,4)
	p.burst = maxf(p.burst, BURST_T)
	if portaAuto and human[f.team] and ctrl[f.team] == p:
		dribCarry(p, f.team)
	ev("dribble_go", {"p": p, "o": f.o, "side": f.side})


# Luis 2026-11-25 "dopo una skill riuscita il giocatore si ferma": la corsa oltre il difensore frenava fino a ~2 m/s
# sulla meta (DRIB_PAST oltre di lui), poi la fuga si riapriva col difensore battuto alle spalle. Come dopo lo Scatto:
# la meta va DRIB_CARRY m più avanti (stessa durata del comando: niente frenata), la guida automatica riparte subito
# con una direzione nuova e per BURST_FLEE_CD s la fuga non si riapre per lui.
func dribCarry(p: R.Player, tm: int) -> void:
	var mv: R.Move = move[tm]
	if mv != null:
		var wx: float = mv.x - p.x
		var wy: float = mv.y - p.y
		var wn: float = C.orf(C.hyp(wx, wy), 1.0)
		mv.x = C.clamp_(mv.x + wx / wn * DRIB_CARRY, -HW + 1.0, HW - 1.0)
		mv.y = C.clamp_(mv.y + wy / wn * DRIB_CARRY, -HL + 1.0, HL - 1.0)
		p.tx = mv.x
		p.ty = mv.y
		p.dx = mv.x
		p.dy = mv.y
	p.aiT = 0.0
	fleeCd[tm] = BURST_FLEE_CD
	fleeCdP[tm] = p


# passo lento verso la finta: velocità portata (frenando) a DRIB_SHOW_V, un po' di lato dalla parte opposta al lato scelto
func dribShowSteer(f: R.Duel, dt: float) -> void:
	var p := f.p
	var o := f.o
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d: float = C.orf(C.hyp(dx, dy), 1.0)
	var ux: float = dx / d
	var uy: float = dy / d
	var fw: float = DRIB_FEINT_FWD * C.clamp_(d - DRIB_SHOW_GAP, 0.0, 1.0)
	var wx: float = ux * fw + uy * f.side * DRIB_FEINT
	var wy: float = uy * fw - ux * f.side * DRIB_FEINT
	var wn: float = C.orf(C.hyp(wx, wy), 1.0)
	wx = wx / wn * DRIB_SHOW_V
	wy = wy / wn * DRIB_SHOW_V
	var ex: float = wx - p.vx
	var ey: float = wy - p.vy
	var e: float = C.hyp(ex, ey)
	var acc: float = DRIB_SHOW_DEC * dt
	if e <= acc:
		p.vx = wx
		p.vy = wy
	else:
		p.vx += ex / e * acc
		p.vy += ey / e * acc
	# il motore lo muove verso un punto vicino (velocità bassa: min(vmax, distanza · 3,2)), sempre più avanti
	var tx: float = C.clamp_(p.x + wx * 0.3, -HW + 0.5, HW - 0.5)
	var ty: float = C.clamp_(p.y + wy * 0.3, -HL + 0.5, HL - 0.5)
	p.tx = tx
	p.ty = ty
	p.dx = tx
	p.dy = ty
	var tm := f.team
	if human[tm] and ctrl[tm] == p:
		var mv := R.Move.new()
		mv.x = tx
		mv.y = ty
		mv.ttl = 0.2
		mv.held = false
		mv.sprint = false
		move[tm] = mv


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
