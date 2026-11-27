# Giochetto del dribbling "Triplo elastico" (id `elastico3`), PROVVISORIO: per ora è la copia di skill/elastico.gd (da rifare sul gesto vero)
# Giochetto del dribbling "Triplo elastico" (id `elastico3`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# elastico: l'esterno del piede della finta porta il pallone fuori (e il corpo ci va dietro), poi il piede gli gira
# intorno e l'interno lo riporta di scatto attraverso il corpo dal lato scelto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var tf := 0.4 * g
	K.rincorsa(c, pF, tf)
	c.tocca(pF, tf, "outside", Vector3(-F * 0.35, 0.15, 0), {"rel": Vector3(F * 0.04, 0, 0.5)})
	c.tocca(pF, 0.74 * g, "outside", Vector3(-F * 0.5, 0.15, 0), {"rel": Vector3(F * 0.5, 0, 0.52), "lega": true, "frena": true})
	c.passa_palla(pF, 0.92 * g, Vector3(F * 0.2, 0.2, 0.02), Vector3(-S * 0.6, 0.25, 0), 0.0)
	c.tocca(pF, g + 0.05, "inside", K.interno(S, 1.2), {"rel": Vector3(F * 0.5, 0, 0.52)})
	# il piede che regge fa un saltello per seguire il corpo
	c.stacca(pS, 0.6 * g)
	c.appoggia_corsa(pS, 0.6 * g + 0.07, 0.14, Vector2(0.0, -0.04), 0.04)
	c.chiave_bacino(tf, Vector3(F * 0.04, 0.9, -0.03))
	c.chiave_bacino(0.74 * g, Vector3(F * 0.15, 0.86, 0.0))
	c.chiave_angoli(0.74 * g, Vector3(F * 0.34, 0.06, F * 0.08))
	c.chiave_busto(0.74 * g, Vector3(0.14, F * 0.24, F * 0.26))
	K.braccia(c, 0.74 * g, pS, Vector3(0.14, -0.26, 0.28), Vector3(0.38, -0.12, 0.0))
	c.chiave_sguardo(0.7 * g, 0.6, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'interno riporta il pallone di scatto dall'altra parte del corpo
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	K.via(c, S, tg, pF, "inside", K.interno(S, 1.2), 0.04,
		{"palla": [[tg + 0.15, {"rel": Vector3(S * 0.24, 0, 0.5)}]]})
