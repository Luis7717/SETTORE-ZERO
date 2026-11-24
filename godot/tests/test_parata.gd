# Parata col fermatempo (sim/parata.gd): bersaglio sulla porta, punto scelto rispettato, scadenza senza linea, limiti
# veri del tuffo (non tutti i tiri sono parabili) e durata del fermatempo (scripts/partita/fermatempo_parata.gd).
extends "test_base.gd"

const FP := preload("res://scripts/partita/fermatempo_parata.gd")
const SimRngScript := preload("res://sim/rng.gd")
const ParataScript := preload("res://sim/parata.gd")


## tiro della squadra 1 verso la nostra porta (y = −HL) da (sx, −HL + dist) al punto (tx, th) della porta.
## Difesa parcheggiata, portiere al centro. Ritorna [m, tiratore]
func tiro(sd: int, sx: float, dist: float, tx: float, th: float, tir: float = 70.0, parata: bool = true, por: float = 70.0, auto: bool = false) -> Array:
	var m := H.scene(sd, [true, false])
	m.paraCtl = parata
	m.autoGk = [auto, false]
	m.paraSeed = sd
	var k: R.Player = m.team(1)[9]
	H.wake(k, sx, -C.HL + dist)
	k.fx = 0.0
	k.fy = -1.0
	k.st.tir = tir
	var g := m.gk(0)
	H.wake(g, 0.0, -C.HL + 0.6)
	g.st.por = por
	H.give(m, k)
	m.kick(k, {"type": "shot", "tx": tx, "ty": -C.HL, "th": th})
	m.events.clear()
	return [m, k]


## passi finché il tiro finisce: "parata", "gol" o "fuori"
func esito(m: SimMatchScript, sec: float = 3.0) -> String:
	for i in int(sec * 60.0):
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "save" and e.p.team == 0:
				return "parata"
			if e.type == "goal":
				return "gol"
		m.events.clear()
		if m.phase != "play":
			return "fuori"
	return "fuori"


func test_senza_opzione_il_tuffo_parte_subito() -> bool:
	var a := tiro(1, 0.0, 20.0, 2.5, 1.0, 70.0, false)
	var m: SimMatchScript = a[0]
	check(m.ball.shot != null, "tiro rilevato")
	check(m.ball.shot.area.is_empty(), "senza opzione niente bersaglio")
	check(not m.paraFor(0), "senza opzione niente fermatempo")
	check(m.userDive(0, 2.0, 1.0), "tuffo accettato")
	eq(m.gk(0).state, "dive", "tuffo subito, come prima")
	return done()


func test_il_bersaglio_non_tocca_i_numeri_casuali() -> bool:
	var a := tiro(3, -4.0, 22.0, 2.0, 1.5, 70.0, false)
	var b := tiro(3, -4.0, 22.0, 2.0, 1.5, 70.0, true)
	var ma: SimMatchScript = a[0]
	var mb: SimMatchScript = b[0]
	eq(ma.rng.a, mb.rng.a, "stesso stato del generatore con e senza bersaglio")
	near(ma.ball.shot.cx, mb.ball.shot.cx, 1e-9, "stesso tiro")
	var c := tiro(3, -4.0, 22.0, 2.0, 1.5, 70.0, true)
	var mc: SimMatchScript = c[0]
	eq(mc.ball.shot.area, mb.ball.shot.area, "stesso seme = stesso bersaglio")
	return done()


func test_fermatempo_aperto_sul_tiro() -> bool:
	var a := tiro(2, 3.0, 20.0, -2.0, 0.8)
	var m: SimMatchScript = a[0]
	check(m.paraFor(0), "fermatempo aperto in attesa della linea")
	eq(m.hint(0), "dive", "il dito para")
	var ar := m.paraArea(0)
	check(not ar.is_empty(), "bersaglio pronto")
	check(ParataScript.paraInArea(ar, m.ball.shot.cx, m.ball.shot.ch), "il bersaglio contiene il punto vero")
	return done()


# il centro non è il punto vero ma il bersaglio lo contiene sempre; più grande con tiratore bravo e tiro forte
func test_bersaglio_contiene_il_punto_e_cresce_col_tiratore() -> bool:
	var fuori := 0
	var uguali := 0
	for sd in range(1, 41):
		var a := tiro(sd, (sd % 7) - 3.0, 14.0 + sd % 12, (sd % 5) - 2.0, 0.3 + (sd % 4) * 0.6, 40.0 + sd)
		var m: SimMatchScript = a[0]
		var s: R.Shot = m.ball.shot
		if s == null:
			continue
		if not ParataScript.paraInArea(s.area, s.cx, s.ch):
			fuori += 1
		if absf(float(s.area.x) - s.cx) < 1e-4 and absf(float(s.area.h) - s.ch) < 1e-4:
			uguali += 1
	eq(fuori, 0, "punto vero sempre dentro il bersaglio")
	check(uguali < 3, "il centro di solito non è il punto vero (%d uguali)" % uguali)
	var r1 := SimRngScript.new(5)
	var r2 := SimRngScript.new(5)
	var r3 := SimRngScript.new(5)
	var debole: Dictionary = ParataScript.paraAreaFor(0.0, 1.0, 40.0, 14.0, r1)
	var forte: Dictionary = ParataScript.paraAreaFor(0.0, 1.0, 90.0, 32.0, r2)
	var medio: Dictionary = ParataScript.paraAreaFor(0.0, 1.0, 90.0, 18.0, r3)
	check(float(forte.rx) > float(medio.rx) and float(medio.rx) > float(debole.rx), "raggio: debole %.2f < tiratore bravo %.2f < bravo e forte %.2f" % [debole.rx, medio.rx, forte.rx])
	check(float(forte.rh) < float(forte.rx), "più largo che alto")
	return done()


func test_scia_dal_pallone_al_bersaglio() -> bool:
	var a := tiro(4, 5.0, 22.0, -2.5, 1.8)
	var m: SimMatchScript = a[0]
	var v := m.paraVolo(0)
	check(v.size() > 5, "scia con abbastanza punti (%d)" % v.size())
	if v.size() < 2:
		return done()
	near(float(v[0].x), m.ball.x, 1e-6, "parte dal pallone")
	var fine: Dictionary = v[v.size() - 1]
	var ar := m.paraArea(0)
	near(float(fine.x), float(ar.x), 1e-4, "finisce al centro del bersaglio (x)")
	near(float(fine.h), maxf(0.0, float(ar.h)), 1e-4, "finisce al centro del bersaglio (h)")
	near(absf(float(fine.y)), C.HL, 1e-4, "sulla linea di porta")
	return done()


# Luis: "poter dire al portiere precisamente dove andare": il tuffo va proprio verso il punto scelto
func test_il_punto_scelto_e_rispettato() -> bool:
	var a := tiro(5, -3.0, 24.0, 1.5, 1.2)
	var m: SimMatchScript = a[0]
	var g := m.gk(0)
	var px := 1.5
	var ph := 1.4
	check(m.userDive(0, px - g.x, ph), "linea accettata")
	check(not m.paraFor(0), "linea disegnata: niente più attesa")
	var e: Variant = null
	for i in 120:
		m.step(DT)
		e = findEvent(m.events, "dive")
		m.events.clear()
		if e != null:
			break
	check(e != null, "il portiere si tuffa")
	if e == null or g.dive == null:
		return done()
	near(g.dive.tx, px, 1e-6, "tuffo verso la x scelta")
	near(g.dive.th, ph, 1e-6, "tuffo all'altezza scelta")
	check(not g.dive.auto, "tuffo comandato, non automatico")
	return done()


# su un tiro da lontano il tuffo non parte subito (cadrebbe prima del pallone) ma al momento giusto
func test_tuffo_al_momento_giusto() -> bool:
	var a := tiro(6, 0.0, 30.0, 2.0, 1.0)
	var m: SimMatchScript = a[0]
	var g := m.gk(0)
	var tc: float = m.ball.shot.tc
	m.userDive(0, 2.0 - g.x, 1.0)
	eq(g.state, "play", "non si tuffa subito (pallone a %.2f s)" % tc)
	var t := 0.0
	while g.state == "play" and t < 3.0:
		m.step(DT)
		t += DT
	check(g.state == "dive", "poi si tuffa")
	check(tc - t <= ParataScript.PARA_LEAD + ParataScript.PARA_MARGIN + 0.8 and tc - t > 0.0, "tuffo partito %.2f s prima del pallone" % (tc - t))
	return done()


# finito il fermatempo senza linea: fa da solo, verso il centro del bersaglio, dopo la reazione
func test_scadenza_il_portiere_fa_da_solo() -> bool:
	var a := tiro(7, 2.0, 18.0, -2.5, 0.6)
	var m: SimMatchScript = a[0]
	var g := m.gk(0)
	var ar := m.paraArea(0)
	m.paraExpire(0)
	check(not m.paraFor(0), "fermatempo chiuso")
	check(not m.userDive(0, 1.0, 1.0), "dopo la scadenza la linea non conta più")
	var e: Variant = null
	for i in 120:
		m.step(DT)
		e = findEvent(m.events, "dive")
		m.events.clear()
		if e != null:
			break
	check(e != null and e.get("auto", false), "tuffo automatico segnato auto")
	if g.dive != null:
		near(g.dive.tx, ParataScript.paraReachX(m.ball.shot.gx0 if m.ball.shot != null else 0.0, g.st.por, float(ar.x)), 0.05, "verso il centro del bersaglio (fin dove arriva)")
		check(g.dive.auto, "Dive.auto")
	return done()


func test_tuffo_lungo_al_massimo_quanto_puo() -> bool:
	var a := tiro(8, 0.0, 20.0, 3.4, 1.0, 70.0, true, 40.0)
	var m: SimMatchScript = a[0]
	var g := m.gk(0)
	var lim: float = ParataScript.PARA_DIVE_MAX + 40.0 * ParataScript.PARA_DIVE_POR
	near(ParataScript.paraReachX(0.0, 40.0, 10.0), lim, 1e-6, "la mano arriva al massimo a %.2f m" % lim)
	near(ParataScript.paraReachX(0.0, 40.0, -0.5), -0.5, 1e-6, "vicino: proprio lì")
	check(ParataScript.paraReachX(0.0, 90.0, 10.0) > lim, "un portiere più bravo arriva più lontano")
	check(m.userDive(0, 3.4 - g.x, 1.0), "linea all'angolo lontano")
	for i in 90:
		m.step(DT)
		if g.dive != null:
			break
	if check(g.dive != null, "si tuffa"):
		near(g.dive.tx, lim, 1e-6, "nella direzione scelta ma fin dove arriva")
	return done()


func test_fermatempo_dura_tre_secondi_veri() -> bool:
	check(FP.fermo(0.0, false), "appena aperto: fermo")
	check(FP.fermo(2.9, false), "a 2,9 s: fermo")
	check(not FP.fermo(3.0, false), "a 3 s: finito")
	check(FP.fermo(5.0, true), "dito che disegna ancora: si aspetta")
	near(FP.frazione(1.5), 0.5, 1e-6, "cerchio a metà")
	near(FP.frazione(4.0), 0.0, 1e-6, "cerchio vuoto")
	return done()


## percentuale di parate su `n` semi: con auto il portiere automatico, senza la persona sceglie il punto giusto (vero)
func quota_parate(sx: float, dist: float, txs: Array, ths: Array, tir: float, n: int, por: float = 70.0, auto: bool = false) -> Dictionary:
	var parate := 0
	var tot := 0
	for sd in range(1, n + 1):
		var tx: float = txs[sd % txs.size()]
		var th: float = ths[(sd / txs.size()) % ths.size()]
		var a := tiro(sd, sx * (1.0 if sd % 2 else -1.0), dist, tx, th, tir, true, por, auto)
		var m: SimMatchScript = a[0]
		var s: R.Shot = m.ball.shot
		if s == null or not s.on:
			continue
		var g := m.gk(0)
		if not auto:
			m.userDive(0, s.cx - g.x, s.ch) # la scelta giusta: il punto vero
		tot += 1
		if esito(m) == "parata":
			parate += 1
	return {"parate": parate, "tot": tot, "quota": float(parate) / maxf(1.0, float(tot))}


const FACILI_TX := [-1.2, -0.4, 0.5, 1.3]
const FACILI_TH := [0.4, 1.0, 1.5]
const ANGOLI_TX := [-3.3, 3.3]
const ANGOLI_TH := [0.25, 2.2]


# Luis 2026-11-23: "non tutti i tiri per forza parabili": anche con la scelta giusta il tiro forte e preciso
# nell'angolo lontano resta spesso gol; quello centrale o debole si para quasi sempre
func test_non_tutti_i_tiri_sono_parabili() -> bool:
	var facili := quota_parate(0.0, 24.0, FACILI_TX, FACILI_TH, 45.0, 40)
	var difficili := quota_parate(0.0, 16.0, ANGOLI_TX, ANGOLI_TH, 92.0, 40)
	note("scelta giusta: centrali/deboli parati %d/%d (%.0f%%), forti negli angoli lontani parati %d/%d (%.0f%%)" % [
		facili.parate, facili.tot, 100.0 * facili.quota, difficili.parate, difficili.tot, 100.0 * difficili.quota])
	check(facili.tot >= 20 and difficili.tot >= 15, "abbastanza tiri in porta (%d, %d)" % [facili.tot, difficili.tot])
	check(facili.quota >= 0.85, "centrali/deboli: parati almeno 85%% (%.0f%%)" % (100.0 * facili.quota))
	check(difficili.quota <= 0.4, "forti negli angoli lontani: parati al massimo 40%% (%.0f%%)" % (100.0 * difficili.quota))
	var bravo := quota_parate(0.0, 16.0, ANGOLI_TX, ANGOLI_TH, 92.0, 40, 92.0)
	check(bravo.quota >= difficili.quota, "un portiere più bravo arriva a più angoli (%.0f%% contro %.0f%%)" % [100.0 * bravo.quota, 100.0 * difficili.quota])
	return done()


# Luis 2026-11-23: il portiere automatico della persona para secondo tiro e precisione dell'avversario contro la sua
# bravura (motore di sempre, portiere del computer): centrali/deboli quasi sempre, angoli forti quasi mai
func test_portiere_automatico_secondo_tiro_e_bravura() -> bool:
	var facili := quota_parate(0.0, 24.0, FACILI_TX, FACILI_TH, 45.0, 40, 70.0, true)
	var difficili := quota_parate(0.0, 16.0, ANGOLI_TX, ANGOLI_TH, 92.0, 40, 70.0, true)
	var medi_scarso := quota_parate(0.0, 18.0, [-2.4, 2.4], [0.5, 1.5], 80.0, 40, 50.0, true)
	var medi_bravo := quota_parate(0.0, 18.0, [-2.4, 2.4], [0.5, 1.5], 80.0, 40, 90.0, true)
	note("automatico: centrali/deboli %.0f%%, angoli forti %.0f%%, tiri a metà strada portiere 50 %.0f%% / portiere 90 %.0f%%" % [
		100.0 * facili.quota, 100.0 * difficili.quota, 100.0 * medi_scarso.quota, 100.0 * medi_bravo.quota])
	check(facili.quota >= 0.85, "centrali/deboli: parati quasi sempre (%.0f%%)" % (100.0 * facili.quota))
	check(difficili.quota <= 0.3, "angoli forti: quasi sempre gol (%.0f%%)" % (100.0 * difficili.quota))
	check(medi_bravo.quota > medi_scarso.quota, "il portiere più bravo para di più")
	return done()


# Luis 2026-11-23: portiere automatico di base, anche coi salvataggi vecchi (che hanno autoGk false); manuale da
# provare nelle Impostazioni (gkManuale); nelle lezioni guidate sempre manuale
func test_portiere_automatico_predefinito() -> bool:
	eq(Carriera.SETTINGS_DEFAULT.get("gkManuale"), false, "chiave nuova, predefinita no")
	check(Carriera.portiere_auto({"autoGk": false}, "campionato"), "salvataggio vecchio (autoGk false): automatico")
	check(Carriera.portiere_auto(Carriera.SETTINGS_DEFAULT, "amichevole"), "carriera nuova: automatico")
	check(not Carriera.portiere_auto({"gkManuale": true}, "campionato"), "Manuale scelto: manuale")
	check(not Carriera.portiere_auto({"gkManuale": false}, "allenamento"), "lezioni guidate: manuale")
	return done()


# Luis 2026-11-24: "tirando dal centrocampo il portiere si butta a terra e la palla va in rete". Il portiere automatico
# (e quello della CPU) sul tiro lungo non si tuffa appena reagisce: aspetta che il pallone sia vicino, poi si tuffa
func test_tiro_da_lontano_il_portiere_automatico_non_si_tuffa_troppo_presto() -> bool:
	var parate := 0
	var tot := 0
	for sd in range(1, 21):
		var tx: float = [-2.2, -1.2, 1.2, 2.2][sd % 4]
		var a := tiro(sd, 0.0, 48.0, tx, 0.8, 70.0, true, 70.0, true)
		var m: SimMatchScript = a[0]
		var s: R.Shot = m.ball.shot
		if s == null or not s.on:
			continue
		tot += 1
		var g := m.gk(0)
		var tc: float = s.tc
		var t := 0.0
		var tuffo := -1.0
		var finito := ""
		while t < tc + 1.0 and finito == "":
			m.step(DT)
			t += DT
			if tuffo < 0.0 and g.state == "dive":
				tuffo = t
			for e: Dictionary in m.events:
				if e.type == "save" and e.p.team == 0:
					finito = "parata"
				elif e.type == "goal":
					finito = "gol"
			m.events.clear()
		if finito == "parata":
			parate += 1
		if tuffo >= 0.0:
			check(tc - tuffo <= 1.0, "seme %d: tuffo %.2f s prima del pallone (volo %.2f s), non subito" % [sd, tc - tuffo, tc])
	note("tiri da 48 m nel mezzo della porta, portiere automatico: parati %d/%d" % [parate, tot])
	check(tot >= 10, "abbastanza tiri in porta (%d)" % tot)
	check(parate >= int(tot * 0.7), "il portiere para quasi sempre i tiri da lontano a mezza porta (%d/%d)" % [parate, tot])
	return done()


# il portiere della CPU (squadra 1) sul tiro da centrocampo della persona: stessa regola
func test_tiro_da_centrocampo_il_portiere_cpu_aspetta() -> bool:
	var m := H.scene(4, [true, false])
	m.paraCtl = true
	var k: R.Player = m.team(0)[9]
	H.wake(k, 0.0, 0.0)
	k.fx = 0.0
	k.fy = 1.0
	var g := m.gk(1)
	H.wake(g, 0.0, C.HL - 0.6)
	H.give(m, k)
	m.kick(k, {"type": "shot", "tx": 2.4, "ty": C.HL, "th": 1.0})
	var s: R.Shot = m.ball.shot
	check(s != null, "tiro rilevato")
	if s == null:
		return done()
	var t := 0.0
	while t < s.tc - 0.05 and g.state == "play":
		m.step(DT)
		t += DT
	check(s.tc - t <= 1.0, "il portiere della CPU si tuffa solo vicino all'arrivo (%.2f s prima, volo %.2f s)" % [s.tc - t, s.tc])
	return done()
