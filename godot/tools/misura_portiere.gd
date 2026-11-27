# Misura del portiere (non è un test: il runner lo ignora). Luis 2026-11-26: "con i cross da lontano o tiri da lontano
# il portiere si butta a vuoto molto prima e la palla va in rete".
#   $G --headless --path godot -s res://tools/misura_portiere.gd -- [--partite=10] [--seme=1] [--manuale] [--righe]
#   $G --headless --path godot -s res://tools/misura_portiere.gd -- --scene [--semi=8]
# --partite: partite vere col dito finto (tools/dito_motore.gd) e le opzioni del gioco (parata, riprese, rifiniture...).
#   Per ogni tuffo: quanto prima dell'arrivo del pallone sul portiere è partito ("anticipo"), se quando il pallone
#   arriva il portiere è ancora in tuffo o già a terra ("a vuoto"), esito (parata, gol, altro), tipo del calcio.
# --scene: tiri da 25-45 m (rasoterra, alti, a giro) e cross lunghi in scene costruite a mano, contro il portiere della
#   CPU, il nostro automatico e il nostro manuale (fermatempo scaduto = fa da solo): parate, gol, tuffi a vuoto.
extends SceneTree

const H := preload("res://tests/harness.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const Dito := preload("res://tools/dito_motore.gd")
const FRAME := 1.0 / 60.0
const TEMPO_K := 14.0
const DIVE_T := 0.8   # durata del tuffo nel motore (motion.gd diveStep): dopo il portiere è a terra

var tot := {}
var righe := false
var debug := false


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	righe = opz.has("righe")
	debug = opz.has("debug")
	if opz.has("scene"):
		_scene(int(opz.get("semi", "8")))
	else:
		for i in int(opz.get("partite", "10")):
			_partita(int(opz.get("seme", "1")) + i, opz.has("manuale"))
			H.disposeAll()
		_stampa_partite()
	quit(0)


func _add(k: String, v: float = 1.0) -> void:
	tot[k] = float(tot.get(k, 0.0)) + v


# ------------------------------------------------------------ partite vere
func _partita(sd: int, manuale: bool) -> void:
	var ta := H.mkTeam("A", 60.0, sd * 7 + 1)
	var tb := H.mkTeam("B", 60.0, sd * 13 + 5, "4-4-2")
	var meteo: String = ["sereno", "sereno", "nuvoloso", "pioggia", "neve"][sd % 5]
	var m := H.newMatch(sd, 150.0, [true, false], ta, tb, meteo, {"portaAuto": true, "testa": true, "rifiniture": true,
		"falli": true, "contatti": true, "attacco": true, "parata": true, "riprese": true, "autoGk": [not manuale, false]})
	var dito := Dito.new(sd * 31 + 7)
	var ts := 1.0
	var testa_reale := -1.0
	var seguiti: Array = []
	var frames := 0
	while m.phase != "full" and frames < 60 * 60 * 40:
		frames += 1
		dito.passo(m, FRAME, FRAME * ts)
		var hw = m.headWin
		if hw != null and hw.team == 0 and not hw.lost and not hw.aimed:
			testa_reale = 0.0 if testa_reale < 0.0 else testa_reale + FRAME
			if testa_reale < Dito.TESTA_FERMO_S or dito.draw_mode == "head":
				ts = 0.0
			else:
				m.headExpire()
				testa_reale = -1.0
				ts = 1.0
		else:
			testa_reale = -1.0
			ts += (dito.velocita_voluta(m) - ts) * minf(1.0, FRAME * TEMPO_K)
		var sdt := FRAME * ts
		if sdt <= 0.0:
			continue
		m.step(sdt)
		if m.phase == "half":
			m.startSecondHalf()
		for e: Dictionary in m.events:
			if e.type == "dive":
				seguiti.append(_nuovo(m, e.p))
				if debug:
					var bs: R.Shot = m.ball.shot
					print("DIVE t %.2f team %d age %.2f tc %s same %s kick %s age %.2f ball (%.1f,%.1f,h%.1f) v(%.1f,%.1f,%.1f) gk (%.1f,%.1f) tx %.1f" % [m.time, e.p.team, m.paraAge,
						str(bs.tc) if bs != null else "-", str(bs == m.paraShot), m.ball.kick.type if m.ball.kick != null else "-", m.ball.kick.age if m.ball.kick != null else -1.0,
						m.ball.x, m.ball.y, m.ball.h, m.ball.vx, m.ball.vy, m.ball.vh, e.p.x, e.p.y, e.p.dive.tx])
		_segui(m, seguiti, sd)
		m.events.clear()
	_add("partite")
	_add("gol_u", m.score[0])
	_add("gol_c", m.score[1])
	_add("tiri_u", m.stats.shots[0])
	_add("tiri_c", m.stats.shots[1])
	_add("parate_u", m.stats.saves[0])
	_add("parate_c", m.stats.saves[1])


func _nuovo(m, g: R.Player) -> Dictionary:
	var b: R.Ball = m.ball
	var k: R.Kick = b.kick
	var dir: float = -1.0 if g.team else 1.0
	var own: float = -dir * C.HL
	var d: float = C.hyp(k.x0, k.y0 - own) if k != null else -1.0
	var s: R.Shot = b.shot
	return {"g": g, "t0": m.time, "lato": float(b.y - g.y) * dir, "tipo": (k.type if k != null else "-"),
		"dist": d, "left": m.paraLeft() if s != null else -1.0,
		"dx": absf(s.cx - g.x) if s != null else -1.0, "ch": s.ch if s != null else -1.0, "auto": g.dive != null and g.dive.auto,
		"chi": "cpu" if g.team == 1 else "nostro", "h0": b.h, "fatto": false}


func _segui(m, seguiti: Array, sd: int) -> void:
	var b: R.Ball = m.ball
	for c: Dictionary in seguiti:
		if c.fatto:
			continue
		var g: R.Player = c.g
		var dir: float = -1.0 if g.team else 1.0
		var esito := ""
		for e: Dictionary in m.events:
			if e.type == "save" and e.p == g:
				esito = "parata"
			elif e.type == "goal":
				esito = "gol"
		var passato: bool = (b.y - g.y) * dir <= 0.0 or absf(b.y) >= C.HL
		if esito == "" and (passato or m.phase != "play" or (b.owner != null)):
			esito = "altro"
		if esito == "" and m.time - c.t0 > 4.0:
			esito = "altro"
		if esito == "":
			continue
		c.fatto = true
		var ant: float = m.time - float(c.t0)
		var vuoto: bool = ant > DIVE_T and esito != "parata"
		var fascia: String = "lontano" if float(c.dist) >= 25.0 else "vicino"
		var key: String = "%s_%s" % [c.chi, fascia]
		_add(key + "_tuffi")
		_add(key + "_" + esito)
		_add(key + "_ant", ant)
		if vuoto:
			_add(key + "_vuoto")
			if esito == "gol":
				_add(key + "_vuoto_gol")
		if righe or vuoto:
			print("seme %d t %.1f %s tuffo %s, calcio %s da %.0f m, anticipo %.2f s (prev. %.2f), dx %.1f h %.1f -> %s%s" % [sd, float(c.t0),
				c.chi, "auto" if c.auto else "", c.tipo, float(c.dist), ant, float(c.left), float(c.dx), float(c.ch), esito, "  A VUOTO" if vuoto else ""])


func _stampa_partite() -> void:
	var n: float = maxf(1.0, float(tot.get("partite", 0.0)))
	print("partite %d  gol nostri %.2f, CPU %.2f a partita  tiri %.1f-%.1f  parate %.1f-%.1f" % [n, tot.get("gol_u", 0.0) / n,
		tot.get("gol_c", 0.0) / n, tot.get("tiri_u", 0.0) / n, tot.get("tiri_c", 0.0) / n, tot.get("parate_u", 0.0) / n, tot.get("parate_c", 0.0) / n])
	for chi: String in ["cpu", "nostro"]:
		for f: String in ["vicino", "lontano"]:
			var k := "%s_%s" % [chi, f]
			var nt: float = float(tot.get(k + "_tuffi", 0.0))
			if nt == 0.0:
				continue
			print("portiere %s, calcio %s: tuffi %d  parate %d  gol %d  altro %d  a vuoto %d (gol %d)  anticipo medio %.2f s" % [chi, f, nt,
				tot.get(k + "_parata", 0.0), tot.get(k + "_gol", 0.0), tot.get(k + "_altro", 0.0), tot.get(k + "_vuoto", 0.0),
				tot.get(k + "_vuoto_gol", 0.0), float(tot.get(k + "_ant", 0.0)) / nt])


# ------------------------------------------------------------ scene costruite a mano
## un tiro o un cross in una scena: chi = "cpu" (tira la persona, para il portiere della CPU) | "auto" | "manuale"
## (tira la CPU verso la nostra porta). spec del calcio. Ritorna {esito, ant, vuoto}
func _caso(sd: int, chi: String, kx: float, dist: float, spec: Dictionary, por: float, testa: bool) -> Dictionary:
	var m := H.scene(sd, [true, false])
	m.paraCtl = true
	m.rifiniture = true
	m.headCtl = true
	m.paraSeed = sd
	var att: int = 0 if chi == "cpu" else 1
	var def: int = 1 - att
	m.autoGk = [chi == "auto", false]
	var dir: float = 1.0 if att == 0 else -1.0 # verso dove attacca
	var goalY: float = dir * C.HL
	# tutti lontani tranne tiratore, portiere e (nei cross) un attaccante in area
	for p: R.Player in m.players:
		H.wake(p, (p.i % 11 - 5) * 5.0, -dir * 30.0 + (p.team - 0.5) * 2.0)
	var k: R.Player = m.team(att)[9]
	H.wake(k, kx, goalY - dir * dist)
	k.fx = 0.0
	k.fy = dir
	k.st.tir = 75.0
	k.st.pas = 75.0
	var g: R.Player = m.gk(def)
	H.wake(g, 0.0, goalY - dir * 0.6)
	g.st.por = por
	if testa:
		var a: R.Player = m.team(att)[10]
		H.wake(a, float(spec.tx), float(spec.ty))
		# due difensori sulla linea dell'area piccola: l'attaccante non è in fuorigioco
		H.wake(m.team(def)[2], -3.0, goalY - dir * 1.5)
		H.wake(m.team(def)[3], 3.0, goalY - dir * 1.5)
	H.give(m, k)
	var sp := spec.duplicate()
	sp["human"] = att == 0
	m.kick(k, sp)
	m.events.clear()
	var t0 := -1.0
	var esito := "fuori"
	var ant := -1.0
	for i in int(4.5 * 60.0):
		if chi == "manuale" and m.paraFor(def) and m.time > 0.0:
			m.paraExpire(def) # fermatempo scaduto senza linea: fa da solo
		m.step(FRAME)
		for e: Dictionary in m.events:
			if e.type == "dive" and e.p == g and t0 < 0.0:
				t0 = m.time
			if e.type == "save" and e.p == g:
				esito = "parata"
			elif e.type == "goal":
				esito = "gol"
			elif e.type == "aerial" and e.p == g:
				esito = "presa"
		m.events.clear()
		var b: R.Ball = m.ball
		if t0 >= 0.0 and ant < 0.0 and ((b.y - g.y) * -dir <= 0.0 or absf(b.y) >= C.HL):
			ant = m.time - t0
		if esito != "fuori" or m.phase != "play":
			break
		if b.owner != null:
			esito = "presa" if b.owner == g else ("controllo" if b.owner.team == att else "difesa")
			break
	var vuoto: bool = t0 >= 0.0 and esito != "parata" and ant > DIVE_T
	H.disposeAll()
	return {"esito": esito, "ant": ant, "vuoto": vuoto, "tuffo": t0 >= 0.0}


func _scene(semi: int) -> void:
	var casi := [
		["rasoterra 25", 25.0, {"type": "shot", "th": 0.0, "tratto": true, "curve": 0.0}],
		["rasoterra 35", 35.0, {"type": "shot", "th": 0.0, "tratto": true, "curve": 0.0}],
		["alto 30", 30.0, {"type": "shot", "th": 2.0}],
		["alto 40", 40.0, {"type": "shot", "th": 1.9}],
		["mezza 45", 45.0, {"type": "shot", "th": 1.0}],
		["giro 25", 25.0, {"type": "shot", "th": 1.6, "tratto": true, "curve": 4.0}],
		["giro 35", 35.0, {"type": "shot", "th": 1.8, "tratto": true, "curve": 6.0}],
		["giro 45", 45.0, {"type": "shot", "th": 1.5, "tratto": true, "curve": 8.0}],
	]
	var txs := [-3.2, -2.2, -1.0, 0.0, 1.0, 2.2, 3.2]
	for chi: String in ["cpu", "auto", "manuale"]:
		print("== portiere %s ==" % chi)
		for c: Array in casi:
			var st := {"parata": 0, "gol": 0, "altro": 0, "vuoto": 0, "vuoto_gol": 0, "n": 0, "ant": 0.0, "nt": 0}
			for sd in range(1, semi * txs.size() + 1):
				var tx: float = txs[sd % txs.size()]
				var dir: float = 1.0 if chi == "cpu" else -1.0
				var sp: Dictionary = (c[2] as Dictionary).duplicate()
				var kx: float = float((sd % 5) - 2) * 4.0
				sp["tx"] = tx
				sp["ty"] = dir * C.HL
				if sp.has("curve"):
					sp["curve"] = float(sp.curve) * (1.0 if sd % 2 == 0 else -1.0)
				var r := _caso(sd, chi, kx, float(c[1]), sp, 70.0, false)
				st.n += 1
				var es: String = r.esito if r.esito in ["parata", "gol"] else "altro"
				st[es] += 1
				if r.tuffo:
					st.nt += 1
					st.ant += maxf(0.0, float(r.ant))
					st.amax = maxf(float(st.get("amax", 0.0)), float(r.ant))
				if r.vuoto:
					st.vuoto += 1
					if r.esito == "gol":
						st.vuoto_gol += 1
			print("%-13s parate %2d  gol %2d  altro %2d  su %d | tuffi a vuoto %2d (gol %2d)  anticipo medio %.2f max %.2f s" % [c[0], st.parata, st.gol,
				st.altro, st.n, st.vuoto, st.vuoto_gol, st.ant / maxf(1.0, st.nt), float(st.get("amax", 0.0))])
		# cross lunghi: pallone alto da 30-40 m verso il secondo palo con un attaccante lì (tratto curvo = alto)
		var stc := {}
		for sd in range(1, semi * 4 + 1):
			var dir: float = 1.0 if chi == "cpu" else -1.0
			var lato: float = 1.0 if sd % 2 == 0 else -1.0
			var tx: float = -lato * (2.0 + float(sd % 3) * 1.5)
			var ty: float = dir * (C.HL - 4.0 - float(sd % 4) * 1.5)
			var sp := {"type": "auto", "tx": tx, "ty": ty, "tratto": true, "curve": lato * 5.0}
			var r := _caso(sd, chi, lato * 26.0, 18.0 + float(sd % 3) * 6.0, sp, 70.0, true)
			stc[r.esito] = int(stc.get(r.esito, 0)) + 1
			if r.tuffo:
				stc["tuffi"] = int(stc.get("tuffi", 0)) + 1
				stc["anticipo_max"] = maxf(float(stc.get("anticipo_max", 0.0)), float(r.ant))
			if r.vuoto:
				stc["VUOTO"] = int(stc.get("VUOTO", 0)) + 1
		print("cross lunghi   %s" % str(stc))
