# Maglia di casa e maglia da trasferta (Luis 2026-11-24: "ad ogni squadra viene assegnata una maglia in casa e una
# maglia fuori casa, così quando giochi sono ben distinguibili le squadre").
# Casa = i colori della squadra (Carriera.KITS: maglia del colore principale). Trasferta = una maglia fissa per colore
# (TRASFERTA), chiara per le squadre scure e scura per quelle chiare. In partita la squadra di casa veste la maglia di
# casa; l'ospite la sua di casa se si distingue bene, altrimenti quella da trasferta (e se anche quella si confonde, i
# riserve: nera, bianca, blu notte...). Conta anche il secondo colore (righe, maniche, calzoncini). Stile, stemma e portiere restano quelli della squadra.
# Solo colori: nessun campo nuovo nel salvataggio (la trasferta si ricava dal colore della squadra).
extends RefCounted

const Car := preload("res://scripts/carriera/carriera.gd")

## colori troppo simili sotto questa distanza come la vede l'occhio (ΔE nello spazio Lab, `dist`). Prima era la somma
## delle differenze R, G, B: rosso e nero risultavano "simili" e il nero veniva scartato (Luis 2026-11-25)
const SIMILI := 50.0
const BIANCO := 0xf4f4f4
const NERO := 0x16161c
## per indice di Carriera.KITS: [maglia, calzoncini, calzettoni] da trasferta
const TRASFERTA := [
	[0xf4f4f4, 0xc8102e, 0xf4f4f4], # Rosso → bianca
	[0xf4f4f4, 0x1746a2, 0xf4f4f4], # Blu → bianca
	[0xf4f4f4, 0x0b7a3e, 0xf4f4f4], # Verde → bianca
	[0x14224a, 0xf2c200, 0x14224a], # Giallo → blu notte
	[0xf4f4f4, 0x1c1c22, 0xf4f4f4], # Nero → bianca
	[0x14224a, 0xf2f2f2, 0x14224a], # Bianco → blu notte
	[0x1c1c22, 0xe8650a, 0x1c1c22], # Arancio → nera
	[0xf4f4f4, 0x5b2a86, 0xf4f4f4], # Viola → bianca
	[0x14224a, 0x4aa3df, 0x14224a], # Celeste → blu notte
	[0xf4f4f4, 0x7a1230, 0xf4f4f4], # Granata → bianca
]


## [maglia, calzoncini, calzettoni] di casa e da trasferta della squadra col colore k (indice di KITS)
static func casa(k: int) -> Array:
	var c: Array = Car.KITS[_idx(k)]
	return [c[1], c[2], c[1]]


static func trasferta(k: int) -> Array:
	return TRASFERTA[_idx(k)]


static func simili(a: int, b: int) -> bool:
	return dist(a, b) < SIMILI


## distanza tra due colori 0xRRGGBB come la vede l'occhio (ΔE76 in CIELAB, luce D65)
static func dist(a: int, b: int) -> float:
	return _lab(a).distance_to(_lab(b))


static func _lab(c: int) -> Vector3:
	var rgb := Vector3(_lin((c >> 16) & 255), _lin((c >> 8) & 255), _lin(c & 255))
	var x := (0.4124 * rgb.x + 0.3576 * rgb.y + 0.1805 * rgb.z) / 0.95047
	var y := 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z
	var z := (0.0193 * rgb.x + 0.1192 * rgb.y + 0.9505 * rgb.z) / 1.08883
	var fx := _f(x)
	var fy := _f(y)
	var fz := _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lin(v: int) -> float:
	var f := v / 255.0
	return f / 12.92 if f <= 0.04045 else pow((f + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


## secondo colore come lo disegna la figura (vista._secondo_colore: righe, maniche, colletto): i calzoncini, o
## quasi nero / bianco se sono come la maglia
static func secondo(col: Array) -> int:
	if int(col[1]) != int(col[0]):
		return int(col[1])
	return NERO if dist(int(col[0]), NERO) > dist(int(col[0]), BIANCO) else BIANCO


## due divise si confondono se le maglie sono simili, o se hanno gli stessi due colori scambiati (Luis 2026-11-25:
## biancorossa contro bianca a righe rosse non si capiva niente)
static func confuse(a: Array, b: Array) -> bool:
	return distacco(a, b) < SIMILI


## quanto si distinguono due divise: la distanza tra le maglie, o tra i colori scambiati se è più piccola
static func distacco(a: Array, b: Array) -> float:
	var a1: int = int(a[0])
	var b1: int = int(b[0])
	var scambiati := maxf(dist(a1, secondo(b)), dist(secondo(a), b1))
	return minf(dist(a1, b1), scambiati)


## divise di riserva dopo casa e trasferta, in ordine: nera, bianca, blu notte, gialla, verde, viola
static func riserve(kb: int) -> Array:
	var c: Array = Car.KITS[_idx(kb)]
	return [[NERO, c[1], NERO], [NERO, 0xe8e8e8, NERO], [BIANCO, NERO, BIANCO], [0x14224a, BIANCO, 0x14224a],
		[0xf2c200, NERO, 0xf2c200], [0x0b7a3e, BIANCO, 0x0b7a3e], [0x5b2a86, BIANCO, 0x5b2a86]]


## colori che veste l'ospite (colore kb) contro la squadra di casa (colore ka, in maglia di casa): la prima tra
## casa, trasferta e riserve che non si confonde; se si confondono tutte, quella che si distingue di più
static func scelta_ospite(ka: int, kb: int) -> Array:
	var m_casa: Array = casa(ka)
	var opzioni: Array = [casa(kb), trasferta(kb)]
	opzioni.append_array(riserve(kb))
	var meglio: Array = opzioni[0]
	for opz: Array in opzioni:
		if not confuse(opz, m_casa):
			return opz
		if distacco(opz, m_casa) > distacco(meglio, m_casa):
			meglio = opz
	return meglio


## colore (indice di KITS) di una divisa già fatta da Carriera (stemma coi colori della squadra), -1 se non si capisce
static func indice_di(kit: Dictionary) -> int:
	var cr: Variant = kit.get("crest")
	if cr is Dictionary:
		for i in Car.KITS.size():
			if int(Car.KITS[i][1]) == int(cr.get("c1", -1)) and int(Car.KITS[i][2]) == int(cr.get("c2", -1)):
				return i
	return -1


## veste le due squadre della partita (dizionari di Carriera.squadraPartita / avversarioPartita, cambiati qui):
## la mia (colore km) e l'avversario (colore ko); casa = gioco io in casa
static func assegna(mia: Dictionary, km: int, avv: Dictionary, ko: int, casa_mia: bool) -> void:
	if casa_mia:
		_vesti(mia.kit, casa(km))
		_vesti(avv.kit, scelta_ospite(km, ko))
	else:
		_vesti(avv.kit, casa(ko))
		_vesti(mia.kit, scelta_ospite(ko, km))


static func _vesti(kit: Dictionary, col: Array) -> void:
	kit["shirt"] = int(col[0])
	kit["shorts"] = int(col[1])
	kit["socks"] = int(col[2])


static func _idx(k: int) -> int:
	return k if k >= 0 and k < Car.KITS.size() else 0
