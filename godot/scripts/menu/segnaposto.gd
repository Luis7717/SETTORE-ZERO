# Schermata segnaposto del menu (finché non ci sono quelle vere in scenes/menu/): elenco testuale per provare il
# flusso dell'app. Nuova carriera, prossima partita, amichevole, allenamento, classifica in testo; dopo una partita
# mostra risultato, incassi e (a fine stagione) promozione o retrocessione. Arg (App.vai): ultimo_esito o null.
extends Control

const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const FONDO := Color("#0f1b2d")
const GIALLO := Color("#ffe14a")
const GRIGIO := Color("#a9b8d6")
const MARGINE := 16
const ALTO := 48            # spazio sopra (area sicura approssimata: è solo un segnaposto)
const ESITI := {"up": "Promossi!", "down": "Retrocessi", "stay": "Salvi", "champ": "Campioni!"}

var _box: VBoxContainer
var _conferma_cancella := false


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = MARGINE
	scroll.offset_right = -MARGINE
	scroll.offset_top = ALTO
	scroll.offset_bottom = -MARGINE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_box)
	_disegna()


func _disegna() -> void:
	for c in _box.get_children():
		c.queue_free()
	var arg: Variant = get_meta("arg") if has_meta("arg") else null
	_testo("TIRO A GIRO 3D", 26, GIALLO)
	_testo("menu provvisorio · schermata \"%s\"" % get_meta("schermata", "?"), 12, GRIGIO)
	var c: CarrieraScript = App.carriera
	if c.s == null:
		_testo("Nessuna carriera salvata.", 16)
		_tasto("Nuova carriera", func() -> void:
			c.create("FC Tiro a Giro", 0)
			_disegna())
		return
	if arg is Dictionary and arg.has("esito"):
		_dopo_partita(arg)
	var s: Dictionary = c.s
	var d := c.div()
	_testo("%s · %s" % [s.club, CarrieraScript.DIV_NAMES[d]], 18)
	_testo("Stagione %d · giornata %d di %d · soldi %s · forza %d" % [s.season, s.day, CarrieraScript.ROUNDS, CarrieraScript.fmtMoney(s.money), c.myRating()], 13, GRIGIO)
	var nm: Variant = c.nextMatch()
	if nm != null:
		_tasto("Gioca: giornata %d %s %s" % [nm.day, "in casa con" if nm.home else "fuori con", nm.opp.name], App.gioca_campionato)
	_tasto("Amichevole", func() -> void: App.gioca_amichevole())
	_tasto("Allenamento", App.allenamento)
	_testo("Classifica", 16, GIALLO)
	var righe := PackedStringArray()
	var tab := c.table(d)
	for i in tab.size():
		var r: Dictionary = tab[i]
		var t: Dictionary = c.team(r.id)
		var nome: String = ("> " if r.id == "me" else "  ") + String(t.short)
		righe.append("%2d %-6s %2d pt  %2d-%-2d  %dV %dN %dP" % [i + 1, nome, r.pts, r.gf, r.ga, r.w, r.d, r.l])
	var l := _testo("\n".join(righe), 14)
	l.add_theme_font_override("font", _mono())
	var b := _tasto("Cancella carriera", Callable())
	b.pressed.connect(func() -> void:
		if not _conferma_cancella:
			_conferma_cancella = true
			b.text = "Sicuro? Tocca di nuovo per cancellare tutto"
			return
		c.reset()
		_conferma_cancella = false
		_disegna())


func _dopo_partita(u: Dictionary) -> void:
	var e: Dictionary = u.esito
	_testo(String(u.titolo), 13, GRIGIO)
	var a: String = App.carriera.s.club
	_testo("Fine partita: %d – %d" % [e.gol_a, e.gol_b], 22, GIALLO)
	var res: Variant = u.res
	if res is Dictionary:
		_testo("Incasso %s · stipendi %s" % [CarrieraScript.fmtMoney(res.income), CarrieraScript.fmtMoney(res.wages)], 13)
		var altre := PackedStringArray()
		for o: Array in res.others:
			altre.append("%s %d-%d %s" % o)
		if not altre.is_empty():
			_testo("Altre partite: " + " · ".join(altre), 12, GRIGIO)
		if res.has("season"):
			var st: Dictionary = res.season
			_testo("Fine stagione: %d° posto · %s · premio %s" % [st.pos, ESITI.get(st.outcome, st.outcome), CarrieraScript.fmtMoney(st.prize + st.bonus)], 16, GIALLO)
	elif a != "":
		_testo("Amichevole: nessun effetto sulla carriera", 13, GRIGIO)


func _testo(t: String, dim: int, colore: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	_box.add_child(l)
	return l


func _tasto(t: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 15)
	b.clip_text = true
	if azione.is_valid():
		b.pressed.connect(azione)
	_box.add_child(b)
	return b


static func _mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Menlo", "Courier New", "monospace"])
	return f
