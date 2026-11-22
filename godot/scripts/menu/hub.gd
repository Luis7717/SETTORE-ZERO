# Casa della carriera (hub() di src/ui.js): barra della squadra (stemma, nome, divisione, stagione, posto),
# obiettivo della dirigenza (verde se oggi è raggiunto), prossima partita (giornata, casa/trasferta, DERBY contro
# la rivale, le due squadre con la forza, avanzamento, scelta partita intera / momenti chiave, GIOCA che pulsa),
# ultimo risultato e le otto caselle (Rosa, Mercato, Classifica, Calendario, Amichevole, 1 contro 1,
# Come si gioca, Impostazioni), più quella larga dell'allenamento libero.
extends MenuSchermata

const I := preload("res://scripts/menu/icone.gd")
const Dirigenza := preload("res://scripts/carriera/dirigenza.gd")
const Meteo := preload("res://scripts/partita/meteo.gd")
const SceltaModo := preload("res://scripts/menu/scelta_modo.gd")
const Stili := preload("res://sim/stili.gd")
const GIORNATE := 18
const PULSA := 2.4                 # s: un respiro del pulsante GIOCA (uiPulse)


func prepara() -> void:
	con_testata = false
	con_3d = true      # il campione palleggia anche dietro la casa della carriera (come il web)
	velo_3d = 0.55


func costruisci() -> void:
	var c := carriera()
	var s := stato()
	if s.is_empty():
		vai.call_deferred("principale")
		return
	var d: int = c.div()
	var tab: Array = c.table(d)
	var pos := 1
	for i in tab.size():
		if tab[i].id == "me":
			pos = i + 1
	var me: Dictionary = s.teams.me
	var cs := colori_squadra()

	# barra della squadra
	var bar := U.hbox(12)
	bar.add_child(stemma_squadra(me, Vector2(46, 54)))
	var info := U.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(U.corto(str(s.club), 23, T.TXT, T.PESO_NERO))
	var riga := U.bb("%s · Stagione %d · [color=#ffd93d][b]%d°[/b][/color] posto" % [D.div_names()[d], int(s.season), pos], 13, T.DIM)
	info.add_child(riga)
	var ob: Dictionary = c.obiettivo()
	if not ob.is_empty():
		var ok := pos <= int(ob.get("posto", 8))
		info.add_child(U.bb("Obiettivo: [color=%s][b]%s[/b][/color]" % ["#4aeb9f" if ok else "#ffd93d", U.esc(Dirigenza.testo(ob))], 12.5, T.DIM))
	bar.add_child(info)
	corpo.add_child(bar)

	# prossima partita
	var nm: Variant = c.nextMatch()
	if nm != null:
		corpo.add_child(_carta_prossima(nm, me, cs[0]))
	var last: Variant = s.get("last")
	if last is Dictionary:
		corpo.add_child(_ultima(last, str(s.club)))

	# caselle
	var g := U.griglia(2, 10, 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tiles := [
		["squad", "Rosa", "Formazione e titolari", "rosa"],
		["market", "Mercato", "Compra e vendi", "mercato"],
		["table", "Classifica", "%d° su 10" % pos, "classifica"],
		["calendar", "Calendario", "Risultati e prossime", "calendario"],
		["friendly", "Amichevole", "Allenati senza rischi", "amichevole"],
		["vs", "1 contro 1", "Sfida un amico", "uno_contro_uno"],
		["howto", "Come si gioca", "I comandi", "come_si_gioca"],
		["settings", "Impostazioni", "Durata, difficoltà", "impostazioni"],
	]
	for t: Array in tiles:
		g.add_child(_casella(t[0], t[1], t[2], t[3], cs[0]))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 4)
	m.add_child(g)
	corpo.add_child(m)
	# allenamento libero (tiri, punizioni, rigori a punti): casella larga sotto le otto
	corpo.add_child(_casella("goal", "Allenamento libero", "Tiri, punizioni, rigori: batti il record", "allenamento_libero", cs[0]))


func stemma_squadra(t: Dictionary, misura: Vector2) -> MenuStemma:
	var k := D.kit(t.get("kit", 0))
	return MenuStemma.nuovo(carriera().teamCrest(t), int(k[1]), int(k[2]), misura)


func _carta_prossima(nm: Dictionary, me: Dictionary, k1: Color) -> Control:
	var c := carriera()
	# linear-gradient(160deg, k1 al 34% su #14213a, #101a2f 62%) con bordo #ffffff1f
	var cs := U.carta_sfumata(T.mix(k1, 34, T.CARD_TOP), T.CARD_BOTTOM, 160, 0.62, T.R, Vector4(16, 16, 16, 18), Color(1, 1, 1, 0.12))
	var carta: Control = cs[0]
	carta.add_child(_sfumatura_carta(k1))
	carta.move_child(carta.get_child(-1), 2)
	var v := U.vbox(0)
	cs[1].add_child(v)
	var top := U.hbox(8)
	top.add_child(U.testo("GIORNATA %d DI %d" % [int(nm.day), GIORNATE], 12, Color("#b7c7e3"), T.PESO_NERO))
	top.add_child(U.riempi())
	if c.isDerby(nm.opp):
		var derby := U.pannello_stile(T.stile(Color("#ff4d5e"), 999, Color(0, 0, 0, 0), 0, Vector4(10, 3, 10, 3)))
		derby.add_child(U.testo("DERBY", 11.5, Color.WHITE, T.PESO_NERO))
		top.add_child(derby)
	var pill := U.pannello("PillolaOro" if nm.home else "Pillola")
	pill.add_child(U.testo("IN CASA" if nm.home else "IN TRASFERTA", 11.5, T.GOLD if nm.home else Color("#c9d6ee"), T.PESO_NERO))
	top.add_child(pill)
	v.add_child(top)
	# previsione: la stessa che troverà la partita (app.gd → Meteo.per_giornata)
	var st := stato()
	var prev := Meteo.per_giornata(int(st.get("seed", 0)), int(st.get("season", 1)), int(nm.day))
	v.add_child(U.spazio(4))
	v.add_child(U.testo(Meteo.testo(prev), 12, Color("#b7c7e3"), T.PESO_NERO))
	v.add_child(U.spazio(12))
	var vs := U.hbox(6)
	vs.add_child(_lato_vs(me, str(stato().club), int(c.myRating())))
	var cerchio := U.pannello_stile(T.stile(Color(1, 1, 1, 0.08), 21, T.LINE2, 1, Vector4.ZERO))
	cerchio.custom_minimum_size = Vector2(42, 42)
	cerchio.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cerchio.add_child(U.testo("VS", 13, Color.WHITE, 900, HORIZONTAL_ALIGNMENT_CENTER))
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_top", 16)
	cm.add_child(cerchio)
	vs.add_child(cm)
	var opp: Dictionary = nm.opp
	vs.add_child(_lato_vs(opp, str(opp.name), int(opp.rating)))
	v.add_child(vs)
	# stile di gioco dell'avversario (fase D): lo stesso che userà in partita (Carriera.avversarioPartita)
	var sa: Dictionary = c.stileDi(opp)
	v.add_child(U.spazio(8))
	v.add_child(U.bb("[center]Loro: [color=#eef3fb][b]%s[/b][/color][/center]" % U.esc(Stili.testo(sa.att, sa.dif)), 12, T.DIM))
	v.add_child(U.spazio(18))
	v.add_child(U.barra((float(nm.day) - 1.0) / GIORNATE, 5.0))
	v.add_child(U.spazio(12))
	v.add_child(SceltaModo.nuova(self)) # partita intera o momenti chiave
	v.add_child(U.spazio(12))
	var gioca_btn := U.bottone("GIOCA", "BtnGrande", func() -> void: gioca("campionato"))
	U.contenuto_centrato(gioca_btn, MenuDisegno.nuovo(I.play(), Vector2(24, 24), Vector2(22, 22)), "GIOCA", 18, T.INK, T.PESO_NERO)
	_pulsa(gioca_btn)
	v.add_child(gioca_btn)
	return carta


# riflesso tondo in alto a destra della carta (.card.next::after)
func _sfumatura_carta(_k1: Color) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		# riflesso tondo nell'angolo in alto a destra, tutto dentro la carta (il web lo ritaglia con overflow:hidden)
		var centro := Vector2(c.size.x - 40.0, 40.0)
		for i in 8:
			var r := 40.0 * (1.0 - i / 8.0)
			c.draw_circle(centro, r, Color(1, 1, 1, 0.012)))
	return c


func _lato_vs(t: Dictionary, nome: String, forza: int) -> Control:
	var v := U.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	var st := stemma_squadra(t, Vector2(60, 72))
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	var n := U.paragrafo(nome, 14.5, T.TXT, T.PESO_NERO)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.max_lines_visible = 2
	n.add_theme_constant_override("line_spacing", 1)
	v.add_child(n)
	v.add_child(U.bb("[center]forza [color=#eef3fb][b]%d[/b][/color][/center]" % forza, 12, T.DIM))
	return v


func _ultima(last: Dictionary, club: String) -> Control:
	var my := int(last.my)
	var op := int(last.op)
	var w := "w" if my > op else ("l" if my < op else "d")
	var h := U.hbox(10)
	var col: Color = {"w": T.GOOD, "d": Color("#f1c75a"), "l": T.BAD}[w]
	var box := U.pannello_stile(T.stile(col, 8, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	box.custom_minimum_size = Vector2(26, 26)
	box.add_child(U.testo({"w": "V", "d": "P", "l": "S"}[w], 12, Color("#06120c"), 900, HORIZONTAL_ALIGNMENT_CENTER))
	h.add_child(box)
	var t := U.bb("Ultima: %s [color=#eef3fb][b]%d – %d[/b][/color] %s" % [U.esc(club), my, op, U.esc(last.opp)], 13, Color("#a9bad6"))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 2)
	m.add_child(h)
	return m


func _casella(icona: String, titolo_t: String, sotto: String, dove: String, k1: Color) -> Control:
	var b := U.bottone("", "Tile", func() -> void: vai(dove), 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := U.pannello_stile(T.stile(T.mix(k1, 38, Color("#1c2b49")), 11, Color(1, 1, 1, 0.11), 1, Vector4.ZERO))
	ic.custom_minimum_size = Vector2(34, 34)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ic.position = Vector2(-44, 10)
	var dis := MenuDisegno.nuovo(I.icona(icona), Vector2(24, 24), Vector2(20, 20))
	dis.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dis.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_child(dis)
	b.add_child(ic)
	var v := U.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -12
	v.offset_bottom = -14
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(U.testo(titolo_t, 16, T.TXT, T.PESO_NERO))
	var s := U.corto(sotto, 12.5, T.DIM, T.PESO_MEDIO)
	v.add_child(s)
	b.add_child(v)
	b.resized.connect(func() -> void: ic.position = Vector2(b.size.x - 44.0, 10))
	return b


# GIOCA respira: l'alone giallo sotto il pulsante cresce e cala (uiPulse del web)
func _pulsa(b: Button) -> void:
	var st := T.stile_grande()
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	var tw := b.create_tween().set_loops()
	tw.tween_method(func(f: float) -> void:
		st.shadow_size = int(lerpf(10.0, 18.0, f))
		st.shadow_color = Color(1, 0.851, 0.239, lerpf(0.25, 0.5, f)), 0.0, 1.0, PULSA / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(f: float) -> void:
		st.shadow_size = int(lerpf(10.0, 18.0, f))
		st.shadow_color = Color(1, 0.851, 0.239, lerpf(0.25, 0.5, f)), 1.0, 0.0, PULSA / 2.0).set_trans(Tween.TRANS_SINE)
