# Giochetto del dribbling "Veronica" (id `veronica`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# veronica (roulette), in corsa: la suola del primo piede (lato scelto) ferma il pallone e lo tira indietro mentre il
# corpo, che continua ad avanzare, gli gira sopra dando la schiena al difensore; l'altra suola lo riprende e lo porta
# avanti finendo il giro intero (parte B), oltre il difensore dal lato scelto. Giro continuo, sempre nello stesso verso.
const VER_GIRO_A := 2.5        # rad di giro alla fine della parte A (schiena al difensore e oltre)
const VER_B := 0.44            # s: il resto del giro dopo lo scatto

static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	c.yaw_k = 40.0
	c.yaw_v = 26.0
	var t0 := K.libera(c, pS)
	var t1 := maxf(t0 + 0.08, 0.26 * g)
	c.palla_a(0.06, {"rel0": Vector3(0, 0, 0.52)})
	# suola sul pallone: il pallone rallenta, il corpo gli passa accanto girando
	c.tocca(pS, t1, "sole", Vector3(0, -0.25, 0), {"rel0": Vector3(S * 0.06, 0, 0.46)})
	c.tocca(pS, g + 0.02, "sole", Vector3(0, -0.2, 0), {"rel0": Vector3(S * 0.12, 0, 0.1), "lega": true})
	c.chiave_giro(t1 - 0.02, 0.0)
	c.chiave_giro(t1 + 0.5 * (g - t1), -S * VER_GIRO_A * 0.45)
	c.chiave_giro(g, -S * VER_GIRO_A)
	# il piede che regge fa perno: due saltelli che lo rimettono sotto il corpo che gira
	var th := t1 + 0.38 * (g - t1)
	c.stacca(pF, th)
	c.appoggia_corsa(pF, th + 0.09, 0.1, Vector2(0.0, -0.02), 0.03)
	c.chiave_bacino(t1, Vector3(0, 0.89, -0.03))
	c.chiave_angoli(t1, Vector3(0, 0.04, 0))
	c.chiave_busto(t1, Vector3(0.12, 0, 0))
	c.chiave_bacino(g, Vector3(0, 0.88, 0.0))
	c.chiave_angoli(g, Vector3(0, 0.06, -S * 0.08))
	c.chiave_busto(g, Vector3(0.16, 0, -S * 0.3))
	# braccia larghe per girare (quella del lato del giro guida)
	K.braccia(c, t1, pS, Vector3(0.36, -0.2, 0.1), Vector3(0.36, -0.22, 0.0))
	K.braccia(c, g, pS, Vector3(0.4, -0.06, -0.1), Vector3(0.4, -0.08, 0.16))
	c.chiave_sguardo(g, 0.7, -S * 0.3)


static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	var pF := K.ls(-S)
	# quanto manca per finire il giro (sempre nello stesso verso, −S) fino al verso di corsa del motore
	var manca := fposmod(S * (c.yaw - c.yaw_motore()), TAU)
	if manca < 1.6:
		manca += TAU
	var dur := VER_B
	c.taglia(tg)
	c.yaw_fisso_fino = tg
	c.chiave_giro(tg, S * manca)
	c.chiave_giro(tg + dur * 0.5, S * manca * 0.5)
	c.chiave_giro(tg + dur, 0.0)
	c.chiave_sguardo(tg, 1.0)
	# il primo piede lascia il pallone e appoggia; l'altra suola lo prende (schiena al difensore) e lo porta avanti
	c.appoggia_corsa(pS, tg + 0.07, 0.1, Vector2.ZERO, 0.04)
	c.stacca(pF, tg + 0.02)
	c.tocca(pF, tg + 0.12, "sole", Vector3(0, -0.2, 0), {"rel0": Vector3(S * 0.14, 0, 0.12)})
	c.tocca(pF, tg + 0.3, "sole", Vector3(0, -0.2, 0), {"rel0": Vector3(S * 0.16, 0, 0.5), "lega": true})
	c.palla_a(tg + 0.52, {"moto": true})
	c.appoggia_corsa(pF, tg + 0.38, K.PASSO_CORSA, Vector2.ZERO, 0.05)
	c.stacca(pS, tg + 0.3)
	c.appoggia_corsa(pS, tg + 0.46, K.PASSO_CORSA, Vector2.ZERO, 0.1)
	c.stacca(pF, tg + 0.45)
	c.appoggia_corsa(pF, tg + 0.55, K.PASSO_CORSA, Vector2.ZERO, 0.1)
	c.chiave_bacino(tg + 0.15, Vector3(0, 0.89, 0.0))
	c.chiave_angoli(tg + 0.15, Vector3(0, 0.06, -S * 0.06))
	c.chiave_busto(tg + 0.15, Vector3(0.14, 0, -S * 0.25))
	c.chiave_bacino(tg + dur, Vector3(0, 0.9, 0.02))
	c.chiave_angoli(tg + dur, Vector3(0, 0.18, 0))
	c.chiave_busto(tg + dur, Vector3(0.18, 0, 0))
	K.braccia(c, tg + 0.15, pS, Vector3(0.4, -0.06, 0.1), Vector3(0.4, -0.06, -0.06))
	K.braccia(c, tg + dur, pS, K.BR_DIETRO, K.BR_AVANTI)
	c.fine = tg + 0.56
