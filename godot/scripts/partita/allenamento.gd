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
const PASS_DEF_DIST := 11.0   # lezione Passaggio: distanza iniziale del difensore davanti al portatore (m)
const DRIB_DEF_DIF := 15.0    # lezione Scatto: difesa del difensore, così lo scatto riesce quasi sempre (è una lezione)
const HALF_LEN := 99999.0     # in allenamento il tempo non finisce mai
const BRAVO := "Bravo!"

# Ogni lezione: titolo, testi, chi resta fermo (freeze), `needs` = metodo del motore senza il quale si salta.
# Situazioni (setup), riuscita (check sugli eventi, poll sullo stato) sono i metodi _setup_*, _check_*, _poll_* sotto.
const LESSONS := [
	{
		"id": "passaggio", "title": "Passaggio",
		"short": "Corri verso il difensore; quando il tempo rallenta disegna dalla palla fino a un compagno.",
		"text": "Si passa quando ti avvicini a un difensore (la visuale si abbassa e il tempo rallenta) e negli ultimi 20 metri prima della porta. Allora <b>disegna dalla palla fino a un compagno</b>, chiunque sia: il passaggio si disegna sempre, toccare il compagno non basta. I puntini azzurri mostrano dove andrà davvero la palla.",
		"freeze": "opp-but-o",
	},
	{
		"id": "tiro", "title": "Tiro",
		"short": "Disegna una linea che finisce in porta.",
		"text": "Disegna una linea che <b>finisce dentro la porta</b>: più in alto la finisci, più alto va il tiro. <b>Curvala</b> per tirare a giro attorno al portiere.",
		"freeze": "opp-but-gk",
	},
	{
		"id": "corsa", "title": "Corsa e scatto",
		"text": "Col pallone, <b>disegna la strada</b> partendo dal tuo giocatore: lui la segue. Con tanta strada davanti <b>scatta</b> (ma si stanca prima). Se la linea finisce dentro la porta è un tiro.",
		"hint": ["Disegna una strada in avanti di una decina di metri.", "Ora disegna una strada che curva verso una fascia.", "Ora una strada lunga: il giocatore <b>scatta</b>."],
		"freeze": "opp",
	},
	{
		"id": "recupera", "title": "Recupera palla",
		"short": "Disegna una linea dal tuo giocatore fino all'avversario.",
		"text": "In difesa <b>disegna una linea dai tuoi giocatori</b> (tutti tranne il portiere): corrono lungo la strada che tracci. Mandali addosso all'avversario o sulla linea del passaggio per intercettarlo: ogni difensore prende la palla dentro un piccolo raggio, più largo se è bravo in difesa e più stretto se chi passa è bravo nei passaggi.",
		# l'avversario resta fermo col pallone (prima lo perdeva da solo passando a vuoto); i tuoi si muovono solo con la linea
		"freeze": "opp", "noAutoDef": true,
	},
	{
		"id": "scatto", "title": "Scatto", # era "Dribbling" (Luis 2026-11-20: nel duello il tasto è Scatto)
		"short": "Avvicinati al difensore e tocca Scatto.",
		"text": "Quando arrivi addosso a un difensore la visuale si abbassa e il tempo rallenta: puoi <b>passare</b> a un compagno libero oppure toccare <b>Scatto</b> in basso per bruciarlo in velocità e proseguire dritto.",
		"needs": "userSprint",
		"freeze": "opp-but-o",
	},
	{
		"id": "portiere", "title": "Portiere",
		"short": "Quando tira, linea dal portiere al punto della porta.",
		"text": "Quando l'avversario tira la visuale va dietro la tua porta e il tempo rallenta. <b>Tira una linea dal portiere al punto della porta</b> dove arriva la palla e alza il dito al momento giusto: troppo presto o troppo lontano e non ci arriva.",
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
	# difensore a una decina di metri: prima ci si avvicina, poi parte il duello (DUEL_R = 7 m)
	var o: R.Player = m.players[16]
	put(o, c.x + [0.0, 1.5, -1.5][kk], c.y + PASS_DEF_DIST)
	o.fx = 0.0
	o.fy = -1.0
	var mate: Array = [[9.0, 18.0], [-22.0, 10.0], [17.0, 6.0]][kk]
	put(m.players[9], mate[0], mate[1])
	return {"c": c, "o": o}


func _check_passaggio(e: Dictionary) -> bool:
	return e.type == "control" and (e.p as R.Player).team == 0 and e.p != st.c


func _setup_tiro(kk: int) -> Dictionary:
	var p: Array = [[5.0, 29.0], [-12.0, 33.0], [2.0, 22.0]][kk]
	var c := carrier(9, p[0], p[1])
	clear_opp()
	return {"c": c}


func _check_tiro(e: Dictionary) -> bool:
	return e.type == "kick" and (e.p as R.Player).team == 0 and e.kind == "shot"


func _setup_corsa(kk: int) -> Dictionary:
	var c := carrier(7, [0.0, -10.0, 8.0][kk], [-14.0, -6.0, -20.0][kk])
	clear_opp()
	return {"c": c, "x0": c.x, "y0": c.y, "k": kk}


func _poll_corsa() -> bool:
	var c: R.Player = st.c
	if m.ball.owner != c:
		return false
	if st.k == 0:
		return c.y - float(st.y0) > 12.0                       # avanti
	if st.k == 1:
		return absf(c.x - float(st.x0)) > 10.0                 # verso la fascia
	return c.sprint and C.hyp(c.x - float(st.x0), c.y - float(st.y0)) > 12.0   # scatto


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


func _setup_scatto(kk: int) -> Dictionary:
	var c := carrier(7, [0.0, -10.0, 10.0][kk], [-6.0, 0.0, -2.0][kk])
	clear_opp()
	var o: R.Player = m.players[16]
	put(o, c.x + [0.0, 1.0, -1.0][kk], c.y + 7.0)
	o.fx = 0.0
	o.fy = -1.0
	o.st.dif = minf(o.st.dif, DRIB_DEF_DIF)
	put(m.players[9], c.x + [12.0, 14.0, -14.0][kk], c.y + 4.0)
	return {"c": c, "o": o}


func _check_scatto(e: Dictionary) -> bool:
	return e.type == "dribble" and (e.p as R.Player).team == 0 and e.ok


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
	return (e.type == "dive" or e.type == "save") and (e.p as R.Player).team == 0 and (e.type == "save" or not m.autoGk[0])
