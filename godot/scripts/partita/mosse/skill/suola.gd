# Giochetto del dribbling "Suola" (id `suola`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# Rotolata laterale con la suola, in corsa (Luis: "malino", "si ferma sul posto prima di farla"). Il motore intanto
# porta il corpo di lato verso il lato scelto (lat negativo in sim/skill.gd) senza frenare: il portatore scivola di
# lato insieme al pallone, col petto sempre verso il difensore.
const T_SUOLA := 0.22          # (frazione di g) la suola si posa sul pallone, dalla parte della finta
const T_LASCIA := 0.84         # ... e lo lascia dal lato scelto, dopo averlo fatto rotolare davanti al corpo
const T_SALTO_1 := 0.36        # primo saltello di lato del piede che regge
const T_SALTO_2 := 0.66        # secondo saltello
const SALTO := 0.075           # s: quanto dura un saltello
const X_DA := 0.2              # m del modello: pallone dalla parte della finta quando la suola lo prende ...
const X_A := 0.4              # ... e dal lato scelto quando lo lascia
const Z_PALLA := 0.47          # pallone davanti al corpo durante la rotolata


# suola in corsa: l'altro piede regge, la suola del piede della finta si posa sul pallone e lo fa rotolare attraverso
# il corpo fino al lato scelto; intanto il piede che regge fa due saltelli dallo stesso lato (il corpo non si ferma:
# scivola di lato col pallone), braccia larghe e busto che pende dalla parte opposta per equilibrio; poi il pallone
# rotola via da solo, la gamba della suola scende incrociata davanti e l'esterno dell'altro piede lo porta avanti
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t1 := T_SUOLA * g
	var t2 := T_LASCIA * g
	var tm := 0.5 * (t1 + t2)
	K.rincorsa(c, pF, t1)
	# pallone: preso dalla parte della finta, rotola sotto la suola (piede attaccato) fino al lato scelto, poi da solo
	c.tocca(pF, t1, "sole", Vector3(F * 0.25, -0.24, 0), {"rel": Vector3(F * X_DA, 0, Z_PALLA + 0.03)})
	c.tocca(pF, tm, "sole", Vector3(0, -0.24, 0), {"rel": Vector3(S * 0.5 * (X_A - X_DA), 0, Z_PALLA), "lega": true})
	c.tocca(pF, t2, "sole", Vector3(S * 0.3, -0.2, 0), {"rel": Vector3(S * X_A, 0, Z_PALLA - 0.02), "lega": true})
	c.palla_a(g + 0.1, {"rel": Vector3(S * (X_A + 0.1), 0, Z_PALLA + 0.04)})
	# (la gamba della suola scende incrociata davanti un attimo prima dello scatto: da lì spinge)
	c.appoggia_corsa(pF, 0.98 * g, 0.12, Vector2(S * 0.1, 0.0), 0.05)
	# saltelli di lato del piede che regge
	for k: float in [T_SALTO_1, T_SALTO_2]:
		c.stacca(pS, k * g)
		c.appoggia_corsa(pS, k * g + SALTO, 0.14, Vector2(S * 0.12, -0.04), 0.04)
	# corpo: basso sul piede che regge, anche verso il lato scelto, busto che pende verso la finta, braccia larghe
	K.braccia(c, 0.5 * t1, pS, K.BR_AVANTI, K.BR_DIETRO)
	c.chiave_busto(0.5 * t1, Vector3(0.2, 0, 0))
	c.chiave_bacino(t1, Vector3(S * 0.03, 0.9, -0.05))
	c.chiave_angoli(t1, Vector3(F * 0.22, -0.02, 0))
	c.chiave_busto(t1, Vector3(0.06, F * 0.08, F * 0.16))
	K.braccia(c, t1, pS, Vector3(0.44, -0.16, 0.04), Vector3(0.4, -0.22, -0.08))
	c.chiave_bacino(tm, Vector3(S * 0.07, 0.885, -0.05))
	c.chiave_angoli(tm, Vector3(0, -0.02, S * 0.05))
	c.chiave_busto(tm, Vector3(0.05, F * 0.16, 0))
	K.braccia(c, tm, pS, Vector3(0.44, -0.14, -0.04), Vector3(0.42, -0.16, 0.08))
	c.chiave_bacino(t2, Vector3(S * 0.1, 0.89, -0.03))
	c.chiave_angoli(t2, Vector3(S * 0.25, 0.02, S * 0.06))
	c.chiave_busto(t2, Vector3(0.1, F * 0.06, S * 0.15))
	K.braccia(c, t2, pS, Vector3(0.42, -0.18, -0.14), Vector3(0.4, -0.1, 0.12))
	c.chiave_sguardo(t1, 1.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "inside", Vector3(S * 0.4, 0.1, 0), 0.06)
