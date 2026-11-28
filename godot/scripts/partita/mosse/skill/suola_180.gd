# Giochetto del dribbling "Suola e giro" (id `suola_180`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B
# (dallo scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# Il gesto vero: il portatore porta via il pallone di lato con la suola (verso la finta: il motore lo fa correre da
# quella parte, lat positivo), poi la stessa suola lo ferma, lo tira indietro nel verso opposto e il corpo si gira di
# netto: riparte dall'altra parte (il lato scelto). Inversione della corsa di quasi 180 gradi.
const GIRO_FINTA := 1.3       # rad: il corpo si gira verso la finta mentre corre di lato
const GIRO_FINE := 0.5         # rad: ... e allo scatto è già girato di tanto verso il lato scelto
const T_SUOLA := 0.16          # (frazione di g) la suola del piede del lato scelto si posa sul pallone
const T_FERMA := 0.5           # ... l'ha fatto rotolare verso la finta e lo ferma
const T_TIENE := 0.6           # ... lo tiene fermo sul prato (il corpo gli arriva sopra)
const T_DIETRO := 0.9          # ... e l'ha tirato indietro, dal lato scelto
const X_FINTA := 0.5           # m del modello: pallone dalla parte della finta alla fine della rotolata
const X_DIETRO := 0.3          # ... e dal lato scelto dopo la tirata (riferimento dell'inizio)


static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t1 := T_SUOLA * g
	var t2 := T_FERMA * g
	var t3 := T_TIENE * g
	var t4 := T_DIETRO * g
	c.yaw_k = 22.0
	c.yaw_v = 13.0
	K.rincorsa(c, pS, t1)
	# pallone (riferimento dell'inizio, non gira col corpo): rotola sotto la suola verso la finta, si ferma, torna indietro
	c.tocca(pS, t1, "sole", Vector3(F * 0.3, -0.24, 0), {"rel0": Vector3(F * 0.1, 0, 0.5)})
	c.tocca(pS, t2, "sole", Vector3(F * 0.3, -0.26, 0), {"rel0": Vector3(F * X_FINTA, 0, 0.42), "lega": true})
	c.tocca(pS, t3, "sole", Vector3(0, -0.26, 0), {"resta": true, "lega": true})
	c.tocca(pS, t4, "sole", Vector3(S * 0.5, -0.14, 0), {"rel0": Vector3(S * X_DIETRO, 0, 0.3), "lega": true})
	c.palla_a(g + 0.03, {"resta": true})
	# la gamba della suola scende dal lato scelto, già girata: primo appoggio nel verso nuovo
	c.appoggia_corsa(pS, g + 0.01, 0.1, Vector2(S * 0.3, -0.06), 0.05)
	# piede che regge: un passo di lato verso la finta durante la rotolata, poi frena piantato oltre il pallone
	c.stacca(pF, 0.27 * g)
	c.appoggia_corsa(pF, 0.27 * g + 0.08, 0.16, Vector2(F * 0.1, -0.04), 0.05)
	c.stacca(pF, 0.56 * g)
	c.appoggia_corsa(pF, 0.56 * g + 0.08, 0.2, Vector2(F * 0.12, 0.0), 0.04)
	# giro: verso la finta mentre rotola, poi di netto verso il lato scelto mentre la suola tira indietro
	c.chiave_giro(0.3 * g, F * GIRO_FINTA * 0.8)
	c.chiave_giro(t2, F * GIRO_FINTA)
	c.chiave_giro(t3, F * GIRO_FINTA * 0.9)
	c.chiave_giro(g, S * GIRO_FINE)
	# corpo: di corsa di lato; alla frenata basso e indietro, braccia larghe; poi dentro la curva nuova
	c.chiave_bacino(t1, Vector3(0, 0.9, -0.03))
	c.chiave_angoli(t1, Vector3(0, 0.06, 0))
	c.chiave_busto(t1, Vector3(0.14, 0, 0))
	K.braccia(c, t1, pS, Vector3(0.36, -0.24, 0.1), Vector3(0.3, -0.3, -0.12))
	c.chiave_bacino(t3, Vector3(0, 0.86, -0.08))
	c.chiave_angoli(t3, Vector3(0, -0.1, 0))
	c.chiave_busto(t3, Vector3(0.0, 0, S * 0.1))
	K.braccia(c, t3, pS, Vector3(0.48, -0.08, -0.08), Vector3(0.46, -0.06, 0.12))
	c.chiave_bacino(g, Vector3(S * 0.04, 0.86, 0.0))
	c.chiave_angoli(g, Vector3(S * 0.25, 0.14, S * 0.08))
	c.chiave_busto(g, Vector3(0.24, S * 0.1, S * 0.3))
	K.braccia(c, g, pS, Vector3(0.4, -0.18, -0.24), Vector3(0.42, -0.1, 0.2))
	c.chiave_sguardo(t1, 1.0)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'interno dell'altro piede porta via il pallone nel verso nuovo
static func b(c: Coreo, S: float, tg: float) -> void:
	var pF := K.ls(-S)
	var manca := wrapf(c.yaw - c.yaw_motore(), -PI, PI)
	K.via(c, S, tg, pF, "inside", K.interno(S, 0.4), 0.06, {"giro": true, "spinta": 1.2})
	c.chiave_giro(tg, manca)
	c.chiave_giro(tg + 0.2, 0.0)
