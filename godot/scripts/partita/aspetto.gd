# Aspetto dei giocatori e stile della divisa (porting di src/looks.js): elenchi di opzioni e scelte deterministiche,
# identiche al web bit per bit (hash32, seeded): lo stesso seme dà la stessa faccia nelle due versioni.
# Modulo puro, niente grafica (provato in tests/test_aspetto.gd).
#
# look di un giocatore: {skin, hair, hairColor, eyes, eyeColor, brows, beard, boots} = indici negli elenchi sotto.
# Stile della divisa: {fit, sleeves, collar, pattern, shorts, socks} = indici in KIT_N.
extends RefCounted

const SKINS := ["#f6d5bc", "#eec09c", "#e3ad8a", "#d29b6c", "#b67c50", "#93603b", "#6e432a", "#4b2d1e"]
const HAIR_COLORS := ["#17110e", "#3a2417", "#5f3b22", "#8b5b33", "#a97c46", "#d7b26b", "#eadfba", "#9e3c1b", "#c2692d", "#8e8e8e", "#e6e6e6"]
# tagli (come HAIR_STYLES del web): 0 calvo, 1 rasato, 2 corti, 3 spazzola, 4 ciuffo, 5 riga di lato, 6 cresta,
# 7 a punte, 8 ricci, 9 afro, 10 caschetto, 11 lunghi, 12 coda, 13 chignon, 14 treccine, 15 frangia, 16 all'indietro
const N_HAIR_STYLES := 17
const EYE_COLORS := ["#3b2517", "#6c4424", "#8f6b33", "#4e7b3a", "#4a90ca", "#7c8995", "#b27b1f"]
# barba: 0 nessuna, 1 ombra, 2 pizzetto, 3 baffi, 4 baffi e pizzetto, 5 barba corta, 6 barba piena
const BOOTS := ["#17171b", "#efefef", "#d4202c", "#f2d21b", "#2fa6e8", "#ff7a1a"]
const LOOK_N := {"skin": 8, "hair": 17, "hairColor": 11, "eyes": 6, "eyeColor": 7, "brows": 6, "beard": 7, "boots": 6}
const LOOK_BASE := {"skin": 1, "hair": 2, "hairColor": 2, "eyes": 0, "eyeColor": 1, "brows": 0, "beard": 0, "boots": 0}
# stile della divisa: fit 0 aderente / 1 larga · sleeves 0 corte / 1 lunghe / 2 senza · collar 0 girocollo / 1 a V /
# 2 polo · pattern 0 tinta unita / 1 righe verticali / 2 orizzontali / 3 banda diagonale / 4 metà e metà ·
# shorts 0 corti / 1 lunghi · socks 0 alti / 1 bassi / 2 ripiegati
const KIT_N := {"fit": 2, "sleeves": 3, "collar": 3, "pattern": 5, "shorts": 2, "socks": 3}
const KIT_BASE := {"fit": 0, "sleeves": 0, "collar": 0, "pattern": 0, "shorts": 0, "socks": 0}
const M32 := 0xffffffff


# ---------------------------------------------------------------- numeri pseudo-casuali come il web
## parte bassa (32 bit, senza segno) di a·b, come Math.imul del web (diviso in due per non uscire dai 64 bit)
static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & M32


## hash32 del web: le parti diventano testo (gli interi in cifre decimali, come String() di JS)
static func hash32(parts: Array) -> int:
	var h := 2166136261
	for p: Variant in parts:
		var s: String = str(int(p)) if typeof(p) == TYPE_FLOAT and is_equal_approx(p, roundf(p)) else str(p)
		for i in s.length():
			h ^= s.unicode_at(i)
			h = imul(h, 16777619)
		h ^= 0x9e3779b9
		h = imul(h ^ (h >> 15), 2246822507)
	return h & M32


## generatore col seme (mulberry32 del web): stato in un Array di un elemento, next() lo fa avanzare
static func seeded(seed: int) -> Array:
	return [seed & M32]


static func next(st: Array) -> float:
	var a: int = (st[0] + 0x6d2b79f5) & M32
	st[0] = a
	var t := imul(a ^ (a >> 15), a | 1)
	t ^= (t + imul(t ^ (t >> 7), t | 61)) & M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0


static func _wpick(st: Array, w: Array) -> int:
	var tot := 0.0
	for x: float in w:
		tot += x
	var u := next(st) * tot
	for i in w.size():
		u -= w[i]
		if u < 0.0:
			return i
	return w.size() - 1


static func _ipick(st: Array, n: int) -> int:
	return int(floor(next(st) * n)) % n


# ---------------------------------------------------------------- aspetto
## aspetto plausibile da un seme (lookFromSeed): capelli chiari più frequenti con la pelle chiara, barba e calvi rari
static func look_from_seed(seed: int) -> Dictionary:
	var r := seeded(hash32(["look", seed]))
	var skin := _wpick(r, [10, 14, 12, 12, 9, 8, 7, 5])
	var dark := skin >= 4
	var hair_color := _wpick(r, [60, 25, 8, 2, 1, 1, 0, 0, 0, 2, 1]) if dark else _wpick(r, [14, 20, 18, 12, 9, 9, 2, 4, 4, 3, 1])
	var hair := _wpick(r, [3, 9, 10, 6, 4, 3, 3, 3, 9, 7, 1, 2, 2, 2, 7, 2, 3]) if dark else _wpick(r, [2, 7, 14, 7, 9, 8, 2, 4, 5, 1, 4, 4, 3, 3, 1, 5, 6])
	var eyes := _ipick(r, 6)
	var eye_color := _wpick(r, [55, 35, 8, 1, 0, 1, 2]) if dark else _wpick(r, [18, 24, 14, 13, 18, 9, 4])
	var brows := _wpick(r, [30, 12, 16, 12, 16, 14])
	var beard := _wpick(r, [50, 14, 7, 5, 6, 10, 8])
	var boots := _wpick(r, [30, 18, 12, 10, 14, 16])
	return {"skin": skin, "hair": hair, "hairColor": hair_color, "eyes": eyes, "eyeColor": eye_color, "brows": brows, "beard": beard, "boots": boots}


## completa e corregge un look (campi mancanti o fuori elenco → valori validi, senza toccare l'originale)
static func normalize_look(l: Variant, fallback: Dictionary = LOOK_BASE) -> Dictionary:
	return _normalizza(l, fallback, LOOK_N)


## aspetto di un giocatore: il suo `look` se c'è (completato col seme), altrimenti da id e nome (lookOf del web)
static func look_of(src: Dictionary) -> Dictionary:
	var auto := look_from_seed(hash32([src.get("id", ""), src.get("name", "")]))
	var l: Variant = src.get("look")
	return normalize_look(l, auto) if l is Dictionary else auto


# ---------------------------------------------------------------- stile della divisa
static func normalize_kit_style(st: Variant) -> Dictionary:
	return _normalizza(st, KIT_BASE, KIT_N)


static func kit_style_from_seed(seed: int) -> Dictionary:
	var r := seeded(hash32(["kit", seed]))
	return {"fit": _wpick(r, [6, 4]), "sleeves": _wpick(r, [12, 4, 1]), "collar": _ipick(r, 3), "pattern": _wpick(r, [8, 4, 3, 2, 2]),
		"shorts": _wpick(r, [8, 2]), "socks": _wpick(r, [8, 2, 3])}


## cognome per la schiena: "L. Ferrante" → "FERRANTE" (al massimo 12 lettere)
static func back_name(name: String) -> String:
	var s := name
	var k := s.rfind(".")
	if k >= 0:
		s = s.substr(k + 1)
	return s.strip_edges().to_upper().substr(0, 12)


static func colore(lista: Array, i: int) -> Color:
	return Color(lista[clampi(i, 0, lista.size() - 1)])


static func _normalizza(l: Variant, base: Dictionary, n: Dictionary) -> Dictionary:
	var out := {}
	for k: String in n:
		var v: int = base[k]
		if l is Dictionary and l.has(k) and (typeof(l[k]) == TYPE_INT or (typeof(l[k]) == TYPE_FLOAT and is_equal_approx(l[k], roundf(l[k])))):
			v = int(l[k])
		out[k] = ((v % n[k]) + n[k]) % n[k]
	return out
