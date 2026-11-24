# Parata col fermatempo (Luis 2026-11-23: "poter dire al portiere precisamente dove andare, timer di 3 secondi per
# decidere dove parare" e "per il portiere non si capisce dove va il tiro").
# Sul tiro avversario contro la squadra umana (portiere non automatico) il gioco ferma il tempo per qualche secondo vero
# (scripts/partita/fermatempo_parata.gd) e mostra sulla porta un BERSAGLIO: un'ellisse che contiene di sicuro il punto
# dove il pallone passerà la linea di porta, ma il cui centro non coincide con quel punto (scostamento col seme). È più
# grande se il tiratore è bravo e il tiro è forte, più piccola se il tiro è debole (paraMark). La persona disegna dal
# portiere al punto dove vuole andare: quel punto è rispettato esattamente (userDive → paraAim). Il portiere si sposta
# verso di lui di corsa e si tuffa al momento giusto (quando al pallone manca PARA_LEAD, o prima se serve per arrivarci):
# quanto ci arriva dipende dalla sua bravura (velocità del tuffo) e dal tempo che resta, come prima.
# Finito il fermatempo senza linea (paraExpire) il portiere fa da solo: dopo il suo tempo di reazione va verso il centro
# del bersaglio (quello che "legge" lui), con il tuffo segnato auto (l'allenamento non lo conta).
# Solo con l'opzione "parata" della partita (paraCtl, la accende il gioco): senza, il motore resta identico a prima
# (confronti col JS). Nessun numero casuale del generatore della partita: lo scostamento usa un generatore a parte
# con un seme ricavato da quello della partita, così la partita resta ripetibile e uguale con o senza bersaglio.
extends "attacco.gd"

const PARA_LEAD := 0.45      # il tuffo parte quando al pallone mancano tanti secondi di partita ...
const PARA_MARGIN := 0.12    # ... o prima, se alla mano serve più tempo per arrivare al punto (s in più)
const PARA_STEP := 0.6       # mentre aspetta, il portiere fa al massimo tanti metri di passi verso il punto (il resto col tuffo)
# Limiti veri (Luis 2026-11-23: "non tutti i tiri devono essere parabili"): il punto scelto vale come direzione, ma il
# portiere si ferma dove arriva. Spostamento a passi laterali (non di corsa) e tuffo lungo al massimo tanto
const PARA_SHUFFLE_K := 0.25 # passi laterali mentre aspetta: velocità = velocità massima × tanto
const PARA_DIVE_MAX := 1.2   # la mano arriva al massimo a tanti metri di lato da dove era il portiere al tiro (m) ...
const PARA_DIVE_POR := 0.007 # ... più tanto per ogni punto di bravura da portiere (por 70 → 1,7 m; la presa arriva ~0,85 m oltre la mano)
const PARA_R_MIN := 0.45     # raggio orizzontale del bersaglio: minimo (m) ...
const PARA_R_TIR := 0.6      # ... più tanto per un tiratore da 100 di tiro ...
const PARA_R_V := 0.5        # ... più tanto per un tiro forte
const PARA_V_LO := 15.0      # velocità del tiro (m/s) sotto cui non allarga il bersaglio ...
const PARA_V_HI := 32.0      # ... e sopra cui lo allarga del tutto
const PARA_RH_K := 0.6       # raggio verticale = raggio orizzontale × tanto (la porta è bassa)
const PARA_OFF_MAX := 0.7    # il centro si sposta dal punto vero al massimo di tanto (frazione del raggio): lo contiene sempre
const PARA_TIR_DEF := 60.0   # bravura di tiro se non si sa chi ha tirato
const PARA_SEED_K := 2654435761  # mescola il seme della partita per il generatore del bersaglio
const PARA_N_K := 40503
const PARA_X_K := 997
const PARA_VOLO_STEPS := 240 # scia del volo: al massimo tanti passi da 1/60 s ...
const PARA_VOLO_OGNI := 2    # ... un punto ogni tanti passi

var paraCtl: bool = false     # opzione "parata" della partita
var paraSeed: int = 1         # seme della partita (per lo scostamento del bersaglio)
var paraN: int = 0            # tiri contati per il bersaglio (cambiano lo scostamento)
var paraShot: R.Shot = null   # tiro seguito adesso
var paraAge: float = 0.0      # tempo di partita da quando è partito (s)
var paraAim: Array = [null, null]   # per squadra: {x, h, wait} punto scelto (wait = reazione che resta, s)
var paraExp: Array = [false, false] # per squadra: fermatempo finito senza linea (il portiere fa da solo)


## si può parare: tiro avversario in volo verso la porta della squadra T, portiere in piedi (come il web)
func diveWin(tm: int) -> bool:
	var b := ball
	var g := gk(tm)
	return bool(human[tm]) and phase == "play" and b.shot != null and b.shot.team != tm and b.owner == null and g.state == "play"


## la persona ha disegnato dal portiere: dxm = spostamento del punto dal portiere (m), th = altezza (m).
## Con l'opzione "parata" il punto si ricorda e il tuffo parte al momento giusto (updatePara); senza, subito (come prima)
func userDive(tm: int, dxm: float, th: float) -> bool:
	if not diveWin(tm):
		return false
	var g := gk(tm)
	if paraOn(tm):
		_paraSync()
		if paraExp[tm]:
			return false # fermatempo finito: il portiere sta già facendo da solo
		paraAim[tm] = {"x": g.x + dxm, "h": th, "wait": 0.0}
		ev("para_aim", {"team": tm, "x": g.x + dxm, "h": th})
		_paraTry(tm)
		return true
	startDive(g, g.x + dxm, th)
	return true


## la parata col fermatempo vale per la squadra T (umana, portiere non automatico, opzione accesa)
func paraOn(tm: int) -> bool:
	return paraCtl and bool(human[tm]) and not bool(autoGk[tm])


## fermatempo della parata aperto per la squadra T, in attesa della linea
func paraFor(tm: int) -> bool:
	return paraOn(tm) and diveWin(tm) and paraAim[tm] == null and not paraExp[tm]


## bersaglio del tiro in arrivo sulla porta della squadra T: {x, h, rx, rh} (vuoto se non c'è)
func paraArea(tm: int) -> Dictionary:
	var s := ball.shot
	if s == null or s.team == tm:
		return {}
	return s.area


## tempo di partita che manca al pallone sulla linea di porta (s)
func paraLeft() -> float:
	return maxf(0.0, paraShot.tc - paraAge) if paraShot != null else 0.0


## tempo del fermatempo finito senza linea (lo decide il gioco): il portiere fa da solo, verso il centro del bersaglio,
## dopo il suo tempo di reazione
func paraExpire(tm: int) -> void:
	_paraSync()
	if not paraFor(tm):
		return
	paraExp[tm] = true
	var a := paraArea(tm)
	var s := ball.shot
	var g := gk(tm)
	paraAim[tm] = {"x": float(a.get("x", s.cx)), "h": float(a.get("h", s.ch)), "wait": maxf(0.0, g.reactT), "auto": true}
	ev("para_auto", {"team": tm})


## bersaglio del tiro appena partito (dalla partita in detectShot): ellisse sulla linea di porta che contiene il punto
## vero (cx, ch); raggio secondo la bravura di chi tira e la forza del tiro, centro spostato col seme
func paraMark(sh: R.Shot) -> void:
	var b := ball
	var k := b.kick
	var tir: float = k.kicker.st.tir if (k != null and k.kicker != null) else PARA_TIR_DEF
	var v: float = C.hyp3(b.vx, b.vy, b.vh)
	sh.area = paraAreaFor(sh.cx, sh.ch, tir, v, _paraRng(sh.cx))
	paraN += 1


## bersaglio per il punto vero (cx, ch), bravura di tiro `tir` (0..100), velocità `v` (m/s), generatore `r`
static func paraAreaFor(cx: float, ch: float, tir: float, v: float, r: SimRngScript) -> Dictionary:
	var kv: float = C.clamp_((v - PARA_V_LO) / (PARA_V_HI - PARA_V_LO), 0.0, 1.0)
	var rx: float = PARA_R_MIN + PARA_R_TIR * C.clamp_(tir, 0.0, 100.0) / 100.0 + PARA_R_V * kv
	var rh: float = rx * PARA_RH_K
	var f: float = PARA_OFF_MAX * r.next()
	var a: float = TAU * r.next()
	return {"x": cx + cos(a) * f * rx, "h": ch + sin(a) * f * rh, "rx": rx, "rh": rh}


## true se il punto (x, h) sta dentro il bersaglio `a`
static func paraInArea(a: Dictionary, x: float, h: float) -> bool:
	var u: float = (x - float(a.x)) / float(a.rx)
	var w: float = (h - float(a.h)) / float(a.rh)
	return u * u + w * w <= 1.0


func _paraRng(cx: float) -> SimRngScript:
	var h: int = (paraSeed * PARA_SEED_K + paraN * PARA_N_K + int(absf(cx) * PARA_X_K)) & SimRngScript.M32
	return SimRngScript.new(h if h != 0 else 1)


## scia del volo previsto dal pallone fino al bersaglio, per la squadra T: punti {x, y, h}. È il volo vero, piegato
## piano piano (niente all'inizio, tutto alla fine) così finisce al centro del bersaglio e non svela il punto vero
func paraVolo(tm: int) -> Array:
	var a := paraArea(tm)
	if a.is_empty():
		return []
	var s := ball.physCopy()
	var raw: Array = [{"x": s.x, "y": s.y, "h": s.h}]
	for i in PARA_VOLO_STEPS:
		var py: float = s.y
		var px: float = s.x
		var ph: float = s.h
		C.ballPhys(s, 1.0 / 60.0, roll)
		if absf(s.y) >= HL:
			var f: float = (HL - absf(py)) / C.orf(absf(s.y) - absf(py), 1e-6)
			raw.append({"x": px + (s.x - px) * f, "y": signf(s.y) * HL, "h": ph + (s.h - ph) * f})
			break
		if (i + 1) % PARA_VOLO_OGNI == 0:
			raw.append({"x": s.x, "y": s.y, "h": s.h})
	var fine: Dictionary = raw[raw.size() - 1]
	if absf(float(fine.y)) < HL - 0.01:
		return raw # non arriva alla porta (non dovrebbe succedere): volo vero
	var ex: float = float(a.x) - float(fine.x)
	var eh: float = float(a.h) - float(fine.h)
	var n: int = raw.size() - 1
	var out_: Array = []
	for i in raw.size():
		var q: Dictionary = raw[i]
		var k: float = float(i) / float(maxi(1, n))
		out_.append({"x": float(q.x) + ex * k, "y": q.y, "h": maxf(0.0, float(q.h) + eh * k)})
	return out_


## a ogni passo (dalla partita): segue il tiro in volo e fa partire il tuffo verso il punto scelto al momento giusto
func updatePara(dt: float) -> void:
	if not paraCtl:
		return
	if _paraSync():
		return
	if paraShot == null:
		return
	paraAge += dt
	for tm in 2:
		var am: Variant = paraAim[tm]
		if am == null:
			continue
		if not diveWin(tm):
			paraAim[tm] = null # tuffo partito, pallone preso o deviato
			continue
		if float(am.wait) > 0.0:
			am.wait = float(am.wait) - dt
			continue
		_paraTry(tm)


## segue il tiro in volo: se è cambiato riparte da capo (niente punto scelto). true se è cambiato
func _paraSync() -> bool:
	var s := ball.shot
	if s == paraShot:
		return false
	paraShot = s
	paraAge = 0.0
	paraAim = [null, null]
	paraExp = [false, false]
	return true


## tuffo verso il punto scelto se è ora: al pallone manca PARA_LEAD, o meno del tempo che serve alla mano per arrivarci
func _paraTry(tm: int) -> void:
	var am: Variant = paraAim[tm]
	if am == null or float(am.wait) > 0.0 or not diveWin(tm):
		return
	var g := gk(tm)
	var x0: float = paraShot.gx0 if paraShot != null else g.x
	var tx: float = paraReachX(x0, g.st.por, float(am.x))
	var need: float = absf(tx - g.x) / (GK_HUMAN_SPEED + g.st.por * 0.03) + PARA_MARGIN
	if paraLeft() > maxf(PARA_LEAD, need):
		return
	var auto: bool = bool(am.get("auto", false))
	paraAim[tm] = null
	startDive(g, tx, float(am.h))
	g.dive.auto = auto
	if auto and not events.is_empty() and events[-1].type == "dive":
		events[-1]["auto"] = true


## x dove il portiere (che era in x0 quando è partito il tiro, bravura `por`) può portare la mano verso il punto x:
## nella direzione scelta, ma non oltre passi e tuffo più lungo (PARA_DIVE_MAX + bravura), passi compresi
static func paraReachX(x0: float, por: float, x: float) -> float:
	var lim: float = PARA_DIVE_MAX + por * PARA_DIVE_POR
	return C.clamp_(x0 + C.clamp_(x - x0, -lim, lim), -GW / 2.0 - 0.9, GW / 2.0 + 0.9)


## portiere della squadra umana col punto scelto: va a passi laterali verso di lui (al massimo PARA_STEP, il resto col tuffo)
func gkAI(p: R.Player) -> void:
	var tm := p.team
	var am: Variant = paraAim[tm] if paraCtl else null
	var s := ball.shot
	if am == null or float(am.wait) > 0.0 or s == null or s.team == tm or phase != "play":
		super(p)
		return
	var dir: float = -1.0 if tm else 1.0
	var tx: float = float(am.x)
	p.tx = C.clamp_(s.gx0 + C.clamp_(tx - s.gx0, -PARA_STEP, PARA_STEP), -GW / 2.0, GW / 2.0)
	p.ty = -dir * HL + dir * 0.6
	p.sprint = false
	p.spdF = PARA_SHUFFLE_K
