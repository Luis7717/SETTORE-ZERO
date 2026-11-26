# Giochetto del dribbling "Tunnel" (id `tunnel`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# parte B: partenza di scatto dietro al pallone (Luis 2026-11-26: "subito dopo il calcio la posa sembrava ferma e
# dritta"): falcate vere (appoggio lungo, poi in volo), non passettini sotto il corpo, e busto buttato in avanti
const FINE := 0.66             # la coreografia finisce tanto dopo il calcio (poi il clip di corsa)
# (il motore lo porta subito a più di 7 m/s: un appoggio più lungo di 0,11 s lascerebbe il piede troppo indietro)
const APPOGGIO_1 := 0.12       # s: quanto dura il primo appoggio della partenza (spinta lunga) ...
const APPOGGIO_MIN := 0.1      # ... e i successivi sempre più corti, fino a tanto (corre sempre più veloce)
const APPOGGIO_CALA := 0.01
const VOLO := 0.06             # s in volo tra un appoggio e l'altro
const TALLONE := 0.2           # m del modello: quanto sale il piede dietro mentre torna avanti
const BR_SPINTA_AV := Vector3(0.1, -0.16, 0.36)    # braccia della corsa di scatto: ampie
const BR_SPINTA_DI := Vector3(0.2, -0.3, -0.3)


# tunnel: in corsa, mezza finta di corpo per far allargare le gambe al difensore, il ginocchio del lato scelto sale
# (il passo "sospeso" che si vede da lontano) e la punta scende a colpire il pallone dritto tra le sue gambe (da lì è
# il pallone staccato del motore: dritto, rallenta per l'attrito); il portatore gli gira intorno e lo va a riprendere
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pF)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	var tp := maxf(t0 + 0.1, 0.5 * g)
	c.appoggia_corsa(pF, tp, 0.16, Vector2(F * 0.1, 0.0), 0.07)
	c.stacca(pS, tp + 0.02)
	# ginocchio su, piede sotto, poi giù di punta sul pallone (quello del motore, ai suoi piedi) verso il difensore
	c.passa(pS, tp + 0.55 * (g - tp), Vector3(S * 0.12, 0.3, 0.16), Vector3(0, 0.55, 0), 0.0)
	c.tocca(pS, g, "toe", Vector3(-S * 0.25, 0.3, 0), {"moto": true}, 0.0)
	c.passa(pS, g + 0.1, Vector3(S * 0.08, 0.2, 0.5), Vector3(0, 0.1, 0), 0.0)
	c.chiave_bacino(0.6 * g, Vector3(F * 0.1, 0.87, 0.0))
	c.chiave_angoli(0.6 * g, Vector3(F * 0.25, 0.06, F * 0.06))
	c.chiave_busto(0.6 * g, Vector3(0.14, F * 0.18, F * 0.22))
	c.chiave_bacino(g, Vector3(F * 0.08, 0.87, 0.04))
	c.chiave_angoli(g, Vector3(0, 0.14, 0))
	c.chiave_busto(g, Vector3(0.26, 0, 0))
	K.braccia(c, 0.6 * g, pS, Vector3(0.12, -0.26, 0.28), Vector3(0.37, -0.14, 0.0))
	K.braccia(c, g, pS, K.BR_DIETRO, K.BR_LARGO)
	c.chiave_sguardo(0.5 * g, 0.2, F * 0.5)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto). Il pallone è già partito (ball.finto del motore) e qui non lo
# tocca nessuno: il portatore parte di scatto dal lato scelto, intorno al difensore, guardando il pallone
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	var pF := K.altro(pS)
	c.taglia(tg, false)
	c.yaw_fisso_fino = tg
	c.chiave_giro(tg + 0.16, 0.0)
	c.chiave_sguardo(tg + 0.1, 1.0)
	# il piede del calcio prosegue appena e atterra avanti dal lato scelto: è il primo appoggio della partenza; quello
	# d'appoggio, rimasto dietro, spinge e si stacca
	c.passa(pS, tg + 0.05, Vector3(S * 0.14, 0.2, 0.42), Vector3(0, 0.25, 0), 0.0)
	c.stacca(pF, tg + 0.05)
	var a := pS
	var tp := tg + 0.13
	var T := APPOGGIO_1
	var primo := true
	var appoggi: Array = []
	while tp < tg + FINE + 0.12:
		c.appoggia_corsa(a, tp, T, Vector2(S * 0.05, 0.0) if primo else Vector2.ZERO, 0.05 if primo else TALLONE)
		c.stacca(a, tp + T)
		appoggi.append([tp, a])
		a = K.altro(a)
		tp += T + VOLO
		T = maxf(APPOGGIO_MIN, T - APPOGGIO_CALA)
		primo = false
	# spinta: bacino giù e avanti, busto buttato in avanti e dentro la curva; poi piano piano su, di corsa
	c.chiave_bacino(tg + 0.09, Vector3(S * 0.04, 0.85, 0.04))
	c.chiave_angoli(tg + 0.09, Vector3(S * 0.2, 0.3, S * 0.1))
	c.chiave_busto(tg + 0.1, Vector3(0.42, S * 0.12, S * 0.15))
	c.chiave_bacino(tg + 0.32, Vector3(0, 0.86, 0.04))
	c.chiave_angoli(tg + 0.32, Vector3(0, 0.3, S * 0.06))
	c.chiave_busto(tg + 0.32, Vector3(0.45, S * 0.06, 0))
	c.chiave_bacino(tg + FINE, Vector3(0, 0.91, -0.01))
	c.chiave_angoli(tg + FINE, Vector3(0, 0.16, 0))
	c.chiave_busto(tg + FINE, Vector3(0.2, 0, 0))
	# braccia: sul calcio larghe (equilibrio), poi a ogni appoggio avanti quello opposto alla gamba che appoggia
	K.braccia(c, tg + 0.04, pS, K.BR_DIETRO, K.BR_LARGO)
	for k: Array in appoggi:
		c.chiave_braccio(K.altro(String(k[1])), float(k[0]) + 0.02, BR_SPINTA_AV)
		c.chiave_braccio(String(k[1]), float(k[0]) + 0.02, BR_SPINTA_DI)
	c.fine = tg + FINE
