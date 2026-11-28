# Misura delle istruzioni ai giocatori (sim/istruzioni_gioco.gd) in partite vere, insieme agli stili di gioco.
# Per ogni istruzione e ogni stile (d'attacco per le istruzioni che si vedono quando attacchiamo, di difesa per quelle
# che si vedono quando difendiamo) gioca tre partite a seme fisso con la scelta di sinistra, Equilibrato e quella di
# destra date a tutti i giocatori del ruolo, e misura quello che il nome promette (es. Si sovrappone = più avanti
# quando attacchiamo, Marcatura stretta = più vicino all'avversario). Stampa una riga per istruzione e stile:
#   RIGA|chiave|stile|misura sinistra|valore sinistra|valore equilibrato|misura destra|valore destra|esito
# e alla fine quante combinazioni vanno nel verso giusto, più gol e tiri medi (partite sane).
#   $G --headless --path godot -s res://tools/misura_istruzioni.gd -- [--chiave=spinta] [--tempo=90] [--semi=1]
extends SceneTree

const Stili := preload("res://sim/stili.gd")
const SimMatchScript := preload("res://sim/match.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const DT := 1.0 / 60.0
const CAMPIONE := 30   # un campione ogni tanti passi

# chiave → [ruoli, modulo, scelte [sinistra, destra], misura sinistra [nome, verso atteso], misura destra, fase stili]
const PROVE := {
	"spinta": [["TS", "TD"], "4-3-3", ["bloccato", "sovrapposizione"], ["yA", -1], ["yA", 1], "att"],
	"corsia": [["TS", "TD"], "4-3-3", ["fascia", "accentra"], ["xA", 1], ["xA", -1], "att"],
	"fascia": [["ES", "ED"], "4-2-3-1", ["linea", "torna"], ["xA", 1], ["yD", -1], "att"],
	"mediano": [["CDC"], "4-2-3-1", ["abbassa", "accompagna"], ["yA", -1], ["yA", 1], "att"],
	"marcatura": [["DC"], "4-3-3", ["copre", "stretta"], ["yD", -1], ["nearC", -1], "dif"],
	"imposta": [["DC"], "4-3-3", ["semplice", "imposta"], ["hold", -1], ["hold", 1], "att"],
	"mezzala": [["CC"], "4-3-3", ["copertura", "box"], ["yA", -1], ["boxA", 1], "att"],
	"trequarti": [["COC"], "4-2-3-1", ["aiuta", "seconda_punta"], ["yA", -1], ["yA", 1], "att"],
	"area": [["COC"], "4-2-3-1", ["tra_linee", "inserimento"], ["boxA", -1], ["boxA", 1], "att"],
	"ala": [["AS", "AD"], "4-3-3", ["larga", "taglia"], ["xA", 1], ["xA", -1], "att"],
	"cross": [["AS", "AD"], "4-3-3", ["fuori", "secondo_palo"], ["box2", -1], ["palo2", -1], "att"],
	"movimento": [["ATT"], "4-3-3", ["falso_nove", "profondita"], ["yA", -1], ["offA", -1], "att"],
	"riferimento": [["ATT"], "4-3-3", ["boa", "filo"], ["offA", 1], ["offA", -1], "att"],
	"pressione": [["ATT", "AS", "AD"], "4-3-3", ["resta", "pressa"], ["yD", 1], ["pressD", -1], "dif"],
	"con_palla": [["CC", "ATT", "AS", "AD"], "4-3-3", ["semplice", "porta"], ["hold", -1], ["hold", 1], "att"],
	"uscite": [["P"], "4-3-3", ["pali", "esce"], ["gk", -1], ["gk", 1], "dif"],
}

var _tot_gol := 0.0
var _tot_tiri := 0.0
var _partite := 0


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1]
	var tempo := float(opz.get("tempo", "90"))
	var semi := int(opz.get("semi", "1"))
	var solo: String = opz.get("chiave", "")
	var ok := 0
	var tutte := 0
	var male: Array = []
	for k: String in PROVE:
		if solo != "" and k != solo:
			continue
		var pr: Array = PROVE[k]
		var stili: Array = Stili.ATTACCO if pr[5] == "att" else Stili.DIFESA
		for st: String in stili:
			var v := {}
			for scelta: String in [pr[2][0], "", pr[2][1]]:
				var somma := {}
				for sd in semi:
					var mis := _partita(k, pr, scelta, st, tempo, 11 + sd * 17)
					for nome: String in mis:
						somma[nome] = float(somma.get(nome, 0.0)) + float(mis[nome]) / semi
				v[scelta] = somma
			var m_sx: Array = pr[3]
			var m_dx: Array = pr[4]
			var base_sx: float = v[""].get(m_sx[0], 0.0)
			var base_dx: float = v[""].get(m_dx[0], 0.0)
			var val_sx: float = v[pr[2][0]].get(m_sx[0], 0.0)
			var val_dx: float = v[pr[2][1]].get(m_dx[0], 0.0)
			var giusto_sx: bool = (val_sx - base_sx) * float(m_sx[1]) > 0.0
			var giusto_dx: bool = (val_dx - base_dx) * float(m_dx[1]) > 0.0
			tutte += 2
			ok += int(giusto_sx) + int(giusto_dx)
			if not giusto_sx:
				male.append("%s=%s con %s" % [k, pr[2][0], st])
			if not giusto_dx:
				male.append("%s=%s con %s" % [k, pr[2][1], st])
			print("RIGA|%s|%s|%s %s|%.2f|%.2f / %.2f|%s %s|%.2f|%s" % [k, st, pr[2][0], m_sx[0], val_sx, base_sx, base_dx,
				pr[2][1], m_dx[0], val_dx, ("ok" if giusto_sx and giusto_dx else "NO")])
	print("ESITO|%d su %d nel verso giusto|gol a partita %.2f|tiri a partita %.2f|partite %d" % [ok, tutte,
		_tot_gol / maxi(_partite, 1), _tot_tiri / maxi(_partite, 1), _partite])
	for x: String in male:
		print("MALE|" + x)
	quit(0)


func _partita(k: String, pr: Array, scelta: String, stile: String, tempo: float, seme: int) -> Dictionary:
	var c := Carriera.new()
	c.percorso = "user://misura_istruzioni.json"
	c.create("Prova", 1, 4321)
	c.s.formation = pr[1]
	c.autoLineup()
	var mia := c.squadraPartita()
	if pr[5] == "att":
		mia["stileAtt"] = stile
	else:
		mia["stileDif"] = stile
	var avv := c.avversarioPartita(c.team(c.s.divs[2][1]))
	for q: Variant in avv.players: # avversario senza istruzioni, stili equilibrati: cambia solo la nostra scelta
		if q is Dictionary:
			(q as Dictionary).erase("istr")
	avv["stileAtt"] = "equilibrato"
	avv["stileDif"] = "equilibrata"
	var m := SimMatchScript.new({"seed": seme, "halfLen": tempo, "human": [false, false], "teams": [mia, avv],
		"kickoff": 0, "rifiniture": true, "riprese": true, "falli": true, "contatti": true, "testa": true,
		"attacco": true})
	var ruoli: Array = pr[0]
	var miei: Array = []
	for p: R.Player in m.team(0):
		if ruoli.has(p.ruolo):
			miei.append(p)
			if scelta != "":
				p.src["istr"] = {k: scelta}
	var acc := {}
	var n := {}
	var carry := 0.0
	var tenuta := 0.0 # secondi col pallone (per tocco: Gioca semplice lo dà via prima, Porta palla lo tiene)
	var tocchi := 0
	var aveva: R.Player = null
	var prima := {}
	var passi := int(tempo * 2.0 / DT) + 600
	for i in passi:
		m.step(DT)
		if m.phase == "full":
			break
		if m.phase == "half":
			m.startSecondHalf()
		var own: R.Player = m.ball.owner
		if own != null and miei.has(own):
			tenuta += DT
			if own != aveva:
				tocchi += 1
			elif prima.has(own):
				carry += C.hyp(own.x - prima[own][0], own.y - prima[own][1])
			prima[own] = [own.x, own.y]
		aveva = own
		if i % CAMPIONE != 0 or m.phase != "play":
			continue
		_campioni(m, miei, acc, n)
	acc["carry"] = carry
	n["carry"] = maxf(1.0, tocchi)
	acc["hold"] = tenuta
	n["hold"] = maxf(1.0, tocchi)
	_tot_gol += m.score[0] + m.score[1]
	_tot_tiri += float(m.stats.shots[0]) + float(m.stats.shots[1])
	_partite += 1
	m.dispose()
	var out := {}
	for nome: String in acc:
		out[nome] = float(acc[nome]) / maxf(1.0, float(n.get(nome, 1.0)))
	return out


func _somma(acc: Dictionary, n: Dictionary, nome: String, v: float) -> void:
	acc[nome] = float(acc.get(nome, 0.0)) + v
	n[nome] = float(n.get(nome, 0.0)) + 1.0


func _campioni(m: SimMatchScript, miei: Array, acc: Dictionary, n: Dictionary) -> void:
	var b: R.Ball = m.ball
	var noi: bool = m.att == 0
	var bf: float = (b.y + C.HL) / C.L
	for p: R.Player in miei:
		if p.off:
			continue
		var fwd: float = p.y # squadra 0 attacca verso +y
		if p.pos == "P":
			_somma(acc, n, "gk", fwd + C.HL)
			continue
		var in_area: float = 1.0 if absf(p.x) < C.BOX_W / 2.0 and fwd > C.HL - C.BOX_D else 0.0
		if noi:
			_somma(acc, n, "yA", fwd)
			_somma(acc, n, "xA", absf(p.x))
			_somma(acc, n, "boxA", in_area)
			_somma(acc, n, "offA", float(m.offLine[0]) - fwd)
			var sgn: float = signf(p.bx) if p.bx != 0.0 else 1.0
			if b.x * sgn < -8.0 and bf > 0.68: # pallone sull'altra fascia in fondo: in area? e quanto lontano dal palo lontano
				_somma(acc, n, "box2", in_area)
				_somma(acc, n, "palo2", C.hyp(p.x - sgn * (C.GW / 2.0 + 1.5), fwd - (C.HL - 6.0)))
		else:
			_somma(acc, n, "yD", fwd)
			var best := 99.0
			for o: R.Player in m.team(1):
				if o.pos != "P" and not o.off:
					best = minf(best, C.hyp(o.x - p.x, o.y - p.y))
			_somma(acc, n, "near", best)
			if best < 16.0 and b.y < 0.0: # c'è un avversario da marcare e il pallone è nella nostra metà
				_somma(acc, n, "nearC", best)
			var c: R.Player = b.owner
			if c != null and c.team == 1 and b.y > 8.0: # impostano nella loro metà: quanto è vicino all'avversario più vicino
				_somma(acc, n, "pressD", best)
