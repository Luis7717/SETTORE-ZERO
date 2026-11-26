# Giochetto del dribbling "Elastico inverso" (id `elastico_inv`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# elastico inverso: l'interno del piede del lato scelto porta il pallone dentro, attraverso il corpo (gamba
# incrociata), poi l'esterno dello stesso piede lo riporta fuori di scatto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pS)
	var tf := maxf(t0 + 0.08, 0.26 * g)
	c.tocca(pS, tf, "inside", Vector3(S * 0.35, 0.1, 0), {"rel": Vector3(S * 0.1, 0, 0.5)})
	c.tocca(pS, 0.76 * g, "inside", Vector3(S * 0.5, 0.1, 0), {"rel": Vector3(F * 0.3, 0, 0.5), "lega": true, "frena": true})
	c.passa_palla(pS, 0.94 * g, Vector3(F * 0.06, 0.26, 0.04), Vector3(-S * 0.5, 0.3, 0), 0.0)
	c.tocca(pS, g + 0.05, "outside", K.esterno(S, 0.9), {"rel": Vector3(F * 0.3, 0, 0.5)})
	c.stacca(pF, 0.4 * g)
	c.appoggia(pF, 0.4 * g + 0.09, Vector2(F * 0.2, -0.04), F * 0.2, 0.04)
	c.chiave_bacino(tf, Vector3(0, 0.9, -0.03))
	c.chiave_bacino(0.76 * g, Vector3(F * 0.1, 0.87, 0.0))
	c.chiave_angoli(0.76 * g, Vector3(F * 0.4, 0.06, F * 0.06))
	c.chiave_busto(0.76 * g, Vector3(0.14, F * 0.18, F * 0.3))
	K.braccia(c, 0.76 * g, pS, Vector3(0.4, -0.2, -0.16), Vector3(0.36, -0.14, 0.1))
	c.chiave_sguardo(0.7 * g, 0.6, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.9), 0.05)
