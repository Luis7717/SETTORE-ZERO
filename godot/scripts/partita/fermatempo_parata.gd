# Fermatempo della parata (sim/parata.gd, Luis 2026-11-23: "timer di 3 secondi per decidere dove parare"). Sul tiro
# avversario il tempo si FERMA del tutto per PARATA_FERMATEMPO_S secondi veri, con il bersaglio sulla porta e il
# cerchio "Para!" che si svuota. Disegnata la linea il tempo riparte normale e il portiere va verso quel punto;
# finiti i secondi senza linea il portiere fa da solo (paraExpire nel motore). Se il dito sta ancora disegnando allo
# scadere si aspetta che lo alzi. La regia (scripts/partita/parata_regia.gd) usa queste funzioni.
extends RefCounted

const PARATA_FERMATEMPO_S := 3.0  # durata del fermatempo in secondi veri (Luis 2026-11-23)


## true se il tempo resta fermo: `reale_passato` s veri dall'apertura, `disegna` = il dito sta tracciando la linea
static func fermo(reale_passato: float, disegna: bool) -> bool:
	return disegna or reale_passato < PARATA_FERMATEMPO_S


## frazione del cerchio ancora piena (1 = appena aperto, 0 = tempo finito)
static func frazione(reale_passato: float) -> float:
	return clampf(1.0 - reale_passato / PARATA_FERMATEMPO_S, 0.0, 1.0)
