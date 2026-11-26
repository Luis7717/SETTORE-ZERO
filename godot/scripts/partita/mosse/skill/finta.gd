# Giochetto del dribbling "Finta di corpo" (id `finta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")


const PASSO := 0.11   # s di partita tra due appoggi dei passi di corsa che portano al giochetto


## passi di corsa fino a quando il piede `s` fa la sua cosa (appoggio largo, tocco, giro) a `tp`: l'altro piede
## appoggia PASSO prima, `s` PASSO prima ancora, e così indietro fino ad adesso, partendo dai piedi come sono (uno può
## essere in volo): niente piede piantato e niente corpo sospeso mentre il motore lo porta avanti. Ritorna da quando
## `s` è libero (s). (Usata anche dagli altri giochetti di questo gruppo: è qui perché comune.gd non si tocca.)
static func rincorsa(c: Coreo, s: String, tp: float, T: float = PASSO) -> float:
	var passi: Array = []
	var tt := tp - T
	var a := K.altro(s)
	while tt > 0.02:
		passi.push_front([tt, a])
		a = K.altro(a)
		tt -= T
	if not passi.is_empty():
		var primo := String(passi[0][1])
		if c.a_terra(primo) and not c.a_terra(K.altro(primo)):
			# il primo appoggio toccherebbe al piede che è già a terra: prima atterra quello in volo
			if float(passi[0][0]) > 0.09:
				passi.push_front([0.03, K.altro(primo)])
			else:
				passi.pop_front()
		elif c.a_terra(primo):
			c.stacca(primo, 0.01)
	if passi.is_empty():
		return K.libera(c, s)
	for k: Array in passi:
		K.passo(c, String(k[1]), float(k[0]), T, Vector2.ZERO, 0.13)
	return float(passi.back()[0])


# finta di corpo: in corsa, passo largo e basso dal lato della finta con la spalla che cade di là e lo sguardo di là
# (i passi di prima sono di corsa: non si pianta); il pallone continua dritto e allo scatto l'esterno dell'altro piede
# lo porta via mentre la gamba della finta spinge
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var tp := 0.76 * g
	rincorsa(c, pF, tp)
	K.dritto(c, "finta", S, g)
	c.appoggia_corsa(pF, tp, 0.08, Vector2(F * 0.3, 0.0), 0.08)
	c.stacca(pS, tp + 0.04)
	c.chiave_bacino(tp - 0.1, Vector3(F * 0.04, 0.9, 0.0))
	c.chiave_bacino(tp + 0.03, Vector3(F * 0.16, 0.84, 0.0))
	c.chiave_angoli(tp + 0.03, Vector3(F * 0.36, 0.06, F * 0.1))
	c.chiave_busto(tp + 0.03, Vector3(0.15, F * 0.27, F * 0.3))
	c.chiave_bacino(g, Vector3(F * 0.18, 0.83, 0.02))
	c.chiave_angoli(g, Vector3(F * 0.38, 0.06, F * 0.12))
	c.chiave_busto(g, Vector3(0.16, F * 0.3, F * 0.32))
	K.braccia(c, tp - 0.1, pS, K.BR_DIETRO, K.BR_AVANTI)
	K.braccia(c, tp + 0.03, pS, Vector3(0.1, -0.24, 0.3), Vector3(0.38, -0.1, -0.05))
	c.chiave_sguardo(tp - 0.04, 0.2, F * 0.55)
	c.chiave_sguardo(g, 0.4, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto)
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.85), 0.05)
