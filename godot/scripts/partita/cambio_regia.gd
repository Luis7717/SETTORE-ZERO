# Scena del cambio (Luis 2026-11-24: "per i cambi fai una piccola animazione in cui il giocatore esce e entra quello
# dopo"). Dopo la Rosa e tattica della pausa, a "Riprendi" / "Secondo tempo": DURATA s veri col tempo di partita
# fermo; chi esce cammina verso la linea laterale a centrocampo (zona panchine), chi entra corre da lì al suo posto;
# targhette sopra la testa (▲ numero verde chi entra, ▼ rosso chi esce) e in basso il riquadro "CAMBIO" con ENTRA /
# ESCE, numero e nome. Più cambi insieme, ognuno col suo punto sulla linea. Un tocco la salta. Telecamera ferma dal
# lato opposto alle panchine, in alto, alla distanza più vicina che inquadra tutti i percorsi (_distanza).
# Chi entra è il giocatore vero del motore (figura già rifatta dalla vista col nuovo src): lo si muove qui e alla fine
# torna esattamente dov'era. Chi esce è una figura in più (Figura della vista, senza numero sulla schiena) che sparisce
# alla fine. Gli altri restano fermi (velocità azzerata durante la scena e poi rimessa). Solo grafica: il motore non
# fa passi e alla fine è identico a prima.
extends Node

signal finita

const R := preload("res://sim/records.gd")
const Coord := preload("res://scripts/coord.gd")

const DURATA := 3.4            # s veri della scena
const V_CORSA := 7.0           # m/s: chi entra corre (se il posto è più lontano parte già un po' dentro il campo)
const ESCE_DA_M := 7.5         # m: chi esce parte al massimo da tanti metri dalla linea e cammina fin oltre
const OLTRE_LINEA := 1.5       # m oltre la linea laterale: punto delle panchine
const ESCE_OLTRE := 2.5        # m: chi esce finisce ancora più in là della panchina
const PASSO_Y := 5.0           # m tra i punti di due cambi lungo la linea
const PARTENZA := 0.25         # s: prima di muoversi
const CAM_DIR := Vector3(0.75, 0.95, 0.12)   # telecamera: dal lato opposto alle panchine, in alto, guarda verso la linea
const CAM_FUORI_MAX := 4.0     # m oltre la linea laterale: più in là ci sono le tribune ...
const CAM_SOPRA_TRIBUNE := 24.0  # ... e la telecamera sta almeno così in alto
const CAM_ALTA_MIN := 16.0     # m: altezza minima della telecamera
const LOOK_DENTRO := 4.0       # m: il punto guardato sta almeno tanto dentro il campo
const CAM_DIST_MIN := 22.0
const CAM_BORDO_PX := 24.0     # px: la scena sta almeno così dentro i bordi dello schermo ...
const CAM_SOPRA_PX := 70.0     # ... sotto il punteggio in alto ...
const CAM_SOTTO_SCRITTA := 12.0  # ... e tanti px sopra la scritta CAMBIO in basso
const CAM_PASSO := 1.06        # la distanza cresce di tanto finché tutto è dentro
const CAM_DIST_MAX := 110.0
const FOV := 58.0
const ENTRA := Color("#4aeb9f")
const ESCE := Color("#ff6b6b")
const TARGHETTA_H := 2.7       # m: altezza della targhetta col numero sopra la testa
const PANNELLO_GIU := 40.0     # px sopra il bordo basso: la scritta CAMBIO sta in basso (la linea delle panchine è in alto)

var attiva := false
var t := 0.0
var _m: Object = null
var _me := 0
var _vista: Node = null
var _coppie: Array = []        # [{p, da, a, finto, fig, eda, ea}] (coordinate di gioco, Vector2)
var _salvati: Array = []       # [p, x, y, vx, vy, sprint] di tutti i giocatori
var _cam_dist := CAM_DIST_MIN
var _sopra_scritta := 844.0    # px: bordo alto della scritta CAMBIO
var _layer: CanvasLayer = null
var _targhette: Array = []     # [Label chi entra, Label chi esce] per ogni coppia


## punto della panchina (coordinate di gioco) per il cambio k di n: oltre la linea laterale che sta a sinistra dello
## schermo (x mondo negativa), a centrocampo
static func punto_panchina(k: int, n: int, flip: float) -> Vector2:
	var y := (float(k) - (n - 1) / 2.0) * PASSO_Y
	return Vector2(-(Coord.HW + OLTRE_LINEA) * flip, y * flip)


## da dove parte chi corre verso `a` dalla panchina `da` in `durata` s a velocità v (se è troppo lontano, più avanti)
static func partenza(da: Vector2, a: Vector2, v: float, durata: float) -> Vector2:
	var d := da.distance_to(a)
	var max_d := v * durata
	return da if d <= max_d else a + (da - a).normalized() * max_d


## parte la scena per i cambi `cambi` (quelli di CambiPartita.applica / SimMatch.cambiaSquadra). false = niente da fare
func avvia(m: Object, me: int, vista: Node, cambi: Array) -> bool:
	if cambi.is_empty() or m == null or vista == null:
		return false
	_m = m
	_me = me
	_vista = vista
	t = 0.0
	_coppie = []
	_salvati = []
	for p: Object in m.players:
		_salvati.append([p, p.x, p.y, p.vx, p.vy, p.sprint])
		p.vx = 0.0
		p.vy = 0.0
		p.sprint = false
	var flip: float = vista.get("flip") if vista.get("flip") != null else 1.0
	var n := cambi.size()
	for k in n:
		var c: Dictionary = cambi[k]
		var p: Object = c.p
		var a := Vector2(p.x, p.y)
		var panca := punto_panchina(k, n, flip)
		var fuori := panca + Vector2(-ESCE_OLTRE * flip, 0.0)
		var eda := fuori + (a - fuori).limit_length(ESCE_DA_M) # chi esce: già vicino alla linea
		var finto := R.Player.new()
		finto.team = p.team
		finto.i = p.i
		finto.src = c.get("fuoriSrc", {})
		finto.name = String(c.get("fuori", ""))
		finto.pos = String(c.get("fuoriPos", p.pos))
		finto.x = eda.x
		finto.y = eda.y
		var fig: Node3D = vista._figura(finto) if vista.has_method("_figura") else null
		_coppie.append({"p": p, "da": partenza(panca, a, V_CORSA, DURATA - PARTENZA), "a": a, "finto": finto, "fig": fig,
			"eda": eda, "ea": fuori})
	_crea_scritta(cambi)
	vista.set("replay", true) # la telecamera la muove la scena (come il replay del gol)
	_cam_dist = _distanza() # telecamera ferma: tutta la scena inquadrata
	attiva = true
	_metti(0.0)
	return true


## un fotogramma della scena (dt = s veri)
func fotogramma(dt: float) -> void:
	if not attiva:
		return
	t += dt
	_metti(dt)
	if t >= DURATA:
		_chiudi()


## tocco: salta alla fine
func salta() -> void:
	if not attiva:
		return
	t = DURATA
	_metti(0.0)
	_chiudi()


# posizioni al tempo t: chi entra corre (motore), chi esce cammina (figura in più); poi vista e telecamera
func _metti(dt: float) -> void:
	var q := clampf((t - PARTENZA) / (DURATA - PARTENZA), 0.0, 1.0)
	for c: Dictionary in _coppie:
		var p: Object = c.p
		var prima := Vector2(p.x, p.y)
		var ora: Vector2 = (c.da as Vector2).lerp(c.a, q)
		_muovi(p, prima, ora, dt, c.a - c.da)
		var f: Object = c.finto
		var fp := Vector2(f.x, f.y)
		var fo: Vector2 = (c.eda as Vector2).lerp(c.ea, q)
		_muovi(f, fp, fo, dt, c.ea - c.eda)
		_posa_finto(c, dt)
	_vista.update_view(dt, dt)
	_telecamera(dt)
	_metti_targhette()


# targhetta col numero sopra chi entra (verde) e chi esce (rosso)
func _metti_targhette() -> void:
	for k in mini(_targhette.size(), _coppie.size()):
		var c: Dictionary = _coppie[k]
		for j in 2:
			var l: Label = _targhette[k][j]
			var p: Object = c.p if j == 0 else c.finto
			var sp: Vector3 = _vista.world_to_screen(p.x, p.y, TARGHETTA_H)
			l.visible = sp.z > 0.5
			l.reset_size()
			l.position = Vector2(sp.x, sp.y) - Vector2(l.size.x / 2.0, l.size.y)


static func _muovi(p: Object, prima: Vector2, ora: Vector2, dt: float, verso: Vector2) -> void:
	p.x = ora.x
	p.y = ora.y
	if dt > 0.0:
		p.vx = (ora.x - prima.x) / dt
		p.vy = (ora.y - prima.y) / dt
	var v := verso.normalized()
	if v != Vector2.ZERO:
		p.fx = v.x
		p.fy = v.y


func _posa_finto(c: Dictionary, dt: float) -> void:
	var f: Node3D = c.fig
	if f == null or not is_instance_valid(f):
		return
	var p: Object = c.finto
	var s: float = _vista.get("flip") if _vista.get("flip") != null else 1.0
	var yaw := atan2(s * p.fx, -s * p.fy)
	f.position = Vector3(s * p.x, 0.0, -s * p.y)
	f.rotation = Vector3(0.0, yaw, 0.0)
	f.posa(p, dt, {"t": t, "phase": _m.phase, "flip": s, "yaw": yaw, "ball": _m.ball, "trick": null, "coreo": null, "m": _m})


# punti di tutti i percorsi (partenze e arrivi di chi entra e chi esce, coordinate di gioco)
func _punti() -> Array:
	var out: Array = []
	for c: Dictionary in _coppie:
		out.append_array([c.da, c.a, c.eda, c.ea])
	return out


# punto guardato: in mezzo a tutti i percorsi (fisso: la telecamera non insegue, si vede tutta la scena)
func _centro() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for v: Vector2 in _punti():
		lo = lo.min(v)
		hi = hi.max(v)
	return _mondo((lo + hi) / 2.0)


func _mondo(g: Vector2) -> Vector3:
	var s: float = _vista.get("flip") if _vista.get("flip") != null else 1.0
	return Vector3(s * g.x, 0.0, -s * g.y)


# posa della telecamera a distanza d dal punto guardato: [pos, guarda]
func _posa_a(d: float) -> Array:
	var guarda := _centro()
	guarda.x = maxf(guarda.x, -Coord.HW + LOOK_DENTRO)
	var pos := guarda + CAM_DIR.normalized() * d
	if absf(pos.x) > Coord.HW + CAM_FUORI_MAX: # sopra le tribune: abbastanza in alto
		pos.y = maxf(pos.y, CAM_SOPRA_TRIBUNE)
	pos.y = maxf(pos.y, CAM_ALTA_MIN)
	return [pos, guarda]


# distanza della telecamera: la più vicina con tutti i percorsi (piedi e testa) dentro lo schermo, sotto la scritta
func _distanza() -> float:
	var cam: Camera3D = _vista.get("cam")
	var vis := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(390, 844)
	var sotto := _sopra_scritta - CAM_SOTTO_SCRITTA
	var dentro := Rect2(CAM_BORDO_PX, CAM_SOPRA_PX, vis.x - 2.0 * CAM_BORDO_PX, sotto - CAM_SOPRA_PX)
	var d := CAM_DIST_MIN
	if cam == null:
		return d
	var prima := cam.global_transform
	var fov0 := cam.fov
	cam.fov = FOV
	while d < CAM_DIST_MAX:
		var pg := _posa_a(d)
		cam.look_at_from_position(pg[0], pg[1], Vector3.UP)
		var ok := true
		for v: Vector2 in _punti():
			for h: float in [0.0, 2.0]:
				var w := _mondo(v) + Vector3(0.0, h, 0.0)
				if cam.is_position_behind(w) or not dentro.has_point(cam.unproject_position(w)):
					ok = false
		if ok:
			break
		d *= CAM_PASSO
	cam.global_transform = prima
	cam.fov = fov0
	return minf(d, CAM_DIST_MAX)


func _telecamera(_dt: float) -> void:
	var cam: Camera3D = _vista.get("cam")
	if cam == null:
		return
	var pg := _posa_a(_cam_dist)
	cam.fov = FOV
	cam.look_at_from_position(pg[0], pg[1], Vector3.UP)


func _chiudi() -> void:
	attiva = false
	var entrati := {}
	for c: Dictionary in _coppie:
		entrati[c.p] = c.a
		if c.fig != null and is_instance_valid(c.fig):
			c.fig.queue_free()
	for v: Array in _salvati:
		var p: Object = v[0]
		if entrati.has(p): # chi entra resta al suo posto, fermo
			p.x = entrati[p].x
			p.y = entrati[p].y
			p.vx = 0.0
			p.vy = 0.0
			continue
		p.x = v[1]
		p.y = v[2]
		p.vx = v[3]
		p.vy = v[4]
		p.sprint = v[5]
	_coppie = []
	_salvati = []
	if _vista != null:
		_vista.set("replay", false)
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_targhette = []
	finita.emit()


# ---------------------------------------------------------------- scritta "CAMBIO"
func _crea_scritta(cambi: Array) -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.7
	var pann := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.039, 0.063, 0.125, 0.88)
	st.set_corner_radius_all(16)
	st.border_color = Color(1, 1, 1, 0.16)
	st.set_border_width_all(1)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 10
	st.content_margin_bottom = 12
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 8
	pann.add_theme_stylebox_override("panel", st)
	pann.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pann.add_child(v)
	v.add_child(_etichetta("CAMBIO" if cambi.size() == 1 else "CAMBI", 26, Color("#ffe14a"), font, HORIZONTAL_ALIGNMENT_CENTER))
	for c: Dictionary in cambi:
		var dentro: Dictionary = c.p.src if c.p.src is Dictionary else {}
		var fuori: Dictionary = c.get("fuoriSrc", {})
		v.add_child(_riga("ENTRA", dentro, String(c.p.name), ENTRA, font))
		v.add_child(_riga("ESCE", fuori, String(c.get("fuori", "")), ESCE, font))
	_layer.add_child(pann)
	var vis := get_viewport().get_visible_rect().size
	pann.reset_size()
	pann.size.x = minf(vis.x - 32.0, maxf(pann.get_combined_minimum_size().x, 250.0))
	var alto_pann := pann.get_combined_minimum_size().y
	pann.position = Vector2((vis.x - pann.size.x) / 2.0, vis.y - PANNELLO_GIU - _sicura_basso() - alto_pann)
	_sopra_scritta = pann.position.y
	_targhette = []
	for c: Dictionary in cambi:
		var coppia: Array = []
		for j in 2:
			var src: Dictionary = (c.p.src if c.p.src is Dictionary else {}) if j == 0 else c.get("fuoriSrc", {})
			var num: Variant = src.get("num")
			var l := _etichetta(("▲ %d" if j == 0 else "▼ %d") % int(num) if num != null else ("▲" if j == 0 else "▼"), 17,
				Color.WHITE, font, HORIZONTAL_ALIGNMENT_CENTER)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(ENTRA if j == 0 else ESCE, 0.92).darkened(0.25)
			sb.set_corner_radius_all(8)
			sb.content_margin_left = 7
			sb.content_margin_right = 7
			sb.content_margin_top = 1
			sb.content_margin_bottom = 2
			l.add_theme_stylebox_override("normal", sb)
			_layer.add_child(l)
			coppia.append(l)
		_targhette.append(coppia)
	pann.modulate.a = 0.0
	pann.create_tween().tween_property(pann, "modulate:a", 1.0, 0.2)


func _sicura_basso() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var vis := get_viewport().get_visible_rect().size
	var schermo := Vector2(DisplayServer.screen_get_size())
	if schermo.y <= 0.0:
		return 0.0
	var sa := DisplayServer.get_display_safe_area()
	return (schermo.y - sa.end.y) * vis.y / schermo.y


func _riga(cosa: String, src: Dictionary, nome: String, colore: Color, font: Font) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var c := _etichetta(cosa, 15, colore, font, HORIZONTAL_ALIGNMENT_LEFT)
	c.custom_minimum_size.x = 62
	h.add_child(c)
	var num: Variant = src.get("num")
	var testo := ("%d  %s" % [int(num), nome]) if num != null else nome
	var l := _etichetta(testo, 18, Color.WHITE.lerp(colore, 0.35), font, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	return h


static func _etichetta(testo: String, dim: int, colore: Color, font: Font, al: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = testo
	l.horizontal_alignment = al
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	return l


## testi della scritta (per le prove): ["CAMBIO", "ENTRA ...", ...]
func testi() -> Array:
	var out: Array = []
	if _layer == null or not is_instance_valid(_layer):
		return out
	for l: Node in _layer.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out
