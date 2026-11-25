# Fine partita e risultati della giornata (post() di src/ui.js). Nome "dopo_partita": ci arriva App dopo la partita
# con arg = App.ultimo_esito = {esito: {gol_a, gol_b, marcatori, statistiche, me, squadre?}, res, titolo, tipo};
# accetta anche il formato del web {m, res, title} (prove):
#   m     = la partita (SimMatch o Dictionary): score, goalsLog [{team, name, minute}], stats {shots, onT, poss,
#           corners, fouls}, teams [{short, kit: {crest: {shape, pattern, icon, c1, c2}}}]
#   res   = risultato di Carriera.finishMatch (incasso, stipendi, migliorati, altri risultati, season) o null,
#           con le novità di Carriera.dopoPartita: derby (premio), crescita del campione, infortuni, cambi
#   title = riga in alto ("Terza Divisione · Giornata 4", "Amichevole", ...)
# "Continua" porta alla fine della stagione se è finita, altrimenti alla casa della carriera.
# "Statistiche e pagelle" (se l'esito ha il tabellino della partita) apre la schermata "statistiche" con
# arg = {m, tabellino, title, dopo}: dopo = questo stesso arg, per tornare qui col tasto ‹.
extends MenuSchermata

const Crescita := preload("res://scripts/carriera/crescita.gd")
const Forma := preload("res://scripts/carriera/forma.gd")

var _tabellino: Variant = null   # esito.tabellino (conta_giocatori.gd): c'è il tasto delle statistiche


func prepara() -> void:
	con_testata = false


func costruisci() -> void:
	var r: Dictionary = arg if arg is Dictionary else {}
	_tabellino = null
	if r.has("esito"):
		_tabellino = r.esito.get("tabellino")
		r = da_esito(r)
	var m: Variant = r.get("m")
	if m == null:
		corpo.add_child(U.bottone("CONTINUA", "BtnGrande", func() -> void: vai("hub")))
		return
	var score: Array = D.campo(m, "score", [0, 0])
	var teams: Array = D.campo(m, "teams", [{}, {}])
	var stats: Dictionary = D.campo(m, "stats", {})
	var s0 := int(score[0])
	var s1 := int(score[1])
	var vd: Array = ["w", "VITTORIA"] if s0 > s1 else (["l", "SCONFITTA"] if s0 < s1 else ["d", "PAREGGIO"])

	corpo.add_child(U.spazio(maxf(0.0, get_viewport_rect().size.y * 0.02 - 12.0)))
	corpo.add_child(U.testo(str(r.get("title", "")).to_upper(), 12, T.DIM, T.PESO_FORTE, HORIZONTAL_ALIGNMENT_CENTER))
	var k1: Color = colori_squadra()[0]
	var cs := U.carta_sfumata(T.mix(k1, 38, Color("#16253f")), Color("#0f192c"), 160, 0.7, 22, Vector4(12, 18, 12, 16), T.LINE2, Color(0, 0, 0, 0.45))
	var tab := U.vbox(10)
	cs[1].add_child(tab)
	var riga := U.hbox(6)
	riga.add_child(_squadra(teams[0], false))
	riga.add_child(U.testo("%d – %d" % [s0, s1], 56, T.TXT, 900, HORIZONTAL_ALIGNMENT_CENTER))
	riga.add_child(_squadra(teams[1], true))
	tab.add_child(riga)
	var col: Color = {"w": T.GOOD, "d": Color("#f1c75a"), "l": T.BAD}[vd[0]]
	var pill := U.pannello_stile(T.stile(Color(col, 0.15), 999, Color(0, 0, 0, 0), 0, Vector4(14, 5, 14, 5)))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_child(U.testo(vd[1], 12, col, 900))
	tab.add_child(pill)
	var marc := U.vbox(5)
	for g: Variant in D.campo(m, "goalsLog", []):
		var t0: bool = int(D.campo(g, "team", 0)) == 0
		var nome := str(D.campo(g, "name", ""))
		var minuto := int(D.campo(g, "minute", 0))
		var l := U.testo(("%s %d'" % [nome, minuto]) if t0 else ("%d' %s" % [minuto, nome]), 13, Color("#c9d6ee"), T.PESO_MEDIO, HORIZONTAL_ALIGNMENT_LEFT if t0 else HORIZONTAL_ALIGNMENT_RIGHT)
		marc.add_child(l)
	tab.add_child(marc)
	corpo.add_child(cs[0])

	var poss: Array = stats.get("poss", [0, 0])
	var ps := float(poss[0]) + float(poss[1])
	if ps <= 0.0:
		ps = 1.0
	var righe := U.vbox(0)
	righe.add_child(riga_stat("Tiri", stats.get("shots", [0, 0])))
	righe.add_child(riga_stat("In porta", stats.get("onT", [0, 0])))
	righe.add_child(riga_stat("Possesso", ["%d%%" % D._round_js(float(poss[0]) / ps * 100.0), "%d%%" % D._round_js(float(poss[1]) / ps * 100.0)]))
	righe.add_child(riga_stat("Angoli", stats.get("corners", [0, 0])))
	righe.add_child(riga_stat("Falli", stats.get("fouls", [0, 0])))
	for voce: Array in righe_cartellini(stats):
		righe.add_child(riga_stat(voce[0], voce[1]))
	corpo.add_child(righe)

	var res: Variant = r.get("res")
	if res is Dictionary:
		var nov := _novita(res)
		if nov != null:
			corpo.add_child(nov)
		corpo.add_child(_soldi(res))
	var stagione: Variant = res.get("season") if res is Dictionary else null
	if _tabellino is Dictionary and not (_tabellino as Dictionary).is_empty():
		var dati := {"m": m, "tabellino": _tabellino, "title": r.get("title", ""), "dopo": arg}
		corpo.add_child(U.bottone("STATISTICHE E PAGELLE", "BtnFantasma", func() -> void: vai("statistiche", dati)))
	corpo.add_child(U.bottone("CONTINUA", "BtnGrande", func() -> void:
		if stagione is Dictionary:
			vai("fine_stagione", stagione)
		else:
			vai("hub")))


## App.ultimo_esito → {m, res, title}. Le squadre: esito.squadre se la partita le passa, altrimenti la mia dalla
## carriera e l'avversario dall'ultima partita registrata (s.last.opp) o generico per le amichevoli
func da_esito(a: Dictionary) -> Dictionary:
	var e: Dictionary = a.esito
	var me := int(e.get("me", 0))
	var teams: Array = e.get("squadre", [])
	if teams.size() < 2:
		var mia := _squadra_mia()
		var loro := _squadra_avversaria(str(a.get("tipo", "")))
		teams = [mia, loro] if me == 0 else [loro, mia]
	var m := {"score": [int(e.get("gol_a", 0)), int(e.get("gol_b", 0))], "teams": teams,
		"goalsLog": e.get("marcatori", []), "stats": e.get("statistiche", {})}
	return {"m": m, "res": a.get("res"), "title": a.get("titolo", "")}


func _squadra_mia() -> Dictionary:
	var c := carriera()
	var s := stato()
	if s.is_empty():
		return {"short": "MIA", "kit": {}}
	var k := D.kit(s.kit)
	var cr: Dictionary = c.crest().duplicate()
	cr.c1 = int(k[1])
	cr.c2 = int(k[2])
	return {"short": str(s.teams.me.get("short", "MIA")), "kit": {"crest": cr}}


func _squadra_avversaria(tipo: String) -> Dictionary:
	var c := carriera()
	var s := stato()
	var last: Variant = s.get("last")
	if tipo == "campionato" and last is Dictionary:
		for t: Dictionary in s.teams.values():
			if t.name == last.get("opp"):
				var k := D.kit(t.get("kit", 0))
				var cr: Dictionary = c.teamCrest(t).duplicate()
				cr.c1 = int(k[1])
				cr.c2 = int(k[2])
				return {"short": str(t.short), "kit": {"crest": cr}}
	return {"short": "AMI", "kit": {}}


func _squadra(t: Variant, destra: bool) -> Control:
	var h := U.hbox(6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var kit: Variant = D.campo(t, "kit", {})
	var cr: Variant = D.campo(kit, "crest")
	var st: Control = null
	if cr is Dictionary:
		st = MenuStemma.nuovo(cr, int(cr.get("c1", 0xc8102e)), int(cr.get("c2", 0xffffff)), Vector2(30, 36))
	var nome := U.testo(str(D.campo(t, "short", "")), 20, T.TXT, T.PESO_NERO)
	if st != null:
		h.add_child(st)
	h.add_child(nome)
	return h


# riga di statistica: valori ai lati, nome al centro, barra divisa sotto (giallo noi, blu loro); la usa anche la
# schermata delle statistiche. `quote` = numeri per la barra se i valori sono scritte ("78%", "54,2")
## righe dei cartellini (stats.yellows / stats.reds, falli.gd) solo se in partita ce n'è stato almeno uno:
## [[nome, [squadra 0, squadra 1]], ...]
static func righe_cartellini(stats: Dictionary) -> Array:
	var out: Array = []
	for voce: Array in [["Ammonizioni", "yellows"], ["Espulsioni", "reds"]]:
		var v: Variant = stats.get(voce[1])
		if v is Array and (v as Array).size() == 2 and int(v[0]) + int(v[1]) > 0:
			out.append([voce[0], [int(v[0]), int(v[1])]])
	return out


static func riga_stat(nome: String, v: Array, quote: Array = []) -> Control:
	var box := U.vbox(4)
	var h := U.hbox(10)
	var a := U.testo(str(v[0]), 16, T.TXT, T.PESO_NERO)
	a.custom_minimum_size.x = 56
	h.add_child(a)
	var n := U.testo(nome, 13, Color("#b3c3de"), T.PESO_MEDIO, HORIZONTAL_ALIGNMENT_CENTER)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var b := U.testo(str(v[1]), 16, T.TXT, T.PESO_NERO, HORIZONTAL_ALIGNMENT_RIGHT)
	b.custom_minimum_size.x = 56
	h.add_child(b)
	box.add_child(h)
	var fa := float(quote[0]) if quote.size() == 2 else str(v[0]).to_float()
	var fb := float(quote[1]) if quote.size() == 2 else str(v[1]).to_float()
	var qa := fa if fa > 0.0 else (0.01 if fb > 0.0 else 1.0)
	var qb := fb if fb > 0.0 else (0.01 if fa > 0.0 else 1.0)
	var barra := Control.new()
	barra.custom_minimum_size.y = 5
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.draw.connect(func() -> void:
		var w := barra.size.x - 3.0
		var wa := w * qa / (qa + qb)
		MenuUi._rett_tondo(barra, Rect2(0, 0, wa, 5), 2, T.GOLD)
		MenuUi._rett_tondo(barra, Rect2(wa + 3.0, 0, w - wa, 5), 2, Color("#6f86b0")))
	box.add_child(barra)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_theme_constant_override("margin_left", 2)
	m.add_theme_constant_override("margin_right", 2)
	m.add_child(box)
	return m


func _soldi(res: Dictionary) -> Control:
	var s := stato()
	var carta := U.pannello("Carta")
	var v := U.vbox(0)
	carta.add_child(v)
	v.add_child(_voce("Incasso partita", "+" + D.fmt_money(float(res.get("income", 0))), T.GOOD, false))
	v.add_child(_voce("Stipendi", "−" + D.fmt_money(float(res.get("wages", 0))), T.BAD, true))
	if int(res.get("derby", 0)) > 0:
		v.add_child(_voce("Premio del derby", "+" + D.fmt_money(float(res.derby)), T.GOOD, true))
	v.add_child(_voce("Cassa", D.fmt_money(float(s.get("money", 0))), T.TXT, true))
	var grown: Array = res.get("grown", [])
	if not grown.is_empty():
		v.add_child(U.spazio(8))
		v.add_child(U.paragrafo("Migliorati: " + ", ".join(grown.map(func(x: Variant) -> String: return str(x))), 13.5))
	var others: Array = res.get("others", [])
	if not others.is_empty():
		v.add_child(U.spazio(8))
		var parti: Array = others.map(func(o: Array) -> String: return "%s %d–%d %s" % [o[0], int(o[1]), int(o[2]), o[3]])
		v.add_child(U.paragrafo("Altri risultati: " + " · ".join(parti), 13.5))
	return carta


func _voce(nome: String, val: String, col: Color, riga_sopra: bool) -> Control:
	var box := U.vbox(0)
	if riga_sopra:
		var r := ColorRect.new()
		r.color = T.LINE
		r.custom_minimum_size.y = 1
		box.add_child(r)
	var h := U.hbox(10)
	h.custom_minimum_size.y = 40
	h.add_child(U.corto(nome, 13, Color("#b3c3de"), T.PESO_MEDIO))
	h.add_child(U.testo(val, 16, col, T.PESO_NERO))
	box.add_child(h)
	return box


## righe della crescita a voti (res.voti_crescita: "Rossi (voto 7,5): Passaggio +1") e della metà stagione
## (res.meta_stagione: un anno in più, chi sale e chi scende con la media dei voti), crescita_voti.gd
static func righe_voti(res: Dictionary) -> Array:
	var out: Array = []
	var per_nome := {}
	var ordine: Array = []
	for r: Dictionary in res.get("voti_crescita", []):
		var n := str(r.nome)
		if not per_nome.has(n):
			per_nome[n] = {"voto": float(r.voto), "pezzi": []}
			ordine.append(n)
		var su := int(r.su) > 0
		var testo := "%s %s1" % [Crescita.NOMI.get(r.stat, r.stat), "+" if su else "−"]
		per_nome[n].pezzi.append("[color=%s]%s[/color]" % ["#4aeb9f" if su else "#ff7079", U.esc(testo)])
	for n: String in ordine:
		var voto := ("%.1f" % float(per_nome[n].voto)).replace(".", ",").replace(",0", "")
		out.append("[b]%s[/b] (voto %s): %s" % [U.esc(n), voto, " · ".join(per_nome[n].pezzi)])
	var meta: Variant = res.get("meta_stagione")
	if meta is Array:
		var pezzi: Array = []
		for r: Dictionary in meta:
			var pt := int(r.punti)
			if pt == 0:
				continue
			pezzi.append("[color=%s]%s %s%d[/color]" % ["#4aeb9f" if pt > 0 else "#ff7079", U.esc(str(r.nome)), "+" if pt > 0 else "−", absi(pt)])
		var testo := "[color=#ffd93d][b]Metà stagione:[/b][/color] un anno in più per tutti (il campione no)."
		if not pezzi.is_empty():
			testo += " Con la media dei voti e l'età: " + " · ".join(pezzi)
		out.append(testo)
	return out


## crescita del campione ("Tiro +1"), derby, infortuni e cambi della CPU (Carriera.dopoPartita); null se niente
func _novita(res: Dictionary) -> Control:
	var righe: Array = []
	var cr: Variant = res.get("crescita")
	if cr is Dictionary:
		var su: Array = []
		for r: Dictionary in cr.get("righe", []):
			if int(r.su) > 0:
				su.append("[color=#4aeb9f][b]%s[/b][/color]" % U.esc(Crescita.testo(r)))
			elif float(r.parte) >= 0.05:
				su.append(U.esc(Crescita.testo(r)))
		if not su.is_empty():
			righe.append("[b]%s cresce:[/b] %s" % [U.esc(str(cr.nome)), " · ".join(su)])
	righe.append_array(righe_voti(res))
	if res.has("infortuni"): # giornata di campionato registrata (Forma.giornata): energia tra le partite
		righe.append("[b]Energia:[/b] il campione riparte al 100%%; gli altri recuperano %d punti, %d chi ha riposato (vedi la barretta in Rosa)." % [Forma.RECUPERO, Forma.RECUPERO + Forma.RECUPERO_RIPOSO])
	if res.has("derby"):
		righe.append("[color=#ffd93d][b]Derby vinto![/b][/color] Premio in più dalla società." if int(res.derby) > 0 else "Derby perso o pareggiato: niente premio in più.")
	for inf: Dictionary in res.get("infortuni", []):
		var g := int(inf.giornate)
		righe.append("[color=#ff7079][b]Infortunio:[/b][/color] %s si è fatto male: fuori %d %s." % [U.esc(str(inf.name)), g, "giornata" if g == 1 else "giornate"])
	for c: Dictionary in res.get("cambi", []):
		righe.append("In formazione %s al posto di %s." % [U.esc(str(c.dentro)), U.esc(str(c.fuori))])
	if righe.is_empty():
		return null
	var carta := U.pannello("Carta")
	var v := U.vbox(8)
	carta.add_child(v)
	for t: String in righe:
		v.add_child(U.bb(t, 13.5, Color("#d7e1f3")))
	return carta
