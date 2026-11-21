# Esultanze del campione (fase C, punto 12): elenco con i nomi, quella predefinita e il controllo del valore
# salvato. Solo dati, nessuna grafica: li usano la carriera (salvataggio), l'editor (scelta) e la partita.
# Le pose stanno in mosse/esultanza.gd, la regia in partita (telecamera, tocco per saltare) in esultanza_regia.gd.
extends RefCounted

## [id, nome] nell'ordine in cui si vedono nell'editor
const ELENCO := [
	["aeroplano", "Aeroplano"],
	["ginocchio", "Scivolata in ginocchio"],
	["capriola", "Capriola"],
	["pugno", "Pugno al cielo"],
	["indice", "Indici al cielo"],
	["saluto", "Saluto militare"],
	["cuore", "Cuore con le mani"],
	["ballo", "Balletto"],
	["orecchie", "Mani alle orecchie"],
	["silenzio", "Dito sulla bocca"],
	["salto", "Salto col pugno"],
	["inchino", "Inchino"],
	["conserte", "Braccia conserte"],
	["giravolta", "Giravolta"],
	["bandierina", "Calcio alla bandierina"],
]
## quella dei salvataggi vecchi e di chi non ha ancora scelto
const PREDEFINITA := "aeroplano"


static func ids() -> Array:
	var out: Array = []
	for e: Array in ELENCO:
		out.append(e[0])
	return out


## valore salvato → id buono (qualunque cosa sbagliata o mancante = PREDEFINITA)
static func valida(v: Variant) -> String:
	if v is String or v is StringName:
		for e: Array in ELENCO:
			if e[0] == String(v):
				return e[0]
	return PREDEFINITA


static func nome(id: Variant) -> String:
	var k := valida(id)
	for e: Array in ELENCO:
		if e[0] == k:
			return e[1]
	return ""


static func indice(id: Variant) -> int:
	return ids().find(valida(id))
