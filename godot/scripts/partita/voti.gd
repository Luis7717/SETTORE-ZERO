# Voti in pagella dei giocatori della persona a fine partita (schermata delle statistiche). Logica pura, senza nodi:
# si prova in tests/test_voti.gd. I conteggi vengono da conta_giocatori.gd (tabellino().giocatori[i].conti).
#
# Formula (punti), poi limitati fra 4 e 10 e arrotondati al mezzo punto:
#   6 di base
#   + risultato: vittoria +0,5 · pareggio 0 · sconfitta −0,5
#   + gol +1 ciascuno · assist +0,6
#   + dribbling riusciti +0,2 (al massimo +1) · contrasti vinti +0,25 (al massimo +1,25)
#   + intercetti +0,15 (al massimo +0,75) · passaggi riusciti +0,03 (al massimo +0,6)
#   + parate +0,4 (al massimo +2)
#   − gol subiti mentre era in campo: portiere −0,5 · difensore −0,3 · centrocampista −0,1 (attaccante niente)
#   + porta inviolata (squadra a zero gol subiti): portiere +0,5 · difensore +0,3
#   − palle perse −0,1 (al massimo −1,5)
# Migliore in campo: chi ha più punti (prima del limite e dell'arrotondamento); a pari punti il primo in elenco.
extends RefCounted

const BASE := 6.0
const VOTO_MIN := 4.0
const VOTO_MAX := 10.0
const VITTORIA := 0.5
const SCONFITTA := -0.5
# conteggio → [punti per ogni volta, tetto (0 = senza tetto)]
const PESI := {
	"gol": [1.0, 0.0],
	"assist": [0.6, 0.0],
	"dribbling": [0.2, 1.0],
	"contrasti": [0.25, 1.25],
	"intercetti": [0.15, 0.75],
	"passaggi": [0.03, 0.6],
	"parate": [0.4, 2.0],
}
const SUBITI := {"P": -0.5, "D": -0.3, "C": -0.1, "A": 0.0}
const INVIOLATA := {"P": 0.5, "D": 0.3}
const PERSA := -0.1
const PERSE_MAX := -1.5


## punti grezzi di un giocatore (ruolo "P"/"D"/"C"/"A", conteggi della partita, gol fatti e subiti dalla squadra)
static func punti(pos: String, conti: Dictionary, gol_mie: int, gol_loro: int) -> float:
	var v := BASE
	if gol_mie > gol_loro:
		v += VITTORIA
	elif gol_mie < gol_loro:
		v += SCONFITTA
	for k: String in PESI:
		var p: Array = PESI[k]
		var q := float(conti.get(k, 0)) * float(p[0])
		v += minf(q, float(p[1])) if float(p[1]) > 0.0 else q
	v += float(conti.get("subiti", 0)) * float(SUBITI.get(pos, 0.0))
	if gol_loro == 0:
		v += float(INVIOLATA.get(pos, 0.0))
	v += maxf(float(conti.get("perse", 0)) * PERSA, PERSE_MAX)
	return v


## voto da pagella: punti limitati fra 4 e 10, al mezzo punto
static func da_punti(p: float) -> float:
	return clampf(roundf(p * 2.0) / 2.0, VOTO_MIN, VOTO_MAX)


static func voto(pos: String, conti: Dictionary, gol_mie: int, gol_loro: int) -> float:
	return da_punti(punti(pos, conti, gol_mie, gol_loro))


## giocatori [{id, name, pos, champ, conti}] → copie con "voto", "punti" e "migliore" (uno solo, se l'elenco non è
## vuoto); l'ordine resta quello dato
static func calcola(giocatori: Array, gol_mie: int, gol_loro: int) -> Array:
	var out: Array = []
	var meglio := -1
	for i in giocatori.size():
		var g: Dictionary = (giocatori[i] as Dictionary).duplicate()
		var c: Variant = g.get("conti", {})
		g.punti = punti(str(g.get("pos", "C")), c if c is Dictionary else {}, gol_mie, gol_loro)
		g.voto = da_punti(g.punti)
		g.migliore = false
		if meglio < 0 or g.punti > out[meglio].punti:
			meglio = i
		out.append(g)
	if meglio >= 0:
		out[meglio].migliore = true
	return out


## voto scritto all'italiana: "6", "6,5"
static func testo(v: float) -> String:
	var intero := int(floorf(v))
	return str(intero) + (",5" if v - intero >= 0.25 else "")
