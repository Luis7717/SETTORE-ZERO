# Tiro da girato (Luis 2026-11-25, opzione "rifiniture"): "se il giocatore tira da girato è meno preciso e meno forte
# il tiro; i giocatori si mettono nella miglior posizione per tirare ma ci vuole tempo". Il tiro col corpo girato
# oltre GIRATA_DA (60°) rispetto alla direzione del tiro è più debole e impreciso, al massimo con le spalle alla porta
# (GIRATA_PIENA, 150°); la CPU girata prima si gira verso la porta (almeno GIRATA_ATTESA col pallone).
# Senza l'opzione il motore resta quello del JS.
extends "test_base.gd"

const CAMPIONI := 400   # tiri con l'errore casuale per misurare la precisione


func _scena(rif: bool) -> SimMatchScript:
	var m := H.scene(3, [false, false])
	m.rifiniture = rif
	return m


# tiratore della squadra 0 (attacca verso +y) a 14 m dalla porta, verso del corpo (fx, fy), pallone tra i piedi
func _tiratore(m: SimMatchScript, fx: float, fy: float) -> R.Player:
	var p: R.Player = m.team(0)[9]
	H.wake(p, 0.0, 36.0)
	p.fx = fx
	p.fy = fy
	H.give(m, p)
	return p


const SPEC := {"type": "shot", "tx": 2.0, "ty": 50.0, "th": 1.0}


# deviazione standard (gradi) della direzione del tiro, su CAMPIONI tiri con l'errore casuale
func _sparpaglio(m: SimMatchScript, p: R.Player) -> float:
	var somma := 0.0
	var somma2 := 0.0
	var a0: float = atan2(SPEC.ty - m.ball.y, SPEC.tx - m.ball.x)
	for i in CAMPIONI:
		var L: Dictionary = m.launch(p, SPEC, true)
		var a: float = rad_to_deg(wrapf(atan2(float(L.vy), float(L.vx)) - a0, -PI, PI))
		somma += a
		somma2 += a * a
	var media := somma / CAMPIONI
	return sqrt(maxf(0.0, somma2 / CAMPIONI - media * media))


func test_quanto_e_girato() -> bool:
	near(SimMatchScript.girataK(0.0, 1.0, 0.0, 1.0), 0.0, 1e-9, "frontale")
	near(SimMatchScript.girataK(cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)), 1.0, 0.0), 0.0, 1e-9, "30 gradi")
	near(SimMatchScript.girataK(cos(deg_to_rad(59.0)), sin(deg_to_rad(59.0)), 1.0, 0.0), 0.0, 1e-9, "59 gradi")
	near(SimMatchScript.girataK(1.0, 0.0, 0.0, 1.0), 1.0 / 3.0, 1e-6, "90 gradi")
	near(SimMatchScript.girataK(cos(deg_to_rad(150.0)), sin(deg_to_rad(150.0)), 1.0, 0.0), 1.0, 1e-6, "150 gradi")
	near(SimMatchScript.girataK(0.0, -1.0, 0.0, 1.0), 1.0, 1e-9, "spalle alla porta")
	return done()


func test_tiro_da_girato_piu_debole() -> bool:
	var m := _scena(true)
	var p := _tiratore(m, 0.0, 1.0)
	var v_fronte: float = m.launch(p, SPEC, false).v0
	p.fx = 1.0
	p.fy = 0.0
	var v_fianco: float = m.launch(p, SPEC, false).v0
	p.fx = 0.0
	p.fy = -1.0
	var v_spalle: float = m.launch(p, SPEC, false).v0
	note("velocità del tiro: frontale %.1f · di fianco %.1f · spalle alla porta %.1f m/s" % [v_fronte, v_fianco, v_spalle])
	check(v_fianco < v_fronte * 0.9, "di fianco più debole del frontale")
	check(v_spalle < v_fianco, "con le spalle alla porta più debole che di fianco")
	check(v_spalle < v_fronte * 0.55, "con le spalle alla porta molto debole (sotto il 55%)")
	# tiro a giro (tratto curvo) e rasoterra (tratto dritto): anche loro più deboli da girato
	for sp: Dictionary in [{"type": "shot", "tx": 2.0, "ty": 50.0, "th": 1.5, "curve": 4.0, "tratto": true},
			{"type": "shot", "tx": 2.0, "ty": 50.0, "th": 0.0, "tratto": true}]:
		p.fx = 0.0
		p.fy = 1.0
		var a: float = m.launch(p, sp, false).v0
		p.fy = -1.0
		var b: float = m.launch(p, sp, false).v0
		check(b < a * 0.7, "tratto %s: da girato %.1f contro %.1f" % ["curvo" if sp.has("curve") else "dritto", b, a])
	return done()


func test_tiro_da_girato_meno_preciso() -> bool:
	var m := _scena(true)
	var p := _tiratore(m, 0.0, 1.0)
	var s_fronte := _sparpaglio(m, p)
	p.fx = 1.0
	p.fy = 0.0
	var s_fianco := _sparpaglio(m, p)
	p.fx = 0.0
	p.fy = -1.0
	var s_spalle := _sparpaglio(m, p)
	note("errore di direzione (dev. standard): frontale %.2f° · di fianco %.2f° · spalle alla porta %.2f°" % [s_fronte, s_fianco, s_spalle])
	check(s_fianco > s_fronte * 1.3, "di fianco meno preciso del frontale")
	check(s_spalle > s_fronte * 2.5, "con le spalle alla porta molto meno preciso")
	return done()


func test_calci_da_fermo_e_senza_rifiniture_come_prima() -> bool:
	var m := _scena(false)
	var p := _tiratore(m, 0.0, 1.0)
	var a: float = m.launch(p, SPEC, false).v0
	p.fy = -1.0
	eq(m.launch(p, SPEC, false).v0, a, "senza rifiniture il verso del corpo non conta")
	var m2 := _scena(true)
	var p2 := _tiratore(m2, 0.0, 1.0)
	var fronte: float = m2.launch(p2, SPEC, false).v0
	p2.fy = -1.0
	m2.phase = "restart" # punizione o rigore: il battitore si prepara, niente tiro da girato
	eq(m2.launch(p2, SPEC, false).v0, fronte, "calcio da fermo: il verso del corpo non conta")
	return done()


# CPU (squadra 1, attacca verso -y) col pallone a 12 m dalla porta e nessuno intorno: quando tira, e com'è girata
func _quando_tira(rif: bool, fy: float, vy: float) -> Dictionary:
	var m := _scena(rif)
	var p: R.Player = m.team(1)[9]
	H.wake(p, 0.0, -38.0)
	p.fx = 0.0
	p.fy = fy
	p.vy = vy
	H.give(m, p)
	m.give(p) # presa del pallone come in partita (presaT, primo pensiero dell'IA)
	var t0: float = m.time
	for i in 240:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "kick" and e.p == p:
				var b := m.ball
				var gradi: float = rad_to_deg(acos(clampf((p.fx * b.vx + p.fy * b.vy) / maxf(1e-6, C.hyp(b.vx, b.vy)), -1.0, 1.0)))
				return {"t": m.time - t0, "kind": e.kind, "gradi": gradi}
		m.events.clear()
	return {"t": 99.0, "kind": "", "gradi": 0.0}


func test_la_cpu_girata_aspetta_prima_di_tirare() -> bool:
	var girata := _quando_tira(true, 1.0, 3.0)     # spalle alla porta, corre via dalla porta
	var dritta := _quando_tira(true, -1.0, -1.0)   # già rivolta verso la porta
	var prima := _quando_tira(false, 1.0, 3.0)     # senza rifiniture: come nel JS
	note("tiro della CPU: girata dopo %.2f s (corpo a %.0f°) · dritta dopo %.2f s (%.0f°) · senza rifiniture girata dopo %.2f s (%.0f°)" % [
		girata.t, girata.gradi, dritta.t, dritta.gradi, prima.t, prima.gradi])
	eq(girata.kind, "shot", "la CPU girata alla fine tira")
	eq(dritta.kind, "shot", "la CPU dritta tira")
	check(girata.t >= SimMatchScript.GIRATA_ATTESA, "la CPU girata non tira prima di %.1f s (%.2f)" % [SimMatchScript.GIRATA_ATTESA, girata.t])
	check(girata.gradi <= 60.5 or girata.t >= SimMatchScript.GIRATA_MAX_T, "la CPU tira dopo essersi girata (%.0f°)" % girata.gradi)
	check(dritta.t < SimMatchScript.GIRATA_ATTESA, "la CPU già girata verso la porta tira subito (%.2f)" % dritta.t)
	check(prima.t < girata.t, "senza rifiniture tira prima (%.2f contro %.2f)" % [prima.t, girata.t])
	return done()
