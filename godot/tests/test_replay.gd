# Replay del gol (scripts/partita/replay_buffer.gd e replay.gd): buffer circolare, stato rimesso identico al
# motore dopo il replay (bit per bit: la partita continua uguale), tiro trovato nel buffer, velocità e durata,
# motore tenuto fermo alla fine della festa del gol.
extends "test_base.gd"

const ReplayBuffer := preload("res://scripts/partita/replay_buffer.gd")
const Replay := preload("res://scripts/partita/replay.gd")


static func _partita(seme: int) -> SimMatchScript:
	return H.newMatch(seme, 9999.0, [false, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))


# impronta completa dello stato che il replay tocca (e un po' di più): uguale = partita identica. Con gli oggetti
# (stessa = gli oggetti stessi, per la stessa partita) o al loro posto chi sono (per confrontare due partite gemelle)
static func _impronta(m: SimMatchScript, stessa := true) -> Array:
	var v: Array = [m.time, m.phase, m.rng.a, m.score[0], m.score[1]]
	for p: R.Player in m.players:
		v.append_array([p.x, p.y, p.fx, p.fy, p.vx, p.vy, p.kickAnim, p.t, p.state, p.sprint, p.cele, p.warn, p.off,
			p.tx, p.ty, p.stun, p.aiT])
		v.append(p.dive if stessa else (null if p.dive == null else [p.dive.tx, p.dive.th]))
	var b := m.ball
	v.append_array([b.x, b.y, b.h, b.vx, b.vy, b.vh])
	if stessa:
		v.append_array([b.owner, b.kick, b.shot])
	else:
		v.append_array([m.players.find(b.owner), b.kick != null, b.shot != null])
	return v


func test_buffer_tiene_solo_gli_ultimi_secondi() -> bool:
	var m := _partita(5)
	var buf := ReplayBuffer.new()
	for i in 60 * 12: # 12 s di gioco
		m.step(DT)
		m.events.clear()
		buf.registra(m)
	var iv := buf.intervallo()
	check(buf.quanti() <= ReplayBuffer.CAPIENZA, "non più di CAPIENZA campioni")
	check(buf.quanti() >= ReplayBuffer.CAPIENZA - 1, "buffer pieno dopo 12 s")
	near(iv.y, m.time, ReplayBuffer.PASSO + 1e-6, "l'ultimo campione è di adesso")
	check(iv.y - iv.x <= ReplayBuffer.DURATA + 2.0 * ReplayBuffer.PASSO, "al massimo DURATA s nel buffer")
	check(iv.y - iv.x >= ReplayBuffer.DURATA - 2.0 * ReplayBuffer.PASSO, "circa DURATA s nel buffer")
	note("campioni %d su %.2f s" % [buf.quanti(), iv.y - iv.x])
	return done()


func test_applica_rimette_lo_stato_registrato() -> bool:
	var m := _partita(6)
	var buf := ReplayBuffer.new()
	var x_allora := 0.0
	var t_allora := 0.0
	for i in 60 * 4:
		m.step(DT)
		m.events.clear()
		if buf.registra(m) and t_allora == 0.0 and i >= 60 * 2: # primo campione dopo 2 s: lo ricordo
			x_allora = m.players[7].x
			t_allora = m.time
	check(buf.applica(m, t_allora), "applica con campioni")
	eq(m.players[7].x, x_allora, "posizione registrata rimessa")
	buf.ripristina(m)
	check(not buf.applicato(), "ripristinato")
	return done()


func test_replay_non_cambia_la_partita() -> bool:
	# due partite gemelle: una con buffer, replay a metà (applica/ripristina più volte), l'altra senza
	var a := _partita(42)
	var b := _partita(42)
	var buf := ReplayBuffer.new()
	for i in 60 * 8:
		a.step(DT)
		a.events.clear()
		buf.registra(a)
		b.step(DT)
		b.events.clear()
	var prima := _impronta(a)
	var iv := buf.intervallo()
	var t := iv.x
	while t < iv.y:
		buf.applica(a, t)
		t += 0.05
		buf.ripristina(a)
	var dopo := _impronta(a)
	check(prima == dopo, "stato identico dopo il replay")
	for i in 60 * 20:
		a.step(DT)
		a.events.clear()
		b.step(DT)
		b.events.clear()
	check(_impronta(a, false) == _impronta(b, false), "la partita continua identica a quella senza replay")
	return done()


func test_tiro_trovato_nel_buffer() -> bool:
	var trovati := 0
	for seme in range(1, 40):
		var m := _partita(seme)
		var buf := ReplayBuffer.new()
		var t_tiro := -1.0
		for i in 60 * 90:
			m.step(DT)
			for e: Dictionary in m.events:
				if e.type == "kick" and e.kind == "shot":
					t_tiro = m.time
			m.events.clear()
			buf.registra(m)
			if t_tiro > 0.0 and m.time - t_tiro > 0.4 and m.ball.kick != null:
				break
		if t_tiro < 0.0 or m.ball.kick == null or m.ball.kick.type != "shot":
			continue
		var t := buf.tiro_prima(m.time)
		if near(t, t_tiro, ReplayBuffer.PASSO + DT + 1e-6, "tiro della partita %d" % seme):
			trovati += 1
		if trovati >= 3:
			break
	check(trovati >= 3, "almeno tre tiri trovati (%d)" % trovati)
	return done()


func test_tiro_prima_salta_il_pallone_senza_calcio_dopo_il_gol() -> bool:
	var m := _partita(9)
	var buf := ReplayBuffer.new()
	for i in 60 * 3:
		m.step(DT)
		m.events.clear()
	var k := R.Kick.make(0, m.players[9], "shot", 0.0, [], false)
	m.ball.kick = k
	var t0 := m.time
	for i in 30:
		m.time += DT
		buf.registra(m)
	m.ball.kick = null # gol: il motore toglie il calcio
	for i in 20:
		m.time += DT
		buf.registra(m)
	near(buf.tiro_prima(m.time), t0 + DT, ReplayBuffer.PASSO + 1e-6, "inizio del tiro")
	check(is_nan(ReplayBuffer.new().tiro_prima(1.0)), "buffer vuoto: NAN")
	return done()


func test_velocita_e_durata_del_replay() -> bool:
	eq(Replay.velocita(5.0, 5.1), Replay.LENTO, "attorno al tiro: rallentatore pieno")
	eq(Replay.velocita(3.0, 5.1), Replay.VELOCE, "lontano dal tiro")
	eq(Replay.velocita(3.0, NAN), Replay.VELOCE, "senza tiro")
	var d := Replay.durata_vera(0.0, Replay.PRIMA + Replay.DOPO, Replay.PRIMA - 0.3)
	note("replay normale: %.2f s veri" % d)
	check(d >= 4.0 and d <= 5.5, "4-5 s circa (%.2f)" % d)
	check(d > Replay.PRIMA + Replay.DOPO, "più lungo dell'azione vera (rallentatore)")
	return done()


class FintaPartita:
	extends RefCounted
	var phase := "goal"
	var goalT := 3.2
	var time := 10.0


func test_motore_fermo_alla_fine_della_festa() -> bool:
	var r: Replay = Replay.new()
	var f := FintaPartita.new()
	check(not r.trattieni(f, DT), "prima del gol non trattiene")
	r.gol(f)
	eq(r.stato, "attesa", "gol visto")
	check(not r.trattieni(f, DT), "festa in corso: il motore va")
	check(not r.festa_finita(), "festa non finita")
	f.goalT = DT * 0.5
	check(r.trattieni(f, DT), "il passo dopo farebbe il calcio d'inizio: fermo")
	check(r.festa_finita(), "festa finita (una volta)")
	check(not r.festa_finita(), "... solo una volta")
	check(r.trattieni(f, DT), "resta fermo finché nessuno fa partire il replay")
	# buffer vuoto: avvia non parte e il motore riparte
	var emesso := [false]
	r.finito.connect(func() -> void: emesso[0] = true)
	check(not r.avvia(null, null), "niente da rigiocare")
	check(emesso[0], "segnale finito")
	check(not r.trattieni(f, DT), "motore libero")
	r.free()
	return done()
