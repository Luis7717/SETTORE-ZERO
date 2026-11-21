# Obiettivi della dirigenza e rivalità (solo versione Godot).
# - Obiettivo: a inizio stagione, dalla forza della mia squadra rispetto alle altre della divisione (posto nella
#   classifica delle forze): titolo / promozione / metà classifica / salvezza. A fine stagione premio o penalità in
#   soldi del mercato, in proporzione agli incassi della divisione. Stato in s.obiettivo.
# - Rivale: la squadra della mia divisione con la forza più vicina alla mia (scelta una volta e tenuta finché resta
#   nella mia divisione). Partita contro la rivale = derby: premio in più se si vince. Stato in s.rivale.
# Niente numeri casuali: le scelte vengono solo dallo stato.
extends RefCounted

## tipo → [posto massimo da raggiungere, testo, premio (× incasso della divisione)]
const TIPI := {
	"titolo": [1, "Vincere il titolo", 6.0],
	"promozione": [2, "Promozione (primi 2 posti)", 5.0],
	"meta": [5, "Metà classifica (primi 5)", 3.0],
	"salvezza": [8, "Salvezza (non negli ultimi 2)", 2.0],
}
const PENALITA := 1.5          # obiettivo mancato: −1,5 × incasso della divisione (mai sotto zero di cassa)
const DERBY_PREMIO := 0.5      # derby vinto: + metà dell'incasso della divisione


## posto della mia squadra tra le forze della divisione (1 = la più forte; a pari forza conto prima le altre)
static func posto_forza(mia: int, altre: Array) -> int:
	var n := 1
	for r: Variant in altre:
		if int(r) >= mia:
			n += 1
	return n


## tipo di obiettivo dalla divisione d (0 = Prima) e dal posto tra le forze
static func tipo_per(d: int, posto: int) -> String:
	if d == 0:
		return "titolo" if posto == 1 else ("meta" if posto <= 5 else "salvezza")
	return "promozione" if posto <= 2 else ("meta" if posto <= 6 else "salvezza")


static func nuovo(stagione: int, d: int, mia: int, altre: Array) -> Dictionary:
	var t := tipo_per(d, posto_forza(mia, altre))
	return {"stagione": stagione, "div": d, "tipo": t, "posto": int(TIPI[t][0])}


static func testo(ob: Variant) -> String:
	if not ob is Dictionary or not TIPI.has(ob.get("tipo")):
		return ""
	return String(TIPI[ob.tipo][1])


## fine stagione: obiettivo ob, posto finale pos, incasso della divisione base, cassa attuale soldi.
## Ritorna {tipo, testo, riuscito, soldi (premio + o penalità −), messaggio}
static func valuta(ob: Dictionary, pos: int, base: int, soldi: int) -> Dictionary:
	var t: String = ob.get("tipo", "salvezza")
	var riuscito := pos <= int(ob.get("posto", 8))
	var delta: int
	var msg: String
	if riuscito:
		delta = int(round(base * float(TIPI[t][2])))
		msg = "La dirigenza è contenta, obiettivo raggiunto: %s." % TIPI[t][1]
	else:
		delta = -mini(maxi(soldi, 0), int(round(base * PENALITA)))
		msg = "La dirigenza è delusa, obiettivo mancato: %s." % TIPI[t][1]
	return {"tipo": t, "testo": TIPI[t][1], "riuscito": riuscito, "soldi": delta, "messaggio": msg}


## rivale nella divisione `ids` (senza "me"): resta quella di prima se è ancora lì, altrimenti la forza più vicina
## alla mia (a pari distanza la più forte, poi l'id più piccolo). teams = s.teams
static func scegli_rivale(prima: Variant, ids: Array, teams: Dictionary, mia: int) -> String:
	if prima is String and prima != "" and ids.has(prima):
		return prima
	var best := ""
	var bd := 1 << 30
	var br := -1
	for id: String in ids:
		if id == "me" or not teams.has(id):
			continue
		var r := int(teams[id].get("rating", 55))
		var dd := absi(r - mia)
		if dd < bd or (dd == bd and (r > br or (r == br and id < best))):
			best = id
			bd = dd
			br = r
	return best


static func premio_derby(base: int, mie: int, loro: int) -> int:
	return int(round(base * DERBY_PREMIO)) if mie > loro else 0
