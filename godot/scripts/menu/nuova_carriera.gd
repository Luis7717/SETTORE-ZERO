# Nuova carriera (title('new') di src/ui.js): nome della squadra, colori della maglia (10 maglie) con lo stemma
# che cambia coi colori; "Avanti" apre l'editor (stemma e poi campione). La carriera si crea solo alla fine,
# nell'editor (come il web): "Annulla" non tocca quella salvata.
extends MenuSchermata

const I := preload("res://scripts/menu/icone.gd")
const P := preload("res://scripts/menu/principale.gd")
const NOME_MAX := 18
const NOME_PREDEFINITO := "FC Tiro a Giro"

var kit := 0
var nome := ""
var _campo_nome: LineEdit


func prepara() -> void:
	con_testata = false
	if arg is Dictionary:
		kit = int(arg.get("kit", 0))
		nome = str(arg.get("club", ""))


func kit_scelto() -> int:
	return kit


func costruisci() -> void:
	var ha := not stato().is_empty()
	var hero := U.vbox(0)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	var palla := MenuDisegno.nuovo(I.pallone(), Vector2(64, 64), Vector2(46, 46))
	palla.ombra = Color(0, 0, 0, 0.5)
	palla.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.add_child(U.spazio(10))
	hero.add_child(palla)
	hero.add_child(U.spazio(8))
	hero.add_child(P.logo(40))
	hero.add_child(U.spazio(6))
	corpo.add_child(hero)

	var carta := U.pannello("Carta")
	var v := U.vbox(10)
	carta.add_child(v)
	var testa := U.hbox(14)
	var k: Array = D.kit(kit)
	testa.add_child(MenuStemma.nuovo(D.crest_from_seed(kit * 7 + 3), int(k[1]), int(k[2]), Vector2(52, 62)))
	testa.add_child(U.paragrafo("Crea la tua squadra e parti dalla Terza Divisione.", 15, T.DIM, T.PESO_MEDIO))
	v.add_child(testa)
	v.add_child(_etichetta("NOME DELLA TUA SQUADRA"))
	_campo_nome = LineEdit.new()
	_campo_nome.max_length = NOME_MAX
	_campo_nome.placeholder_text = "es. Atletico Sole"
	_campo_nome.text = nome
	_campo_nome.custom_minimum_size.y = 54
	_campo_nome.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_campo_nome.text_changed.connect(func(t: String) -> void: nome = t)
	_campo_nome.text_submitted.connect(func(_t: String) -> void: _campo_nome.release_focus())
	v.add_child(_campo_nome)
	v.add_child(U.spazio(4))
	var col := U.hbox(6)
	col.add_child(_etichetta("COLORI"))
	col.add_child(U.riempi())
	col.add_child(U.testo(str(k[0]), 13, T.TXT, T.PESO_NERO))
	v.add_child(col)
	var g := U.griglia(5, 8, 8)
	for i in D.kits().size():
		var kk: Array = D.kits()[i]
		var b := U.bottone("", "KitOn" if i == kit else "Kit", _scegli_kit.bind(i), 0)
		b.tooltip_text = str(kk[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(44, 0)
		var m := MenuDisegno.nuovo(I.maglia(kk), Vector2(40, 40), Vector2.ZERO)
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.offset_left = 6
		m.offset_top = 6
		m.offset_right = -6
		m.offset_bottom = -6
		m.ombra = Color(0, 0, 0, 0.5)
		m.ombra_sposta = Vector2(0, 2)
		b.add_child(m)
		b.resized.connect(func() -> void: b.custom_minimum_size.y = b.size.x)
		g.add_child(b)
	v.add_child(g)
	corpo.add_child(carta)
	corpo.add_child(U.spazio(4))
	corpo.add_child(U.bottone("AVANTI: STEMMA E CAMPIONE", "BtnGrande", _avanti))
	if ha:
		corpo.add_child(U.bottone("Annulla", "BtnFantasma", func() -> void: vai("hub")))
		var n := U.paragrafo("Una nuova carriera sostituisce quella salvata.", 13.5)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		corpo.add_child(n)


func _etichetta(t: String) -> Label:
	return U.testo(t, 12, T.DIM, T.PESO_FORTE)


func _scegli_kit(i: int) -> void:
	kit = i
	ridisegna()


func _avanti() -> void:
	var n := nome.strip_edges().substr(0, NOME_MAX)
	if n == "":
		n = NOME_PREDEFINITO
	vai("editor", {"flow": "new", "club": n, "kit": kit})
