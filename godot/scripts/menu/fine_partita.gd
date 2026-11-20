# Fine partita e risultati della giornata (post() di src/ui.js). arg = {m, res, title} come G.res del web:
#   m     = la partita (SimMatch o Dictionary): score, goalsLog [{team, name, minute}], stats {shots, onT, poss,
#           corners, fouls}, teams [{short, kit: {crest: {shape, pattern, icon, c1, c2}}}]
#   res   = risultato di Carriera.finishMatch (incasso, stipendi, migliorati, altri risultati, season) o null
#   title = riga in alto ("Terza Divisione · Giornata 4", "Amichevole", ...)
# "Continua" porta alla fine della stagione se è finita, altrimenti alla casa della carriera.
extends MenuSchermata


func prepara() -> void:
	con_testata = false


func costruisci() -> void:
	var r: Dictionary = arg if arg is Dictionary else {}
	var m: Variant = r.get("m")
	if m == null:
		corpo.add_child(U.bottone("CONTINUA", "BtnGrande", func() -> void: vai("hub")))
		return
	var score: Array = D.campo(m, "score", [0, 0])
	var teams: Array = D.campo(m, "teams", [{}, {}])
	var stats: Dictionary = D.campo(m, "stats", {})
	var s0 := int(score[0])
	var s1 := int(score[1])
	var vd: Array = ["w", "VITTORIA"] if s0 > s1 else (["l", "SCONFITTA"] if s0 < s1 else ["d", "PAREGGIO"])

	corpo.add_child(U.spazio(maxf(0.0, get_viewport_rect().size.y * 0.02 - 12.0)))
	corpo.add_child(U.testo(str(r.get("title", "")).to_upper(), 12, T.DIM, T.PESO_FORTE, HORIZONTAL_ALIGNMENT_CENTER))
	var k1: Color = colori_squadra()[0]
	var cs := U.carta_sfumata(T.mix(k1, 38, Color("#16253f")), Color("#0f192c"), 160, 0.7, 22, Vector4(12, 18, 12, 16), T.LINE2, Color(0, 0, 0, 0.45))
	var tab := U.vbox(10)
	cs[1].add_child(tab)
	var riga := U.hbox(6)
	riga.add_child(_squadra(teams[0], false))
	riga.add_child(U.testo("%d – %d" % [s0, s1], 56, T.TXT, 900, HORIZONTAL_ALIGNMENT_CENTER))
	riga.add_child(_squadra(teams[1], true))
	tab.add_child(riga)
	var col: Color = {"w": T.GOOD, "d": Color("#f1c75a"), "l": T.BAD}[vd[0]]
	var pill := U.pannello_stile(T.stile(Color(col, 0.15), 999, Color(0, 0, 0, 0), 0, Vector4(14, 5, 14, 5)))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_child(U.testo(vd[1], 12, col, 900))
	tab.add_child(pill)
	var marc := U.vbox(5)
	for g: Variant in D.campo(m, "goalsLog", []):
		var t0: bool = int(D.campo(g, "team", 0)) == 0
		var nome := str(D.campo(g, "name", ""))
		var minuto := int(D.campo(g, "minute", 0))
		var l := U.testo(("%s %d'" % [nome, minuto]) if t0 else ("%d' %s" % [minuto, nome]), 13, Color("#c9d6ee"), T.PESO_MEDIO, HORIZONTAL_ALIGNMENT_LEFT if t0 else HORIZONTAL_ALIGNMENT_RIGHT)
		marc.add_child(l)
	tab.add_child(marc)
	corpo.add_child(cs[0])

	var poss: Array = stats.get("poss", [0, 0])
	var ps := float(poss[0]) + float(poss[1])
	if ps <= 0.0:
		ps = 1.0
	var righe := U.vbox(0)
	righe.add_child(_stat("Tiri", stats.get("shots", [0, 0])))
	righe.add_child(_stat("In porta", stats.get("onT", [0, 0])))
	righe.add_child(_stat("Possesso", ["%d%%" % D._round_js(float(poss[0]) / ps * 100.0), "%d%%" % D._round_js(float(poss[1]) / ps * 100.0)]))
	righe.add_child(_stat("Angoli", stats.get("corners", [0, 0])))
	righe.add_child(_stat("Falli", stats.get("fouls", [0, 0])))
	corpo.add_child(righe)

	var res: Variant = r.get("res")
	if res is Dictionary:
		corpo.add_child(_soldi(res))
	var stagione: Variant = res.get("season") if res is Dictionary else null
	corpo.add_child(U.bottone("CONTINUA", "BtnGrande", func() -> void:
		if stagione is Dictionary:
			vai("fine_stagione", stagione)
		else:
			vai("hub")))


func _squadra(t: Variant, destra: bool) -> Control:
	var h := U.hbox(6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var kit: Variant = D.campo(t, "kit", {})
	var cr: Variant = D.campo(kit, "crest")
	var st: Control = null
	if cr is Dictionary:
		st = MenuStemma.nuovo(cr, int(cr.get("c1", 0xc8102e)), int(cr.get("c2", 0xffffff)), Vector2(30, 36))
	var nome := U.testo(str(D.campo(t, "short", "")), 20, T.TXT, T.PESO_NERO)
	if st != null:
		h.add_child(st)
	h.add_child(nome)
	return h


# riga di statistica: valori ai lati, nome al centro, barra divisa sotto (giallo noi, blu loro)
func _stat(nome: String, v: Array) -> Control:
	var box := U.vbox(4)
	var h := U.hbox(10)
	var a := U.testo(str(v[0]), 16, T.TXT, T.PESO_NERO)
	a.custom_minimum_size.x = 56
	h.add_child(a)
	var n := U.testo(nome, 13, Color("#b3c3de"), T.PESO_MEDIO, HORIZONTAL_ALIGNMENT_CENTER)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var b := U.testo(str(v[1]), 16, T.TXT, T.PESO_NERO, HORIZONTAL_ALIGNMENT_RIGHT)
	b.custom_minimum_size.x = 56
	h.add_child(b)
	box.add_child(h)
	var fa := str(v[0]).to_float()
	var fb := str(v[1]).to_float()
	var qa := fa if fa > 0.0 else (0.01 if fb > 0.0 else 1.0)
	var qb := fb if fb > 0.0 else (0.01 if fa > 0.0 else 1.0)
	var barra := Control.new()
	barra.custom_minimum_size.y = 5
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.draw.connect(func() -> void:
		var w := barra.size.x - 3.0
		var wa := w * qa / (qa + qb)
		MenuUi._rett_tondo(barra, Rect2(0, 0, wa, 5), 2, T.GOLD)
		MenuUi._rett_tondo(barra, Rect2(wa + 3.0, 0, w - wa, 5), 2, Color("#6f86b0")))
	box.add_child(barra)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_theme_constant_override("margin_left", 2)
	m.add_theme_constant_override("margin_right", 2)
	m.add_child(box)
	return m


func _soldi(res: Dictionary) -> Control:
	var s := stato()
	var carta := U.pannello("Carta")
	var v := U.vbox(0)
	carta.add_child(v)
	v.add_child(_voce("Incasso partita", "+" + D.fmt_money(float(res.get("income", 0))), T.GOOD, false))
	v.add_child(_voce("Stipendi", "−" + D.fmt_money(float(res.get("wages", 0))), T.BAD, true))
	v.add_child(_voce("Cassa", D.fmt_money(float(s.get("money", 0))), T.TXT, true))
	var grown: Array = res.get("grown", [])
	if not grown.is_empty():
		v.add_child(U.spazio(8))
		v.add_child(U.paragrafo("Migliorati: " + ", ".join(grown.map(func(x: Variant) -> String: return str(x))), 13.5))
	var others: Array = res.get("others", [])
	if not others.is_empty():
		v.add_child(U.spazio(8))
		var parti: Array = others.map(func(o: Array) -> String: return "%s %d–%d %s" % [o[0], int(o[1]), int(o[2]), o[3]])
		v.add_child(U.paragrafo("Altri risultati: " + " · ".join(parti), 13.5))
	return carta


func _voce(nome: String, val: String, col: Color, riga_sopra: bool) -> Control:
	var box := U.vbox(0)
	if riga_sopra:
		var r := ColorRect.new()
		r.color = T.LINE
		r.custom_minimum_size.y = 1
		box.add_child(r)
	var h := U.hbox(10)
	h.custom_minimum_size.y = 40
	h.add_child(U.corto(nome, 13, Color("#b3c3de"), T.PESO_MEDIO))
	h.add_child(U.testo(val, 16, col, T.PESO_NERO))
	box.add_child(h)
	return box
