# Giochetto del dribbling "Suola" (id `suola`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# suola: la suola del piede della finta fa rotolare il pallone attraverso il corpo fino al lato scelto, col corpo che
# lo accompagna di lato
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pF)
	var t1 := maxf(t0 + 0.07, 0.22 * g)
	c.tocca(pF, t1, "sole", Vector3(F * 0.2, -0.22, 0), {"rel": Vector3(F * 0.14, 0, 0.46)})
	c.tocca(pF, 0.95 * g, "sole", Vector3(-F * 0.25, -0.22, 0), {"rel": Vector3(S * 0.4, 0, 0.44), "lega": true})
	c.stacca(pS, 0.4 * g)
	c.appoggia_corsa(pS, 0.4 * g + 0.11, 0.16, Vector2(S * 0.1, -0.04), 0.05)
	c.chiave_bacino(t1, Vector3(S * 0.02, 0.91, -0.05))
	c.chiave_angoli(t1, Vector3(F * 0.2, -0.02, 0))
	c.chiave_busto(t1, Vector3(0.06, F * 0.06, F * 0.15))
	c.chiave_bacino(0.9 * g, Vector3(S * 0.1, 0.89, -0.03))
	c.chiave_angoli(0.9 * g, Vector3(S * 0.25, 0.02, S * 0.06))
	c.chiave_busto(0.9 * g, Vector3(0.1, S * 0.09, S * 0.15))
	K.braccia(c, t1, pS, K.BR_LARGO, Vector3(0.4, -0.24, -0.1))
	K.braccia(c, 0.9 * g, pS, Vector3(0.4, -0.2, -0.16), Vector3(0.37, -0.1, 0.12))


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.5), 0.06)
