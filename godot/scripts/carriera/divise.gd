# Maglia di casa e maglia da trasferta (Luis 2026-11-24: "ad ogni squadra viene assegnata una maglia in casa e una
# maglia fuori casa, così quando giochi sono ben distinguibili le squadre").
# Casa = i colori della squadra (Carriera.KITS: maglia del colore principale). Trasferta = una maglia fissa per colore
# (TRASFERTA), chiara per le squadre scure e scura per quelle chiare. In partita la squadra di casa veste la maglia di
# casa; l'ospite la sua di casa se si distingue bene, altrimenti quella da trasferta (e se anche quella si confonde, i
# suoi colori invertiti, poi bianco o nero). Stile, stemma e portiere restano quelli della squadra.
# Solo colori: nessun campo nuovo nel salvataggio (la trasferta si ricava dal colore della squadra).
extends RefCounted

const Car := preload("res://scripts/carriera/carriera.gd")

## maglie troppo simili sotto questa distanza di colore (somma delle differenze R, G, B, come Carriera.colorDist)
const SIMILI := 260
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
	return Car.colorDist(a, b) < SIMILI


## colori che veste l'ospite (colore kb) contro la squadra di casa (colore ka, in maglia di casa)
static func scelta_ospite(ka: int, kb: int) -> Array:
	var m_casa: int = casa(ka)[0]
	var c: Array = Car.KITS[_idx(kb)]
	for opz: Array in [casa(kb), trasferta(kb), [c[2], c[1], c[2]]]:
		if not simili(opz[0], m_casa):
			return opz
	var lontano: int = BIANCO if Car.colorDist(BIANCO, m_casa) > Car.colorDist(NERO, m_casa) else NERO
	return [lontano, c[1], lontano]


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
