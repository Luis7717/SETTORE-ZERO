# Fase d'attacco della CPU e dei compagni CPU della persona (solo Godot, opzione "attacco" del Match: la accende il
# gioco; spenta nei confronti col JS e nei test vecchi, che restano identici). Dallo studio degli stili del 2026-11-24
# (tools/studio_stili.gd): nessuno entrava in area, nessun fuorigioco, contropiede basso in attacco invece che in difesa,
# fasce con tre giocatori sulla riga, lanci lunghi e contropiede troppo simili, terzino ed esterno sulla stessa riga.
#  1) attacchi all'area: col pallone nostro sulla trequarti o sulla fascia 1-2 compagni (punte, poi centrocampisti)
#     vanno verso il primo e il secondo palo; aspettano sulla linea del fuorigioco e quando parte il cross entrano di
#     corsa. Il portatore della CPU crossa anche verso chi sta arrivando (non solo verso chi è già in area);
#  2) fuorigioco: ogni tanto un attaccante della CPU anticipa il taglio oltre la linea e a volte il passaggio parte lo
#     stesso (fischio). Più spesso con più spazio dietro la difesa, contro il Fuorigioco e con squadre meno brave;
#  3) contropiede: in attacco non più bassa (prima CONTRO_LOW la abbassava quando attaccava), in difesa bassa e
#     stretta; nella ripartenza centrocampisti e punte salgono di corsa;
#  4) fasce: terzino in sovrapposizione sulla fascia del pallone (l'esterno davanti si stringe), mezzala del 4-3-3
#     non sulla riga se c'è già l'ala; cross anche verso chi arriva (punto 1);
#  5) contropiede palla a terra (meno pallonetti), lanci lunghi con più lanci alti;
#  6) terzino ed esterno sulla stessa fascia sfalsati: il più arretrato un po' più dentro.
# Tutto in metodi che ridefiniscono quelli di ai.gd/base.gd e chiamano super(): con l'opzione spenta niente cambia.
extends "ai.gd"

# 1) attacchi all'area
const RUN_FROM := 0.6          # pallone oltre questa frazione del campo (dalla nostra linea di fondo): un compagno attacca l'area
const RUN_TWO_FROM := 0.75     # ... oltre questa: due
const RUN_WIDE_X := 14.0       # pallone sulla fascia (|x| oltre questo) ...
const RUN_WIDE_FROM := 0.5     # ... già da qui uno ...
const RUN_WIDE_TWO := 0.62     # ... e da qui due
const RUN_MID := 8.0           # un centrocampista conta come più lontano di così dall'area (si preferiscono le punte, m)
const RUN_KEEP := 6.0          # chi sta già correndo conta come più vicino di così: niente scambi continui (m)
const RUN_NEAR := [3.5, 6.0]   # primo palo: metri dal centro verso il lato del pallone, metri dalla linea di fondo
const RUN_FAR := [4.5, 8.5]    # secondo palo: metri dal centro dal lato opposto, metri dalla linea di fondo
const RUN_ONE := [1.0, 11.0]   # un solo compagno: verso il dischetto
const RUN_SPRINT := 4.0        # corsa all'area di corsa se manca più di tanto (m) e il cross è possibile o in volo
const RUN_CARRIER := 4.0       # niente punto d'arrivo addosso al portatore (m)
const CROSS2_X := 12.0         # cross verso chi arriva: portatore oltre questa |x| ...
const CROSS2_Y := 30.0         # ... ed entro tanti metri dalla linea di fondo (con le Fasce + FASCE_CROSS_X/Y)
const CROSS2_FREE := 1.5       # spazio libero richiesto sul punto d'arrivo (Fasce: FASCE_CROSS_FREE)
const CROSS2_LATE := 0.6       # chi arriva può arrivare fino a tanto dopo il pallone (s)
const CROSS2_MIN := 8.0        # cross più corti di così no (m)
# 2) fuorigioco
const GAMBLE_RATE := 0.3       # volte al secondo che un attaccante della CPU vicino alla linea anticipa il taglio (bravura 0,5, spazio normale)
const GAMBLE_T := 2.0          # durata del taglio anticipato (s)
const GAMBLE_OVER := 2.0       # quanto oltre la linea del fuorigioco (m)
const GAMBLE_FROM := -10.0     # solo col pallone da qui in avanti (m nel verso d'attacco)
const GAMBLE_SPACE := 25.0     # spazio dietro la difesa "normale" (m): più spazio = più tagli
const GAMBLE_TRAP := 1.4       # contro la difesa Fuorigioco (linea che sale insieme) più tagli
const GAMBLE_MISREAD := 0.8    # il portatore della CPU non vede che il compagno è oltre la linea (per decisione)
const GAMBLE_PULL := 1.0       # ... e il passaggio verso chi taglia lo tenta: preferenza in più
const GAMBLE_SAFE := 0.4       # ... e lo crede sicuro (così lo gioca davvero)
const GAMBLE_SEE := 3.0        # ... solo se il compagno è oltre di meno di così (m)
const GAMBLE_DRIFT := 0.25     # punta rimasta appena oltre la linea senza taglio: il portatore sbaglia meno spesso ...
const GAMBLE_DRIFT_SEE := 1.5  # ... e solo se è oltre di meno di così (m)
const GAMBLE_NEAR := 4.0       # il taglio parte solo da vicino alla linea (entro tanti metri, m)
# 3) contropiede
const CONTRO_ATT_D := -0.03    # in attacco solo i difensori restano un po' più bassi (frazione del campo)
const CONTRO_DEF := -0.04      # in difesa tutta la squadra più bassa ...
const CONTRO_NARROW := 0.93    # ... e più stretta
const CONTRO_RUN := 6.0        # nella ripartenza si sale di corsa se il posto è più avanti di tanto (m)
# 4) e 6) fasce
const STAGGER := 0.8           # il più arretrato dei due esterni sulla stessa fascia: frazione della larghezza
const OVERLAP_FROM := 0.45     # Fasce: pallone sulla fascia del terzino oltre questa frazione del campo = sovrapposizione
const OVERLAP_Y := 0.2         # ... il terzino sale di tanto (frazione del campo)
const OVERLAP_IN := 0.72       # ... e l'esterno davanti si stringe a questa frazione della larghezza
# 5) lanci lunghi e contropiede
const CONTRO_LOFT := 0.35      # pallonetto nel contropiede: preferenza in meno
const CONTRO_LOFT_GAIN := 0.8  # ... e il premio del guadagno in avanti vale così di meno per i pallonetti
const LANCI_SC2 := 0.25        # lancio alto nei Lanci lunghi: preferenza in più (oltre LANCI_SC)

var attaccoOn: bool = false
var boxRun: Array = [[], []]   # chi attacca l'area, per squadra (il primo è il più vicino)
var gambleT: Dictionary = {}   # indice del giocatore (team * 11 + i) -> secondi di taglio anticipato che restano


# ------------------------------------------------------------ 3), 4), 6): posti in campo
func anchor(p: R.Player) -> PackedFloat64Array:
	var r := super(p)
	if not attaccoOn or p.pos == "P":
		return r
	var tm := p.team
	var sa: Stili.Att = stA[tm]
	var dir: float = -1.0 if tm else 1.0
	var ayf: float = r[1] / (L * dir) + 0.5
	var dy: float = 0.0
	if att == tm:
		if sa.contro and p.pos != "A":
			dy += -Stili.CONTRO_LOW + (CONTRO_ATT_D if p.pos == "D" else 0.0)
		var sgn: float = C.sign_(p.bx)
		if absf(p.bx) > 0.6:
			var bside: bool = ball.x * sgn > 2.0 and (ball.y * dir + HL) / L > OVERLAP_FROM
			if _wideMate(p, 1.0) != null:
				if sa.fasce and bside:
					dy += OVERLAP_Y # sovrapposizione: il terzino sale largo
				else:
					r[0] = sgn * (HW - WIDE_GAP) * STAGGER # due sulla stessa riga: il più arretrato un po' dentro
			elif sa.fasce and bside and _wideMate(p, -1.0) != null:
				r[0] = sgn * (HW - WIDE_GAP) * OVERLAP_IN # il terzino si sovrappone: l'esterno si stringe
		elif sa.fasce and p.pos == "C" and absf(p.bx) > Stili.FASCE_WIDE_C and _wideMate(p, 1.0) != null:
			r[0] = C.clamp_(p.bx + ball.x / HW * 0.15, -0.95, 0.95) * HW * 0.94 # c'è già l'ala sulla riga: la mezzala resta dentro
	elif sa.contro and not stD[tm].catenaccio:
		dy += CONTRO_DEF
		r[0] *= CONTRO_NARROW
	if dy != 0.0:
		r[1] = (C.clamp_(ayf + dy, 0.04, 0.96) - 0.5) * L * dir
	return r


# ganci per le istruzioni dei giocatori (istruzioni_gioco.gd): qui non cambiano niente
## metri in più (o in meno) nella scelta di chi attacca l'area
func istrRunBias(_q: R.Player) -> float:
	return 0.0


## quante volte più spesso p anticipa il taglio oltre la linea
func istrGambleK(_p: R.Player) -> float:
	return 1.0


# compagno esterno (|bx| > 0,6) sulla stessa fascia di p, più avanti (side 1) o più indietro (side -1) nella formazione
func _wideMate(p: R.Player, side: float) -> R.Player:
	var sgn: float = C.sign_(p.bx)
	for q: R.Player in players:
		if q.team == p.team and q != p and not q.off and q.pos != "P" and absf(q.bx) > 0.6 and C.sign_(q.bx) == sgn and (q.by - p.by) * side > 0.05:
			return q
	return null


# ------------------------------------------------------------ 1): chi attacca l'area
func computeChasers() -> void:
	super()
	if attaccoOn:
		_computeBoxRuns()


func _computeBoxRuns() -> void:
	var b := ball
	for tm in 2:
		var c := b.owner
		if c == null:
			if b.kick == null or b.kick.team != tm or phase != "play":
				boxRun[tm] = []
			continue # nostro passaggio (o cross) in volo: chi corre continua la corsa
		if c.team != tm or phase != "play":
			boxRun[tm] = []
			continue
		var dir: float = -1.0 if tm else 1.0
		var bf: float = (b.y * dir + HL) / L
		var wide: bool = absf(b.x) > RUN_WIDE_X
		var n: int = 0
		if bf > RUN_TWO_FROM or (wide and bf > RUN_WIDE_TWO):
			n = 2
		elif bf > RUN_FROM or (wide and bf > RUN_WIDE_FROM):
			n = 1
		if n == 0:
			boxRun[tm] = []
			continue
		var was: Array = boxRun[tm]
		var hl: Array = helpers[tm]
		var gy: float = dir * HL
		var cand: Array = []
		for q: R.Player in players:
			if q.team == tm and q != c and not q.off and (q.pos == "A" or q.pos == "C") and q.state == "play" and not hl.has(q):
				cand.append(q)
		cand = stableSort(cand, func(q: R.Player) -> float: return C.hyp(q.x, q.y - gy) + (0.0 if q.pos == "A" else RUN_MID) - (RUN_KEEP if was.has(q) else 0.0) + istrRunBias(q))
		boxRun[tm] = cand.slice(0, n)


# punto d'arrivo della corsa in area di m (primo palo, secondo palo o, se corre da solo, verso il dischetto)
func _runSpot(m: R.Player) -> PackedFloat64Array:
	var b := ball
	var tm := m.team
	var dir: float = -1.0 if tm else 1.0
	var gy: float = dir * HL
	var s: float = -1.0 if b.x < 0.0 else 1.0
	var rs: Array = boxRun[tm]
	if rs.size() < 2:
		return PackedFloat64Array([s * RUN_ONE[0], gy - dir * RUN_ONE[1]])
	var other: R.Player = rs[1] if rs[0] == m else rs[0]
	var nx: float = s * RUN_NEAR[0]
	var near: bool = absf(m.x - nx) < absf(other.x - nx) or (absf(m.x - nx) == absf(other.x - nx) and rs[0] == m)
	if near:
		return PackedFloat64Array([nx, gy - dir * RUN_NEAR[1]])
	return PackedFloat64Array([-s * RUN_FAR[0], gy - dir * RUN_FAR[1]])


# il cross verso l'area è possibile: portatore largo e vicino alla linea di fondo
func _crossZone(tm: int, ox: float, oy: float) -> bool:
	var dir: float = -1.0 if tm else 1.0
	var fz: bool = stA[tm].fasce
	return absf(ox) > (CROSS2_X - Stili.FASCE_CROSS_X if fz else CROSS2_X) and oy * dir > HL - (CROSS2_Y + Stili.FASCE_CROSS_Y if fz else CROSS2_Y)


func support(p: R.Player) -> void:
	super(p)
	if not attaccoOn or phase != "play":
		return
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	if b.owner != null and b.owner.team == tm and helpers[tm].has(p):
		return # d'appoggio al portatore: resta quello che ha scelto offerSupport
	if boxRun[tm].has(p):
		_boxRunTo(p)
	if not human[tm] and (p.pos == "A" or boxRun[tm].has(p)):
		_gamble(p)
	if stA[tm].contro and counter(tm) and p.pos != "D" and (p.ty - p.y) * dir > CONTRO_RUN:
		p.sprint = true # contropiede: si riparte di corsa


# corsa verso il primo o il secondo palo: sulla linea del fuorigioco finché il pallone è del portatore, dentro l'area
# appena parte il nostro passaggio
func _boxRunTo(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var sp := _runSpot(p)
	var tx: float = sp[0]
	var ty: float = sp[1]
	var c := b.owner
	if c != null and C.hyp(tx - c.x, ty - c.y) < RUN_CARRIER:
		return
	var flight: bool = c == null and b.kick != null and b.kick.team == tm
	if not flight:
		var cap: float = maxf(offLine[tm] - 0.8, b.y * dir)
		if ty * dir > cap:
			ty = cap * dir
	p.tx = C.clamp_(tx, -HW + 1.0, HW - 1.0)
	p.ty = C.clamp_(ty, -HL + 1.0, HL - 1.0)
	if C.hyp(p.tx - p.x, p.ty - p.y) > RUN_SPRINT and (flight or (c != null and _crossZone(tm, c.x, c.y))):
		p.sprint = true


# ------------------------------------------------------------ 2): taglio anticipato (fuorigioco)
func _gamble(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var key: int = tm * 11 + p.i
	var t: float = float(gambleT.get(key, 0.0)) - dtT
	var c := b.owner
	if c == null or c.team != tm or b.y * dir < GAMBLE_FROM:
		gambleT[key] = minf(t, 0.0)
		return
	var line: float = maxf(offLine[tm], b.y * dir)
	if t <= 0.0 and p.y * dir > line - GAMBLE_NEAR:
		var sk: float = teams[tm].skill
		var space: float = C.clamp_((HL - line) / GAMBLE_SPACE, 0.3, 1.6)
		var rate: float = GAMBLE_RATE * (1.5 - sk) * space * (GAMBLE_TRAP if stD[1 - tm].fuorigioco else 1.0) * istrGambleK(p)
		if rnd() < rate * dtT:
			t = GAMBLE_T
	gambleT[key] = t
	if t > 0.0 and line + GAMBLE_OVER < HL - 6.0:
		p.ty = (line + GAMBLE_OVER) * dir
		p.sprint = true


func _gambling(p: R.Player) -> bool:
	return float(gambleT.get(p.team * 11 + p.i, 0.0)) > 0.0


# ------------------------------------------------------------ 1) e 2): scelta del passaggio
func passOptions(p: R.Player, exempt: bool = false) -> Variant:
	var best: Variant = super(p, exempt)
	if not attaccoOn:
		return best
	best = _crossToRunners(p, best)
	if not human[p.team] and not exempt:
		best = _misread(p, best)
	return best


# cross verso un compagno che sta arrivando in area (in gioco adesso, arriva sul punto entro il volo del pallone)
func _crossToRunners(p: R.Player, best: Variant) -> Variant:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var gy: float = dir * HL
	var ox: float = b.x if b.owner == p else p.x
	var oy: float = b.y if b.owner == p else p.y
	if not _crossZone(tm, ox, oy):
		return best
	var fz: bool = stA[tm].fasce
	var lim: float = maxf(offLine[tm], b.y * dir)
	for m: R.Player in boxRun[tm]:
		if m == p or m.off or m.y * dir > lim + 0.2:
			continue
		var sp := _runSpot(m)
		var d: float = C.hyp(sp[0] - ox, sp[1] - oy)
		if d < CROSS2_MIN:
			continue
		var tl: float = C.clamp_(d / 14.0, 0.75, 2.6)
		var tr: float = maxf(0.0, C.hyp(m.x - sp[0], m.y - sp[1]) - 0.8) / vmax(m)
		if tr > tl + CROSS2_LATE or nearOpp(sp[0], sp[1], tm) < (Stili.FASCE_CROSS_FREE if fz else CROSS2_FREE):
			continue
		var sc: float = 1.1 + (rnd() - 0.5) * 0.5 - C.hyp(sp[0], sp[1] - gy) * 0.03 + (Stili.FASCE_CROSS_SC if fz else 0.0)
		if best == null or sc > best.sc:
			best = {"m": m, "tx": sp[0], "ty": sp[1], "type": "loft", "sc": sc, "safe": 0.5, "d": d, "gain": 8.0, "cross": true}
	return best


# il portatore della CPU non vede che il compagno è appena oltre la linea (taglio anticipato, o punta rimasta oltre):
# passaggio lo stesso, e l'arbitro fischia il fuorigioco
func _misread(p: R.Player, best: Variant) -> Variant:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var gy: float = dir * HL
	var ox: float = b.x if b.owner == p else p.x
	var oy: float = b.y if b.owner == p else p.y
	var lim: float = maxf(offLine[tm], oy * dir)
	for m: R.Player in players:
		if m.team != tm or m == p or m.off or m.pos == "P":
			continue
		var g: bool = _gambling(m)
		if not g and m.pos != "A":
			continue
		var over: float = m.y * dir - lim
		if over < 0.3 or over > (GAMBLE_SEE if g else GAMBLE_DRIFT_SEE) or m.y * dir < 0.0 or rnd() >= (GAMBLE_MISREAD if g else GAMBLE_DRIFT):
			continue
		var lead: float = 6.0 + rnd() * 4.0
		var gx: float = m.x * 0.6
		var n: float = C.orf(C.hyp(gx - m.x, gy - m.y), 1.0)
		var tx: float = m.x + (gx - m.x) / n * lead
		var ty: float = m.y + (gy - m.y) / n * lead
		var sk: float = teams[tm].skill
		# passaggio sui piedi (dove sarà fra mezzo secondo) o filtrante davanti a lui, il migliore dei due
		var o: Variant = _consider(null, p, tm, dir, gy, sk, ox, oy, m, m.x + m.vx * 0.5, m.y + m.vy * 0.5, false)
		if absf(ty) < HL - 5.0:
			o = _consider(o, p, tm, dir, gy, sk, ox, oy, m, tx, ty, true)
		if o != null:
			o.sc += GAMBLE_PULL
			o.safe = maxf(float(o.safe), GAMBLE_SAFE) # lui lo crede un passaggio sicuro
			if best == null or o.sc > best.sc:
				best = o
	return best


# ------------------------------------------------------------ 5): contropiede palla a terra, lanci lunghi più alti
func _styleScore(sa: Stili.Att, tm: int, d: float, gain: float, safe: float, type: String, through: bool) -> float:
	var s: float = super(sa, tm, d, gain, safe, type, through)
	if attaccoOn and type == "loft":
		if sa.contro and counter(tm):
			s -= gain * Stili.CONTRO_GAIN * CONTRO_LOFT_GAIN + CONTRO_LOFT
		elif sa.lanci:
			s += LANCI_SC2
	return s
