# Diagnosi (non è un test): cosa succede al portatore della persona dopo un dribbling riuscito, in partite vere col
# dito finto (tools/dito_motore.gd) e il tempo che scorre come nel gioco (regia del dribbling, duello, fuga, area).
#   $G --headless --path godot -s res://tools/diag_dopo_dribbling.gd -- --partite=6 [--righe] [--solo-dribbling]
# --solo-dribbling: niente dito finto, la persona tocca solo Dribbling appena si apre il duello
# Per ogni dribble_go della persona segue 3 s VERI: velocità del portatore (m/s di partita), velocità del tempo (ts),
# velocità "a schermo" (v × ts) e perché il tempo è lento.
extends SceneTree

const H := preload("res://tests/harness.gd")
const C := preload("res://sim/core.gd")
const Dito := preload("res://tools/dito_motore.gd")
const Regia := preload("res://scripts/partita/dribbling_regia.gd")
const FRAME := 1.0 / 60.0
const TEMPO_K := 14.0
const SEGUI_S := 3.0

var casi: Array = []
var solo_dribbling := false


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	solo_dribbling = opz.has("solo-dribbling")
	for i in int(opz.get("partite", "6")):
		_partita(int(opz.get("seme", "1")) + i)
	_stampa(opz.has("righe"))
	quit(0)


func _partita(sd: int) -> void:
	var ta := H.mkTeam("A", 60.0, sd * 7 + 1)
	var tb := H.mkTeam("B", 60.0, sd * 13 + 5, "4-4-2")
	var m := H.newMatch(sd, 150.0, [true, false], ta, tb, "sereno", {"portaAuto": true, "testa": true, "rifiniture": true,
		"falli": true, "contatti": true, "attacco": true})
	var dito := Dito.new(sd * 31 + 7)
	var regia := Regia.new()
	var ts := 1.0
	var segui: Dictionary = {}
	var frames := 0
	while m.phase != "full" and frames < 60 * 60 * 40:
		frames += 1
		if solo_dribbling:
			if m.duelFor(0) and not m.dribBooked(0):
				m.userDribble(0)
		else:
			dito.passo(m, FRAME, FRAME * ts)
		var target: float = dito.velocita_voluta(m)
		var rv: float = regia.velocita()
		if rv >= 0.0 and dito.draw_mode == "":
			target = rv
		ts += (target - ts) * minf(1.0, FRAME * regia.k_tempo(TEMPO_K))
		var sdt := FRAME * ts
		if sdt > 0.0:
			m.step(sdt)
		regia.passo(m, 0, sdt, ts)
		for e: Dictionary in m.events:
			regia.evento(e, 0)
			if e.type == "dribble_go" and e.p.team == 0 and segui.is_empty():
				segui = {"p": e.p, "reale": 0.0, "camp": [], "seme": sd, "t": m.time, "fine": ""}
		if m.phase == "half":
			m.startSecondHalf()
		if not segui.is_empty():
			var p = segui.p
			segui.reale += FRAME
			var causa := "normale"
			if regia.velocita() >= 0.0:
				causa = "regia_" + regia.fase
			elif dito.draw_mode != "":
				causa = "disegno"
			elif m.duelFor(0):
				causa = "duello"
			elif m.fleeFor(0):
				causa = "fuga"
			elif m.inZone(0):
				causa = "area"
			var v: float = C.hyp(p.vx, p.vy)
			segui.camp.append([segui.reale, v, ts, causa, m.ball.owner == p])
			if m.ball.owner != p and segui.fine == "":
				segui.fine = "perso/passato a %.2f s" % segui.reale
			if segui.reale >= SEGUI_S:
				casi.append(segui)
				segui = {}
		m.events.clear()
	m.dispose()


func _stampa(righe: bool) -> void:
	print("casi: %d" % casi.size())
	var cause := {}
	var lento_schermo := 0
	for c: Dictionary in casi:
		var lenti := 0.0
		var pezzi: Array = []
		var ultimo := -1.0
		for x: Array in c.camp:
			if not x[4]:
				break
			if float(x[1]) * float(x[2]) < 1.5:
				lenti += FRAME
				cause[x[3]] = float(cause.get(x[3], 0.0)) + FRAME
			if float(x[0]) - ultimo >= 0.25:
				ultimo = float(x[0])
				pezzi.append("%.2f:v%.1f ts%.2f %s" % [x[0], x[1], x[2], String(x[3]).left(12)])
		if lenti > 0.6:
			lento_schermo += 1
		if righe:
			print("seme %d t=%.1f lento a schermo %.2f s  %s\n   %s" % [c.seme, c.t, lenti, c.fine, " | ".join(pezzi)])
	print("casi con più di 0,6 s veri 'fermo a schermo' (v × ts < 1,5): %d" % lento_schermo)
	print("secondi veri lenti per causa: %s" % str(cause))
