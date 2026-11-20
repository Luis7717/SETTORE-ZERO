# Livelli di qualità automatici della vista (logica pura, provata in tests/test_qualita.gd).
# Si misurano gli FPS su finestre di FINESTRA secondi; se la media resta sotto SOGLIA_FPS per LENTE finestre di fila
# (qualche secondo: un intoppo solo non basta) si scende di un livello e si aspetta ATTESA secondi prima di misurare
# di nuovo (il cambio deve avere effetto). Non si risale mai da soli:
# un telefono caldo che ha rallentato una volta lo rifarebbe.
#
# Livelli (cosa resta acceso; li applica PartitaVista.set_qualita):
#   3 alto    bagliore, profondità di campo, ombre morbide, pubblico pieno, coriandoli pieni, scia, sbuffi
#   2 medio   senza profondità di campo e ombre morbide (le voci più care)
#   1 basso   anche senza bagliore; metà pubblico, metà coriandoli
#   0 minimo  pubblico dipinto (niente 3D), pochi coriandoli, niente scia né sbuffi
extends RefCounted

const SOGLIA_FPS := 58.0
const FINESTRA := 1.0          # s su cui si fa la media
const LENTE := 3               # finestre lente di fila per scendere
const ATTESA := 4.0            # s dopo l'avvio o dopo un cambio prima di misurare
const ALTO := 3
const MEDIO := 2
const BASSO := 1
const MINIMO := 0
const NOMI := ["minimo", "basso", "medio", "alto"]

var livello := ALTO
var _attesa := ATTESA
var _t := 0.0
var _n := 0
var _lente := 0
var ultima_media := 0.0


## un fotogramma lungo dt secondi (tempo vero). true se il livello è appena sceso
func aggiorna(dt: float) -> bool:
	if dt <= 0.0:
		return false
	if _attesa > 0.0:
		_attesa -= dt
		return false
	_t += dt
	_n += 1
	if _t < FINESTRA:
		return false
	ultima_media = _n / _t
	_t = 0.0
	_n = 0
	_lente = _lente + 1 if ultima_media < SOGLIA_FPS else 0
	if _lente >= LENTE and livello > MINIMO:
		livello -= 1
		_attesa = ATTESA
		_lente = 0
		return true
	return false


## livello scelto a mano (anche dalle prove): riparte l'attesa
func imposta(l: int) -> void:
	livello = clampi(l, MINIMO, ALTO)
	_attesa = ATTESA
	_t = 0.0
	_n = 0
	_lente = 0
