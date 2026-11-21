# Carta di un giocatore nella Rosa (card() di src/ui-squad.js, .fc del web): valutazione nel ruolo del posto,
# ruolo, ritratto, nome breve; fuori ruolo = ruolo vero in arancio a sinistra, a destra quanto cambia la squadra
# scambiandola col giocatore scelto (verde/rosso). Bordo per fascia di valutazione; scelta = gialla, confronto =
# bianca che pulsa, appena scambiata = lampo giallo che si spegne. Stato fisico (solo Godot, fisico()): croce rossa
# sugli infortunati e barretta della forma in basso quando non è piena (verde, gialla, rossa).
# Disegnata tutta in _draw (un nodo per carta: la Rosa ne ha fino a 24 e si ridisegna a ogni tocco).
# Un tocco (dito giù e su senza spostarsi) manda `toccata`; trascinando, il movimento passa a chi sta sotto
# (la panchina scorre di lato).
class_name MenuCarta
extends Control

const T := preload("res://scripts/menu/tema_menu.gd")
const D := preload("res://scripts/menu/menu_dati.gd")

signal toccata(id: Variant)

const W := 64.0
const H := 70.0
const TOCCO_MAX := 10.0          # px: oltre è un trascinamento, non un tocco
const BORDO := {"o1": Color(0.718, 0.761, 0.839, 0.31), "o2": Color(0.561, 0.827, 1.0, 0.55), "o3": Color(0.29, 0.922, 0.624, 0.61), "o4": Color("#ffd93d")}
const FONDO_A := Color("#1b2b49")
const FONDO_B := Color("#101b30")
const FONDO_O4_A := Color("#2a2c34")
const FONDO_O4_B := Color("#16171d")
const FONDO_SEL_A := Color("#2c3f66")
const FONDO_SEL_B := Color("#1a2846")
const ARANCIO := Color("#ffbf70")
const LAMPO := 1.0               # s: lampo giallo dopo lo scambio (fcJust)
const PULSA := 1.1               # s: respiro del bordo del confronto (fcTgt)

var id: Variant = null
var ovr := 50
var cls := "o1"
var ruolo := "C"
var ruolo_vero := ""             # se diverso da ruolo: fuori ruolo
var nome := ""
var delta: Variant = null        # int o null
var scelta := false
var confronto := false
var appena := false
var faccia_svg := ""
var forma := 100                 # 0..100
var infortunio := 0              # giornate che mancano (0 = sano)

var _t := 0.0
var _giu := Vector2.INF
var _sb := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_sb.set_corner_radius_all(12)
	_sb.anti_aliasing = true
	_sb.corner_detail = 6


## riempie la carta: p = giocatore, slot_pos = ruolo del posto in campo ("" = panchina)
func imposta(p: Dictionary, slot_pos: String, faccia: String, d: Variant) -> void:
	id = p.id
	var vero: String = str(p.pos)
	ruolo = slot_pos if slot_pos != "" else vero
	ovr = D.overall_as(p, slot_pos) if slot_pos != "" else D.overall(p)
	cls = D.ovr_cls(ovr)
	ruolo_vero = vero if slot_pos != "" and slot_pos != vero else ""
	nome = MenuRosa.short_name(p.get("name", ""))
	faccia_svg = faccia
	delta = d
	tooltip_text = "%s, %s %d" % [str(p.get("name", "")), D.pos_name(ruolo), ovr]
	set_process(appena or confronto)
	queue_redraw()


## forma (0..100) e giornate di infortunio (0 = sano)
func fisico(forma_: int, infortunio_: int) -> void:
	forma = forma_
	infortunio = infortunio_
	if infortunio > 0:
		tooltip_text += " · infortunato (%d)" % infortunio
	queue_redraw()


func segna(sel: bool, tgt: bool, just: bool) -> void:
	scelta = sel
	confronto = tgt
	appena = just
	_t = 0.0
	z_index = 2 if (sel or tgt) else 0
	set_process(just or tgt)
	queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	if appena and _t >= LAMPO and not confronto:
		appena = false
		set_process(false)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_giu = ev.position
		elif _giu != Vector2.INF:
			if ev.position.distance_to(_giu) <= TOCCO_MAX:
				accept_event()
				toccata.emit(id)
			_giu = Vector2.INF
	elif ev is InputEventMouseMotion and _giu != Vector2.INF:
		if ev.position.distance_to(_giu) > TOCCO_MAX:
			_giu = Vector2.INF


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(W, H))
	# alone sotto (box-shadow): scelta = giallo, confronto = azzurrino che respira, lampo dopo lo scambio
	var alone := Color(0, 0, 0, 0.5)
	var alone_px := 4
	if scelta:
		alone = Color(1, 0.851, 0.239, 0.4)
		alone_px = 3
	elif confronto:
		var f := 0.5 + 0.5 * sin(_t / PULSA * TAU)
		alone = Color(0.812, 0.878, 1.0, lerpf(0.5, 0.25, f))
		alone_px = int(lerpf(3.0, 5.0, f))
	if appena and _t < LAMPO:
		var k := 1.0 - _t / LAMPO
		alone = alone.lerp(Color(1, 0.851, 0.239, 0.8), k)
		alone_px = int(lerpf(float(alone_px), 8.0, k))
	_sb.bg_color = FONDO_SEL_A if scelta else (FONDO_O4_A if cls == "o4" else FONDO_A)
	_sb.border_color = T.GOLD if scelta else (Color.WHITE if confronto else BORDO[cls])
	_sb.set_border_width_all(2 if (scelta or confronto) else 1)
	_sb.shadow_color = alone
	_sb.shadow_size = alone_px
	_sb.shadow_offset = Vector2(0, 0 if (scelta or confronto or appena) else 3)
	draw_style_box(_sb, r)
	# sfumatura verso il basso (linear-gradient del web)
	var b := FONDO_SEL_B if scelta else (FONDO_O4_B if cls == "o4" else FONDO_B)
	var basso := Rect2(2, H * 0.45, W - 4, H * 0.55 - 2)
	draw_polygon(PackedVector2Array([basso.position, Vector2(basso.end.x, basso.position.y), basso.end, Vector2(basso.position.x, basso.end.y)]),
		PackedColorArray([Color(b, 0), Color(b, 0), Color(b, 0.9), Color(b, 0.9)]))
	# riga in alto: valutazione e ruolo
	var f_nero := T.font(900)
	draw_string(f_nero, Vector2(5, 16), str(ovr), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, T.TXT)
	var nr := D.pos_name(ruolo)
	var f_pos := T.font(850)
	var lw := f_pos.get_string_size(nr, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 8.0
	var rp := Rect2(W - 5.0 - lw, 4, lw, 14)
	_rett(rp, T.POS_BG.get(ruolo, T.PANEL2), 5)
	draw_string(f_pos, Vector2(rp.position.x + 4, rp.position.y + 10.5), nr, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	# ritratto
	if faccia_svg != "":
		var tx := MenuSvg.texture(faccia_svg, 30.0 * MenuSvg.scala_schermo() / 40.0)
		if tx != null:
			draw_texture_rect(tx, Rect2((W - 30.0) / 2.0, 20, 30, 30), false)
	# fuori ruolo (a sinistra) e variazione della squadra (a destra)
	if ruolo_vero != "":
		var t := D.pos_name(ruolo_vero)
		var w := f_pos.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0
		_rett(Rect2(2, 32, w, 12), ARANCIO, 4)
		draw_string(f_pos, Vector2(5, 41), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#2a1600"))
	if delta != null:
		var dv := int(delta)
		var t := ("+%d" % dv) if dv > 0 else (("−%d" % -dv) if dv < 0 else "=")
		var col := T.GOOD if dv > 0 else (T.BAD if dv < 0 else Color(1, 1, 1, 0.18))
		var fg := Color("#05140c") if dv > 0 else (Color("#1a0507") if dv < 0 else Color("#dbe4f3"))
		var w := f_nero.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 6.0
		_rett(Rect2(W - 2.0 - w, 32, w, 13), col, 4)
		draw_string(f_nero, Vector2(W - 2.0 - w + 3.0, 42), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fg)
	# nome breve, tagliato coi puntini se non ci sta
	var fn := T.font(T.PESO_FORTE)
	var testo := _taglia(fn, nome, 10.5, W - 8.0)
	var tw := fn.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(fn, Vector2((W - tw) / 2.0, 63), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, T.TXT)
	_disegna_fisico()


# croce rossa (infortunato) a sinistra del ritratto; barretta della forma sotto il nome
func _disegna_fisico() -> void:
	if infortunio > 0:
		_rett(Rect2(3, 21, 15, 15), T.BAD, 4)
		draw_rect(Rect2(9, 23.5, 3, 10), Color.WHITE)
		draw_rect(Rect2(5.5, 27, 10, 3), Color.WHITE)
	if forma < 100:
		var col := T.GOOD if forma >= 80 else (Color("#f1c75a") if forma >= 50 else T.BAD)
		var w := W - 16.0
		draw_rect(Rect2(8, H - 5, w, 2), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(8, H - 5, w * clampf(forma / 100.0, 0.0, 1.0), 2), col)


func _rett(r: Rect2, c: Color, raggio: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(raggio)
	s.anti_aliasing = true
	draw_style_box(s, r)


static func _taglia(f: Font, t: String, _dim: float, larghezza: float) -> String:
	if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= larghezza:
		return t
	var s := t
	while s.length() > 1 and f.get_string_size(s + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > larghezza:
		s = s.substr(0, s.length() - 1)
	return s + "…"
