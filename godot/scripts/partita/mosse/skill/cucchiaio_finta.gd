# Giochetto del dribbling "Finta col cucchiaio" (id `cucchiaio_finta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# Tempi della parte A (s prima dello scatto previsto)
const T_APPOGGIO := 0.26       # il piede della finta si pianta accanto al pallone (l'altra gamba è caricata dietro)
const T_PUNTA := 0.15          # la punta del piede del lato scelto scende sotto il pallone
const T_ALZA := 0.08           # ... e fa per alzarlo (il pallone si solleva appena e ricade lì)
const ALZA_H := 0.13           # m: di quanto
const B_TOCCO := 0.035         # s dopo lo scatto: l'esterno dello stesso piede lo porta via dal lato scelto


# finta col cucchiaio, in corsa: il piede della finta si pianta accanto al pallone, l'altra gamba si carica dietro
# (ginocchio piegato, braccia larghe, busto un po' indietro: come per alzare il pallone con la punta) e scende: la punta
# va sotto il pallone, che si solleva appena e resta lì sul prato; il corpo intanto scivola dalla parte della finta
# (dove porterebbe il cucchiaio) e lo stesso piede passa dall'altra parte del pallone: allo scatto (parte B) l'esterno
# lo porta via secco dal lato scelto, e il corpo gira e riparte da quella parte.
static func a(c: Coreo, S: float, g: float) -> void:
	var F := -S
	var pS := K.ls(S)
	var pF := K.ls(F)
	var tp := maxf(0.12, g - T_APPOGGIO)
	var ts := g - T_PUNTA
	var ta := g - T_ALZA
	K.rincorsa(c, pF, tp)
	# pallone: rallenta e si ferma sul prato accanto al piede d'appoggio; la punta lo solleva appena, lì dov'è
	c.palla_a(0.05, {"rel": Vector3(0, 0, 0.5)})
	c.palla_a(tp, {"rel": Vector3(S * 0.05, 0, 0.3)})
	c.appoggia_palla(pF, tp, Vector3(F * 0.24, K.H, -0.04), F * 0.1, 0.1)
	# gamba del cucchiaio: tallone alto dietro quando l'altro piede atterra, poi giù con la punta sotto il pallone
	c.stacca(pS, tp - 0.1)
	c.passa(pS, tp - 0.01, Vector3(S * 0.14, 0.56, -0.42), Vector3(0, 1.2, 0), 0.0)
	c.passa(pS, tp + 0.04, Vector3(S * 0.14, 0.58, -0.4), Vector3(0, 1.2, 0), 0.0)
	c.tocca(pS, ts, "toe", Vector3(0, -0.1, 0), {"resta": true})
	c.tocca(pS, ta, "toe", Vector3(0, -0.5, 0), {"resta": true, "h": ALZA_H, "lega": true})
	c.palla_a(g - 0.01, {"resta": true})
	# poi il piede passa sopra il pallone, dall'altra parte (quella della finta), pronto per l'esterno
	c.passa_palla(pS, g + 0.02, Vector3(F * 0.2, 0.2, -0.1), Vector3(F * 0.2, 0.2, 0), 0.05)
	# corpo: caricamento (busto dritto e indietro, bacino aperto), poi sopra il pallone, poi verso la finta
	c.chiave_bacino(tp, Vector3(0, 0.86, 0.02))
	c.chiave_angoli(tp, Vector3(S * 0.25, -0.06, 0))
	c.chiave_busto(tp, Vector3(-0.14, 0, S * 0.25))
	c.chiave_bacino(ts, Vector3(F * 0.03, 0.84, 0.0))
	c.chiave_angoli(ts, Vector3(0, 0.02, 0))
	c.chiave_busto(ts, Vector3(-0.04, 0, 0))
	c.chiave_bacino(ta, Vector3(F * 0.06, 0.88, 0.0))
	c.chiave_angoli(ta, Vector3(F * 0.2, -0.04, F * 0.06))
	c.chiave_busto(ta, Vector3(-0.1, F * 0.12, F * 0.2))
	c.chiave_bacino(g, Vector3(F * 0.03, 0.85, 0.0))
	c.chiave_angoli(g, Vector3(0, 0.1, 0))
	c.chiave_busto(g, Vector3(0.2, 0, S * 0.1))
	# braccia larghe da equilibrio: nel cucchiaio salgono (quella opposta alla gamba avanti)
	K.braccia(c, tp, pS, Vector3(0.32, -0.24, -0.26), Vector3(0.38, -0.12, 0.2))
	K.braccia(c, ta, pS, Vector3(0.36, -0.16, -0.12), Vector3(0.4, -0.06, 0.16))
	K.braccia(c, g, pS, Vector3(0.36, -0.2, 0.0), Vector3(0.38, -0.16, 0.1))
	# sguardo: giù sul pallone, poi dove andrebbe il cucchiaio (davanti, dalla parte della finta)
	c.chiave_sguardo(ts, 1.0, 0.0)
	c.chiave_sguardo(ta, 0.2, F * 0.35)
	c.chiave_sguardo(g, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto): l'esterno porta via il pallone di lato, dal lato scelto
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	K.via(c, S, tg, pS, "outside", K.esterno(S, 0.35), B_TOCCO,
		{"palla": [[tg + B_TOCCO + 0.14, {"rel": Vector3(S * 0.36, 0, 0.42)}]]})
