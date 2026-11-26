# Giochetto del dribbling "Taglio secco" (id `chop`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# taglio secco: di corsa verso la finta; il piede del lato scelto si pianta oltre il pallone, saltello, e l'interno
# dell'altro piede (punta girata in dentro) arriva da dietro e taglia il pallone dietro la gamba d'appoggio, di lato:
# cambio secco di direzione, il corpo atterra già inclinato da quella parte
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pS)
	c.chiave_giro(0.5 * g, F * 0.35)
	c.chiave_giro(g, F * 0.3)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.52)})
	c.palla_a(0.95 * g, {"rel": Vector3(F * 0.04, 0, 0.4)})
	# il piede d'appoggio si pianta oltre il pallone, dal lato scelto: il pallone gli passerà dietro
	var tp := maxf(t0 + 0.1, 0.55 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.16, K.H, 0.2), S * 0.2, 0.08)
	c.stacca(pF, tp - 0.02)
	# l'altro piede si carica largo e alto, punta girata in dentro
	c.passa(pF, 0.86 * g, Vector3(F * 0.36, 0.36, 0.2), Vector3(-S * 1.4, 0.2, 0), 0.04)
	c.chiave_bacino(tp, Vector3(0, 0.88, 0.04))
	c.chiave_angoli(tp, Vector3(0, 0.14, 0))
	c.chiave_busto(tp, Vector3(0.2, 0, 0))
	c.chiave_bacino(0.9 * g, Vector3(S * 0.03, 1.0, 0.08))
	c.chiave_angoli(0.9 * g, Vector3(S * 0.35, 0.1, S * 0.1))
	c.chiave_busto(0.9 * g, Vector3(0.14, S * 0.12, S * 0.35))
	K.braccia(c, tp, pS, K.BR_DIETRO, K.BR_AVANTI)
	K.braccia(c, 0.9 * g, pS, Vector3(0.4, 0.02, 0.0), Vector3(0.4, -0.02, 0.1))
	c.chiave_sguardo(0.5 * g, 0.4, F * 0.3)
	c.chiave_sguardo(0.9 * g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	K.via(c, S, tg, pF, "inside", Vector3(-S * 1.5, 0.05, 0), 0.03, {"salto": 0.07, "fine": 0.44})
