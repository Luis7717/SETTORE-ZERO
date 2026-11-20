# Numeri casuali con seme: porting esatto di rng32 (core.js, "mulberry32").
# In JS gli interi sono a 32 bit (`| 0`, `>>> 0`, Math.imul); in GDScript gli int sono a 64 bit:
# qui lo stato si tiene come intero senza segno in [0, 2^32) e ogni somma/prodotto si maschera con 0xFFFFFFFF.
# Stesso seme = stessa sequenza del JS, bit per bit (verificato da tests/test_rng.gd).
class_name SimRng
extends RefCounted

const M32 := 0xFFFFFFFF
const INC := 0x6d2b79f5
const TWO32 := 4294967296.0

var a: int = 0


func _init(seed_value: int = 1) -> void:
	a = seed_value & M32  # `a |= 0` del JS: stessi 32 bit anche per semi negativi


# Math.imul per interi senza segno a 32 bit: prodotto troncato a 32 bit, spezzato in due metà da 16 bit
# così il prodotto intermedio (< 2^48) non supera mai i 63 bit dell'int di GDScript.
static func imul(x: int, y: int) -> int:
	return ((x * (y & 0xFFFF)) + (((x * (y >> 16)) & 0xFFFF) << 16)) & M32


# numero in [0, 1), come la funzione restituita da rng32
func next() -> float:
	a = (a + INC) & M32
	var t: int = imul(a ^ (a >> 15), 1 | a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & M32) ^ t
	return float(t ^ (t >> 14)) / TWO32
