# Misura della velocità del motore in GDScript (non è un test: il runner lo ignora).
# Uso:  godot --headless --path godot -s res://tests/bench.gd
# Confronto con Node:  node -e "import('./test/lib/harness.mjs').then(({playMatch})=>{const t=performance.now();const r=playMatch({seed:1,mode:'bot',halfLen:60});console.log(r.steps/(performance.now()-t)*1000,'passi/s')})"
extends SceneTree

const H := preload("harness.gd")
const F := preload("../sim/fmath.gd")
const N_TRIG := 100000


func _init() -> void:
	var t0 := Time.get_ticks_usec()
	var s := 0.0
	for i in N_TRIG:
		s += F.sin_(i * 0.0001 - 3.0)
	var t1 := Time.get_ticks_usec()
	for i in N_TRIG:
		s += sin(i * 0.0001 - 3.0)
	var t2 := Time.get_ticks_usec()
	for i in N_TRIG:
		s += F.atan2_(i * 0.0001 - 3.0, 1.7)
	var t3 := Time.get_ticks_usec()
	print("sin fdlibm %.2f us, sin di Godot %.3f us, atan2 fdlibm %.2f us (controllo %f)" % [
		float(t1 - t0) / N_TRIG, float(t2 - t1) / N_TRIG, float(t3 - t2) / N_TRIG, s])
	for k in 3:
		var a := Time.get_ticks_usec()
		var res := H.playMatch({"seed": 1, "mode": "bot", "halfLen": 60.0})
		var ms := (Time.get_ticks_usec() - a) / 1000.0
		print("partita (seme 1, bot, 2×60 s): %d passi in %.0f ms = %.0f passi/s, %.3f ms a passo" % [
			res.steps, ms, res.steps / ms * 1000.0, ms / res.steps])
		res.m.dispose()
	# passo più lento (con il "bot" che gioca come un utente): per la stima contro i 16 ms di un fotogramma
	var m := H.newMatch(1, 60.0, [true, false], H.mkTeam("A", 60, 8), H.mkTeam("B", 60, 18))
	var bot := H.Bot.new(10)
	var times := PackedFloat64Array()
	while m.phase != "full":
		var a := Time.get_ticks_usec()
		m.step(1.0 / 60.0)
		times.append((Time.get_ticks_usec() - a) / 1000.0)
		if m.phase == "half":
			m.startSecondHalf()
		bot.stepBot(m)
		m.events.clear()
	times.sort()
	print("tempo a passo: mediana %.3f ms, 99%% %.3f ms, massimo %.3f ms su %d passi" % [
		times[times.size() / 2], times[int(times.size() * 0.99)], times[times.size() - 1], times.size()])
	m.dispose()
	quit()
