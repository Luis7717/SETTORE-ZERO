# I giochetti del dribbling della persona (Luis 2026-11-26: "fanno pena, falli veri e aggiungine"): 16 movimenti del
# calcio vero costruiti con coreo.gd (piedi fermi a terra, passi programmati, pallone mosso solo dai tocchi).
# Quale giochetto e quanto dura lo decide il motore (sim/skill.gd: evento 'dribble' con skill e show); qui si decide
# come si muovono gambe, busto, braccia e pallone. Niente è copiato da altri giochi: sono i gesti del calcio.
#
# Ogni giochetto ha due parti:
#   A (a_ID, dura `g` = show): la finta davanti al difensore. Il motore intanto porta il corpo piano di lato verso la
#     finta (o dritto, o dal lato scelto: `lat` di sim/skill.gd);
#   B (b_ID, dall'evento 'dribble_go'): il tocco che porta via il pallone dal lato scelto e i primi passi di corsa nel
#     verso nuovo (il motore scatta oltre il difensore).
# Lati: S = lato scelto (+1 = sinistra del portatore), F = −S (finta); pS / pF = piede di quel lato.
# Riferimento del corpo: x sinistra, y su, z avanti, m del modello (a schermo ×1,25).
extends RefCounted

const Coreo := preload("coreo.gd")
const Corpo := preload("corpo.gd")

const IDS := ["finta", "stopgo", "suola", "doppiopasso", "croqueta", "fintatiro", "chop", "cruyff", "tacco", "bicicletta",
	"elastico", "tunnel", "veronica", "elastico_inv", "sombrero", "arcobaleno"]
const FINE_GO := 0.4           # la coreografia finisce tanto dopo lo scatto (poi il clip di corsa)
const PASSO_CORSA := 0.085     # s tra due appoggi nei primi passi dello scatto
const H := Corpo.ANKLE_H
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
		"bicicletta": a_bicicletta(c, S, g)
		"elastico": a_elastico(c, S, g)
		"tunnel": a_tunnel(c, S, g)
		"veronica": a_veronica(c, S, g)
		"elastico_inv": a_elastico_inv(c, S, g)
		"sombrero": a_sombrero(c, S, g)
		"arcobaleno": a_arcobaleno(c, S, g)
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
			via(c, S, tg, pS, "inside", Vector3(S * 1.15, 0.1, 0), 0.08, {"rel": Vector3(S * 0.03, 0, 0.52)})
		"fintatiro":
			via(c, S, tg, pF, "inside", interno(S, 0.7), 0.05)
		"chop":
			via(c, S, tg, pF, "inside", Vector3(-S * 1.45, 0.1, 0), 0.03, {"salto": 0.05})
		"cruyff":
			via(c, S, tg, pF, "inside", Vector3(S * 1.25, 0.05, 0), 0.04, {"fine": 0.46})
		"tacco":
			via(c, S, tg, pF, "heel", Vector3(-S * 1.15, 0.2, 0), 0.04)
		"elastico":
			via(c, S, tg, pF, "inside", interno(S, 1.2), 0.05)
		"elastico_inv":
			via(c, S, tg, pS, "outside", esterno(S, 0.9), 0.05)
		"tunnel":
			b_tunnel(c, S, tg)
		"veronica":
			b_veronica(c, S, tg)
		"sombrero", "arcobaleno":
			via(c, S, tg, pS, "", Vector3.ZERO, 0.0, {"volo": true, "fine": float(c.dati.get("atterra", tg + 0.4)) - tg + 0.06})
		_:   # finta, doppio passo, bicicletta
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
	c.appoggia(o, 0.06, Vector2(segno(o) * 0.12, 0.1), 0.0, 0.04)
	if c.a_terra(s):
		c.stacca(s, 0.06)
	return 0.07


static func braccia(c: Coreo, tt: float, pS: String, bS: Vector3, bF: Vector3) -> void:
	c.chiave_braccio(pS, tt, bS)
	c.chiave_braccio(altro(pS), tt, bF)


# il pallone che il portatore si portava avanti si ferma subito lì davanti (z m del modello dal corpo com'è adesso) e
# ci resta: nelle finte di corpo è il corpo che se ne va, non il pallone
static func ferma(c: Coreo, z: float) -> void:
	var q := davanti(c, z)
	c.palla_a(0.1, {"mondo": q})
	c.palla_a(9.0, {"mondo": q})


# punto fisso nel mondo davanti al corpo com'è adesso (z avanti, x a sinistra; m del modello), a terra
static func davanti(c: Coreo, z: float, x: float = 0.0) -> Vector3:
	var q := c.mondo_a(c.t, Vector3(x, 0, z))
	return Vector3(q.x, 0.0, q.z)


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
	c.appoggia(piede, t1, Vector2(segno(piede) * 0.1, 0.3), 0.0, 0.08)
	c.stacca(o, maxf(tg + 0.05, t1 - 0.04))
	var a := o
	var tp := t1 + PASSO_CORSA
	while tp < tg + fine + 0.1:
		c.appoggia(a, tp, Vector2(segno(a) * 0.1, 0.32), 0.0, 0.11)
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


# ================================================================ finte di corpo (il pallone resta lì, il corpo va via)
# finta di corpo: passo largo e basso dal lato della finta, spalla che cade di là e sguardo di là; il pallone resta
# dov'era e allo scatto l'esterno dell'altro piede lo porta via
static func a_finta(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	ferma(c, 0.54)
	c.appoggia(pF, maxf(t0 + 0.1, 0.55 * g), Vector2(F * 0.52, 0.16), F * 0.35, 0.08)
	c.chiave_bacino(0.55 * g, Vector3(F * 0.17, 0.85, 0.0))
	c.chiave_angoli(0.55 * g, Vector3(F * 0.35, 0.04, F * 0.1))
	c.chiave_busto(0.55 * g, Vector3(0.14, F * 0.25, F * 0.3))
	c.chiave_bacino(g, Vector3(F * 0.2, 0.84, 0.02))
	c.chiave_angoli(g, Vector3(F * 0.38, 0.05, F * 0.12))
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
	ferma(c, 0.56)
	var tp := maxf(t0 + 0.1, 0.3 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.24, H, -0.08), S * 0.15, 0.06)
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


# tunnel: mezza finta di corpo per far allargare le gambe al difensore, poi (parte B) il pallone gli passa in mezzo
static func a_tunnel(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	ferma(c, 0.54)
	c.appoggia(pF, maxf(t0 + 0.1, 0.55 * g), Vector2(F * 0.4, 0.12), F * 0.25, 0.07)
	c.chiave_bacino(0.6 * g, Vector3(F * 0.12, 0.87, 0.0))
	c.chiave_angoli(0.6 * g, Vector3(F * 0.25, 0.04, F * 0.06))
	c.chiave_busto(0.6 * g, Vector3(0.14, F * 0.18, F * 0.22))
	c.chiave_bacino(g, Vector3(F * 0.12, 0.86, 0.02))
	braccia(c, 0.6 * g, pS, Vector3(0.12, -0.26, 0.28), Vector3(0.37, -0.14, 0.0))
	c.chiave_sguardo(0.5 * g, 0.2, F * 0.5)
	c.chiave_sguardo(g, 1.0, 0.0)


static func b_tunnel(c: Coreo, S: float, tg: float) -> void:
	var pS := ls(S)
	var tt := tg + 0.05
	var b0 := c.pallone_previsto(tt)
	var d := c.altro()
	if d == Vector3.INF:
		via(c, S, tg, pS, "outside", esterno(S, 0.85), 0.05)
		return
	d.y = 0.0
	var dir := (d - b0).normalized()
	# la punta guarda il difensore: giro del piede rispetto al corpo com'è al momento del tocco
	var ang := wrapf(atan2(dir.x, dir.z) - c.yaw_a(tt), -PI, PI)
	var t2 := tt + clampf(b0.distance_to(d) / 9.0, 0.1, 0.25)
	# passato tra le gambe il pallone piega verso il lato scelto, dove il portatore lo va a riprendere
	var lato := Vector3(dir.z, 0, -dir.x) * S
	via(c, S, tg, pS, "toe", Vector3(clampf(ang, -1.2, 1.2), 0.25, 0), 0.05, {"fine": 0.62,
		"palla": [[t2, {"altro": true}], [t2 + 0.13, {"mondo": d + dir * 1.0 + lato * 0.7}]]})


# ================================================================ passi sopra il pallone
# giro del piede `s` intorno al davanti del pallone, da dentro a fuori (verso il lato dir), dal tempo ta per dur s;
# largo = quanto fuori appoggia (m del modello dal pallone)
static func _passo_sopra(c: Coreo, s: String, dir: float, ta: float, dur: float, largo: float, alto: float) -> void:
	c.passa_palla(s, ta + 0.38 * dur, Vector3(-dir * 0.1, alto, -0.06), Vector3(dir * 0.35, 0.25, 0), 0.03)
	c.passa_palla(s, ta + 0.7 * dur, Vector3(dir * 0.05, alto + 0.03, 0.22), Vector3(-dir * 0.25, 0.3, 0), 0.0)
	c.appoggia_palla(s, ta + dur, Vector3(dir * largo, H, -0.16), dir * 0.4, 0.02)


# doppio passo: due passi larghi e lenti sopra il pallone (prima dal lato scelto, poi dalla finta, con tutto il corpo
# che ci va dietro), poi l'esterno lo porta via
static func a_doppiopasso(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.palla_a(0.1, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(g + 0.05, {"rel": Vector3(0, 0, 0.44)})
	var d1 := 0.19
	var ta := t0
	_passo_sopra(c, pS, S, ta, d1, 0.3, 0.24)
	var tb := ta + d1 - 0.02
	c.stacca(pF, tb)
	var d2 := minf(0.2, g - 0.02 - tb)
	_passo_sopra(c, pF, F, tb, d2, 0.38, 0.24)
	c.chiave_bacino(ta + 0.75 * d1, Vector3(S * 0.08, 0.88, 0.0))
	c.chiave_angoli(ta + 0.75 * d1, Vector3(S * 0.3, 0.08, S * 0.06))
	c.chiave_busto(ta + 0.75 * d1, Vector3(0.16, S * 0.16, S * 0.22))
	c.chiave_bacino(tb + 0.85 * d2, Vector3(F * 0.15, 0.85, 0.0))
	c.chiave_angoli(tb + 0.85 * d2, Vector3(F * 0.38, 0.08, F * 0.11))
	c.chiave_busto(tb + 0.85 * d2, Vector3(0.18, F * 0.25, F * 0.3))
	braccia(c, ta + 0.75 * d1, pS, Vector3(0.37, -0.16, -0.02), Vector3(0.12, -0.26, 0.28))
	braccia(c, tb + 0.85 * d2, pS, Vector3(0.12, -0.26, 0.28), Vector3(0.38, -0.1, -0.04))
	c.chiave_sguardo(tb + 0.6 * d2, 0.5, F * 0.4)


# bicicletta: quattro passi sopra il pallone veloci e stretti, uno dopo l'altro (la "pedalata"), busto dritto e
# braccia che pompano; il pallone intanto rotola avanti
static func a_bicicletta(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.palla_a(0.1, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(g + 0.05, {"rel": Vector3(0, 0, 0.46)})
	var n := 4
	var per := (g - 0.03 - t0) / float(n)
	for i in n:
		var s := pS if i % 2 == 0 else pF
		var dir := S if i % 2 == 0 else F
		var ta := t0 + per * i
		if i > 0:
			c.stacca(s, ta - 0.015)
		_passo_sopra(c, s, dir, ta, per + 0.02, 0.2 if i < n - 1 else 0.32, 0.2)
		var tm := ta + 0.7 * per
		var k := 0.6 if i < n - 1 else 1.0
		c.chiave_bacino(tm, Vector3(dir * 0.06 * k, 0.93 - 0.05 * k, 0.0))
		c.chiave_angoli(tm, Vector3(dir * 0.24 * k, 0.03, dir * 0.05 * k))
		c.chiave_busto(tm, Vector3(0.08, dir * 0.12 * k, dir * 0.22 * k))
		braccia(c, tm, ls(dir), Vector3(0.36, -0.2, -0.14), Vector3(0.14, -0.2, 0.3))
	c.chiave_sguardo(g * 0.5, 0.6, 0.0)


# ================================================================ il pallone fa la finta
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


# croqueta: l'interno di un piede passa il pallone di lato all'interno dell'altro, con un saltello di tutto il corpo
static func a_croqueta(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pF)
	var t1 := maxf(t0 + 0.09, 0.6 * g)
	c.tocca(pF, t1, "inside", Vector3(0, 0.05, 0), {"rel": Vector3(F * 0.14, 0, 0.42)})
	c.tocca(pS, g + 0.08, "inside", Vector3(S * 1.15, 0.1, 0), {"rel": Vector3(S * 0.5, 0, 0.42)})
	c.appoggia(pF, t1 + 0.09, Vector2(F * 0.02, 0.1), 0.0, 0.05)
	c.chiave_bacino(t1 - 0.03, Vector3(F * 0.08, 0.86, -0.02))
	c.chiave_angoli(t1 - 0.03, Vector3(F * 0.15, 0.06, F * 0.06))
	c.chiave_busto(t1 - 0.03, Vector3(0.14, F * 0.12, F * 0.1))
	c.chiave_bacino(g + 0.02, Vector3(S * 0.08, 0.95, 0.0))
	c.chiave_angoli(g + 0.02, Vector3(S * 0.1, 0.04, S * 0.07))
	c.chiave_busto(g + 0.02, Vector3(0.1, S * 0.12, 0))
	braccia(c, t1, pS, BR_LARGO, BR_LARGO)
	braccia(c, g + 0.02, pS, Vector3(0.38, -0.05, 0.0), Vector3(0.36, -0.2, 0.1))


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
	c.appoggia(pS, 0.4 * g + 0.11, Vector2(S * 0.2, -0.04), S * 0.2, 0.05)
	c.chiave_bacino(t1, Vector3(S * 0.02, 0.91, -0.05))
	c.chiave_angoli(t1, Vector3(F * 0.2, -0.02, 0))
	c.chiave_busto(t1, Vector3(0.06, F * 0.06, F * 0.15))
	c.chiave_bacino(0.9 * g, Vector3(S * 0.1, 0.89, -0.03))
	c.chiave_angoli(0.9 * g, Vector3(S * 0.25, 0.02, S * 0.06))
	c.chiave_busto(0.9 * g, Vector3(0.1, S * 0.09, S * 0.15))
	braccia(c, t1, pS, BR_LARGO, Vector3(0.4, -0.24, -0.1))
	braccia(c, 0.9 * g, pS, Vector3(0.4, -0.2, -0.16), Vector3(0.37, -0.1, 0.12))


# ================================================================ tagli dietro la gamba d'appoggio
# taglio alla Ronaldo: di corsa verso la finta, appoggio avanti, saltello e l'interno dell'altro piede taglia il
# pallone dietro la gamba d'appoggio: cambio secco di direzione
static func a_chop(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.chiave_giro(0.6 * g, F * 0.55)
	c.chiave_giro(g, F * 0.6)
	c.palla_a(0.9 * g, {"rel": Vector3(F * 0.06, 0, 0.36)})
	var tp := maxf(t0 + 0.1, 0.5 * g)
	c.appoggia(pS, tp, Vector2(S * 0.14, 0.58), 0.0, 0.08)
	c.stacca(pF, tp - 0.02)
	c.passa(pF, 0.9 * g, Vector3(F * 0.26, 0.34, 0.3), Vector3(-S * 1.3, 0.3, 0), 0.04)
	c.chiave_bacino(tp, Vector3(0, 0.9, 0.04))
	c.chiave_angoli(tp, Vector3(0, 0.12, 0))
	c.chiave_busto(tp, Vector3(0.18, 0, 0))
	c.chiave_bacino(0.92 * g, Vector3(S * 0.02, 0.97, 0.08))
	c.chiave_angoli(0.92 * g, Vector3(S * 0.3, 0.1, 0))
	c.chiave_busto(0.92 * g, Vector3(0.16, S * 0.06, S * 0.3))
	braccia(c, tp, pS, BR_DIETRO, BR_AVANTI)
	braccia(c, 0.92 * g, pS, Vector3(0.38, -0.04, 0.0), Vector3(0.36, -0.06, 0.12))


# giro alla Cruyff: finge il passaggio (gamba caricata, braccia larghe, corpo aperto verso la finta), il piede passa
# davanti al pallone e l'interno lo aggancia dietro la gamba d'appoggio: mezzo giro e via
static func a_cruyff(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	var t0 := libera(c, pS)
	c.chiave_giro(0.45 * g, F * 0.5)
	c.chiave_giro(g, F * 0.55)
	c.palla_a(0.85 * g, {"rel": Vector3(F * 0.04, 0, 0.42)})
	var tp := maxf(t0 + 0.1, 0.36 * g)
	c.appoggia(pS, tp, Vector2(S * 0.24, 0.6), 0.0, 0.07)
	c.stacca(pF, tp - 0.03)
	c.passa(pF, 0.58 * g, Vector3(F * 0.18, 0.56, -0.46), Vector3(0, 0.9, 0), 0.0)
	c.passa_palla(pF, 0.92 * g, Vector3(F * 0.03, 0.16, 0.27), Vector3(S * 1.2, 0.1, 0), 0.02)
	c.chiave_bacino(0.58 * g, Vector3(S * 0.04, 0.93, -0.02))
	c.chiave_angoli(0.58 * g, Vector3(F * 0.3, -0.05, 0))
	c.chiave_busto(0.58 * g, Vector3(-0.08, S * 0.06, F * 0.25))
	c.chiave_bacino(0.95 * g, Vector3(S * 0.06, 0.87, 0.04))
	c.chiave_angoli(0.95 * g, Vector3(S * 0.25, 0.12, S * 0.05))
	c.chiave_busto(0.95 * g, Vector3(0.24, S * 0.07, S * 0.3))
	braccia(c, 0.58 * g, pS, Vector3(0.38, -0.04, 0.1), Vector3(0.36, -0.1, -0.2))
	braccia(c, 0.95 * g, pS, Vector3(0.36, -0.18, -0.2), Vector3(0.4, -0.12, 0.2))
	c.chiave_sguardo(0.5 * g, 0.15, F * 0.3)
	c.chiave_sguardo(0.9 * g, 1.0, 0.0)


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
# veronica (roulette): suola del primo piede che ferma e tira indietro il pallone mentre il corpo gira dando la
# schiena al difensore; l'altra suola lo riprende e lo porta avanti finendo il giro intero (parte B, oltre il difensore)
static func a_veronica(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := ls(S)
	var pF := ls(F)
	c.yaw_k = 34.0
	c.yaw_v = 24.0
	var t0 := libera(c, pF)
	var t1 := maxf(t0 + 0.07, 0.3 * g)
	c.tocca(pF, t1, "sole", Vector3(0, -0.25, 0), {"rel0": Vector3(F * 0.03, 0, 0.5)})
	c.tocca(pF, g + 0.02, "sole", Vector3(0, -0.2, 0), {"rel0": Vector3(S * 0.1, 0, 0.26), "lega": true})
	c.chiave_giro(t1, 0.0)
	c.chiave_giro(g, -S * 1.5)
	# il piede che regge fa perno e si rimette sotto il corpo girato
	c.stacca(pS, 0.55 * g)
	c.appoggia(pS, 0.55 * g + 0.1, Vector2(S * 0.12, -0.06), 0.0, 0.03)
	c.chiave_bacino(t1, Vector3(0, 0.9, -0.05))
	c.chiave_angoli(t1, Vector3(0, 0.0, 0))
	c.chiave_busto(t1, Vector3(0.08, 0, 0))
	c.chiave_bacino(g, Vector3(0, 0.88, 0.0))
	c.chiave_busto(g, Vector3(0.14, 0, -S * 0.25))
	braccia(c, t1, pS, BR_LARGO, BR_LARGO)
	braccia(c, g, pS, Vector3(0.38, -0.05, 0.0), Vector3(0.38, -0.1, 0.1))


static func b_veronica(c: Coreo, S: float, tg: float) -> void:
	var pS := ls(S)
	var pF := ls(-S)
	# quanto manca per finire il giro (sempre nello stesso verso, −S) fino al verso di corsa del motore
	var manca := fposmod(S * (c.yaw - c.yaw_motore()), TAU)
	if manca < 2.0:
		manca += TAU
	var dur := 0.44
	c.taglia(tg)
	c.yaw_fisso_fino = tg
	c.chiave_giro(tg, S * manca)
	c.chiave_giro(tg + dur * 0.5, S * manca * 0.48)
	c.chiave_giro(tg + dur, 0.0)
	c.chiave_sguardo(tg, 1.0)
	# il primo piede lascia il pallone e appoggia; l'altra suola lo prende (schiena al difensore) e lo porta avanti
	c.appoggia(pF, tg + 0.08, Vector2(-S * 0.12, 0.02), 0.0, 0.04)
	c.stacca(pS, tg + 0.03)
	c.tocca(pS, tg + 0.13, "sole", Vector3(0, -0.2, 0), {"rel0": Vector3(S * 0.16, 0, 0.26)})
	c.tocca(pS, tg + 0.3, "sole", Vector3(0, -0.2, 0), {"rel0": Vector3(S * 0.18, 0, 0.5), "lega": true})
	c.palla_a(tg + 0.54, {"moto": true})
	c.appoggia(pS, tg + 0.39, Vector2(S * 0.1, 0.26), 0.0, 0.05)
	c.stacca(pF, tg + 0.3)
	c.appoggia(pF, tg + 0.47, Vector2(-S * 0.1, 0.3), 0.0, 0.1)
	c.stacca(pS, tg + 0.46)
	c.appoggia(pS, tg + 0.56, Vector2(S * 0.1, 0.32), 0.0, 0.1)
	c.chiave_bacino(tg + 0.15, Vector3(0, 0.9, 0.0))
	c.chiave_angoli(tg + 0.15, Vector3(0, 0.04, 0))
	c.chiave_busto(tg + 0.15, Vector3(0.1, 0, -S * 0.2))
	c.chiave_bacino(tg + dur, Vector3(0, 0.9, 0.02))
	c.chiave_angoli(tg + dur, Vector3(0, 0.18, 0))
	c.chiave_busto(tg + dur, Vector3(0.18, 0, 0))
	braccia(c, tg + 0.15, pS, Vector3(0.38, -0.04, 0.0), Vector3(0.38, -0.06, 0.06))
	braccia(c, tg + dur, pS, BR_DIETRO, BR_AVANTI)
	c.fine = tg + 0.56


# ================================================================ pallonetti
# sombrero: la suola tira il pallone verso di sé, la punta gli va sotto e lo alza: pallonetto sopra la testa del
# difensore, e il portatore gli gira intorno
static func a_sombrero(c: Coreo, S: float, g: float) -> void:
	var pS := ls(S)
	var t0 := libera(c, pS)
	var t1 := maxf(t0 + 0.07, 0.18 * g)
	c.tocca(pS, t1, "sole", Vector3(0, -0.25, 0), {"rel": Vector3(S * 0.05, 0, 0.5)})
	c.tocca(pS, 0.5 * g, "sole", Vector3(0, -0.2, 0), {"rel": Vector3(S * 0.05, 0, 0.36), "lega": true})
	var tf := 0.74 * g
	c.tocca(pS, tf, "toe", Vector3(0, -0.45, 0), {"rel": Vector3(S * 0.05, 0, 0.36), "h": 0.03})
	c.passa(pS, tf + 0.1, Vector3(S * 0.1, 0.5, 0.5), Vector3(0, -0.5, 0), 0.0)
	_volo(c, tf, 0.34, 2.75, 0.62)
	c.chiave_bacino(0.5 * g, Vector3(0, 0.9, -0.06))
	c.chiave_busto(0.5 * g, Vector3(0.1, 0, 0))
	c.chiave_bacino(tf + 0.05, Vector3(0, 0.95, -0.04))
	c.chiave_angoli(tf + 0.05, Vector3(0, -0.1, 0))
	c.chiave_busto(tf + 0.05, Vector3(-0.14, 0, 0))
	braccia(c, 0.5 * g, pS, BR_RIPOSO, BR_RIPOSO)
	braccia(c, tf + 0.05, pS, Vector3(0.38, -0.04, 0.0), Vector3(0.37, -0.06, -0.1))


# colpo dell'arcobaleno: il pallone stretto tra i piedi, un collo lo fa salire dietro il polpaccio dell'altra gamba e
# il tacco lo lancia da dietro sopra la propria testa e quella del difensore
static func a_arcobaleno(c: Coreo, S: float, g: float) -> void:
	var pS := ls(S)
	var pF := ls(-S)
	var t0 := libera(c, pS)
	var b0 := davanti(c, 0.56, S * 0.04)
	c.palla_a(0.3 * g, {"mondo": b0})
	# un piede avanti oltre il pallone, l'altro dietro: il pallone è in mezzo
	var tp := maxf(t0 + 0.1, 0.28 * g)
	c.appoggia_palla(pS, tp, Vector3(S * 0.06, H, 0.24), 0.0, 0.07)
	c.stacca(pF, tp - 0.03)
	c.tocca(pF, 0.46 * g, "instep", Vector3(0, 0.25, 0), {"mondo": b0})
	c.tocca(pF, 0.66 * g, "instep", Vector3(0, -0.2, 0), {"mondo": b0, "h": 0.34, "lega": true})
	var tf := 0.78 * g
	c.stacca(pS, 0.62 * g)
	c.tocca(pS, tf, "heel", Vector3(0, 1.1, 0), {"mondo": b0, "h": 0.62})
	c.passa(pS, tf + 0.08, Vector3(S * 0.1, 0.62, -0.3), Vector3(0, 1.4, 0), 0.0)
	c.appoggia(pF, 0.66 * g + 0.08, Vector2(-S * 0.1, 0.02), 0.0, 0.03)
	_volo(c, tf, 0.36, 3.1, 0.7)
	c.chiave_bacino(0.46 * g, Vector3(0, 0.88, 0.06))
	c.chiave_angoli(0.46 * g, Vector3(0, 0.12, 0))
	c.chiave_busto(0.46 * g, Vector3(0.22, 0, 0))
	c.chiave_bacino(tf, Vector3(0, 0.99, 0.12))
	c.chiave_angoli(tf, Vector3(0, 0.26, 0))
	c.chiave_busto(tf, Vector3(0.4, 0, 0))
	braccia(c, 0.46 * g, pS, BR_LARGO, BR_LARGO)
	braccia(c, tf, pS, Vector3(0.28, -0.3, -0.22), Vector3(0.3, -0.26, -0.2))
	c.chiave_sguardo(tf, 0.3, 0.0)
	c.chiave_sguardo(tf + 0.2, 1.0, 0.0)


# volo del pallone dal tocco a tf: sale fino sopra la testa del difensore (alto `su` m, dopo `t_su` s) e scende sul
# pallone del motore, davanti al portatore che intanto gli è girato intorno (`t_giu` s dal tocco)
static func _volo(c: Coreo, tf: float, t_su: float, su: float, t_giu: float) -> void:
	if c.altro() == Vector3.INF:
		c.palla_a(tf + t_su, {"mondo": davanti(c, 1.6), "h": su, "arco": 0.6})
	else:   # (dove sta il difensore in quel momento: intanto indietreggia)
		c.palla_a(tf + t_su, {"altro": true, "h": su, "arco": 0.6})
	c.palla_a(tf + t_giu, {"moto": true, "arco": 0.6})
	c.dati["atterra"] = tf + t_giu
