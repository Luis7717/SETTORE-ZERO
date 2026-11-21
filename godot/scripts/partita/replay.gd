# Replay del gol (solo grafica, fase C). Il motore non cambia: si registrano gli ultimi secondi in un buffer
# circolare (replay_buffer.gd) e dopo il gol si rigiocano sulla vista, ripresi da un'altra visuale (bassa da dietro
# la porta o bassa di lato), al rallentatore, con la linea del tiro che cresce dietro al pallone. Un tocco lo salta.
#
# Sequenza dopo un gol (gioco.gd):
#   1. gol(m)            evento "goal": stato "attesa"; la festa del motore (fase "goal", 3,2 s) va avanti
#   2. trattieni(m, dt)  nei passi del motore: true = non fare il passo. Quando la festa sta per finire (il passo
#                        dopo partirebbe il calcio d'inizio) il motore resta fermo lì: stato "fermo" e `festa_finita()`
#                        diventa true una volta (gioco.gd chiama allora l'esultanza, poi dopo_esultanza → avvia)
#   3. avvia(vista, hud) parte il replay ("in_onda"); fotogramma(m, vista, dt) a ogni fotogramma
#   4. finito (o saltato con salta()) → "spento", segnale `finito`: il motore riparte e fa il calcio d'inizio
extends Node

signal finito

const ReplayBuffer := preload("replay_buffer.gd")
const Coord := preload("res://scripts/coord.gd")
const CronacaVista := preload("cronaca_vista.gd")

const PRIMA := 2.2             # s di gioco prima del gol rigiocati
const DOPO := 0.6              # ... e dopo (il pallone nella rete)
const LENTO := 0.35            # velocità attorno al tiro (rallentatore pieno)
const VELOCE := 0.75           # velocità nel resto dell'azione
const LENTO_PRIMA := 0.35      # s di gioco prima del tiro da cui si rallenta del tutto...
const LENTO_DOPO := 0.5        # ... fino a questi s dopo il tiro
const DURATA_MAX := 5.0        # s veri al massimo (se l'azione è lunga si accelera tutto)
const CAM_K := 3.5             # 1/s: la telecamera del replay insegue il pallone
const FOV := 48.0
const MIN_CAMPIONI := 10       # con meno campioni (gol appena partita la registrazione) niente replay
const PORTA_FIANCO := 5.0      # visuale "porta": m di lato oltre il palo,
const PORTA_DIETRO := 4.0      # ... dietro la linea di fondo,
const PORTA_H := 2.8           # ... e d'altezza
const LATO_FUORI := 4.0        # visuale "lato": m oltre la linea laterale,
const LATO_DIETRO := 7.0       # ... dietro il pallone (verso la propria metà),
const LATO_H := 3.2            # ... e d'altezza

var buffer := ReplayBuffer.new()
var stato := "spento"          # "spento", "attesa" (gol visto), "fermo" (motore fermo prima del calcio d'inizio), "in_onda"
var visuale := "porta"         # "porta" (bassa da dietro la porta) o "lato" (bassa dalla linea laterale)

var _rng := RandomNumberGenerator.new()
var _visuale_forzata := ""     # prove: --replay=porta|lato
var _festa_finita := false
var _t_gol := 0.0
var _t_tiro := NAN
var _t := 0.0                  # tempo di gioco del replay (m.time registrato)
var _t0 := 0.0
var _t1 := 0.0
var _scala := 1.0              # accelera tutto se il replay verrebbe più lungo di DURATA_MAX
var _lato_porta := 1.0         # +1 = porta a y = +HL
var _lato_cam := 1.0           # da che parte del campo (x) sta la telecamera del replay
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _cam_pronta := false
var _vista: Node = null
var _hud: Node = null
var _scritta: CanvasLayer = null


func _ready() -> void:
	_rng.randomize()
	for arg in OS.get_cmdline_user_args():
		if arg == "--replay=porta" or arg == "--replay=lato":
			_visuale_forzata = arg.substr(9)
	_crea_scritta()


func attivo() -> bool:
	return stato == "in_onda"


## evento "goal" del motore: il replay partirà alla fine della festa
func gol(m: Object) -> void:
	_t_gol = m.time
	_lato_porta = signf(buffer.pallone_a(_t_gol).y)
	if _lato_porta == 0.0:
		_lato_porta = 1.0
	stato = "attesa"
	_festa_finita = false


## nei passi del motore (prima di ogni m.step): true = il motore resta fermo (festa finita, esultanza o replay)
func trattieni(m: Object, dt: float) -> bool:
	if stato == "fermo" or stato == "in_onda":
		return true
	if stato == "attesa":
		if m.phase != "goal":       # la festa è finita senza di noi (non dovrebbe succedere): si lascia stare
			stato = "spento"
			return false
		if m.goalT <= dt:
			stato = "fermo"
			_festa_finita = true
			return true
	return false


## true una volta sola, quando il motore si è fermato alla fine della festa del gol
func festa_finita() -> bool:
	if _festa_finita:
		_festa_finita = false
		return true
	return false


## ogni fotogramma dopo i passi del motore (non durante il replay)
func registra(m: Object) -> void:
	if stato != "in_onda":
		buffer.registra(m)


## parte il replay; false se non c'è abbastanza da rigiocare (allora il motore riparte subito)
func avvia(vista: Node, hud: Node) -> bool:
	_vista = vista
	_hud = hud
	if buffer.quanti() < MIN_CAMPIONI or vista == null or not ("replay" in vista):
		_chiudi()
		return false
	var iv := buffer.intervallo()
	_t0 = maxf(iv.x, _t_gol - PRIMA)
	_t1 = minf(iv.y, _t_gol + DOPO)
	if _t1 - _t0 < 0.5:
		_chiudi()
		return false
	_t_tiro = buffer.tiro_prima(_t_gol)
	_scala = maxf(1.0, durata_vera(_t0, _t1, _t_tiro) / DURATA_MAX)
	_t = _t0
	visuale = "porta" if _rng.randf() < 0.55 else "lato"
	if _visuale_forzata != "":
		visuale = _visuale_forzata
	var px := buffer.pallone_a(_t0).x
	_lato_cam = (-1.0 if px > 0.0 else 1.0) if visuale == "porta" else (1.0 if px >= 0.0 else -1.0)
	_disponi_scritta()
	_cam_pronta = false
	stato = "in_onda"
	vista.replay = true
	if vista.has_method("clear_path"):
		vista.clear_path()
	if hud != null and hud.has_method("fade"):
		hud.fade()
	_scritta.visible = true
	return true


## velocità del replay al tempo di gioco t (rallentatore pieno attorno al tiro)
static func velocita(t: float, t_tiro: float) -> float:
	if is_nan(t_tiro):
		return VELOCE
	if t >= t_tiro - LENTO_PRIMA and t <= t_tiro + LENTO_DOPO:
		return LENTO
	return VELOCE


## quanti secondi veri dura il replay da t0 a t1 (senza l'accelerazione di DURATA_MAX)
static func durata_vera(t0: float, t1: float, t_tiro: float) -> float:
	var s := 0.0
	var t := t0
	var d := 1.0 / 120.0
	while t < t1:
		s += d / velocita(t, t_tiro)
		t += d
	return s


## un fotogramma del replay: stato registrato sulla partita → vista → stato vero rimesso subito
func fotogramma(m: Object, vista: Node, dt: float) -> void:
	if stato != "in_onda":
		return
	var dt_gioco := dt * velocita(_t, _t_tiro) * _scala
	_t = minf(_t1, _t + dt_gioco)
	buffer.applica(m, _t)
	_muovi_telecamera(m, vista, dt)
	_linea_tiro(vista)
	vista.update_view(dt_gioco, dt) # col replay acceso la vista non muove la telecamera
	buffer.ripristina(m)
	if _t >= _t1:
		_chiudi()


## un tocco: salta il replay
func salta() -> void:
	if stato == "in_onda":
		_chiudi()


func _chiudi() -> void:
	var era := stato
	stato = "spento"
	_festa_finita = false
	if _scritta != null:
		_scritta.visible = false
	if _vista != null and is_instance_valid(_vista):
		if "replay" in _vista:
			_vista.replay = false
		if _vista.has_method("clear_path"):
			_vista.clear_path()
	if era == "in_onda" and _hud != null and is_instance_valid(_hud) and _hud.has_method("fade"):
		_hud.fade()
	finito.emit()


# telecamera del replay: bassa dietro la porta del gol, o bassa dalla linea laterale; guarda il pallone
func _muovi_telecamera(m: Object, vista: Node, dt: float) -> void:
	var cam: Camera3D = vista.get("cam")
	if cam == null:
		return
	var flip: float = vista.get("flip") if vista.get("flip") != null else 1.0
	var b: Object = m.ball
	var bx: float = b.x
	var by: float = b.y
	var bh: float = b.h
	var gy := _lato_porta * Coord.HL
	var pos: Vector3
	var look: Vector3
	if visuale == "porta":
		# dietro la linea di fondo, di fianco al palo (la rete non copre), bassa: si vede arrivare l'azione e il
		# pallone entrare. Il lato è quello opposto al pallone, così il tiro viene verso la telecamera di sbieco
		pos = Vector3(_lato_cam * (Coord.GW / 2.0 + PORTA_FIANCO), PORTA_H, gy + _lato_porta * PORTA_DIETRO)
		look = Vector3(bx * 0.7, 0.6 + bh * 0.5, lerpf(by, gy, 0.2))
	else:
		# dalla linea laterale più vicina al pallone, bassa, un po' dietro l'azione
		pos = Vector3(_lato_cam * (Coord.HW + LATO_FUORI), LATO_H, by - _lato_porta * LATO_DIETRO)
		look = Vector3(bx * 0.6, 0.6 + bh * 0.5, lerpf(by, gy, 0.25))
	if not _cam_pronta:
		_cam_pos = pos
		_cam_look = look
		_cam_pronta = true
	else:
		var k := minf(1.0, dt * CAM_K)
		_cam_pos = _cam_pos.lerp(pos, k)
		_cam_look = _cam_look.lerp(look, minf(1.0, k * 1.6))
	cam.look_at_from_position(_mondo(_cam_pos, flip), _mondo(_cam_look, flip), Vector3.UP)
	cam.fov = FOV


# (x, altezza, y) del gioco → posizione nel mondo di Godot (con la vista girata se si gioca con la squadra 1)
static func _mondo(v: Vector3, flip: float) -> Vector3:
	return Vector3(flip * v.x, v.y, -flip * v.z)


# linea del tiro: dal punto del calcio fino a dove è arrivato il pallone adesso (cresce con lui)
func _linea_tiro(vista: Node) -> void:
	if is_nan(_t_tiro) or _t < _t_tiro:
		return
	var punti := buffer.traiettoria(_t_tiro, minf(_t, _t_gol))
	punti.append(buffer.pallone_a(minf(_t, _t_gol)))
	if punti.size() < 2:
		return
	var terra := PackedVector2Array()
	for p: Vector3 in punti:
		terra.append(Vector2(p.x, p.y))
	var ultimo: Vector3 = punti[punti.size() - 1]
	if vista.has_method("show_path"):
		vista.show_path(terra, "shot", ultimo.z)
	if vista.has_method("show_preview"):
		vista.show_preview(punti, NAN)


# scritta "REPLAY" in alto e "Tocca per saltare" in basso (sopra la vista, sotto i menu dell'HUD)
func _crea_scritta() -> void:
	_scritta = CanvasLayer.new()
	_scritta.layer = 4
	_scritta.visible = false
	add_child(_scritta)
	_scritta.add_child(_etichetta("● REPLAY", 22, Color("#ffe14a")))
	_scritta.add_child(_etichetta("Tocca per saltare", 15, Color(1, 1, 1, 0.85)))


# "REPLAY" sotto il punteggio (dove sta la scritta della visuale, spenta nel replay), sopra la cronaca;
# "Tocca per saltare" in fondo all'area sicura
func _disponi_scritta() -> void:
	var s := CronacaVista.area_sicura(get_viewport())
	var su: Label = _scritta.get_child(0)
	var giu: Label = _scritta.get_child(1)
	for l: Label in [su, giu]:
		l.size = Vector2(s.size.x, l.get_minimum_size().y)
	su.position = Vector2(s.position.x, s.position.y + 52.0)
	giu.position = Vector2(s.position.x, s.end.y - 16.0 - giu.size.y)


static func _etichetta(testo: String, dim: int, colore: Color) -> Label:
	var l := Label.new()
	l.text = testo
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 8)
	return l
