# Buffer circolare del replay del gol (solo grafica): tiene gli ultimi DURATA secondi di gioco della partita
# (posizioni, versi, velocità e stati di giocatori e pallone, fase) e li rimette sulla partita per un fotogramma
# della vista. Il motore NON cambia: `applica` scrive i valori registrati sugli oggetti della partita, la vista li
# legge, e `ripristina` rimette subito i valori veri, identici bit per bit (si salvano le Variant così come sono).
# Tra applica e ripristina il motore non deve fare passi (lo garantisce replay.gd: durante il replay è fermo).
#
# Uso:
#   registra(m)                ogni fotogramma dopo i passi del motore (prende un campione ogni PASSO s di gioco)
#   applica(m, t) / ripristina(m)   attorno a vista.update_view: stato interpolato al tempo di gioco t (m.time)
#   tiro_prima(t)              tempo del calcio (l'ultimo prima di t) che ha portato al gol, per la linea del tiro
#   traiettoria(t0, t1)        punti del pallone Vector3(x, y, h) tra t0 e t1
extends RefCounted

const DURATA := 6.0            # s di gioco tenuti nel buffer
const PASSO := 1.0 / 30.0      # s di gioco tra un campione e l'altro (nei rallenty si registra meno spesso del video)
const CAPIENZA := int(DURATA / PASSO) + 2
const TOLLERANZA := 1e-4       # s: m.time somma tanti passi e può restare un pelo sotto il PASSO

# campi del giocatore: i primi N_NUM si interpolano tra due campioni, gli altri si prendono dal più vicino
const CAMPI_G: Array[StringName] = [&"x", &"y", &"fx", &"fy", &"vx", &"vy", &"kickAnim", &"t",
	&"state", &"sprint", &"dive", &"cele", &"warn", &"off"]
const N_NUM_G := 8
const CAMPI_P: Array[StringName] = [&"x", &"y", &"h", &"vx", &"vy", &"vh", &"owner", &"kick", &"shot"]
const N_NUM_P := 6
const CAMPI_M: Array[StringName] = [&"phase", &"restart"]

var _buf: Array = []           # campioni {t, g: Array (per giocatore un Array di CAMPI_G), p: Array, m: Array}
var _testa := 0                # dove va il prossimo campione
var _n := 0                    # campioni validi
var _ultimo_t := -INF
var _salvato: Dictionary = {}  # valori veri durante applica (vuoto = niente da ripristinare)


func _init() -> void:
	_buf.resize(CAPIENZA)


func svuota() -> void:
	_n = 0
	_testa = 0
	_ultimo_t = -INF


func quanti() -> int:
	return _n


## tempo di gioco del campione più vecchio e di quello più nuovo (Vector2(INF, -INF) se vuoto)
func intervallo() -> Vector2:
	if _n == 0:
		return Vector2(INF, -INF)
	return Vector2(_campione(0).t, _campione(_n - 1).t)


## prende un campione se dall'ultimo sono passati almeno PASSO s di gioco (o se il tempo è tornato indietro);
## true se l'ha preso
func registra(m: Object) -> bool:
	var t: float = m.time
	if t - _ultimo_t < PASSO - TOLLERANZA and t >= _ultimo_t:
		return false
	if t < _ultimo_t:
		svuota()
	_ultimo_t = t
	var g: Array = []
	g.resize(m.players.size())
	for i in m.players.size():
		g[i] = _leggi(m.players[i], CAMPI_G)
	_buf[_testa] = {"t": t, "g": g, "p": _leggi(m.ball, CAMPI_P), "m": _leggi(m, CAMPI_M)}
	_testa = (_testa + 1) % CAPIENZA
	_n = mini(_n + 1, CAPIENZA)
	return true


## mette sulla partita lo stato registrato al tempo t (interpolato); i valori veri restano da parte per ripristina()
func applica(m: Object, t: float) -> bool:
	if _n == 0:
		return false
	if not _salvato.is_empty():
		ripristina(m)
	var g: Array = []
	for p: Object in m.players:
		g.append(_leggi(p, CAMPI_G))
	_salvato = {"g": g, "p": _leggi(m.ball, CAMPI_P), "m": _leggi(m, CAMPI_M)}
	var ab := _coppia(t)
	var a: Dictionary = ab[0]
	var b: Dictionary = ab[1]
	var w: float = ab[2]
	var vicino: Dictionary = a if w < 0.5 else b
	for i in mini(m.players.size(), (a.g as Array).size()):
		_scrivi(m.players[i], CAMPI_G, a.g[i], b.g[i], vicino.g[i], N_NUM_G, w)
	_scrivi(m.ball, CAMPI_P, a.p, b.p, vicino.p, N_NUM_P, w)
	_scrivi(m, CAMPI_M, a.m, b.m, vicino.m, 0, w)
	return true


## rimette i valori veri salvati da applica() (identici: sono le stesse Variant)
func ripristina(m: Object) -> void:
	if _salvato.is_empty():
		return
	var g: Array = _salvato.g
	for i in mini(m.players.size(), g.size()):
		_scrivi_tutto(m.players[i], CAMPI_G, g[i])
	_scrivi_tutto(m.ball, CAMPI_P, _salvato.p)
	_scrivi_tutto(m, CAMPI_M, _salvato.m)
	_salvato = {}


func applicato() -> bool:
	return not _salvato.is_empty()


## tempo dell'ultimo calcio partito prima di t (il tiro del gol); NAN se nel buffer non c'è
## (dopo il gol il motore toglie il calcio dal pallone: i campioni senza calcio in fondo si saltano)
func tiro_prima(t: float) -> float:
	var calcio: Variant = null
	var inizio := NAN
	for j in range(_n - 1, -1, -1):
		var c: Dictionary = _campione(j)
		if c.t > t:
			continue
		var k: Variant = c.p[7]
		if calcio == null:
			if k != null:
				calcio = k
				inizio = c.t
			continue
		if k != calcio:
			break
		inizio = c.t
	return inizio


## punti del pallone (Vector3(x, y, h)) dei campioni tra t0 e t1 compresi
func traiettoria(t0: float, t1: float) -> Array:
	var out: Array = []
	for j in _n:
		var c: Dictionary = _campione(j)
		if c.t >= t0 and c.t <= t1:
			out.append(Vector3(c.p[0], c.p[1], c.p[2]))
	return out


## stato del pallone registrato al tempo t (interpolato): Vector3(x, y, h)
func pallone_a(t: float) -> Vector3:
	if _n == 0:
		return Vector3.ZERO
	var ab := _coppia(t)
	var pa: Array = ab[0].p
	var pb: Array = ab[1].p
	var w: float = ab[2]
	return Vector3(lerpf(pa[0], pb[0], w), lerpf(pa[1], pb[1], w), lerpf(pa[2], pb[2], w))


# j-esimo campione dal più vecchio
func _campione(j: int) -> Dictionary:
	return _buf[(_testa - _n + j + CAPIENZA) % CAPIENZA]


# i due campioni attorno a t e il peso del secondo
func _coppia(t: float) -> Array:
	var primo := _campione(0)
	if t <= primo.t or _n == 1:
		return [primo, primo, 0.0]
	for j in range(1, _n):
		var b := _campione(j)
		if b.t >= t:
			var a := _campione(j - 1)
			return [a, b, clampf((t - a.t) / maxf(1e-6, b.t - a.t), 0.0, 1.0)]
	var ultimo := _campione(_n - 1)
	return [ultimo, ultimo, 0.0]


static func _leggi(o: Object, campi: Array[StringName]) -> Array:
	var v: Array = []
	v.resize(campi.size())
	for k in campi.size():
		v[k] = o.get(campi[k])
	return v


static func _scrivi(o: Object, campi: Array[StringName], a: Array, b: Array, vicino: Array, n_num: int, w: float) -> void:
	for k in campi.size():
		if k < n_num and w > 0.0 and w < 1.0:
			o.set(campi[k], lerpf(a[k], b[k], w))
		elif k < n_num:
			o.set(campi[k], a[k] if w <= 0.0 else b[k])
		else:
			o.set(campi[k], vicino[k])


static func _scrivi_tutto(o: Object, campi: Array[StringName], v: Array) -> void:
	for k in campi.size():
		o.set(campi[k], v[k])
