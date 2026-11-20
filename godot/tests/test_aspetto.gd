# Aspetto dei giocatori (scripts/partita/aspetto.gd, porting di src/looks.js): stessi numeri del web.
# Valori attesi presi da Node con src/looks.js (hash32, seeded, lookFromSeed, kitStyleFromSeed, backName).
extends "test_base.gd"

const A := preload("res://scripts/partita/aspetto.gd")


func test_hash32_come_il_web() -> bool:
	eq(A.hash32(["look", 5]), 1166894537, "hash32('look', 5)")
	eq(A.hash32([123456789, 3]), 1658020841, "hash32(123456789, 3)")
	eq(A.hash32(["Virtus", "Mario Rossi"]), 3169179679, "hash32 di due testi")
	eq(A.hash32([""]), 1039343097, "hash32('')")
	return done()


func test_seeded_come_il_web() -> bool:
	var r := A.seeded(42)
	for v: float in [0.6011037519201636, 0.44829055899754167, 0.8524657934904099]:
		check(absf(A.next(r) - v) < 1e-12, "seeded(42) deve dare %s" % v)
	return done()


func test_look_from_seed_come_il_web() -> bool:
	var attesi := [
		[0, {"skin": 0, "hair": 5, "hairColor": 2, "eyes": 0, "eyeColor": 4, "brows": 2, "beard": 0, "boots": 1}],
		[1, {"skin": 4, "hair": 14, "hairColor": 1, "eyes": 2, "eyeColor": 0, "brows": 2, "beard": 0, "boots": 0}],
		[7, {"skin": 7, "hair": 8, "hairColor": 0, "eyes": 0, "eyeColor": 1, "brows": 0, "beard": 0, "boots": 5}],
		[99, {"skin": 0, "hair": 2, "hairColor": 0, "eyes": 5, "eyeColor": 4, "brows": 5, "beard": 2, "boots": 3}],
		[A.hash32([3141592, 4]), {"skin": 3, "hair": 7, "hairColor": 1, "eyes": 2, "eyeColor": 3, "brows": 2, "beard": 5, "boots": 2}],
	]
	for a: Array in attesi:
		check(A.look_from_seed(a[0]) == a[1], "lookFromSeed(%d) = %s, atteso %s" % [a[0], A.look_from_seed(a[0]), a[1]])
	return done()


func test_stile_divisa_e_cognome_come_il_web() -> bool:
	check(A.kit_style_from_seed(0) == {"fit": 0, "sleeves": 0, "collar": 1, "pattern": 2, "shorts": 0, "socks": 0}, "kitStyleFromSeed(0)")
	check(A.kit_style_from_seed(5) == {"fit": 0, "sleeves": 0, "collar": 0, "pattern": 4, "shorts": 0, "socks": 1}, "kitStyleFromSeed(5)")
	check(A.kit_style_from_seed(77) == {"fit": 0, "sleeves": 0, "collar": 2, "pattern": 0, "shorts": 0, "socks": 0}, "kitStyleFromSeed(77)")
	eq(A.back_name("L. Ferrante"), "FERRANTE", "cognome")
	eq(A.back_name("mario rossi"), "MARIO ROSSI", "nome senza punto")
	return done()


func test_look_incompleto_si_completa() -> bool:
	var l := A.normalize_look({"skin": 9, "hair": -1, "beard": 3.0}, A.LOOK_BASE)
	eq(l.skin, 1, "pelle fuori elenco: si gira")
	eq(l.hair, 16, "capelli negativi: dall'ultimo")
	eq(l.beard, 3, "barba come numero decimale intero")
	eq(l.boots, 0, "campo mancante: valore di base")
	var auto := A.look_of({"name": "Mario"})
	check(auto == A.look_of({"name": "Mario"}), "senza look: sempre lo stesso aspetto dal nome")
	return done()
