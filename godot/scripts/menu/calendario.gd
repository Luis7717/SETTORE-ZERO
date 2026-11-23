# Calendario (calendar() di src/ui.js): le 18 giornate della mia divisione, avversario con stemma, casa/fuori,
# forza, risultato colorato (vittoria verde, pareggio azzurro, sconfitta rossa); la prossima giornata evidenziata.
extends MenuSchermata


func prepara() -> void:
	titolo = "Calendario"


func costruisci() -> void:
	var c := carriera()
	var s := stato()
	if s.is_empty():
		return
	var d: int = c.div()
	var righe := U.vbox(7)
	var res: Array = s.get("res", [])
	for i in s.fix[d].size():
		var round_: Array = s.fix[d][i]
		var m: Array = []
		for x: Array in round_:
			if x[0] == "me" or x[1] == "me":
				m = x
		if m.is_empty():
			continue
		var home: bool = m[0] == "me"
		var opp: Dictionary = c.team(m[1] if home else m[0])
		var r: Variant = res[i] if i < res.size() else null
		righe.add_child(_riga(i, home, opp, r, i == int(s.day)))
	corpo.add_child(righe)


func _riga(i: int, home: bool, opp: Dictionary, r: Variant, adesso: bool) -> Control:
	var c := carriera()
	var p := U.pannello_stile(T.stile(Color("#1f3052") if adesso else Color("#13203a"), 14, T.GOLD if adesso else T.LINE, 1, Vector4(8, 6, 10, 6)))
	if adesso:
		T.con_ombra(p.get_theme_stylebox("panel") as StyleBoxFlat, Color(1, 0.851, 0.239, 0.11), 3, Vector2.ZERO)
	p.custom_minimum_size.y = 56
	var h := U.hbox(10)
	p.add_child(h)
	var n := U.testo(str(i + 1), 14, T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
	n.custom_minimum_size.x = 38
	h.add_child(n)
	var k := D.kit(opp.get("kit", 0))
	h.add_child(MenuStemma.nuovo(c.teamCrest(opp), int(k[1]), int(k[2]), Vector2(22, 26)))
	# nome dell'avversario su tutta la larghezza; casa/fuori e forza sotto, piccoli (prima stavano sulla stessa
	# riga e il nome si leggeva a metà)
	var testi := U.vbox(0)
	testi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testi.alignment = BoxContainer.ALIGNMENT_CENTER
	testi.add_child(U.corto(str(opp.name), 15.5, T.TXT, T.PESO_FORTE))
	testi.add_child(U.corto(("Casa" if home else "Fuori") + " · forza %d" % int(opp.rating), 12.5, T.DIM, T.PESO_MEDIO))
	h.add_child(testi)
	if r is Array and r.size() >= 2:
		var cls := "o3" if r[0] > r[1] else ("bad" if r[0] < r[1] else "o2")
		var v := U.valutazione(0, cls, 52)
		(v.get_child(0) as Label).text = "%d–%d" % [int(r[0]), int(r[1])]
		h.add_child(v)
	else:
		h.add_child(U.valutazione(-1, "", 52))
	return p
