# Giochetto del dribbling "Abracadabra" (id `abracadabra`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# Tempi della parte A (s prima dello scatto previsto)
const T_APPOGGIO := 0.27       # il piede della finta si pianta largo, avanti, accanto al pallone
const T_PRENDE := 0.24         # l'interno del piede del lato scelto prende il pallone
const T_DIETRO := 0.15         # il pallone passa dietro il tallone d'appoggio
const T_FUORI := 0.06          # il pallone spunta dall'altra parte della gamba d'appoggio (il lato della finta)
# Pallone rispetto alla caviglia del piede d'appoggio (x verso il lato scelto, z avanti; m del modello)
const P_PRENDE := Vector2(0.23, -0.02)
const P_DIETRO := Vector2(0.02, -0.28)
const P_FUORI := Vector2(-0.36, -0.04)
const B_TOCCO := 0.035         # s dopo lo scatto: l'esterno dello stesso piede lo fa schizzare dal lato scelto


# velocità del corpo durante il giochetto nel riferimento del corpo (x sinistra, z avanti; m del modello al secondo),
# come la decide il motore (sim/duel.gd dribShowSteer): `av` verso il difensore, dov'è adesso, e `lat` di lato verso
# la finta (K.vel_corpo fa lo stesso conto col difensore dritto davanti)
static func _vel_corpo(c: Coreo, S: float) -> Vector3:
	var sk := K.Skill.trova("abracadabra")
	var u := Vector3(0, 0, 1)
	var o := c.altro()
	if o != Vector3.INF:
		var d := Basis(Vector3.UP, c.yaw).inverse() * (o - c.corpo_a(c.t))
		d.y = 0.0
		if d.length() > 0.1:
			u = d.normalized()
	var w := u * float(sk.get("av", 1.0)) + Vector3(-S * u.z, 0.0, S * u.x) * float(sk.get("lat", 0.0))
	return w / maxf(1.0, w.length()) * (K.Duel.DRIB_SHOW_V * float(sk.get("vel", 1.0)) / K.SCALA)


# abracadabra, in corsa: passo largo del piede della finta, che si pianta avanti accanto al pallone (il corpo va da
# quella parte: sembra che esca di lì); l'interno del piede del lato scelto prende il pallone e lo porta DIETRO la gamba
# d'appoggio (gambe incrociate, il piede gira intorno al pallone), finché il pallone spunta dall'altra parte, dal lato
# della finta; lì l'esterno dello stesso piede (parte B) lo fa schizzare indietro in diagonale, dal lato scelto.
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var v := _vel_corpo(c, S)
	var tp := maxf(0.12, g - T_APPOGGIO)
	var t1 := g - T_PRENDE
	var tm := g - T_DIETRO
	var t2 := g - T_FUORI
	K.rincorsa(c, pF, tp)
	# dove sta il piede d'appoggio (rispetto al corpo) quando atterra: accanto a dove l'interno prenderà il pallone;
	# poi resta fermo sul prato e il corpo gli passa sopra (v = velocità del corpo secondo il motore)
	var rel1 := Vector3(S * 0.05, 0, 0.23)
	var P := rel1 + v * (t1 - tp) - Vector3(S * P_PRENDE.x, 0, P_PRENDE.y)
	var da_P := func(d: Vector2, tt: float) -> Vector3: return P - v * (tt - tp) + Vector3(S * d.x, 0, d.y)
	c.appoggia(pF, tp, Vector2(P.x, P.z), F * 0.2, 0.1)
	c.stacca(pS, tp + 0.01)
	# pallone: l'interno lo porta indietro e verso la finta, dietro il tallone; poi il piede gli gira intorno e lo
	# spinge fuori dall'altra parte (punta in dentro = interno che guarda indietro; punta in fuori = interno avanti)
	c.palla_a(0.05, {"rel": Vector3(0, 0, 0.5)})
	c.tocca(pS, t1, "inside", Vector3(F * 0.75, 0.1, 0), {"rel": rel1})
	c.tocca(pS, tm, "inside", Vector3(F * 0.1, 0.05, 0), {"rel": da_P.call(P_DIETRO, tm), "lega": true})
	c.tocca(pS, t2, "inside", Vector3(S * 0.45, 0.05, 0), {"rel": da_P.call(P_FUORI, t2), "lega": true, "frena": true})
	# (se lo scatto tarda il piede è già dietro il pallone, dalla parte della finta, pronto per l'esterno)
	c.passa_palla(pS, g + 0.03, Vector3(F * 0.06, K.H + 0.05, -0.24), Vector3(F * 0.5, 0.2, 0), 0.02)
	# corpo: sul passo largo si butta dalla parte della finta, basso sull'appoggio; spalle girate di là
	c.chiave_bacino(tp, Vector3(F * 0.04, 0.85, 0.0))
	c.chiave_angoli(tp, Vector3(F * 0.15, 0.1, F * 0.06))
	c.chiave_busto(tp, Vector3(0.16, F * 0.12, F * 0.2))
	c.chiave_bacino(tm, Vector3(F * 0.08, 0.83, 0.0))
	c.chiave_angoli(tm, Vector3(F * 0.38, 0.1, F * 0.1))
	c.chiave_busto(tm, Vector3(0.2, F * 0.2, F * 0.34))
	c.chiave_bacino(t2, Vector3(F * 0.07, 0.84, 0.0))
	c.chiave_angoli(t2, Vector3(F * 0.3, 0.12, F * 0.08))
	c.chiave_busto(t2, Vector3(0.24, F * 0.14, F * 0.2))
	# braccia larghe (equilibrio su una gamba): quella della finta avanti, l'altra dietro e larga
	K.braccia(c, tp, pS, Vector3(0.3, -0.3, -0.16), Vector3(0.36, -0.18, 0.2))
	K.braccia(c, tm, pS, Vector3(0.42, -0.16, -0.2), Vector3(0.4, -0.12, 0.16))
	K.braccia(c, t2, pS, Vector3(0.4, -0.2, -0.1), Vector3(0.38, -0.16, 0.1))
	# sguardo: dalla parte della finta mentre il pallone sparisce dietro la gamba
	c.chiave_sguardo(tp, 0.5, F * 0.3)
	c.chiave_sguardo(t2, 0.9, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'esterno dello stesso piede fa schizzare il pallone in diagonale,
# avanti dal lato scelto (un piccolo salto sopra la punta del piede d'appoggio), e via di corsa
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.8), B_TOCCO,
		{"palla": [[tg + B_TOCCO + 0.13, {"rel": Vector3(S * 0.34, 0, 0.5), "arco": 0.07}]]})
