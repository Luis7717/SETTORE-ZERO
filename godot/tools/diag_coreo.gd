# Diagnosi (non è un test): piedi, bacino e pallone di una coreografia del dribbling passo per passo.
#   $G --headless --path godot -s res://tools/diag_coreo.gd -- --giochetto=bicicletta [--ko]
extends SceneTree

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("res://tests/test_dribbling.gd")
const TC := preload("res://tests/test_coreo.gd")
const DT := 1.0 / 60.0


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var ko := opz.has("ko")
	var s := TD.setup(TD.first_ok_seed() if not ko else 2, 5.0)
	var m = s[0]
	m.rifiniture = true
	m.skillForza = String(opz.get("giochetto", "finta"))
	var p = s[1]
	var o = s[2]
	p.st.dri = 1 if ko else 99
	o.st.dif = 99 if ko else 20
	m.userDribble(0)
	var cp: Coreo = null
	var n := 0
	for i in 300:
		m.step(DT)
		for e in m.events:
			if e.type == "dribble":
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				if e.ok:
					CD.portatore(cp, String(e.skill), float(e.side), float(e.show))
				else:
					CD.inciampo(cp)
				print("dribble %s lato %s show %s" % [e.get("skill"), e.side, e.get("show")])
			elif e.type == "dribble_go" and cp != null:
				CD.portatore_go(cp)
				print("go")
		m.events.clear()
		if cp == null:
			continue
		cp.passo(DT, p, m.ball)
		if cp.finito:
			break
		n += 1
		if n % 3 == 0:
			var pd := cp.piedi()
			var c := Vector3(p.x, 0, -p.y)
			var fr := cp.frame(TC.figura(cp, p), cp.pallone(), cp.pallone_h())
			var l: Vector3 = pd.l.pos - c
			var r: Vector3 = pd.r.pos - c
			var b: Vector3 = cp.pallone() - c
			var rot := Basis(Vector3.UP, cp.yaw).inverse()   # nel riferimento del corpo (x sinistra, z avanti), m del mondo
			l = rot * l
			r = rot * r
			b = rot * b
			print("t=%.2f yaw=%.2f bac=(%.2f,%.2f,%.2f) L%s(%.2f,%.2f,%.2f) R%s(%.2f,%.2f,%.2f) palla(%.2f,%.2f h%.2f) v=%.1f" % [cp.t, cp.yaw,
				fr.pelvis.p.x, fr.pelvis.p.y, fr.pelvis.p.z, "_" if pd.l.terra else "^", l.x, l.y, l.z, "_" if pd.r.terra else "^", r.x, r.y, r.z,
				b.x, b.z, cp.pallone_h(), Vector2(p.vx, p.vy).length()])
	quit(0)
