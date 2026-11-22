# Misura degli stili di gioco (stili.gd): partite IA contro IA a seme fisso, una squadra con lo stile da provare e
# l'altra equilibrata (metà partite in casa, metà fuori). Stampa una riga di numeri per lo stile.
#   $G --headless --path godot -s res://tools/misura_stili.gd -- --stile=att:contropiede --partite=16 --tempo=90
#   --stile=att:<nome> | dif:<nome> | base (tutto equilibrato) · --forza=65 (forza delle due squadre)
# Numeri (per la squadra con lo stile): passaggi per azione, % lanci alti, passaggi lunghi (>25 m) a partita,
# cross a partita, altezza media della linea difensiva quando difende (m dalla propria linea di fondo),
# recuperi alti a partita (pallone preso nella metà campo avversaria), tiri, gol fatti e subiti, punti a partita.
extends SceneTree

const H := preload("res://tests/harness.gd")
const Stili := preload("res://sim/stili.gd")


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1]
	var stile: String = opz.get("stile", "base")
	var partite := int(opz.get("partite", "16"))
	var tempo := float(opz.get("tempo", "90"))
	var forza := float(opz.get("forza", "65"))
	var tot := {"pass": 0.0, "azioni": 0.0, "lanci": 0.0, "lunghi": 0.0, "cross": 0.0, "linea": 0.0, "lineaN": 0.0,
		"recAlti": 0.0, "tiri": 0.0, "gf": 0.0, "gs": 0.0, "punti": 0.0, "off": 0.0}
	for k in partite:
		var lato: int = k % 2
		_partita(k + 1, lato, stile, tempo, forza, tot)
	var n := float(partite)
	print("RIGA|%s|%.2f|%.0f%%|%.1f|%.1f|%.1f|%.1f|%.1f|%.2f|%.2f|%.2f|%.1f" % [stile,
		tot.pass / maxf(1.0, tot.azioni), 100.0 * tot.lanci / maxf(1.0, tot.pass), tot.lunghi / n, tot.cross / n,
		tot.linea / maxf(1.0, tot.lineaN), tot.recAlti / n, tot.tiri / n, tot.gf / n, tot.gs / n, tot.punti / n, tot.off / n])
	H.disposeAll()
	quit(0)


func _partita(sd: int, lato: int, stile: String, tempo: float, forza: float, tot: Dictionary) -> void:
	var ta := H.mkTeam("A", forza, sd * 7 + 1)
	var tb := H.mkTeam("B", forza, sd * 13 + 5)
	var mine: Dictionary = ta if lato == 0 else tb
	if stile.begins_with("att:"):
		mine["stileAtt"] = stile.substr(4)
	elif stile.begins_with("dif:"):
		mine["stileDif"] = stile.substr(4)
	var m := H.newMatch(sd, tempo, [false, false], ta, tb)
	var dir: float = -1.0 if lato else 1.0
	var own: int = -1        # squadra col pallone (possesso)
	var kick_from := Vector2.INF
	var kick_team := -1
	var kick_loft := false
	var steps := 0
	while m.phase != "full" and steps < 60 * 60 * 30:
		m.step(H.DT)
		steps += 1
		if m.phase == "half":
			m.startSecondHalf()
		var b := m.ball
		for e: Dictionary in m.events:
			if e.type == "kick" and e.p.team == lato and (e.kind == "ground" or e.kind == "loft"):
				tot.pass += 1.0
				kick_from = Vector2(e.p.x, e.p.y)
				kick_team = lato
				kick_loft = e.kind == "loft"
				if kick_loft:
					tot.lanci += 1.0
					if absf(e.p.x) > 9.0 and e.p.y * dir > 14.0:
						tot.cross += 1.0
			elif e.type == "kick" and e.kind == "shot" and e.p.team == lato:
				tot.tiri += 1.0
			elif e.type == "offside" and e.p.team != lato:
				tot.off += 1.0
		if b.owner != null and m.phase == "play":
			if kick_team == lato and kick_from != Vector2.INF:
				if Vector2(b.x, b.y).distance_to(kick_from) > 25.0:
					tot.lunghi += 1.0
				kick_from = Vector2.INF
			if b.owner.team != own:
				if b.owner.team == lato:
					tot.azioni += 1.0
					if own >= 0 and b.y * dir > 0.0:
						tot.recAlti += 1.0
				own = b.owner.team
			if b.owner.team != lato:
				# linea difensiva: il difensore più arretrato (pos D), metri dalla propria linea di fondo
				var lo := 99.0
				for p in m.players:
					if p.team == lato and not p.off and p.pos == "D":
						lo = minf(lo, p.y * dir + 50.0)
				if lo < 99.0:
					tot.linea += lo
					tot.lineaN += 1.0
		m.events.clear()
	var gf: int = m.score[lato]
	var gs: int = m.score[1 - lato]
	tot.gf += gf
	tot.gs += gs
	tot.punti += 3.0 if gf > gs else (1.0 if gf == gs else 0.0)
