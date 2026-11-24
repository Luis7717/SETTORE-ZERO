# Sfondo 3D del menu principale (porting di src/menu-bg.js con la sequenza di src/menu-routine.js): il campione che
# si allena in mezzo al campo dello stadio (palleggi, un giochetto, corsa palla al piede, tiro, pallone nuovo), con
# fisica vera del pallone e posa del corpo calcolata con la IK (scripts/partita/mosse/*), luce calda da menu e una
# telecamera che gira piano attorno a lui. I pulsanti del menu stanno sopra (scena 3D a tutto schermo).
#
# Uso dal menu: istanziare res://scenes/menu/sfondo_menu.tscn dietro i pulsanti. Facoltativo:
#   imposta_giocatore(kit, aspetto)   divisa e aspetto del campione (kit come career.js: {shirt, shorts, socks},
#                                     colori 0xRRGGBB, "#rrggbb" o Color; aspetto {skin, hair}); senza, rosso e bianco
#   attivo = false / visible = false  ferma tutto (niente calcoli, telecamera e cielo staccati): il menu resta leggero
#                                     quando lo sfondo non si vede; tornando visibile riparte da dove era
# Da sola (prove): $G --path godot res://scenes/menu/sfondo_menu.tscn -- [opzioni]
#   --schermata=shots/x.png [--dopo=SEC]   schermata 390×844 ed esce
#   --tempo=SEC                            sequenza ferma a quell'istante (come `hold` del web)
#   --sequenza --schermata=shots/menu/s.png   una schermata per ogni fase (palleggio, giochetti, corsa, tiro, pallone nuovo)
#   --vicino                               telecamera di prova in primo piano (come dbgCam del web)
#   --senza-vsync --esci-dopo=SEC          FPS massimi del PC: stampa "FPS medi"
extends Node3D

const Routine := preload("res://scripts/menu/routine_menu.gd")
const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Coord := preload("res://scripts/coord.gd")
const Giochetti := preload("res://scripts/partita/mosse/giochetti.gd")
const Tiro := preload("res://scripts/partita/mosse/tiro.gd")
const HudFase1 := preload("res://scripts/hud.gd")

const FIG_S := Coord.SCALE          # scala del giocatore e del pallone (1,25, come in partita e nel web)
const BALL_R := 0.11                # raggio vero del pallone (m, prima della scala)
const POSTO := Vector2(0, 26)       # dove si allena (x, y del campo): nella metà avversaria, verso la porta a +y
const YAW := 0.55                   # tre quarti: si vedono viso, gambe e pallone (come il web)
const CAM_D := 7.2                  # telecamera: distanza, altezza e punto guardato (m), campo visivo (gradi)
const CAM_H := 1.45
const CAM_LOOK := 1.2
const CAM_FOV := 30.0
const ORBITA := 0.32                # rad: la telecamera gira piano attorno al giocatore di ± tanto...
const ORBITA_T := 38.0              # ... in tanti secondi
const RESPIRO := 0.5                # m: e si avvicina e allontana di tanto...
const RESPIRO_T := 23.0             # ... in tanti secondi
const CAM_VICINO := [Vector3(1.4, 1.0, 2.6), Vector3(0, 0.75, 0.3)]   # telecamera di prova: posizione e punto (locali)
const SOLE_DA := Vector3(-0.5, 0.62, -0.6)   # da dove arriva il sole (luce calda di fine pomeriggio, davanti a lui)
const MAX_DT := 0.05
const OMBRA_A := 0.35               # ombra del pallone: più piccola e chiara quando sale
const DISCO_A := 0.3                # ombra morbida sotto il giocatore
const RISOLUZIONE_3D_LARGO := 780.0 # sul telefono il 3D si disegna largo al massimo così (px), poi FSR (come la partita)
const KIT_BASE := {"shirt": 0xc8102e, "shorts": 0xffffff, "socks": 0xc8102e}
const ASPETTO_BASE := {"skin": "#d9a47a", "hair": "#2a1a10"}

## falso giocatore del motore per figura.posa (come `st` di src/menu-bg.js)
class Allenato:
	extends RefCounted
	var vx := 0.0
	var vy := 0.0
	var state := "play"
	var cele := 0
	var kickAnim := 0.0
	var pos := "A"
	var i := 0
	var warn := false
	var sprint := false
	var dive: Object = null
	var t := 0.0

## acceso: calcola e disegna. Spento (anche con visible = false): niente calcoli, telecamera e cielo staccati
var attivo := true:
	set(v):
		attivo = v
		_aggiorna_attivo()
## tempo fermo (prove a schermo): la sequenza resta a quell'istante. < 0 = scorre
var hold := -1.0
var t := 0.0

var _fig: Node3D = null
var _st := Allenato.new()
var _ctx := {"t": 0.0, "phase": "menu", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}
var _kit := KIT_BASE
var _aspetto := ASPETTO_BASE
var _opzioni := {}
var _vicino := false
var _fotogrammi := 0
var _inizio_ms := 0

@onready var _cam: Camera3D = $Telecamera
@onready var _ambiente: WorldEnvironment = $Ambiente
@onready var _campione: Node3D = $Campione
@onready var _pallone: MeshInstance3D = $Campione/Pallone
@onready var _ombra_pallone: MeshInstance3D = $Campione/OmbraPallone
@onready var _sole: DirectionalLight3D = $Sole

var _ambiente_env: Environment
var _ombra_mat: StandardMaterial3D


func _ready() -> void:
	_ambiente_env = _ambiente.environment
	_campione.position = Coord.a_godot(POSTO.x, POSTO.y)
	_campione.rotation.y = PI   # il davanti della figura è +Z locale: così guarda verso la porta a +y (Godot −Z)
	_campione.scale = Vector3.ONE * FIG_S
	_sole.look_at_from_position(_campione.position + SOLE_DA.normalized() * 50.0, _campione.position, Vector3.UP)
	_prepara_pallone()
	_crea_figura()
	_cam.fov = CAM_FOV
	_imposta_risoluzione_3d()
	Routine.moves()   # i movimenti si calcolano adesso, non al primo fotogramma
	if get_tree().current_scene == self:
		_leggi_opzioni()
	_aggiorna_attivo()
	_aggiorna(0.0)


## divisa e aspetto del campione (vedi in cima). Si può chiamare anche prima di aggiungere la scena all'albero
func imposta_giocatore(kit: Dictionary = {}, aspetto: Dictionary = {}) -> void:
	_kit = kit if not kit.is_empty() else KIT_BASE
	_aspetto = aspetto if not aspetto.is_empty() else ASPETTO_BASE
	if is_node_ready():
		_crea_figura()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_aggiorna_attivo()


# spento o nascosto: niente _process, la telecamera non è più quella attiva e il cielo si stacca (sennò il menu
# continuerebbe a disegnare cielo e nebbia dietro ai pulsanti)
func _aggiorna_attivo() -> void:
	if not is_node_ready():
		return
	var on := attivo and is_visible_in_tree()
	set_process(on)
	_cam.current = on
	_ambiente.environment = _ambiente_env if on else null
	_sole.visible = on


func _process(delta: float) -> void:
	_fotogrammi += 1
	var dt := minf(MAX_DT, delta)
	t = hold if hold >= 0.0 else t + dt
	_aggiorna(dt)


# un fotogramma: posa del corpo (clip + posa calcolata sopra), pallone, telecamera
func _aggiorna(dt: float) -> void:
	var r := Routine.at(t)
	if _fig != null:
		_st.vx = r.vx
		_ctx.t = t
		_fig.posa(_st, dt, _ctx)
		if r.frame != null and r.w > 0.0:
			_fig.applica_mossa(r.frame, r.w)
	var b: Dictionary = r.ball
	var p: Vector3 = b.p
	_pallone.visible = b.vis
	_ombra_pallone.visible = b.vis
	_pallone.position = p
	_pallone.quaternion = b.q
	var hk := maxf(0.0, p.y - BALL_R)
	_ombra_pallone.position = Vector3(p.x, 0.004, p.z)
	_ombra_pallone.scale = Vector3.ONE * (1.0 + hk * 0.5)
	_ombra_mat.albedo_color.a = OMBRA_A / (1.0 + hk * 1.5)
	_metti_telecamera()


# telecamera lenta: tre quarti davanti al giocatore, gira piano di qua e di là e respira (funzione del tempo della
# sequenza, così le schermate sono sempre uguali)
func _metti_telecamera() -> void:
	var g := _campione.global_transform
	if _vicino:
		_cam.global_position = g * (CAM_VICINO[0] as Vector3)
		_cam.look_at(g * (CAM_VICINO[1] as Vector3), Vector3.UP)
		return
	var a := YAW + ORBITA * sin(TAU * t / ORBITA_T)
	var d := CAM_D + RESPIRO * sin(TAU * t / RESPIRO_T)
	# nel riferimento del giocatore (+Z avanti, +X sua sinistra): la telecamera sta davanti, spostata alla sua destra
	var loc := Vector3(-sin(a) * d, CAM_H, cos(a) * d) / FIG_S
	_cam.global_position = g * loc
	_cam.look_at(g * Vector3(0, CAM_LOOK / FIG_S, 0), Vector3.UP)


func _crea_figura() -> void:
	if _fig != null:
		_fig.queue_free()
	_fig = Figura.new()
	_fig.name = "Figura"
	_campione.add_child(_fig)
	_fig.prepara(_kit_figura(_kit), _aspetto_figura(_aspetto), 0.0, TV.avviso())


func _prepara_pallone() -> void:
	var sfera := SphereMesh.new()
	sfera.radius = BALL_R
	sfera.height = BALL_R * 2.0
	sfera.radial_segments = 20
	sfera.rings = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TV.palla()
	mat.roughness = 0.4
	mat.metallic_specular = 0.6
	_pallone.mesh = sfera
	_pallone.material_override = mat
	_pallone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := PlaneMesh.new()
	q.size = Vector2(BALL_R * 2.6, BALL_R * 2.6)
	_ombra_mat = TV.materiale_segno(TV.ombra(64, 1.0), Color(1, 1, 1, OMBRA_A), 1, false)
	_ombra_mat.no_depth_test = false
	_ombra_pallone.mesh = q
	_ombra_pallone.material_override = _ombra_mat
	_ombra_pallone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disco := MeshInstance3D.new()
	disco.name = "Disco"
	var qd := PlaneMesh.new()
	qd.size = Vector2(2.0, 2.0)
	disco.mesh = qd
	var md := TV.materiale_segno(TV.ombra(64, 1.0), Color(1, 1, 1, DISCO_A), 0, false)
	md.no_depth_test = false
	disco.material_override = md
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disco.position.y = 0.002
	_campione.add_child(disco)


# kit come career.js ({shirt, shorts, socks}) → parametri dello shader della divisa (come _kit_di di vista.gd)
static func _kit_figura(k: Dictionary) -> Dictionary:
	var shirt := _colore(k.get("shirt", 0xc8102e))
	var shorts := _colore(k.get("shorts", 0xffffff))
	return {"maglia": shirt, "calzoncini": shorts, "calzettoni": _colore(k.get("socks", k.get("shirt", 0xc8102e))), "bordino": shorts}


static func _aspetto_figura(a: Dictionary) -> Dictionary:
	return {"pelle": _colore(a.get("skin", ASPETTO_BASE.skin)), "capelli": _colore(a.get("hair", ASPETTO_BASE.hair))}


static func _colore(v: Variant) -> Color:
	if v is Color:
		return v
	if v is String:
		return Color(v)
	return Color.hex((int(v) << 8) | 0xff)


# come la vista della partita: sul telefono il 3D largo al massimo RISOLUZIONE_3D_LARGO px, poi FSR
func _imposta_risoluzione_3d() -> void:
	if not OS.has_feature("mobile"):
		return
	var vp := get_viewport()
	var largo_px := vp.get_visible_rect().size.x * vp.get_final_transform().get_scale().x
	var scala := clampf(RISOLUZIONE_3D_LARGO / maxf(1.0, largo_px), 0.5, 1.0)
	vp.scaling_3d_scale = scala
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scala < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR


# ---------------------------------------------------------------- prove da riga di comando (solo da scena principale)
func _leggi_opzioni() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parti := arg.substr(2).split("=", true, 1)
			_opzioni[parti[0]] = parti[1] if parti.size() > 1 else "1"
	_vicino = _opzioni.has("vicino")
	if _opzioni.has("tempo"):
		hold = float(_opzioni["tempo"])
	if _opzioni.has("senza-vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_inizio_ms = Time.get_ticks_msec()
	_prove.call_deferred()


func _prove() -> void:
	if _opzioni.has("sequenza") and _opzioni.has("schermata"):
		var base: String = _opzioni["schermata"]
		var n := 0
		for ist: Array in istanti_sequenza():
			n += 1
			hold = ist[1]
			for i in 4:   # qualche fotogramma: clip e telecamera al loro posto
				await get_tree().process_frame
			await _salva(base.get_basename() + "_%02d_%s.png" % [n, ist[0]])
		Uscita.esci(get_tree(), 0)   # toglie la scena e lascia le risorse grafiche prima di uscire
	elif _opzioni.has("schermata"):
		await get_tree().create_timer(float(_opzioni.get("dopo", "2"))).timeout
		await _salva(_opzioni["schermata"])
		Uscita.esci(get_tree(), 0)   # toglie la scena e lascia le risorse grafiche prima di uscire
	elif _opzioni.has("esci-dopo"):
		await get_tree().create_timer(float(_opzioni["esci-dopo"])).timeout
		var secondi := maxf(0.001, (Time.get_ticks_msec() - _inizio_ms) / 1000.0)
		print("FPS medi %.1f · %s" % [_fotogrammi / secondi, HudFase1.testo_memoria()])
		Uscita.esci(get_tree(), 0)   # toglie la scena e lascia le risorse grafiche prima di uscire


## istanti da fotografare: [nome, tempo della sequenza]
static func istanti_sequenza() -> Array:
	var m := Routine.moves()
	var j := Routine.juggle_time()
	var out: Array = [["palleggio_suola", 0.5], ["palleggio_collo", 2.2], ["palleggio_coscia", 0.0], ["palleggio_testa", 0.0]]
	# tocchi dei palleggi: il primo di coscia e quello di testa
	for tc: Dictionary in (m.juggle as Object).touches:
		if tc.part == "r.thigh" and out[2][1] == 0.0:
			out[2][1] = tc.t
		elif tc.part == "head":
			out[3][1] = tc.t
	var t0 := 0.0
	for k in Giochetti.TRICKS.size():
		var tr: Object = m.tricks[k]
		out.append(["giochetto_%s" % Giochetti.TRICKS[k].id, t0 + j + tr.T * 0.45])
		if k == 0:
			var corsa: float = t0 + j + float(tr.T)
			out.append(["corsa", corsa + Routine.RUN_T * 0.5])
			out.append(["tiro_carica", corsa + Routine.RUN_T + 0.4])
			out.append(["tiro", corsa + Routine.RUN_T + Tiro.T_HIT + 0.03])
			out.append(["pallone_nuovo", corsa + Routine.RUN_T + (m.shot as Object).T + 0.9])
		t0 += Routine.cycle_length(k)
	return out


func _salva(percorso: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if percorso.is_relative_path(): # relativo alla cartella del repo (quella che contiene godot/)
		percorso = ProjectSettings.globalize_path("res://").path_join("..").path_join(percorso).simplify_path()
	DirAccess.make_dir_recursive_absolute(percorso.get_base_dir())
	var err := img.save_png(percorso)
	print("schermata %s %dx%d errore=%d" % [percorso, img.get_width(), img.get_height(), err])
