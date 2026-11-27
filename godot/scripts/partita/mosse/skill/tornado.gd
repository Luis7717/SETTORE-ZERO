# Giochetto del dribbling "Tornado" (id `tornado`), PROVVISORIO: per ora è la copia di skill/chop.gd (da rifare sul gesto vero)
# Giochetto del dribbling "Tornado" (id `tornado`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
#
# Luis 2026-11-26 "movimenti senza senso": rifatto sul gesto vero. Il motore intanto porta il corpo di corsa in
# diagonale verso la finta (circa 4 m/s) e allo scatto lo gira di colpo di 80-90° dal lato scelto (quasi 8 m/s). Quindi:
#   A  corre girato dove va (non di traverso), col pallone davanti; saltello a gambe larghe e braccia aperte: il piede
#      che taglia (lato della finta) sale largo e alto, il piede d'appoggio (lato scelto) atterra piantato DAVANTI al
#      pallone, ginocchio piegato;
#   B  il piede alto scende da fuori e con l'interno taglia il pallone dietro il tallone d'appoggio: il pallone schizza
#      di lato più veloce del corpo (si stacca di un metro), il corpo ci si butta dietro inclinato e lo riprende di corsa.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

const GIRO_CORSA := 0.95       # rad: in A il corpo si gira verso la finta tanto (è dove lo porta il motore)
const GIRO_TOCCO := 0.75       # rad: quanto di quel giro resta al momento del taglio (il corpo sta già girando)
const RIT := 0.02              # s: il taglio arriva tanto dopo lo scatto del motore
const PALLA_Z := 0.18          # m del modello: al taglio il pallone sta tanto davanti al corpo ...
const APPOGGIO_Z := 0.46       # ... e il piede d'appoggio tanto (il pallone gli passa dietro)
const SCHIZZO := 0.9           # m del modello: il pallone tagliato arriva tanto davanti al corpo nel verso nuovo
const FINE := 0.52             # s: la coreografia finisce tanto dopo lo scatto
const BR_VOLO := Vector3(0.44, -0.1, 0.02)   # braccia aperte nel saltello (equilibrio)


static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	# il corpo si gira verso dove corre (il motore lo porta in diagonale verso la finta)
	c.chiave_giro(0.4 * g, F * 0.45 * GIRO_CORSA)
	c.chiave_giro(0.68 * g, F * GIRO_CORSA)
	c.chiave_giro(g + 0.1, F * GIRO_CORSA)
	# pallone davanti, portato di corsa; nel saltello il corpo gli arriva sopra
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(0.55 * g, {"rel": Vector3(0, 0, 0.44)})
	c.palla_a(g + RIT, {"rel": Vector3(S * 0.02, 0, PALLA_Z)})
	# passi fino al saltello: l'ultimo appoggio prima del volo è col piede che è libero adesso
	var t_volo: float       # da quando tutti e due i piedi sono in aria
	if c.a_terra(pF):
		# piede della finta a terra: un passo di corsa col piede d'appoggio, che poi saltella e riatterra piantato
		if c.a_terra(pS):
			c.stacca(pS, 0.01)
		K.passo(c, pS, 0.25 * g, 0.14)
		t_volo = 0.6 * g
		c.stacca(pS, t_volo)
	else:
		# piede della finta in aria: appoggia lui, spinge e stacca per il saltello; l'altro va avanti a piantarsi
		K.passo(c, pF, 0.14 * g, 0.15)
		t_volo = 0.52 * g
		c.stacca(pF, t_volo)
	# il piede che taglia: su largo e dietro (ginocchio piegato, punta in giù), poi largo di fianco, pronto a scendere
	c.passa(pF, t_volo + 0.4 * (g - t_volo), Vector3(F * 0.3, 0.4, -0.2), Vector3(-S * 0.2, 0.6, 0), 0.0)
	c.passa(pF, t_volo + 0.78 * (g - t_volo), Vector3(F * 0.42, 0.36, 0.0), Vector3(-S * 0.3, 0.3, 0), 0.0)
	# ... e scende sul pallone da fuori (il tocco vero arriva con lo scatto, parte B)
	c.passa_palla(pF, g + RIT, Vector3(F * 0.16, 0.13, -0.14), Vector3(-S * 0.27, 0.1, 0), 0.0)
	# il piede d'appoggio atterra piantato davanti al pallone, punta appena in dentro
	c.appoggia(pS, g - 0.03, Vector2(S * 0.05, APPOGGIO_Z), S * 0.15, 0.1)
	# corpo: corsa, su nel saltello (braccia aperte), giù sull'appoggio già inclinato dal lato scelto
	c.chiave_bacino(0.3 * g, Vector3(0, 0.9, 0.02))
	c.chiave_angoli(0.3 * g, Vector3(0, 0.16, 0))
	c.chiave_busto(0.3 * g, Vector3(0.18, 0, 0))
	var ta := t_volo + 0.5 * (g - t_volo)
	c.chiave_bacino(ta, Vector3(0, 1.0, 0.04))
	c.chiave_angoli(ta, Vector3(F * 0.12, 0.1, 0))
	c.chiave_busto(ta, Vector3(0.1, 0, F * 0.15))
	c.chiave_bacino(g, Vector3(S * 0.03, 0.87, 0.08))
	c.chiave_angoli(g, Vector3(S * 0.15, 0.16, S * 0.12))
	c.chiave_busto(g, Vector3(0.2, S * 0.1, S * 0.12))
	K.braccia(c, 0.3 * g, pS, K.BR_AVANTI, K.BR_DIETRO)
	K.braccia(c, ta, pS, BR_VOLO, BR_VOLO)
	K.braccia(c, g, pS, Vector3(0.4, -0.16, 0.1), Vector3(0.42, -0.14, -0.1))
	c.chiave_sguardo(0.3 * g, 0.5, 0.0)
	c.chiave_sguardo(0.8 * g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var tt := tg + RIT
	var b_tocco := c.pallone_previsto(tt)
	c.taglia(tg)
	c.yaw_fisso_fino = tg
	# il corpo gira nel verso nuovo (dal motore) in un attimo
	c.chiave_giro(tt, F * GIRO_TOCCO)
	c.chiave_giro(tg + 0.14, 0.0)
	c.chiave_sguardo(tg + 0.1, 1.0)
	# il taglio: interno del piede che guarda il verso nuovo (il piede resta girato dove si correva prima)
	c.tocca(pF, tt, "inside", Vector3(-S * (PI / 2.0 - GIRO_TOCCO), 0.12, 0), {"mondo": b_tocco}, 0.0)
	# il pallone schizza via più veloce del corpo, poi rallenta e il portatore lo riprende di corsa
	c.palla_a(tt + 0.16, {"rel": Vector3(0, 0, SCHIZZO)})
	c.palla_a(tt + 0.36, {"rel": Vector3(0, 0, SCHIZZO - 0.14)})
	c.palla_a(tg + FINE, {"moto": true})
	# passi: il piede del taglio appoggia nel verso nuovo, quello piantato si stacca e segue; poi corsa
	var t1 := tt + 0.08
	c.appoggia_corsa(pF, t1, K.PASSO_CORSA, Vector2.ZERO, 0.05)
	c.stacca(pS, tg + 0.08)
	var s := pS
	var tp := t1 + K.PASSO_CORSA
	while tp < tg + FINE + 0.1:
		c.appoggia_corsa(s, tp, K.PASSO_CORSA, Vector2.ZERO, 0.11)
		c.stacca(K.altro(s), tp - 0.01)
		s = K.altro(s)
		tp += K.PASSO_CORSA
	# corpo: giù e buttato dentro la curva sul taglio, poi su di corsa
	c.chiave_bacino(tg + 0.06, Vector3(S * 0.07, 0.81, 0.05))
	c.chiave_angoli(tg + 0.06, Vector3(S * 0.25, 0.28, S * 0.26))
	c.chiave_busto(tg + 0.07, Vector3(0.34, S * 0.22, S * 0.2))
	c.chiave_bacino(tg + 0.24, Vector3(S * 0.03, 0.85, 0.04))
	c.chiave_angoli(tg + 0.24, Vector3(0, 0.3, S * 0.14))
	c.chiave_busto(tg + 0.26, Vector3(0.34, S * 0.1, 0))
	c.chiave_bacino(tg + FINE, Vector3(0, 0.92, -0.02))
	c.chiave_angoli(tg + FINE, Vector3(0, 0.14, 0))
	c.chiave_busto(tg + FINE, Vector3(0.16, 0, 0))
	# braccia: larghe sul taglio (equilibrio), poi di corsa (avanti quello opposto alla gamba che appoggia)
	K.braccia(c, tg + 0.05, pS, Vector3(0.36, -0.2, -0.2), Vector3(0.44, -0.08, 0.1))
	var tb := t1
	s = pF
	while tb < tg + FINE + 0.05:
		c.chiave_braccio(K.altro(s), tb + 0.1, K.BR_AVANTI)
		c.chiave_braccio(s, tb + 0.1, K.BR_DIETRO)
		s = K.altro(s)
		tb += K.PASSO_CORSA
	c.fine = tg + FINE
