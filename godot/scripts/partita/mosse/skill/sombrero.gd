# Giochetto del dribbling "Sombrero" (id `sombrero`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
# Luis 2026-11-26: "bella, ma deve essere il giocatore a riprendere la palla, non la palla a tornare". Il pallone, dal
# colpo di punta in poi, è quello staccato del motore (sim/duel.gd dribPallaLancia: gravità e rimbalzo veri); qui ci
# sono il gesto che lo alza, la partenza di corsa intorno al difensore con gli occhi sul pallone, e il piede che lo
# controlla quando lo raggiunge (coreo.presa).
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

const T_SUOLA := 0.1          # la suola arriva sul pallone (s dall'inizio) ...
const T_TIRA := 0.25          # ... e lo ha tirato indietro, sotto il corpo
const Z_SUOLA := 0.58         # pallone davanti al corpo quando la suola lo prende (m del modello) ...
const Z_TIRA := 0.3           # ... e dove lo porta
const Z_PUNTA := 0.38         # da qui la punta lo alza
const PASSO := 0.16           # s tra due appoggi nella partenza intorno al difensore ...
const FALCATA := 0.26         # ... lunghi quanto il corpo fa in tanto (s): falcate, non passetti
const FINE_B := 0.32          # la coreografia del corpo dura tanto dopo lo scatto (poi il clip di corsa)
const PRESA_T := 0.1          # ripreso il pallone: il piede ci arriva in tanto ...
const PRESA_FINE := 0.24      # ... e il gesto dura tanto


# sombrero in corsa: la suola ferma il pallone e lo tira sotto il corpo (saltello sul piede d'appoggio), la punta gli
# va sotto e lo alza col ginocchio che sale, busto indietro e braccia larghe: pallonetto sopra la testa del difensore
static func a(c: Coreo, S: float, _g: float) -> void:
	var pS := K.ls(S)
	var pF := K.altro(pS)
	var tk := float(K.Skill.trova("sombrero").tk)
	var t0 := K.libera(c, pS)
	var t1 := maxf(t0 + 0.03, T_SUOLA)
	# pallone: suola sopra, tirato indietro col piede attaccato, poi la punta sotto (da lì è quello del motore)
	c.tocca(pS, t1, "sole", Vector3(0, -0.3, 0), {"rel": Vector3(S * 0.05, 0, Z_SUOLA)})
	c.tocca(pS, T_TIRA, "sole", Vector3(0, -0.12, 0), {"rel": Vector3(S * 0.05, 0, Z_TIRA), "lega": true})
	c.tocca(pS, tk, "toe", Vector3(0, -0.5, 0), {"rel": Vector3(S * 0.03, 0, Z_PUNTA), "h": 0.03}, 0.0)
	c.passa(pS, tk + 0.09, Vector3(S * 0.08, 0.5, 0.56), Vector3(0, -0.55, 0), 0.0)
	# piede d'appoggio: un saltello mentre la suola tira (il corpo continua ad avanzare), fermo quando la punta alza
	c.stacca(pF, t1 + 0.05)
	c.appoggia_corsa(pF, T_TIRA - 0.02, 0.2, Vector2(-S * 0.04, 0.0), 0.04)
	# corpo: sopra il pallone mentre lo tira (busto avanti, bacino giù), poi su e indietro col pallone che sale
	c.chiave_bacino(t1, Vector3(0, 0.9, -0.05))
	c.chiave_busto(t1, Vector3(0.14, 0, 0))
	c.chiave_bacino(T_TIRA, Vector3(-S * 0.03, 0.87, -0.04))
	c.chiave_angoli(T_TIRA, Vector3(0, 0.08, -S * 0.05))
	c.chiave_busto(T_TIRA, Vector3(0.2, 0, 0))
	c.chiave_bacino(tk + 0.06, Vector3(-S * 0.03, 0.96, -0.08))
	c.chiave_angoli(tk + 0.06, Vector3(0, -0.14, 0))
	c.chiave_busto(tk + 0.06, Vector3(-0.2, 0, 0))
	K.braccia(c, t1, pS, K.BR_RIPOSO, K.BR_LARGO)
	K.braccia(c, T_TIRA, pS, Vector3(0.2, -0.36, 0.1), Vector3(0.36, -0.24, 0.0))
	K.braccia(c, tk + 0.06, pS, Vector3(0.4, -0.02, -0.06), Vector3(0.4, -0.06, -0.12))


# parte B: S = lato scelto, tg = adesso (lo scatto). Il pallone è in volo (ball.finto del motore): il ginocchio finisce
# di salire e quella gamba fa subito una falcata lunga dal lato scelto (l'altra spinge: uno stacco, non passetti), busto
# dentro la curva e occhi sul pallone; poi il clip di corsa. Quando lo raggiunge lo controlla col piede (_presa)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	var pF := K.altro(pS)
	c.taglia(tg, false)
	c.yaw_fisso_fino = tg
	c.chiave_giro(tg + 0.18, 0.0)
	c.chiave_sguardo(tg + 0.08, 1.0)
	c.passa(pS, tg + 0.04, Vector3(S * 0.1, 0.44, 0.5), Vector3(0, -0.4, 0), 0.0)
	c.stacca(pF, tg + 0.1)
	c.appoggia_corsa(pS, tg + 0.18, FALCATA, Vector2(S * 0.08, 0.04), 0.0)
	c.appoggia_corsa(pF, tg + 0.18 + PASSO, FALCATA, Vector2.ZERO, 0.2)
	c.stacca(pS, tg + 0.14 + PASSO)
	c.appoggia_corsa(pS, tg + 0.18 + 2.0 * PASSO, FALCATA, Vector2.ZERO, 0.2)
	# corpo: ancora indietro a guardare il pallone, stacco, poi dentro la curva e avanti, di corsa
	c.chiave_bacino(tg + 0.05, Vector3(0, 0.95, -0.06))
	c.chiave_angoli(tg + 0.05, Vector3(0, -0.1, 0))
	c.chiave_busto(tg + 0.05, Vector3(-0.16, 0, 0))
	c.chiave_bacino(tg + 0.14, Vector3(S * 0.03, 0.97, 0.0))
	c.chiave_bacino(tg + 0.24, Vector3(S * 0.05, 0.88, 0.02))
	c.chiave_angoli(tg + 0.24, Vector3(S * 0.16, 0.2, S * 0.1))
	c.chiave_busto(tg + 0.24, Vector3(0.16, S * 0.08, S * 0.12))
	c.chiave_bacino(tg + FINE_B, Vector3(0, 0.92, -0.02))
	c.chiave_angoli(tg + FINE_B, Vector3(0, 0.14, 0))
	c.chiave_busto(tg + FINE_B, Vector3(0.16, 0, 0))
	# braccia: larghe finché il pallone sale, poi di corsa (avanti quello opposto alla gamba che appoggia)
	K.braccia(c, tg + 0.05, pS, Vector3(0.4, -0.04, -0.04), Vector3(0.38, -0.1, -0.1))
	K.braccia(c, tg + 0.2, pS, K.BR_DIETRO, K.BR_AVANTI)
	K.braccia(c, tg + 0.2 + PASSO, pS, K.BR_AVANTI, K.BR_DIETRO)
	c.fine = tg + FINE_B
	var wc: WeakRef = weakref(c)   # (la funzione resta in c: senza, c terrebbe in vita sé stessa)
	c.presa = func() -> void: _presa(wc.get_ref() as Coreo)


# il portatore ha raggiunto il pallone (sul rimbalzo): il piede libero gli va incontro e lo porta avanti di collo,
# senza fermarsi; poi di nuovo il clip di corsa
static func _presa(c: Coreo) -> void:
	if c == null:
		return
	var tt := c.t
	var s := "l" if not c.a_terra("l") else ("r" if not c.a_terra("r") else K.ls(c.lato))
	c.taglia(tt, false)
	c.tocca(s, tt + PRESA_T, "instep", Vector3(0, 0.35, 0), {"moto": true}, 0.02)
	c.stacca(K.altro(s), tt + PRESA_T + 0.03)
	c.appoggia_corsa(s, tt + PRESA_T + 0.08, FALCATA, Vector2.ZERO, 0.05)
	c.appoggia_corsa(K.altro(s), tt + PRESA_T + 0.08 + PASSO, FALCATA, Vector2.ZERO, 0.16)
	c.chiave_sguardo(tt + PRESA_T, 1.0)
	c.chiave_bacino(tt + PRESA_T, Vector3(0, 0.9, 0.0))
	c.chiave_angoli(tt + PRESA_T, Vector3(0, 0.16, 0))
	c.chiave_busto(tt + PRESA_T, Vector3(0.2, 0, 0))
	K.braccia(c, tt + PRESA_T, s, K.BR_DIETRO, K.BR_LARGO)
	c.chiave_bacino(tt + PRESA_FINE, Vector3(0, 0.92, -0.02))
	c.chiave_busto(tt + PRESA_FINE, Vector3(0.14, 0, 0))
	K.braccia(c, tt + PRESA_FINE, s, K.BR_AVANTI, K.BR_DIETRO)
	c.fine = tt + PRESA_FINE
