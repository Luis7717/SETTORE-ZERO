# Statistiche a fine partita (PIANO.md, fase C punto 14): ci si arriva dal "dopo partita" col tasto
# "Statistiche e pagelle". arg = {m, tabellino, title, dopo}:
#   m         = la partita come la vede dopo_partita.gd ({score, teams, stats, goalsLog})
#   tabellino = conta_giocatori.gd tabellino(): passaggi e km per squadra, mappa dei tiri, giocatori della persona
#   dopo      = l'arg del dopo partita, per tornarci col tasto ‹ (o "Torna al risultato")
# Tre parti: numeri della partita (squadra 0 a sinistra, in giallo; squadra 1 a destra, in blu, come il dopo
# partita), mappa dei tiri su tutto il campo (la persona attacca verso l'alto; pieno = gol, vuoto = parato,
# respinto o fuori) e pagella della mia squadra (voti di scripts/partita/voti.gd, migliore in campo e campione
# evidenziati). Nessun dato della carriera cambia qui.
extends MenuSchermata

const DopoPartita := preload("res://scripts/menu/dopo_partita.gd")
const Voti := preload("res://scripts/partita/voti.gd")
const Mappa := preload("res://scripts/partita/mappa_tiri.gd")
const BLU := Color("#6f86b0")          # colore della squadra 1 (come le barre del dopo partita)
const BLU_MAPPA := Color("#8fb0ff")    # più chiaro sul verde della mappa
const ALTEZZA_MAPPA := 330.0
const RAGGIO_TIRO := 6.0
const PORTA_SPORGE := 4.0              # px: le porte escono dal campo disegnato
const ERBA := Color("#123a2a")
const ERBA2 := Color("#15422f")
const RIGHE := Color(1, 1, 1, 0.38)
const VOTO_BUONO := 7.0
const VOTO_SUFF := 6.0

var _m: Dictionary = {}
var _tab: Dictionary = {}


func prepara() -> void:
	titolo = "Statistiche"
	soldi = false
	var a: Dictionary = arg if arg is Dictionary else {}
	_m = a.get("m", {}) if a.get("m") is Dictionary else {}
	_tab = a.get("tabellino", {}) if a.get("tabellino") is Dictionary else {}


func torna_indietro() -> void:
	var a: Dictionary = arg if arg is Dictionary else {}
	vai("dopo_partita", a.get("dopo"))


func costruisci() -> void:
	var score: Array = _m.get("score", [0, 0])
	var teams: Array = _m.get("teams", [{}, {}])
	var me := int(_tab.get("me", 0))
	corpo.add_child(_testata_risultato(teams, score))
	corpo.add_child(U.sezione("Numeri della partita"))
	corpo.add_child(_numeri())
	corpo.add_child(U.sezione("Mappa dei tiri"))
	corpo.add_child(_mappa(teams, me))
	corpo.add_child(U.sezione("Pagella", str(D.campo(teams[me], "short", ""))))
	var mie := int(score[me])
	var loro := int(score[1 - me])
	corpo.add_child(_pagella(Voti.calcola(_tab.get("giocatori", []), mie, loro)))
	corpo.add_child(U.paragrafo("Voto da 4 a 10: base 6, più per gol, assist, dribbling, contrasti e parate, meno per gol subiti e palle perse; il risultato conta un po'.", 12.5))
	corpo.add_child(U.bottone("TORNA AL RISULTATO", "BtnGrande", func() -> void: torna_indietro()))


# riga compatta: SIGLA 2 – 1 SIGLA (titolo della partita sopra)
func _testata_risultato(teams: Array, score: Array) -> Control:
	var v := U.vbox(4)
	var a: Dictionary = arg if arg is Dictionary else {}
	if str(a.get("title", "")) != "":
		v.add_child(U.testo(str(a.title).to_upper(), 11.5, T.DIM, T.PESO_FORTE, HORIZONTAL_ALIGNMENT_CENTER))
	var h := U.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(U.testo(str(D.campo(teams[0], "short", "")), 18, T.GOLD, T.PESO_NERO))
	h.add_child(U.testo("%d – %d" % [int(score[0]), int(score[1])], 30, T.TXT, 900))
	h.add_child(U.testo(str(D.campo(teams[1], "short", "")), 18, BLU_MAPPA, T.PESO_NERO))
	v.add_child(h)
	return v


func _numeri() -> Control:
	var st: Dictionary = _m.get("stats", {})
	var poss: Array = st.get("poss", [0, 0])
	var ps := maxf(0.001, float(poss[0]) + float(poss[1]))
	var p0 := D._round_js(float(poss[0]) / ps * 100.0) if float(poss[0]) + float(poss[1]) > 0.0 else 50
	var pas: Array = _tab.get("passaggi", [[0, 0], [0, 0]])
	var km: Array = _tab.get("km", [0.0, 0.0])
	var carta := U.pannello("Carta")
	var righe := U.vbox(0)
	carta.add_child(righe)
	righe.add_child(DopoPartita.riga_stat("Possesso", ["%d%%" % p0, "%d%%" % (100 - p0)]))
	righe.add_child(DopoPartita.riga_stat("Tiri", st.get("shots", [0, 0])))
	righe.add_child(DopoPartita.riga_stat("Tiri in porta", st.get("onT", [0, 0])))
	righe.add_child(DopoPartita.riga_stat("Passaggi riusciti", [_pct(pas[0]), _pct(pas[1])], [_frazione(pas[0]), _frazione(pas[1])]))
	righe.add_child(DopoPartita.riga_stat("Angoli", st.get("corners", [0, 0])))
	righe.add_child(DopoPartita.riga_stat("Falli", st.get("fouls", [0, 0])))
	for riga: Array in DopoPartita.righe_cartellini(st):
		righe.add_child(DopoPartita.riga_stat(riga[0], riga[1]))
	righe.add_child(DopoPartita.riga_stat("Parate", st.get("saves", [0, 0])))
	righe.add_child(DopoPartita.riga_stat("Km percorsi", [_km(km[0]), _km(km[1])], [float(km[0]), float(km[1])]))
	return carta


static func _frazione(p: Variant) -> float:
	if not p is Array or (p as Array).size() < 2 or int(p[1]) <= 0:
		return 0.0
	return float(p[0]) / float(p[1])


static func _pct(p: Variant) -> String:
	if not p is Array or (p as Array).size() < 2 or int(p[1]) <= 0:
		return "–"
	return "%d%%" % roundi(_frazione(p) * 100.0)


static func _km(v: Variant) -> String:
	return ("%.1f" % float(v)).replace(".", ",")


static func colore_squadra(team: int) -> Color:
	return T.GOLD if team == 0 else BLU_MAPPA


# ---------------------------------------------------------------- mappa dei tiri
func _mappa(teams: Array, me: int) -> Control:
	var tiri: Array = _tab.get("tiri", [])
	var carta := U.pannello("Carta")
	var v := U.vbox(10)
	carta.add_child(v)
	var su := U.testo("↑ attacca %s" % str(D.campo(teams[me], "short", "")), 12, colore_squadra(me), T.PESO_FORTE, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(su)
	var campo := Control.new()
	campo.custom_minimum_size = Vector2(0, ALTEZZA_MAPPA)
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	campo.draw.connect(func() -> void: _disegna_campo(campo, tiri, me))
	v.add_child(campo)
	v.add_child(U.testo("↓ attacca %s" % str(D.campo(teams[1 - me], "short", "")), 12, colore_squadra(1 - me), T.PESO_FORTE, HORIZONTAL_ALIGNMENT_CENTER))
	var leg := U.hbox(14)
	leg.alignment = BoxContainer.ALIGNMENT_CENTER
	leg.add_child(_voce_legenda(true, "Gol"))
	leg.add_child(_voce_legenda(false, "Parato, respinto o fuori"))
	v.add_child(leg)
	var righe := U.hbox(10)
	for team in [0, 1]:
		var c := Mappa.conta(tiri, team)
		var t := U.testo("%s: %d %s, %d gol, %d %s" % [str(D.campo(teams[team], "short", "")), c.tiri,
			"tiro" if c.tiri == 1 else "tiri", c.gol, c.parato, "parato" if c.parato == 1 else "parati"],
			12.5, colore_squadra(team), T.PESO_MEDIO, HORIZONTAL_ALIGNMENT_CENTER)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		righe.add_child(t)
	v.add_child(righe)
	return carta


func _disegna_campo(c: Control, tiri: Array, me: int) -> void:
	var r := Mappa.rettangolo(c.size - Vector2(0, 2.0 * PORTA_SPORGE))   # spazio per le porte, fuori dal campo
	r.position.y += PORTA_SPORGE
	var strisce := 8
	for i in strisce:
		var h := r.size.y / strisce
		c.draw_rect(Rect2(r.position.x, r.position.y + i * h, r.size.x, h), ERBA if i % 2 == 0 else ERBA2)
	var sx := r.size.x / (2.0 * Mappa.MEZZA_LARGHEZZA)   # px per metro
	var sy := r.size.y / (2.0 * Mappa.MEZZA_LUNGHEZZA)
	c.draw_rect(r, RIGHE, false, 1.5)
	var meta := r.position.y + r.size.y / 2.0
	c.draw_line(Vector2(r.position.x, meta), Vector2(r.end.x, meta), RIGHE, 1.5)
	c.draw_arc(Vector2(r.get_center().x, meta), 9.15 * sx, 0.0, TAU, 40, RIGHE, 1.5)
	# aree di rigore (40,3 × 16,5 m) e piccole aree (18,3 × 5,5 m), in alto e in basso
	for alto: bool in [true, false]:
		for dim: Vector2 in [Vector2(40.3, 16.5), Vector2(18.3, 5.5)]:
			var w := dim.x * sx
			var h := dim.y * sy
			var y := r.position.y if alto else r.end.y - h
			c.draw_rect(Rect2(r.get_center().x - w / 2.0, y, w, h), RIGHE, false, 1.5)
		var pw := 7.32 * sx
		var py := r.position.y - PORTA_SPORGE if alto else r.end.y
		c.draw_rect(Rect2(r.get_center().x - pw / 2.0, py, pw, PORTA_SPORGE), Color(1, 1, 1, 0.75))
	# prima i tiri sbagliati, poi i gol sopra
	for giro in [false, true]:
		for t: Dictionary in tiri:
			if Mappa.pieno(t) != giro:
				continue
			var p := Mappa.punto(t, me, r)
			var col := colore_squadra(int(t.get("team", 0)))
			if giro:
				c.draw_circle(p, RAGGIO_TIRO + 1.0, Color(0, 0, 0, 0.55))
				c.draw_circle(p, RAGGIO_TIRO, col)
			else:
				c.draw_circle(p, RAGGIO_TIRO, Color(0, 0, 0, 0.35))
				c.draw_arc(p, RAGGIO_TIRO - 1.0, 0.0, TAU, 20, col, 2.0, true)


func _voce_legenda(pieno: bool, testo: String) -> Control:
	var h := U.hbox(6)
	var cerchio := Control.new()
	cerchio.custom_minimum_size = Vector2(14, 14)
	cerchio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cerchio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cerchio.draw.connect(func() -> void:
		var centro := cerchio.size / 2.0
		if pieno:
			cerchio.draw_circle(centro, 6.0, T.TXT)
		else:
			cerchio.draw_arc(centro, 5.0, 0.0, TAU, 20, T.TXT, 2.0, true))
	h.add_child(cerchio)
	h.add_child(U.testo(testo, 12.5, T.NOTE, T.PESO_MEDIO))
	return h


# ---------------------------------------------------------------- pagella
func _pagella(voti: Array) -> Control:
	var v := U.vbox(8)
	if voti.is_empty():
		v.add_child(U.paragrafo("Nessun dato sui giocatori per questa partita.", 13.5))
		return v
	for g: Dictionary in voti:
		v.add_child(_riga_voto(g))
	return v


func _riga_voto(g: Dictionary) -> Control:
	var migliore: bool = g.get("migliore", false)
	var champ: bool = g.get("champ", false)
	var bordo := T.GOLD if migliore else (Color(T.GOLD, 0.35) if champ else T.LINE)
	var fondo := T.mix(T.GOLD, 10, T.PANEL) if migliore else T.PANEL
	var carta := U.pannello_stile(T.stile(fondo, 14, bordo, 2 if migliore else 1, Vector4(10, 8, 10, 8)))
	var h := U.hbox(10)
	carta.add_child(h)
	var pos := str(g.get("pos", "C"))
	h.add_child(U.ruolo(pos, D.pos_name(pos)))
	var col := U.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nome := U.corto(str(g.get("name", "")), 15, T.GOLD if champ else T.TXT, T.PESO_NERO)
	col.add_child(nome)
	var etichette: Array = []
	if migliore:
		etichette.append("[color=#ffd93d][b]MIGLIORE IN CAMPO[/b][/color]")
	if champ:
		etichette.append("[color=#ffe45e][b]★ CAMPIONE[/b][/color]")
	if not etichette.is_empty():
		col.add_child(U.bb(" · ".join(etichette), 11.5, T.NOTE))
	var det := dettaglio(g.get("conti", {}))
	if det != "":
		col.add_child(U.bb(U.esc(det), 11.5, T.NOTE))
	h.add_child(col)
	var voto := float(g.get("voto", 6.0))
	var cv := T.GOOD if voto >= VOTO_BUONO else (T.TXT if voto >= VOTO_SUFF else T.BAD)
	var box := U.pannello_stile(T.stile(Color(cv, 0.14), 10, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	box.custom_minimum_size = Vector2(50, 38)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(U.testo(Voti.testo(voto), 19, cv, T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER))
	h.add_child(box)
	return carta


## riga corta coi fatti del giocatore: "1 gol · 2 contrasti · 3 palle perse" (solo quelli che contano per il voto)
static func dettaglio(conti: Variant) -> String:
	if not conti is Dictionary:
		return ""
	var parti: Array = []
	for voce: Array in [["gol", "gol", "gol"], ["assist", "assist", "assist"], ["parate", "parata", "parate"],
			["dribbling", "dribbling", "dribbling"], ["contrasti", "contrasto", "contrasti"],
			["intercetti", "intercetto", "intercetti"], ["subiti", "gol subito", "gol subiti"],
			["perse", "palla persa", "palle perse"]]:
		var n := int(conti.get(voce[0], 0))
		if n > 0:
			parti.append("%d %s" % [n, voce[1] if n == 1 else voce[2]])
	if int(conti.get("rossi", 0)) > 0:
		parti.append("espulso")
	elif int(conti.get("gialli", 0)) > 0:
		parti.append("ammonito")
	return " · ".join(parti)
