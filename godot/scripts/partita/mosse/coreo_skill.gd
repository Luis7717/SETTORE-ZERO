# I giochetti del dribbling della persona (Luis 2026-11-26: "fanno pena, falli veri e aggiungine"): 16 movimenti del
# calcio vero costruiti con coreo.gd (piedi fermi a terra, passi programmati, pallone mosso solo dai tocchi).
# Quale giochetto e quanto dura lo decide il motore (sim/skill.gd: evento 'dribble' con skill e show); qui si decide
# come si muovono gambe, busto, braccia e pallone. Niente è copiato da altri giochi: sono i gesti del calcio.
#
# Tutti si fanno IN CORSA (Luis 2026-11-26: "si ferma sul posto prima del giochetto"): il motore intanto porta il
# corpo avanti e di lato (`av`, `lat`, `vel` di sim/skill.gd), quindi i piedi fanno passi di corsa (coreo.appoggia_corsa,
# e i passi automatici di coreo.gd) e il pallone viaggia col corpo ("rel").
# Ogni giochetto ha due parti:
#   A (a_ID, dura `g` = show): la finta davanti al difensore;
#   B (b_ID, dall'evento 'dribble_go'): il tocco che porta via il pallone dal lato scelto e i primi passi di corsa nel
#     verso nuovo (il motore scatta oltre il difensore).
# Tunnel, sombrero e bicicletta: dal calcio in poi il pallone è quello staccato del motore (ball.finto: dritto, attrito
# e gravità veri) e il portatore gli corre dietro; qui c'è solo il gesto del calcio.
# Lati: S = lato scelto (+1 = sinistra del portatore), F = −S (finta); pS / pF = piede di quel lato.
# Riferimento del corpo: x sinistra, y su, z avanti, m del modello (a schermo ×1,25).
extends RefCounted

const Coreo := preload("coreo.gd")
const Corpo := preload("corpo.gd")
const Skill := preload("res://sim/skill.gd")
const Duel := preload("res://sim/duel.gd")

const IDS := ["finta", "stopgo", "suola", "doppiopasso", "croqueta", "fintatiro", "chop", "cruyff", "tacco", "pedalata",
	"elastico", "tunnel", "veronica", "elastico_inv", "sombrero", "bicicletta"]
const FINE_GO := 0.4           # la coreografia finisce tanto dopo lo scatto (poi il clip di corsa)
const PASSO_CORSA := 0.085     # s tra due appoggi nei primi passi dello scatto
const PASSO_A := 0.15          # s tra due appoggi nei passi di corsa durante il giochetto
const H := Corpo.ANKLE_H
const SCALA := 1.25            # m del gioco per m del modello
# braccia (mano rispetto alla spalla: x fuori, y su, z avanti): gomiti piegati, mai dritte e ferme
const BR_RIPOSO := Vector3(0.13, -0.4, 0.12)
const BR_LARGO := Vector3(0.34, -0.28, 0.06)
const BR_AVANTI := Vector3(0.08, -0.26, 0.32)
const BR_DIETRO := Vector3(0.2, -0.34, -0.24)
const BR_ALTO := Vector3(0.37, -0.04, 0.1)
const BR_PETTO := Vector3(0.02, -0.28, 0.3)


static func ls(x: float) -> String:
	return "l" if x > 0.0 else "r"


static func segno(s: String) -> float:
	return 1.0 if s == "l" else -1.0


static func altro(s: String) -> String:
	return "r" if s == "l" else "l"


## parte A del giochetto `id`
static func parte_a(c: Coreo, id: String, S: float, g: float) -> void:
	match id:
		"stopgo": a_stopgo(c, S, g)
		"suola": a_suola(c, S, g)
		"doppiopasso": a_doppiopasso(c, S, g)
		"croqueta": a_croqueta(c, S, g)
		"fintatiro": a_fintatiro(c, S, g)
		"chop": a_chop(c, S, g)
		"cruyff": a_cruyff(c, S, g)
		"tacco": a_tacco(c, S, g)
		"pedalata": a_pedalata(c, S, g)
		"elastico": a_elastico(c, S, g)
		"tunnel": a_tunnel(c, S, g)
		"veronica": a_veronica(c, S, g)
		"elastico_inv": a_elastico_inv(c, S, g)
		"sombrero": a_sombrero(c, S, g)
		"bicicletta": a_bicicletta(c, S, g)
		_: a_finta(c, S, g)


## parte B (arrivato lo scatto del motore, adesso)
static func parte_b(c: Coreo, id: String, S: float) -> void:
	var tg := c.t
	var pS := ls(S)
	var pF := ls(-S)
	match id:
		"stopgo":
			via(c, S, tg, pS, "outside", esterno(S, 0.6), 0.04, {"spinta": 1.3})
		"suola":
			via(c, S, tg, pS, "outside", esterno(S, 0.5), 0.06)
		"croqueta":
			via(c, S, tg, pS, "inside", Vector3(S * 0.5, 0.1, 0), 0.07, {"rel": Vector3(S * 0.1, 0, 0.5)})
		"fintatiro":
			via(c, S, tg, pF, "inside", interno(S, 0.7), 0.05)
		"chop":
			via(c, S, tg, pF, "inside", Vector3(-S * 1.5, 0.05, 0), 0.03, {"salto": 0.07, "fine": 0.44})
		"cruyff":
			via(c, S, tg, pF, "inside", Vector3(S * 1.3, 0.05, 0), 0.04, {"fine": 0.48})
		"tacco":
			via(c, S, tg, pF, "heel", Vector3(-S * 1.15, 0.2, 0), 0.04)
		"elastico":
			via(c, S, tg, pF, "inside", interno(S, 1.2), 0.05)
		"elastico_inv":
			via(c, S, tg, pS, "outside", esterno(S, 0.9), 0.05)
		"veronica":
			b_veronica(c, S, tg)
		"tunnel", "sombrero", "bicicletta":
			# il pallone è partito (ball.finto): via di corsa intorno al difensore, a riprenderlo
			via(c, S, tg, pS, "", Vector3.ZERO, 0.0, {"volo": true, "fine": 0.42})
		_:   # finta, doppio passo, pedalata
			via(c, S, tg, pS, "outside", esterno(S, 0.85), 0.05)


# esterno del piede del lato S verso l'avanti e un po' di lato: k = quanto è girata la punta verso dentro
static func esterno(S: float, k: float) -> Vector3:
	return Vector3(-S * k, 0.25, 0)


# interno del piede della finta (lato −S) verso l'avanti e il lato S
static func interno(S: float, k: float) -> Vector3:
	return Vector3(-S * k, 0.1, 0)


# il piede `s` deve essere libero subito e l'altro a terra: sistema i piedi come sono adesso (uno può essere in volo)
# e ritorna da quando `s` può muoversi (s)
static func libera(c: Coreo, s: String) -> float:
	var o := altro(s)
	if c.a_terra(o):
		if c.a_terra(s):
			c.stacca(s, 0.01)
			return 0.02
		return 0.0
	c.appoggia_corsa(o, 0.06, 0.12, Vector2.ZERO, 0.04)
	if c.a_terra(s):
		c.stacca(s, 0.06)
	return 0.07


static func braccia(c: Coreo, tt: float, pS: String, bS: Vector3, bF: Vector3) -> void:
	c.chiave_braccio(pS, tt, bS)
	c.chiave_braccio(altro(pS), tt, bF)


# velocità del corpo durante il giochetto `id` secondo il motore (sim/skill.gd, sim/duel.gd dribShowSteer), nel
# riferimento del corpo all'inizio (x sinistra, z avanti), m del modello al secondo
static func vel_corpo(id: String, S: float) -> Vector3:
	var sk := Skill.trova(id)
	var w := Vector3(-S * float(sk.get("lat", 0.0)), 0.0, float(sk.get("av", 1.0)))
	return w / maxf(1.0, w.length()) * (Duel.DRIB_SHOW_V * float(sk.get("vel", 1.0)) / SCALA)


# un passo di corsa: il piede s atterra a tt (appoggio lungo T), l'altro si stacca
static func passo(c: Coreo, s: String, tt: float, T: float = PASSO_A, rel: Vector2 = Vector2.ZERO, alto: float = 0.09) -> void:
	c.appoggia_corsa(s, tt, T, rel, alto)
	c.stacca(altro(s), tt - 0.01)


# punto fisso nel mondo davanti al corpo com'è adesso (z avanti, x a sinistra; m del modello), a terra
static func davanti(c: Coreo, z: float, x: float = 0.0) -> Vector3:
	var q := c.mondo_a(c.t, Vector3(x, 0, z))
	return Vector3(q.x, 0.0, q.z)


# il pallone continua dritto sulla linea di prima mentre il corpo va di lato verso la finta: alla fine sta `z` avanti
# e, rispetto al corpo, dalla parte del lato scelto di quanto il corpo si è spostato
static func dritto(c: Coreo, id: String, S: float, g: float, z: float = 0.46) -> void:
	var v := vel_corpo(id, S)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(g + 0.05, {"rel": Vector3(-v.x * (g - 0.05), 0, z)})


# ================================================================ parte B comune: tocco e via di corsa
## tocco del pallone col piede `piede` (punto `part`, girato di ang) `rit` s dopo lo scatto, poi primi passi di corsa
## nel verso nuovo. opt: rel (pallone del tocco davanti al corpo nuovo invece che dov'era diretto), palla (altri punti
## del pallone [[t, spec], ...] prima di tornare quello del motore), fine (durata), volo (il pallone è in volo: niente
## tocco, continua da solo), spinta (quanto è profonda la partenza), salto (saltello sul tocco)
static func via(c: Coreo, S: float, tg: float, piede: String, part: String, ang: Vector3, rit: float, opt: Dictionary = {}) -> void:
	var volo: bool = opt.get("volo", false)
	var fine: float = opt.get("fine", FINE_GO)
	var tt := tg + rit
	var b_tocco := c.pallone_previsto(tt)
	c.taglia(tg, not volo)
	c.yaw_fisso_fino = tg
	if not opt.has("giro"):
		c.chiave_giro(tg + 0.16, 0.0)
	c.chiave_sguardo(tg + 0.1, 1.0)
	if not volo:
		c.tocca(piede, tt, part, ang, {"rel": opt.rel} if opt.has("rel") else {"mondo": b_tocco})
		for k: Array in opt.get("palla", []):
			c.palla_a(float(k[0]), k[1])
		c.palla_a(tg + fine, {"moto": true})
	# primi passi di corsa: il piede del tocco appoggia avanti, l'altro (quello della spinta) si stacca
	var o := altro(piede)
	var t1 := tt + 0.07
	c.appoggia_corsa(piede, t1, PASSO_CORSA, Vector2.ZERO, 0.08)
	c.stacca(o, maxf(tg + 0.05, t1 - 0.04))
	var a := o
	var tp := t1 + PASSO_CORSA
	while tp < tg + fine + 0.1:
		c.appoggia_corsa(a, tp, PASSO_CORSA, Vector2.ZERO, 0.11)
		c.stacca(altro(a), tp - 0.01)
		a = altro(a)
		tp += PASSO_CORSA
	# spinta: bacino giù e in avanti, busto dentro la curva; poi su, di corsa (non piegato in due)
	var k: float = opt.get("spinta", 1.0)
	var su: float = opt.get("salto", 0.0)
	c.chiave_bacino(tg + 0.07, Vector3(S * 0.05, 0.875 - 0.02 * k + su, 0.02))
	c.chiave_angoli(tg + 0.07, Vector3(S * 0.22, 0.22 * k, S * 0.08))
	c.chiave_busto(tg + 0.08, Vector3(0.22 * k, S * 0.1, S * 0.14))
	c.chiave_bacino(tg + 0.22, Vector3(0, 0.9, 0.02))
	c.chiave_angoli(tg + 0.22, Vector3(0, 0.2, 0))
	c.chiave_busto(tg + 0.24, Vector3(0.2, 0, 0))
	c.chiave_bacino(tg + fine, Vector3(0, 0.92, -0.02))
	c.chiave_angoli(tg + fine, Vector3(0, 0.14, 0))
	c.chiave_busto(tg + fine, Vector3(0.16, 0, 0))
	# braccia di corsa: avanti quello opposto alla gamba che appoggia; sul tocco larghe (equilibrio)
	braccia(c, tg + 0.05, ls(S), BR_DIETRO, BR_LARGO)
	var tb := t1
	a = piede
	while tb < tg + fine + 0.05:
		c.chiave_braccio(altro(a), tb, BR_AVANTI)
		c.chiave_braccio(a, tb, BR_DIETRO)
		a = altro(a)
		tb += PASSO_CORSA
	c.fine = tg + fine


# ================================================================ finte di corpo (il pallone va dritto, il corpo va via)
# finta di corpo: in corsa, passo largo e basso dal lato della finta, spalla che cade di là e sguardo di là; il pallone
# continua dritto e allo scatto l'esterno dell'altro piede lo porta via
static func a_finta(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	dritto(c, "finta", S, g)
	var tp := maxf(t0 + 0.1, 0.5 * g)
	c.appoggia_corsa(pF, tp, 0.2, Vector2(F * 0.3, 0.0), 0.08)
	c.stacca(pS, tp + 0.03)
	c.chiave_bacino(0.55 * g, Vector3(F * 0.15, 0.85, 0.0))
	c.chiave_angoli(0.55 * g, Vector3(F * 0.35, 0.06, F * 0.1))
	c.chiave_busto(0.55 * g, Vector3(0.14, F * 0.25, F * 0.3))
	c.chiave_bacino(g, Vector3(F * 0.18, 0.84, 0.02))
	c.chiave_angoli(g, Vector3(F * 0.38, 0.06, F * 0.12))
	c.chiave_busto(g, Vector3(0.16, F * 0.28, F * 0.32))
	braccia(c, 0.55 * g, pS, Vector3(0.1, -0.24, 0.3), Vector3(0.38, -0.1, -0.05))
	c.chiave_sguardo(0.5 * g, 0.2, F * 0.55)
	c.chiave_sguardo(g, 0.4, F * 0.3)


# stop e via: suola sul pallone, il portatore si ferma e si alza dritto (il difensore si rilassa), tira appena
# indietro il pallone e riparte di scatto
static func a_stopgo(c: Coreo, S: float, g: float) -> void:
	var pS := ls(S)
	var t0 := libera(c, pS)   # (l'altro piede regge fermo)
	var t1 := maxf(t0 + 0.07, 0.2 * g)
	c.tocca(pS, t1, "sole", Vector3(0, -0.25, 0), {"rel": Vector3(S * 0.05, 0, 0.5)})
	c.tocca(pS, 0.8 * g, "sole", Vector3(0, -0.2, 0), {"rel": Vector3(S * 0.05, 0, 0.36), "lega": true})
	c.chiave_bacino(t1, Vector3(0, 0.9, -0.08))
	c.chiave_angoli(t1, Vector3(0, -0.06, 0))
	c.chiave_busto(t1, Vector3(0.02, 0, 0))
	c.chiave_bacino(0.6 * g, Vector3(-S * 0.03, 0.955, -0.08))
	c.chiave_angoli(0.6 * g, Vector3(0, -0.04, 0))
	c.chiave_busto(0.6 * g, Vector3(-0.04, 0, 0))
	c.chiave_bacino(g, Vector3(-S * 0.02, 0.9, -0.04))
	c.chiave_busto(g, Vector3(0.1, 0, 0))
	braccia(c, t1, pS, BR_LARGO, BR_LARGO)
	braccia(c, 0.6 * g, pS, BR_RIPOSO, BR_RIPOSO)
	braccia(c, g, pS, BR_DIETRO, BR_AVANTI)
	c.chiave_sguardo(0.5 * g, 0.25, 0.0)
	c.chiave_sguardo(g, 1.0, 0.0)


# finta di tiro: appoggio accanto al pallone, gamba caricata dietro e braccio alto come per calciare; il piede scende
# ma si ferma sul pallone e l'interno lo taglia dal lato scelto
static func a_fintatiro(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.52)})
	c.palla_a(g + 0.05, {"rel": Vector3(F * 0.05, 0, 0.4)})
	var tp := maxf(t0 + 0.1, 0.3 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.24, H, 0.1), S * 0.15, 0.06)
	c.stacca(pF, tp - 0.04)
	c.passa(pF, 0.6 * g, Vector3(F * 0.16, 0.62, -0.5), Vector3(0, 1.0, 0), 0.0)
	c.passa_palla(pF, 0.92 * g, Vector3(F * 0.14, 0.2, -0.16), Vector3(-S * 0.4, 0.5, 0), 0.0)
	c.chiave_bacino(0.6 * g, Vector3(S * 0.04, 0.93, 0.0))
	c.chiave_angoli(0.6 * g, Vector3(F * 0.38, -0.06, 0))
	c.chiave_busto(0.6 * g, Vector3(-0.1, S * 0.07, F * 0.3))
	c.chiave_bacino(0.95 * g, Vector3(S * 0.04, 0.88, 0.06))
	c.chiave_angoli(0.95 * g, Vector3(S * 0.1, 0.1, 0))
	c.chiave_busto(0.95 * g, Vector3(0.22, S * 0.03, S * 0.2))
	braccia(c, 0.6 * g, pS, Vector3(0.38, -0.04, 0.12), Vector3(0.3, -0.26, -0.3))
	braccia(c, 0.95 * g, pS, Vector3(0.32, -0.26, -0.2), Vector3(0.2, -0.24, 0.26))
	c.chiave_sguardo(0.5 * g, 0.1, 0.0)
	c.chiave_sguardo(g, 1.0, 0.0)


# tunnel: in corsa, mezza finta di corpo per far allargare le gambe al difensore, poi la punta manda il pallone
# dritto tra le sue gambe (da lì è il pallone staccato del motore: dritto, rallenta per l'attrito) e il portatore gli
# gira intorno e lo va a riprendere
static func a_tunnel(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	var tp := maxf(t0 + 0.1, 0.5 * g)
	c.appoggia_corsa(pF, tp, 0.2, Vector2(F * 0.22, 0.0), 0.07)
	c.stacca(pS, tp + 0.02)
	# la punta del piede del lato scelto colpisce il pallone (quello del motore, ai suoi piedi) verso il difensore
	c.tocca(pS, g, "toe", Vector3(-S * 0.25, 0.3, 0), {"moto": true}, 0.05)
	c.passa(pS, g + 0.1, Vector3(S * 0.08, 0.2, 0.5), Vector3(0, 0.1, 0), 0.0)
	c.chiave_bacino(0.6 * g, Vector3(F * 0.1, 0.87, 0.0))
	c.chiave_angoli(0.6 * g, Vector3(F * 0.25, 0.06, F * 0.06))
	c.chiave_busto(0.6 * g, Vector3(0.14, F * 0.18, F * 0.22))
	c.chiave_bacino(g, Vector3(F * 0.08, 0.88, 0.04))
	c.chiave_busto(g, Vector3(0.2, 0, 0))
	braccia(c, 0.6 * g, pS, Vector3(0.12, -0.26, 0.28), Vector3(0.37, -0.14, 0.0))
	braccia(c, g, pS, BR_DIETRO, BR_LARGO)
	c.chiave_sguardo(0.5 * g, 0.2, F * 0.5)
	c.chiave_sguardo(g, 1.0, 0.0)


# ================================================================ passi sopra il pallone
# giro del piede `s` intorno al davanti del pallone, da dentro a fuori (verso il lato dir), dal tempo ta per dur s;
# largo = quanto fuori appoggia (m del modello dal pallone), alto = quanto alto passa, dietro = quanto dietro appoggia
static func _passo_sopra(c: Coreo, s: String, dir: float, ta: float, dur: float, largo: float, alto: float, dietro: float = -0.16) -> void:
	c.passa_palla(s, ta + 0.38 * dur, Vector3(-dir * 0.1, alto, -0.06), Vector3(dir * 0.35, 0.25, 0), 0.03)
	c.passa_palla(s, ta + 0.7 * dur, Vector3(dir * 0.05, alto + 0.03, 0.22), Vector3(-dir * 0.25, 0.3, 0), 0.0)
	c.appoggia_palla(s, ta + dur, Vector3(dir * largo, H, dietro), dir * 0.4, 0.02)


# doppio passo: quasi fermo sul pallone, due passi larghi e lenti sopra il pallone (prima dal lato scelto, poi dalla
# finta, con tutto il corpo basso che ci va dietro), poi l'esterno lo porta via
static func a_doppiopasso(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.palla_a(0.1, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(g + 0.05, {"rel": Vector3(0, 0, 0.44)})
	var d1 := 0.21
	var ta := t0
	_passo_sopra(c, pS, S, ta, d1, 0.3, 0.24, 0.02)
	var tb := ta + d1 - 0.02
	c.stacca(pF, tb)
	var d2 := minf(0.24, g - 0.02 - tb)
	_passo_sopra(c, pF, F, tb, d2, 0.4, 0.24, 0.02)
	c.chiave_bacino(ta + 0.75 * d1, Vector3(S * 0.08, 0.86, 0.0))
	c.chiave_angoli(ta + 0.75 * d1, Vector3(S * 0.3, 0.08, S * 0.06))
	c.chiave_busto(ta + 0.75 * d1, Vector3(0.18, S * 0.16, S * 0.22))
	c.chiave_bacino(tb + 0.85 * d2, Vector3(F * 0.16, 0.82, 0.0))
	c.chiave_angoli(tb + 0.85 * d2, Vector3(F * 0.4, 0.08, F * 0.12))
	c.chiave_busto(tb + 0.85 * d2, Vector3(0.2, F * 0.28, F * 0.32))
	braccia(c, ta + 0.75 * d1, pS, Vector3(0.37, -0.16, -0.02), Vector3(0.12, -0.26, 0.28))
	braccia(c, tb + 0.85 * d2, pS, Vector3(0.12, -0.26, 0.28), Vector3(0.38, -0.1, -0.04))
	c.chiave_sguardo(tb + 0.6 * d2, 0.5, F * 0.4)


# pedalata: di corsa, col pallone che rotola avanti, quattro giri veloci delle gambe sopra il pallone, uno per passo
# (larghi e alti: da lontano si vedono le gambe che girano), busto dritto e braccia che pompano; poi l'esterno e via
static func a_pedalata(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.56)})
	c.palla_a(g + 0.05, {"rel": Vector3(0, 0, 0.56)})
	var n := 4
	var per := (g - 0.02 - t0) / float(n)
	for i in n:
		var s := pS if i % 2 == 0 else pF
		var dir := S if i % 2 == 0 else F
		var ta := t0 + per * i
		if i > 0:
			c.stacca(s, ta - 0.015)
		# il piede gira largo e alto intorno al davanti del pallone e atterra fuori, più avanti (il corpo corre)
		c.passa_palla(s, ta + 0.3 * per, Vector3(-dir * 0.12, 0.3, -0.08), Vector3(dir * 0.4, 0.3, 0), 0.03)
		c.passa_palla(s, ta + 0.62 * per, Vector3(dir * 0.1, 0.34, 0.26), Vector3(-dir * 0.3, 0.3, 0), 0.0)
		c.appoggia_palla(s, ta + per + 0.01, Vector3(dir * 0.36, H, 0.06), dir * 0.3, 0.02)
		var tm := ta + 0.7 * per
		c.chiave_bacino(tm, Vector3(dir * 0.07, 0.93, 0.02))
		c.chiave_angoli(tm, Vector3(dir * 0.3, 0.06, dir * 0.07))
		c.chiave_busto(tm, Vector3(0.08, dir * 0.1, dir * 0.26))
		braccia(c, tm, ls(dir), Vector3(0.38, -0.14, -0.16), Vector3(0.16, -0.16, 0.32))
	c.chiave_sguardo(g * 0.5, 0.6, 0.0)


# elastico: l'esterno del piede della finta porta il pallone fuori (e il corpo ci va dietro), poi il piede gli gira
# intorno e l'interno lo riporta di scatto dal lato scelto
static func a_elastico(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	var tf := maxf(t0 + 0.08, 0.26 * g)
	c.tocca(pF, tf, "outside", Vector3(-F * 0.35, 0.15, 0), {"rel": Vector3(F * 0.04, 0, 0.5)})
	c.tocca(pF, 0.76 * g, "outside", Vector3(-F * 0.5, 0.15, 0), {"rel": Vector3(F * 0.44, 0, 0.52), "lega": true, "frena": true})
	c.passa_palla(pF, 0.94 * g, Vector3(F * 0.04, 0.26, 0.06), Vector3(-S * 0.5, 0.3, 0), 0.0)
	c.tocca(pF, g + 0.05, "inside", interno(S, 1.2), {"rel": Vector3(F * 0.44, 0, 0.52)})
	# il piede che regge fa un saltello per seguire il corpo
	c.stacca(pS, 0.45 * g)
	c.appoggia(pS, 0.45 * g + 0.09, Vector2(S * 0.1, 0.0), 0.0, 0.04)
	c.chiave_bacino(tf, Vector3(F * 0.04, 0.9, -0.03))
	c.chiave_bacino(0.76 * g, Vector3(F * 0.14, 0.86, 0.0))
	c.chiave_angoli(0.76 * g, Vector3(F * 0.32, 0.06, F * 0.08))
	c.chiave_busto(0.76 * g, Vector3(0.14, F * 0.22, F * 0.24))
	braccia(c, 0.76 * g, pS, Vector3(0.14, -0.26, 0.28), Vector3(0.38, -0.12, 0.0))
	c.chiave_sguardo(0.7 * g, 0.6, F * 0.3)


# elastico inverso: l'interno del piede del lato scelto porta il pallone dentro, attraverso il corpo (gamba
# incrociata), poi l'esterno dello stesso piede lo riporta fuori di scatto
static func a_elastico_inv(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	var tf := maxf(t0 + 0.08, 0.26 * g)
	c.tocca(pS, tf, "inside", Vector3(S * 0.35, 0.1, 0), {"rel": Vector3(S * 0.1, 0, 0.5)})
	c.tocca(pS, 0.76 * g, "inside", Vector3(S * 0.5, 0.1, 0), {"rel": Vector3(F * 0.3, 0, 0.5), "lega": true, "frena": true})
	c.passa_palla(pS, 0.94 * g, Vector3(F * 0.06, 0.26, 0.04), Vector3(-S * 0.5, 0.3, 0), 0.0)
	c.tocca(pS, g + 0.05, "outside", esterno(S, 0.9), {"rel": Vector3(F * 0.3, 0, 0.5)})
	c.stacca(pF, 0.4 * g)
	c.appoggia(pF, 0.4 * g + 0.09, Vector2(F * 0.2, -0.04), F * 0.2, 0.04)
	c.chiave_bacino(tf, Vector3(0, 0.9, -0.03))
	c.chiave_bacino(0.76 * g, Vector3(F * 0.1, 0.87, 0.0))
	c.chiave_angoli(0.76 * g, Vector3(F * 0.4, 0.06, F * 0.06))
	c.chiave_busto(0.76 * g, Vector3(0.14, F * 0.18, F * 0.3))
	braccia(c, 0.76 * g, pS, Vector3(0.4, -0.2, -0.16), Vector3(0.36, -0.14, 0.1))
	c.chiave_sguardo(0.7 * g, 0.6, F * 0.3)


# croqueta: scivolando di lato verso il lato scelto, l'interno del piede della finta passa il pallone di traverso
# (quasi un metro) all'interno dell'altro piede, che lo porta avanti; il corpo salta da un piede all'altro col pallone
static func a_croqueta(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	var t1 := maxf(t0 + 0.1, 0.38 * g)
	# il pallone davanti al piede della finta, che lo colpisce d'interno verso il lato scelto ...
	c.palla_a(0.08, {"rel": Vector3(F * 0.1, 0, 0.46)})
	c.tocca(pF, t1, "inside", Vector3(F * 0.5, 0.05, 0), {"rel": Vector3(F * 0.16, 0, 0.42)}, 0.08)
	# ... e arriva all'interno dell'altro piede, già aperto ad aspettarlo dall'altra parte del corpo
	c.tocca(pS, g + 0.07, "inside", Vector3(S * 0.5, 0.1, 0), {"rel": Vector3(S * 0.34, 0, 0.44)}, 0.05)
	c.appoggia_corsa(pF, t1 + 0.1, 0.14, Vector2(S * 0.06, 0.0), 0.05)
	c.passa(pS, 0.75 * g, Vector3(S * 0.4, 0.2, 0.3), Vector3(S * 0.5, 0.1, 0), 0.06)
	# si abbassa sul primo tocco, poi il saltello di lato e si allunga verso il lato scelto
	c.chiave_bacino(t1 - 0.03, Vector3(F * 0.06, 0.85, -0.02))
	c.chiave_angoli(t1 - 0.03, Vector3(F * 0.2, 0.08, F * 0.08))
	c.chiave_busto(t1 - 0.03, Vector3(0.16, F * 0.14, F * 0.12))
	c.chiave_bacino(0.75 * g, Vector3(S * 0.08, 0.96, 0.0))
	c.chiave_angoli(0.75 * g, Vector3(S * 0.1, 0.04, S * 0.12))
	c.chiave_busto(0.75 * g, Vector3(0.1, S * 0.2, S * 0.1))
	c.chiave_bacino(g + 0.04, Vector3(S * 0.1, 0.87, 0.0))
	c.chiave_angoli(g + 0.04, Vector3(S * 0.15, 0.08, S * 0.1))
	c.chiave_busto(g + 0.04, Vector3(0.14, S * 0.16, 0))
	braccia(c, t1, pS, Vector3(0.38, -0.16, 0.0), Vector3(0.3, -0.3, 0.1))
	braccia(c, 0.75 * g, pS, Vector3(0.4, -0.02, 0.0), Vector3(0.4, -0.1, 0.0))
	braccia(c, g + 0.04, pS, Vector3(0.38, -0.12, 0.0), Vector3(0.34, -0.24, 0.12))


# suola: la suola del piede della finta fa rotolare il pallone attraverso il corpo fino al lato scelto, col corpo che
# lo accompagna di lato
static func a_suola(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	var t1 := maxf(t0 + 0.07, 0.22 * g)
	c.tocca(pF, t1, "sole", Vector3(F * 0.2, -0.22, 0), {"rel": Vector3(F * 0.14, 0, 0.46)})
	c.tocca(pF, 0.95 * g, "sole", Vector3(-F * 0.25, -0.22, 0), {"rel": Vector3(S * 0.4, 0, 0.44), "lega": true})
	c.stacca(pS, 0.4 * g)
	c.appoggia_corsa(pS, 0.4 * g + 0.11, 0.16, Vector2(S * 0.1, -0.04), 0.05)
	c.chiave_bacino(t1, Vector3(S * 0.02, 0.91, -0.05))
	c.chiave_angoli(t1, Vector3(F * 0.2, -0.02, 0))
	c.chiave_busto(t1, Vector3(0.06, F * 0.06, F * 0.15))
	c.chiave_bacino(0.9 * g, Vector3(S * 0.1, 0.89, -0.03))
	c.chiave_angoli(0.9 * g, Vector3(S * 0.25, 0.02, S * 0.06))
	c.chiave_busto(0.9 * g, Vector3(0.1, S * 0.09, S * 0.15))
	braccia(c, t1, pS, BR_LARGO, Vector3(0.4, -0.24, -0.1))
	braccia(c, 0.9 * g, pS, Vector3(0.4, -0.2, -0.16), Vector3(0.37, -0.1, 0.12))


# ================================================================ tagli dietro la gamba d'appoggio
# taglio secco: di corsa verso la finta; il piede del lato scelto si pianta oltre il pallone, saltello, e l'interno
# dell'altro piede (punta girata in dentro) arriva da dietro e taglia il pallone dietro la gamba d'appoggio, di lato:
# cambio secco di direzione, il corpo atterra già inclinato da quella parte
static func a_chop(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.chiave_giro(0.5 * g, F * 0.35)
	c.chiave_giro(g, F * 0.3)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.52)})
	c.palla_a(0.95 * g, {"rel": Vector3(F * 0.04, 0, 0.4)})
	# il piede d'appoggio si pianta oltre il pallone, dal lato scelto: il pallone gli passerà dietro
	var tp := maxf(t0 + 0.1, 0.55 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.16, H, 0.2), S * 0.2, 0.08)
	c.stacca(pF, tp - 0.02)
	# l'altro piede si carica largo e alto, punta girata in dentro
	c.passa(pF, 0.86 * g, Vector3(F * 0.36, 0.36, 0.2), Vector3(-S * 1.4, 0.2, 0), 0.04)
	c.chiave_bacino(tp, Vector3(0, 0.88, 0.04))
	c.chiave_angoli(tp, Vector3(0, 0.14, 0))
	c.chiave_busto(tp, Vector3(0.2, 0, 0))
	c.chiave_bacino(0.9 * g, Vector3(S * 0.03, 1.0, 0.08))
	c.chiave_angoli(0.9 * g, Vector3(S * 0.35, 0.1, S * 0.1))
	c.chiave_busto(0.9 * g, Vector3(0.14, S * 0.12, S * 0.35))
	braccia(c, tp, pS, BR_DIETRO, BR_AVANTI)
	braccia(c, 0.9 * g, pS, Vector3(0.4, 0.02, 0.0), Vector3(0.4, -0.02, 0.1))
	c.chiave_sguardo(0.5 * g, 0.4, F * 0.3)
	c.chiave_sguardo(0.9 * g, 1.0, 0.0)


# finta e giro: il corpo si apre verso la finta come per un passaggio o un cross (appoggio accanto al pallone, gamba
# caricata dietro, braccio alto); il piede scende, ma invece di calciare passa davanti al pallone e l'interno lo
# trascina dietro la gamba d'appoggio: il giocatore si gira dall'altra parte e riparte
static func a_cruyff(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.chiave_giro(0.3 * g, F * 0.9)
	c.chiave_giro(0.7 * g, F * 1.15)
	c.chiave_giro(g, F * 1.1)
	c.palla_a(0.08, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(0.34 * g, {"rel": Vector3(F * 0.08, 0, 0.5)})
	c.palla_a(0.9 * g, {"rel": Vector3(F * 0.1, 0, 0.3)})
	# appoggio accanto al pallone (dalla parte del lato scelto, che ora è alle sue spalle)
	var tp := maxf(t0 + 0.1, 0.36 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.22, H, 0.02), 0.0, 0.07)
	c.stacca(pF, tp - 0.03)
	# gamba caricata dietro, ben alta ...
	c.passa(pF, 0.62 * g, Vector3(F * 0.16, 0.66, -0.52), Vector3(0, 1.1, 0), 0.0)
	# ... scende ma passa davanti al pallone, punta girata in dentro
	c.passa_palla(pF, 0.93 * g, Vector3(F * 0.02, 0.16, 0.26), Vector3(S * 1.25, 0.1, 0), 0.02)
	c.chiave_bacino(0.3 * g, Vector3(0, 0.9, 0.0))
	c.chiave_bacino(0.62 * g, Vector3(S * 0.05, 0.95, -0.04))
	c.chiave_angoli(0.62 * g, Vector3(F * 0.35, -0.08, 0))
	c.chiave_busto(0.62 * g, Vector3(-0.14, S * 0.08, F * 0.3))
	c.chiave_bacino(0.95 * g, Vector3(S * 0.06, 0.86, 0.04))
	c.chiave_angoli(0.95 * g, Vector3(S * 0.3, 0.14, S * 0.06))
	c.chiave_busto(0.95 * g, Vector3(0.26, S * 0.08, S * 0.3))
	# braccia da calcio: quello opposto alla gamba che calcia alto e largo, l'altro indietro
	braccia(c, 0.62 * g, pS, Vector3(0.42, 0.1, 0.12), Vector3(0.36, -0.1, -0.26))
	braccia(c, 0.95 * g, pS, Vector3(0.36, -0.18, -0.2), Vector3(0.4, -0.12, 0.2))
	c.chiave_sguardo(0.3 * g, 0.2, 0.0)
	c.chiave_sguardo(0.62 * g, 0.1, 0.0)
	c.chiave_sguardo(0.92 * g, 1.0, 0.0)


# colpo di tacco: appoggio accanto al pallone, l'altro piede gli passa davanti e il tacco lo manda dietro la gamba
# d'appoggio, dal lato scelto
static func a_tacco(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.chiave_giro(0.6 * g, F * 0.3)
	c.palla_a(0.8 * g, {"rel": Vector3(F * 0.02, 0, 0.4)})
	var tp := maxf(t0 + 0.1, 0.4 * g)
	c.appoggia(pS, tp, Vector2(S * 0.2, 0.6), 0.0, 0.07)
	c.stacca(pF, tp - 0.03)
	c.passa_palla(pF, 0.7 * g, Vector3(F * 0.24, 0.24, 0.05), Vector3(-S * 0.5, 0.3, 0), 0.03)
	c.passa_palla(pF, 0.93 * g, Vector3(F * 0.2, 0.14, 0.2), Vector3(-S * 1.1, 0.2, 0), 0.0)
	c.chiave_bacino(tp, Vector3(0, 0.9, 0.02))
	c.chiave_bacino(0.93 * g, Vector3(S * 0.04, 0.92, 0.06))
	c.chiave_angoli(0.93 * g, Vector3(F * 0.2, 0.08, 0))
	c.chiave_busto(0.93 * g, Vector3(0.14, F * 0.06, F * 0.2))
	braccia(c, 0.93 * g, pS, Vector3(0.37, -0.1, 0.1), Vector3(0.36, -0.14, -0.1))
	c.chiave_sguardo(0.6 * g, 0.3, F * 0.45)
	c.chiave_sguardo(g, 0.7, 0.0)


# ================================================================ veronica
# veronica (roulette), in corsa: la suola del primo piede (lato scelto) ferma il pallone e lo tira indietro mentre il
# corpo, che continua ad avanzare, gli gira sopra dando la schiena al difensore; l'altra suola lo riprende e lo porta
# avanti finendo il giro intero (parte B), oltre il difensore dal lato scelto. Giro continuo, sempre nello stesso verso.
const VER_GIRO_A := 2.5        # rad di giro alla fine della parte A (schiena al difensore e oltre)
const VER_B := 0.44            # s: il resto del giro dopo lo scatto

static func a_veronica(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	c.yaw_k = 40.0
	c.yaw_v = 26.0
	var t0 := libera(c, pS)
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
	braccia(c, t1, pS, Vector3(0.36, -0.2, 0.1), Vector3(0.36, -0.22, 0.0))
	braccia(c, g, pS, Vector3(0.4, -0.06, -0.1), Vector3(0.4, -0.08, 0.16))
	c.chiave_sguardo(g, 0.7, -S * 0.3)


static func b_veronica(c: Coreo, S: float, tg: float) -> void:
	var pS := ls(S)
	var pF := ls(-S)
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
	c.appoggia_corsa(pF, tg + 0.38, PASSO_CORSA, Vector2.ZERO, 0.05)
	c.stacca(pS, tg + 0.3)
	c.appoggia_corsa(pS, tg + 0.46, PASSO_CORSA, Vector2.ZERO, 0.1)
	c.stacca(pF, tg + 0.45)
	c.appoggia_corsa(pF, tg + 0.55, PASSO_CORSA, Vector2.ZERO, 0.1)
	c.chiave_bacino(tg + 0.15, Vector3(0, 0.89, 0.0))
	c.chiave_angoli(tg + 0.15, Vector3(0, 0.06, -S * 0.06))
	c.chiave_busto(tg + 0.15, Vector3(0.14, 0, -S * 0.25))
	c.chiave_bacino(tg + dur, Vector3(0, 0.9, 0.02))
	c.chiave_angoli(tg + dur, Vector3(0, 0.18, 0))
	c.chiave_busto(tg + dur, Vector3(0.18, 0, 0))
	braccia(c, tg + 0.15, pS, Vector3(0.4, -0.06, 0.1), Vector3(0.4, -0.06, -0.06))
	braccia(c, tg + dur, pS, BR_DIETRO, BR_AVANTI)
	c.fine = tg + 0.56


# ================================================================ pallonetti (il volo è del motore: ball.finto)
# sombrero: rallentando, la suola tira il pallone verso di sé, la punta gli va sotto e lo alza: pallonetto sopra la
# testa del difensore (gravità vera), e il portatore gli gira intorno e va a riprenderlo dove cade
static func a_sombrero(c: Coreo, S: float, g: float) -> void:
	var pS := ls(S)
	var tk := float(Skill.trova("sombrero").tk)
	var t0 := libera(c, pS)
	var t1 := maxf(t0 + 0.07, 0.22 * tk)
	c.palla_a(0.06, {"rel": Vector3(0, 0, 0.52)})
	c.tocca(pS, t1, "sole", Vector3(0, -0.25, 0), {"rel": Vector3(S * 0.05, 0, 0.52)})
	c.tocca(pS, 0.66 * tk, "sole", Vector3(0, -0.2, 0), {"rel": Vector3(S * 0.05, 0, 0.38), "lega": true})
	c.tocca(pS, tk, "toe", Vector3(0, -0.45, 0), {"rel": Vector3(S * 0.03, 0, 0.42), "h": 0.03})
	c.passa(pS, tk + 0.1, Vector3(S * 0.1, 0.55, 0.5), Vector3(0, -0.5, 0), 0.0)
	c.chiave_bacino(0.66 * tk, Vector3(0, 0.9, -0.06))
	c.chiave_busto(0.66 * tk, Vector3(0.1, 0, 0))
	c.chiave_bacino(tk + 0.05, Vector3(0, 0.95, -0.04))
	c.chiave_angoli(tk + 0.05, Vector3(0, -0.1, 0))
	c.chiave_busto(tk + 0.05, Vector3(-0.14, 0, 0))
	braccia(c, 0.66 * tk, pS, BR_RIPOSO, BR_RIPOSO)
	braccia(c, tk + 0.05, pS, Vector3(0.38, -0.04, 0.0), Vector3(0.37, -0.06, -0.1))


# bicicletta (per Luis: il pallone portato su dietro il polpaccio e alzato col tacco sopra la testa propria e del
# difensore): in corsa il piede del lato scelto si pianta oltre il pallone, che resta fermo sul prato dietro il suo
# tallone mentre il corpo avanza; il collo dell'altro piede lo fa rotolare su per il polpaccio; saltello, e il tacco
# della gamba davanti lo lancia da dietro sopra la testa (da lì è il pallone staccato del motore: gravità vera)
static func a_bicicletta(c: Coreo, S: float, g: float) -> void:
	var pS := ls(S)
	var pF := ls(-S)
	var tk := float(Skill.trova("bicicletta").tk)
	var t0 := libera(c, pS)
	var tp := maxf(t0 + 0.1, 0.3 * tk)
	c.palla_a(0.06, {"rel": Vector3(S * 0.02, 0, 0.5)})
	c.palla_a(tp, {"rel": Vector3(S * 0.02, 0, 0.36)})
	# un piede avanti oltre il pallone: da qui il pallone è fermo sul prato, dietro quel tallone
	c.appoggia_palla(pS, tp, Vector3(S * 0.05, H, 0.2), 0.0, 0.07)
	c.stacca(pF, tp - 0.02)
	c.tocca(pF, 0.5 * tk, "instep", Vector3(0, 0.3, 0), {"resta": true})
	c.tocca(pF, 0.84 * tk, "instep", Vector3(0, -0.15, 0), {"resta": true, "h": 0.4, "lega": true})
	# saltello: la gamba davanti si piega indietro e il tacco colpisce il pallone da sotto
	c.stacca(pS, 0.8 * tk)
	c.tocca(pS, tk, "heel", Vector3(0, 1.15, 0), {"resta": true, "h": 0.58})
	c.passa(pS, tk + 0.08, Vector3(S * 0.1, 0.66, -0.3), Vector3(0, 1.45, 0), 0.0)
	c.appoggia_corsa(pF, 0.84 * tk + 0.09, 0.12, Vector2.ZERO, 0.03)
	c.chiave_bacino(0.5 * tk, Vector3(0, 0.87, 0.04))
	c.chiave_angoli(0.5 * tk, Vector3(0, 0.14, 0))
	c.chiave_busto(0.5 * tk, Vector3(0.24, 0, 0))
	c.chiave_bacino(tk, Vector3(0, 1.0, 0.1))
	c.chiave_angoli(tk, Vector3(0, 0.28, 0))
	c.chiave_busto(tk, Vector3(0.42, 0, 0))
	braccia(c, 0.5 * tk, pS, BR_LARGO, BR_LARGO)
	braccia(c, tk, pS, Vector3(0.3, -0.28, -0.24), Vector3(0.32, -0.24, -0.22))
	c.chiave_sguardo(0.5 * tk, 1.0, 0.0)
	c.chiave_sguardo(tk, 0.3, 0.0)
	c.chiave_sguardo(tk + 0.2, 1.0, 0.0)
