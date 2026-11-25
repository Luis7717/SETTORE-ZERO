# Statistiche dettagliate di un giocatore "come su FIFA" (Luis 2026-11-25). Velo scuro su tutto lo schermo con un
# riquadro: in alto faccia, nome, ruolo, età e valutazione (×  per chiudere); sotto, in una lista che scorre col
# dito, i gruppi in 2 colonne: VELOCITÀ, TIRO, PASSAGGI, DRIBBLING, DIFESA, FISICO (il portiere ha PORTIERE per
# primo). Ogni gruppo: arco col valore grande (la statistica grande = media delle sue sotto-statistiche,
# sim/sottostat.gd) e sotto le sotto-statistiche con nome, numero e barretta (verde ≥ 70, gialla 50-69, rossa
# sotto). Il colpo di testa (`tes`) sta sotto Difesa. Chi non ha `sub` (salvataggi vecchi) vede ogni
# sotto-statistica uguale alla sua grande (Sotto.valore). Si apre dalla Rosa (tasto Statistiche) e dal Mercato.
# Si chiude toccando fuori o con la ×. Solo lettura: nessun dato cambia.
extends RefCounted

const T := preload("res://scripts/menu/tema_menu.gd")
const U := preload("res://scripts/menu/ui.gd")
const D := preload("res://scripts/menu/menu_dati.gd")
const Sotto := preload("res://sim/sottostat.gd")

const ORDINE := ["vel", "tir", "pas", "dri", "dif", "fis"]
const ORDINE_PORTIERE := ["por", "vel", "tir", "pas", "dri", "dif", "fis"]
const BUONO := 70                 # da qui in su verde
const MEDIO := 50                 # da qui a BUONO-1 giallo, sotto rosso
const MARGINE := 10.0             # px tra il riquadro e il bordo dell'area sicura
const LARGHEZZA_MAX := 520.0
const VELO := Color(0.02, 0.035, 0.07, 0.82)
const COMPARSA := 0.16            # s: dissolvenza
const ARCO_H := 70.0              # px: altezza della zona dell'arco
const ARCO_R := 27.0
const ARCO_SPESSORE := 6.0
const ARCO_INIZIO := 135.0        # gradi: l'arco è aperto in basso (270°)
const ARCO_GIRO := 270.0
const SCALA_MAX := 99.0


## colore di un valore: verde ≥ 70, giallo 50-69, rosso sotto
static func colore(v: int) -> Color:
	return T.GOOD if v >= BUONO else (T.GOLD if v >= MEDIO else T.BAD)


## gruppi da mostrare, in ordine: [[chiave grande, nome, valore, [[chiave, nome, valore], ...]], ...]
static func gruppi(p: Dictionary) -> Array:
	var out: Array = []
	for g: String in (ORDINE_PORTIERE if str(p.get("pos", "")) == "P" else ORDINE):
		var righe: Array = []
		for k: String in Sotto.GRUPPI[g]:
			righe.append([k, Sotto.NOMI[k], int(roundf(Sotto.valore(p, k)))])
		if g == "dif":
			righe.append(["tes", Sotto.NOMI["tes"], D.stat_of(p, "tes")])
		out.append([g, Sotto.NOMI_GRANDI[g], D.stat_of(p, g), righe])
	return out


## la vista sopra tutto. ovr = valutazione da mostrare; colori = [maglia, secondo colore] e k1 per la faccia
## ([] = niente faccia); area = area sicura; chiudi() la chiama chi apre (toglie il velo)
static func vista(p: Dictionary, ovr: int, colori: Array, k1: int, area: Rect2, chiudi: Callable) -> Control:
	var velo := ColorRect.new()
	velo.name = "StatisticheGiocatore"
	velo.color = VELO
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	velo.z_index = 50 # sopra la carta scelta della Rosa (che ha z_index 2)
	velo.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and not ev.pressed) or (ev is InputEventScreenTouch and not ev.pressed):
			chiudi.call())
	var pann := U.pannello("PannelloRosa")
	pann.mouse_filter = Control.MOUSE_FILTER_STOP   # i tocchi sul riquadro non chiudono
	var v := U.vbox(8)
	pann.add_child(v)
	v.add_child(_testa(p, ovr, colori, k1, chiudi))
	var scorri := ScrollContainer.new()
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scorri.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scorri.scroll_deadzone = 6
	scorri.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scorri.mouse_filter = Control.MOUSE_FILTER_PASS
	var griglia := U.griglia(2, 8, 8)
	griglia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for gr: Array in gruppi(p):
		griglia.add_child(_gruppo(gr))
	scorri.add_child(griglia)
	v.add_child(scorri)
	velo.add_child(pann)
	# riquadro alto quanto l'area sicura (la lista scorre dentro), largo al massimo LARGHEZZA_MAX, al centro
	var disponi := func() -> void:
		var w := minf(LARGHEZZA_MAX, area.size.x - 2.0 * MARGINE)
		var h := area.size.y - 2.0 * MARGINE
		pann.size = Vector2(w, h)
		pann.position = area.position + Vector2((area.size.x - w) / 2.0, MARGINE)
	velo.resized.connect(disponi)
	disponi.call()
	velo.modulate.a = 0.0
	velo.ready.connect(func() -> void: velo.create_tween().tween_property(velo, "modulate:a", 1.0, COMPARSA))
	return velo


static func _testa(p: Dictionary, ovr: int, colori: Array, k1: int, chiudi: Callable) -> Control:
	var testa := U.hbox(9)
	if colori.size() >= 2:
		testa.add_child(MenuFaccia.nuovo(D.look_of(p), colori[0], colori[1], 40, k1))
	var nm := U.vbox(1)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.alignment = BoxContainer.ALIGNMENT_CENTER
	nm.add_child(U.corto(str(p.get("name", "")), 16, T.TXT, T.PESO_NERO))
	var info := "%s · %d anni · Statistiche" % [D.pos_name(str(p.get("pos", "C"))), int(p.get("age", 0))]
	nm.add_child(U.corto(info, 12, T.DIM, T.PESO_MEDIO))
	testa.add_child(nm)
	testa.add_child(U.valutazione(ovr, D.ovr_cls(ovr)))
	var x := U.bottone("×", "Chiudi", chiudi, 38)
	x.custom_minimum_size.x = 38
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	testa.add_child(x)
	return testa


# un gruppo: arco col valore grande, nome del gruppo, poi una riga per sotto-statistica
static func _gruppo(gr: Array) -> Control:
	var cella := U.pannello("Stat")
	cella.name = "Gruppo_" + str(gr[0])
	cella.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cella.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var cv := U.vbox(5)
	cella.add_child(cv)
	cv.add_child(_arco(int(gr[2])))
	cv.add_child(U.testo(str(gr[1]).to_upper(), 12, T.TXT, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(U.spazio(2))
	for r: Array in gr[3]:
		cv.add_child(_riga(str(r[1]), int(r[2])))
	return cella


static func _riga(nome: String, val: int) -> Control:
	var v := U.vbox(3)
	var h := U.hbox(4)
	h.add_child(U.corto(nome, 12, T.NOTE, T.PESO_MEDIO))
	var n := U.testo(str(val), 13, colore(val), T.PESO_NERO, HORIZONTAL_ALIGNMENT_RIGHT)
	n.custom_minimum_size.x = 22
	h.add_child(n)
	v.add_child(h)
	v.add_child(U.barra(clampf(val / SCALA_MAX, 0.04, 1.0), 4.0, colore(val)))
	return v


# arco aperto in basso, pieno in proporzione al valore, col numero grande in mezzo
static func _arco(val: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, ARCO_H)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := colore(val)
	c.draw.connect(func() -> void:
		var centro := Vector2(c.size.x / 2.0, ARCO_H / 2.0 + 2.0)
		var a0 := deg_to_rad(ARCO_INIZIO)
		var a1 := deg_to_rad(ARCO_INIZIO + ARCO_GIRO)
		c.draw_arc(centro, ARCO_R, a0, a1, 48, Color(1, 1, 1, 0.09), ARCO_SPESSORE, true)
		var fine := deg_to_rad(ARCO_INIZIO + ARCO_GIRO * clampf(val / SCALA_MAX, 0.0, 1.0))
		c.draw_arc(centro, ARCO_R, a0, fine, 48, col, ARCO_SPESSORE, true))
	var n := U.testo(str(val), 24, col, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
	n.name = "Valore"
	n.set_anchors_preset(Control.PRESET_FULL_RECT)
	n.offset_top = 2
	c.add_child(n)
	return c
