# Stemmi delle squadre, parte dati: porting 1:1 di src/crest.js (forme, motivi, simboli, crestFromSeed,
# normalizeCrest, crestColors). Il disegno (SVG nel web, qui Path2D/Polygon2D o texture) lo fanno i menu e la vista.
# Tracciati nel formato SVG "d" come nel web: sagome nel riquadro 40×48, simboli nel riquadro 24×24 spostati di
# (9, 13.5) e scalati 0,92 dentro lo stemma. Ogni pezzo di simbolo: [tracciato, ruolo] con ruolo "i" = inchiostro,
# "b" = colore di fondo, "s" = solo contorno nel colore di fondo.
# I colori vengono dalla maglia (KITS in carriera.gd): c1 = principale, c2 = secondario.
class_name StemmaDati
extends RefCounted

const JS := preload("res://scripts/carriera/js.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")

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

const CREST_N := {"shape": 10, "pattern": 10, "icon": 20}
const DEFAULT_CREST := {"shape": 0, "pattern": 3, "icon": 0}


static func crestFromSeed(seed_value: Variant) -> Dictionary:
	var r := Asp.seeded(Asp.hash32("crest", seed_value))
	var out := {}
	out["shape"] = int(floor(r.call() * CREST_SHAPES.size()))
	out["pattern"] = int(floor(r.call() * CREST_PATTERNS.size()))
	out["icon"] = int(floor(r.call() * CREST_ICONS.size()))
	return out


## completa e corregge uno stemma {shape, pattern, icon} (senza toccare l'originale)
static func normalizeCrest(c: Variant, fallback: Variant = null) -> Dictionary:
	var base: Dictionary = fallback if fallback is Dictionary else DEFAULT_CREST
	var out := {}
	for k: String in CREST_N:
		var v: Variant = c[k] if c is Dictionary and c.has(k) and JS.is_integer(c[k]) else base[k]
		out[k] = posmod(int(v), CREST_N[k])
	return out


static func hex(n: int) -> String:
	return "#" + ("%06x" % (n & 0xFFFFFFFF)).right(6)


static func lum(n: int) -> float:
	return (((n >> 16) & 255) * 0.299 + ((n >> 8) & 255) * 0.587 + (n & 255) * 0.114) / 255.0


## colori dello stemma da due colori della maglia (0xRRGGBB): fondo, motivo, simbolo e suo contorno ("#rrggbb")
static func crestColors(c1: int, c2: int) -> Dictionary:
	var near := absf(lum(c1) - lum(c2)) < 0.18
	var ink := (0x111827 if lum(c1) > 0.5 else 0xffffff) if near else c2
	return {"base": hex(c1), "alt": hex(c2), "ink": hex(ink), "line": "#0b1020" if lum(ink) > 0.5 else "#ffffff"}
