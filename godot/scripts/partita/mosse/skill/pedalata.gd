# Giochetto del dribbling "Pedalata" (id `pedalata`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# pedalata: di corsa, col pallone che rotola avanti, quattro giri veloci delle gambe sopra il pallone, uno per passo
# (larghi e alti: da lontano si vedono le gambe che girano), busto dritto e braccia che pompano; poi l'esterno e via
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pS)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.56)})
	c.palla_a(g + 0.05, {"rel": Vector3(0, 0, 0.56)})
	var n := 4
	var per := (g - 0.02 - t0) / float(n)
	for i in n:
		var s := pS if i % 2 == 0 else pF
		var dir := S if i % 2 == 0 else F
		var ta := t0 + per * i
		if i > 0:
			c.stacca(s, ta - 0.015)
		# il piede gira largo e alto intorno al davanti del pallone e atterra fuori, più avanti (il corpo corre)
		c.passa_palla(s, ta + 0.3 * per, Vector3(-dir * 0.12, 0.3, -0.08), Vector3(dir * 0.4, 0.3, 0), 0.03)
		c.passa_palla(s, ta + 0.62 * per, Vector3(dir * 0.1, 0.34, 0.26), Vector3(-dir * 0.3, 0.3, 0), 0.0)
		c.appoggia_palla(s, ta + per + 0.01, Vector3(dir * 0.36, K.H, 0.06), dir * 0.3, 0.02)
		var tm := ta + 0.7 * per
		c.chiave_bacino(tm, Vector3(dir * 0.07, 0.93, 0.02))
		c.chiave_angoli(tm, Vector3(dir * 0.3, 0.06, dir * 0.07))
		c.chiave_busto(tm, Vector3(0.08, dir * 0.1, dir * 0.26))
		K.braccia(c, tm, K.ls(dir), Vector3(0.38, -0.14, -0.16), Vector3(0.16, -0.16, 0.32))
	c.chiave_sguardo(g * 0.5, 0.6, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.85), 0.05)
