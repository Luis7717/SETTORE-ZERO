# Salto conteso del colpo di testa (sim/testa.gd, kind "def" e "pass", Luis 2026-11-24): fermatempo in difesa sui
# palloni alti avversari e sui nostri passaggi alti, solo con un avversario attaccato e se il nostro vince il salto
# (deciso prima col seme); senza linea, o col salto perso, colpisce l'avversario. Senza avversario attaccato tutto come
# prima: il lancio sulla fascia si controlla e si corre.
extends "test_base.gd"


## cross della CPU (squadra 1, attacca verso −y) dalla destra verso il suo n. 10 al limite della nostra area, col nostro
## difensore attaccato. Ritorna [m, nostro difensore, attaccante avversario]
func cross_cpu(sd: int, mio_tes: float = 90.0, suo_tes: float = 40.0, testa: bool = true) -> Array:
	var m := H.scene(sd, [true, false])
	m.headCtl = testa
	var att: R.Player = m.team(1)[9]
	var cr: R.Player = m.team(1)[7]
	var d: R.Player = m.team(0)[3]
	H.wake(att, 1.0, -(C.HL - 10.0))
	H.wake(cr, -24.0, -(C.HL - 12.0))
	H.wake(d, 1.8, -(C.HL - 10.6))
	d.st.tes = mio_tes
	att.st.tes = suo_tes
	H.give(m, cr)
	m.ctrl[0] = d
	m.kick(cr, {"type": "loft", "tx": att.x - 1.5, "ty": att.y - 1.0})
	m.events.clear()
	return [m, d, att]


## nostro lancio alto (squadra 0) dal centrocampo al n. 10 a 30 m dalla porta; `marcato` = difensore attaccato a lui.
## Ritorna [m, ricevitore, difensore]
func lancio(sd: int, marcato: bool, mio_tes: float = 90.0, suo_tes: float = 40.0, x: float = -6.0, y: float = 20.0) -> Array:
	var m := H.scene(sd, [true, false])
	m.headCtl = true
	var pas: R.Player = m.team(0)[6]
	var rc: R.Player = m.team(0)[9]
	var df: R.Player = m.team(1)[3]
	H.wake(pas, x - 4.0, y - 24.0)
	H.wake(rc, x, y)
	if marcato:
		H.wake(df, x + 0.9, y + 0.9)
	else:
		H.wake(df, x + 16.0, y + 12.0)
	rc.st.tes = mio_tes
	df.st.tes = suo_tes
	H.give(m, pas)
	m.ctrl[0] = pas
	m.kick(pas, {"type": "loft", "tx": x, "ty": y + 1.5})
	m.events.clear()
	return [m, rc, df]


## passi finché non succede uno degli eventi `tipi` (al massimo `sec` s); ritorna l'evento o null
func fino_a(m: SimMatchScript, tipi: Array, sec: float) -> Variant:
	for i in int(sec * 60.0):
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type in tipi:
				m.events.clear()
				return e
		m.events.clear()
	return null


func test_difesa_salto_vinto_apre_il_fermatempo() -> bool:
	var aperti := 0
	for sd in range(1, 9):
		var a := cross_cpu(sd)
		var m: SimMatchScript = a[0]
		var e: Variant = fino_a(m, ["head_win", "head_give"], 3.0)
		if e == null or e.type != "head_win":
			continue
		aperti += 1
		eq(e.kind, "def", "seme %d: fermatempo in difesa" % sd)
		eq(e.p, a[1], "seme %d: colpisce il nostro difensore" % sd)
		eq(e.o, a[2], "seme %d: contro l'attaccante attaccato" % sd)
		check(m.headFor(0), "seme %d: si aspetta la linea" % sd)
		eq(m.ctrl[0], a[1], "seme %d: comanda il difensore" % sd)
		check(not m.headCanShoot(), "seme %d: in difesa niente tiro" % sd)
		check(m.headLeft() >= m.HEAD_WIN_MIN and m.headLeft() <= m.HEAD_WIN_T, "seme %d: colpo tra poco (%s s)" % [sd, m.headLeft()])
	check(aperti >= 5, "difensore più bravo di testa: fermatempo in %d casi su 8" % aperti)
	return done()


func test_difesa_linea_e_un_passaggio_di_testa() -> bool:
	var colpi := 0
	for sd in range(1, 9):
		var a := cross_cpu(sd)
		var m: SimMatchScript = a[0]
		var q: R.Player = m.team(0)[6]
		H.wake(q, -12.0, -(C.HL - 30.0))
		var e: Variant = fino_a(m, ["head_win", "head_give"], 3.0)
		if e == null or e.type != "head_win":
			continue
		# anche una linea "in porta" in difesa diventa un passaggio: qui verso il compagno
		check(m.userHeader(0, {"goal": true, "tx": 0.0, "th": 1.0}), "seme %d: linea accettata" % sd)
		check(not m.headWin.goal, "seme %d: la linea in porta in difesa non è un tiro" % sd)
		m.headWin.ax = q.x
		m.headWin.ay = q.y
		var k: Variant = fino_a(m, ["kick"], 2.0)
		if not check(k != null, "seme %d: colpo partito" % sd):
			continue
		colpi += 1
		eq(k.p, a[1], "seme %d: colpisce il nostro difensore" % sd)
		check(k.get("guidato", false) and k.get("sponda", false) and k.get("difesa", false), "seme %d: passaggio di testa guidato in difesa" % sd)
		check(m.ball.shot == null and m.ball.kick != null and m.ball.kick.team == 0, "seme %d: pallone nostro, non un tiro" % sd)
		var b := m.ball
		var cosa: float = (b.vx * (q.x - b.x) + b.vy * (q.y - b.y)) / (C.hyp(b.vx, b.vy) * C.hyp(q.x - b.x, q.y - b.y))
		check(cosa > 0.85, "seme %d: verso il compagno (coseno %.2f)" % [sd, cosa])
	check(colpi >= 5, "passaggi di testa in difesa: %d su 8" % colpi)
	return done()


# Luis 2026-11-24: senza linea entro i 3 s il colpo lo vince l'avversario che se lo contendeva
func test_difesa_senza_linea_colpisce_l_avversario() -> bool:
	var ceduti := 0
	for sd in range(1, 9):
		var a := cross_cpu(sd)
		var m: SimMatchScript = a[0]
		var e: Variant = fino_a(m, ["head_win", "head_give"], 3.0)
		if e == null or e.type != "head_win":
			continue
		m.headExpire() # i 3 s veri finiti senza linea (lo fa il gioco)
		check(m.headWin == null and m.headGive != null, "seme %d: salto passato all'avversario" % sd)
		var evs := H.run(m, 2.0)
		check(not hasEvent(evs, "kick", func(x: Dictionary) -> bool: return x.p == a[1]), "seme %d: il nostro difensore non colpisce" % sd)
		check(not hasEvent(evs, "control", func(x: Dictionary) -> bool: return x.p == a[1]), "seme %d: né controlla" % sd)
		if hasEvent(evs, "kick", func(x: Dictionary) -> bool: return x.p == a[2] and x.kind in ["header", "volley"]):
			ceduti += 1
	check(ceduti >= 4, "l'attaccante colpisce di testa in %d casi" % ceduti)
	return done()


func test_difesa_salto_perso_niente_fermatempo() -> bool:
	var persi := 0
	for sd in range(1, 9):
		var a := cross_cpu(sd, 20.0, 99.0)
		var m: SimMatchScript = a[0]
		var e: Variant = fino_a(m, ["head_win", "head_give"], 3.0)
		if e == null or e.type != "head_give":
			continue
		persi += 1
		check(not m.headFor(0), "seme %d: nessun fermatempo" % sd)
		var evs := H.run(m, 2.0)
		check(not hasEvent(evs, "head_win"), "seme %d: e non si apre dopo" % sd)
		check(not hasEvent(evs, "kick", func(x: Dictionary) -> bool: return x.p == a[1]), "seme %d: il nostro non colpisce" % sd)
	check(persi >= 5, "difensore scarso di testa: salto perso in %d casi su 8" % persi)
	return done()


func test_difesa_senza_opzione_come_prima() -> bool:
	for sd in range(1, 5):
		var a := cross_cpu(sd, 90.0, 40.0, false)
		var evs := H.run(a[0], 3.0)
		check(not hasEvent(evs, "head_win") and not hasEvent(evs, "head_give") and not hasEvent(evs, "aerial_pre"), "seme %d: senza opzione niente salto conteso" % sd)
	return done()


func test_passaggio_alto_con_difensore_attaccato() -> bool:
	var aperti := 0
	for sd in range(1, 9):
		var a := lancio(sd, true)
		var m: SimMatchScript = a[0]
		var e: Variant = fino_a(m, ["head_win", "head_give"], 3.0)
		if e == null or e.type != "head_win":
			continue
		aperti += 1
		eq(e.kind, "pass", "seme %d: fermatempo sul passaggio" % sd)
		eq(e.p, a[1], "seme %d: colpisce il ricevitore" % sd)
		eq(e.o, a[2], "seme %d: contro il difensore attaccato" % sd)
		check(not m.headCanShoot(), "seme %d: a 30 m dalla porta niente tiro" % sd)
		var q: R.Player = m.team(0)[10]
		H.wake(q, 6.0, 30.0)
		m.userHeader(0, {"goal": false, "tx": q.x, "ty": q.y})
		var k: Variant = fino_a(m, ["kick"], 2.0)
		check(k != null and k.p == a[1] and k.get("sponda", false), "seme %d: sponda di testa del ricevitore" % sd)
	check(aperti >= 5, "passaggio alto conteso: fermatempo in %d casi su 8" % aperti)
	return done()


func test_passaggio_alto_senza_linea_colpisce_il_difensore() -> bool:
	var ceduti := 0
	for sd in range(1, 9):
		var a := lancio(sd, true)
		var m: SimMatchScript = a[0]
		var e: Variant = fino_a(m, ["head_win", "head_give"], 3.0)
		if e == null or e.type != "head_win":
			continue
		m.headExpire()
		var evs := H.run(m, 2.0)
		check(not hasEvent(evs, "kick", func(x: Dictionary) -> bool: return x.p == a[1]), "seme %d: il ricevitore non colpisce" % sd)
		check(not hasEvent(evs, "control", func(x: Dictionary) -> bool: return x.p == a[1]), "seme %d: né controlla" % sd)
		if hasEvent(evs, "kick", func(x: Dictionary) -> bool: return x.p == a[2] and x.kind == "header"):
			ceduti += 1
	check(ceduti >= 4, "il difensore colpisce di testa in %d casi" % ceduti)
	return done()


# il salto conteso è un momento speciale: sul nostro passaggio solo oltre HEAD_PASS_ZONE nella metà avversaria
# (a centrocampo resta automatico come prima, niente fermatempo e niente esito deciso prima)
func test_passaggio_conteso_a_centrocampo_resta_automatico() -> bool:
	for sd in range(1, 7):
		var a := lancio(sd, true, 90.0, 40.0, -6.0, 4.0)
		var evs := H.run(a[0], 3.0)
		check(not hasEvent(evs, "head_win") and not hasEvent(evs, "head_give") and not hasEvent(evs, "aerial_pre"), "seme %d: a centrocampo niente salto conteso" % sd)
	return done()


# Luis 2026-11-24: lancio alto sulla fascia a un compagno senza difensore attaccato = controllo e corsa, non testa
func test_lancio_sulla_fascia_senza_difensore_si_controlla() -> bool:
	var controllati := 0
	for sd in range(1, 9):
		var a := lancio(sd, false, 90.0, 40.0, -25.0, 24.0)
		var m: SimMatchScript = a[0]
		var evs := H.run(m, 4.0)
		check(not hasEvent(evs, "head_win") and not hasEvent(evs, "head_give"), "seme %d: niente salto conteso" % sd)
		if hasEvent(evs, "control", func(x: Dictionary) -> bool: return x.p == a[1]):
			controllati += 1
		check(not hasEvent(evs, "kick", func(x: Dictionary) -> bool: return x.p == a[1] and x.kind == "header"), "seme %d: nessun colpo di testa" % sd)
	check(controllati >= 6, "lancio controllato dal compagno in %d casi su 8" % controllati)
	return done()


func test_cross_in_area_resta_come_prima() -> bool:
	# il cross in area del nostro attaccante, anche marcato, apre il fermatempo di sempre (kind "att", si può tirare)
	var m := H.scene(3, [true, false])
	m.headCtl = true
	var p: R.Player = m.team(0)[9]
	var k: R.Player = m.team(0)[7]
	H.wake(p, 1.0, C.HL - 9.0)
	H.wake(k, 24.0, C.HL - 12.0)
	H.wake(m.team(1)[3], 1.6, C.HL - 8.4)
	H.give(m, k)
	m.ctrl[0] = k
	m.kick(k, {"type": "loft", "tx": p.x - 1.5, "ty": p.y + 1.0})
	m.events.clear()
	var e: Variant = fino_a(m, ["head_win", "head_give"], 3.0)
	check(e != null and e.type == "head_win" and e.get("kind", "att") == "att", "fermatempo del cross come prima")
	check(m.headCanShoot(), "dal cross si tira")
	return done()


func test_frequenza_in_partita() -> bool:
	var tot := {"def": 0, "pass": 0, "att": 0, "give": 0}
	var conta := func(m: SimMatchScript) -> void:
		for e: Dictionary in m.events:
			if e.type == "head_win" and e.team == 0:
				tot[String(e.get("kind", "att"))] += 1
			elif e.type == "head_give" and e.team == 0:
				tot.give += 1
	for sd in range(1, 4):
		var res := H.playMatch({"seed": sd, "mode": "bot", "halfLen": 150.0, "testa": true, "extra": {"rifiniture": true, "attacco": true}}, conta)
		res.m.dispose()
	note("3 partite da 2×150 s: fermatempi in difesa %d, sui passaggi %d, cross %d, salti ceduti all'avversario %d" % [tot.def, tot.pass, tot.att, tot.give])
	check(tot.def + tot.pass >= 1, "il salto conteso capita (%d)" % (tot.def + tot.pass))
	check(tot.def + tot.pass <= 3 * 8, "ma è un momento speciale, non continuo (%d in 3 partite)" % (tot.def + tot.pass))
	return done()
