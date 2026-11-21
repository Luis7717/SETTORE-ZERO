# Equivalenza col motore JS: stessi numeri casuali, stesse funzioni matematiche, stesse partite bit per bit.
# Le tracce di riferimento si rigenerano dal JS con `node test/export-trace.mjs` (cartella fixtures/).
extends "test_base.gd"

const SimRngScript := preload("../sim/rng.gd")
const F := preload("../sim/fmath.gd")
const FIX := "res://tests/fixtures/"
const STATE := {"play": 1, "prep": 2, "slide": 3, "down": 4, "dive": 5}
const FNV := 16777619

var _buf := PackedByteArray()


func _init() -> void:
	_buf.resize(8)


static func readJson(name: String) -> Variant:
	var f := FileAccess.open(FIX + name, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func bitsHex(x: float) -> String:
	_buf.encode_double(0, x)
	return _buf.hex_encode()


func fromHex(h: String) -> float:
	return h.hex_decode().decode_double(0)


# impronta FNV-1a dei bit del double (stessa di stepHash in test/export-trace.mjs)
func mix(h: int, x: float) -> int:
	_buf.encode_double(0, x)
	h = SimRngScript.imul(h ^ _buf.decode_u32(0), FNV)
	return SimRngScript.imul(h ^ _buf.decode_u32(4), FNV)


func stepHash(m: SimMatchScript) -> int:
	var b := m.ball
	var h: int = 2166136261
	for v: float in [b.x, b.y, b.h, b.vx, b.vy, b.vh]:
		h = mix(h, v)
	for p: R.Player in m.players:
		for v: float in [p.x, p.y, p.vx, p.vy, p.fx, p.fy, p.energy]:
			h = mix(h, v)
		h = SimRngScript.imul(h ^ int(STATE[p.state]), FNV)
	return h


func test_rng_stessi_bit_del_js() -> bool:
	var ref: Dictionary = readJson("rng.json")
	if not check(ref != null, "manca fixtures/rng.json"):
		return done()
	var n := 0
	for k: String in ref:
		var r := SimRngScript.new(int(k))
		for i in ref[k].size():
			var v := r.next()
			if not eq(bitsHex(v), ref[k][i], "seme %s, numero %d" % [k, i]):
				return done()
			n += 1
	note("%d numeri casuali identici al JS (7 semi, anche negativi e 2^32-1)" % n)
	return done()


func test_hypot_come_v8() -> bool:
	var ref: Dictionary = readJson("math.json")
	var bad := 0
	for row: Array in ref.hypot:
		if bitsHex(C.hyp(fromHex(row[0]), fromHex(row[1]))) != row[2]:
			bad += 1
	eq(bad, 0, "Math.hypot diversi su %d" % ref.hypot.size())
	return done()


# sin, cos e atan2 del motore (sim/fmath.gd, fdlibm) devono dare gli stessi bit di V8; per confronto si misura
# quante volte differiscono quelli di Godot (libreria C del sistema), che il motore quindi non usa.
func test_trigonometria_come_v8() -> bool:
	var ref: Dictionary = readJson("math.json")
	for fn: String in ["sin", "cos", "atan2"]:
		var bad := 0
		var badGodot := 0
		var maxUlp := 0
		for row: Array in ref[fn]:
			var mine: float
			var godot: float
			var want: float
			if fn == "atan2":
				var yy := fromHex(row[0])
				var xx := fromHex(row[1])
				mine = F.atan2_(yy, xx)
				godot = atan2(yy, xx)
				want = fromHex(row[2])
			else:
				var a := fromHex(row[0])
				mine = F.sin_(a) if fn == "sin" else F.cos_(a)
				godot = sin(a) if fn == "sin" else cos(a)
				want = fromHex(row[1])
			if bitsHex(mine) != bitsHex(want):
				bad += 1
			if godot != want:
				badGodot += 1
				_buf.encode_double(0, godot)
				var gi := _buf.decode_s64(0)
				_buf.encode_double(0, want)
				maxUlp = maxi(maxUlp, absi(gi - _buf.decode_s64(0)))
		eq(bad, 0, "%s del motore diversi da V8 su %d" % [fn, ref[fn].size()])
		note("%s: motore identico a V8 su %d valori; %s di Godot diverso in %d casi (al massimo %d ulp)" % [fn, ref[fn].size(), fn, badGodot, maxUlp])
	return done()


static func ints(a: Array) -> Array:
	return a.map(func(v: Variant) -> int: return int(v))


func _trace(idx: int) -> bool:
	var ref: Dictionary = readJson("trace_%d.json" % idx)
	if not check(ref != null, "manca fixtures/trace_%d.json" % idx):
		return done()
	var sc: Dictionary = ref.scenario
	var hashes: String = ref.hashes
	var evRef: Array = ref.events
	var frames: Array = ref.frames
	var frameEvery: int = int(ref.frameEvery)
	var st := {"n": 0, "firstDiff": -1, "events": [], "maxDev": 0.0, "devAt": -1, "fi": 0}
	var onStep := func(m: SimMatchScript) -> void:
		var n: int = st.n
		if st.firstDiff < 0:
			var h := "%08x" % stepHash(m)
			if n * 8 + 8 > hashes.length() or h != hashes.substr(n * 8, 8):
				st.firstDiff = n
		for e: Dictionary in m.events:
			var p: Variant = e.get("p")
			st.events.append([n, e.type, e.get("kind", ""), (p.team * 11 + p.i) if p != null else -1])
		if n % frameEvery == 0 and st.fi < frames.size() and int(frames[st.fi][0]) == n:
			var fr: Array = frames[st.fi]
			var dev: float = maxf(absf(m.ball.x - fr[1]), absf(m.ball.y - fr[2]))
			for k in 22:
				dev = maxf(dev, maxf(absf(m.players[k].x - fr[4 + k * 2]), absf(m.players[k].y - fr[5 + k * 2])))
			if dev > st.maxDev:
				st.maxDev = dev
				st.devAt = n
			st.fi += 1
		st.n = n + 1
	var opt := {"seed": int(sc.seed), "mode": sc.mode, "my": float(sc.my), "op": float(sc.op), "halfLen": float(sc.halfLen),
		"fA": sc.get("fA", "4-4-2"), "fB": sc.get("fB", "4-4-2")}
	var res := H.playMatch(opt, onStep)
	var m: SimMatchScript = res.m
	var firstEv := -1
	var evs: Array = st.events
	for i in mini(evs.size(), evRef.size()):
		var a: Array = evs[i]
		var b: Array = evRef[i]
		if int(a[0]) != int(b[0]) or a[1] != b[1] or a[2] != b[2] or int(a[3]) != int(b[3]):
			firstEv = i
			break
	note("scenario %s: punteggio %s (JS %s), passi %d (JS %d), eventi %d (JS %d)" % [JSON.stringify(sc), ints(m.score), ints(ref.score), res.steps, int(ref.steps), evs.size(), evRef.size()])
	if st.firstDiff >= 0:
		note("stato diverso dal JS dal passo %d (%.1f s di partita); scarto massimo %.6f m al passo %d" % [st.firstDiff, st.firstDiff / 60.0, st.maxDev, st.devAt])
	else:
		note("stato identico al JS, bit per bit, a ogni passo (%d passi)" % res.steps)
	eq(st.firstDiff, -1, "primo passo con stato diverso dal JS")
	eq(firstEv, -1, "primo evento diverso dal JS")
	eq(evs.size(), evRef.size(), "numero di eventi")
	eq(int(res.steps), int(ref.steps), "numero di passi")
	eq(str(ints(m.score)), str(ints(ref.score)), "punteggio")
	for k: String in ["shots", "onT", "fouls", "corners", "saves", "headers", "volleys"]:
		eq(str(ints(m.stats[k])), str(ints(ref.stats[k])), "statistica " + k)
	for tm in 2:
		near(m.stats.poss[tm], float(ref.stats.poss[tm]), 1e-9, "possesso squadra %d" % tm)
	m.dispose()
	return done()


func test_traccia_0() -> bool:
	return _trace(0)


func test_traccia_1() -> bool:
	return _trace(1)


func test_traccia_2() -> bool:
	return _trace(2)


func test_traccia_3() -> bool:
	return _trace(3)


func test_traccia_4() -> bool:
	return _trace(4)


func test_traccia_5() -> bool:
	return _trace(5)


func test_traccia_6() -> bool:
	return _trace(6)


# Fuga e tasto Scatto (userSprint → burst): le partite col bot non li usano mai, quindi hanno scene loro
# (fixtures/sprint.json: avversario dietro, alla pari, davanti "per linee", squadra 1): stessa apertura di fuga o
# duello, stesso esito del tocco e stessa impronta dello stato a ogni passo dopo
func test_scatto_come_js() -> bool:
	var ref: Variant = readJson("sprint.json")
	if not check(ref != null, "manca fixtures/sprint.json"):
		return done()
	var nSteps: int = int(C.round_(float(ref.sec) * 60.0))
	var scatti := 0
	for r: Dictionary in ref.scenes:
		var sc: Dictionary = r.scene
		var tag := "scena %d" % int(sc.seed)
		var tm := int(sc.team)
		var dir := -1.0 if tm == 1 else 1.0
		var m := H.scene(int(sc.seed), [false, true] if tm == 1 else [true, false])
		var p: R.Player = m.players[tm * 11 + 9]
		var o: R.Player = m.players[(1 - tm) * 11 + 3]
		H.wake(p, float(sc.px), float(sc.py))
		p.fx = 0
		p.fy = dir
		p.vy = float(sc.vy0) * dir
		H.give(m, p)
		m.updateCtrl(tm)
		H.wake(o, float(sc.px) + float(sc.ox), float(sc.py) + float(sc.oy) * dir)
		o.fx = 0
		o.fy = dir
		if sc.run:
			m.userMove(tm, p.x, p.y + 10.0 * dir, true)
		else:
			m.userMove(tm, p.x, p.y, true)
		m.step(DT)
		m.events.clear()
		eq(m.fleeFor(tm), r.flee, tag + ": fuga")
		eq(m.duelFor(tm), r.duel, tag + ": duello")
		eq(m.userSprint(tm), r.tapped, tag + ": tasto")
		eq(p.burst, float(r.burst), tag + ": burst")
		eq(str(m.events.map(func(x: Dictionary) -> String: return x.type)), str(r.tapEvents), tag + ": eventi del tocco")
		m.events.clear()
		var hashes: String = r.hashes
		var firstDiff := -1
		var evs: Array = []
		for n in nSteps:
			m.step(DT)
			if firstDiff < 0 and "%08x" % stepHash(m) != hashes.substr(n * 8, 8):
				firstDiff = n
			for x: Dictionary in m.events:
				var xp: Variant = x.get("p")
				evs.append([n, x.type, (xp.team * 11 + xp.i) if xp != null else -1])
			m.events.clear()
		eq(firstDiff, -1, tag + ": stato diverso dal JS dal passo")
		eq(str(evs), str((r.events as Array).map(func(a: Array) -> Array: return [int(a[0]), a[1], int(a[2])])), tag + ": eventi")
		if r.tapped == true:
			scatti += 1
		m.dispose()
	note("%d scene di fuga (%d con lo Scatto) identiche al JS per %d passi" % [ref.scenes.size(), scatti, nSteps])
	return done()


# Dribbling prenotato (userDribble → dribBookStep → dribble col lato scelto): le partite col bot non lo usano, quindi ha
# scene sue (fixtures/dribble.json: difensore lontano, vicino, di lato, vicino alla linea laterale, un altro avversario,
# squadra 1): stesso esito del tocco, stessi eventi col lato e stessa impronta dello stato a ogni passo
func test_dribbling_prenotato_come_js() -> bool:
	var ref: Variant = readJson("dribble.json")
	if not check(ref != null, "manca fixtures/dribble.json"):
		return done()
	var nSteps: int = int(C.round_(float(ref.sec) * 60.0))
	for r: Dictionary in ref.scenes:
		var sc: Dictionary = r.scene
		var tag := "scena %d" % int(sc.seed)
		var tm := int(sc.team)
		var dir := -1.0 if tm == 1 else 1.0
		var m := H.scene(int(sc.seed), [false, true] if tm == 1 else [true, false])
		var p: R.Player = m.players[tm * 11 + 9]
		var o: R.Player = m.players[(1 - tm) * 11 + 3]
		H.wake(p, float(sc.px), 0.0)
		p.fx = 0
		p.fy = dir
		p.st.dri = float(sc.get("dri", 80))
		H.give(m, p)
		m.updateCtrl(tm)
		H.wake(o, float(sc.px) + float(sc.ox), float(sc.d) * dir)
		o.fx = 0
		o.fy = -dir
		o.vy = -float(sc.ovy) * dir
		o.st.dif = float(sc.get("dif", 50))
		if sc.has("extra"):
			H.wake(m.players[(1 - tm) * 11 + 5], float(sc.px) + float(sc.extra[0]), float(sc.extra[1]) * dir)
		m.userMove(tm, p.x, p.y, true)
		m.step(DT)
		m.events.clear()
		eq(m.duelFor(tm), r.duel, tag + ": duello")
		eq(m.userDribble(tm), r.tapped, tag + ": tasto")
		eq(m.dribBooked(tm), r.booked, tag + ": prenotato")
		eq(str(m.events.map(func(x: Dictionary) -> Array: return [x.type, int(x.get("side", 0))])),
			str((r.tapEvents as Array).map(func(a: Array) -> Array: return [a[0], int(a[1])])), tag + ": eventi del tocco")
		m.events.clear()
		var hashes: String = r.hashes
		var firstDiff := -1
		var evs: Array = []
		for n in nSteps:
			m.step(DT)
			if firstDiff < 0 and "%08x" % stepHash(m) != hashes.substr(n * 8, 8):
				firstDiff = n
			for x: Dictionary in m.events:
				var xp: Variant = x.get("p")
				evs.append([n, x.type, (xp.team * 11 + xp.i) if xp != null else -1, int(x.get("side", 0))])
			m.events.clear()
		eq(firstDiff, -1, tag + ": stato diverso dal JS dal passo")
		eq(str(evs), str((r.events as Array).map(func(a: Array) -> Array: return [int(a[0]), a[1], int(a[2]), int(a[3])])), tag + ": eventi")
		m.dispose()
	note("%d scene di dribbling prenotato identiche al JS per %d passi" % [ref.scenes.size(), nSteps])
	return done()


# Niente doppio tocco sui calci da fermo (b.dbl, dblBan): fixtures/restart.json, calci battuti corti col battitore che
# insegue il pallone (anche oltre DBL_FREE) o a campo pieno con l'IA: stessa impronta dello stato e stessi eventi
func test_calci_da_fermo_come_js() -> bool:
	var ref: Variant = readJson("restart.json")
	if not check(ref != null, "manca fixtures/restart.json"):
		return done()
	var nSteps: int = int(C.round_(float(ref.sec) * 60.0))
	for r: Dictionary in ref.scenes:
		var sc: Dictionary = r.scene
		var tag := "scena %d (%s)" % [int(sc.seed), sc.type]
		var solo: bool = sc.solo
		var m := H.scene(int(sc.seed), [true, false] if solo else [false, false])
		m.setRestart(sc.type, int(sc.team), float(sc.x), float(sc.y))
		var p: R.Player = m.restart.taker
		var b := m.ball
		if solo:
			for k in m.players.size():
				if m.players[k] != p:
					H.park(m.players[k], k)
		m.restart.t = 1.0
		m.kick(p, {"type": "ground", "tx": b.x + float(sc.dx), "ty": b.y + float(sc.dy)})
		eq(p.team * 11 + p.i, int(r.taker), tag + ": battitore")
		eq(b.dbl == p, r.dbl, tag + ": battitore segnato")
		m.events.clear()
		var hashes: String = r.hashes
		var firstDiff := -1
		var evs: Array = []
		for n in nSteps:
			if solo:
				m.ctrl[0] = p
				m.switchCd[0] = 9.0
				m.userMove(0, b.x, b.y, true)
			m.step(DT)
			if firstDiff < 0 and "%08x" % stepHash(m) != hashes.substr(n * 8, 8):
				firstDiff = n
			for x: Dictionary in m.events:
				var xp: Variant = x.get("p")
				evs.append([n, x.type, x.get("kind", ""), (xp.team * 11 + xp.i) if xp != null else -1])
			m.events.clear()
		eq(firstDiff, -1, tag + ": stato diverso dal JS dal passo")
		eq(str(evs), str((r.events as Array).map(func(a: Array) -> Array: return [int(a[0]), a[1], a[2], int(a[3])])), tag + ": eventi")
		m.dispose()
	note("%d scene di calci da fermo identiche al JS per %d passi" % [ref.scenes.size(), nSteps])
	return done()
