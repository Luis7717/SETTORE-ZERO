# Aiuti per rifare in GDScript il comportamento esatto del JavaScript usato da src/career.js, src/looks.js e
# src/crest.js: ordinamento di V8 (anche col confronto a caso `() => r() - 0.5`), Math.round, toFixed, String(x),
# charCodeAt (UTF-16), Number.isInteger. Così la carriera dà gli stessi numeri del web a parità di seme.
extends RefCounted

const SimRng := preload("res://sim/rng.gd")
const M32 := 0xFFFFFFFF


## generatore rng32 (core.js) come Callable che ritorna un float in [0, 1): r.call()
## (la lambda tiene vivo l'oggetto SimRng; un Callable sul metodo no)
static func rng32(seed_value: int) -> Callable:
	var g := SimRng.new(seed_value)
	return func() -> float: return g.next()


## Math.round del JS come intero: la metà va verso +infinito
static func jround(x: float) -> int:
	return int(floor(x + 0.5))


## Number.isInteger
static func is_integer(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		return is_finite(f) and f == floor(f)
	return false


## String(x) del JS per numeri, testi, null e booleani
static func js_str(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floor(f) and absf(f) < 1e21:
				return str(int(f))
			return str(f)
	return str(v)


## codici UTF-16 di un testo (come charCodeAt del JS: i caratteri fuori dal piano base diventano due "surrogati")
static func utf16(s: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in s.length():
		var c := s.unicode_at(i)
		if c > 0xFFFF:
			c -= 0x10000
			out.append(0xD800 + (c >> 10))
			out.append(0xDC00 + (c & 0x3FF))
		else:
			out.append(c)
	return out


## (x).toFixed(2) del JS: per gli interi diviso 1000 arrotonda la metà verso l'alto come il JS (esatto)
static func to_fixed2(x: float) -> String:
	var neg := x < 0.0
	var a := absf(x)
	var cent := int(floor(a * 100.0 + 0.5))
	var testo := "%d.%02d" % [cent / 100, cent % 100]
	return ("-" if neg and cent > 0 else "") + testo


## (k / 1000).toFixed(2) del JS per k intero: toFixed arrotonda il valore ESATTO del double k/1000
## (1005/1000 = 1,00499999… → "1.00"; 1125/1000 = 1,125 esatto → "1.13", a pari distanza vince il più grande).
## Qui si decide sugli interi; nel solo caso dubbio (k finisce per 5) si guarda da che parte sta il double
## rispetto a k/1000, con il prodotto esatto di Dekker (x·1000 = p + e senza errori).
static func thousands_fixed2(k: float) -> String:
	if not is_integer(k):
		return to_fixed2(k / 1000.0)
	var neg := k < 0.0
	var a := int(absf(k))
	var cent := a / 10
	if a % 10 > 5:
		cent += 1
	elif a % 10 == 5:
		if a % 1000 in [125, 375, 625, 875] or _above(float(a) / 1000.0, float(a)):
			cent += 1 # metà esatta (vince il più grande) oppure double un po' sopra la metà
	return ("-" if neg and cent > 0 else "") + "%d.%02d" % [cent / 100, cent % 100]


# true se il double x è maggiore del numero esatto k / 1000 (cioè x·1000 > k), con Dekker/Veltkamp
static func _above(x: float, k: float) -> bool:
	var split := 134217729.0 # 2^27 + 1
	var c := split * x
	var xh := c - (c - x)
	var xl := x - xh
	var c2 := split * 1000.0
	var yh := c2 - (c2 - 1000.0)
	var yl := 1000.0 - yh
	var p := x * 1000.0
	var e := ((xh * yh - p) + xh * yl + xl * yh) + xl * yl
	return (p - k) + e > 0.0


## Array.prototype.sort di V8 (TimSort): per meno di 64 elementi è un "run" iniziale più l'inserimento binario,
## chiamando il confronto nello stesso ordine di V8. Conta per i mescolamenti `sort(() => r() - 0.5)` di career.js,
## dove il risultato dipende da quante volte e in che ordine si chiama r(). Ordina sul posto e ritorna l'array.
## Verificato contro Node 26 da 8 a 63 elementi (career.js mescola liste da 10 e da 32). Sotto 8 elementi il V8
## recente usa un altro metodo: col confronto a caso darebbe un altro ordine, coi confronti coerenti lo stesso
## (ordinamento stabile). Con 64 elementi o più: stesso inserimento binario (stabile, uguale per i confronti coerenti).
static func v8_sort(a: Array, cmp: Callable) -> Array:
	var n := a.size()
	if n < 2:
		return a
	var run := _count_and_make_run(a, 0, n, cmp)
	_binary_insertion_sort(a, 0, run, n, cmp)
	return a


static func _count_and_make_run(a: Array, low_arg: int, high: int, cmp: Callable) -> int:
	var low := low_arg + 1
	if low == high:
		return 1
	var run_length := 2
	var element_low: Variant = a[low]
	var element_low_pre: Variant = a[low - 1]
	var order: float = cmp.call(element_low, element_low_pre)
	var descending := order < 0.0
	var previous: Variant = element_low
	for idx in range(low + 1, high):
		var current: Variant = a[idx]
		order = cmp.call(current, previous)
		if descending:
			if order >= 0.0:
				break
		elif order < 0.0:
			break
		previous = current
		run_length += 1
	if descending:
		_reverse_range(a, low_arg, low_arg + run_length)
	return run_length


static func _reverse_range(a: Array, from: int, to: int) -> void:
	var lo := from
	var hi := to - 1
	while lo < hi:
		var t: Variant = a[lo]
		a[lo] = a[hi]
		a[hi] = t
		lo += 1
		hi -= 1


static func _binary_insertion_sort(a: Array, low: int, start_arg: int, high: int, cmp: Callable) -> void:
	var start := start_arg + 1 if low == start_arg else start_arg
	while start < high:
		var left := low
		var right := start
		var pivot: Variant = a[start]
		while left < right:
			var mid := left + ((right - left) >> 1)
			var order: float = cmp.call(pivot, a[mid])
			if order < 0.0:
				right = mid
			else:
				left = mid + 1
		var p := start
		while p > left:
			a[p] = a[p - 1]
			p -= 1
		a[left] = pivot
		start += 1


## dati letti da JSON: Godot legge tutti i numeri come float; qui quelli interi tornano int (come li crea il codice),
## altrimenti `[1.0].has(1)` è falso e le chiavi dei dizionari non combaciano. Ritorna una copia.
static func int_numbers(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floor(f) and absf(f) <= 9007199254740992.0:
				return int(f)
			return f
		TYPE_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(int_numbers(x))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				out[k] = int_numbers(v[k])
			return out
	return v


## confronto profondo con la semantica dei numeri del JS (1 e 1.0 sono uguali); ritorna "" se uguali,
## altrimenti il percorso della prima differenza
static func diff(a: Variant, b: Variant, path: String = "") -> String:
	var ta := typeof(a)
	var tb := typeof(b)
	var na := ta == TYPE_INT or ta == TYPE_FLOAT
	var nb := tb == TYPE_INT or tb == TYPE_FLOAT
	if na and nb:
		# il JSON di Godot legge alcuni decimali lunghi con 1 ulp di errore: per i non interi si tollerano 2 ulp
		var fa := float(a)
		var fb := float(b)
		var ok: bool = fa == fb or (fa != floor(fa) and absf(fa - fb) <= absf(fb) * 4.5e-16)
		return "" if ok else "%s: %s contro %s" % [path, str(a), str(b)]
	if ta != tb:
		return "%s: tipo %s contro %s (%s / %s)" % [path, type_string(ta), type_string(tb), str(a).left(60), str(b).left(60)]
	if ta == TYPE_ARRAY:
		if a.size() != b.size():
			return "%s: lunghezza %d contro %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if ta == TYPE_DICTIONARY:
		for k: Variant in a:
			if not b.has(k):
				return "%s.%s: manca nel secondo" % [path, k]
		for k: Variant in b:
			if not a.has(k):
				return "%s.%s: manca nel primo" % [path, k]
			var d := diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		return ""
	return "" if a == b else "%s: %s contro %s" % [path, str(a), str(b)]
