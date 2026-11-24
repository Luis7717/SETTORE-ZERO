# Fermatempo del colpo di testa controllato (sim/testa.gd). Luis 2026-11-23: niente rallenty, il tempo si FERMA del
# tutto (sennò si perde il momento) per TESTA_FERMATEMPO_S secondi veri, con la visuale vicina come nel tiro. Disegnata
# la linea il tempo riparte normale e il colpo parte appena arriva il pallone; finiti i secondi senza linea il pallone è
# perso (headExpire nel motore); nel salto conteso (difesa, passaggio alto) il colpo passa all'avversario.
extends RefCounted

const TESTA_FERMATEMPO_S := 3.0  # durata del fermatempo in secondi veri (Luis 2026-11-22)
const SCRITTA_DIFESA := "Respingi!" # salto conteso vinto in difesa (kind "def"): la linea è un passaggio o un rinvio


## true se il tempo resta fermo: `reale_passato` s veri dall'apertura, `con_linea` = linea già disegnata
static func fermo(reale_passato: float, con_linea: bool) -> bool:
	return not con_linea and reale_passato < TESTA_FERMATEMPO_S


## frazione del cerchio ancora piena (1 = appena aperto, 0 = tempo finito)
static func frazione(reale_passato: float) -> float:
	return clampf(1.0 - reale_passato / TESTA_FERMATEMPO_S, 0.0, 1.0)


## scritta sopra il cerchio secondo il tipo di fermatempo (sim/testa.gd): "" = quella di sempre ("Di testa!")
static func scritta(kind: String) -> String:
	return SCRITTA_DIFESA if kind == "def" else ""
