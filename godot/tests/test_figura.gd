# Pose dei giocatori (scripts/partita/figura.gd): rotazioni procedurali attorno agli assi del corpo (calcio, tuffo),
# giochetti con la IK sullo scheletro vero (piedi e bacino dove li vuole il movimento), miscela corsa/scatto.
# Nei test la figura sta fuori dall'albero dei nodi e l'AnimationTree non gira: la posa di partenza è
# quella di legame del modello, e si controlla che ogni rotazione la porti dove deve.
extends "test_base.gd"

const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Giochetti := preload("res://scripts/partita/mosse/giochetti.gd")
const Mossa := preload("res://scripts/partita/mosse/mossa.gd")
const KIT := {"maglia": Color.RED, "calzoncini": Color.WHITE, "calzettoni": Color.RED, "bordino": Color.WHITE}
const LOOK := {"pelle": Color.TAN, "capelli": Color.BLACK}


func nuova() -> Node3D:
	var f := Figura.new()   # fuori dall'albero dei nodi: il runner gira dentro _init, prima che l'albero parta
	f.prepara(KIT, LOOK, 0.0, TV.avviso())
	return f


func ctx() -> Dictionary:
	return {"t": 0.0, "phase": "play", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}


func dir(f: Node3D, a: String, b: String) -> Vector3:
	return (f.pos_corpo(b) - f.pos_corpo(a)).normalized()


func test_calcio_la_gamba_destra_va_avanti_attorno_all_asse_di_lato() -> bool:
	var f := nuova()
	var p := R.Player.new()
	p.pos = "C"
	var d0 := dir(f, "thigh_r", "calf_r")
	p.kickAnim = Figura.KICK_T * 0.5
	f.posa(p, 0.0, ctx())
	var atteso := Quaternion(Vector3.RIGHT, 0.5 - 1.9) * d0
	check(dir(f, "thigh_r", "calf_r").distance_to(atteso) < 0.02, "coscia destra %s, attesa %s" % [dir(f, "thigh_r", "calf_r"), atteso])
	check(dir(f, "thigh_r", "calf_r").z > 0.9, "la gamba va avanti")
	f.free()
	return done()


func test_tuffo_braccia_sopra_la_testa_corpo_di_lato_e_in_alto() -> bool:
	var f := nuova()
	var p := R.Player.new()
	p.pos = "P"
	var dl := dir(f, "upperarm_l", "lowerarm_l")
	var dr := dir(f, "upperarm_r", "lowerarm_r")
	p.state = "dive"
	p.dive = R.Dive.new()
	p.dive.tx = 3.0
	p.dive.dirx = 1.0
	p.dive.hh = 1.4
	p.t = 0.5
	f.posa(p, 0.0, ctx())
	check(dir(f, "upperarm_l", "lowerarm_l").distance_to(Quaternion(Vector3.BACK, 2.9) * dl) < 0.02, "braccio sinistro")
	check(dir(f, "upperarm_r", "lowerarm_r").distance_to(Quaternion(Vector3.BACK, -2.9) * dr) < 0.02, "braccio destro")
	near(f.corpo.rotation.z, -1.35, 1e-4, "corpo girato di lato (tuffo verso la sinistra dello schermo)")
	check(f.corpo.position.y > 0.5, "corpo sollevato: %s" % f.corpo.position.y)
	f.free()
	return done()


func test_le_pose_non_si_sommano_tra_un_fotogramma_e_l_altro() -> bool:
	var f := nuova()
	var p := R.Player.new()
	p.pos = "C"
	p.kickAnim = 0.2
	f.posa(p, 0.0, ctx())
	var a := dir(f, "thigh_r", "calf_r")
	f.posa(p, 0.0, ctx())
	check(dir(f, "thigh_r", "calf_r").distance_to(a) < 1e-4, "stessa posa due volte = stesso risultato")
	p.kickAnim = 0.0
	p.vx = 6.0
	f.posa(p, 0.0, ctx())
	f.posa(p, 0.0, ctx())
	var b := dir(f, "thigh_r", "calf_r")
	check(b.distance_to(a) > 0.3, "finito il calcio la gamba torna")
	f.free()
	return done()


func test_giochetti_piedi_e_bacino_dove_li_vuole_il_movimento() -> bool:
	var f := nuova()
	var worst := 0.0
	for tk: Dictionary in Giochetti.TRICKS:
		var mv := Giochetti.trick_move(tk.id)
		for q: float in [0.3, 0.5, 0.7]:
			for side: float in [1.0, -1.0]:
				var fr := mv.at(q * mv.T)
				if side < 0.0:
					fr = Mossa.mirror_frame(fr)
				f._rimetti()
				f._gcache.clear()
				f.applica_mossa(fr, 1.0)
				check(f.pos_corpo("pelvis").distance_to(fr.pelvis.p) < 0.01, "%s q=%s: bacino" % [tk.id, q])
				for s: String in ["l", "r"]:
					var e: float = f.pos_corpo("foot_" + s).distance_to(fr.legs[s].ankle)
					worst = maxf(worst, e)
					check(e < 0.06, "%s q=%s lato %s: caviglia %s a %.3f m dal bersaglio" % [tk.id, q, side, s, e])
	note("caviglia più lontana dal bersaglio: %.3f m (proporzioni del modello diverse da quelle del web)" % worst)
	f.free()
	return done()


func test_scatto_solo_correndo_forte_prima_se_il_motore_dice_che_scatta() -> bool:
	eq(Figura.sprint_mix(4.0, false), 0.0, "corsa normale")
	eq(Figura.sprint_mix(4.0, true), 0.0, "piano anche scattando")
	check(Figura.sprint_mix(6.0, true) > 0.4 and Figura.sprint_mix(6.0, false) == 0.0, "a 6 m/s solo chi scatta")
	eq(Figura.sprint_mix(10.0, false), 1.0, "velocissimo")
	return done()
