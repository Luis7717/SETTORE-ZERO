# Dati e piccoli aiuti dei menu (porting di src/ui-util.js) e unico punto di contatto coi file della carriera
# (scripts/carriera/: Carriera = career.js, Aspetto = looks.js, StemmaDati = dati di crest.js). Le schermate
# chiamano MenuDati.overall(p), MenuDati.look_of(p), ... e qui si gira tutto alla carriera vera: se un giorno
# cambia un nome là, si corregge solo questo file.
class_name MenuDati
extends RefCounted

const Car := preload("res://scripts/carriera/carriera.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const Stm := preload("res://scripts/carriera/stemma_dati.gd")
const JS := preload("res://scripts/carriera/js.gd")
const Core := preload("res://sim/core.gd")

# ---------------------------------------------------------------- carriera (career.js)
const DIV_NAMES := Car.DIV_NAMES
const POS_NAME := Car.POS_NAME
const KITS := Car.KITS
const POS_FULL := {"P": "Portiere", "D": "Difensore", "C": "Centrocampista", "A": "Attaccante"}

# ---------------------------------------------------------------- ui-util.js
const STATS := [["vel", "VEL"], ["fis", "RES"], ["tir", "TIR"], ["pas", "PAS"], ["dri", "DRI"], ["dif", "DIF"], ["tes", "TES"]]
const GK_STATS := [["por", "POR"], ["pas", "PAS"], ["fis", "RES"], ["vel", "VEL"]]

# ---------------------------------------------------------------- looks.js e crest.js
const SKINS := Asp.SKINS
const HAIR_COLORS := Asp.HAIR_COLORS
const HAIR_STYLES := Asp.HAIR_STYLES
const EYE_SHAPES := Asp.EYE_SHAPES
const EYE_COLORS := Asp.EYE_COLORS
const BEARD_COLORS := Asp.BEARD_COLORS
const BROWS := Asp.BROWS
const BEARDS := Asp.BEARDS
const BOOTS := Asp.BOOTS
const LOOK_KEYS := Asp.LOOK_KEYS
const LOOK_DEFAULT := Asp.DEFAULT_LOOK
const KIT_OPTS := Asp.KIT_OPTS
const KIT_KEYS := Asp.KIT_KEYS
const CREST_SHAPES := Stm.CREST_SHAPES
const CREST_PATTERNS := Stm.CREST_PATTERNS
const CREST_ICONS := Stm.CREST_ICONS


static func kits() -> Array:
	return KITS


static func kit(i: Variant) -> Array:
	var n := int(i) if (typeof(i) == TYPE_INT or typeof(i) == TYPE_FLOAT) else 0
	return KITS[n] if n >= 0 and n < KITS.size() else KITS[0]


static func div_names() -> Array:
	return DIV_NAMES


static func pos_name(pos: Variant) -> String:
	return str(POS_NAME.get(str(pos), str(pos)))


# ---------------------------------------------------------------- valutazioni e soldi
static func overall_as(p: Dictionary, pos: String) -> int:
	return Car.overallAs(p, pos)


static func overall(p: Dictionary) -> int:
	return Car.overall(p)


static func value(p: Dictionary) -> int:
	return Car.value(p)


static func fmt_money(k: float) -> String:
	return Car.fmtMoney(k)


# Math.round del JS (le metà vanno verso +∞)
static func _round_js(x: float) -> int:
	return JS.jround(x)


static func stat_of(p: Dictionary, k: String) -> int:
	return int(Core.headingOf(p)) if k == "tes" else int(p.get(k, 0))


## ordinamento come Array.sort del JS (stabile, stesso ordine del web a pari valore); cmp(a, b) -> numero
static func ordina(a: Array, cmp: Callable) -> Array:
	return JS.v8_sort(a, cmp)


## errore di Carriera.buy/sell: "" (o null) = tutto bene
static func errore(v: Variant) -> String:
	return "" if v == null else str(v)


# fascia di valutazione: colore del numero e del bordo della carta (o1..o4)
static func ovr_cls(o: int) -> String:
	return "o4" if o >= 75 else ("o3" if o >= 65 else ("o2" if o >= 55 else "o1"))


static func hex(n: int) -> String:
	return "#" + ("%06x" % (n & 0xFFFFFF))


static func colore(n: int) -> Color:
	return Color.hex((n << 8) | 0xff)


# ---------------------------------------------------------------- aspetto e stemmi
static func hash32(parts: Array) -> int:
	match parts.size():
		1:
			return Asp.hash32(parts[0])
		2:
			return Asp.hash32(parts[0], parts[1])
		3:
			return Asp.hash32(parts[0], parts[1], parts[2])
		_:
			return Asp.hash32(parts[0], parts[1], parts[2], parts[3])


static func look_from_seed(seed_value: int) -> Dictionary:
	return Asp.lookFromSeed(seed_value)


static func normalize_look(l: Variant, fallback: Variant = null) -> Dictionary:
	return Asp.normalizeLook(l, fallback)


static func look_of(p: Variant) -> Dictionary:
	return Asp.lookOf(p)


static func normalize_kit_style(st: Variant) -> Dictionary:
	return Asp.normalizeKitStyle(st)


static func kit_style_from_seed(seed_value: int) -> Dictionary:
	return Asp.kitStyleFromSeed(seed_value)


static func crest_from_seed(seed_value: int) -> Dictionary:
	return Stm.crestFromSeed(seed_value)


static func normalize_crest(c: Variant, fallback: Variant = null) -> Dictionary:
	return Stm.normalizeCrest(c, fallback)


static func crest_shapes() -> Array:
	return CREST_SHAPES


static func crest_patterns() -> Array:
	return CREST_PATTERNS


static func crest_icons() -> Array:
	return CREST_ICONS


static func random_name(seed_value: int) -> String:
	return Car.randomName(Asp.seeded(seed_value))


# ---------------------------------------------------------------- lettura comoda di Dictionary e oggetti
## valore di un campo sia da un Dictionary sia da un oggetto (risultati della partita, squadre del motore)
static func campo(o: Variant, k: String, def: Variant = null) -> Variant:
	if o is Dictionary:
		return o.get(k, def)
	if o is Object and o != null:
		var v: Variant = o.get(k)
		return def if v == null else v
	return def
