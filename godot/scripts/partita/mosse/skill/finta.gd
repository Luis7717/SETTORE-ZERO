# Giochetto del dribbling "Finta di corpo" (id `finta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# finta di corpo: in corsa, passo largo e basso dal lato della finta, spalla che cade di là e sguardo di là; il pallone
# continua dritto e allo scatto l'esterno dell'altro piede lo porta via
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pF)
	K.dritto(c, "finta", S, g)
	var tp := maxf(t0 + 0.1, 0.5 * g)
	c.appoggia_corsa(pF, tp, 0.2, Vector2(F * 0.3, 0.0), 0.08)
	c.stacca(pS, tp + 0.03)
	c.chiave_bacino(0.55 * g, Vector3(F * 0.15, 0.85, 0.0))
	c.chiave_angoli(0.55 * g, Vector3(F * 0.35, 0.06, F * 0.1))
	c.chiave_busto(0.55 * g, Vector3(0.14, F * 0.25, F * 0.3))
	c.chiave_bacino(g, Vector3(F * 0.18, 0.84, 0.02))
	c.chiave_angoli(g, Vector3(F * 0.38, 0.06, F * 0.12))
	c.chiave_busto(g, Vector3(0.16, F * 0.28, F * 0.32))
	K.braccia(c, 0.55 * g, pS, Vector3(0.1, -0.24, 0.3), Vector3(0.38, -0.1, -0.05))
	c.chiave_sguardo(0.5 * g, 0.2, F * 0.55)
	c.chiave_sguardo(g, 0.4, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.85), 0.05)
