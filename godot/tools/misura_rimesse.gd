# Misura delle rimesse laterali (Luis 2026-11-24: "i giocatori si mettono troppo sulla linea"). Partite intere della
# persona simulata (harness.gd → Bot) contro la CPU con le opzioni del gioco (riprese, rifiniture, portaAuto, testa,
# falli). Al momento del lancio di ogni rimessa: distanza media dalla linea della rimessa dei giocatori (non battitore né
# portieri) entro 25 m lungo la linea dal punto della rimessa (media dei 6 più vicini alla linea), il più vicino, compagno più vicino al battitore; poi se
# la rimessa è riuscita (il primo a prendere il pallone è un compagno del battitore).
#   $G --headless --path godot -s res://tools/misura_rimesse.gd -- --partite=10 --forza=60 --seme=1 [--senza-rifiniture]
extends SceneTree

const H := preload("res://tests/harness.gd")
const R := preload("res://sim/records.gd")
const C := preload("res://sim/core.gd")
const DT := 1.0 / 60.0
const VICINO_Y := 25.0 # m lungo la linea dal punto della rimessa
const VICINI_N := 6    # la distanza media si fa sui tanti giocatori più vicini alla linea


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var partite := int(opz.get("partite", "10"))
	var forza := float(opz.get("forza", "60"))
	var seme := int(opz.get("seme", "1"))
	var rif := not opz.has("senza-rifiniture")
	var tot := {"n": 0, "media": 0.0, "minimo": 0.0, "sotto4": 0, "gioc": 0, "compagno": 0.0, "ok": 0, "esito": 0, "opp2": 0}
	for k in partite:
		_partita(seme + k, forza, rif, tot)
	var n := maxf(1.0, float(tot.n))
	print("RIMESSE %s · %d rimesse in %d partite · distanza media dalla linea dei 6 più vicini %.1f m · più vicino (media) %.1f m · giocatori sotto 4 m %.1f%% · compagno più vicino al battitore %.1f m · avversari sotto 2 m %d · riuscite %.0f%% (%d/%d)" % [
		"con rifiniture" if rif else "senza rifiniture", tot.n, partite, tot.media / n, tot.minimo / n,
		100.0 * tot.sotto4 / maxf(1.0, float(tot.gioc)), tot.compagno / n, tot.opp2, 100.0 * tot.ok / maxf(1.0, float(tot.esito)), tot.ok, tot.esito])
	H.disposeAll()
	quit(0)


func _partita(sd: int, forza: float, rif: bool, tot: Dictionary) -> void:
	var ta := H.mkTeam("A", forza, sd * 7 + 1)
	var tb := H.mkTeam("B", forza, sd * 13 + 5)
	var m := H.newMatch(sd, 150.0, [true, false], ta, tb, "", {"portaAuto": true, "testa": true, "rifiniture": rif, "riprese": true, "falli": true})
	var bot: H.Bot = H.Bot.new(sd + 9)
	var foto: Variant = null # ultima situazione durante l'attesa della rimessa
	var lancio: Variant = null # rimessa partita, in attesa dell'esito: {team, taker}
	var steps := 0
	while m.phase != "full" and steps < 60 * 60 * 30:
		var attesa: bool = m.phase == "restart" and m.restart.type == "throw" and m.restart.scena == ""
		if attesa:
			foto = _foto(m)
		m.step(DT)
		steps += 1
		if m.phase == "half":
			m.startSecondHalf()
		# la persona simulata batte come l'IA, ma solo a battitore pronto (non durante i passi verso la linea)
		if not (m.phase == "restart" and (m.restart.scena != "" or m.restart.pend != null)):
			bot.stepBot(m)
		for e: Dictionary in m.events:
			if e.type == "kick" and foto != null and e.p == foto.taker:
				_conta(foto, tot)
				lancio = {"team": foto.taker.team, "taker": foto.taker}
				foto = null
		m.events.clear()
		if lancio != null:
			var o: R.Player = m.ball.owner
			if m.phase != "play":
				tot.esito += 1
				lancio = null
			elif o != null and o != lancio.taker:
				tot.esito += 1
				if o.team == lancio.team:
					tot.ok += 1
				lancio = null
		if m.phase != "restart":
			foto = null


func _foto(m: Object) -> Dictionary:
	var r: R.Restart = m.restart
	var side: float = 1.0 if r.x >= 0.0 else -1.0
	var ds: Array = []
	var comp := 99.0
	var opp := 99.0
	for p: R.Player in m.players:
		if p == r.taker or p.pos == "P" or p.off:
			continue
		var d: float = Vector2(p.x - r.taker.x, p.y - r.taker.y).length()
		if p.team == r.team:
			comp = minf(comp, d)
		else:
			opp = minf(opp, d)
		if absf(p.y - r.y) <= VICINO_Y:
			ds.append(C.HW - p.x * side)
	return {"taker": r.taker, "ds": ds, "comp": comp, "opp": opp}


func _conta(f: Dictionary, tot: Dictionary) -> void:
	var ds: Array = f.ds
	if ds.is_empty():
		return
	var s := 0.0
	var mn := 99.0
	for d: float in ds:
		mn = minf(mn, d)
		if d < 4.0:
			tot.sotto4 += 1
	ds.sort()
	var k: int = mini(VICINI_N, ds.size())
	for i in k:
		s += float(ds[i])
	tot.n += 1
	tot.gioc += ds.size()
	tot.media += s / k
	tot.minimo += mn
	tot.compagno += float(f.comp)
	if float(f.opp) < 2.0:
		tot.opp2 += 1
