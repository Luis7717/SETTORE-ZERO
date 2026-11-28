# Giochetto del dribbling "Croqueta" (id `croqueta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


# croqueta: il corpo scivola di lato verso il lato scelto (lo porta il motore: `lat` −1), col petto verso il difensore.
# Due tocchi rapidi:
#   1) l'interno del piede della finta (quello lontano dal lato scelto) spinge il pallone di traverso davanti al corpo;
#   2) saltello: il piede del tocco atterra e resta indietro, l'altra gamba si apre larga dal lato scelto e riceve il
#      pallone d'interno quasi un metro più in là, a gambe larghe e bacino basso, poi lo porta avanti (parte B).
const DT1 := 0.09          # primo tocco tanto dopo l'appoggio del piede d'appoggio (s)
const DT2_MAX := 0.27      # dal primo al secondo tocco al massimo tanto (s)
const PRIMA_GO := 0.06     # il secondo tocco (la ricezione) tanto prima dello scatto
const X1 := 0.27           # pallone al primo tocco: tanto dalla parte della finta (m del modello) ...
const X2 := 0.56           # ... e al secondo tanto dal lato scelto
const Z1 := 0.4
const Z2 := 0.34
const GIRO_MAX := 0.6      # il petto si gira verso il difensore al massimo di tanto (rad)


# ultimo passo di corsa prima del giochetto: il piede `pS` appoggia davanti al corpo (ci resta sopra durante il primo
# tocco) e `pF` resta libero. Il corpo arriva di corsa: un piede già a terra resterebbe troppo indietro, quindi pS fa
# sempre un passo nuovo (e se è lui quello a terra, prima appoggia pF). Ritorna quando appoggia pS (s).
static func _ultimo_passo(c: Coreo, pS: String, pF: String) -> float:
	var ts := 0.07
	if c.a_terra(pS):
		if c.a_terra(pF):
			c.stacca(pS, 0.0)
		else:
			# pF sta arrivando a terra: appoggia lui, poi pS
			c.appoggia_corsa(pF, 0.04, 0.1, Vector2.ZERO, 0.04)
			c.stacca(pS, 0.03)
			ts = 0.13
	c.appoggia_corsa(pS, ts, 0.12, Vector2.ZERO, 0.07)
	c.stacca(pF, ts - 0.01)
	return ts


# di quanto girare il corpo perché il petto guardi il difensore (rad, + = sinistra); senza difensore niente
static func _verso_difensore(c: Coreo) -> float:
	var o := c.altro()
	if o == Vector3.INF:
		return 0.0
	var d := o - c.corpo_a(c.t)
	if Vector2(d.x, d.z).length() < 0.3:
		return 0.0
	return clampf(wrapf(atan2(d.x, d.z) - c.yaw, -PI, PI), -GIRO_MAX, GIRO_MAX)


static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var ts := _ultimo_passo(c, pS, pF)
	var t2 := maxf(g - PRIMA_GO, ts + DT1 + 0.2)
	var t1 := maxf(ts + DT1, t2 - DT2_MAX)
	var tm := t1 + 0.07            # punto più alto del saltello (poco: la gamba che atterra non deve stirarsi)
	var tl := t1 + 0.1             # il piede del primo tocco torna a terra
	# il petto verso il difensore: lo scivolamento del motore diventa un passo di lato vero
	c.chiave_giro(ts, _verso_difensore(c))
	# primo tocco: interno del piede della finta, punta un po' in fuori, che spinge verso il lato scelto
	c.tocca(pF, t1, "inside", Vector3(F * 0.35, 0.05, 0), {"rel": Vector3(F * X1, 0, Z1)}, 0.06)
	# il piede segue il pallone e atterra quasi sotto il corpo, che continua a scivolare: resta indietro, gamba tesa
	c.appoggia_corsa(pF, tl, 0.06, Vector2(S * 0.04, -0.06), 0.05)
	# saltello: l'altro piede si stacca subito dopo il tocco e si apre largo ad aspettare il pallone
	c.stacca(pS, t1 + 0.02)
	c.passa(pS, t1 + 0.11, Vector3(S * 0.46, 0.2, 0.2), Vector3(S * 0.55, 0.1, 0), 0.05)
	if t2 - t1 > 0.2:
		c.passa(pS, t2 - 0.06, Vector3(S * (X2 + 0.1), 0.19, Z2 - 0.04), Vector3(S * 0.55, 0.08, 0), 0.0)
	# secondo tocco: interno dell'altro piede, punta in fuori, gamba larga; poi il piede resta sul pallone e lo porta avanti
	c.tocca(pS, t2, "inside", Vector3(S * 0.55, 0.05, 0), {"rel": Vector3(S * X2, 0, Z2)}, 0.03)
	c.tocca(pS, t2 + 0.16, "inside", Vector3(S * 0.35, 0.08, 0), {"rel": Vector3(S * 0.42, 0, 0.56), "lega": true}, 0.02)
	# corpo: basso sul primo tocco, su nel saltello, giù a gambe larghe sulla ricezione
	c.chiave_bacino(t1, Vector3(F * 0.03, 0.85, -0.03))
	c.chiave_angoli(t1, Vector3(F * 0.12, 0.1, F * 0.05))
	c.chiave_busto(t1, Vector3(0.2, S * 0.1, F * 0.1))
	c.chiave_bacino(tm, Vector3(S * 0.02, 0.92, 0.0))
	c.chiave_angoli(tm, Vector3(0, 0.04, S * 0.1))
	c.chiave_busto(tm, Vector3(0.08, S * 0.18, 0))
	c.chiave_bacino(tl + 0.03, Vector3(S * 0.05, 0.87, 0.0))
	c.chiave_bacino(t2, Vector3(S * 0.1, 0.8, 0.0))
	c.chiave_angoli(t2, Vector3(S * 0.18, 0.1, S * 0.1))
	c.chiave_busto(t2, Vector3(0.22, S * 0.16, S * 0.12))
	c.chiave_bacino(t2 + 0.14, Vector3(S * 0.1, 0.84, 0.02))
	c.chiave_angoli(t2 + 0.14, Vector3(S * 0.12, 0.14, S * 0.06))
	c.chiave_busto(t2 + 0.14, Vector3(0.2, S * 0.08, 0))
	# braccia: larghe nel saltello (equilibrio), quella del lato scelto alta
	K.braccia(c, t1, pS, Vector3(0.34, -0.2, 0.06), Vector3(0.26, -0.32, -0.1))
	K.braccia(c, tm, pS, Vector3(0.42, -0.02, 0.0), Vector3(0.42, -0.08, 0.0))
	K.braccia(c, t2, pS, Vector3(0.38, -0.14, 0.1), Vector3(0.42, -0.12, -0.12))


# parte B: S = lato scelto, tg = adesso (lo scatto): lo stesso piede che ha ricevuto spinge avanti e via di corsa.
# Il pallone resta dal lato scelto (non torna davanti al difensore): rientra davanti al corpo piano, correndo
# (il motore dopo lo scatto corre un po' verso il lato vecchio: "avanti" del corpo nuovo è già girato di là)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "inside", Vector3(S * 0.3, 0.1, 0), 0.07, {"rel": Vector3(S * 0.6, 0, 0.3),
		"palla": [[tg + 0.24, {"rel": Vector3(S * 0.4, 0, 0.6)}]]})
