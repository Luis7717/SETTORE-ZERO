# Giochetto del dribbling "Stop e via" (id `stopgo`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


const Finta := preload("finta.gd")


# stop e via: passo di frenata, la suola ferma il pallone sul prato (il pallone resta lì e il corpo gli arriva sopra),
# il portatore si alza dritto e l'altro piede si rimette sotto (il difensore si rilassa), tira appena indietro il
# pallone e riparte di scatto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t1 := 0.3 * g
	Finta.rincorsa(c, pS, t1)
	c.tocca(pS, t1, "sole", Vector3(0, -0.25, 0), {"rel": Vector3(S * 0.05, 0, 0.56)})
	c.tocca(pS, 0.62 * g, "sole", Vector3(0, -0.2, 0), {"resta": true, "lega": true})
	c.tocca(pS, 0.92 * g, "sole", Vector3(0, -0.16, 0), {"rel": Vector3(S * 0.06, 0, 0.3), "lega": true})
	# il piede che regge ha frenato davanti: quando il corpo gli è passato sopra si rimette sotto l'anca
	c.stacca(pF, 0.52 * g)
	c.appoggia(pF, 0.52 * g + 0.08, Vector2(F * 0.13, -0.02), F * 0.1, 0.04)
	c.chiave_bacino(t1, Vector3(0, 0.88, -0.1))
	c.chiave_angoli(t1, Vector3(0, -0.1, 0))
	c.chiave_busto(t1, Vector3(-0.04, 0, 0))
	c.chiave_bacino(0.66 * g, Vector3(-S * 0.03, 0.955, -0.06))
	c.chiave_angoli(0.66 * g, Vector3(0, -0.04, 0))
	c.chiave_busto(0.66 * g, Vector3(-0.05, 0, 0))
	c.chiave_bacino(g, Vector3(-S * 0.02, 0.89, -0.02))
	c.chiave_busto(g, Vector3(0.12, 0, 0))
	K.braccia(c, t1, pS, K.BR_LARGO, K.BR_LARGO)
	K.braccia(c, 0.66 * g, pS, K.BR_RIPOSO, K.BR_RIPOSO)
	K.braccia(c, g, pS, K.BR_DIETRO, K.BR_AVANTI)
	c.chiave_sguardo(0.5 * g, 0.25, 0.0)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.6), 0.04, {"spinta": 1.3})
