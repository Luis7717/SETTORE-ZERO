# Laboratorio dei calci d'angolo: batte N angoli a seme fisso e conta come finiscono.
# Lo usano tests/angoli.gd (stampa i numeri) e tests/test_angoli.gd (soglie fisse).
# Squadra 0 = umana (portiere comandato come in partita: IA del portiere + tuffo del "giocatore medio" di harness.gd,
# oppure portiere automatico), squadra 1 = CPU. cpu_batte = true: angolo della CPU contro di noi; false: il contrario.
extends RefCounted

const H := preload("harness.gd")
const C := preload("../sim/core.gd")
const R := preload("../sim/records.gd")

const DT := 1.0 / 60.0
const MAX_SEC := 7.0      # un angolo si considera finito dopo questo tempo di gioco dal cross (s)
const FAR_OUT := 4.0      # portiere più lontano di così dalla propria linea di porta = è uscito (m)
const EMPTY_NET := 3.0    # gol col portiere più lontano di così dal centro della porta = porta vuota (m)


# opt: n, seed, cpu_batte, auto_gk, my, op, rifiniture (difesa degli angoli di sim/angoli.gd). Ritorna un dizionario di conteggi.
static func misura(opt: Dictionary) -> Dictionary:
	var n: int = opt.get("n", 100)
	var sd0: int = opt.get("seed", 1)
	var cpu: bool = opt.get("cpu_batte", true)
	var out := {"angoli": 0, "gol": 0, "uscite": 0, "prese": 0, "respinte": 0, "parate": 0, "teste": 0, "teste_porta": 0,
		"respinte_testa": 0, "porta_vuota": 0, "uscite_mancate": 0, "gol_testa": 0}
	for i in n:
		var r := uno(sd0 + i * 31, cpu, bool(opt.get("auto_gk", false)), float(opt.get("my", 60.0)), float(opt.get("op", 60.0)), bool(opt.get("rifiniture", false)))
		for k: String in r:
			out[k] = int(out.get(k, 0)) + int(r[k])
		out.angoli += 1
	H.disposeAll()
	return out


# un solo angolo: ritorna i conteggi (0/1) di quell'angolo
static func uno(sd: int, cpu: bool, autoGk: bool, my: float, op: float, rif: bool = false) -> Dictionary:
	var m := H.newMatch(sd, 9999.0, [true, false], H.mkTeam("A", my, sd * 7 + 1), H.mkTeam("B", op, sd * 13 + 5), "", {"rifiniture": rif})
	m.autoGk = [autoGk, false]
	m.phase = "play"
	var atk: int = 1 if cpu else 0
	var dfn: int = 1 - atk
	var dir: float = -1.0 if atk else 1.0
	var sx: float = 1.0 if (sd % 2) == 0 else -1.0
	m.setRestart("corner", atk, sx * C.HW, dir * C.HL)
	m.events.clear()
	var bot := H.Bot.new(sd + 9, false)
	var g: R.Player = m.gk(dfn)
	var gy: float = dir * C.HL # linea di porta di chi difende
	var res := {"gol": 0, "uscite": 0, "prese": 0, "respinte": 0, "parate": 0, "teste": 0, "teste_porta": 0,
		"respinte_testa": 0, "porta_vuota": 0, "uscite_mancate": 0, "gol_testa": 0}
	var lastHead := false # l'ultimo tocco prima del gol è un colpo di testa di un attaccante
	var crossed := false
	var tPlay := 0.0
	var wentOut := false
	var gkTouched := false
	var steps := 0
	while steps < 60 * 30:
		steps += 1
		bot.stepBot(m)
		m.step(DT)
		if m.phase == "play":
			crossed = true
			tPlay += DT
			if absf(g.y - gy) > FAR_OUT:
				wentOut = true
		var stop := false
		for e: Dictionary in m.events:
			var p: Variant = e.get("p")
			match e.type:
				"goal":
					if int(e.team) == atk:
						res.gol = 1
						if lastHead:
							res.gol_testa = 1
						if C.hyp(g.x, g.y - gy) > EMPTY_NET:
							res.porta_vuota = 1
					stop = true
				"save":
					if p == g:
						gkTouched = true
						res.parate = 1
						if e.get("catch", false):
							res.prese = 1
						else:
							res.respinte = 1
				"punch":
					if p == g:
						gkTouched = true # respinta di pugno: uscita non a vuoto
				"control":
					if p == g:
						gkTouched = true
						res.prese = 1
					if p != null and (p as R.Player).team == dfn:
						stop = true
				"kick":
					lastHead = p != null and e.get("kind", "") == "header" and (p as R.Player).team == atk
					if p != null and e.get("kind", "") == "header":
						if (p as R.Player).team == atk:
							res.teste = 1
							if m.ball.shot != null and m.ball.shot.on:
								res.teste_porta = 1
						elif e.get("clear", false):
							res.respinte_testa = 1
				"restart":
					if crossed:
						stop = true
		m.events.clear()
		if stop or m.phase == "goal" or (crossed and tPlay > MAX_SEC):
			break
	if wentOut:
		res.uscite = 1
		if not gkTouched:
			res.uscite_mancate = 1
	return res


static func riga(nome: String, r: Dictionary) -> String:
	var n: float = maxf(1.0, float(r.angoli))
	return "%s: %d angoli, gol %.1f%% (di testa %d, porta vuota %d), uscite %d (a vuoto %d), prese %d, respinte %d, teste attaccanti %d (in porta %d), respinte di testa %d" % [
		nome, r.angoli, 100.0 * r.gol / n, r.gol_testa, r.porta_vuota, r.uscite, r.uscite_mancate, r.prese, r.respinte, r.teste, r.teste_porta, r.respinte_testa]
