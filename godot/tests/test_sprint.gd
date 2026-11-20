# Scatto nel duello (Luis 2026-11-20): porting di test/unit/sprint.test.mjs. Nel duello il tasto in basso è Scatto
# (era Dribbling): il portatore brucia il difensore in velocità e prosegue dritto.
# (Lo scatto della corsa, tenendo il dito lontano, è in test_attack.gd.)
extends "test_base.gd"

const D := preload("../sim/duel.gd")


# portatore umano (squadra 0) a centrocampo che guarda verso +y, difensore della squadra 1 davanti a `dist_` m
static func setup(seed_value: int, dist_: float = 4.0, vel: float = 70.0, dif: float = 50.0, ox: float = 0.6) -> Array:
	var m := H.scene(seed_value)
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, 0, 0)
	p.fx = 0
	p.fy = 1
	p.st.vel = vel
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, ox, dist_)
	o.st.dif = dif
	o.fx = 0
	o.fy = -1
	return [m, p, o]


static func hold(m: SimMatchScript, p: R.Player) -> Callable:
	return func(_mm: SimMatchScript) -> void: m.userMove(0, p.x, p.y, true)


# tocca Scatto e ritorna l'evento 'dribble' che ne esce (null se il tasto non ha fatto niente)
static func tap(m: SimMatchScript) -> Variant:
	if not m.userSprint(0):
		return null
	var e: Variant = findEvent(m.events, "dribble")
	m.events.clear()
	return e


func test_scatto_fuori_dal_duello_non_fa_niente() -> bool:
	var s := setup(1, 20.0)
	var m: SimMatchScript = s[0]
	H.run(m, 1.0 / 60.0, hold(m, s[1]))
	eq(m.duelFor(0), false, "niente duello")
	eq(m.userSprint(0), false, "il tasto non fa niente")
	eq((s[1] as R.Player).burst, 0.0, "niente scatto")
	return done()


func test_scatto_riuscito_prosegue_dritto_oltre_il_difensore() -> bool:
	var ok := 0
	for seed_value in range(1, 21):
		# Arrange
		var s := setup(seed_value)
		var m: SimMatchScript = s[0]
		var p: R.Player = s[1]
		var o: R.Player = s[2]
		H.run(m, 1.0 / 60.0, hold(m, p))
		eq(m.duelFor(0), true, "duello aperto (seme %d)" % seed_value)
		# Act
		var res: Variant = tap(m)
		var evs := H.run(m, D.BURST_T)
		# Assert
		if not check(res != null and res.get("sprint", false) == true, "evento dribble con sprint (seme %d)" % seed_value):
			continue
		eq(m.duelFor(0), false, "il duello si chiude")
		if not res.ok:
			continue
		ok += 1
		eq(m.ball.owner, p, "ha ancora il pallone (seme %d)" % seed_value)
		check(not hasEvent(evs, "tackle"), "nessun contrasto (seme %d)" % seed_value)
		check(p.y > o.y + 1.0, "è passato oltre il difensore (%.1f contro %.1f)" % [p.y, o.y])
		check(absf(p.x) < 2.0, "dritto, non di lato (x %.1f)" % p.x)
		check(p.x * o.x <= 0.0, "passa dalla parte opposta al difensore")
		var mv: R.Move = m.move[0]
		check(mv == null or mv.y > D.BURST_RUN - 2.0, "prosegue dritto verso la meta davanti")
	check(ok >= 10, "riusciti %d su 20 (veloce contro difesa scarsa)" % ok)
	note("riusciti %d su 20" % ok)
	return done()


func test_scatto_riesce_piu_spesso_veloce_contro_difesa_scarsa() -> bool:
	var veloce := _riusciti(85.0, 40.0)
	var lento := _riusciti(45.0, 80.0)
	check(veloce > lento, "veloce contro difesa scarsa (%d) > lento contro difesa forte (%d)" % [veloce, lento])
	return done()


func _riusciti(vel: float, dif: float) -> int:
	var ok := 0
	for seed_value in range(1, 41):
		var s := setup(seed_value + 100, 4.0, vel, dif)
		var m: SimMatchScript = s[0]
		H.run(m, 1.0 / 60.0, hold(m, s[1]))
		var r: Variant = tap(m)
		if r != null and r.ok:
			ok += 1
	return ok


# in più rispetto al JS: lo Scatto dà gli stessi numeri del JS (vedi DECISIONI: probabilità velocità contro difesa)
func test_scatto_probabilita_velocita_contro_difesa() -> bool:
	var s := setup(1)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	near(m.sprintChance(p, o), 0.5 + 1.2 * (70.0 - 50.0) / 100.0, 1e-12, "70 contro 50")
	p.st.vel = 10
	o.st.dif = 99
	eq(m.sprintChance(p, o), D.DRIB_MIN, "limite basso")
	return done()
