# Ruoli specifici (Luis 2026-11-26): al posto di D/C/A ogni giocatore ha un ruolo vero (campo `ruolo`) e, tranne
# il portiere, una seconda scelta (`ruolo2`). Il vecchio `pos` (P/D/C/A) resta: è il "gruppo" del ruolo e lo usano il
# motore (IA) e i confronti col JS. Chi non ha `ruolo` (squadre dei confronti col JS, prove) gioca e si valuta come prima.
#
# Qui c'è tutto quello che riguarda i ruoli, in un posto solo:
# - POSTI: per ogni modulo il ruolo di ognuno degli 11 posti (stesso ordine di C.FORMATIONS). SI CAMBIA QUI.
# - COMPATIBILI e fattore(): quanto rende un giocatore in un posto che non è il suo.
# - PESI e valuta(): valutazione complessiva per ruolo (dalle sotto-statistiche, sim/sottostat.gd).
# - PROFILO e modella(): statistiche coerenti col ruolo per i giocatori generati.
# - assegna_rosa() e seconda(): ruolo e seconda scelta per i giocatori dei salvataggi vecchi (statistiche intatte).
# Motore puro: niente grafica, numeri casuali solo dal generatore passato.
extends RefCounted

const Sotto := preload("sottostat.gd")

const TUTTI := ["P", "TD", "TS", "DC", "CDC", "CC", "ED", "ES", "COC", "ATT", "AD", "AS"]
const GRUPPO := {"P": "P", "TD": "D", "TS": "D", "DC": "D", "CDC": "C", "CC": "C", "ED": "C", "ES": "C", "COC": "C",
	"ATT": "A", "AD": "A", "AS": "A"}
## ruolo di chi ha solo il gruppo (giocatori senza `ruolo`)
const PREDEFINITO := {"P": "P", "D": "DC", "C": "CC", "A": "ATT"}
const NOMI := {"P": "Portiere", "TD": "Terzino destro", "TS": "Terzino sinistro", "DC": "Difensore centrale",
	"CDC": "Mediano", "CC": "Centrocampista", "ED": "Esterno destro", "ES": "Esterno sinistro", "COC": "Trequartista",
	"ATT": "Attaccante", "AD": "Ala destra", "AS": "Ala sinistra"}
## ruoli del gruppo, nell'ordine in cui si mostrano
const DEL_GRUPPO := {"P": ["P"], "D": ["TS", "DC", "TD"], "C": ["CDC", "CC", "ES", "ED", "COC"], "A": ["AS", "ATT", "AD"]}

## ruolo di ogni posto, modulo per modulo (ordine dei posti di C.FORMATIONS). Unico posto da cambiare.
const POSTI := {
	"4-4-2": ["P", "TS", "DC", "DC", "TD", "ES", "CC", "CC", "ED", "ATT", "ATT"],
	"4-3-3": ["P", "TS", "DC", "DC", "TD", "CC", "CC", "CC", "AS", "ATT", "AD"],
	"3-5-2": ["P", "DC", "DC", "DC", "ES", "CDC", "COC", "CDC", "ED", "ATT", "ATT"],
	"4-2-3-1": ["P", "TS", "DC", "DC", "TD", "CDC", "CDC", "ES", "COC", "ED", "ATT"],
	"4-5-1": ["P", "TS", "DC", "DC", "TD", "ES", "CC", "CDC", "CC", "ED", "ATT"],
	"3-4-3": ["P", "DC", "DC", "DC", "ES", "CC", "CC", "ED", "AS", "ATT", "AD"],
	"5-3-2": ["P", "TS", "DC", "DC", "DC", "TD", "CC", "CDC", "CC", "ATT", "ATT"],
	"4-1-4-1": ["P", "TS", "DC", "DC", "TD", "CDC", "ES", "CC", "CC", "ED", "ATT"],
	"4-2-4": ["P", "TS", "DC", "DC", "TD", "CC", "CC", "AS", "ATT", "ATT", "AD"],
	"4-3-2-1": ["P", "TS", "DC", "DC", "TD", "CC", "CC", "CC", "ATT", "ATT", "ATT"],
	"4-2-2-2": ["P", "TS", "DC", "DC", "TD", "CDC", "CDC", "COC", "COC", "ATT", "ATT"],
	"4-3-3 offensivo": ["P", "TS", "DC", "DC", "TD", "CC", "CC", "COC", "AS", "ATT", "AD"],
	"4-3-3 difensivo": ["P", "TS", "DC", "DC", "TD", "CDC", "CC", "CC", "AS", "ATT", "AD"],
	"4-1-2-1-2 largo": ["P", "TS", "DC", "DC", "TD", "CDC", "ES", "ED", "COC", "ATT", "ATT"],
}

## ruolo del giocatore → posti dove gioca quasi senza malus (Luis: terzini ⇄ esterni e esterni ⇄ ali dello stesso lato,
## ATT ⇄ COC, DC ⇄ CDC; il CC può fare il COC ma il COC non fa il CC)
const COMPATIBILI := {
	"TS": ["ES"], "TD": ["ED"], "ES": ["TS", "AS"], "ED": ["TD", "AD"], "AS": ["ES"], "AD": ["ED"],
	"ATT": ["COC"], "COC": ["ATT"], "DC": ["CDC"], "CDC": ["DC"], "CC": ["COC"],
}
## tra cosa si sceglie la seconda scelta (le prime sono le più probabili)
const SECONDE := {
	"TS": ["ES", "TD", "DC"], "TD": ["ED", "TS", "DC"], "DC": ["CDC", "TD", "TS"], "CDC": ["DC", "CC"],
	"CC": ["COC", "CDC", "ES", "ED"], "COC": ["ATT", "AS", "AD"], "ES": ["TS", "AS", "ED", "CC"],
	"ED": ["TD", "AD", "ES", "CC"], "AS": ["ES", "AD", "ATT"], "AD": ["ED", "AS", "ATT"], "ATT": ["COC", "AS", "AD"],
}
## terzini e ali non si scambiano mai (Luis 2026-11-27: "i terzini non possono mai fare le ali, al massimo gli
## esterni"): nessuna seconda scelta tra loro, malus pieno da linea lontana e autoLineup/fixLineup non li mettono lì
const VIETATI := {"TS": ["AS", "AD"], "TD": ["AS", "AD"], "AS": ["TS", "TD"], "AD": ["TS", "TD"]}
## esterno dello stesso lato: prende il posto di una seconda scelta vietata (salvataggi di prima)
const ESTERNO := {"TS": "ES", "AS": "ES", "TD": "ED", "AD": "ED"}
const SPECCHIO := {"TS": "TD", "TD": "TS", "ES": "ED", "ED": "ES", "AS": "AD", "AD": "AS"}
## fascia del ruolo: -1 sinistra, 1 destra, 0 centro
const LATO := {"TS": -1, "ES": -1, "AS": -1, "TD": 1, "ED": 1, "AD": 1}

# quanto rende fuori dal suo ruolo (moltiplica tiro, passaggi, dribbling, difesa, testa; come il vecchio POSPEN)
const F_SECONDA := 0.98        # nella seconda scelta
const F_COMPATIBILE := 0.97    # in un ruolo compatibile
const F_SPECCHIO := 0.94       # stesso ruolo sull'altra fascia
const F_GRUPPO := 0.9          # altro ruolo della stessa linea (DC terzino, COC centrocampista, punta ala)
const F_VICINO := 0.86         # linea accanto (difesa ⇄ centrocampo, centrocampo ⇄ attacco)
const F_LONTANO := 0.72        # difesa ⇄ attacco (ala in difesa centrale, terzino ala: VIETATI)
const F_PORTIERE := 0.6        # portiere fuori dalla porta, o un altro in porta (come prima)
## sotto questo fattore la Rosa segna "fuori ruolo"
const F_FUORI := 0.96

## pesi della valutazione complessiva per ruolo: sotto-statistiche (e `tes`), somma 1
const PESI := {
	"TD": {"vmax": 0.12, "acc": 0.10, "cro": 0.12, "ctr": 0.18, "int": 0.16, "res": 0.12, "pco": 0.08, "drb": 0.06, "ctl": 0.06},
	"DC": {"int": 0.20, "ctr": 0.25, "tes": 0.15, "frz": 0.15, "ele": 0.10, "vmax": 0.08, "pco": 0.07},
	"CDC": {"int": 0.22, "ctr": 0.20, "pco": 0.16, "plu": 0.10, "res": 0.10, "frz": 0.10, "ctl": 0.07, "agg": 0.05},
	"CC": {"pco": 0.22, "plu": 0.14, "ctl": 0.14, "res": 0.12, "int": 0.08, "ctr": 0.06, "drb": 0.08, "lon": 0.08, "acc": 0.08},
	"COC": {"pco": 0.18, "drb": 0.16, "ctl": 0.16, "lon": 0.12, "fin": 0.10, "eff": 0.08, "agi": 0.10, "acc": 0.10},
	"ED": {"vmax": 0.14, "acc": 0.12, "cro": 0.18, "res": 0.12, "drb": 0.12, "ctl": 0.10, "pco": 0.12, "ctr": 0.05, "int": 0.05},
	"AD": {"vmax": 0.15, "acc": 0.15, "drb": 0.18, "agi": 0.08, "ctl": 0.10, "cro": 0.12, "fin": 0.12, "lon": 0.05, "pco": 0.05},
	"ATT": {"fin": 0.30, "tes": 0.12, "frz": 0.10, "pot": 0.10, "vol": 0.08, "acc": 0.10, "vmax": 0.08, "ctl": 0.07, "drb": 0.05},
}
## giocatori generati: quanto si spostano le sotto-statistiche da quelle "generiche" del gruppo (poi modella() rimette
## la valutazione dov'era)
const PROFILO := {
	"TD": {"acc": 5, "vmax": 5, "cro": 9, "res": 4, "drb": 3, "ctl": 3, "pco": 2, "frz": -4, "ele": -4, "tes": -6, "plu": -2},
	"DC": {"frz": 4, "ele": 3, "tes": 4, "ctr": 2, "int": 1, "acc": -4, "vmax": -3, "cro": -5, "drb": -3, "agi": -4},
	"CDC": {"int": 14, "ctr": 14, "frz": 5, "agg": 6, "res": 4, "pco": -2, "plu": -1, "ctl": -2, "fin": -7, "lon": -4, "drb": -6, "agi": -4, "acc": -2, "eff": -4, "cro": -4},
	"CC": {"pco": 2, "plu": 2, "res": 5, "ctl": 2, "lon": 1},
	"COC": {"drb": 5, "agi": 4, "ctl": 3, "lon": 6, "fin": 4, "eff": 4, "pco": 1, "int": -6, "ctr": -7, "frz": -3, "res": -2, "tes": -2},
	"ED": {"acc": 7, "vmax": 8, "cro": 10, "res": 5, "drb": 2, "plu": -4, "lon": -4, "fin": -3, "frz": -3, "int": 1, "ctr": 1, "tes": -3},
	"AD": {"acc": 6, "vmax": 6, "drb": 7, "agi": 6, "cro": 10, "eff": 4, "ctl": 2, "frz": -6, "ele": -5, "tes": -8, "pot": -4, "fin": -5, "lon": -4, "vol": -3},
	"ATT": {"fin": 3, "tes": 6, "frz": 5, "ele": 4, "pot": 2, "vol": 2, "cro": -5, "agi": -2, "plu": -3, "drb": -1},
}
## scarti delle statistiche grandi di un giocatore generato (Carriera.genPlayer), per gruppo: servono alla taratura
const GENERICO := {
	"D": {"dif": 5, "fis": 3, "vel": -2, "pas": -6, "dri": -10, "tir": -18},
	"C": {"pas": 5, "dri": 1, "vel": -2, "dif": -6, "tir": -5, "fis": -2},
	"A": {"tir": 5, "vel": 2, "dri": 2, "pas": -6, "fis": -3, "dif": -22},
}
const TES_GRUPPO := {"D": 8, "C": -1, "A": 2}
## quanti per ruolo in una rosa (ogni 4 difensori, 6 centrocampisti, 4 attaccanti): per assegnare i ruoli a una rosa
const QUOTE := {"TS": 1.0, "DC": 2.0, "TD": 1.0, "CDC": 1.0, "CC": 2.0, "ES": 1.0, "ED": 1.0, "COC": 1.0, "AS": 1.0, "ATT": 2.0, "AD": 1.0}
const PESO_QUOTA := 4.0        # punti di valutazione tolti a un ruolo già pieno, quando si assegna la rosa
const PREMIO_SECONDA := [1.5, 0.5, 0.0, 0.0]

static var _tara := {}


static func valido(r: Variant) -> bool:
	return r is String and GRUPPO.has(r)


static func gruppo(r: String) -> String:
	return GRUPPO.get(r, r if r.length() == 1 else "C")


static func nome(r: String) -> String:
	return NOMI.get(r, r)


## ruolo di ogni posto del modulo (per un modulo sconosciuto: quelli predefiniti del gruppo del posto)
static func posti(modulo: String, F: Array = []) -> Array:
	if POSTI.has(modulo):
		return POSTI[modulo]
	var out: Array = []
	for slot: Array in F:
		out.append(PREDEFINITO.get(str(slot[0]), "CC"))
	return out


## ruolo del giocatore sorgente: `ruolo` se c'è, sennò quello predefinito del suo gruppo
static func di(p: Dictionary) -> String:
	var r: Variant = p.get("ruolo")
	if valido(r):
		return r
	return PREDEFINITO.get(str(p.get("pos", "C")), "CC")


static func seconda_di(p: Dictionary) -> String:
	var r: Variant = p.get("ruolo2")
	return r if valido(r) else ""


static func _pesi(r: String) -> Dictionary:
	return PESI.get(r, PESI.get(SPECCHIO.get(r, ""), {}))


static func _profilo(r: String) -> Dictionary:
	return PROFILO.get(r, PROFILO.get(SPECCHIO.get(r, ""), {}))


static func _stat(p: Dictionary, k: String) -> float:
	if k == "tes":
		return float(p.get("tes", (float(p.get("fis", 50)) + float(p.get("tir", 50))) / 2.0))
	return Sotto.valore(p, k)


## valutazione del vecchio gioco per gruppo (P/D/C/A), senza malus: stessa formula e stesso ordine di career.js
static func base_gruppo(p: Dictionary, g: String) -> float:
	if g == "P":
		return p.por * 0.72 + p.fis * 0.14 + p.pas * 0.14
	if g == "D":
		return p.dif * 0.45 + p.fis * 0.2 + p.vel * 0.15 + p.pas * 0.1 + p.dri * 0.1
	if g == "C":
		return p.pas * 0.35 + p.dri * 0.25 + p.dif * 0.12 + p.vel * 0.12 + p.tir * 0.16
	return p.tir * 0.4 + p.vel * 0.22 + p.dri * 0.23 + p.pas * 0.1 + p.fis * 0.05


static func _pesata(p: Dictionary, r: String) -> float:
	var w := _pesi(r)
	var o := 0.0
	for k: String in w:
		o += _stat(p, k) * float(w[k])
	return o


## taratura del ruolo: un giocatore "generico" del gruppo (come quelli dei salvataggi vecchi) vale in media quanto
## valeva con la formula vecchia, in qualunque ruolo del suo gruppo. Calcolata una volta dalle tabelle.
static func tara(r: String) -> float:
	if _tara.has(r):
		return _tara[r]
	var g := gruppo(r)
	var t := 0.0
	if GENERICO.has(g):
		var p := {"vel": 60.0, "tir": 60.0, "pas": 60.0, "dri": 60.0, "dif": 60.0, "fis": 60.0, "por": 12.0}
		for k: String in GENERICO[g]:
			p[k] = 60.0 + float(GENERICO[g][k])
		p["tes"] = (p.fis + p.tir) / 2.0 + float(TES_GRUPPO[g])
		t = base_gruppo(p, g) - _pesata(p, r)
	_tara[r] = t
	return t


## valutazione del giocatore come se il ruolo r fosse il suo (senza malus), coi decimali
static func valuta(p: Dictionary, r: String) -> float:
	if r == "P" or not GRUPPO.has(r):
		return base_gruppo(p, "P" if r == "P" else gruppo(r))
	return _pesata(p, r) + tara(r)


## quanto rende il giocatore nel posto `posto` (1 = è il suo ruolo). portiere = fattore di chi è fuori dalla porta
static func fattore(p: Dictionary, posto: String, portiere: float = F_PORTIERE) -> float:
	var r := di(p)
	if r == posto:
		return 1.0
	if (r == "P") != (posto == "P"):
		return portiere
	if vietato(p, posto):
		return F_LONTANO
	if seconda_di(p) == posto:
		return F_SECONDA
	if (COMPATIBILI.get(r, []) as Array).has(posto):
		return F_COMPATIBILE
	var a := gruppo(r)
	var b := gruppo(posto)
	if a == b:
		return F_SPECCHIO if SPECCHIO.get(r, "") == posto else F_GRUPPO
	if a != "C" and b != "C":
		return F_LONTANO
	return F_VICINO


## terzino in un posto da ala o ala in un posto da terzino (VIETATI): la formazione automatica non ce li mette mai
static func vietato(p: Dictionary, posto: String) -> bool:
	return (VIETATI.get(di(p), []) as Array).has(posto)


## valutazione mostrata nel suo ruolo
static func overall(p: Dictionary) -> int:
	return int(floor(valuta(p, di(p)) + 0.5))


## valutazione mostrata nel posto `posto` (col malus se non è il suo ruolo; portiere fuori porta 0,55 come prima)
static func overall_come(p: Dictionary, posto: String) -> int:
	return int(floor(valuta(p, posto) * fattore(p, posto, 0.55) + 0.5))


## seconda scelta per un giocatore che ha già il ruolo: tra le SECONDE del ruolo, quella dove vale di più (le prime
## della lista, le compatibili, partono avvantaggiate). Niente numeri casuali: stesso giocatore = stessa scelta.
static func seconda(p: Dictionary) -> String:
	var cand: Array = SECONDE.get(di(p), [])
	var best := ""
	var bo := -INF
	for i in cand.size():
		var o: float = valuta(p, cand[i]) + float(PREMIO_SECONDA[mini(i, PREMIO_SECONDA.size() - 1)])
		if o > bo:
			bo = o
			best = cand[i]
	return best


## salvataggi vecchi e nuovi arrivati: dà `ruolo` e `ruolo2` a chi nella rosa non li ha, senza toccare le
## statistiche. Chi è titolare in un posto del suo gruppo prende il ruolo di quel posto (l'ha messo lì la persona);
## gli altri il ruolo del gruppo dove valgono di più, tenendo la rosa assortita (QUOTE). posti_modulo = ruoli dei
## posti della formazione, nell'ordine di lineup. Ritorna quanti ne ha assegnati.
static func assegna_rosa(squad: Array, lineup: Array, posti_modulo: Array) -> int:
	var conta := {}
	for p: Dictionary in squad:
		if valido(p.get("ruolo")) and gruppo(p.ruolo) == str(p.get("pos", "")):
			conta[p.ruolo] = int(conta.get(p.ruolo, 0)) + 1
	var fatti := 0
	for giro in 2: # prima i titolari nel loro gruppo, poi tutti gli altri
		for p: Dictionary in squad:
			var g := str(p.get("pos", "C"))
			if valido(p.get("ruolo")) and gruppo(p.ruolo) == g:
				continue
			var r := ""
			if g == "P":
				r = "P"
			elif giro == 0:
				var i := lineup.find(p.get("id"))
				if i >= 0 and i < posti_modulo.size() and gruppo(posti_modulo[i]) == g:
					r = posti_modulo[i]
			else:
				var bo := -INF
				for cand: String in DEL_GRUPPO.get(g, ["CC"]):
					var o: float = valuta(p, cand) - PESO_QUOTA * float(conta.get(cand, 0)) / float(QUOTE.get(cand, 1.0))
					if o > bo:
						bo = o
						r = cand
			if r == "":
				continue
			p["ruolo"] = r
			conta[r] = int(conta.get(r, 0)) + 1
			fatti += 1
	for p: Dictionary in squad:
		sistema_seconda(p)
	return fatti


## `ruolo2` giusto: niente per il portiere, mai uguale al ruolo; se manca o è sbagliato lo sceglie seconda(); un
## terzino con un'ala come seconda scelta (o un'ala con un terzino) prende l'esterno dello stesso lato
static func sistema_seconda(p: Dictionary) -> void:
	var r := di(p)
	if r == "P":
		p.erase("ruolo2")
		return
	var s: Variant = p.get("ruolo2")
	if valido(s) and (VIETATI.get(r, []) as Array).has(s):
		p["ruolo2"] = ESTERNO[r]
		return
	if not valido(s) or s == r or s == "P":
		p["ruolo2"] = seconda(p)


## giocatore appena generato (statistiche "generiche" del gruppo, con le sotto-statistiche): gli dà il ruolo r e
## statistiche che hanno senso per quel ruolo (PROFILO), poi alza o abbassa insieme quelle che contano per il ruolo
## finché la valutazione nuova è uguale a quella vecchia del gruppo: forza delle squadre, valore e prezzi restano.
## Seconda scelta con r2 (numeri casuali con seme; null = la sceglie seconda()).
static func modella(p: Dictionary, r: String, r2: Variant = null) -> void:
	if not GRUPPO.has(r):
		return
	p["ruolo"] = r
	p["pos"] = GRUPPO[r]
	if r == "P":
		p.erase("ruolo2")
		return
	var meta := int(floor(base_gruppo(p, GRUPPO[r]) + 0.5))
	if Sotto.ha(p):
		var prof := _profilo(r)
		for k: String in prof:
			_sposta(p, k, int(prof[k]))
		var w := _pesi(r)
		for _giro in 6:
			var d := meta - overall(p)
			if d == 0:
				break
			for k: String in w:
				_sposta(p, k, d)
		Sotto.ricalcola(p)
	if r2 is Callable:
		var cand: Array = SECONDE.get(r, [])
		var x := float(r2.call())
		p["ruolo2"] = cand[0] if x < 0.55 else (cand[1] if x < 0.85 else cand[mini(2, cand.size() - 1)])
	else:
		sistema_seconda(p)


static func _sposta(p: Dictionary, k: String, d: int) -> void:
	if k == "tes":
		p["tes"] = clampi(int(p.get("tes", 50)) + d, Sotto.MIN, Sotto.MAX)
	elif (p.sub as Dictionary).has(k):
		p.sub[k] = clampi(int(p.sub[k]) + d, Sotto.MIN, Sotto.MAX)
