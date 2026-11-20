# Scena di prova della fase 1: campo, stadio, 22 giocatori in 4-4-2 che corrono avanti e indietro, pallone che
# passa tra i giocatori della squadra di casa, telecamera verticale come nel gioco web, contatore FPS e memoria.
# Non c'è ancora il motore di gioco: i movimenti sono finti, servono solo a vedere grafica, animazioni e prestazioni.
#
# Tocchi (un dito; col mouse sul PC funziona uguale):
# - tocca un giocatore: lo scegli (anello giallo); toccalo di nuovo per lasciarlo;
# - tocca il campo con un giocatore scelto: corre lì; senza giocatore scelto la visuale va lì;
# - trascina: sposti la visuale (poi torna piano sul pallone).
#
# Opzioni da riga di comando (dopo "--"), per le prove automatiche:
#   --schermata=PERCORSO.png [--dopo=SEC]  salva una schermata dopo SEC secondi (predefinito 3) ed esce;
#                                          un percorso relativo parte dalla cartella del repo (es. shots/x.png)
#   --esci-dopo=SEC                        esce dopo SEC secondi e stampa gli FPS medi
#   --senza-vsync                          niente limite agli FPS (per misurare quanto regge il PC)
#   --scala-3d=K                           risoluzione del 3D (0,5..1), come sull'iPhone
#   --prova-tocchi                         simula un tocco su un giocatore e uno sul campo e controlla che corra lì
#                                          (serve la finestra: senza schermo i tocchi simulati non arrivano)
#   --scegli=N                             parte col giocatore N già scelto (0..21; 9 = centravanti di casa)
#   --vista=vicina|porta|alta              telecamera fissa di prova: vicino a un giocatore, davanti a una porta,
#                                          dall'alto su tutto il campo
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const Giocatore := preload("res://scripts/giocatore.gd")

# divise come nel gioco web (src/career.js, KITS: Rosso e Blu; portieri arancio e verde)
const KIT_CASA := {"maglia": Color("#c8102e"), "calzoncini": Color("#ffffff"), "calzettoni": Color("#c8102e"), "bordino": Color("#ffffff")}
const KIT_OSPITI := {"maglia": Color("#1746a2"), "calzoncini": Color("#ffffff"), "calzettoni": Color("#1746a2"), "bordino": Color("#ffffff")}
const KIT_PORTIERE_CASA := {"maglia": Color("#ffa41c"), "calzoncini": Color("#222222"), "calzettoni": Color("#ffa41c"), "bordino": Color("#222222")}
const KIT_PORTIERE_OSPITI := {"maglia": Color("#2ad17a"), "calzoncini": Color("#15803d"), "calzettoni": Color("#15803d"), "bordino": Color("#15803d")}
const PELLI := [Color("#f1c9a5"), Color("#d9a47a"), Color("#a9744f"), Color("#6b4630")]   # src/render.js SKIN
const CAPELLI := [Color("#1c1410"), Color("#4a2f1b"), Color("#8a5a2b"), Color("#d9b66a"), Color("#222222")]

# 4-4-2 della squadra 0 (attacca verso +y): ruolo, x, y (m)
const FORMAZIONE := [
	["P", 0.0, -46.0],
	["D", -20.0, -31.0], ["D", -7.0, -34.0], ["D", 7.0, -34.0], ["D", 20.0, -31.0],
	["C", -22.0, -14.0], ["C", -7.0, -17.0], ["C", 7.0, -17.0], ["C", 22.0, -14.0],
	["A", -6.0, -3.0], ["A", 6.0, -5.0],
]
# corsa avanti e indietro per ruolo: ampiezza (m) e velocità angolare (rad/s) della corsa personale
const CORSA := {"P": [0.0, 0.0], "D": [3.0, 0.55], "C": [5.0, 0.7], "A": [5.0, 0.95]}
const ONDA_AMPIEZZA := 10.0   # tutta la squadra sale e scende insieme (m)
const ONDA_W := 0.35          # rad/s
const LATO_AMPIEZZA := 1.5    # un po' di movimento laterale (m)
const COMANDO_V := 7.0        # m/s: velocità di chi corre dove l'ha mandato il dito
const ARRIVATO := 0.3         # m
const PALLA_R := 0.11 * Coord.SCALE
const PASSA_OGNI := 2.6       # secondi tra un passaggio e l'altro
const PASSAGGIO_V := 15.0     # m/s
const PASSAGGIO_MAX := 32.0   # distanza massima di un passaggio (m)
const PIEDE_AVANTI := 0.7     # il pallone sta così davanti al portatore (m)
const TOCCO_MAX_PX := 14.0    # oltre questo movimento il dito trascina invece di toccare (punti)
const PRESA_PX := 34.0        # raggio di presa di un giocatore sullo schermo (punti)
const RISOLUZIONE_3D_LARGO := 780.0   # sul telefono il 3D si disegna largo al massimo così (px): 2× la larghezza logica

class Atleta:
	var nodo: Node3D
	var squadra := 0
	var ruolo := "C"
	var base := Vector2.ZERO      # posizione di partenza (gioco)
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var fase := 0.0
	var comando: Variant = null   # Vector2 dove l'ha mandato il dito

var _atleti: Array[Atleta] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _palla: MeshInstance3D
var _palla_pos := Vector2.ZERO
var _palla_h := PALLA_R
var _portatore := 9
var _ricevitore := -1
var _volo_da := Vector2.ZERO
var _volo_t := 0.0
var _volo_durata := 1.0
var _prossimo_passaggio := PASSA_OGNI
var _scelto := -1
var _anello: MeshInstance3D
var _dito_giu := false
var _dito_inizio := Vector2.ZERO
var _dito_ultimo := Vector2.ZERO
var _trascina := false
var _opzioni := {}

@onready var _telecamera: Camera3D = $Telecamera
@onready var _squadre: Node3D = $Squadre
@onready var _sole: DirectionalLight3D = $Sole
@onready var _hud: CanvasLayer = $Hud


func _ready() -> void:
	_rng.seed = 7
	_leggi_opzioni()
	_sole.look_at_from_position(Vector3(-0.42, 0.78, -0.46) * 60.0, Vector3.ZERO, Vector3.UP)
	_imposta_risoluzione_3d()
	_crea_squadre()
	_crea_palla()
	_crea_anello()
	_avvia_prove()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	_t += dt
	for i in _atleti.size():
		_muovi(_atleti[i], dt)
	_aggiorna_palla(dt)
	if _opzioni.has("vista"):
		_vista_di_prova(_opzioni["vista"])
	else:
		_telecamera.segui(_palla_pos, dt, _trascina)
	if _scelto >= 0:
		var a := _atleti[_scelto]
		_anello.visible = true
		_anello.position = Coord.a_godot(a.pos.x, a.pos.y, 0.03)
	else:
		_anello.visible = false


# ---------------------------------------------------------------- squadre
func _crea_squadre() -> void:
	for squadra in 2:
		var lato := 1.0 if squadra == 0 else -1.0
		for k in FORMAZIONE.size():
			var f: Array = FORMAZIONE[k]
			var a := Atleta.new()
			a.squadra = squadra
			a.ruolo = f[0]
			a.base = Vector2(f[1], f[2]) * lato
			a.pos = a.base
			a.fase = _rng.randf() * TAU
			var kit: Dictionary
			if a.ruolo == "P":
				kit = KIT_PORTIERE_CASA if squadra == 0 else KIT_PORTIERE_OSPITI
			else:
				kit = KIT_CASA if squadra == 0 else KIT_OSPITI
			var aspetto := {"pelle": PELLI[_rng.randi() % PELLI.size()], "capelli": CAPELLI[_rng.randi() % CAPELLI.size()]}
			var g := Giocatore.new()
			g.name = "%s%d" % ["Casa" if squadra == 0 else "Ospiti", k + 1]
			_squadre.add_child(g)
			g.prepara(kit, aspetto, _rng.randf() * 2.0)
			g.guarda(0.0, lato)
			a.nodo = g
			_atleti.append(a)


# posizione "di copione" dell'atleta al tempo t (prima dei comandi del dito)
func _copione(a: Atleta, t: float) -> Vector2:
	var lato := 1.0 if a.squadra == 0 else -1.0
	if a.ruolo == "P":
		return Vector2(clampf(_palla_pos.x * 0.12, -2.5, 2.5), a.base.y)
	var c: Array = CORSA[a.ruolo]
	var onda := ONDA_AMPIEZZA * sin(t * ONDA_W)               # tutta la partita si sposta avanti e indietro
	var personale: float = c[0] * sin(t * c[1] + a.fase) * lato
	var laterale := LATO_AMPIEZZA * sin(t * 0.4 + a.fase * 1.7)
	return a.base + Vector2(laterale, onda + personale)


func _muovi(a: Atleta, dt: float) -> void:
	var prima := a.pos
	if a.comando != null:
		var meta: Vector2 = a.comando
		var d := meta - a.pos
		if d.length() <= ARRIVATO:
			a.pos = meta
			a.base += meta - _copione(a, _t)   # da qui riprende a correre attorno al nuovo posto
			a.comando = null
		else:
			a.pos += d.normalized() * minf(d.length(), COMANDO_V * dt)
	else:
		a.pos = _copione(a, _t)
	a.pos.x = clampf(a.pos.x, -Coord.HW + 0.5, Coord.HW - 0.5)
	a.pos.y = clampf(a.pos.y, -Coord.HL + 0.5, Coord.HL - 0.5)
	if dt > 0.0:
		a.vel = a.vel.lerp((a.pos - prima) / dt, minf(1.0, dt * 12.0))
	a.nodo.aggiorna(a.pos, a.vel, dt)


# ---------------------------------------------------------------- pallone
func _crea_palla() -> void:
	var sfera := SphereMesh.new()
	sfera.radius = PALLA_R
	sfera.height = PALLA_R * 2.0
	sfera.radial_segments = 24
	sfera.rings = 12
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture_palla()
	m.roughness = 0.45
	_palla = MeshInstance3D.new()
	_palla.name = "Pallone"
	_palla.mesh = sfera
	_palla.material_override = m
	add_child(_palla)
	_palla_pos = _atleti[_portatore].pos


# pallone bianco con 12 macchie scure ai vertici di un icosaedro (texture equirettangolare)
func _texture_palla() -> ImageTexture:
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var vertici: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-phi, phi]:
			vertici.append(Vector3(0, a, b).normalized())
			vertici.append(Vector3(a, b, 0).normalized())
			vertici.append(Vector3(b, 0, a).normalized())
	for y in h:
		var lat := PI * (0.5 - (y + 0.5) / h)
		for x in w:
			var lon := TAU * (x + 0.5) / w
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var vicino := 0.0
			for v in vertici:
				vicino = maxf(vicino, d.dot(v))
			img.set_pixel(x, y, Color(0.08, 0.08, 0.1) if vicino > 0.93 else Color(0.96, 0.96, 0.96))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _aggiorna_palla(dt: float) -> void:
	var prima := _palla_pos
	if _ricevitore >= 0:
		_volo_t += dt
		var k := clampf(_volo_t / _volo_durata, 0.0, 1.0)
		var meta := _davanti_ai_piedi(_atleti[_ricevitore])
		_palla_pos = _volo_da.lerp(meta, k)
		_palla_h = PALLA_R + 4.0 * k * (1.0 - k) * _volo_da.distance_to(meta) * 0.07
		if k >= 1.0:
			_portatore = _ricevitore
			_ricevitore = -1
			_prossimo_passaggio = PASSA_OGNI
	else:
		_palla_pos = _davanti_ai_piedi(_atleti[_portatore])
		_palla_h = PALLA_R + absf(sin(_t * 7.0)) * 0.04
		_prossimo_passaggio -= dt
		if _prossimo_passaggio <= 0.0:
			_passa()
	_palla.position = Coord.a_godot(_palla_pos.x, _palla_pos.y, _palla_h)
	# rotola: gira attorno all'asse perpendicolare al movimento
	var mossa := _palla_pos - prima
	if mossa.length() > 1e-4:
		var asse := Vector3(-mossa.y, 0.0, -mossa.x).normalized()
		_palla.rotate(asse, mossa.length() / PALLA_R)
		_palla.basis = _palla.basis.orthonormalized()   # tante rotazioni di fila deformerebbero la palla


func _davanti_ai_piedi(a: Atleta) -> Vector2:
	var dir := a.vel.normalized() if a.vel.length() > 0.5 else Vector2(0, 1.0 if a.squadra == 0 else -1.0)
	return a.pos + dir * PIEDE_AVANTI


# passaggio a un compagno della squadra di casa (non al portiere), scelto a caso tra quelli abbastanza vicini
func _passa() -> void:
	var da := _atleti[_portatore]
	var candidati: Array[int] = []
	for i in _atleti.size():
		var b := _atleti[i]
		if i != _portatore and b.squadra == 0 and b.ruolo != "P" and b.pos.distance_to(da.pos) < PASSAGGIO_MAX:
			candidati.append(i)
	if candidati.is_empty():
		_prossimo_passaggio = PASSA_OGNI
		return
	_ricevitore = candidati[_rng.randi() % candidati.size()]
	_volo_da = _palla_pos
	_volo_t = 0.0
	_volo_durata = maxf(0.4, _volo_da.distance_to(_atleti[_ricevitore].pos) / PASSAGGIO_V)


# ---------------------------------------------------------------- tocchi
func _crea_anello() -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.75
	t.outer_radius = 0.92
	t.rings = 24
	t.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#ffd400")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_anello = MeshInstance3D.new()
	_anello.name = "Anello"
	_anello.mesh = t
	_anello.material_override = m
	_anello.scale = Vector3(1.0, 0.15, 1.0)
	_anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anello.visible = false
	add_child(_anello)


# l'app perde il fuoco (sottofondo, centro di controllo): il dito non è più giù
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_dito_giu = false
		_trascina = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.index != 0:
			return
		if e.pressed:
			_dito_giu = true
			_trascina = false
			_dito_inizio = e.position
			_dito_ultimo = e.position
		else:
			var annullato := e.canceled   # gesto di sistema, chiamata, app in sottofondo: non è un tocco
			var era_tocco := _dito_giu and not _trascina
			_dito_giu = false
			_trascina = false
			if era_tocco and not annullato:
				_tocco(e.position)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index != 0 or not _dito_giu:
			return
		if not _trascina and e.position.distance_to(_dito_inizio) > TOCCO_MAX_PX:
			_trascina = true
		if _trascina:
			var prima: Variant = _telecamera.punto_campo(_dito_ultimo)
			var ora: Variant = _telecamera.punto_campo(e.position)
			if prima != null and ora != null:
				_telecamera.spostamento -= (ora as Vector2) - (prima as Vector2)
		_dito_ultimo = e.position


func _tocco(schermo: Vector2) -> void:
	var i := _giocatore_sotto(schermo)
	if i >= 0:
		_scelto = -1 if i == _scelto else i
		return
	var punto: Variant = _telecamera.punto_campo(schermo)
	if punto == null:
		return
	var p: Vector2 = punto
	p.x = clampf(p.x, -Coord.HW, Coord.HW)
	p.y = clampf(p.y, -Coord.HL, Coord.HL)
	if _scelto >= 0:
		_atleti[_scelto].comando = p
	else:
		_telecamera.spostamento = p - _palla_pos


# indice del giocatore più vicino al punto dello schermo (entro PRESA_PX), −1 se nessuno
func _giocatore_sotto(schermo: Vector2) -> int:
	var migliore := -1
	var dist_min := PRESA_PX
	for i in _atleti.size():
		var a := _atleti[i]
		var centro := Coord.a_godot(a.pos.x, a.pos.y, 1.0 * Coord.SCALE)
		if _telecamera.is_position_behind(centro):
			continue
		var d := _telecamera.unproject_position(centro).distance_to(schermo)
		if d < dist_min:
			dist_min = d
			migliore = i
	return migliore


func _schermo_di(i: int) -> Vector2:
	var a := _atleti[i]
	return _telecamera.unproject_position(Coord.a_godot(a.pos.x, a.pos.y, 1.0 * Coord.SCALE))


# ---------------------------------------------------------------- risoluzione 3D
# Sull'iPhone lo schermo ha 3 pixel per punto: disegnare il 3D a piena risoluzione costa tanto. Il 3D si disegna
# largo al massimo RISOLUZIONE_3D_LARGO px e si ingrandisce con FSR; l'interfaccia resta nitida.
func _imposta_risoluzione_3d() -> void:
	var vp := get_viewport()
	var scala := 1.0
	if _opzioni.has("scala-3d"):
		scala = clampf(float(_opzioni["scala-3d"]), 0.5, 1.0)
	elif OS.has_feature("mobile"):
		var largo_px := vp.get_visible_rect().size.x * vp.get_final_transform().get_scale().x
		scala = clampf(RISOLUZIONE_3D_LARGO / maxf(1.0, largo_px), 0.5, 1.0)
	vp.scaling_3d_scale = scala
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scala < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR


# ---------------------------------------------------------------- prove da riga di comando
func _leggi_opzioni() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parti := arg.substr(2).split("=", true, 1)
			_opzioni[parti[0]] = parti[1] if parti.size() > 1 else "1"


func _avvia_prove() -> void:
	if _opzioni.has("senza-vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	if _opzioni.has("scegli"):
		_scelto = clampi(int(_opzioni["scegli"]), 0, _atleti.size() - 1)
	if _opzioni.has("prova-tocchi"):
		_prova_tocchi()
	if _opzioni.has("schermata"):
		await get_tree().create_timer(float(_opzioni.get("dopo", "3"))).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var percorso: String = _opzioni["schermata"]
		if percorso.is_relative_path():   # relativo alla cartella del repo (quella che contiene godot/)
			percorso = ProjectSettings.globalize_path("res://").path_join("..").path_join(percorso).simplify_path()
		DirAccess.make_dir_recursive_absolute(percorso.get_base_dir())
		var err := img.save_png(percorso)
		print("schermata %s %dx%d errore=%d" % [percorso, img.get_width(), img.get_height(), err])
		_esci()
	elif _opzioni.has("esci-dopo"):
		await get_tree().create_timer(float(_opzioni["esci-dopo"])).timeout
		_esci()


func _esci() -> void:
	print("FPS medi %.1f (ultimo %d) · %s · disegni %d" % [
		_hud.fps_medi(), Engine.get_frames_per_second(), _hud.testo_memoria(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	get_tree().quit(0)


# tocco simulato su un difensore della squadra di casa, poi sul campo: deve correre lì
func _prova_tocchi() -> void:
	await get_tree().create_timer(1.0).timeout
	var chi := _giocatore_al_centro()
	_simula_tocco(_schermo_di(chi))
	await get_tree().process_frame
	if _scelto != chi:
		push_error("prova tocchi: toccando il giocatore %d è stato scelto %d" % [chi, _scelto])
		return
	var meta := _atleti[chi].pos + Vector2(6.0, 8.0)
	var schermo := _telecamera.unproject_position(Coord.a_godot(meta.x, meta.y))
	_simula_tocco(schermo)
	await get_tree().process_frame
	var comando: Variant = _atleti[chi].comando
	if comando == null or (comando as Vector2).distance_to(meta) > 0.5:
		push_error("prova tocchi: il comando non va dove ho toccato (%s invece di %s)" % [comando, meta])
		return
	# arrivato quando il comando si chiude (poi riprende a correre attorno al nuovo posto)
	var limite := Time.get_ticks_msec() + 4000
	while _atleti[chi].comando != null and Time.get_ticks_msec() < limite:
		await get_tree().process_frame
	var arrivo := _atleti[chi].pos.distance_to(meta)
	if _atleti[chi].comando != null or arrivo > 1.0:
		push_error("prova tocchi: il giocatore non è arrivato (manca %.1f m)" % arrivo)
		return
	print("prova tocchi: ok (giocatore %d scelto, arrivato a %.2f m dal punto toccato)" % [chi, arrivo])


# il giocatore della squadra di casa più vicino al centro dello schermo (per la prova dei tocchi)
func _giocatore_al_centro() -> int:
	var centro := get_viewport().get_visible_rect().size / 2.0
	var migliore := 0
	var dist_min := INF
	for i in _atleti.size():
		var a := _atleti[i]
		if a.squadra != 0 or i == _portatore or _telecamera.is_position_behind(Coord.a_godot(a.pos.x, a.pos.y)):
			continue
		var d := _schermo_di(i).distance_to(centro)
		if d < dist_min:
			dist_min = d
			migliore = i
	return migliore


func _simula_tocco(schermo: Vector2) -> void:
	for giu in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = schermo
		e.pressed = giu
		Input.parse_input_event(e)


# telecamere fisse per guardare da vicino modello e divisa, porta e rete, righe del campo
func _vista_di_prova(nome: String) -> void:
	match nome:
		"porta":
			_telecamera.look_at_from_position(Coord.a_godot(9.0, 36.0, 3.2), Coord.a_godot(0.0, Coord.HL, 1.0), Vector3.UP)
		"alta":
			_telecamera.look_at_from_position(Coord.a_godot(0.0, -78.0, 62.0), Coord.a_godot(0.0, 2.0, 0.0), Vector3.UP)
		_:
			var a := _atleti[_scelto if _scelto >= 0 else 9]
			var p := Coord.a_godot(a.pos.x + 2.2, a.pos.y + 3.2, 1.9)
			_telecamera.look_at_from_position(p, Coord.a_godot(a.pos.x, a.pos.y, 1.15), Vector3.UP)
