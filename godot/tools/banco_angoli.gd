# Banco dei calci d'angolo (non è un test: il runner lo ignora). Batte N angoli in partite "vere" a livello di motore,
# con le opzioni del gioco (portaAuto, testa, rifiniture, meteo e stili come tools/controllo_gameplay.gd) e la persona
# simulata tools/dito_motore.gd per la squadra 0 (tuffo del portiere, colpo di testa nel fermatempo, cross dell'angolo).
# Per ogni seme: un angolo della CPU contro di noi e uno nostro contro la CPU, ognuno in una partita nuova.
# Un angolo "finisce in gol" se chi lo batte segna entro FINESTRA_S secondi di gioco dall'assegnazione (come "gol da
# angolo" di controllo_gameplay: 12 s), senza un'altra ripresa in mezzo.
#   $G --headless --path godot -s res://tools/banco_angoli.gd -- --angoli=200 --forza=60 --seme=1
#   opzioni: --mia=60 · --senza-rifiniture · --solo=cpu|noi · --somma=f1,f2 (somma le righe "TOT|" di più processi)
extends SceneTree

const H := preload("res://tests/harness.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const Stili := preload("res://sim/stili.gd")
const Dito := preload("res://tools/dito_motore.gd")

const FRAME := 1.0 / 60.0
const TEMPO_K := 14.0
const FINESTRA_S := 12.0      # gol entro tanti secondi di gioco dall'assegnazione dell'angolo = gol da angolo
const FUORI_PORTA := 4.0      # portiere più lontano di così dalla propria linea = uscito (m)
const MAX_FRAMES := 60 * 60   # sicurezza: al massimo 60 s veri per angolo

var tot := {}


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if opz.has("somma"):
		for f: String in String(opz.somma).split(","):
			for riga: String in FileAccess.get_file_as_string(f).split("\n"):
				if riga.begins_with("TOT|"):
					var d: Dictionary = JSON.parse_string(riga.substr(4))
					for k: String in d:
						_add(k, float(d[k]))
		_stampa()
		quit(0)
		return
	var n := int(opz.get("angoli", "100"))
	var seme0 := int(opz.get("seme", "1"))
	var solo: String = opz.get("solo", "")
	for i in n:
		if solo != "noi":
			_angolo(seme0 + i, 1, opz)
		if solo != "cpu":
			_angolo(seme0 + i, 0, opz)
		H.disposeAll()
	print("TOT|" + JSON.stringify(tot))
	_stampa()
	quit(0)


func _add(k: String, v: float = 1.0) -> void:
	tot[k] = float(tot.get(k, 0.0)) + v


func _v(k: String) -> float:
	return float(tot.get(k, 0.0))


func _nuova_partita(sd: int, opz: Dictionary):
	var forza := float(opz.get("forza", "60"))
	var ta := H.mkTeam("A", float(opz.get("mia", "60")), sd * 7 + 1)
	var tb := H.mkTeam("B", forza, sd * 13 + 5)
	var st := Stili.perSquadra(sd, "Atletico" if sd % 3 == 0 else ("Real" if sd % 3 == 1 else "Fortitudo"), forza, "4-4-2")
	tb["stileAtt"] = st.get("att", "equilibrato")
	tb["stileDif"] = st.get("dif", "equilibrata")
	var meteo: String = ["sereno", "sereno", "nuvoloso", "pioggia", "neve"][sd % 5]
	return H.newMatch(sd, 9999.0, [true, false], ta, tb, meteo, {"portaAuto": true, "testa": true, "rifiniture": not opz.has("senza-rifiniture")})


# un angolo: atk = squadra che batte (1 = CPU contro di noi, 0 = noi contro la CPU)
func _angolo(sd: int, atk: int, opz: Dictionary) -> void:
	var m = _nuova_partita(sd, opz)
	var suf := "_c" if atk == 1 else "_u"
	var dfn := 1 - atk
	var dir: float = -1.0 if atk == 1 else 1.0
	var sx: float = 1.0 if (sd % 2) == 0 else -1.0
	m.phase = "play"
	m.setRestart("corner", atk, sx * C.HW, dir * C.HL)
	m.events.clear()
	var battitore = m.restart.taker
	var dito := Dito.new(sd * 31 + 7 + atk)
	var ts := 1.0
	var testa_reale := -1.0
	var t0: float = m.time
	var g = m.gk(dfn)
	var gy: float = dir * C.HL
	var primo := ""          # primo tocco dopo il cross
	var ultimo_testa := false
	var tocchi := 0
	var uscito := false
	var esito := "niente"
	_add("angoli" + suf)
	var frames := 0
	while frames < MAX_FRAMES and m.time - t0 < FINESTRA_S:
		frames += 1
		dito.passo(m, FRAME, FRAME * ts)
		# velocità del tempo come controllo_gameplay._tempo
		var hw = m.headWin
		if hw != null and hw.team == 0 and not hw.lost:
			if hw.aimed:
				testa_reale = -1.0
				ts = 1.0
			else:
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
		if ts > 0.0:
			m.step(FRAME * ts)
		if m.phase == "play" and absf(g.y - gy) > FUORI_PORTA:
			uscito = true
		var stop := false
		for e: Dictionary in m.events:
			var p = e.get("p")
			var tipo := String(e.type)
			if tipo == "kick" and p != null and p == battitore and tocchi == 0 and String(e.get("kind", "")) == "loft":
				continue # il cross stesso
			match tipo:
				"kick", "control", "save", "punch":
					tocchi += 1
					var chi := "att" if (p != null and p.team == atk) else ("por" if (p != null and p.pos == "P") else "dif")
					var k := String(e.get("kind", tipo))
					if tipo == "kick" and k == "header" and e.get("clear", false):
						k = "respinta_testa"
					if tipo == "save" and e.get("catch", false):
						k = "presa"
					if primo == "":
						primo = chi + ":" + k
						_add("primo" + suf + ":" + primo)
					ultimo_testa = tipo == "kick" and chi == "att" and k == "header"
					if tipo == "kick" and chi == "att" and k == "header":
						_add("teste_att" + suf)
				"aerial":
					_add("aereo" + suf + (":vince_att" if (p != null and p.team == atk) else ":vince_dif"))
				"goal":
					if int(e.team) == atk:
						esito = "gol"
						_add("gol" + suf)
						_add("gol" + suf + (":primo_tocco_testa" if (ultimo_testa and tocchi == 1) else (":testa" if ultimo_testa else ":seconda_palla")))
						if C.hyp(g.x, g.y - gy) > 3.0:
							_add("gol" + suf + ":porta_vuota")
					else:
						esito = "gol_contro"
					stop = true
				"restart":
					esito = "ripresa:" + String(e.kind)
					stop = true
		m.events.clear()
		if stop:
			break
	_add("esito" + suf + ":" + esito)
	if uscito:
		_add("uscite" + suf)


func _pct(a: float, b: float) -> String:
	return "-" if b <= 0.0 else "%.1f%%" % (100.0 * a / b)


func _elenco(pref: String) -> String:
	var parti: Array[String] = []
	var ks := tot.keys()
	ks.sort()
	for k: String in ks:
		if k.begins_with(pref):
			parti.append("%s %d" % [k.substr(pref.length()), int(_v(k))])
	return "{" + ", ".join(parti) + "}"


func _stampa() -> void:
	for suf in ["_c", "_u"]:
		var n := _v("angoli" + suf)
		if n <= 0.0:
			continue
		print("=== %s: %d angoli · gol %d (%s) %s · portiere uscito %d" % ["CPU contro di noi" if suf == "_c" else "noi contro la CPU", n,
			_v("gol" + suf), _pct(_v("gol" + suf), n), _elenco("gol" + suf + ":"), _v("uscite" + suf)])
		print("  primo tocco  %s" % _elenco("primo" + suf + ":"))
		print("  contesa      %s · teste degli attaccanti %d" % [_elenco("aereo" + suf + ":"), _v("teste_att" + suf)])
		print("  esito        %s" % _elenco("esito" + suf + ":"))
