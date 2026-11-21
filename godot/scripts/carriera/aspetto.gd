# Aspetto dei giocatori e stile della divisa: porting 1:1 di src/looks.js (stessi nomi, stessi numeri).
# Dati puri (al massimo dei Color per lo shader): lo usano la carriera, la vista della partita e l'editor dei menu.
# È l'unico porting di looks.js (prima ce n'era un secondo in scripts/partita/aspetto.gd, tolto il 2026-11-21).
#
# look di un giocatore: {skin, hair, hairColor, eyes, eyeColor, brows, beard, boots} = indici negli elenchi sotto.
# Giocatori senza `look` (mercato, avversari): aspetto calcolato da id e nome, sempre uguale (lookOf).
# Stile della divisa: {fit, sleeves, collar, pattern, shorts, socks} = indici in KIT_OPTS.
#
# Differenze dal JS: hash32 prende i pezzi come argomenti variabili (`hash32("look", seed)`, come in JS);
# `seeded(seed)` ritorna un Callable (r.call() → float), che dà gli stessi numeri di rng32 (è lo stesso algoritmo);
# squadNumbers ritorna un Dictionary id → numero al posto di una Map.
class_name Aspetto
extends RefCounted

const JS := preload("res://scripts/carriera/js.gd")
const SimRng := preload("res://sim/rng.gd")

const SKINS := [["Chiarissima", "#f6d5bc"], ["Chiara", "#eec09c"], ["Rosata", "#e3ad8a"], ["Olivastra", "#d29b6c"], ["Ambrata", "#b67c50"], ["Bruna", "#93603b"], ["Scura", "#6e432a"], ["Molto scura", "#4b2d1e"]]
const HAIR_COLORS := [["Nero", "#17110e"], ["Castano scuro", "#3a2417"], ["Castano", "#5f3b22"], ["Castano chiaro", "#8b5b33"], ["Biondo scuro", "#a97c46"], ["Biondo", "#d7b26b"], ["Platino", "#eadfba"], ["Rosso", "#9e3c1b"], ["Ramato", "#c2692d"], ["Grigio", "#8e8e8e"], ["Bianco", "#e6e6e6"]]
const HAIR_STYLES := ["Calvo", "Rasato", "Corti", "Spazzola", "Ciuffo", "Riga di lato", "Cresta", "A punte", "Ricci", "Afro", "Caschetto", "Lunghi", "Coda", "Chignon", "Treccine", "Frangia", "All'indietro"]
const EYE_SHAPES := ["Tondi", "A mandorla", "Sottili", "Grandi", "Allungati", "Assonnati"]
const EYE_COLORS := [["Marrone scuro", "#3b2517"], ["Marrone", "#6c4424"], ["Nocciola", "#8f6b33"], ["Verde", "#4e7b3a"], ["Azzurro", "#4a90ca"], ["Grigio", "#7c8995"], ["Ambra", "#b27b1f"]]
const BROWS := ["Naturali", "Sottili", "Folte", "Arcuate", "Dritte", "Decise"]
const BEARDS := ["Nessuna", "Ombra", "Pizzetto", "Baffi", "Baffi e pizzetto", "Barba corta", "Barba piena"]
const BOOTS := [["Nere", "#17171b"], ["Bianche", "#efefef"], ["Rosse", "#d4202c"], ["Gialle", "#f2d21b"], ["Azzurre", "#2fa6e8"], ["Arancio", "#ff7a1a"]]

# numero di opzioni per ogni campo del look (per normalizzare e per l'editor)
const LOOK_N := {"skin": 8, "hair": 17, "hairColor": 11, "eyes": 6, "eyeColor": 7, "brows": 6, "beard": 7, "boots": 6}
const LOOK_KEYS := ["skin", "hair", "hairColor", "eyes", "eyeColor", "brows", "beard", "boots"]

const KIT_OPTS := {
	"fit": ["Aderente", "Larga"],
	"sleeves": ["Corte", "Lunghe", "Senza maniche"],
	"collar": ["Girocollo", "A V", "Polo"],
	"pattern": ["Tinta unita", "Righe verticali", "Righe orizzontali", "Banda diagonale", "Metà e metà"],
	"shorts": ["Corti", "Lunghi"],
	"socks": ["Alti", "Bassi", "Ripiegati"],
}
const KIT_KEYS := ["fit", "sleeves", "collar", "pattern", "shorts", "socks"]
const DEFAULT_KIT_STYLE := {"fit": 0, "sleeves": 0, "collar": 0, "pattern": 0, "shorts": 0, "socks": 0}
const DEFAULT_LOOK := {"skin": 1, "hair": 2, "hairColor": 2, "eyes": 0, "eyeColor": 1, "brows": 0, "beard": 0, "boots": 0}

# numeri di maglia preferiti per ruolo
const PREF := {"P": [1, 12, 22], "D": [2, 3, 4, 5, 6, 13, 14, 15], "C": [8, 10, 7, 16, 17, 18, 20], "A": [9, 11, 19, 21, 23]}


# ---------------------------------------------------------------- numeri pseudo-casuali senza stato globale
## hash FNV-1a dei pezzi (come testi), con un rimescolamento dopo ogni pezzo: intero senza segno a 32 bit
static func hash32(...parts: Array) -> int:
	var h := 2166136261
	for p: Variant in parts:
		for c in JS.utf16(JS.js_str(p)):
			h ^= c
			h = SimRng.imul(h, 16777619)
		h ^= 0x9e3779b9
		h = SimRng.imul(h ^ (h >> 15), 2246822507)
	return h & JS.M32


## generatore con seme (stesso algoritmo di rng32): Callable che ritorna un float in [0, 1)
static func seeded(seed_value: int) -> Callable:
	return JS.rng32(seed_value)


static func wpick(r: Callable, w: Array) -> int:
	var t := 0.0
	for x: float in w:
		t += x
	var u: float = r.call() * t
	for i in w.size():
		u -= w[i]
		if u < 0.0:
			return i
	return w.size() - 1


static func ipick(r: Callable, n: int) -> int:
	return int(floor(r.call() * n)) % n


# ---------------------------------------------------------------- aspetto
## aspetto plausibile da un seme: i capelli chiari sono più frequenti con la pelle chiara, barba e calvi più rari
static func lookFromSeed(seed_value: Variant) -> Dictionary:
	var r := seeded(hash32("look", seed_value))
	var skin := wpick(r, [10, 14, 12, 12, 9, 8, 7, 5])
	var dark := skin >= 4
	var hairColor := wpick(r, [60, 25, 8, 2, 1, 1, 0, 0, 0, 2, 1]) if dark else wpick(r, [14, 20, 18, 12, 9, 9, 2, 4, 4, 3, 1])
	var hair := wpick(r, [3, 9, 10, 6, 4, 3, 3, 3, 9, 7, 1, 2, 2, 2, 7, 2, 3]) if dark else wpick(r, [2, 7, 14, 7, 9, 8, 2, 4, 5, 1, 4, 4, 3, 3, 1, 5, 6])
	var out := {"skin": skin, "hair": hair, "hairColor": hairColor}
	out["eyes"] = ipick(r, EYE_SHAPES.size())
	out["eyeColor"] = wpick(r, [55, 35, 8, 1, 0, 1, 2]) if dark else wpick(r, [18, 24, 14, 13, 18, 9, 4])
	out["brows"] = wpick(r, [30, 12, 16, 12, 16, 14])
	out["beard"] = wpick(r, [50, 14, 7, 5, 6, 10, 8])
	out["boots"] = wpick(r, [30, 18, 12, 10, 14, 16])
	return out


## completa e corregge un look (campi mancanti o fuori elenco → valori validi, senza toccare l'originale)
static func normalizeLook(l: Variant, fallback: Variant = null) -> Dictionary:
	var base: Dictionary = fallback if fallback is Dictionary else DEFAULT_LOOK
	var out := {}
	for k: String in LOOK_KEYS:
		var v: Variant = l[k] if l is Dictionary and l.has(k) and JS.is_integer(l[k]) else base[k]
		out[k] = posmod(int(v), LOOK_N[k])
	return out


## aspetto di un giocatore (carriera o avversario): il suo `look` se c'è, altrimenti da id e nome
static func lookOf(p: Variant) -> Dictionary:
	if not p is Dictionary:
		return lookFromSeed(0)
	var nome: Variant = p.get("name", "")
	var id: Variant = p.get("id") if p.has("id") else "undefined" # String(undefined) del JS
	var auto := lookFromSeed(hash32(id, nome if nome != null and nome != "" else ""))
	var look: Variant = p.get("look")
	return normalizeLook(look, auto) if look is Dictionary else auto


## parametri di shaders/divisa.gdshader per un look (vista della partita e anteprima dell'editor):
## pelle, capelli, iride, scarpe (Color) e stile2 = (taglio, barba, sopracciglia, calzoncini dello stile della divisa)
static func parametri_figura(look: Variant, stile_divisa: Variant = null) -> Dictionary:
	var l := normalizeLook(look)
	var st := normalizeKitStyle(stile_divisa)
	return {
		"pelle": Color(SKINS[l.skin][1]), "capelli": Color(HAIR_COLORS[l.hairColor][1]),
		"iride": Color(EYE_COLORS[l.eyeColor][1]), "scarpe": Color(BOOTS[l.boots][1]),
		"stile2": Vector4(l.hair, l.beard, l.brows, st.shorts),
	}


## parametro `stile` dello shader per uno stile della divisa: (maniche, colletto, motivo, calzettoni)
static func stile_figura(stile_divisa: Variant) -> Vector4:
	var st := normalizeKitStyle(stile_divisa)
	return Vector4(st.sleeves, st.collar, st.pattern, st.socks)


# ---------------------------------------------------------------- stile della divisa
static func normalizeKitStyle(st: Variant) -> Dictionary:
	var out := {}
	for k: String in KIT_KEYS:
		var n: int = KIT_OPTS[k].size()
		var v: Variant = st[k] if st is Dictionary and st.has(k) and JS.is_integer(st[k]) else DEFAULT_KIT_STYLE[k]
		out[k] = posmod(int(v), n)
	return out


static func kitStyleFromSeed(seed_value: Variant) -> Dictionary:
	var r := seeded(hash32("kit", seed_value))
	var out := {}
	out["fit"] = wpick(r, [6, 4])
	out["sleeves"] = wpick(r, [12, 4, 1])
	out["collar"] = ipick(r, 3)
	out["pattern"] = wpick(r, [8, 4, 3, 2, 2])
	out["shorts"] = wpick(r, [8, 2])
	out["socks"] = wpick(r, [8, 2, 3])
	return out


# ---------------------------------------------------------------- numeri di maglia
## cognome per la schiena: "L. Ferrante" → "FERRANTE"
static func backName(name: Variant) -> String:
	var s := JS.js_str(name) if name != null else ""
	var re := RegEx.create_from_string("^.*\\.\\s*")
	return re.sub(s, "", false).strip_edges().to_upper().left(12)


## numeri per una rosa: chi ha già un numero valido e non doppio lo tiene, gli altri ricevono il primo libero
## per ruolo. Deterministico (dipende solo dall'ordine della rosa). Ritorna {id: numero}, non modifica i giocatori.
static func squadNumbers(squad: Array) -> Dictionary:
	var used := {}
	var out := {}
	for p: Dictionary in squad:
		var num: Variant = p.get("num")
		if JS.is_integer(num) and num >= 1 and num <= 99 and not used.has(int(num)):
			used[int(num)] = true
			out[p.id] = int(num)
	for p: Dictionary in squad:
		if out.has(p.id):
			continue
		var n := 0
		for x: int in PREF.get(p.get("pos", ""), []):
			if not used.has(x):
				n = x
				break
		if n == 0:
			n = 24
			while used.has(n) and n < 99:
				n += 1
		used[n] = true
		out[p.id] = n
	return out
