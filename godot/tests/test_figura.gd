# Pose dei giocatori (scripts/partita/figura.gd): rotazioni procedurali attorno agli assi del corpo (calcio, tuffo),
# giochetti con la IK sullo scheletro vero (piedi e bacino dove li vuole il movimento), miscela corsa/scatto.
# Nei test la figura sta fuori dall'albero dei nodi e l'AnimationTree non gira: la posa di partenza è
# quella di legame del modello, e si controlla che ogni rotazione la porti dove deve.
extends "test_base.gd"

const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Giochetti := preload("res://scripts/partita/mosse/giochetti.gd")
const Mossa := preload("res://scripts/partita/mosse/mossa.gd")
const Coord := preload("res://scripts/coord.gd")
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


# ---------------------------------------------------------------- portiere a gioco fermo (Luis 2026-11-22: "portiere
# non realistico a braccia aperte quando rimette palla dal fondo")
class PartitaFinta:
	extends RefCounted
	var phase := "play"
	var restart: Object = null
	var goalsLog: Array = []
	var players: Array = []
	var ball: Object = null


func portiere(team: int) -> R.Player:
	var p := R.Player.new()
	p.pos = "P"
	p.team = team
	p.name = "Portiere%d" % team
	p.src = {"name": p.name}
	return p


func ripresa(m: PartitaFinta, tipo: String, team: int, chi: R.Player) -> void:
	m.phase = "restart"
	m.restart = R.Restart.new()
	m.restart.type = tipo
	m.restart.team = team
	m.restart.taker = chi


func ctx_partita(m: PartitaFinta) -> Dictionary:
	return {"t": 0.0, "phase": m.phase, "flip": 1.0, "yaw": 0.0, "ball": m.ball, "trick": null, "m": m}


func test_portiere_pronto_solo_quando_puo_arrivare_un_tiro() -> bool:
	var m := PartitaFinta.new()
	m.ball = R.Ball.new()
	var gk0 := portiere(0)
	var gk1 := portiere(1)
	check(Figura.portiere_pronto(gk0, m, "play", m.ball), "in gioco: pronto")
	check(Figura.portiere_pronto(gk0, null, "play", null), "senza partita, fase di gioco: pronto (come prima)")
	ripresa(m, "goalkick", 0, gk0)
	check(not Figura.portiere_pronto(gk0, m, "restart", m.ball), "rinvio dal fondo: chi batte sta rilassato")
	check(not Figura.portiere_pronto(gk1, m, "restart", m.ball), "rinvio dal fondo: anche l'altro portiere")
	for tipo: String in ["throw", "kickoff", "gk"]:
		ripresa(m, tipo, 0, null)
		check(not Figura.portiere_pronto(gk1, m, "restart", m.ball), "%s: niente posa pronta" % tipo)
	for tipo: String in ["penalty", "corner", "freekick"]:
		ripresa(m, tipo, 0, null)
		check(Figura.portiere_pronto(gk1, m, "restart", m.ball), "%s: chi difende è pronto" % tipo)
		check(not Figura.portiere_pronto(gk0, m, "restart", m.ball), "%s: il portiere di chi batte no" % tipo)
	for fase: String in ["goal", "half", "full"]:
		check(not Figura.portiere_pronto(gk0, m, fase, m.ball), "fase %s: rilassato" % fase)
	m.phase = "play"
	m.restart = null
	m.ball.owner = gk0
	check(not Figura.portiere_pronto(gk0, m, "play", m.ball), "col pallone tra i piedi: niente braccia aperte")
	var c := R.Player.new()
	c.pos = "C"
	check(not Figura.portiere_pronto(c, m, "play", m.ball), "solo i portieri")
	return done()


func test_rinvio_dal_fondo_il_portiere_non_apre_le_braccia() -> bool:
	var m := PartitaFinta.new()
	m.ball = R.Ball.new()
	var gk := portiere(0)
	m.players = [gk]
	var f := nuova()
	var dl := dir(f, "upperarm_l", "lowerarm_l")
	var dr := dir(f, "upperarm_r", "lowerarm_r")
	var gamba := dir(f, "thigh_l", "calf_l")
	f.posa(gk, 0.0, ctx_partita(m))   # in gioco: posa pronta, braccia e gambe girate
	check(dir(f, "upperarm_l", "lowerarm_l").distance_to(dl) > 0.3, "in gioco il portiere è pronto (braccia girate)")
	ripresa(m, "goalkick", 0, gk)
	m.ball.owner = gk
	f.posa(gk, 0.0, ctx_partita(m))
	# nel test l'AnimationTree non gira: senza pose calcolate restano solo le piccole correzioni del clip "fermo"
	check(dir(f, "upperarm_l", "lowerarm_l").distance_to(dl) < 0.1, "rinvio: braccio sinistro come nel clip")
	check(dir(f, "upperarm_r", "lowerarm_r").distance_to(dr) < 0.1, "rinvio: braccio destro come nel clip")
	check(dir(f, "thigh_l", "calf_l").distance_to(gamba) < 0.15, "rinvio: gambe non piegate")
	near(f.corpo.position.y, 0.0, 1e-4, "rinvio: corpo non abbassato")
	eq(f.mano_gk, 0.0, "rinvio: il pallone resta a terra")
	f.free()
	return done()


func test_rilancio_dalle_mani_pallone_tra_le_mani_davanti_al_petto() -> bool:
	var m := PartitaFinta.new()
	m.ball = R.Ball.new()
	var gk := portiere(0)
	m.players = [gk]
	ripresa(m, "gk", 0, gk)
	m.ball.owner = gk
	check(Figura.palla_in_mano(gk, m), "ripresa gk del proprio portiere: pallone in mano")
	check(not Figura.palla_in_mano(portiere(1), m), "l'altro portiere no")
	var f := nuova()
	f.posa(gk, 0.0, ctx_partita(m))
	eq(f.mano_gk, 1.0, "pallone tutto in mano")
	var r := Figura.PALLA_R / Coord.SCALE
	var hl: Vector3 = f.pos_corpo("hand_l")
	var hr: Vector3 = f.pos_corpo("hand_r")
	var atteso_l := Figura.MANO_PALLA + Vector3(r + Figura.MANO_POLSO.x, Figura.MANO_POLSO.y, Figura.MANO_POLSO.z)
	check(hl.distance_to(atteso_l) < 0.03, "polso sinistro %s, atteso %s" % [hl, atteso_l])
	check(hr.distance_to(atteso_l * Vector3(-1, 1, 1)) < 0.03, "polso destro %s" % hr)
	check(hl.x > r and hr.x < -r, "le mani ai lati del pallone, non dentro")
	var pm: Vector4 = f.pallone_in_mano()
	near(pm.w, 1.0, 1e-4, "peso del pallone in mano")
	check(Vector3(pm.x, pm.y, pm.z).distance_to(Figura.MANO_PALLA) < 0.03, "pallone tra le mani: %s" % pm)
	check(pm.z > 0.15 and pm.y > 0.9 and pm.y < 1.4, "davanti al petto, né ai piedi né sopra la testa")
	# calcia: il pallone torna sul vero (dolce) e le braccia le comanda di nuovo la posa del calcio
	gk.kickAnim = Figura.KICK_T
	check(not Figura.palla_in_mano(gk, m), "dopo il calcio non è più in mano")
	f.posa(gk, 0.1, ctx_partita(m))
	check(f.mano_gk < 1.0 and f.mano_gk > 0.0, "il pallone esce dalle mani dolcemente (%.2f)" % f.mano_gk)
	f.posa(gk, 1.0, ctx_partita(m))
	eq(f.mano_gk, 0.0, "poi è tornato sul pallone vero")
	f.free()
	return done()


func test_pallone_a_schermo_in_proporzione_coi_giocatori() -> bool:
	# Luis 2026-11-22: "palla leggermente troppo grande rispetto ai giocatori". Vero: 22 cm su 1,80 m (0,12);
	# a schermo un filo più grande per leggerlo da lontano, ma non più di 0,15 dell'altezza (prima 0,42 / 2,3 = 0,18)
	var vista := load("res://scripts/partita/vista.gd")
	var alto: float = Figura.MODEL_H * Coord.SCALE
	var k: float = vista.BALL_R * 2.0 / alto
	check(k > 0.12 and k < 0.15, "diametro del pallone / altezza del giocatore = %.3f" % k)
	near(vista.BALL_R, Figura.PALLA_R, 1e-6, "la vista disegna il pallone della figura (mani del portiere)")
	return done()
