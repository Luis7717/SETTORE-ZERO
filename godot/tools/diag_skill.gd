# Diagnosi (non è un test): distanza tra portatore e difensore durante il dribbling prenotato della persona
# (corsa, giochetto, scatto o contrasto), per controllare che i corpi a schermo non si compenetrino.
#   $G --headless --path godot -s res://tools/diag_skill.gd -- [--ko] [--seme=1] [--dist=6.5] [--righe] [--giochetto=ID]
extends SceneTree

const H := preload("res://tests/harness.gd")
const C := preload("res://sim/core.gd")
const DT := 1.0 / 60.0


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var ko := opz.has("ko")
	var n := int(opz.get("n", "1"))
	for k in n:
		_uno(int(opz.get("seme", "1")) + k, ko, float(opz.get("dist", "6.5")), opz.has("righe"), String(opz.get("giochetto", "")))
	quit(0)


func _uno(sd: int, ko: bool, d0: float, righe: bool, forza: String) -> void:
	var ta := H.mkTeam("A", 60.0, sd * 7 + 1)
	var tb := H.mkTeam("B", 60.0, sd * 13 + 5, "4-4-2")
	var m := H.newMatch(sd, 600.0, [true, false], ta, tb, "sereno", {"portaAuto": true, "rifiniture": true, "contatti": true})
	m.phase = "play"
	m.skillForza = forza
	m.restart = null
	var p = m.players[9]
	var o = m.players[11 + 3]
	for q in m.players:
		if q != p and q != o:
			q.x = clampf(q.x, -30.0, -12.0) if q.x < 0.0 else clampf(q.x, 14.0, 30.0)
	for q in [p, o]:
		q.vx = 0.0; q.vy = 0.0; q.state = "play"
	p.x = 4.0; p.y = 8.0; p.fx = 0.0; p.fy = 1.0; p.tx = 4.0; p.ty = 30.0
	o.x = 4.6; o.y = 8.0 + d0; o.fx = 0.0; o.fy = -1.0; o.tx = o.x; o.ty = o.y
	p.st.dri = 1.0 if ko else 99.0
	o.st.dif = 99.0 if ko else 1.0
	p.st.sub.erase("drb"); o.st.sub.erase("ctr")
	m.ball.owner = p; m.ball.last = p; m.ball.x = p.x; m.ball.y = p.y + 0.6
	m.ctrl[0] = p
	var pren := false
	var dmin := INF
	var t_ev := -1.0
	var esito := "?"
	for i in 600:
		m.step(DT)
		for e in m.events:
			if e.type == "dribble":
				t_ev = m.time
				esito = "ok" if e.ok else "ko"
				print("  %.2f dribble %s lato %s show %s skill %s d=%.2f" % [m.time, esito, e.side, e.get("show"), e.get("skill", "-"), C.hyp(p.x - o.x, p.y - o.y)])
			elif e.type == "dribble_palla" or e.type == "dribble_presa":
				print("  %.2f %s %s" % [m.time, e.type, e.get("ok", "")])
			elif e.type == "dribble_go":
				print("  %.2f dribble_go d=%.2f" % [m.time, C.hyp(p.x - o.x, p.y - o.y)])
		m.events.clear()
		if not pren and m.duelFor(0):
			m.userDribble(0)
			pren = true
		var d := C.hyp(p.x - o.x, p.y - o.y)
		if t_ev >= 0.0:
			dmin = minf(dmin, d)
			if righe and i % 3 == 0:
				var fi = m.ball.finto
				print("  %.2f d=%.2f p=(%.2f,%.2f) v=%.1f o=(%.2f,%.2f) v=%.1f palla %s%s" % [m.time, d, p.x, p.y, C.hyp(p.vx, p.vy), o.x, o.y, C.hyp(o.vx, o.vy),
					"p" if m.ball.owner == p else ("o" if m.ball.owner == o else "-"),
					"" if fi == null else " finto=(%.2f,%.2f h%.2f) v=%.1f" % [fi.x, fi.y, fi.h, C.hyp(fi.vx, fi.vy)]])
			if m.time > t_ev + 2.6:
				break
	print("seme %d %s: distanza minima %.2f m" % [sd, esito, dmin])
	m.dispose()
