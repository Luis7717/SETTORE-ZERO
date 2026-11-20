# Menu principale (title() di src/ui.js senza "new"): logo TIRO A GIRO, frase, tre etichette, "Continua carriera"
# e "Nuova carriera". Senza carriera salvata porta subito alla nuova carriera (come il web).
# Dietro i pulsanti c'è lo sfondo 3D del campione che palleggia (con_3d, vedi MenuSchermata.crea_sfondo); senza
# (--senza-3d o scena mancante) resta la sfumatura con il campo disegnato.
extends MenuSchermata

const I := preload("res://scripts/menu/icone.gd")


func prepara() -> void:
	con_testata = false
	ferma = true
	con_3d = true
	velo_3d = 0.2


func costruisci() -> void:
	var s := stato()
	if s.is_empty():
		# niente carriera: si crea subito (title('new') del web)
		vai.call_deferred("nuova_carriera")
		return
	var hero := Control.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(hero)
	var v := U.vbox(0)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(v)
	if sfondo_3d == null:
		var campo := MenuDisegno.nuovo(I.campo_titolo(), Vector2(400, 300), Vector2(0, 0))
		campo.modulate.a = 0.5
		campo.set_anchors_preset(Control.PRESET_FULL_RECT)
		hero.add_child(campo)
		hero.move_child(campo, 0)
		var palla := MenuDisegno.nuovo(I.pallone(), Vector2(64, 64), Vector2(64, 64))
		palla.ombra = Color(0, 0, 0, 0.5)
		palla.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(palla)
		v.add_child(U.spazio(14))
	v.add_child(logo(52))
	var sub := U.testo("Disegna la giocata. Vinci il campionato.", 16, Color("#c3d0e8"), T.PESO_MEDIO, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(U.spazio(16))
	v.add_child(sub)
	v.add_child(U.spazio(22))
	var claim := U.hbox(8)
	claim.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in ["CAMPIONATO", "MERCATO", "A UN DITO"]:
		var p := U.pannello("Claim")
		p.add_child(U.testo(t, 12, Color("#bcd0f0"), T.PESO_FORTE))
		claim.add_child(p)
	v.add_child(claim)
	hero.resized.connect(func() -> void:
		v.size = Vector2(hero.size.x, v.get_combined_minimum_size().y)
		v.position = Vector2(0, (hero.size.y - v.size.y) * 0.62))
	var btn := U.bottone("CONTINUA CARRIERA", "BtnGrande", func() -> void: vai("hub"))
	corpo.add_child(btn)
	corpo.add_child(U.bottone("Nuova carriera", "BtnFantasma", func() -> void: vai("nuova_carriera")))


## logo TIRO A GIRO in corsivo pesante con la A gialla (.logo del web)
static func logo(dim: float) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", int(dim * 0.12))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for parte: Array in [["TIRO", MenuTema.TXT], ["A", MenuTema.GOLD], ["GIRO", MenuTema.TXT]]:
		var l := MenuUi.testo(parte[0], dim, parte[1], 900, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_font_override("font", MenuTema.font(900, true))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		l.add_theme_constant_override("shadow_offset_y", 4)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_outline_size", 0)
		h.add_child(l)
	return h
