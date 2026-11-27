# Coreografie del dribbling (coreo.gd: piedi fermi a terra dove appoggiano, pallone mosso solo dai tocchi).
# Solo grafica: l'esito, i movimenti veri del giocatore e QUALE giochetto fa li decide il motore (sim/duel.gd,
# sim/skill.gd), qui si sceglie come muovere gambe, busto, braccia e pallone per arrivarci come farebbe un calciatore.
#
# Portatore, dribbling riuscito col tasto (evento 'dribble' con show > 0 e skill, poi 'dribble_go'): i 16 giochetti di
#   coreo_skill.gd, ognuno con la parte A (la finta, `show` s) e la parte B (il tocco che porta via il pallone e i
#   primi passi di corsa nel verso nuovo).
# Difensore battuto (difensore_vuoto / difensore_go), secondo il giochetto:
#   "affondo" passo largo verso la finta (si sbilancia), poi allunga l'altra gamba verso il pallone che se ne va (a
#             vuoto, senza entrare nel corpo del portatore), la ritira e si gira;
#   "gambe"   (tunnel) gambe larghe, il pallone gli passa in mezzo: si piega a guardare e chiude le ginocchia tardi;
#   "alto"    (sombrero, bicicletta) guarda in su il pallone che gli passa sopra, un passo indietro, braccia su;
#   "blocco"  (finta di tiro) si gira di fianco e alza la gamba per coprirsi dal tiro che non arriva.
# Dribbling fallito: il difensore fa un passo lungo e toglie il pallone con l'interno del piede (i due corpi restano
#   staccati: sim/duel.gd DRIB_GAP); il portatore, col piede portato via, cade in avanti: busto giù, braccia avanti, una
#   mano verso terra, due passi pesanti e si rialza.
# Lati: S = lato scelto dal motore (+1 = sinistra del portatore), F = −S (finta). Riferimento del corpo: x sinistra,
# z avanti, m del modello (coreo.gd).
extends RefCounted

const Coreo := preload("coreo.gd")
const Corpo := preload("corpo.gd")
const Sk := preload("coreo_skill.gd")
const Skill := preload("res://sim/skill.gd")

const GO := 0.35               # scatto previsto (s; quello vero arriva con 'dribble_go' e riprogramma la parte B)
const T_CONTRASTO := 0.2       # fallito: il piede del difensore arriva sul pallone dopo tanto (s)
const ALLUNGO := 0.95          # il difensore allunga la gamba (bassa, verso il pallone) al massimo a questa frazione della sua lunghezza
# giochetti della persona (ordine di sim/skill.gd)
const FINTE := Sk.IDS
# (i giochetti provvisori copiati da un altro tengono lo stile del modello: ponte ← tunnel, cucchiaio_finta ← fintatiro)
const STILE_DIF := {"tunnel": "gambe", "sombrero": "alto", "bicicletta": "alto", "fintatiro": "blocco",
	"ponte": "affondo", "cucchiaio_finta": "blocco"}
const GAMBE_LARGHE := 0.22      # tunnel: ogni piede del difensore sta tanto più in fuori dell'anca (m del modello)
const BR_RIPOSO := Sk.BR_RIPOSO

## solo per le prove (prova_vista --giochetto=...) quando il motore non dice il giochetto: giochetto fisso
static var FORZA := ""


static func _ls(x: float) -> String:
	return "l" if x > 0.0 else "r"


static func _segno(s: String) -> float:
	return 1.0 if s == "l" else -1.0


static func _altro(s: String) -> String:
	return "r" if s == "l" else "l"


## giochetto del portatore quando non lo dice il motore (r in [0, 1)): {id, name, ...} di sim/skill.gd
static func scegli(dri: float, r: float) -> Dictionary:
	return Skill.scegli(dri, r, 0.0, FORZA)


## nome a schermo del giochetto `id`
static func nome(id: String) -> String:
	return String(Skill.trova(id).get("name", "Dribbling"))


# ================================================================ portatore
## parte A: S = lato scelto (+1 sinistra del portatore), go = quando è previsto lo scatto (s)
static func portatore(c: Coreo, id: String, S: float, go: float = GO) -> void:
	c.tipo = "giochetto"
	c.lato = S
	c.yaw_fisso = c.yaw          # fino allo scatto il corpo guarda dove andava (più il giro del giochetto)
	c.yaw_fisso_fino = INF
	c.dati = {"id": id if id in FINTE else "finta", "S": S}
	# frenata: bacino appena indietro (poi le chiavi del giochetto)
	c.chiave_angoli(0.0, Vector3(0, 0.1, 0))
	Sk.parte_a(c, String(c.dati.id), S, go)
	c.fine = INF


## parte B: arrivato lo scatto del motore (adesso, c.t)
static func portatore_go(c: Coreo) -> void:
	Sk.parte_b(c, String(c.dati.get("id", "finta")), float(c.dati.get("S", c.lato)))


# ================================================================ difensore battuto
## lato = verso la finta rispetto al difensore (+1 sua sinistra); show = durata del giochetto (0 = dribbling dell'IA:
## niente finta, allunga subito la gamba); palla = Callable() -> pallone mostrato (mondo); id = giochetto del portatore
static func difensore_vuoto(c: Coreo, lato: float, show: float, palla: Callable, id: String = "") -> void:
	c.tipo = "affondo"
	c.lato = 1.0 if lato >= 0.0 else -1.0
	c.dati = {"palla": palla, "stile": STILE_DIF.get(id, "affondo")}
	c.yaw_fisso = c.yaw
	c.yaw_fisso_fino = INF
	var L := c.lato
	var pL := _ls(L)
	var pO := _altro(pL)
	if show <= 0.0:
		difensore_go(c, 0.04)
		return
	var ta := clampf(0.55 * show, 0.16, 0.3)
	if not c.a_terra(pO):
		c.appoggia(pO, 0.07, Vector2(-L * 0.12, 0.0), 0.0, 0.05)
	match String(c.dati.stile):
		"gambe":
			# passo di lato: resta a gambe larghe davanti al pallone
			# (i due piedi si allargano di qua e di là di dove sarà il corpo al calcio: il pallone gli passa in mezzo)
			# (indietreggia davanti al portatore fino al calcio: ogni piede atterra dove sarà il corpo in quel momento,
			# così al calcio sono alla pari, uno di qua e uno di là)
			var tl := maxf(ta, show - 0.1)
			var tr := show - 0.03
			c.appoggia_corsa(pL, tl, 2.0 * (show - tl), Vector2(L * GAMBE_LARGHE, 0.0), 0.07)
			c.stacca(pO, tl - 0.04)
			c.appoggia_corsa(pO, tr, 2.0 * (show - tr), Vector2(-L * GAMBE_LARGHE, 0.0), 0.04)
			c.chiave_bacino(ta, Vector3(L * 0.1, 0.84, 0.0))
			c.chiave_angoli(ta, Vector3(L * 0.1, 0.1, L * 0.04))
			c.chiave_busto(ta, Vector3(0.16, L * 0.1, 0))
			Sk.braccia(c, ta, pL, Vector3(0.37, -0.2, 0.08), Vector3(0.36, -0.2, 0.1))
			# ... e al calcio è in mezzo ai due piedi, basso sulle ginocchia
			c.chiave_bacino(show, Vector3(0, 0.83, 0.0))
			c.chiave_angoli(show, Vector3(0, 0.1, 0))
			c.chiave_busto(show, Vector3(0.2, 0, 0))
		"alto":
			c.appoggia(pL, ta, Vector2(L * 0.3, 0.06), L * 0.3, 0.06)
			c.chiave_bacino(ta, Vector3(L * 0.05, 0.86, 0.02))
			c.chiave_angoli(ta, Vector3(L * 0.1, 0.12, 0))
			c.chiave_busto(ta, Vector3(0.16, 0, 0))
			Sk.braccia(c, ta, pL, Vector3(0.36, -0.2, 0.1), Vector3(0.36, -0.2, 0.1))
		"blocco":
			# si gira di fianco e alza la gamba dal lato del tiro, braccia strette al corpo
			var tb := clampf(0.7 * show, 0.2, 0.4)
			c.chiave_giro(tb, L * 0.9)
			c.passa(pL, tb, Vector3(L * 0.14, 0.42, 0.22), Vector3(0, 0.5, 0), 0.0)
			c.chiave_bacino(tb, Vector3(-L * 0.04, 0.9, -0.04))
			c.chiave_angoli(tb, Vector3(0, -0.05, -L * 0.08))
			c.chiave_busto(tb, Vector3(0.2, 0, 0))
			Sk.braccia(c, tb, pL, Vector3(0.02, -0.24, 0.24), Vector3(0.02, -0.26, 0.22))
			c.chiave_sguardo(tb, 0.0, -L * 0.3)
		_:
			# si butta dalla parte della finta: passo largo e basso, bacino giù e di là, braccia larghe
			c.appoggia(pL, ta, Vector2(L * 0.5, 0.06), L * 0.55, 0.07)
			c.chiave_bacino(ta, Vector3(L * 0.14, 0.83, 0.0))
			c.chiave_angoli(ta, Vector3(L * 0.25, 0.14, L * 0.14))
			c.chiave_busto(ta, Vector3(0.16, L * 0.2, L * 0.12))
			Sk.braccia(c, ta, pL, Vector3(0.38, -0.14, 0.02), Vector3(0.36, -0.24, 0.18))
	c.fine = INF


## lo scatto del portatore: il difensore reagisce tardi (secondo lo stile), poi si rimette dritto e si gira
static func difensore_go(c: Coreo, ritardo: float = 0.03) -> void:
	var tg := c.t
	var L := c.lato
	var pL := _ls(L)
	var pO := _altro(pL)
	c.taglia(tg)
	var t1 := tg + ritardo
	match String(c.dati.get("stile", "affondo")):
		"gambe":
			# il pallone gli passa tra le gambe: resta piantato a gambe larghe (si vede il pallone passare in mezzo),
			# abbassa la testa a guardarlo, braccia larghe; se ne accorge tardi: si torce a guardarlo dietro di sé
			# dalla parte da cui passa il portatore (−L), chiude le gambe e si gira
			c.niente_passi_fino = t1 + 0.44
			c.chiave_bacino(t1 + 0.16, Vector3(0, 0.83, -0.02))
			c.chiave_angoli(t1 + 0.16, Vector3(0, 0.12, 0))
			c.chiave_busto(t1 + 0.16, Vector3(0.34, 0, 0))
			Sk.braccia(c, t1 + 0.16, pL, Vector3(0.4, -0.2, 0.12), Vector3(0.4, -0.2, 0.12))
			c.chiave_sguardo(t1 + 0.1, 1.0)
			c.chiave_bacino(t1 + 0.44, Vector3(0, 0.86, -0.02))
			c.chiave_angoli(t1 + 0.44, Vector3(-L * 0.1, 0.08, 0))
			c.chiave_busto(t1 + 0.44, Vector3(0.14, 0, -L * 0.45))
			Sk.braccia(c, t1 + 0.44, pL, Vector3(0.3, -0.26, -0.16), Vector3(0.36, -0.16, 0.2))
			c.chiave_sguardo(t1 + 0.44, 0.3, -L * 0.6)
			c.stacca(pO, t1 + 0.46)
			c.appoggia(pO, t1 + 0.6, Vector2(-L * 0.2, 0.0), 0.0, 0.05)
			c.chiave_bacino(t1 + 0.7, Vector3(0, 0.9, -0.04))
			c.chiave_angoli(t1 + 0.7, Vector3(0, 0.1, 0))
			c.chiave_busto(t1 + 0.7, Vector3(0.18, 0, 0))
			c.stacca(pL, t1 + 0.6)
			c.appoggia(pL, t1 + 0.74, Vector2(L * 0.16, 0.04), 0.0, 0.08)
			Sk.braccia(c, t1 + 0.74, pL, BR_RIPOSO, BR_RIPOSO)
			c.yaw_fisso_fino = t1 + 0.5
			c.fine = t1 + 0.8
		"alto":
			# il pallone gli passa sopra: testa in su, busto indietro, braccia su, un passo indietro, poi si gira
			c.chiave_bacino(t1 + 0.16, Vector3(0, 0.93, -0.1))
			c.chiave_angoli(t1 + 0.16, Vector3(0, -0.12, 0))
			c.chiave_busto(t1 + 0.16, Vector3(-0.3, 0, 0))
			Sk.braccia(c, t1 + 0.16, pL, Vector3(0.4, 0.3, 0.14), Vector3(0.36, 0.36, 0.16))
			c.stacca(pO, t1 + 0.1)
			c.appoggia(pO, t1 + 0.26, Vector2(-L * 0.14, -0.3), 0.0, 0.05)
			c.stacca(pL, t1 + 0.3)
			c.appoggia(pL, t1 + 0.46, Vector2(L * 0.14, -0.1), 0.0, 0.06)
			c.chiave_bacino(t1 + 0.6, Vector3(0, 0.92, -0.04))
			c.chiave_angoli(t1 + 0.6, Vector3(0, 0.06, 0))
			c.chiave_busto(t1 + 0.6, Vector3(0.1, 0, 0))
			Sk.braccia(c, t1 + 0.65, pL, BR_RIPOSO, BR_RIPOSO)
			c.yaw_fisso_fino = t1 + 0.3
			c.fine = t1 + 0.72
		_:
			_affondo_go(c, t1)


# allunga l'altra gamba verso il pallone che se ne va (a vuoto: al massimo ALLUNGO della gamba, mai dentro il corpo
# del portatore: coreo.ostacolo), si sbilancia, la ritira e si rimette dritto
static func _affondo_go(c: Coreo, t1: float) -> void:
	var L := c.lato
	var pL := _ls(L)
	var pO := _altro(pL)
	var palla: Callable = c.dati.palla
	var memo := {}
	var wc: WeakRef = weakref(c)   # (la funzione resta negli eventi di c: senza, c terrebbe in vita sé stessa)
	var allunga := func() -> Vector3:
		if not memo.has("p"):
			var cc := wc.get_ref() as Coreo
			memo["p"] = cc.dal_suo_lato(pO, cc.verso(palla.call(), ALLUNGO, 0.12), 0.1)
		return memo.p
	var blocco := String(c.dati.get("stile", "")) == "blocco"
	if blocco:
		c.chiave_giro(t1 + 0.3, 0.0)
		c.appoggia(pL, t1 + 0.1, Vector2(L * 0.16, 0.1), 0.0, 0.02)
	c.stacca(pO, t1 + (0.1 if blocco else 0.0))
	c.passa_fn(pO, t1 + 0.2, allunga, Vector3(L * 1.2, -0.1, 0), 0.06)
	c.passa_fn(pO, t1 + 0.34, allunga, Vector3(L * 1.2, -0.1, 0), 0.0)
	c.appoggia(pO, t1 + 0.52, Vector2(-L * 0.16, 0.02), 0.0, 0.06)
	c.stacca(pL, t1 + 0.54)
	c.appoggia(pL, t1 + 0.68, Vector2(L * 0.13, 0.04), 0.0, 0.08)
	c.chiave_bacino(t1 + 0.2, Vector3(-L * 0.04, 0.82, 0.0))
	c.chiave_angoli(t1 + 0.2, Vector3(-L * 0.3, 0.12, -L * 0.16))
	c.chiave_busto(t1 + 0.2, Vector3(0.14, -L * 0.2, -L * 0.25))
	c.chiave_bacino(t1 + 0.36, Vector3(-L * 0.05, 0.82, 0.0))
	c.chiave_angoli(t1 + 0.36, Vector3(-L * 0.3, 0.12, -L * 0.14))
	c.chiave_bacino(t1 + 0.68, Vector3(0, 0.92, -0.04))
	c.chiave_angoli(t1 + 0.68, Vector3(0, 0.08, 0))
	c.chiave_busto(t1 + 0.68, Vector3(0.12, 0, 0))
	# braccia: quello del lato della finta su e largo (equilibrio perso), l'altro verso il pallone
	Sk.braccia(c, t1 + 0.2, pL, Vector3(0.38, -0.04, -0.06), Vector3(0.34, -0.3, 0.22))
	Sk.braccia(c, t1 + 0.7, pL, BR_RIPOSO, BR_RIPOSO)
	c.chiave_sguardo(t1, 1.0)
	c.yaw_fisso_fino = t1 + 0.42
	c.fine = t1 + 0.76


# ================================================================ dribbling fallito
## difensore: passo lungo verso il pallone e interno del piede di traverso che lo porta via (lato = dov'è il pallone
## rispetto a lui, 0 davanti); ruba = il pallone resta a lui (sennò lo devia e va dove lo manda il motore)
static func contrasto(c: Coreo, lato: float, ruba: bool) -> void:
	c.tipo = "contrasto"
	c.lato = lato
	c.yaw_fisso = c.yaw
	var pT := _ls(lato) if lato != 0.0 else ("r" if c.a_terra("l") or not c.a_terra("r") else "l")
	var pU := _altro(pT)
	var sT := _segno(pT)
	var sU := _segno(pU)
	if not c.a_terra(pU):
		c.appoggia(pU, 0.08, Vector2(sU * 0.13, 0.2), 0.0, 0.06)
		if c.a_terra(pT):
			c.stacca(pT, 0.09)
	elif c.a_terra(pT):
		c.stacca(pT, 0.03)
	var tc := T_CONTRASTO
	# il pallone dov'è adesso (ai piedi del portatore), ma solo fin dove arriva la gamba allungata col passo
	var b0 := c.pallone()
	var qui := c.mondo_a(0.0, Vector3.ZERO)
	var d := Vector3(b0.x - qui.x, 0.0, b0.z - qui.z)
	var lim := 0.95 * 1.25
	if d.length() > lim:
		d = d.normalized() * lim
	var punto := Vector3(qui.x + d.x, 0.0, qui.z + d.z)
	# piede di traverso, interno in avanti sul pallone; il bacino va avanti e giù col passo (affondo vero)
	c.tocca(pT, tc, "inside", Vector3(sT * 1.35, 0.0, 0.0), {"mondo": punto}, 0.05)
	c.palla_a(tc + (0.22 if ruba else 0.1), {"moto": true})
	c.appoggia(pT, tc + 0.12, Vector2(sT * 0.12, 0.5), sT * 0.5, 0.03)
	c.stacca(pU, tc + 0.2)
	c.appoggia(pU, tc + 0.34, Vector2(sU * 0.12, 0.2), 0.0, 0.08)
	c.chiave_bacino(0.08, Vector3(0, 0.88, 0.04))
	c.chiave_angoli(0.08, Vector3(0, 0.14, 0))
	c.chiave_bacino(tc, Vector3(sT * 0.03, 0.8, 0.2))
	c.chiave_angoli(tc, Vector3(sT * 0.3, 0.06, -sT * 0.08))
	c.chiave_busto(tc, Vector3(0.0, 0, sT * 0.2))
	Sk.braccia(c, tc, pT, Vector3(0.36, -0.3, -0.2), Vector3(0.37, -0.12, 0.16))
	c.chiave_bacino(tc + 0.14, Vector3(sT * 0.03, 0.82, 0.22))
	c.chiave_bacino(tc + 0.4, Vector3(0, 0.92, -0.02))
	c.chiave_angoli(tc + 0.4, Vector3(0, 0.1, 0))
	c.chiave_busto(tc + 0.4, Vector3(0.14, 0, 0))
	Sk.braccia(c, tc + 0.4, pT, BR_RIPOSO, BR_RIPOSO)
	c.yaw_fisso_fino = tc + 0.2
	c.fine = tc + 0.44


## portatore fermato: il difensore gli porta via pallone e piede; il piede colpito vola indietro e lui cade su un
## ginocchio con una mano a terra (il motore lo tiene fermo: sim/duel.gd DRIB_KO_STUN), poi si rialza
static func inciampo(c: Coreo) -> void:
	c.tipo = "inciampo"
	c.yaw_fisso = c.yaw
	var pX := "r"
	if not c.a_terra("l") and c.a_terra("r"):
		pX = "l"
	var pY := _altro(pX)
	var sX := _segno(pX)
	var sY := _segno(pY)
	var tc := T_CONTRASTO
	# allunga il piede sul pallone...
	if c.a_terra(pX):
		c.stacca(pX, 0.02)
	c.passa(pX, tc - 0.04, Vector3(sX * 0.06, 0.14, 0.46), Vector3(0, 0.2, 0), 0.05)
	# ... e il contrasto glielo porta via: gamba indietro e in alto, poi giù sul ginocchio (punta a terra dietro)
	c.passa(pX, tc + 0.13, Vector3(sX * 0.16, 0.44, -0.34), Vector3(0, 1.1, 0), 0.0)
	var giu := Vector3(sX * 0.13, 0.13, -0.42)
	c.passa(pX, tc + 0.32, giu, Vector3(0, 1.25, 0), 0.0)
	c.passa(pX, tc + 0.46, giu, Vector3(0, 1.25, 0), 0.0)
	c.appoggia(pX, tc + 0.64, Vector2(sX * 0.12, -0.1), 0.0, 0.05)
	if not c.a_terra(pY):
		c.appoggia(pY, 0.07, Vector2(sY * 0.12, 0.16), 0.0, 0.04)
	c.chiave_bacino(tc - 0.04, Vector3(0, 0.9, 0.0))
	c.chiave_angoli(tc - 0.04, Vector3(0, 0.1, 0))
	c.chiave_busto(tc - 0.04, Vector3(0.12, 0, 0))
	c.chiave_bacino(tc + 0.14, Vector3(sY * 0.03, 0.8, 0.02))
	c.chiave_angoli(tc + 0.14, Vector3(sX * 0.25, 0.22, sX * 0.16))
	c.chiave_busto(tc + 0.14, Vector3(0.26, sX * 0.12, sX * 0.25))
	c.chiave_bacino(tc + 0.34, Vector3(sY * 0.02, 0.5, -0.04))
	c.chiave_angoli(tc + 0.34, Vector3(sX * 0.15, 0.2, sY * 0.06))
	c.chiave_busto(tc + 0.34, Vector3(0.4, 0, 0))
	c.chiave_bacino(tc + 0.46, Vector3(sY * 0.02, 0.52, -0.04))
	c.chiave_angoli(tc + 0.46, Vector3(0, 0.18, 0))
	c.chiave_busto(tc + 0.46, Vector3(0.36, 0, 0))
	c.chiave_bacino(tc + 0.72, Vector3(0, 0.9, -0.03))
	c.chiave_angoli(tc + 0.72, Vector3(0, 0.08, 0))
	c.chiave_busto(tc + 0.72, Vector3(0.12, 0, 0))
	# braccia: su e larghe quando perde l'equilibrio, poi una mano a terra davanti e l'altra larga, poi tornano
	c.chiave_braccio(pX, tc + 0.13, Vector3(0.38, 0.1, 0.1))
	c.chiave_braccio(pY, tc + 0.13, Vector3(0.36, 0.04, 0.2))
	c.chiave_braccio(pX, tc + 0.36, Vector3(0.08, -0.5, 0.26))
	c.chiave_braccio(pY, tc + 0.36, Vector3(0.34, -0.26, 0.1))
	c.chiave_braccio(pX, tc + 0.46, Vector3(0.08, -0.5, 0.24))
	c.chiave_braccio(pY, tc + 0.46, Vector3(0.3, -0.3, 0.12))
	c.chiave_braccio("l", tc + 0.74, BR_RIPOSO)
	c.chiave_braccio("r", tc + 0.74, BR_RIPOSO)
	c.chiave_sguardo(tc + 0.3, 0.0, 0.0)
	c.yaw_fisso_fino = tc + 0.6
	c.fine = tc + 0.78
