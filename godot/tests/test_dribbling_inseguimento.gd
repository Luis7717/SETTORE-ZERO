# Tunnel e pallonetti (sim/duel.gd dribChase*): mentre il portatore insegue il pallone staccato non si aprono duello
# né fuga (il rallenty a metà inseguimento lo lasciava "bloccato" col pallone ancora lontano), e appena ripreso il
# pallone ha un attimo prima che si apra un duello nuovo.
extends "test_base.gd"

const D := preload("../sim/duel.gd")
const TD := preload("test_dribbling.gd")
const IDS := ["tunnel", "sombrero", "bicicletta"]
const RESPIRO := 0.9      # s di partita dopo la presa senza duelli nuovi (DUEL_CD meno un passo)


# dal tasto in poi con un secondo avversario tenuto fermo `altro_d` m oltre il difensore (0 = nessuno); dalla presa un terzo
# avversario sta sempre `davanti` m davanti al portatore (0 = no). Ritorna {ok, go, presa, durante (duello o fuga
# aperti durante l'inseguimento), t_duello (s dalla presa al primo duello, −1 = mai), palla}
static func insegui(sd: int, id: String, altro_d: float, davanti: float) -> Dictionary:
	var r := TD.book_and_resolve(sd, true, id)
	var m: SimMatchScript = r[0]
	var p: R.Player = r[1]
	var o: R.Player = r[2]
	var out := {"ok": r[3] != null and bool(r[3].ok), "go": false, "presa": false, "durante": "", "t_duello": -1.0, "palla": false}
	if not out.ok:
		m.dispose()
		return out
	m.portaAuto = true
	var a: R.Player = m.players[11 + 4]
	var ax := o.x + 0.8
	var ay := o.y + altro_d
	var t_presa := -1.0
	var t := 0.0
	while t < 7.0 and (t_presa < 0.0 or t - t_presa < 3.0) and float(out.t_duello) < 0.0:
		if altro_d > 0.0 and t_presa < 0.0:   # (tenuto fermo lì: la sua IA lo porterebbe via)
			H.wake(a, ax, ay)
		if davanti > 0.0 and t_presa >= 0.0:  # (sempre lì davanti a lui, verso la porta: ferma, non contrasta)
			var b: R.Player = m.players[11 + 5]
			H.wake(b, p.x, p.y + davanti)
			b.stun = 0.0
			b.tackleCd = 1.0
		m.step(DT)
		t += DT
		for e: Dictionary in m.events:
			if e.type == "dribble_go":
				out.go = true
			elif e.type == "dribble_presa":
				out.presa = bool(e.ok)
				t_presa = t
			elif e.type == "duel_start" or e.type == "flee_start":
				if out.go and t_presa < 0.0:
					out.durante = String(e.type)
				elif t_presa >= 0.0 and e.type == "duel_start":
					out.t_duello = t - t_presa
		m.events.clear()
	out.palla = m.ball.owner == p
	m.dispose()
	return out


func test_niente_duello_ne_fuga_mentre_insegue_il_pallone() -> bool:
	for id: String in IDS:
		var visti := 0
		for sd in range(1, 9):
			# Arrange / Act: un altro avversario poco oltre il difensore, sulla strada del pallone
			var r := insegui(sd, id, 5.0, 0.0)
			if not r.ok:
				continue
			visti += 1
			# Assert
			check(r.go and r.presa, "%s seme %d: scatto e presa del pallone" % [id, sd])
			check(r.durante == "", "%s seme %d: durante l'inseguimento si apre %s" % [id, sd, r.durante])
		check(visti >= 3, "%s: almeno 3 dribbling riusciti (visti %d)" % [id, visti])
	return done()


func test_appena_ripreso_il_pallone_niente_duello_nuovo_per_un_attimo() -> bool:
	for id: String in IDS:
		var aperti := 0
		for sd in range(1, 9):
			# Arrange / Act: alla presa un avversario gli compare davanti a 4 m
			var r := insegui(sd, id, 0.0, 4.0)
			if not r.ok or not r.presa:
				continue
			# Assert
			if float(r.t_duello) >= 0.0:
				aperti += 1
				check(float(r.t_duello) >= RESPIRO, "%s seme %d: duello nuovo %.2f s dopo la presa" % [id, sd, r.t_duello])
		check(aperti >= 1, "%s: passato il respiro il duello con chi sta davanti si apre (prova valida)" % id)
	return done()


func test_i_giochetti_senza_pallone_staccato_restano_come_prima() -> bool:
	# la finta di corpo non insegue niente: nessun evento di presa
	var r := insegui(TD.first_ok_seed(), "finta", 0.0, 0.0)
	check(r.go, "scatto dopo la finta")
	check(not r.presa, "nessuna presa: il pallone non si è mai staccato")
	return done()
