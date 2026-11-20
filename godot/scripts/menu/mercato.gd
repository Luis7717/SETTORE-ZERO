# Mercato (market() di src/ui.js): filtri per ruolo, giocatori in vendita ordinati per valutazione; un tocco apre
# la scheda col prezzo e "Compra" (secondo tocco = conferma). Per vendere si va nella Rosa.
extends MenuSchermata

const FILTRI := [["T", "Tutti"], ["P", "POR"], ["D", "DIF"], ["C", "CEN"], ["A", "ATT"]]

var filtro := "T"
var aperto: Variant = null       # id del giocatore con la scheda aperta
var _conferma: Variant = null


func prepara() -> void:
	titolo = "Mercato"
	if arg is Dictionary:
		filtro = str(arg.get("filtro", "T"))
		var a: Variant = arg.get("aperto")
		if a is int:
			var l := _lista()
			if a < l.size():
				aperto = l[a].id


func _lista() -> Array:
	var s := stato()
	var l: Array = s.market.filter(func(p: Dictionary) -> bool: return filtro == "T" or p.pos == filtro)
	l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return D.overall(a) > D.overall(b))
	return l


func costruisci() -> void:
	var s := stato()
	if s.is_empty():
		return
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for fk: Array in FILTRI:
		chips.add_child(U.chip(fk[1], filtro == fk[0], _filtra.bind(fk[0])))
	corpo.add_child(chips)
	corpo.add_child(U.ricco("Rosa: %d/24. Ogni giornata arrivano giocatori nuovi. Per vendere vai in <b>Rosa</b> e tocca un giocatore." % s.squad.size(), 13.5, T.NOTE, false))
	var righe := U.vbox(7)
	for p: Dictionary in _lista():
		righe.add_child(_riga(p, s))
		if aperto == p.id:
			righe.add_child(scheda(p, _bottone_compra(p, s)))
	corpo.add_child(righe)


func _filtra(f: String) -> void:
	filtro = f
	ridisegna()


func _riga(p: Dictionary, s: Dictionary) -> Control:
	var o := D.overall(p)
	var b := U.bottone("", "RigaSel" if aperto == p.id else "Riga", _apri.bind(p.id), 56)
	var h := U.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(U.ruolo(p.pos, D.pos_name(p.pos)))
	h.add_child(U.corto(str(p.name), 15.5, T.TXT, T.PESO_FORTE))
	h.add_child(U.testo("%da" % int(p.age), 12.5, T.DIM, T.PESO_MEDIO))
	h.add_child(U.valutazione(o, D.ovr_cls(o)))
	var puo: bool = s.money >= p.price
	var prezzo := U.testo(D.fmt_money(p.price), 13.5, T.GOOD if puo else Color("#ff9aa0"), T.PESO_NERO, HORIZONTAL_ALIGNMENT_RIGHT)
	prezzo.custom_minimum_size.x = 62
	h.add_child(prezzo)
	b.add_child(h)
	return b


func _apri(id: Variant) -> void:
	aperto = null if aperto == id else id
	_conferma = null
	ridisegna()


func _bottone_compra(p: Dictionary, s: Dictionary) -> Control:
	if s.money < p.price:
		return U.paragrafo("Non hai abbastanza soldi.", 13.5)
	var b := U.bottone("Compra per %s" % D.fmt_money(p.price), "", Callable(), 46)
	b.pressed.connect(func() -> void:
		if U.al_tocco.is_valid():
			U.al_tocco.call()
		if _conferma != p.id:
			_conferma = p.id
			b.text = "Conferma"
			b.theme_type_variation = "BtnAvviso"
			return
		var err: Variant = carriera().buy(p.id)
		_conferma = null
		aperto = null
		toast(str(err) if err != null else "Acquistato!"))
	return b


## scheda di un giocatore (pcard del web): nome, ruolo, età, valore, statistiche con le barre, pulsante sotto
static func scheda(p: Dictionary, sotto: Control) -> Control:
	var pann := MenuUi.pannello("Pannello")
	var v := MenuUi.vbox(12)
	pann.add_child(v)
	var testa := MenuUi.vbox(4)
	testa.add_child(MenuUi.testo(str(p.name), 18, MenuTema.TXT, MenuTema.PESO_NERO))
	var info := "%s · %d anni · valore %s" % [MenuDati.pos_name(p.pos), int(p.age), MenuDati.fmt_money(MenuDati.value(p))]
	if p.get("num") != null:
		info += " · n. %d" % int(p.num)
	if int(p.get("apps", 0)) > 0:
		info += " · %d pres. %d gol" % [int(p.apps), int(p.get("goals", 0))]
	testa.add_child(MenuUi.paragrafo(info, 12.5, MenuTema.DIM, MenuTema.PESO_MEDIO))
	v.add_child(testa)
	var g := MenuUi.griglia(4, 8, 8)
	for kn: Array in (MenuDati.GK_STATS if p.pos == "P" else MenuDati.STATS):
		var val := MenuDati.stat_of(p, kn[0])
		var cls := MenuDati.ovr_cls(val)
		var cella := MenuUi.pannello("Stat")
		cella.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := MenuUi.vbox(6)
		var r := MenuUi.hbox(2)
		r.add_child(MenuUi.testo(kn[1], 10.5, MenuTema.DIM, MenuTema.PESO_NERO))
		r.add_child(MenuUi.riempi())
		r.add_child(MenuUi.testo(str(val), 18, MenuTema.TXT, MenuTema.PESO_NERO))
		cv.add_child(r)
		cv.add_child(MenuUi.barra(maxf(6.0, minf(100.0, val)) / 100.0, 5.0, MenuTema.STAT[cls]))
		cella.add_child(cv)
		g.add_child(cella)
	v.add_child(g)
	if sotto != null:
		v.add_child(sotto)
	return pann
