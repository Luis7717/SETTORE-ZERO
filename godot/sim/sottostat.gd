# Statistiche dettagliate (Luis 2026-11-25, "suddivideresti le statistiche come su FIFA?" → "procedi con quelle
# scelte"). Ogni statistica grande del giocatore (vel, tir, pas, dri, dif, fis, por) è la MEDIA arrotondata delle sue
# sotto-statistiche, che stanno nel campo `sub` del giocatore ({fin: 74, pot: 80, ...}). Il colpo di testa `tes`
# resta una statistica a sé (si mostra sotto Difesa).
# Chi non ha `sub` (salvataggi vecchi, squadre dei confronti col JS) gioca come prima: ogni sotto-statistica vale
# quanto la sua grande (valore()). Le funzioni portate dal JS (overall, value, ...) usano solo le grandi.
# Motore puro: niente grafica, numeri casuali solo dal generatore passato.
extends RefCounted

## grande → sue sotto-statistiche
const GRUPPI := {
	"vel": ["acc", "vmax"],
	"tir": ["fin", "pot", "lon", "vol", "rig"],
	"pas": ["pco", "plu", "cro", "eff", "pun"],
	"dri": ["agi", "ctl", "drb", "equ"],
	"dif": ["int", "ctr"],
	"fis": ["ele", "res", "frz", "agg"],
	"por": ["tuf", "rif", "pre", "pia"],
}
const NOMI := {
	"acc": "Accelerazione", "vmax": "Velocità massima",
	"fin": "Finalizzazione", "pot": "Potenza di tiro", "lon": "Tiri da lontano", "vol": "Al volo e in girata", "rig": "Rigori",
	"pco": "Passaggio corto", "plu": "Passaggio lungo", "cro": "Cross", "eff": "Effetto", "pun": "Punizioni",
	"agi": "Agilità", "ctl": "Controllo palla", "drb": "Dribbling", "equ": "Equilibrio",
	"int": "Intercetti", "ctr": "Contrasto", "tes": "Colpo di testa",
	"ele": "Elevazione", "res": "Resistenza", "frz": "Forza", "agg": "Aggressività",
	"tuf": "Tuffo", "rif": "Riflessi", "pre": "Presa", "pia": "Piazzamento",
}
const NOMI_GRANDI := {"vel": "Velocità", "tir": "Tiro", "pas": "Passaggi", "dri": "Dribbling", "dif": "Difesa",
	"fis": "Fisico", "por": "Portiere"}
const MIN := 15
const MAX := 99
## differenza massima di una sotto-statistica dalla sua grande quando si creano (±)
const SPARGI := 7.0


static func gruppo_di(k: String) -> String:
	for g: String in GRUPPI:
		if (GRUPPI[g] as Array).has(k):
			return g
	return ""


static func ha(p: Dictionary) -> bool:
	return p.get("sub") is Dictionary and not (p.sub as Dictionary).is_empty()


## valore della sotto-statistica k del giocatore sorgente p (senza `sub`: quello della sua grande)
static func valore(p: Dictionary, k: String) -> float:
	if p.get("sub") is Dictionary and (p.sub as Dictionary).has(k):
		return float(p.sub[k])
	return float(p.get(gruppo_di(k), 50))


## crea le sotto-statistiche di p dalle grandi (se mancano): sparse intorno alla grande, con somma esatta perché
## la media arrotondata resti uguale alla grande (valutazione e valore non cambiano). r = numeri casuali con seme
static func crea(p: Dictionary, r: Callable) -> void:
	if ha(p):
		return
	var sub := {}
	for g: String in GRUPPI:
		var chiavi: Array = GRUPPI[g]
		var base := int(p.get(g, 50))
		if g == "por" and str(p.get("pos", "")) != "P":
			for k: String in chiavi:
				sub[k] = base # portiere di chi non è portiere: tutte uguali
			continue
		var rumore: Array = []
		var media := 0.0
		for k: String in chiavi:
			var n: float = (float(r.call()) - 0.5) * 2.0 * SPARGI
			rumore.append(n)
			media += n
		media /= chiavi.size()
		var vals: Array = []
		var somma := 0
		for i in chiavi.size():
			var v := clampi(int(roundf(base + float(rumore[i]) - media)), MIN, MAX)
			vals.append(v)
			somma += v
		var resto := base * chiavi.size() - somma # porta la somma esatta (media = grande)
		var giri := 0
		while resto != 0 and giri < 200:
			var i := int(floor(float(r.call()) * chiavi.size()))
			var passo := 1 if resto > 0 else -1
			if vals[i] + passo >= MIN and vals[i] + passo <= MAX:
				vals[i] += passo
				resto -= passo
			giri += 1
		for i in chiavi.size():
			sub[chiavi[i]] = vals[i]
	p["sub"] = sub


## rimette le grandi uguali alla media arrotondata delle sotto-statistiche (dopo una crescita)
static func ricalcola(p: Dictionary) -> void:
	if not ha(p):
		return
	for g: String in GRUPPI:
		var chiavi: Array = GRUPPI[g]
		var somma := 0.0
		for k: String in chiavi:
			somma += float(p.sub.get(k, p.get(g, 50)))
		p[g] = clampi(int(roundf(somma / chiavi.size())), 1, MAX)


## sposta la sotto-statistica k (o "tes") di d, dentro MIN..MAX, poi ricalcola le grandi; ritorna il cambio vero
static func muovi(p: Dictionary, k: String, d: int) -> int:
	if k == "tes":
		var prima_t := int(p.get("tes", 50))
		p["tes"] = clampi(prima_t + d, MIN, MAX)
		return int(p.tes) - prima_t
	if not ha(p) or not (p.sub as Dictionary).has(k):
		return 0
	var prima := int(p.sub[k])
	p.sub[k] = clampi(prima + d, MIN, MAX)
	ricalcola(p)
	return int(p.sub[k]) - prima
