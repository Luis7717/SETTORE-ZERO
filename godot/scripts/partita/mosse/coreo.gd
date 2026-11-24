# Coreografia "nel mondo" per i movimenti del dribbling (portatore che finta e cambia direzione, difensore che
# interviene a vuoto o contrasta, portatore che inciampa). Solo grafica: il motore decide dove sta il giocatore, qui
# si decide come si muove il corpo per arrivarci.
#
# Differenza con mossa.gd (giochetti): lì tutto è nel riferimento del giocatore, quindi se il motore lo sposta mentre il
# giochetto va i piedi "a terra" scivolano con lui. Qui:
#   - i PIEDI sono nel mondo: un piede appoggiato resta fermo dov'è finché non si stacca (passo); dove appoggia lo si
#     decide durante il passo guardando dove sarà il corpo in quel momento (posizione e velocità del motore). Se il
#     motore porta il corpo troppo lontano da un piede a terra, quel piede fa da solo un passo (mai gambe stirate);
#   - il PALLONE si muove solo coi tocchi: tra due tocchi va dritto dal punto del tocco a quello del tocco dopo (il
#     piede lo prende proprio lì), dopo l'ultimo raggiunge il pallone del motore;
#   - il bacino segue il motore, più spostamenti, inclinazioni e abbassamenti per chiavi (riferimento del corpo, come
#     mossa.gd), e così busto, braccia e sguardo (verso il pallone);
#   - il verso mostrato del corpo gira dolce verso quello voluto (fisso o quello del motore, che invece può scattare).
# Il risultato (frame()) è una posa come Mossa.at(): figura.gd la mette con applica_mossa (IK di gambe e braccia).
#
# Riferimento del corpo (come mossa.gd): x = sinistra, y = su, z = avanti, metri del modello; i punti nel mondo sono
# Vector3 di Godot (y su). Tempi in s di partita dall'inizio dell'episodio.
extends RefCounted

const Corpo := preload("corpo.gd")
const Mossa := preload("mossa.gd")

const ENTRA := 0.08           # s: il peso della coreografia sale da 0 a 1 (sopra il clip di corsa)
const ESCE := 0.15            # s: ... e scende alla fine
const PELVIS := Vector3(0, 0.93, -0.04)
const PASSO_ALTO := 0.11      # m del modello: quanto si alza il piede a metà di un passo
const ALLUNGO_MAX := 0.93     # frazione della gamba (anca → caviglia) oltre cui un piede a terra fa un passo da solo
const PASSO_AUTO := 0.13      # s: durata di quel passo
const GAMBA := Corpo.THIGH_L + Corpo.CALF_L
const PALLA_R := 0.16         # raggio del pallone a schermo (m del gioco: vista.gd BALL_R)
const ANCA := 0.115           # m del modello: anca di lato rispetto al bacino
const YAW_K := 14.0           # 1/s: il verso mostrato va verso quello voluto con questa rapidità...
const YAW_V := 9.0            # ... e al massimo a questa velocità (rad/s)

var t := 0.0
var fine := INF               # fine dell'episodio (s); poi ESCE di uscita
var peso := 0.0
var finito := false
var yaw := 0.0                # verso mostrato (rotation.y della figura)
var yaw_fisso := NAN          # verso voluto fino a yaw_fisso_fino; NAN (o dopo) = quello del motore
var yaw_fisso_fino := INF
var palla := false            # questo episodio muove il pallone (vista.gd lo mostra al posto di quello del motore)
var tipo := ""
var lato := 0.0               # parametro della coreografia (lato del dribbling o della reazione)
var dati := {}                # dati della coreografia (coreo_dribbling.gd)

var _flip := 1.0
var _pos := Vector3.ZERO      # corpo nel mondo (dal motore) a questo fotogramma
var _vel := Vector3.ZERO
var _yaw_moto := 0.0
var _scala := Vector3.ONE     # scala della figura (Coord.SCALE × fisico)
var _palla_moto := Vector3.ZERO   # pallone del motore (a terra, mondo) e velocità
var _palla_vel := Vector3.ZERO
var _palla0 := Vector3.ZERO   # pallone mostrato all'inizio e sua velocità
var _palla0_v := Vector3.ZERO

# chiavi del corpo: [{t, v}] (v Vector3), curve rifatte quando cambiano
var _k := {"bacino": [], "angoli": [], "busto": [], "br_l": [], "br_r": []}
var _c := {}
var _sporco := true

# piedi: stato e passi programmati
var _piedi := {}
# tocchi del pallone: [{t, spec, pos (fissata quando passa)}]
var _tocchi: Array = []
var _palla_pos := Vector3.ZERO    # pallone mostrato (a terra) e velocità mostrata
var _palla_v := Vector3.ZERO
var _dt := 1.0 / 60.0
const ANTICIPO := 0.12        # s: un piede a terra con un appoggio, un tocco o un passaggio programmato si stacca tanto prima


## start: corpo all'inizio. p = giocatore del motore, flip = vista.flip, scala = scala della figura, caviglie =
## {l, r: Vector3 mondo} dalla posa di adesso, palla0 / palla0_v = pallone mostrato adesso e sua velocità (mondo)
func _init(p: Object, flip: float, scala: Vector3, caviglie: Dictionary, palla0: Vector3, palla0_v: Vector3) -> void:
	_flip = flip
	_scala = scala
	_leggi_motore(p, null)
	yaw = _yaw_moto
	_palla0 = Vector3(palla0.x, 0.0, palla0.z)
	_palla0_v = Vector3(palla0_v.x, 0.0, palla0_v.z)
	_palla_pos = _palla0
	_palla_v = _palla0_v
	var hl: float = (caviglie.l as Vector3).y
	var hr: float = (caviglie.r as Vector3).y
	var giu := Corpo.ANKLE_H * _scala.y
	for s: String in ["l", "r"]:
		var c: Vector3 = caviglie[s]
		var h := hl if s == "l" else hr
		var altra := hr if s == "l" else hl
		# a terra se basso e non chiaramente più alto dell'altro (correndo un piede è sempre più su)
		var terra := h < giu + 0.06 * _scala.y and h <= altra + 0.02 * _scala.y
		_piedi[s] = {"terra": terra, "pos": Vector3(c.x, giu if terra else c.y, c.z), "yaw": yaw, "pitch": 0.0, "roll": 0.0,
			"ev": [], "da": Vector3(c.x, c.y, c.z), "da_t": 0.0, "da_yaw": yaw, "da_pitch": 0.0, "da_roll": 0.0}
	if not _piedi.l.terra and not _piedi.r.terra:   # in volo tutti e due: il più basso è quello che appoggia prima
		_piedi["l" if hl <= hr else "r"].terra = false
	chiave_bacino(0.0, PELVIS)
	chiave_angoli(0.0, Vector3.ZERO)
	chiave_busto(0.0, Vector3(0.1, 0, 0))
	chiave_braccio("l", 0.0, Vector3(0.2, -0.5, 0.05))
	chiave_braccio("r", 0.0, Vector3(0.2, -0.5, 0.05))


## il piede `s` è a terra adesso?
func a_terra(s: String) -> bool:
	return _piedi[s].terra


# ---------------------------------------------------------------- costruzione (coreo_dribbling.gd)
func chiave_bacino(tt: float, p: Vector3) -> void:
	_metti("bacino", tt, p)


## angoli del bacino: (giro, avanti, di lato) in rad (come Mossa.pelvis)
func chiave_angoli(tt: float, a: Vector3) -> void:
	_metti("angoli", tt, a)


## curva del busto: (avanti, di lato, giro) in rad (come Mossa.bend)
func chiave_busto(tt: float, b: Vector3) -> void:
	_metti("busto", tt, b)


## mano rispetto alla spalla (x verso l'esterno, y su, z avanti), come Mossa.arm
func chiave_braccio(s: String, tt: float, off: Vector3) -> void:
	_metti("br_" + s, tt, off)


## il piede si stacca da terra a tt
func stacca(s: String, tt: float) -> void:
	_evento(s, {"t": tt, "tipo": "stacca"})


## il piede appoggia a tt in rel (x, z: riferimento del corpo in quel momento), girato di yaw_rel; dur = da quanto
## prima si stacca (se è a terra), 0 = come già programmato
func appoggia(s: String, tt: float, rel: Vector2, yaw_rel: float = 0.0, alto: float = PASSO_ALTO) -> void:
	_evento(s, {"t": tt, "tipo": "appoggia", "rel": rel, "yaw": yaw_rel, "alto": alto})


## punto di passaggio del piede in volo: rel = caviglia nel riferimento del corpo in quel momento (Vector3), piede
## girato (giro, punta in giù, inclinato)
func passa(s: String, tt: float, rel: Vector3, ang: Vector3 = Vector3.ZERO, alto: float = 0.03) -> void:
	_evento(s, {"t": tt, "tipo": "via", "rel3": rel, "ang": ang, "alto": alto})


## punto di passaggio nel mondo calcolato al momento (Callable() -> Vector3 caviglia), piede girato di ang
func passa_fn(s: String, tt: float, fn: Callable, ang: Vector3 = Vector3.ZERO, alto: float = 0.03) -> void:
	_evento(s, {"t": tt, "tipo": "via", "fn": fn, "ang": ang, "alto": alto})


## tocco del pallone col punto `part` del piede s a tt, piede girato di ang (giro, punta in giù, inclinato) rispetto
## al corpo; dove sta il pallone in quel momento lo dice spec (vedi _risolvi_palla). Il pallone dopo va al tocco dopo.
func tocca(s: String, tt: float, part: String, ang: Vector3, spec: Dictionary, alto: float = 0.04) -> void:
	var k := {"t": tt, "spec": spec, "pos": null}
	_tocchi.append(k)
	_tocchi.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	palla = true
	if s != "":
		_evento(s, {"t": tt, "tipo": "tocco", "part": part, "ang": ang, "tocco": k, "alto": alto})


## il pallone (senza piede) arriva a spec a tt: per esempio {"moto": true} = raggiunge quello del motore
func palla_a(tt: float, spec: Dictionary) -> void:
	tocca("", tt, "", Vector3.ZERO, spec)


## da tt in poi via chiavi, passi e tocchi programmati dopo (la coreografia cambia: arriva lo scatto del motore);
## i valori di adesso restano come chiave a tt, così il movimento continua senza salti
func taglia(tt: float) -> void:
	for nome: String in _k:
		var v: Vector3 = _curva(nome).at(tt) if not (_k[nome] as Array).is_empty() else Vector3.ZERO
		var tenute: Array = []
		for k: Dictionary in _k[nome]:
			if float(k.t) < tt - 1e-6:
				tenute.append(k)
		tenute.append({"t": tt, "p": v})
		_k[nome] = tenute
	_sporco = true
	for s: String in _piedi:
		var ev: Array = []
		for e: Dictionary in _piedi[s].ev:
			if float(e.t) <= tt:
				ev.append(e)
		_piedi[s].ev = ev
	var tk: Array = []
	for k: Dictionary in _tocchi:
		if float(k.t) <= tt:
			tk.append(k)
	_tocchi = tk
	if palla: # il pallone resta dov'è adesso (da qui va al tocco nuovo)
		_tocchi.append({"t": tt, "spec": {"mondo": _palla_pos}, "pos": _palla_pos})


## dove sarà il pallone mostrato a tt andando avanti come adesso
func pallone_previsto(tt: float) -> Vector3:
	return _palla_pos + _palla_v * maxf(0.0, tt - t)


## caviglia (mondo) verso `punto` a altezza h (m del modello), al massimo a frac della gamba dal bacino
func verso(punto: Vector3, frac: float, h: float) -> Vector3:
	var bac := _bacino_mondo()
	var q := Vector3(punto.x, h * _scala.y, punto.z)
	var d := q - bac
	var lim := frac * GAMBA * _scala.y
	return bac + d.normalized() * lim if d.length() > lim else q


func _metti(nome: String, tt: float, v: Vector3) -> void:
	var l: Array = _k[nome]
	for i in l.size():
		if absf(float(l[i].t) - tt) < 1e-6:
			l.remove_at(i)
			break
	l.append({"t": tt, "p": v})
	l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	_sporco = true


func _evento(s: String, e: Dictionary) -> void:
	var ev: Array = _piedi[s].ev
	ev.append(e)
	ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))


func _curva(nome: String) -> Object:
	if _sporco:
		for n: String in _k:
			_c[n] = Mossa.Curva.new(_k[n]) if not (_k[n] as Array).is_empty() else null
		_sporco = false
	return _c[nome]


# ---------------------------------------------------------------- motore → mondo
func _leggi_motore(p: Object, b: Object) -> void:
	var s := _flip
	_pos = Vector3(s * p.x, 0.0, -s * p.y)
	_vel = Vector3(s * p.vx, 0.0, -s * p.vy)
	_yaw_moto = atan2(s * p.fx, -s * p.fy)
	if b != null:
		_palla_moto = Vector3(s * b.x, 0.0, -s * b.y)
		_palla_vel = Vector3(s * b.vx, 0.0, -s * b.vy)


## dove sarà il corpo a tt (dal motore: posizione + velocità)
func corpo_a(tt: float) -> Vector3:
	return _pos + _vel * maxf(0.0, tt - t)


## verso del corpo a tt: quello fisso voluto (fino a yaw_fisso_fino), sennò quello del motore
func yaw_a(tt: float) -> float:
	return yaw_fisso if not is_nan(yaw_fisso) and tt < yaw_fisso_fino else _yaw_moto


## punto rel (riferimento del corpo, m del modello) nel mondo, col corpo come sarà a tt
func mondo_a(tt: float, rel: Vector3) -> Vector3:
	return corpo_a(tt) + Basis(Vector3.UP, yaw_a(tt)).scaled(_scala) * rel


# pallone (a terra, mondo) secondo spec a tt:
#   {"rel": Vector3}  punto davanti al corpo come sarà a tt (riferimento del corpo, m del modello)
#   {"rotola": true}  dove arriva quello mostrato all'inizio continuando con la sua velocità
#   {"moto": true}    pallone del motore (posizione + velocità)
#   {"mondo": Vector3} punto fisso
func _risolvi_palla(spec: Dictionary, tt: float) -> Vector3:
	if spec.has("rel"):
		var q := mondo_a(tt, spec.rel)
		return Vector3(q.x, 0.0, q.z)
	if spec.has("rotola"):
		return _palla0 + _palla0_v * tt * float(spec.get("k", 1.0))
	if spec.has("moto"):
		return _palla_moto + _palla_vel * maxf(0.0, tt - t)
	if spec.has("mondo"):
		return spec.mondo
	return _palla_pos


# ---------------------------------------------------------------- passo di ogni fotogramma
## avanza di dt (tempo di partita) col giocatore p e il pallone b del motore; fermo = il gioco si è fermato
## (l'episodio va subito in uscita)
func passo(dt: float, p: Object, b: Object) -> void:
	t += dt
	if dt > 0.0:
		_dt = dt
	_leggi_motore(p, b)
	if p.state != "play" and fine > t:
		fine = t
	# verso mostrato: dolce verso quello voluto, mai più veloce di YAW_V
	var mira := yaw_a(t)
	var d := wrapf(mira - yaw, -PI, PI)
	var passo_y := clampf(d * minf(1.0, dt * YAW_K), -YAW_V * dt, YAW_V * dt)
	yaw = wrapf(yaw + passo_y, -PI, PI)
	# peso
	if t >= fine:
		peso = maxf(0.0, peso - dt / ESCE)
		if peso <= 0.0:
			finito = true
	else:
		peso = minf(1.0, peso + dt / ENTRA) if dt > 0.0 else peso
	_aggiorna_palla()
	for s: String in ["l", "r"]:
		_aggiorna_piede(s)
	_passi_automatici()


func _aggiorna_palla() -> void:
	if not palla:
		return
	var prima := _palla_pos
	# tocchi passati: il pallone è lì
	var t0 := 0.0
	var p0 := _palla0
	var v0 := _palla0_v
	var dopo: Dictionary = {}
	for k: Dictionary in _tocchi:
		if float(k.t) <= t:
			if k.pos == null:
				k.pos = _risolvi_palla(k.spec, float(k.t))
			t0 = float(k.t)
			p0 = k.pos
			v0 = Vector3.INF
		else:
			dopo = k
			break
	if dopo.is_empty():
		# dopo l'ultimo tocco: se era "moto" il pallone è quello del motore, sennò resta dov'è
		var ultimo: Dictionary = _tocchi.back() if not _tocchi.is_empty() else {}
		_palla_pos = _palla_moto if ultimo.is_empty() or (ultimo.spec as Dictionary).has("moto") else p0
	else:
		var t1 := float(dopo.t)
		var p1 := _risolvi_palla(dopo.spec, t1)
		var u := clampf((t - t0) / maxf(1e-4, t1 - t0), 0.0, 1.0)
		if v0 == Vector3.INF:
			_palla_pos = p0.lerp(p1, u)   # dopo un tocco: dritto e a velocità costante fino al tocco dopo
		else:
			# dall'inizio al primo tocco: parte con la velocità che aveva e rallenta fino al tocco
			var dt1 := t1 - t0
			var m1 := (p1 - p0) / maxf(1e-4, dt1) * 0.5
			_palla_pos = Mossa.Curva.hermite(p0, v0, p1, m1, dt1, u)
	_palla_v = (_palla_pos - prima) / _dt


## pallone mostrato (a terra, mondo)
func pallone() -> Vector3:
	return _palla_pos


## l'episodio comanda ancora il pallone (dopo l'ultimo tocco "moto" coincide con quello del motore)
func pallone_attivo() -> bool:
	if not palla or finito:
		return false
	return not _tocchi.is_empty() and (float(_tocchi.back().t) > t or not (_tocchi.back().spec as Dictionary).has("moto"))


func _aggiorna_piede(s: String) -> void:
	var f: Dictionary = _piedi[s]
	var ev: Array = f.ev
	# a terra con un movimento programmato a breve (e nessuno stacco prima): si stacca adesso
	if f.terra and not ev.is_empty() and ev[0].tipo != "stacca" and float(ev[0].t) - t <= ANTICIPO:
		_stacca_ora(f, t)
	# eventi passati
	while not ev.is_empty() and float(ev[0].t) <= t:
		var e: Dictionary = ev.pop_front()
		match String(e.tipo):
			"stacca":
				if f.terra:
					_stacca_ora(f, float(e.t))
			"appoggia":
				var q := _bersaglio(s, e)
				f.terra = true
				f.pos = Vector3(q.pos.x, Corpo.ANKLE_H * _scala.y, q.pos.z)
				f.yaw = q.yaw
				f.pitch = 0.0
				f.roll = 0.0
			"tocco", "via":
				if f.terra:   # (un tocco col piede a terra: si stacca adesso)
					_stacca_ora(f, float(e.t))
				var q := _bersaglio(s, e)
				f.da = q.pos
				f.da_t = float(e.t)
				f.da_yaw = q.yaw
				f.da_pitch = q.pitch
				f.da_roll = q.roll
				f.pos = q.pos
	if f.terra:
		return
	# in volo: dal punto di prima al prossimo punto (appoggio, tocco o passaggio)
	var nx: Dictionary = {}
	for e: Dictionary in ev:
		if e.tipo != "stacca":
			nx = e
			break
	if nx.is_empty():   # nessun appoggio programmato: appoggia presto sotto l'anca
		nx = {"t": t + PASSO_AUTO * 0.5, "tipo": "appoggia", "rel": Vector2(Corpo.SIDE[s] * ANCA, 0.08), "yaw": 0.0, "alto": PASSO_ALTO * 0.5}
		ev.append(nx)
		ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	var q := _bersaglio(s, nx)
	var t0: float = f.da_t
	var t1 := float(nx.t)
	var u := clampf((t - t0) / maxf(1e-4, t1 - t0), 0.0, 1.0)
	var e2 := u * u * (3.0 - 2.0 * u)
	var a: Vector3 = f.da
	var b: Vector3 = q.pos
	var alto := float(nx.get("alto", PASSO_ALTO)) * _scala.y
	f.pos = a.lerp(b, e2) + Vector3.UP * (alto * sin(PI * u))
	f.yaw = lerp_angle(float(f.da_yaw), float(q.yaw), e2)
	# punta in giù a metà passo verso un appoggio; verso un tocco la posa del tocco
	var giu := 0.35 * sin(PI * u) if nx.tipo == "appoggia" else 0.0
	f.pitch = lerpf(float(f.da_pitch), float(q.pitch), e2) + giu
	f.roll = lerpf(float(f.da_roll), float(q.roll), e2)


func _stacca_ora(f: Dictionary, tt: float) -> void:
	f.terra = false
	f.da = f.pos
	f.da_t = tt
	f.da_yaw = f.yaw
	f.da_pitch = 0.0
	f.da_roll = 0.0


# dove va il piede per l'evento e: {pos (caviglia, mondo), yaw (mondo), pitch, roll}
func _bersaglio(s: String, e: Dictionary) -> Dictionary:
	var tt := float(e.t)
	var yb := yaw_a(tt)
	match String(e.tipo):
		"appoggia":
			var rel: Vector2 = e.rel
			var q := mondo_a(tt, Vector3(rel.x, Corpo.ANKLE_H, rel.y))
			return {"pos": q, "yaw": yb + float(e.yaw), "pitch": 0.0, "roll": 0.0}
		"via":
			var ang: Vector3 = e.ang
			var q: Vector3 = (e.fn as Callable).call() if e.has("fn") else mondo_a(tt, e.rel3)
			return {"pos": q, "yaw": yb + ang.x, "pitch": ang.y, "roll": ang.z}
		"tocco":
			var ang: Vector3 = e.ang
			var k: Dictionary = e.tocco
			var bp: Vector3 = k.pos if k.pos != null else _risolvi_palla(k.spec, tt)
			var centro := bp + Vector3.UP * PALLA_R
			var fq := Corpo.q_body(ang.x, ang.y, ang.z)            # piede nel riferimento del corpo
			var rot := Basis(Vector3.UP, yb)
			var n: Vector3 = rot * Corpo.foot_normal(fq, String(e.part), s)
			var contatto := centro - n.normalized() * PALLA_R
			var pt: Vector3 = Corpo.FOOT_PTS[String(e.part)][0]
			var off := rot.scaled(_scala) * (fq * Vector3(pt.x * Corpo.SIDE[s], pt.y, pt.z))
			var q := contatto - off
			q.y = maxf(q.y, Corpo.ANKLE_H * _scala.y * 0.9)
			return {"pos": q, "yaw": yb + ang.x, "pitch": ang.y, "roll": ang.z}
	return {"pos": _piedi[s].pos, "yaw": yb, "pitch": 0.0, "roll": 0.0}


# un piede a terra troppo lontano dall'anca (il motore ha portato via il corpo) fa da solo un passo
func _passi_automatici() -> void:
	var bac := _bacino_mondo()
	var rot := Basis(Vector3.UP, yaw).scaled(_scala)
	for s: String in ["l", "r"]:
		var f: Dictionary = _piedi[s]
		if not f.terra:
			continue
		var anca := bac + rot * Vector3(Corpo.SIDE[s] * ANCA, 0.0, 0.0)
		var lim := ALLUNGO_MAX * GAMBA * _scala.y
		if anca.distance_to(f.pos) <= lim:
			continue
		# (se è già programmato che si stacchi a momenti, va bene così)
		var presto := false
		for e: Dictionary in f.ev:
			if e.tipo == "stacca" and float(e.t) <= t + 0.04:
				presto = true
		var altro: Dictionary = _piedi["r" if s == "l" else "l"]
		if presto or not altro.terra:
			continue
		_stacca_ora(f, t)
		var nx: Dictionary = {}
		for e: Dictionary in f.ev:
			if e.tipo == "appoggia":
				nx = e
				break
		if nx.is_empty() or float(nx.t) > t + PASSO_AUTO * 1.5:
			_evento(s, {"t": t + PASSO_AUTO, "tipo": "appoggia", "rel": Vector2(Corpo.SIDE[s] * ANCA, 0.12), "yaw": 0.0, "alto": PASSO_ALTO})


func _bacino_mondo() -> Vector3:
	var bp: Vector3 = _curva("bacino").at(t)
	return _pos + Basis(Vector3.UP, yaw).scaled(_scala) * bp


# ---------------------------------------------------------------- posa
## posa nel riferimento del corpo per figura.applica_mossa: N = trasformazione della figura (mondo) in questo
## fotogramma (posizione del motore, verso `yaw`, scala). palla_mondo = pallone mostrato (per lo sguardo)
func frame(N: Transform3D, palla_mondo: Vector3) -> Dictionary:
	var inv := N.affine_inverse()
	var bp: Vector3 = _curva("bacino").at(t)
	var an: Vector3 = _curva("angoli").at(t)
	var pq := Corpo.q_body(an.x, an.y, an.z)
	var bend: Vector3 = _curva("busto").at(t)
	# sguardo verso il pallone (come Mossa.trunk_look): metà al collo e metà alla testa
	var ball_l := inv * (palla_mondo + Vector3.UP * PALLA_R)
	var tr0 := Corpo.trunk(bp, pq, bend)
	var to_b: Vector3 = Corpo.q_conj(tr0.q.spine_03) * (ball_l - ((tr0.p.Head as Vector3) + Vector3(0, 0.08, 0)))
	var hz := sqrt(to_b.x * to_b.x + to_b.z * to_b.z)
	var gy := clampf(atan2(to_b.x, to_b.z), -0.9, 0.9) * Corpo.smooth(hz / 0.25)
	var gp := clampf(atan2(-to_b.y, hz), -Mossa.LOOK_UP, 0.9)
	var half := Corpo.q_axis(Vector3.UP, gy / 2.0) * Corpo.q_axis(Vector3.RIGHT, gp / 2.0)
	var tr := Corpo.trunk(bp, pq, bend, half, half)
	var q3: Quaternion = tr.q.spine_03
	var arms := {}
	var legs := {}
	for s: String in ["l", "r"]:
		var off: Vector3 = _curva("br_" + s).at(t)
		var x: float = Corpo.SIDE[s]
		arms[s] = {"hand": Corpo.shoulder(tr, s) + q3 * Vector3(off.x * x, off.y, off.z), "pole": q3 * Vector3(0.35 * x, -0.25, -1)}
		var f: Dictionary = _piedi[s]
		var fq := Corpo.q_body(wrapf(float(f.yaw) - yaw, -PI, PI), float(f.pitch), float(f.roll))
		legs[s] = {"ankle": inv * (f.pos as Vector3), "fq": fq, "pole": Mossa._knee_dir(fq)}
	return {"t": t, "pelvis": {"p": bp, "q": pq}, "yaw": an.x, "rot": tr.q, "legs": legs, "arms": arms}


## per i test: {l, r: {terra, pos (mondo)}}
func piedi() -> Dictionary:
	var out := {}
	for s: String in _piedi:
		out[s] = {"terra": _piedi[s].terra, "pos": _piedi[s].pos}
	return out
