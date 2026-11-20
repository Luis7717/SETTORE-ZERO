# Amichevole (friendly() di src/ui.js): tre avversari (facile 46, medio 58, forte 72) con i pallini del livello.
# Non conta per il campionato e non cambia i soldi.
extends MenuSchermata

const AVVERSARI := [[46, "Avversario facile", 1], [58, "Avversario medio", 2], [72, "Avversario forte", 3]]


func prepara() -> void:
	titolo = "Amichevole"


func costruisci() -> void:
	corpo.add_child(U.paragrafo("Partita di prova: non conta per il campionato e non cambia i soldi.", 13.5))
	for a: Array in AVVERSARI:
		var b := U.bottone("", "", gioca.bind("amichevole", a[0]), 56)
		var h := U.hbox(8)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 18
		h.offset_right = -18
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(U.corto(a[1], 16, T.TXT, T.PESO_FORTE))
		var lv := U.hbox(4)
		lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for i in range(1, 4):
			var pal := U.pannello_stile(T.stile(T.GOLD if i <= a[2] else Color(1, 1, 1, 0.15), 5, Color(0, 0, 0, 0), 0, Vector4.ZERO))
			pal.custom_minimum_size = Vector2(9, 9)
			lv.add_child(pal)
		h.add_child(lv)
		b.add_child(h)
		corpo.add_child(b)
