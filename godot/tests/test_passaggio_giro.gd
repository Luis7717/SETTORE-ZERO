# Passaggio a giro corto (Luis 2026-11-24: "per fare il passaggio rotante, non dritto al mio giocatore ma che gira, il
# giocatore sceglie di fare un passaggio alto anche se è corto"). Con le rifiniture (gioco Godot) il tratto curvo fino a
# CURVE_GROUND_M resta rasoterra a effetto se la curva passa libera; se un avversario sta sulla curva si alza (come prima).
extends "test_base.gd"

const SimMatch := preload("res://sim/match.gd")


## portatore della squadra 0 in (0, 0) col pallone, compagno in (mx, my); avversario in `opp` (o lontano)
func scena(sd: int, mx: float, my: float, opp: Vector2, rif: bool = true) -> Array:
	var m := H.scene(sd, [true, false])
	m.rifiniture = rif
	var c: R.Player = m.team(0)[6]
	var q: R.Player = m.team(0)[9]
	H.wake(c, 0.0, 0.0)
	H.wake(q, mx, my)
	for o: R.Player in m.team(1):
		H.wake(o, 30.0, 45.0) # tutti lontani
	H.wake(m.team(1)[4], opp.x, opp.y)
	H.give(m, c)
	m.ctrl[0] = c
	m.events.clear()
	return [m, c, q]


func tipo_calcio(m: SimMatchScript) -> String:
	for e: Dictionary in m.events:
		if e.type == "kick":
			return e.kind
	return ""


func test_giro_corto_libero_resta_rasoterra_e_gira() -> bool:
	var a := scena(1, 0.0, 14.0, Vector2(25.0, 40.0))
	var m: SimMatchScript = a[0]
	check(m.userKick(0, {"type": "auto", "tx": 0.0, "ty": 14.0, "curve": 3.0, "tratto": true}), "calcio accettato")
	eq(tipo_calcio(m), "ground", "giro corto senza nessuno sulla curva: rasoterra")
	var hmax := 0.0
	var xmax := 0.0
	for i in 60:
		m.step(DT)
		hmax = maxf(hmax, m.ball.h)
		if m.ball.owner == null:
			xmax = maxf(xmax, absf(m.ball.x))
	check(hmax < 0.3, "resta a terra (altezza massima %.2f m)" % hmax)
	check(xmax > 1.0, "gira davvero (si allarga di %.1f m dalla linea dritta)" % xmax)
	return done()


func test_giro_corto_con_avversario_sulla_curva_si_alza() -> bool:
	# curva verso sinistra (normale sinistra di +y = −x): avversario proprio sulla pancia della curva
	var a := scena(2, 0.0, 14.0, Vector2(-3.0, 7.0))
	var m: SimMatchScript = a[0]
	m.userKick(0, {"type": "auto", "tx": 0.0, "ty": 14.0, "curve": 3.0, "tratto": true})
	eq(tipo_calcio(m), "loft", "avversario sulla curva: alto, lo scavalca")
	return done()


func test_giro_intorno_all_avversario_resta_rasoterra() -> bool:
	# avversario sulla linea dritta: la curva gli gira intorno, il pallone resta a terra
	var a := scena(3, 0.0, 14.0, Vector2(0.0, 7.0))
	var m: SimMatchScript = a[0]
	m.userKick(0, {"type": "auto", "tx": 0.0, "ty": 14.0, "curve": 4.0, "tratto": true})
	eq(tipo_calcio(m), "ground", "la curva evita l'avversario: rasoterra")
	return done()


func test_giro_lungo_resta_alto() -> bool:
	var a := scena(4, 0.0, 28.0, Vector2(25.0, 40.0))
	var m: SimMatchScript = a[0]
	m.userKick(0, {"type": "auto", "tx": 0.0, "ty": 28.0, "curve": 5.0, "tratto": true})
	eq(tipo_calcio(m), "loft", "giro oltre %d m: alto come prima" % int(SimMatch.CURVE_GROUND_M))
	return done()


func test_senza_rifiniture_come_prima() -> bool:
	var a := scena(5, 0.0, 14.0, Vector2(25.0, 40.0), false)
	var m: SimMatchScript = a[0]
	m.userKick(0, {"type": "auto", "tx": 0.0, "ty": 14.0, "curve": 3.0, "tratto": true})
	eq(tipo_calcio(m), "loft", "senza rifiniture (confronti col JS, lezioni): curvo = alto")
	return done()
