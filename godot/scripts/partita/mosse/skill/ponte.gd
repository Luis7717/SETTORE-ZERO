# Giochetto del dribbling "Ponte" (id `ponte`): parte A (la corsa e il tocco, dura `g` = show di sim/skill.gd) e parte B
# (dallo scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
# Luis 2026-11-27: "il portatore tocca il pallone da un lato del difensore e gli corre dall'altro lato, lo riprende
# dietro". Il pallone dal tocco in poi è quello staccato del motore (sim/duel.gd dribPallaLancia con `palla_lato`: passa
# accanto al difensore dal lato della finta, rallenta per l'attrito); qui c'è il gesto: corsa dritta sul difensore,
# colpetto d'esterno col piede lontano dal lato scelto (gamba che si allunga di là, dietro al pallone), poi quel piede
# atterra largo e spinge: taglio secco dal lato scelto e scatto intorno al difensore.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

const PRIMA := 0.11            # s: il piede d'appoggio atterra tanto prima del tocco
const FINE := 0.66             # la coreografia finisce tanto dopo il tocco (poi il clip di corsa)
# (il motore lo porta subito a più di 7 m/s: un appoggio più lungo di 0,11 s lascerebbe il piede troppo indietro)
const APPOGGIO_1 := 0.11       # s: quanto dura il primo appoggio della partenza (la spinta del taglio) ...
const APPOGGIO_MIN := 0.1      # ... e i successivi
const APPOGGIO_CALA := 0.01
const VOLO := 0.06             # s in volo tra un appoggio e l'altro
const TALLONE := 0.2           # m del modello: quanto sale il piede dietro mentre torna avanti
const BR_SPINTA_AV := Vector3(0.1, -0.16, 0.36)    # braccia della corsa di scatto: ampie
const BR_SPINTA_DI := Vector3(0.2, -0.3, -0.3)


# parte A: S = lato scelto (da dove passerà il portatore), F = lato del pallone. Passi di corsa, il piede del lato
# scelto appoggia accanto al pallone, l'altro si carica appena e col suo esterno (punta girata in dentro) spinge il
# pallone avanti e di là, deciso; spalle già verso il lato scelto, braccio del lato del pallone largo (equilibrio)
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var ts := maxf(0.08, g - PRIMA)
	K.rincorsa(c, pS, ts)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	c.appoggia_corsa(pS, ts, 0.16, Vector2(S * 0.08, 0.0), 0.08)
	c.stacca(pF, ts - 0.01)
	# la gamba del tocco si carica poco dietro e fuori, poi l'esterno colpisce basso il pallone (quello del motore)
	c.passa(pF, ts + 0.45 * (g - ts), Vector3(F * 0.16, 0.2, -0.08), Vector3(S * 0.3, 0.6, 0), 0.0)
	c.tocca(pF, g, "outside", Vector3(S * 0.55, 0.3, 0), {"moto": true}, 0.0)
	# ... e prosegue allungata dietro al pallone, avanti e di là
	c.passa(pF, g + 0.08, Vector3(F * 0.3, 0.14, 0.5), Vector3(S * 0.35, 0.1, 0), 0.0)
	c.chiave_bacino(ts, Vector3(0, 0.88, 0.0))
	c.chiave_angoli(ts, Vector3(0, 0.12, 0))
	c.chiave_busto(ts, Vector3(0.16, 0, 0))
	c.chiave_bacino(g, Vector3(S * 0.05, 0.86, 0.03))
	c.chiave_angoli(g, Vector3(F * 0.2, 0.12, S * 0.08))
	c.chiave_busto(g, Vector3(0.2, S * 0.12, S * 0.2))
	K.braccia(c, ts, pS, K.BR_AVANTI, K.BR_DIETRO)
	K.braccia(c, g, pS, Vector3(0.22, -0.3, -0.16), Vector3(0.4, -0.06, 0.1))
	c.chiave_sguardo(0.5 * g, 0.9, 0.0)
	c.chiave_sguardo(g, 0.6, S * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto). Il pallone è già partito (ball.finto del motore) e qui non lo
# tocca nessuno: il piede del tocco atterra largo dal lato del pallone e spinge, il portatore taglia dal lato scelto e
# gira intorno al difensore di scatto, guardando il pallone che gli passa dall'altra parte
static func b(c: Coreo, S: float, tg: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.altro(pS)
	c.taglia(tg, false)
	c.yaw_fisso_fino = tg
	c.chiave_giro(tg + 0.16, 0.0)
	# il piede del tocco atterra largo, avanti dal lato del pallone: è la spinta del taglio; l'altro, rimasto dietro,
	# si stacca e apre il primo passo dal lato scelto
	c.passa(pF, tg + 0.05, Vector3(F * 0.3, 0.12, 0.44), Vector3(S * 0.2, 0.1, 0), 0.0)
	c.stacca(pS, tg + 0.05)
	var a := pF
	var tp := tg + 0.11
	var T := APPOGGIO_1
	var primo := true
	var appoggi: Array = []
	while tp < tg + FINE + 0.12:
		c.appoggia_corsa(a, tp, T, Vector2(F * 0.12, 0.0) if primo else Vector2.ZERO, 0.05 if primo else TALLONE)
		c.stacca(a, tp + T)
		appoggi.append([tp, a])
		a = K.altro(a)
		tp += T + VOLO
		T = maxf(APPOGGIO_MIN, T - APPOGGIO_CALA)
		primo = false
	# taglio: bacino giù sopra il piede largo, tutto il corpo inclinato dentro la curva (verso il lato scelto), busto
	# buttato in avanti; poi piano piano su, di corsa
	c.chiave_bacino(tg + 0.1, Vector3(S * 0.08, 0.83, 0.04))
	c.chiave_angoli(tg + 0.1, Vector3(S * 0.25, 0.28, S * 0.2))
	c.chiave_busto(tg + 0.11, Vector3(0.4, S * 0.16, S * 0.2))
	c.chiave_bacino(tg + 0.32, Vector3(S * 0.03, 0.86, 0.04))
	c.chiave_angoli(tg + 0.32, Vector3(0, 0.3, S * 0.1))
	c.chiave_busto(tg + 0.32, Vector3(0.44, S * 0.08, 0))
	c.chiave_bacino(tg + FINE, Vector3(0, 0.91, -0.01))
	c.chiave_angoli(tg + FINE, Vector3(0, 0.16, 0))
	c.chiave_busto(tg + FINE, Vector3(0.2, 0, 0))
	# braccia: nel taglio quello del lato del pallone largo e alto (equilibrio), poi a ogni appoggio avanti quello
	# opposto alla gamba che appoggia
	K.braccia(c, tg + 0.06, pS, Vector3(0.2, -0.32, -0.2), Vector3(0.42, -0.02, 0.06))
	for i in appoggi.size():
		if i == 0:
			continue
		var k: Array = appoggi[i]
		c.chiave_braccio(K.altro(String(k[1])), float(k[0]) + 0.02, BR_SPINTA_AV)
		c.chiave_braccio(String(k[1]), float(k[0]) + 0.02, BR_SPINTA_DI)
	# la testa segue il pallone che passa dall'altra parte del difensore, poi avanti
	c.chiave_sguardo(tg + 0.12, 1.0)
	c.chiave_sguardo(tg + 0.45, 1.0)
	c.fine = tg + FINE
