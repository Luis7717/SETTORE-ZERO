# Un giocatore della partita (porting di Players3D/Athlete3D.pose di src/players3d.js e src/athlete3d.js):
# modello athlete.glb con la divisa dello shader, clip fermo/corsa/scatto/salto mescolati come nel web
# (scatto con sprintMix), pose procedurali sopra il clip (calcio, colpo di testa, tuffo, scivolata, a terra,
# esultanza, portiere pronto) e i giochetti del dribbling come movimenti calcolati con la IK (mosse/*).
#
# Nodi (come i gruppi three del web): Figura (posizione, verso, scala 1,25; +Z locale = avanti, +X = sinistra)
#   → Corpo (rotazioni e spostamenti del corpo intero) → Fix (verso, altezza e scala del modello) → modello.
# Le animazioni girano col tempo di gioco (AnimationTree in modo manuale, avanzato da posa()): col rallenty rallentano.
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const Giocatore := preload("res://scripts/giocatore.gd")
const MODELLO := preload("res://assets/models/athlete.glb")
const Mossa := preload("mosse/mossa.gd")
const Giochetti := preload("mosse/giochetti.gd")
const Corpo := preload("mosse/corpo.gd")
const IK := preload("mosse/ik.gd")
const FiguraMocap := preload("figura_mocap.gd")   # animazioni mocap (esultanze, parate, calci, rimessa, difesa)
const Capelli := preload("capelli.gd")            # capelli: mesh a parte sull'osso della testa (barba dipinta)

const MODEL_H := 1.84          # altezza del modello prima della scala del gioco (come src/athlete3d.js)
const RUN_FULL := 1.6          # m/s: sopra questa velocità il clip di corsa è a peso pieno
const RUN_REF := 4.2           # m/s: velocità a cui la corsa gira a velocità 1
const SPRINT_REF := 8.0
const SPRINT_FROM := 7.6       # sprintMix: senza scatto il clip di scatto arriva solo a velocità altissime...
const SPRINT_FULL := 9.5
const SPRINT_ON_FROM := 5.0    # ... col giocatore che scatta davvero (p.sprint) arriva presto
const SPRINT_ON_FULL := 6.6
const KICK_T := 0.35           # durata di kickAnim nel motore
const HEAD_H := 1.3            # palla sopra questa altezza al momento del colpo = colpo di testa
const IDLE_FIX_LEGS := 0.12    # rad: nel clip "fermo" si chiudono un po' le gambe...
const IDLE_FIX_ARMS := -0.05   # ... e si aprono appena le braccia
const TRICK_BLEND := 0.12      # s: entrata e uscita dal movimento calcolato del giochetto
# raggio del pallone a schermo (m del gioco; vista.gd BALL_R). 2026-11-22: da 0,21 a 0,16 (Luis: "palla leggermente
# troppo grande rispetto ai giocatori", alti 2,3 m a schermo). I giochetti restano misurati col pallone del web (0,21,
# mosse/giochetti.gd MATCH_R: stesse pose del JS), cambia solo quanto è grande quello disegnato
const PALLA_R := 0.16
# portiere "pronto" (gambe piegate, braccia avanti e aperte) a gioco fermo solo se difende su questi calci da fermo
const GK_PRONTO_SU := ["penalty", "corner", "freekick"]
# rilancio dalle mani (ripresa "gk" del motore): il portiere tiene il pallone davanti al petto (metri del modello,
# riferimento del corpo: +X sinistra, +Y su, +Z avanti); polsi ai lati del pallone, gomiti in basso, fuori e indietro
const MANO_PALLA := Vector3(0, 1.12, 0.3)
const MANO_POLSO := Vector3(0.05, -0.03, -0.05)    # polso rispetto al lato del pallone (x verso fuori)
const MANO_GOMITO := Vector3(0.6, -0.6, -0.5)      # verso dei gomiti (x verso fuori)
const MANO_ENTRA := 0.2        # s: il pallone arriva nelle mani
const MANO_ESCE := 0.3         # s: dopo il rilancio torna sul pallone vero
const AX_X := 0
const AX_Y := 1
const AX_Z := 2
const TRUNK := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"]
const P_SALTO := &"parameters/salto/blend_amount"
const P_MOTO := &"parameters/moto/blend_amount"
const P_CORSA := &"parameters/corsa/blend_amount"
const P_TS_RUN := &"parameters/ts_run/scale"
const P_TS_SPRINT := &"parameters/ts_sprint/scale"
const P_TS_JUMP := &"parameters/ts_jump/scale"
const PARAM_EPS := 0.004       # sotto questa differenza un parametro dell'albero non si riscrive

# risorse e misure condivise (costruite una volta)
static var _pronto := false
static var _albero: AnimationNodeBlendTree
static var _fix_yaw := 0.0
static var _fix_scale := 1.0
static var _fix_y := 0.0
static var _fix_q := Quaternion.IDENTITY
static var _rest_q := {}       # osso → orientamento in posa di legame nel riferimento del corpo
static var _limbs := {}        # "leg_l"... → {up, mid, end, dU, dL, h}

var corpo: Node3D
var _fix: Node3D
var _scheletro: Skeleton3D
var _anim: AnimationTree
var _ossa := {}                # nome → indice
var _todo: Array = []          # [osso, asse, angolo] da applicare sopra il clip
var _saved: Array = []         # [osso, tipo (0 rotazione, 1 posizione), valore] per rimettere la posa del clip
var _w_idle := 0.0
var _params := PackedFloat32Array([0.0, 0.0, 0.0, -1.0, -1.0, -1.0])   # ultimi valori scritti (_param)
var _gcache := {}              # osso → posa globale calcolata in questo fotogramma (vedi _glob)
var _avviso: Sprite3D
var _mesh: MeshInstance3D
var _capelli: MeshInstance3D   # capelli (Capelli.mesh_per), sotto l'osso della testa
var _stile2 := Vector4(2, 0, 0, 0)   # taglio, barba, sopracciglia, calzoncini (come stile2 di divisa.gdshader)
var _corsa := 0.0              # ultimo valore di "corsa" dato allo shader (la maglia ondeggia)
## clip mocap di questa figura (figura_mocap.gd); null solo prima di prepara()
var mocap: FiguraMocap
## pallone tra le mani del portiere nel rilancio dalle mani (0..1, entra ed esce dolce)
var mano_gk := 0.0
## esultanza del campione in corso: null, oppure {fr, corsa, vel, corpo, braccia} di mosse/esultanza.gd posa() più
## w (peso 0..1, entrata e uscita). La mette chi la guida (esultanza_regia.gd in partita, l'anteprima nell'editor)
## prima di posa(): finché c'è, comanda lei (niente clip mocap né pose del motore)
var esultanza: Variant = null


## kit: maglia, calzoncini, calzettoni, bordino (Color) e se c'è stile, numero (Vector4); aspetto: pelle, capelli
## (Color) e se ci sono iride, scarpe (Color), stile2 (Vector4): parametri di shaders/divisa.gdshader
func prepara(kit: Dictionary, aspetto: Dictionary, sfasa: float, tex_avviso: Texture2D) -> void:
	corpo = Node3D.new()
	corpo.name = "Corpo"
	add_child(corpo)
	_fix = Node3D.new()
	_fix.name = "Fix"
	corpo.add_child(_fix)
	var modello := MODELLO.instantiate() as Node3D
	modello.name = "Modello"
	_fix.add_child(modello)
	var mesh := modello.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_scheletro = modello.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := modello.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not _pronto:
		_prepara_condivisi(mesh, _scheletro, player)
	mesh.mesh = Giocatore._mesh_divisa
	mesh.material_override = Giocatore._materiale
	for k: String in kit:
		mesh.set_instance_shader_parameter(k, kit[k])
	_mesh = mesh
	_capelli = Capelli.attacca(_scheletro, mesh.skin)
	metti_aspetto(aspetto)
	_fix.rotation.y = _fix_yaw
	_fix.scale = Vector3.ONE * _fix_scale
	_fix.position.y = _fix_y
	for i in _scheletro.get_bone_count():
		_ossa[_scheletro.get_bone_name(i)] = i
	_anim = AnimationTree.new()
	_anim.name = "Animazioni"
	modello.add_child(_anim)
	_anim.anim_player = _anim.get_path_to(player)
	_anim.tree_root = _albero
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	mocap = FiguraMocap.new(self, player, _anim)   # [mocap] libreria "mocap" nel suo AnimationPlayer
	_anim.active = true
	_anim.set(P_MOTO, 0.0)
	_anim.set(P_SALTO, 0.0)
	_anim.set(P_CORSA, 0.0)
	_anim.advance(sfasa)   # i giocatori non corrono tutti col passo uguale
	_avviso = Sprite3D.new()
	_avviso.texture = tex_avviso
	_avviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_avviso.no_depth_test = true
	_avviso.pixel_size = 0.7 / 64.0
	_avviso.position.y = 2.25
	_avviso.render_priority = 20
	_avviso.visible = false
	add_child(_avviso)


## pelle, capelli (Color) e, se ci sono, iride, scarpe, stile2, occhi_forma (Aspetto.parametri_figura): parametri
## dello shader della divisa (barba, sopracciglia, occhi, cute dipinti) e mesh dei capelli del taglio. Si può
## richiamare per cambiare aspetto (anteprima dell'editor: il modellino cambia subito)
func metti_aspetto(aspetto: Dictionary) -> void:
	for k: String in aspetto:
		if k != "punte":   # punte: solo i capelli (sfumati)
			_mesh.set_instance_shader_parameter(k, aspetto[k])
	if aspetto.has("stile2"):
		_stile2 = aspetto.stile2
	var m := Capelli.mesh_per(int(_stile2.x + 0.5))
	if _capelli.mesh != m:
		_capelli.mesh = m
	_capelli.visible = m != null
	if aspetto.has("capelli"):
		_capelli.set_instance_shader_parameter(&"colore", aspetto.capelli)
	if aspetto.has("pelle"):
		_capelli.set_instance_shader_parameter(&"pelle", aspetto.pelle)
	if aspetto.has("punte"):
		_capelli.set_instance_shader_parameter(&"punte", aspetto.punte)


## peso del clip di scatto (0..1) a velocità v (m/s); sprinting = il motore dice che il giocatore sta scattando
static func sprint_mix(v: float, sprinting: bool) -> float:
	return smoothstep(SPRINT_ON_FROM, SPRINT_ON_FULL, v) if sprinting else smoothstep(SPRINT_FROM, SPRINT_FULL, v)


## Posa a ogni fotogramma (dt = tempo di gioco). p = giocatore del motore; ctx = {t, phase, flip, yaw, ball, trick}
## con trick = null oppure {id, q (0..1), side (±1)}.
func posa(p: Object, dt: float, ctx: Dictionary) -> void:
	_rimetti()
	_avviso.visible = p.warn
	if esultanza != null:
		_posa_esultanza(esultanza, dt, ctx)
		return
	var mc := mocap.aggiorna(p, dt, ctx)   # [mocap] peso della clip mocap (0 = nessuna)
	var v := sqrt(p.vx * p.vx + p.vy * p.vy)
	var run := clampf((v - 0.25) / RUN_FULL, 0.0, 1.0)
	var corsa := clampf(v / SPRINT_REF, 0.0, 1.0)
	if absf(corsa - _corsa) > 0.06:
		_corsa = corsa
		_mesh.set_instance_shader_parameter(&"corsa", corsa)
	var bx := 0.0
	var by := 0.0
	var bz := 0.0
	var px := 0.0
	var py := 0.0
	var pz := 0.0
	var w_idle := 1.0 - run
	var w_run := run
	var w_jump := 0.0
	var st: String = p.state
	var cele: bool = p.cele > 0 and ctx.phase == "goal"
	var b: Object = ctx.ball
	var near_ball: bool = b != null and Vector2(b.x - p.x, b.y - p.y).length() < 2.2
	var header: bool = p.kickAnim > 0.0 and near_ball and b.h > HEAD_H
	var trick: Variant = ctx.get("trick")
	var m: Object = ctx.get("m")
	var in_mano := palla_in_mano(p, m)
	mano_gk = move_toward(mano_gk, 1.0 if in_mano else 0.0, dt / (MANO_ENTRA if in_mano else MANO_ESCE)) if dt > 0.0 else (1.0 if in_mano else mano_gk)
	if st == "slide" or st == "down" or (st == "dive" and p.dive != null):
		w_idle = 1.0
		w_run = 0.0
	elif cele or header:
		w_idle = 0.0
		w_run = 0.0
		w_jump = 1.0
	_mescola(w_idle, w_run, w_jump, v, cele, p.sprint)
	_w_idle *= 1.0 - mc   # [mocap] le correzioni del clip "fermo" non vanno sopra la clip mocap
	_anim.advance(dt)
	_gcache.clear()
	var s := Coord.SCALE
	if mocap.al_posto_delle_pose():   # [mocap] la clip fa tutto il corpo: niente pose calcolate, solo il giro
		by = mocap.yaw
	elif st == "slide":
		bx = -1.2
		py = 0.36 / s
		pz = -0.3
		_rot("thigh_l", AX_X, -0.3); _rot("thigh_r", AX_X, -1.05); _rot("calf_l", AX_X, 0.5)
		_rot("upperarm_l", AX_Z, 0.9); _rot("upperarm_r", AX_Z, -0.9)
	elif st == "down":
		bx = -1.42
		py = 0.26 / s
		pz = -0.4
		_rot("thigh_l", AX_X, -0.25); _rot("thigh_r", AX_X, -0.45); _rot("calf_l", AX_X, 0.6); _rot("calf_r", AX_X, 0.25)
		_rot("upperarm_l", AX_Z, 0.7); _rot("upperarm_r", AX_Z, -0.7)
	elif st == "dive" and p.dive != null:
		var d: Object = p.dive
		var pr := minf(1.0, p.t / 0.35)
		var lx := 1.0 if float(ctx.flip) * d.dirx * cos(float(ctx.yaw)) >= 0.0 else -1.0
		var reach := 1.0 if absf(d.tx - d.x0) > 0.9 else 0.35
		bz = -lx * pr * 1.35 * reach
		py = (maxf(0.25, d.hh - 0.6) * pr * reach + sin(pr * 3.14) * 0.3) / s
		_rot("upperarm_l", AX_Z, 2.7 * pr + 0.2); _rot("upperarm_r", AX_Z, -2.7 * pr - 0.2)
		_rot("thigh_l", AX_Z, 0.2 * pr); _rot("thigh_r", AX_Z, -0.2 * pr)
		_rot("calf_l", AX_X, 0.3); _rot("calf_r", AX_X, 0.4)
	elif cele:
		var t: float = ctx.t
		py = absf(sin(t * 7.0 + p.i)) * 0.3
		# braccia a V larghe: dritte in alto sparirebbero dietro la testa
		var w := 0.2 * sin(t * 9.0 + p.i)
		_rot("upperarm_l", AX_Z, 1.05 + w); _rot("upperarm_r", AX_Z, -1.05 - w)
		_rot("lowerarm_l", AX_Z, 0.4); _rot("lowerarm_r", AX_Z, -0.4)
	elif trick != null and st == "play":
		pass   # movimento calcolato, dopo _applica_rot
	elif header:
		var q: float = 1.0 - p.kickAnim / KICK_T
		py = sin(q * PI) * 0.35
		_rot("spine_02", AX_X, 0.5 * sin(q * PI * 2.0 - 0.6))
		_rot("upperarm_l", AX_Z, 1.0); _rot("upperarm_r", AX_Z, -1.0)
	elif p.kickAnim > 0.0:
		var q: float = 1.0 - p.kickAnim / KICK_T
		_rot("thigh_r", AX_X, 0.5 - 1.9 * sin(q * PI))
		_rot("calf_r", AX_X, 1.1 * (1.0 - q))
		_rot("spine_02", AX_X, -0.18)
		_rot("upperarm_l", AX_Z, 0.8); _rot("upperarm_r", AX_X, -0.7)
	elif in_mano:
		pass   # braccia col pallone, dopo _applica_rot (_tieni_palla)
	elif v < 1.2 and portiere_pronto(p, m, String(ctx.phase), b):
		# portiere pronto: gambe piegate, braccia avanti e aperte
		py = -0.06
		_rot("spine_02", AX_X, 0.25)
		_rot("thigh_l", AX_X, -0.45); _rot("thigh_r", AX_X, -0.45)
		_rot("calf_l", AX_X, 0.75); _rot("calf_r", AX_X, 0.75)
		_rot("upperarm_l", AX_Z, 0.7); _rot("upperarm_r", AX_Z, -0.7)
		_rot("upperarm_l", AX_X, -0.6); _rot("upperarm_r", AX_X, -0.6)
	elif run > 0.3:
		bx = 0.08 * run
	# rotazione del corpo come Euler "XYZ" di three.js (Rx · Ry · Rz)
	corpo.basis = Basis(Vector3.RIGHT, bx) * Basis(Vector3.UP, by) * Basis(Vector3.BACK, bz)
	corpo.position = Vector3(px, py, pz)
	_applica_rot()
	if trick != null and st == "play" and not cele and mc <= 0.0:
		_giochetto(trick)
	if mano_gk > 0.0 and mc <= 0.0:
		_tieni_palla(mano_gk)


## portiere col pallone in mano: rilancio dalle mani (ripresa "gk" del motore) finché non calcia
static func palla_in_mano(p: Object, m: Object) -> bool:
	if m == null or m.phase != "restart" or m.restart == null:
		return false
	return m.restart.type == "gk" and m.restart.taker == p and p.kickAnim <= 0.0


## portiere in posa "pronto" (gambe piegate, braccia avanti e aperte): solo quando può arrivare un tiro. A gioco fermo
## (rinvio dal fondo, rimesse, calcio d'inizio, gol, intervallo) sta dritto e rilassato come gli altri, tranne quello
## che difende su rigore, angolo o punizione; col pallone tra i piedi mai. Senza partita (m = null) conta solo la fase.
static func portiere_pronto(p: Object, m: Object, fase: String, ball: Object) -> bool:
	if p.pos != "P" or (ball != null and ball.owner == p):
		return false
	if fase == "play":
		return true
	if fase != "restart" or m == null or m.restart == null:
		return false
	return m.restart.team != p.team and GK_PRONTO_SU.has(m.restart.type)


## pallone tra le mani: Vector4(x, y, z del mondo, peso 0..1), peso 0 = il pallone resta dov'è. Rimessa laterale
## (clip mocap) o rilancio del portiere dalle mani (mano_gk)
func pallone_in_mano() -> Vector4:
	if mano_gk <= 0.0:
		return mocap.pallone_in_mano() if mocap != null else Vector4.ZERO
	_gcache.clear()
	var c := (pos_corpo("hand_l") + pos_corpo("hand_r")) * 0.5 + Vector3(0, -MANO_POLSO.y, -MANO_POLSO.z)
	var w: Transform3D = global_transform if is_inside_tree() else transform
	var g := w * (corpo.transform * c)
	return Vector4(g.x, g.y, g.z, mano_gk)


# polsi ai lati del pallone davanti al petto (IK delle braccia), peso w
func _tieni_palla(w: float) -> void:
	var r := PALLA_R / Coord.SCALE   # raggio del pallone a schermo nelle misure del modello
	for s: String in ["l", "r"]:
		var x := 1.0 if s == "l" else -1.0
		var polso := MANO_PALLA + Vector3(x * (r + MANO_POLSO.x), MANO_POLSO.y, MANO_POLSO.z)
		_arto(_limbs["arm_" + s], polso, Vector3(x * MANO_GOMITO.x, MANO_GOMITO.y, MANO_GOMITO.z), null, w)


# pesi e velocità dei clip (Athlete3D.blend): sopra SPRINT_FROM lo scatto prende il posto della corsa
func _mescola(w_idle: float, w_run: float, w_jump: float, v: float, cele: bool, sprinting: bool) -> void:
	_w_idle = 0.0 if w_jump > 0.0 else w_idle
	_param(0, P_SALTO, w_jump)
	_param(1, P_MOTO, w_run if w_jump < 1.0 else 0.0)
	_param(2, P_CORSA, sprint_mix(v, sprinting))
	_param(3, P_TS_RUN, clampf(v / RUN_REF, 0.6, 1.6))
	_param(4, P_TS_SPRINT, clampf(v / SPRINT_REF, 0.8, 1.3))
	_param(5, P_TS_JUMP, 1.3 if cele else 1.6)


# parametro dell'albero delle animazioni, scritto solo se cambia davvero (scriverlo costa: 6 × 22 a fotogramma)
func _param(k: int, nome: StringName, val: float) -> void:
	if absf(_params[k] - val) > PARAM_EPS:
		_params[k] = val
		_anim.set(nome, val)


# rotazione di un osso attorno a un asse del corpo (x = di lato, y = su, z = avanti), sopra la posa del clip
func _rot(nome: String, ax: int, ang: float) -> void:
	if ang == 0.0 or not _ossa.has(nome):
		return
	_todo.append([_ossa[nome], ax, ang])


# tutte le correzioni calcolate sulla posa del clip, poi applicate (i figli "seguono" il padre). Senza altre pose,
# nel clip "fermo" gambe e braccia si chiudono un po' (in proporzione al peso del clip).
func _applica_rot() -> void:
	if _todo.is_empty() and _w_idle > 0.05:
		var w := _w_idle
		_rot("thigh_l", AX_Z, -IDLE_FIX_LEGS * w); _rot("thigh_r", AX_Z, IDLE_FIX_LEGS * w)
		_rot("upperarm_l", AX_Z, -IDLE_FIX_ARMS * w); _rot("upperarm_r", AX_Z, IDLE_FIX_ARMS * w)
	if _todo.is_empty():
		return
	var out: Array = []
	for e: Array in _todo:
		var b: int = e[0]
		var asse := Vector3.RIGHT if e[1] == AX_X else (Vector3.UP if e[1] == AX_Y else Vector3.BACK)
		var pq := _fix_q * _rot_globale(_scheletro.get_bone_parent(b))
		# D = P⁻¹ · R · P  (P = orientamento del padre nel riferimento del corpo)
		out.append([b, pq.inverse() * Quaternion(asse, e[2]) * pq])
	for e: Array in out:
		var b: int = e[0]
		var q := _scheletro.get_bone_pose_rotation(b)
		_saved.append([b, 0, q])
		_scheletro.set_bone_pose_rotation(b, (e[1] as Quaternion) * q)
	_gcache.clear()
	_todo.clear()


func _rot_globale(b: int) -> Quaternion:
	if b < 0:
		return Quaternion.IDENTITY
	return _glob(b).basis.orthonormalized().get_rotation_quaternion()


# posa globale di un osso (nello spazio dello scheletro) calcolata dalle pose locali di adesso: quella che dà lo
# Skeleton3D si aggiorna solo al disegno, e qui serve subito dopo ogni osso cambiato (i figli seguono il padre)
func _glob(b: int) -> Transform3D:
	if b < 0:
		return Transform3D.IDENTITY
	var c: Variant = _gcache.get(b)
	if c != null:
		return c
	var loc := Transform3D(Basis(_scheletro.get_bone_pose_rotation(b)).scaled(_scheletro.get_bone_pose_scale(b)), _scheletro.get_bone_pose_position(b))
	var g := _glob(_scheletro.get_bone_parent(b)) * loc
	_gcache[b] = g
	return g


# rimette la posa del clip delle ossa toccate al fotogramma prima (le correzioni non si sommano)
func _rimetti() -> void:
	for i in range(_saved.size() - 1, -1, -1):
		var e: Array = _saved[i]
		if e[1] == 0:
			_scheletro.set_bone_pose_rotation(e[0], e[2])
		else:
			_scheletro.set_bone_pose_position(e[0], e[2])
	_saved.clear()


# ---------------------------------------------------------------- giochetti: movimento calcolato + IK
# tutto il corpo nella posa del movimento (col sinistro, side −1, specchiato); entra ed esce sfumando dal clip
func _giochetto(tr: Dictionary) -> void:
	var mv := Giochetti.trick_move(tr.id)
	var u := clampf(float(tr.q), 0.0, 1.0) * mv.T
	var fr := mv.at(u)
	if float(tr.side) < 0.0:
		fr = Mossa.mirror_frame(fr)
	applica_mossa(fr, clampf(minf(u / TRICK_BLEND, (mv.T - u) / TRICK_BLEND), 0.0, 1.0))


## mette lo scheletro nella posa fr di una Mossa (src/move-pose.js applyMove): bacino, busto, collo e testa con la
## rotazione voluta rispetto alla posa di legame, braccia e gambe con la IK, piede orientato. w = peso (0..1);
## w_corpo (se >= 0) = peso diverso per bacino, busto e gambe (esultanze: correndo le gambe le fa il clip di corsa);
## w_braccia e w_busto (se >= 0) = pesi diversi per le braccia e per il busto (bacino girato, schiena, collo, testa)
func applica_mossa(fr: Dictionary, w: float, w_corpo: float = -1.0, w_braccia: float = -1.0, w_busto: float = -1.0) -> void:
	var wc := w if w_corpo < 0.0 else w_corpo
	var wb := w if w_braccia < 0.0 else w_braccia
	var wt := wc if w_busto < 0.0 else w_busto
	if wc > 0.0:
		_set_pos("pelvis", fr.pelvis.p, wc)
	if wt > 0.0:
		for n: String in TRUNK:
			_set_quat(n, (fr.rot[n] as Quaternion) * _rest_q[n], wt)
	if wb > 0.0:
		for s: String in ["l", "r"]:
			_set_quat("clavicle_" + s, (fr.rot.spine_03 as Quaternion) * _rest_q["clavicle_" + s], wb)
			var a: Variant = fr.arms.get(s)
			if a != null:
				_arto(_limbs["arm_" + s], a.hand, a.pole, null, wb)
	if wc > 0.0:
		for s: String in ["l", "r"]:
			var l: Variant = fr.legs.get(s)
			if l != null:
				_arto(_limbs["leg_" + s], l.ankle, l.pole, l.fq, wc)


# esultanza del campione (mosse/esultanza.gd): clip di fermo o di corsa sotto, corpo intero spostato e girato,
# posa calcolata sopra (le gambe solo fuori dalla corsa)
func _posa_esultanza(e: Dictionary, dt: float, ctx: Dictionary) -> void:
	mocap.spegni(ctx.get("m"))
	var w: float = e.get("w", 1.0)
	var corsa: float = e.corsa
	_mescola(1.0 - corsa, corsa, 0.0, e.vel, false, false)
	_w_idle = 0.0
	_anim.advance(dt)
	_gcache.clear()
	corpo.transform = Transform3D.IDENTITY.interpolate_with(e.corpo, w) if w < 1.0 else e.corpo
	applica_mossa(e.fr, w, w * (1.0 - corsa), w * float(e.braccia), w * float(e.get("busto", 1.0 - corsa)))


# due ossa verso il bersaglio: radice, metà e fine
func _arto(lm: Dictionary, target: Vector3, pole: Vector3, fq: Variant, w: float) -> void:
	var a := pos_corpo(lm.up)
	var k := pos_corpo(lm.mid)
	var e := pos_corpo(lm.end)
	var s := IK.two_bone(a, target, a.distance_to(k), k.distance_to(e), pole)
	var hinge: Vector3 = s.hinge
	_set_quat(lm.up, Corpo.q_align(lm.dU, lm.h, ((s.knee as Vector3) - a).normalized(), hinge) * _rest_q[lm.up], w)
	_set_quat(lm.mid, Corpo.q_align(lm.dL, lm.h, ((s.end as Vector3) - (s.knee as Vector3)).normalized(), hinge) * _rest_q[lm.mid], w)
	if fq != null:
		_set_quat(lm.end, (fq as Quaternion) * _rest_q[lm.end], w)


## posizione di un osso nel riferimento del corpo (metri del modello: +X sinistra, +Y su, +Z avanti)
func pos_corpo(nome: String) -> Vector3:
	var o := _glob(_ossa[nome]).origin
	return Vector3(0, _fix_y, 0) + _fix_q * (o * _fix_scale)


# osso con orientamento q nel riferimento del corpo; w < 1 = mescolato con la posa che ha già
func _set_quat(nome: String, q: Quaternion, w: float) -> void:
	var b: int = _ossa[nome]
	var qs := _fix_q.inverse() * q
	var loc := _rot_globale(_scheletro.get_bone_parent(b)).inverse() * qs
	var cur := _scheletro.get_bone_pose_rotation(b)
	_saved.append([b, 0, cur])
	_scheletro.set_bone_pose_rotation(b, cur.slerp(loc, w) if w < 1.0 else loc)
	_gcache.clear()


# osso nel punto p (riferimento del corpo)
func _set_pos(nome: String, p: Vector3, w: float) -> void:
	var b: int = _ossa[nome]
	var ps := _fix_q.inverse() * (p - Vector3(0, _fix_y, 0)) / _fix_scale
	var par := _scheletro.get_bone_parent(b)
	var loc := _glob(par).affine_inverse() * ps
	var cur := _scheletro.get_bone_pose_position(b)
	_saved.append([b, 1, cur])
	_scheletro.set_bone_pose_position(b, cur.lerp(loc, w) if w < 1.0 else loc)
	_gcache.clear()


# ---------------------------------------------------------------- risorse condivise
static func _prepara_condivisi(mi: MeshInstance3D, sk: Skeleton3D, player: AnimationPlayer) -> void:
	_pronto = true
	if Giocatore._mesh_divisa == null:
		Giocatore._prepara_condivisi(mi, sk, player)
	if player.has_animation("jump"):
		player.get_animation("jump").loop_mode = Animation.LOOP_LINEAR
	# verso: la punta del piede guarda +Z (il "davanti" del corpo, come nel web); altezza MODEL_H coi piedi a terra
	var gr := func(nome: String) -> Transform3D: return sk.get_bone_global_rest(sk.find_bone(nome))
	var punta: Vector3 = gr.call("ball_r").origin - gr.call("foot_r").origin
	_fix_yaw = -atan2(punta.x, punta.z)
	var aabb := Giocatore._mesh_divisa.get_aabb()
	_fix_scale = MODEL_H / aabb.size.y
	_fix_y = -aabb.position.y * _fix_scale
	_fix_q = Quaternion(Vector3.UP, _fix_yaw)
	for i in sk.get_bone_count():
		_rest_q[sk.get_bone_name(i)] = _fix_q * sk.get_bone_global_rest(i).basis.orthonormalized().get_rotation_quaternion()
	var rp := func(nome: String) -> Vector3: return _fix_q * ((gr.call(nome) as Transform3D).origin * _fix_scale)
	for s: String in ["l", "r"]:
		_limbs["leg_" + s] = {"up": "thigh_" + s, "mid": "calf_" + s, "end": "foot_" + s,
			"dU": (rp.call("calf_" + s) - rp.call("thigh_" + s)).normalized(), "dL": (rp.call("foot_" + s) - rp.call("calf_" + s)).normalized(),
			"h": Vector3(1, 0, 0)}
		_limbs["arm_" + s] = {"up": "upperarm_" + s, "mid": "lowerarm_" + s, "end": "hand_" + s,
			"dU": (rp.call("lowerarm_" + s) - rp.call("upperarm_" + s)).normalized(), "dL": (rp.call("hand_" + s) - rp.call("lowerarm_" + s)).normalized(),
			"h": Vector3(0, -1 if s == "l" else 1, 0)}
	_albero = _costruisci_albero()


# fermo / corsa / scatto / salto, ognuno con la sua velocità (come le azioni del mixer di three)
static func _costruisci_albero() -> AnimationNodeBlendTree:
	var t := AnimationNodeBlendTree.new()
	var x := 0.0
	for nome: String in ["idle", "run", "sprint", "jump"]:
		var a := AnimationNodeAnimation.new()
		a.animation = nome
		t.add_node(nome, a, Vector2(x, 0))
		x += 200.0
	for nome: String in ["run", "sprint", "jump"]:
		t.add_node("ts_" + nome, AnimationNodeTimeScale.new(), Vector2(200, 200))
		t.connect_node("ts_" + nome, 0, nome)
	t.add_node("corsa", AnimationNodeBlend2.new(), Vector2(400, 300))
	t.connect_node("corsa", 0, "ts_run")
	t.connect_node("corsa", 1, "ts_sprint")
	t.add_node("moto", AnimationNodeBlend2.new(), Vector2(600, 300))
	t.connect_node("moto", 0, "idle")
	t.connect_node("moto", 1, "corsa")
	t.add_node("salto", AnimationNodeBlend2.new(), Vector2(800, 300))
	t.connect_node("salto", 0, "moto")
	t.connect_node("salto", 1, "ts_jump")
	t.connect_node("output", 0, "salto")
	FiguraMocap.estendi_albero(t, "salto")   # [mocap] output ← Blend2 "mocap" (salto, clip mocap)
	return t
