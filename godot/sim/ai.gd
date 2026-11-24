# IA: tiro, passaggi, portatore, rimesse, posizioni in attacco e difesa, portiere (porting di src/sim/ai.js).
extends "difesa.gd"

# Regolazioni dell'IA (misurate con test/balance.mjs e test/diag-flow.mjs)
const CLEAR_ZONE := 30.0     # metri dalla propria linea di fondo in cui un difensore pressato può spazzare
const CLEAR_TOUCH := 0.6     # spazzate mandate apposta in fallo laterale
const LOFT_RISK := 0.35      # margine richiesto in più per un lancio alto (i lanci si perdevano 1 volta su 2)
const CROSS_FREE := 2.2      # il cross si sceglie solo se il compagno in area ha questo spazio (m)
const SHOT_RANGE := 32.0     # distanza massima dalla porta per pensare al tiro (m)
const BOX_SHOT := 16.0       # sotto questa distanza la posizione di tiro è sempre buona (m)
const SHOT_BAR := 0.18       # soglia della qualità del tiro (più bassa = tira più spesso)
const LONG_SHOT := 1.1       # peso della posizione per i tiri da fuori area
const SHOT_BLOCKED := 0.65   # porta coperta da un difensore: si tira lo stesso, ma meno volentieri
const THROUGH_BOX := 1.0     # preferenza per il filtrante che porta un compagno dentro l'area
const PRESS_NEAR := 2.6      # avversario più vicino di così = portatore pressato (m)
const PRESS_REACT := 3.4     # distanza dell'avversario che fa decidere in fretta il portatore (m)
const PRESS_REACT_T := 0.06  # tempo minimo di decisione sotto pressione (s), più lento per squadre scarse
const SHOT_POST := 0.45      # distanza dal palo a cui mira l'IA (m): più vicino = più gol e più tiri fuori
const HELPERS := 2           # compagni che vengono incontro al portatore
const AIR_REACH := 2.4       # sui lanci vicino alle porte si va sul pallone fino a questa altezza (colpo di testa)
const AIR_ZONE := 17.0       # distanza dalla porta avversaria entro cui l'attaccante va a colpire di testa (m)
# Squadra umana senza palla: la CPU pressa il portatore con un giocatore (due vicino alla nostra porta) e gli altri
# rientrano nella posizione di squadra. Le linee disegnate e il dito della persona hanno sempre la precedenza.
const HUM_PRESS_ZONE := 33.0 # portatore entro questi metri dalla nostra linea di fondo (nostra trequarti): pressano in due
const HUM_PRESS_KEEP := 4.0  # chi sta già pressando conta come più vicino di così: niente scambi continui tra due quasi alla pari (m)
const HUM_BEHIND_D := 2.0    # i difensori restano almeno così dietro la palla (m)
const HUM_BEHIND_C := -1.0   # i centrocampisti al massimo 1 m davanti alla palla (m)
const HUM_MID_LANE := 0.3    # quanto i centrocampisti si stringono sulla linea palla-porta (chiudono il centro)
const HUM_SCREEN := 4.0      # chi non pressa resta almeno a questa distanza dal portatore, in copertura (m)
const HUM_MARK_R := 7.5      # si marca l'avversario più vicino al proprio posto entro questa distanza (m)
const HUM_RECOVER := 8.0     # più lontano di così dal proprio posto, verso la propria porta: rientro con lo scatto (m)
const HUM_MAGNET_R := 3.0    # giocatore mosso dalla persona (linea o dito) entro questa distanza dal pallone: va dritto sul pallone (m)
const HUM_STICK_T := 1.5     # linea finita vicino al pallone: il giocatore resta attaccato al pallone per questo tempo (s)
# Squadra umana in attacco: compagni senza palla larghi, in profondità e lontani tra loro
const SPACE_MIN := 9.0       # distanza minima voluta tra due compagni (m)
const SPACE_PUSH := 0.7      # parte della distanza mancante recuperata spostando il punto di arrivo (0..1)
const SPACE_PEN := 0.35      # penalità per metro mancante nella scelta dello spazio libero
const DEEP_FROM := -30.0     # con la palla da qui in avanti (m nel verso d'attacco) le punte attaccano la profondità
const HELP_KEEP := 4.0       # chi è già d'appoggio conta come più vicino di così al portatore: niente cambi continui di compito (m)
const SUPPORT_FAR := [15.0, 18.0] # il secondo compagno d'appoggio si offre più lontano (m), il primo resta a 8-11 m
const SUPPORT_NEAR := [8.0, 11.0]
const SPOTS := [[0.0, 0.0], [5.0, 0.0], [-5.0, 0.0], [0.0, 4.0], [3.5, 3.0], [-3.5, 3.0], [0.0, -4.0]]
const RUN_TRY := [-1.2, -0.7, -0.35, 0.0, 0.35, 0.7, 1.2]
const CHASE_N := 36
# Portiere sui cross avversari (Luis 2026-11-22: "la CPU segna sempre dagli angoli perché il portiere esce"):
# esce solo se arriva sicuro sul pallone, prima degli attaccanti e vicino alla porta; altrimenti resta tra i pali.
const GK_CLAIM_R := 12.0      # punto di presa entro questa distanza dal centro della propria porta (m)
const GK_CLAIM_MARGIN := 0.3  # ... raggiunto almeno così prima del primo avversario che può colpirlo di testa (s)
const GK_CROSS_OUT := 1.2     # cross avversario in volo e portiere che non esce: al massimo così fuori dalla linea (m)
# ... sul cross di un calcio d'angolo, con "rifiniture" (angoli.gd, 2026-11-24): esce con più decisione anche sui
# cross che scendono vicino alla porta e su cui è in anticipo di poco (oltre alle uscite di sopra)
const CORNER_GK_CLAIM_R := 6.0      # punto di presa entro questa distanza dal centro della porta (m)
const CORNER_GK_CLAIM_MARGIN := 0.1 # ... raggiunto almeno così prima del primo attaccante (s; i tempi vanno a passi di 0,1)
# Portatore della squadra umana che si muove da solo (humanCarrierAuto, opzione "portaAuto" della partita)
const AUTO_THINK := 0.25      # ogni quanto sceglie la direzione (s)
const AUTO_LOOK := 5.0        # distanza dei punti provati (m)
const AUTO_RUN := 10.0        # distanza del punto di arrivo (m)
const AUTO_EDGE := 2.0        # resta almeno così dentro le linee (m)
const AUTO_SPACE := 5.0       # spazio libero oltre il quale non conta di più (m)
const AUTO_BUMP := 2.5        # punto più vicino di così a un avversario = da evitare (m)
const AUTO_LANES := 0.35      # premio per ogni compagno con la linea di passaggio libera dal punto
const AUTO_BOX := 1.5         # premio per i punti dentro l'area avversaria, se c'è spazio
const AUTO_MATES := 2         # meno compagni di così davanti al portatore: rallenta per aspettarli
const AUTO_SPD := 0.85        # andatura normale (frazione della velocità massima)
const AUTO_SPD_POSS := 0.6    # possesso: avanza piano
const AUTO_SPD_LANCI := 0.4   # lanci lunghi: quasi fermo, testa alta
const AUTO_SPD_CROSS := 0.45  # fasce, arrivato sul fondo: aspetta il cross
const AUTO_SPD_WAIT := 0.55   # pochi compagni davanti: aspetta
const AUTO_SPD_SHIELD := 0.6  # pressato: protegge palla
const AUTO_CROSS_Y := 16.0    # fasce: a questi metri dalla linea di fondo si smette di salire sulla fascia
const AUTO_TRY := [-2.4, -1.8, -1.2, -0.7, -0.35, 0.0, 0.35, 0.7, 1.2, 1.8, 2.4, 3.14159]


# side: -1/1 = palo scelto; se manca (0), lato opposto al portiere (con un po' di casualità)
func aiShoot(p: R.Player, pen: bool = false, side: float = 0.0) -> void:
	var dir: float = -1.0 if p.team else 1.0
	var g := gk(1 - p.team)
	if side == 0.0:
		if pen:
			side = -1.0 if rnd() < 0.5 else 1.0
		else:
			side = (-1.0 if g.x > 0.0 else 1.0) * (1.0 if rnd() < 0.8 else -1.0)
	var tx: float = side * (GW / 2.0 - (0.8 if pen else SHOT_POST))
	var ty: float = dir * HL
	var th: float = (0.3 + rnd() * 0.4) if rnd() < 0.55 else (1.2 + rnd() * 0.8)
	var curve: float = (rnd() - 0.5) * 1.5
	kick(p, {"type": "shot", "tx": tx, "ty": ty, "th": th, "curve": curve})


# lato di tiro con la linea libera (0 = entrambi coperti); a pari merito, il palo lontano dal portiere
func shotSide(p: R.Player) -> float:
	var tm := p.team
	var gy: float = (-1.0 if tm else 1.0) * HL
	var g := gk(1 - tm)
	var tx: float = GW / 2.0 - SHOT_POST
	var open: Array[float] = []
	for sd: float in [-1.0, 1.0]:
		if lane(p.x, p.y, sd * tx, gy, tm, 28.0, true) > 0.0:
			open.append(sd)
	if open.is_empty():
		return 0.0
	if open.size() == 1:
		return open[0]
	return -1.0 if g.x > 0.0 else 1.0


# spazzata: lunga e alta verso la fascia; a volte direttamente in fallo laterale
func clear(p: R.Player) -> void:
	var dir: float = -1.0 if p.team else 1.0
	var side: float = C.sign_(p.x) if absf(p.x) > 4.0 else (-1.0 if rnd() < 0.5 else 1.0)
	var touch: bool = rnd() < CLEAR_TOUCH
	var tx: float = side * ((HW + 3.0 + rnd() * 6.0) if touch else (HW - 6.0 - rnd() * 10.0))
	var ty: float = C.clamp_(p.y + dir * (22.0 + rnd() * 16.0), -HL + 6.0, HL - 6.0)
	kick(p, {"type": "loft", "tx": tx, "ty": ty})


# un'opzione di passaggio verso (tx, ty) per il compagno m (la funzione `consider` dentro passOptions in JS);
# ritorna la migliore tra `best` e questa
func _consider(best: Variant, p: R.Player, tm: int, dir: float, gy: float, sk: float, ox: float, oy: float, m: R.Player, tx: float, ty: float, through: bool) -> Variant:
	var d: float = C.hyp(tx - ox, ty - oy)
	var sa: Stili.Att = stA[tm]
	if d < 4.0 or d > (Stili.LANCI_MAX if sa.lanci else 44.0):
		return best
	var vp: float = minf(17.0 + p.st.pas * 0.13, sqrt(25.0 + 2.0 * rollKick * d)) * 0.8
	var safe: float = lane(ox, oy, tx, ty, tm, vp)
	var type := "ground"
	var open: float = nearOpp(tx, ty, tm)
	if through:
		var dm: float = C.hyp(m.x - tx, m.y - ty)
		if open < dm + 1.5:
			return best
		safe = minf(safe, (open - dm - 1.5) / 3.0)
	elif (safe < 0.3 and d > 16.0) or (sa.lanci and safe < Stili.LANCI_SAFE and d > Stili.LANCI_MIN):
		# pallonetto solo se nessun avversario può arrivare sul punto di caduta prima della palla
		var Tl: float = C.clamp_(d / 14.0, 0.75, 2.6)
		var mar: float = 9.0
		for o: R.Player in players:
			if o.team != tm and not o.off:
				mar = minf(mar, C.hyp(o.x - tx, o.y - ty) - (0.9 + vmax(o) * maxf(0.0, Tl - 0.35)))
		var s2: float = minf(mar / 3.0, 0.8) - LOFT_RISK
		if sa.lanci:
			s2 += Stili.LANCI_RISK
		if s2 > safe:
			safe = s2
			type = "loft"
	var gain: float = (ty - oy) * dir
	var sc: float = C.clamp_(safe, -2.0, 1.2) + gain * 0.09 + minf(open, 8.0) * 0.06 - (0.25 if d > 30.0 else 0.0) + ((THROUGH_BOX if (absf(tx) < BOX_W / 2.0 and ty * dir > HL - BOX_D) else 0.6) if through else 0.0)
	var dg: float = C.hyp(tx, ty - gy)
	if dg < 22.0:
		sc += (22.0 - dg) * 0.05
	if m.pos == "P":
		sc -= 1.0
	sc += (rnd() - 0.5) * 0.6 * (1.0 - sk)
	if sa.on:
		sc += _styleScore(sa, tm, d, gain, safe, type, through)
	if best == null or sc > best.sc:
		return {"m": m, "tx": tx, "ty": ty, "type": type, "sc": sc, "safe": safe, "d": d, "gain": gain, "through": through}
	return best


# migliore passaggio per p: {m, tx, ty, type, sc, safe, d, gain, through|cross} oppure null
func passOptions(p: R.Player, exempt: bool = false) -> Variant:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var sk: float = teams[tm].skill
	var line: float = offLine[tm]
	var press: float = nearOpp(p.x, p.y, tm)
	var gy: float = dir * HL
	var ox: float = b.x if b.owner == p else p.x
	var oy: float = b.y if b.owner == p else p.y
	var best: Variant = null
	var fz: bool = stA[tm].fasce
	for m: R.Player in players:
		if m.team != tm or m == p or m.off:
			continue
		if m.pos == "P" and not (press < 3.0 and p.y * dir < -HL * 0.3):
			continue
		var mf: float = m.y * dir
		if not exempt and mf > line + 0.2 and mf > b.y * dir and mf > 0.0:
			continue
		best = _consider(best, p, tm, dir, gy, sk, ox, oy, m, m.x + m.vx * 0.5, m.y + m.vy * 0.5, false)
		if absf(ox) > (14.0 - Stili.FASCE_CROSS_X if fz else 14.0) and oy * dir > HL - (24.0 + Stili.FASCE_CROSS_Y if fz else 24.0) and m.pos != "D" and absf(m.x) < 11.0 and m.y * dir > HL - 17.0 and nearOpp(m.x, m.y, tm) > (Stili.FASCE_CROSS_FREE if fz else CROSS_FREE):
			var sc: float = 1.1 + (rnd() - 0.5) * 0.5 - C.hyp(m.x, m.y - gy) * 0.03
			if fz:
				sc += Stili.FASCE_CROSS_SC
			if best == null or sc > best.sc:
				best = {"m": m, "tx": m.x + m.vx * 0.6, "ty": m.y + m.vy * 0.6, "type": "loft", "sc": sc, "safe": 0.5, "d": C.hyp(m.x - ox, m.y - oy), "gain": 8.0, "cross": true}
		if m.pos != "D" and m.pos != "P" and mf > oy * dir - 3.0 and mf > -10.0:
			var lead: float = 7.0 + rnd() * 5.0
			var gx: float = m.x * 0.6
			var n: float = C.orf(C.hyp(gx - m.x, gy - m.y), 1.0)
			var tx: float = m.x + (gx - m.x) / n * lead
			var ty: float = m.y + (gy - m.y) / n * lead
			if absf(ty) < HL - 5.0:
				best = _consider(best, p, tm, dir, gy, sk, ox, oy, m, tx, ty, true)
	return best


func carrierAI(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var sk: float = teams[tm].skill
	var gy: float = dir * HL
	var dg: float = C.hyp(p.x, p.y - gy)
	var press: float = nearOpp(b.x, b.y, tm)
	var sa: Stili.Att = stA[tm]
	p.aiT -= dtT
	# avversario in arrivo: si decide subito (prima che arrivi il contrasto)
	var react: float = PRESS_REACT_T + 0.1 * (1.0 - sk)
	if press < PRESS_REACT and p.aiT > react:
		p.aiT = react
	if p.aiT <= 0.0 and p.stun <= 0.0:
		p.aiT = 0.42 - 0.2 * sk + rnd() * 0.15
		if sa.contro and counter(tm):
			p.aiT *= Stili.CONTRO_THINK
		if dg < SHOT_RANGE:
			var ang: float = absf(F.atan2_(p.x, maxf(0.1, HL - p.y * dir)))
			# dentro l'area si tira quasi sempre; da fuori solo da buona posizione (i tiri da lontano li para quasi tutti)
			var q: float = (1.0 if dg < BOX_SHOT else C.clamp_((SHOT_RANGE - dg) / (SHOT_RANGE - BOX_SHOT), 0.0, 1.0) * LONG_SHOT) * C.clamp_(1.25 - ang * 0.9, 0.1, 1.0)
			# si guarda la linea verso ciascun palo (dove si mira davvero), meglio se lontano dal portiere
			var side: float = shotSide(p)
			if side == 0.0:
				q *= SHOT_BLOCKED
			if dg < 10.0:
				q += 0.5
			var bar: float = SHOT_BAR + rnd() * 0.3 - (0.12 if press < 2.5 else 0.0)
			if sa.poss and dg > BOX_SHOT:
				bar += Stili.POSS_SHOT
			if q > bar:
				aiShoot(p, false, side)
				return
		# pressato vicino alla propria porta e senza passaggi sicuri: spazzata lunga verso la fascia
		if p.y * dir < -HL + CLEAR_ZONE and press < 2.6:
			var safe: Variant = passOptions(p)
			if safe == null or safe.safe < (0.5 if inOwnBox(p) else 0.15):
				clear(p)
				return
		# avversario che chiude la strada verso la porta
		var gdx: float = -p.x * 0.5
		var gdy: float = gy - p.y
		var gn: float = C.orf(C.hyp(gdx, gdy), 1.0)
		var front: float = 99.0
		for o: R.Player in players:
			if o.team == tm or o.off:
				continue
			var dx: float = o.x - p.x
			var dy: float = o.y - p.y
			var d: float = C.hyp(dx, dy)
			if d < 5.0 and (dx * gdx + dy * gdy) / C.orf(d * gn, 1.0) > 0.6:
				front = minf(front, d)
		var pass_: Variant = passOptions(p)
		p.holdN = p.holdN + 1
		if pass_ != null:
			var want: float = 0.0
			if press < PRESS_NEAR:
				want = 0.95 if pass_.safe > 0.0 else (0.5 if p.y * dir < -HL * 0.5 else 0.0)
			elif pass_.safe > 0.15:
				if pass_.gain > 6.0:
					want = 0.8 if front < 5.0 else 0.45
				elif front < 4.0:
					want = 0.6
				elif p.holdN > 5:
					want = 0.3
			if sa.on:
				want = _styleWant(sa, p, pass_, want, press)
			if rnd() < want:
				kick(p, {"type": pass_.type if pass_.safe > 0.0 else "loft", "tx": pass_.tx, "ty": pass_.ty})
				return
		# avversario davanti e nessun passaggio scelto: a volte si prova il dribbling (stessa regola dell'umano)
		if front < 5.0 and aiDribble(p):
			return
		var base: float = F.atan2_(gy - p.y, (p.x * 0.7 if dg > 30.0 else 0.0) - p.x)
		if sa.fasce and absf(p.x) > Stili.FASCE_RUN_X and dg > Stili.FASCE_RUN_DG:
			base = F.atan2_(gy - p.y, C.sign_(p.x) * (HW - 5.0) - p.x) # corsa sulla fascia
		var bs: float = -1e9
		var ba: float = base
		for o: float in RUN_TRY:
			var a: float = base + o
			var qx: float = p.x + F.cos_(a) * 5.0
			var qy: float = p.y + F.sin_(a) * 5.0
			var s2: float = (dg - C.hyp(qx, qy - gy)) * 1.5 + minf(nearOpp(qx, qy, tm), 4.0) * (2.6 if press < PRESS_NEAR else 1.1) - absf(o) * 0.3
			if absf(qx) > HW - 2.0 or absf(qy) > HL - 1.5:
				s2 -= 6.0
			if s2 > bs:
				bs = s2
				ba = a
		p.dx = p.x + F.cos_(ba) * 10.0
		p.dy = p.y + F.sin_(ba) * 10.0
	p.tx = C.clamp_(p.dx, -HW + 1.0, HW - 1.0)
	p.ty = C.clamp_(p.dy, -HL + 1.0, HL - 1.0)
	if sa.contro and counter(tm):
		p.sprint = true


func aiRestart() -> void:
	var r := restart
	var p := r.taker
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	if r.type == "penalty":
		aiShoot(p, true)
		return
	if r.type == "corner":
		var tx: float = (rnd() - 0.5) * 10.0
		var ty: float = dir * (HL - 5.0 - rnd() * 6.0)
		var curve: float = (rnd() - 0.5) * 3.0
		kick(p, {"type": "loft", "tx": tx, "ty": ty, "curve": curve})
		return
	if r.type == "kickoff":
		var m: R.Player = null
		var bd: float = 99.0
		for q: R.Player in players:
			if q.team == tm and q != p and not q.off and q.pos != "P":
				var d: float = C.hyp(q.x - p.x, q.y - p.y)
				if d < bd and q.y * dir < p.y * dir - 2.0:
					bd = d
					m = q
		if m != null:
			kick(p, {"type": "ground", "tx": m.x, "ty": m.y})
			return
	if r.type == "freekick":
		var dg: float = C.hyp(p.x, p.y - dir * HL)
		if dg < 27.0 and absf(p.x) < 16.0:
			aiShoot(p, false, -r.wallSide if r.wallSide != 0.0 else 0.0)
			return
		if dg < 42.0:
			var tx2: float = (rnd() - 0.5) * 12.0
			var ty2: float = dir * (HL - 7.0 - rnd() * 5.0)
			kick(p, {"type": "loft", "tx": tx2, "ty": ty2})
			return
	var o: Variant = passOptions(p, r.type == "throw" or r.type == "goalkick")
	if o != null and o.safe > -0.2:
		kick(p, {"type": o.type, "tx": o.tx, "ty": o.ty})
		return
	var tx3: float = C.clamp_(p.x * 0.5 + (rnd() - 0.5) * 24.0, -HW + 4.0, HW - 4.0)
	var ty3: float = C.clamp_(p.y + dir * 36.0, -HL + 8.0, HL - 8.0)
	kick(p, {"type": "loft", "tx": tx3, "ty": ty3})


# ------------------------------------------------------------ IA
func computeLines() -> void:
	for tm in 2:
		offLine[tm] = maxf(0.0, lineOf(tm))
		if rifiniture:
			defLinesUpdate(tm) # difesa.gd: rientri, abbinamenti a uomo
		if stD[tm].uomo and not rifiniture:
			_computeMarks(tm)
		elif stD[tm].fuorigioco:
			offLineD[tm] = _defLine(tm)


func computeChasers() -> void:
	var b := ball
	presser = [null, null]
	for tm in 2:
		var bp: R.Player = null
		var bd: float = 1e9
		for p: R.Player in players:
			if p.team == tm and not p.off and p.pos != "P" and p.state == "play":
				var d: float = C.hyp(p.x - b.x, p.y - b.y)
				if d < bd:
					bd = d
					bp = p
		presser[tm] = bp
	presser2 = [null, null]
	for tm in 2:
		if stD[tm].pressing:
			presser2[tm] = _second(tm, presser[tm])
	helpers = [[], []]
	if b.owner != null:
		var c := b.owner
		var was: Array = helpWas if human[c.team] else []
		var near: Array = []
		for q: R.Player in players:
			if q.team == c.team and q != c and not q.off and q.pos != "P" and q.state == "play":
				near.append(q)
		near = stableSort(near, func(q: R.Player) -> float: return C.hyp(q.x - c.x, q.y - c.y) - (HELP_KEEP if was.has(q) else 0.0))
		helpers[c.team] = near.slice(0, HELPERS + (Stili.POSS_HELPERS if stA[c.team].poss else 0))
		helpWas = helpers[c.team]
	# squadra umana in difesa: chi va sul portatore (i più vicini al pallone, senza linea disegnata)
	var wasP: Array = hPress if hPress != null else [[], []]
	hPress = [[], []]
	if b.owner != null and human[1 - b.owner.team]:
		var c := b.owner
		var tm: int = 1 - c.team
		var dir: float = -1.0 if tm else 1.0
		var deep: bool = c.y * dir < -HL + HUM_PRESS_ZONE
		var wasT: Array = wasP[tm]
		var cand: Array = []
		for p: R.Player in players:
			if p.team == tm and not p.off and p.pos != "P" and p.state == "play" and runOf(p) == null:
				cand.append(p)
		cand = stableSort(cand, func(q: R.Player) -> float: return C.hyp(q.x - c.x, q.y - c.y) - (HUM_PRESS_KEEP if wasT.has(q) else 0.0))
		var nPress: int = 2 if deep else 1
		if stD[tm].pressing:
			nPress += Stili.PRESS_HUM
		elif stD[tm].catenaccio and c.y * dir > -HL + Stili.CAT_ZONE:
			nPress = 0
		hPress[tm] = cand.slice(0, nPress)
	cover = [null, null]
	if b.owner != null:
		var c := b.owner
		var tm: int = 1 - c.team
		var dir: float = -1.0 if tm else 1.0
		var own: float = -dir * HL
		var ux: float = -c.x * 0.6
		var uy: float = own - c.y
		var n: float = C.orf(C.hyp(ux, uy), 1.0)
		var qx: float = c.x + ux / n * 4.0
		var qy: float = c.y + uy / n * 4.0
		var first: R.Player = ctrl[tm] if human[tm] else presser[tm]
		var bp: R.Player = null
		var bd: float = 14.0
		for p: R.Player in players:
			if p.team == tm and not p.off and p.pos != "P" and p.state == "play" and p != first:
				var d: float = C.hyp(p.x - qx, p.y - qy)
				if d < bd:
					bd = d
					bp = p
		cover[tm] = null if (human[tm] or float(teams[tm].skill) < 0.42) else bp
		chase = [null, null]
		return
	_computeChase(b)


# pallone libero: previsione del volo e, per ogni squadra, chi ci arriva prima (seconda parte di computeChasers)
func _computeChase(b: R.Ball) -> void:
	var N := CHASE_N
	var px := PackedFloat64Array()
	var py := PackedFloat64Array()
	var ph := PackedFloat64Array()
	px.resize(N)
	py.resize(N)
	ph.resize(N)
	var s := b.physCopy()
	for k in N:
		px[k] = C.clamp_(s.x, -HW, HW)
		py[k] = C.clamp_(s.y, -HL, HL)
		ph[k] = s.h
		for j in 4:
			C.ballPhys(s, 0.025, roll)
	# cross (lancio alto) in volo: quando arriva a colpirlo il primo avversario di chi difende
	var cross: bool = b.kick != null and b.kick.type == "loft"
	var oppT: Array = [99.0, 99.0]
	if cross:
		oppT[1 - b.kick.team] = _firstHeader(b.kick, px, py, ph)
	var cornerX: bool = cross and cornerLive()
	for tm in 2:
		var dir: float = -1.0 if tm else 1.0
		var best: R.Chase = null
		var bestO: R.Chase = null
		for p: R.Player in players:
			if p.team != tm or p.off or p.state != "play":
				continue
			if b.kick != null and b.kick.kicker == p and b.kick.age < 1.2:
				continue
			if dblBan(p):
				continue # ha battuto il calcio da fermo: non può ritoccarlo, ci vanno gli altri
			var isGk: bool = p.pos == "P"
			var vm: float = vmax(p)
			var gkCross: bool = isGk and cross and b.kick.team != tm
			var hm: float = (C.GK_HAND_HI if gkCross else 2.3) if isGk else 1.5
			# sui lanci alti vicino alle porte si va incontro al pallone per colpirlo di testa
			var loft: bool = not isGk and b.kick != null and b.kick.type == "loft" and b.kick.kicker != p
			var mate: bool = loft and b.kick.team == tm
			var r: R.Chase = null
			for k in N:
				var lim: float = hm
				if loft and ph[k] <= AIR_REACH and (C.hyp(px[k], py[k] - dir * HL) < AIR_ZONE if mate else C.hyp(px[k], py[k] + dir * HL) < AIR_ZONE + 15.0):
					lim = AIR_REACH
				if ph[k] > lim:
					continue
				var tk: float = k * 0.1
				var d: float = C.hyp(p.x - px[k], p.y - py[k])
				if d - 0.8 <= vm * maxf(0.0, tk - 0.12):
					r = R.Chase.new()
					r.p = p
					r.t = tk
					r.x = px[k]
					r.y = py[k]
					break
			if r == null:
				r = R.Chase.new()
				r.p = p
				r.t = 50.0 + C.hyp(p.x - px[N - 1], p.y - py[N - 1])
				r.x = px[N - 1]
				r.y = py[N - 1]
			if isGk:
				if not (absf(r.x) < BOX_W / 2.0 and r.y * dir < -HL + BOX_D):
					continue
				# sul cross esce solo se ci arriva prima degli attaccanti e vicino alla porta (o se è già uscito)
				if gkCross and p.claim != b.kick and not _gkClaims(r, float(oppT[tm]), dir, cornerX):
					continue
			elif bestO == null or r.t < bestO.t:
				bestO = r
			if best == null or r.t < best.t:
				best = r
		if best != null:
			if cross and best.p.pos == "P" and b.kick.team != tm:
				best.p.claim = b.kick
			var ch := R.Chase.new()
			ch.p = best.p
			ch.x = best.x
			ch.y = best.y
			ch.t = best.t
			ch.p2 = bestO.p if bestO != null else null
			ch.x2 = bestO.x if bestO != null else 0.0
			ch.y2 = bestO.y if bestO != null else 0.0
			chase[tm] = ch
		else:
			chase[tm] = null


# il portiere esce sul cross: punto di presa r raggiunto in anticipo sul primo attaccante (oppT) e vicino alla porta
func _gkClaims(r: R.Chase, oppT: float, dir: float, cornerX: bool) -> bool:
	var d: float = C.hyp(r.x, r.y + dir * HL)
	if r.t + GK_CLAIM_MARGIN <= oppT and d <= GK_CLAIM_R:
		return true
	return cornerX and r.t + CORNER_GK_CLAIM_MARGIN <= oppT and d <= CORNER_GK_CLAIM_R


# primo istante (s) in cui un giocatore della squadra che ha crossato (portiere escluso) arriva sul pallone ad altezza
# di colpo di testa; 99 se nessuno ci arriva
func _firstHeader(k: R.Kick, px: PackedFloat64Array, py: PackedFloat64Array, ph: PackedFloat64Array) -> float:
	var best: float = 99.0
	for q: R.Player in players:
		if q.team != k.team or q.off or q.state != "play" or q.pos == "P" or dblBan(q):
			continue
		if k.kicker == q and k.age < 1.2:
			continue
		var vm: float = vmax(q)
		for j in CHASE_N:
			var tk: float = j * 0.1
			if tk >= best:
				break
			if ph[j] > HEAD_HI:
				continue
			if C.hyp(q.x - px[j], q.y - py[j]) - 0.8 <= vm * maxf(0.0, tk - 0.12):
				best = tk
				break
	return best


func think(dt: float) -> void:
	var b := ball
	dtT = dt
	att = b.owner.team if b.owner != null else (b.kick.team if b.kick != null else (restart.team if phase == "restart" else -1))
	# pallone rubato all'avversario (contropiede, stili.gd); non cambia niente per gli altri stili
	if b.owner != null and phase == "play" and b.owner.team != possWho:
		if possWho >= 0:
			possT0[b.owner.team] = time
		possWho = b.owner.team
	cornerTrack() # angoli.gd (solo con "rifiniture")
	predT -= dt
	if predT <= 0.0:
		predT = 0.1
		computeChasers()
		computeLines()
	for p: R.Player in players:
		if p.off or p.state != "play":
			continue
		p.spdF = 1.0
		p.sprint = false
		assign(p)
		if rifiniture and phase == "restart" and restart.type == "throw":
			throwRoom(p) # riprese.gd: nella rimessa gli altri restano lontani dalla linea


# la squadra T è senza palla: possesso avversario, oppure pallone libero che non viene da un nostro passaggio o tiro
func manualDef(tm: int) -> bool:
	var b := ball
	return b.owner.team != tm if b.owner != null else not (b.kick != null and b.kick.team == tm)


func assign(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var hum: bool = human[tm]
	if phase == "restart" and (restart.scena != "" or restart.pend != null) and sceneAssign(p):
		return # scena della ripresa (riprese.gd): il battitore va a prendere il pallone, gli altri al loro posto
	if phase == "restart" and restart.taker == p:
		p.tx = p.x
		p.ty = p.y
		return
	if phase == "restart" and p.wall != null:
		p.tx = p.wall.x
		p.ty = p.wall.y
		return
	if headWin != null and headRun(p):
		return
	var mv: R.Move = move[tm] if (hum and ctrl[tm] == p) else null
	if mv != null and mv.path != null:
		followPath(p, mv)
	var def: bool = hum and p.pos != "P" and phase == "play" and manualDef(tm)
	# linea disegnata in difesa: vale più di tutto il resto (anche del pressing) finché non è finita
	if hum and b.owner != p and not runs[tm].is_empty():
		var r := runOf(p)
		if r != null and followRun(p, r):
			if def:
				magnet(p)
			return
	# senza palla (avversario in possesso o pallone libero non passato da noi): il controllato segue il dito,
	# gli altri li muove la CPU (pressing e posizione difensiva, vedi humanDefend)
	if def:
		if mv != null and mv.path == null:
			p.tx = mv.x
			p.ty = mv.y
			p.sprint = mv.sprint
			magnet(p)
			return
		if not autoDef[tm]:
			p.tx = p.x
			p.ty = p.y
			return
		if cornerMark(p):
			return
		humanDefend(p)
		return
	if mv != null and mv.sprint:
		p.sprint = true
	if b.owner == p:
		if hum:
			if mv != null:
				p.tx = mv.x
				p.ty = mv.y
			elif portaAuto:
				humanCarrierAuto(p)
			else:
				p.tx = p.x * 0.9
				p.ty = C.clamp_(p.y + dir * 8.0, -HL + 3.0, HL - 3.0)
				p.spdF = 0.7
		else:
			carrierAI(p)
		return
	if mv != null:
		p.tx = mv.x
		p.ty = mv.y
		return
	if p.pos == "P":
		gkAI(p)
		return
	if b.owner == null and phase == "play":
		var ch: R.Chase = chase[tm]
		if ch != null and ch.p == p:
			p.tx = ch.x
			p.ty = ch.y
			return
		if ch != null and ch.p2 == p:
			p.tx = ch.x2
			p.ty = ch.y2
			return
	if att != tm and cornerMark(p):
		pass # marcatura sull'angolo avversario (angoli.gd); sotto, la distanza dal pallone nella ripresa
	elif att == tm:
		support(p)
	else:
		defend(p)
	if phase == "restart" and restart.team != tm:
		var r := restart
		var Rr: float = 5.0 if r.type == "throw" else (CIRCLE if r.type == "kickoff" else 8.5)
		var dx: float = p.tx - r.x
		var dy: float = p.ty - r.y
		var d: float = C.hyp(dx, dy)
		if d < Rr:
			p.tx = r.x + (dx / C.orf(d, 1.0)) * Rr
			p.ty = r.y + (dy / C.orf(d, 1.0)) * Rr
			if d < 0.1:
				p.ty = r.y - dir * Rr
		if r.type == "kickoff" and p.ty * dir > -0.5:
			p.ty = -dir * 0.5
	if phase == "restart" and restart.type == "kickoff" and p.ty * dir > -0.3:
		p.ty = -dir * 0.3
	# con "rifiniture" anche i compagni del battitore restano fuori dal cerchio (motion.gd kickoffClear)
	if rifiniture and phase == "restart" and restart.type == "kickoff":
		var kr: float = CIRCLE + KO_MARGIN
		var kd: float = C.hyp(p.tx, p.ty)
		if kd < kr:
			p.tx = p.tx / C.orf(kd, 1.0) * kr if kd > 0.01 else 0.0
			p.ty = p.ty / kd * kr if kd > 0.01 else -dir * kr


# giocatore mosso dalla persona vicino al pallone (avversario col pallone o pallone libero): l'ultimo tratto va dritto
# sul pallone, così il contrasto non si manca di poco. true se ha cambiato la destinazione
func magnet(p: R.Player) -> bool:
	var b := ball
	var c := b.owner
	if C.hyp(b.x - p.x, b.y - p.y) > HUM_MAGNET_R or b.h > 1.7:
		return false
	p.tx = b.x + (c.vx if c != null else b.vx) * 0.2
	p.ty = b.y + (c.vy if c != null else b.vy) * 0.2
	return true


# giocatore della squadra umana mosso dalla persona: il controllato, chi segue una linea, chi l'ha appena finita addosso al pallone
func directed(p: R.Player) -> bool:
	return bool(human[p.team]) and (ctrl[p.team] == p or p.stickT > 0.0 or runOf(p) != null)


# chiamata quando finisce una linea di difesa: se è finita addosso al pallone, il giocatore ci resta attaccato un attimo
func runEnded(p: R.Player) -> void:
	var b := ball
	if human[p.team] and manualDef(p.team) and C.hyp(b.x - p.x, b.y - p.y) < HUM_MAGNET_R + 1.5:
		p.stickT = HUM_STICK_T


# squadra umana senza palla, giocatore senza linea e senza dito: pressing (i più vicini), pallone vagante
# (il più rapido ad arrivarci; i passaggi avversari in volo no: l'intercetto resta alla persona),
# altrimenti posizione di squadra dietro la palla con marcatura a zona
func humanDefend(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var own: float = -dir * HL
	var c := b.owner
	p.stickT = maxf(0.0, p.stickT - dtT)
	if p.stickT > 0.0 and magnet(p):
		return
	if c == null:
		var ch: R.Chase = chase[tm]
		if ch != null and ch.p2 == p and (b.kick == null or _crossOnUs(tm, ch.x2, ch.y2)):
			p.tx = ch.x2
			p.ty = ch.y2
			return
	elif hPress != null and hPress[tm].has(p):
		var hp: Array = hPress[tm]
		if rifiniture and stD[tm].pressing and hp.find(p) > 0:
			var q2 := press2Pos(p, c, hp[0]) # difesa.gd: chi pressa per secondo raddoppia o chiude la linea
			p.tx = q2[0]
			p.ty = q2[1]
			return
		p.tx = b.x + c.vx * 0.25
		p.ty = b.y + c.vy * 0.25
		return
	var an := defAnchor(p)
	var ax: float = an[0]
	var ay: float = an[1]
	var tx: float = ax
	var ty: float = ay
	var mo: R.Player = null
	var md: float = defMarkR(tm, HUM_MARK_R)
	for o: R.Player in players:
		if o.team != tm and not o.off and o.pos != "P" and o != c:
			var d: float = C.hyp(o.x - ax, o.y - ay)
			if d < md:
				md = d
				mo = o
	if mo != null:
		var ux: float = -mo.x
		var uy: float = own - mo.y
		var n: float = C.orf(C.hyp(ux, uy), 1.0)
		tx = ax * 0.35 + (mo.x + ux / n * 1.6) * 0.65
		ty = ay * 0.35 + (mo.y + uy / n * 1.6) * 0.65
	# centrocampisti: si stringono sulla linea tra palla e centro della porta (chiudono i passaggi centrali)
	if p.pos == "C":
		var k: float = C.clamp_((ty - own) / C.orf(b.y - own, 1.0), 0.0, 1.0)
		tx += (b.x * k - tx) * HUM_MID_LANE
	if stD[tm].on:
		var sp := _styleDefPos(p, ax, ay, tx, ty)
		tx = sp[0]
		ty = sp[1]
	# chi non pressa non va addosso al portatore: resta in copertura a qualche metro
	if c != null:
		var ux2: float = tx - c.x
		var uy2: float = ty - c.y
		var d2: float = C.hyp(ux2, uy2)
		if d2 < HUM_SCREEN:
			if d2 < 0.5:
				ux2 = -c.x * 0.3
				uy2 = own - c.y
			var n2: float = C.orf(C.hyp(ux2, uy2), 1.0)
			tx = c.x + ux2 / n2 * HUM_SCREEN
			ty = c.y + uy2 / n2 * HUM_SCREEN
	# difensori e centrocampisti rientrano dietro la linea della palla
	var hasLim: bool = p.pos == "D" or p.pos == "C"
	var lim: float = (b.y * dir - HUM_BEHIND_D) if p.pos == "D" else (b.y * dir - HUM_BEHIND_C)
	if hasLim and ty * dir > lim:
		ty = maxf(lim, -HL + 4.0) * dir
	p.tx = C.clamp_(tx, -HW + 1.0, HW - 1.0)
	p.ty = C.clamp_(ty, -HL + 1.0, HL - 1.0)
	# lontano dal proprio posto, con la porta alle spalle: rientro di corsa
	if C.hyp(p.tx - p.x, p.ty - p.y) > HUM_RECOVER and (p.ty - p.y) * dir < 0.0:
		p.sprint = true


# cross (lancio alto) avversario che scende vicino alla porta di tm, nel punto (x, y): il difensore che ci arriva
# prima va a colpirlo di testa anche nella squadra umana (prima ci andava solo il portiere, che usciva a vuoto)
func _crossOnUs(tm: int, x: float, y: float) -> bool:
	var k := ball.kick
	var dir: float = -1.0 if tm else 1.0
	return k != null and k.type == "loft" and k.team != tm and C.hyp(x, y + dir * HL) < HEAD_CLEAR_ZONE


# penalità per i compagni troppo vicini al punto (x, y) (squadra umana in attacco): niente grappoli
func crowd(p: R.Player, x: float, y: float) -> float:
	var pen: float = 0.0
	for q: R.Player in players:
		if q.team == p.team and q != p and not q.off and q.pos != "P":
			var d: float = C.hyp(q.x - x, q.y - y)
			if d < SPACE_MIN:
				pen += SPACE_MIN - d
	return pen


# sposta (x, y) lontano dai compagni più vicini di SPACE_MIN (portatore compreso)
func spread(p: R.Player, x: float, y: float) -> PackedFloat64Array:
	for q: R.Player in players:
		if q.team != p.team or q == p or q.off or q.pos == "P":
			continue
		var dx: float = x - q.x
		var dy: float = y - q.y
		var d: float = C.hyp(dx, dy)
		if d < SPACE_MIN:
			var k: float = (SPACE_MIN - d) * SPACE_PUSH / C.orf(d, 1.0)
			x += (dx if d != 0.0 else (1.0 if p.i % 2 else -1.0)) * k
			y += dy * k
	return PackedFloat64Array([C.clamp_(x, -HW + 1.5, HW - 1.5), C.clamp_(y, -HL + 2.0, HL - 2.0)])


# compagno vicino al portatore: cerca uno spazio libero raggiungibile con un passaggio sicuro
func offerSupport(p: R.Player, c: R.Player) -> void:
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	p.supT = p.supT - dtT
	if p.supT <= 0.0 or p.supC != c:
		p.supT = 0.35 + rnd() * 0.25
		p.supC = c
		var bs: float = -1e9
		p.supX = p.x - c.x
		p.supY = p.y - c.y
		# squadra umana: il secondo d'appoggio si offre più lontano (linee di passaggio a distanze diverse), lontano dai compagni
		var hum: bool = human[tm]
		var far: bool = hum and helpers[tm].size() > 1 and helpers[tm][1] == p
		for r: float in (SUPPORT_FAR if far else (Stili.POSS_SUPPORT if stA[tm].poss else SUPPORT_NEAR)):
			for k in range(-5, 6):
				var a: float = F.atan2_(dir, 0.0) + k * 0.5
				var qx: float = c.x + F.cos_(a) * r
				var qy: float = c.y + F.sin_(a) * r
				if absf(qx) > HW - 1.5 or absf(qy) > HL - 2.0 or qy * dir > offLine[tm] - 0.8:
					continue
				var sc: float = minf(nearOpp(qx, qy, tm), 7.0) * 0.8 + C.clamp_(lane(c.x, c.y, qx, qy, tm, 16.0), -2.0, 2.0) * 1.2 + (qy - c.y) * dir * 0.07 - C.hyp(qx - p.x, qy - p.y) * 0.08 + rnd() * 0.3 - (crowd(p, qx, qy) * SPACE_PEN if hum else 0.0)
				if sc > bs:
					bs = sc
					p.supX = qx - c.x
					p.supY = qy - c.y
	p.tx = C.clamp_(c.x + p.supX, -HW + 1.0, HW - 1.0)
	p.ty = C.clamp_(c.y + p.supY, -HL + 1.0, HL - 1.0)
	if human[tm]:
		var sp := spread(p, p.tx, p.ty)
		p.tx = sp[0]
		p.ty = sp[1]
		var mf: float = offLine[tm] - 0.8
		if p.ty * dir > mf:
			p.ty = mf * dir


func support(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var hum: bool = human[tm] and phase == "play"
	if phase == "play" and b.owner != null and b.owner.team == tm and helpers[tm].has(p):
		offerSupport(p, b.owner)
		return
	var an := anchor(p)
	var ax: float = an[0]
	var ay: float = an[1]
	p.soT -= dtT
	if p.soT <= 0.0:
		p.soT = 0.5 + rnd() * 0.4
		var bs: float = -1e9
		for c: Array in SPOTS:
			var qx: float = ax + c[0]
			var qy: float = ay + c[1] * dir
			if absf(qx) > HW - 1.5 or absf(qy) > HL - 2.0:
				continue
			var s: float = minf(nearOpp(qx, qy, tm), 7.0) + (1.5 if lane(b.x, b.y, qx, qy, tm, 18.0) > 0.0 else 0.0) + (0.6 if c[1] > 0.0 else 0.0) + rnd() * 0.5 - (crowd(p, qx, qy) * SPACE_PEN if hum else 0.0)
			if s > bs:
				bs = s
				p.sox = c[0]
				p.soy = c[1] * dir
	var tx: float = ax + p.sox
	var ty: float = ay + p.soy
	var line: float = offLine[tm]
	var flight: bool = b.owner == null and b.kick != null and b.kick.team == tm
	# le punte attaccano lo spazio dietro la difesa, sulla linea del fuorigioco (la squadra umana già dalla propria metà)
	if p.pos == "A" and b.y * dir > (DEEP_FROM if hum else -15.0):
		ty = maxf(ty * dir, minf(line - 0.8, HL - 6.0)) * dir
	if hum:
		var sp := spread(p, tx, ty)
		tx = sp[0]
		ty = sp[1]
	if not flight:
		var mf: float = maxf(line - 0.8, b.y * dir)
		if ty * dir > mf:
			ty = mf * dir
	p.tx = tx
	p.ty = ty


func defend(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var own: float = -dir * HL
	var hum: bool = human[tm]
	var an := defAnchor(p)
	var ax: float = an[0]
	var ay: float = an[1]
	var tx: float = ax
	var ty: float = ay
	if phase == "play" and b.owner != null and b.owner.team != tm:
		var c := b.owner
		if (ctrl[tm] == p) if hum else (presser[tm] == p):
			if hum: # contenimento automatico se non si tocca lo schermo
				var ux: float = -c.x
				var uy: float = own - c.y
				var n: float = C.orf(C.hyp(ux, uy), 1.0)
				p.tx = c.x + ux / n * 2.6
				p.ty = c.y + uy / n * 2.6
			elif stD[tm].catenaccio and c.y * dir > -HL + Stili.CAT_ZONE:
				# catenaccio: lontano dalla nostra area non si va addosso, si resta davanti al portatore
				var ux4: float = -c.x * 0.3
				var uy4: float = own - c.y
				var n4: float = C.orf(C.hyp(ux4, uy4), 1.0)
				p.tx = c.x + ux4 / n4 * Stili.CAT_HOLD
				p.ty = c.y + uy4 / n4 * Stili.CAT_HOLD
			else:
				# niente scivolate (tolte anche all'IA il 2026-11-20): il pressatore ruba palla solo col contatto
				p.tx = b.x + c.vx * 0.25
				p.ty = b.y + c.vy * 0.25
				if rifiniture and stD[tm].pressing:
					p.sprint = true # pressing: si va sul portatore di corsa
			return
		if not hum and presser2[tm] == p and c.y * dir > (Stili.PRESS_FROM_R if rifiniture else Stili.PRESS_FROM):
			# pressing alto: il secondo pressatore va anche lui sul portatore (con "rifiniture" poi chiude la linea, difesa.gd)
			if rifiniture:
				var q2 := press2Pos(p, c, presser[tm])
				p.tx = q2[0]
				p.ty = q2[1]
				p.sprint = true
				return
			p.tx = b.x + c.vx * 0.25
			p.ty = b.y + c.vy * 0.25
			return
		if cover[tm] == p:
			var ux2: float = -c.x * 0.6
			var uy2: float = own - c.y
			var n2: float = C.orf(C.hyp(ux2, uy2), 1.0)
			p.tx = c.x + ux2 / n2 * 3.2
			p.ty = c.y + uy2 / n2 * 3.2
			return
	var mo: R.Player = null
	var md: float = defMarkR(tm, 7.5)
	for o: R.Player in players:
		if o.team != tm and not o.off and o.pos != "P" and o != b.owner:
			var d: float = C.hyp(o.x - ax, o.y - ay)
			if d < md:
				md = d
				mo = o
	if mo != null:
		var ux3: float = -mo.x
		var uy3: float = own - mo.y
		var n3: float = C.orf(C.hyp(ux3, uy3), 1.0)
		tx = ax * 0.35 + (mo.x + ux3 / n3 * 1.6) * 0.65
		ty = ay * 0.35 + (mo.y + uy3 / n3 * 1.6) * 0.65
	if stD[tm].on:
		var sp := _styleDefPos(p, ax, ay, tx, ty)
		tx = sp[0]
		ty = sp[1]
	p.tx = tx
	p.ty = ty


# ------------------------------------------------------------ stili di gioco (stili.gd)
# la squadra T ha rubato il pallone da poco e ce l'ha ancora (finestra del contropiede)
func counter(tm: int) -> bool:
	return ball.owner != null and ball.owner.team == tm and time - float(possT0[tm]) < Stili.CONTRO_WIN


# preferenza in più per un passaggio secondo lo stile d'attacco
func _styleScore(sa: Stili.Att, tm: int, d: float, gain: float, safe: float, type: String, through: bool) -> float:
	if sa.contro:
		return (gain * Stili.CONTRO_GAIN + (Stili.CONTRO_THROUGH if through else 0.0)) if counter(tm) else 0.0
	if sa.poss:
		return gain * Stili.POSS_GAIN - maxf(0.0, d - Stili.POSS_LEN0) * Stili.POSS_LEN + C.clamp_(safe, -1.0, 1.0) * Stili.POSS_SAFE - (Stili.POSS_NO_LOFT if type == "loft" else 0.0)
	if sa.lanci:
		return maxf(0.0, d - Stili.LANCI_LEN0) * Stili.LANCI_LEN + (Stili.LANCI_SC if type == "loft" else 0.0)
	return 0.0


# voglia di passare del portatore secondo lo stile d'attacco
func _styleWant(sa: Stili.Att, p: R.Player, pass_: Dictionary, want: float, press: float) -> float:
	if sa.poss and press >= PRESS_NEAR and pass_.safe > 0.15 and p.holdN > Stili.POSS_HOLD:
		return maxf(want, Stili.POSS_HOLD_WANT)
	if sa.contro and counter(p.team) and pass_.safe > 0.0 and pass_.gain > 6.0:
		return maxf(want, 0.9)
	if sa.lanci and pass_.type == "loft" and pass_.safe > 0.0 and pass_.d > 22.0:
		return maxf(want, Stili.LANCI_WANT)
	if sa.fasce and pass_.get("cross", false) and pass_.safe > 0.0:
		return maxf(want, 0.8)
	return want


# il secondo giocatore più vicino al pallone (pressing alto)
func _second(tm: int, first: R.Player) -> R.Player:
	var b := ball
	var bp: R.Player = null
	var bd: float = 1e9
	for p: R.Player in players:
		if p.team == tm and p != first and not p.off and p.pos != "P" and p.state == "play":
			var d: float = C.hyp(p.x - b.x, p.y - b.y)
			if d < bd:
				bd = d
				bp = p
	return bp


# marcatura a uomo: ogni difensore e centrocampista ha il suo avversario (dai posti della formazione, i più arretrati
# scelgono per primi); si rifà solo se manca o se qualcuno è uscito
func _computeMarks(tm: int) -> void:
	var mk: Dictionary = marks[tm]
	var ok: bool = not mk.is_empty()
	for k: int in mk:
		if players[k].off or players[mk[k]].off:
			ok = false
	if ok:
		return
	mk.clear()
	var dir: float = -1.0 if tm else 1.0
	var mine: Array = []
	for p: R.Player in players:
		if p.team == tm and not p.off and (p.pos == "D" or p.pos == "C"):
			mine.append(p)
	mine = stableSort(mine, func(q: R.Player) -> float: return q.by)
	var taken := {}
	for p: R.Player in mine:
		var px: float = p.bx * HW
		var py: float = (p.by - 0.5) * L * dir
		var bo: int = -1
		var bd: float = 1e9
		for o: R.Player in players:
			var k: int = o.team * 11 + o.i
			if o.team == tm or o.off or o.pos == "P" or taken.has(k):
				continue
			var d: float = C.hyp(o.bx * HW - px, (o.by - 0.5) * L * -dir - py)
			if d < bd:
				bd = d
				bo = k
		if bo >= 0:
			taken[bo] = true
			mk[p.team * 11 + p.i] = bo


# fuorigioco: linea comune dei difensori = il posto più alto tra i loro, sempre dietro al pallone
func _defLine(tm: int) -> float:
	var dir: float = -1.0 if tm else 1.0
	var hi: float = -HL
	for p: R.Player in players:
		if p.team == tm and not p.off and p.pos == "D":
			hi = maxf(hi, anchor(p)[1] * dir)
	if rifiniture:
		return offStepUp(tm, hi) # difesa.gd: più alta e sale insieme quando il pallone va avanti
	return C.clamp_(minf(hi, ball.y * dir - Stili.OFF_BALL), -HL + 6.0, 0.0)


# posizione difensiva secondo lo stile di difesa (giocatore senza pressing né copertura): (tx, ty) corretti
func _styleDefPos(p: R.Player, ax: float, ay: float, tx: float, ty: float) -> PackedFloat64Array:
	var tm := p.team
	var sd: Stili.Dif = stD[tm]
	var dir: float = -1.0 if tm else 1.0
	var key: int = tm * 11 + p.i
	if sd.uomo and rifiniture:
		return uomoPos(p, ax, ay, tx, ty) # difesa.gd
	if sd.uomo and marks[tm].has(key):
		var o: R.Player = players[marks[tm][key]]
		if not o.off and o != ball.owner:
			var ux: float = -o.x
			var uy: float = -dir * HL - o.y
			var n: float = C.orf(C.hyp(ux, uy), 1.0)
			tx = ax * (1.0 - Stili.UOMO_K) + (o.x + ux / n * Stili.UOMO_GAP) * Stili.UOMO_K
			ty = ay * (1.0 - Stili.UOMO_K) + (o.y + uy / n * Stili.UOMO_GAP) * Stili.UOMO_K
	elif sd.fuorigioco and p.pos == "D" and att != tm:
		ty = float(offLineD[tm]) * dir
		if rifiniture and absf(p.y - ty) > Stili.OFF_SPRINT:
			p.sprint = true # la linea sale (o scende) tutta insieme, di corsa
	return PackedFloat64Array([tx, ty])


# ------------------------------------------------------------ portatore umano senza strada (Luis 2026-11-22)
# Con l'opzione "portaAuto" della partita (predefinita: sì; i test confrontati col JS la spengono) il portatore della squadra
# umana senza strada disegnata (o a strada finita) si muove da solo: avanza nello spazio libero, protegge palla se
# pressato, si allarga o si accentra, rallenta per aspettare i compagni, gira intorno ai difensori e resta in campo,
# secondo lo stile d'attacco. Non passa e non tira mai: quelle scelte restano al dito. Niente numeri casuali.
# Nel duello e nella fuga (rallenty col tasto) fa come prima: avanza piano e dritto, decide la persona.
func humanCarrierAuto(p: R.Player) -> void:
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	if duelFor(tm) or fleeFor(tm):
		p.tx = p.x * 0.9
		p.ty = C.clamp_(p.y + dir * 8.0, -HL + 3.0, HL - 3.0)
		p.spdF = 0.7
		if rifiniture:
			p.aiT = 0.0 # finito il rallenty sceglie subito una direzione nuova (prima ripartiva verso la meta vecchia)
		return
	p.aiT -= dtT
	if p.aiT <= 0.0 or p.supC != p:
		p.aiT = AUTO_THINK
		p.supC = p # segna che dx/dy sono della guida automatica (supC del portatore non serve all'appoggio)
		_autoDecide(p)
	p.tx = C.clamp_(p.dx, -HW + AUTO_EDGE, HW - AUTO_EDGE)
	p.ty = C.clamp_(p.dy, -HL + AUTO_EDGE, HL - AUTO_EDGE)
	p.spdF = float(autoSpd[tm])
	p.sprint = bool(autoSpr[tm])


# sceglie verso e andatura del portatore umano automatico (ogni AUTO_THINK s)
func _autoDecide(p: R.Player) -> void:
	var tm := p.team
	var sa: Stili.Att = stA[tm]
	var dir: float = -1.0 if tm else 1.0
	var gy: float = dir * HL
	var dg: float = C.hyp(p.x, p.y - gy)
	var press: float = nearOpp(p.x, p.y, tm)
	var fwd: float = p.y * dir
	# punto verso cui andare
	var gx: float = p.x * 0.7 if dg > 30.0 else 0.0
	var ty: float = gy
	var spd: float = AUTO_SPD
	var spr: bool = false
	if sa.contro:
		gx = p.x * 0.4 if dg > 30.0 else 0.0
		spd = 1.0
	elif sa.poss:
		spd = AUTO_SPD_POSS
	elif sa.fasce:
		if fwd < HL - AUTO_CROSS_Y:
			gx = C.sign_(p.x if absf(p.x) > 1.0 else (1.0 if p.i % 2 else -1.0)) * (HW - 4.0)
		else: # arrivato in fondo: si stringe un po' verso l'area e aspetta il cross del dito
			gx = C.sign_(p.x) * (BOX_W / 2.0 + 3.0)
			ty = dir * (HL - 6.0)
			spd = AUTO_SPD_CROSS
	elif sa.lanci:
		spd = AUTO_SPD_LANCI
	# compagni davanti: senza appoggi in avanti si rallenta per aspettarli (non nel contropiede)
	var ahead := 0
	for q: R.Player in players:
		if q.team == tm and q != p and not q.off and q.pos != "P" and q.y * dir > fwd - 2.0:
			ahead += 1
	if ahead < AUTO_MATES and not sa.contro:
		spd = minf(spd, AUTO_SPD_WAIT)
	var pressed: bool = press < PRESS_NEAR
	if pressed:
		spd = AUTO_SPD_SHIELD # protegge palla: va dove c'è spazio, anche di lato o indietro
	var base: float = F.atan2_(ty - p.y, gx - p.x)
	var bs: float = -1e9
	var ba: float = base
	var dgt: float = C.hyp(gx - p.x, ty - p.y)
	for k in AUTO_TRY.size():
		var o: float = AUTO_TRY[k]
		if not pressed and absf(o) > 1.3:
			continue
		var a: float = base + o
		var qx: float = p.x + F.cos_(a) * AUTO_LOOK
		var qy: float = p.y + F.sin_(a) * AUTO_LOOK
		var s2: float = (dgt - C.hyp(gx - qx, ty - qy)) * (0.6 if pressed else 1.5) + minf(nearOpp(qx, qy, tm), AUTO_SPACE) * (3.0 if pressed else 1.2) - absf(o) * 0.3
		# niente corsa addosso a un difensore: punto a meno di 2,5 m da un avversario = da evitare
		if nearOpp(qx, qy, tm) < AUTO_BUMP:
			s2 -= 4.0
		if absf(qx) > HW - AUTO_EDGE - 1.0 or absf(qy) > HL - AUTO_EDGE - 0.5:
			s2 -= 8.0
		if not pressed:
			# linee di passaggio libere dal punto (così il dito ha sempre a chi passare) e ingresso in area se c'è spazio
			s2 += _autoLanes(p, qx, qy) * AUTO_LANES
			if absf(qx) < BOX_W / 2.0 and qy * dir > HL - BOX_D and nearOpp(qx, qy, tm) > AUTO_BUMP:
				s2 += AUTO_BOX
		if s2 > bs:
			bs = s2
			ba = a
	var run: float = AUTO_RUN if spd >= AUTO_SPD else AUTO_RUN * 0.6
	p.dx = p.x + F.cos_(ba) * run
	p.dy = p.y + F.sin_(ba) * run
	if sa.contro and not pressed and nearOpp(p.dx, p.dy, tm) > AUTO_SPACE:
		spr = true # strada libera verso la porta: di corsa
	autoSpd[tm] = spd
	autoSpr[tm] = spr


# compagni (portiere escluso) raggiungibili da (x, y) con un passaggio rasoterra a linea libera
func _autoLanes(p: R.Player, x: float, y: float) -> int:
	var n := 0
	for m: R.Player in players:
		if m.team == p.team and m != p and not m.off and m.pos != "P" and C.hyp(m.x - x, m.y - y) < 30.0 and lane(x, y, m.x, m.y, p.team, 16.0) > 0.0:
			n += 1
	return n


func gkAI(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var own: float = -dir * HL
	if phase == "restart":
		p.tx = 0.0
		p.ty = own + dir * (9.0 if restart.team == tm else 1.2)
		return
	var s := b.shot
	if s != null and s.team != tm:
		p.ty = own + dir * 0.6
		if human[tm] and not autoGk[tm]:
			p.tx = s.gx0 + C.clamp_(s.cx - s.gx0, -0.9, 0.9)
			return
		if not p.decided:
			p.reactT -= dtT
			p.tx = p.x
			if p.reactT <= 0.0:
				p.decided = true
				if absf(s.cx - p.x) > 1.0 or s.ch > 2.0:
					startDive(p, s.cx, s.ch)
		else:
			p.tx = C.clamp_(s.cx, -GW / 2.0, GW / 2.0)
		return
	var ch: R.Chase = chase[tm]
	if b.owner == null and ch != null and ch.p == p:
		p.tx = ch.x
		p.ty = ch.y
		return
	if att == tm:
		p.tx = b.x * 0.1
		p.ty = own + dir * C.clamp_((b.y * dir + HL) * 0.22, 3.0, 16.0)
		return
	var vx: float = b.x
	var vy: float = b.y - own
	var d: float = C.orf(C.hyp(vx, vy), 1.0)
	var out_: float = C.clamp_(d * 0.09, 0.8, 4.5)
	if b.owner == null and b.kick != null and b.kick.type == "loft" and b.kick.team != tm:
		out_ = minf(out_, GK_CROSS_OUT) # cross su cui non esce: resta tra i pali per il colpo di testa
	if b.owner != null and d < 16.0:
		var nd: float = 99.0
		var c := b.owner
		for q: R.Player in players:
			if q.team == tm and q != p and not q.off:
				nd = minf(nd, C.hyp(q.x - c.x, q.y - c.y))
		if nd > 3.0:
			out_ = C.clamp_(d - 3.0, 1.0, 8.0)
	p.tx = C.clamp_(vx / d * out_, -GW / 2.0 - 1.0, GW / 2.0 + 1.0)
	p.ty = own + vy / d * out_


func startDive(p: R.Player, tx: float, th: float) -> void:
	p.state = "dive"
	p.t = 0.0
	p.vx = 0.0
	p.vy = 0.0
	var tt: float = C.clamp_(tx, -GW / 2.0 - 0.9, GW / 2.0 + 0.9)
	var dv := R.Dive.new()
	dv.tx = tt
	dv.th = C.clamp_(th, 0.15, 2.7)
	dv.hx = p.x
	dv.hh = 1.1
	dv.x0 = p.x
	dv.dirx = 1.0 if tt >= p.x else -1.0
	p.dive = dv
	ev("dive", {"p": p})
