# Aspetto dei giocatori (scripts/carriera/aspetto.gd, unico porting di src/looks.js): stessi numeri del web.
# Valori attesi presi da Node con src/looks.js: quelli scritti qui sotto (hash32, seeded, lookFromSeed,
# kitStyleFromSeed, backName) e tests/fixtures/aspetto.json (`node test/export-aspetto.mjs`: aspetto di chi è in campo,
# stile della divisa dal nome della squadra, cognomi, colori). Il resto di looks.js lo prova test_carriera.gd.
extends "test_base.gd"

const A := preload("res://scripts/carriera/aspetto.gd")
const FIX := "res://tests/fixtures/aspetto.json"


func _fixture() -> Dictionary:
	var f := FileAccess.open(FIX, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


# il JSON dà numeri decimali: si confrontano come interi
static func _interi(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = int(d[k])
	return out


func test_hash32_come_il_web() -> bool:
	eq(A.hash32("look", 5), 1166894537, "hash32('look', 5)")
	eq(A.hash32(123456789, 3), 1658020841, "hash32(123456789, 3)")
	eq(A.hash32("Virtus", "Mario Rossi"), 3169179679, "hash32 di due testi")
	eq(A.hash32(""), 1039343097, "hash32('')")
	return done()


func test_seeded_come_il_web() -> bool:
	var r := A.seeded(42)
	for v: float in [0.6011037519201636, 0.44829055899754167, 0.8524657934904099]:
		check(absf(r.call() - v) < 1e-12, "seeded(42) deve dare %s" % v)
	return done()


func test_look_from_seed_come_il_web() -> bool:
	var attesi := [
		[0, {"skin": 0, "hair": 5, "hairColor": 2, "eyes": 0, "eyeColor": 4, "brows": 2, "beard": 0, "boots": 1}],
		[1, {"skin": 4, "hair": 14, "hairColor": 1, "eyes": 2, "eyeColor": 0, "brows": 2, "beard": 0, "boots": 0}],
		[7, {"skin": 7, "hair": 8, "hairColor": 0, "eyes": 0, "eyeColor": 1, "brows": 0, "beard": 0, "boots": 5}],
		[99, {"skin": 0, "hair": 2, "hairColor": 0, "eyes": 5, "eyeColor": 4, "brows": 5, "beard": 2, "boots": 3}],
		[A.hash32(3141592, 4), {"skin": 3, "hair": 7, "hairColor": 1, "eyes": 2, "eyeColor": 3, "brows": 2, "beard": 5, "boots": 2}],
	]
	for a: Array in attesi:
		check(A.lookFromSeed(a[0]) == a[1], "lookFromSeed(%d) = %s, atteso %s" % [a[0], A.lookFromSeed(a[0]), a[1]])
	return done()


func test_stile_divisa_e_cognome_come_il_web() -> bool:
	check(A.kitStyleFromSeed(0) == {"fit": 0, "sleeves": 0, "collar": 1, "pattern": 2, "shorts": 0, "socks": 0}, "kitStyleFromSeed(0)")
	check(A.kitStyleFromSeed(5) == {"fit": 0, "sleeves": 0, "collar": 0, "pattern": 4, "shorts": 0, "socks": 1}, "kitStyleFromSeed(5)")
	check(A.kitStyleFromSeed(77) == {"fit": 0, "sleeves": 0, "collar": 2, "pattern": 0, "shorts": 0, "socks": 0}, "kitStyleFromSeed(77)")
	eq(A.backName("L. Ferrante"), "FERRANTE", "cognome")
	eq(A.backName("mario rossi"), "MARIO ROSSI", "nome senza punto")
	return done()


func test_look_incompleto_si_completa() -> bool:
	var l := A.normalizeLook({"skin": 9, "hair": -1, "beard": 3.0}, A.DEFAULT_LOOK)
	eq(l.skin, 1, "pelle fuori elenco: si gira")
	eq(l.hair, 16, "capelli negativi: dall'ultimo")
	eq(l.beard, 3, "barba come numero decimale intero")
	eq(l.boots, 0, "campo mancante: valore di base")
	var auto := A.lookOf({"name": "Mario"})
	check(auto == A.lookOf({"name": "Mario"}), "senza look: sempre lo stesso aspetto dal nome")
	return done()


# quello che usa la vista della partita (vista.gd: _aspetto_di, _stile_squadra, _prepara_schiene), confrontato col JS
func test_vista_come_il_web() -> bool:
	var fx := _fixture()
	if not check(not fx.is_empty(), "manca %s (node test/export-aspetto.mjs)" % FIX):
		return done()
	for c: Array in fx.lookOf:
		var l := A.lookOf(c[0])
		l.erase("beardColor")   # campo solo di Godot (2026-11-22), il web non ce l'ha
		check(l == _interi(c[1]), "lookOf(%s) = %s, atteso %s" % [c[0], l, c[1]])
	for c: Array in fx.kitStyle:
		var st := A.kitStyleFromSeed(A.hash32(str(c[0])))
		check(st == _interi(c[1]), "stile della squadra %s = %s, atteso %s" % [c[0], st, c[1]])
	for c: Array in fx.backName:
		eq(A.backName(c[0]), c[1], "backName(%s)" % c[0])
	var liste := {"skins": A.SKINS, "hair": A.HAIR_COLORS, "eyes": A.EYE_COLORS, "boots": A.BOOTS}
	for k: String in liste:
		# i primi come il web; in coda i colori aggiunti in Godot (2026-11-22)
		var n: int = fx.colori[k].size()
		eq(liste[k].slice(0, n).map(func(x: Array) -> String: return x[1]), fx.colori[k], "colori %s" % k)
	return done()


# parametri dello shader per la figura: stessi per la partita e per l'anteprima dell'editor
func test_parametri_figura() -> bool:
	var look := {"skin": 2, "hair": 13, "hairColor": 7, "eyes": 1, "eyeColor": 4, "brows": 3, "beard": 6, "boots": 2}
	var p := A.parametri_figura(look, {"shorts": 1})
	eq(p.pelle, Color("#e3ad8a"), "pelle")
	eq(p.capelli, Color("#9e3c1b"), "capelli")
	eq(p.iride, Color("#4a90ca"), "iride")
	eq(p.scarpe, Color("#d4202c"), "scarpe")
	eq(p.stile2, Vector4(13, 6, 3, 1), "stile2 = taglio, barba, sopracciglia, calzoncini")
	eq(A.parametri_figura(null).stile2, Vector4(2, 0, 0, 0), "senza look: aspetto di base")
	eq(A.stile_figura({"sleeves": 2, "collar": 1, "pattern": 4, "socks": 2, "fit": 1}), Vector4(2, 1, 4, 2), "stile della divisa")
	return done()


# colori nuovi (2026-11-22): capelli naturali, particolari e sfumati; barba col suo colore; occhi particolari ed
# eterocromia. I salvataggi vecchi (senza beardColor, indici vecchi) restano uguali.
func test_colori_nuovi_e_salvataggi_vecchi() -> bool:
	eq(A.HAIR_COLORS.size(), A.LOOK_N.hairColor, "capelli: elenco e numero di opzioni")
	eq(A.EYE_COLORS.size(), A.LOOK_N.eyeColor, "occhi: elenco e numero di opzioni")
	eq(A.BEARD_COLORS.size(), A.LOOK_N.beardColor, "barba: elenco e numero di opzioni")
	check(A.HAIR_COLORS.size() >= 20 and A.EYE_COLORS.size() >= 12, "più colori di prima")
	eq(A.HAIR_COLORS[6][1], "#eadfba", "indici vecchi invariati (platino)")
	eq(A.EYE_COLORS[4][1], "#4a90ca", "indici vecchi invariati (azzurro)")
	var visti := {}
	for c: Array in A.HAIR_COLORS:
		check(not visti.has(c[0]), "capelli: nome doppio %s" % c[0])
		visti[c[0]] = true
	var vecchio := {"skin": 2, "hair": 13, "hairColor": 7, "eyes": 1, "eyeColor": 4, "brows": 3, "beard": 6, "boots": 2}
	var n := A.normalizeLook(vecchio)
	eq(n.beardColor, 0, "salvataggio vecchio: barba come i capelli")
	eq(A.normalizeLook({"beardColor": 99}).beardColor, 99 % A.BEARD_COLORS.size(), "fuori elenco: riportato dentro")
	var p := A.parametri_figura(vecchio)
	eq(p.iride2.a, 0.0, "niente eterocromia")
	eq(p.punte.a, 0.0, "niente punte")
	var et := A.parametri_figura({"eyeColor": 10, "hairColor": 19})
	check(et.iride2.a > 0.5 and et.iride2 != et.iride, "eterocromia: due colori")
	check(et.punte.a > 0.5, "sfumato: colore delle punte")
	var bionda := A.parametri_figura({"skin": 0, "hairColor": 0, "beard": 6, "beardColor": 3})
	var nera := A.parametri_figura({"skin": 0, "hairColor": 0, "beard": 6, "beardColor": 1})
	check(A.luminanza(bionda.barba) > A.luminanza(nera.barba) + 0.15, "barba bionda più chiara della nera coi capelli neri")
	return done()
