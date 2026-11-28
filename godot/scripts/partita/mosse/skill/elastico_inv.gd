# Giochetto del dribbling "Elastico inverso" (id `elastico_inv`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
# Il gesto morbido e continuo (curva del pallone, piede incollato) è quello di elastico.gd (El).
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")
const El := preload("elastico.gd")


# elastico inverso: l'interno del piede del lato scelto accompagna il pallone dentro, attraverso il corpo (gamba
# incrociata), il piede gli gira intorno e l'esterno lo riporta fuori dal lato scelto, in un gesto solo
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := 0.17 * g
	var ta := 0.7 * g
	var d := {"piede": pS, "nodi": [
		[t0, Vector3(S * 0.08, 0, 0.56)],
		[ta, Vector3(F * 0.3, 0, 0.5)],
		[g + El.FINE_CAMBIO, Vector3(S * 0.13, 0, 0.46)]]}
	c.dati["el"] = d
	El.saltelli(c, pF, [0.26 * g], g, S * 0.1)
	K.libera(c, pS)
	El.piano(c, d)
	# il corpo va col pallone verso la finta (bacino e spalle girati di là), poi torna
	c.chiave_bacino(t0, Vector3(0, 0.9, -0.03))
	c.chiave_bacino(ta, Vector3(F * 0.16, 0.85, 0.01))
	c.chiave_bacino(g, Vector3(F * 0.05, 0.87, 0.02))
	c.chiave_angoli(ta, Vector3(F * 0.38, 0.07, F * 0.06))
	c.chiave_angoli(g, Vector3(F * 0.06, 0.14, 0.0))
	c.chiave_busto(ta, Vector3(0.15, F * 0.18, F * 0.28))
	c.chiave_busto(g, Vector3(0.2, F * 0.04, 0.0))
	K.braccia(c, ta, pS, Vector3(0.32, -0.27, -0.06), Vector3(0.34, -0.16, 0.12))
	c.chiave_sguardo(ta, 0.6, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'esterno finisce di riportare il pallone fuori e via
static func b(c: Coreo, S: float, tg: float) -> void:
	El.esci(c, S, tg)
