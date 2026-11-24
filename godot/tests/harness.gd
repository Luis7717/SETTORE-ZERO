# Strumenti comuni per i test del motore (porting di test/lib/harness.mjs e test/lib/scene.mjs):
# squadre finte, "umano simulato", partite complete e scene costruite a mano.
extends RefCounted

const SimMatchScript := preload("../sim/match.gd")
const SimRngScript := preload("../sim/rng.gd")
const C := preload("../sim/core.gd")
const R := preload("../sim/records.gd")

const DT := 1.0 / 60.0


static func skillOf(rating: float) -> float:
	return maxf(0.1, minf(0.95, (rating - 42.0) / 48.0))


# Squadra con statistiche intorno a `rating` (stesso schema di balance.mjs). skill < 0 = ricavata dal rating.
static func mkTeam(name: String, rating: float, seed_value: int, formation: String = "4-4-2", skill: float = -1.0) -> Dictionary:
	var r := SimRngScript.new(seed_value)
	var F: Array = C.FORMATIONS[formation]
	var players: Array = []
	for i in F.size():
		var s: Array = F[i]
		var p := {"name": name + str(i), "pos": s[0]}
		for key: String in ["vel", "tir", "pas", "dri", "dif", "fis"]:
			p[key] = int(C.round_(rating + (r.next() - 0.5) * 10.0))
		p["por"] = int(C.round_(rating + (r.next() - 0.5) * 10.0)) + 4 if s[0] == "P" else 20
		players.append(p)
	return {"name": name, "formation": formation, "skill": skill if skill >= 0.0 else skillOf(rating), "players": players}


# partite create dai test: alla fine il runner le chiude con disposeAll() (riferimenti circolari tra giocatori)
static var live: Array = []


## meteo (facoltativo, "" = nessuno): campo meteo delle opzioni della partita ("pioggia", "neve", ...)
## I test partono col portatore umano "come prima" (portaAuto false, così le partite restano uguali al JS);
## extra = altre opzioni della partita, es. {"portaAuto": true} per provare il portatore che si muove da solo.
static func newMatch(seed_value: int, halfLen: float, human: Array, teamA: Dictionary, teamB: Dictionary, meteo := "", extra := {}) -> SimMatchScript:
	var o := {"seed": seed_value, "halfLen": halfLen, "human": human, "teams": [teamA, teamB], "portaAuto": false}
	if meteo != "":
		o["meteo"] = meteo
	o.merge(extra, true)
	var m := SimMatchScript.new(o)
	live.append(m)
	return m


static func disposeAll() -> void:
	for m: SimMatchScript in live:
		m.dispose()
	live.clear()


# "Giocatore medio" che comanda la squadra 0 con gli stessi comandi del telefono (makeBot in harness.mjs):
# con la palla usa le scelte dell'IA, in difesa pressa col solo giocatore controllato,
# in porta si tuffa con un ritardo e un errore casuali.
class Bot:
	extends RefCounted
	var r: SimRngScript
	var press: bool
	var diveAt: float = -1.0
	var headAt: float = -1.0

	func _init(seed_value: int, press_: bool = true) -> void:
		r = SimRngScript.new(seed_value)
		press = press_

	func stepBot(m: SimMatchScript) -> void:
		var c: R.Player = m.ctrl[0]
		var b := m.ball
		if c != null:
			if b.owner == c:
				if m.phase == "restart":
					if m.restart.t > 1.2:
						m.human[0] = false
						m.aiRestart()
						m.human[0] = true
				else:
					m.dtT = 1.0 / 60.0
					m.human[0] = false
					m.carrierAI(c)
					m.human[0] = true
					if b.owner == c:
						m.userMove(0, c.tx, c.ty, true)
			elif b.owner != null and b.owner.team == 1:
				if press and r.next() < 0.9:
					m.userMove(0, b.x + b.owner.vx * 0.25, b.y + b.owner.vy * 0.25, true)
			elif b.owner == null and m.manualDef(0) and press:
				m.userMove(0, b.x + b.vx * 0.3, b.y + b.vy * 0.3, true)
		# colpo di testa controllato (solo con m.headCtl): dopo un attimo linea verso la porta, lontano dal portiere
		if m.headFor(0):
			if headAt < 0.0:
				headAt = m.time + r.next() * 0.3
			elif m.time >= headAt:
				if m.headCanShoot():
					var g0 := m.gk(1)
					var side: float = -1.0 if g0.x > 0.0 else 1.0
					m.userHeader(0, {"goal": true, "tx": side * (C.GW / 2.0 - 0.6 - r.next() * 1.2), "th": 0.3 + r.next() * 1.4})
				else: # salto conteso senza tiro (difesa, passaggio lontano dalla porta): di testa al compagno più avanti
					var q: Array = m.headMateTarget()
					m.userHeader(0, {"goal": false, "tx": q[0], "ty": q[1]})
				headAt = -1.0
		else:
			headAt = -1.0
		if m.diveWin(0):
			if diveAt < 0.0:
				diveAt = m.time + 0.12 + r.next() * 0.16
			if m.time >= diveAt:
				var s := b.shot
				var g := m.gk(0)
				var dxm: float = (s.cx - g.x) * (0.8 + r.next() * 0.6)
				dxm += (-C.sign_(s.cx - g.x) * 3.0) if r.next() < 0.12 else 0.0
				m.userDive(0, dxm, s.ch + (r.next() - 0.5) * 0.8)
				diveAt = -1.0
		else:
			diveAt = -1.0


# Gioca una partita intera a passi di 1/60 s (playMatch in harness.mjs).
# opt: seed, my, op, mode ('bot' = umano simulato contro IA, 'ai' = IA contro IA), halfLen, fA, fB, maxSteps,
# tired ([[squadra, indice, energia iniziale], ...], facoltativo), extra (altre opzioni della partita, facoltativo).
# onStep(m) viene chiamato a ogni passo prima che gli eventi vengano svuotati. Ritorna {m, steps}.
static func playMatch(opt: Dictionary, onStep: Callable = Callable()) -> Dictionary:
	var sd: int = opt.get("seed", 1)
	var mode: String = opt.get("mode", "bot")
	var ta := mkTeam("A", opt.get("my", 60.0), sd * 7 + 1, opt.get("fA", "4-4-2"))
	var tb := mkTeam("B", opt.get("op", 60.0), sd * 13 + 5, opt.get("fB", "4-4-2"))
	for t: Array in opt.get("tired", []): # [squadra, indice, energia iniziale]: giocatori che partono stanchi
		([ta, tb][int(t[0])].players[int(t[1])] as Dictionary)["energy0"] = float(t[2])
	var m := newMatch(sd, opt.get("halfLen", 150.0), [true, false] if mode == "bot" else [false, false], ta, tb, String(opt.get("meteo", "")), opt.get("extra", {}))
	m.headCtl = bool(opt.get("testa", false))
	var bot: Bot = Bot.new(sd + 9) if mode == "bot" else null
	var maxSteps: int = opt.get("maxSteps", 60 * 60 * 30)
	var steps := 0
	while m.phase != "full" and steps < maxSteps:
		m.step(DT)
		steps += 1
		if m.phase == "half":
			m.startSecondHalf()
		if bot != null:
			bot.stepBot(m)
		if onStep.is_valid():
			onStep.call(m)
		m.events.clear()
	return {"m": m, "steps": steps}


# ------------------------------------------------------------ scene (test/lib/scene.mjs)
# partita in gioco, tutti i giocatori "parcheggiati" lontano e fermi, tranne quelli rimessi in campo con wake
static func scene(sd: int = 1, human: Array = [true, false], my: float = 60.0, op: float = 60.0) -> SimMatchScript:
	var m := newMatch(sd, 9999.0, human, mkTeam("A", my, sd * 7 + 1), mkTeam("B", op, sd * 13 + 5))
	m.phase = "play"
	m.restart = null
	var b := m.ball
	b.owner = null
	b.kick = null
	b.shot = null
	b.x = 0.0
	b.y = 0.0
	b.h = 0.0
	b.vx = 0.0
	b.vy = 0.0
	b.vh = 0.0
	for k in m.players.size():
		park(m.players[k], k)
	m.events.clear()
	return m


static func park(p: R.Player, k: int) -> void:
	p.x = (1.0 if k % 2 else -1.0) * 31.0
	p.y = -45.0 + k * 4.3
	p.vx = 0.0
	p.vy = 0.0
	p.tx = p.x
	p.ty = p.y
	p.state = "play"
	p.stun = 999.0
	p.contact = 0.0


static func wake(p: R.Player, x: float, y: float) -> void:
	p.x = x
	p.y = y
	p.vx = 0.0
	p.vy = 0.0
	p.tx = x
	p.ty = y
	p.stun = 0.0
	p.state = "play"
	p.contact = 0.0
	p.tackleCd = 0.0
	p.protect = 0.0


static func give(m: SimMatchScript, p: R.Player) -> void:
	var b := m.ball
	b.owner = p
	b.last = p
	b.x = p.x + p.fx * 0.6
	b.y = p.y + p.fy * 0.6
	p.protect = 0.0


# passi da 1/60 s; onStep(m) prima di ogni passo; ritorna gli eventi visti
static func run(m: SimMatchScript, sec: float, onStep: Callable = Callable()) -> Array:
	var evs: Array = []
	for i in int(C.round_(sec * 60.0)):
		if onStep.is_valid():
			onStep.call(m)
		m.step(DT)
		evs.append_array(m.events)
		m.events.clear()
	return evs


# tocco del tasto Dribbling: prenota il dribbling e fa passi da 1/60 s finché non parte davvero (evento 'dribble',
# al massimo 2 s); ritorna gli eventi visti dal tocco in poi (vuoto se il tasto non ha fatto nulla). = tapDribble di scene.mjs
static func tapDribble(m: SimMatchScript, tm: int = 0) -> Array:
	if not m.userDribble(tm):
		return []
	var evs: Array = m.events.duplicate()
	m.events.clear()
	var i := 0
	while i < 120 and not evs.any(func(e: Dictionary) -> bool: return e.type == "dribble"):
		m.step(DT)
		evs.append_array(m.events)
		m.events.clear()
		i += 1
	return evs
