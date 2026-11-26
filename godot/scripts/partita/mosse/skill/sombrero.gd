# Giochetto del dribbling "Sombrero" (id `sombrero`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# sombrero: rallentando, la suola tira il pallone verso di sé, la punta gli va sotto e lo alza: pallonetto sopra la
# testa del difensore (gravità vera), e il portatore gli gira intorno e va a riprenderlo dove cade
static func a(c: Coreo, S: float, g: float) -> void:
	var pS := K.ls(S)
	var tk := float(K.Skill.trova("sombrero").tk)
	var t0 := K.libera(c, pS)
	var t1 := maxf(t0 + 0.07, 0.22 * tk)
	c.palla_a(0.06, {"rel": Vector3(0, 0, 0.52)})
	c.tocca(pS, t1, "sole", Vector3(0, -0.25, 0), {"rel": Vector3(S * 0.05, 0, 0.52)})
	c.tocca(pS, 0.66 * tk, "sole", Vector3(0, -0.2, 0), {"rel": Vector3(S * 0.05, 0, 0.38), "lega": true})
	c.tocca(pS, tk, "toe", Vector3(0, -0.45, 0), {"rel": Vector3(S * 0.03, 0, 0.42), "h": 0.03})
	c.passa(pS, tk + 0.1, Vector3(S * 0.1, 0.55, 0.5), Vector3(0, -0.5, 0), 0.0)
	c.chiave_bacino(0.66 * tk, Vector3(0, 0.9, -0.06))
	c.chiave_busto(0.66 * tk, Vector3(0.1, 0, 0))
	c.chiave_bacino(tk + 0.05, Vector3(0, 0.95, -0.04))
	c.chiave_angoli(tk + 0.05, Vector3(0, -0.1, 0))
	c.chiave_busto(tk + 0.05, Vector3(-0.14, 0, 0))
	K.braccia(c, 0.66 * tk, pS, K.BR_RIPOSO, K.BR_RIPOSO)
	K.braccia(c, tk + 0.05, pS, Vector3(0.38, -0.04, 0.0), Vector3(0.37, -0.06, -0.1))


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	# il pallone è partito (ball.finto del motore): via di corsa intorno al difensore, a riprenderlo
	K.via(c, S, tg, pS, "", Vector3.ZERO, 0.0, {"volo": true, "fine": 0.42})
