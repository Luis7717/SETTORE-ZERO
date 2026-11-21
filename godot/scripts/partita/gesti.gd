# Comandi a un dito (porting di src/input.js). Traduce i tocchi in ordini per la squadra `team`.
# Logica pura: niente nodi né eventi di Godot. Riceve posizioni sullo schermo (punti logici, come la vista) e il tempo
# in millisecondi, così gira anche nei test senza schermo (tests/test_gesti.gd) con una vista finta.
#
# La vista (scripts/partita/vista.gd o vista_finta.gd, senza tipo: basta che abbia questi metodi) serve per:
#   world_to_screen(x, y, h) -> Vector3(x_px, y_px, visibile 1/0)   (visibile = davanti alla telecamera)
#   screen_to_field(p) -> Vector2                                    (non finito = il dito guarda il cielo)
#   screen_to_goal(p, gy) -> Vector3(x, h, 1/0)                       (facoltativo; se manca: omografia, vedi sotto)
#   show_path(punti, kind) / clear_path()                             (kind "run", "pass", "shot", "def")
#   user_yaw, cam_drag                                                (visuale girata col dito)
# Gli ordini vanno a `out` (stessi nomi del JS: kick, move, stop, dive, sw, path, run): nel gioco è ComandiPartita,
# che li gira al motore; nei test un registratore.
extends RefCounted

const SimMatchScript := preload("res://sim/match.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const VD := preload("res://scripts/partita/visuale_dito.gd")

const HW := C.HW
const HL := C.HL
const GW := C.GW
const GH := C.GH
const NO_OFFSIDE := ["throw", "goalkick", "corner"] # ripartenze senza fuorigioco
const PASS_SNAP := 5.0          # la linea che finisce entro tanti metri da un compagno è un passaggio a lui (m)
const PUNTO_OGNI_PX := 5.0      # un nuovo punto della linea ogni tanti px di dito
const PUNTI_MAX := 150          # oltre, si toglie il secondo punto (il primo è il pallone o il giocatore)
const LINEA_MIN_PX := 28.0      # linea più corta di così (px sullo schermo) = nessun ordine
const TOCCO_PX := 16.0          # tocco: il dito si è spostato meno di così (px) ...
const TOCCO_MS := 320           # ... ed è rimasto giù meno di così (ms)
const TENUTO_MS := 110          # tenendo premuto oltre questo tempo (ms) ...
const TENUTO_PX := 12.0         # ... o muovendo il dito più di così (px) il giocatore controllato segue il dito
const TUFFO_MIN_PX := 22.0      # linea del portiere più corta = niente tuffo
const PRESA_PORTATORE := [64.0, 0.085]  # raggio di presa attorno al pallone o al portatore: max(px, frazione dell'altezza)
const PRESA_PROPRIO := [50.0, 0.065]    # raggio di presa di un proprio giocatore (linea di difesa)
const PRESA_COMPAGNO := [46.0, 0.06]    # raggio di presa di un compagno (tocco per comandarlo)


## Ordini al motore (le funzioni `out` di src/main.js)
class ComandiPartita:
	extends RefCounted
	var m: SimMatchScript
	var tm := 0

	func _init(match_: SimMatchScript, team_: int) -> void:
		m = match_
		tm = team_

	func kick(spec: Dictionary) -> void:
		m.userKick(tm, spec)

	func move(x: float, y: float, held: bool, sprint: Variant = null) -> void:
		m.userMove(tm, x, y, held, sprint)

	func stop() -> void:
		m.userStop(tm)

	func dive(dx: float, th: float) -> void:
		m.userDive(tm, dx, th)

	func sw(i: int) -> void:
		m.userSwitch(tm, m.team(tm)[i])

	func path(punti: Array) -> void:
		m.userPath(tm, punti)

	func run(i: int, punti: Array) -> void:
		m.userRun(tm, m.team(tm)[i], punti)


var partita: SimMatchScript = null
var team := 0
var vista = null                 # vedi in cima (senza tipo: vista vera o finta)
var out = null                   # ComandiPartita o registratore dei test
var enabled := false
var dim := Vector2(390.0, 844.0) # misura dello schermo in punti logici (w, h)

var mode := ""                   # "" (nessuno), "draw", "dpath", "cam", "dive", "move"
var pts: Array = []              # punti della linea: {x, y, h, sx, sy, goal?}
var sx := 0.0
var sy := 0.0
var x := 0.0
var y := 0.0
var t0 := 0
var moved := 0.0
var dito := -1                   # indice del dito giù (−1 = nessuno): un dito solo alla volta
var drawing := false             # col pallone, mentre si disegna (rallenty più forte, visuale larga)
var cam_on := false              # la visuale sta girando col dito
var yaw0 := 0.0
var cam_used := false            # la persona ha già girato la visuale almeno una volta (per la scritta d'aiuto)
var runner: R.Player = null      # giocatore della linea di difesa
## anteprima del calcio che si sta disegnando, per l'HUD: punti del volo {x, y, h}, linea del fuorigioco, ricevitore
var anteprima := {"punti": [], "fuorigioco": NAN, "ricevitore": null}


func set_match(m: SimMatchScript, tm: int) -> void:
	partita = m
	team = tm
	cancel()


func cancel() -> void:
	mode = ""
	dito = -1
	drawing = false
	pts = []
	end_cam()
	_pulisci_anteprima()
	if vista != null:
		vista.clear_path()


func end_cam() -> void:
	cam_on = false
	if vista != null:
		vista.cam_drag = false


func _pulisci_anteprima() -> void:
	anteprima = {"punti": [], "fuorigioco": NAN, "ricevitore": null}


func _schermo(px: float, py: float, ph: float) -> Vector3:
	return vista.world_to_screen(px, py, ph)


# ---------------------------------------------------------------- dito giù
func down(p: Vector2, now_ms: int, indice: int = 0) -> void:
	var m := partita
	if m == null or not enabled or dito >= 0:
		return
	dito = indice
	sx = p.x
	x = p.x
	sy = p.y
	y = p.y
	t0 = now_ms
	moved = 0.0
	var T := team
	var b := m.ball
	var c: R.Player = m.ctrl[T]
	var hint: String = m.hint(T)
	if hint == "dive":
		mode = "dive"
		return
	if c != null and b.owner == c and (hint == "attack" or hint == "restart"):
		var sp := _schermo(b.x, b.y, 0.3)
		var sc := _schermo(c.x, c.y, 1.0)
		var Rr := maxf(PRESA_PORTATORE[0], dim.y * PRESA_PORTATORE[1])
		# sulle rimesse il dito disegna dalla palla ovunque si appoggi, tranne nel calcio d'angolo: lì solo vicino al
		# battitore (lontano gira la visuale, come nel rallenty)
		if (sp.z > 0.5 and Vector2(x - sp.x, y - sp.y).length() < Rr) or (sc.z > 0.5 and Vector2(x - sc.x, y - sc.y).length() < Rr) \
				or (hint == "restart" and not VD.corner_cam_on(m)):
			mode = "draw"
			drawing = true
			pts = [{"x": b.x, "y": b.y, "h": 0.0, "sx": x, "sy": y}]
			return
	# rallenty in attacco (duello, area di tiro): dito lontano dal portatore = trascinando di lato gira la visuale;
	# il tocco breve (sul campo o su un compagno) non fa niente: il passaggio si disegna sempre
	if (c != null and b.owner == c and hint == "attack" and VD.user_cam_on(m, T)) or VD.corner_cam_on(m):
		mode = "cam"
		cam_on = false
		yaw0 = vista.user_yaw
		return
	# difesa: dito su un proprio giocatore = linea da fargli seguire (tutti tranne il portiere)
	if hint == "defend" or hint == "loose":
		var r := near_own(x, y)
		if r != null:
			mode = "dpath"
			runner = r
			pts = [{"x": r.x, "y": r.y, "h": 0.0, "sx": x, "sy": y}]
			return
	mode = "move"


## proprio giocatore (non portiere, compreso quello controllato) sotto il dito
func near_own(px: float, py: float) -> R.Player:
	var m := partita
	var best: R.Player = null
	var bd := maxf(PRESA_PROPRIO[0], dim.y * PRESA_PROPRIO[1])
	for p: R.Player in m.players:
		if p.team != team or p.off or p.pos == "P":
			continue
		var s := _schermo(p.x, p.y, 0.9)
		var d := Vector2(px - s.x, py - s.y).length()
		if s.z > 0.5 and d < bd:
			bd = d
			best = p
	return best


func near_mate(px: float, py: float) -> R.Player:
	var m := partita
	var best: R.Player = null
	var bd := maxf(PRESA_COMPAGNO[0], dim.y * PRESA_COMPAGNO[1])
	for p: R.Player in m.players:
		if p.team != team or p.off or p == m.ctrl[team]:
			continue
		var s := _schermo(p.x, p.y, 0.9)
		var d := Vector2(px - s.x, py - s.y).length()
		if s.z > 0.5 and d < bd:
			bd = d
			best = p
	return best


func goal_y() -> float:
	return HL if team == 0 else -HL


func own_goal_y() -> float:
	return -goal_y()


## compagno (chiunque, tranne il portatore) vicino a un punto del campo
func mate_at(px: float, py: float, Rr: float = PASS_SNAP) -> R.Player:
	var m := partita
	var best: R.Player = null
	var bd := Rr
	for p: R.Player in m.players:
		if p.team == team and not p.off and p != m.ctrl[team]:
			var d := C.hyp(p.x - px, p.y - py)
			if d < bd:
				bd = d
				best = p
	return best


## la linea è una strada da correre? No se finisce in porta, in rimessa e in ogni rallenty (duello, fuga, area di tiro):
## lì ogni linea è un passaggio (Luis 2026-11-21: durante il rallenty niente corsa disegnata)
func run_path() -> bool:
	var m := partita
	if pts.is_empty():
		return false
	var e: Dictionary = pts[-1]
	if e.get("goal", false):
		return false
	if m.phase == "restart":
		return false
	return not m.passFor(team)


## punto del campo sotto il dito; null se guarda il cielo
func _campo(px: float, py: float) -> Variant:
	var g: Vector2 = vista.screen_to_field(Vector2(px, py))
	return g if g.is_finite() else null


## punto (x, h) del piano della porta y = gy sotto il dito; null se il piano è dietro la telecamera
func _porta(px: float, py: float, gy: float) -> Variant:
	if vista.has_method("screen_to_goal"):
		var q: Vector3 = vista.screen_to_goal(Vector2(px, py), gy)
		return Vector2(q.x, q.y) if q.z > 0.5 else null
	return porta_da_omografia(vista, Vector2(px, py), gy)


## punto del campo (o della porta) sotto il dito
func pick(px: float, py: float) -> Variant:
	var gy := goal_y()
	var gv: Variant = _campo(px, py)
	var qv: Variant = _porta(px, py, gy)
	var beyond := gv == null or (absf((gv as Vector2).y) > HL and signf((gv as Vector2).y) == signf(gy))
	if qv != null and beyond:
		var q: Vector2 = qv
		if q.y >= 0.0 and q.y < GH + 2.2 and absf(q.x) < GW / 2.0 + 3.5:
			return {"x": q.x, "y": gy, "h": maxf(0.15, q.y), "goal": true}
	if gv == null:
		return null
	var g: Vector2 = gv
	return {"x": clampf(g.x, -HW - 2.0, HW + 2.0), "y": clampf(g.y, -HL - 2.0, HL + 2.0), "h": 0.0}


# ---------------------------------------------------------------- dito che si muove
func move_ev(p: Vector2, indice: int = 0) -> void:
	if indice != dito or dito < 0:
		return
	moved += Vector2(p.x - x, p.y - y).length()
	x = p.x
	y = p.y
	if mode == "draw":
		var last: Dictionary = pts[-1]
		if Vector2(x - last.sx, y - last.sy).length() >= PUNTO_OGNI_PX:
			var q: Variant = pick(x, y)
			if q != null:
				q.sx = x
				q.sy = y
				pts.append(q)
				if pts.size() > PUNTI_MAX:
					pts.remove_at(1)
			show_path()
	elif mode == "dpath":
		var last: Dictionary = pts[-1]
		if Vector2(x - last.sx, y - last.sy).length() >= PUNTO_OGNI_PX:
			var g: Variant = _campo(x, y)
			if g != null:
				pts.append({"x": g.x, "y": g.y, "h": 0.0, "sx": x, "sy": y})
				if pts.size() > PUNTI_MAX:
					pts.remove_at(1)
			# la linea di difesa si vede già tagliata alla lunghezza massima (il motore la taglia allo stesso modo)
			if pts.size() >= 2:
				vista.show_path(_xy([pts[0]] + linea_difesa_tagliata()), "def")
	elif mode == "cam":
		# la visuale parte quando il dito si sposta abbastanza di lato, poi lo segue (angolo e limiti: visuale_dito.gd)
		var dx := x - sx
		if not cam_on and VD.is_cam_drag(dx, y - sy):
			cam_on = true
			cam_used = true
		if cam_on and VD.user_cam_on(partita, team):
			vista.user_yaw = VD.drag_yaw(yaw0, dx, dim.x)
			vista.cam_drag = true
		else:
			vista.cam_drag = false
	elif mode == "dive":
		# linea dal portiere verso il punto della porta dove tuffarsi: il tuffo parte quando si alza il dito
		var t: Variant = dive_target()
		var g := partita.gk(team)
		if t != null:
			vista.show_path(PackedVector2Array([Vector2(g.x, g.y), Vector2(t.x, own_goal_y())]), "shot")


## punti della linea di difesa (senza il primo, il giocatore) tagliati a RUN_MAX_LEN dal giocatore
func linea_difesa_tagliata() -> Array:
	if pts.size() < 2:
		return []
	return SimMatchScript.clipLen(pts[0].x, pts[0].y, pts.slice(1), SimMatchScript.RUN_MAX_LEN)


static func _xy(lista: Array) -> PackedVector2Array:
	var out_: PackedVector2Array = []
	for q: Dictionary in lista:
		out_.append(Vector2(q.x, q.y))
	return out_


func show_path() -> void:
	var m := partita
	var b := m.ball
	if pts.size() < 2:
		return
	pts[0].x = b.x
	pts[0].y = b.y
	var e: Dictionary = pts[-1]
	if run_path(): # strada da correre
		vista.show_path(_xy(pts), "run")
		_pulisci_anteprima()
		return
	var recv: R.Player = null
	if not e.get("goal", false):
		recv = mate_at(e.x, e.y)
	vista.show_path(_xy(pts), "shot" if e.get("goal", false) else "pass")
	# anteprima del volo vero e linea del fuorigioco (non vale su rimessa, rinvio e angolo)
	var c: R.Player = m.ctrl[team]
	if c == null or b.owner != c:
		return
	var free: bool = m.phase == "restart" and NO_OFFSIDE.has(m.restart.type)
	anteprima = {"punti": m.predictKick(c, spec()), "fuorigioco": NAN if free else m.offsideY(team), "ricevitore": recv}


func spec() -> Dictionary:
	var b := partita.ball
	var e: Dictionary = pts[-1]
	var gy := goal_y()
	var bx := b.x
	var by := b.y
	var tx: float = e.x
	var ty: float = e.y
	var type := "auto"
	var th := 0.0
	if e.get("goal", false):
		type = "shot"
		th = e.h
		ty = gy
	var dx := tx - bx
	var dy := ty - by
	var D := C.hyp(dx, dy)
	if D == 0.0:
		D = 1.0
	var nx := -dy / D
	var ny := dx / D
	var curve := 0.0
	for q: Dictionary in pts:
		if q.get("goal", false):
			continue
		var d: float = (q.x - bx) * nx + (q.y - by) * ny
		if absf(d) > absf(curve):
			curve = d
	return {"type": type, "tx": tx, "ty": ty, "th": th, "curve": curve}


## punto della propria porta sotto il dito (la telecamera è dietro la porta mentre si para): {x, h} o null
func dive_target() -> Variant:
	var qv: Variant = _porta(x, y, own_goal_y())
	if qv == null:
		return null
	var q: Vector2 = qv
	return {"x": clampf(q.x, -GW / 2.0 - 1.5, GW / 2.0 + 1.5), "h": clampf(q.y, 0.2, GH + 0.4)}


func do_dive() -> void:
	vista.clear_path()
	var t: Variant = dive_target()
	var g := partita.gk(team)
	if t != null:
		out.dive(t.x - g.x, t.h)
		return
	# riserva: gesto senza punto in porta (vecchio comando: verso e lunghezza dello scorrimento)
	var dx := x - sx
	var dy := y - sy
	var w := dim.x * 0.36
	var s := _verso_schermo(g)
	out.dive(s * clampf(dx / w, -1.0, 1.0) * 3.7, clampf(1.0 - (dy / w) * 1.5, 0.2, 2.5))


# +1 se sullo schermo la x del campo cresce verso destra, −1 se al contrario (il `flip` della vista web)
func _verso_schermo(g: R.Player) -> float:
	var a := _schermo(g.x, g.y, 0.0)
	var b := _schermo(g.x + 1.0, g.y, 0.0)
	return 1.0 if b.x >= a.x else -1.0


# ---------------------------------------------------------------- dito su
## annullato = tocco interrotto dal sistema (gesto di iOS, chiamata, app in sottofondo): nessun ordine.
## La posizione del rilascio non conta (come pointerup in src/input.js): vale l'ultimo punto trascinato.
func up(_p: Vector2, now_ms: int, indice: int = 0, annullato: bool = false) -> void:
	if indice != dito or dito < 0:
		return
	if annullato:
		cancel()
		return
	var m := partita
	var T := team
	dito = -1
	var dt := now_ms - t0
	var dist := Vector2(x - sx, y - sy).length()
	var md := mode
	mode = ""
	if m == null:
		return
	if md == "draw":
		drawing = false
		if pts.size() >= 2 and _lunghezza_px(pts) > LINEA_MIN_PX:
			if run_path():
				var strada: Array = []
				for q: Dictionary in pts.slice(1):
					strada.append({"x": q.x, "y": q.y})
				out.path(strada)
			else:
				out.kick(spec())
		pts = []
		_pulisci_anteprima()
		vista.clear_path()
		return
	if md == "dive":
		if dist > TUFFO_MIN_PX:
			do_dive()
		else:
			vista.clear_path()
		return
	if md == "cam":
		end_cam() # nessun ordine al giocatore: né col tocco breve né tenendo premuto
		return
	if md == "dpath":
		var r := runner
		var linea := pts
		runner = null
		pts = []
		vista.clear_path()
		if linea.size() >= 2 and _lunghezza_px(linea) > LINEA_MIN_PX:
			var punti: Array = []
			for q: Dictionary in linea.slice(1):
				punti.append({"x": q.x, "y": q.y})
			out.run(r.i, punti)
			return
		if dist < TOCCO_PX and r != m.ctrl[T]:
			out.sw(r.i) # tocco = passa a comandare quel giocatore
		return
	if md != "move":
		return
	var hint: String = m.hint(T)
	if dist < TOCCO_PX and dt < TOCCO_MS:
		var mate := near_mate(x, y)
		if mate != null:
			# col pallone il tocco su un compagno non fa niente (il passaggio si disegna sempre); senza = lo si comanda
			if hint != "attack" and hint != "restart":
				out.sw(mate.i)
		else:
			var g: Variant = _campo(x, y)
			if g != null:
				out.move(g.x, g.y, false)
		return
	out.stop()


static func _lunghezza_px(linea: Array) -> float:
	var tot := 0.0
	for i in range(1, linea.size()):
		tot += Vector2(linea[i].sx - linea[i - 1].sx, linea[i].sy - linea[i - 1].sy).length()
	return tot


# ---------------------------------------------------------------- a ogni fotogramma
## tenendo premuto il giocatore segue il dito; mentre si disegna si aggiorna l'anteprima
func update(now_ms: int) -> void:
	if mode == "move" and dito >= 0 and (now_ms - t0 > TENUTO_MS or moved > TENUTO_PX):
		var gv: Variant = _campo(x, y)
		if gv != null:
			var g: Vector2 = gv
			# dito lontano dal giocatore controllato = scatto; vicino = corsa normale
			var c: R.Player = partita.ctrl[team] if partita != null else null
			out.move(g.x, g.y, true, c != null and C.hyp(g.x - c.x, g.y - c.y) > SimMatchScript.SPRINT_DIST)
	if mode == "draw":
		var m := partita
		var c: R.Player = m.ctrl[team] if m != null else null
		if m == null or c == null or m.ball.owner != c:
			cancel()
			return
		show_path()
	if mode == "dive" and partita != null and not partita.diveWin(team):
		mode = "move"


# ---------------------------------------------------------------- piano della porta senza screen_to_goal
## Punto (x, h) del piano verticale della porta y = gy sotto il punto p dello schermo, calcolato solo con
## world_to_screen: un piano visto da una telecamera prospettica arriva sullo schermo con un'omografia, che si ricava
## da 4 punti del piano (i pali e la traversa) e si inverte. null se i punti non sono davanti alla telecamera o se p
## sta oltre l'orizzonte del piano (dietro la telecamera).
static func porta_da_omografia(v, p: Vector2, gy: float) -> Variant:
	var piano := [Vector2(-GW / 2.0, 0.0), Vector2(GW / 2.0, 0.0), Vector2(GW / 2.0, GH), Vector2(-GW / 2.0, GH)]
	var schermo: Array[Vector2] = []
	var centro := Vector2.ZERO
	for q: Vector2 in piano:
		var s: Vector3 = v.world_to_screen(q.x, gy, q.y)
		if s.z < 0.5 or not s.is_finite():
			return null
		schermo.append(Vector2(s.x, s.y))
		centro += Vector2(s.x, s.y) / 4.0
	var hm := omografia(schermo, piano)
	if hm.is_empty():
		return null
	var w := hm[6] * p.x + hm[7] * p.y + 1.0
	var w_rif := hm[6] * centro.x + hm[7] * centro.y + 1.0
	if absf(w) < 1e-9 or signf(w) != signf(w_rif):
		return null
	return Vector2((hm[0] * p.x + hm[1] * p.y + hm[2]) / w, (hm[3] * p.x + hm[4] * p.y + hm[5]) / w)


## omografia da 4 punti src a 4 punti dst: 8 coefficienti [a b c d e f g h] con
## X = (a u + b v + c) / (g u + h v + 1), Y = (d u + e v + f) / (g u + h v + 1). Vuota se i punti sono degeneri.
static func omografia(src: Array[Vector2], dst: Array) -> PackedFloat64Array:
	var A: Array = []
	for k in 4:
		var u := src[k].x
		var vv := src[k].y
		var X: float = dst[k].x
		var Y: float = dst[k].y
		A.append(PackedFloat64Array([u, vv, 1.0, 0.0, 0.0, 0.0, -u * X, -vv * X, X]))
		A.append(PackedFloat64Array([0.0, 0.0, 0.0, u, vv, 1.0, -u * Y, -vv * Y, Y]))
	# eliminazione di Gauss con pivot parziale
	for col in 8:
		var piv := col
		for r in range(col + 1, 8):
			if absf(A[r][col]) > absf(A[piv][col]):
				piv = r
		if absf(A[piv][col]) < 1e-12:
			return PackedFloat64Array()
		var tmp: PackedFloat64Array = A[col]
		A[col] = A[piv]
		A[piv] = tmp
		var riga: PackedFloat64Array = A[col]
		for r in 8:
			if r == col:
				continue
			var altra: PackedFloat64Array = A[r]
			var f: float = altra[col] / riga[col]
			if f == 0.0:
				continue
			for k in range(col, 9):
				altra[k] -= f * riga[k]
			A[r] = altra
	var hm := PackedFloat64Array()
	for r in 8:
		hm.append(A[r][8] / A[r][r])
	return hm
