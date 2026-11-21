# Meteo e ora del giorno della partita (PIANO.md fase C, punto 10).
#
# Scelta (funzioni statiche, niente grafica):
#   scegli(seme, giornata)      → {"meteo": "sereno"|"nuvoloso"|"pioggia"|"neve", "ora": "giorno"|"tramonto"|"notte"}
#                                 a caso ma col seme (SimRng, niente randi): stesso seme = stesso meteo;
#                                 con la giornata di campionato la probabilità segue la stagione (più pioggia e neve
#                                 d'inverno), senza giornata è fissa (neve al 5%).
#   per_giornata(seme_carriera, stagione, giornata)   previsione della prossima partita di campionato (hub e partita)
#   per_partita(avvio, opzioni, seme)                 quella da usare in partita: --meteo/--ora (prove) > avvio > seme
#   testo(scelta)               "Notte · Pioggia" (intro della partita, hub)
#
# Grafica (nodo, figlio della scena della partita): applica(vista, scelta) cambia cielo, luce, nebbia, erba
# (uniform bagnato/neve di shaders/erba.gdshader), lampade delle torri faro, colore del pallone sulla neve, e aggiunge
# pioggia o neve (GPUParticles3D leggere che seguono la telecamera; nel rallenty cadono più piano).
# Di notte niente luci in più (le ombre multiple costano sull'iPhone): la luce principale diventa quella dei fari,
# alta e bianca, con ambiente bluastro e un alone finto sulle lampade.
#
# Il motore riceve solo il meteo (campo "meteo" delle opzioni di SimMatch: pioggia e neve cambiano la fisica,
# vedi weatherFx in sim/match.gd); l'ora è solo grafica.
extends Node3D

const SimRngScript := preload("res://sim/rng.gd")

const METEO := ["sereno", "nuvoloso", "pioggia", "neve"]
const ORE := ["giorno", "tramonto", "notte"]
const NOMI_METEO := {"sereno": "Sereno", "nuvoloso": "Nuvoloso", "pioggia": "Pioggia", "neve": "Neve"}
const NOMI_ORA := {"giorno": "Pomeriggio", "tramonto": "Tramonto", "notte": "Notte"}
const SALE := 0x6d657465          # seme del meteo diverso da quello della partita (stesso seme, numeri diversi)
const GIORNATE := 18              # giornate di un campionato (come hub.gd)
# probabilità (su 100) di [sereno, nuvoloso, pioggia, neve]: il campionato va da fine estate a primavera
const PROB_ESTATE := [58, 28, 14, 0]     # prime e ultime giornate
const PROB_MEZZA := [44, 30, 22, 4]      # autunno e inizio primavera
const PROB_INVERNO := [30, 30, 28, 12]   # giornate in mezzo (inverno)
const PROB_FISSA := [45, 30, 20, 5]      # senza giornata (amichevole): neve rara
const PROB_ORA := [45, 25, 30]           # [giorno, tramonto, notte]

# ---------------------------------------------------------------- grafica: tabelle
# ora del giorno: luce principale (sole o fari), cielo, ambiente
# di giorno la direzione del sole resta quella di vista.gd (_ready)
const ORA_GIORNO := {"luce": Color(1.0, 0.92, 0.8), "energia": 1.2,
	"cielo": Color(0.25, 0.45, 0.8), "orizzonte": Color(0.7, 0.79, 0.9), "terra": Color(0.18, 0.22, 0.18),
	"ambiente": 0.6, "nebbia": Color(0.62, 0.7, 0.82), "pubblico": 1.0}
const ORA_TRAMONTO := {"elev": 13.0, "az": 255.0, "luce": Color(1.0, 0.7, 0.46), "energia": 1.3,
	"cielo": Color(0.2, 0.27, 0.52), "orizzonte": Color(0.98, 0.6, 0.36), "terra": Color(0.16, 0.14, 0.14),
	"ambiente": 0.5, "nebbia": Color(0.85, 0.6, 0.45), "pubblico": 0.8}
const ORA_NOTTE := {"elev": 62.0, "az": 200.0, "luce": Color(0.94, 0.97, 1.0), "energia": 0.95,
	"cielo": Color(0.02, 0.035, 0.08), "orizzonte": Color(0.09, 0.12, 0.2), "terra": Color(0.03, 0.035, 0.04),
	"ambiente": 0.55, "nebbia": Color(0.08, 0.1, 0.16), "pubblico": 0.5}
# di notte l'ambiente viene da un colore (il cielo è nero): blu tenue, così i giocatori in ombra si leggono
const NOTTE_AMBIENTE := Color(0.42, 0.48, 0.62)
const NOTTE_LAMPADE := 7.0         # forza delle lampade delle torri (di giorno 3, stadio.gd)
const STRATO_STADIO := 1 << 19     # di notte lo stadio sta su questo strato e la luce dei fari non lo illumina
                                   # (prende solo l'ambiente: tribune scure, campo illuminato)
const ALONE_M := 16.0              # alone finto attorno a ogni pannello di lampade (m)
# meteo: quanto si copre il cielo (colore e quanto), luce, ombre, nebbia, erba, particelle
const METEO_FX := {
	"sereno": {"pubblico": 1.0, "coperto": 0.0, "grigio": Color(0.6, 0.64, 0.7), "luce": 1.0, "ombre": 1.0, "nebbia": 0.0012, "bagnato": 0.0, "neve": 0.0},
	"nuvoloso": {"pubblico": 0.86, "coperto": 0.75, "grigio": Color(0.58, 0.62, 0.68), "luce": 0.62, "ombre": 0.5, "nebbia": 0.002, "bagnato": 0.0, "neve": 0.0},
	"pioggia": {"pubblico": 0.75, "coperto": 0.9, "grigio": Color(0.4, 0.44, 0.5), "luce": 0.5, "ombre": 0.38, "nebbia": 0.0055, "bagnato": 1.0, "neve": 0.0},
	"neve": {"pubblico": 0.9, "coperto": 0.85, "grigio": Color(0.78, 0.81, 0.86), "luce": 0.72, "ombre": 0.45, "nebbia": 0.0022, "bagnato": 0.0, "neve": 0.55},
}
const PUBBLICO_LUCE := 0.92        # luce del pubblico 3D di giorno col sereno (uniform luce di shaders/pubblico.gdshader)
const PALLONE_NEVE := Color(1.0, 0.5, 0.12)   # pallone arancione sulla neve (si vede sul bianco)
# particelle: attorno alla telecamera, un po' davanti
const PIOGGIA_N := 900
const PIOGGIA_V := 19.0            # m/s
const NEVE_N := 700
const NEVE_V := 1.6
const SCATOLA := Vector3(16.0, 9.0, 16.0)  # metà dei lati della scatola dove nascono (m)
const AVANTI := 9.0                # centro della scatola davanti alla telecamera (m)
const RALLENTY_MIN := 0.12         # nel rallenty le gocce rallentano, ma non si fermano del tutto

var scelta := {"meteo": "sereno", "ora": "giorno"}
var _cam: Camera3D = null
var _gocce: GPUParticles3D = null


# ---------------------------------------------------------------- scelta
## meteo e ora a caso col seme; giornata 1..GIORNATE = campionato (probabilità della stagione), 0 = fissa
static func scegli(seme: int, giornata: int = 0) -> Dictionary:
	var r := SimRngScript.new(seme ^ SALE)
	var m := _pesca(r.next(), probabilita(giornata))
	var o := _pesca(r.next(), PROB_ORA)
	return {"meteo": METEO[m], "ora": ORE[o]}


## probabilità [sereno, nuvoloso, pioggia, neve] per la giornata (0 = senza giornata)
static func probabilita(giornata: int) -> Array:
	if giornata <= 0:
		return PROB_FISSA
	var f := clampf(float(giornata - 1) / float(GIORNATE - 1), 0.0, 1.0)
	if f < 0.15 or f > 0.85:
		return PROB_ESTATE
	if f >= 0.35 and f <= 0.65:
		return PROB_INVERNO
	return PROB_MEZZA


## previsione della partita di campionato: dipende da carriera, stagione e giornata (la stessa nell'hub e in partita)
static func per_giornata(seme_carriera: int, stagione: int, giornata: int) -> Dictionary:
	return scegli(seme_carriera * 31 + stagione * 977 + giornata * 7919, giornata)


## per la partita: --meteo/--ora da riga di comando (prove) vincono, poi avvio.meteo/avvio.ora (l'app, campionato),
## poi a caso col seme della partita; l'allenamento è sempre sereno di giorno
static func per_partita(avvio: Dictionary, opzioni: Dictionary, seme: int, allenamento := false) -> Dictionary:
	var s := {"meteo": "sereno", "ora": "giorno"} if allenamento else scegli(seme)
	for k: String in ["meteo", "ora"]:
		var lista: Array = METEO if k == "meteo" else ORE
		if avvio.has(k) and String(avvio[k]) in lista:
			s[k] = String(avvio[k])
		if opzioni.has(k):
			if String(opzioni[k]) in lista:
				s[k] = String(opzioni[k])
			else:
				push_warning("meteo: --%s=%s sconosciuto (%s)" % [k, opzioni[k], "|".join(lista)])
	return s


static func testo(s: Dictionary) -> String:
	return "%s · %s" % [NOMI_ORA.get(s.get("ora", ""), "Pomeriggio"), NOMI_METEO.get(s.get("meteo", ""), "Sereno")]


static func _pesca(x: float, pesi: Array) -> int:
	var tot := 0
	for p: int in pesi:
		tot += p
	var v := x * tot
	for i in pesi.size():
		v -= pesi[i]
		if v < 0.0:
			return i
	return pesi.size() - 1


# ---------------------------------------------------------------- grafica
## cambia la vista della partita (scenes/vista_partita.tscn) per il meteo e l'ora scelti
func applica(vista: Node3D, s: Dictionary) -> void:
	scelta = s.duplicate()
	var ora: Dictionary = {"tramonto": ORA_TRAMONTO, "notte": ORA_NOTTE}.get(s.ora, ORA_GIORNO)
	var fx: Dictionary = METEO_FX.get(s.meteo, METEO_FX.sereno)
	var notte: bool = s.ora == "notte"
	_luce(vista.get_node_or_null("Sole") as DirectionalLight3D, ora, fx, notte)
	var amb := vista.get_node_or_null("Ambiente") as WorldEnvironment
	if amb != null and amb.environment != null:
		_ambiente(amb.environment, ora, fx, notte)
	var campo := vista.get_node_or_null("Campo")
	if campo != null and campo.has_method("set_meteo"):
		campo.set_meteo(fx.bagnato, fx.neve)
	var stadio := vista.get_node_or_null("Stadio")
	_stadio(stadio, notte)
	_pubblico(stadio, PUBBLICO_LUCE * float(ora.pubblico) * float(fx.pubblico))
	if notte and stadio != null:
		_strato_scuro(stadio, [stadio.get("cartelloni"), stadio.get("maxischermo")])
		var sole := vista.get_node_or_null("Sole") as DirectionalLight3D
		if sole != null:
			sole.light_cull_mask = sole.light_cull_mask & ~STRATO_STADIO
	var palla := vista.get_node_or_null("Pallone") as MeshInstance3D
	if palla != null and palla.material_override is StandardMaterial3D:
		(palla.material_override as StandardMaterial3D).albedo_color = PALLONE_NEVE if s.meteo == "neve" else Color.WHITE
	_cam = vista.get_node_or_null("Telecamera") as Camera3D
	if s.meteo == "pioggia":
		_gocce = _particelle_pioggia()
	elif s.meteo == "neve":
		_gocce = _particelle_neve()
	if _gocce != null:
		add_child(_gocce)
		_segui()


func _luce(sole: DirectionalLight3D, ora: Dictionary, fx: Dictionary, notte: bool) -> void:
	if sole == null:
		return
	if ora.has("elev"):
		var el := deg_to_rad(float(ora.elev))
		var az := deg_to_rad(float(ora.az))
		var dir := Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
		sole.look_at_from_position(dir * 60.0, Vector3.ZERO, Vector3.UP)
	sole.light_color = ora.luce
	# i fari non si coprono con le nuvole: di notte il meteo toglie meno luce
	var k: float = lerpf(float(fx.luce), 1.0, 0.6) if notte else float(fx.luce)
	sole.light_energy = float(ora.energia) * k
	sole.shadow_opacity = lerpf(float(fx.ombre), 1.0, 0.5) if notte else float(fx.ombre)
	# disco del sole nel cielo solo col sereno di giorno o al tramonto
	sole.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY if (not notte and float(fx.coperto) < 0.5) else DirectionalLight3D.SKY_MODE_LIGHT_ONLY


func _ambiente(env: Environment, ora: Dictionary, fx: Dictionary, notte: bool) -> void:
	var cop := float(fx.coperto)
	# il grigio delle nuvole prende la luce dell'ora (di notte quasi nero, al tramonto caldo)
	var scuro: float = 0.14 if notte else (0.75 if ora == ORA_TRAMONTO else 1.0)
	var grigio: Color = (fx.grigio as Color) * scuro
	if ora == ORA_TRAMONTO:
		grigio = grigio.lerp(Color(0.75, 0.5, 0.42), 0.35)
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = (ora.cielo as Color).lerp(grigio * 0.85, cop)
	cielo.sky_horizon_color = (ora.orizzonte as Color).lerp(grigio, cop)
	cielo.ground_bottom_color = ora.terra
	cielo.ground_horizon_color = cielo.sky_horizon_color
	cielo.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = cielo
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	if notte:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = NOTTE_AMBIENTE
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(ora.ambiente) * (1.0 + 0.35 * cop)
	env.fog_enabled = true
	env.fog_light_color = (ora.nebbia as Color).lerp(grigio, cop)
	env.fog_density = float(fx.nebbia)


# di notte le lampade delle torri si accendono forte, con un alone finto (niente luci vere in più)
func _stadio(stadio: Node, notte: bool) -> void:
	if stadio == null or not notte:
		return
	for c in stadio.get_children():
		if not (c is MeshInstance3D and String(c.name).begins_with("FaroLampade")):
			continue
		var mi := c as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			(mi.material_override as StandardMaterial3D).emission_energy_multiplier = NOTTE_LAMPADE
		var alone := MeshInstance3D.new()
		alone.name = "Alone"
		var q := QuadMesh.new()
		q.size = Vector2(ALONE_M, ALONE_M)
		alone.mesh = q
		alone.material_override = _materiale_alone()
		alone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		alone.position = mi.position
		add_child(alone)


var _mat_alone: StandardMaterial3D = null


# il pubblico 3D non riceve luci vere: la sua luce è un uniform del materiale (uno solo per tutte le tribune)
static func _pubblico(stadio: Node, luce: float) -> void:
	var pub: Variant = stadio.get("pubblico") if stadio != null else null
	if not pub is Node:
		return
	for c in (pub as Node).get_children():
		if c is GeometryInstance3D and (c as GeometryInstance3D).material_override is ShaderMaterial:
			((c as GeometryInstance3D).material_override as ShaderMaterial).set_shader_parameter("luce", luce)


# mette sullo strato scuro tutto lo stadio tranne i cartelloni e i maxischermi (schermi accesi: restano illuminati)
static func _strato_scuro(n: Node, salta: Array) -> void:
	if n in salta:
		return
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = STRATO_STADIO
	for c in n.get_children():
		_strato_scuro(c, salta)


func _materiale_alone() -> StandardMaterial3D:
	if _mat_alone != null:
		return _mat_alone
	_mat_alone = StandardMaterial3D.new()
	_mat_alone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_alone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_alone.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_alone.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat_alone.albedo_texture = _tondo(64, 2.2)
	_mat_alone.albedo_color = Color(1.0, 0.96, 0.85, 0.55)
	_mat_alone.disable_fog = true
	return _mat_alone


# ---------------------------------------------------------------- pioggia e neve
func _particelle(n: int, durata: float, mesh: Mesh, pm: ParticleProcessMaterial) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.name = "Precipitazione"
	g.amount = n
	g.lifetime = durata
	g.preprocess = durata
	g.local_coords = true
	g.draw_pass_1 = mesh
	g.process_material = pm
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(-SCATOLA * 1.6, SCATOLA * 3.2)
	return g


func _scatola(pm: ParticleProcessMaterial) -> void:
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = SCATOLA
	pm.direction = Vector3(0.0, -1.0, 0.0)


func _particelle_pioggia() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	_scatola(pm)
	pm.direction = Vector3(0.08, -1.0, 0.03) # un filo di vento
	pm.spread = 2.0
	pm.initial_velocity_min = PIOGGIA_V * 0.9
	pm.initial_velocity_max = PIOGGIA_V * 1.1
	pm.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_texture = _riga(8, 32)
	mat.albedo_color = Color(0.82, 0.87, 0.95, 0.42)
	mat.disable_fog = true
	q.material = mat
	return _particelle(PIOGGIA_N, SCATOLA.y * 2.0 / PIOGGIA_V, q, pm)


func _particelle_neve() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	_scatola(pm)
	pm.direction = Vector3(0.25, -1.0, 0.1)
	pm.spread = 30.0
	pm.initial_velocity_min = NEVE_V * 0.6
	pm.initial_velocity_max = NEVE_V * 1.3
	pm.gravity = Vector3(0.0, -0.15, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _tondo(32, 1.6)
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	mat.disable_fog = true
	q.material = mat
	return _particelle(NEVE_N, SCATOLA.y * 2.0 / NEVE_V, q, pm)


func _process(_delta: float) -> void:
	if _gocce == null:
		return
	_segui()
	# rallenty: il gioco (gioco.gd, genitore) tiene la velocità del tempo in `ts`
	var g := get_parent()
	if g != null and "ts" in g:
		_gocce.speed_scale = clampf(float(g.ts), RALLENTY_MIN, 1.0)


# la scatola delle gocce segue la telecamera (solo la posizione: le gocce cadono sempre in verticale)
func _segui() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var avanti := -_cam.global_transform.basis.z
	avanti.y = 0.0
	if avanti.length() > 0.01:
		avanti = avanti.normalized()
	_gocce.global_position = _cam.global_position + avanti * AVANTI


# ---------------------------------------------------------------- texture piccole disegnate a codice
# goccia: riga verticale che sfuma in alto e in basso
static func _riga(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var a := sin(PI * (y + 0.5) / h)
		for x in w:
			var b := 1.0 - absf((x + 0.5) / w * 2.0 - 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * b))
	return ImageTexture.create_from_image(img)


# tondo morbido (fiocco di neve, alone): `duro` = quanto in fretta sfuma verso il bordo
static func _tondo(n: int, duro: float) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), duro)))
	return ImageTexture.create_from_image(img)
