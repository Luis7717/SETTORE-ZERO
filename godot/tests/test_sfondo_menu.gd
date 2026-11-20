# Sfondo del menu (scripts/menu/routine_menu.gd, porting di src/menu-routine.js, con palleggi, giochetti del menu e
# tiro di scripts/partita/mosse/*): gli stessi casi di test/unit/menu-routine.test.mjs più il confronto, istante per
# istante, con la sequenza del JS (tests/fixtures/menu.json, da `node test/export-menu.mjs`).
extends "test_base.gd"

const Routine := preload("res://scripts/menu/routine_menu.gd")
const Giochetti := preload("res://scripts/partita/mosse/giochetti.gd")
const Palleggi := preload("res://scripts/partita/mosse/palleggi.gd")
const TM := preload("test_mosse.gd")
const TOL := 2e-3            # m e componenti dei quaternioni (Vector3 e Quaternion di Godot sono a 32 bit)
const BALL_Q_TOL := 0.02     # rotazione del pallone: integrata in migliaia di passi a 32 bit, scarta di più
const COSTO_MAX_MS := 1.0    # una posa della sequenza (a ogni fotogramma del menu) deve costare meno di così

static var _fx := {}


static func fixture() -> Dictionary:
	if _fx.is_empty():
		_fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/menu.json"))
	return _fx


func test_un_giro_palleggi_giochetto_corsa_tiro_pallone_nuovo() -> bool:
	# Arrange
	var seen: Array[String] = []
	# Act
	var t := 0.0
	while t < Routine.cycle_length(0):
		var s: String = Routine.at(t).seg
		if seen.is_empty() or seen[-1] != s:
			seen.append(s)
		t += 0.05
	# Assert
	eq(seen, ["juggle", "trick", "run", "shot", "rest"] as Array[String], "sequenza di un giro")
	var j := Routine.juggle_time()
	eq(Routine.at(j + 0.1).trick.id, Giochetti.TRICKS[0].id, "primo giro: primo giochetto")
	eq(Routine.at(Routine.cycle_length(0) + j + 0.1).trick.id, Giochetti.TRICKS[1].id, "secondo giro: il giochetto dopo")
	var t0 := 0.0
	for k in Giochetti.TRICKS.size():
		t0 += Routine.cycle_length(k)
	eq(Routine.at(t0 + j + 0.1).trick.id, Giochetti.TRICKS[0].id, "dopo tutti i giochetti si ricomincia")
	return done()


func test_palleggi_posa_calcolata_e_pallone_che_sale_e_scende() -> bool:
	var lo := 9.0
	var hi := 0.0
	var t := 1.5
	while t < Routine.juggle_time() - 1.5:
		var s := Routine.at(t)
		check(s.frame != null and s.w == 1.0, "t=%.2f: posa calcolata a pieno peso" % t)
		var y: float = (s.ball.p as Vector3).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		t += 0.05
	check(lo < 0.45 and hi > 0.9, "pallone fra %.2f e %.2f m" % [lo, hi])
	return done()


func test_corsa_col_clip_tiro_che_manda_via_il_pallone_che_poi_sparisce() -> bool:
	var run: Variant = null
	var gone := false
	var fast := 0.0
	var t := Routine.juggle_time()
	while t < Routine.cycle_length(0):
		var s := Routine.at(t)
		if s.seg == "run" and s.w == 0.0:
			run = s
		if s.seg == "shot":
			fast = maxf(fast, (s.ball.p as Vector3).z)
			if not s.ball.vis:
				gone = true
		t += 0.02
	check(run != null and run.vx > 5.0 and run.frame == null, "corsa del clip senza posa calcolata")
	check(fast > 10.0, "il tiro manda il pallone lontano (%.1f m)" % fast)
	check(gone, "il pallone lontano sparisce")
	return done()


func test_mai_numeri_sbagliati_pallone_mai_sotto_terra() -> bool:
	var t := 0.0
	while t < 120.0:
		var s := Routine.at(t)
		var b: Dictionary = s.ball
		var p: Vector3 = b.p
		var q: Quaternion = b.q
		for v: float in [p.x, p.y, p.z, q.x, q.y, q.z, q.w, s.vx, s.w]:
			if not is_finite(v):
				check(false, "t=%.3f: numero non finito" % t)
		check(p.y >= Palleggi.BALL_R - 1e-4, "t=%.3f h=%.4f" % [t, p.y])
		t += 0.037
	return done()


func test_stessa_sequenza_del_js() -> bool:
	var fx := fixture()
	near(Routine.juggle_time(), fx.juggleTime, 1e-5, "durata dei palleggi")
	for k in Giochetti.TRICKS.size():
		near(Routine.cycle_length(k), fx.cycles[k], 1e-4, "giro %d" % k)
	for tk: Dictionary in Giochetti.TRICKS:
		near(Giochetti.trick_move(tk.id, Giochetti.MENU_OPT).T, fx.moves.tricks[tk.id].T, 1e-5, tk.id + " (menu): durata")
	var tc: Array = Routine.moves().juggle.touches
	eq(tc.size(), fx.moves.juggle.touches.size(), "tocchi dei palleggi")
	for i in mini(tc.size(), fx.moves.juggle.touches.size()):
		var js: Dictionary = fx.moves.juggle.touches[i]
		near(tc[i].t, js.t, 1e-4, "tocco %d (%s)" % [i, js.part])
		eq(tc[i].part, js.part, "tocco %d: parte" % i)
	var tm := TM.new()
	for s: Dictionary in fx.samples:
		var g := Routine.at(s.t)
		var what := "t=%.2f %s" % [s.t, s.seg]
		eq(g.seg, s.seg, what + " segmento")
		eq(g.cycle, int(s.cycle), what + " giro")
		near(g.w, s.w, TOL, what + " peso")
		near(g.vx, s.vx, 1e-6, what + " corsa")
		check((g.ball.p as Vector3).distance_to(TM.v3(s.ball.p)) < TOL, "%s pallone %s contro %s" % [what, g.ball.p, s.ball.p])
		check(absf((g.ball.q as Quaternion).dot(TM.qq(s.ball.q))) > 1.0 - BALL_Q_TOL, "%s rotazione del pallone" % what)
		eq(g.ball.vis, s.ball.vis, what + " pallone visibile")
		if s.trick != null:
			eq(g.trick.id, s.trick.id, what + " giochetto")
		check((g.frame == null) == (s.frame == null), what + " posa calcolata sì/no")
		if g.frame != null and s.frame != null:
			_stessa_posa(tm, g.frame, s.frame, what)
	for f: String in tm.failures:
		failures.append(f)
	return done()


# come TM.same_frame, ma la rotazione del pallone con la sua tolleranza (qui il pallone si controlla a parte)
func _stessa_posa(tm, fr: Dictionary, js: Dictionary, what: String) -> void:
	tm.close_v(fr.pelvis.p, TM.v3(js.pelvis), what + " bacino")
	for k: String in js.rot:
		tm.close_q(fr.rot[k], TM.qq(js.rot[k]), what + " " + k)
	for s: String in js.legs:
		var l: Dictionary = js.legs[s]
		tm.close_v(fr.legs[s].ankle, TM.v3(l.ankle), what + " caviglia " + s)
		tm.close_q(fr.legs[s].fq, TM.qq(l.fq), what + " piede " + s)
		tm.close_v(fr.legs[s].pole, TM.v3(l.pole), what + " ginocchio " + s)
	for s: String in js.arms:
		tm.close_v(fr.arms[s].hand, TM.v3(js.arms[s].hand), what + " mano " + s)
		tm.close_v(fr.arms[s].pole, TM.v3(js.arms[s].pole), what + " gomito " + s)


func test_una_posa_costa_poco() -> bool:
	Routine.moves() # costruzione a parte (una volta all'avvio)
	var n := 600
	var t0 := Time.get_ticks_usec()
	for i in n:
		Routine.at(i / 60.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	note("una posa della sequenza: %.3f ms (PC)" % ms)
	check(ms < COSTO_MAX_MS, "una posa costa %.3f ms" % ms)
	return done()
