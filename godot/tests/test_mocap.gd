# Animazioni mocap (assets/mocap/mocap.res, fatte da tools/converti_mocap.gd; usate da scripts/partita/figura_mocap.gd):
# la libreria si carica, le tracce puntano a ossa vere del modello, il bacino non si sposta in orizzontale, il contatto
# del calcio è dove il piede va più veloce, e la figura sceglie la clip giusta e la fa partire dal punto giusto.
# Come in test_figura.gd la figura sta fuori dall'albero dei nodi: si controllano le scelte (clip, tempo, peso),
# non lo scheletro mosso dall'AnimationTree (quello si guarda nelle schermate di prova_vista).
extends "test_base.gd"

const FM := preload("res://scripts/partita/figura_mocap.gd")
const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const MODELLO := preload("res://assets/models/athlete.glb")
const KIT := {"maglia": Color.RED, "calzoncini": Color.WHITE, "calzettoni": Color.RED, "bordino": Color.WHITE}
const LOOK := {"pelle": Color.TAN, "capelli": Color.BLACK}
const USATE := ["piatto_dx", "piatto_sx", "collo_dx", "collo_sx", "rigore1_dx", "rigore1_sx", "rigore2_dx",
	"rigore2_sx", "rimessa", "esulta1", "esulta2", "esulta3", "parata_alta_sx", "parata_alta_dx", "parata_media_sx",
	"parata_media_dx", "parata_bassa_sx", "parata_bassa_dx", "difesa1", "difesa2"]
const PRONTE := ["palleggio1", "palleggio2", "palleggio3", "giallo", "giallo_rosso"]
const MAX_FILE := 20 * 1024 * 1024
const PASSO := 1.0 / 30.0


# partita finta: solo i campi che figura_mocap legge
class PartitaFinta:
	extends RefCounted
	var phase := "play"
	var restart: Object = null
	var goalsLog: Array = []
	var players: Array = []
	var ball: Object = null


func giocatore(team: int, i: int, x: float, y: float) -> R.Player:
	var p := R.Player.new()
	p.team = team
	p.i = i
	p.name = "G%d_%d" % [team, i]
	p.pos = "C"
	p.x = x
	p.y = y
	p.fx = 0.0
	p.fy = 1.0
	p.src = {"name": p.name}
	return p


func nuova() -> Node3D:
	var f := Figura.new()
	f.prepara(KIT, LOOK, 0.0, TV.avviso())
	return f


func ctx(m: PartitaFinta) -> Dictionary:
	return {"t": 0.0, "phase": m.phase, "flip": 1.0, "yaw": 0.0, "ball": m.ball, "trick": null, "m": m}


func partita() -> PartitaFinta:
	var m := PartitaFinta.new()
	m.ball = R.Ball.new()
	return m


# scheletro del modello in posa a T (per rifare i conti delle clip)
func scheletro() -> Skeleton3D:
	var r := MODELLO.instantiate()
	var sk := r.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	sk.get_parent().remove_child(sk)   # lo si tiene da solo; il resto del modello si libera
	sk.owner = null
	for c in sk.get_children():
		sk.remove_child(c)
		c.free()
	r.free()
	return sk


# posizione di un osso (spazio dello scheletro) all'istante t della clip, rifatta dalle tracce
func pos_osso(sk: Skeleton3D, an: Animation, osso: String, t: float) -> Vector3:
	var catena: Array[int] = []
	var b := sk.find_bone(osso)
	while b >= 0:
		catena.push_front(b)
		b = sk.get_bone_parent(b)
	var g := Transform3D.IDENTITY
	for k in catena:
		var nome := sk.get_bone_name(k)
		var rest := sk.get_bone_rest(k)
		var q := rest.basis.get_rotation_quaternion()
		var o := rest.origin
		var tr := an.find_track(NodePath("Armature/Skeleton3D:" + nome), Animation.TYPE_ROTATION_3D)
		if tr >= 0:
			q = an.rotation_track_interpolate(tr, t)
		var tp := an.find_track(NodePath("Armature/Skeleton3D:" + nome), Animation.TYPE_POSITION_3D)
		if tp >= 0:
			o = an.position_track_interpolate(tp, t)
		g = g * Transform3D(Basis(q), o)
	return g.origin


# ---------------------------------------------------------------- libreria
func test_le_clip_si_caricano_compresse_e_piccole() -> bool:
	var lib := FM.libreria()
	if not check(lib != null, "libreria mocap non caricata"):
		return done()
	for n: String in USATE + PRONTE:
		if check(lib.has_animation(n), "manca la clip " + n):
			var an := lib.get_animation(n)
			check(an.length > 0.8, "%s troppo corta: %s" % [n, an.length])
			check(an.is_capture_included() == false, n)
			check(an.get_track_count() > 0 and an.track_is_compressed(0), "%s non è compressa" % n)
	check(not lib.has_animation("dribbling1"), "le clip di dribbling non usate non vanno nell'app")
	var size := FileAccess.get_file_as_bytes(FM.LIB_PATH).size()
	check(size > 0 and size < MAX_FILE, "file troppo grande: %d" % size)
	note("mocap.res: %.1f KB, %d clip" % [size / 1024.0, lib.get_animation_list().size()])
	eq(FM.info("rimessa").get("tipo"), "rimessa", "dati della rimessa")
	check(float(FM.info("piatto_dx").get("contatto", -1.0)) > 0.2, "contatto del piatto misurato")
	eq(lib.get_animation("difesa1").loop_mode, Animation.LOOP_LINEAR, "la difesa gira in loop")
	eq(lib.get_animation("esulta1").loop_mode, Animation.LOOP_NONE, "l'esultanza no")
	return done()


func test_le_tracce_puntano_a_ossa_vere_del_modello() -> bool:
	var sk := scheletro()
	var lib := FM.libreria()
	for n: String in lib.get_animation_list():
		var an := lib.get_animation(n)
		var ossa := {}
		for t in an.get_track_count():
			var path := String(an.track_get_path(t))
			check(path.begins_with("Armature/Skeleton3D:"), "%s: percorso %s" % [n, path])
			var osso := path.get_slice(":", 1)
			check(sk.find_bone(osso) >= 0, "%s: osso %s non esiste nel modello" % [n, osso])
			if an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				ossa[osso] = true
		for i in sk.get_bone_count():
			check(ossa.has(sk.get_bone_name(i)), "%s: manca la rotazione di %s" % [n, sk.get_bone_name(i)])
		check(an.find_track(NodePath("Armature/Skeleton3D:pelvis"), Animation.TYPE_POSITION_3D) >= 0, n + ": posizione del bacino")
	sk.free()
	return done()


func test_il_bacino_non_si_sposta_in_orizzontale_ma_tiene_l_altezza() -> bool:
	var sk := scheletro()
	var piedi := (sk.get_bone_global_rest(sk.find_bone("foot_l")).origin + sk.get_bone_global_rest(sk.find_bone("foot_r")).origin) * 0.5
	var su := (sk.get_bone_global_rest(sk.find_bone("Head")).origin - piedi).normalized()   # come il convertitore
	# la traccia del bacino è nel riferimento del padre (la radice): "su" va portato lì
	var padre := sk.get_bone_global_rest(sk.get_bone_parent(sk.find_bone("pelvis")))
	su = (padre.basis.inverse() * su).normalized()
	var lib := FM.libreria()
	var peggio := 0.0
	for n: String in lib.get_animation_list():
		var an := lib.get_animation(n)
		var tp := an.find_track(NodePath("Armature/Skeleton3D:pelvis"), Animation.TYPE_POSITION_3D)
		var p0 := an.position_track_interpolate(tp, 0.0)
		var hmin := INF
		var hmax := -INF
		var t := 0.0
		while t <= an.length:
			var d := an.position_track_interpolate(tp, t) - p0
			var oriz := (d - su * d.dot(su)).length()
			peggio = maxf(peggio, oriz)
			hmin = minf(hmin, d.dot(su))
			hmax = maxf(hmax, d.dot(su))
			t += PASSO
		if n == "esulta1":
			check(hmax - hmin > 0.3, "esulta1 (in ginocchio): il bacino deve scendere, varia di %s" % (hmax - hmin))
	check(peggio < 0.01, "il bacino si sposta in orizzontale di %s m" % peggio)
	note("spostamento orizzontale massimo del bacino: %.4f m" % peggio)
	sk.free()
	return done()


func test_il_contatto_del_calcio_e_dove_il_piede_va_piu_veloce() -> bool:
	var sk := scheletro()
	var lib := FM.libreria()
	for n: String in ["piatto_dx", "piatto_sx", "collo_dx", "collo_sx", "rigore1_dx", "rigore2_sx"]:
		var an := lib.get_animation(n)
		var inf := FM.info(n)
		var osso: String = "ball_r" if inf.piede == "dx" else "ball_l"
		var tc: float = inf.contatto
		var best := -1.0
		var tbest := 0.0
		var t := PASSO
		while t < an.length - PASSO:
			var v := (pos_osso(sk, an, osso, t + PASSO) - pos_osso(sk, an, osso, t - PASSO)).length() / (2.0 * PASSO)
			if v > best and (pos_osso(sk, an, osso, t)).y < 0.35:
				best = v
				tbest = t
			t += PASSO
		near(tbest, tc, PASSO * 1.5, "%s: contatto" % n)
		# al contatto il piede che calcia va in avanti (+Z del corpo = punta del piede in posa a T)
		var avanti := sk.get_bone_global_rest(sk.find_bone("ball_r")).origin - sk.get_bone_global_rest(sk.find_bone("foot_r")).origin
		avanti.y = 0.0
		var vel := pos_osso(sk, an, osso, tc + PASSO) - pos_osso(sk, an, osso, tc - PASSO)
		vel.y = 0.0
		check(vel.normalized().dot(avanti.normalized()) > 0.8, "%s: il piede al contatto va avanti (%s)" % [n, vel.normalized().dot(avanti.normalized())])
	sk.free()
	return done()


# ---------------------------------------------------------------- scelte in partita
func test_calcio_la_clip_parte_dal_contatto_quando_il_motore_calcia() -> bool:
	var f := nuova()
	var m := partita()
	var p := giocatore(0, 7, 0.0, 0.0)
	m.players = [p]
	f.posa(p, 1.0 / 60.0, ctx(m))
	eq(f.mocap.clip, "", "nessuna clip prima del calcio")
	# passaggio a terra verso destra: il motore mette kickAnim = 0,35 e la velocità del pallone
	m.ball.kick = R.Kick.make(0, p, "ground")
	m.ball.vx = 12.0
	m.ball.vy = 12.0
	m.ball.x = 0.4
	m.ball.y = 0.6
	p.kickAnim = 0.35
	f.posa(p, 1.0 / 60.0, ctx(m))
	var s: Dictionary = f.mocap.stato()
	eq(s.clip, "piatto_dx", "passaggio a terra = piatto (destro)")
	near(s.t, float(FM.info("piatto_dx").contatto), 1e-6, "la clip è sul fotogramma del contatto")
	check(s.peso > 0.2, "la clip entra subito: peso %s" % s.peso)
	check(f.mocap.al_posto_delle_pose(), "niente pose calcolate sopra")
	near(s.yaw, -PI / 4.0, 1e-4, "il corpo si gira verso il pallone (45° a destra)")
	# col rallenty il tempo della clip avanza col tempo di gioco
	p.kickAnim -= 0.01
	f.posa(p, 0.01, ctx(m))
	near(f.mocap.stato().t, float(FM.info("piatto_dx").contatto) + 0.01, 1e-5, "avanza di dt di gioco")
	# tiro
	p.kickAnim = 0.0
	f.posa(p, 0.3, ctx(m))
	m.ball.kick = R.Kick.make(0, p, "shot")
	p.kickAnim = 0.35
	f.posa(p, 1.0 / 60.0, ctx(m))
	var c: String = f.mocap.clip
	check(c.begins_with("collo_") or c.begins_with("rigore"), "tiro = collo pieno o rigore: %s" % c)
	f.free()
	return done()


func test_colpo_di_testa_resta_calcolato() -> bool:
	var f := nuova()
	var m := partita()
	var p := giocatore(0, 7, 0.0, 0.0)
	m.ball.h = 1.8
	m.ball.x = 0.3
	m.ball.kick = R.Kick.make(0, p, "shot")
	f.posa(p, 1.0 / 60.0, ctx(m))
	p.kickAnim = 0.35
	f.posa(p, 1.0 / 60.0, ctx(m))
	eq(f.mocap.clip, "", "colpo di testa: nessuna clip")
	f.free()
	return done()


func test_rimessa_presa_poi_rilascio_col_pallone_in_mano() -> bool:
	var f := nuova()
	var m := partita()
	var p := giocatore(0, 3, 32.0, 10.0)
	m.players = [p]
	m.phase = "restart"
	var r := R.Restart.new()
	r.type = "throw"
	r.taker = p
	m.restart = r
	for i in 90:   # 1,5 s col pallone in mano
		f.posa(p, 1.0 / 60.0, ctx(m))
	eq(f.mocap.tipo, "presa", "il battitore aspetta col pallone sopra la testa")
	var inf := FM.info("rimessa")
	check(f.mocap.t >= float(inf.presa_da) - 0.05 and f.mocap.t <= float(inf.presa_a) + 0.05, "nel tratto della presa: %s" % f.mocap.t)
	check(f.mocap.pallone_in_mano().w > 0.99, "pallone tra le mani")
	# il motore lancia: fase di gioco, kickAnim
	m.phase = "play"
	m.restart = null
	m.ball.kick = R.Kick.make(0, p, "ground")
	p.kickAnim = 0.35
	f.posa(p, 1.0 / 60.0, ctx(m))
	eq(f.mocap.clip, "rimessa", "lancio")
	near(f.mocap.t, float(inf.contatto), 1e-6, "dal rilascio")
	for i in 40:
		f.posa(p, 1.0 / 60.0, ctx(m))
	check(f.mocap.pallone_in_mano().w < 0.01, "dopo il lancio il pallone torna quello vero")
	f.free()
	return done()


func test_parata_mocap_solo_se_lato_e_altezza_combaciano() -> bool:
	var f := nuova()
	var m := partita()
	var p := giocatore(0, 0, 0.0, -49.0)
	p.pos = "P"
	f.posa(p, 1.0 / 60.0, ctx(m))
	# tuffo basso e corto verso x positiva: il portiere guarda +y, quindi va alla sua destra
	p.state = "dive"
	p.dive = R.Dive.new()
	p.dive.x0 = 0.0
	p.dive.tx = 0.8
	p.dive.th = 0.4
	p.dive.dirx = 1.0
	f.posa(p, 1.0 / 60.0, ctx(m))
	eq(f.mocap.clip, "parata_bassa_dx", "tuffo basso a destra")
	var inf := FM.info("parata_bassa_dx")
	near(f.mocap.t, FM.inizio_parata(inf), 1e-6, "parte poco prima dello slancio")
	check(f.mocap.t >= float(inf.stacco) - FM.TUFFO_ANTICIPO and f.mocap.t < float(inf.contatto), "tra stacco e punto più lontano")
	# finito il tuffo la clip esce
	p.state = "play"
	p.dive = null
	f.posa(p, 1.0 / 60.0, ctx(m))
	eq(f.mocap.stato().bersaglio, 0.0, "a tuffo finito la clip esce")
	# tuffo lungo e a mezza altezza (nessuna clip lo somiglia): resta il tuffo calcolato
	var f2 := nuova()
	f2.posa(p, 1.0 / 60.0, ctx(m))
	p.state = "dive"
	p.dive = R.Dive.new()
	p.dive.tx = -4.0
	p.dive.th = 1.0
	p.dive.dirx = -1.0
	p.t = 0.3
	f2.posa(p, 1.0 / 60.0, ctx(m))
	eq(f2.mocap.clip, "", "tuffo lungo: posa calcolata")
	check(f2.corpo.rotation.z != 0.0, "il tuffo calcolato gira il corpo")
	# tuffo alto e di lato verso sinistra: parata alta a sinistra
	var f3 := nuova()
	p.state = "play"
	f3.posa(p, 1.0 / 60.0, ctx(m))
	p.state = "dive"
	p.dive = R.Dive.new()
	p.dive.tx = -1.6
	p.dive.th = 2.1
	p.dive.dirx = -1.0
	f3.posa(p, 1.0 / 60.0, ctx(m))
	eq(f3.mocap.clip, "parata_alta_sx", "tuffo alto a sinistra")
	f.free()
	f2.free()
	f3.free()
	return done()


func test_esultano_il_marcatore_e_i_compagni_vicini_sempre_uguale() -> bool:
	var m := partita()
	m.phase = "goal"
	var marc := giocatore(0, 9, 2.0, 40.0)
	var vicino := giocatore(0, 8, 6.0, 38.0)
	var lontano := giocatore(0, 2, 0.0, -10.0)
	var avversario := giocatore(1, 4, 3.0, 41.0)
	m.players = [marc, vicino, lontano, avversario]
	for q: R.Player in m.players:
		q.cele = 1 if q.team == 0 else -1
	m.goalsLog = [{"team": 0, "name": marc.name, "minute": 33, "scorer": marc.src}]
	var scelte := []
	for giro in 2:
		var clip := {}
		for q: R.Player in m.players:
			var f := nuova()
			f.posa(q, 1.0 / 60.0, ctx(m))
			clip[q.name] = f.mocap.clip
			f.free()
		scelte.append(clip)
	var c: Dictionary = scelte[0]
	check(String(c[marc.name]).begins_with("esulta"), "il marcatore esulta: %s" % c[marc.name])
	check(String(c[vicino.name]).begins_with("esulta"), "il compagno vicino esulta: %s" % c[vicino.name])
	eq(c[lontano.name], "", "il compagno lontano no (esultanza calcolata)")
	eq(c[avversario.name], "", "gli avversari no")
	eq(scelte[1], scelte[0], "stessa partita, stesse esultanze")
	return done()


func test_difesa_vicino_al_portatore_e_piano() -> bool:
	var m := partita()
	var att := giocatore(1, 9, 0.0, 3.0)
	att.fy = -1.0
	m.ball.owner = att
	var dif := giocatore(0, 4, 0.0, 0.0)
	m.players = [att, dif]
	var f := nuova()
	for i in 30:
		f.posa(dif, 1.0 / 60.0, ctx(m))
	check(String(f.mocap.clip).begins_with("difesa"), "chi marca da vicino: clip di difesa (%s)" % f.mocap.clip)
	check(f.mocap.peso > 0.5, "peso alto da fermo: %s" % f.mocap.peso)
	dif.vx = 0.0
	dif.vy = 5.0   # corre forte: si vede la corsa
	for i in 30:
		f.posa(dif, 1.0 / 60.0, ctx(m))
	check(f.mocap.peso < 0.05, "di corsa la difesa sparisce: %s" % f.mocap.peso)
	f.free()
	return done()


func test_senza_mocap_tornano_le_pose_calcolate() -> bool:
	FM.spento = true
	var f := nuova()
	var m := partita()
	var p := giocatore(0, 7, 0.0, 0.0)
	m.ball.kick = R.Kick.make(0, p, "ground")
	p.kickAnim = 0.35
	f.posa(p, 1.0 / 60.0, ctx(m))
	FM.spento = false
	eq(f.mocap.clip, "", "spento: nessuna clip")
	check(not f.mocap.al_posto_delle_pose(), "spento: pose calcolate")
	f.free()
	return done()
