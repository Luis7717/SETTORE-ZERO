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
#   user_yaw, cam_drag, drawing        scritti da chi gestisce il dito (src/input.js), letti qui; il ritorno dolce
#                                      di user_yaw a 0 (relaxYaw) lo fa la vista in update_view
#
# Coordinate: il gioco ha x larghezza, y lunghezza, h altezza. In Godot X = s·x, Y = h, Z = −s·y con s = −1 se la
# squadra umana è la 1: così chi gioca attacca sempre "in su" sullo schermo, come nel web (View.flip).
class_name PartitaVista
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const Figura := preload("figura.gd")
const TV := preload("texture_vista.gd")
const CU := preload("camuser.gd")
const Giochetti := preload("mosse/giochetti.gd")

const BALL_R := 0.21           # raggio del pallone a schermo (più grande del vero, per leggerlo da lontano)
const PASS_RECV := 5.0         # linea "pass": compagno entro questa distanza dalla fine = riceve (anello verde)
const RING_K := 1.9            # anello del controllato: scala, pulsa di ±0,12 a 6 rad/s
const MARKER_H := 2.75         # segnalino sopra il controllato (m)
const SHADOW_SIZE := 1.15      # ombra morbida sotto i giocatori (m)
const NET_K := 170.0           # rete: molla e smorzamento (oscilla ~2 volte al secondo), come src/props.js
const NET_C := 7.0
const NET_KICK := 0.14         # spinta del pallone che arriva in fondo alla rete (per m/s)
const NET_FAR := 0.78          # trasparenza della rete: porta avversaria / propria porta (guardata attraverso)
const NET_NEAR := 0.22
const RETE_FONDO := 2.0        # profondità della rete a terra e alla traversa (come scripts/campo.gd)
const RETE_ALTO := 1.0
const NET_MAX := 0.45          # il telo si gonfia al massimo così (m); il pallone a schermo non va oltre
const RISOLUZIONE_3D_LARGO := 780.0   # sul telefono il 3D si disegna largo al massimo così (px), poi FSR

# divise come nel gioco web (src/career.js kitOf: Rosso e Blu; portieri arancio e verde)
const KIT_CASA := {"shirt": 0xc8102e, "shorts": 0xffffff, "socks": 0xc8102e, "gk": {"shirt": 0xffa41c, "shorts": 0x222222, "socks": 0xffa41c}}
const KIT_OSPITI := {"shirt": 0x1746a2, "shorts": 0xffffff, "socks": 0x1746a2, "gk": {"shirt": 0x2ad17a, "shorts": 0x15803d, "socks": 0x15803d}}
const PELLI := [Color("#f1c9a5"), Color("#d9a47a"), Color("#a9744f"), Color("#6b4630")]
const CAPELLI := [Color("#1c1410"), Color("#4a2f1b"), Color("#8a5a2b"), Color("#d9b66a"), Color("#222222")]

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
var _nets := {}                # lato in Godot (1 / −1) → {d, v, hit, entered, sp}
var _ctx := {"t": 0.0, "phase": "", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}   # riusato per tutti
var _zoom_t := -1.0            # zoom voluto dal gioco (set_zoom); < 0 = lo calcola la telecamera

@onready var cam: Camera3D = $Telecamera
@onready var _campo: Node3D = $Campo
@onready var _giocatori: Node3D = $Giocatori
@onready var _nastri: Node3D = $Nastri
@onready var _sole: DirectionalLight3D = $Sole


func _ready() -> void:
	_rng.randomize()
	_sole.look_at_from_position(Vector3(-0.42, 0.78, -0.46) * 60.0, Vector3.ZERO, Vector3.UP)
	_imposta_risoluzione_3d()
	_tex_warn = TV.avviso()
	_crea_pallone()
	_crea_segni()
	for lato: float in [1.0, -1.0]:
		_nets[lato] = {"d": 0.0, "v": 0.0, "hit": false, "entered": false, "sp": 0.0}


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
	var mm := _shadows.multimesh
	mm.instance_count = m.players.size()
	cam.reset(m.ball.x, m.ball.y)
	for lato: float in _nets:
		_nets[lato] = {"d": 0.0, "v": 0.0, "hit": false, "entered": false, "sp": 0.0}
	clear_path()


## dopo il passo del motore. dt_game = tempo di gioco (rallenty compreso), dt_real = tempo vero (0 in pausa)
func update_view(dt_game: float, dt_real: float) -> void:
	if m == null:
		return
	t += dt_game
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
	by = _dentro_la_rete(bx, by, bh)
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


func _kit_di(p: Object) -> Dictionary:
	var team: Dictionary = m.teams[p.team]
	var k: Dictionary = team.get("kit", KIT_CASA if p.team == 0 else KIT_OSPITI)
	var def: Dictionary = KIT_CASA if p.team == 0 else KIT_OSPITI
	if p.pos == "P":
		k = k.get("gk", def.gk)
	var shirt := _colore(k.get("shirt", 0xffffff))
	var shorts := _colore(k.get("shorts", 0xffffff))
	return {"maglia": shirt, "calzoncini": shorts, "calzettoni": _colore(k.get("socks", k.get("shirt", 0xffffff))), "bordino": shorts}


# pelle e capelli: dal giocatore (src.look {skin, hair} se c'è), altrimenti fissi per nome
func _aspetto_di(p: Object) -> Dictionary:
	var look: Variant = p.src.get("look")
	var h := hash(str(p.team) + ":" + str(p.name) + ":" + str(p.i))
	var skin: Color = PELLI[absi(h) % PELLI.size()]
	var hair: Color = CAPELLI[absi(h / 7) % CAPELLI.size()]
	if look is Dictionary:
		if look.has("skin"):
			skin = _colore(look.skin)
		if look.has("hair"):
			hair = _colore(look.hair)
	return {"pelle": skin, "capelli": hair}


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
	sfera.radial_segments = 20
	sfera.rings = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TV.palla()
	mat.roughness = 0.45
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
# pallone in porta oltre il fondo della rete (il motore lo tiene fino a 1,9 m dietro la linea): a schermo si ferma
# nel telo gonfio, non lo buca
func _dentro_la_rete(bx: float, by: float, bh: float) -> float:
	var depth := absf(by) - Coord.HL
	if depth <= 0.0 or absf(bx) > Coord.GW / 2.0 + 0.25 or bh > Coord.GH + 0.8:
		return by
	var lim := _fondo_rete(bh + BALL_R) + NET_MAX - BALL_R
	return signf(by) * (Coord.HL + minf(depth, lim))


# profondità del fondo della rete dietro la linea di porta all'altezza h (m)
static func _fondo_rete(h: float) -> float:
	return RETE_FONDO + (RETE_ALTO - RETE_FONDO) * clampf(h / Coord.GH, 0.0, 1.0)

# Rete che si gonfia quando il pallone arriva in fondo e poi ondeggia (src/props.js updateGoals, semplificata: un solo
# spostamento per porta, distribuito dallo shader attorno al punto d'impatto). La propria porta è più trasparente.
func _aggiorna_reti(b: Object, dt: float) -> void:
	var s := flip
	var wx: float = s * b.x
	var wz: float = -s * b.y
	var h: float = b.h + BALL_R
	for lato: float in _nets:
		var mat: ShaderMaterial = _campo.materiale_rete(lato)
		if mat == null:
			continue
		var g: Dictionary = _nets[lato]
		mat.set_shader_parameter("opacita", NET_NEAR if lato < 0.0 else NET_FAR)
		var depth := -wz * lato - Coord.HL      # quanto il pallone è oltre la linea di porta (m)
		var inside: bool = (m.phase == "goal" or m.phase == "play") and depth > -0.2 and depth < RETE_FONDO + 0.8 \
			and absf(wx) < Coord.GW / 2.0 + 0.25 and h < Coord.GH + 0.8 and absf(b.y) > Coord.HL - 0.3
		if inside and not g.entered:
			g.entered = true
			g.sp = Vector3(b.vx, b.vy, b.vh).length()
		var dn := _fondo_rete(h)
		if inside and depth > RETE_ALTO * 0.9 and not g.hit:
			g.hit = true
			g.v += minf(5.0, 1.0 + g.sp * NET_KICK) * 0.5
		if not inside:
			g.hit = false
			g.entered = false
		var target := clampf(depth + BALL_R - dn, 0.0, NET_MAX) if inside else 0.0
		var d: float = g.d
		var v: float = g.v
		if target > d:
			d += (target - d) * minf(1.0, dt * 30.0)
			v = maxf(v, 0.0)
		else:
			var steps := maxi(1, ceili(dt * 60.0))
			var hh := dt / steps
			for n in steps:
				v += (NET_K * (target - d) - NET_C * v) * hh
				d += v * hh
		if absf(d) < 1e-4 and absf(v) < 1e-3:
			d = 0.0
			v = 0.0
		g.d = d
		g.v = v
		if inside:
			mat.set_shader_parameter("colpo", Vector2(wx, h))
		mat.set_shader_parameter("gonfia", d)


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
