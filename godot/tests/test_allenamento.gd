# Allenamento guidato (scripts/partita/allenamento.gd, porting di src/tutorial.js): gli stessi casi di
# test/unit/tutorial.test.mjs e le due prove della lezione Dribbling di test/unit/dribble-beat.test.mjs
# (il difensore saltato non si attacca al portatore, il tasto della prova nuova funziona subito).
extends "test_base.gd"

const Allenamento := preload("res://scripts/partita/allenamento.gd")
const REPS := Allenamento.REPS


## interfaccia finta che registra quello che l'allenamento mostra
class Registro:
	extends RefCounted
	var texts: Array = []      # [titolo, testo, prova, prove, bene]
	var cards: Array = []      # titolo della lezione, o null alla fine

	func text(titolo: String, testo: String, prova: int, prove: int, bene: bool) -> void:
		texts.append([titolo, testo, prova, prove, bene])

	func card(lezione: Variant, _i: int, _n: int) -> void:
		cards.append(lezione.title if lezione != null else null)


func nuova_partita(seed_value: int = 5, a: float = 60.0, b: float = 40.0, sa: int = 1, sb: int = 2) -> SimMatchScript:
	return H.newMatch(seed_value, Allenamento.HALF_LEN, [true, false], H.mkTeam("A", a, sa), H.mkTeam("B", b, sb))


# un fotogramma come in gioco.gd: blocca, muove, controlla gli eventi, poi li consuma
func fotogramma(m: SimMatchScript, t: Allenamento, dt: float = DT) -> void:
	t.before()
	m.step(dt)
	t.after(dt)
	m.events.clear()


func a_lezione(t: Allenamento, titolo: String) -> void:
	while t.lesson().title != titolo:
		t.next_lesson()


# comandi "da telefono" che superano ogni lezione (DRIVE del test JS)
func comanda(m: SimMatchScript, t: Allenamento) -> void:
	var c: R.Player = m.ctrl[0]
	var b := m.ball
	match t.lesson().title:
		"Passaggio rasoterra", "Passaggio a effetto": # linea dalla palla al compagno: dritta o curva
			var q: R.Player = m.players[9]
			if c != null and b.owner == c:
				var curva := 6.0 if t.lesson().id == "passaggio_alto" else 0.0
				m.userKick(0, {"type": "auto", "tx": q.x, "ty": q.y, "curve": curva, "tratto": true})
		"Tiro rasoterra", "Tiro a giro":
			if c != null and b.owner == c:
				var giro: bool = t.lesson().id == "tiro_giro"
				m.userKick(0, {"type": "shot", "tx": 2.0, "ty": 50.0, "th": 1.2 if giro else 0.5, "curve": 4.0 if giro else 0.0, "tratto": true})
		"Recupera palla": # linea dal proprio giocatore fino al portatore avversario
			if c != null and b.owner != null and b.owner.team == 1 and m.runOf(c) == null:
				m.userRun(0, c, [{"x": (c.x + b.x) / 2.0, "y": (c.y + b.y) / 2.0}, {"x": b.x, "y": b.y}])
		"Dribbling":
			if m.duelFor(0):
				m.userDribble(0)
			elif c != null:
				m.userMove(0, c.x, c.y + 4.0, true)
		"Scatto": # avversario alle spalle: la fuga si apre da sola, poi il tasto
			if m.fleeFor(0):
				m.userSprint(0)
		"Portiere":
			if m.diveWin(0):
				var s := b.shot
				var g := m.gk(0)
				m.userDive(0, s.cx - g.x, s.ch)


func test_ogni_meccanica_ha_una_scheda_e_tre_prove_superate() -> bool:
	# Arrange
	var m := nuova_partita()
	var r := Registro.new()
	var t := Allenamento.new(m, r)
	var passed := {}
	# Act
	var guard := 0
	while guard < 60 * 60 * 8 and not t.finished:
		guard += 1
		if t.card:
			t.go()
			continue
		var L := t.lesson()
		var k_prima := t.k
		if t.done <= 0.0:
			comanda(m, t)
		fotogramma(m, t)
		if t.done > 1.25 and k_prima == t.k:
			passed[L.title] = int(passed.get(L.title, 0)) + 1
	# Assert
	check(t.finished, "allenamento concluso; lezioni superate: %s" % passed)
	var titoli: Array = []
	for l: Dictionary in t.lessons:
		titoli.append(l.title)
	eq(r.cards.slice(0, r.cards.size() - 1), titoli, "una scheda per lezione, in ordine")
	eq(r.cards[-1], null, "scheda finale di chiusura")
	var bravo := 0
	for x: Array in r.texts:
		if x[1] == Allenamento.BRAVO:
			bravo += 1
	eq(bravo, t.lessons.size() * REPS, "tre riuscite per lezione")
	eq(t.lessons.size(), 8, "otto lezioni (passaggi e tiri dritti e curvi; il motore sa fare dribbling e scatto)")
	note("lezioni superate (fotogrammi di Bravo!): %s · %d fotogrammi" % [passed, guard])
	H.disposeAll()
	return done()


func test_le_tre_prove_partono_da_situazioni_diverse() -> bool:
	for L: Dictionary in Allenamento.LESSONS:
		var pos: Array = []
		for k in REPS:
			var m := nuova_partita()
			var t := Allenamento.new(m, Registro.new())
			a_lezione(t, L.title)
			t.go()
			t.k = k
			t.reset()
			var who: R.Player = m.ball.owner
			pos.append("%.0f,%.0f" % [who.x, who.y])
		var unici := {}
		for p: String in pos:
			unici[p] = true
		eq(unici.size(), pos.size(), "%s: %s" % [L.title, " | ".join(pos)])
	H.disposeAll()
	return done()


func test_se_la_prova_non_riesce_entro_il_tempo_si_rimette_a_posto() -> bool:
	var m := nuova_partita()
	var r := Registro.new()
	var t := Allenamento.new(m, r)
	t.go()
	for i in 18 * 60: # nessun comando
		fotogramma(m, t)
	eq(t.li, 0, "stessa lezione")
	eq(t.k, 0, "stessa prova")
	check(r.texts.size() >= 2, "la prova è stata riproposta")
	check(m.ball.owner == m.players[7], "pallone di nuovo al portatore della prova")
	H.disposeAll()
	return done()


func test_passaggi_e_tiri_hanno_la_linea_guida_dritta_o_curva() -> bool:
	var m := nuova_partita()
	var t := Allenamento.new(m, Registro.new())
	for titolo: String in ["Passaggio rasoterra", "Passaggio a effetto", "Tiro rasoterra", "Tiro a giro"]:
		a_lezione(t, titolo)
		check(t.guida().is_empty(), "%s: scheda aperta, niente guida" % titolo)
		t.go()
		var g: Array = t.guida()
		check(g.size() > 2, "%s: linea guida" % titolo)
		if g.size() < 3:
			continue
		var a: Vector3 = g[0]
		var b: Vector3 = g[-1]
		var meta: Vector3 = g[g.size() / 2]
		var corda := Vector2(b.x - a.x, b.y - a.y)
		var pancia: float = absf(corda.normalized().cross(Vector2(meta.x - a.x, meta.y - a.y)))
		var curva: bool = t.lesson().guida == "curva"
		check(SimMatchScript.curveIsCurved(corda.length(), pancia) == curva, "%s: guida %s (pancia %.1f m su %.1f m)" % [titolo, "curva" if curva else "dritta", pancia, corda.length()])
	a_lezione(t, "Recupera palla")
	t.go()
	check(t.guida().is_empty(), "le altre lezioni non hanno la guida")
	H.disposeAll()
	return done()


func test_passaggio_a_effetto_il_rasoterra_non_basta() -> bool:
	var m := nuova_partita()
	var t := Allenamento.new(m, Registro.new())
	a_lezione(t, "Passaggio a effetto")
	t.go()
	var q: R.Player = m.players[9]
	m.userKick(0, {"type": "auto", "tx": q.x, "ty": q.y, "curve": 0.0, "tratto": true})
	var bravo := false
	for i in 240:
		fotogramma(m, t)
		if t.done > 0.0:
			bravo = true
			break
	check(not bravo, "passaggio dritto (rasoterra) nella lezione del passaggio a effetto: non vale")
	H.disposeAll()
	return done()


func test_ogni_prova_riparte_senza_linee_rimaste() -> bool:
	var m := nuova_partita()
	var t := Allenamento.new(m, Registro.new())
	a_lezione(t, "Recupera palla")
	m.userRun(0, m.players[7], [{"x": 10.0, "y": 10.0}])
	m.userRun(0, m.players[4], [{"x": -10.0, "y": 0.0}])
	t.go()
	eq(m.runs[0].size(), 0, "nessuna linea all'inizio della prova")
	var me: R.Player = m.ctrl[0]
	var x0 := me.x
	var y0 := me.y
	for i in 60:
		fotogramma(m, t)
	check(C.hyp(me.x - x0, me.y - y0) < 0.5, "il giocatore non parte da solo (%.2f m)" % C.hyp(me.x - x0, me.y - y0))
	H.disposeAll()
	return done()


# ---------------------------------------------------------------- lezione Dribbling, come sul telefono
func _nuovo_dribbling(seed_value: int) -> Allenamento:
	var m := H.newMatch(seed_value, Allenamento.HALF_LEN, [true, false], H.mkTeam("A", 55, seed_value), H.mkTeam("B", 40, seed_value + 1))
	var t := Allenamento.new(m, Registro.new())
	a_lezione(t, "Dribbling")
	t.go()
	return t


# un fotogramma vero (1/60 s) col rallenty del duello come gioco.gd (velocità del tempo verso 0,08)
func _fotogramma_rallenty(t: Allenamento, g: Dictionary) -> void:
	var m: SimMatchScript = t.m
	var target := 0.08 if m.duelFor(0) else 1.0
	g.ts += (target - g.ts) * minf(1.0, DT * 14.0)
	fotogramma(m, t, DT * g.ts)


func test_dribbling_dopo_un_tentativo_fallito_il_tasto_funziona_subito() -> bool:
	# Arrange: come dopo un dribbling fallito, attese ancora in corso quando la prova riparte
	var t := _nuovo_dribbling(3)
	var m: SimMatchScript = t.m
	var c0: R.Player = t.st.c
	c0.dribCd = 1.2
	m.duelCd[0] = 1.0
	m.duelCdP[0] = c0
	t.reset()
	# Act: il duello si apre al primo passo (difensore a 7 m)
	_fotogramma_rallenty(t, {"ts": 1.0})
	# Assert
	eq(m.duelFor(0), true, "duello aperto subito")
	eq(m.userDribble(0), true, "il tasto Dribbling funziona")
	H.disposeAll()
	return done()


func test_dribbling_si_supera_e_il_difensore_saltato_non_si_attacca() -> bool:
	const SEEDS := 8
	var attempts := 0
	var sticky := 0
	var passed := 0
	for seed_i in range(1, SEEDS + 1):
		# Arrange
		var t := _nuovo_dribbling(seed_i * 31)
		var m: SimMatchScript = t.m
		var g := {"ts": 1.0}
		var L := t.lesson()
		var since := 0.0
		var tap_c: R.Player = null
		var tap_o: R.Player = null
		# Act: tocco del tasto 1 s vero dopo l'apertura del duello, finché le 3 prove non sono superate
		var f := 0
		while f < 60 * 120 and not t.finished and t.lesson() == L:
			f += 1
			if m.duelFor(0):
				since += DT
				if since >= 1.0 and tap_c == null and m.userDribble(0):
					attempts += 1
					tap_c = t.st.c
					tap_o = t.st.o
			else:
				since = 0.0
			_fotogramma_rallenty(t, g)
			# durante il "Bravo!" (giochetto in corso) il difensore saltato, ormai superato, non sta addosso al portatore
			if t.done > 0.0 and tap_c != null and tap_c.y > tap_o.y + 0.5 and dist(tap_c, tap_o) < 1.2:
				sticky += 1
			if t.done <= 0.0 and not m.duelFor(0):
				tap_c = null
				tap_o = null
		if t.finished or t.lesson() != L:
			passed += 1
	# Assert
	eq(passed, SEEDS, "lezione superata in tutte le partite")
	check(attempts <= SEEDS * REPS * 1.5, "tentativi %d per %d prove superate" % [attempts, SEEDS * REPS])
	eq(sticky, 0, "fotogrammi col difensore saltato attaccato al portatore")
	note("dribbling: %d tentativi per %d prove superate" % [attempts, SEEDS * REPS])
	H.disposeAll()
	return done()
