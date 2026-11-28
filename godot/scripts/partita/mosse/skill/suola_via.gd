# Giochetto del dribbling "Suola indietro e via" (id `suola_via`): parte A (la finta, dura `g` = show di sim/skill.gd)
# e parte B (dallo scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# Il gesto vero: in corsa la suola si posa sul pallone davanti e lo tira indietro sotto il corpo (il piede che regge fa
# un saltello) e in fuori dal lato scelto (una L), il corpo si apre da quella parte e lo stesso piede lo spinge via.
# Il motore intanto rallenta il corpo ma lo fa sempre avanzare (vel bassa, av 1): il pallone, tirato indietro, a
# schermo torna davvero indietro sul prato mentre il corpo gli arriva sopra.
const T_SUOLA := 0.22          # (frazione di g) la suola del piede del lato scelto si posa sul pallone
const T_SOTTO := 0.84          # ... e l'ha tirato sotto il corpo
const Z_DAVANTI := 0.62        # m del modello: pallone davanti al corpo quando la suola lo prende
const Z_SOTTO := 0.0           # ... e quando lo lascia, accanto al corpo dal lato scelto
const X_SOTTO := 0.32          # ... di tanto di lato (la tirata fa una L: indietro e in fuori)
const GIRO := 0.8              # rad: il corpo si apre di tanto verso il lato scelto
const T_SALTO := 0.5          # saltello del piede che regge (frazione di g)


static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t1 := T_SUOLA * g
	var t2 := T_SOTTO * g
	c.yaw_k = 20.0
	c.yaw_v = 11.0
	K.rincorsa(c, pS, t1)
	# pallone: la suola lo ferma davanti e lo tira indietro fin sotto l'anca; lì resta fermo sul prato
	c.tocca(pS, t1, "sole", Vector3(0, -0.3, 0), {"rel0": Vector3(S * 0.08, 0, Z_DAVANTI)})
	c.tocca(pS, t2, "sole", Vector3(S * 0.7, -0.12, 0), {"rel0": Vector3(S * X_SOTTO, 0, Z_SOTTO), "lega": true})
	c.palla_a(g + 0.02, {"resta": true})
	# la gamba della suola, lasciato il pallone, si raccoglie dietro di lui: da lì lo spinge
	c.passa_palla(pS, 0.97 * g, Vector3(S * 0.02, 0.2, -0.24), Vector3(S * 0.2, 0.3, 0), 0.02)
	# piede che regge: saltello indietro mentre la suola tira
	c.stacca(pF, T_SALTO * g)
	c.appoggia_corsa(pF, T_SALTO * g + 0.08, 0.16, Vector2(F * 0.06, -0.08), 0.04)
	# corpo: frena (bacino indietro, busto dritto), poi si abbassa e si apre verso il lato scelto
	c.chiave_giro(t1, 0.0)
	c.chiave_giro(t2, S * GIRO * 0.8)
	c.chiave_giro(g, S * GIRO)
	c.chiave_bacino(t1, Vector3(0, 0.9, -0.12))
	c.chiave_angoli(t1, Vector3(0, -0.1, 0))
	c.chiave_busto(t1, Vector3(-0.08, 0, 0))
	K.braccia(c, t1, pS, Vector3(0.3, -0.26, -0.2), Vector3(0.32, -0.2, 0.24))
	c.chiave_bacino(t2, Vector3(F * 0.04, 0.85, -0.04))
	c.chiave_angoli(t2, Vector3(S * 0.15, 0.04, F * 0.04))
	c.chiave_busto(t2, Vector3(0.14, F * 0.06, S * 0.12))
	K.braccia(c, t2, pS, Vector3(0.42, -0.16, -0.04), Vector3(0.34, -0.24, 0.12))
	c.chiave_bacino(g, Vector3(0, 0.86, 0.0))
	c.chiave_angoli(g, Vector3(S * 0.2, 0.14, S * 0.06))
	c.chiave_busto(g, Vector3(0.24, S * 0.08, S * 0.2))
	K.braccia(c, g, pS, Vector3(0.38, -0.2, -0.22), Vector3(0.4, -0.14, 0.2))
	c.chiave_sguardo(t1, 1.0)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'esterno dello stesso piede spinge il pallone di lato e via
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	var manca := wrapf(c.yaw - c.yaw_motore(), -PI, PI)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.3), 0.05, {"giro": true, "spinta": 1.2})
	c.chiave_giro(tg, manca)
	c.chiave_giro(tg + 0.2, 0.0)
