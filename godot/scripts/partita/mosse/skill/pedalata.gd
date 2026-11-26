# Giochetto del dribbling "Pedalata" (id `pedalata`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

const GIRI := 4            # giri alternati del piede intorno al pallone (l'ultimo dal lato della finta)
const PALLA_Z := 0.4       # pallone tanto davanti al corpo (m del modello): vicino, sennò la gamba non gli gira davanti
const LARGO := 0.46        # il piede che ha girato appoggia tanto fuori dal pallone (gambe larghe)
const GIRO_ALTO := 0.27    # caviglia a questa altezza quando passa davanti al pallone
const GIRO_AVANTI := 0.21  # ... e tanto più avanti del pallone
const BACINO_H := 0.84     # bacino basso (ginocchia piegate) per tutta la pedalata
const FINE_PRIMA := 0.035  # s: l'ultimo giro finisce tanto prima dello scatto


# pedalata: di corsa, col pallone che rotola vicino davanti ai piedi, tre giri veloci alternati del piede intorno al
# davanti del pallone, da dentro a fuori (finta, lato scelto, finta): gambe larghe e basse, il busto che oscilla ogni
# volta dalla parte del giro, braccia larghe. Il pallone non viene mai toccato: lo porta via l'esterno nella parte B.
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var t0 := K.libera(c, pF if GIRI % 2 == 1 else pS)
	c.palla_a(0.1, {"rel": Vector3(0, 0, PALLA_Z + 0.06)})
	c.palla_a(g + 0.05, {"rel": Vector3(0, 0, PALLA_Z)})
	# (l'ultimo appoggio un attimo prima dello scatto del motore: sennò lo scatto lo taglia e il piede atterra sotto il corpo)
	var per := (g - FINE_PRIMA - t0) / float(GIRI)
	c.chiave_bacino(t0, Vector3(0, BACINO_H + 0.03, 0.0))
	for i in GIRI:
		var dir := F if (GIRI - 1 - i) % 2 == 0 else S
		var s := K.ls(dir)
		var ta := t0 + per * i
		if i > 0:
			c.stacca(s, ta - 0.02)
		_giro(c, s, dir, ta, per)
		# il corpo va dietro alla gamba che gira: bacino e spalle dalla parte del giro, busto avanti sul pallone
		var tm := ta + 0.8 * per
		c.chiave_bacino(tm, Vector3(dir * 0.1, BACINO_H, 0.03))
		c.chiave_angoli(tm, Vector3(dir * 0.34, 0.1, dir * 0.1))
		c.chiave_busto(tm, Vector3(0.24, dir * 0.24, dir * 0.3))
		K.braccia(c, tm, s, Vector3(0.4, -0.12, -0.12), Vector3(0.26, -0.2, 0.26))
		c.chiave_sguardo(tm, 0.45, dir * 0.35)
	# il piede del lato scelto si stacca già e viene dietro il pallone: nella parte B lo porta via con l'esterno
	c.passa_palla(pS, g + 0.04, Vector3(F * 0.06, 0.13, -0.16), Vector3(F * 0.5, 0.2, 0), 0.02)


# un giro del piede `s` (lato dir) intorno al davanti del pallone: entra da dietro-dentro, passa alto davanti al
# pallone con la punta in dentro, esce fuori e appoggia largo accanto al pallone
static func _giro(c: Coreo, s: String, dir: float, ta: float, per: float) -> void:
	c.passa_palla(s, ta + 0.3 * per, Vector3(-dir * 0.1, 0.17, -0.12), Vector3(-dir * 0.3, 0.3, 0), 0.03)
	c.passa_palla(s, ta + 0.56 * per, Vector3(dir * 0.02, GIRO_ALTO, GIRO_AVANTI), Vector3(dir * 0.1, 0.3, 0), 0.02)
	c.passa_palla(s, ta + 0.8 * per, Vector3(dir * 0.32, GIRO_ALTO - 0.07, GIRO_AVANTI - 0.04), Vector3(dir * 0.45, 0.2, 0), 0.0)
	c.appoggia_palla(s, ta + per, Vector3(dir * LARGO, K.H, 0.02), dir * 0.4, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto). L'esterno del piede del lato scelto porta via il pallone; il corpo,
# che era basso e largo, si butta dentro la curva spingendo sulla gamba della finta e si tira su di corsa
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.85), 0.06, {"spinta": 0.8})
	c.chiave_bacino(tg + 0.07, Vector3(S * 0.12, 0.88, 0.04))
	c.chiave_angoli(tg + 0.07, Vector3(S * 0.3, 0.2, S * 0.14))
	c.chiave_busto(tg + 0.08, Vector3(0.3, S * 0.22, S * 0.2))
	c.chiave_bacino(tg + 0.22, Vector3(S * 0.03, 0.91, 0.02))
