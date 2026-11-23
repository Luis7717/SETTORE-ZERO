# Misura delle parate per fasce (non è un test: il runner lo ignora).
# Uso:  godot --headless --path godot -s res://tests/parate_fasce.gd [-- N [modo]]
# Tiri della squadra 1 verso la porta della squadra umana (difesa parcheggiata), N semi per casella. Per ogni modo del
# portiere ("auto" = portiere automatico della persona, "giusto" = manuale che sceglie il punto vero, "bersaglio" =
# manuale che sceglie il centro del bersaglio) stampa la percentuale di parate per fascia di precisione del tiro
# (distanza del punto d'arrivo dal portiere: centrale < 1,5 m, medio 1,5-2,8 m, angolo > 2,8 m) e per livello del
# tiratore (tir) e del portiere (por).
extends SceneTree

const H := preload("harness.gd")
const C := preload("../sim/core.gd")
const R := preload("../sim/records.gd")
const SimMatchScript := preload("../sim/match.gd")
const DT := 1.0 / 60.0
const FASCE := ["centrale", "medio", "angolo"]
const TIR := [50.0, 75.0, 92.0]
const POR := [50.0, 70.0, 90.0]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 12
	var modi: Array = [args[1]] if args.size() > 1 else ["auto", "giusto", "bersaglio"]
	for modo: String in modi:
		print("== portiere %s ==" % modo)
		for por: float in POR:
			var riga := PackedStringArray()
			for tir: float in TIR:
				var st := misura(modo, tir, por, n)
				var celle := PackedStringArray()
				for f: String in FASCE:
					celle.append("%s %d%% (%d)" % [f, roundi(100.0 * st[f][0] / maxf(1.0, st[f][1])), st[f][1]])
				riga.append("tir %d: %s" % [tir, ", ".join(celle)])
			print("por %d | %s" % [por, " | ".join(riga)])
	quit(0)


static func misura(modo: String, tir: float, por: float, n: int) -> Dictionary:
	var st := {"centrale": [0, 0], "medio": [0, 0], "angolo": [0, 0]}
	var txs := [-3.3, -2.4, -1.0, 0.0, 1.0, 2.4, 3.3]
	var ths := [0.3, 1.2, 2.1]
	for sd in range(1, n * txs.size() + 1):
		var tx: float = txs[sd % txs.size()]
		var th: float = ths[(sd / txs.size()) % ths.size()]
		var dist: float = 14.0 + float(sd % 4) * 4.0
		var m := tiro(sd, (sd % 5 - 2) * 2.0, dist, tx, th, tir, por, modo == "auto")
		var s: R.Shot = m.ball.shot
		if s == null or not s.on:
			H.disposeAll()
			continue
		var g := m.gk(0)
		if modo == "giusto":
			m.userDive(0, s.cx - g.x, s.ch)
		elif modo == "bersaglio":
			m.userDive(0, float(s.area.x) - g.x, float(s.area.h))
		var d: float = absf(s.cx - g.x)
		var f: String = "centrale" if d < 1.5 else ("medio" if d < 2.8 else "angolo")
		st[f][1] += 1
		if esito(m) == "parata":
			st[f][0] += 1
	return st


static func tiro(sd: int, sx: float, dist: float, tx: float, th: float, tir: float, por: float, auto: bool) -> SimMatchScript:
	var m := H.scene(sd, [true, false])
	m.paraCtl = true
	m.paraSeed = sd
	m.autoGk = [auto, false]
	var k: R.Player = m.team(1)[9]
	H.wake(k, sx, -C.HL + dist)
	k.fx = 0.0
	k.fy = -1.0
	k.st.tir = tir
	var g := m.gk(0)
	H.wake(g, 0.0, -C.HL + 0.6)
	g.st.por = por
	H.give(m, k)
	m.kick(k, {"type": "shot", "tx": tx, "ty": -C.HL, "th": th})
	m.events.clear()
	return m


static func esito(m: SimMatchScript) -> String:
	for i in 180:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "save" and e.p.team == 0:
				return "parata"
			if e.type == "goal":
				return "gol"
		m.events.clear()
		if m.phase != "play":
			return "fuori"
	return "fuori"
