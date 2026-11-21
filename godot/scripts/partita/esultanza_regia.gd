# Regia dell'esultanza del campione in partita (fase C, punto 12). Dopo un gol del giocatore principale (quello con
# champ: true nella carriera, src del giocatore del motore) la sua figura fa l'esultanza scelta nell'editor
# (mosse/esultanza.gd) e la telecamera va davanti a lui per circa 3 s; un tocco la salta. Gli altri segnano come prima.
# Solo grafica: il motore non cambia, l'esultanza dura dentro la pausa dopo il gol che c'è già (fase "goal", 3,2 s).
#
# Come la usa gioco.gd (pochi agganci):
#   avvia(e, m, me, vista)  all'evento "goal": true se parte (gol del campione con una vista vera)
#   aggiorna(dt, m)         a ogni fotogramma PRIMA di vista.update_view: mette la posa sulla figura
#   camera(vista)           DOPO vista.update_view: sposta la telecamera (sopra quella calcolata, sfumando)
#   salta()                 tocco sullo schermo mentre è in corso
#   segnale finita          alla fine dell'esultanza (o al tocco), una volta per gol: lì si aggancia il replay
# Finita, la posa finale resta finché dura la pausa del gol (poi il calcio d'inizio rimette tutti a posto); al tocco
# invece la figura e la telecamera tornano normali sfumando. Si ferma da sola se la fase "goal" finisce prima.
extends Node

signal finita

const E := preload("mosse/esultanza.gd")
const Esultanze := preload("esultanze.gd")

const ENTRA := 0.3             # s: la posa e la telecamera arrivano a peso pieno
const ESCE := 0.35             # s: uscita dopo il tocco
const GIRO_T := 0.45           # s: il campione si gira verso il centro del campo (dove c'è la telecamera)
const CAM_DIST := 6.6          # m: telecamera davanti al campione (alto 2,3 m con la scala del gioco)...
const CAM_LATO := 0.4          # rad: ... un po' di lato (tre quarti)
const CAM_ALTA := 2.4          # m
const CAM_GUARDA := 1.25       # m: altezza del punto guardato
const CAM_FOV := 48.0
const CAM_SEGUE := 6.0         # 1/s: quanto in fretta segue il campione che si sposta
const SCRITTA_ALTA := 0.86     # frazione dell'altezza dello schermo

var attiva := false            # true dall'avvio fino alla fine dell'uscita (o della pausa del gol)
var id := ""
var t := 0.0
var _p: Object = null          # giocatore del motore (R.Player)
var _fig: Node3D = null
var _flip := 1.0
var _verso := 0.0              # giro voluto della figura (rad, come Figura.rotation.y)
var _w := 0.0
var _uscita := false
var _finita_emessa := false
var _centro := Vector3.ZERO
var _centro_ok := false
var _strato: CanvasLayer
var _scritta: Label


func _ready() -> void:
	_strato = CanvasLayer.new()
	_strato.layer = 40
	add_child(_strato)
	_scritta = Label.new()
	_scritta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scritta.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_scritta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_scritta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scritta.visible = false
	_strato.add_child(_scritta)


## il gol `e` (evento "goal" del motore) è del campione della mia squadra? Ritorna l'id dell'esultanza o ""
static func esultanza_del_gol(e: Dictionary, me: int) -> String:
	if int(e.get("team", -1)) != me or e.get("og", false):
		return ""
	var p: Object = e.get("scorer")
	if p == null or not "src" in p or not p.src is Dictionary or not p.src.get("champ", false):
		return ""
	return Esultanze.valida(p.src.get("esultanza"))


## all'evento "goal": se è del campione e la vista sa dare la sua figura, parte. Ritorna true se è partita
func avvia(e: Dictionary, _m: Object, me: int, vista: Object) -> bool:
	var scelta := esultanza_del_gol(e, me)
	if scelta == "" or vista == null or not vista.has_method("figura_di"):
		return false
	var fig: Node3D = vista.figura_di(e.scorer)
	if fig == null or not "esultanza" in fig:
		return false
	_rilascia()
	id = scelta
	t = 0.0
	_p = e.scorer
	_fig = fig
	_flip = float(vista.get("flip")) if "flip" in vista else 1.0
	_w = 0.0
	_uscita = false
	_finita_emessa = false
	_centro_ok = false
	attiva = true
	# verso il centro del campo: lì dietro c'è la telecamera e il pubblico lo vede in faccia
	var pos := Vector3(_flip * _p.x, 0.0, -_flip * _p.y)
	_verso = atan2(-pos.x, -pos.z) if pos.length() > 1.0 else fig.rotation.y
	_scritta.text = "%s  ·  tocca per saltare" % Esultanze.nome(id)
	_scritta.visible = true
	return true


## a ogni fotogramma, prima di vista.update_view (dt = tempo vero, 0 in pausa)
func aggiorna(dt: float, m: Object) -> void:
	if not attiva:
		return
	if m == null or m.phase != "goal" or _p == null or _p.off or not is_instance_valid(_fig):
		_chiudi()
		return
	var tt := E.durata(id)
	if _uscita:
		_w = move_toward(_w, 0.0, dt / ESCE)
		if _w <= 0.0:
			_chiudi()
			return
	else:
		t = minf(tt, t + dt)
		_w = move_toward(_w, 1.0, dt / ENTRA)
		if t >= tt and not _finita_emessa:
			_emetti_finita()
	var po := E.posa(id, t)
	var yaw_fig := atan2(_flip * _p.fx, -_flip * _p.fy)
	var giro := wrapf(_verso - yaw_fig, -PI, PI) * smoothstep(0.0, GIRO_T, t)
	po["corpo"] = Transform3D(Basis(Vector3.UP, giro), Vector3.ZERO) * (po.corpo as Transform3D)
	po["w"] = smoothstep(0.0, 1.0, _w)
	_fig.esultanza = po
	_misura_scritta()


## dopo vista.update_view: telecamera davanti al campione, sfumata sopra quella calcolata dalla vista
func camera(vista: Object) -> void:
	if not attiva or vista == null or not is_instance_valid(_fig):
		return
	var cam: Camera3D = vista.get("cam")
	if cam == null:
		return
	var k := smoothstep(0.0, 1.0, _w)
	var c: Vector3 = _fig.corpo.to_global(Vector3(0, 0.9, 0))   # bacino (anche capovolto nella capriola)
	c.y = 0.0
	var dt := get_process_delta_time()
	_centro = c if not _centro_ok else _centro.lerp(c, minf(1.0, dt * CAM_SEGUE))
	_centro_ok = true
	var a := _verso + CAM_LATO
	var dir := Vector3(sin(a), 0.0, cos(a))
	var guarda := _centro + Vector3(0, CAM_GUARDA, 0)
	var dove := _centro + dir * CAM_DIST + Vector3(0, CAM_ALTA, 0)
	var voluta := Transform3D(Basis.looking_at(guarda - dove, Vector3.UP), dove)
	cam.global_transform = cam.global_transform.interpolate_with(voluta, k)
	cam.fov = lerpf(cam.fov, CAM_FOV, k)


## tocco: l'esultanza finisce subito (figura e telecamera tornano normali sfumando)
func salta() -> void:
	if not attiva or _uscita:
		return
	_uscita = true
	_scritta.visible = false
	if not _finita_emessa:
		_emetti_finita()


## per chi viene dopo (replay): ferma tutto subito, senza sfumare
func ferma() -> void:
	_chiudi()


func _emetti_finita() -> void:
	_finita_emessa = true
	finita.emit()


func _chiudi() -> void:
	var da_emettere := attiva and not _finita_emessa
	_rilascia()
	attiva = false
	_uscita = false
	if da_emettere:
		_emetti_finita()


func _rilascia() -> void:
	if is_instance_valid(_fig):
		_fig.esultanza = null
	_fig = null
	_p = null
	_scritta.visible = false


func _misura_scritta() -> void:
	var vis := get_viewport().get_visible_rect().size
	_scritta.add_theme_font_size_override("font_size", int(maxf(14.0, vis.y * 0.021)))
	_scritta.add_theme_constant_override("outline_size", int(maxf(3.0, vis.y * 0.004)))
	_scritta.position = Vector2(0, vis.y * SCRITTA_ALTA)
	_scritta.size = Vector2(vis.x, vis.y * 0.05)
