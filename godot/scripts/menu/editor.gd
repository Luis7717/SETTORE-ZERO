# Editor dello stemma, del campione, dell'aspetto di un giocatore e dello stile della divisa (src/editor.js).
# arg = {flow: "new" | "crest" | "look" | "kit", club, kit (flow new), id (flow look), mode, tab (per le prove)}.
# Modi: "crest" (stemma), "champ" (campione: viso, capelli, divisa, nome e ruolo), "look" (viso, capelli, scarpe di
# un giocatore della rosa), "kit" (stile della divisa). Nuova squadra: stemma → campione → Carriera.create, poi
# l'allenamento guidato. Sopra resta fisso il palco (stemma grande o giocatore 3D che gira), poi le schede, in
# mezzo le scelte che scorrono, in fondo Casuale e Avanti / Salva.
extends MenuSchermata

const Asp := preload("res://scripts/carriera/aspetto.gd")
const KIT_LABELS := {"fit": "Maglia", "sleeves": "Maniche", "collar": "Colletto", "pattern": "Motivo", "shorts": "Pantaloncini", "socks": "Calzettoni"}
const SCHEDE := {
	"crest": [["shape", "Forma"], ["pattern", "Motivo"], ["icon", "Simbolo"]],
	"champ": [["face", "Viso"], ["hair", "Capelli"], ["kit", "Divisa"], ["me", "Nome e ruolo"]],
	"look": [["face", "Viso"], ["hair", "Capelli"], ["boots", "Scarpe"]],
	"kit": [["kit", "Divisa"]],
}
const TITOLI := {"crest": "Lo stemma", "champ": "Crea il tuo campione", "look": "Aspetto", "kit": "Stile della divisa"}
const RUOLI := [["P", "Portiere"], ["D", "Difensore"], ["C", "Centrocampista"], ["A", "Attaccante"]]
const NUMERI_RAPIDI := [7, 9, 10, 11, 1, 4, 8, 99]
const GK_KIT := {"shirt": 0x27e0c0, "shorts": 0x0c5c52, "socks": 0x27e0c0}
const PALCO_ALTO := 0.38         # frazione dello schermo (min(38vh, 320px) del web)
const PALCO_MAX := 320.0
const PALCO_STEMMA := 0.34
const FACCIA := 76.0             # lato del viso disegnato nel palco

var flow := ""
var mode := ""
var tab := ""
var d: Dictionary = {}
var _palco: Control = null       # resta tra un ridisegno e l'altro (l'anteprima 3D non si ricrea)
var _anteprima: MenuAnteprima = null
var _faccia: MenuFaccia = null
var _stemma_grande: MenuStemma = null
var _cartellino: Label = null


func prepara() -> void:
	ferma = false
	soldi = false
	var a: Dictionary = arg if arg is Dictionary else {}
	flow = str(a.get("flow", "crest"))
	match flow:
		"new":
			_apri_nuova(str(a.get("club", "FC Tiro a Giro")), int(a.get("kit", 1)))
		"look":
			if not _apri_aspetto(a.get("id")):
				flow = "crest"
				_apri_stemma()
		"kit":
			_apri_divisa()
		_:
			_apri_stemma()
	if a.has("mode"):
		mode = str(a.mode)
		tab = SCHEDE[mode][0][0]
	if a.has("tab"):
		tab = str(a.tab)
	_titoli()


func _titoli() -> void:
	titolo = TITOLI[mode]
	pillola = ("1 di 2" if mode == "crest" else "2 di 2") if flow == "new" else ""


func _apri_nuova(club: String, kit: int) -> void:
	var seme := D.hash32([club, kit, Time.get_ticks_usec()])
	d = {"club": club, "kit": kit, "crest": D.crest_from_seed(seme), "style": D.normalize_kit_style(null),
		"look": D.look_from_seed(seme), "name": D.random_name(seme), "pos": "A", "num": 9}
	mode = "crest"
	tab = "shape"


func _apri_aspetto(id: Variant) -> bool:
	var c := carriera()
	var p: Variant = c.player(id) if c != null and id != null else null
	if not p is Dictionary:
		return false
	mode = "look"
	tab = "face"
	var s := stato()
	d = {"id": id, "kit": s.kit, "crest": c.crest(), "style": c.kitStyle(), "look": D.look_of(p), "name": p.name, "pos": p.pos, "num": p.get("num", 0)}
	return true


func _apri_divisa() -> void:
	var c := carriera()
	var s := stato()
	var p: Dictionary = s.squad[0]
	for q: Dictionary in s.squad:
		if q.get("champ", false):
			p = q
			break
	mode = "kit"
	tab = "kit"
	d = {"kit": s.kit, "crest": c.crest(), "style": c.kitStyle(), "look": D.look_of(p), "name": p.name, "pos": "A", "num": p.get("num", 0)}


func _apri_stemma() -> void:
	var c := carriera()
	var s := stato()
	mode = "crest"
	tab = "shape"
	d = {"kit": s.get("kit", 1), "crest": c.crest() if c != null else D.crest_from_seed(1), "club": s.get("club", "")}


func kit_scelto() -> int:
	return int(d.get("kit", 1))


func colori_squadra() -> Array:
	var k := D.kit(d.get("kit", 1))
	return [D.colore(int(k[1])), D.colore(int(k[2]))]


func torna_indietro() -> void:
	if flow == "new" and mode == "champ":
		mode = "crest"
		tab = "shape"
		_cambia_palco()
		return
	_esci("")


func _esci(m: String) -> void:
	MenuSchermata.prossimo_msg = m
	match flow:
		"new":
			vai("nuova_carriera", {"club": d.club, "kit": d.kit})
		"look":
			vai("rosa", {"sel": d.id})
		_:
			vai("impostazioni")


# ---------------------------------------------------------------- costruzione
func costruisci() -> void:
	if d.is_empty():
		return
	if _palco == null:
		_crea_palco()
	fisso_sopra.add_child(_palco)
	_aggiorna_palco()
	var schede: Array = SCHEDE[mode]
	if schede.size() > 1:
		fisso_sopra.add_child(_schede(schede))
	_pannello()
	fisso_sotto.add_child(_barra())


func _cambia_palco() -> void:
	if _palco != null:
		_palco.queue_free()
		_palco = null
		_anteprima = null
		_faccia = null
		_stemma_grande = null
	_titoli()
	mostra(true)
	if scorri != null:
		scorri.scroll_vertical = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _palco != null and is_instance_valid(_palco) and not _palco.is_inside_tree():
		_palco.free()


func _crea_palco() -> void:
	var vis := get_viewport_rect().size
	_palco = Control.new()
	_palco.set_meta("resta", true)
	_palco.clip_contents = true
	_palco.mouse_filter = Control.MOUSE_FILTER_PASS
	# sfondo: ellisse col colore della squadra (radial-gradient(70% 80% at 50% 38%, k1·45%, #0c1528 72%))
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER_SFONDO
	m.set_shader_parameter("centro", T.mix(colori_squadra()[0], 45, Color("#1d2c4b")))
	m.set_shader_parameter("mezzo", Color("#0c1528"))
	m.set_shader_parameter("bordo", Color("#0c1528"))
	m.set_shader_parameter("punto_mezzo", 0.72)
	m.set_shader_parameter("fuoco", Vector2(0.5, 0.38))
	m.set_shader_parameter("raggio", Vector2(0.7, 0.8))
	bg.material = m
	_palco.add_child(bg)
	var riga := ColorRect.new()
	riga.color = T.LINE
	riga.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	riga.offset_top = -1
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(riga)
	if mode == "crest":
		_palco.custom_minimum_size.y = minf(vis.y * PALCO_STEMMA, 290.0)
		var v := U.vbox(10)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := _palco.custom_minimum_size.y * 0.72 - 30.0
		_stemma_grande = MenuStemma.nuovo(d.crest, 0, 0, Vector2(h * 42.0 / 50.0, h))
		_stemma_grande.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(_stemma_grande)
		v.add_child(U.testo(str(d.get("club", "")), 18, T.TXT, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER))
		_palco.add_child(v)
		return
	_palco.custom_minimum_size.y = minf(vis.y * PALCO_ALTO, PALCO_MAX)
	_anteprima = MenuAnteprima.new()
	_anteprima.set_anchors_preset(Control.PRESET_FULL_RECT)
	_palco.add_child(_anteprima)
	# viso disegnato in alto a destra (come il web); il modello 3D mostra anche taglio, barba, sopracciglia e occhi
	var k := D.kit(d.kit)
	_faccia = MenuFaccia.nuovo(d.look, D.hex(int(k[1])), D.hex(int(k[2])), FACCIA, int(k[1]))
	_faccia.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_faccia.offset_left = -FACCIA - 12.0
	_faccia.offset_right = -12.0
	_faccia.offset_top = 10.0
	_faccia.offset_bottom = 10.0 + FACCIA
	_palco.add_child(_faccia)
	var tag := U.pannello_stile(T.stile(Color(0.039, 0.071, 0.141, 0.75), 999, T.LINE2, 1, Vector4(12, 5, 12, 5)))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tag.offset_left = 12.0
	tag.offset_bottom = -10.0
	tag.offset_top = -10.0
	_cartellino = U.testo("", 13, T.TXT, T.PESO_FORTE)
	tag.add_child(_cartellino)
	_palco.add_child(tag)


func _aggiorna_palco() -> void:
	var k := D.kit(d.kit)
	if _stemma_grande != null:
		_stemma_grande.crest = d.crest
		_stemma_grande.c1 = int(k[1])
		_stemma_grande.c2 = int(k[2])
		return
	if _anteprima == null:
		return
	_cartellino.text = "%s · %s" % [d.name, str(d.num) if int(d.num) > 0 else ""]
	_anteprima.vicino = tab == "face" or tab == "hair"
	_anteprima.metti(_kit_figura(), _aspetto_figura())
	_faccia.look = d.look
	var gk: bool = d.pos == "P"
	_faccia.maglia = D.hex(GK_KIT.shirt if gk else int(k[1]))
	_faccia.colletto = D.hex(GK_KIT.shorts if gk else int(k[2]))
	_faccia.queue_redraw()


# colori e stile per Figura (kitFor del web: il portiere ha la sua divisa, maniche lunghe, tinta unita e girocollo).
# Niente numero né cognome sulla schiena (numero.z = 0): nella partita li disegna l'atlante di schiene.gd.
func _kit_figura() -> Dictionary:
	var k := D.kit(d.kit)
	var gk: bool = d.pos == "P"
	var kit: Dictionary = GK_KIT if gk else {"shirt": int(k[1]), "shorts": int(k[2]), "socks": int(k[1])}
	var st: Dictionary = D.normalize_kit_style(d.get("style"))
	if gk:
		st.sleeves = 1
		st.pattern = 0
		st.collar = 0
	return {"maglia": D.colore(kit.shirt), "calzoncini": D.colore(kit.shorts), "calzettoni": D.colore(kit.socks),
		"bordino": D.colore(kit.shorts), "stile": Asp.stile_figura(st), "numero": Vector4(0, 0, 0, st.fit)}


# pelle, capelli, occhi, scarpe e taglio, barba, sopracciglia: come la figura in partita (Aspetto.parametri_figura)
func _aspetto_figura() -> Dictionary:
	return Asp.parametri_figura(d.look, d.get("style"))


func _schede(schede: Array) -> Control:
	var fondo := U.pannello_stile(T.stile(Color("#0a1224"), 0, Color(0, 0, 0, 0), 0, Vector4(16, 8, 16, 8)))
	var h := U.hbox(6)
	for sk: Array in schede:
		var b := U.bottone(sk[1], "SchedaOn" if tab == sk[0] else "Scheda", _scheda.bind(sk[0]), 46)
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		h.add_child(b)
	fondo.add_child(h)
	return fondo


func _scheda(v: String) -> void:
	tab = v
	mostra(false)
	if scorri != null:
		scorri.scroll_vertical = 0


func _riga(nome: String, val: String) -> void:
	corpo.add_child(U.sezione(nome, val))


func _chips(chiave: String, nomi: Array, cur: Variant) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	for i in nomi.size():
		var b := U.chip(str(nomi[i]), i == cur, _imposta.bind(chiave, i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 96
		f.add_child(b)
	corpo.add_child(f)


func _tinte(chiave: String, lista: Array, cur: int) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 10)
	for i in lista.size():
		f.add_child(_tinta(Color(lista[i][1]), i == cur, _imposta.bind(chiave, i)))
	corpo.add_child(f)


# pallino di colore (.sw del web): 46 px, bordo d'oro quando è scelto
func _tinta(col: Color, on: bool, cb: Callable) -> Control:
	var b := U.bottone("", "Vuoto", cb, 46)
	b.custom_minimum_size.x = 46
	b.draw.connect(func() -> void:
		var c := Vector2(23, 23)
		if on:
			b.draw_circle(c, 26.0, Color(1, 0.851, 0.239, 0.2))
		b.draw_circle(c, 23.0, T.GOLD if on else Color(1, 1, 1, 0.13))
		b.draw_circle(c, 20.0, col)
		b.draw_circle(c + Vector2(0, 7), 13.0, Color(0, 0, 0, 0.12)))
	if on:
		b.scale = Vector2(1.08, 1.08)
	return b


func _pannello() -> void:
	var l: Dictionary = D.normalize_look(d.get("look", {}))
	if mode == "crest":
		_pannello_stemma()
		return
	match tab:
		"face":
			_riga("Pelle", D.SKINS[l.skin][0])
			_tinte("look.skin", D.SKINS, l.skin)
			_riga("Occhi", "")
			_chips("look.eyes", D.EYE_SHAPES, l.eyes)
			_riga("Colore degli occhi", D.EYE_COLORS[l.eyeColor][0])
			_tinte("look.eyeColor", D.EYE_COLORS, l.eyeColor)
			_riga("Sopracciglia", "")
			_chips("look.brows", D.BROWS, l.brows)
			_riga("Barba", "")
			_chips("look.beard", D.BEARDS, l.beard)
		"hair":
			_riga("Taglio", "%d di %d" % [l.hair + 1, D.HAIR_STYLES.size()])
			_chips("look.hair", D.HAIR_STYLES, l.hair)
			_riga("Colore", D.HAIR_COLORS[l.hairColor][0])
			_tinte("look.hairColor", D.HAIR_COLORS, l.hairColor)
		"boots":
			_riga("Scarpe", D.BOOTS[l.boots][0])
			_tinte("look.boots", D.BOOTS, l.boots)
		"kit":
			corpo.add_child(U.paragrafo("Lo stile vale per tutta la squadra; i colori sono quelli scelti per la maglia.", 13.5))
			for key: String in D.KIT_KEYS:
				_riga(KIT_LABELS[key], "")
				_chips("style." + key, D.KIT_OPTS[key], d.style.get(key, 0))
			if mode == "champ":
				_riga("Scarpe del campione", D.BOOTS[l.boots][0])
				_tinte("look.boots", D.BOOTS, l.boots)
		"me":
			_pannello_nome()


func _pannello_stemma() -> void:
	var k := D.kit(d.kit)
	corpo.add_child(U.paragrafo("Colori presi dalla maglia (%s)." % k[0], 13.5))
	var lista: Array = {"shape": D.CREST_SHAPES, "pattern": D.CREST_PATTERNS, "icon": D.CREST_ICONS}[tab]
	var g := U.griglia(4, 8, 8)
	for i in lista.size():
		var c: Dictionary = d.crest.duplicate()
		c[tab] = i
		var on: bool = int(d.crest.get(tab, 0)) == i
		var b := U.bottone("", "OpzioneOn" if on else "Opzione", _imposta.bind("crest." + tab, i), 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := U.vbox(4)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_top = 8
		v.offset_bottom = -6
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := MenuStemma.nuovo(c, int(k[1]), int(k[2]), Vector2(42, 50), false)
		st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(st)
		var nome := U.testo(str(lista[i][0]), 11, Color("#c4d1e8"), T.PESO_FORTE, HORIZONTAL_ALIGNMENT_CENTER)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nome)
		b.add_child(v)
		g.add_child(b)
	corpo.add_child(g)


func _pannello_nome() -> void:
	_riga("Nome", "")
	var nome := LineEdit.new()
	nome.text = str(d.name)
	nome.max_length = 20
	nome.custom_minimum_size.y = 52
	nome.select_all_on_focus = false
	nome.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	nome.text_changed.connect(func(t: String) -> void:
		d.name = t.left(20)
		_aggiorna_palco())
	corpo.add_child(nome)
	_riga("Ruolo", "")
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	for r: Array in RUOLI:
		var b := U.chip(r[1], d.pos == r[0], _imposta.bind("pos", r[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 100
		f.add_child(b)
	corpo.add_child(f)
	_riga("Numero di maglia", "")
	var h := U.hbox(10)
	var meno := U.bottone("−", "", _numero.bind(-1), 56)
	meno.custom_minimum_size.x = 64
	meno.add_theme_font_size_override("font_size", 28)
	h.add_child(meno)
	var n := U.testo(str(d.num), 40, T.TXT, 900, HORIZONTAL_ALIGNMENT_CENTER)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var piu := U.bottone("+", "", _numero.bind(1), 56)
	piu.custom_minimum_size.x = 64
	piu.add_theme_font_size_override("font_size", 28)
	h.add_child(piu)
	corpo.add_child(h)
	var q := HFlowContainer.new()
	q.add_theme_constant_override("h_separation", 8)
	q.add_theme_constant_override("v_separation", 8)
	for v: int in NUMERI_RAPIDI:
		var b := U.chip(str(v), int(d.num) == v, _imposta.bind("num", v))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 64
		q.add_child(b)
	corpo.add_child(q)
	corpo.add_child(U.paragrafo("Il campione entra in rosa come un giovane forte della Terza Divisione (%s), con l'aspetto che hai scelto." % D.pos_name(d.pos), 13.5))


func _barra() -> Control:
	var fondo := U.pannello_stile(T.stile(Color(0.039, 0.071, 0.141, 0.95), 0, Color(0, 0, 0, 0), 0, Vector4(16, 12, 16, 14 + sicura_sotto())))
	var h := U.hbox(10)
	var r := U.bottone("Casuale", "BtnFantasma", _casuale, 56)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_stretch_ratio = 1.0
	h.add_child(r)
	var ok_t := ("Avanti" if mode == "crest" else "Conferma e allenati") if flow == "new" else "Salva"
	var ok := U.bottone(ok_t, "BtnGrande", _conferma, 56)
	ok.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	ok.add_theme_font_size_override("font_size", 16)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.size_flags_stretch_ratio = 1.8
	h.add_child(ok)
	fondo.add_child(h)
	return fondo


func sicura_sotto() -> float:
	return maxf(0.0, get_viewport_rect().size.y - sicura.end.y)


# ---------------------------------------------------------------- azioni
func _imposta(chiave: String, val: Variant) -> void:
	var parti := chiave.split(".")
	if parti.size() == 2:
		var o: Dictionary = d[parti[0]].duplicate()
		o[parti[1]] = val
		d[parti[0]] = o
	else:
		d[chiave] = val
	if chiave == "pos" and val == "P" and int(d.num) == 9:
		d.num = 1
	ridisegna()


func _numero(passo: int) -> void:
	d.num = posmod(int(d.num) - 1 + passo + 99, 99) + 1
	ridisegna()


func _casuale() -> void:
	var r := D.Asp.seeded(D.hash32([Time.get_ticks_usec(), randi()]))
	var seme := int(float(r.call()) * 1e9)
	if mode == "crest":
		d.crest = D.crest_from_seed(seme)
	elif tab == "kit":
		d.style = D.kit_style_from_seed(seme)
	elif tab == "me":
		d.name = D.random_name(seme)
	else:
		# "Casuale" cambia solo la scheda aperta, il resto resta com'è
		var nuovo := D.look_from_seed(seme)
		var l: Dictionary = d.look.duplicate()
		if tab == "hair":
			l.hair = nuovo.hair
			l.hairColor = nuovo.hairColor
		elif tab == "boots":
			l.boots = nuovo.boots
		else:
			for k: String in nuovo:
				if k != "hair" and k != "hairColor" and k != "boots":
					l[k] = nuovo[k]
		d.look = l
	ridisegna()


func _conferma() -> void:
	var c := carriera()
	if mode == "crest" and flow == "new":
		mode = "champ"
		tab = "face"
		_cambia_palco()
		return
	match flow:
		"new":
			if c == null:
				c = _carriera_nuova()
			c.create(d.club, d.kit)
			c.setCrest(d.crest)
			c.setKitStyle(d.style)
			c.addChampion({"name": d.name, "pos": d.pos, "look": d.look, "num": d.num})
			gioca("allenamento")
		"crest":
			c.setCrest(d.crest)
			_esci("Stemma salvato")
		"kit":
			c.setKitStyle(d.style)
			_esci("Divisa salvata")
		"look":
			c.setLook(d.id, d.look)
			_esci("Aspetto salvato")


# nessuna carriera ancora (primo avvio senza App): se ne crea una e la si dà ad App se c'è
func _carriera_nuova() -> Object:
	var c := Carriera.new()
	var ap := app()
	if ap != null and "carriera" in ap:
		ap.set("carriera", c)
	else:
		MenuSchermata.carriera_prova = c
	return c
