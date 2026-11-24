# Controllo del gameplay (non è un test: il runner lo ignora). Gioca N partite "vere" a livello di motore: la squadra 0
# la comanda la persona simulata tools/dito_motore.gd (gesti veri: tratto dritto/curvo, di prima, Dribbling, Scatto,
# colpo di testa nel fermatempo, tuffo, linee di difesa), con le opzioni del gioco (testa, portaAuto, meteo, stili).
# Il tempo scorre come nel gioco (rallenty, fermatempo del colpo di testa): si misura anche il tempo VERO.
#   $G --headless --path godot -s res://tools/controllo_gameplay.gd -- --partite=20 --forza=60 --mia=60 --tempo=150
#   opzioni: --seme=1 (primo seme) · --stile=<attacco della squadra umana> · --stilecpu=att/dif|caso|base
#            --meteo=caso|sereno|pioggia|neve · --righe (una riga per partita) · --senza-falli (opzione "falli" spenta)
#            --senza-contatti (opzione "contatti" spenta: giocatori a 0,7 m, niente respiro dopo il recupero)
# Stampa una tabella per gruppi: risultati, tiri, meccaniche della persona, riprese, fluidità, possibili bug.
extends SceneTree

const H := preload("res://tests/harness.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const SimMatchScript := preload("res://sim/match.gd")
const Stili := preload("res://sim/stili.gd")
const Dito := preload("res://tools/dito_motore.gd")
const Regia := preload("res://scripts/partita/dribbling_regia.gd")

const TEMPO_K := 14.0
const RALLENTY_SOTTO := 0.6
const FRAME := 1.0 / 60.0
const FERMO_V := 0.8          # portatore umano "impallato": più lento di così (m/s) ...
const FERMO_T := 2.5          # ... per tanti secondi di gioco, senza avversari entro FERMO_LIBERO m
const FERMO_LIBERO := 4.0
const LIBERA_LUNGA := 4.0     # pallone di nessuno (in gioco, senza calcio in volo) per più di tanti secondi
const FUORI_M := 3.0          # giocatore oltre le linee di più di tanto = sospetto
const PALLA_ALTA := 12.0     # pallone più alto di così (m) = sospetto
const ORIGINE_S := 12.0       # gol entro tanti secondi da una ripresa = gol "da" quella ripresa

var tot := {}
var righe := false
var debug := false
var traccia_da := -1.0


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	righe = opz.has("righe")
	debug = opz.has("debug")
	traccia_da = float(opz.get("traccia", "-1"))
	if opz.has("somma"): # somma dei totali stampati da più processi (righe "TOT|{...}" nei file)
		for f: String in String(opz.somma).split(","):
			for riga: String in FileAccess.get_file_as_string(f).split("
"):
				if riga.begins_with("TOT|"):
					var d: Dictionary = JSON.parse_string(riga.substr(4))
					for k: String in d:
						if k == "libera_max":
							_max(k, float(d[k]))
						else:
							_add(k, float(d[k]))
		_stampa(int(_v("partite")), opz)
		quit(0)
		return
	var partite := int(opz.get("partite", "10"))
	var seme0 := int(opz.get("seme", "1"))
	for k in partite:
		_partita(seme0 + k, opz)
	print("TOT|" + JSON.stringify(tot))
	_stampa(partite, opz)
	H.disposeAll()
	quit(0)


func _add(k: String, v: float = 1.0) -> void:
	tot[k] = float(tot.get(k, 0.0)) + v


func _max(k: String, v: float) -> void:
	tot[k] = maxf(float(tot.get(k, 0.0)), v)


func _partita(sd: int, opz: Dictionary) -> void:
	var tempo := float(opz.get("tempo", "150"))
	var ta := H.mkTeam("A", float(opz.get("mia", "60")), sd * 7 + 1)
	var tb := H.mkTeam("B", float(opz.get("forza", "60")), sd * 13 + 5, String(opz.get("formazione", "4-4-2")))
	if opz.has("stile"):
		ta["stileAtt"] = opz.stile
	var sc: String = opz.get("stilecpu", "caso")
	if sc == "caso":
		var st := Stili.perSquadra(sd, "Atletico" if sd % 3 == 0 else ("Real" if sd % 3 == 1 else "Fortitudo"), float(opz.get("forza", "60")), "4-4-2")
		tb["stileAtt"] = st.get("att", "equilibrato")
		tb["stileDif"] = st.get("dif", "equilibrata")
	elif sc != "base":
		var parti := sc.split("/")
		tb["stileAtt"] = parti[0]
		if parti.size() > 1:
			tb["stileDif"] = parti[1]
	var meteo: String = opz.get("meteo", "caso")
	if meteo == "caso":
		meteo = ["sereno", "sereno", "nuvoloso", "pioggia", "neve"][sd % 5]
	var m := H.newMatch(sd, tempo, [true, false], ta, tb, meteo, {"portaAuto": true, "testa": true, "rifiniture": not opz.has("senza-rifiniture"),
		"falli": not opz.has("senza-falli"), "contatti": not opz.has("senza-contatti"), "attacco": not opz.has("senza-attacco")})
	var dito := Dito.new(sd * 31 + 7)
	var st := {"ts": 1.0, "testa_reale": -1.0, "last_restart": ["", ""], "last_restart_t": [-99.0, -99.0],
		"pass": null, "owner_prev": null, "fermo_t": 0.0, "libera_t": 0.0, "slow": false, "ultimo_calcio": {},
		"sub_dito": "", "duel_t": -1.0, "burst_t": -1.0, "drib_t": -1.0, "burst_p": null, "causa": "", "storia": [], "alta": false, "owner_step": null, "duel_o": null, "booked": false, "tiro": "",
		"poss": -1, "rec": null, "hk": null, "fase_prev": "play", "ceduto": "", "lancio": false}
	st.regia = Regia.new() # regia del dribbling (rallenty dal tasto alla fine del giochetto), come gioco.gd
	dito.on_kick = func(sub: String) -> void: st.sub_dito = sub
	var frames := 0
	var cap := 60 * 60 * 40
	var g0 := tot.duplicate()
	while m.phase != "full" and frames < cap:
		frames += 1
		var dt_g: float = FRAME * float(st.ts)
		dito.passo(m, FRAME, dt_g)
		st.dm = dito.draw_mode
		_tempo(m, dito, st)
		var sdt: float = FRAME * float(st.ts)
		if sdt > 0.0:
			m.step(sdt)
		st.regia.passo(m, 0, sdt, st.ts)
		for e: Dictionary in m.events:
			st.regia.evento(e, 0)
		if m.phase == "half":
			m.startSecondHalf()
		_conta(m, st, sdt)
		if traccia_da >= 0.0 and m.time >= traccia_da and m.time <= traccia_da + 0.8:
			print("TRACCIA t=%.3f dt %.4f ts %.3f palla (%.2f, %.2f, h %.2f) v (%.2f, %.2f, %.2f) owner %s kick %s ev %s" % [m.time, sdt, st.ts, m.ball.x, m.ball.y, m.ball.h,
				m.ball.vx, m.ball.vy, m.ball.vh, m.ball.owner.name if m.ball.owner != null else "-", m.ball.kick.type if m.ball.kick != null else "-",
				str(m.events.map(func(e: Dictionary) -> String: return String(e.type)))])
		m.events.clear()
	if frames >= cap:
		_add("bug_partita_non_finita")
	_add("partite")
	_add("reale_s", frames * FRAME)
	_add("gioco_s", m.time)
	var gf: int = m.score[0]
	var gs: int = m.score[1]
	_add("gf", gf)
	_add("gs", gs)
	_add("vinte" if gf > gs else ("pari" if gf == gs else "perse"))
	for t in 2:
		var suf := "_u" if t == 0 else "_c"
		_add("tiri" + suf, m.stats.shots[t])
		_add("inporta" + suf, m.stats.onT[t])
		_add("angoli" + suf, m.stats.corners[t])
		_add("falli" + suf, m.stats.fouls[t])
	var pt: float = maxf(0.001, m.stats.poss[0] + m.stats.poss[1])
	_add("poss_u", m.stats.poss[0] / pt)
	for k: String in dito.conti:
		_add("dito_" + k, dito.conti[k])
	if righe:
		print("seme %d %s  %d-%d  tiri %d-%d  reale %.0f s  rallenty %.0f%%" % [sd, meteo, gf, gs, m.stats.shots[0], m.stats.shots[1],
			frames * FRAME, 100.0 * (float(tot.get("slow_s", 0.0)) - float(g0.get("slow_s", 0.0))) / (frames * FRAME)])


## velocità del tempo come gioco.gd (_passi_motore + _velocita_testa)
func _tempo(m, dito, st: Dictionary) -> void:
	var hw = m.headWin
	if hw != null and hw.team == 0 and not hw.lost:
		if hw.aimed:
			st.testa_reale = -1.0
			st.ts = 1.0
			return
		st.testa_reale = 0.0 if st.testa_reale < 0.0 else st.testa_reale + FRAME
		if st.testa_reale < Dito.TESTA_FERMO_S or dito.draw_mode == "head":
			st.ts = 0.0
			_add("fermo_testa_s", FRAME)
			return
		m.headExpire()
		_add("testa_scaduta")
		st.testa_reale = -1.0
		st.ts = 1.0
		return
	st.testa_reale = -1.0
	var target: float = dito.velocita_voluta(m)
	var rv: float = st.regia.velocita()
	if rv >= 0.0 and dito.draw_mode == "" and not (m.diveWin(0) and not m.autoGk[0]):
		target = rv # dribbling della persona: rallenty della regia (gioco.velocita_voluta)
	st.ts += (target - st.ts) * minf(1.0, FRAME * st.regia.k_tempo(TEMPO_K))


func _causa(m, st: Dictionary) -> String:
	if st.ts <= 0.0:
		return "testa"
	if st.get("dm", "") != "":
		return "disegno_" + String(st.dm)
	if m.diveWin(0):
		return "parata"
	if st.regia.velocita() >= 0.0:
		return "dribbling"
	if m.duelFor(0):
		return "duello"
	if m.fleeFor(0):
		return "fuga"
	if m.inZone(0):
		return "area"
	return "uscita" # il tempo sta tornando normale


func _chi(p) -> String:
	return "_u" if p != null and p.team == 0 else "_c"


func _conta(m, st: Dictionary, sdt: float) -> void:
	var b: R.Ball = m.ball
	var slow: bool = st.ts < RALLENTY_SOTTO
	if slow:
		_add("slow_s", FRAME)
		var causa := _causa(m, st)
		_add("slowc_s:" + causa, FRAME)
		if not st.slow or causa != st.causa:
			_add("slowc_n:" + causa)
		st.causa = causa
		if not st.slow:
			_add("slow_n")
	else:
		st.causa = ""
	st.slow = slow
	# esito del dribbling riuscito della persona 3 s dopo (tenuto, compagno, perso, libero, fermo; con tiro nel frattempo)
	if st.get("drib_ok_p") != null and m.time - float(st.drib_ok_t) >= 3.0:
		var bo2: R.Player = b.owner
		var es2 := "tenuto" if bo2 == st.drib_ok_p else ("compagno" if (bo2 != null and bo2.team == 0) else ("perso" if (bo2 != null) else ("fermo" if m.phase != "play" else "libero")))
		_add("dribbling_dopo:" + ("tiro" if st.get("drib_tiro", false) else es2))
		st.drib_ok_p = null
	# esito dello Scatto 3 s dopo
	if st.burst_p != null and m.time - float(st.burst_t) >= 3.0:
		var bo: R.Player = b.owner
		var es := "tenuto" if bo == st.burst_p else ("compagno" if (bo != null and bo.team == 0) else ("perso" if (bo != null) else ("fermo" if m.phase != "play" else "libero")))
		_add("scatto_esito:" + es)
		st.burst_p = null
	if m.phase == "restart":
		_add("ripresa_s", sdt)
	for e: Dictionary in m.events:
		match String(e.type):
			"kick":
				var p: R.Player = e.p
				var k: String = e.kind
				var sub: String = k
				if st.ceduto != "" and p.team == 1:
					_add("testa_ceduta:" + String(st.ceduto) + ":" + ("tiro" if (m.ball.kick != null and m.ball.kick.type == "shot") else ("respinta" if e.get("clear", false) else ("sponda" if e.get("sponda", false) else k))))
				st.ceduto = ""
				if st.lancio:
					_add("lancio_esito:calcio_" + ("nostro" if p.team == 0 else "loro"))
					st.lancio = false
				if k == "loft" and p.team == 0 and m.phase == "play":
					st.lancio = true
					_add("lanci")
				if p.team == 0 and st.sub_dito != "":
					sub = st.sub_dito
					st.sub_dito = ""
				elif k == "loft":
					sub = "loft_curvo" if e.get("curvo", false) else "loft"
				if e.get("prima", false):
					sub = "prima"
					_add("prima_calci")
				st.ultimo_calcio = {"team": p.team, "sub": sub, "t": m.time}
				if st.tiro != "":
					_add("tiro_esito:" + String(st.tiro) + ":altro_tocco")
					st.tiro = ""
				if p.team == 0 and (k == "shot" or ((k == "header" or k == "volley") and not e.get("clear", false) and not e.get("sponda", false))):
					st.tiro = ("testa_dito" if e.get("guidato", false) else k) if sub == k else sub
					_add("tiro_fatto:" + String(st.tiro))
					if st.get("drib_ok_p") != null:
						st.drib_tiro = true
				if k == "ground" or k == "loft":
					st.pass = {"team": p.team, "sub": sub, "from": p}
					_add("pass" + _chi(p))
				if p.team == 0 and e.get("guidato", false):
					st.ultimo_calcio.sub = "testa_dito"
				if k == "header" and not e.get("clear", false):
					_add("testa_colpi" + _chi(p))
			"goal":
				if st.tiro != "":
					_add("tiro_esito:" + String(st.tiro) + ":gol")
					st.tiro = ""
				var t: int = e.team
				var suf := "_u" if t == 0 else "_c"
				var uc: Dictionary = st.ultimo_calcio
				var sub := String(uc.get("sub", "?")) if int(uc.get("team", -1)) == t else "autogol/deviato"
				_add("gol_tipo" + suf + ":" + sub)
				var lr: String = st.last_restart[t]
				if lr != "" and m.time - float(st.last_restart_t[t]) < ORIGINE_S:
					_add("gol_da" + suf + ":" + lr)
				st.last_restart = ["", ""]
			"restart":
				var kind: String = e.kind
				_add("ripresa:" + kind)
				st.last_restart[int(e.team)] = kind
				st.last_restart_t[int(e.team)] = m.time
				st.pass = null
			"out":
				if st.tiro != "":
					_add("tiro_esito:" + String(st.tiro) + ":fuori")
					st.tiro = ""
				_add("fuori:" + String(e.kind))
				var op: R.Player = st.owner_prev
				if op != null and op.team == 0 and String(e.kind) == "throw":
					_add("bug?_portatore_umano_fuori")
					if debug:
						print("DEBUG portatore fuori t=%.1f %s a (%.1f, %.1f) v (%.1f, %.1f) duello %s fuga %s scatto %.2f mossa %s · %s" % [m.time, op.name, op.x, op.y, op.vx, op.vy,
							m.duel != null, m.flee != null, op.burst, m.move[0] != null, " | ".join(st.storia.slice(-4))])
				if st.pass != null:
					_add("pass_fuori" + ("_u" if st.pass.team == 0 else "_c") + ":" + String(st.pass.sub))
					st.pass = null
			"foul":
				_add("fallo")
				_add("fallo" + _chi(e.by))
				_add("fallo_come:" + String(e.get("how", "?")) + _chi(e.by))
				if e.get("card", null) != null:
					_add("cartellino")
					_add("giallo" if e.card == "yellow" else "rosso")
				if e.get("pen", false):
					_add("rigore")
			"offside":
				_add("fuorigioco" + _chi(e.p))
			"save":
				if st.tiro != "":
					_add("tiro_esito:" + String(st.tiro) + ":parata")
					st.tiro = ""
				_add("parata" + _chi(e.p))
				if e.get("catch", false):
					_add("presa" + _chi(e.p))
			"post":
				if st.tiro != "":
					_add("tiro_esito:" + String(st.tiro) + ":palo")
					st.tiro = ""
				_add("palo")
			"dive":
				if (e.p as R.Player).team == 0:
					_add("tuffo_u")
			"duel_start":
				_add("duello")
				st.duel_t = m.time
				st.duel_o = e.o
				st.booked = false
			"duel_end":
				_add("duello_fine:" + String(e.reason))
			"dribble_book":
				_add("dribbling_prenotato")
				st.booked = true
			"dribble":
				if (e.p as R.Player).team == 0:
					_add("dribbling_u_ok" if e.ok else "dribbling_u_ko")
					if e.ok:
						st.drib_ok_p = e.p
						st.drib_ok_t = m.time
						st.drib_tiro = false
					if not e.ok:
						st.drib_t = m.time
				else:
					_add("dribbling_c_ok" if e.ok else "dribbling_c_ko")
			"flee_start":
				_add("fuga")
			"flee_end":
				_add("fuga_fine:" + String(e.reason))
			"burst":
				_add("scatto")
				st.burst_t = m.time
				st.burst_p = e.p
				var bp: R.Player = e.p
				var avanti: float = bp.fy
				_add("scatto_verso:" + ("avanti" if avanti > 0.5 else ("lato" if avanti > -0.3 else "indietro")))
				if absf(bp.x) > C.HW - 8.0:
					_add("scatto_vicino_linea")
			"block", "punch":
				if st.tiro != "":
					_add("tiro_esito:" + String(st.tiro) + ":respinto")
					st.tiro = ""
				if e.type == "punch":
					_add("pugno")
			"tackle":
				var on: R.Player = e.get("on", null)
				if on != null:
					_add("contrasto_su" + _chi(on))
					var tp: R.Player = e.p
					var dx := tp.x - on.x
					var dy := tp.y - on.y
					var dn := maxf(0.01, C.hyp(dx, dy) * maxf(0.01, C.hyp(on.fx, on.fy)))
					var dot := (on.fx * dx + on.fy * dy) / dn
					_add("contrasto_angolo:" + ("dietro" if dot < -0.35 else ("fianco" if dot < 0.1 else "fronte")))
			"head_win":
				if int(e.team) == 0:
					_add("testa_fermatempo")
					_add("testa_fermatempo:" + String(e.get("kind", "att")))
					if st.lancio:
						_add("lancio_esito:fermatempo_" + String(e.get("kind", "att")))
						st.lancio = false
			"aerial_pre": # salto conteso deciso prima (testa.gd)
				var pw: R.Player = e.p
				_add("testa_salto:" + String(e.kind) + (":vinto" if pw.team == 0 else ":perso"))
			"head_give":
				if int(e.team) == 0:
					st.ceduto = String(e.kind)
			"head_end":
				if int(e.team) == 0:
					_add("testa_fine:" + String(e.reason))
			"control":
				if st.lancio:
					_add("lancio_esito:" + ("controllato" if (e.p as R.Player).team == 0 else "perso"))
					st.lancio = false
				if st.tiro != "":
					_add("tiro_esito:" + String(st.tiro) + ":controllato")
					st.tiro = ""
			"aerial":
				_add("aereo")
			"advantage":
				_add("vantaggio")
			"advantage_back":
				_add("vantaggio_indietro")
	# passaggi: completati / persi al primo controllo
	var o: R.Player = b.owner
	if o != null and st.pass != null and m.phase == "play":
		var ps: Dictionary = st.pass
		var who := "_u" if ps.team == 0 else "_c"
		if o == ps.from:
			pass
		elif o.team == ps.team:
			_add("pass_ok" + who + ":" + String(ps.sub))
		else:
			_add("pass_perso" + who + ":" + String(ps.sub))
		st.pass = null
	# palla persa dal portatore umano che corre da solo (non nel duello/fuga): avversario prende il pallone
	var op2: R.Player = st.owner_step
	var calciato := false # calciato e ribattuto nello stesso passo: è un passaggio/tiro ribattuto, non una palla persa
	for e: Dictionary in m.events:
		if e.type == "kick" and e.p == op2:
			calciato = true
	if calciato and op2 != null and op2.team == 0 and o != op2 and (b.kick == null or b.kick.kicker != op2):
		_add("ribattuto_subito_u")
	if op2 != null and op2.team == 0 and o != op2 and m.phase == "play" and not calciato and (b.kick == null or b.kick.kicker != op2):
		# il portatore umano ha perso il pallone senza calciarlo (contrasto, dribbling fallito, pallone che gli scappa)
		var dove := "dopo_dribbling_ko" if (m.time - float(st.drib_t) < 1.5) else ("duello" if (m.time - float(st.duel_t) < 3.0) else ("dopo_scatto" if m.time - float(st.burst_t) < 3.0 else "corsa"))
		_add("persa_portatore_u:" + dove)
		if dove == "duello" and debug:
			print("DEBUG persa nel duello t=%.2f (duello da %.2f s) prenotato %s · ultimi eventi: %s · ora: %s · palla v %.1f h %.2f · stato %s stun %.2f" % [m.time, m.time - float(st.duel_t), st.booked, " | ".join(st.storia.slice(-4)), str(m.events.map(func(e: Dictionary) -> String: return String(e.type) + ":" + String(e.get("kind", "")) + ":" + ((e.p as R.Player).name if e.get("p", null) is R.Player else ""))), C.hyp(b.vx, b.vy), b.h, op2.state, op2.stun])
		if dove == "duello":
			_add("persa_duello:" + ("prenotato" if st.booked else "senza_tasto") + "/" + ("dal_difensore" if o == st.duel_o else ("altro" if o != null else "palla_libera")))
		if debug and dove == "corsa":
			print("DEBUG persa in corsa t=%.1f a (%.1f, %.1f) nuovo %s" % [m.time, op2.x, op2.y, o.name if o != null else "nessuno"])
	st.owner_step = o
	_contatti(m, st, sdt)
	if o != null and o.team == 0 and m.ctrl[0] == o and m.phase == "play":
		_add("porta_u_s", sdt)
		if not m.duelFor(0) and not m.fleeFor(0) and C.hyp(o.vx, o.vy) < FERMO_V and m.nearOpp(o.x, o.y, 0) > FERMO_LIBERO:
			st.fermo_t += sdt
			if st.fermo_t > FERMO_T and st.fermo_t - sdt <= FERMO_T:
				_add("portatore_impallato")
		else:
			st.fermo_t = 0.0
	else:
		st.fermo_t = 0.0
	if o != null:
		st.owner_prev = o
	elif m.phase != "play":
		st.owner_prev = null
	# pallone di nessuno a lungo
	if m.phase == "play" and o == null and b.kick == null:
		st.libera_t += sdt
		if st.libera_t > LIBERA_LUNGA and st.libera_t - sdt <= LIBERA_LUNGA:
			_add("bug?_pallone_libero_4s")
			if debug:
				var near := 99.0
				for p: R.Player in m.players:
					if not p.off:
						near = minf(near, C.hyp(p.x - b.x, p.y - b.y))
				print("DEBUG libero t=%.1f palla (%.1f, %.1f, h %.2f) v %.1f · più vicino %.1f m · noP %s noT %.2f dbl %s headWin %s" % [m.time, b.x, b.y, b.h,
					C.hyp(b.vx, b.vy), near, b.noP.name if b.noP != null else "-", b.noT, b.dbl.name if b.dbl != null else "-", m.headWin != null])
	else:
		_max("libera_max", st.libera_t)
		st.libera_t = 0.0
	# controlli
	for e: Dictionary in m.events:
		st.storia.append("%.2f %s %s %s" % [m.time, e.type, String(e.get("kind", e.get("reason", ""))), (e.p as R.Player).name if e.get("p", null) is R.Player else ""])
	while st.storia.size() > 12:
		st.storia.pop_front()
	if b.h > PALLA_ALTA and not st.alta:
		st.alta = true
		_add("bug?_pallone_oltre_12m")
		if debug:
			print("DEBUG pallone alto t=%.2f h %.1f vh %.1f pos (%.1f, %.1f) fase %s owner %s · ultimi eventi: %s" % [m.time, b.h, b.vh, b.x, b.y, m.phase,
				b.owner.name if b.owner != null else "-", " | ".join(st.storia)])
	elif b.h < 3.0:
		st.alta = false
	if is_nan(b.x) or is_nan(b.y) or is_nan(b.h):
		_add("bug_nan")
	if m.phase == "play":
		for p: R.Player in m.players:
			if not p.off and (absf(p.x) > C.HW + FUORI_M or absf(p.y) > C.HL + FUORI_M):
				_add("bug?_giocatore_fuori_campo_passi")
				break


## compenetrazioni e recuperi palla della persona (Luis 2026-11-24: "i giocatori si compenetrano", "quando recupero
## palla me la rubano subito")
func _contatti(m, st: Dictionary, sdt: float) -> void:
	var b: R.Ball = m.ball
	var o: R.Player = b.owner
	var gioco: bool = m.phase == "play" and st.fase_prev == "play"
	st.fase_prev = m.phase
	if m.phase != "play":
		st.poss = -1 # dopo una ripresa il possesso riparte da capo: non è un recupero
	if gioco and sdt > 0.0:
		var dmin := 99.0
		var dmin_avv := 99.0
		var n: int = m.players.size()
		for i in n:
			var a: R.Player = m.players[i]
			if a.off:
				continue
			for j in range(i + 1, n):
				var c: R.Player = m.players[j]
				if c.off:
					continue
				var d := C.hyp(a.x - c.x, a.y - c.y)
				dmin = minf(dmin, d)
				if a.team != c.team:
					dmin_avv = minf(dmin_avv, d)
		_add("ct_s", sdt)
		_add("ct_dmin_sum", dmin * sdt)
		_add("ct_dminavv_sum", dmin_avv * sdt)
		if dmin < 0.6:
			_add("ct_sotto06_s", sdt)
		if dmin_avv < 0.6:
			_add("ct_avv_sotto06_s", sdt)
		if dmin < 0.85:
			_add("ct_sotto085_s", sdt)
		if dmin_avv < 0.85:
			_add("ct_avv_sotto085_s", sdt)
		if dmin < 0.45:
			_add("ct_sotto045_s", sdt)
		if o != null:
			var dp: float = m.nearOpp(o.x, o.y, o.team)
			_add("ct_portatore_sum", dp * sdt)
			_add("ct_portatore_s", sdt)
			if dp < 0.6:
				_add("ct_portatore_sotto06_s", sdt)
	# passaggi della persona intercettati entro 1 s
	for e: Dictionary in m.events:
		if e.type == "kick" and (e.p as R.Player).team == 0 and (e.kind == "ground" or e.kind == "loft"):
			var kp: R.Player = e.p
			var dk: float = m.nearOpp(kp.x, kp.y, 0)
			st.hk = {"t": m.time, "d": dk, "x": m.ball.x, "y": m.ball.y, "kind": e.kind, "sh": (m.ball.kick.shield.size() if m.ball.kick != null and "shield" in m.ball.kick else -1)}
			_add("rk_pass_u")
			_add("rk_pass_u_vicino:" + _fascia(dk))
	if st.hk != null:
		var hk: Dictionary = st.hk
		var tolto := (o != null and o.team == 1)
		for e: Dictionary in m.events:
			if (e.type == "block" or e.type == "tackle") and e.get("p", null) is R.Player and (e.p as R.Player).team == 1:
				tolto = true
		if tolto and m.time - float(hk.t) <= 1.0:
			if debug and float(hk.d) < 1.0:
				var chi: R.Player = o
				for e: Dictionary in m.events:
					if (e.type == "block" or e.type == "tackle") and e.get("p", null) is R.Player:
						chi = e.p
				print("DEBUG passaggio vicino intercettato t=%.2f dopo %.2f s · %s · avversario più vicino al calcio %.2f m · scudo %d · pallone a %.1f m dal calcio, h %.2f · da %s (%s)" % [m.time, m.time - float(hk.t), hk.kind, hk.d, hk.sh,
					C.hyp(m.ball.x - float(hk.x), m.ball.y - float(hk.y)), m.ball.h, chi.name if chi != null else "-", str(m.events.map(func(e: Dictionary) -> String: return String(e.type)))])
			_add("rk_pass_u_int1s")
			_add("rk_pass_u_int1s_vicino:" + _fascia(float(hk.d)))
			st.hk = null
		elif m.time - float(hk.t) > 1.0 or (o != null and o.team == 0):
			st.hk = null
	# recuperi palla della persona
	if o != null and gioco:
		if o.team == 0 and int(st.poss) == 1:
			var dr: float = m.nearOpp(o.x, o.y, 0)
			st.rec = {"t": m.time, "p": o, "d0": dr, "dmin": dr, "rall": false, "vicino": _fascia(dr)}
			_add("rec_n")
			_add("rec_vicino:" + _fascia(dr))
			_add("rec_d0_sum", dr)
		st.poss = o.team
	if st.rec != null:
		var rc: Dictionary = st.rec
		var age: float = m.time - float(rc.t)
		for e: Dictionary in m.events:
			if e.type == "kick" and (e.p as R.Player).team == 0:
				rc.passato = true
			if e.type == "dribble" and (e.p as R.Player).team == 0:
				rc.drib = true
		if o != null and o.team == 0:
			rc.dmin = minf(float(rc.dmin), m.nearOpp(o.x, o.y, 0))
		if age <= 1.0 and (m.duelFor(0) or m.fleeFor(0)) and not rc.rall:
			rc.rall = true
			_add("rec_rallenty1s")
		if o != null and o.team == 1:
			if age <= 2.0:
				var come := "palla_libera"
				if rc.get("passato", false):
					come = "passaggio"
				for e: Dictionary in m.events:
					if e.type == "tackle":
						come = "contrasto"
				if rc.get("drib", false):
					come = "dribbling"
				if debug:
					print("DEBUG recupero perso dopo %.2f s (%s) · avversario al recupero %.2f m · rallenty %s · ultimi: %s" % [age, come, float(rc.d0), rc.rall, " | ".join(st.storia.slice(-5))])
				_add("rec_persa2s_dopo:" + ("a<0.5" if age < 0.5 else ("b<1" if age < 1.0 else "c<2")))
				_add("rec_persa2s")
				_add("rec_persa2s:" + come)
				_add("rec_persa2s_vicino:" + String(rc.vicino))
				if rc.rall:
					_add("rec_persa2s_dopo_rallenty")
			_add("rec_dmin_sum", float(rc.dmin))
			_add("rec_chiusi")
			st.rec = null
		elif age > 2.0 or m.phase != "play":
			_add("rec_dmin_sum", float(rc.dmin))
			_add("rec_chiusi")
			st.rec = null


func _fascia(d: float) -> String:
	return "a<1" if d < 1.0 else ("b1-2" if d < 2.0 else ("c2-4" if d < 4.0 else "d>4"))


func _v(k: String) -> float:
	return float(tot.get(k, 0.0))


func _pct(a: float, b: float) -> String:
	return "%.0f%%" % (100.0 * a / b) if b > 0.0 else "-"


func _stampa(n: int, opz: Dictionary) -> void:
	var N := float(n)
	print("=== controllo gameplay: %d partite, umano %s contro CPU %s, tempo %s s, stile %s, stile CPU %s, meteo %s ===" % [n,
		opz.get("mia", "60"), opz.get("forza", "60"), opz.get("tempo", "150"), opz.get("stile", "equilibrato"), opz.get("stilecpu", "caso"), opz.get("meteo", "caso")])
	print("RISULTATI  V/N/P %d/%d/%d · gol a partita %.2f-%.2f · tiri %.1f-%.1f · in porta %.1f-%.1f · possesso umano %.0f%%" % [
		_v("vinte"), _v("pari"), _v("perse"), _v("gf") / N, _v("gs") / N, _v("tiri_u") / N, _v("tiri_c") / N, _v("inporta_u") / N, _v("inporta_c") / N, 100.0 * _v("poss_u") / N])
	print("PARATE     umano %.1f (prese %s) · CPU %.1f (prese %s) · pali %.2f · tuffi del dito %.1f" % [_v("parata_u") / N, _pct(_v("presa_u"), _v("parata_u")),
		_v("parata_c") / N, _pct(_v("presa_c"), _v("parata_c")), _v("palo") / N, _v("tuffo_u") / N])
	print("RIPRESE    a partita: rimesse %.1f · angoli %.1f-%.1f · rinvii %.1f · punizioni %.1f · rigori (fallo in area) %.2f · falli %.1f · cartellini %.2f · fuorigioco %.2f/%.2f · vantaggi %.2f" % [
		_v("ripresa:throw") / N, _v("angoli_u") / N, _v("angoli_c") / N, _v("ripresa:goalkick") / N, _v("ripresa:freekick") / N, _v("rigore") / N,
		_v("fallo") / N, _v("cartellino") / N, _v("fuorigioco_u") / N, _v("fuorigioco_c") / N, _v("vantaggio") / N])
	print("FALLI      a partita %.2f (umano %.2f, CPU %.2f) · per 90' %.1f · gialli %.2f · rossi %.3f · rigori %.3f · vantaggi %.2f (tornati indietro %d) · come %s · gol da punizione %d, da rigore %d" % [
		_v("fallo") / N, _v("fallo_u") / N, _v("fallo_c") / N, _v("fallo") / N * 5400.0 / (2.0 * float(opz.get("tempo", "150"))), _v("giallo") / N, _v("rosso") / N, _v("ripresa:penalty") / N,
		_v("vantaggio") / N, _v("vantaggio_indietro"), _elenco("fallo_come:"), _v("gol_da_u:freekick") + _v("gol_da_c:freekick"), _v("gol_da_u:penalty") + _v("gol_da_c:penalty")])
	print("CONTRASTI  angolo dei contrasti riusciti %s" % _elenco("contrasto_angolo:"))
	print("ANGOLI     gol da angolo umano %d su %d angoli (%s) · CPU %d su %d (%s)" % [_v("gol_da_u:corner"), _v("angoli_u"), _pct(_v("gol_da_u:corner"), _v("angoli_u")),
		_v("gol_da_c:corner"), _v("angoli_c"), _pct(_v("gol_da_c:corner"), _v("angoli_c"))])
	print("FLUIDITA'  tempo vero %.0f s a partita (gioco %.0f s) · rallenty %s del tempo vero, %.1f volte a partita, %.1f s veri l'uno · fermatempo testa %.1f s · gioco fermo (riprese) %s del tempo di gioco · pallone libero più lungo %.1f s" % [
		_v("reale_s") / N, _v("gioco_s") / N, _pct(_v("slow_s"), _v("reale_s")), _v("slow_n") / N, _v("slow_s") / maxf(1.0, _v("slow_n")), _v("fermo_testa_s") / N,
		_pct(_v("ripresa_s"), _v("gioco_s")), _v("libera_max")])
	print("RALLENTY per causa (s veri a partita / volte a partita): %s" % _cause(N))
	print("--- meccaniche della persona (a partita; ok = primo tocco di un compagno, perso = di un avversario, fuori = palla fuori)")
	for sub in ["pass_raso", "pass_alto_dritto", "pass_curvo", "cross"]:
		var ok := _v("pass_ok_u:" + sub)
		var ko := _v("pass_perso_u:" + sub)
		var fu := _v("pass_fuori_u:" + sub)
		print("  %-17s fatti %5.1f · ok %s · persi %s · fuori %s" % [sub, _v("dito_" + sub) / N, _pct(ok, ok + ko + fu), _pct(ko, ok + ko + fu), _pct(fu, ok + ko + fu)])
	var cpu_ok := 0.0
	var cpu_ko := 0.0
	for k: String in tot:
		if k.begins_with("pass_ok_c:"):
			cpu_ok += _v(k)
		elif k.begins_with("pass_perso_c:") or k.begins_with("pass_fuori_c:"):
			cpu_ko += _v(k)
	print("  (CPU: passaggi riusciti %s su %.1f a partita)" % [_pct(cpu_ok, cpu_ok + cpu_ko), (cpu_ok + cpu_ko) / N])
	for sub in ["tiro_raso", "tiro_giro"]:
		print("  %-17s fatti %5.1f · gol %d (%s)" % [sub, _v("dito_" + sub) / N, _v("gol_tipo_u:" + sub), _pct(_v("gol_tipo_u:" + sub), _v("dito_" + sub))])
	print("  di prima          preparati %.1f · calciati %.1f · gol %d" % [_v("dito_prima") / N, _v("prima_calci") / N, _v("gol_tipo_u:prima")])
	print("  testa contesa     fermatempo in difesa %.1f · sui passaggi alti %.1f · salti decisi prima %s · dopo il salto ceduto l'avversario %s" % [
		_v("testa_fermatempo:def") / N, _v("testa_fermatempo:pass") / N, _elenco("testa_salto:"), _elenco("testa_ceduta:")])
	print("  lanci alti nostri (non tiri): %.1f a partita · esito %s" % [_v("lanci") / N, _elenco("lancio_esito:")])
	print("  colpo di testa    fermatempo %.1f · linee %.1f · saltati apposta %.1f · scaduti %.1f · gol di testa col dito %d · esiti %s" % [
		_v("testa_fermatempo") / N, _v("dito_testa") / N, _v("dito_testa_saltata") / N, _v("testa_scaduta") / N, _v("gol_tipo_u:testa_dito"), _elenco("testa_fine:")])
	print("  duello            aperti %.1f · Dribbling %.1f (riusciti %s) · esiti %s" % [_v("duello") / N, _v("dito_dribbling") / N,
		_pct(_v("dribbling_u_ok"), _v("dribbling_u_ok") + _v("dribbling_u_ko")), _elenco("duello_fine:")])
	print("  dopo il dribbling riuscito, 3 s dopo: %s" % _elenco("dribbling_dopo:"))
	print("  perse nel duello  %s · calci ribattuti subito (stesso passo) %.1f" % [_elenco("persa_duello:"), _v("ribattuto_subito_u") / N])
	print("  fuga              aperte %.1f · Scatto %.1f · esiti %s" % [_v("fuga") / N, _v("scatto") / N, _elenco("fuga_fine:")])
	print("  dopo lo Scatto    verso %s · vicino alla linea laterale %d · 3 s dopo %s" % [_elenco("scatto_verso:"), _v("scatto_vicino_linea"), _elenco("scatto_esito:")])
	print("  portatore auto    col pallone %.0f s di gioco a partita · palle perse %s · impallato %.1f · portato fuori %.2f" % [
		_v("porta_u_s") / N, _elenco("persa_portatore_u:"), _v("portatore_impallato") / N, _v("bug?_portatore_umano_fuori") / N])
	print("  difesa            linee %.1f · contrasti subiti umano %.1f / CPU %.1f · comandi rifiutati %.1f" % [_v("dito_difesa") / N, _v("contrasto_su_u") / N, _v("contrasto_su_c") / N, _v("dito_comando_rifiutato") / N])
	print("  dribbling CPU     riusciti %s su %.1f" % [_pct(_v("dribbling_c_ok"), _v("dribbling_c_ok") + _v("dribbling_c_ko")), (_v("dribbling_c_ok") + _v("dribbling_c_ko")) / N])
	print("TIRI DELLA PERSONA per tipo (esito): %s" % _elenco("tiro_esito:"))
	print("GOL UMANO per tipo: %s" % _elenco("gol_tipo_u:"))
	print("GOL CPU per tipo:   %s" % _elenco("gol_tipo_c:"))
	print("GOL da ripresa:     umano %s · CPU %s" % [_elenco("gol_da_u:"), _elenco("gol_da_c:")])
	print("BUG?               %s" % _elenco("bug"))
	print("CONTATTI   distanza minima media tra due giocatori %.2f m (avversari %.2f) · tempo con due a meno di 0,6 m %s (avversari %s, sotto 0,45 m %s) · a meno di 0,85 m %s (avversari %s) · portatore: avversario più vicino in media %.2f m, a meno di 0,6 m %s del tempo" % [
		_v("ct_dmin_sum") / maxf(0.001, _v("ct_s")), _v("ct_dminavv_sum") / maxf(0.001, _v("ct_s")), _pct(_v("ct_sotto06_s"), _v("ct_s")), _pct(_v("ct_avv_sotto06_s"), _v("ct_s")),
		_pct(_v("ct_sotto045_s"), _v("ct_s")), _pct(_v("ct_sotto085_s"), _v("ct_s")), _pct(_v("ct_avv_sotto085_s"), _v("ct_s")), _v("ct_portatore_sum") / maxf(0.001, _v("ct_portatore_s")), _pct(_v("ct_portatore_sotto06_s"), _v("ct_portatore_s"))])
	print("RECUPERI   della persona %.1f a partita · avversario più vicino al recupero %.2f m %s · più vicino nei 2 s %.2f m · rallenty duello/fuga entro 1 s %s · persi entro 2 s %s (%.1f a partita) %s · per distanza %s" % [
		_v("rec_n") / N, _v("rec_d0_sum") / maxf(1.0, _v("rec_n")), _elenco("rec_vicino:"), _v("rec_dmin_sum") / maxf(1.0, _v("rec_chiusi")), _pct(_v("rec_rallenty1s"), _v("rec_n")),
		_pct(_v("rec_persa2s"), _v("rec_n")), _v("rec_persa2s") / N, _elenco("rec_persa2s:"), _elenco("rec_persa2s_vicino:")])
	print("RECUPERI   persi entro 2 s: quanto dopo %s · dopo il rallenty %d" % [_elenco("rec_persa2s_dopo:"), _v("rec_persa2s_dopo_rallenty")])
	print("PASSAGGI P passaggi della persona %.1f a partita · intercettati entro 1 s %s (%.1f a partita) · per avversario vicino al calcio: fatti %s, intercettati %s" % [
		_v("rk_pass_u") / N, _pct(_v("rk_pass_u_int1s"), _v("rk_pass_u")), _v("rk_pass_u_int1s") / N, _elenco("rk_pass_u_vicino:"), _elenco("rk_pass_u_int1s_vicino:")])


func _cause(N: float) -> String:
	var parti := PackedStringArray()
	for k: String in tot:
		if k.begins_with("slowc_s:"):
			var c := k.substr(8)
			parti.append("%s %.0f s / %.1f" % [c, _v(k) / N, _v("slowc_n:" + c) / N])
	parti.sort()
	return ", ".join(parti)


func _elenco(pref: String) -> String:
	var parti := PackedStringArray()
	var chiavi := tot.keys()
	chiavi.sort()
	for k: String in chiavi:
		if k.begins_with(pref):
			parti.append("%s %d" % [k.substr(pref.length()), int(_v(k))])
	return "{" + ", ".join(parti) + "}"
