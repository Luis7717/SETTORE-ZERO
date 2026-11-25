# Crescita coi voti in pagella (solo Godot, Luis 2026-11-25): "un giocatore può crescere se prende più di 6 e
# decrescere se prende meno di 6, una crescita che varia in base all'età"; "a metà stagione, salvo il campione che non
# cambia età, gli altri giocatori guadagnano un anno e in base alle prestazioni medie delle partite salgono o scendono
# con valori livellati sull'età"; poi: "fai in modo che le statistiche dei giocatori salgano in quel momento, non prima
# e non dopo. Fallo valere anche per gli avversari".
# Quindi: dopo ogni partita si segnano solo i voti (s.voti); le statistiche (sotto-statistiche di sim/sottostat.gd)
# cambiano SOLO a metà stagione, per la mia rosa (media dei voti ed età) e per gli avversari (meta_cpu: media dalla
# loro classifica). Il campione no: cresce con quello che fa in partita (crescita.gd) e non invecchia.
# Logica pura (niente nodi); lo stato sta nella carriera:
#   s.voti = {id: [somma dei voti, partite]} da metà stagione a metà stagione (media_voti, offerte del mercato)
#   s.metaStagione = stagione in cui è già stata fatta la metà stagione
#   s.metaCpu = {stagione, medie: {id squadra: media}} (avversari: valgono dal girone di ritorno)
# Prove: tests/test_crescita_voti.gd.
extends RefCounted

const Sotto := preload("res://sim/sottostat.gd")

const VOTO_NEUTRO := 6.0
## età → [quanto si cresce col voto alto, quanto si cala col voto basso]
const ETA := [[21, 1.0, 0.35], [24, 0.8, 0.5], [28, 0.55, 0.7], [31, 0.3, 0.9], [99, 0.15, 1.1]]
## metà stagione: punti per ogni punto di media sopra/sotto il 6 (poi × fattore dell'età) ...
const META_PER_PUNTO := 4.0
## ... più la spinta dell'età, anche per chi non ha giocato: [fino a età, punti]
const META_ETA := [[21, 2.0], [24, 1.0], [28, 0.0], [31, -1.0], [33, -2.0], [99, -3.0]]
## sotto-statistiche che si muovono, per ruolo (sim/sottostat.gd; "tes" = colpo di testa)
const STAT_RUOLO := {"P": ["tuf", "rif", "pre", "pia", "pco", "plu"],
	"D": ["int", "ctr", "tes", "ele", "frz", "res", "pco", "acc"],
	"C": ["pco", "plu", "eff", "ctl", "agi", "int", "res", "lon", "drb"],
	"A": ["fin", "pot", "lon", "vol", "acc", "vmax", "drb", "agi", "ctl"]}
## calando, da 30 anni in su metà dei punti va sul fisico che invecchia
const CALO_VECCHI := ["acc", "vmax", "res", "agi", "ele"]
const ETA_CALO_FISICO := 30
## sotto-statistiche mosse per ogni punto di metà stagione (una grande è la media di 2-5 sotto-statistiche)
const SUB_PER_PUNTO := 3
## avversari: media "di squadra" dai punti a partita del girone d'andata (1,4 a partita = 6)
const CPU_PPG_NEUTRO := 1.4
const CPU_PER_PUNTO := 0.8


static func _riga_eta(eta: int) -> Array:
	for e: Array in ETA:
		if eta <= int(e[0]):
			return e
	return ETA[ETA.size() - 1]


## fattore dell'età: col voto sopra il 6 quanto si cresce, sotto quanto si cala
static func fattore(eta: int, su: bool) -> float:
	var e := _riga_eta(eta)
	return float(e[1]) if su else float(e[2])


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


## muove le sotto-statistiche del ruolo di p di `punti` (× SUB_PER_PUNTO passi, positivi su, negativi giù), una
## alla volta a caso (r = numeri casuali con seme); crea le sotto-statistiche se mancano. Ritorna {stat: differenza}
static func muovi(p: Dictionary, punti: int, r: Callable) -> Dictionary:
	Sotto.crea(p, r)
	var out := {}
	var chiavi: Array = STAT_RUOLO.get(str(p.get("pos", "C")), STAT_RUOLO.C)
	var passo := 1 if punti > 0 else -1
	var vecchio := passo < 0 and int(p.get("age", 25)) >= ETA_CALO_FISICO
	for _i in absi(punti) * SUB_PER_PUNTO:
		var lista: Array = CALO_VECCHI if vecchio and float(r.call()) < 0.5 else chiavi
		var k: String = lista[int(floor(float(r.call()) * lista.size()))]
		var d := Sotto.muovi(p, k, passo)
		if d != 0:
			out[k] = int(out.get(k, 0)) + d
	return out


## voti di una partita: pagella [{id, voto}] (voti.gd calcola) → somma i voti dei giocatori della rosa (campione
## escluso). Le statistiche non cambiano qui: solo a metà stagione
static func dopo_partita(rosa: Array, pagella: Array, voti: Dictionary) -> void:
	var per_id := {}
	for p: Dictionary in rosa:
		per_id[str(p.id)] = p
	for g: Variant in pagella:
		if not g is Dictionary or not g.has("voto"):
			continue
		var id := str(g.get("id", ""))
		var p: Variant = per_id.get(id)
		if p == null or p.get("champ", false):
			continue
		var tot: Array = voti.get(id) if voti.get(id) is Array and voti.get(id).size() >= 2 else [0.0, 0]
		voti[id] = [snappedf(float(tot[0]) + float(g.voto), 0.01), int(tot[1]) + 1]


## metà stagione: tutti tranne il campione +1 anno e statistiche su/giù secondo media dei voti ed età; azzera i voti.
## ovr = funzione valutazione(p) per mostrare prima/dopo. Ritorna
## [{id, nome, pos, eta, media (o null), punti, prima, dopo, cambi {stat: d}}]
static func meta_stagione(rosa: Array, voti: Dictionary, r: Callable, ovr: Callable) -> Array:
	var righe: Array = []
	for p: Dictionary in rosa:
		if p.get("champ", false):
			continue
		var prima := int(ovr.call(p))
		p.age = int(p.get("age", 25)) + 1
		var m: Variant = media(voti, p.id)
		var pt := punti_meta(m, int(p.age))
		var cambi := muovi(p, pt, r)
		righe.append({"id": p.id, "nome": p.name, "pos": p.pos, "eta": p.age, "media": m, "punti": pt,
			"prima": prima, "dopo": int(ovr.call(p)), "cambi": cambi})
	voti.clear()
	return righe


## media "dei voti" di una squadra della CPU dai punti a partita (pti/partite) del girone d'andata
static func media_cpu(punti: int, partite: int) -> float:
	if partite <= 0:
		return VOTO_NEUTRO
	return clampf(VOTO_NEUTRO + (float(punti) / partite - CPU_PPG_NEUTRO) * CPU_PER_PUNTO, 5.0, 7.0)


## giocatore della CPU nel girone di ritorno: +1 anno e statistiche mosse con la media della squadra (r con seme
## della squadra e del giocatore: stesso giocatore = stessi cambi ogni volta che si genera)
static func meta_cpu(p: Dictionary, media_squadra: float, r: Callable) -> void:
	p.age = int(p.get("age", 25)) + 1
	muovi(p, punti_meta(media_squadra, int(p.age)), r)
