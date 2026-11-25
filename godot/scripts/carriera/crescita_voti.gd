# Crescita della rosa coi voti in pagella (solo Godot, Luis 2026-11-25): "un giocatore può crescere post partita
# se prende più di 6 e decrescere se prende meno di 6, una crescita che varia in base all'età"; "a metà stagione,
# salvo il campione che non cambia età, gli altri giocatori guadagnano un anno e in base alle prestazioni medie
# delle partite salgono o scendono con valori livellati sull'età".
# Il campione no: lui cresce con quello che fa in partita (crescita.gd) e non invecchia.
# Logica pura (niente nodi); lo stato sta nella carriera:
#   s.voti     = {id: [somma dei voti, partite]} da metà stagione a metà stagione (media_voti, offerte del mercato)
#   s.progVoti = {id: progresso} decimali della crescita partita per partita (a ±1 una statistica sale/scende di 1)
#   s.metaStagione = stagione in cui è già stata fatta la metà stagione
# Prove: tests/test_crescita_voti.gd.
extends RefCounted

const VOTO_NEUTRO := 6.0
const STAT_MIN := 15
const STAT_MAX := 99
## progresso per punto di voto sopra/sotto il 6 (a 20 anni un 7 = +0,5: una statistica +1 ogni due partite)
const PER_PUNTO := 0.5
## età → [quanto si cresce col voto alto, quanto si cala col voto basso]
const ETA := [[21, 1.0, 0.35], [24, 0.8, 0.5], [28, 0.55, 0.7], [31, 0.3, 0.9], [99, 0.15, 1.1]]
## metà stagione: punti per ogni punto di media sopra/sotto il 6 (poi × fattore dell'età) ...
const META_PER_PUNTO := 4.0
## ... più la spinta dell'età, anche per chi non ha giocato: [fino a età, punti]
const META_ETA := [[21, 2.0], [24, 1.0], [28, 0.0], [31, -1.0], [33, -2.0], [99, -3.0]]
## statistiche che si muovono, per ruolo (come la crescita dei giovani del web)
const STAT_RUOLO := {"P": ["por", "fis", "pas"], "D": ["dif", "fis", "vel", "pas"],
	"C": ["pas", "dri", "tir", "vel", "dif"], "A": ["tir", "vel", "dri", "pas"]}


static func _riga_eta(eta: int) -> Array:
	for e: Array in ETA:
		if eta <= int(e[0]):
			return e
	return ETA[ETA.size() - 1]


## fattore dell'età: col voto sopra il 6 quanto si cresce, sotto quanto si cala
static func fattore(eta: int, su: bool) -> float:
	var e := _riga_eta(eta)
	return float(e[1]) if su else float(e[2])


## progresso di una partita col voto v a quell'età (positivo = cresce)
static func progresso(v: float, eta: int) -> float:
	var d := v - VOTO_NEUTRO
	return d * PER_PUNTO * fattore(eta, d > 0.0)


static func spinta_eta(eta: int) -> float:
	for e: Array in META_ETA:
		if eta <= int(e[0]):
			return float(e[1])
	return -3.0


## punti interi di metà stagione (con l'età già aumentata): media dei voti (o null se non ha giocato) e età
static func punti_meta(media_: Variant, eta: int) -> int:
	var p := spinta_eta(eta)
	if media_ != null:
		var d := float(media_) - VOTO_NEUTRO
		p += d * META_PER_PUNTO * fattore(eta, d > 0.0)
	return int(roundf(p))


## media dei voti di id in voti ({id: [somma, n]}), o null se non ha giocato
static func media(voti: Dictionary, id: Variant) -> Variant:
	var v: Variant = voti.get(str(id))
	if not v is Array or v.size() < 2 or float(v[1]) <= 0.0:
		return null
	return float(v[0]) / float(v[1])


## muove le statistiche del ruolo di p di `punti` (positivi su, negativi giù), una alla volta a caso (r = numeri
## casuali con seme); ritorna {stat: differenza} delle statistiche cambiate davvero
static func muovi(p: Dictionary, punti: int, r: Callable) -> Dictionary:
	var out := {}
	var chiavi: Array = STAT_RUOLO.get(str(p.get("pos", "C")), STAT_RUOLO.C)
	var passo := 1 if punti > 0 else -1
	for _i in absi(punti):
		var k: String = chiavi[int(floor(r.call() * chiavi.size()))]
		if not p.has(k):
			continue
		var prima := int(p[k])
		p[k] = clampi(prima + passo, STAT_MIN, STAT_MAX)
		if int(p[k]) != prima:
			out[k] = int(out.get(k, 0)) + passo
	return out


## voti di una partita: pagella [{id, voto}] (voti.gd calcola) → aggiorna voti e progressi dei giocatori della
## rosa (campione escluso). Ritorna le righe da mostrare [{nome, voto, su (+1/-1 per stat cambiata), stat}]
static func dopo_partita(rosa: Array, pagella: Array, voti: Dictionary, prog: Dictionary, r: Callable) -> Array:
	var per_id := {}
	for p: Dictionary in rosa:
		per_id[str(p.id)] = p
	var righe: Array = []
	for g: Variant in pagella:
		if not g is Dictionary or not g.has("voto"):
			continue
		var id := str(g.get("id", ""))
		var p: Variant = per_id.get(id)
		if p == null or p.get("champ", false):
			continue
		var v := float(g.voto)
		var tot: Array = voti.get(id) if voti.get(id) is Array and voti.get(id).size() >= 2 else [0.0, 0]
		voti[id] = [snappedf(float(tot[0]) + v, 0.01), int(tot[1]) + 1]
		var acc := float(prog.get(id, 0.0)) + progresso(v, int(p.get("age", 25)))
		var interi := int(acc) # verso lo zero: +1,3 → 1, −1,3 → −1
		acc -= interi
		prog[id] = snappedf(acc, 0.001)
		if interi != 0:
			var cambi := muovi(p, interi, r)
			for k: String in cambi:
				righe.append({"nome": p.name, "voto": v, "su": cambi[k], "stat": k})
	return righe


## metà stagione: tutti tranne il campione +1 anno e statistiche su/giù secondo media dei voti ed età; azzera i voti.
## Ritorna [{nome, eta, media (o null), punti (cambio totale vero)}]
static func meta_stagione(rosa: Array, voti: Dictionary, r: Callable) -> Array:
	var righe: Array = []
	for p: Dictionary in rosa:
		if p.get("champ", false):
			continue
		p.age = int(p.get("age", 25)) + 1
		var m: Variant = media(voti, p.id)
		var cambi := muovi(p, punti_meta(m, int(p.age)), r)
		var tot := 0
		for k: String in cambi:
			tot += int(cambi[k])
		righe.append({"nome": p.name, "eta": p.age, "media": m, "punti": tot})
	voti.clear()
	return righe
