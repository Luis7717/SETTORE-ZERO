# Giochetto del dribbling "Colpo di tacco" (id `tacco`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# colpo di tacco. Luis 2026-11-27: "il contatto di tacco non si vede da dietro": prima il pallone restava sotto il
# corpo (16 cm avanti → 12 cm dietro) e da dietro lo coprivano le gambe. Ora il gesto è largo e fuori dal corpo:
#   1) in corsa il pallone scivola dal lato della finta, davanti al piede di quel lato (il lato della telecamera);
#   2) quel piede lo scavalca col ginocchio alto, scende DAVANTI al pallone e il tacco lo colpisce all'indietro e di
#      traverso: il pallone esce da dietro il corpo, dal lato scelto, dietro la gamba d'appoggio (si vede bene da dietro);
#   3) allo scatto il piede del lato scelto, rimasto dietro, lo calcia avanti col collo: salta fuori con un piccolo arco.
const T_TACCO := 0.6       # il colpo di tacco a questa frazione del giochetto (poi il pallone si vede andare dietro)
const X_TACCO := 0.15      # m del modello: pallone al colpo di tacco, tanto dal lato della finta ...
const Z_TACCO := 0.24      # ... e tanto avanti
const DIETRO := Vector3(0.26, 0, -0.3)   # dove arriva dietro il corpo (x × lato scelto)


static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var th := T_TACCO * g
	K.rincorsa(c, pF, th - 0.1)
	c.palla_a(0.06, {"rel": Vector3(F * 0.05, 0, 0.48)})
	# ginocchio alto sopra il pallone, poi il piede scende davanti al pallone e il tacco lo colpisce all'indietro
	c.passa_palla(pF, th - 0.1, Vector3(F * 0.03, 0.52, 0.04), Vector3(0, 0.5, 0), 0.0)
	c.tocca(pF, th, "heel", Vector3(-S * 0.3, -0.3, 0), {"rel": Vector3(F * X_TACCO, 0, Z_TACCO)})
	c.palla_a(g + 0.04, {"rel": Vector3(S * DIETRO.x, 0, DIETRO.z)})
	c.appoggia_corsa(pF, th + 0.09, 0.1, Vector2(F * 0.06, 0.06), 0.03)
	c.chiave_bacino(th - 0.1, Vector3(S * 0.02, 0.95, -0.02))
	c.chiave_angoli(th - 0.1, Vector3(0, -0.04, 0))
	c.chiave_busto(th - 0.1, Vector3(0.0, 0, 0))
	c.chiave_bacino(th, Vector3(S * 0.03, 0.93, 0.02))
	c.chiave_busto(th, Vector3(0.1, 0, S * 0.14))
	# dopo il tacco la testa e le spalle si girano a guardare il pallone dietro, dal lato scelto
	c.chiave_bacino(g, Vector3(0, 0.89, 0.02))
	c.chiave_busto(g, Vector3(0.14, S * 0.08, S * 0.3))
	K.braccia(c, th - 0.1, pS, K.BR_LARGO, K.BR_ALTO)
	K.braccia(c, th, pS, K.BR_LARGO, K.BR_LARGO)
	K.braccia(c, g, pS, K.BR_DIETRO, K.BR_LARGO)
	c.chiave_sguardo(0.5 * g, 0.9, 0.0)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	# (il pallone, colpito da dietro, salta in avanti con un arco: si vede uscire da dietro il corpo)
	K.via(c, S, tg, pS, "instep", Vector3(-S * 0.25, 0.6, 0), 0.05,
		{"palla": [[tg + 0.3, {"rel": Vector3(S * 0.22, 0, 0.8), "arco": 0.4}]]})
