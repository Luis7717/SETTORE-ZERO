# Misura delle parate (non è un test: il runner lo ignora).
# Uso:  godot --headless --path godot -s res://tests/parate.gd [-- N]
# Gioca N partite a seme fisso (umano simulato contro IA e IA contro IA) e conta le parate: prese (palla in mano),
# respinte in angolo, respinte in campo e dove finisce la respinta in campo (distanza dal centro della porta 1 s dopo).
extends SceneTree

const H := preload("harness.gd")
const C := preload("../sim/core.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 6
	for mode: String in ["bot", "ai"]:
		var st := conta(n, mode)
		print("%s: %d parate, prese %d (%.0f%%), respinte in angolo %d, respinte in campo %d (a %.1f m dalla porta in media, %d dentro l'area piccola); squadra 0 prese %d/%d, squadra 1 prese %d/%d" % [
			mode, st.n, st.prese, 100.0 * st.prese / maxf(1.0, st.n), st.angolo, st.campo, st.dist / maxf(1.0, st.campo), st.vicine,
			st.p0, st.n0, st.p1, st.n1])
	quit(0)


static func conta(n: int, mode: String) -> Dictionary:
	var st := {"n": 0, "prese": 0, "angolo": 0, "campo": 0, "dist": 0.0, "vicine": 0, "n0": 0, "p0": 0, "n1": 0, "p1": 0}
	var pend: Array = [] # [passi rimasti, porta y] delle respinte in campo da misurare
	var onStep := func(m: Object) -> void:
		for i in range(pend.size() - 1, -1, -1):
			pend[i][0] -= 1
			if pend[i][0] <= 0:
				var d: float = C.hyp(m.ball.x, m.ball.y - pend[i][1])
				st.dist += d
				if absf(m.ball.x) < C.SIX_W / 2.0 and absf(m.ball.y - pend[i][1]) < C.SIX_D:
					st.vicine += 1
				pend.remove_at(i)
		for e: Dictionary in m.events:
			if e.type != "save":
				continue
			var tm: int = e.p.team
			st.n += 1
			st["n%d" % tm] += 1
			if e.get("catch", false):
				st.prese += 1
				st["p%d" % tm] += 1
			elif e.get("out", false):
				st.angolo += 1
			else:
				st.campo += 1
				pend.append([60, (-1.0 if tm == 0 else 1.0) * C.HL])
	for s in n:
		H.playMatch({"seed": 100 + s, "mode": mode, "halfLen": 150.0}, onStep)
		H.disposeAll()
	return st
