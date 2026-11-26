# Giochetto del dribbling "Elastico" (id `elastico`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# elastico: l'esterno del piede della finta porta il pallone fuori (e il corpo ci va dietro), poi il piede gli gira
# intorno e l'interno lo riporta di scatto dal lato scelto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pF)
	var tf := maxf(t0 + 0.08, 0.26 * g)
	c.tocca(pF, tf, "outside", Vector3(-F * 0.35, 0.15, 0), {"rel": Vector3(F * 0.04, 0, 0.5)})
	c.tocca(pF, 0.76 * g, "outside", Vector3(-F * 0.5, 0.15, 0), {"rel": Vector3(F * 0.44, 0, 0.52), "lega": true, "frena": true})
	c.passa_palla(pF, 0.94 * g, Vector3(F * 0.04, 0.26, 0.06), Vector3(-S * 0.5, 0.3, 0), 0.0)
	c.tocca(pF, g + 0.05, "inside", K.interno(S, 1.2), {"rel": Vector3(F * 0.44, 0, 0.52)})
	# il piede che regge fa un saltello per seguire il corpo
	c.stacca(pS, 0.45 * g)
	c.appoggia(pS, 0.45 * g + 0.09, Vector2(S * 0.1, 0.0), 0.0, 0.04)
	c.chiave_bacino(tf, Vector3(F * 0.04, 0.9, -0.03))
	c.chiave_bacino(0.76 * g, Vector3(F * 0.14, 0.86, 0.0))
	c.chiave_angoli(0.76 * g, Vector3(F * 0.32, 0.06, F * 0.08))
	c.chiave_busto(0.76 * g, Vector3(0.14, F * 0.22, F * 0.24))
	K.braccia(c, 0.76 * g, pS, Vector3(0.14, -0.26, 0.28), Vector3(0.38, -0.12, 0.0))
	c.chiave_sguardo(0.7 * g, 0.6, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	K.via(c, S, tg, pF, "inside", K.interno(S, 1.2), 0.05)
