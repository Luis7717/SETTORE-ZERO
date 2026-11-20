# Dati e piccoli aiuti dei menu (porting di src/ui-util.js e delle parti di src/looks.js, src/crest.js e
# src/career.js che servono a disegnare le schermate).
#
# È anche l'unico punto di contatto coi file della carriera (scripts/carriera/*, altro lavoro): se ci sono
# (carriera.gd, aspetto.gd, stemma_dati.gd) i valori e le funzioni si prendono da lì, altrimenti si usano le copie
# qui sotto (stessi numeri del web, provati da tests/test_menu_dati.gd). Così i menu funzionano e si provano anche
# prima che la carriera Godot esista, e dopo l'unione restano allineati.
class_name MenuDati
extends RefCounted

const SimRngScript := preload("res://sim/rng.gd")
const M32 := 0xFFFFFFFF

const PERCORSO_CARRIERA := "res://scripts/carriera/carriera.gd"
const PERCORSO_ASPETTO := "res://scripts/carriera/aspetto.gd"
const PERCORSO_STEMMA := "res://scripts/carriera/stemma_dati.gd"

# ---------------------------------------------------------------- carriera (career.js)
const DIV_NAMES := ["Prima Divisione", "Seconda Divisione", "Terza Divisione"]
const POS_NAME := {"P": "POR", "D": "DIF", "C": "CEN", "A": "ATT"}
const KITS := [
	["Rosso", 0xc8102e, 0xffffff], ["Blu", 0x1746a2, 0xffffff], ["Verde", 0x0b7a3e, 0xffffff], ["Giallo", 0xf2c200, 0x1b1b1b], ["Nero", 0x1c1c22, 0xe8e8e8],
	["Bianco", 0xf2f2f2, 0x1b2a5c], ["Arancio", 0xe8650a, 0x1b1b1b], ["Viola", 0x5b2a86, 0xffffff], ["Celeste", 0x4aa3df, 0xffffff], ["Granata", 0x7a1230, 0xf0d9a0],
]
const POS_FULL := {"P": "Portiere", "D": "Difensore", "C": "Centrocampista", "A": "Attaccante"}

# ---------------------------------------------------------------- ui-util.js
const STATS := [["vel", "VEL"], ["fis", "RES"], ["tir", "TIR"], ["pas", "PAS"], ["dri", "DRI"], ["dif", "DIF"], ["tes", "TES"]]
const GK_STATS := [["por", "POR"], ["pas", "PAS"], ["fis", "RES"], ["vel", "VEL"]]

# ---------------------------------------------------------------- looks.js
const SKINS := [["Chiarissima", "#f6d5bc"], ["Chiara", "#eec09c"], ["Rosata", "#e3ad8a"], ["Olivastra", "#d29b6c"], ["Ambrata", "#b67c50"], ["Bruna", "#93603b"], ["Scura", "#6e432a"], ["Molto scura", "#4b2d1e"]]
const HAIR_COLORS := [["Nero", "#17110e"], ["Castano scuro", "#3a2417"], ["Castano", "#5f3b22"], ["Castano chiaro", "#8b5b33"], ["Biondo scuro", "#a97c46"], ["Biondo", "#d7b26b"], ["Platino", "#eadfba"], ["Rosso", "#9e3c1b"], ["Ramato", "#c2692d"], ["Grigio", "#8e8e8e"], ["Bianco", "#e6e6e6"]]
const HAIR_STYLES := ["Calvo", "Rasato", "Corti", "Spazzola", "Ciuffo", "Riga di lato", "Cresta", "A punte", "Ricci", "Afro", "Caschetto", "Lunghi", "Coda", "Chignon", "Treccine", "Frangia", "All'indietro"]
const EYE_SHAPES := ["Tondi", "A mandorla", "Sottili", "Grandi", "Allungati", "Assonnati"]
const EYE_COLORS := [["Marrone scuro", "#3b2517"], ["Marrone", "#6c4424"], ["Nocciola", "#8f6b33"], ["Verde", "#4e7b3a"], ["Azzurro", "#4a90ca"], ["Grigio", "#7c8995"], ["Ambra", "#b27b1f"]]
const BROWS := ["Naturali", "Sottili", "Folte", "Arcuate", "Dritte", "Decise"]
const BEARDS := ["Nessuna", "Ombra", "Pizzetto", "Baffi", "Baffi e pizzetto", "Barba corta", "Barba piena"]
const BOOTS := [["Nere", "#17171b"], ["Bianche", "#efefef"], ["Rosse", "#d4202c"], ["Gialle", "#f2d21b"], ["Azzurre", "#2fa6e8"], ["Arancio", "#ff7a1a"]]
const LOOK_KEYS := ["skin", "hair", "hairColor", "eyes", "eyeColor", "brows", "beard", "boots"]
const LOOK_DEFAULT := {"skin": 1, "hair": 2, "hairColor": 2, "eyes": 0, "eyeColor": 1, "brows": 0, "beard": 0, "boots": 0}
const KIT_OPTS := {
	"fit": ["Aderente", "Larga"],
	"sleeves": ["Corte", "Lunghe", "Senza maniche"],
	"collar": ["Girocollo", "A V", "Polo"],
	"pattern": ["Tinta unita", "Righe verticali", "Righe orizzontali", "Banda diagonale", "Metà e metà"],
	"shorts": ["Corti", "Lunghi"],
	"socks": ["Alti", "Bassi", "Ripiegati"],
}
const KIT_KEYS := ["fit", "sleeves", "collar", "pattern", "shorts", "socks"]

# ---------------------------------------------------------------- crest.js (sagome 40×48, motivi, simboli 24×24)
const CREST_SHAPES := [
	["Scudo classico", "M3 3h34v22c0 11-9 17-17 21C12 42 3 36 3 25z"],
	["Tondo", "M20 5a19 19 0 1 1 0 38a19 19 0 1 1 0-38z"],
	["Ovale", "M20 2a16 22 0 1 1 0 44a16 22 0 1 1 0-44z"],
	["Scudo a punta", "M3 3h34l-1 21L20 46 4 24z"],
	["Rombo", "M20 1l19 23-19 23L1 24z"],
	["Esagono", "M20 2l18 10v24L20 46 2 36V12z"],
	["Quadrato", "M10 4h20a7 7 0 0 1 7 7v26a7 7 0 0 1-7 7H10a7 7 0 0 1-7-7V11a7 7 0 0 1 7-7z"],
	["Stendardo", "M4 3h32v41l-16-8-16 8z"],
	["Scudo arcuato", "M3 7q17-8 34 0v15c0 12-8 19-17 24C11 41 3 34 3 22z"],
	["Scudo a coda", "M3 3h34v29c0 4-2 6-6 6h-6l-5 7-5-7H9c-4 0-6-2-6-6z"],
]
const CREST_PATTERNS := [
	["Tinta unita", []],
	["Righe verticali", ["M8 0h6v48H8z", "M20 0h6v48h-6z", "M32 0h6v48h-6z"]],
	["Righe orizzontali", ["M0 8h40v6H0z", "M0 20h40v6H0z", "M0 32h40v6H0z"]],
	["Diagonale", ["M-6 34L46 6v14L-6 48z"]],
	["Quarti", ["M20 0h20v24H20z", "M0 24h20v24H0z"]],
	["Scacchi", ["M0 0h10v12H0zM20 0h10v12H20zM10 12h10v12H10zM30 12h10v12H30zM0 24h10v12H0zM20 24h10v12H20zM10 36h10v12H10zM30 36h10v12H30z"]],
	["Banda centrale", ["M14 0h12v48H14z"]],
	["Croce", ["M16 0h8v48h-8z", "M0 18h40v8H0z"]],
	["Metà e metà", ["M20 0h20v48H20z"]],
	["Chevron", ["M0 18l20 12 20-12v9L20 39 0 27z"]],
]
const CREST_ICONS := [
	["Pallone", [["M12 1.5a10.5 10.5 0 1 0 0 21a10.5 10.5 0 1 0 0-21z", "i"], ["M12 7.2l4.2 3-1.6 5h-5.2l-1.6-5z", "b"], ["M12 1.8v5.4M16.2 10.2l4.8-1.8M14.6 15.2l3 4.4M9.4 15.2l-3 4.4M7.8 10.2L3 8.4", "s"]]],
	["Stella", [["M12 1.5l3 6.8 7.3.7-5.5 4.9 1.6 7.2L12 17.4 5.6 21.1l1.6-7.2L1.7 9l7.3-.7z", "i"]]],
	["Leone", [["M12 1l3 2.6 4-.6.4 4 3.1 2.8-2.3 3.4.4 4-4 .8-2.4 3.3L12 23l-2.2-1.7-2.4-3.3-4-.8.4-4L1.5 9.8l3.1-2.8.4-4 4 .6z", "i"], ["M12 7.5c3 0 4.6 2.2 4.6 4.8 0 3-2 5.2-4.6 5.2s-4.6-2.2-4.6-5.2c0-2.6 1.6-4.8 4.6-4.8z", "b"], ["M9.6 11.2h1.4v1.4H9.6zM13 11.2h1.4v1.4H13zM10.8 14.6h2.4L12 16z", "i"]]],
	["Aquila", [["M12 5.5c-1.2 0-2 .9-2 2.1L1 4.5c.8 4.4 3 7 6.4 8l-2 2.3h4l2.6 7 2.6-7h4l-2-2.3c3.4-1 5.6-3.6 6.4-8l-9 3.1c0-1.2-.8-2.1-2-2.1z", "i"], ["M11 7.4h1.2v1.2H11z", "b"]]],
	["Torre", [["M5 22.5V9h2.2V4.5h2.6v2.2h1.6V4.5h1.2v2.2h1.6V4.5h2.6V9H19v13.5h-4.6v-4.6a2.4 2.4 0 0 0-4.8 0v4.6z", "i"], ["M10.8 11.2h2.4v3h-2.4z", "b"]]],
	["Corona", [["M2.5 18.5L1.5 6.5l5.5 4.3L12 3.5l5 7.3 5.5-4.3-1 12z", "i"], ["M2.5 19.6h19v3.2h-19z", "i"], ["M11 11.5h2v2h-2z", "b"]]],
	["Fulmine", [["M14.5 1L3.5 14h6.6l-2.3 9L19 9.8h-6.6z", "i"]]],
	["Quercia", [["M12 1.5c-4 0-7 2.8-7 5.9C3 8.4 2 10.4 2 12.4c0 3 2.8 5.2 6 5.2h8c3.2 0 6-2.2 6-5.2 0-2-1-4-3-5 0-3.1-3-5.9-7-5.9z", "i"], ["M10.7 16.5h2.6v6.5h-2.6z", "i"], ["M12 8v6M9 10.5l3 2.3 3-2.3", "s"]]],
	["Onda", [["M1 9.5c3.5-3.6 7-3.6 10.5 0s7 3.6 11.5 0v4c-4.5 3.6-8 3.6-11.5 0S4.5 9.9 1 13.5z", "i"], ["M1 16c3.5-3.6 7-3.6 10.5 0s7 3.6 11.5 0v4c-4.5 3.6-8 3.6-11.5 0S4.5 16.4 1 20z", "i"]]],
	["Sole", [["M12 6.5a5.5 5.5 0 1 0 0 11a5.5 5.5 0 1 0 0-11z", "i"], ["M12 0l1.6 4.6h-3.2zM12 24l-1.6-4.6h3.2zM0 12l4.6-1.6v3.2zM24 12l-4.6 1.6v-3.2zM3.5 3.5l4.4 2.2L5.7 7.9zM20.5 20.5l-4.4-2.2 2.2-2.2zM20.5 3.5l-2.2 4.4-2.2-2.2zM3.5 20.5l2.2-4.4 2.2 2.2z", "i"]]],
	["Ancora", [["M12 .8a3.2 3.2 0 1 0 0 6.4a3.2 3.2 0 1 0 0-6.4zm0 2a1.2 1.2 0 1 1 0 2.4a1.2 1.2 0 1 1 0-2.4z", "i"], ["M10.8 6.8h2.4v13.4c3-.3 5.4-2.1 6.3-4.8l-2-.9 4.5-2 1 4.8-1.8-.8c-1.3 4-5 6.7-9.2 6.7s-7.9-2.7-9.2-6.7l-1.8.8 1-4.8 4.5 2-2 .9c.9 2.7 3.3 4.5 6.3 4.8z", "i"], ["M7.5 8.6h9v2.2h-9z", "i"]]],
	["Chiave", [["M7 3a5.5 5.5 0 1 0 0 11a5.5 5.5 0 1 0 0-11zm0 3.2a2.3 2.3 0 1 1 0 4.6a2.3 2.3 0 1 1 0-4.6z", "i"], ["M11.8 7.2H23v3.2h-1.8v3.2h-3v-3.2h-1.6v3.2h-3v-3.2h-1.8z", "i"]]],
	["Spiga", [["M11.3 7h1.4v16h-1.4z", "i"], ["M12 .8c1.7 1.7 1.7 4 0 5.7-1.7-1.7-1.7-4 0-5.7zM11.4 10.2c-2.8 0-4.4-1.6-5-3.9 2.8 0 4.4 1.6 5 3.9zM12.6 10.2c2.8 0 4.4-1.6 5-3.9-2.8 0-4.4 1.6-5 3.9zM11.4 14.4c-2.8 0-4.4-1.6-5-3.9 2.8 0 4.4 1.6 5 3.9zM12.6 14.4c2.8 0 4.4-1.6 5-3.9-2.8 0-4.4 1.6-5 3.9zM11.4 18.6c-2.8 0-4.4-1.6-5-3.9 2.8 0 4.4 1.6 5 3.9zM12.6 18.6c2.8 0 4.4-1.6 5-3.9-2.8 0-4.4 1.6-5 3.9z", "i"]]],
	["Lupo", [["M3.5 1.5l5.2 5h6.6l5.2-5v9.5l-2 4.2-6.5 7.3-6.5-7.3-2-4.2z", "i"], ["M7.6 10.6l2.6.6-.4 1.6zM16.4 10.6l-2.6.6.4 1.6zM10.6 16.4h2.8L12 18.2z", "b"]]],
	["Cavallo", [["M7.5 22.5l.9-7.2C6 14.2 4.2 12.3 4.2 9.6l3.2-1.2.8-4.4 2.4 2.2c4.6-1.1 9 1.5 9.8 6.2l1 10.1z", "i"], ["M8.6 9.4h1.6V11H8.6z", "b"], ["M11 6.4l3.4-4 .6 4.6", "i"]]],
	["Ruota", [["M12 .8a11.2 11.2 0 1 0 0 22.4a11.2 11.2 0 1 0 0-22.4zm0 3a8.2 8.2 0 1 1 0 16.4a8.2 8.2 0 1 1 0-16.4z", "i"], ["M10.8 3h2.4v18h-2.4zM3 10.8h18v2.4H3z", "i"], ["M12 8.8a3.2 3.2 0 1 0 0 6.4a3.2 3.2 0 1 0 0-6.4z", "i"]]],
	["Montagna", [["M.5 21.5L8.8 6.5l4.2 6.4 3.1-4.2 7.4 12.8z", "i"], ["M8.8 6.5l2.3 3.6-1.2-.6-1.1 1.3-1.1-1.3-1.2.7z", "b"]]],
	["Fiamma", [["M12 .8c1.2 4.2 6.6 6.4 6.6 12.8a6.6 6.6 0 0 1-13.2 0c0-3.4 2.1-5.6 3.3-7.6 0 2.2 1 3.4 2.2 3.4 0-3.3-1.1-5.4 1.1-8.6z", "i"], ["M12 13.5c1.4 1.4 2.6 2.4 2.6 4.4a2.6 2.6 0 0 1-5.2 0c0-1.6 1.6-2.8 2.6-4.4z", "b"]]],
	["Giglio", [["M12 .8c2.2 3 3.2 5.4 3.2 8.4 0 2.2-1.1 4.2-3.2 6.2-2.1-2-3.2-4-3.2-6.2 0-3 1-5.4 3.2-8.4z", "i"], ["M9.6 15c-3.4 0-6.6-2.2-6.6-5.6 2.4 0 4.6 1.2 5.8 3.4zM14.4 15c3.4 0 6.6-2.2 6.6-5.6-2.4 0-4.6 1.2-5.8 3.4z", "i"], ["M5.5 15.4h13v2.4h-13z", "i"], ["M10.6 18h2.8l1.2 5H9.4z", "i"]]],
	["Toro", [["M1.5 3c0 4.4 2.2 6.8 5.6 6.8l1.2 8.6L12 22.5l3.7-4.1 1.2-8.6c3.4 0 5.6-2.4 5.6-6.8-2.2 2.2-4.4 3.3-6.6 3.3H8.1C5.9 6.3 3.7 5.2 1.5 3z", "i"], ["M8.6 11.2l2.2.7-.3 1.4zM15.4 11.2l-2.2.7.3 1.4zM9.8 17.4h4.4L12 19.6z", "b"]]],
]


# ---------------------------------------------------------------- collegamento coi file della carriera
static var _cache_script := {}


static func _script(percorso: String) -> Script:
	if not _cache_script.has(percorso):
		_cache_script[percorso] = load(percorso) if ResourceLoader.exists(percorso) else null
	return _cache_script[percorso]


# funzione statica del file della carriera se esiste, altrimenti null (chi chiama usa la copia locale)
static func _fuori(percorso: String, nome: String, args: Array) -> Variant:
	var s := _script(percorso)
	if s == null:
		return null
	for m in s.get_script_method_list():
		if m.name == nome:
			return s.callv(nome, args)
	return null


static func _costante(percorso: String, nome: String, locale: Variant) -> Variant:
	var s := _script(percorso)
	if s == null:
		return locale
	var mappa := s.get_script_constant_map()
	return mappa.get(nome, locale)


static func kits() -> Array:
	return _costante(PERCORSO_CARRIERA, "KITS", KITS)


static func kit(i: Variant) -> Array:
	var k := kits()
	var n := int(i) if (typeof(i) == TYPE_INT or typeof(i) == TYPE_FLOAT) else 0
	return k[n] if n >= 0 and n < k.size() else k[0]


static func div_names() -> Array:
	return _costante(PERCORSO_CARRIERA, "DIV_NAMES", DIV_NAMES)


static func pos_name(pos: Variant) -> String:
	return str(_costante(PERCORSO_CARRIERA, "POS_NAME", POS_NAME).get(str(pos), str(pos)))


# ---------------------------------------------------------------- valutazioni e soldi (career.js)
static func overall_as(p: Dictionary, pos: String) -> int:
	var v: Variant = _fuori(PERCORSO_CARRIERA, "overallAs", [p, pos])
	if v != null:
		return int(v)
	var mine: String = str(p.get("pos", ""))
	var pen := 1.0
	if mine != pos:
		if (mine == "P") != (pos == "P"):
			pen = 0.55
		elif mine + pos == "DA" or mine + pos == "AD":
			pen = 0.82
		else:
			pen = 0.92
	var o := 0.0
	var g := func(k: String) -> float: return float(p.get(k, 0))
	if pos == "P":
		o = g.call("por") * 0.72 + g.call("fis") * 0.14 + g.call("pas") * 0.14
	elif pos == "D":
		o = g.call("dif") * 0.45 + g.call("fis") * 0.2 + g.call("vel") * 0.15 + g.call("pas") * 0.1 + g.call("dri") * 0.1
	elif pos == "C":
		o = g.call("pas") * 0.35 + g.call("dri") * 0.25 + g.call("dif") * 0.12 + g.call("vel") * 0.12 + g.call("tir") * 0.16
	else:
		o = g.call("tir") * 0.4 + g.call("vel") * 0.22 + g.call("dri") * 0.23 + g.call("pas") * 0.1 + g.call("fis") * 0.05
	return _round_js(o * pen)


static func overall(p: Dictionary) -> int:
	return overall_as(p, str(p.get("pos", "")))


static func value(p: Dictionary) -> int:
	var v: Variant = _fuori(PERCORSO_CARRIERA, "value", [p])
	if v != null:
		return int(v)
	var o := overall(p)
	var a := int(p.get("age", 25))
	var af := 1.35 if a <= 21 else (1.2 if a <= 25 else (1.0 if a <= 29 else (0.75 if a <= 31 else (0.5 if a <= 33 else 0.3))))
	return maxi(5, _round_js(30.0 * pow(1.115, o - 50) * af))


static func fmt_money(k: float) -> String:
	var v: Variant = _fuori(PERCORSO_CARRIERA, "fmtMoney", [k])
	if v != null:
		return str(v)
	if absf(k) >= 1000.0:
		return ("%.2f" % (k / 1000.0)).replace(".", ",") + " M€"
	return str(_round_js(k)) + " k€"


# Math.round del JS (le metà vanno verso +∞, anche per i negativi)
static func _round_js(x: float) -> int:
	return int(floor(x + 0.5))


static func stat_of(p: Dictionary, k: String) -> int:
	if k == "tes":
		var tes: Variant = p.get("tes")
		if typeof(tes) == TYPE_INT or typeof(tes) == TYPE_FLOAT:
			return int(tes)
		return int(preload("res://sim/core.gd").headingOf(p))
	return int(p.get(k, 0))


# fascia di valutazione: colore del numero e del bordo della carta (o1..o4)
static func ovr_cls(o: int) -> String:
	return "o4" if o >= 75 else ("o3" if o >= 65 else ("o2" if o >= 55 else "o1"))


static func hex(n: int) -> String:
	return "#" + ("%06x" % (n & 0xFFFFFF))


static func colore(n: int) -> Color:
	return Color.hex((n << 8) | 0xff)


# ---------------------------------------------------------------- numeri pseudo-casuali (looks.js)
static func _imul(x: int, y: int) -> int:
	return SimRngScript.imul(x & M32, y & M32)


static func hash32(parts: Array) -> int:
	var h := 2166136261
	for part: Variant in parts:
		var s := _str_js(part)
		for i in s.length():
			h = (h ^ s.unicode_at(i)) & M32
			h = _imul(h, 16777619)
		h = (h ^ 0x9e3779b9) & M32
		h = _imul(h ^ (h >> 15), 2246822507)
	return h & M32


# String() del JS per i valori che passano a hash32 (gli interi senza ".0")
static func _str_js(v: Variant) -> String:
	if typeof(v) == TYPE_FLOAT and is_equal_approx(v, roundf(v)) and absf(v) < 1e15:
		return str(int(v))
	return str(v)


static func seeded(seed_value: int) -> SimRngScript:
	return SimRngScript.new(seed_value & M32)


static func _wpick(r: SimRngScript, w: Array) -> int:
	var t := 0.0
	for x: float in w:
		t += x
	var u := r.next() * t
	for i in w.size():
		u -= w[i]
		if u < 0.0:
			return i
	return w.size() - 1


static func _ipick(r: SimRngScript, n: int) -> int:
	return int(floor(r.next() * n)) % n


static func look_from_seed(seed_value: int) -> Dictionary:
	var v: Variant = _fuori(PERCORSO_ASPETTO, "lookFromSeed", [seed_value])
	if v is Dictionary:
		return v
	var r := seeded(hash32(["look", seed_value]))
	var skin := _wpick(r, [10, 14, 12, 12, 9, 8, 7, 5])
	var dark := skin >= 4
	var hair_color := _wpick(r, [60, 25, 8, 2, 1, 1, 0, 0, 0, 2, 1]) if dark else _wpick(r, [14, 20, 18, 12, 9, 9, 2, 4, 4, 3, 1])
	var hair := _wpick(r, [3, 9, 10, 6, 4, 3, 3, 3, 9, 7, 1, 2, 2, 2, 7, 2, 3]) if dark else _wpick(r, [2, 7, 14, 7, 9, 8, 2, 4, 5, 1, 4, 4, 3, 3, 1, 5, 6])
	var out := {"skin": skin, "hair": hair, "hairColor": hair_color}
	out.eyes = _ipick(r, EYE_SHAPES.size())
	out.eyeColor = _wpick(r, [55, 35, 8, 1, 0, 1, 2]) if dark else _wpick(r, [18, 24, 14, 13, 18, 9, 4])
	out.brows = _wpick(r, [30, 12, 16, 12, 16, 14])
	out.beard = _wpick(r, [50, 14, 7, 5, 6, 10, 8])
	out.boots = _wpick(r, [30, 18, 12, 10, 14, 16])
	return out


static func _look_n(k: String) -> int:
	match k:
		"skin": return SKINS.size()
		"hair": return HAIR_STYLES.size()
		"hairColor": return HAIR_COLORS.size()
		"eyes": return EYE_SHAPES.size()
		"eyeColor": return EYE_COLORS.size()
		"brows": return BROWS.size()
		"beard": return BEARDS.size()
		"boots": return BOOTS.size()
	return 1


static func _intero(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_equal_approx(v, roundf(v)))


static func normalize_look(l: Variant, fallback: Variant = null) -> Dictionary:
	var base: Dictionary = fallback if fallback is Dictionary else LOOK_DEFAULT
	var out := {}
	for k: String in LOOK_KEYS:
		var v: Variant = l.get(k) if l is Dictionary else null
		var x := int(v) if _intero(v) else int(base[k])
		var n := _look_n(k)
		out[k] = ((x % n) + n) % n
	return out


# aspetto di un giocatore: il suo `look` se c'è, altrimenti da id e nome (sempre uguale)
static func look_of(p: Variant) -> Dictionary:
	var v: Variant = _fuori(PERCORSO_ASPETTO, "lookOf", [p])
	if v is Dictionary:
		return v
	if not (p is Dictionary):
		return look_from_seed(0)
	var auto := look_from_seed(hash32([p.get("id"), p.get("name", "")]))
	var lk: Variant = p.get("look")
	return normalize_look(lk, auto) if lk is Dictionary else auto


static func normalize_kit_style(st: Variant) -> Dictionary:
	var out := {}
	for k: String in KIT_KEYS:
		var n: int = KIT_OPTS[k].size()
		var v: Variant = st.get(k) if st is Dictionary else null
		var x := int(v) if _intero(v) else 0
		out[k] = ((x % n) + n) % n
	return out


static func kit_style_from_seed(seed_value: int) -> Dictionary:
	var v: Variant = _fuori(PERCORSO_ASPETTO, "kitStyleFromSeed", [seed_value])
	if v is Dictionary:
		return v
	var r := seeded(hash32(["kit", seed_value]))
	return {"fit": _wpick(r, [6, 4]), "sleeves": _wpick(r, [12, 4, 1]), "collar": _ipick(r, 3), "pattern": _wpick(r, [8, 4, 3, 2, 2]), "shorts": _wpick(r, [8, 2]), "socks": _wpick(r, [8, 2, 3])}


# ---------------------------------------------------------------- stemmi (crest.js)
static func crest_from_seed(seed_value: int) -> Dictionary:
	var v: Variant = _fuori(PERCORSO_STEMMA, "crestFromSeed", [seed_value])
	if v is Dictionary:
		return v
	var r := seeded(hash32(["crest", seed_value]))
	var shape := int(floor(r.next() * CREST_SHAPES.size()))
	var pattern := int(floor(r.next() * CREST_PATTERNS.size()))
	var icon := int(floor(r.next() * CREST_ICONS.size()))
	return {"shape": shape, "pattern": pattern, "icon": icon}


static func normalize_crest(c: Variant, fallback: Variant = null) -> Dictionary:
	var base: Dictionary = fallback if fallback is Dictionary else {"shape": 0, "pattern": 3, "icon": 0}
	var out := {}
	for k: String in ["shape", "pattern", "icon"]:
		var n: int = {"shape": CREST_SHAPES.size(), "pattern": CREST_PATTERNS.size(), "icon": CREST_ICONS.size()}[k]
		var v: Variant = c.get(k) if c is Dictionary else null
		var x := int(v) if _intero(v) else int(base[k])
		out[k] = ((x % n) + n) % n
	return out


static func crest_shapes() -> Array:
	return _costante(PERCORSO_STEMMA, "CREST_SHAPES", CREST_SHAPES)


static func crest_patterns() -> Array:
	return _costante(PERCORSO_STEMMA, "CREST_PATTERNS", CREST_PATTERNS)


static func crest_icons() -> Array:
	return _costante(PERCORSO_STEMMA, "CREST_ICONS", CREST_ICONS)


# ---------------------------------------------------------------- lettura comoda di Dictionary e oggetti
## valore di un campo sia da un Dictionary sia da un oggetto (risultati della partita, squadre del motore)
static func campo(o: Variant, k: String, def: Variant = null) -> Variant:
	if o is Dictionary:
		return o.get(k, def)
	if o is Object and o != null:
		var v: Variant = o.get(k)
		return def if v == null else v
	return def
