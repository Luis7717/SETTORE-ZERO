# Giochetti del dribbling e IK (scripts/partita/mosse/*, porting di src/moves/*, src/ik.js, src/tricks.js):
# stessi casi di test/unit/tricks.test.mjs più il confronto, posa per posa, coi movimenti del JS
# (tests/fixtures/vista.json, da `node test/export-vista.mjs`).
extends "test_base.gd"

const Giochetti := preload("res://scripts/partita/mosse/giochetti.gd")
const Mossa := preload("res://scripts/partita/mosse/mossa.gd")
const IK := preload("res://scripts/partita/mosse/ik.gd")
const TC := preload("test_camfit.gd")
const TOL := 2e-3   # m e componenti dei quaternioni (Vector3 e Quaternion di Godot sono a 32 bit)


static func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


static func qq(a: Array) -> Quaternion:
	return Quaternion(a[0], a[1], a[2], a[3])


func close_v(a: Vector3, b: Vector3, what: String) -> void:
	check(a.distance_to(b) < TOL, "%s: %s contro %s" % [what, a, b])


# stessa rotazione (q e −q sono la stessa)
func close_q(a: Quaternion, b: Quaternion, what: String) -> void:
	check(absf(a.dot(b)) > 1.0 - TOL, "%s: %s contro %s" % [what, a, b])


func same_frame(fr: Dictionary, js: Dictionary, what: String) -> void:
	close_v(fr.pelvis.p, v3(js.pelvis), what + " bacino")
	for k: String in js.rot:
		close_q(fr.rot[k], qq(js.rot[k]), what + " " + k)
	for s: String in js.legs:
		var l: Dictionary = js.legs[s]
		close_v(fr.legs[s].ankle, v3(l.ankle), what + " caviglia " + s)
		close_q(fr.legs[s].fq, qq(l.fq), what + " piede " + s)
		close_v(fr.legs[s].pole, v3(l.pole), what + " ginocchio " + s)
		near(fr.legs[s].w, l.w, TOL, what + " peso gamba " + s)
	for s: String in js.arms:
		close_v(fr.arms[s].hand, v3(js.arms[s].hand), what + " mano " + s)
		close_v(fr.arms[s].pole, v3(js.arms[s].pole), what + " gomito " + s)
	close_v(fr.ball.p, v3(js.ball.p), what + " pallone")
	close_q(fr.ball.q, qq(js.ball.q), what + " rotazione del pallone")


func test_giochetti_stesse_pose_del_js() -> bool:
	var fx: Dictionary = TC.fixture().tricks
	for id: String in fx:
		var js: Dictionary = fx[id]
		var mv := Giochetti.trick_move(id)
		near(mv.T, js.T, 1e-6, id + ": durata")
		for f: Dictionary in js.frames:
			same_frame(mv.at(f.t), f, "%s t=%.3f" % [id, f.t])
		same_frame(Mossa.mirror_frame(mv.at(mv.T * 0.4)), js.mirror, id + " specchiato")
		for o: Dictionary in js.offs:
			var b := Giochetti.ball_offset(id, o.q)
			check(Vector3(b.x - o.f, b.y - o.s, b.z - o.h).length() < TOL * 1.25, "%s: pallone a q=%s %s contro %s" % [id, o.q, b, [o.f, o.s, o.h]])
	return done()


func test_giochetti_piu_dribbling_piu_belli() -> bool:
	var fx: Dictionary = TC.fixture()
	for a: Array in fx.best:
		eq(Giochetti.best_trick(a[0]), int(a[1]), "bestTrick(%s)" % a[0])
	for a: Array in fx.choose:
		eq(Giochetti.choose_trick(a[0], a[1]).id, a[2], "chooseTrick(%s, %s)" % [a[0], a[1]])
	eq(Giochetti.TRICKS[Giochetti.best_trick(30)].id, "finta", "dribbling scarso: solo la finta")
	eq(Giochetti.TRICKS[Giochetti.best_trick(90)].id, "arcobaleno", "dribbling da campione: arcobaleno")
	return done()


func test_giochetti_il_pallone_parte_e_torna_al_suo_posto() -> bool:
	for tk: Dictionary in Giochetti.TRICKS:
		var id: String = tk.id
		for q: float in [0.0, 1.0]:
			check(Giochetti.ball_offset(id, q).length() < 0.035, "%s a q=%s: %s" % [id, q, Giochetti.ball_offset(id, q)])
		var max_h := 0.0
		for i in 21:
			max_h = maxf(max_h, Giochetti.ball_offset(id, i / 20.0).z)
		if id == "sombrero" or id == "arcobaleno":
			check(max_h > 1.5, "%s: pallone alto %.2f m" % [id, max_h])
		var dur := Giochetti.duration(id)
		check(dur > 0.4 and dur < 2.6, "%s: durata %s" % [id, dur])
	return done()


func test_ik_a_due_ossa_come_il_js() -> bool:
	for c: Dictionary in TC.fixture().ik:
		var s := IK.two_bone(v3(c.A), v3(c.C), c.a, c.b, v3(c.pole))
		close_v(s.knee, v3(c.out.knee), "ginocchio")
		close_v(s.end, v3(c.out.end), "fine")
		close_v(s.hinge, v3(c.out.hinge), "cerniera")
		eq(s.reach, c.out.reach, "raggiungibile")
		# le ossa tengono la loro lunghezza
		near(v3(c.A).distance_to(s.knee), c.a, 1e-4, "coscia")
		near((s.knee as Vector3).distance_to(s.end), c.b, 1e-4, "gamba")
	return done()
