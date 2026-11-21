# Stanchezza e infortuni tra le partite (solo versione Godot).
# Ogni giocatore ha una forma 0..100 (s.forma, per id; chi manca è a 100): cala se gioca, risale se riposa.
# Sotto ENERGIA_DA il giocatore parte la partita già un po' stanco (energia iniziale del motore, campo `energy0`)
# e rischia di più l'infortunio. Gli infortunati (s.infortuni = giornate che mancano, per id) non giocano.
# Numeri casuali solo dal generatore passato (con seme): stessa carriera = stessi infortuni.
extends RefCounted

const FORMA_MAX := 100
const CALO_GIOCO := 14.0        # forma persa giocando una partita ...
const CALO_FIS := 0.05          # ... meno questo per ogni punto di fisico (fisico 60 → −11)
const RECUPERO := 6             # forma che tutti recuperano tra una giornata e l'altra
const RECUPERO_RIPOSO := 14     # in più per chi non ha giocato (o è infortunato)
const ENERGIA_DA := 80          # sotto questa forma si parte stanchi ...
const ENERGIA_MIN := 0.6        # ... fino a questa energia iniziale a forma 0
const INF_BASE := 0.008         # probabilità d'infortunio per partita giocata, in piena forma
const INF_STANCO := 0.045       # in più a forma 0 (cresce sotto FORMA_RISCHIO)
const FORMA_RISCHIO := 70
## durata: [probabilità cumulata, giornate minime, giornate massime]
const DURATE := [[0.7, 1, 2], [0.95, 3, 4], [1.0, 5, 8]]


static func energia(forma: int) -> float:
	if forma >= ENERGIA_DA:
		return 1.0
	return ENERGIA_MIN + (1.0 - ENERGIA_MIN) * clampf(float(forma) / ENERGIA_DA, 0.0, 1.0)


static func rischio(forma: int) -> float:
	return INF_BASE + INF_STANCO * maxf(0.0, float(FORMA_RISCHIO - forma)) / FORMA_RISCHIO


static func calo(p: Dictionary) -> int:
	return int(round(maxf(4.0, CALO_GIOCO - float(p.get("fis", 50)) * CALO_FIS)))


static func durata(r: Callable) -> int:
	var u: float = r.call()
	var v: float = r.call()
	for d: Array in DURATE:
		if u < float(d[0]):
			return int(d[1]) + int(floor(v * (int(d[2]) - int(d[1]) + 1)))
	return 1


## dopo una giornata di campionato: squad = rosa, giocato = id di chi ha giocato, forma e infortuni = dizionari
## dello stato (cambiano qui), r = numeri casuali. Ritorna i nuovi infortunati [{id, name, giornate}]
static func giornata(squad: Array, giocato: Array, forma: Dictionary, infortuni: Dictionary, r: Callable) -> Array:
	# chi era già infortunato ha saltato questa giornata
	for k: String in infortuni.keys():
		infortuni[k] = int(infortuni[k]) - 1
		if infortuni[k] <= 0:
			infortuni.erase(k)
	var nuovi: Array = []
	for p: Dictionary in squad: # nell'ordine della rosa: i numeri casuali si usano sempre nello stesso ordine
		var k := str(p.id)
		var f := int(forma.get(k, FORMA_MAX))
		var ha_giocato := giocato.has(p.id)
		if ha_giocato:
			f -= calo(p)
		else:
			f += RECUPERO_RIPOSO
		f = clampi(f + RECUPERO, 0, FORMA_MAX)
		forma[k] = f
		if ha_giocato and not infortuni.has(k) and r.call() < rischio(f):
			var g := durata(r)
			infortuni[k] = g
			nuovi.append({"id": p.id, "name": p.name, "giornate": g})
	return nuovi


## nuova stagione: estate di riposo, tutti in forma e guariti
static func estate(forma: Dictionary, infortuni: Dictionary) -> void:
	forma.clear()
	infortuni.clear()
