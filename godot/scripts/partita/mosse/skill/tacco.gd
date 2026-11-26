# Giochetto del dribbling "Colpo di tacco" (id `tacco`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


const Finta := preload("finta.gd")


# colpo di tacco (tacco contro tacco): in corsa il corpo passa sopra il pallone, che rallenta; il piede della finta lo
# scavalca col ginocchio alto e col tacco lo manda indietro, verso il piede rimasto dietro, che allo scatto lo calcia
# in avanti dal lato scelto
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var th := 0.8 * g
	Finta.rincorsa(c, pF, th - 0.1)
	# ginocchio alto sopra il pallone, poi il piede scende davanti al pallone e il tacco lo colpisce all'indietro
	c.passa_palla(pF, th - 0.1, Vector3(F * 0.03, 0.5, 0.06), Vector3(0, 0.5, 0), 0.0)
	c.tocca(pF, th, "heel", Vector3(-S * 0.1, -0.3, 0), {"rel": Vector3(F * 0.02, 0, 0.16)})
	c.palla_a(g + 0.07, {"rel": Vector3(S * 0.12, 0, -0.12)})
	c.appoggia_corsa(pF, th + 0.08, 0.1, Vector2(F * 0.04, 0.04), 0.03)
	c.chiave_bacino(th - 0.1, Vector3(0, 0.95, -0.02))
	c.chiave_angoli(th - 0.1, Vector3(0, -0.04, 0))
	c.chiave_busto(th - 0.1, Vector3(0.0, 0, 0))
	c.chiave_bacino(th, Vector3(0, 0.93, 0.02))
	c.chiave_busto(th, Vector3(0.1, 0, S * 0.1))
	K.braccia(c, th - 0.1, pS, K.BR_LARGO, K.BR_ALTO)
	K.braccia(c, th, pS, K.BR_LARGO, K.BR_LARGO)
	c.chiave_sguardo(0.5 * g, 0.9, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	# (il pallone, colpito da dietro, salta in avanti con un piccolo arco: si vede uscire da sotto il corpo)
	K.via(c, S, tg, pS, "instep", Vector3(-S * 0.25, 0.6, 0), 0.04,
		{"palla": [[tg + 0.26, {"rel": Vector3(S * 0.16, 0, 0.75), "arco": 0.3}]]})
