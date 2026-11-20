# Fine stagione (season() di src/ui.js). arg = risultato di Carriera.endSeason: {pos, prize, bonus, outcome
# ("up" | "down" | "champ" | "stay"), div, newDiv}. Coppa (tranne in retrocessione), titolo, premio, nuova divisione.
extends MenuSchermata

const I := preload("res://scripts/menu/icone.gd")


func prepara() -> void:
	con_testata = false


func costruisci() -> void:
	var r: Dictionary = arg if arg is Dictionary else {}
	var esito := str(r.get("outcome", "stay"))
	var titolo_t: String = {"up": "PROMOSSI!", "down": "Retrocessi", "champ": "CAMPIONI!"}.get(esito, "Stagione finita")
	var nomi := D.div_names()
	corpo.add_child(U.spazio(maxf(0.0, get_viewport_rect().size.y * 0.09 - 12.0)))
	if esito != "down":
		var coppa := MenuDisegno.nuovo(I.coppa(), Vector2(64, 64), Vector2(96, 96))
		coppa.ombra = Color(1, 0.851, 0.239, 0.25)
		coppa.ombra_sposta = Vector2(0, 8)
		coppa.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		corpo.add_child(coppa)
	corpo.add_child(U.testo(titolo_t, 32, T.TXT, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER))
	var div_ora: String = nomi[clampi(int(r.get("div", 2)), 0, 2)]
	var div_nuova: String = nomi[clampi(int(r.get("newDiv", 2)), 0, 2)]
	var premio := D.fmt_money(float(r.get("prize", 0)) + float(r.get("bonus", 0)))
	for t: String in ["Hai chiuso al <b>%d° posto</b> in %s." % [int(r.get("pos", 1)), div_ora],
			"Premio di fine stagione: <b>%s</b>" % premio,
			"La prossima stagione giochi in <b>%s</b>. I giocatori hanno un anno in più: controlla la rosa e il mercato." % div_nuova]:
		var p := U.bb("[center]%s[/center]" % U.html_a_bbcode(t), 16.5, Color("#d7e1f3"))
		corpo.add_child(p)
	corpo.add_child(U.spazio(4))
	corpo.add_child(U.bottone("AVANTI", "BtnGrande", func() -> void: vai("hub")))
