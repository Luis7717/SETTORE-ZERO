# Giochetto del dribbling "Croqueta" (id `croqueta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# croqueta: scivolando di lato verso il lato scelto, l'interno del piede della finta passa il pallone di traverso
# (quasi un metro) all'interno dell'altro piede, che lo porta avanti; il corpo salta da un piede all'altro col pallone
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pF)
	var t1 := maxf(t0 + 0.1, 0.38 * g)
	# il pallone davanti al piede della finta, che lo colpisce d'interno verso il lato scelto ...
	c.palla_a(0.08, {"rel": Vector3(F * 0.1, 0, 0.46)})
	c.tocca(pF, t1, "inside", Vector3(F * 0.5, 0.05, 0), {"rel": Vector3(F * 0.16, 0, 0.42)}, 0.08)
	# ... e arriva all'interno dell'altro piede, già aperto ad aspettarlo dall'altra parte del corpo
	c.tocca(pS, g + 0.07, "inside", Vector3(S * 0.5, 0.1, 0), {"rel": Vector3(S * 0.34, 0, 0.44)}, 0.05)
	c.appoggia_corsa(pF, t1 + 0.1, 0.14, Vector2(S * 0.06, 0.0), 0.05)
	c.passa(pS, 0.75 * g, Vector3(S * 0.4, 0.2, 0.3), Vector3(S * 0.5, 0.1, 0), 0.06)
	# si abbassa sul primo tocco, poi il saltello di lato e si allunga verso il lato scelto
	c.chiave_bacino(t1 - 0.03, Vector3(F * 0.06, 0.85, -0.02))
	c.chiave_angoli(t1 - 0.03, Vector3(F * 0.2, 0.08, F * 0.08))
	c.chiave_busto(t1 - 0.03, Vector3(0.16, F * 0.14, F * 0.12))
	c.chiave_bacino(0.75 * g, Vector3(S * 0.08, 0.96, 0.0))
	c.chiave_angoli(0.75 * g, Vector3(S * 0.1, 0.04, S * 0.12))
	c.chiave_busto(0.75 * g, Vector3(0.1, S * 0.2, S * 0.1))
	c.chiave_bacino(g + 0.04, Vector3(S * 0.1, 0.87, 0.0))
	c.chiave_angoli(g + 0.04, Vector3(S * 0.15, 0.08, S * 0.1))
	c.chiave_busto(g + 0.04, Vector3(0.14, S * 0.16, 0))
	K.braccia(c, t1, pS, Vector3(0.38, -0.16, 0.0), Vector3(0.3, -0.3, 0.1))
	K.braccia(c, 0.75 * g, pS, Vector3(0.4, -0.02, 0.0), Vector3(0.4, -0.1, 0.0))
	K.braccia(c, g + 0.04, pS, Vector3(0.38, -0.12, 0.0), Vector3(0.34, -0.24, 0.12))


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "inside", Vector3(S * 0.5, 0.1, 0), 0.07, {"rel": Vector3(S * 0.1, 0, 0.5)})
