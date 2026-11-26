# Giochetto del dribbling "Stop e via" (id `stopgo`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# stop e via: suola sul pallone, il portatore si ferma e si alza dritto (il difensore si rilassa), tira appena
# indietro il pallone e riparte di scatto
static func a(c: Coreo, S: float, g: float) -> void:
	var pS := K.ls(S)
	var t0 := K.libera(c, pS)   # (l'altro piede regge fermo)
	var t1 := maxf(t0 + 0.07, 0.2 * g)
	c.tocca(pS, t1, "sole", Vector3(0, -0.25, 0), {"rel": Vector3(S * 0.05, 0, 0.5)})
	c.tocca(pS, 0.8 * g, "sole", Vector3(0, -0.2, 0), {"rel": Vector3(S * 0.05, 0, 0.36), "lega": true})
	c.chiave_bacino(t1, Vector3(0, 0.9, -0.08))
	c.chiave_angoli(t1, Vector3(0, -0.06, 0))
	c.chiave_busto(t1, Vector3(0.02, 0, 0))
	c.chiave_bacino(0.6 * g, Vector3(-S * 0.03, 0.955, -0.08))
	c.chiave_angoli(0.6 * g, Vector3(0, -0.04, 0))
	c.chiave_busto(0.6 * g, Vector3(-0.04, 0, 0))
	c.chiave_bacino(g, Vector3(-S * 0.02, 0.9, -0.04))
	c.chiave_busto(g, Vector3(0.1, 0, 0))
	K.braccia(c, t1, pS, K.BR_LARGO, K.BR_LARGO)
	K.braccia(c, 0.6 * g, pS, K.BR_RIPOSO, K.BR_RIPOSO)
	K.braccia(c, g, pS, K.BR_DIETRO, K.BR_AVANTI)
	c.chiave_sguardo(0.5 * g, 0.25, 0.0)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.6), 0.04, {"spinta": 1.3})
