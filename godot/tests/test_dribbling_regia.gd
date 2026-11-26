# Regia del dribbling della persona (scripts/partita/dribbling_regia.gd): rallenty dal tasto alla fine del giochetto,
# uscita dolce, telecamera girata di 45° dal lato del dribbling, pose di reazione; e la visuale (camfit.dribble_view).
extends "test_base.gd"

const Regia := preload("res://scripts/partita/dribbling_regia.gd")
const CF := preload("res://scripts/partita/camfit.gd")
const D := preload("../sim/duel.gd")
const TD := preload("test_dribbling.gd")
const ASPECT := 390.0 / 844.0


# fa avanzare motore e regia come gioco.gd: passi, regia.passo, poi gli eventi del passo; ritorna i tipi visti
static func avanza(m: SimMatchScript, rg: Regia, sec: float, ts: float = 0.3) -> Array:
	var tipi: Array = []
	for i in int(round(sec * 60.0)):
		m.step(DT)
		rg.passo(m, 0, DT, ts)
		for e: Dictionary in m.events:
			rg.evento(e, 0)
			tipi.append(e.type)
		m.events.clear()
	return tipi


# come avanza, ma si ferma dopo il passo in cui arriva l'evento `tipo` (al massimo `sec`); ritorna true se è arrivato
static func avanza_fino(m: SimMatchScript, rg: Regia, tipo: String, sec: float) -> bool:
	for i in int(round(sec * 60.0)):
		if avanza(m, rg, DT).has(tipo):
			return true
	return false


func test_rallenty_dal_tasto_alla_fine_del_giochetto() -> bool:
	# Arrange: duello aperto, dribbling che riesce (seme trovato dal test del motore)
	var sd := TD.first_ok_seed()
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = "finta"   # giochetto corto: il rallenty finisce DOPO_OK dopo lo scatto
	(s[1] as R.Player).st.dri = 99
	(s[2] as R.Player).st.dif = 20
	var rg := Regia.new()
	eq(rg.velocita(), -1.0, "prima del tasto la regia non decide")
	# Act: tasto
	m.userDribble(0)
	rg.passo(m, 0, 0.0, 0.08)
	for e: Dictionary in m.events:
		rg.evento(e, 0)
	m.events.clear()
	# Assert: corsa verso il difensore in rallenty, telecamera girata
	eq(rg.fase, "corsa", "fase corsa")
	near(rg.velocita(), Regia.TS_CORSA, 1e-6, "rallenty della corsa")
	check(not rg.camera().is_empty(), "visuale del dribbling")
	check(rg.attiva(), "regia attiva: il timer del rallenty non conta")
	# Act: fino all'esito
	var esito := avanza_fino(m, rg, "dribble", 1.3)
	# Assert
	check(esito, "esito arrivato")
	eq(rg.fase, "giochetto", "giochetto")
	near(rg.velocita(), Regia.TS_GIOCHETTO, 1e-6, "rallenty del giochetto")
	# Act: giochetto fino allo scatto
	check(avanza_fino(m, rg, "dribble_go", D.DRIB_SHOW_T + 0.1), "scatto")
	avanza(m, rg, Regia.DOPO_OK - 0.1)
	eq(rg.fase, "giochetto", "il rallenty resta durante il sorpasso")
	check(not rg.camera().is_empty(), "visuale del dribbling durante il sorpasso")
	avanza(m, rg, 0.15)
	# Assert: uscita dolce
	eq(rg.fase, "uscita", "poi si esce")
	eq(rg.velocita(), -1.0, "in uscita decide il resto del gioco ...")
	near(rg.k_tempo(14.0), Regia.USCITA_K_OK, 1e-6, "... e dopo il dribbling riuscito il tempo torna normale in fretta")
	check(rg.camera().is_empty(), "la telecamera torna dritta")
	rg.passo(m, 0, DT, 0.99)
	eq(rg.fase, "", "tempo tornato normale: regia finita")
	near(rg.k_tempo(14.0), 14.0, 1e-6, "dopo, la dolcezza normale")
	m.dispose()
	return done()


func test_prenotazione_finita_senza_esito_esce() -> bool:
	# Arrange
	var s := TD.setup(4, 6.0)
	var m: SimMatchScript = s[0]
	var o: R.Player = s[2]
	var rg := Regia.new()
	m.userDribble(0)
	rg.passo(m, 0, 0.0, 0.08)
	# Act: palla persa
	m.ball.owner = o
	m.ball.last = o
	avanza(m, rg, 0.1)
	# Assert
	eq(rg.fase, "uscita", "esce subito")
	avanza(m, rg, Regia.USCITA_MAX + 0.05, 0.5)
	eq(rg.fase, "", "e finisce anche se il tempo non torna normale (altro rallenty)")
	m.dispose()
	return done()


func test_esito_nello_stesso_passo_del_tasto() -> bool:
	# Arrange: difensore già vicino, il dribbling parte col tocco
	var s := TD.setup(2, D.DRIB_NEAR - 0.3)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	var rg := Regia.new()
	# Act
	var ok := m.userDribble(0)
	rg.passo(m, 0, 0.0, 0.08)
	for e: Dictionary in m.events:
		rg.evento(e, 0)
	# Assert
	check(ok, "tasto toccato")
	check(findEvent(m.events, "dribble") != null, "esito subito")
	eq(rg.fase, "giochetto", "la regia parte lo stesso (dribble_book)")
	m.dispose()
	return done()


func test_telecamera_girata_dal_lato_del_dribbling() -> bool:
	# Arrange / Act / Assert: lato +1 = sinistra del portatore: telecamera dietro a destra, guarda a sinistra (yaw −),
	# nel verso dello scatto: il portatore passa di fianco al difensore senza coprirlo
	near(Regia.giro_camera(Vector2(0, 0), Vector2(0, 5), 1.0, 1.0), -deg_to_rad(45.0), 1e-5, "lato sinistro")
	near(Regia.giro_camera(Vector2(0, 0), Vector2(0, 5), -1.0, 1.0), deg_to_rad(45.0), 1e-5, "lato destro")
	# squadra 1 (attacca verso −y): spazio orientato girato, stesso risultato
	near(Regia.giro_camera(Vector2(0, 0), Vector2(0, -5), 1.0, -1.0), -deg_to_rad(45.0), 1e-5, "squadra 1")
	# difensore spostato di lato: il verso conta al massimo BASE_MAX
	var y := Regia.giro_camera(Vector2(0, 0), Vector2(5, 1), 1.0, 1.0)
	near(y, Regia.BASE_MAX - deg_to_rad(45.0), 1e-5, "verso del difensore limitato")
	return done()


func test_visuale_del_dribbling_portatore_e_difensore_a_schermo() -> bool:
	for lato: float in [1.0, -1.0]:
		# Arrange
		var c := Vector2(4, 8)
		var o := Vector2(4.6, 10.0)
		var yaw := Regia.giro_camera(c, o, lato, 1.0)
		# Act
		var v := CF.dribble_view(c, o, yaw, ASPECT, 70.0)
		# Assert: dentro lo schermo coi margini, e più vicina della visuale larga del rallenty
		for q: Vector3 in [Vector3(c.x, 0, c.y), Vector3(c.x, 2.2, c.y), Vector3(o.x, 0, o.y), Vector3(o.x, 2.2, o.y)]:
			var s := CF.project(v.pos, yaw, CF.DRIB_PITCH, tan(deg_to_rad(v.fov / 2.0)), ASPECT, q)
			check(absf(s.x) <= 1.0 - CF.DRIB_MARGIN.l + 0.01 and s.y >= -1.0 + CF.DRIB_MARGIN.b - 0.01 and s.y <= 1.0 - CF.DRIB_MARGIN.t + 0.01 and s.z > 0.0, "a schermo (lato %d): %s" % [lato, s])
		var dist := (v.pos as Vector3).distance_to(Vector3(c.x, 0, c.y))
		check(dist < CF.WIDE_MIN_DIST, "più vicina della visuale larga: %.1f m" % dist)
		# la telecamera sta dalla parte opposta al lato del dribbling (+1 = sinistra = x minori) e guarda nel verso dello
		# scatto: il portatore passa di fianco al difensore senza coprirlo
		check(((v.pos as Vector3).x - c.x) * lato > 0.0, "dalla parte opposta al lato del dribbling")
	return done()


func test_esito_grafico_riuscito_e_fallito() -> bool:
	# Arrange: portatore verso +y, difensore davanti che lo guarda
	var m := H.scene(1)
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[14]
	H.wake(p, 0, 0)
	H.wake(o, 0, 2)
	p.fx = 0
	p.fy = 1
	o.fx = 0
	o.fy = -1
	# Act
	var ok := Regia.esito({"p": p, "o": o, "ok": true, "side": 1.0, "show": D.DRIB_SHOW_T})
	var ko := Regia.esito({"p": p, "o": o, "ok": false, "side": 1.0, "show": 0.0})
	var ia := Regia.esito({"p": p, "o": o, "ok": true, "side": -1.0})
	# Assert: riuscito = giochetto lungo quanto il giochetto del motore più la coda; difensore a vuoto verso la finta
	near(float(ok.dur), D.DRIB_SHOW_T + Regia.GIOCHETTO_CODA, 1e-6, "durata del giochetto")
	eq(ok.reazioni.size(), 1, "una reazione")
	eq(ok.reazioni[0][0], o, "del difensore")
	eq(ok.reazioni[0][1], "affondo", "intervento a vuoto")
	# finta alla destra del portatore (x maggiori) = alla sinistra del difensore che guarda verso −y
	eq(ok.reazioni[0][2], 1.0, "verso la finta")
	eq(ia.dur, -1.0, "senza giochetto del motore: durata naturale")
	eq(ia.reazioni[0][2], -1.0, "lato opposto")
	# fallito: niente giochetto, contrasto del difensore e portatore che inciampa
	eq(ko.dur, 0.0, "niente giochetto")
	eq(ko.reazioni[0][1], "contrasto", "contrasto")
	eq(ko.reazioni[0][2], 0.0, "in avanti")
	eq(ko.reazioni[1][0], p, "il portatore")
	eq(ko.reazioni[1][1], "inciampo", "inciampa")
	m.dispose()
	return done()
