# Allenamento guidato (porting di src/tutorial.js): per ogni meccanica una scheda di spiegazione, poi la si prova
# subito in campo REPS volte, in situazioni diverse. Usa una partita vera (SimMatch) e la prepara a ogni prova; avanza
# quando il motore segnala l'evento giusto. Non tocca il motore: sposta solo giocatori e pallone come fanno i test.
# Logica pura, senza grafica: la provano i test (tests/test_allenamento.gd); la collega alla partita gioco.gd
# (before() prima dei passi del motore, after(dt) dopo, prima di consumare m.events), l'interfaccia è
# scripts/partita/allenamento_hud.gd.
#
# ui = oggetto con due metodi (come { text, card } del web):
#   text(titolo: String, testo: String, prova: int, prove: int, bene: bool)   riquadro in alto ("" = nascosto)
#   card(lezione: Dictionary o null, indice: int, totale: int)               scheda della meccanica; null = fine
# I testi hanno <b>...</b> come nel web (l'interfaccia li fa gialli).
extends RefCounted

const R := preload("res://sim/records.gd")
const C := preload("res://sim/core.gd")
const SimRng := preload("res://sim/rng.gd")

const STEP_TIMEOUT := 16.0    # secondi prima di rimettere a posto la prova
const DONE_PAUSE := 1.3       # secondi di "Bravo!" prima della prova successiva
const FREEZE := 0.2           # stordimento rinnovato a ogni fotogramma per tenere fermi i giocatori fuori dalla prova
const REPS := 3               # prove per ogni meccanica
const GUIDA_PUNTI := 16       # punti della linea guida dei passaggi e dei tiri
const GUIDA_PANCIA := 0.25    # linea guida curva: pancia pari a tanta parte della lunghezza (sopra la soglia CURVE_*) ...
const GUIDA_PANCIA_TIRO := 0.2 # ... e nei tiri, più lunghi (così resta sullo schermo)
const DRIB_DEF_DIF := 15.0    # lezione Dribbling: difesa del difensore, così il dribbling riesce quasi sempre (è una lezione)
const HALF_LEN := 99999.0     # in allenamento il tempo non finisce mai
const BRAVO := "Bravo!"

# Ogni lezione: titolo, testi, chi resta fermo (freeze), `needs` = metodo del motore senza il quale si salta.
# Situazioni (setup), riuscita (check sugli eventi, poll sullo stato) sono i metodi _setup_*, _check_*, _poll_* sotto.
const LESSONS := [
	# Passaggi e tiri (Luis 2026-11-22): col pallone ogni linea è un calcio; la forma del tratto decide il colpo.
	# guida = linea da seguire mostrata in campo (guida() sotto, disegnata da allenamento_hud.gd)
	{
		"id": "passaggio", "title": "Passaggio rasoterra",
		"short": "Linea <b>dritta</b> dalla palla al compagno: rasoterra.",
		"text": "Col pallone il tuo giocatore corre da solo: tu <b>disegni dalla palla</b>. Una linea <b>dritta</b> fino a un compagno è un passaggio <b>rasoterra</b>, forte quanto basta per arrivare dove finisce la linea. Funziona in ogni zona del campo. Segui la linea tratteggiata.",
		"freeze": "opp", "guida": "dritta",
	},
	{
		"id": "passaggio_alto", "title": "Passaggio a effetto",
		"short": "Linea <b>curva</b> dalla palla al compagno: la palla si alza e scavalca il difensore.",
		"text": "Se in mezzo c'è un avversario <b>curva la linea</b>: la palla gira dal lato della curva e <b>si alza</b>, scavalcando chi sta in mezzo. Più curvi, più va alta. Una linea appena storta resta un passaggio rasoterra.",
		"freeze": "opp", "guida": "curva",
	},
	{
		"id": "tiro", "title": "Tiro rasoterra",
		"short": "Linea <b>dritta</b> che finisce dentro la porta: tiro rasoterra.",
		"text": "Una linea che <b>finisce dentro la porta</b> è un tiro. Se è <b>dritta</b> il tiro è <b>rasoterra</b>, forte e teso verso il punto dove l'hai finita.",
		"freeze": "opp-but-gk", "guida": "dritta",
	},
	{
		"id": "tiro_giro", "title": "Tiro a giro",
		"short": "Linea <b>curva</b> che finisce in porta: tiro a giro.",
		"text": "<b>Curva la linea</b> che finisce in porta: il pallone gira attorno al portiere e <b>si alza</b>, ed entra all'altezza dove finisce la linea. Più curvi, più gira.",
		"freeze": "opp-but-gk", "guida": "curva",
	},
	{
		"id": "recupera", "title": "Recupera palla",
		"short": "Disegna una linea dal tuo giocatore fino all'avversario.",
		"text": "In difesa <b>disegna una linea dai tuoi giocatori</b> (tutti tranne il portiere): corrono lungo la strada che tracci. Mandali addosso all'avversario o sulla linea del passaggio per intercettarlo: ogni difensore prende la palla dentro un piccolo raggio, più largo se è bravo in difesa e più stretto se chi passa è bravo nei passaggi.",
		# l'avversario resta fermo col pallone (prima lo perdeva da solo passando a vuoto); i tuoi si muovono solo con la linea
		"freeze": "opp", "noAutoDef": true,
	},
	{
		"id": "dribbling", "title": "Dribbling",
		"short": "Avvicinati al difensore e tocca Dribbling.",
		"text": "Quando arrivi addosso a un difensore la visuale si abbassa e il tempo rallenta: puoi <b>passare</b> a un compagno libero oppure toccare <b>Dribbling</b> in basso: il tuo giocatore punta il difensore e lo salta quando gli arriva vicino.",
		"needs": "userDribble",
		"freeze": "opp-but-o",
	},
	{
		"id": "scatto", "title": "Scatto", # Luis 2026-11-21: Scatto solo con l'avversario alla pari o dietro (fuga)
		"short": "Hai un avversario alle spalle: tocca Scatto.",
		"text": "Se un avversario ti arriva <b>alla pari o alle spalle</b> il tempo rallenta e in basso compare <b>Scatto</b>: toccalo e il tuo giocatore si stacca e prosegue dritto. Puoi anche <b>passare</b> disegnando fino a un compagno. Con l'avversario davanti, invece, si dribbla o si passa.",
		"needs": "userSprint",
		"freeze": "opp-but-o",
	},
	{
		"id": "portiere", "title": "Portiere",
		"short": "Quando tira, il tempo si ferma: linea dal portiere al bersaglio.",
		"text": "Quando l'avversario tira la visuale va dietro la tua porta e il tempo <b>si ferma per 3 secondi</b>: il <b>bersaglio rosso</b> sulla porta mostra dove arriva la palla, più o meno. <b>Tira una linea dal portiere al punto della porta</b> dove vuoi tuffarti: alzato il dito il tempo riparte e il portiere va lì. Un tiro forte nell'angolo lontano può restare imprendibile; senza linea il portiere fa da solo, ma in ritardo.",
		"freeze": "all-but-shooter",
	},
]

var m                          # SimMatch
var ui: Object
var lessons: Array = []        # LESSONS senza quelle che il motore non sa fare
var li := -1                   # lezione attuale
var k := 0                     # prova attuale (0..REPS-1)
var t := 0.0                   # secondi di gioco dall'inizio della prova
var done := 0.0                # > 0: "Bravo!" in corso, secondi che mancano alla prova dopo
var st := {}                   # stato della prova: {c portatore, o avversario, x0, y0, k}
var card := false              # scheda della meccanica aperta (partita ferma)
var finished := false
var riuscite := {}             # titolo della lezione → prove riuscite (per le prove e il riassunto)


func _init(match_, ui_: Object) -> void:
	m = match_
	ui = ui_
	for l: Dictionary in LESSONS:
		if not l.has("needs") or m.has_method(l.needs):
			lessons.append(l)
	next_lesson()


## lezione attuale (Dictionary di LESSONS)
func lesson() -> Dictionary:
	return lessons[li]


## squadra avversaria dell'allenamento (come il web: "Allenamento", livello 40), statistiche da un seme fisso
static func squadra_ospite() -> Dictionary:
	var r := SimRng.new(7)
	var F: Array = C.FORMATIONS["4-4-2"]
	var giocatori: Array = []
	for i in F.size():
		var pos: String = F[i][0]
		var p := {"name": "Sparring %d" % (i + 1), "num": i + 1, "pos": pos}
		for s: String in ["vel", "tir", "pas", "dri", "dif", "fis"]:
			p[s] = int(C.round_(40.0 + (r.next() - 0.5) * 10.0))
		p["por"] = int(C.round_(44.0 + (r.next() - 0.5) * 10.0)) if pos == "P" else 12
		p["tes"] = int(C.headingOf(p))
		giocatori.append(p)
	return {"name": "Allenamento", "short": "ALL", "formation": "4-4-2", "skill": 0.1,
		"kit": {"shirt": 0x1e9e5a, "shorts": 0xffffff, "socks": 0x1e9e5a, "gk": {"shirt": 0xffa41c, "shorts": 0x222222, "socks": 0xffa41c}},
		"players": giocatori}


# ------------------------------------------------ aiuti per preparare le prove
func put(p: R.Player, x: float, y: float) -> void:
	m.place(p, x, y)
	p.fx = 0.0
	p.fy = 1.0


func carrier(idx: int, x: float, y: float) -> R.Player:
	var c: R.Player = m.players[idx]
	put(c, x, y)
	var b: R.Ball = m.ball
	b.owner = c
	b.x = c.x + c.fx * 0.6 # pallone già ai piedi (prima arrivava solo al primo passo del motore)
	b.y = c.y + c.fy * 0.6
	b.kick = null
	b.shot = null
	b.h = 0.0
	b.vx = 0.0
	b.vy = 0.0
	b.vh = 0.0
	m.ctrl[0] = c
	m.att = 0
	c.protect = 1.0
	return c


# avversari lontani dall'azione (portiere al suo posto)
func clear_opp() -> void:
	var n := 0
	for p: R.Player in m.team(1):
		if p.pos == "P":
			put(p, 0.0, 49.0)
			continue
		put(p, -26.0 + (n % 5) * 13.0, 41.0 - floorf(n / 5.0) * 3.0)
		n += 1


# ------------------------------------------------ svolgimento
func next_lesson() -> void:
	li += 1
	k = 0
	if li >= lessons.size():
		finished = true
		card = false
		ui.card(null, li, lessons.size())
		return
	card = true
	ui.card(lesson(), li, lessons.size())


## la scheda è stata chiusa: si comincia a provare
func go() -> void:
	if not card:
		return
	card = false
	reset()


func reset() -> void:
	var L := lesson()
	t = 0.0
	done = 0.0
	m.phase = "play"
	m.restart = null
	m.move = [null, null]
	m.runs = [[], []]
	m.lastPass = null
	m.resetStates()
	m.autoDef = [not L.get("noAutoDef", false), true] # in "Recupera palla" la CPU non difende: si impara la linea
	# in allenamento niente espulsioni né stanchezza: ogni prova riparte con tutti in campo; e niente attese rimaste
	# dalla prova prima: duello, dribbling e contrasti ripartono da zero (sennò, dopo un dribbling fallito, il tasto
	# Dribbling della prova nuova non faceva nulla per secondi)
	for p: R.Player in m.players:
		p.off = false
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
	m.duel = null
	m.duelCd = [0.0, 0.0]
	m.duelCdP = [null, null]
	m.flee = null
	m.fleeCd = [0.0, 0.0]
	m.fleeCdP = [null, null]
	m.ctrl[0] = null
	m.place(m.gk(0), 0.0, -49.0)
	m.place(m.gk(1), 0.0, 49.0)
	for p: R.Player in m.team(0):
		if p.pos != "P" and p.i != 7 and p.i != 9:
			var a: PackedFloat64Array = m.anchor(p)
			put(p, a[0], minf(a[1], -5.0))
	st = call("_setup_" + String(L.id), k)
	m.events.clear()
	var hint: Array = L.get("hint", [])
	ui.text(L.title, hint[k] if not hint.is_empty() else String(L.short), k, REPS, false)


func frozen(p: R.Player) -> bool:
	var f: String = lesson().freeze
	match f:
		"opp":
			return p.team == 1
		"opp-but-gk":
			return p.team == 1 and p.pos != "P"
		"opp-but-o":
			return p.team == 1 and p != st.get("o")
		"all-but-duel":
			return p != st.get("o") and p != m.ctrl[0]
		"all-but-shooter":
			return p != st.get("o") and p.pos != "P"
	return false


## da chiamare prima di m.step: tiene fermi i giocatori fuori dalla prova
func before() -> void:
	if finished or card:
		return
	for p: R.Player in m.players:
		if not p.off and frozen(p):
			p.stun = maxf(p.stun, FREEZE)


## da chiamare dopo m.step (dt = tempo di gioco passato), prima che gioco.gd consumi m.events
func after(dt: float) -> void:
	if finished or card:
		return
	var L := lesson()
	if done > 0.0:
		done -= dt
		if done <= 0.0:
			k += 1
			if k >= REPS:
				next_lesson()
			else:
				reset()
		return
	t += dt
	var ok := false
	var chk := "_check_" + String(L.id)
	if has_method(chk):
		for e: Dictionary in m.events:
			if call(chk, e):
				ok = true
	var pol := "_poll_" + String(L.id)
	if not ok and has_method(pol) and call(pol):
		ok = true
	if ok:
		done = DONE_PAUSE
		riuscite[L.title] = int(riuscite.get(L.title, 0)) + 1
		ui.text(L.title, BRAVO, k + 1, REPS, true)
		return
	# pallone uscito, gol o tempo scaduto: si rimette a posto la stessa prova
	var c: R.Player = st.get("c")
	var lost: bool = c != null and m.ball.owner != null and m.ball.owner.team == 1
	if m.phase != "play" or t > STEP_TIMEOUT or lost:
		reset()


# ------------------------------------------------ le lezioni: situazioni (indice kk della prova) e riuscita
func _setup_passaggio(kk: int) -> Dictionary:
	var c := carrier(7, [0.0, -6.0, 4.0][kk], [0.0, -4.0, 6.0][kk])
	clear_opp()
	var mate: Array = [[9.0, 18.0], [-16.0, 10.0], [14.0, 8.0]][kk]
	put(m.players[9], mate[0], mate[1])
	return {"c": c, "mate": m.players[9]}


## passaggio riuscito: un compagno controlla un nostro passaggio del tipo voluto (ground o loft); curvo = solo col
## tratto curvo (il pallone alto ma dritto del tratto dritto lungo o scavalcando non vale per la lezione a effetto)
func _passaggio_ok(e: Dictionary, kind: String, curvo: bool = false) -> bool:
	if e.type == "kick" and (e.p as R.Player).team == 0:
		st.kind = e.kind
		st.curvo = bool(e.get("curvo", false))
	return e.type == "control" and (e.p as R.Player).team == 0 and e.p != st.c and st.get("kind", "") == kind 			and (not curvo or st.get("curvo", false))


func _check_passaggio(e: Dictionary) -> bool:
	return _passaggio_ok(e, "ground")


func _setup_passaggio_alto(kk: int) -> Dictionary:
	var c := carrier(7, [0.0, -6.0, 4.0][kk], [0.0, -4.0, 6.0][kk])
	clear_opp()
	var mate: Array = [[4.0, 20.0], [-14.0, 14.0], [16.0, 18.0]][kk]
	put(m.players[9], mate[0], mate[1])
	# difensore a metà strada: un passaggio rasoterra lo prenderebbe
	var o: R.Player = m.players[16]
	put(o, (c.x + mate[0]) / 2.0, (c.y + mate[1]) / 2.0)
	o.fy = -1.0
	return {"c": c, "o": o, "mate": m.players[9]}


func _check_passaggio_alto(e: Dictionary) -> bool:
	return _passaggio_ok(e, "loft", true)


func _setup_tiro(kk: int) -> Dictionary:
	var p: Array = [[5.0, 29.0], [-12.0, 33.0], [2.0, 22.0]][kk]
	var c := carrier(9, p[0], p[1])
	clear_opp()
	return {"c": c}


func _check_tiro(e: Dictionary) -> bool:
	return e.type == "kick" and (e.p as R.Player).team == 0 and e.kind == "shot" and not e.get("curvo", false)


func _setup_tiro_giro(kk: int) -> Dictionary:
	return _setup_tiro(kk)


func _check_tiro_giro(e: Dictionary) -> bool:
	return e.type == "kick" and (e.p as R.Player).team == 0 and e.kind == "shot" and e.get("curvo", false)


## linea guida della lezione (passaggi e tiri): punti del campo Vector3(x, y, h) dal pallone a dove finire,
## dritta o curva come va disegnata; [] se la lezione non ne ha o il pallone non è del portatore della prova
func guida() -> Array:
	if finished or card or done > 0.0 or li < 0:
		return []
	var tipo: String = lesson().get("guida", "")
	var c: R.Player = st.get("c")
	if tipo == "" or c == null or m.ball.owner != c:
		return []
	var a := Vector3(m.ball.x, m.ball.y, 0.0)
	var b: Vector3
	var lato := 1.0
	var pancia := GUIDA_PANCIA
	if st.has("mate"):
		var q: R.Player = st.mate
		b = Vector3(q.x, q.y, 0.0)
		lato = 1.0 if q.x <= c.x else -1.0
	else:
		var px := -2.2 if c.x >= 0.0 else 2.2 # palo lontano
		b = Vector3(px, C.HL, 1.3 if tipo == "curva" else 0.0)
		lato = -signf(px)
		pancia = GUIDA_PANCIA_TIRO
	var punti: Array = []
	var n := Vector2(-(b.y - a.y), b.x - a.x).normalized() * Vector2(b.x - a.x, b.y - a.y).length() * pancia * lato
	for i in GUIDA_PUNTI + 1:
		var u := float(i) / GUIDA_PUNTI
		var p := a.lerp(b, u)
		if tipo == "curva":
			p += Vector3(n.x, n.y, 0.0) * 4.0 * u * (1.0 - u)
		punti.append(p)
	return punti


func _setup_recupera(kk: int) -> Dictionary:
	var o: R.Player = m.players[20]
	put(o, [0.0, -14.0, 12.0][kk], [6.0, 10.0, 2.0][kk])
	o.fx = 0.0
	o.fy = -1.0
	m.ball.owner = o
	m.ball.kick = null
	m.att = 1
	var me: R.Player = m.players[7]
	put(me, o.x + 1.0, o.y - 8.0)
	m.ctrl[0] = me
	return {"o": o}


func _check_recupera(e: Dictionary) -> bool:
	return e.type == "tackle" and (e.p as R.Player).team == 0


func _poll_recupera() -> bool:
	return m.ball.owner != null and m.ball.owner.team == 0


func _setup_dribbling(kk: int) -> Dictionary:
	var c := carrier(7, [0.0, -10.0, 10.0][kk], [-6.0, 0.0, -2.0][kk])
	clear_opp()
	var o: R.Player = m.players[16]
	put(o, c.x + [0.0, 1.0, -1.0][kk], c.y + 7.0)
	o.fx = 0.0
	o.fy = -1.0
	o.st.dif = minf(o.st.dif, DRIB_DEF_DIF)
	put(m.players[9], c.x + [12.0, 14.0, -14.0][kk], c.y + 4.0)
	return {"c": c, "o": o}


func _check_dribbling(e: Dictionary) -> bool:
	return e.type == "dribble" and (e.p as R.Player).team == 0 and e.ok


func _setup_scatto(kk: int) -> Dictionary:
	var c := carrier(7, [0.0, -12.0, 12.0][kk], [-8.0, -2.0, -14.0][kk])
	clear_opp()
	var o: R.Player = m.players[16]
	put(o, c.x + [-1.5, 2.0, 0.0][kk], c.y - [2.0, 0.5, 2.5][kk])
	return {"c": c, "o": o}


func _check_scatto(e: Dictionary) -> bool:
	return e.type == "burst" and (e.p as R.Player).team == 0


func _setup_portiere(kk: int) -> Dictionary:
	var o: R.Player = m.players[20]
	put(o, [4.0, -12.0, 10.0][kk], [-31.0, -34.0, -28.0][kk])
	o.fx = 0.0
	o.fy = -1.0
	m.ball.owner = o
	m.ball.kick = null
	m.att = 1
	o.aiT = 0.6
	put(m.gk(0), 0.0, -49.0)
	return {"o": o}


func _check_portiere(e: Dictionary) -> bool:
	if e.type != "dive" and e.type != "save":
		return false
	var g := e.p as R.Player
	if g.team != 0:
		return false
	# il tuffo partito da solo (fermatempo finito senza linea, sim/parata.gd) non conta: la lezione è la linea
	if e.get("auto", false) or (g.dive != null and g.dive.auto):
		return false
	return e.type == "save" or not m.autoGk[0]
