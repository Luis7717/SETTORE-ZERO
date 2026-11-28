# Giochetto del dribbling "Trottola" (id `waka`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# trottola: un giro intero su se stesso VERSO il lato scelto, con due suole, in corsa e senza pause:
#   1. affondo: il piede del lato scelto (S) si pianta lungo oltre il pallone, corpo basso; la suola dell'altro piede
#      si posa sul pallone e lo frena: il pallone resta quasi fermo sul prato, il corpo gli passa accanto e gira
#      verso S (la schiena al difensore);
#   2. saltello: il primo piede lascia il pallone e appoggia oltre, il corpo basso continua a girare; la gamba del
#      lato scelto gira intorno raccolta;
#   3. di schiena, la suola del piede del lato scelto prende il pallone (rimasto dietro, dalla parte della finta,
#      coperto dal corpo) e lo trascina verso il lato scelto finendo il giro; allo scatto (parte B) lo lascia davanti,
#      dal lato scelto, e appoggia: è la prima falcata della corsa.
# La meccanica del giro è quella della veronica (skill/veronica.gd: giro unico a velocità costante, chiavi del giro
# riscritte nel riferimento del motore allo scatto, piedi che appoggiano davvero) ma specchiata: qui si gira verso
# il lato da cui si esce, e il pallone attraversa da una parte all'altra sotto la seconda suola.
# Posizioni nel "riferimento della corsa": x sinistra, z nel verso della corsa (all'inizio in A, del motore in B).
const VER_W := 7.0             # rad/s: velocità del giro (un giro intero in 0,84 s; era 9 con show 0,5: troppo svelta da leggere)
const VER_A1 := 0.45           # rad: giro già fatto quando la prima suola tocca il pallone
const VER_T1 := 0.17           # s: prima suola sul pallone
const VER_AFFONDO := 0.06      # s prima della prima suola: il piede del lato scelto si pianta oltre il pallone
const VER_FRENA := 0.09        # s: la prima suola resta sul pallone (lo frena)
const VER_POSA := 0.14         # s dopo la prima suola: il primo piede appoggia oltre il pallone
const VER_ANTICIPO := 0.14     # s prima dello scatto: seconda suola sul pallone
const VER_TRASCINA := 0.06     # s dopo lo scatto: la seconda suola lascia il pallone davanti
const VER_PASSO := 0.17        # s tra due appoggi nella corsa dopo il giro (falcata vera, non passettini)
const VER_CONTATTO := 0.1      # s: quanto resta a terra il piede in quella corsa


# vettore v (x sinistra, z avanti) del riferimento col verso `rif` nel riferimento del corpo com'è girato a tt
static func _nel_corpo(c: Coreo, tt: float, v: Vector2, rif: float) -> Vector2:
	var w := Basis(Vector3.UP, rif - c.yaw_a(tt)) * Vector3(v.x, 0.0, v.y)
	return Vector2(w.x, w.z)


# giro rispetto al corpo (com'è girato a tt) di un piede che punta `punta` rad rispetto a rif
static func _punta(c: Coreo, tt: float, punta: float, rif: float) -> float:
	return wrapf(rif + punta - c.yaw_a(tt), -PI, PI)


# appoggio del piede s a tt nel punto v del riferimento `rif` (rispetto al corpo in quel momento), punta girata di
# `punta` rad rispetto a rif
static func _posa(c: Coreo, s: String, tt: float, v: Vector2, punta: float, rif: float, alto: float = 0.05) -> void:
	c.appoggia(s, tt, _nel_corpo(c, tt, v, rif), _punta(c, tt, punta, rif), alto)


# la gamba `piede`, staccata a ts, torna avanti da corsa: tallone verso il sedere, poi ginocchio avanti
static func _richiamo(c: Coreo, piede: String, ts: float) -> void:
	var x := K.segno(piede) * 0.1
	c.passa(piede, ts + 0.09, Vector3(x, 0.42, -0.22), Vector3(0, 0.9, 0), 0.0)
	c.passa(piede, ts + 0.17, Vector3(x, 0.3, 0.2), Vector3(0, 0.2, 0), 0.0)


# corsa dopo il giro: falcate vere (un appoggio ogni VER_PASSO), dal piede `piede` che atterra a tp fino a `fine`;
# braccia opposte alle gambe
static func _corsa(c: Coreo, piede: String, tp: float, fine: float) -> void:
	while tp < fine + 0.12:
		c.appoggia_corsa(piede, tp, VER_CONTATTO, Vector2(0.0, 0.02), 0.06)
		c.stacca(piede, tp + VER_CONTATTO)
		_richiamo(c, piede, tp + VER_CONTATTO)
		c.chiave_braccio(K.altro(piede), tp, K.BR_AVANTI)
		c.chiave_braccio(piede, tp, K.BR_DIETRO)
		piede = K.altro(piede)
		tp += VER_PASSO


static func a(c: Coreo, S: float, g: float) -> void:
	var V := -S                 # lato della finta: il corpo ci va girando la schiena al difensore
	var G := S                  # verso del giro (+ = verso sinistra): verso il lato scelto
	var p1 := K.ls(V)           # primo piede: la prima suola
	var p2 := K.ls(S)           # secondo: l'affondo oltre il pallone, poi la seconda suola
	var rif := c.yaw0
	c.yaw_k = 40.0
	c.yaw_v = 26.0
	# affondo: il piede del lato scelto si pianta lungo, oltre il pallone e di fianco; l'altro si stacca per la suola
	var t0 := VER_T1 - VER_AFFONDO
	K.rincorsa(c, p2, t0)
	c.appoggia(p2, t0, Vector2(S * 0.17, 0.4), G * 0.3, 0.1)
	c.stacca(p1, t0 + 0.01)
	c.chiave_bacino(t0, Vector3(0, 0.85, 0.0))
	c.chiave_angoli(t0, Vector3(0, 0.12, 0))
	var t1 := maxf(t0 + 0.04, VER_T1)
	var t2 := maxf(g - VER_ANTICIPO, t1 + 0.22)
	var tr := t1 + VER_FRENA
	var tl := t1 + VER_POSA
	# ---- giro: fermo fino a poco prima della suola, poi a velocità costante (chiavi anche oltre lo scatto previsto)
	var a2 := VER_A1 + VER_W * (t2 - t1)
	var tempi := [0.0, t1 - 0.07, t1, t2, t2 + 0.1, t2 + 0.3]
	var angoli := [0.0, 0.0, VER_A1, a2, a2 + VER_W * 0.1, a2 + VER_W * 0.3]
	for i in tempi.size():
		c.chiave_giro(float(tempi[i]), G * float(angoli[i]))
	c.dati["ver_t"] = tempi
	var ang := func(tt: float) -> float: return VER_A1 + VER_W * (tt - t1)
	# ---- pallone: la prima suola lo frena (resta quasi fermo sul prato, il corpo gli passa accanto: finisce dietro,
	# dalla parte del lato scelto, coperto dal corpo), la seconda lo riprende e lo trascina avanti
	c.palla_a(0.05, {"rel0": Vector3(0, 0, 0.52)})
	c.tocca(p1, t1, "sole", Vector3(_punta(c, t1, 0.0, rif), -0.2, 0), {"rel0": Vector3(0, 0, 0.5)})
	c.tocca(p1, tr, "sole", Vector3(_punta(c, tr, G * 0.55, rif), -0.15, 0),
		{"rel0": Vector3(V * 0.06, 0, 0.32), "lega": true, "frena": true})
	var dt := t2 - tr
	c.tocca(p2, t2, "sole", Vector3(G * 0.2, -0.2, 0), {"rel0": Vector3(V * (0.14 + 0.6 * dt), 0, 0.32 - 2.5 * dt)})
	c.tocca(p2, t2 + 0.2, "sole", Vector3(G * 0.45, -0.12, 0), {"rel0": Vector3(S * 0.14, 0, 0.42), "lega": true})
	# ---- primo piede: dopo la suola appoggia oltre il pallone, già girato; poi un saltello di perno
	_posa(c, p1, tl, Vector2(-V * 0.12, 0.22), G * (float(ang.call(tl)) + 0.5), rif, 0.06)
	# (a metà del giro un altro saltello di perno: il corpo intanto corre, il piede non resta indietro)
	var th := tl + 0.5 * (t2 - tl)
	if t2 - tl > 0.2:
		c.stacca(p1, th - 0.035)
		_posa(c, p1, th, Vector2(-V * 0.08, 0.14), G * (float(ang.call(th)) + 0.55), rif, 0.03)
	var tp := t2 + 0.02
	c.stacca(p1, tp - 0.035)
	_posa(c, p1, tp, Vector2(-V * 0.05, 0.2), G * (float(ang.call(tp)) + 0.6), rif, 0.025)
	# ---- l'altro piede: regge durante la suola, spinge (saltello) e gira intorno raccolto fino al pallone
	c.stacca(p2, t1 + 0.07)
	var tm := t1 + 0.07 + 0.5 * (t2 - t1 - 0.07)
	c.passa(p2, tm, Vector3(-V * 0.2, 0.36, -0.22), Vector3(0, 0.6, 0), 0.0)
	# ---- corpo: basso sulle ginocchia, busto sopra il pallone, spalle che guidano il giro
	c.chiave_bacino(t1, Vector3(0, 0.87, -0.02))
	c.chiave_angoli(t1, Vector3(0, 0.14, 0))
	c.chiave_busto(t1, Vector3(0.24, 0, G * 0.2))
	c.chiave_bacino(tl, Vector3(0, 0.81, 0.0))
	c.chiave_angoli(tl, Vector3(0, 0.2, 0))
	c.chiave_busto(tl, Vector3(0.4, 0, G * 0.3))
	c.chiave_bacino(t2, Vector3(0, 0.82, 0.0))
	c.chiave_angoli(t2, Vector3(0, 0.18, 0))
	c.chiave_busto(t2, Vector3(0.36, 0, G * 0.25))
	# braccia: quella del primo piede sale piegata davanti al petto (lancia il giro), l'altra larga dietro; poi larghe
	K.braccia(c, t1, p1, Vector3(0.1, -0.1, 0.28), Vector3(0.32, -0.24, -0.18))
	K.braccia(c, tl, p1, Vector3(0.24, -0.16, 0.2), Vector3(0.36, -0.18, -0.08))
	K.braccia(c, t2, p1, Vector3(0.32, -0.26, -0.04), Vector3(0.32, -0.22, 0.1))
	c.chiave_sguardo(t1, 1.0)


static func b(c: Coreo, S: float, tg: float) -> void:
	var V := -S
	var G := S
	var p1 := K.ls(V)
	var p2 := K.ls(S)
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
	var dur := clampf((tutto - fatto) / VER_W, 0.15, 0.5)
	var ang := func(tt: float) -> float: return minf(tutto, fatto + (tutto - fatto) * (tt - tg) / dur)
	c.chiave_giro(tg, G * fatto)
	c.chiave_giro(tg + dur * 0.5, G * float(ang.call(tg + dur * 0.5)))
	c.chiave_giro(tg + dur, G * tutto)
	c.chiave_giro(tg + dur + 0.1, G * tutto)
	c.chiave_sguardo(tg, 1.0)
	# ---- pallone: la seconda suola finisce di trascinarlo nel verso nuovo e lo lascia davanti; poi quello del motore
	var tt2 := tg + VER_TRASCINA
	var dove := Basis(Vector3.UP, rif - c.yaw0) * Vector3(S * 0.2, 0, 0.42)
	c.tocca(p2, tt2, "sole", Vector3(_punta(c, tt2, G * 0.3, rif), -0.1, 0), {"rel0": dove, "lega": true})
	c.palla_a(tt2 + 0.16, {"moto": true})
	# ---- piedi: il primo spinge e si stacca (il corpo adesso scatta); il secondo, lasciato il pallone, appoggia
	# avanti: prima falcata della corsa
	var t4 := tt2 + 0.07
	c.stacca(p1, tg + 0.04)
	_richiamo(c, p1, tg + 0.04)
	_posa(c, p2, t4, Vector2(-V * 0.1, 0.3), G * maxf(-0.7, float(ang.call(t4)) - TAU), rif, 0.04)
	c.stacca(p2, t4 + VER_CONTATTO)
	_richiamo(c, p2, t4 + VER_CONTATTO)
	var fine := t4 + 3.0 * VER_PASSO
	K.braccia(c, tt2, p1, Vector3(0.3, -0.28, -0.12), Vector3(0.3, -0.2, 0.14))
	c.chiave_braccio(p1, t4, K.BR_AVANTI)
	c.chiave_braccio(p2, t4, K.BR_DIETRO)
	_corsa(c, p1, t4 + VER_PASSO, fine)
	# ---- corpo: ancora basso mentre trascina, poi su, piegato in avanti di corsa
	c.chiave_bacino(tt2, Vector3(0, 0.84, 0.0))
	c.chiave_angoli(tt2, Vector3(0, 0.2, 0))
	c.chiave_busto(tt2, Vector3(0.32, 0, G * 0.15))
	c.chiave_bacino(t4 + 0.12, Vector3(0, 0.88, 0.02))
	c.chiave_angoli(t4 + 0.12, Vector3(0, 0.24, 0))
	c.chiave_busto(t4 + 0.12, Vector3(0.26, 0, 0))
	c.chiave_bacino(fine, Vector3(0, 0.91, -0.02))
	c.chiave_angoli(fine, Vector3(0, 0.16, 0))
	c.chiave_busto(fine, Vector3(0.18, 0, 0))
	c.fine = fine
