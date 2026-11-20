# Vista della partita (porting di View in src/render.js, con i pezzi di src/props.js e src/players3d.js):
# tutto quello che si vede durante una partita. Legge lo stato del motore (SimMatch), non lo cambia mai.
#
# Contratto con chi la usa (il ciclo di gioco e i gesti stanno altrove):
#   setup(m, me)                       22 giocatori con le divise, pallone, telecamera sul pallone
#   update_view(dt_game, dt_real)      dopo il passo del motore: animazioni col tempo di gioco, telecamera col tempo vero
#   world_to_screen(x, y, h)           → Vector3(x_px, y_px, 1 se davanti alla telecamera / 0 se dietro)
#   screen_to_field(p)                 → punto del campo (x, y) sotto il dito; Vector2(INF, INF) se punta il cielo
#   screen_to_goal(p, gy)              → Vector3(x, h, 1 se valido / 0 se no) sul piano della porta a y = gy
#   set_zoom(z)                        zoom voluto dal gioco (come setZoom di render.js; senza, lo calcola la vista)
#   show_path(points, kind[, end_h, recv]) / clear_path()   linea disegnata ("run", "pass", "shot", "def")
#   show_preview(points, offside_y)    puntini del volo vero (m.predictKick) e linea del fuorigioco (facoltativa:
#                                      nel gioco l'anteprima la disegna l'interfaccia in 2D)
#   trick(p[, r])                      parte un giochetto del dribbling per p (solo grafica); ritorna {id, name, dur}
#   dispose()                          via tutto (la partita la chiude chi l'ha creata); va bene anche da _exit_tree
#   tifo(tipo, squadra)                reazione del pubblico: "gol", "occasione", "parata", "palo", "fischio"
#   set_rallenty(k)                    quanto è forte il rallenty (0..1) per la profondità di campo; −1 = la vista lo
#                                      ricava da sola da dt_game / dt_real (predefinito)
#   set_qualita(l) / qualita_auto      livello grafico 0..3 (qualita.gd); con qualita_auto scende da solo sotto 58 fps
#   user_yaw, cam_drag, drawing        scritti da chi gestisce il dito (src/input.js), letti qui; il ritorno dolce
#                                      di user_yaw a 0 (relaxYaw) lo fa la vista in update_view
#
# Coordinate: il gioco ha x larghezza, y lunghezza, h altezza. In Godot X = s·x, Y = h, Z = −s·y con s = −1 se la
# squadra umana è la 1: così chi gioca attacca sempre "in su" sullo schermo, come nel web (View.flip).
class_name PartitaVista
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const Figura := preload("figura.gd")
const PALLA_HD := "res://assets/textures/pallone.png"
const PALLA_N := "res://assets/textures/pallone_n.png"
const AspettoVista := preload("aspetto.gd") # stesso porting di looks.js di scripts/carriera/aspetto.gd (Aspetto)
const Schiene := preload("schiene.gd")
const Giocatore := preload("res://scripts/giocatore.gd")
const TV := preload("texture_vista.gd")
const CU := preload("camuser.gd")
const Giochetti := preload("mosse/giochetti.gd")
const Effetti := preload("effetti.gd")
const Qualita := preload("qualita.gd")

const BALL_R := 0.21           # raggio del pallone a schermo (più grande del vero, per leggerlo da lontano)
const PASS_RECV := 5.0         # linea "pass": compagno entro questa distanza dalla fine = riceve (anello verde)
const RING_K := 1.9            # anello del controllato: scala, pulsa di ±0,12 a 6 rad/s
const MARKER_H := 2.75         # segnalino sopra il controllato (m)
const SHADOW_SIZE := 1.15      # ombra morbida sotto i giocatori (m)
const NET_FAR := 0.78          # trasparenza della rete: porta avversaria / propria porta (guardata attraverso)
const NET_NEAR := 0.22
const RETE_FONDO := 2.0        # profondità della rete a terra e alla traversa (come scripts/campo.gd)
const RETE_ALTO := 1.0
const NET_MAX := 0.45          # il telo si gonfia al massimo così (m); il pallone a schermo non va oltre
const RISOLUZIONE_3D_LARGO := 780.0   # sul telefono il 3D si disegna largo al massimo così (px), poi FSR
const GOL_SCHERMO := 5.0       # s di "GOOOL!" sul maxischermo
const GOL_DOPPIO := 4.0        # due avvisi di gol entro questo tempo sono lo stesso gol
const SCIA_V := 17.0           # m/s: oltre questa velocità (o su un tiro) il pallone lascia la scia
const DOF_VICINO := 16.0       # telecamera più vicina di così al pallone (m): primo piano, sfocatura in crescita...
const DOF_PRIMO := 9.0         # ... piena da qui
const DOF_OLTRE := 16.0        # nel rallenty è a fuoco fino a questa distanza oltre il pallone (m); nel primo piano 5
const DOF_FORZA := 0.07        # sfocatura massima (dof_blur_amount)

# divise come nel gioco web (src/career.js kitOf: Rosso e Blu; portieri arancio e verde)
const KIT_CASA := {"shirt": 0xc8102e, "shorts": 0xffffff, "socks": 0xc8102e, "gk": {"shirt": 0xffa41c, "shorts": 0x222222, "socks": 0xffa41c}}
const KIT_OSPITI := {"shirt": 0x1746a2, "shorts": 0xffffff, "socks": 0x1746a2, "gk": {"shirt": 0x2ad17a, "shorts": 0x15803d, "socks": 0x15803d}}

## angolo (rad) della visuale girata col dito: lo scrive chi gestisce il dito, qui torna dolcemente a 0 (relaxYaw)
var user_yaw := 0.0
## il dito sta girando la visuale adesso
var cam_drag := false
## il dito sta disegnando una linea (col pallone: visuale larga del rallenty)
var drawing := false

var m: Object = null           # SimMatch
var me := 0
var flip := 1.0
var t := 0.0

var _figs: Array = []          # Figura per ogni m.players[i]
var _srcs: Array = []          # src del giocatore che la figura rappresenta (cambio = figura nuova)
var _tricks := {}              # indice in m.players → {id, name, dur, t, side}
var _rng := RandomNumberGenerator.new()
var _yaw_owner: Object = null
var _ball: MeshInstance3D
var _ball_sh: MeshInstance3D
var _ball_sh_mat: StandardMaterial3D
var _shadows: MultiMeshInstance3D
var _ring: MeshInstance3D
var _marker: Sprite3D
var _tex_warn: Texture2D
var _ctx := {"t": 0.0, "phase": "", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}   # riusato per tutti
var _zoom_t := -1.0            # zoom voluto dal gioco (set_zoom); < 0 = lo calcola la telecamera
## il livello grafico scende da solo se gli FPS restano sotto 58 (qualita.gd)
var qualita_auto := true
## livello grafico in uso: 3 alto, 2 medio, 1 basso, 0 minimo
var livello_qualita := Qualita.ALTO
var t_vero := 0.0              # tempo vero dall'inizio (s)
var _qualita := Qualita.new()
var _schiene: Node
var _effetti: Node3D
var _attr: CameraAttributesPractical
var _env: Environment
var _dof_on := true
var _dof_k := 0.0
var _rk_auto := 0.0            # rallenty ricavato dai tempi (0..1)
var _rk_forzato := -1.0        # set_rallenty
var _ultimo_calcio: Object = null
var _punti := [0, 0]
var _gol_t := -INF
var _schermo_gol := false

@onready var cam: Camera3D = $Telecamera
@onready var _campo: Node3D = $Campo
@onready var _giocatori: Node3D = $Giocatori
@onready var _nastri: Node3D = $Nastri
@onready var _sole: DirectionalLight3D = $Sole
@onready var _stadio: Node3D = $Stadio
@onready var _ambiente: WorldEnvironment = $Ambiente


func _ready() -> void:
	_rng.randomize()
	_sole.look_at_from_position(Vector3(-0.42, 0.78, -0.46) * 60.0, Vector3.ZERO, Vector3.UP)
	_imposta_risoluzione_3d()
	_tex_warn = TV.avviso()
	_crea_pallone()
	_crea_segni()
	_schiene = Schiene.new()
	_schiene.name = "Schiene"
	add_child(_schiene)
	_effetti = Effetti.new()
	add_child(_effetti)
	_attr = CameraAttributesPractical.new()
	cam.attributes = _attr
	_env = _ambiente.environment
	_imposta_bagliore()
	if DisplayServer.get_name() == "headless":
		qualita_auto = false
	_applica_qualita(livello_qualita)


## nuova partita: 22 giocatori con le divise della loro squadra (team.kit se c'è: shirt, shorts, socks e gk,
## colori 0xRRGGBB, "#rrggbb" o Color), telecamera subito sul pallone
func setup(match_: SimMatch, me_: int) -> void:
	_libera_figure()
	m = match_
	me = me_
	flip = -1.0 if me == 1 else 1.0
	_nastri.flip = flip
	_tricks.clear()
	_yaw_owner = null
	user_yaw = 0.0
	_zoom_t = -1.0
	t = 0.0
	for i in m.players.size():
		_figs.append(_figura(m.players[i]))
		_srcs.append(m.players[i].src)
	_prepara_schiene()
	var mm := _shadows.multimesh
	mm.instance_count = m.players.size()
	cam.reset(m.ball.x, m.ball.y)
	_ultimo_calcio = m.ball.kick
	_prepara_stadio()
	clear_path()


## dopo il passo del motore. dt_game = tempo di gioco (rallenty compreso), dt_real = tempo vero (0 in pausa)
func update_view(dt_game: float, dt_real: float) -> void:
	if m == null:
		return
	t += dt_game
	t_vero += dt_real
	var s := flip
	var b: Object = m.ball
	# giochetti in corso
	for k: int in _tricks.keys():
		var tk: Dictionary = _tricks[k]
		tk.t += dt_game
		if tk.t >= tk.dur:
			_tricks.erase(k)
	var mm := _shadows.multimesh
	for i in m.players.size():
		var p: Object = m.players[i]
		if p.src != _srcs[i]:   # cambio: entra un altro giocatore
			_figs[i].queue_free()
			_figs[i] = _figura(p)
			_srcs[i] = p.src
			_prepara_schiene()
			_srcs[i] = p.src
		_posa(i, p, dt_game)
		var on: bool = not p.off
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE if on else Vector3.ZERO), Vector3(s * p.x, 0.025, -s * p.y)))
	# pallone (durante un giochetto di chi lo porta, spostato per farlo vedere)
	var bx: float = b.x
	var by: float = b.y
	var bh: float = b.h
	var tk := _trick_of(b.owner)
	if not tk.is_empty():
		var o := Giochetti.ball_offset(tk.id, tk.q)
		var c: Object = b.owner
		bx += c.fx * o.x - c.fy * o.y * tk.side
		by += c.fy * o.x + c.fx * o.y * tk.side
		bh += o.z
	var rete := _dentro_la_rete(bx, by, bh)
	by = rete.x
	bh = rete.y
	_aggiorna_pallone(b, bx, by, bh, dt_game)
	_aggiorna_segni()
	# visuale girata dalla persona: resta finché dura il rallenty in attacco con lo stesso portatore e mentre si
	# disegna; poi torna dolcemente dritta (src/camuser.js). Con un portatore nuovo si riparte dritti.
	if cam_drag:
		_yaw_owner = b.owner
	var hold: bool = (CU.user_cam_on(m, me) and b.owner == _yaw_owner) or drawing
	user_yaw = CU.relax_yaw(user_yaw, hold, dt_real)
	cam.aggiorna(m, me, dt_game, dt_real, drawing, cam_drag, user_yaw, _zoom_t)
	_nastri.mostra_corse(m.runs[me] if m.runs != null else [])
	if dt_game > 0.0:
		_aggiorna_reti(b, dt_game)
	_aggiorna_stadio(dt_real)
	_aggiorna_effetti(b, dt_game, dt_real)


## punto del gioco (x, y, altezza h) → Vector3(x_px, y_px, 1 se davanti alla telecamera / 0 se dietro).
## Il terzo valore NON dice se il punto sta dentro lo schermo (come vis di worldToScreen nel web)
func world_to_screen(x: float, y: float, h: float) -> Vector3:
	var w := Vector3(flip * x, h, -flip * y)
	var p := cam.unproject_position(w)
	return Vector3(p.x, p.y, 0.0 if cam.is_position_behind(w) else 1.0)


## zoom voluto dal gioco (setZoom di render.js): 1 = largo (senza palla, disegnando, ripartenza nostra),
## 0,5 ripartenza, 0,4 col pallone. La telecamera lo insegue col tempo vero
func set_zoom(z: float) -> void:
	_zoom_t = z


## punto dello schermo → punto del campo (x, y) del gioco, con la telecamera vera (anche girata);
## Vector2(INF, INF) se il dito punta sopra l'orizzonte (cielo)
func screen_to_field(p: Vector2) -> Vector2:
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	if d.y > -1e-4:
		return Vector2.INF
	var k := -o.y / d.y
	var g := o + d * k
	return Vector2(flip * g.x, -flip * g.z)


## punto dello schermo → punto sul piano della porta a y = gy (coordinate del motore), per tiro e tuffo:
## Vector3(x, altezza, 1 se valido / 0 se il piano è dietro la telecamera o parallelo al raggio)
func screen_to_goal(p: Vector2, gy: float) -> Vector3:
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	var zp := -flip * gy
	if absf(d.z) < 1e-6:
		return Vector3.ZERO
	var k := (zp - o.z) / d.z
	if k <= 0.0:
		return Vector3.ZERO
	return Vector3(flip * (o.x + d.x * k), o.y + d.y * k, 1.0)


## linea disegnata dal dito (punti del gioco). kind: "run" strada da correre, "pass" passaggio (anello verde sul
## compagno che riceve: recv, o il compagno entro 5 m dalla fine), "shot" tiro (gialla col mirino all'altezza end_h),
## "def" linea di difesa
func show_path(points: PackedVector2Array, kind: String, end_h: float = 0.0, recv: Variant = null) -> void:
	if kind == "pass" and recv == null and m != null and points.size() >= 2:
		recv = _compagno_vicino(points[points.size() - 1])
	_nastri.mostra_linea(points, kind, end_h, recv if kind == "pass" else null)


func clear_path() -> void:
	_nastri.nascondi_linea()


## puntini del volo vero: points = Array di {x, y, h} (m.predictKick) o di Vector3(x, y, h);
## offside_y = y della linea del fuorigioco, NAN = niente linea
func show_preview(points: Array, offside_y: float = NAN) -> void:
	var pts: Array = []
	for q: Variant in points:
		pts.append(q if q is Vector3 else Vector3(q.x, q.y, q.h))
	_nastri.mostra_anteprima(pts, offside_y)


## dribbling tentato da p: parte un giochetto, più bello se il dribbling di p è alto (solo grafica).
## r = numero casuale 0..1 (−1 = lo sceglie la vista). Ritorna {id, name, dur} del giochetto.
func trick(p: Object, r: float = -1.0) -> Dictionary:
	if m == null:
		return {}
	if r < 0.0:
		r = _rng.randf()
	var dri: float = p.st.dri if p.st != null else 50.0
	var tk := Giochetti.choose_trick(dri, r)
	var dur := Giochetti.duration(tk.id)
	_tricks[m.players.find(p)] = {"id": tk.id, "name": tk.name, "dur": dur, "t": 0.0, "side": 1.0 if fmod(r * 1000.0, 2.0) < 1.0 else -1.0}
	return {"id": tk.id, "name": tk.name, "dur": dur}


## via figure e riferimenti alla partita (la partita la chiude chi l'ha creata, con m.dispose()).
## Funziona anche chiamata da _exit_tree del padre, coi nodi già fuori dall'albero (niente viewport né telecamera)
func dispose() -> void:
	_libera_figure()
	m = null
	_yaw_owner = null
	_tricks.clear()
	_zoom_t = -1.0
	if is_instance_valid(_nastri) and _nastri.is_node_ready():
		_nastri.nascondi_linea()
		_nastri.mostra_corse([])


## reazione del pubblico a un fatto della partita (solo grafica). tipo: "gol", "occasione" (tiro pericoloso),
## "parata", "palo", "fischio" (fallo o fuorigioco); squadra = indice nel motore (0 / 1) di chi segna, ha l'occasione,
## para, prende il palo o subisce il fischio. Il gol la vista lo vede anche da sola (cambio del punteggio): chiamare
## tifo("gol", ...) in più non raddoppia la festa (folla, maxischermo e coriandoli partono una volta per gol).
func tifo(tipo: String, squadra: int) -> void:
	if m == null:
		return
	if tipo == "gol":
		_festa_gol(squadra)
		return
	_stadio.tifo(tipo, squadra)


# ---------------------------------------------------------------- stadio, pubblico, maxischermo
func _prepara_stadio() -> void:
	var nomi := []
	var colori := []
	for k in 2:
		var team: Dictionary = m.teams[k]
		nomi.append(str(team.get("short", team.get("name", "CASA" if k == 0 else "OSPITI"))))
		colori.append(_colori_tifo(k))
	_stadio.squadre(nomi, colori)
	_punti = [m.score[0], m.score[1]]
	_gol_t = -INF
	_schermo_gol = false
	_stadio.punteggio(_punti[0], _punti[1], false)


# maglia e secondo colore dei tifosi di una squadra (fanColors del web: i calzoncini se si distinguono dalla maglia,
# sennò bianco o nero)
func _colori_tifo(k: int) -> Array:
	var team: Dictionary = m.teams[k]
	var def: Dictionary = KIT_CASA if k == 0 else KIT_OSPITI
	var kit: Dictionary = team.get("kit", def)
	var a := _colore(kit.get("shirt", def.shirt))
	var b := _colore(kit.get("shorts", 0xffffff))
	if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) <= 0.45:
		b = Color("#15171c") if a.get_luminance() > 0.55 else Color("#f4f4f4")
	return [a, b]


func _aggiorna_stadio(dt_real: float) -> void:
	if m.score[0] != _punti[0] or m.score[1] != _punti[1]:
		var chi := 0 if m.score[0] > _punti[0] else 1
		_punti = [m.score[0], m.score[1]]
		_festa_gol(chi)
	if _schermo_gol and t_vero - _gol_t > GOL_SCHERMO:
		_schermo_gol = false
		_stadio.punteggio(_punti[0], _punti[1], false)
	_stadio.aggiorna(dt_real)


# folla, maxischermo e coriandoli per il gol di `squadra`, una volta sola per gol
func _festa_gol(squadra: int) -> void:
	if t_vero - _gol_t < GOL_DOPPIO:
		return
	_gol_t = t_vero
	_stadio.tifo("gol", squadra)
	_schermo_gol = true
	_stadio.punteggio(m.score[0], m.score[1], true)
	_effetti.coriandoli(squadra, _colori_tifo(squadra), flip)


# ---------------------------------------------------------------- giocatori
func _figura(p: Object) -> Node3D:
	var f := Figura.new()
	f.name = "G%d_%d" % [p.team, p.i]
	f.scale = Vector3.ONE * Coord.SCALE
	_giocatori.add_child(f)
	f.prepara(_kit_di(p), _aspetto_di(p), _rng.randf() * 2.0, _tex_warn)
	return f


func _libera_figure() -> void:
	for f: Node3D in _figs:
		if is_instance_valid(f):
			f.queue_free()
	_figs.clear()
	_srcs.clear()


func _posa(i: int, p: Object, dt: float) -> void:
	var f: Node3D = _figs[i]
	if p.off:
		f.visible = false
		return
	f.visible = true
	var s := flip
	var yaw := atan2(s * p.fx, -s * p.fy)
	f.position = Vector3(s * p.x, 0.0, -s * p.y)
	f.rotation = Vector3(0.0, yaw, 0.0)
	var tk := _trick_of(p)
	_ctx.t = t
	_ctx.phase = m.phase
	_ctx.flip = s
	_ctx.yaw = yaw
	_ctx.ball = m.ball
	_ctx.trick = null if tk.is_empty() else tk
	f.posa(p, dt, _ctx)


func _trick_of(p: Object) -> Dictionary:
	if p == null or _tricks.is_empty():
		return {}
	var k: Variant = _tricks.get(m.players.find(p))
	if k == null:
		return {}
	return {"id": k.id, "q": minf(1.0, k.t / k.dur), "side": k.side}


# divisa del giocatore (figFor di src/render.js): kit della squadra o del portiere, stile (team.kit.style, sennò dal
# nome della squadra come kitStyleFromSeed; il portiere ha maniche lunghe, tinta unita e girocollo), numero e cognome
func _kit_di(p: Object) -> Dictionary:
	var team: Dictionary = m.teams[p.team]
	var def: Dictionary = KIT_CASA if p.team == 0 else KIT_OSPITI
	var squadra: Dictionary = team.get("kit", def)
	var k: Dictionary = squadra
	var st := _stile_squadra(p.team)
	if p.pos == "P":
		k = squadra.get("gk", def.gk)
		st = st.duplicate()
		st.sleeves = 1
		st.pattern = 0
		st.collar = 0
	var shirt := _colore(k.get("shirt", 0xffffff))
	var shorts := _colore(k.get("shorts", 0xffffff))
	var i: int = m.players.find(p)
	var cel := Schiene.cella(maxi(i, 0))
	return {"maglia": shirt, "calzoncini": shorts, "calzettoni": _colore(k.get("socks", k.get("shirt", 0xffffff))),
		"bordino": _secondo_colore(shirt, shorts),
		"stile": Vector4(st.sleeves, st.collar, st.pattern, st.socks),
		"numero": Vector4(cel.x, cel.y, 1.0 if i >= 0 else 0.0, st.fit)}


func _stile_squadra(k: int) -> Dictionary:
	var team: Dictionary = m.teams[k]
	var kit: Variant = team.get("kit")
	if kit is Dictionary and kit.has("style"):
		return AspettoVista.normalize_kit_style(kit["style"])
	return AspettoVista.kit_style_from_seed(AspettoVista.hash32([str(team.get("name", "squadra %d" % k))]))


# secondo colore della divisa (altH di src/athlete3d.js): i calzoncini, o bianco / quasi nero se sono come la maglia
static func _secondo_colore(maglia: Color, calzoncini: Color) -> Color:
	if maglia.is_equal_approx(calzoncini):
		return Color("#1b1b1b") if maglia.get_luminance() > 0.5 else Color.WHITE
	return calzoncini


# aspetto (src/looks.js): il `look` del giocatore se c'è (completato), sennò dal suo id e nome come lookOf del web
func _aspetto_di(p: Object) -> Dictionary:
	var src: Dictionary = p.src if p.src is Dictionary else {}
	var l := AspettoVista.look_of(src if not src.is_empty() else {"id": "%d_%d" % [p.team, p.i], "name": str(p.name)})
	return {"pelle": AspettoVista.colore(AspettoVista.SKINS, l.skin), "capelli": AspettoVista.colore(AspettoVista.HAIR_COLORS, l.hairColor),
		"iride": AspettoVista.colore(AspettoVista.EYE_COLORS, l.eyeColor), "scarpe": AspettoVista.colore(AspettoVista.BOOTS, l.boots),
		"stile2": Vector4(l.hair, l.beard, l.brows, _stile_squadra(p.team).shorts)}


# cognomi e numeri di chi è in campo (numero: src.num, sennò il posto in squadra + 1, come figFor del web)
func _prepara_schiene() -> void:
	var voci: Array = []
	for i in m.players.size():
		var p: Object = m.players[i]
		var k := _kit_di(p)
		var st: Vector4 = k.stile
		var ink := Schiene.inchiostro(k.maglia, k.bordino, int(st.z))
		var src: Dictionary = p.src if p.src is Dictionary else {}
		voci.append({"num": int(src.get("num", p.i + 1)), "nome": AspettoVista.back_name(str(src.get("name", p.name))),
			"fill": ink[0], "line": ink[1]})
	_schiene.prepara(voci, Giocatore._materiale)


static func _colore(v: Variant) -> Color:
	if v is Color:
		return v
	if v is String:
		return Color(v)
	return Color.hex((int(v) << 8) | 0xff)


func _compagno_vicino(e: Vector2) -> Variant:
	var best: Variant = null
	var dmin := PASS_RECV
	for p: Object in m.players:
		if p.team != me or p.off or p == m.ball.owner:
			continue
		var d := Vector2(p.x, p.y).distance_to(e)
		if d < dmin:
			dmin = d
			best = Vector2(p.x, p.y)
	return best


# ---------------------------------------------------------------- pallone, ombre, anello
func _crea_pallone() -> void:
	var sfera := SphereMesh.new()
	sfera.radius = BALL_R
	sfera.height = BALL_R * 2.0
	sfera.radial_segments = 32
	sfera.rings = 16
	var mat := StandardMaterial3D.new()
	# pallone HD (tools/genera_texture.gd: 32 spicchi con le cuciture in rilievo), sennò quello disegnato al volo
	if ResourceLoader.exists(PALLA_HD) and ResourceLoader.exists(PALLA_N):
		mat.albedo_texture = load(PALLA_HD)
		mat.normal_enabled = true
		mat.normal_texture = load(PALLA_N)
		mat.normal_scale = 0.8
	else:
		mat.albedo_texture = TV.palla()
	mat.roughness = 0.45
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_ball = MeshInstance3D.new()
	_ball.name = "Pallone"
	_ball.mesh = sfera
	_ball.material_override = mat
	add_child(_ball)
	var q := PlaneMesh.new()
	q.size = Vector2(0.6, 0.6)
	_ball_sh_mat = TV.materiale_segno(TV.ombra(64, 0.6), Color.WHITE, 1, false)
	_ball_sh_mat.no_depth_test = false
	_ball_sh = MeshInstance3D.new()
	_ball_sh.name = "OmbraPallone"
	_ball_sh.mesh = q
	_ball_sh.material_override = _ball_sh_mat
	_ball_sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball_sh)


func _aggiorna_pallone(b: Object, bx: float, by: float, bh: float, dt: float) -> void:
	var s := flip
	_ball.position = Vector3(s * bx, bh + BALL_R, -s * by)
	var sp := sqrt(b.vx * b.vx + b.vy * b.vy)
	if sp > 0.2 and dt > 0.0:   # rotola nel verso giusto (asse = su × velocità)
		_ball.rotate(Vector3(-s * b.vy, 0.0, -s * b.vx).normalized(), sp * dt / BALL_R)
		_ball.basis = _ball.basis.orthonormalized()
	# ombra: più larga e più chiara quando il pallone è alto
	var hk := minf(bh, 8.0)
	var hs := 0.8 + hk * 0.13
	_ball_sh.position = Vector3(s * bx, 0.03, -s * by)
	_ball_sh.scale = Vector3(hs, 1.0, hs)
	_ball_sh_mat.albedo_color.a = 1.0 / (1.0 + hk * 0.45)


func _crea_segni() -> void:
	# ombre morbide sotto i giocatori (oltre a quelle del sole): un solo disegno per tutti
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := PlaneMesh.new()
	q.size = Vector2(SHADOW_SIZE, SHADOW_SIZE)
	mm.mesh = q
	mm.instance_count = 0
	var sm := TV.materiale_segno(TV.ombra(64, 0.42), Color.WHITE, 0, false)
	sm.no_depth_test = false
	_shadows = MultiMeshInstance3D.new()
	_shadows.name = "OmbreGiocatori"
	_shadows.multimesh = mm
	_shadows.material_override = sm
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadows.extra_cull_margin = 16384.0
	add_child(_shadows)
	# anello giallo e segnalino sopra il giocatore controllato
	var r := PlaneMesh.new()
	r.size = Vector2(1.0, 1.0)
	_ring = MeshInstance3D.new()
	_ring.name = "Anello"
	_ring.mesh = r
	_ring.material_override = TV.materiale_segno(TV.anello(TV.GIALLO, 50.0, 9.0), Color.WHITE, 2, false)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_marker = Sprite3D.new()
	_marker.name = "Segnalino"
	_marker.texture = TV.segnalino()
	_marker.pixel_size = 0.55 / 64.0
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.render_priority = 20
	_marker.shaded = false
	_marker.visible = false
	add_child(_marker)


func _aggiorna_segni() -> void:
	var c: Object = m.ctrl[me]
	if c == null or c.off:
		_ring.visible = false
		_marker.visible = false
		return
	var s := flip
	_ring.visible = true
	_ring.position = Vector3(s * c.x, 0.04, -s * c.y)
	var k := RING_K + sin(t * 6.0) * 0.12
	_ring.scale = Vector3(k, 1.0, k)
	_marker.visible = true
	_marker.position = Vector3(s * c.x, MARKER_H + sin(t * 5.0) * 0.08, -s * c.y)


# ---------------------------------------------------------------- reti
# pallone in porta (il motore, dopo il gol, lo tiene fino a 1,9 m dietro la linea e lo lascia volare in alto, come il
# web): a schermo si ferma nel telo gonfio e sotto il tetto della rete, non lo buca. Ritorna (y, h) da disegnare
func _dentro_la_rete(bx: float, by: float, bh: float) -> Vector2:
	var depth := absf(by) - Coord.HL
	if depth <= 0.0 or absf(bx) > Coord.GW / 2.0 + 0.25 or bh > Coord.GH + 0.8:
		return Vector2(by, bh)
	var h := minf(bh, _tetto_rete(minf(depth, RETE_FONDO)))
	# fin dove il telo è gonfio davanti al pallone adesso (rete a molle), mai oltre NET_MAX
	var molle: RefCounted = _campo.rete_molle(signf(flip * by))
	var gonfio := NET_MAX
	if molle != null:
		gonfio = clampf(molle.gonfiore_in(Vector3(flip * bx, flip * by, h + BALL_R)) + 0.04, 0.0, NET_MAX)
	var d := minf(depth, _fondo_rete(h + BALL_R) + gonfio - BALL_R)
	h = minf(h, _tetto_rete(d))
	return Vector2(signf(by) * (Coord.HL + d), h)


# altezza massima del pallone (da terra al punto più basso) dentro la rete a d m dietro la linea: tetto piano fino a
# RETE_ALTO, poi il fondo inclinato fino a terra a RETE_FONDO (più il telo che si gonfia)
static func _tetto_rete(d: float) -> float:
	var alto := Coord.GH
	if d > RETE_ALTO:
		alto = Coord.GH * clampf((RETE_FONDO + NET_MAX - d) / (RETE_FONDO - RETE_ALTO), 0.0, 1.0)
	return maxf(0.0, alto - BALL_R * 2.0)


# profondità del fondo della rete dietro la linea di porta all'altezza h (m)
static func _fondo_rete(h: float) -> float:
	return RETE_FONDO + (RETE_ALTO - RETE_FONDO) * clampf(h / Coord.GH, 0.0, 1.0)

# Reti a molle (scripts/rete_molle.gd, una per porta): il pallone spinge i nodi che tocca, il telo si gonfia attorno
# a lui e poi ondeggia. Il pallone del motore (anche oltre il telo, dopo il gol) dà quanto spingere; quello a schermo
# resta dentro (_dentro_la_rete). La propria porta è più trasparente (la si guarda attraverso).
func _aggiorna_reti(b: Object, dt: float) -> void:
	var s := flip
	var palla := Vector3(s * b.x, s * b.y, b.h + BALL_R)    # gioco, campo non girato (come scripts/campo.gd)
	var vel := Vector3(b.vx, b.vy, b.vh).length()
	for lato: float in [1.0, -1.0]:
		var mat: ShaderMaterial = _campo.materiale_rete(lato)
		var molle: RefCounted = _campo.rete_molle(lato)
		if mat == null or molle == null:
			continue
		mat.set_shader_parameter("opacita", NET_NEAR if lato < 0.0 else NET_FAR)
		var depth := palla.y * lato - Coord.HL
		var dentro: bool = (m.phase == "goal" or m.phase == "play") and depth > -0.6 and absf(palla.x) < Coord.GW / 2.0 + 0.3 \
			and palla.z < Coord.GH + 0.6
		molle.passo(dt, palla, BALL_R, vel, dentro)


# ---------------------------------------------------------------- effetti, profondità di campo, qualità
## forza del rallenty per la profondità di campo: 0 = niente, 1 = pieno; −1 = la vista lo ricava da sola
## (dt_game / dt_real: sotto 0,6 inizia, a 0,2 è pieno)
func set_rallenty(k: float) -> void:
	_rk_forzato = clampf(k, 0.0, 1.0) if k >= 0.0 else -1.0


## livello grafico a mano (0 minimo .. 3 alto, vedi qualita.gd); la discesa automatica riparte da qui
func set_qualita(l: int) -> void:
	_qualita.imposta(l)
	_applica_qualita(_qualita.livello)


func _process(delta: float) -> void:
	if qualita_auto and m != null and _qualita.aggiorna(delta):
		_applica_qualita(_qualita.livello)
		print("qualità grafica: %s (FPS %.1f)" % [Qualita.NOMI[livello_qualita], _qualita.ultima_media])


func _applica_qualita(l: int) -> void:
	livello_qualita = l
	_dof_on = l >= Qualita.ALTO
	if not _dof_on:
		_attr.dof_blur_far_enabled = false
		_attr.dof_blur_near_enabled = false
		_dof_k = 0.0
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if l >= Qualita.ALTO else RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	_sole.shadow_blur = 1.6 if l >= Qualita.ALTO else 1.0
	_env.glow_enabled = l >= Qualita.MEDIO
	_stadio.set_pubblico(1.0 if l >= Qualita.MEDIO else (0.5 if l == Qualita.BASSO else 0.0))
	_effetti.set_quantita(1.0 if l >= Qualita.MEDIO else (0.5 if l == Qualita.BASSO else 0.25))
	_effetti.scia_on = l >= Qualita.BASSO
	_effetti.sbuffi_on = l >= Qualita.BASSO


# bagliore leggero: solo le cose più luminose del bianco (led, lampade, maxischermo, riflessi forti)
func _imposta_bagliore() -> void:
	_env.glow_intensity = 0.55
	_env.glow_strength = 0.9
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.0
	_env.glow_hdr_scale = 1.6
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN


func _aggiorna_effetti(b: Object, dt_game: float, dt_real: float) -> void:
	if dt_real > 0.0:
		var r := dt_game / dt_real
		_rk_auto = lerpf(_rk_auto, clampf((0.6 - r) / 0.4, 0.0, 1.0), minf(1.0, dt_real * 5.0))
		_effetti.rallenty(r)
	else:
		_effetti.rallenty(0.0)
	# sbuffo d'erba quando parte un calcio da terra
	if b.kick != null and b.kick != _ultimo_calcio:
		if b.h < 0.6:
			_effetti.sbuffo(_ball.global_position)
	_ultimo_calcio = b.kick
	var v := Vector3(b.vx, b.vy, b.vh).length()
	var tiro: bool = b.owner == null and (b.shot != null or v > SCIA_V) and v > 9.0 and m.phase == "play"
	_effetti.scia(_ball.global_position, tiro, cam.global_position, dt_real)
	_aggiorna_profondita(dt_real)


# profondità di campo: nel rallenty (sfocati solo stadio e campo lontano) e nei primi piani (fuoco sul pallone)
func _aggiorna_profondita(dt_real: float) -> void:
	if not _dof_on:
		return
	var dist := cam.global_position.distance_to(_ball.global_position)
	var k_r := _rk_forzato if _rk_forzato >= 0.0 else _rk_auto
	var k_c := smoothstep(DOF_VICINO, DOF_PRIMO, dist)
	var k := maxf(k_r, k_c)
	_dof_k = lerpf(_dof_k, k, minf(1.0, maxf(dt_real, 1.0 / 60.0) * 4.0))
	var on := _dof_k > 0.02
	_attr.dof_blur_far_enabled = on
	_attr.dof_blur_near_enabled = on and k_c > 0.3
	if not on:
		return
	var oltre := lerpf(DOF_OLTRE, 5.0, k_c)
	_attr.dof_blur_far_distance = dist + oltre
	_attr.dof_blur_far_transition = oltre * 1.5
	_attr.dof_blur_near_distance = dist * 0.45
	_attr.dof_blur_near_transition = dist * 0.3
	_attr.dof_blur_amount = DOF_FORZA * _dof_k


# ---------------------------------------------------------------- risoluzione 3D
# Sull'iPhone lo schermo ha 3 pixel per punto: il 3D si disegna largo al massimo RISOLUZIONE_3D_LARGO px e si
# ingrandisce con FSR (come scripts/prova_campo.gd); l'interfaccia resta nitida.
func _imposta_risoluzione_3d() -> void:
	if not OS.has_feature("mobile"):
		return
	var vp := get_viewport()
	var largo_px := vp.get_visible_rect().size.x * vp.get_final_transform().get_scale().x
	var scala := clampf(RISOLUZIONE_3D_LARGO / maxf(1.0, largo_px), 0.5, 1.0)
	vp.scaling_3d_scale = scala
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scala < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
