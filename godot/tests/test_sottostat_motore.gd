# Statistiche dettagliate in partita (Luis 2026-11-25, "come su FIFA"): le sotto-statistiche di sim/sottostat.gd
# contano nel motore al posto della loro grande (accelerazione, velocità massima, tiri vicini e lontani, rigori,
# passaggi corti e lunghi, cross, effetto, punizioni, agilità, controllo, dribbling, equilibrio, intercetti,
# contrasto, elevazione, resistenza, forza, aggressività, tuffo, riflessi, presa, piazzamento).
# Senza `sub` (o con sotto-statistiche uguali alle grandi) il motore fa esattamente come prima.
extends "test_base.gd"

const Sotto := preload("../sim/sottostat.gd")
const Fisico := preload("res://scripts/carriera/fisico.gd")
const CAMPIONI := 400


## sotto-statistiche tutte uguali alla loro grande (portiere compreso)
static func _subUguali(p: Dictionary) -> Dictionary:
	var sub := {}
	for g: String in Sotto.GRUPPI:
		for k: String in Sotto.GRUPPI[g]:
			sub[k] = int(p.get(g, 50))
	return sub


## partita intera a passi di 1/60 s con le opzioni del gioco; conSub = giocatori con sotto-statistiche uguali alle grandi
func _partita(sd: int, conSub: bool) -> SimMatchScript:
	var ta := H.mkTeam("A", 62.0, sd * 7 + 1)
	var tb := H.mkTeam("B", 60.0, sd * 13 + 5, "4-3-3")
	if conSub:
		for t: Dictionary in [ta, tb]:
			for p: Dictionary in t.players:
				p["sub"] = _subUguali(p)
	var m := H.newMatch(sd, 60.0, [true, false], ta, tb, "pioggia", {"portaAuto": true, "testa": true, "rifiniture": true,
		"falli": true, "contatti": true, "parata": true, "riprese": true})
	m.headCtl = true
	var bot := H.Bot.new(sd + 9)
	var steps := 0
	while m.phase != "full" and steps < 60 * 60 * 10:
		m.step(DT)
		steps += 1
		if m.phase == "half":
			m.startSecondHalf()
		bot.stepBot(m)
		m.events.clear()
	return m


func _impronta(m: SimMatchScript) -> String:
	var parti: Array = [m.score, m.time, m.ball.x, m.ball.y, m.ball.h]
	for p: R.Player in m.players:
		parti.append([p.x, p.y, p.energy])
	parti.append(m.stats.shots)
	parti.append(m.stats.saves)
	return str(parti)


func test_senza_sub_vale_la_grande() -> bool:
	var src := {"pos": "A", "vel": 70, "tir": 80, "pas": 60, "dri": 75, "dif": 30, "fis": 65, "por": 20}
	var st := C.effStats(src, "A")
	check(st.sub.is_empty(), "senza sub: niente sotto-statistiche")
	eq(st.sv("fin"), st.tir, "fin = tir")
	eq(st.sv("acc"), st.vel, "acc = vel")
	eq(st.sv("pre"), st.por, "pre = por")
	eq(st.scarto("ele"), 0.0, "scarto zero senza sub")
	return done()


func test_senza_sub_tiri_con_tir_e_passaggi_con_pas() -> bool:
	# senza sotto-statistiche ogni tiro usa `tir` e ogni passaggio `pas`, come prima (anche a giro e su punizione)
	var m := H.scene(3, [false, false])
	var p: R.Player = m.team(0)[9]
	p.st.tir = 71.0
	p.st.pas = 43.0
	for k: String in ["fin", "lon", "vol", "rig", "eff", "pun"]:
		eq(SimMatchScript.abilCalcio(p, k, "shot"), 71.0, "tiro con " + k)
	for k: String in ["pco", "plu", "cro", "eff", "pun"]:
		eq(SimMatchScript.abilCalcio(p, k, "ground"), 43.0, "passaggio con " + k)
	# con sub: il tiro a giro sente lo scarto di `eff` dalla sua grande
	p.st.sub = {"eff": 53.0}
	eq(SimMatchScript.abilCalcio(p, "eff", "shot"), 81.0, "tiro a giro con eff alto")
	eq(SimMatchScript.abilCalcio(p, "eff", "loft"), 53.0, "passaggio a giro con eff")
	return done()


func test_sub_col_malus_del_ruolo() -> bool:
	# difensore schierato in attacco (malus 0,82): le sotto-statistiche di tiro hanno lo stesso malus della grande
	var src := {"pos": "D", "vel": 70, "tir": 60, "pas": 60, "dri": 60, "dif": 80, "fis": 65, "por": 20,
		"sub": {"fin": 70, "lon": 50, "acc": 74, "vmax": 66, "res": 80, "tuf": 30}}
	var st := C.effStats(src, "A")
	near(st.sv("fin"), 70.0 * 0.82, 1e-9, "fin col malus")
	near(st.tir, 60.0 * 0.82, 1e-9, "tir col malus")
	eq(st.sv("acc"), 74.0, "velocità senza malus")
	eq(st.sv("res"), 80.0, "fisico senza malus")
	eq(st.sv("tuf"), 30.0, "portiere senza malus")
	# chi non è portiere messo in porta: al massimo 25, come `por`
	var st2 := C.effStats(src, "P")
	eq(st2.sv("tuf"), 25.0, "portiere fuori ruolo al massimo 25")
	eq(st2.por, 20.0, "por fuori ruolo come prima")
	return done()


func test_partita_identica_con_sub_uguali_alle_grandi() -> bool:
	var a := _impronta(_partita(4, false))
	var b := _impronta(_partita(4, true))
	check(a == b, "con sotto-statistiche uguali alle grandi la partita è identica")
	return done()


# --------------------------------------------------------------------- corsa
func _corsa(acc: float, vmax: float) -> Array:
	var m := H.scene(3)
	var p: R.Player = m.players[5]
	H.wake(p, 0.0, -30.0)
	p.fx = 0.0
	p.fy = 1.0
	p.st.sub = {"acc": acc, "vmax": vmax}
	var y0 := p.y
	var dopo := 0.0
	var vel := 0.0
	for i in 150:
		m.userMove(0, p.x, p.y + 30.0, true)
		m.step(DT)
		if i == 29:
			dopo = p.y - y0
	vel = C.hyp(p.vx, p.vy)
	return [dopo, vel]


func test_accelerazione_e_velocita_massima() -> bool:
	var base := C.effStats({"vel": 60, "fis": 60}, "C").vel
	var piano := _corsa(base - 15.0, base)
	var svelto := _corsa(base + 15.0, base)
	var veloce := _corsa(base, base + 15.0)
	var lento := _corsa(base, base - 15.0)
	note("in 0,5 s: acc bassa %.2f m, acc alta %.2f m · velocità finale: vmax alta %.2f, bassa %.2f m/s" % [piano[0], svelto[0], veloce[1], lento[1]])
	check(svelto[0] > piano[0], "con acc alta parte più in fretta")
	check(veloce[1] > lento[1] + 0.5, "con vmax alta corre più veloce")
	return done()


# --------------------------------------------------------------------- tiri
func _tiratore(m: SimMatchScript, y: float) -> R.Player:
	var p: R.Player = m.team(0)[9]
	H.wake(p, 0.0, y)
	p.fx = 0.0
	p.fy = 1.0
	H.give(m, p)
	return p


func _sparpaglio(m: SimMatchScript, p: R.Player, spec: Dictionary) -> float:
	var somma := 0.0
	var somma2 := 0.0
	var a0: float = atan2(float(spec.ty) - m.ball.y, float(spec.tx) - m.ball.x)
	for i in CAMPIONI:
		var L: Dictionary = m.launch(p, spec, true)
		var a: float = rad_to_deg(wrapf(atan2(float(L.vy), float(L.vx)) - a0, -PI, PI))
		somma += a
		somma2 += a * a
	var media := somma / CAMPIONI
	return sqrt(maxf(0.0, somma2 / CAMPIONI - media * media))


func test_finalizzazione_e_tiri_da_lontano() -> bool:
	var m := H.scene(3, [false, false])
	var spec := {"type": "shot", "tx": 2.0, "ty": 50.0, "th": 1.0}
	var p := _tiratore(m, 38.0) # 12 m: conta `fin`
	var t: float = p.st.tir
	p.st.sub = {"fin": t + 25.0, "lon": t - 25.0}
	var bravo := _sparpaglio(m, p, spec)
	p.st.sub = {"fin": t - 25.0, "lon": t + 25.0}
	var scarso := _sparpaglio(m, p, spec)
	note("in area: fin alta %.2f°, fin bassa %.2f°" % [bravo, scarso])
	check(bravo < scarso * 0.8, "con fin alta tira più preciso in area")
	H.wake(p, 0.0, 22.0) # 28 m: conta `lon`
	H.give(m, p)
	var lontano_bravo := _sparpaglio(m, p, spec)
	p.st.sub = {"fin": t + 25.0, "lon": t - 25.0}
	var lontano_scarso := _sparpaglio(m, p, spec)
	note("da 28 m: lon alta %.2f°, lon bassa %.2f°" % [lontano_bravo, lontano_scarso])
	check(lontano_bravo < lontano_scarso * 0.8, "con lon alta tira più preciso da lontano")
	return done()


func test_potenza_del_tiro() -> bool:
	var m := H.scene(3, [false, false])
	var spec := {"type": "shot", "tx": 2.0, "ty": 50.0, "th": 1.0}
	var p := _tiratore(m, 30.0)
	var t: float = p.st.tir
	p.st.sub = {"pot": t + 20.0}
	var forte: float = m.launch(p, spec, false).v0
	p.st.sub = {"pot": t - 20.0}
	var debole: float = m.launch(p, spec, false).v0
	check(forte > debole + 4.0, "pot alta tira più forte (%.1f contro %.1f m/s)" % [forte, debole])
	return done()


func test_girata_meno_cara_con_vol_alto() -> bool:
	var m := H.scene(3, [false, false])
	m.rifiniture = true
	var spec := {"type": "shot", "tx": 2.0, "ty": 50.0, "th": 1.0}
	var p := _tiratore(m, 36.0)
	p.fx = 0.0
	p.fy = -1.0 # spalle alla porta
	var t: float = p.st.tir
	p.st.sub = {"vol": t + 20.0, "pot": t}
	var bravo: float = m.launch(p, spec, false).v0
	p.st.sub = {"vol": t - 20.0, "pot": t}
	var scarso: float = m.launch(p, spec, false).v0
	check(bravo > scarso * 1.1, "da girato con vol alto il tiro resta più forte (%.1f contro %.1f)" % [bravo, scarso])
	return done()


func test_passaggi_corti_e_lunghi() -> bool:
	var m := H.scene(3, [false, false])
	var p := _tiratore(m, -10.0)
	var a: float = p.st.pas
	var corto := {"type": "ground", "tx": 0.0, "ty": 2.0}
	p.st.sub = {"pco": a + 25.0, "plu": a - 25.0}
	var c_bravo := _sparpaglio(m, p, corto)
	p.st.sub = {"pco": a - 25.0, "plu": a + 25.0}
	var c_scarso := _sparpaglio(m, p, corto)
	check(c_bravo < c_scarso * 0.8, "pco alto: passaggio corto più preciso (%.2f° contro %.2f°)" % [c_bravo, c_scarso])
	var lungo := {"type": "loft", "tx": 0.0, "ty": 25.0}
	var l_bravo := _sparpaglio(m, p, lungo)
	p.st.sub = {"pco": a + 25.0, "plu": a - 25.0}
	var l_scarso := _sparpaglio(m, p, lungo)
	check(l_bravo < l_scarso * 0.8, "plu alto: lancio lungo più preciso (%.2f° contro %.2f°)" % [l_bravo, l_scarso])
	return done()


func test_quale_sotto_statistica_nel_calcio() -> bool:
	var m := H.scene(3, [false, false])
	var p := _tiratore(m, 30.0)
	var tiro := {"type": "shot", "tx": 0.0, "ty": 50.0}
	eq(m.subCalcio(p, tiro, "shot", 0.0, 12.0, false, 0.0), "fin", "tiro vicino")
	eq(m.subCalcio(p, tiro, "shot", 0.0, 25.0, false, 0.0), "lon", "tiro lontano")
	eq(m.subCalcio(p, tiro, "shot", 0.0, 12.0, true, 0.0), "eff", "tiro a giro")
	eq(m.subCalcio(p, tiro, "shot", 0.0, 12.0, false, 0.4), "vol", "tiro girato")
	eq(m.subCalcio(p, {"type": "shot", "tx": 0.0, "ty": 50.0, "first": true}, "shot", 0.0, 12.0, false, 0.0), "vol", "di prima")
	eq(m.subCalcio(p, {"type": "ground", "tx": 0.0, "ty": 40.0}, "ground", 0.0, 10.0, false, 0.0), "pco", "passaggio corto")
	eq(m.subCalcio(p, {"type": "loft", "tx": 0.0, "ty": 0.0}, "loft", 0.0, 30.0, false, 0.0), "plu", "lancio lungo")
	eq(m.subCalcio(p, {"type": "loft", "tx": 3.0, "ty": 42.0}, "loft", 25.0, 25.0, false, 0.0), "cro", "cross dalla fascia")
	eq(m.subCalcio(p, {"type": "ground", "tx": 0.0, "ty": 40.0}, "ground", 0.0, 10.0, true, 0.0), "eff", "passaggio a giro")
	m.setRestart("penalty", 0, 0.0, 0.0)
	eq(m.subCalcio(p, tiro, "shot", 0.0, 11.0, false, 0.0), "rig", "rigore")
	m.setRestart("freekick", 0, 0.0, 25.0)
	eq(m.subCalcio(p, tiro, "shot", 0.0, 25.0, false, 0.0), "pun", "punizione")
	return done()


# --------------------------------------------------------------------- portiere, dribbling, fatica
func test_presa_blocca_di_piu() -> bool:
	var m := H.scene(3)
	var g := m.gk(1)
	var p: float = g.st.por
	g.st.sub = {"pre": p + 20.0}
	var molte: float = m.catchChance(g, 24.0, true, 1.0)
	g.st.sub = {"pre": p - 20.0}
	var poche: float = m.catchChance(g, 24.0, true, 1.0)
	check(molte > poche, "pre alta blocca di più (%.2f contro %.2f)" % [molte, poche])
	return done()


func test_dribbling_e_contrasto() -> bool:
	var m := H.scene(3)
	var p: R.Player = m.team(0)[9]
	var o: R.Player = m.team(1)[2]
	var d0: float = m.dribbleChance(p, o)
	p.st.sub = {"drb": p.st.dri + 20.0}
	var d1: float = m.dribbleChance(p, o)
	o.st.sub = {"ctr": o.st.dif + 20.0}
	var d2: float = m.dribbleChance(p, o)
	check(d1 > d0, "drb alto dribbla meglio (%.2f contro %.2f)" % [d1, d0])
	check(d2 < d1, "ctr alto del difensore lo ferma di più (%.2f contro %.2f)" % [d2, d1])
	return done()


func _consumo(res: float) -> float:
	var m := H.scene(3)
	var p: R.Player = m.players[5]
	H.wake(p, 0.0, -30.0)
	p.energy = 1.0
	p.st.sub = {"res": res}
	H.run(m, 4.0, func(mm: SimMatchScript) -> void: mm.userMove(0, p.x, p.y + 20.0, true, true))
	return 1.0 - p.energy


func test_resistenza_stanca_meno() -> bool:
	var f: float = C.effStats({"fis": 60}, "C").fis
	var tanto := _consumo(f - 25.0)
	var poco := _consumo(f + 25.0)
	note("energia usata in 4 s di scatto: res bassa %.4f, res alta %.4f" % [tanto, poco])
	check(poco < tanto * 0.8, "con res alta si stanca meno")
	return done()


func test_intercetti() -> bool:
	var m := H.scene(3)
	var o: R.Player = m.team(1)[2]
	var k := R.Kick.make(0, m.team(0)[5], "ground", 0.0, [], false)
	m.ball.kick = k
	var r0: float = m.reachOf(o)
	o.st.sub = {"int": o.st.dif + 20.0}
	check(m.reachOf(o) > r0, "int alto: intercetta da più lontano")
	return done()


func test_salto_conteso_con_elevazione() -> bool:
	var m := H.scene(3)
	var p: R.Player = m.team(0)[9]
	var a0: float = m.aereo(p)
	p.st.sub = {"ele": p.st.fis + 15.0}
	near(m.aereo(p), a0 + 15.0, 1e-9, "ele alta: più forza nei salti contesi")
	return done()


# --------------------------------------------------------------------- fisico (scripts/carriera/fisico.gd)
func test_fisico_sposta_anche_le_sotto_statistiche() -> bool:
	var p := {"id": 7, "name": "Prova", "pos": "D", "vel": 60, "tir": 50, "pas": 55, "dri": 58, "dif": 70, "fis": 66,
		"por": 20, "tes": 70, "altezza": 2, "corporatura": 2, "sub": {"acc": 62, "vmax": 58, "int": 72, "ctr": 68,
		"agi": 60, "ctl": 57, "drb": 56, "equ": 59, "ele": 66, "res": 66, "frz": 66, "agg": 66}}
	var q: Dictionary = Fisico.applica(p)
	# alto + robusto: dif +2 +4, vel -1 -2, dri -2, fis -2
	eq(int(q.dif), 76, "dif spostata")
	eq(int(q.sub.int), 78, "int spostata come dif")
	eq(int(q.sub.ctr), 74, "ctr spostata come dif")
	eq(int(q.sub.acc), 59, "acc spostata come vel")
	eq(int(q.sub.drb), 54, "drb spostata come dri")
	eq(int(q.sub.res), 64, "res spostata come fis")
	eq(int(p.sub.int), 72, "l'originale non cambia")
	# senza sub: niente sub nella copia
	var senza: Dictionary = p.duplicate()
	senza.erase("sub")
	check(not Fisico.applica(senza).has("sub"), "senza sub resta senza")
	return done()
