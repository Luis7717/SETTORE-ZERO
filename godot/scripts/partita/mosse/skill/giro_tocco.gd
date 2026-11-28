# Giochetto del dribbling "Giro e tocco" (id `giro_tocco`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# giro e tocco (il giro con la suola di chi protegge palla girando su sé stesso; riferimento: primo piano del video di
# Luis a 8:18), diverso dalla veronica: UNA suola sola, che non lascia mai il pallone.
#   1. la suola del piede del lato scelto (pS) si posa sul pallone davanti al corpo;
#   2. il corpo gira sull'altro piede (perno: saltelli corti sul posto, verso -S) e la suola TRASCINA il pallone in
#      cerchio intorno al perno: il pallone resta sempre davanti al corpo che gira (di lato, poi dietro: a metà giro
#      il corpo dà la schiena al difensore e il pallone sta dalla parte opposta), braccia larghe, busto sopra il pallone;
#   3. a tre quarti di giro (lo scatto del motore) la suola lascia il pallone, che esce dal cerchio verso la corsa
#      nuova; quel piede appoggia (primo passo) e l'altro piede, finito il giro, lo tocca avanti d'interno: via.
# Il giro è uno solo, a velocità costante (GT_W); come nella veronica le chiavi del giro della parte A vengono
# riscritte nel riferimento della parte B (verso del motore).
# Posizioni nel "riferimento della corsa": x sinistra, z nel verso della corsa (all'inizio in A, del motore in B).
const GT_W := 7.0              # rad/s: velocità del giro
const GT_A1 := 0.4             # rad: giro già fatto quando la suola tocca il pallone
const GT_T1 := 0.1             # s: suola sul pallone
const GT_PALLA := Vector3(0.1, 0, 0.42)   # pallone sotto la suola rispetto al corpo che gira (x dal lato del piede)
const GT_PERNO := 0.15         # s tra due saltelli del piede di perno
const GT_LASCIA := 0.03        # s dopo lo scatto: la suola lascia il pallone
const GT_TOCCO := 0.2          # s dopo lo scatto (almeno): tocco d'interno dell'altro piede
const GT_PASSO := 0.17         # s tra due appoggi nella corsa dopo il giro
const GT_CONTATTO := 0.1       # s: quanto resta a terra il piede in quella corsa


# la gamba `piede`, staccata a ts, torna avanti da corsa: tallone verso il sedere, poi ginocchio avanti
static func _richiamo(c: Coreo, piede: String, ts: float) -> void:
	var x := K.segno(piede) * 0.1
	c.passa(piede, ts + 0.09, Vector3(x, 0.42, -0.22), Vector3(0, 0.9, 0), 0.0)
	c.passa(piede, ts + 0.17, Vector3(x, 0.3, 0.2), Vector3(0, 0.2, 0), 0.0)


# corsa dopo il giro: falcate vere (un appoggio ogni GT_PASSO), dal piede `piede` che atterra a tp fino a `fine`;
# braccia opposte alle gambe
static func _corsa(c: Coreo, piede: String, tp: float, fine: float) -> void:
	while tp < fine + 0.12:
		c.appoggia_corsa(piede, tp, GT_CONTATTO, Vector2(0.0, 0.02), 0.06)
		c.stacca(piede, tp + GT_CONTATTO)
		_richiamo(c, piede, tp + GT_CONTATTO)
		c.chiave_braccio(K.altro(piede), tp, K.BR_AVANTI)
		c.chiave_braccio(piede, tp, K.BR_DIETRO)
		piede = K.altro(piede)
		tp += GT_PASSO


static func a(c: Coreo, S: float, g: float) -> void:
	var G := -S                 # verso del giro (+ = verso sinistra)
	var pS := K.ls(S)           # piede della suola
	var pF := K.ls(-S)          # piede di perno
	c.yaw_k = 40.0
	c.yaw_v = 26.0
	var t0 := K.libera(c, pS)
	var t1 := maxf(t0 + 0.04, GT_T1)
	# ---- giro: fermo fino a poco prima della suola, poi a velocità costante (chiavi anche oltre lo scatto previsto)
	var ag := GT_A1 + GT_W * (g - t1)
	var tempi := [0.0, t1 - 0.07, t1, g, g + 0.1, g + 0.3]
	var angoli := [0.0, 0.0, GT_A1, ag, ag + GT_W * 0.1, ag + GT_W * 0.3]
	for i in tempi.size():
		c.chiave_giro(float(tempi[i]), G * float(angoli[i]))
	c.dati["ver_t"] = tempi
	# ---- pallone: sotto la suola, davanti al corpo che gira (un cerchio intorno al perno)
	var rel := Vector3(S * GT_PALLA.x, 0, GT_PALLA.z)
	c.palla_a(0.05, {"rel0": Vector3(0, 0, 0.52)})
	c.tocca(pS, t1, "sole", Vector3(0, -0.2, 0), {"rel": Vector3(S * 0.1, 0, 0.5)})
	var tt := t1 + 0.07
	while tt < g + 0.25:
		c.tocca(pS, tt, "sole", Vector3(G * 0.25, -0.14, 0), {"rel": rel, "lega": true})
		tt += 0.07
	# ---- piede di perno: saltelli corti sul posto, sotto la sua anca, già un po' girato nel verso del giro
	var tp := t1 + 0.1
	while tp < g + 0.2:
		c.stacca(pF, tp - 0.06)
		c.appoggia(pF, tp, Vector2(-S * 0.11, -0.03), G * 0.4, 0.03)
		tp += GT_PERNO
	# ---- corpo: basso sul perno, busto sopra il pallone e dentro il giro
	c.chiave_bacino(t1, Vector3(0, 0.87, -0.03))
	c.chiave_angoli(t1, Vector3(0, 0.12, 0))
	c.chiave_busto(t1, Vector3(0.22, 0, G * 0.15))
	c.chiave_bacino(t1 + 0.15, Vector3(-S * 0.03, 0.83, -0.05))
	c.chiave_angoli(t1 + 0.15, Vector3(0, 0.16, G * 0.06))
	c.chiave_busto(t1 + 0.15, Vector3(0.34, G * 0.1, G * 0.28))
	c.chiave_bacino(g, Vector3(-S * 0.03, 0.83, -0.05))
	c.chiave_angoli(g, Vector3(0, 0.16, G * 0.06))
	c.chiave_busto(g, Vector3(0.34, G * 0.1, G * 0.28))
	# braccia larghe (equilibrio): quella del perno avanti nel verso del giro, l'altra larga dietro
	K.braccia(c, t1, pS, Vector3(0.3, -0.24, -0.1), Vector3(0.26, -0.2, 0.22))
	K.braccia(c, t1 + 0.2, pS, Vector3(0.38, -0.16, -0.12), Vector3(0.34, -0.12, 0.16))
	K.braccia(c, g, pS, Vector3(0.36, -0.2, -0.06), Vector3(0.34, -0.14, 0.12))
	c.chiave_sguardo(t1, 1.0)


static func b(c: Coreo, S: float, tg: float) -> void:
	var G := -S
	var pS := K.ls(S)
	var pF := K.ls(-S)
	var rif := c.yaw_motore()
	# ---- giro: le chiavi di prima passano dal verso fisso a quello del motore (stesso verso a schermo, stessa
	# velocità), poi si finisce il giro intero alla stessa velocità
	var off := wrapf(c.yaw_fisso - rif, -PI, PI) if not is_nan(c.yaw_fisso) else 0.0
	var prima: Object = c._curva("giro")
	var vecchie: Array = []
	for tt: float in c.dati.get("ver_t", []):
		if tt < tg - 1e-6:
			vecchie.append([tt, (prima.at(tt) as Vector3).x])
	var ora: float = (prima.at(tg) as Vector3).x
	c.taglia(tg)
	for k: Array in vecchie:
		c.chiave_giro(float(k[0]), float(k[1]) + off)
	c.yaw_fisso_fino = tg
	var fatto := G * (ora + off)           # giro già fatto (rad, positivo) rispetto al verso di corsa nuovo
	var tutto := TAU
	while tutto - fatto < 1.0:
		tutto += TAU
	var dur := clampf((tutto - fatto) / GT_W, 0.15, 0.5)
	var ang := func(tt: float) -> float: return minf(tutto, fatto + (tutto - fatto) * (tt - tg) / dur)
	c.chiave_giro(tg, G * fatto)
	c.chiave_giro(tg + dur * 0.5, G * float(ang.call(tg + dur * 0.5)))
	c.chiave_giro(tg + dur, G * tutto)
	c.chiave_giro(tg + dur + 0.1, G * tutto)
	c.chiave_sguardo(tg, 1.0)
	# ---- pallone: la suola lo lascia (esce dal cerchio verso la corsa nuova); finito il giro l'altro piede lo
	# tocca avanti d'interno; poi quello del motore
	var tl := tg + GT_LASCIA
	var tk := maxf(tg + GT_TOCCO, tg + dur - 0.02)
	c.tocca(pS, tl, "sole", Vector3(G * 0.25, -0.12, 0), {"rel": Vector3(S * GT_PALLA.x, 0, GT_PALLA.z), "lega": true})
	c.tocca(pF, tk, "inside", K.interno(S, 0.55), {"rel": Vector3(-S * 0.03, 0, 0.5)})
	c.palla_a(tk + 0.18, {"moto": true})
	# ---- piedi: la suola, lasciato il pallone, appoggia verso la corsa (primo passo); il perno si stacca, tocca il
	# pallone e appoggia avanti: poi falcate vere
	# (il corpo adesso scatta: nessun piede resta piantato più di un appoggio di corsa, sennò la gamba si stira)
	var t4 := tl + 0.06
	c.stacca(pF, tg + 0.05)
	c.appoggia_corsa(pS, t4, GT_CONTATTO, Vector2(0.0, 0.0), 0.04)
	c.stacca(pS, t4 + GT_CONTATTO)
	_richiamo(c, pS, t4 + GT_CONTATTO)
	var t5 := tk + 0.07
	c.appoggia_corsa(pF, t5, GT_CONTATTO, Vector2(0.0, 0.02), 0.06)
	c.stacca(pF, t5 + GT_CONTATTO)
	_richiamo(c, pF, t5 + GT_CONTATTO)
	var fine := t5 + 2.0 * GT_PASSO
	K.braccia(c, tl, pS, Vector3(0.34, -0.2, -0.08), Vector3(0.32, -0.16, 0.12))
	c.chiave_braccio(pF, tk, K.BR_DIETRO)
	c.chiave_braccio(pS, tk, K.BR_AVANTI)
	c.chiave_braccio(pS, t5, K.BR_AVANTI)
	c.chiave_braccio(pF, t5, K.BR_DIETRO)
	_corsa(c, pS, t5 + GT_PASSO, fine)
	# ---- corpo: ancora basso finché gira, poi su, piegato in avanti di corsa
	c.chiave_bacino(tl, Vector3(0, 0.84, -0.03))
	c.chiave_angoli(tl, Vector3(0, 0.18, 0))
	c.chiave_busto(tl, Vector3(0.32, 0, G * 0.18))
	c.chiave_bacino(tk, Vector3(0, 0.87, 0.0))
	c.chiave_angoli(tk, Vector3(0, 0.22, 0))
	c.chiave_busto(tk, Vector3(0.28, 0, 0))
	c.chiave_bacino(fine, Vector3(0, 0.91, -0.02))
	c.chiave_angoli(fine, Vector3(0, 0.16, 0))
	c.chiave_busto(fine, Vector3(0.18, 0, 0))
	c.fine = fine
