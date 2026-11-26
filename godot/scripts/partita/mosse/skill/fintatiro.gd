# Giochetto del dribbling "Finta di tiro" (id `fintatiro`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# finta di tiro: appoggio accanto al pallone, gamba caricata dietro e braccio alto come per calciare; il piede scende
# ma si ferma sul pallone e l'interno lo taglia dal lato scelto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pS)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.52)})
	c.palla_a(g + 0.05, {"rel": Vector3(F * 0.05, 0, 0.4)})
	var tp := maxf(t0 + 0.1, 0.3 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.24, K.H, 0.1), S * 0.15, 0.06)
	c.stacca(pF, tp - 0.04)
	c.passa(pF, 0.6 * g, Vector3(F * 0.16, 0.62, -0.5), Vector3(0, 1.0, 0), 0.0)
	c.passa_palla(pF, 0.92 * g, Vector3(F * 0.14, 0.2, -0.16), Vector3(-S * 0.4, 0.5, 0), 0.0)
	c.chiave_bacino(0.6 * g, Vector3(S * 0.04, 0.93, 0.0))
	c.chiave_angoli(0.6 * g, Vector3(F * 0.38, -0.06, 0))
	c.chiave_busto(0.6 * g, Vector3(-0.1, S * 0.07, F * 0.3))
	c.chiave_bacino(0.95 * g, Vector3(S * 0.04, 0.88, 0.06))
	c.chiave_angoli(0.95 * g, Vector3(S * 0.1, 0.1, 0))
	c.chiave_busto(0.95 * g, Vector3(0.22, S * 0.03, S * 0.2))
	K.braccia(c, 0.6 * g, pS, Vector3(0.38, -0.04, 0.12), Vector3(0.3, -0.26, -0.3))
	K.braccia(c, 0.95 * g, pS, Vector3(0.32, -0.26, -0.2), Vector3(0.2, -0.24, 0.26))
	c.chiave_sguardo(0.5 * g, 0.1, 0.0)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	K.via(c, S, tg, pF, "inside", K.interno(S, 0.7), 0.05)
