# Momenti chiave (scripts/partita/momenti.gd): numero di azioni (~10), almeno 3 d'attacco, proporzione secondo la
# forza, partenza da centrocampo col pallone alla squadra giusta, occasioni vere, punteggio coerente (gol giocati +
# simulati = punteggio = marcatori), tutto ripetibile col seme; conteggi del resto simulato; salvataggio vecchio.
extends "test_base.gd"

const Momenti := preload("res://scripts/partita/momenti.gd")
const ContaGiocatori := preload("res://scripts/partita/conta_giocatori.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const TIRI := ["shot", "volley", "header"]


static func _conta_att(piano: Array) -> int:
	return piano.filter(func(a: Dictionary) -> bool: return a.tipo == "att").size()


func _partita(seme: int, mia: float = 60.0, loro: float = 60.0, human: Array = [false, false]) -> SimMatchScript:
	return H.newMatch(seme, Momenti.HALF_LEN, human, H.mkTeam("A", mia, seme * 7 + 1), H.mkTeam("B", loro, seme * 13 + 5))


func test_circa_dieci_azioni() -> bool:
	for s in range(1, 120):
		var p := Momenti.piano_azioni(60.0, 60.0, s)
		check(p.size() >= 9 and p.size() <= 11, "seme %d: %d azioni" % [s, p.size()])
	return done()


func test_almeno_tre_in_attacco_anche_scarsi() -> bool:
	for s in range(1, 120):
		var debole := Momenti.piano_azioni(35.0, 90.0, s)
		eq(_conta_att(debole), Momenti.MIN_ATT, "squadra molto più scarsa, seme %d: azioni d'attacco" % s)
		var forte := Momenti.piano_azioni(90.0, 35.0, s)
		check(forte.size() - _conta_att(forte) >= Momenti.MIN_DIF, "squadra molto più forte, seme %d: qualche azione in difesa" % s)
		check(_conta_att(forte) > _conta_att(debole), "più forte = più attacco, seme %d" % s)
	return done()


func test_proporzione_secondo_la_forza() -> bool:
	var medie: Array = []
	for diff: float in [-14.0, -5.0, 0.0, 5.0, 14.0]:
		var tot := 0.0
		for s in range(1, 80):
			var p := Momenti.piano_azioni(60.0 + diff / 2.0, 60.0 - diff / 2.0, s)
			tot += float(_conta_att(p)) / p.size()
		medie.append(tot / 79.0)
	note("quota d'attacco media per differenza -14, -5, 0, +5, +14: %s" % str(medie.map(func(x: float) -> String: return "%.2f" % x)))
	for i in range(1, medie.size()):
		check(medie[i] > medie[i - 1], "la quota cresce con la forza: %s" % str(medie))
	near(medie[2], 0.5, 0.06, "forze uguali: metà e metà")
	return done()


func test_minuti_in_ordine_lontani_da_intervallo_e_fine() -> bool:
	for s in range(1, 120):
		var p := Momenti.piano_azioni(60.0, 60.0, s)
		var prima := 0
		var nel_primo := 0
		for a: Dictionary in p:
			var mn: int = a.minuto
			check(mn > prima + 2, "seme %d: minuti crescenti e distanziati %s" % [s, str(p.map(func(x: Dictionary) -> int: return x.minuto))])
			check(mn <= Momenti.ULTIMO_1T or mn >= Momenti.PRIMO_2T, "seme %d: niente azioni a cavallo dell'intervallo (%d)" % [s, mn])
			check(mn >= Momenti.PRIMO_MIN and mn <= Momenti.ULTIMO_MIN, "seme %d: minuto %d nei limiti" % [s, mn])
			if mn <= 45:
				nel_primo += 1
			prima = mn
		check(absi(nel_primo * 2 - p.size()) <= 1, "seme %d: metà circa nel primo tempo" % s)
	return done()


func test_partenza_da_centrocampo() -> bool:
	for me in 2:
		for tipo: String in ["att", "dif"]:
			for variante: String in ["contropiede", "manovra"]:
				var m := _partita(31 + me)
				var mn := 23 if tipo == "att" else 61
				Momenti.prepara_azione(m, {"minuto": mn, "tipo": tipo, "variante": variante}, me)
				var tb := me if tipo == "att" else 1 - me
				var d := 1.0 if tb == 0 else -1.0
				var b := m.ball
				var cosa := "me=%d %s %s" % [me, tipo, variante]
				eq(m.phase, "play", cosa + ": si parte in gioco")
				check(b.owner != null and b.owner.team == tb, cosa + ": pallone a chi attacca")
				check(b.y * d >= 0.0 and b.y * d <= 15.0, cosa + ": a centrocampo o poco oltre (y=%.1f)" % b.y)
				eq(m.minute() + 1, mn, cosa + ": minuto dell'azione")
				eq(m.events.size(), 0, cosa + ": niente eventi di calcio d'inizio")
				# chi difende: nessuno addosso al portatore (l'azione non finisce subito) e la porta difesa
				for p: R.Player in m.team(1 - tb):
					check(dist(p, b.owner) > 2.5, cosa + ": avversario troppo vicino al portatore")
				var dietro := m.team(1 - tb).filter(func(p: R.Player) -> bool: return p.pos == "C" and (p.y - b.y) * d < 0.0).size()
				check(dietro >= (1 if tipo == "dif" else 2), cosa + ": centrocampisti avversari già saltati (%d)" % dietro)
	return done()


# le azioni d'attacco sono occasioni vere: giocate dall'IA da tutte e due le parti, spesso finiscono con un tiro
func test_occasioni_vere() -> bool:
	var tiri := 0
	var gol := 0
	var prove := 40
	for s in range(1, prove + 1):
		var m := _partita(s)
		var mo := Momenti.new(m, 0, s)
		mo.piano = [{"minuto": 20, "tipo": "att", "variante": "contropiede" if s % 2 == 0 else "manovra"}]
		mo.avvia_prossima(m)
		var tiro := false
		for i in 60 * 40:
			m.step(DT)
			for e: Dictionary in m.events:
				if e.type == "kick" and TIRI.has(e.get("kind", "")) and (e.p as R.Player).team == 0:
					tiro = true
			mo.leggi(m, DT)
			m.events.clear()
			if mo.azione_finita(m):
				break
		check(mo.esito != "", "seme %d: l'azione finisce" % s)
		tiri += 1 if tiro else 0
		gol += 1 if mo.esito == "gol" else 0
	note("azioni d'attacco IA contro IA: %d su %d con un tiro, %d gol" % [tiri, prove, gol])
	check(tiri >= prove * 0.4, "almeno 4 azioni d'attacco su 10 arrivano al tiro (%d su %d)" % [tiri, prove])
	return done()


# partita intera nei momenti chiave, IA contro IA: ritorna [m, momenti, gol giocati per squadra]
func _gioca_tutta(seme: int, mia: float = 60.0, loro: float = 60.0) -> Array:
	var m := _partita(seme, mia, loro)
	var mo := Momenti.new(m, 0, seme)
	var giocati := [0, 0]
	var guardia := 0
	while mo.stato != "fine" and guardia < 30:
		guardia += 1
		mo.simula_fino_a(m, mo.fino_alla_prossima())
		if mo.prossima().is_empty():
			mo.fischio_finale(m)
			break
		mo.avvia_prossima(m)
		for i in 60 * 60:
			m.step(DT)
			for e: Dictionary in m.events:
				if e.type == "goal":
					giocati[int(e.team)] += 1
			mo.leggi(m, DT)
			m.events.clear()
			if mo.azione_finita(m):
				break
		mo.chiudi_azione(m)
	return [m, mo, giocati]


func test_punteggio_coerente() -> bool:
	var tot := [0, 0]
	for s in range(1, 7):
		var r := _gioca_tutta(s)
		var m: SimMatchScript = r[0]
		var mo: Momenti = r[1]
		var giocati: Array = r[2]
		eq(m.phase, "full", "seme %d: partita finita" % s)
		eq(m.minute(), 90, "seme %d: orologio al 90'" % s)
		eq(mo.minuto_sim, 90, "seme %d: raccontata fino al 90'" % s)
		eq(mo.esiti.size(), mo.piano.size(), "seme %d: tutte le azioni giocate" % s)
		for t in 2:
			var nel_log := m.goalsLog.filter(func(g: Dictionary) -> bool: return int(g.team) == t).size()
			eq(m.score[t], nel_log, "seme %d squadra %d: punteggio = marcatori" % [s, t])
			check(m.score[t] >= giocati[t], "seme %d squadra %d: gol giocati compresi nel punteggio" % [s, t])
			check(m.stats.shots[t] >= m.stats.onT[t] and m.stats.onT[t] >= m.score[t] - giocati[t], "seme %d: tiri ≥ in porta ≥ gol simulati" % s)
			tot[t] += m.score[t]
		var minuti := m.goalsLog.map(func(g: Dictionary) -> int: return int(g.minute))
		var ordinati := minuti.duplicate()
		ordinati.sort()
		eq(minuti, ordinati, "seme %d: marcatori in ordine di minuto" % s)
		check(m.stats.poss[0] > 0.0 and m.stats.poss[1] > 0.0, "seme %d: possesso di tutte e due" % s)
	note("gol in 6 partite (momenti chiave, forze uguali, IA contro IA): %d – %d" % [tot[0], tot[1]])
	check(tot[0] + tot[1] >= 6 and tot[0] + tot[1] <= 45, "gol per partita plausibili (%d in 6)" % (tot[0] + tot[1]))
	return done()


func test_ripetibile_col_seme() -> bool:
	for s: int in [17]:
		eq(Momenti.piano_azioni(62.0, 55.0, s), Momenti.piano_azioni(62.0, 55.0, s), "stesso piano, seme %d" % s)
		var a := _gioca_tutta(s, 64.0, 58.0)
		var b := _gioca_tutta(s, 64.0, 58.0)
		eq((a[0] as SimMatchScript).score, (b[0] as SimMatchScript).score, "stesso risultato, seme %d" % s)
		eq((a[1] as Momenti).esiti, (b[1] as Momenti).esiti, "stessi esiti, seme %d" % s)
	check(Momenti.piano_azioni(60.0, 60.0, 1) != Momenti.piano_azioni(60.0, 60.0, 2), "semi diversi, piani diversi")
	return done()


# il resto simulato non dipende da come sono state spezzate le azioni: ogni minuto ha il suo seme
func test_simulato_uguale_comunque_spezzato() -> bool:
	var m1 := _partita(5)
	var a := Momenti.new(m1, 0, 99)
	a.simula_fino_a(m1, 90)
	var m2 := _partita(5)
	var b := Momenti.new(m2, 0, 99)
	for fino: int in [7, 19, 33, 45, 52, 70, 90]:
		b.simula_fino_a(m2, fino)
	eq(m1.score, m2.score, "stesso punteggio")
	eq(m1.goalsLog.size(), m2.goalsLog.size(), "stessi marcatori")
	eq(m1.stats.shots, m2.stats.shots, "stessi tiri")
	return done()


func test_piu_forte_segna_di_piu_nel_simulato() -> bool:
	var gol := [0, 0]
	for s in range(1, 60):
		var m := _partita(s, 75.0, 50.0)
		var mo := Momenti.new(m, 0, s)
		mo.simula_fino_a(m, 90)
		gol[0] += m.score[0]
		gol[1] += m.score[1]
	note("resto simulato 75 contro 50 in 59 partite: %d – %d" % [gol[0], gol[1]])
	check(gol[0] > gol[1] * 1.5, "la squadra più forte segna di più: %s" % str(gol))
	return done()


func test_conteggi_del_simulato() -> bool:
	var m := _partita(8)
	var conta := ContaGiocatori.new(0)
	conta.leggi(m) # chi è in campo
	var mo := Momenti.new(m, 0, 8)
	mo.simula_fino_a(m, 90, conta)
	var tab := conta.tabellino()
	var gol_miei := 0
	var tiri_miei := 0
	for g: Dictionary in tab.giocatori:
		gol_miei += int(g.conti.get("gol", 0))
		tiri_miei += int(g.conti.get("tiri", 0))
	eq(gol_miei, m.score[0], "gol simulati della mia squadra nei conteggi")
	eq(tiri_miei, m.stats.shots[0], "tiri simulati della mia squadra nei conteggi")
	eq(tab.tiri.size(), m.stats.shots[0] + m.stats.shots[1], "mappa dei tiri con quelli simulati")
	var subiti := 0
	for g: Dictionary in tab.giocatori:
		subiti = maxi(subiti, int(g.conti.get("subiti", 0)))
	eq(subiti, m.score[1], "gol subiti contati")
	return done()


func test_fine_azione() -> bool:
	# palla persa: l'azione d'attacco finisce poco dopo che l'avversario ha il pallone
	var m := _partita(4)
	var mo := Momenti.new(m, 0, 4)
	mo.piano = [{"minuto": 30, "tipo": "att", "variante": "manovra"}]
	mo.avvia_prossima(m)
	var dif: R.Player = m.team(1)[5]
	m.ball.owner = dif
	mo.leggi(m, DT)
	eq(mo.esito, "persa", "palla all'avversario = persa")
	check(not mo.azione_finita(m), "si vede ancora un attimo")
	for i in 60:
		mo.leggi(m, DT)
	check(mo.azione_finita(m), "poi l'azione è finita")
	# difesa: recupero; rigore: si continua
	var m2 := _partita(6)
	var mo2 := Momenti.new(m2, 0, 6)
	mo2.piano = [{"minuto": 60, "tipo": "dif", "variante": "manovra"}]
	mo2.avvia_prossima(m2)
	m2.events.append({"type": "foul", "by": m2.team(0)[2], "on": m2.ball.owner, "card": null, "pen": true})
	mo2.leggi(m2, DT)
	eq(mo2.esito, "", "fallo da rigore: l'azione continua col rigore")
	m2.events.clear()
	m2.ball.owner = m2.team(0)[3]
	mo2.leggi(m2, DT)
	eq(mo2.esito, "recuperata", "in difesa, pallone mio = recuperata")
	# tempo massimo
	var m3 := _partita(7)
	var mo3 := Momenti.new(m3, 1, 7)
	mo3.piano = [{"minuto": 10, "tipo": "att", "variante": "manovra"}]
	mo3.avvia_prossima(m3)
	mo3.leggi(m3, Momenti.DURATA_MAX + 0.1)
	eq(mo3.esito, "tempo", "dopo il tempo massimo l'azione sfuma")
	return done()


func test_salvataggio_vecchio_senza_momenti() -> bool:
	eq(CarrieraScript.SETTINGS_DEFAULT.get("momenti"), false, "predefinito: partita intera")
	var c := CarrieraScript.new()
	c.percorso = "user://prove_momenti/salva.json"
	c.create("Prova", 0, 5)
	c.s.settings.erase("momenti")
	c.save()
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	c2.load()
	eq(c2.s.settings.get("momenti"), false, "salvataggio vecchio: momenti spento")
	c2.reset()
	return done()
