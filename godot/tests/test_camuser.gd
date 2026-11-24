# Visuale girata col dito (scripts/partita/camuser.gd, porting di src/camuser.js): stessi casi di
# test/unit/camuser.test.mjs (angolo che segue il dito, limiti, ritorno dolce, quando si può girare) più il confronto
# coi valori del JS (tests/fixtures/vista.json) e il portatore sempre a schermo con la visuale larga girata.
extends "test_base.gd"

const CU := preload("res://scripts/partita/camuser.gd")
const CF := preload("res://scripts/partita/camfit.gd")
const TC := preload("test_camfit.gd")
const Telecamera := preload("res://scripts/partita/telecamera_partita.gd")
const W := 390.0


func test_trascinando_tutto_lo_schermo_gira_di_150_gradi_entro_il_limite() -> bool:
	near(CU.drag_yaw(0.0, -W, W), minf(CU.CAM_USER_MAX, deg_to_rad(CU.CAM_USER_DEG_PER_SCREEN)), 1e-9, "schermo intero")
	near(CU.drag_yaw(0.0, -W / 2.0, W), deg_to_rad(CU.CAM_USER_DEG_PER_SCREEN / 2.0), 1e-9, "mezzo schermo")
	check(CU.drag_yaw(0.0, 80.0, W) < 0.0 and CU.drag_yaw(0.0, -80.0, W) > 0.0, "si afferra il campo")
	eq(CU.drag_yaw(0.0, 0.0, W), 0.0, "fermo")
	eq(CU.drag_yaw(0.0, -5.0 * W, W), CU.CAM_USER_MAX, "limite +")
	eq(CU.drag_yaw(0.0, 5.0 * W, W), -CU.CAM_USER_MAX, "limite −")
	near(CU.CAM_USER_MAX, deg_to_rad(100.0), 1e-9, "limite a 100°")
	return done()


func test_il_gesto_parte_solo_di_lato_e_abbastanza_lungo() -> bool:
	eq(CU.is_cam_drag(CU.CAM_USER_START - 1.0, 0.0), false, "tocco")
	eq(CU.is_cam_drag(CU.CAM_USER_START, 0.0), true, "soglia")
	eq(CU.is_cam_drag(-40.0, 10.0), true, "di lato")
	eq(CU.is_cam_drag(20.0, 40.0), false, "più in verticale")
	return done()


func test_nel_rallenty_l_angolo_resta_poi_torna_dolcemente() -> bool:
	eq(CU.relax_yaw(0.8, true, 0.1), 0.8, "resta")
	eq(CU.relax_yaw(5.0, true, 0.1), CU.CAM_USER_MAX, "limitato")
	var y := 1.2
	var prev := y
	var t := 0.0
	while y != 0.0 and t < 5.0:
		y = CU.relax_yaw(y, false, 1.0 / 60.0)
		check(absf(y) <= absf(prev), "mai più girata di prima")
		prev = y
		t += 1.0 / 60.0
	eq(y, 0.0, "torna a 0")
	check(t > 0.8 and t < 3.5, "ritorno in %.2f s" % t)
	check(CU.relax_yaw(1.2, false, 0.1) > 0.8, "niente scatto")
	return done()


func test_stessi_valori_del_js() -> bool:
	var fx: Dictionary = TC.fixture().camuser
	for a: Array in fx.drag:
		near(CU.drag_yaw(a[0], a[1], a[2]), a[3], 1e-9, "dragYaw %s" % [a])
	for a: Array in fx.relax:
		near(CU.relax_yaw(a[0], a[1], a[2]), a[3], 1e-9, "relaxYaw %s" % [a])
	for a: Array in fx.keep:
		eq(CU.keep_goal(a[0], a[1]), a[2], "keepGoal %s" % [a])
	for a: Array in fx.isDrag:
		eq(CU.is_cam_drag(a[0], a[1]), a[2], "isCamDrag %s" % [a])
	return done()


func test_si_gira_solo_in_gioco_col_pallone_nostro_nel_duello_o_area_di_tiro_e_sul_calcio_d_angolo() -> bool:
	var m := H.scene(1, [true, false])
	var c: R.Player = m.players[9]
	H.wake(c, 0.0, 0.0)
	H.give(m, c)
	m.ctrl[0] = c
	eq(CU.user_cam_on(m, 0), false, "fuori dal rallenty")
	var d := R.Duel.new()
	d.team = 0
	d.p = c
	d.o = m.players[14]
	m.duel = d
	eq(CU.user_cam_on(m, 0), true, "duello")
	eq(CU.user_cam_on(m, 1), false, "pallone dell'altra squadra")
	m.duel = null
	H.wake(c, 0.0, 38.0)
	H.give(m, c)
	eq(CU.user_cam_on(m, 0), true, "area di tiro")
	m.phase = "restart"
	var r := R.Restart.new()
	r.type = "corner"
	r.team = 1
	m.restart = r
	eq(CU.corner_cam_on(m), true, "calcio d'angolo")
	eq(CU.user_cam_on(m, 0), true, "calcio d'angolo di chiunque")
	for t: String in ["throw", "free", "goalkick", "penalty"]:
		r.type = t
		eq(CU.user_cam_on(m, 0), false, "rimessa " + t)
	eq(CU.user_cam_on(null, 0), false, "senza partita")
	return done()


# gioco normale col pallone (Luis 2026-11-24): la visuale si gira anche fuori dal rallenty; resta finché lo stesso
# portatore ha il pallone, dopo un passaggio a un compagno ancora CAM_USER_PASS_HOLD s, perso il possesso torna dritta
func test_col_pallone_in_gioco_la_visuale_si_gira_e_resta_finche_il_possesso_e_nostro() -> bool:
	var m := H.scene(1, [true, false])
	var c: R.Player = m.players[9]
	var q: R.Player = m.players[10]
	H.wake(c, 0.0, 0.0)
	H.wake(q, -12.0, 10.0)
	H.give(m, c)
	m.ctrl[0] = c
	eq(CU.user_cam_on(m, 0), false, "niente rallenty")
	eq(CU.ball_cam_on(m, 0), true, "pallone nostro in gioco")
	eq(CU.drag_cam_on(m, 0), true, "si gira col dito")
	eq(CU.ball_cam_on(m, 1), false, "non per l'altra squadra")
	eq(CU.drag_cam_on(m, 1), false, "... nemmeno col dito")
	eq(CU.ball_cam_on(null, 0), false, "senza partita")
	# stesso portatore: resta sempre
	check(CU.hold_yaw(m, 0, true, 99.0), "stesso portatore: resta")
	check(not CU.hold_yaw(m, 0, false, CU.CAM_USER_PASS_HOLD + 0.1), "portatore diverso da troppo: torna")
	# passaggio in volo: possesso nostro, resta per CAM_USER_PASS_HOLD
	m.kick(c, {"type": "pass", "tx": q.x, "ty": q.y})
	check(m.ball.owner == null and m.ball.kick != null, "pallone in volo")
	eq(CU.possesso(m, 0), true, "il nostro passaggio in volo è possesso nostro")
	eq(CU.drag_cam_on(m, 0), false, "in volo non si gira (nessun portatore)")
	check(CU.hold_yaw(m, 0, false, 1.0), "dopo il passaggio resta")
	check(not CU.hold_yaw(m, 0, false, CU.CAM_USER_PASS_HOLD), "poi torna dritta")
	# arrivato al compagno: ancora possesso nostro
	H.give(m, q)
	check(CU.hold_yaw(m, 0, false, CU.CAM_USER_PASS_HOLD * 0.5), "al compagno resta ancora un po'")
	# possesso perso: torna subito
	H.give(m, m.players[14])
	eq(CU.possesso(m, 0), false, "pallone avversario")
	check(not CU.hold_yaw(m, 0, false, 0.0), "possesso perso: torna dritta")
	check(not CU.hold_yaw(m, 0, true, 0.0), "anche se era lo stesso giocatore")
	# il nostro tiro non è possesso
	H.give(m, c)
	m.kick(c, {"type": "shot", "tx": 0.0, "ty": C.HL, "th": 1.0})
	eq(CU.possesso(m, 0), false, "tiro in volo: non conta")
	m.phase = "restart"
	eq(CU.possesso(m, 0), false, "fuori dal gioco: no")
	return done()


# la telecamera vera, in gioco normale (niente visuale larga): girata di yaw intorno al portatore, che resta davanti
func test_telecamera_in_gioco_normale_gira_intorno_al_portatore() -> bool:
	var m := H.scene(1, [true, false])
	var c: R.Player = m.players[9]
	H.wake(c, 5.0, -10.0)
	H.give(m, c)
	m.ctrl[0] = c
	var cam: Camera3D = Telecamera.new() # fuori dall'albero: schermo dell'iPhone in verticale
	cam.reset(m.ball.x, m.ball.y)
	for i in 90:
		cam.aggiorna(m, 0, DT, DT, false, false, 0.0)
	var f0 := -cam.transform.basis.z
	for yaw: float in [0.9, -0.9, CU.CAM_USER_MAX]:
		cam.aggiorna(m, 0, DT, DT, false, true, yaw)
		var f1 := -cam.transform.basis.z
		var a0 := Vector2(f0.x, -f0.z) # direzione orizzontale nelle coordinate del motore
		var a1 := Vector2(f1.x, -f1.z)
		near(a0.angle_to(a1), -yaw, 0.03, "girata di %.2f rad (+ = guarda a destra, verso +x)" % yaw)
		var loc := cam.transform.affine_inverse() * Vector3(c.x, 1.0, -c.y)
		var mezzo := tan(deg_to_rad(cam.fov / 2.0)) * 390.0 / 844.0
		check(loc.z < 0.0 and absf(loc.x / -loc.z) < mezzo, "portatore a schermo con la visuale girata di %.2f" % yaw)
	cam.free()
	m.dispose()
	return done()


func test_area_di_tiro_porta_a_schermo_solo_con_visuale_poco_girata() -> bool:
	eq(CU.keep_goal(true, 0.0), true, "dritta")
	eq(CU.keep_goal(true, CU.CAM_USER_GOAL_YAW * 0.9), true, "poco girata")
	eq(CU.keep_goal(true, -CU.CAM_USER_GOAL_YAW * 1.1), false, "girata")
	eq(CU.keep_goal(false, 0.0), false, "fuori dall'area")
	return done()


func test_visuale_larga_girata_il_portatore_resta_a_schermo() -> bool:
	for deg: float in [-100.0, -60.0, -30.0, 0.0, 30.0, 60.0, 100.0]:
		for zone: bool in [false, true]:
			var yaw := deg_to_rad(deg)
			var carrier := Vector2(6, 34) if zone else Vector2(-10, 0)
			var mates := [carrier + Vector2(-20, 4), carrier + Vector2(18, 2), carrier + Vector2(4, 12)]
			var v := CF.wide_view(carrier, yaw, mates, CU.keep_goal(zone, yaw), 390.0 / 844.0, 70.0)
			check(v.ok, "inquadratura impossibile a %s°" % deg)
			check(TC.in_frame(v, Vector3(carrier.x, 0, carrier.y), CF.WIDE_MARGIN) and TC.in_frame(v, Vector3(carrier.x, 2.3, carrier.y), CF.WIDE_MARGIN),
				"portatore fuori a %s° (%s)" % [deg, "area" if zone else "duello"])
	return done()
