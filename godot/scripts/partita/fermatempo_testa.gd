# Fermatempo del colpo di testa controllato (sim/testa.gd): quanto rallentare il tempo perché il pallone arrivi alla
# testa esattamente TESTA_FERMATEMPO_S secondi veri (d'orologio) dopo l'apertura, qualunque sia il volo che manca.
# Ogni fotogramma: velocità = tempo di partita che manca / secondi veri che mancano. Così anche se il pallone arriva
# prima o dopo il previsto la correzione è continua, e allo scadere il tempo torna normale.
extends RefCounted

const TESTA_FERMATEMPO_S := 3.0  # durata del fermatempo in secondi veri (Luis 2026-11-22)
const VEL_MIN := 0.01            # velocità del tempo più bassa (non si ferma mai del tutto)
const REALE_MIN := 0.05          # sotto questi secondi veri rimasti si va a velocità normale (niente divisioni per zero)


## velocità del tempo (0..1) con `partita_rimasta` s di partita al colpo e `reale_rimasto` s veri al termine
static func velocita(partita_rimasta: float, reale_rimasto: float) -> float:
	if reale_rimasto <= REALE_MIN:
		return 1.0
	return clampf(partita_rimasta / reale_rimasto, VEL_MIN, 1.0)


## frazione del cerchio ancora piena (1 = appena aperto, 0 = tempo finito)
static func frazione(reale_passato: float) -> float:
	return clampf(1.0 - reale_passato / TESTA_FERMATEMPO_S, 0.0, 1.0)
