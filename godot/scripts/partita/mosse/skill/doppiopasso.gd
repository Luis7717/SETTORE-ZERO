# Giochetto del dribbling "Doppio passo" (id `doppiopasso`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# doppio passo: quasi fermo sul pallone, due passi larghi e lenti sopra il pallone (prima dal lato scelto, poi dalla
# finta, con tutto il corpo basso che ci va dietro), poi l'esterno lo porta via
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pS)
	c.palla_a(0.1, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(g + 0.05, {"rel": Vector3(0, 0, 0.44)})
	var d1 := 0.21
	var ta := t0
	K.passo_sopra(c, pS, S, ta, d1, 0.3, 0.24, 0.02)
	var tb := ta + d1 - 0.02
	c.stacca(pF, tb)
	var d2 := minf(0.24, g - 0.02 - tb)
	K.passo_sopra(c, pF, F, tb, d2, 0.4, 0.24, 0.02)
	c.chiave_bacino(ta + 0.75 * d1, Vector3(S * 0.08, 0.86, 0.0))
	c.chiave_angoli(ta + 0.75 * d1, Vector3(S * 0.3, 0.08, S * 0.06))
	c.chiave_busto(ta + 0.75 * d1, Vector3(0.18, S * 0.16, S * 0.22))
	c.chiave_bacino(tb + 0.85 * d2, Vector3(F * 0.16, 0.82, 0.0))
	c.chiave_angoli(tb + 0.85 * d2, Vector3(F * 0.4, 0.08, F * 0.12))
	c.chiave_busto(tb + 0.85 * d2, Vector3(0.2, F * 0.28, F * 0.32))
	K.braccia(c, ta + 0.75 * d1, pS, Vector3(0.37, -0.16, -0.02), Vector3(0.12, -0.26, 0.28))
	K.braccia(c, tb + 0.85 * d2, pS, Vector3(0.12, -0.26, 0.28), Vector3(0.38, -0.1, -0.04))
	c.chiave_sguardo(tb + 0.6 * d2, 0.5, F * 0.4)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.85), 0.05)
