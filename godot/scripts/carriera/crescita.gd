# Il campione cresce giocando (solo versione Godot): le statistiche del giocatore principale (quello creato
# nell'editor, `champ: true` nella rosa) salgono con quello che fa in partita.
# I conteggi della partita vengono da scripts/partita/conta_giocatori.gd ({gol, tiri, passaggi, ...} per id).
# Ogni conteggio dà un po' di "progresso" a una o due statistiche; il progresso si accumula (s.progressi, decimali)
# e ogni volta che arriva a 1 la statistica sale di 1 punto. Crescita lenta: al massimo PER_PARTITA_MAX per
# statistica a partita, mai oltre 99, e più piano con l'età.
extends RefCounted

const MASSIMO := 99
const PER_PARTITA_MAX := 0.5     # progresso massimo di una statistica in una partita
## conteggio → [[statistica, progresso per ogni volta], ...]; "km" = chilometri corsi
const PESI := {
	"gol": [["tir", 0.25]],
	"in_porta": [["tir", 0.08]],
	"tiri": [["tir", 0.03]],
	"dribbling": [["dri", 0.1]],
	"scatti": [["vel", 0.08], ["dri", 0.03]],
	"passaggi": [["pas", 0.025]],
	"assist": [["pas", 0.15]],
	"contrasti": [["dif", 0.08]],
	"intercetti": [["dif", 0.06]],
	"testa": [["tes", 0.08], ["fis", 0.04]],
	"parate": [["por", 0.08]],
	"km": [["vel", 0.04], ["fis", 0.06]],
}
const NOMI := {"vel": "Velocità", "fis": "Fisico", "dri": "Dribbling", "tir": "Tiro", "dif": "Difesa",
	"pas": "Passaggio", "por": "Parate", "tes": "Colpo di testa"}
## età → quanto si cresce (1 = tutto): i giovani crescono di più, oltre i 30 quasi niente (poi c'è il calo
## di fine stagione di Carriera.endSeason)
const ETA := [[23, 1.0], [27, 0.85], [30, 0.55], [33, 0.25], [99, 0.1]]


static func fattore_eta(eta: int) -> float:
	for e: Array in ETA:
		if eta <= int(e[0]):
			return float(e[1])
	return 0.1


## progresso di ogni statistica in questa partita (già col tetto e col fattore dell'età): {stat: float}
static func progresso(conteggi: Dictionary, eta: int) -> Dictionary:
	var out := {}
	for k: String in PESI:
		var n := float(conteggi.get(k, 0))
		if n <= 0.0:
			continue
		for sp: Array in PESI[k]:
			out[sp[0]] = float(out.get(sp[0], 0.0)) + n * float(sp[1])
	var f := fattore_eta(eta)
	for st: String in out.keys():
		out[st] = minf(PER_PARTITA_MAX, out[st]) * f
	return out


## applica la crescita al giocatore p (cambia p e progressi[id]); ritorna le righe da mostrare:
## [{k, nome, su (punti interi guadagnati), ora (valore), parte (progresso di questa partita)}], prima chi è salito
static func applica(p: Dictionary, conteggi: Dictionary, progressi: Dictionary) -> Array:
	var chiave := str(p.id)
	var pr: Dictionary = progressi.get(chiave, {}) if progressi.get(chiave) is Dictionary else {}
	var righe: Array = []
	var guadagno := progresso(conteggi, int(p.get("age", 25)))
	for st: String in guadagno:
		if not p.has(st):
			continue
		var acc := float(pr.get(st, 0.0)) + float(guadagno[st])
		var su := int(floor(acc))
		acc -= su
		var prima := int(p[st])
		var ora := mini(MASSIMO, prima + su)
		if ora >= MASSIMO:
			acc = 0.0
		p[st] = ora
		pr[st] = snappedf(acc, 0.001)
		righe.append({"k": st, "nome": NOMI.get(st, st), "su": ora - prima, "ora": ora, "parte": snappedf(float(guadagno[st]), 0.01)})
	progressi[chiave] = pr
	righe.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.su != b.su:
			return a.su > b.su
		return a.parte > b.parte)
	return righe


## testo breve di una riga: "Tiro +1" (punto guadagnato) oppure "Tiro +0,3" (solo progresso)
static func testo(r: Dictionary) -> String:
	if int(r.su) > 0:
		return "%s +%d" % [r.nome, int(r.su)]
	return "%s +%s" % [r.nome, ("%.1f" % float(r.parte)).replace(".", ",")]
