# Rosa: i tre tasti in alto (Formazione, Attacco, Difesa) e il loro menu a comparsa (Luis 2026-11-24).
# Tasto = due righe (cosa si sceglie, in piccolo; scelta attuale, in giallo). Menu = velo scuro su tutto lo schermo,
# riquadro con titolo e ×, una voce grande per scelta (nome + riga di spiegazione, con la formazione disegnata a
# puntini se c'è lo schema), la scelta attuale in giallo. Si chiude toccando fuori, con la × o scegliendo.
extends RefCounted

const T := preload("res://scripts/menu/tema_menu.gd")
const U := preload("res://scripts/menu/ui.gd")

const ALTEZZA_TASTO := 58.0
const ALTEZZA_VOCE := 58.0
const LARGHEZZA_MENU := 420.0     # al massimo; sull'iPhone è lo schermo meno i margini
const MARGINE_MENU := 14.0
const TESTA_MENU := 78.0          # titolo, × e bordi del riquadro: il resto dell'altezza è per le voci
const VELO := Color(0.02, 0.035, 0.07, 0.78)
const SCHEMA := Vector2(34, 44)   # formazione disegnata a puntini nella voce
const PUNTINO := 2.6
const COMPARSA := 0.16            # s: dissolvenza del menu


## tasto in alto: etichetta piccola sopra, scelta attuale in giallo sotto
static func tasto(etichetta: String, valore: String, cb: Callable) -> Button:
	var b := U.bottone("", "", cb, ALTEZZA_TASTO)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := T.stile(T.PANEL2, 14, T.LINE2, 1, Vector4(6, 6, 6, 6))
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", T._premuto(st))
	var v := U.vbox(1)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := U.testo(etichetta.to_upper(), 10.5, T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
	var val := U.testo(valore + "  ▾", 15, T.GOLD, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
	for l: Label in [e, val]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
	b.add_child(v)
	return b


## menu a comparsa sopra tutto. voci = [{id, nome, spiega, schema (facoltativo: posti [ruolo, x, y] della formazione)}];
## area = rettangolo dove stare (area sicura); scegli(id) e chiudi() le chiama chi apre.
static func menu(titolo: String, voci: Array, scelto: String, area: Rect2, scegli: Callable, chiudi: Callable) -> Control:
	var velo := ColorRect.new()
	velo.color = VELO
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	velo.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and not ev.pressed) or (ev is InputEventScreenTouch and not ev.pressed):
			chiudi.call())
	var w := minf(LARGHEZZA_MENU, area.size.x - 2.0 * MARGINE_MENU)
	var pann := U.pannello("PannelloRosa")
	pann.mouse_filter = Control.MOUSE_FILTER_STOP   # i tocchi sul riquadro non chiudono
	pann.custom_minimum_size.x = w
	var v := U.vbox(6)
	pann.add_child(v)
	var testa := U.hbox(8)
	var tit := U.testo(titolo.to_upper(), 13, T.TXT, T.PESO_NERO)
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	testa.add_child(tit)
	var x := U.bottone("×", "Chiudi", chiudi, 38)
	x.custom_minimum_size.x = 38
	testa.add_child(x)
	v.add_child(testa)
	# tante voci (14 moduli, Luis 2026-11-26): la lista scorre dentro il riquadro, che resta nello schermo
	var lista := U.vbox(6)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var i_scelto := 0
	for i in voci.size():
		var voce: Dictionary = voci[i]
		if voce.id == scelto:
			i_scelto = i
		lista.add_child(_voce(voce, voce.id == scelto, scegli))
	var alta := voci.size() * (ALTEZZA_VOCE + 6.0) - 6.0
	var spazio := area.size.y - 2.0 * MARGINE_MENU - TESTA_MENU
	if alta <= spazio:
		v.add_child(lista)
	else:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size.y = spazio
		sc.scroll_deadzone = 6
		sc.add_child(lista)
		v.add_child(sc)
		# la scelta attuale in vista
		var giu := maxf(0.0, (i_scelto + 0.5) * (ALTEZZA_VOCE + 6.0) - spazio / 2.0)
		sc.ready.connect(func() -> void: sc.set_deferred("scroll_vertical", int(giu)))
	velo.add_child(pann)
	# al centro dell'area sicura, ricalcolato quando il velo prende la misura dello schermo o il riquadro cresce
	# (segnali dei nodi stessi: spariscono col menu chiuso)
	var centra := func() -> void:
		pann.size = pann.get_combined_minimum_size()
		pann.position = area.position + (area.size - pann.size) / 2.0
	velo.resized.connect(centra)
	pann.minimum_size_changed.connect(centra)
	velo.modulate.a = 0.0
	velo.ready.connect(func() -> void: velo.create_tween().tween_property(velo, "modulate:a", 1.0, COMPARSA))
	return velo


# una voce: (schema) nome + spiegazione; la scelta attuale ha fondo e bordo gialli
static func _voce(voce: Dictionary, on: bool, scegli: Callable) -> Button:
	var b := U.bottone("", "", scegli.bind(voce.id), ALTEZZA_VOCE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := T.stile(Color(T.GOLD, 0.14) if on else T.PANEL2, 12, T.GOLD if on else T.LINE2, 2 if on else 1, Vector4.ZERO)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", T._premuto(st))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lato: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(lato, 10)
	var h := U.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	if voce.has("schema"):
		h.add_child(_schema(voce.schema, on))
	var col := U.vbox(1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nome := U.testo(str(voce.nome), 16, T.GOLD if on else T.TXT, T.PESO_NERO)
	var sp := U.paragrafo(str(voce.spiega), 12, T.TXT if on else T.NOTE)
	sp.add_theme_constant_override("line_spacing", -2)
	sp.max_lines_visible = 2
	for l: Label in [nome, sp]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	h.add_child(col)
	b.add_child(m)
	# alta quanto serve se la spiegazione va su due righe
	m.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = maxf(ALTEZZA_VOCE, m.get_combined_minimum_size().y + 10.0))
	return b


# formazione a puntini: porta in basso, attacco in alto (come le carte nella Rosa)
static func _schema(F: Array, on: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = SCHEMA
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, SCHEMA)
		c.draw_rect(r, Color(1, 1, 1, 0.05))
		c.draw_rect(r, Color(1, 1, 1, 0.14), false, 1.0)
		c.draw_line(Vector2(0, SCHEMA.y / 2.0), Vector2(SCHEMA.x, SCHEMA.y / 2.0), Color(1, 1, 1, 0.14), 1.0)
		for slot: Array in F:
			var px: float = SCHEMA.x / 2.0 + float(slot[1]) * (SCHEMA.x / 2.0 - 4.0)
			var py: float = SCHEMA.y - 3.0 - float(slot[2]) / 0.72 * (SCHEMA.y - 6.0)
			var colore: Color = T.GOLD if on else T.TXT
			if slot[0] == "P":
				colore = T.DIM
			c.draw_circle(Vector2(px, py), PUNTINO, colore, true, -1.0, true))
	return c
