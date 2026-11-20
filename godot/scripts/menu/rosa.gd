# Rosa stile FUT (squad() di src/ui.js e src/ui-squad.js): schermata ferma con in alto le formazioni (o il
# pannello del giocatore scelto, o il confronto tra due giocatori), il campo visto dall'alto con le carte degli
# 11 titolari ai posti della formazione e la panchina che scorre di lato.
# Tocchi (MenuRosa.pick_card): uno sceglie, un secondo giocatore scambiabile apre il confronto, toccarlo ancora
# (o "Scambia") li scambia; i badge verdi/rossi dicono quanto cambia la squadra con lo scambio.
extends MenuSchermata

const Rosa := preload("res://scripts/menu/rosa_logica.gd")
const Carta := preload("res://scripts/menu/carta_giocatore.gd")
const C := preload("res://sim/core.gd")
const ALTEZZA_SOPRA := 150.0       # .sqtop
const RIGA_CAMPO := Color(1, 1, 1, 0.11)

var sel: Variant = null
var tgt: Variant = null
var just: Variant = null
var _vendi_ok: Variant = null      # id del giocatore con "Conferma vendita" già mostrato
var _campo: Control
var _carte_campo: Array = []
var _panchina: ScrollContainer
var _scorri_panchina := 0
var _colori: Array = ["#c8102e", "#ffffff"]
var _k1 := 0
var _rate := func(p: Dictionary, r: String) -> int: return D.overall_as(p, r)


func prepara() -> void:
	titolo = "Rosa"
	ferma = true
	if arg is Dictionary:
		sel = arg.get("sel")
		tgt = arg.get("tgt")


func costruisci() -> void:
	var c := carriera()
	var s := stato()
	if s.is_empty():
		return
	var k := D.kit(s.kit)
	_k1 = int(k[1])
	_colori = [D.hex(int(k[1])), D.hex(int(k[2]))]
	var F: Array = C.FORMATIONS[s.formation]
	var sp: Variant = c.player(sel) if sel != null else null
	if sp == null:
		sel = null
	var tp: Variant = c.player(tgt) if sp != null and tgt != null else null
	corpo.add_theme_constant_override("separation", 8)

	var sopra := Control.new()
	sopra.custom_minimum_size.y = ALTEZZA_SOPRA
	sopra.mouse_filter = Control.MOUSE_FILTER_PASS
	var pannello: Control
	if tp != null:
		pannello = _confronto(sp, tp, F)
	elif sp != null:
		pannello = _pannello_giocatore(sp, F)
	else:
		pannello = _controlli()
	pannello.set_anchors_preset(Control.PRESET_FULL_RECT)
	sopra.add_child(pannello)
	corpo.add_child(sopra)

	# campo
	var fm := MarginContainer.new()
	fm.add_theme_constant_override("margin_left", -10)
	fm.add_theme_constant_override("margin_right", -10)
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.mouse_filter = Control.MOUSE_FILTER_PASS
	_campo = Control.new()
	_campo.mouse_filter = Control.MOUSE_FILTER_PASS
	_campo.draw.connect(_disegna_campo)
	_campo.resized.connect(_disponi_carte)
	fm.add_child(_campo)
	corpo.add_child(fm)
	_carte_campo = []
	for i in s.lineup.size():
		var p: Variant = c.player(s.lineup[i])
		if p == null:
			_carte_campo.append(null)
			continue
		var carta := _carta(p, F[i][0], sp, F)
		_campo.add_child(carta)
		_carte_campo.append(carta)

	# panchina
	var bench: Array = Rosa.bench_order(c.bench())
	var lbl := U.hbox(6)
	lbl.add_child(U.testo("PANCHINA", 11.5, T.DIM, T.PESO_NERO))
	lbl.add_child(U.testo(str(bench.size()), 11.5, T.TXT, T.PESO_NERO))
	lbl.add_child(U.riempi())
	lbl.add_child(U.testo("Rosa %d/24" % s.squad.size(), 11.5, T.DIM, T.PESO_FORTE))
	corpo.add_child(lbl)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left", -16)
	bm.add_theme_constant_override("margin_right", -16)
	bm.mouse_filter = Control.MOUSE_FILTER_PASS
	_panchina = ScrollContainer.new()
	_panchina.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panchina.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_panchina.custom_minimum_size.y = Carta.H + 10
	_panchina.scroll_deadzone = 6
	_panchina.mouse_filter = Control.MOUSE_FILTER_PASS
	var riga := U.hbox(6)
	riga.add_child(U.spazio(0, 10))
	for p: Dictionary in bench:
		var box := Control.new()
		box.custom_minimum_size = Vector2(Carta.W, Carta.H + 8)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var carta := _carta(p, "", sp, F)
		carta.position = Vector2(0, 3)
		box.add_child(carta)
		riga.add_child(box)
	riga.add_child(U.spazio(0, 10))
	_panchina.add_child(riga)
	bm.add_child(_panchina)
	corpo.add_child(bm)
	_rimetti_panchina.call_deferred(_scorri_panchina)


func _carta(p: Dictionary, slot_pos: String, sp: Variant, F: Array) -> MenuCarta:
	var carta := Carta.new()
	carta.imposta(p, slot_pos, MenuFaccia.svg_tondo(D.look_of(p), _colori[0], _colori[1], MenuFaccia.fondo_di(_k1)), _delta(p, sp, F))
	carta.segna(sel == p.id, tgt == p.id, just is Array and (just as Array).has(p.id))
	carta.toccata.connect(_tocca)
	return carta


# badge sulla carta: quanto cambia la squadra scambiandola col giocatore scelto; si mostra per chi gioca nello
# stesso ruolo e per ogni scambio che migliora (gli scambi assurdi, attaccante in porta, no)
func _delta(p: Dictionary, sp: Variant, F: Array) -> Variant:
	var s := stato()
	if sp == null or p.id == sp.id or not Rosa.can_swap(s.lineup, sp.id, p.id):
		return null
	var d := Rosa.swap_delta(s.lineup, F, sp, p, _rate)
	return d if d > 0 or _ruolo_ora(p, F) == _ruolo_ora(sp, F) else null


func _ruolo_ora(p: Dictionary, F: Array) -> String:
	var i: int = stato().lineup.find(p.id)
	return F[i][0] if i >= 0 else str(p.pos)


# ruolo e valutazione dove sta adesso (posto in campo o panchina)
func _posto(p: Dictionary, F: Array) -> Dictionary:
	var i: int = stato().lineup.find(p.id)
	if i >= 0:
		return {"role": F[i][0], "o": D.overall_as(p, F[i][0]), "where": D.pos_name(F[i][0])}
	return {"role": p.pos, "o": D.overall(p), "where": "Panchina"}


func _disponi_carte() -> void:
	var s := stato()
	if s.is_empty() or _campo == null:
		return
	var L := Rosa.field_layout(C.FORMATIONS[s.formation], _campo.size.x, _campo.size.y)
	for i in _carte_campo.size():
		var carta: Control = _carte_campo[i]
		if carta == null:
			continue
		var pos: Vector2 = L.cards[i]
		carta.position = pos - Vector2(L.w, L.h) / 2.0
		carta.scale = Vector2.ONE * L.scale
	_campo.set_meta("scala", L.scale)


func _rimetti_panchina(x: int) -> void:
	if _panchina != null and is_instance_valid(_panchina):
		await get_tree().process_frame
		if is_instance_valid(_panchina):
			_panchina.scroll_horizontal = x


# campo: strisce, sfumatura verde scura, righe bianche leggere (.field e .fl del web)
func _disegna_campo() -> void:
	var w := _campo.size.x
	var h := _campo.size.y
	var sb := T.stile(Color("#0b2419"), 16, T.LINE, 1, Vector4.ZERO)
	_campo.draw_style_box(sb, Rect2(0, 0, w, h))
	var a := Color("#123526")
	_campo.draw_polygon(PackedVector2Array([Vector2(2, 2), Vector2(w - 2, 2), Vector2(w - 2, h * 0.7), Vector2(2, h * 0.7)]),
		PackedColorArray([a, a, Color(a, 0), Color(a, 0)]))
	var passo := h * 0.22
	var y := 0.0
	while y < h - 2.0:
		_campo.draw_rect(Rect2(2, maxf(2.0, y), w - 4, minf(passo * 0.5, h - 2.0 - y)), Color(1, 1, 1, 0.027))
		y += passo
	var r := Rect2(6, 6, w - 12, h - 12)
	var linee := T.stile(Color(0, 0, 0, 0), 6, RIGA_CAMPO, 1, Vector4.ZERO)
	linee.draw_center = false
	linee.set_border_width_all(2)
	_campo.draw_style_box(linee, r)
	_campo.draw_line(Vector2(r.position.x, h / 2.0), Vector2(r.end.x, h / 2.0), RIGA_CAMPO, 1.5, true)
	_campo.draw_arc(Vector2(w / 2.0, h / 2.0), 38.0, 0.0, TAU, 48, RIGA_CAMPO, 1.5, true)
	var bw := r.size.x * 0.52
	var bh := r.size.y * 0.12
	var bx := r.position.x + r.size.x * 0.24
	_campo.draw_polyline(PackedVector2Array([Vector2(bx, r.position.y), Vector2(bx, r.position.y + bh), Vector2(bx + bw, r.position.y + bh), Vector2(bx + bw, r.position.y)]), RIGA_CAMPO, 1.5, true)
	_campo.draw_polyline(PackedVector2Array([Vector2(bx, r.end.y), Vector2(bx, r.end.y - bh), Vector2(bx + bw, r.end.y - bh), Vector2(bx + bw, r.end.y)]), RIGA_CAMPO, 1.5, true)


# ---------------------------------------------------------------- tocchi
func _tocca(id: Variant) -> void:
	if U.al_tocco.is_valid():
		U.al_tocco.call()
	var c := carriera()
	var s := stato()
	var nuovo := Rosa.pick_card({"sel": sel, "tgt": tgt}, s.lineup, id, func(x: Variant) -> bool: return c.player(x) != null)
	if nuovo.swap != null:
		c.swap(nuovo.swap[0], nuovo.swap[1])
	sel = nuovo.sel
	tgt = nuovo.tgt
	just = nuovo.just
	_vendi_ok = null
	_aggiorna()


func _aggiorna() -> void:
	_scorri_panchina = _panchina.scroll_horizontal if _panchina != null and is_instance_valid(_panchina) else 0
	ridisegna()


func _scambia() -> void:
	if sel != null and tgt != null:
		_tocca(tgt)


func _chiudi() -> void:
	sel = null
	tgt = null
	just = null
	_aggiorna()


func _formazione(f: String) -> void:
	var c := carriera()
	stato().formation = f
	c.autoLineup()
	salva()
	_chiudi()


func _migliori() -> void:
	carriera().autoLineup()
	salva()
	_chiudi()


func _vendi(id: Variant, b: Button) -> void:
	if _vendi_ok != id:
		_vendi_ok = id
		b.text = "Conferma vendita"
		b.theme_type_variation = "BtnAvviso"
		return
	var err: Variant = carriera().sell(id)
	sel = null
	tgt = null
	just = null
	_vendi_ok = null
	_scorri_panchina = 0
	if err != null:
		toast(str(err))
	else:
		ridisegna()


# ---------------------------------------------------------------- pannelli in alto
func _controlli() -> Control:
	var s := stato()
	var v := U.vbox(8)
	var g := U.griglia(4, 6, 6)
	for f: String in C.FORMATIONS:
		var b := U.chip(f, f == s.formation, _formazione.bind(f))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	v.add_child(g)
	var info := U.hbox(10)
	var forza := U.bb("[font_size=13]Forza squadra [/font_size][font_size=20][color=#ffd93d][b]%d[/b][/color][/font_size]" % int(carriera().myRating()), 13, T.DIM)
	forza.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(forza)
	var best := U.bottone("Migliori 11", "Chip", _migliori)
	best.add_theme_stylebox_override("normal", T.stile(T.PANEL2, 999, T.LINE2, 1, Vector4(16, 10, 16, 10)))
	info.add_child(best)
	v.add_child(info)
	v.add_child(U.paragrafo("Tocca un giocatore per vederlo, poi un altro per confrontarli e scambiarli.", 12.5))
	return v


func _pannello_giocatore(p: Dictionary, F: Array) -> Control:
	var c := carriera()
	var at := _posto(p, F)
	var pann := U.pannello("PannelloRosa")
	var v := U.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pann.add_child(v)
	var testa := U.hbox(9)
	testa.add_child(MenuFaccia.nuovo(D.look_of(p), _colori[0], _colori[1], 40, _k1))
	var nm := U.vbox(2)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_child(U.corto(str(p.name), 16, T.TXT, T.PESO_NERO))
	var info := D.pos_name(p.pos)
	if at.where != D.pos_name(p.pos):
		info += " · in campo %s" % at.where
	info += " · %d anni · %s" % [int(p.age), D.fmt_money(D.value(p))]
	if p.get("num") != null:
		info += " · n. %d" % int(p.num)
	nm.add_child(U.corto(info, 11.5, T.DIM, T.PESO_MEDIO))
	testa.add_child(nm)
	testa.add_child(U.valutazione(at.o, D.ovr_cls(at.o)))
	var x := U.bottone("×", "Chiudi", _chiudi, 38)
	x.custom_minimum_size.x = 38
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	testa.add_child(x)
	v.add_child(testa)
	v.add_child(U.riempi())
	var keys: Array = D.GK_STATS if p.pos == "P" else D.STATS
	var g := U.griglia(keys.size(), 4, 4)
	for kn: Array in keys:
		var val := D.stat_of(p, kn[0])
		var cella := U.pannello("StatPiccola")
		cella.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := U.vbox(0)
		cv.add_child(U.testo(kn[1], 9.5, T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(U.testo(str(val), 15, T.STAT[D.ovr_cls(val)], 900, HORIZONTAL_ALIGNMENT_CENTER))
		cella.add_child(cv)
		g.add_child(cella)
	v.add_child(g)
	v.add_child(U.riempi())
	var bt := U.griglia(2, 8, 8)
	var asp := U.bottone("Aspetto", "", func() -> void: vai("editor", {"flow": "look", "id": p.id}), 44)
	asp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.add_child(asp)
	var vendi := U.bottone("Vendi per %s" % D.fmt_money(c.sellPrice(p)), "BtnFantasma", Callable(), 44)
	vendi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vendi.pressed.connect(func() -> void:
		if U.al_tocco.is_valid():
			U.al_tocco.call()
		_vendi(p.id, vendi))
	bt.add_child(vendi)
	v.add_child(bt)
	return pann


# confronto: valori di a (scelto) e b (toccato), verde chi è meglio, rosso chi è peggio
func _confronto(a: Dictionary, b: Dictionary, F: Array) -> Control:
	var s := stato()
	var pa := _posto(a, F)
	var pb := _posto(b, F)
	var keys: Array = D.STATS
	if a.pos == "P" or b.pos == "P":
		keys = [["por", "POR"]] + D.STATS.filter(func(kn: Array) -> bool: return kn[0] != "tes")
	var ora := 0
	for i in s.lineup.size():
		var p: Variant = carriera().player(s.lineup[i])
		ora += D.overall_as(p, F[i][0]) if p != null else 30
	var dopo := ora + Rosa.swap_delta(s.lineup, F, a, b, _rate)
	var r_ora := D._round_js(ora / 11.0)
	var r_dopo := D._round_js(dopo / 11.0)
	var pann := U.pannello("PannelloRosa")
	var v := U.vbox(0)
	pann.add_child(v)
	var testa := U.hbox(6)
	testa.add_child(_lato(a, pa, false))
	testa.add_child(U.testo("⇄", 18, T.GOLD, 900))
	testa.add_child(_lato(b, pb, true))
	v.add_child(testa)
	v.add_child(U.riempi())
	var tab := U.pannello("Riquadro")
	var g := U.griglia(keys.size() + 1, 2, 1)
	tab.add_child(g)
	g.add_child(U.spazio(0, 12))
	for kn: Array in keys:
		g.add_child(U.testo(kn[1], 9.5, T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER))
	for riga in 2:
		var x: Dictionary = a if riga == 0 else b
		var y: Dictionary = b if riga == 0 else a
		g.add_child(_pallino(riga == 1))
		for kn: Array in keys:
			var vx := D.stat_of(x, kn[0])
			var vy := D.stat_of(y, kn[0])
			var col := T.GOOD if vx > vy else (T.BAD if vx < vy else Color("#dbe4f3"))
			var l := U.testo(str(vx), 14, col, 900, HORIZONTAL_ALIGNMENT_CENTER)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(l)
	v.add_child(tab)
	v.add_child(U.riempi())
	var basso := U.hbox(8)
	var col_dopo := "#4aeb9f" if r_dopo > r_ora else ("#ff7079" if r_dopo < r_ora else "#ffd93d")
	var f := U.bb("Forza %d → [font_size=20][color=%s][b]%d[/b][/color][/font_size]" % [r_ora, col_dopo, r_dopo], 13, T.DIM)
	f.size_flags_horizontal = Control.SIZE_FILL
	f.autowrap_mode = TextServer.AUTOWRAP_OFF
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	basso.add_child(f)
	var ann := U.bottone("Annulla", "BtnFantasma", _chiudi, 44)
	ann.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basso.add_child(ann)
	var sc := U.bottone("Scambia", "BtnVai", _scambia, 44)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 1.25
	basso.add_child(sc)
	v.add_child(basso)
	return pann


func _lato(p: Dictionary, at: Dictionary, destra: bool) -> Control:
	var h := U.hbox(7)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.alignment = BoxContainer.ALIGNMENT_END if destra else BoxContainer.ALIGNMENT_BEGIN
	var faccia := MenuFaccia.nuovo(D.look_of(p), _colori[0], _colori[1], 32, _k1)
	var nv := U.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := U.corto(Rosa.short_name(p.name), 14, T.TXT, T.PESO_NERO)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if destra else HORIZONTAL_ALIGNMENT_LEFT
	nv.add_child(n)
	var col := MenuTema.STAT[D.ovr_cls(at.o)]
	var pallino := "[color=#cfe0ff]●[/color]" if destra else "[color=#ffd93d]●[/color]"
	var riga := U.bb("%s%s %s [color=#%s][b]%d[/b][/color]%s" % ["[right]" if destra else "", pallino, at.where, col.to_html(false), int(at.o), "[/right]" if destra else ""], 11, T.DIM)
	riga.autowrap_mode = TextServer.AUTOWRAP_OFF
	nv.add_child(riga)
	if destra:
		h.add_child(nv)
		h.add_child(faccia)
	else:
		h.add_child(faccia)
		h.add_child(nv)
	return h


func _pallino(b: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(12, 16)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: c.draw_circle(c.size / 2.0, 4.0, Color("#cfe0ff") if b else T.GOLD, true, -1.0, true))
	return c
