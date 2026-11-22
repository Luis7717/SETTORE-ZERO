# Stili di gioco (sim/stili.gd, Fase D) e portatore umano che si muove da solo (ai.gd humanCarrierAuto).
# - stile predefinito (o sconosciuto) = motore identico a prima, passo per passo;
# - ogni stile cambia quello che deve cambiare (posizioni, pressing, linea, passaggi);
# - carriera: salvataggio vecchio senza stili = equilibrati, stile della CPU fisso e coerente;
# - portatore automatico: avanza verso la porta, resta in campo, la strada disegnata vince, gli stili si vedono.
extends "test_base.gd"

const Stili := preload("../sim/stili.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const DIR := "user://test_stili/"


# impronta dello stato: pallone e giocatori (posizioni e velocità) a ogni passo
static func _impronta(m: SimMatchScript) -> float:
	var h: float = m.ball.x * 3.0 + m.ball.y * 7.0 + m.ball.h * 11.0
	for p: R.Player in m.players:
		h = h * 1.0000001 + p.x * 13.0 + p.y * 17.0 + p.vx * 19.0 + p.vy * 23.0
	return h


func _traccia(styles: Array, mode: String, sec: float, sd: int) -> Array:
	var ta := H.mkTeam("A", 62, sd * 7 + 1)
	var tb := H.mkTeam("B", 62, sd * 13 + 5)
	for k in 2:
		var t: Dictionary = [ta, tb][k]
		if styles[k][0] != null:
			t["stileAtt"] = styles[k][0]
		if styles[k][1] != null:
			t["stileDif"] = styles[k][1]
	var m := H.newMatch(sd, 60.0, [true, false] if mode == "bot" else [false, false], ta, tb)
	var bot: H.Bot = H.Bot.new(sd + 9) if mode == "bot" else null
	var out: Array = []
	for i in int(sec * 60.0):
		m.step(DT)
		if bot != null:
			bot.stepBot(m)
		out.append(_impronta(m))
		m.events.clear()
	out.append(m.score.duplicate())
	return out


func test_stile_predefinito_non_cambia_niente() -> bool:
	for mode: String in ["ai", "bot"]:
		var base := _traccia([[null, null], [null, null]], mode, 50.0, 4)
		var esplicito := _traccia([["equilibrato", "equilibrata"], ["equilibrato", "equilibrata"]], mode, 50.0, 4)
		var strano := _traccia([["boh", 3], [null, "nessuno"]], mode, 50.0, 4)
		eq(esplicito, base, "%s: stile equilibrato scritto = nessuno stile" % mode)
		eq(strano, base, "%s: valori sconosciuti ignorati" % mode)
	# e uno stile vero cambia la partita
	var con := _traccia([["lanci", "pressing"], [null, null]], "ai", 50.0, 4)
	check(con != _traccia([[null, null], [null, null]], "ai", 50.0, 4), "uno stile vero cambia la partita")
	return done()


func test_nomi_e_parametri() -> bool:
	for n: String in Stili.ATTACCO + Stili.DIFESA:
		check(Stili.NOMI.has(n) and Stili.CORTI.has(n) and Stili.SPIEGA.has(n), "testi di " + n)
		check(String(Stili.SPIEGA[n]).length() <= 75, "spiegazione corta (una riga e poco più): " + n)
	check(not Stili.att(null).on and not Stili.att("equilibrato").on and not Stili.dif("xyz").on, "predefiniti spenti")
	check(Stili.att("fasce").fasce and Stili.att("fasce").on, "fasce")
	check(Stili.dif("uomo").uomo and Stili.dif("uomo").on, "uomo")
	eq(Stili.testo("contropiede", "pressing"), "Contropiede · Pressing alto", "testo")
	eq(Stili.testo(null, 5), "Equilibrato · Equilibrata", "testo predefinito")
	return done()


# posto di un giocatore con la squadra in attacco (att = squadra) o in difesa
func _posto(m: SimMatchScript, p: R.Player, attacca: bool) -> PackedFloat64Array:
	m.att = p.team if attacca else 1 - p.team
	return m.anchor(p)


func _scena_stile(att: Variant, dif: Variant) -> SimMatchScript:
	var m := H.scene(3, [false, false])
	m.stA[0] = Stili.att(att)
	m.stD[0] = Stili.dif(dif)
	return m


func test_posizioni_degli_stili() -> bool:
	var base := _scena_stile(null, null)
	var d: R.Player = base.players[2]  # difensore centrale (4-4-2)
	var cl: R.Player = base.players[5] # centrocampista largo
	var a: R.Player = base.players[9]  # punta
	var y_d_att := _posto(base, d, true)[1]
	var y_a_att := _posto(base, a, true)[1]
	var x_c_att := absf(_posto(base, cl, true)[0])
	var y_d_dif := _posto(base, d, false)[1]
	var x_c_dif := absf(_posto(base, cl, false)[0])
	var contro := _scena_stile("contropiede", null)
	check(_posto(contro, contro.players[2], true)[1] < y_d_att - 3.0, "contropiede: difensori più bassi in attacco")
	check(_posto(contro, contro.players[9], true)[1] > y_a_att + 1.5, "contropiede: punte più alte")
	var fasce := _scena_stile("fasce", null)
	# il centrocampista largo del 4-4-2 (bx 0,78) è già largo; quello del 4-3-3 (bx 0,5) lo diventa con le fasce
	var m433 := H.newMatch(3, 9999.0, [false, false], H.mkTeam("A", 60, 22, "4-3-3"), H.mkTeam("B", 60, 23))
	var c433: R.Player = m433.players[5]
	var x_base := absf(_posto(m433, c433, true)[0])
	m433.stA[0] = Stili.att("fasce")
	check(absf(_posto(m433, c433, true)[0]) > x_base + 6.0, "fasce: anche la mezzala sta larga (%.1f → %.1f)" % [x_base, absf(_posto(m433, c433, true)[0])])
	check(absf(_posto(fasce, fasce.players[5], true)[0]) >= x_c_att - 0.01, "fasce: l'esterno resta largo")
	var press := _scena_stile(null, "pressing")
	check(_posto(press, press.players[2], false)[1] > y_d_dif + 5.0, "pressing: linea più alta")
	var cat := _scena_stile(null, "catenaccio")
	check(_posto(cat, cat.players[2], false)[1] < y_d_dif - 7.0, "catenaccio: linea più bassa")
	check(absf(_posto(cat, cat.players[5], false)[0]) < x_c_dif - 2.0, "catenaccio: più stretti")
	var off := _scena_stile(null, "fuorigioco")
	check(_posto(off, off.players[2], false)[1] > y_d_dif + 1.5, "fuorigioco: linea più alta")
	return done()


# scena: la squadra 1 (B) ha il pallone a centrocampo nella metà della squadra 0; difende la squadra 0 col suo stile
func _difesa(dif: Variant, cx: float = 0.0, cy: float = 10.0) -> SimMatchScript:
	var m := H.newMatch(5, 9999.0, [false, false], H.mkTeam("A", 60, 36), H.mkTeam("B", 60, 70))
	m.stD[0] = Stili.dif(dif)
	m.phase = "play"
	m.restart = null
	var c: R.Player = m.players[20]
	H.wake(c, cx, cy)
	c.fy = -1.0
	H.give(m, c)
	m.att = 1
	m.computeChasers()
	m.computeLines()
	return m


func test_pressing_due_sul_portatore() -> bool:
	var m := _difesa("pressing")
	var c: R.Player = m.ball.owner
	var p2: R.Player = m.presser2[0]
	check(p2 != null and p2 != m.presser[0], "c'è il secondo pressatore")
	m.dtT = DT
	m.assign(p2)
	check(C.hyp(p2.tx - c.x, p2.ty - c.y) < 2.0, "il secondo pressatore va sul portatore")
	var base := _difesa(null)
	check(base.presser2[0] == null, "senza stile niente secondo pressatore")
	return done()


func test_catenaccio_non_pressa_lontano() -> bool:
	var m := _difesa("catenaccio", 0.0, 20.0) # portatore a 70 m dalla porta della squadra 0
	var pr: R.Player = m.presser[0]
	m.dtT = DT
	m.assign(pr)
	var c: R.Player = m.ball.owner
	near(C.hyp(pr.tx - c.x, pr.ty - c.y), Stili.CAT_HOLD, 0.01, "resta davanti al portatore a CAT_HOLD m")
	check(pr.ty < c.y, "dal lato della propria porta")
	var vicino := _difesa("catenaccio", 0.0, -25.0) # a 25 m dalla propria porta: si pressa
	var pr2: R.Player = vicino.presser[0]
	vicino.dtT = DT
	vicino.assign(pr2)
	check(C.hyp(pr2.tx - vicino.ball.x, pr2.ty - vicino.ball.y) < 1.5, "vicino all'area si va sul pallone")
	return done()


func test_marcatura_a_uomo() -> bool:
	var m := _difesa("uomo")
	var mk: Dictionary = m.marks[0]
	eq(mk.size(), 8, "4 difensori e 4 centrocampisti hanno il loro uomo")
	var visti := {}
	for k: int in mk:
		check(m.players[mk[k]].team == 1 and m.players[mk[k]].pos != "P", "avversario di movimento")
		check(not visti.has(mk[k]), "nessun avversario marcato da due")
		visti[mk[k]] = true
	# i difensori marcano le punte avversarie
	var punte := 0
	for k: int in mk:
		if m.players[k].pos == "D" and m.players[mk[k]].pos == "A":
			punte += 1
	eq(punte, 2, "le due punte sono marcate da difensori")
	# chi marca sta vicino al suo uomo, dal lato della propria porta (un difensore che non pressa e non copre)
	var d: R.Player = null
	for i in range(1, 5):
		if m.players[i] != m.presser[0] and m.players[i] != m.cover[0]:
			d = m.players[i]
	var o: R.Player = m.players[mk[d.i]]
	H.wake(o, 6.0, -20.0)
	m.dtT = DT
	m.assign(d)
	check(C.hyp(d.tx - o.x, d.ty - o.y) < 4.0, "segue il suo uomo (%.1f m)" % C.hyp(d.tx - o.x, d.ty - o.y))
	check(d.ty < o.y, "dal lato della propria porta")
	return done()


func test_fuorigioco_linea_unica() -> bool:
	var m := _difesa("fuorigioco")
	m.dtT = DT
	var ys: Array = []
	for i in range(1, 5):
		var d: R.Player = m.players[i]
		if d == m.presser[0] or d == m.cover[0]:
			continue
		m.assign(d)
		ys.append(d.ty)
	check(ys.size() >= 2, "almeno due difensori in linea")
	for y: float in ys:
		near(y, ys[0], 1e-9, "difensori sulla stessa linea")
	check(ys[0] < m.ball.y - Stili.OFF_BALL + 1e-9, "linea dietro al pallone")
	return done()


func test_contropiede_finestra() -> bool:
	var m := H.scene(2, [false, false])
	m.stA[0] = Stili.att("contropiede")
	var a: R.Player = m.players[9]
	H.wake(a, 0.0, -10.0)
	m.possWho = 1
	H.give(m, a)
	m.step(DT) # think vede il cambio di possesso (intanto la CPU può già aver calciato)
	near(m.possT0[0], m.time, 1e-9, "istante del recupero")
	H.give(m, a)
	check(m.counter(0), "appena rubato il pallone: contropiede")
	m.time += Stili.CONTRO_WIN + 0.1
	check(not m.counter(0), "dopo CONTRO_WIN no")
	return done()


# partite brevi IA contro IA: conteggi della squadra 0 con lo stile (stessi semi con e senza)
func _conta(att: Variant, partite: int) -> Dictionary:
	var r := {"pass": 0, "loft": 0, "cross": 0, "dist": 0.0}
	for k in partite:
		var ta := H.mkTeam("A", 64, k * 7 + 3)
		if att != null:
			ta["stileAtt"] = att
		var m := H.newMatch(k + 11, 40.0, [false, false], ta, H.mkTeam("B", 64, k * 5 + 2))
		var steps := 0
		while m.phase != "full" and steps < 60 * 200:
			m.step(DT)
			steps += 1
			if m.phase == "half":
				m.startSecondHalf()
			for e: Dictionary in m.events:
				if e.type == "kick" and e.p.team == 0 and (e.kind == "ground" or e.kind == "loft"):
					r.pass += 1
					if e.kind == "loft":
						r.loft += 1
						if absf(e.p.x) > 9.0 and e.p.y > 14.0:
							r.cross += 1
			m.events.clear()
	return r


func test_stili_d_attacco_si_distinguono() -> bool:
	var base := _conta(null, 4)
	var lanci := _conta("lanci", 4)
	var poss := _conta("possesso", 4)
	var fasce := _conta("fasce", 4)
	note("base %s · lanci %s · possesso %s · fasce %s" % [str(base), str(lanci), str(poss), str(fasce)])
	var q := func(r: Dictionary) -> float: return float(r.loft) / maxf(1.0, float(r.pass))
	check(q.call(lanci) > q.call(base) * 1.5, "lanci lunghi: più lanci alti")
	check(q.call(poss) < q.call(base), "possesso: meno lanci alti")
	check(poss.pass > base.pass, "possesso: più passaggi")
	check(fasce.cross > base.cross, "fasce: più cross")
	return done()


# ---------------------------------------------------------------- carriera
func _nuova(nome_file: String, seme: int = 77) -> CarrieraScript:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + nome_file
	Salv.cancella(c.percorso)
	c.create("Prova Stili", 2, seme)
	return c


func test_carriera_salvataggio_vecchio_e_scelta() -> bool:
	var c := _nuova("vecchio.json")
	eq(c.stileAtt(), "equilibrato", "nuova carriera: attacco equilibrato")
	eq(c.stileDif(), "equilibrata", "nuova carriera: difesa equilibrata")
	var st: Dictionary = c.s.duplicate(true)
	st.erase("stileAtt")
	st.erase("stileDif")
	Salv.scrivi(c.percorso, st)
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "salvataggio senza stili si carica")
	eq(c2.s.get("stileAtt"), "equilibrato", "campo nuovo col predefinito")
	eq(c2.s.get("stileDif"), "equilibrata", "campo nuovo col predefinito")
	c2.setStili("fasce", null)
	c2.setStili(null, "uomo")
	c2.setStili("nonesiste", null)
	var c3 := CarrieraScript.new()
	c3.percorso = c.percorso
	check(c3.load(), "si ricarica")
	eq(c3.stileAtt(), "equilibrato", "valore sconosciuto = predefinito")
	eq(c3.stileDif(), "uomo", "difesa salvata")
	c3.setStili("fasce", null)
	var sq := c3.squadraPartita()
	eq([sq.stileAtt, sq.stileDif], ["fasce", "uomo"], "la mia squadra porta in partita gli stili scelti")
	c.reset()
	return done()


func test_stile_della_cpu_fisso_e_coerente() -> bool:
	var c := _nuova("cpu.json")
	var visti := {}
	for id: String in c.s.teams:
		if id == "me":
			continue
		var t: Dictionary = c.s.teams[id]
		var a := c.stileDi(t)
		eq(c.stileDi(t), a, "stesso stile ogni volta: " + str(t.name))
		var sq := c.avversarioPartita(t)
		eq([sq.stileAtt, sq.stileDif], [a.att, a.dif], "in partita lo stile mostrato: " + str(t.name))
		eq(c.formazioneDi(t), c.aiMatchTeam(t).formation, "formazione come aiMatchTeam")
		visti[a.att] = true
		visti[a.dif] = true
	# su tante squadre finte escono tutti gli stili
	for k in 400:
		var st := Stili.perSquadra(k * 7919 + 1, ["Atletico X", "Real Y", "Robur Z", "Nuova W"][k % 4], 50.0 + (k % 35), ["4-4-2", "4-3-3", "3-5-2", "4-2-3-1"][k % 4])
		visti[st.att] = true
		visti[st.dif] = true
	for n: String in Stili.ATTACCO + Stili.DIFESA:
		check(visti.has(n), "lo stile %s esce per qualche squadra" % n)
	# identità: tra le "Fortitudo" deboli il catenaccio esce più spesso che tra le "Real" forti
	var cat := [0, 0]
	for k in 300:
		if Stili.perSquadra(k * 31 + 5, "Fortitudo A", 52.0, "4-4-2").dif == "catenaccio":
			cat[0] += 1
		if Stili.perSquadra(k * 31 + 5, "Real A", 78.0, "4-3-3").dif == "catenaccio":
			cat[1] += 1
	check(cat[0] > cat[1] * 2, "catenaccio: Fortitudo deboli %d, Real forti %d" % cat)
	c.reset()
	return done()


# ---------------------------------------------------------------- portatore umano automatico
func _auto(att: Variant, x: float = 0.0, y: float = -20.0, opps := []) -> SimMatchScript:
	var m := H.scene(6, [true, false])
	m.portaAuto = true
	m.stA[0] = Stili.att(att)
	var p: R.Player = m.players[7]
	H.wake(p, x, y)
	p.fy = 1.0
	m.ctrl[0] = p
	H.give(m, p)
	for k in opps.size():
		H.wake(m.players[12 + k], opps[k][0], opps[k][1])
	return m


func test_portatore_automatico_avanza_e_resta_in_campo() -> bool:
	for start: Array in [[0.0, -20.0], [28.0, -10.0], [-29.0, 20.0], [5.0, 30.0]]:
		var m := _auto(null, start[0], start[1])
		var p: R.Player = m.ball.owner
		var y0: float = p.y
		var fuori := false
		for i in 240:
			m.step(DT)
			m.events.clear()
			if absf(p.x) > m.HW - 1.0 or absf(p.y) > m.HL - 1.0:
				fuori = true
		check(not fuori, "resta in campo (partenza %s)" % str(start))
		check(m.ball.owner == p, "tiene palla da solo (partenza %s)" % str(start))
		check(p.y > y0 + 3.0 or p.y > m.HL - 12.0, "avanza verso la porta (%.1f → %.1f)" % [y0, p.y])
		eq(m.stats.shots[0], 0, "non tira da solo")
	# senza portaAuto: come prima (avanza piano e dritto)
	var vec := _auto(null)
	vec.portaAuto = false
	vec.step(DT)
	near(vec.ball.owner.spdF, 0.7, 1e-9, "senza portaAuto: andatura di prima")
	return done()


func test_portatore_automatico_non_passa_e_gira_intorno() -> bool:
	# difensore fermo 9 m davanti: il portatore non gli va addosso
	var m := _auto(null, 0.0, -10.0, [[0.0, -1.0]])
	var p: R.Player = m.ball.owner
	var o: R.Player = m.players[12]
	o.stun = 999.0 # fermo, non contrasta
	var kicks := 0
	var minimo := 99.0
	for i in 150:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "kick":
				kicks += 1
		m.events.clear()
		minimo = minf(minimo, C.hyp(p.x - o.x, p.y - o.y))
	eq(kicks, 0, "non passa e non tira da solo")
	check(minimo > 1.8, "non va a sbattere sul difensore (%.1f m)" % minimo)
	return done()


func test_strada_disegnata_vince() -> bool:
	var m := _auto(null, 0.0, -20.0)
	var p: R.Player = m.ball.owner
	check(m.userPath(0, [{"x": -15.0, "y": -22.0}, {"x": -25.0, "y": -24.0}]), "strada accettata")
	for i in 90:
		m.step(DT)
		m.events.clear()
	check(p.x < -8.0, "segue la strada verso sinistra (x %.1f)" % p.x)
	check(p.y < -17.0, "non va avanti per conto suo (y %.1f)" % p.y)
	return done()


func _corsa(att: Variant, x: float = 14.0, y: float = -15.0, sec: float = 2.5) -> Dictionary:
	var m := _auto(att, x, y)
	var p: R.Player = m.ball.owner
	var x0: float = p.x
	var y0: float = p.y
	var spr := 0
	for i in int(sec * 60.0):
		m.step(DT)
		m.events.clear()
		if p.sprint:
			spr += 1
	return {"dy": p.y - y0, "dx": absf(p.x) - absf(x0), "spr": spr}


func test_stili_muovono_il_portatore_in_modo_diverso() -> bool:
	var base := _corsa(null)
	var contro := _corsa("contropiede")
	var poss := _corsa("possesso")
	var fasce := _corsa("fasce")
	var lanci := _corsa("lanci")
	note("avanzata in 2,5 s: base %s · contro %s · poss %s · fasce %s · lanci %s" % [base, contro, poss, fasce, lanci])
	check(contro.dy > base.dy + 1.0, "contropiede: punta la porta più veloce")
	check(contro.spr > 0, "contropiede: scatta con la strada libera")
	check(poss.dy < base.dy - 1.0, "possesso: avanza piano")
	check(lanci.dy < poss.dy, "lanci lunghi: resta quasi fermo, testa alta")
	check(fasce.dx > base.dx + 2.0, "fasce: va verso la linea laterale")
	return done()


func test_rallenty_partono_come_prima() -> bool:
	# difensore davanti (per linee) entro 7 m dal percorso: col portatore automatico il duello si apre lo stesso
	var m := _auto(null, 0.0, -10.0, [[0.0, -2.0]])
	var evs := H.run(m, 1.0)
	check(hasEvent(evs, "duel_start"), "duello aperto")
	check(m.duel != null, "duello in corso")
	# avversario alla pari: fuga (tasto Scatto)
	var f := _auto(null, 0.0, -10.0, [[2.5, -10.5]])
	var evs2 := H.run(f, 0.3)
	check(hasEvent(evs2, "flee_start"), "fuga aperta")
	# area di tiro: portatore negli ultimi 20 m
	var z := _auto(null, 0.0, 33.0)
	H.run(z, 0.2)
	check(z.inZone(0), "area di tiro")
	return done()
