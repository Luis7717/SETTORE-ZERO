# Gesti a un dito (scripts/partita/gesti.gd = porting di src/input.js) e visuale girata col dito
# (scripts/partita/visuale_dito.gd = parte "gesto" di src/camuser.js), con una vista finta come test/unit/camuser.test.mjs.
# I gesti girano su una partita vera (scene di harness.gd); gli ordini si registrano e si passano anche al motore,
# così si controlla sia cosa parte dal dito sia cosa fa il motore.
extends "test_base.gd"

const Gesti := preload("res://scripts/partita/gesti.gd")
const VD := preload("res://scripts/partita/visuale_dito.gd")
const TelecameraPartita := preload("res://scripts/partita/telecamera_partita.gd")

const W := 390.0
const SCHERMO_H := 844.0


## vista finta: schermo x = 195 + 6·x, y = 600 − 6·y − 6·h (portatore in basso, campo davanti in alto);
## con `prospettiva` una telecamera vera a punto (per l'omografia della porta)
class VistaFinta:
	extends RefCounted
	var user_yaw := 0.0
	var cam_drag := false
	var drawing := false
	var path: PackedVector2Array = []
	var kind := ""
	var prospettiva := false

	func world_to_screen(x: float, y: float, h: float) -> Vector3:
		if prospettiva:
			return _prospettiva(x, y, h)
		return Vector3(195.0 + 6.0 * x, 600.0 - 6.0 * y - 6.0 * h, 1.0)

	func screen_to_field(p: Vector2) -> Vector2:
		return Vector2((p.x - 195.0) / 6.0, (600.0 - p.y) / 6.0)

	func show_path(punti: PackedVector2Array, k: String) -> void:
		path = punti
		kind = k

	func clear_path() -> void:
		path = PackedVector2Array()
		kind = ""

	# telecamera a (3, −20, 12) che guarda verso +y inclinata di 25° verso il basso, fuoco 420 px
	func _prospettiva(x: float, y: float, h: float) -> Vector3:
		var a := deg_to_rad(25.0)
		var d := Vector3(x - 3.0, y + 20.0, h - 12.0)
		var avanti := Vector3(0.0, cos(a), -sin(a))
		var su := Vector3(0.0, sin(a), cos(a))
		var z := d.dot(avanti)
		if z <= 0.0:
			return Vector3(0.0, 0.0, 0.0)
		return Vector3(195.0 + 420.0 * d.x / z, 422.0 - 420.0 * d.dot(su) / z, 1.0)


## registra gli ordini (come `calls` del test JS) e li passa anche al motore se `inoltra` c'è
class Registro:
	extends RefCounted
	var calls: Array = []
	var inoltra = null

	func kick(spec: Dictionary) -> void:
		calls.append(["kick", spec.duplicate()])
		if inoltra != null:
			inoltra.kick(spec)

	func move(x: float, y: float, held: bool, sprint: Variant = null) -> void:
		calls.append(["move", x, y, held, sprint])
		if inoltra != null:
			inoltra.move(x, y, held, sprint)

	func stop() -> void:
		calls.append(["stop"])
		if inoltra != null:
			inoltra.stop()

	func dive(dx: float, th: float) -> void:
		calls.append(["dive", dx, th])
		if inoltra != null:
			inoltra.dive(dx, th)

	func sw(i: int) -> void:
		calls.append(["sw", i])
		if inoltra != null:
			inoltra.sw(i)

	func path(punti: Array) -> void:
		calls.append(["path", punti])
		if inoltra != null:
			inoltra.path(punti)

	func run(i: int, punti: Array) -> void:
		calls.append(["run", i, punti])
		if inoltra != null:
			inoltra.run(i, punti)

	func queue(i: int, spec: Dictionary) -> void:
		calls.append(["queue", i, spec.duplicate()])
		if inoltra != null:
			inoltra.queue(i, spec)

	func nomi() -> Array:
		return calls.map(func(c: Array) -> String: return c[0])


# ---------------------------------------------------------------- preparazione
var m: SimMatchScript
var g: Gesti
var v: VistaFinta
var reg: Registro
var c: R.Player     # portatore (attaccante di casa)
var mate: R.Player  # compagno
var opp: R.Player   # difensore avversario


## partita in gioco col portatore c in (cx, cy) col pallone, un compagno in (15, cy + 20); duel = duello aperto
func prepara(cx: float = 0.0, cy: float = 0.0, duel: bool = false) -> void:
	m = H.scene(3)
	c = m.team(0)[9]
	mate = m.team(0)[10]
	opp = m.team(1)[3]
	H.wake(c, cx, cy)
	H.wake(mate, 15.0, cy + 20.0)
	c.fx = 0.0
	c.fy = 1.0
	H.give(m, c)
	m.ctrl[0] = c
	if duel:
		H.wake(opp, cx, cy + 5.0)
		m.duel = R.Duel.new()
		m.duel.team = 0
		m.duel.p = c
		m.duel.o = opp
	v = VistaFinta.new()
	reg = Registro.new()
	reg.inoltra = Gesti.ComandiPartita.new(m, 0)
	g = Gesti.new()
	g.vista = v
	g.out = reg
	g.dim = Vector2(W, SCHERMO_H)
	g.set_match(m, 0)
	g.enabled = true


func sch(x: float, y: float, h: float = 0.0) -> Vector2:
	var s := v.world_to_screen(x, y, h)
	return Vector2(s.x, s.y)


func linea(a: Vector2, b: Vector2, n: int = 20) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n + 1:
		out.append(a.lerp(b, float(i) / n))
	return out


## dito giù sul primo punto, trascinato sugli altri, su sull'ultimo (16 ms tra un punto e l'altro)
func trascina(punti: Array[Vector2], t0: int = 1000) -> void:
	g.down(punti[0], t0)
	for i in range(1, punti.size()):
		g.move_ev(punti[i])
	g.up(punti[-1], t0 + 16 * punti.size())


func tocca(p: Vector2, t0: int = 1000) -> void:
	g.down(p, t0)
	g.up(p, t0 + 60)


func lunghezza(x0: float, y0: float, punti: Array) -> float:
	var tot := 0.0
	var px := x0
	var py := y0
	for q in punti:
		tot += C.hyp(q.x - px, q.y - py)
		px = q.x
		py = q.y
	return tot


# ---------------------------------------------------------------- col pallone ogni linea è un calcio (niente più strada)
func test_linea_nello_spazio_fuori_dal_rallenty_e_un_passaggio() -> bool:
	prepara()
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(5.0, 12.0)))
	eq(reg.nomi(), ["kick"], "un solo ordine: passaggio (non più una strada da correre)")
	var sp: Dictionary = reg.calls[0][1]
	near(sp.tx, 5.0, 0.3, "fine linea x")
	near(sp.ty, 12.0, 0.3, "fine linea y")
	check(sp.get("tratto", false), "il motore sceglie il colpo dalla forma del tratto")
	check(m.ball.owner == null and m.ball.kick != null, "il pallone è partito")
	eq(v.kind, "", "linea tolta a dito alzato")
	return done()


func test_mentre_si_disegna_col_pallone_si_vede_un_passaggio() -> bool:
	prepara()
	g.down(sch(m.ball.x, m.ball.y, 0.3), 1000)
	for p in linea(sch(m.ball.x, m.ball.y, 0.3), sch(4.0, 10.0)).slice(1):
		g.move_ev(p)
	check(g.drawing, "si sta disegnando")
	eq(v.kind, "pass", "la vista mostra un passaggio")
	check(not g.run_path(), "mai una strada da correre")
	g.up(sch(4.0, 10.0), 1400)
	check(not g.drawing, "dito alzato: non si disegna più")
	return done()


func test_col_pallone_tenere_premuto_non_guida_il_portatore() -> bool:
	prepara()
	g.down(sch(-10.0, 15.0), 1000)
	g.update(1300)
	g.up(sch(-10.0, 15.0), 1400)
	eq(reg.calls.size(), 0, "il portatore si muove da solo: nessun ordine di corsa")
	return done()


func test_linea_corta_non_fa_niente() -> bool:
	prepara()
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(m.ball.x + 2.0, m.ball.y + 1.0), 4))
	eq(reg.calls.size(), 0, "linea sotto i 28 px: nessun ordine")
	return done()


# ---------------------------------------------------------------- passaggio (sempre disegnato)
func test_duello_linea_fino_al_compagno_e_un_passaggio() -> bool:
	prepara(0.0, 0.0, true)
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(mate.x, mate.y)))
	eq(reg.nomi(), ["kick"], "un solo ordine: calcio")
	var spec: Dictionary = reg.calls[0][1]
	check(C.hyp(spec.tx - mate.x, spec.ty - mate.y) < 0.5, "mira sul compagno")
	eq(spec.type, "auto", "passaggio (non tiro)")
	check(m.ball.owner == null and m.ball.kick != null, "il motore ha calciato")
	eq(v.user_yaw, 0.0, "la linea dal portatore non gira la visuale")
	return done()


func test_mentre_si_disegna_il_passaggio_c_e_l_anteprima() -> bool:
	prepara(0.0, 0.0, true)
	g.down(sch(m.ball.x, m.ball.y, 0.3), 1000)
	for p in linea(sch(m.ball.x, m.ball.y, 0.3), sch(mate.x, mate.y)).slice(1):
		g.move_ev(p)
	eq(v.kind, "pass", "la vista mostra un passaggio")
	check(not g.run_path(), "nel duello ogni linea è un passaggio (rallenty PASS_DRAW_SLOW)")
	check(g.anteprima.punti.size() > 3, "anteprima del volo")
	check(g.anteprima.ricevitore == mate, "compagno che riceve")
	g.cancel()
	return done()


func test_tocco_su_compagno_non_passa() -> bool:
	# duello, gioco normale col pallone e rimessa: il tocco su un compagno non fa niente
	prepara(0.0, 0.0, true)
	tocca(sch(mate.x, mate.y, 0.9))
	tocca(Vector2(60.0, 200.0))
	eq(reg.calls.size(), 0, "duello: nessun ordine dal tocco")
	check(m.ball.owner == c, "il pallone resta al portatore")
	prepara()
	tocca(sch(mate.x, mate.y, 0.9))
	eq(reg.nomi().filter(func(n: String) -> bool: return n == "kick" or n == "sw"), [], "attacco: niente passaggio né cambio")
	check(m.ball.owner == c, "il pallone resta al portatore (attacco)")
	prepara()
	m.setRestart("throw", 0, -C.HW, 0.0)
	var t: R.Player = m.restart.taker
	var compagno: R.Player = m.team(0)[10] if t != m.team(0)[10] else m.team(0)[9]
	tocca(sch(compagno.x, compagno.y, 0.9))
	eq(reg.calls.size(), 0, "rimessa: il tocco non passa")
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(compagno.x, compagno.y)))
	eq(reg.nomi(), ["kick"], "rimessa: la linea sì")
	return done()


# ---------------------------------------------------------------- tiro
func test_area_di_tiro_linea_in_porta_e_un_tiro() -> bool:
	prepara(4.0, 33.0)
	check(m.inZone(0), "portatore nell'area di tiro")
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(1.5, C.HL, 1.2)))
	eq(reg.nomi(), ["kick"], "un solo ordine: calcio")
	var spec: Dictionary = reg.calls[0][1]
	eq(spec.type, "shot", "tiro")
	eq(spec.ty, C.HL, "verso la porta avversaria")
	near(spec.tx, 1.5, 0.3, "punto della porta (x)")
	near(spec.th, 1.2, 0.3, "altezza del tiro")
	check(m.ball.shot != null or m.ball.kick != null, "il motore ha tirato")
	return done()


# Luis 2026-11-21: durante il rallenty niente corsa disegnata, ogni linea è un passaggio (al compagno o nello spazio)
func test_area_di_tiro_ogni_linea_e_un_passaggio() -> bool:
	prepara(4.0, 33.0)
	H.wake(mate, -8.0, 38.0)
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(mate.x, mate.y)))
	eq(reg.nomi(), ["kick"], "fino al compagno (entro 5 m) = passaggio")
	prepara(4.0, 33.0)
	H.wake(mate, -8.0, 38.0)
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(10.0, 40.0)))
	eq(reg.nomi(), ["kick"], "anche nello spazio = passaggio, non corsa")
	return done()


func test_porta_dall_omografia_con_telecamera_vera() -> bool:
	v = VistaFinta.new()
	v.prospettiva = true
	for q: Vector2 in [Vector2(1.7, 1.1), Vector2(-3.0, 0.4), Vector2(0.0, 3.5)]:
		var s := v.world_to_screen(q.x, C.HL, q.y)
		var r: Variant = Gesti.porta_da_omografia(v, Vector2(s.x, s.y), C.HL)
		check(r != null, "punto della porta trovato")
		if r != null:
			near((r as Vector2).x, q.x, 1e-3, "x sul piano della porta")
			near((r as Vector2).y, q.y, 1e-3, "altezza sul piano della porta")
	# oltre l'orizzonte del piano (telecamera inclinata in giù: è sotto lo schermo) il punto sarebbe dietro: null
	eq(Gesti.porta_da_omografia(v, Vector2(195.0, 5000.0), C.HL), null, "oltre l'orizzonte: null")
	return done()


# ---------------------------------------------------------------- difesa
func test_linea_di_difesa_tagliata_a_14_m() -> bool:
	prepara()
	var porta: R.Player = m.team(1)[9]
	H.wake(porta, -10.0, 20.0)
	H.give(m, porta)
	var d: R.Player = m.team(0)[2]
	H.wake(d, 0.0, -10.0)
	eq(m.hint(0), "defend", "in difesa")
	g.down(sch(d.x, d.y, 0.9), 1000)
	eq(g.mode, "dpath", "dito sul difensore = linea di difesa")
	for p in linea(sch(d.x, d.y, 0.9), sch(0.0, 20.0), 30).slice(1):
		g.move_ev(p)
	eq(v.kind, "def", "la vista mostra la linea di difesa")
	near(lunghezza(d.x, d.y, Array(v.path).slice(1)), SimMatchScript.RUN_MAX_LEN, 0.05, "mentre si disegna si vede già tagliata")
	g.up(sch(0.0, 20.0), 1500)
	eq(reg.nomi(), ["run"], "un solo ordine: linea di difesa")
	eq(reg.calls[0][1], d.i, "al difensore toccato")
	var runs: Array = m.runs[0]
	check(runs.size() == 1, "il motore ha la linea")
	if runs.size() == 1:
		var r: R.Run = runs[0]
		check(lunghezza(d.x, d.y, r.path) <= SimMatchScript.RUN_MAX_LEN + 0.01, "il motore la taglia a 14 m")
	return done()


func test_difesa_tocco_su_compagno_lo_comanda() -> bool:
	prepara()
	var porta: R.Player = m.team(1)[9]
	H.wake(porta, -10.0, 20.0)
	H.give(m, porta)
	var d: R.Player = m.team(0)[2]
	H.wake(d, 8.0, -6.0)
	tocca(sch(d.x, d.y, 0.9))
	eq(reg.nomi(), ["sw"], "tocco su un proprio giocatore = comandarlo")
	check(m.ctrl[0] == d, "il motore comanda quello toccato")
	return done()


func test_tieni_premuto_muove_il_controllato() -> bool:
	prepara()
	var porta: R.Player = m.team(1)[9]
	H.wake(porta, -10.0, 20.0)
	H.give(m, porta)
	var dove := sch(-6.0, 14.0)
	g.down(dove, 1000)
	eq(g.mode, "move", "dito sul campo = muovi il controllato")
	g.update(1050)
	eq(reg.calls.size(), 0, "prima di 110 ms niente")
	g.update(1200)
	eq(reg.nomi(), ["move"], "tenendo premuto il giocatore segue il dito")
	eq(reg.calls[0][3], true, "comando tenuto")
	eq(reg.calls[0][4], true, "dito lontano = scatto")
	g.up(dove, 1300)
	return done()


# ---------------------------------------------------------------- portiere
func test_tuffo_dal_portiere_al_rilascio() -> bool:
	prepara()
	var gk := m.gk(0)
	H.wake(gk, -1.5, -C.HL + 1.0)
	var b := m.ball
	b.owner = null
	b.x = 0.0
	b.y = -30.0
	b.vy = -20.0
	b.shot = R.Shot.new()
	b.shot.team = 1
	eq(m.hint(0), "dive", "tiro in arrivo: si para")
	var meta := sch(3.0, -C.HL, 1.5)
	g.down(sch(gk.x, gk.y, 1.0), 1000)
	for p in linea(sch(gk.x, gk.y, 1.0), meta, 10).slice(1):
		g.move_ev(p)
	eq(reg.calls.size(), 0, "il tuffo non parte finché il dito è giù")
	g.up(meta, 1200)
	if not eq(reg.nomi(), ["dive"], "tuffo al rilascio"):
		return done()
	near(reg.calls[0][1], 3.0 - gk.x, 0.05, "verso il punto della porta")
	near(reg.calls[0][2], 1.5, 0.05, "all'altezza indicata")
	return done()


# il motore riceve il tuffo davvero (ComandiPartita → m.userDive) e la visuale della parata resta durante il tuffo
func test_tuffo_arriva_al_motore_e_la_visuale_resta() -> bool:
	prepara()
	var gk := m.gk(0)
	H.wake(gk, 1.0, -C.HL + 1.0)
	var b := m.ball
	b.owner = null
	b.x = 0.0
	b.y = -30.0
	b.vy = -20.0
	b.shot = R.Shot.new()
	b.shot.team = 1
	check(TelecameraPartita.parata_in_vista(m, 0), "si può parare: visuale della parata")
	var meta := sch(-3.0, -C.HL, 1.5) # nella vista finta 6 px per metro: linea più lunga di TUFFO_MIN_PX
	g.down(sch(gk.x, gk.y, 1.0), 1000)
	for p in linea(sch(gk.x, gk.y, 1.0), meta, 10).slice(1):
		g.move_ev(p)
	g.update(1150)
	eq(g.mode, "dive", "il dito resta nel gesto del tuffo")
	g.up(meta, 1200)
	eq(reg.nomi(), ["dive"], "ordine di tuffo al rilascio")
	eq(gk.state, "dive", "il motore fa tuffare il portiere")
	near(gk.dive.tx, -3.0, 0.05, "verso il punto della porta")
	check(not m.diveWin(0), "tuffo partito: diveWin finisce (come il web)")
	check(TelecameraPartita.parata_in_vista(m, 0), "durante il tuffo col tiro in volo la visuale resta sulla parata")
	b.owner = gk
	check(not TelecameraPartita.parata_in_vista(m, 0), "palla presa: la visuale torna normale")
	m.autoGk[0] = true
	b.owner = null
	check(not TelecameraPartita.parata_in_vista(m, 0), "portiere automatico: niente visuale della parata")
	return done()


# il pallone della partita ha un materiale semplice (sull'iPhone quello con la normal map non si vedeva)
func test_materiale_del_pallone_senza_normal_map() -> bool:
	var mat: StandardMaterial3D = PartitaVista.materiale_pallone()
	check(not mat.normal_enabled and mat.normal_texture == null, "niente normal map")
	check(mat.albedo_texture != null, "texture del pallone")
	eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "pallone opaco")
	return done()


# ---------------------------------------------------------------- dribbling
func test_dribbling_nel_duello() -> bool:
	prepara()
	H.wake(opp, 0.0, 5.0)
	opp.fy = -1.0
	H.run(m, 0.1)
	check(m.duelFor(0), "il difensore davanti apre il duello")
	check(m.userDribble(0), "il tasto Dribbling fa partire il dribbling")
	var evs := H.run(m, 1.5)
	check(hasEvent(evs, "dribble"), "evento dribble (esito del giochetto)")
	return done()


# ---------------------------------------------------------------- visuale girata col dito
func test_visuale_girata_nel_duello() -> bool:
	prepara(0.0, 0.0, true)
	check(VD.user_cam_on(m, 0), "nel duello la visuale si gira")
	g.down(Vector2(100.0, 250.0), 1000)
	eq(g.mode, "cam", "dito lontano dal portatore = visuale")
	for p in linea(Vector2(100.0, 250.0), Vector2(300.0, 250.0)).slice(1):
		g.move_ev(p)
	check(v.cam_drag, "mentre si trascina")
	g.up(Vector2(300.0, 250.0), 1400)
	check(v.user_yaw < -0.5, "dito verso destra = visuale a sinistra (%s)" % v.user_yaw)
	check(not v.cam_drag, "dito alzato")
	eq(reg.calls.size(), 0, "nessun ordine al giocatore")
	return done()


func test_visuale_soglia_angolo_e_limiti() -> bool:
	near(VD.drag_yaw(0.0, -W / 2.0, W), deg_to_rad(75.0), 1e-9, "mezzo schermo = 75°")
	eq(VD.drag_yaw(0.0, -5.0 * W, W), VD.CAM_USER_MAX, "limite +100°")
	eq(VD.drag_yaw(0.0, 5.0 * W, W), -VD.CAM_USER_MAX, "limite −100°")
	near(VD.CAM_USER_MAX, deg_to_rad(100.0), 1e-9, "100°")
	check(not VD.is_cam_drag(11.0, 0.0), "sotto 12 px è un tocco")
	check(VD.is_cam_drag(12.0, 0.0), "da 12 px gira")
	check(not VD.is_cam_drag(20.0, 40.0), "più in verticale che di lato: no")
	prepara(0.0, 0.0, true)
	g.down(Vector2(100.0, 250.0), 1000)
	g.move_ev(Vector2(108.0, 250.0))
	g.up(Vector2(108.0, 250.0), 1100)
	eq(v.user_yaw, 0.0, "8 px: la visuale non si muove")
	return done()


func test_fuori_dal_rallenty_trascinare_muove() -> bool:
	prepara()
	check(not VD.user_cam_on(m, 0), "senza duello né area di tiro niente visuale")
	g.down(Vector2(100.0, 250.0), 1000)
	for p in linea(Vector2(100.0, 250.0), Vector2(300.0, 250.0)).slice(1):
		g.move_ev(p)
	eq(g.mode, "move", "trascinare = muovere il giocatore")
	eq(v.user_yaw, 0.0, "nessuna rotazione")
	g.cancel()
	return done()


# ---------------------------------------------------------------- calcio d'angolo
func test_calcio_d_angolo_visuale_e_cross() -> bool:
	prepara()
	m.setRestart("corner", 0, C.HW, C.HL)
	check(VD.corner_cam_on(m), "angolo: visuale girabile")
	check(VD.user_cam_on(m, 0), "anche per user_cam_on")
	m.restart.t = 1.0
	var t: R.Player = m.restart.taker
	m.ctrl[0] = t
	t.stun = 0.0
	# lontano dal battitore: gira la visuale
	g.down(Vector2(60.0, 300.0), 1000)
	eq(g.mode, "cam", "lontano dal battitore = visuale")
	for p in linea(Vector2(60.0, 300.0), Vector2(200.0, 300.0)).slice(1):
		g.move_ev(p)
	g.up(Vector2(200.0, 300.0), 1300)
	check(v.user_yaw < -0.3, "visuale girata nell'angolo")
	eq(reg.calls.size(), 0, "nessun ordine")
	# vicino al pallone: si disegna il cross
	var compagno: R.Player = m.team(0)[10] if t != m.team(0)[10] else m.team(0)[9]
	H.wake(compagno, 2.0, 42.0)
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(compagno.x, compagno.y)))
	eq(reg.nomi(), ["kick"], "dal pallone = cross")
	check(m.phase == "play", "il cross rimette in gioco")
	for tipo in ["throw", "freekick", "goalkick"]:
		m.setRestart(tipo, 0, -C.HW, 0.0)
		check(not VD.corner_cam_on(m), "%s: niente visuale" % tipo)
	return done()


# ---------------------------------------------------------------- un dito solo, tocchi annullati
func test_secondo_dito_e_tocco_annullato_ignorati() -> bool:
	prepara()
	g.down(sch(m.ball.x, m.ball.y, 0.3), 1000, 0)
	g.down(Vector2(50.0, 50.0), 1010, 1)
	for p in linea(sch(m.ball.x, m.ball.y, 0.3), sch(5.0, 15.0)).slice(1):
		g.move_ev(p, 0)
		g.move_ev(Vector2(60.0, 60.0), 1)
	g.up(Vector2(50.0, 50.0), 1100, 1)
	check(g.drawing, "il secondo dito non interrompe il primo")
	g.up(sch(5.0, 15.0), 1300, 0, true)
	eq(reg.calls.size(), 0, "tocco annullato dal sistema: nessun ordine")
	eq(g.mode, "", "gesto chiuso")
	check(not g.drawing, "non si disegna più")
	return done()


# fuga (avversario alla pari o dietro, Luis 2026-11-21): come nell'area di tiro e nel duello ogni linea è un
# passaggio (fino al compagno o nello spazio); fuori dal rallenty la stessa linea nel vuoto è una corsa
func _metti_fuga() -> void:
	H.wake(opp, c.x + 1.0, c.y - 2.0)
	m.flee = R.Duel.new()
	m.flee.team = 0
	m.flee.p = c
	m.flee.o = opp


func test_fuga_ogni_linea_e_un_passaggio() -> bool:
	prepara()
	_metti_fuga()
	H.wake(mate, -8.0, 6.0)
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(mate.x, mate.y)))
	eq(reg.nomi(), ["kick"], "fino al compagno (entro 5 m) = passaggio")
	prepara()
	_metti_fuga()
	H.wake(mate, -8.0, 6.0)
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(6.0, 10.0)))
	eq(reg.nomi(), ["kick"], "anche nello spazio = passaggio")
	prepara()
	trascina(linea(sch(m.ball.x, m.ball.y, 0.3), sch(6.0, 10.0)))
	eq(reg.nomi(), ["kick"], "anche fuori dal rallenty = passaggio (Luis 2026-11-22)")
	return done()


# ---------------------------------------------------------------- di prima (passaggio che viaggia)
## passaggio di c al compagno mate già partito (il pallone viaggia, nessuno lo tiene)
func _passaggio_in_volo() -> void:
	prepara()
	H.wake(mate, 0.0, 18.0)
	m.userKick(0, {"type": "ground", "tx": mate.x, "ty": mate.y})
	m.step(DT)
	m.ctrl[0] = mate
	m.events.clear()


func test_di_prima_linea_dal_compagno_che_riceve_aspetta_il_pallone() -> bool:
	_passaggio_in_volo()
	eq(m.hint(0), "loose", "pallone in volo")
	g.down(sch(mate.x, mate.y, 0.9), 1000)
	eq(g.mode, "prima", "dito sul compagno che riceve = si disegna il calcio dopo")
	check(g.drawing, "si sta disegnando")
	for p in linea(sch(mate.x, mate.y, 0.9), sch(-12.0, 30.0)).slice(1):
		g.move_ev(p)
	eq(v.kind, "pass", "la linea si vede mentre si disegna")
	g.up(sch(-12.0, 30.0), 1300)
	eq(reg.nomi(), ["queue"], "un ordine: calcio in attesa")
	eq(reg.calls[0][1], mate.i, "per il compagno che riceve")
	check(m.queued[0] != null, "il motore lo tiene in attesa")
	check(not g.attesa_viva().is_empty(), "l'HUD mostra la linea in attesa")
	var calci := []
	for i in 240:
		m.step(DT)
		g.update(1300 + i * 16)
		for e: Dictionary in m.events:
			if e.type == "kick":
				calci.append(e)
		m.events.clear()
		if not calci.is_empty():
			break
	eq(calci.size(), 1, "appena arriva il pallone il compagno calcia")
	if calci.size() == 1:
		check(calci[0].p == mate and calci[0].prima, "di prima, dal compagno")
	check(g.attesa_viva().is_empty(), "linea in attesa tolta")
	return done()


func test_di_prima_dito_lontano_dal_volo_resta_linea_di_difesa() -> bool:
	_passaggio_in_volo()
	var altro: R.Player = m.team(0)[5]
	H.wake(altro, -25.0, -10.0)
	g.down(sch(altro.x, altro.y, 0.9), 1000)
	eq(g.mode, "dpath", "compagno lontano dal volo del pallone: linea da correre come prima")
	return done()


func test_di_prima_si_annulla_se_il_pallone_lo_prende_un_avversario() -> bool:
	_passaggio_in_volo()
	g.down(sch(mate.x, mate.y, 0.9), 1000)
	for p in linea(sch(mate.x, mate.y, 0.9), sch(-12.0, 30.0)).slice(1):
		g.move_ev(p)
	g.up(sch(-12.0, 30.0), 1300)
	check(m.queued[0] != null, "in attesa")
	H.wake(opp, m.ball.x, m.ball.y + 2.0)
	var preso := false
	for i in 120:
		m.step(DT)
		g.update(1300 + i * 16)
		m.events.clear()
		if m.ball.owner == opp:
			preso = true
			break
	check(preso, "l'avversario intercetta")
	check(m.queued[0] == null, "calcio di prima annullato")
	check(g.attesa_viva().is_empty(), "linea in attesa tolta")
	return done()
