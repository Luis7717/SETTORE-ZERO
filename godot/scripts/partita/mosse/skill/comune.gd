# Aiuti e costanti in comune dei giochetti del dribbling (un file per giochetto in questa cartella; registro in
# ../coreo_skill.gd). Chi lavora a un solo giochetto NON tocca questo file: se gli serve un aiuto diverso lo scrive
# nel file del suo giochetto.
# Lati: S = lato scelto (+1 = sinistra del portatore), F = −S (finta); pS / pF = piede di quel lato.
# Riferimento del corpo: x sinistra, y su, z avanti, m del modello (a schermo ×1,25).
extends RefCounted

const Coreo := preload("../coreo.gd")
const Corpo := preload("../corpo.gd")
const Skill := preload("res://sim/skill.gd")
const Duel := preload("res://sim/duel.gd")

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


# giro del piede `s` intorno al davanti del pallone, da dentro a fuori (verso il lato dir), dal tempo ta per dur s;
# largo = quanto fuori appoggia (m del modello dal pallone), alto = quanto alto passa, dietro = quanto dietro appoggia
static func passo_sopra(c: Coreo, s: String, dir: float, ta: float, dur: float, largo: float, alto: float, dietro: float = -0.16) -> void:
	c.passa_palla(s, ta + 0.38 * dur, Vector3(-dir * 0.1, alto, -0.06), Vector3(dir * 0.35, 0.25, 0), 0.03)
	c.passa_palla(s, ta + 0.7 * dur, Vector3(dir * 0.05, alto + 0.03, 0.22), Vector3(-dir * 0.25, 0.3, 0), 0.0)
	c.appoggia_palla(s, ta + dur, Vector3(dir * largo, H, dietro), dir * 0.4, 0.02)
