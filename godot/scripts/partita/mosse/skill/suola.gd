# Giochetto del dribbling "Suola" (id `suola`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


const Finta := preload("finta.gd")


# suola in corsa: l'altro piede regge, la suola del piede della finta si posa sul pallone e lo fa rotolare attraverso
# il corpo fino al lato scelto; a metà il piede che regge fa un saltello dallo stesso lato (il corpo non si ferma),
# poi il pallone rotola via da solo, la gamba della suola scende e l'esterno dell'altro piede lo porta avanti
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t1 := 0.5 * g
	Finta.rincorsa(c, pF, t1)
	c.tocca(pF, t1, "sole", Vector3(F * 0.2, -0.22, 0), {"rel": Vector3(F * 0.14, 0, 0.48)})
	c.tocca(pF, 0.86 * g, "sole", Vector3(-F * 0.25, -0.22, 0), {"rel": Vector3(S * 0.36, 0, 0.44), "lega": true})
	c.palla_a(g + 0.1, {"rel": Vector3(S * 0.52, 0, 0.5)})
	# (la gamba della suola scende incrociata davanti un attimo prima dello scatto: da lì spinge)
	c.appoggia_corsa(pF, 0.97 * g, 0.12, Vector2(S * 0.1, 0.0), 0.05)
	# saltello del piede che regge
	var th := 0.64 * g
	c.stacca(pS, th)
	c.appoggia_corsa(pS, th + 0.07, 0.14, Vector2(S * 0.12, -0.03), 0.04)
	K.braccia(c, 0.25 * g, pS, K.BR_AVANTI, K.BR_DIETRO)
	c.chiave_busto(0.25 * g, Vector3(0.2, 0, 0))
	c.chiave_bacino(t1, Vector3(S * 0.02, 0.91, -0.05))
	c.chiave_angoli(t1, Vector3(F * 0.2, -0.02, 0))
	c.chiave_busto(t1, Vector3(0.06, F * 0.06, F * 0.15))
	c.chiave_bacino(th + 0.04, Vector3(S * 0.06, 0.93, -0.04))
	c.chiave_bacino(0.9 * g, Vector3(S * 0.1, 0.89, -0.03))
	c.chiave_angoli(0.9 * g, Vector3(S * 0.25, 0.02, S * 0.06))
	c.chiave_busto(0.9 * g, Vector3(0.1, S * 0.09, S * 0.15))
	K.braccia(c, t1, pS, K.BR_LARGO, Vector3(0.4, -0.24, -0.1))
	K.braccia(c, 0.9 * g, pS, Vector3(0.4, -0.2, -0.16), Vector3(0.37, -0.1, 0.12))


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.5), 0.06)
