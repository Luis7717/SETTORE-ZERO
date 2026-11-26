# Giochetto del dribbling "Tunnel" (id `tunnel`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# tunnel: in corsa, mezza finta di corpo per far allargare le gambe al difensore, poi la punta manda il pallone
# dritto tra le sue gambe (da lì è il pallone staccato del motore: dritto, rallenta per l'attrito) e il portatore gli
# gira intorno e lo va a riprendere
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pF)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	var tp := maxf(t0 + 0.1, 0.5 * g)
	c.appoggia_corsa(pF, tp, 0.16, Vector2(F * 0.1, 0.0), 0.07)
	c.stacca(pS, tp + 0.02)
	# la punta del piede del lato scelto colpisce il pallone (quello del motore, ai suoi piedi) verso il difensore
	c.tocca(pS, g, "toe", Vector3(-S * 0.25, 0.3, 0), {"moto": true}, 0.05)
	c.passa(pS, g + 0.1, Vector3(S * 0.08, 0.2, 0.5), Vector3(0, 0.1, 0), 0.0)
	c.chiave_bacino(0.6 * g, Vector3(F * 0.1, 0.87, 0.0))
	c.chiave_angoli(0.6 * g, Vector3(F * 0.25, 0.06, F * 0.06))
	c.chiave_busto(0.6 * g, Vector3(0.14, F * 0.18, F * 0.22))
	c.chiave_bacino(g, Vector3(F * 0.08, 0.88, 0.04))
	c.chiave_busto(g, Vector3(0.2, 0, 0))
	K.braccia(c, 0.6 * g, pS, Vector3(0.12, -0.26, 0.28), Vector3(0.37, -0.14, 0.0))
	K.braccia(c, g, pS, K.BR_DIETRO, K.BR_LARGO)
	c.chiave_sguardo(0.5 * g, 0.2, F * 0.5)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	# il pallone è partito (ball.finto del motore): via di corsa intorno al difensore, a riprenderlo
	K.via(c, S, tg, pS, "", Vector3.ZERO, 0.0, {"volo": true, "fine": 0.42})
