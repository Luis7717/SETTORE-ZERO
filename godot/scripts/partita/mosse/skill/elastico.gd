# Giochetto del dribbling "Elastico" (id `elastico`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
#
# Qui c'è anche il motore in comune dei tre elastici (elastico, elastico_inv, elastico3; Luis 2026-11-27: "da rendere
# più fluidi"): il pallone non va più a scatti da un tocco all'altro con una pausa in mezzo, ma segue UNA curva morbida
# davanti al corpo (`nodi`: gli estremi di lato, dove si ferma un attimo e torna indietro; tra un estremo e l'altro parte
# piano, corre e rallenta), e lo stesso piede lo accompagna incollato: con l'esterno quando va verso il suo lato, con
# l'interno quando torna; a ogni estremo il piede gira intorno al pallone (GIRO s) mentre il pallone quasi fermo cambia
# verso. Il gesto continua uguale attraverso lo scatto del motore (parte B): nessun tocco secco in mezzo.
extends RefCounted

const Coreo := preload("../coreo.gd")
const Corpo := preload("../corpo.gd")
const K := preload("comune.gd")

const CAMPIONE := 0.01        # s: un punto della curva del pallone ogni tanto (tra due punti va dritto: non si vede)
const GIRO := 0.08            # s: a un estremo il piede passa dall'esterno all'interno (o viceversa) in tanto
const GIRO_ALTO := 0.15       # m del modello: ... alzandosi di tanto per scavalcare il pallone
const FINE_CAMBIO := 0.08     # s dopo lo scatto: l'ultimo cambio ha portato il pallone dal lato scelto (poi si corre)
const SALTELLO_T := 0.07      # s in aria del piede d'appoggio a ogni saltello


# da 0 a 1 partendo piano, correndo in mezzo e rallentando (mezza onda): niente scatti agli estremi
static func forma(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(u, 0.0, 1.0))


## pallone a tt sulla curva dei nodi [[t, Vector3 davanti al corpo (x sinistra, z avanti; m del modello)], ...]
static func punto(nodi: Array, tt: float) -> Vector3:
	if tt <= float(nodi[0][0]):
		return nodi[0][1]
	for i in nodi.size() - 1:
		var t1 := float(nodi[i + 1][0])
		if tt <= t1:
			var t0 := float(nodi[i][0])
			return (nodi[i][1] as Vector3).lerp(nodi[i + 1][1], forma((tt - t0) / maxf(1e-4, t1 - t0)))
	return nodi.back()[1]


# con che parte del piede si accompagna il pallone nel tratto i: esterno se va verso il lato di quel piede
static func parte(d: Dictionary, i: int) -> String:
	var nodi: Array = d.nodi
	var dx := ((nodi[i + 1][1] as Vector3).x - (nodi[i][1] as Vector3).x) * K.segno(String(d.piede))
	return "outside" if dx > 0.0 else "inside"


# piede (giro, punta in giù, inclinato) nel tratto: k = 0 all'inizio, 1 alla fine; nell'ultimo tratto finisce più
# girato (spinge il pallone anche in avanti, dove si scatta)
static func angolo(part: String, piede: String, k: float, ultimo: bool) -> Vector3:
	var sg := K.segno(piede)
	if part == "outside":   # punta girata in dentro: l'esterno guarda di lato e un po' avanti
		return Vector3(-sg * lerpf(0.3, 0.8 if ultimo else 0.5, k), 0.15, 0)
	return Vector3(sg * lerpf(0.25, 0.7 if ultimo else 0.45, k), 0.1, 0)


## mette nella coreografia la curva del pallone e i tocchi del piede di d = {piede, nodi} (solo quelli dopo `da`: la
## parte B li rimette dopo che lo scatto ha tagliato i movimenti programmati dei piedi)
static func piano(c: Coreo, d: Dictionary, da: float = -1.0) -> void:
	var nodi: Array = d.nodi
	var piede := String(d.piede)
	var n := nodi.size()
	if da < 0.0:   # la curva del pallone (una volta sola: allo scatto il pallone continua come programmato)
		var tt := float(nodi[0][0]) + CAMPIONE
		while tt < float(nodi[n - 1][0]) - 0.5 * CAMPIONE:
			c.palla_a(tt, {"rel0": punto(nodi, tt)})
			tt += CAMPIONE
	for i in n - 1:
		var ultimo := i == n - 2
		var ta := float(nodi[i][0]) + (0.5 * GIRO if i > 0 else 0.0)
		var tb := float(nodi[i + 1][0]) - (0.0 if ultimo else 0.5 * GIRO)
		if tb <= da + 0.012:
			continue
		var part := parte(d, i)
		if ta > da:
			# il piede arriva sul pallone (dalla corsa, o girandogli intorno dall'altra parte)
			c.tocca(piede, ta, part, angolo(part, piede, 0.0, ultimo), {"rel0": punto(nodi, ta)}, GIRO_ALTO if i > 0 else 0.05)
		else:
			# era già sul pallone in questo tratto: ci resta (da dov'è adesso)
			var tr := da + 0.006
			c.tocca(piede, tr, part, angolo(part, piede, Corpo.smooth((tr - ta) / (tb - ta)), ultimo), {"rel0": punto(nodi, tr)}, 0.0)
		c.tocca(piede, tb, part, angolo(part, piede, 1.0, ultimo), {"rel0": punto(nodi, tb), "lega": true})


## il piede d'appoggio `s` non resta piantato mentre il corpo corre: un saltello a ogni tempo di `quando` (se all'inizio
## è in volo il primo è il suo appoggio, quello di K.libera), e l'ultimo poco prima dello scatto (a `g`): atterra più
## avanti del corpo, che allo scatto gli passa sopra di corsa mentre l'altro piede finisce il cambio (`lato` = tanto
## più a sinistra, m del modello: verso dove si scatterà)
static func saltelli(c: Coreo, s: String, quando: Array, g: float, lato: float = 0.0) -> void:
	for i in quando.size():
		if i == 0 and not c.a_terra(s):
			continue
		var ts := float(quando[i])
		c.stacca(s, ts)
		c.appoggia_corsa(s, ts + SALTELLO_T, 0.18, Vector2.ZERO, 0.05)
	c.stacca(s, g - 0.02 - SALTELLO_T)
	c.appoggia_corsa(s, g - 0.02, 0.24, Vector2(lato, 0.0), 0.05)


## parte B in comune: lo scatto taglia passi e chiavi del corpo, il pallone continua sulla sua curva col piede
## incollato fino all'ultimo nodo, poi i primi passi di corsa e il pallone torna quello del motore
static func esci(c: Coreo, S: float, tg: float) -> void:
	var d: Dictionary = c.dati.get("el", {})
	if d.is_empty():
		K.via(c, S, tg, K.ls(-S), "inside", K.interno(S, 1.2), 0.04)
		return
	var te := float((d.nodi as Array).back()[0])
	K.via(c, S, tg, String(d.piede), "inside", Vector3.ZERO, maxf(0.03, te - tg), {"volo": true})
	piano(c, d, tg)
	c.palla_a(maxf(te + 0.05, tg + K.FINE_GO), {"moto": true})


# elastico: l'esterno del piede della finta accompagna il pallone fuori (e il corpo ci va dietro), il piede gli gira
# intorno e l'interno lo riporta attraverso il corpo dal lato scelto, in un gesto solo
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := 0.17 * g
	var ta := 0.7 * g
	var d := {"piede": pF, "nodi": [
		[t0, Vector3(F * 0.03, 0, 0.56)],
		[ta, Vector3(F * 0.5, 0, 0.54)],
		[g + FINE_CAMBIO, Vector3(S * 0.07, 0, 0.48)]]}
	c.dati["el"] = d
	saltelli(c, pS, [0.26 * g], g)
	K.libera(c, pF)
	piano(c, d)
	# il corpo segue il pallone fuori (bacino giù e verso la finta, busto piegato sopra), poi torna con lui
	c.chiave_bacino(t0, Vector3(F * 0.02, 0.9, -0.03))
	c.chiave_bacino(ta, Vector3(F * 0.15, 0.85, 0.01))
	c.chiave_bacino(g, Vector3(F * 0.04, 0.87, 0.02))
	c.chiave_angoli(ta, Vector3(F * 0.3, 0.07, F * 0.08))
	c.chiave_angoli(g, Vector3(F * 0.05, 0.14, 0.0))
	c.chiave_busto(ta, Vector3(0.15, F * 0.22, F * 0.24))
	c.chiave_busto(g, Vector3(0.2, F * 0.05, 0.0))
	K.braccia(c, ta, pS, Vector3(0.14, -0.26, 0.28), Vector3(0.38, -0.12, 0.0))
	c.chiave_sguardo(ta, 0.6, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'interno finisce di portare il pallone dal lato scelto e via
static func b(c: Coreo, S: float, tg: float) -> void:
	esci(c, S, tg)
