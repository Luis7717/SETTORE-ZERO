# Giochetto del dribbling "Bicicletta" (id `bicicletta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# bicicletta (per Luis: il pallone portato su dietro il polpaccio e alzato col tacco sopra la testa propria e del
# difensore): in corsa il piede del lato scelto si pianta oltre il pallone, che resta fermo sul prato dietro il suo
# tallone mentre il corpo avanza; il collo dell'altro piede lo fa rotolare su per il polpaccio; saltello, e il tacco
# della gamba davanti lo lancia da dietro sopra la testa (da lì è il pallone staccato del motore: gravità vera)
static func a(c: Coreo, S: float, g: float) -> void:
	var pS := K.ls(S)
	var pF := K.ls(-S)
	var tk := float(K.Skill.trova("bicicletta").tk)
	var t0 := K.libera(c, pS)
	var tp := maxf(t0 + 0.1, 0.3 * tk)
	c.palla_a(0.06, {"rel": Vector3(S * 0.02, 0, 0.5)})
	c.palla_a(tp, {"rel": Vector3(S * 0.02, 0, 0.36)})
	# un piede avanti oltre il pallone: da qui il pallone è fermo sul prato, dietro quel tallone
	c.appoggia_palla(pS, tp, Vector3(S * 0.05, K.H, 0.2), 0.0, 0.07)
	c.stacca(pF, tp - 0.02)
	c.tocca(pF, 0.5 * tk, "instep", Vector3(0, 0.3, 0), {"resta": true})
	c.tocca(pF, 0.84 * tk, "instep", Vector3(0, -0.15, 0), {"resta": true, "h": 0.4, "lega": true})
	# saltello: la gamba davanti si piega indietro e il tacco colpisce il pallone da sotto
	c.stacca(pS, 0.8 * tk)
	c.tocca(pS, tk, "heel", Vector3(0, 1.15, 0), {"resta": true, "h": 0.58})
	c.passa(pS, tk + 0.08, Vector3(S * 0.1, 0.66, -0.3), Vector3(0, 1.45, 0), 0.0)
	c.appoggia_corsa(pF, 0.84 * tk + 0.09, 0.12, Vector2.ZERO, 0.03)
	c.chiave_bacino(0.5 * tk, Vector3(0, 0.87, 0.04))
	c.chiave_angoli(0.5 * tk, Vector3(0, 0.14, 0))
	c.chiave_busto(0.5 * tk, Vector3(0.24, 0, 0))
	c.chiave_bacino(tk, Vector3(0, 1.0, 0.1))
	c.chiave_angoli(tk, Vector3(0, 0.28, 0))
	c.chiave_busto(tk, Vector3(0.42, 0, 0))
	K.braccia(c, 0.5 * tk, pS, K.BR_LARGO, K.BR_LARGO)
	K.braccia(c, tk, pS, Vector3(0.3, -0.28, -0.24), Vector3(0.32, -0.24, -0.22))
	c.chiave_sguardo(0.5 * tk, 1.0, 0.0)
	c.chiave_sguardo(tk, 0.3, 0.0)
	c.chiave_sguardo(tk + 0.2, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	# il pallone è partito (ball.finto del motore): via di corsa intorno al difensore, a riprenderlo
	K.via(c, S, tg, pS, "", Vector3.ZERO, 0.0, {"volo": true, "fine": 0.42})
