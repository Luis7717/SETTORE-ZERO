# Prove della partita vera (scena scenes/partita.tscn con la vista vera, motore, gesti e HUD), anche senza schermo:
#   $G --headless --path godot -s res://tests/prova_partita.gd          (esce con 0 se tutto bene, 1 se no)
# 1. Allenamento guidato: dopo il setup di ogni lezione il nodo del pallone c'è, è acceso, sta dove dice il motore
#    (ball.x/y/h, a meno dello spostamento dei giochetti) ed è dentro l'inquadratura; il materiale non ha la normal map
#    (sull'iPhone il pallone non si vedeva, vedi vista.gd materiale_pallone).
# 2. Lezione Portiere col tocco vero: InputEventScreenTouch / ScreenDrag passati da Input come fa iOS (in pixel della
#    finestra, con la scala dello schermo), dal portiere al punto della porta dove arriva il tiro, con la telecamera
#    dietro la porta: al rilascio il motore riceve il tuffo (stato "dive", verso il punto giusto), la telecamera resta
#    sulla parata e la figura del portiere si vede tuffarsi (testa giù e di lato rispetto ai piedi).
# Con la finestra (senza --headless) e `-- --foto=CARTELLA` salva anche una schermata per lezione e una del tuffo.
extends SceneTree

const R := preload("res://sim/records.gd")
const C := preload("res://sim/core.gd")
const Allenamento := preload("res://scripts/partita/allenamento.gd")
const LIMITE_FOTOGRAMMI := 20000
const PALLA_TOLL := 0.8         # m tra il pallone a schermo e quello del motore (giochetti e mani a parte)
const FOTOGRAMMI_DOPO_SETUP := 30  # mezzo secondo di gioco: la telecamera è arrivata
const TUFFO_SECONDI := 0.3      # s di gioco dopo il rilascio in cui guardare la figura

var g: Node
var fallimenti: Array[String] = []
var controlli := 0
var fase := "lezioni"
var lezione := 0
var attesa := 0
var n := 0
# tuffo
var gk_schermo := Vector2.ZERO
var meta_schermo := Vector2.ZERO
var meta_x := 0.0
var passo := 0
var testa_prima := Vector3.ZERO
var t_rilascio := 0.0


var cartella_foto := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--foto="):
			cartella_foto = a.substr(7)
			DirAccess.make_dir_recursive_absolute(cartella_foto)
	g = (load("res://scenes/partita.tscn") as PackedScene).instantiate()
	g._opzioni["allenamento"] = "1"
	g._opzioni["seme"] = "11"
	g._opzioni["veloce"] = "1"  # passo fisso di 1/60 s: uguale con e senza schermo
	root.add_child(g)


func check(ok: bool, msg: String) -> void:
	controlli += 1
	if not ok:
		fallimenti.append(msg)
		print("FALLITO  " + msg)


func fine() -> void:
	print("prova_partita: %d controlli, %d falliti" % [controlli, fallimenti.size()])
	quit(0 if fallimenti.is_empty() else 1)


func _process(_d: float) -> bool:
	n += 1
	if n > LIMITE_FOTOGRAMMI:
		check(false, "tempo scaduto nella fase %s" % fase)
		fine()
		return false
	if g.m == null or g.allenamento == null:
		return false
	match fase:
		"lezioni":
			_lezioni()
		"tuffo_attesa":
			_tuffo_attesa()
		"tuffo_dito":
			_tuffo_dito()
		"tuffo_dopo":
			_tuffo_dopo()
	return false


# ---------------------------------------------------------------- 1. pallone dopo il setup di ogni lezione
func _lezioni() -> void:
	var t = g.allenamento
	if attesa == 0:
		while t.li < lezione:
			t.next_lesson()
		if t.card:
			g._all_hud.premi_prova()
		attesa = 1
		return
	attesa += 1
	if attesa < FOTOGRAMMI_DOPO_SETUP:
		return
	_controlla_pallone(String(t.lesson().id))
	_foto("%d_%s" % [lezione + 1, t.lesson().id])
	lezione += 1
	attesa = 0
	if lezione >= t.lessons.size():
		# lezione Portiere da capo, per il tuffo
		t.li = t.lessons.size() - 2
		t.next_lesson()
		g._all_hud.premi_prova()
		fase = "tuffo_attesa"


func _controlla_pallone(id: String) -> void:
	var v = g.vista
	var b: R.Ball = g.m.ball
	var nodo: MeshInstance3D = v._ball
	check(nodo != null and nodo.is_inside_tree(), "%s: il nodo del pallone c'è" % id)
	if nodo == null:
		return
	check(nodo.is_visible_in_tree(), "%s: pallone acceso" % id)
	var atteso := Vector3(v.flip * b.x, b.h + v.BALL_R, -v.flip * b.y)
	var d := nodo.global_position.distance_to(atteso)
	var giochetto: bool = not v._trick_of(b.owner).is_empty()
	check(giochetto or d < PALLA_TOLL, "%s: pallone a schermo a %.2f m da quello del motore" % [id, d])
	check(nodo.global_position.is_finite() and nodo.global_basis.is_finite(), "%s: posizione e giro del pallone finiti" % id)
	check((v.cam as Camera3D).is_position_in_frustum(nodo.global_position), "%s: pallone dentro l'inquadratura" % id)
	var mat := nodo.material_override as StandardMaterial3D
	check(mat != null and not mat.normal_enabled, "%s: materiale del pallone senza normal map" % id)
	check(mat != null and mat.albedo_texture != null, "%s: texture del pallone" % id)


# ---------------------------------------------------------------- 2. tuffo col tocco vero
func _tuffo_attesa() -> void:
	var m = g.m
	if m.hint(0) != "dive":
		attesa = 0
		return
	attesa += 1
	if attesa < 20: # la telecamera va dietro la porta
		return
	var gk: R.Player = m.gk(0)
	var s: R.Shot = m.ball.shot
	check(g.vista.cam._gk_k > 0.5, "telecamera della parata accesa quando si può parare")
	var a: Vector3 = g.vista.world_to_screen(gk.x, gk.y, 1.0)
	meta_x = clampf(s.cx, -C.GW / 2.0 + 0.4, C.GW / 2.0 - 0.4)
	var b: Vector3 = g.vista.world_to_screen(meta_x, -C.HL, clampf(s.ch, 0.4, 2.0))
	gk_schermo = Vector2(a.x, a.y)
	meta_schermo = Vector2(b.x, b.y)
	var f: Node3D = g.vista._figs[m.players.find(gk)]
	testa_prima = _testa(f)
	_tocca(true, gk_schermo)
	check(g.gesti.mode == "dive", "il tocco sul portiere apre il gesto del tuffo (modo %s)" % g.gesti.mode)
	passo = 0
	fase = "tuffo_dito"


func _tuffo_dito() -> void:
	passo += 1
	var k := passo / 8.0
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = gk_schermo.lerp(meta_schermo, k)
	e.relative = (meta_schermo - gk_schermo) / 8.0
	_invia(e)
	if passo < 8:
		return
	var m = g.m
	var gk: R.Player = m.gk(0)
	check(gk.state == "play", "finché il dito è giù il portiere non si tuffa")
	var tv: Variant = g.gesti.dive_target()
	check(tv != null and absf(float(tv.x) - meta_x) < 0.3, "punto in porta sotto il dito: %s (atteso x=%.2f)" % [tv, meta_x])
	_tocca(false, meta_schermo)
	check(gk.state == "dive", "al rilascio il motore riceve il tuffo (stato %s)" % gk.state)
	if gk.dive != null:
		check(absf(gk.dive.tx - clampf(meta_x, -C.GW / 2.0 - 0.9, C.GW / 2.0 + 0.9)) < 0.3, "tuffo verso il punto indicato (%.2f)" % gk.dive.tx)
	t_rilascio = m.time
	fase = "tuffo_dopo"


func _tuffo_dopo() -> void:
	var m = g.m
	var gk: R.Player = m.gk(0)
	if m.time - t_rilascio < TUFFO_SECONDI and gk.state == "dive":
		return
	check(gk.state == "dive" or gk.state == "down", "portiere ancora in tuffo dopo %.2f s (stato %s)" % [m.time - t_rilascio, gk.state])
	var in_volo: bool = m.ball.shot != null and m.ball.owner == null
	if in_volo:
		check(g.vista.cam._gk_k > 0.5, "tiro in volo: la telecamera resta sulla parata e si vede il tuffo (%.2f)" % g.vista.cam._gk_k)
	var f: Node3D = g.vista._figs[m.players.find(gk)]
	var testa := _testa(f)
	var piedi := f.global_position
	var di_lato := Vector2(testa.x - piedi.x, testa.z - piedi.z).length()
	print("tuffo: testa prima %s, adesso %s (piedi %s): di lato %.2f m, altezza %.2f m" % [testa_prima, testa, piedi, di_lato, testa.y])
	_foto("8_tuffo")
	check(di_lato > 0.6 or testa.y < testa_prima.y - 0.5, "la figura del portiere si tuffa (testa di lato %.2f m, altezza %.2f → %.2f)" % [di_lato, testa_prima.y, testa.y])
	fine()


func _foto(nome: String) -> void:
	if cartella_foto == "" or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	img.save_png(cartella_foto.path_join(nome + ".png"))


# testa della figura nel mondo
func _testa(f: Node3D) -> Vector3:
	f._gcache.clear()
	return f.global_transform * (f.corpo.transform * f.pos_corpo("Head"))


# tocco come lo manda iOS: posizione in pixel della finestra, passata da Input (che lo gira alla vista)
func _tocca(giu: bool, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = giu
	e.position = p
	_invia(e)


func _invia(e: InputEvent) -> void:
	var tr := root.get_final_transform()
	var e2: InputEvent = e.duplicate()
	e2.position = tr * e.position
	if e2 is InputEventScreenDrag:
		e2.relative = tr.basis_xform(e.relative)
	Input.parse_input_event(e2)
	Input.flush_buffered_events()
