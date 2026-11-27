# Giochetto del dribbling "Colpetto e giro" (id `colpetto_giro`), PROVVISORIO: per ora è la copia di skill/cruyff.gd (da rifare sul gesto vero)
# Giochetto del dribbling "Colpetto e giro" (id `colpetto_giro`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# Il motore durante il giochetto porta il corpo di lato verso la finta a circa 3 m/s senza frenare, e allo scatto lo fa
# ripartire subito a 7 m/s quasi dritto: per questo l'aggancio e il trascinamento stanno PRIMA dello scatto (allo
# scatto il pallone sta già andando nel verso nuovo, non resta indietro) e l'appoggio dura poco (il corpo gli passa sopra).
const GIRO_FINTA := 1.5        # rad: il corpo si gira verso la finta (corre di lato, come per un cross)
# Tempi della parte A (frazioni di `g`)
const T_ESTERNO := 0.30        # tocco d'esterno: il pallone va di lato, piano, davanti alla corsa
const T_APPOGGIO := 0.69       # il piede d'appoggio si pianta oltre il pallone (gamba che calcia al punto più alto)
const T_AGGANCIO := 0.82       # il piede è sceso davanti al pallone e l'interno lo aggancia
const T_DIETRO := 0.93         # il pallone è dietro il tallone d'appoggio
const T_TIENE := 0.03          # s: la gamba resta caricata tanto dopo che il piede d'appoggio è atterrato
# Parte B (s dopo lo scatto)
const B_LASCIA := 0.03         # il piede lascia il pallone, che va nel verso nuovo
const B_PERNO_GIU := 0.10      # il piede d'appoggio, staccato allo scatto, riappoggia nel verso nuovo
const B_PASSO := 0.185         # il piede del trascinamento appoggia: secondo passo di corsa
const B_GIRO := 0.24           # il corpo ha finito di girarsi
const B_PALLA := 0.24          # il pallone è quello del motore
const B_FINE := 0.46


# finta e giro, in corsa: il portatore si sposta il pallone d'esterno verso la finta e ci corre dietro di lato, come
# per un cross o un passaggio da quella parte: ultimo passo lungo, gamba che calcia caricata alta dietro, braccia
# larghe, petto aperto e sguardo al bersaglio finto, piede d'appoggio piantato oltre il pallone. Il piede scende ma
# invece di calciare passa davanti al pallone con la punta girata in dentro, e l'interno lo trascina dietro il tallone
# d'appoggio, verso il lato scelto (parte B: il corpo si gira da quella parte e riparte)
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	c.yaw_k = 22.0
	c.yaw_v = 13.0
	var t0 := K.libera(c, pS)
	var te := maxf(t0 + 0.09, T_ESTERNO * g)
	var tp := maxf(te + 0.16, T_APPOGGIO * g)
	var th := maxf(tp + 0.06, T_AGGANCIO * g)
	var td := maxf(th + 0.05, T_DIETRO * g)
	c.chiave_giro(0.35 * tp, F * GIRO_FINTA * 0.75)
	c.chiave_giro(0.7 * tp, F * GIRO_FINTA)
	c.chiave_giro(td, F * GIRO_FINTA)
	c.chiave_giro(maxf(g, td + 0.02), F * GIRO_FINTA * 0.8)
	# passi: appoggio del lato scelto, tocco d'esterno con l'altro piede, che poi appoggia e spinge l'ultimo passo lungo
	K.passo(c, pS, t0 + 0.03, 0.1)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	c.tocca(pF, te, "outside", Vector3(F * 0.5, 0.25, 0), {"rel": Vector3(F * 0.1, 0, 0.5)})
	c.appoggia_corsa(pF, te + 0.07, 0.1, Vector2.ZERO, 0.05)
	c.stacca(pS, te + 0.06)
	# appoggio oltre il pallone, dalla parte del lato scelto: il pallone gli passerà dietro
	c.appoggia_palla(pS, tp, Vector3(S * 0.25, K.H, 0.13), S * 0.15, 0.12)
	# gamba che calcia: spinge, poi tallone alto dietro quando l'altro piede atterra ...
	c.stacca(pF, tp - 0.1)
	c.passa(pF, tp - 0.02, Vector3(F * 0.2, 0.6, -0.5), Vector3(0, 1.2, 0), 0.0)
	c.passa(pF, tp + T_TIENE, Vector3(F * 0.22, 0.66, -0.46), Vector3(0, 1.25, 0), 0.0)
	# ... scende sopra il pallone e gli passa davanti, punta girata in dentro ...
	c.passa_palla(pF, th - 0.015, Vector3(F * 0.04, 0.34, 0.16), Vector3(S * 0.7, 0.4, 0), 0.0)
	# ... l'interno lo aggancia dal davanti e lo trascina dietro il tallone d'appoggio (il corpo intanto gli passa sopra)
	c.tocca(pF, th, "inside", Vector3(S * 1.45, 0.1, 0), {"rel": Vector3(F * 0.05, 0, 0.1)})
	c.tocca(pF, td, "inside", Vector3(S * 1.75, 0.05, 0), {"rel": Vector3(S * 0.22, 0, -0.26), "lega": true})
	c.tocca(pF, td + 0.06, "inside", Vector3(S * 1.9, 0.05, 0), {"rel": Vector3(S * 0.5, 0, -0.42), "lega": true})
	# corsa di lato dietro al pallone
	c.chiave_bacino(te, Vector3(0, 0.9, 0.0))
	c.chiave_angoli(te, Vector3(0, 0.16, 0))
	c.chiave_busto(te, Vector3(0.18, 0, 0))
	K.braccia(c, te, pS, K.BR_DIETRO, K.BR_AVANTI)
	K.braccia(c, te + 0.08, pS, K.BR_AVANTI, K.BR_LARGO)
	# caricamento: bacino e petto aperti verso la gamba che calcia, busto dritto e un po' indietro, basso sull'appoggio
	c.chiave_bacino(tp, Vector3(S * 0.04, 0.84, 0.05))
	c.chiave_angoli(tp, Vector3(F * 0.45, -0.08, S * 0.08))
	c.chiave_busto(tp, Vector3(-0.2, S * 0.14, F * 0.4))
	# braccia da calcio: quello opposto alla gamba che calcia alto, largo e avanti, l'altro largo e indietro
	K.braccia(c, tp - 0.02, pS, Vector3(0.5, 0.1, 0.2), Vector3(0.42, -0.08, -0.34))
	K.braccia(c, tp + T_TIENE, pS, Vector3(0.5, 0.14, 0.16), Vector3(0.44, -0.04, -0.36))
	c.chiave_bacino(tp + T_TIENE, Vector3(S * 0.04, 0.84, 0.03))
	c.chiave_angoli(tp + T_TIENE, Vector3(F * 0.45, -0.08, S * 0.08))
	c.chiave_busto(tp + T_TIENE, Vector3(-0.2, S * 0.14, F * 0.4))
	# aggancio: il busto va sopra il pallone e comincia a girare dalla parte del lato scelto
	c.chiave_bacino(th, Vector3(S * 0.03, 0.84, 0.02))
	c.chiave_angoli(th, Vector3(S * 0.1, 0.1, 0))
	c.chiave_busto(th, Vector3(0.24, S * 0.08, S * 0.1))
	K.braccia(c, th, pS, Vector3(0.46, -0.1, -0.05), Vector3(0.44, -0.1, 0.1))
	c.chiave_bacino(g, Vector3(S * 0.05, 0.85, 0.0))
	c.chiave_angoli(g, Vector3(S * 0.35, 0.14, S * 0.1))
	c.chiave_busto(g, Vector3(0.28, S * 0.12, S * 0.4))
	K.braccia(c, g, pS, Vector3(0.42, -0.12, -0.24), Vector3(0.46, -0.06, 0.22))
	# sguardo: al bersaglio finto (davanti, dove va la corsa) fino al caricamento, poi giù sul pallone
	c.chiave_sguardo(te, 0.6, 0.0)
	c.chiave_sguardo(tp - 0.04, 0.0, 0.0)
	c.chiave_sguardo(tp + T_TIENE, 0.0, 0.0)
	c.chiave_sguardo(th, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto). Il piede lascia il pallone, che va nel verso nuovo; il piede
# d'appoggio si stacca e riappoggia già girato, il corpo si gira dalla parte del lato scelto e riparte di corsa
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	var pF := K.ls(-S)
	var lascia := c.pallone_previsto(tg + B_LASCIA)
	c.taglia(tg)
	c.yaw_fisso_fino = tg
	# il verso voluto ora è quello del motore: il giro riparte da dove guarda adesso il corpo e arriva lì girando
	# dalla parte del difensore (la via corta)
	var manca := wrapf(c.yaw - c.yaw_motore(), -PI, PI)
	c.chiave_giro(tg, manca)
	c.chiave_giro(tg + B_GIRO, 0.0)
	c.chiave_sguardo(tg + 0.05, 1.0)
	c.tocca(pF, tg + B_LASCIA, "inside", Vector3(S * 1.9, 0.05, 0), {"mondo": lascia, "lega": true})
	c.palla_a(tg + B_PALLA, {"moto": true})
	# di corsa nel verso nuovo: prima l'appoggio (che ha fatto perno), poi il piede del trascinamento, poi alternati
	c.stacca(pS, tg + 0.01)
	c.appoggia_corsa(pS, tg + B_PERNO_GIU, K.PASSO_CORSA, Vector2.ZERO, 0.05)
	c.appoggia_corsa(pF, tg + B_PASSO, K.PASSO_CORSA, Vector2.ZERO, 0.08)
	c.stacca(pS, tg + B_PASSO - 0.01)
	var s := pS
	var tp := tg + B_PASSO + K.PASSO_CORSA
	while tp < tg + B_FINE + 0.1:
		c.appoggia_corsa(s, tp, K.PASSO_CORSA, Vector2.ZERO, 0.11)
		c.stacca(K.altro(s), tp - 0.01)
		s = K.altro(s)
		tp += K.PASSO_CORSA
	# spinta nel verso nuovo: basso, spalla del lato scelto dentro la curva; poi su, di corsa
	c.chiave_bacino(tg + B_PERNO_GIU, Vector3(S * 0.04, 0.86, 0.02))
	c.chiave_angoli(tg + B_PERNO_GIU, Vector3(S * 0.25, 0.24, S * 0.12))
	c.chiave_busto(tg + B_PERNO_GIU, Vector3(0.28, S * 0.12, S * 0.25))
	c.chiave_bacino(tg + B_GIRO + 0.06, Vector3(0, 0.9, 0.02))
	c.chiave_angoli(tg + B_GIRO + 0.06, Vector3(0, 0.2, 0))
	c.chiave_busto(tg + B_GIRO + 0.06, Vector3(0.2, 0, 0))
	c.chiave_bacino(tg + B_FINE, Vector3(0, 0.92, -0.02))
	c.chiave_angoli(tg + B_FINE, Vector3(0, 0.14, 0))
	c.chiave_busto(tg + B_FINE, Vector3(0.16, 0, 0))
	# braccia: larghe nel giro (quella del lato scelto tira indietro, l'altra viene avanti), poi di corsa
	K.braccia(c, tg + B_PERNO_GIU, pS, Vector3(0.38, -0.18, -0.22), Vector3(0.4, -0.12, 0.22))
	var tb := tg + B_PASSO
	s = pF
	while tb < tg + B_FINE + 0.05:
		c.chiave_braccio(K.altro(s), tb, K.BR_AVANTI)
		c.chiave_braccio(s, tb, K.BR_DIETRO)
		s = K.altro(s)
		tb += K.PASSO_CORSA
	c.fine = tg + B_FINE
