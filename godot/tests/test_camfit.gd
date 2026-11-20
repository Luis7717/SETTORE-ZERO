# Inquadrature calcolate (scripts/partita/camfit.gd, porting di src/camfit.js): stessi casi di test/unit/camfit.test.mjs
# (pali, traversa, portiere, pallone e compagni dentro lo schermo coi margini) e confronto numerico coi valori del JS
# (tests/fixtures/vista.json, da `node test/export-vista.mjs`).
extends "test_base.gd"

const CF := preload("res://scripts/partita/camfit.gd")
const ASPECT := 390.0 / 844.0
const FOV := 70.0
const HL := 50.0
const GW := 7.32
const GH := 2.44
const TOL_POS := 0.02    # m: il JS lavora a 64 bit, Vector3 di Godot a 32
const TOL_FOV := 0.02    # gradi

static var _fx: Dictionary = {}


static func fixture() -> Dictionary:
	if _fx.is_empty():
		_fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/vista.json"))
	return _fx


# punto (x, h, y) dello spazio orientato a schermo, con la telecamera messa come fa la vista (posizione, look_at, fov):
# dentro il riquadro coi margini (tolleranza piccola per gli arrotondamenti)
static func in_frame(v: Dictionary, p: Vector3, m: Dictionary, eps: float = 0.01) -> bool:
	var pos := Vector3(v.pos.x, v.pos.y, -v.pos.z)
	var look := Vector3(v.look.x, v.look.y, -v.look.z)
	var tr := Transform3D.IDENTITY.looking_at(look - pos, Vector3.UP)
	var d := Vector3(p.x, p.y, -p.z) - pos
	var z := -d.dot(tr.basis.z)
	if z <= 0.0:
		return false
	var tn := tan(deg_to_rad(v.fov / 2.0))
	var x := d.dot(tr.basis.x) / (z * tn * ASPECT)
	var y := d.dot(tr.basis.y) / (z * tn)
	return x >= -1.0 + m.l - eps and x <= 1.0 - m.r + eps and y >= -1.0 + m.b - eps and y <= 1.0 - m.t + eps


static func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func same_as_js(v: Dictionary, js: Dictionary, what: String) -> void:
	check((v.pos as Vector3).distance_to(v3(js.pos)) < TOL_POS, "%s: posizione %s contro %s" % [what, v.pos, js.pos])
	check((v.look as Vector3).distance_to(v3(js.look)) < TOL_POS * 3.0, "%s: punto guardato %s contro %s" % [what, v.look, js.look])
	near(v.fov, js.fov, TOL_FOV, what + ": campo visivo")
	eq(v.used, int(js.used), what + ": gruppi tenuti")


func test_parata_porta_intera_portiere_e_pallone_a_schermo() -> bool:
	for c: Dictionary in fixture().save:
		var ball := v3(c.ball)
		var keeper := Vector2(c.keeper[0], c.keeper[1])
		var v := CF.save_view(ball, keeper, ASPECT, FOV)
		var what := "tiro da %s" % [ball]
		same_as_js(v, c.out, what)
		for p: Vector3 in CF.goal_corners():
			check(in_frame(v, p, CF.SAVE_MARGIN), "%s: angolo della porta %s fuori" % [what, p])
		for p: Vector3 in [Vector3(-GW / 2, 0, -HL), Vector3(GW / 2, 0, -HL), Vector3(-GW / 2, GH, -HL), Vector3(GW / 2, GH, -HL)]:
			check(in_frame(v, p, CF.SAVE_MARGIN), "%s: palo/traversa %s fuori" % [what, p])
		check(in_frame(v, Vector3(keeper.x, 0, keeper.y), CF.SAVE_MARGIN) and in_frame(v, Vector3(keeper.x, 2, keeper.y), CF.SAVE_MARGIN), what + ": portiere fuori")
		check(in_frame(v, ball, CF.SAVE_MARGIN), what + ": pallone fuori")
		eq(v.used, 3, what + ": gruppi")
		var pos: Vector3 = v.pos
		check(pos.z < -HL - 1.0 and pos.z >= -HL - CF.SAVE_MAX_BACK - 0.01, "%s: telecamera a y %s" % [what, pos.z])
		check(pos.y > 1.0, what + ": telecamera sotto l'erba")
	return done()


func test_parata_si_gira_verso_il_lato_del_tiro() -> bool:
	var l := CF.save_view(Vector3(-14, 0.5, -33), Vector2(0, -49.4), ASPECT, FOV)
	var r := CF.save_view(Vector3(14, 0.5, -33), Vector2(0, -49.4), ASPECT, FOV)
	check(l.yaw < 0.0 and r.yaw > 0.0, "verso della girata")
	near(l.pos.x + r.pos.x, 0.0, 1e-4, "simmetrica")
	return done()


func test_rallenty_largo_portatore_compagni_e_porta() -> bool:
	for c: Dictionary in fixture().wide:
		var carrier := Vector2(c.carrier[0], c.carrier[1])
		var mates: Array = []
		for q: Array in c.mates:
			mates.append(Vector2(q[0], q[1]))
		var yaw: float = c.yaw
		var goal: bool = c.goal
		var v := CF.wide_view(carrier, yaw, mates, goal, ASPECT, FOV)
		var what := "portatore %s girata %s" % [carrier, yaw]
		same_as_js(v, c.out, what)
		check(in_frame(v, Vector3(carrier.x, 0, carrier.y), CF.WIDE_MARGIN) and in_frame(v, Vector3(carrier.x, 2.3, carrier.y), CF.WIDE_MARGIN), what + ": portatore fuori")
		if goal:
			for p: Vector3 in CF.goal_corners(HL, 0.5, 0.3):
				check(in_frame(v, p, CF.WIDE_MARGIN), what + ": porta avversaria fuori")
		if yaw == 0.0:
			# compagni a schermo = compagni tenuti dal calcolo, almeno 3
			var cand := 0
			var seen := 0
			for q: Vector2 in mates:
				if q.distance_to(carrier) <= CF.WIDE_R and q.y - carrier.y >= -5.0:
					cand += 1
					if in_frame(v, Vector3(q.x, 0, q.y), CF.WIDE_MARGIN) and in_frame(v, Vector3(q.x, 1.9, q.y), CF.WIDE_MARGIN):
						seen += 1
			eq(seen, int(v.used) - 1 - (1 if goal else 0), what + ": compagni tenuti = compagni a schermo")
			check(seen >= mini(3, cand), "%s: solo %d compagni a schermo su %d" % [what, seen, cand])
	return done()


func test_rallenty_largo_compagno_lontano_di_fianco_resta_fuori() -> bool:
	var v := CF.wide_view(Vector2.ZERO, 0.0, [Vector2(25, 2), Vector2(6, 18)], false, ASPECT, FOV)
	eq(v.used, 2, "portatore + il compagno davanti")
	check(in_frame(v, Vector3.ZERO, CF.WIDE_MARGIN) and in_frame(v, Vector3(6, 0, 18), CF.WIDE_MARGIN), "a schermo")
	var near_v := CF.wide_view(Vector2.ZERO, 0.0, [Vector2(2, 10)], false, ASPECT, FOV)
	var far_v := CF.wide_view(Vector2.ZERO, 0.0, [Vector2(2, 10), Vector2(-14, 16), Vector2(15, 20)], false, ASPECT, FOV)
	eq(far_v.used, 4, "tutti i compagni")
	check(far_v.t > near_v.t or far_v.fov > near_v.fov, "compagni più larghi = più lontana o più larga")
	return done()


func test_fit_view_gruppo_impossibile_saltato() -> bool:
	var v := CF.fit_view({"c0": Vector3(0, 10, -20), "yaw": 0.0, "pitch": 0.5, "aspect": ASPECT, "fov": FOV, "fovMax": 80.0,
		"tMax": 5.0, "m": CF.WIDE_MARGIN, "groups": [[Vector3.ZERO], [Vector3(200, 0, 0)], [Vector3(3, 0, 10)]]})
	same_as_js(v, fixture().fit, "fitView")
	eq(v.used, 2, "gruppi")
	check(in_frame(v, Vector3.ZERO, CF.WIDE_MARGIN) and in_frame(v, Vector3(3, 0, 10), CF.WIDE_MARGIN), "dentro")
	check(not in_frame(v, Vector3(200, 0, 0), CF.WIDE_MARGIN), "quello impossibile resta fuori")
	return done()


func test_calcio_d_angolo_dietro_il_battitore_porta_a_schermo() -> bool:
	for c: Dictionary in fixture().corner:
		var ball := Vector2(c.ball[0], c.ball[1])
		var yaw: float = c.yaw
		var v := CF.corner_view(ball, yaw, ASPECT, FOV)
		var what := "angolo da %s girata %s" % [ball, yaw]
		same_as_js(v, c.out, what)
		check(in_frame(v, Vector3(ball.x, 0, ball.y), CF.CORNER_MARGIN, 0.02) and in_frame(v, Vector3(ball.x, 2, ball.y), CF.CORNER_MARGIN, 0.02), what + ": battitore fuori")
		if yaw == 0.0:
			var gy := signf(ball.y) * HL
			var aim := Vector2(0, gy - signf(ball.y) * 9.0)
			var pos: Vector3 = v.pos
			check(Vector2(pos.x, pos.z).distance_to(aim) > ball.distance_to(aim) + 3.0, what + ": non è dietro il battitore")
			check(absf(pos.x) > 32.0 or absf(pos.z) > 50.0, what + ": non è fuori dal campo")
			for p: Vector3 in CF.goal_corners(gy, 0.0, 0.0):
				check(in_frame(v, p, CF.CORNER_MARGIN), "%s: palo %s" % [what, p])
	return done()


func test_calcio_d_angolo_girato_col_dito() -> bool:
	for turn: float in [-1.2, -0.4, 0.4, 1.2]:
		var v0 := CF.corner_view(Vector2(-32, 50), 0.0, ASPECT, FOV)
		var v := CF.corner_view(Vector2(-32, 50), turn, ASPECT, FOV)
		check(in_frame(v, Vector3(-32, 0, 50), CF.CORNER_MARGIN, 0.02) and in_frame(v, Vector3(-32, 2, 50), CF.CORNER_MARGIN, 0.02), "battitore a schermo, girata %s" % turn)
		var d := _ang(v) - _ang(v0)
		d = atan2(sin(d), cos(d))
		near(d, turn, 0.05, "girata")
	return done()


static func _ang(v: Dictionary) -> float:
	return atan2(v.look.x - v.pos.x, v.look.z - v.pos.z)
