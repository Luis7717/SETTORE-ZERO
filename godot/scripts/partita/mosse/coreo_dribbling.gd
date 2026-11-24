# Coreografie del dribbling (coreo.gd: piedi fermi a terra dove appoggiano, pallone mosso solo dai tocchi).
# Solo grafica: l'esito e i movimenti veri del giocatore li decide il motore (sim/duel.gd), qui si sceglie come
# muovere gambe, busto, braccia e pallone per arrivarci come farebbe un calciatore.
#
# Portatore, dribbling riuscito col tasto (evento 'dribble' con show > 0, poi 'dribble_go'):
#   parte A (finta, `show` s): tocco di suola che frena il pallone, poi il giochetto scelto:
#     finta di corpo = passo largo dal lato della finta, spalla e anche girate di là;
#     doppio passo   = il piede del lato scelto e poi quello della finta passano sopra il pallone;
#     elastico       = esterno del piede della finta che porta il pallone fuori, il piede gli gira intorno;
#   parte B (scatto del motore): tocco che porta il pallone dal lato scelto (esterno del piede di quel lato, o interno
#     del piede della finta nell'elastico), spinta sul piede della finta e primi passi di corsa nel verso nuovo.
# Difensore battuto: passo largo verso la finta (si sbilancia), poi allunga l'altra gamba verso il pallone che va
#   dall'altra parte (a vuoto), la ritira e si rimette dritto.
# Dribbling fallito: il difensore fa un passo verso il pallone e lo prende (o lo devia) con l'interno del piede; il
#   portatore, che allungava il piede sul pallone, perde l'equilibrio in avanti e fa due passi per non cadere.
# Lati: S = lato scelto dal motore (+1 = sinistra del portatore), F = −S (finta). Riferimento del corpo: x sinistra,
# z avanti, m del modello (coreo.gd).
extends RefCounted

const Coreo := preload("coreo.gd")
const Giochetti := preload("giochetti.gd")

const GO := 0.35               # scatto previsto (s; quello vero arriva con 'dribble_go' e riprogramma la parte B)
const TOCCO_GO := 0.05         # il tocco che porta via il pallone arriva tanto dopo lo scatto (s)
const FINE_GO := 0.4           # ... e la coreografia finisce tanto dopo lo scatto (poi il clip di corsa)
const PASSO_CORSA := 0.08      # s tra due appoggi nei primi passi dello scatto
const PALLA_AVANTI := 0.44     # m del modello: pallone davanti al corpo quando arriva il tocco dello scatto
const T_CONTRASTO := 0.17      # fallito: il piede del difensore arriva sul pallone dopo tanto (s)
# giochetti che si fanno davvero davanti al difensore prima del cambio di direzione (gli altri di
# mosse/giochetti.gd restano per i dribbling dell'IA)
const FINTE := ["finta", "doppiopasso", "elastico"]
const BR_RIPOSO := Vector3(0.2, -0.5, 0.05)
const BR_LARGO := Vector3(0.45, -0.28, 0.05)
const BR_AVANTI := Vector3(0.15, -0.35, 0.33)
const BR_DIETRO := Vector3(0.22, -0.42, -0.28)

## solo per le prove a schermo (prova_vista --giochetto=...): giochetto fisso invece di quello scelto
static var FORZA := ""


static func _ls(x: float) -> String:
	return "l" if x > 0.0 else "r"


static func _segno(s: String) -> float:
	return 1.0 if s == "l" else -1.0


static func _altro(s: String) -> String:
	return "r" if s == "l" else "l"


## giochetto del portatore (dribbling alto = più bello, a volte uno più semplice; r in [0, 1)): {id, name}
static func scegli(dri: float, r: float) -> Dictionary:
	for tk: Dictionary in Giochetti.TRICKS:
		if tk.id == FORZA:
			return tk
	var k := mini(Giochetti.best_trick(dri), FINTE.size() - 1)
	var giu := 0 if r < 0.6 else (1 if r < 0.9 else 2)
	return Giochetti.TRICKS[maxi(0, k - giu)]


# ================================================================ portatore: parte A (la finta)
## S = lato scelto (+1 sinistra del portatore), go = quando è previsto lo scatto (s)
static func portatore(c: Coreo, id: String, S: float, go: float = GO) -> void:
	c.tipo = id
	c.lato = S
	c.yaw_fisso = c.yaw          # fino allo scatto il corpo guarda dove andava (le anche si girano verso la finta)
	c.yaw_fisso_fino = INF
	var F := -S
	var pS := _ls(S)
	var pF := _ls(F)
	# piede in aria adesso (quello che fa il primo movimento); a terra tutti e due: quello della finta
	var x := pF
	if not c.a_terra("l") and c.a_terra("r"):
		x = "l"
	elif not c.a_terra("r") and c.a_terra("l"):
		x = "r"
	c.dati = {"id": id, "S": S, "x": x}
	match id:
		"elastico":
			_elastico_a(c, S, x, go)
		"doppiopasso":
			_doppio_a(c, S, x, go)
		_:
			_finta_a(c, S, x, go)
	# frenata: bacino indietro e giù, poi peso verso la finta
	c.chiave_angoli(0.0, Vector3(0, 0.12, 0))
	c.chiave_bacino(0.09, Vector3(F * 0.02, 0.895, -0.09))
	c.chiave_angoli(0.09, Vector3(0, -0.06, 0))
	c.chiave_busto(0.09, Vector3(0.04, 0, 0))
	# il pallone che portava di corsa (prima del tocco dello scatto il corpo resta dov'è il pallone)
	var tg := go + TOCCO_GO
	if id != "elastico":
		c.tocca(pS, tg, "outside", _ang_esterno(S, 0.9), {"rel": Vector3(S * 0.06, 0, PALLA_AVANTI)})
	c.fine = INF


# finta di corpo: suola sul pallone (lo frena), passo largo dal lato della finta col busto che va di là
static func _finta_a(c: Coreo, S: float, x: String, go: float) -> void:
	var F := -S
	var pS := _ls(S)
	var pF := _ls(F)
	if x == pF:
		c.tocca(pF, 0.07, "sole", Vector3(F * 0.15, -0.25, 0), {"rel": Vector3(F * 0.04, 0, 0.5)})
		c.appoggia(pF, 0.19, Vector2(F * 0.4, 0.1), F * 0.35, 0.08)
		c.stacca(pS, 0.21)
	else:
		c.tocca(pS, 0.07, "sole", Vector3(S * 0.1, -0.25, 0), {"rel": Vector3(S * 0.02, 0, 0.5)})
		c.appoggia(pS, 0.14, Vector2(S * 0.12, 0.1), S * 0.1, 0.06)
		c.stacca(pF, 0.15)
		c.appoggia(pF, 0.26, Vector2(F * 0.42, 0.08), F * 0.35, 0.08)
		c.stacca(pS, 0.28)
	# il piede del lato scelto resta basso vicino al pallone, pronto (ma il corpo va dall'altra parte)
	c.passa(pS, go - 0.03, Vector3(S * 0.06, 0.12, 0.2), Vector3(-S * 0.5, 0.15, 0), 0.05)
	c.chiave_bacino(0.22, Vector3(F * 0.06, 0.87, -0.04))
	c.chiave_angoli(0.22, Vector3(F * 0.3, 0.05, F * 0.1))
	c.chiave_busto(0.22, Vector3(0.24, F * 0.3, F * 0.16))
	c.chiave_bacino(go - 0.02, Vector3(F * 0.07, 0.865, -0.03))
	c.chiave_angoli(go - 0.02, Vector3(F * 0.32, 0.08, F * 0.12))
	c.chiave_busto(go - 0.02, Vector3(0.28, F * 0.34, F * 0.18))
	c.chiave_braccio(_ls(F), 0.22, Vector3(0.45, -0.32, 0.0))
	c.chiave_braccio(_ls(S), 0.22, Vector3(0.28, -0.32, 0.22))


# doppio passo: il piede del lato scelto passa sopra il pallone (finta di là), poi quello della finta (finta di qua)
static func _doppio_a(c: Coreo, S: float, x: String, go: float) -> void:
	var F := -S
	var pS := _ls(S)
	var pF := _ls(F)
	var t0 := 0.0
	if x == pF: # prima un passo di frenata col piede della finta, che è in aria
		c.appoggia(pF, 0.07, Vector2(F * 0.12, 0.12), 0.0, 0.05)
		t0 = 0.05
	c.stacca(pS, t0 + 0.0)
	# sopra il pallone da dentro (lato della finta) a fuori (lato scelto), poi appoggio largo
	c.passa(pS, t0 + 0.07, Vector3(F * 0.04, 0.3, 0.38), Vector3(S * 0.3, 0.2, 0), 0.06)
	c.passa(pS, t0 + 0.12, Vector3(S * 0.14, 0.27, 0.46), Vector3(-S * 0.2, 0.25, 0), 0.03)
	c.appoggia(pS, t0 + 0.17, Vector2(S * 0.2, 0.3), S * 0.35, 0.05)
	c.stacca(pF, t0 + 0.16)
	c.passa(pF, t0 + 0.21, Vector3(S * 0.04, 0.3, 0.4), Vector3(F * 0.3, 0.2, 0), 0.06)
	c.passa(pF, t0 + 0.25, Vector3(F * 0.16, 0.27, 0.46), Vector3(-F * 0.2, 0.25, 0), 0.03)
	c.appoggia(pF, minf(go - 0.02, t0 + 0.3), Vector2(F * 0.36, 0.22), F * 0.35, 0.05)
	c.stacca(pS, go - 0.01)
	c.chiave_bacino(t0 + 0.12, Vector3(S * 0.06, 0.88, -0.02))
	c.chiave_angoli(t0 + 0.12, Vector3(S * 0.25, 0.12, S * 0.08))
	c.chiave_busto(t0 + 0.12, Vector3(0.25, S * 0.22, S * 0.12))
	c.chiave_bacino(go - 0.03, Vector3(F * 0.07, 0.87, -0.02))
	c.chiave_angoli(go - 0.03, Vector3(F * 0.3, 0.1, F * 0.1))
	c.chiave_busto(go - 0.03, Vector3(0.28, F * 0.3, F * 0.16))
	c.chiave_braccio(pS, t0 + 0.12, BR_LARGO)
	c.chiave_braccio(pF, t0 + 0.12, Vector3(0.3, -0.3, 0.2))
	c.chiave_braccio(pF, go - 0.03, BR_LARGO)
	c.chiave_braccio(pS, go - 0.03, Vector3(0.3, -0.3, 0.2))


# elastico: esterno del piede della finta che porta il pallone fuori, il piede gli gira intorno (l'interno, allo
# scatto, lo riporta dentro: parte B); il piede del lato scelto regge e fa un saltello per seguire il corpo
static func _elastico_a(c: Coreo, S: float, x: String, go: float) -> void:
	var F := -S
	var pS := _ls(S)
	var pF := _ls(F)
	var tf := 0.1
	if x == pS:
		c.appoggia(pS, 0.1, Vector2(S * 0.12, 0.12), 0.0, 0.05)
		c.stacca(pF, 0.09)
		tf = 0.18
	c.tocca(pF, tf, "outside", Vector3(-F * 0.3, 0.15, 0), {"rel": Vector3(F * 0.02, 0, 0.48)})
	# il pallone va fuori dal lato della finta, il piede lo segue e gli gira intorno (alto, poi giù dall'altra parte)
	var tb := go + 0.02
	c.tocca(pF, tb, "inside", _ang_interno(S, 1.0), {"rel": Vector3(F * 0.24, 0, 0.44)})
	c.passa(pF, lerpf(tf, tb, 0.5), Vector3(F * 0.3, 0.2, 0.5), Vector3(F * 0.2, 0.3, 0), 0.04)
	# saltello del piede che regge
	if c.a_terra(pS) or x == pS:
		var ts := maxf(tf + 0.04, 0.2)
		c.stacca(pS, ts)
		c.appoggia(pS, ts + 0.08, Vector2(S * 0.06, 0.04), 0.0, 0.04)
	c.chiave_bacino(tf, Vector3(F * 0.05, 0.89, -0.03))
	c.chiave_angoli(tf, Vector3(F * 0.2, 0.1, F * 0.08))
	c.chiave_busto(tf, Vector3(0.25, F * 0.2, F * 0.12))
	c.chiave_bacino(go - 0.03, Vector3(F * 0.08, 0.87, -0.02))
	c.chiave_angoli(go - 0.03, Vector3(F * 0.28, 0.12, F * 0.12))
	c.chiave_busto(go - 0.03, Vector3(0.28, F * 0.28, F * 0.18))
	c.chiave_braccio(pF, tf, BR_LARGO)
	c.chiave_braccio(pS, tf, Vector3(0.32, -0.3, 0.18))


# ================================================================ portatore: parte B (lo scatto)
## arrivato lo scatto del motore (adesso, c.t): tocco che porta il pallone dal lato scelto e primi passi di corsa nel
## verso nuovo (da adesso il corpo gira verso dove corre il motore)
static func portatore_go(c: Coreo) -> void:
	var tg := c.t
	var id: String = c.dati.get("id", "finta")
	var S: float = c.dati.get("S", c.lato)
	var F := -S
	var pS := _ls(S)
	var pF := _ls(F)
	# il pallone del tocco: dov'era diretto (nel verso di prima), fissato adesso nel mondo
	var tt := tg + (0.02 if id == "elastico" else TOCCO_GO)
	var b_tocco := c.pallone_previsto(tt)
	c.taglia(tg)
	c.yaw_fisso_fino = tg
	var piede := pF if id == "elastico" else pS
	if id == "elastico":
		c.tocca(pF, tt, "inside", _ang_interno(S, 1.25), {"mondo": b_tocco})
	else:
		c.tocca(pS, tt, "outside", _ang_esterno(S, 0.8), {"mondo": b_tocco})
	c.palla_a(tg + FINE_GO, {"moto": true})
	# primi passi di corsa: il piede del tocco appoggia avanti, l'altro (quello della spinta) si stacca
	var altro := _altro(piede)
	var t1 := tt + 0.07
	c.appoggia(piede, t1, Vector2(_segno(piede) * 0.1, 0.28), 0.0, 0.08)
	c.stacca(altro, tg + 0.05)
	c.appoggia(altro, t1 + PASSO_CORSA, Vector2(_segno(altro) * 0.1, 0.3), 0.0, 0.1)
	c.stacca(piede, t1 + PASSO_CORSA - 0.01)
	c.appoggia(piede, t1 + 2.0 * PASSO_CORSA, Vector2(_segno(piede) * 0.1, 0.3), 0.0, 0.1)
	c.stacca(altro, t1 + 2.0 * PASSO_CORSA - 0.01)
	c.appoggia(altro, t1 + 3.0 * PASSO_CORSA, Vector2(_segno(altro) * 0.1, 0.3), 0.0, 0.1)
	# bacino giù e in avanti (spinta), busto inclinato nella curva, poi la corsa
	c.chiave_bacino(tg + 0.06, Vector3(S * 0.04, 0.86, 0.0))
	c.chiave_angoli(tg + 0.06, Vector3(S * 0.2, 0.3, S * 0.12))
	c.chiave_busto(tg + 0.08, Vector3(0.35, S * 0.12, S * 0.1))
	c.chiave_bacino(tg + 0.2, Vector3(0, 0.88, 0.02))
	c.chiave_angoli(tg + 0.2, Vector3(0, 0.3, 0))
	c.chiave_bacino(tg + FINE_GO, Vector3(0, 0.91, -0.02))
	c.chiave_angoli(tg + FINE_GO, Vector3(0, 0.2, 0))
	c.chiave_busto(tg + FINE_GO, Vector3(0.25, 0, 0))
	# braccia di corsa: avanti quello opposto alla gamba che appoggia
	var tb := t1
	var a := piede
	for i in 4:
		c.chiave_braccio(_altro(a), tb, BR_AVANTI)
		c.chiave_braccio(a, tb, BR_DIETRO)
		a = _altro(a)
		tb += PASSO_CORSA
	c.fine = tg + FINE_GO


# esterno del piede del lato S verso l'avanti e un po' di lato: k = quanto è girata la punta verso dentro
static func _ang_esterno(S: float, k: float) -> Vector3:
	return Vector3(-S * k, 0.25, 0)


# interno del piede della finta (lato −S) verso l'avanti e il lato S
static func _ang_interno(S: float, k: float) -> Vector3:
	return Vector3(-S * k, 0.1, 0)


# ================================================================ difensore battuto
## lato = verso la finta rispetto al difensore (+1 sua sinistra); show = durata del giochetto (0 = dribbling dell'IA:
## niente finta, allunga subito la gamba); palla = Callable() -> pallone mostrato (mondo)
static func difensore_vuoto(c: Coreo, lato: float, show: float, palla: Callable) -> void:
	c.tipo = "affondo"
	c.lato = 1.0 if lato >= 0.0 else -1.0
	c.dati = {"palla": palla}
	c.yaw_fisso = c.yaw
	c.yaw_fisso_fino = INF
	var L := c.lato
	var pL := _ls(L)
	var pO := _altro(pL)
	if show > 0.0:
		# si butta dalla parte della finta: passo largo e basso, bacino giù e di là
		if c.a_terra(pL):
			c.stacca(pL, 0.06)
		if not c.a_terra(pO):
			c.appoggia(pO, 0.08, Vector2(-L * 0.1, 0.0), 0.0, 0.05)
		c.appoggia(pL, 0.2, Vector2(L * 0.46, 0.08), L * 0.6, 0.07)
		c.chiave_bacino(0.2, Vector3(L * 0.1, 0.83, 0.02))
		c.chiave_angoli(0.2, Vector3(L * 0.25, 0.25, L * 0.12))
		c.chiave_busto(0.2, Vector3(0.3, L * 0.12, L * 0.1))
		c.chiave_braccio(pL, 0.2, Vector3(0.45, -0.25, 0.05))
		c.chiave_braccio(pO, 0.2, Vector3(0.35, -0.25, 0.15))
		c.fine = INF
	else:
		difensore_go(c, 0.04)


## lo scatto del portatore: il difensore allunga l'altra gamba verso il pallone che se ne va (a vuoto), poi la ritira
static func difensore_go(c: Coreo, ritardo: float = 0.02) -> void:
	var tg := c.t
	var L := c.lato
	var pL := _ls(L)
	var pO := _altro(pL)
	c.taglia(tg)
	var palla: Callable = c.dati.palla
	var memo := {}
	# punto della gamba allungata: verso il pallone di adesso, al massimo fin dove arriva la gamba
	var allunga := func() -> Vector3:
		if memo.has("p"):
			return memo.p
		return c.verso(palla.call(), 0.92, 0.1)
	var fissa := func() -> Vector3:
		if not memo.has("p"):
			memo["p"] = c.verso(palla.call(), 0.92, 0.1)
		return memo.p
	var t1 := tg + ritardo
	c.stacca(pO, t1)
	c.passa_fn(pO, t1 + 0.14, fissa, Vector3(L * 1.3, -0.1, 0), 0.05)
	c.passa_fn(pO, t1 + 0.38, allunga, Vector3(L * 1.3, -0.1, 0), 0.0)
	c.appoggia(pO, t1 + 0.55, Vector2(-L * 0.16, 0.02), 0.0, 0.06)
	c.stacca(pL, t1 + 0.57)
	c.appoggia(pL, t1 + 0.71, Vector2(L * 0.13, 0.04), 0.0, 0.08)
	c.chiave_bacino(t1 + 0.16, Vector3(-L * 0.05, 0.8, 0.02))
	c.chiave_angoli(t1 + 0.16, Vector3(-L * 0.3, 0.22, -L * 0.18))
	c.chiave_busto(t1 + 0.16, Vector3(0.32, -L * 0.12, -L * 0.2))
	c.chiave_bacino(t1 + 0.42, Vector3(-L * 0.05, 0.81, 0.0))
	c.chiave_angoli(t1 + 0.42, Vector3(-L * 0.28, 0.22, -L * 0.15))
	c.chiave_bacino(t1 + 0.7, Vector3(0, 0.92, -0.04))
	c.chiave_angoli(t1 + 0.7, Vector3(0, 0.08, 0))
	c.chiave_busto(t1 + 0.7, Vector3(0.12, 0, 0))
	c.chiave_braccio(pL, t1 + 0.16, Vector3(0.5, -0.1, 0.0))
	c.chiave_braccio(pO, t1 + 0.16, Vector3(0.3, -0.35, 0.22))
	c.chiave_braccio(pL, t1 + 0.7, BR_RIPOSO)
	c.chiave_braccio(pO, t1 + 0.7, BR_RIPOSO)
	c.yaw_fisso_fino = t1 + 0.45
	c.fine = t1 + 0.76


# ================================================================ dribbling fallito
## difensore: passo verso il pallone e interno del piede sopra (lato = dov'è il pallone rispetto a lui, 0 davanti);
## ruba = il pallone resta a lui (sennò lo devia e va dove lo manda il motore)
static func contrasto(c: Coreo, lato: float, ruba: bool) -> void:
	c.tipo = "contrasto"
	c.lato = lato
	c.yaw_fisso = c.yaw
	var pT := _ls(lato) if lato != 0.0 else ("r" if c.a_terra("l") or not c.a_terra("r") else "l")
	var pU := _altro(pT)
	var sT := _segno(pT)
	var sU := _segno(pU)
	if not c.a_terra(pU):
		c.appoggia(pU, 0.08, Vector2(sU * 0.13, 0.26), 0.0, 0.06)
		if c.a_terra(pT):
			c.stacca(pT, 0.09)
	elif c.a_terra(pT):
		c.stacca(pT, 0.03)
	var tc := T_CONTRASTO
	# piede di traverso, interno in avanti sul pallone
	c.tocca(pT, tc, "inside", Vector3(sT * 1.35, 0.0, 0.0), {"rel": Vector3(sT * 0.06, 0, 0.6)}, 0.06)
	c.palla_a(tc + (0.2 if ruba else 0.1), {"moto": true})
	c.appoggia(pT, tc + 0.14, Vector2(sT * 0.12, 0.24), sT * 0.3, 0.05)
	c.stacca(pU, tc + 0.18)
	c.appoggia(pU, tc + 0.3, Vector2(sU * 0.12, 0.06), 0.0, 0.08)
	c.chiave_bacino(0.09, Vector3(0, 0.86, 0.04))
	c.chiave_angoli(0.09, Vector3(0, 0.22, 0))
	c.chiave_bacino(tc, Vector3(sT * 0.03, 0.82, 0.07))
	c.chiave_angoli(tc, Vector3(sT * 0.2, 0.3, -sT * 0.08))
	c.chiave_busto(tc, Vector3(0.34, 0, 0))
	c.chiave_braccio("l", tc, Vector3(0.42, -0.25, 0.1))
	c.chiave_braccio("r", tc, Vector3(0.42, -0.25, 0.1))
	c.chiave_bacino(tc + 0.3, Vector3(0, 0.92, -0.04))
	c.chiave_angoli(tc + 0.3, Vector3(0, 0.1, 0))
	c.chiave_busto(tc + 0.3, Vector3(0.12, 0, 0))
	c.chiave_braccio("l", tc + 0.3, BR_RIPOSO)
	c.chiave_braccio("r", tc + 0.3, BR_RIPOSO)
	c.yaw_fisso_fino = tc + 0.15
	c.fine = tc + 0.33


## portatore fermato: allungava il piede sul pallone, il difensore glielo toglie e lui perde l'equilibrio in avanti
static func inciampo(c: Coreo) -> void:
	c.tipo = "inciampo"
	c.yaw_fisso = c.yaw
	var pX := "r"
	if not c.a_terra("l") and c.a_terra("r"):
		pX = "l"
	var pY := _altro(pX)
	var sX := _segno(pX)
	var sY := _segno(pY)
	if c.a_terra(pX):
		c.stacca(pX, 0.02)
	c.passa(pX, 0.13, Vector3(sX * 0.05, 0.16, 0.5), Vector3(0, 0.3, 0), 0.06)
	c.appoggia(pX, 0.28, Vector2(sX * 0.05, 0.34), 0.0, 0.05)
	c.stacca(pY, 0.29)
	c.appoggia(pY, 0.42, Vector2(sY * 0.15, 0.3), sY * 0.2, 0.08)
	c.stacca(pX, 0.5)
	c.appoggia(pX, 0.62, Vector2(sX * 0.12, 0.04), 0.0, 0.07)
	c.chiave_bacino(0.13, Vector3(0, 0.91, 0.0))
	c.chiave_angoli(0.13, Vector3(0, 0.12, 0))
	c.chiave_bacino(0.28, Vector3(0, 0.83, 0.08))
	c.chiave_angoli(0.28, Vector3(sX * 0.1, 0.42, sX * 0.1))
	c.chiave_busto(0.28, Vector3(0.45, 0, 0))
	c.chiave_bacino(0.42, Vector3(0, 0.84, 0.06))
	c.chiave_angoli(0.42, Vector3(0, 0.3, -sX * 0.06))
	c.chiave_busto(0.42, Vector3(0.3, 0, 0))
	c.chiave_bacino(0.62, Vector3(0, 0.92, -0.04))
	c.chiave_angoli(0.62, Vector3(0, 0.06, 0))
	c.chiave_busto(0.62, Vector3(0.1, 0, 0))
	c.chiave_braccio("l", 0.2, Vector3(0.4, 0.05, 0.3))
	c.chiave_braccio("r", 0.2, Vector3(0.4, 0.05, 0.3))
	c.chiave_braccio("l", 0.32, Vector3(0.55, -0.02, 0.1))
	c.chiave_braccio("r", 0.32, Vector3(0.55, -0.02, 0.1))
	c.chiave_braccio("l", 0.46, Vector3(0.4, -0.25, 0.1))
	c.chiave_braccio("r", 0.46, Vector3(0.4, -0.25, 0.1))
	c.chiave_braccio("l", 0.65, BR_RIPOSO)
	c.chiave_braccio("r", 0.65, BR_RIPOSO)
	c.yaw_fisso_fino = 0.5
	c.fine = 0.68
