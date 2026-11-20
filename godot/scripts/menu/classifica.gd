# Classifica (table() di src/ui.js): una scheda per divisione, righe con posto, stemma, nome, G V N P DR PT;
# la mia squadra in giallo, a sinistra verde chi sale (o vince il titolo) e rosso chi scende; legenda sotto.
extends MenuSchermata

const COLONNE := ["G", "V", "N", "P", "DR", "PT"]
const LARGHEZZA_NUM := 26.0

var divisione: Variant = null


func prepara() -> void:
	titolo = "Classifica"
	if arg is Dictionary and arg.has("div"):
		divisione = int(arg.div)


func costruisci() -> void:
	var c := carriera()
	if stato().is_empty():
		return
	var d: int = c.div() if divisione == null else divisione
	var chips := U.hbox(8)
	var nomi := D.div_names()
	for i in nomi.size():
		chips.add_child(U.chip(str(nomi[i]).split(" ")[0], i == d, _scheda.bind(i)))
	corpo.add_child(chips)

	var tab := U.vbox(5)
	tab.add_child(_riga_titoli())
	var righe: Array = c.table(d)
	for i in righe.size():
		tab.add_child(_riga(righe[i], i, d))
	corpo.add_child(tab)

	var leg := U.hbox(14)
	leg.add_child(_voce(T.GOOD, "Promozione" if d > 0 else "Titolo"))
	if d < 2:
		leg.add_child(_voce(T.BAD, "Retrocessione"))
	corpo.add_child(leg)
	var nota := ("Le prime due salgono di divisione. " if d > 0 else "La prima vince il titolo. ") + ("Le ultime due retrocedono." if d < 2 else "")
	corpo.add_child(U.paragrafo(nota, 13.5))


func _scheda(i: int) -> void:
	divisione = i
	ridisegna()


func _riga_titoli() -> Control:
	var h := U.hbox(0)
	h.add_child(U.spazio(0, 34))
	h.add_child(U.corto("SQUADRA", 10.5, T.DIM, T.PESO_NERO))
	for k: String in COLONNE:
		var l := U.testo(k, 10.5, T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = LARGHEZZA_NUM + (8.0 if k == "PT" else 0.0)
		h.add_child(l)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_right", 4)
	m.add_child(h)
	return m


func _riga(r: Dictionary, i: int, d: int) -> Control:
	var c := carriera()
	var me: bool = r.id == "me"
	var su := (i < 2 and d > 0) or (i == 0 and d == 0)
	var giu := i >= 8 and d < 2
	var p := U.pannello("RigaTabMe" if me else "RigaTab")
	p.custom_minimum_size.y = 46
	var h := U.hbox(0)
	p.add_child(h)
	var testo_col := T.GOLD if me else T.TXT
	var pos := U.testo(str(i + 1), 13.5, T.GOLD if me else T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
	pos.custom_minimum_size.x = 34
	h.add_child(pos)
	var tm: Dictionary = c.team(r.id)
	var nome := U.hbox(8)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var k := D.kit(tm.get("kit", 0))
	nome.add_child(MenuStemma.nuovo(c.teamCrest(tm), int(k[1]), int(k[2]), Vector2(22, 26)))
	nome.add_child(U.corto(str(tm.name), 14, testo_col, T.PESO_NERO if me else T.PESO_MEDIO))
	h.add_child(nome)
	var dr: int = int(r.gf) - int(r.ga)
	var vals := [r.p, r.w, r.d, r.l, ("+%d" % dr) if dr > 0 else str(dr), r.pts]
	for j in vals.size():
		var ultimo := j == vals.size() - 1
		var l := U.testo(str(vals[j]), 13.5 if not ultimo else 14, testo_col, T.PESO_NERO if (ultimo or me) else T.PESO_MEDIO, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = LARGHEZZA_NUM + (8.0 if ultimo else 0.0)
		h.add_child(l)
	if su or giu:
		var segno := Control.new()
		segno.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := T.GOOD if su else T.BAD
		segno.draw.connect(func() -> void: MenuUi._rett_tondo(segno, Rect2(0, 0, 4, segno.size.y), 2, col))
		p.add_child(segno)
	return p


func _voce(col: Color, t: String) -> Control:
	var h := U.hbox(6)
	var q := U.pannello_stile(T.stile(col, 3, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	q.custom_minimum_size = Vector2(10, 10)
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(q)
	h.add_child(U.testo(t, 12.5, T.DIM, T.PESO_MEDIO))
	return h
