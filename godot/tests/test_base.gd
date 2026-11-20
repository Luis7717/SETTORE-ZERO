# Base dei test del motore: ogni file tests/test_*.gd estende questa classe e ha metodi `test_*() -> bool`
# che finiscono con `return done()`. Se un test si interrompe per un errore di script il metodo non ritorna true
# e il runner lo conta come fallito.
extends RefCounted

const H := preload("harness.gd")
const C := preload("../sim/core.gd")
const R := preload("../sim/records.gd")
const SimMatchScript := preload("../sim/match.gd")
const DT := 1.0 / 60.0

var failures: Array[String] = []
var notes: Array[String] = []


func check(cond: bool, msg: String = "") -> bool:
	if not cond:
		failures.append(msg if msg != "" else "condizione falsa")
	return cond


func eq(a: Variant, b: Variant, msg: String = "") -> bool:
	var same: bool = typeof(a) == typeof(b) and a == b
	if not same and (typeof(a) in [TYPE_INT, TYPE_FLOAT]) and (typeof(b) in [TYPE_INT, TYPE_FLOAT]):
		same = float(a) == float(b)
	if not same:
		failures.append("%s: atteso %s, ottenuto %s" % [msg if msg != "" else "valori diversi", str(b), str(a)])
	return same


func near(a: float, b: float, tol: float, msg: String = "") -> bool:
	return check(absf(a - b) <= tol, "%s: %s contro %s (tolleranza %s)" % [msg, a, b, tol])


# nota che il runner stampa sotto il nome del test (numeri misurati)
func note(msg: String) -> void:
	notes.append(msg)


func done() -> bool:
	return true


static func dist(a: R.Player, b: R.Player) -> float:
	return C.hyp(a.x - b.x, a.y - b.y)


static func hasEvent(evs: Array, type: String, pred: Callable = Callable()) -> bool:
	for e: Dictionary in evs:
		if e.type == type and (not pred.is_valid() or pred.call(e)):
			return true
	return false


static func findEvent(evs: Array, type: String, pred: Callable = Callable()) -> Variant:
	for e: Dictionary in evs:
		if e.type == type and (not pred.is_valid() or pred.call(e)):
			return e
	return null


static func countEvents(evs: Array, type: String, pred: Callable = Callable()) -> int:
	var n := 0
	for e: Dictionary in evs:
		if e.type == type and (not pred.is_valid() or pred.call(e)):
			n += 1
	return n
