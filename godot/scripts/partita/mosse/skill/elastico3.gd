# Giochetto del dribbling "Triplo elastico" (id `elastico3`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
# Il gesto morbido e continuo (curva del pallone, piede incollato) è quello di elastico.gd (El).
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")
const El := preload("elastico.gd")

const FUORI := 0.4            # m del modello: quanto fuori (verso la finta) va il pallone a ogni cambio ...
const DENTRO := 0.05          # ... e dove torna tra un cambio e l'altro
const CAMBIO := 0.11          # s: mezzo cambio (da dentro a fuori, o da fuori a dentro)
const ULTIMO := 0.14          # s prima dello scatto: il pallone è fuori per la terza volta (poi l'interno lo porta via)


# triplo elastico: tre cambi esterno-interno di fila con lo stesso piede (fuori-dentro, fuori-dentro, fuori e via dal
# lato scelto), rapidi e senza pause: il pallone fa un'onda davanti al corpo e il piede gli gira intorno a ogni estremo
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	# all'indietro dall'ultimo "fuori": cinque mezzi cambi
	var t3 := g - ULTIMO
	var t0 := maxf(0.04, t3 - 5.0 * CAMBIO)
	var q := (t3 - t0) / 5.0
	var nodi: Array = [[t0, Vector3(F * 0.02, 0, 0.56)]]
	for i in 5:
		var fuori := i % 2 == 0
		var x := (FUORI + (0.05 if i == 4 else 0.0)) if fuori else DENTRO
		nodi.append([t0 + q * (i + 1), Vector3(F * x, 0, 0.54 if fuori else 0.5)])
	nodi.append([g + El.FINE_CAMBIO, Vector3(S * 0.07, 0, 0.48)])
	var d := {"piede": pF, "nodi": nodi}
	c.dati["el"] = d
	# il piede d'appoggio saltella a ogni rientro del pallone
	El.saltelli(c, pS, [t0 + 0.04, t0 + 2.0 * q - 0.02, t0 + 4.0 * q - 0.04], g)
	K.libera(c, pF)
	El.piano(c, d)
	# il corpo ondeggia col pallone: bacino basso, un po' verso la finta quando il pallone è fuori; braccia larghe
	c.chiave_bacino(t0, Vector3(F * 0.02, 0.89, -0.03))
	for i in 5:
		var fuori := i % 2 == 0
		var tt := t0 + q * (i + 1)
		c.chiave_bacino(tt, Vector3(F * (0.13 if fuori else 0.06), 0.85 if fuori else 0.87, 0.0))
		c.chiave_angoli(tt, Vector3(F * (0.26 if fuori else 0.1), 0.07, F * (0.07 if fuori else 0.02)))
		c.chiave_busto(tt, Vector3(0.15, F * (0.18 if fuori else 0.06), F * (0.2 if fuori else 0.06)))
	c.chiave_bacino(g, Vector3(F * 0.04, 0.87, 0.02))
	c.chiave_angoli(g, Vector3(F * 0.05, 0.14, 0.0))
	c.chiave_busto(g, Vector3(0.2, F * 0.05, 0.0))
	K.braccia(c, t0 + q, pS, Vector3(0.36, -0.16, 0.1), Vector3(0.4, -0.1, 0.0))
	K.braccia(c, t3, pS, Vector3(0.3, -0.2, 0.2), Vector3(0.4, -0.1, 0.0))
	c.chiave_sguardo(t0 + q, 0.8, F * 0.2)
	c.chiave_sguardo(t3, 0.6, F * 0.3)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'interno finisce l'ultimo cambio dal lato scelto e via
static func b(c: Coreo, S: float, tg: float) -> void:
	El.esci(c, S, tg)
