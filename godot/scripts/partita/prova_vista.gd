# Scena di prova della vista della partita (fase 2): il motore (SimMatch) gioca da solo, computer contro computer,
# e la vista lo disegna con update_view() a ogni fotogramma. Non ci sono gesti né interfaccia di gioco: servono a
# guardare grafica, telecamere e prestazioni. Ogni dribbling del motore fa partire un giochetto (vista.trick).
#
# Opzioni da riga di comando (dopo "--"):
#   --scena=NOME          partita (predefinita) · rallenty (visuale larga col dito che disegna) · girata (rallenty con la
#                         visuale girata) · parata (tiro avversario, visuale dietro la porta) · angolo (calcio d'angolo)
#                         · giochetto (arcobaleno da vicino) · gol (la rete si gonfia) · linea (passaggio disegnato, anteprima e linee di difesa)
#   --schermata=PERCORSO.png [--dopo=SEC]   salva una schermata dopo SEC secondi ed esce (percorso relativo = dal repo)
#   --sequenza=N [--ogni=SEC]               con --schermata: N schermate a distanza di SEC secondi (_1, _2, ...)
#   --esci-dopo=SEC       esce dopo SEC secondi e stampa FPS medi e tempo del fotogramma
#   --senza-vsync         niente limite agli FPS (per misurare quanto regge il PC)
#   --seme=N              seme della partita (predefinito 7)
#   --controlla           controlla le conversioni schermo/campo/porta della vista (anche con --me=1 e girata) ed esce
#   --me=0|1              squadra umana (1 = campo capovolto, si attacca sempre "in su")
#   --vicino=N            telecamera fissa vicina al giocatore m.players[N] (0 = portiere di casa)
#   animazioni mocap (figura_mocap.gd), telecamera vicina a chi le fa:
#   --scena=esultanza | tiro | piatto | rimessa | difesa   (e parata con --tuffo=X,ALTEZZA per scegliere il tuffo)
#   --senza-mocap         le stesse scene con le pose calcolate (per confronto)
#   --traccia=N|segui     stampa a ogni fotogramma lo stato mocap di m.players[N] o di quello seguito (clip, tempo, peso)
extends Node

const VISTA := preload("res://scenes/vista_partita.tscn")
const HUD := preload("res://scripts/hud.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const SimRng := preload("res://sim/rng.gd")
const DT := 1.0 / 60.0
const SLOW := 0.22             # rallenty (come l'area di tiro del gioco web)
const FiguraMocap := preload("figura_mocap.gd")

var vista: PartitaVista
var m: SimMatch
var _hud: CanvasLayer
var _opz := {}
var _scena := "partita"
var _acc := 0.0
var _ts := 1.0                 # velocità del tempo di gioco
var _fermo := false            # motore fermo (la vista continua a girare: giochetto da vicino)
var _ms := PackedFloat32Array()
var _us_motore := 0             # microsecondi spesi nel motore e nella vista (per le misure)
var _us_vista := 0
var _n := 0
var _segui: Object = null      # giocatore da guardare da vicino (scene mocap)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parti := arg.substr(2).split("=", true, 1)
			_opz[parti[0]] = parti[1] if parti.size() > 1 else "1"
	_scena = _opz.get("scena", "partita")
	FiguraMocap.spento = _opz.has("senza-mocap")
	if _opz.has("senza-vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	vista = VISTA.instantiate()
	add_child(vista)
	_hud = HUD.new()
	add_child(_hud)
	_hud.get_child(1).text = "Prova della vista: computer contro computer · scena " + _scena
	var seme := int(_opz.get("seme", "7"))
	m = SimMatch.new({"seed": seme, "halfLen": 600.0, "human": [false, false], "kickoff": 0,
		"teams": [squadra("Rossi", 74.0, seme * 3 + 1), squadra("Blu", 72.0, seme * 3 + 2)]})
	vista.setup(m, int(_opz.get("me", "0")))
	await _prepara_scena()
	_avvia_prove()


func _exit_tree() -> void:
	if vista != null:
		vista.dispose()
	if m != null:
		m.dispose()


# squadra inventata con statistiche intorno a `rating` (come tests/harness.gd mkTeam, che non va nell'app)
static func squadra(nome: String, rating: float, seme: int) -> Dictionary:
	var r := SimRng.new(seme)
	var F: Array = C.FORMATIONS["4-4-2"]
	var players: Array = []
	for i in F.size():
		var s: Array = F[i]
		var p := {"name": nome + str(i), "pos": s[0]}
		for key: String in ["vel", "tir", "pas", "dri", "dif", "fis"]:
			p[key] = int(C.round_(rating + (r.next() - 0.5) * 10.0))
		p["por"] = int(C.round_(rating + (r.next() - 0.5) * 10.0)) + 4 if s[0] == "P" else 20
		players.append(p)
	return {"name": nome, "formation": "4-4-2", "skill": clampf((rating - 42.0) / 48.0, 0.1, 0.95), "players": players}


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	_ms.append(delta * 1000.0)
	var t0 := Time.get_ticks_usec()
	if not _fermo:
		_acc += dt * _ts
		while _acc >= DT:
			m.step(DT)
			_acc -= DT
			_eventi()
	var t1 := Time.get_ticks_usec()
	vista.update_view(dt * _ts, dt)
	_us_motore += t1 - t0
	_us_vista += Time.get_ticks_usec() - t1
	_n += 1
	if _scena == "giochetto":
		_telecamera_vicina(m.ball.owner)
	elif _scena == "gol":
		vista.cam.fov = 55.0
		vista.cam.look_at_from_position(Vector3(9.0, 2.6, -40.0), Vector3(0.0, 1.0, -51.5), Vector3.UP)
	elif _opz.has("vicino"):
		_telecamera_vicina(m.players[int(_opz["vicino"])])
	elif _segui != null:
		_telecamera_vicina(_segui)
	if _opz.has("traccia"):
		var q: Object = _segui if _opz["traccia"] == "segui" else m.players[int(_opz["traccia"])]
		var i := m.players.find(q)
		var o: Object = m.ball.owner
		var d := -1.0 if o == null else Vector2(o.x - q.x, o.y - q.y).length()
		print("%.2f %s %s t=%.2f %s f=(%.2f,%.2f) v=%.1f portatore a %.1f m" % [m.time, m.phase, q.state, q.t, str(vista._figs[i].mocap.stato()), q.fx, q.fy, Vector2(q.vx, q.vy).length(), d])


func _eventi() -> void:
	for e: Dictionary in m.events:
		if e.type == "dribble":
			vista.trick(e.p)
	m.events.clear()


# ---------------------------------------------------------------- scene
func _prepara_scena() -> void:
	match _scena:
		"rallenty", "girata", "linea":
			await _palla_nostra_in_attacco()
			_ts = SLOW
			var c: Object = m.ball.owner
			vista.drawing = true
			if _scena == "girata":
				vista.user_yaw = 0.9
			if _scena == "linea":
				_linee(c)
			else:
				var pts := PackedVector2Array()
				for i in 12:
					var k := i / 11.0
					pts.append(Vector2(c.x + sin(k * 2.2) * 7.0, c.y + k * 16.0))
				vista.show_path(pts, "run")
		"parata":
			await _corri(2.0)
			_tiro_avversario()
			_ts = SLOW
			_tuffo_dopo(0.36)   # senza await: le schermate partono subito, il tuffo arriva dopo
		"esultanza":
			await _corri(1.0)
			_tiro_in_porta()
			_segui = m.players[9]
		"tiro", "piatto":
			await _corri(1.0)
			_calcio_da_vicino(_scena == "tiro")
		"rimessa":
			await _corri(1.0)
			m.setRestart("throw", 0, 32.0, 6.0)
			_segui = m.restart.taker
		"difesa":
			await _difensore_vicino()
		"gol":
			await _corri(1.0)
			_tiro_in_porta()
		"angolo":
			await _corri(1.0)
			m.setRestart("corner", 0, Coord_HW(), 50.0)
		"giochetto":
			await _palla_nostra_in_attacco()
			_fermo = true
			_ts = 1.0
			var c: Object = m.ball.owner
			c.vx = 0.0
			c.vy = 0.0
			c.st.dri = 95.0
			vista.trick(c, 0.1)   # dribbling altissimo e r basso: il più bello, l'arcobaleno
		_:
			pass


static func Coord_HW() -> float:
	return 32.0


# corre la partita (a velocità 1) per sec secondi di gioco
func _corri(sec: float) -> void:
	var fine := m.time + sec
	while m.time < fine:
		await get_tree().process_frame


# aspetta che la squadra 0 abbia il pallone nella metà campo avversaria (al massimo 40 s di gioco)
func _palla_nostra_in_attacco() -> void:
	_ts = 4.0
	var limite := m.time + 40.0
	while m.time < limite:
		var c: Object = m.ball.owner
		if c != null and c.team == 0 and c.pos != "P" and c.y > 8.0 and m.phase == "play":
			break
		await get_tree().process_frame
	_ts = 1.0


# tiro forte della squadra 0 nell'angolo alto, col portiere dall'altra parte: la rete si gonfia
func _tiro_in_porta() -> void:
	var g: R.Player = m.gk(1)
	g.x = -3.4
	g.y = 49.5
	var p: R.Player = m.players[9]
	p.x = 2.0
	p.y = 41.0
	m.ball.owner = p
	m.ball.x = p.x
	m.ball.y = p.y + 0.6
	m.kick(p, {"type": "shot", "tx": 2.0, "ty": 50.0, "th": 1.2, "curve": 0.0})


# il portiere si tuffa verso il palo dove va il tiro (sec di gioco dopo il tiro); --tuffo=X,ALTEZZA lo cambia
func _tuffo_dopo(sec: float) -> void:
	await _corri(sec)
	var tf: PackedStringArray = str(_opz.get("tuffo", "-2.4,1.3")).split(",")
	m.userDive(0, float(tf[0]), float(tf[1]))


# mocap: il numero 9 col pallone, fermo, calcia dopo un attimo (tiro in porta o passaggio a terra a un compagno);
# tempo rallentato per vedere il movimento in sequenza
func _calcio_da_vicino(tiro: bool) -> void:
	var p: R.Player = m.players[9]
	var q: R.Player = m.players[10]
	p.x = 4.0
	p.y = 26.0
	p.fx = 0.0
	p.fy = 1.0
	p.vx = 0.0
	p.vy = 0.0
	q.x = -8.0
	q.y = 30.0
	m.ball.owner = p
	m.ball.x = p.x
	m.ball.y = p.y + 0.6
	_segui = p
	_ts = SLOW
	await _corri(0.25)
	if tiro:
		m.kick(p, {"type": "shot", "tx": 1.5, "ty": 50.0, "th": 1.4, "curve": 0.0})
	else:
		m.kick(p, {"type": "ground", "tx": q.x, "ty": q.y})


# mocap: un avversario col pallone fermo davanti a un nostro difensore a 3 m; il motore si ferma (come nel
# giochetto) e la vista continua: il difensore resta in posizione di difesa
func _difensore_vicino() -> void:
	await _corri(1.0)
	var o: R.Player = m.players[20]
	var d: R.Player = m.players[4]
	o.x = 2.0
	o.y = 6.0
	o.fx = 0.0
	o.fy = -1.0
	d.x = 2.0
	d.y = 3.0
	d.fx = 0.0
	d.fy = 1.0
	for q: R.Player in [o, d]:
		q.vx = 0.0
		q.vy = 0.0
		q.state = "play"
	m.ball.owner = o
	m.ball.x = o.x
	m.ball.y = o.y - 0.6
	m.ball.h = 0.0
	m.ball.vx = 0.0
	m.ball.vy = 0.0
	m.phase = "play"   # anche se il motore era in una ripresa
	m.restart = null
	_segui = d
	_fermo = true


# tiro della squadra 1 verso la porta della squadra 0 (y = −50), dal limite dell'area
func _tiro_avversario() -> void:
	var g: R.Player = m.gk(0)
	g.x = 0.0
	g.y = -49.2
	g.vx = 0.0
	g.vy = 0.0
	var p: R.Player = m.players[20]
	p.x = 9.0
	p.y = -29.0
	m.ball.owner = p
	m.ball.x = p.x
	m.ball.y = p.y - 0.6
	m.human[0] = true
	m.kick(p, {"type": "shot", "tx": -2.6, "ty": -50.0, "th": 1.6, "curve": 0.0})


# passaggio disegnato verso un compagno, puntini del volo e due linee di difesa assegnate
func _linee(c: Object) -> void:
	var best: Object = m.players[9]
	var dmin := INF
	for q: Object in m.players:
		if q.team == 0 and q != c and q.pos != "P":
			var d := Vector2(q.x - c.x, q.y - c.y)
			if d.length() > 8.0 and d.length() < dmin and d.y > 3.0:   # un compagno davanti (a schermo nel rallenty)
				dmin = d.length()
				best = q
	var pts := PackedVector2Array()
	for i in 10:
		var k := i / 9.0
		pts.append(Vector2(lerpf(c.x, best.x, k) + sin(k * PI) * 2.5, lerpf(c.y, best.y, k)))
	vista.show_path(pts, "pass")
	vista.show_preview(m.predictKick(c, {"type": "auto", "tx": best.x, "ty": best.y}), 30.0)
	for i in [2, 3]:
		var d: Object = m.players[i]
		m.userRun(0, d, [{"x": d.x + 4.0, "y": d.y + 5.0}, {"x": d.x + 2.0, "y": d.y + 11.0}])


# telecamera fissa vicina a un giocatore (per guardare il giochetto o il tuffo)
func _telecamera_vicina(c: Object) -> void:
	if c == null:
		return
	var s := vista.flip
	var p := Vector3(s * c.x, 0.0, -s * c.y)
	vista.cam.fov = 50.0
	vista.cam.look_at_from_position(p + Vector3(4.2, 2.1, 3.0), p + Vector3(0, 0.9, 0), Vector3.UP)


# ---------------------------------------------------------------- schermate e misure
func _avvia_prove() -> void:
	if _opz.has("controlla"):
		await get_tree().create_timer(1.0).timeout
		_controlla()
		_esci()
	elif _opz.has("schermata"):
		var n := int(_opz.get("sequenza", "1"))
		await get_tree().create_timer(float(_opz.get("dopo", "2"))).timeout
		for i in n:
			if i > 0:
				await get_tree().create_timer(float(_opz.get("ogni", "0.3"))).timeout
			await RenderingServer.frame_post_draw
			var percorso: String = _opz["schermata"]
			if n > 1:
				percorso = percorso.get_basename() + "_%d.png" % (i + 1)
			_salva(percorso)
		_esci()
	elif _opz.has("esci-dopo"):
		await get_tree().create_timer(float(_opz["esci-dopo"])).timeout
		_esci()


# punto del campo → schermo → campo deve tornare lo stesso, anche con la visuale girata; idem sul piano della porta
func _controlla() -> void:
	var errori := 0
	for yaw: float in [0.0, 0.8]:
		vista.user_yaw = yaw
		vista.drawing = yaw != 0.0
		vista.update_view(0.0, 1.0)
		var c := Vector2(m.ball.x, m.ball.y)
		for d: Vector2 in [Vector2.ZERO, Vector2(6, 4), Vector2(-5, 9), Vector2(3, -2)]:
			var w := c + d
			var sp := vista.world_to_screen(w.x, w.y, 0.0)
			if sp.z < 0.5:
				continue
			var back := vista.screen_to_field(Vector2(sp.x, sp.y))
			if back.distance_to(w) > 0.05:
				errori += 1
				push_error("controllo: campo %s → schermo %s → campo %s (girata %s)" % [w, sp, back, yaw])
		var gy := 50.0 if vista.me == 0 else -50.0
		var gs := vista.world_to_screen(1.5, gy, 1.2)
		var g := vista.screen_to_goal(Vector2(gs.x, gs.y), gy)
		if gs.z > 0.5 and (g.z < 0.5 or Vector2(g.x, g.y).distance_to(Vector2(1.5, 1.2)) > 0.05):
			errori += 1
			push_error("controllo: porta (1.5, 1.2) → %s" % g)
	var alto := vista.world_to_screen(m.ball.x, m.ball.y + (400.0 if vista.me == 0 else -400.0), 150.0)   # sopra l'orizzonte
	var cielo := vista.screen_to_field(Vector2(alto.x, alto.y))
	if cielo.is_finite():
		errori += 1
		push_error("controllo: il cielo dovrebbe dare INF, dà %s" % cielo)
	print("controllo vista (me=%d): %s" % [vista.me, "ok" if errori == 0 else "%d errori" % errori])


func _salva(percorso: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if percorso.is_relative_path():
		percorso = ProjectSettings.globalize_path("res://").path_join("..").path_join(percorso).simplify_path()
	DirAccess.make_dir_recursive_absolute(percorso.get_base_dir())
	var err := img.save_png(percorso)
	print("schermata %s %dx%d errore=%d" % [percorso, img.get_width(), img.get_height(), err])


func _esci() -> void:
	var v := Array(_ms.slice(mini(60, _ms.size() - 1)))   # senza i primi fotogrammi (caricamento)
	v.sort()
	var media := 0.0
	for x: float in v:
		media += x
	media /= maxf(1.0, v.size())
	var p99: float = v[int(v.size() * 0.99)] if not v.is_empty() else 0.0
	print("FPS medi %.1f · fotogramma medio %.2f ms, 99%% sotto %.2f ms · motore %.2f ms + vista %.2f ms per fotogramma · %s · disegni %d · partita %.0f s, %d-%d" % [
		_hud.fps_medi(), media, p99, _us_motore / 1000.0 / maxi(1, _n), _us_vista / 1000.0 / maxi(1, _n), _hud.testo_memoria(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), m.time, m.score[0], m.score[1]])
	get_tree().quit(0)
