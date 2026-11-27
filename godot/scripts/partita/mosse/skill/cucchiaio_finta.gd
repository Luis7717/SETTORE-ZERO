# Giochetto del dribbling "Finta col cucchiaio" (id `cucchiaio_finta`), PROVVISORIO: per ora è la copia di skill/fintatiro.gd (da rifare sul gesto vero)
# Giochetto del dribbling "Finta col cucchiaio" (id `cucchiaio_finta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# finta di tiro: ultimo passo lungo con l'appoggio accanto al pallone (il corpo gli arriva sopra), gamba caricata
# dietro e braccio alto come per calciare; il piede scende ma si ferma sul pallone e l'interno lo taglia dal lato scelto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var tp := 0.58 * g
	K.rincorsa(c, pS, tp)
	# il pallone rallenta da solo: allo scatto è accanto al piede d'appoggio
	c.palla_a(g + 0.05, {"rel": Vector3(F * 0.04, 0, 0.18)})
	c.appoggia(pS, tp, Vector2(S * 0.2, 0.3), S * 0.12, 0.06)
	c.stacca(pF, tp + 0.01)
	c.passa(pF, 0.8 * g, Vector3(F * 0.16, 0.66, -0.52), Vector3(0, 1.0, 0), 0.0)
	c.passa_palla(pF, 0.95 * g, Vector3(F * 0.14, 0.2, -0.18), Vector3(-S * 0.4, 0.5, 0), 0.0)
	c.chiave_bacino(tp, Vector3(0, 0.85, -0.04))
	c.chiave_angoli(tp, Vector3(F * 0.12, -0.04, 0))
	c.chiave_bacino(0.8 * g, Vector3(S * 0.04, 0.92, 0.0))
	c.chiave_angoli(0.8 * g, Vector3(F * 0.4, -0.08, 0))
	c.chiave_busto(0.8 * g, Vector3(-0.12, S * 0.08, F * 0.34))
	c.chiave_bacino(0.97 * g, Vector3(S * 0.04, 0.87, 0.06))
	c.chiave_angoli(0.97 * g, Vector3(S * 0.1, 0.1, 0))
	c.chiave_busto(0.97 * g, Vector3(0.24, S * 0.03, S * 0.2))
	K.braccia(c, tp, pS, K.BR_AVANTI, K.BR_DIETRO)
	K.braccia(c, 0.8 * g, pS, Vector3(0.4, 0.02, 0.1), Vector3(0.3, -0.26, -0.32))
	K.braccia(c, 0.97 * g, pS, Vector3(0.32, -0.26, -0.2), Vector3(0.2, -0.24, 0.26))
	c.chiave_sguardo(0.5 * g, 0.1, 0.0)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	K.via(c, S, tg, pF, "inside", K.interno(S, 0.7), 0.05,
		{"palla": [[tg + 0.17, {"rel": Vector3(S * 0.3, 0, 0.45)}]]})
