# Allenamento libero (PIANO.md, fase E punto 13): tre prove a punti col campione della carriera.
#   tiri       10 tiri dal limite e dentro l'area, solo il campione e il portiere avversario
#   punizioni   8 punizioni con la barriera vera del motore (buildWall), distanze e angoli diversi
#   rigori      5 rigori; se entrano tutti si va avanti a oltranza fino al primo errore (massimo RIGORI_MAX)
# Punti per ogni gol: PUNTI_GOL, +PUNTI_PALO vicino al palo, +PUNTI_ALTO sotto la traversa (angolino = tutti e due).
# Si tira coi gesti della partita (linea che finisce in porta, curvata = effetto): qui si prepara solo la situazione.
# Non tocca il motore: chi non serve sta fermo in panchina, fuori dalla linea laterale alle spalle di chi tira
# (non p.off: i calci da fermo dopo il tiro, rimessa o angolo, cercano un battitore tra chi è in campo), e sposta
# giocatori e pallone come allenamento.gd.
# Logica pura, senza grafica: la provano i test (tests/test_prove_tiro.gd); la collega alla partita
# scripts/partita/prove_tiro_regia.gd (before() prima dei passi del motore, after(dt) dopo, prima di consumare
# m.events).
#
# ui = oggetto con tre metodi:
#   stato(prova: String, tentativo: int, tentativi: int, punti: int)   riquadro in alto (tentativo da 0)
#   esito(gol: bool, punti: int, nota: String)                          scritta dopo ogni tiro
#   fine(riassunto: Dictionary)                                         prova finita: {prova, punti, esiti, gol}
extends RefCounted

const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const SimRng := preload("res://sim/rng.gd")

const PROVE := ["tiri", "punizioni", "rigori"]
const NOMI := {"tiri": "Tiri", "punizioni": "Punizioni", "rigori": "Rigori"}
const TENTATIVI := {"tiri": 10, "punizioni": 8, "rigori": 5}
const RIGORI_MAX := 15        # rigori a oltranza: al massimo questi in tutto
const TEMPO_TIRO := 12.0      # secondi di gioco per tirare (poi "Niente tiro")
const TEMPO_ESITO := 3.5      # secondi di gioco dal tiro al verdetto se il pallone resta in campo
const PAUSA_ESITO := 1.8      # secondi di gioco con la scritta dell'esito prima del tentativo dopo
const FREEZE := 0.2           # stordimento rinnovato a ogni fotogramma per tenere fermi i giocatori
const PUNTI_GOL := 10
const PUNTI_PALO := 5
const PUNTI_ALTO := 5
const VICINO_PALO := 0.9      # m dal palo: tiro "vicino al palo"
const ALTO_DA := C.GH - 0.8   # m da terra: tiro "sotto la traversa"
const BARRIERA := 5           # avversari in campo nelle punizioni (la barriera ne usa 2-5)
const PANCHINA_X := C.HW + 3.0    # panchina: fuori dalla linea laterale sinistra...
const PANCHINA_Y := -8.0          # ... dalla metà campo verso la propria porta, alle spalle di chi tira
const PANCHINA_PASSO := 1.6
const HALF_LEN := 99999.0     # il tempo non finisce mai
# tiri: distanza dalla porta (m) fuori e dentro l'area, angolo massimo dal centro (radianti)
const TIRI_FUORI := [19.0, 25.0]
const TIRI_DENTRO := [11.0, 16.0]
const TIRI_ANGOLO := 0.75
const TIRI_FUORI_OGNI := 3    # un tiro ogni tre da fuori area (4 su 10)
# punizioni: distanza dalla porta (m) e angolo massimo; sempre fuori dall'area
const PUN_DIST := [18.0, 28.0]
const PUN_ANGOLO := 0.8

var m                         # SimMatch
var ui: Object
var prova := "tiri"
var seme := 1
var seq: Array = []           # posti del pallone: [{x, y}] (sequenza(prova, seme))
var k := 0                    # tentativo attuale (da 0)
var punti := 0
var esiti: Array = []         # [{gol, punti, nota}]
var fase := "tiro"            # "tiro" (si aspetta il tiro), "volo" (pallone partito), "esito" (scritta), "fine"
var t := 0.0
var finished := false
var campione: R.Player = null
var panchina: Array = []      # chi non gioca la prova: fermo fuori dal campo
var barriera: Array = []      # punizioni: avversari che possono fare la barriera
var _visti := {}              # eventi visti durante il volo (parata, palo, respinta)
var _prima := Vector3.ZERO    # pallone prima dei passi del fotogramma (per il punto in cui entra in porta)


func _init(match_, ui_: Object, prova_: String, seme_: int) -> void:
	m = match_
	ui = ui_
	prova = prova_ if PROVE.has(prova_) else "tiri"
	seme = seme_
	seq = sequenza(prova, seme)
	campione = scegli_campione(m)
	_panchina()
	_prepara()


# ---------------------------------------------------------------- funzioni pure (le provano i test)
## posti del pallone per la prova: stesso seme = stessa sequenza
static func sequenza(prova_: String, seme_: int) -> Array:
	var r := SimRng.new(seme_)
	var out: Array = []
	match prova_:
		"tiri":
			for i in TENTATIVI.tiri:
				var fuori := i % TIRI_FUORI_OGNI == 0
				var lim: Array = TIRI_FUORI if fuori else TIRI_DENTRO
				var d: float = lerpf(lim[0], lim[1], r.next())
				var a := (r.next() - 0.5) * 2.0 * TIRI_ANGOLO
				out.append(_posto(sin(a) * d, C.HL - cos(a) * d))
		"punizioni":
			for i in TENTATIVI.punizioni:
				var d: float = lerpf(PUN_DIST[0], PUN_DIST[1], r.next())
				var a := (r.next() - 0.5) * 2.0 * PUN_ANGOLO
				var x := sin(a) * d
				var y := C.HL - cos(a) * d
				if absf(x) < C.BOX_W / 2.0 + 1.0: # mai dentro l'area (sarebbe rigore)
					y = minf(y, C.HL - C.BOX_D - 1.0)
				out.append(_posto(x, y))
		_:
			for i in RIGORI_MAX:
				out.append(_posto(0.0, C.HL - C.PEN_D))
	return out


static func _posto(x: float, y: float) -> Dictionary:
	return {"x": snappedf(x, 0.1), "y": snappedf(y, 0.1)}


## punti di un gol dal punto in cui il pallone passa la linea (x = di lato, h = altezza): {punti, nota}
static func punti_gol(x: float, h: float) -> Dictionary:
	var palo := absf(x) >= C.GW / 2.0 - VICINO_PALO
	var alto := h >= ALTO_DA
	var p := PUNTI_GOL + (PUNTI_PALO if palo else 0) + (PUNTI_ALTO if alto else 0)
	var nota := "Gol"
	if palo and alto:
		nota = "Angolino!"
	elif palo:
		nota = "Vicino al palo"
	elif alto:
		nota = "Sotto la traversa"
	return {"punti": p, "nota": nota}


## tentativi previsti (per i rigori i primi 5: a oltranza ce ne possono essere di più)
static func tentativi_di(prova_: String) -> int:
	return int(TENTATIVI.get(prova_, 10))


## il campione della persona (src.champ, squadra 0); se manca o è il portiere, chi tira meglio tra gli altri
static func scegli_campione(mm) -> R.Player:
	var meglio: R.Player = null
	for p: R.Player in mm.team(0):
		if p.pos == "P":
			continue
		if p.src.get("champ", false):
			return p
		if meglio == null or p.st.tir > meglio.st.tir:
			meglio = p
	return meglio


# ---------------------------------------------------------------- svolgimento
## quanti tentativi in tutto adesso (rigori: 5, poi uno in più per ogni gol dopo il quinto)
func tentativi() -> int:
	if prova != "rigori" or k < TENTATIVI.rigori:
		return tentativi_di(prova)
	return mini(k + 1, RIGORI_MAX)


func gol_fatti() -> int:
	return esiti.filter(func(e: Dictionary) -> bool: return e.gol).size()


# in gioco solo il campione, i due portieri e (nelle punizioni) chi fa la barriera; gli altri in panchina
func _panchina() -> void:
	panchina.clear()
	barriera.clear()
	for p: R.Player in m.players:
		p.off = false
		if p.pos == "P" or p == campione:
			continue
		if p.team == 1 and prova == "punizioni" and barriera.size() < BARRIERA:
			barriera.append(p)
		else:
			panchina.append(p)


func _in_panchina() -> void:
	for i in panchina.size():
		var p: R.Player = panchina[i]
		m.place(p, -PANCHINA_X, PANCHINA_Y - i * PANCHINA_PASSO)
		p.fx = 1.0
		p.fy = 0.0
		p.wall = null


func _prepara() -> void:
	t = 0.0
	fase = "tiro"
	_visti = {}
	m.phase = "play"
	m.restart = null
	m.move = [null, null]
	m.runs = [[], []]
	m.lastPass = null
	m.advantage = null
	m.resetStates()
	for p: R.Player in m.players:
		p.yellow = 0
		p.energy = 1.0
		p.vx = 0.0
		p.vy = 0.0
		p.stun = 0.0
		p.dribCd = 0.0
		p.tackleCd = 0.0
		p.protect = 0.0
		p.beat = 0.0
		p.burst = 0.0
		p.cele = 0
	m.duel = null
	m.duelCd = [0.0, 0.0]
	m.duelCdP = [null, null]
	m.flee = null
	m.fleeCd = [0.0, 0.0]
	m.fleeCdP = [null, null]
	_metti(m.gk(0), 0.0, -C.HL + 1.0)
	_metti(m.gk(1), 0.0, C.HL - 1.0)
	_in_panchina()
	for n in barriera.size(): # la barriera si forma da sola (buildWall): intanto vicino al dischetto
		_metti(barriera[n], -6.0 + n * 3.0, C.HL - C.PEN_D - 2.0)
	var s: Dictionary = seq[k]
	var b = m.ball
	b.kick = null
	b.shot = null
	b.h = 0.0
	b.vx = 0.0
	b.vy = 0.0
	b.vh = 0.0
	b.dbl = null
	match prova:
		"tiri":
			_metti(campione, s.x, s.y)
			m.faceTo(campione, 0.0, C.HL)
			b.owner = campione
			b.last = campione
			b.x = campione.x + campione.fx * 0.6
			b.y = campione.y + campione.fy * 0.6
			m.att = 0
			campione.protect = 1.0
		"punizioni":
			_metti(campione, s.x, s.y)
			m.setRestart("freekick", 0, s.x, s.y)
			for q: R.Player in barriera: # chi non è servito per la barriera va in panchina
				if q.wall == null:
					m.place(q, -PANCHINA_X, PANCHINA_Y + 2.0 + barriera.find(q) * PANCHINA_PASSO)
		_:
			m.setRestart("penalty", 0, 0.0, 0.0)
	_in_panchina() # il rigore mette tutti al limite dell'area: si torna in panchina
	m.ctrl[0] = campione
	m.events.clear()
	ui.stato(prova, k, tentativi(), punti)


func _metti(p: R.Player, x: float, y: float) -> void:
	m.place(p, x, y)
	p.fx = 0.0
	p.fy = 1.0 if p.team == 0 else -1.0


## da chiamare prima dei passi del motore: ricorda il pallone e tiene fermi i giocatori durante la scritta
func before() -> void:
	var b = m.ball
	_prima = Vector3(b.x, b.y, b.h)
	if finished:
		return
	for p: R.Player in m.players:
		# la panchina sta sempre ferma; dopo il tiro il campione non riprende il pallone; durante la scritta tutti
		var seduto: bool = panchina.has(p) or (barriera.has(p) and absf(p.x) > C.HW)
		if fase == "esito" or (fase == "volo" and p == campione) or seduto:
			p.stun = maxf(p.stun, FREEZE)


## da chiamare dopo i passi del motore (dt = tempo di gioco passato), prima che gioco.gd consumi m.events
func after(dt: float) -> void:
	if finished:
		return
	t += dt
	match fase:
		"tiro":
			_aspetta_tiro()
		"volo":
			_segui_tiro()
		"esito":
			if t >= PAUSA_ESITO:
				_prossimo()


func _aspetta_tiro() -> void:
	for e: Dictionary in m.events:
		if e.type == "kick" and e.p == campione:
			fase = "volo"
			t = 0.0
			_segui_tiro() # un gol già in questo fotogramma (tiro a bruciapelo)
			return
		if e.type == "foul" and e.get("on") == campione: # fallo sul campione: si ripete lo stesso tentativo
			_prepara()
			return
	var b = m.ball
	var perso: bool = b.owner != null and b.owner.team == 1
	var fermo_altro: bool = m.phase == "restart" and (m.restart == null or m.restart.taker != campione)
	if t > TEMPO_TIRO or perso or fermo_altro or m.phase == "goal":
		_esito(false, 0, "Niente tiro")


func _segui_tiro() -> void:
	for e: Dictionary in m.events:
		match e.type:
			"goal":
				if int(e.team) == 0:
					var dove := _punto_in_porta()
					var pg := punti_gol(dove.x, dove.y)
					_esito(true, int(pg.punti), String(pg.nota))
				else:
					_esito(false, 0, "Fuori")
				return
			"save":
				_visti["parata"] = true
			"post":
				_visti["palo"] = true
			"block":
				_visti["respinta"] = true
	var b = m.ball
	var preso: bool = b.owner != null and b.owner.team == 1
	if t > TEMPO_ESITO or m.phase == "restart" or preso:
		var nota := "Fuori"
		if _visti.has("palo"):
			nota = "Palo!"
		elif _visti.has("parata") or (preso and b.owner.pos == "P"):
			nota = "Parata"
		elif _visti.has("respinta") or preso:
			nota = "Respinta"
		_esito(false, 0, nota)


# x e altezza del pallone sulla linea di porta, tra prima e dopo i passi del fotogramma
func _punto_in_porta() -> Vector2:
	var b = m.ball
	var dy: float = b.y - _prima.y
	if absf(dy) < 1e-6 or absf(b.y) < C.HL:
		return Vector2(b.x, b.h)
	var f := clampf((C.HL * signf(b.y) - _prima.y) / dy, 0.0, 1.0)
	return Vector2(lerpf(_prima.x, b.x, f), maxf(0.0, lerpf(_prima.z, b.h, f)))


func _esito(gol: bool, p: int, nota: String) -> void:
	esiti.append({"gol": gol, "punti": p, "nota": nota})
	punti += p
	fase = "esito"
	t = 0.0
	ui.stato(prova, k, tentativi(), punti)
	ui.esito(gol, p, nota)


func _prossimo() -> void:
	k += 1
	var ultimo: Dictionary = esiti[-1]
	var fine := k >= tentativi_di(prova)
	if prova == "rigori" and k >= TENTATIVI.rigori:
		# a oltranza solo se finora sono entrati tutti
		fine = not ultimo.gol or gol_fatti() < k or k >= RIGORI_MAX
	if fine:
		finished = true
		fase = "fine"
		ui.fine(riassunto())
		return
	_prepara()


func riassunto() -> Dictionary:
	return {"prova": prova, "punti": punti, "esiti": esiti.duplicate(true), "gol": gol_fatti(), "tentativi": esiti.size()}
