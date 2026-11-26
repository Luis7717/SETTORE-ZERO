# Giochetto del dribbling "Finta e giro" (id `cruyff`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# finta e giro: il corpo si apre verso la finta come per un passaggio o un cross (appoggio accanto al pallone, gamba
# caricata dietro, braccio alto); il piede scende, ma invece di calciare passa davanti al pallone e l'interno lo
# trascina dietro la gamba d'appoggio: il giocatore si gira dall'altra parte e riparte
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pS)
	c.chiave_giro(0.3 * g, F * 0.9)
	c.chiave_giro(0.7 * g, F * 1.15)
	c.chiave_giro(g, F * 1.1)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(0.34 * g, {"rel": Vector3(F * 0.08, 0, 0.5)})
	c.palla_a(0.9 * g, {"rel": Vector3(F * 0.1, 0, 0.3)})
	# appoggio accanto al pallone (dalla parte del lato scelto, che ora è alle sue spalle)
	var tp := maxf(t0 + 0.1, 0.36 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.22, K.H, 0.02), 0.0, 0.07)
	c.stacca(pF, tp - 0.03)
	# gamba caricata dietro, ben alta ...
	c.passa(pF, 0.62 * g, Vector3(F * 0.16, 0.66, -0.52), Vector3(0, 1.1, 0), 0.0)
	# ... scende ma passa davanti al pallone, punta girata in dentro
	c.passa_palla(pF, 0.93 * g, Vector3(F * 0.02, 0.16, 0.26), Vector3(S * 1.25, 0.1, 0), 0.02)
	c.chiave_bacino(0.3 * g, Vector3(0, 0.9, 0.0))
	c.chiave_bacino(0.62 * g, Vector3(S * 0.05, 0.95, -0.04))
	c.chiave_angoli(0.62 * g, Vector3(F * 0.35, -0.08, 0))
	c.chiave_busto(0.62 * g, Vector3(-0.14, S * 0.08, F * 0.3))
	c.chiave_bacino(0.95 * g, Vector3(S * 0.06, 0.86, 0.04))
	c.chiave_angoli(0.95 * g, Vector3(S * 0.3, 0.14, S * 0.06))
	c.chiave_busto(0.95 * g, Vector3(0.26, S * 0.08, S * 0.3))
	# braccia da calcio: quello opposto alla gamba che calcia alto e largo, l'altro indietro
	K.braccia(c, 0.62 * g, pS, Vector3(0.42, 0.1, 0.12), Vector3(0.36, -0.1, -0.26))
	K.braccia(c, 0.95 * g, pS, Vector3(0.36, -0.18, -0.2), Vector3(0.4, -0.12, 0.2))
	c.chiave_sguardo(0.3 * g, 0.2, 0.0)
	c.chiave_sguardo(0.62 * g, 0.1, 0.0)
	c.chiave_sguardo(0.92 * g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	K.via(c, S, tg, pF, "inside", Vector3(S * 1.3, 0.05, 0), 0.04, {"fine": 0.48})
