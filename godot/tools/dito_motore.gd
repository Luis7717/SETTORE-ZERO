# "Persona simulata" a livello di motore per tools/controllo_gameplay.gd: gioca la squadra 0 con gli STESSI comandi
# che i gesti mandano al motore (userKick col tratto, userQueue di prima, userDribble, userSprint, userHeader,
# userDive, userRun per le linee di difesa), con l'opzione completa del gioco (portaAuto: il portatore corre da solo,
# il dito sceglie solo passaggi e tiri). Diverso da tests/harness.gd Bot, che col pallone usa le scelte dell'IA.
# Pensa in SECONDI VERI: ha un tempo di reazione per ogni situazione e disegnare una linea dura un po' (nel gioco il
# tempo intanto rallenta, vedi velocita_voluta, copiata da scripts/partita/gioco.gd). Un giocatore "medio", non bravo:
# passa in avanti a chi è libero, crossa dalla fascia, tira in area di tiro, nel duello sceglie Dribbling o passaggio,
# nella fuga Scatto, para con un errore, ogni tanto disegna una linea di difesa. Numeri casuali col seme.
extends RefCounted

const SimRng := preload("res://sim/rng.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")

# velocità del tempo come scripts/partita/gioco.gd
const GK_SLOW := 0.1
const DEF_DRAW_SLOW := 0.13
const PASS_DRAW_SLOW := 0.04
const DUEL_SLOW := 0.08
const FLEE_SLOW := 0.08
const ZONE_SLOW := 0.1
const TESTA_FERMO_S := 3.0

const DRAW_S := [0.35, 0.6]      # secondi veri per disegnare una linea
const REACT := {                 # tempo di reazione per situazione (s veri, min-max)
	"attack": [0.35, 0.8], "zone": [0.5, 1.2], "duel": [0.5, 1.3], "flee": [0.4, 0.9], "head": [0.7, 1.6],
	"dive": [0.5, 1.1], "restart": [0.8, 1.6], "defend": [0.8, 1.8], "loose": [0.8, 1.8]}
const CHECK_S := [0.25, 0.5]     # col pallone a velocità normale: ogni quanto si guarda se passare
const PASS_GOOD := 6.0           # punteggio del passaggio sopra cui si passa senza pressione
const PRESS_R := 3.2             # avversario più vicino di così = pressato: si cerca di passare
const LONG_HOLD := 4.0           # s di gioco col pallone senza passare: si passa al migliore
const SHOT_DIST := 19.0          # in area di tiro si tira da meno di così (o prima di aspettare troppo)
const ZONE_WAIT := 1.6           # ... altrimenti si aspetta al massimo tanti secondi veri, poi si tira o si passa
const CROSS_X := 14.0            # cross dalla fascia: oltre tanto di lato ...
const CROSS_Y := 30.0            # ... entro tanto dalla linea di fondo avversaria
const DIVE_ERR := 0.6            # errore del tuffo (m, gaussiano)
const HEAD_MISS := 0.08          # quota di fermatempi in cui la persona non disegna (pallone perso)
const DEF_LINE_P := 0.45         # probabilità di disegnare una linea di difesa a ogni occasione
const PRIMA_P := 0.35            # probabilità di preparare un tiro di prima su un passaggio a un compagno in zona tiro

var r: SimRng
var tm := 0
var busy := 0.0                  # secondi veri che mancano alla fine della linea in corso
var draw_mode := ""             # "" | "draw" (calcio) | "dpath" (difesa) | "head" | "dive"
var pending := {}                # comando da mandare quando la linea finisce
var situ := ""
var react := 0.0
var held := 0.0                  # s di gioco col pallone dello stesso portatore
var held_p: R.Player = null
var zone_wait := 0.0
var conti := {"pass_raso": 0, "pass_alto_dritto": 0, "pass_curvo": 0, "cross": 0, "tiro_raso": 0, "tiro_giro": 0,
	"prima": 0, "dribbling": 0, "scatto": 0, "testa": 0, "testa_saltata": 0, "tuffo": 0, "difesa": 0, "ripresa": 0,
	"comando_rifiutato": 0}
var sub_ultimo := ""             # tipo dell'ultimo calcio della persona (per i gol per tipo)
var on_kick: Callable            # avvisa il contatore: on_kick.call(sub)


func _init(seme: int) -> void:
	r = SimRng.new(seme)


func _rng(a: Array) -> float:
	return a[0] + r.next() * (a[1] - a[0])


## velocità del tempo voluta (come gioco.velocita_voluta, più il fermatempo del colpo di testa a parte)
func velocita_voluta(m) -> float:
	if draw_mode == "dpath":
		return DEF_DRAW_SLOW
	if draw_mode == "draw":
		return PASS_DRAW_SLOW
	var dive: bool = m.diveWin(tm) and not m.autoGk[tm]
	var booked: bool = m.dribBooked(tm)
	var duel: bool = not booked and m.duelFor(tm)
	var flee: bool = not duel and m.fleeFor(tm)
	var zone: bool = not booked and not duel and not flee and m.inZone(tm)
	if dive:
		return GK_SLOW
	if duel:
		return DUEL_SLOW
	if flee:
		return FLEE_SLOW
	if zone:
		return ZONE_SLOW
	return 1.0


func _situazione(m) -> String:
	if m.headFor(tm):
		return "head"
	if m.diveWin(tm):
		return "dive"
	var h: String = m.hint(tm)
	var c: R.Player = m.ctrl[tm]
	var b: R.Ball = m.ball
	if h == "restart":
		return "restart" if (c != null and b.owner == c) else ""
	if h == "attack":
		if c == null or b.owner != c:
			return ""
		if m.dribBooked(tm):
			return "booked"
		if m.duelFor(tm):
			return "duel"
		if m.fleeFor(tm):
			return "flee"
		if m.inZone(tm):
			return "zone"
		return "attack"
	return h # defend, loose, wait, ""


## un fotogramma vero (1/60 s): continua la linea in corso o decide
func passo(m, dt_reale: float, dt_gioco: float) -> void:
	var b: R.Ball = m.ball
	if b.owner != null and b.owner == m.ctrl[tm]:
		if held_p != b.owner:
			held_p = b.owner
			held = 0.0
		held += dt_gioco
	else:
		held_p = null
	if busy > 0.0:
		busy -= dt_reale
		if busy <= 0.0:
			_manda(m)
		return
	var s := _situazione(m)
	if s != situ:
		situ = s
		react = _rng(REACT[s]) if REACT.has(s) else 0.3
		zone_wait = 0.0
	if s == "zone":
		zone_wait += dt_reale
	react -= dt_reale
	if react > 0.0:
		return
	match s:
		"head":
			_testa(m)
		"dive":
			_tuffo(m)
		"restart":
			_ripresa(m)
		"duel":
			_duello(m)
		"flee":
			_fuga(m)
		"zone":
			_zona(m)
		"attack":
			_attacco(m)
		"defend", "loose":
			_difesa(m)
	# nuova occhiata tra poco (le azioni con linea mettono busy e ripartono da capo alla fine)
	if react <= 0.0:
		react = _rng(CHECK_S)


func _disegna(mode: String, cmd: Dictionary) -> void:
	draw_mode = mode
	pending = cmd
	busy = _rng(DRAW_S)


func _manda(m) -> void:
	var cmd := pending
	pending = {}
	var mode := draw_mode
	draw_mode = ""
	situ = "" # ricomincia a guardare (nuovo tempo di reazione)
	var ok := false
	match String(cmd.get("k", "")):
		"kick":
			ok = m.userKick(tm, cmd.spec)
			if ok:
				sub_ultimo = cmd.sub
				conti[cmd.sub] += 1
				if on_kick.is_valid():
					on_kick.call(cmd.sub)
				if cmd.has("prima_q") and r.next() < PRIMA_P:
					_prima(m, cmd.prima_q)
		"queue":
			ok = m.userQueue(tm, cmd.p, cmd.spec)
			if ok:
				conti.prima += 1
		"head":
			ok = m.userHeader(tm, cmd.spec)
			if ok:
				conti.testa += 1
				sub_ultimo = "testa"
		"dive":
			ok = m.userDive(tm, cmd.dx, cmd.th)
			if ok:
				conti.tuffo += 1
		"run":
			ok = m.userRun(tm, cmd.p, cmd.pts)
			if ok:
				conti.difesa += 1
	if not ok and mode != "":
		conti.comando_rifiutato += 1


# ------------------------------------------------------------------ scelte
func _dir() -> float:
	return 1.0 if tm == 0 else -1.0


## miglior passaggio: {q, tx, ty, score, d, libero} o {}
func _miglior_passaggio(m, c: R.Player, solo_avanti: bool = false) -> Dictionary:
	var b: R.Ball = m.ball
	var dir := _dir()
	var off_y: float = m.offsideY(tm) * dir
	var best := {}
	for q: R.Player in m.team(tm):
		if q == c or q.off or q.pos == "P":
			continue
		var tx: float = q.x + q.vx * 0.4
		var ty: float = q.y + q.vy * 0.4
		var d := C.hyp(tx - b.x, ty - b.y)
		if d < 5.0 or d > 42.0:
			continue
		if q.y * dir > off_y + 0.2 and q.y * dir > 0.0:
			continue # in fuorigioco: la persona vede la linea nell'anteprima
		var gain := (ty - b.y) * dir
		if solo_avanti and gain < 3.0:
			continue
		var libero: bool = m.lane(b.x, b.y, tx, ty, tm, 16.0) > 0.0
		var spazio: float = minf(m.nearOpp(tx, ty, tm), 6.0)
		var s := gain * 0.45 + spazio * 0.9 - d * 0.08 + (2.0 if libero else -1.5) + r.next() * 2.0
		if best.is_empty() or s > best.score:
			best = {"q": q, "tx": tx, "ty": ty, "score": s, "d": d, "libero": libero}
	return best


## spec del passaggio verso best: dritto e corto con la linea libera = rasoterra; altrimenti a volte curvo (alto a
## effetto), a volte dritto lungo (alto ma dritto, TRATTO_LOFT_M)
func _spec_passaggio(m, best: Dictionary) -> Dictionary:
	var b: R.Ball = m.ball
	var d: float = best.d
	var spec := {"type": "auto", "tx": best.tx, "ty": best.ty, "th": 0.0, "curve": 0.0, "tratto": true}
	var sub := "pass_raso"
	if d > 25.0 or not best.libero:
		if r.next() < 0.5:
			spec.curve = d * 0.22 * (1.0 if r.next() < 0.5 else -1.0)
			sub = "pass_curvo"
		else:
			sub = "pass_alto_dritto" if (d > 25.0 or m.blocked(b.x, b.y, best.tx, best.ty, tm)) else "pass_raso"
	return {"spec": spec, "sub": sub}


func _passa(m, best: Dictionary) -> void:
	var ps := _spec_passaggio(m, best)
	var cmd := {"k": "kick", "spec": ps.spec, "sub": ps.sub}
	var q: R.Player = best.q
	var dist_porta := C.hyp(q.x, q.y - _dir() * C.HL)
	if dist_porta < 22.0:
		cmd["prima_q"] = q
	_disegna("draw", cmd)


func _spec_tiro(m, x: float, y: float, sub_forzato := "") -> Dictionary:
	var dir := _dir()
	var gk: R.Player = m.gk(1 - tm)
	var side: float = -1.0 if gk.x > 0.0 else 1.0
	if r.next() < 0.25:
		side = -side
	var tx := side * (C.GW / 2.0 - 0.5 - r.next() * 0.9)
	var gy := dir * C.HL
	var giro := r.next() < 0.5 if sub_forzato == "" else sub_forzato == "tiro_giro"
	var D := C.hyp(tx - x, gy - y)
	var curve := 0.0
	if giro:
		curve = D * 0.2 * (1.0 if r.next() < 0.5 else -1.0)
	return {"spec": {"type": "shot", "tx": tx, "ty": gy, "th": 0.3 + r.next() * 1.6, "curve": curve, "tratto": true},
		"sub": "tiro_giro" if giro else "tiro_raso"}


func _tira(m) -> void:
	var b: R.Ball = m.ball
	var st := _spec_tiro(m, b.x, b.y)
	_disegna("draw", {"k": "kick", "spec": st.spec, "sub": st.sub})


func _prima(m, q: R.Player) -> void:
	# subito dopo il passaggio: dito sul compagno e linea in porta (si disegna mentre il pallone viaggia)
	var st := _spec_tiro(m, q.x, q.y)
	_disegna("draw", {"k": "queue", "p": q, "spec": st.spec})


func _attacco(m) -> void:
	var c: R.Player = m.ctrl[tm]
	var b: R.Ball = m.ball
	var dir := _dir()
	var fwd: float = b.y * dir
	# cross dalla fascia verso un compagno in area
	if absf(b.x) > CROSS_X and fwd > C.HL - CROSS_Y:
		var q := _in_area(m, c)
		if q != null and r.next() < 0.6:
			var tx: float = q.x + q.vx * 0.6
			var ty: float = q.y + q.vy * 0.6
			var d := C.hyp(tx - b.x, ty - b.y)
			var spec := {"type": "auto", "tx": tx, "ty": ty, "th": 0.0, "curve": d * 0.22 * signf(b.x) * dir, "tratto": true}
			_disegna("draw", {"k": "kick", "spec": spec, "sub": "cross"})
			return
	var pressato: bool = m.nearOpp(c.x, c.y, tm) < PRESS_R
	var best := _miglior_passaggio(m, c)
	if best.is_empty():
		return
	var vuole: bool = best.score > PASS_GOOD and r.next() < 0.5
	if pressato and r.next() < 0.7:
		vuole = true
	if held > LONG_HOLD:
		vuole = true
	if vuole:
		_passa(m, best)


func _in_area(m, c: R.Player) -> R.Player:
	var dir := _dir()
	var best: R.Player = null
	var bs := -INF
	for q: R.Player in m.team(tm):
		if q == c or q.off or q.pos == "P":
			continue
		if absf(q.x) < C.BOX_W / 2.0 and q.y * dir > C.HL - C.BOX_D - 2.0:
			var s: float = m.nearOpp(q.x, q.y, tm) + r.next()
			if s > bs:
				bs = s
				best = q
	return best


func _zona(m) -> void:
	var c: R.Player = m.ctrl[tm]
	var b: R.Ball = m.ball
	var dir := _dir()
	var dg := C.hyp(b.x, b.y - dir * C.HL)
	var angolo_ok := absf(b.x) < 12.0 or dg < 12.0
	if dg < SHOT_DIST and angolo_ok:
		_tira(m)
		return
	# compagno meglio piazzato (più vicino e centrale, linea libera)
	var best := _miglior_passaggio(m, c, false)
	if not best.is_empty():
		var q: R.Player = best.q
		var dq := C.hyp(q.x, q.y - dir * C.HL)
		if dq < dg - 4.0 and best.libero and absf(q.x) < 12.0:
			_passa(m, best)
			return
	if zone_wait > ZONE_WAIT:
		if dg < 24.0:
			_tira(m)
		elif not best.is_empty():
			_passa(m, best)


func _duello(m) -> void:
	var c: R.Player = m.ctrl[tm]
	var best := _miglior_passaggio(m, c)
	if r.next() < 0.55 or best.is_empty():
		if m.userDribble(tm):
			conti.dribbling += 1
		situ = ""
		return
	_passa(m, best)


func _fuga(m) -> void:
	var c: R.Player = m.ctrl[tm]
	if r.next() < 0.75:
		if m.userSprint(tm):
			conti.scatto += 1
		situ = ""
		return
	var best := _miglior_passaggio(m, c)
	if not best.is_empty():
		_passa(m, best)


func _testa(m) -> void:
	if r.next() < HEAD_MISS:
		conti.testa_saltata += 1
		react = 99.0 # non disegna: il fermatempo finisce da solo
		return
	var gk: R.Player = m.gk(1 - tm)
	var side: float = -1.0 if gk.x > 0.0 else 1.0
	var tx := side * (C.GW / 2.0 - 0.6 - r.next() * 1.2)
	_disegna("head", {"k": "head", "spec": {"goal": true, "tx": tx, "th": 0.3 + r.next() * 1.5}})
	busy = _rng([0.3, 0.5])


func _tuffo(m) -> void:
	var s: R.Shot = m.ball.shot
	var g: R.Player = m.gk(tm)
	if s == null:
		return
	var dx: float = s.cx + (r.next() - 0.5) * 2.0 * DIVE_ERR - g.x
	_disegna("dive", {"k": "dive", "dx": dx, "th": maxf(0.2, s.ch + (r.next() - 0.5) * 0.8)})
	busy = _rng([0.2, 0.4])


func _ripresa(m) -> void:
	var c: R.Player = m.ctrl[tm]
	var rs = m.restart
	if rs == null or rs.t < 0.4:
		return
	var b: R.Ball = m.ball
	var dir := _dir()
	if rs.type == "penalty":
		var st := _spec_tiro(m, b.x, b.y, "tiro_raso")
		_disegna("draw", {"k": "kick", "spec": st.spec, "sub": "tiro_raso"})
		conti.ripresa += 1
		return
	if rs.type == "freekick" and C.hyp(b.x, b.y - dir * C.HL) < 25.0 and r.next() < 0.6:
		var st2 := _spec_tiro(m, b.x, b.y, "tiro_giro")
		_disegna("draw", {"k": "kick", "spec": st2.spec, "sub": "tiro_giro"})
		conti.ripresa += 1
		return
	if rs.type == "corner":
		var q := _in_area(m, c)
		if q != null:
			var tx: float = q.x
			var ty: float = q.y
			var d := C.hyp(tx - b.x, ty - b.y)
			var spec := {"type": "auto", "tx": tx, "ty": ty, "th": 0.0, "curve": d * 0.22 * (1.0 if r.next() < 0.5 else -1.0), "tratto": true}
			_disegna("draw", {"k": "kick", "spec": spec, "sub": "cross"})
			conti.ripresa += 1
			return
	var best := _miglior_passaggio(m, c)
	if best.is_empty():
		return
	conti.ripresa += 1
	_passa(m, best)


func _difesa(m) -> void:
	var b: R.Ball = m.ball
	if r.next() > DEF_LINE_P:
		return
	var best: R.Player = null
	var bd := INF
	for p: R.Player in m.team(tm):
		if p.off or p.pos == "P":
			continue
		var d := C.hyp(p.x - b.x, p.y - b.y)
		if d < bd:
			bd = d
			best = p
	if best == null or bd > 20.0:
		return
	var o: R.Player = b.owner
	var tx: float = b.x + (o.vx * 0.6 if o != null else b.vx * 0.4)
	var ty: float = b.y + (o.vy * 0.6 if o != null else b.vy * 0.4)
	_disegna("dpath", {"k": "run", "p": best, "pts": [{"x": tx, "y": ty}]})
