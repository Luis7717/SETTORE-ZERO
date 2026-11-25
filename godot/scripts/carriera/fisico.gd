# Fisico dei giocatori (solo Godot, 2026-11-22): altezza (basso, medio, alto) e corporatura (snello, normale,
# robusto). Si vede (figura più bassa/alta, più snella/robusta) e cambia le statistiche in partita.
#
# Dati: il campione ha i campi `altezza` e `corporatura` (indici 0..2 in ALTEZZE / CORPORATURE), scritti solo da
# Carriera.setFisico (editor), come l'esultanza: addChampion resta identico al JS. Gli altri giocatori (rosa, mercato,
# squadre del computer) non hanno i campi: il fisico si calcola sempre uguale da id, nome e ruolo (di()), con pesi
# per ruolo (portieri e difensori più spesso alti e robusti). Campione senza campi (salvataggio vecchio) = medio,
# normale. Il salvataggio non cambia chiave né forma.
#
# Statistiche: MOD_ALTEZZA + MOD_CORPORATURA si sommano alle statistiche quando si costruisce la squadra per il
# motore (applica / applicaSquadra, su copie): il motore non cambia. Le statistiche salvate, il valore e la
# valutazione restano quelli di base (stessi numeri del web). Numeri e motivi in DECISIONI.md.
extends RefCounted

const JS := preload("res://scripts/carriera/js.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const C := preload("res://sim/core.gd")
const Sotto := preload("res://sim/sottostat.gd")

const ALTEZZE := ["Basso", "Medio", "Alto"]
const CORPORATURE := ["Snello", "Normale", "Robusto"]
const PREDEFINITO := {"altezza": 1, "corporatura": 1}
const N := 3

## pesi per ruolo (basso/medio/alto, snello/normale/robusto)
const PESI_ALTEZZA := {"P": [5, 30, 65], "D": [15, 40, 45], "C": [35, 45, 20], "A": [30, 42, 28]}
const PESI_CORPORATURA := {"P": [15, 55, 30], "D": [12, 45, 43], "C": [35, 50, 15], "A": [30, 45, 25]}

## punti in più o in meno sulle statistiche (vel = velocità, fis = resistenza e accelerazione, dri = dribbling e
## controllo, dif = contrasti e intercetti, tes = colpo di testa e duelli aerei, por = parate e copertura del portiere)
const MOD_ALTEZZA := [
	{"tes": -8, "por": -5, "dri": 3, "vel": 1, "dif": -3},   # basso
	{},                                                       # medio
	{"tes": 8, "por": 5, "dif": 2, "dri": -2, "vel": -1},     # alto
]
const MOD_CORPORATURA := [
	{"vel": 2, "fis": 1, "dif": -3, "tes": -2},   # snello
	{},                                           # normale
	{"dif": 4, "tes": 2, "vel": -2, "fis": -2},   # robusto
]
const STAT_MIN := 1
const STAT_MAX := 99

## scala della figura: altezza su tutti gli assi (i piedi restano a terra: l'origine è ai piedi), corporatura in
## larghezza e profondità (X e Z, così il giro della figura intorno a Y non la deforma)
const SCALA_ALTEZZA := [0.94, 1.0, 1.06]
const SCALA_LARGHEZZA := [0.92, 1.0, 1.09]


static func valido(v: Variant) -> bool:
	return JS.is_integer(v) and int(v) >= 0 and int(v) < N


## fisico da un seme e dal ruolo (sempre uguale a parità di seme)
static func daSeme(seme: Variant, pos: Variant) -> Dictionary:
	var r := Asp.seeded(Asp.hash32("fisico", seme))
	var ruolo: String = pos if pos is String and PESI_ALTEZZA.has(pos) else "C"
	var a := Asp.wpick(r, PESI_ALTEZZA[ruolo])
	var c := Asp.wpick(r, PESI_CORPORATURA[ruolo])
	return {"altezza": a, "corporatura": c}


## fisico di un giocatore: i suoi campi se validi; altrimenti medio/normale per il campione, dal seme per gli altri
static func di(p: Variant) -> Dictionary:
	if not p is Dictionary:
		return PREDEFINITO.duplicate()
	var auto: Dictionary = PREDEFINITO
	if not p.get("champ", false):
		var nome: Variant = p.get("name", "")
		var id: Variant = p.get("id") if p.has("id") else "undefined"
		auto = daSeme(Asp.hash32(id, nome if nome != null else ""), p.get("pos", "C"))
	var a: Variant = p.get("altezza")
	var c: Variant = p.get("corporatura")
	return {"altezza": int(a) if valido(a) else int(auto.altezza), "corporatura": int(c) if valido(c) else int(auto.corporatura)}


## somma dei punti in più o in meno per un fisico {altezza, corporatura}
static func modificatori(f: Dictionary) -> Dictionary:
	var out := {}
	for m: Dictionary in [MOD_ALTEZZA[int(f.altezza)], MOD_CORPORATURA[int(f.corporatura)]]:
		for k: String in m:
			out[k] = int(out.get(k, 0)) + int(m[k])
	return out


## copia del giocatore con le statistiche della partita (base + fisico) e i campi altezza/corporatura scritti
## (la vista li legge da lì). L'originale non cambia.
static func applica(p: Variant) -> Variant:
	if not p is Dictionary:
		return p
	var q: Dictionary = p.duplicate()
	var f := di(p)
	q["altezza"] = f.altezza
	q["corporatura"] = f.corporatura
	var mods := modificatori(f)
	var sub: Dictionary = (p.sub as Dictionary).duplicate() if p.get("sub") is Dictionary else {}
	for k: String in mods:
		var d := int(mods[k])
		var base: float
		if k == "tes":
			base = C.headingOf(p) # senza `tes` il motore lo calcola così: lo si fissa prima di cambiarlo
		elif q.get(k) is int or q.get(k) is float:
			base = float(q[k])
		else:
			continue
		if d != 0:
			q[k] = clampi(int(round(base)) + d, STAT_MIN, STAT_MAX)
			# le sotto-statistiche di quella grande si spostano dello stesso passo (la media resta coerente)
			var passo := int(q[k]) - int(round(base))
			for sk: String in Sotto.GRUPPI.get(k, []):
				if sub.has(sk):
					sub[sk] = clampi(int(sub[sk]) + passo, STAT_MIN, STAT_MAX)
	if p.get("sub") is Dictionary:
		q["sub"] = sub
	return q


## copia della squadra (myMatchTeam / aiMatchTeam / squadraPartita) coi giocatori di applica()
static func applicaSquadra(t: Dictionary) -> Dictionary:
	var out := t.duplicate()
	out["players"] = (t.get("players", []) as Array).map(func(p: Variant) -> Variant: return applica(p))
	if t.get("bench") is Array:
		out["bench"] = (t.bench as Array).map(func(p: Variant) -> Variant: return applica(p))
	return out


## scala della figura (da moltiplicare per Coord.SCALE)
static func scala(f: Dictionary) -> Vector3:
	var h: float = SCALA_ALTEZZA[int(f.altezza)]
	var w: float = SCALA_LARGHEZZA[int(f.corporatura)]
	return Vector3(h * w, h, h * w)


## "Alto · Robusto"
static func testo(f: Dictionary) -> String:
	return "%s · %s" % [ALTEZZE[int(f.altezza)], CORPORATURE[int(f.corporatura)]]


## effetto in parole: "VEL −1, DRI −2, DIF +2, TES +8, POR +5" (etichette come nei menu)
static func testo_effetto(f: Dictionary) -> String:
	var nomi := {"vel": "VEL", "fis": "RES", "dri": "DRI", "dif": "DIF", "tes": "TES", "por": "POR", "tir": "TIR", "pas": "PAS"}
	var mods := modificatori(f)
	var parti: Array = []
	for k: String in ["vel", "fis", "dri", "dif", "tes", "por"]:
		var v := int(mods.get(k, 0))
		if v != 0:
			parti.append("%s %s%d" % [nomi[k], "+" if v > 0 else "−", absi(v)])
	return ", ".join(parti) if not parti.is_empty() else "nessun effetto"
