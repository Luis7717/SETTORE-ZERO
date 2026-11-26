# Giochetto del dribbling "Colpo di tacco" (id `tacco`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# colpo di tacco: appoggio accanto al pallone, l'altro piede gli passa davanti e il tacco lo manda dietro la gamba
# d'appoggio, dal lato scelto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pS)
	c.chiave_giro(0.6 * g, F * 0.3)
	c.palla_a(0.8 * g, {"rel": Vector3(F * 0.02, 0, 0.4)})
	var tp := maxf(t0 + 0.1, 0.4 * g)
	c.appoggia(pS, tp, Vector2(S * 0.2, 0.6), 0.0, 0.07)
	c.stacca(pF, tp - 0.03)
	c.passa_palla(pF, 0.7 * g, Vector3(F * 0.24, 0.24, 0.05), Vector3(-S * 0.5, 0.3, 0), 0.03)
	c.passa_palla(pF, 0.93 * g, Vector3(F * 0.2, 0.14, 0.2), Vector3(-S * 1.1, 0.2, 0), 0.0)
	c.chiave_bacino(tp, Vector3(0, 0.9, 0.02))
	c.chiave_bacino(0.93 * g, Vector3(S * 0.04, 0.92, 0.06))
	c.chiave_angoli(0.93 * g, Vector3(F * 0.2, 0.08, 0))
	c.chiave_busto(0.93 * g, Vector3(0.14, F * 0.06, F * 0.2))
	K.braccia(c, 0.93 * g, pS, Vector3(0.37, -0.1, 0.1), Vector3(0.36, -0.14, -0.1))
	c.chiave_sguardo(0.6 * g, 0.3, F * 0.45)
	c.chiave_sguardo(g, 0.7, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	K.via(c, S, tg, pF, "heel", Vector3(-S * 1.15, 0.2, 0), 0.04)
