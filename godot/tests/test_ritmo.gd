# Ritmo del gioco col pallone (Luis 2026-11-23):
# - dopo lo Scatto il portatore non si blocca: finita la corsa dritta riprende subito la guida automatica (portaAuto);
# - rallenty col pallone scaduto (timer di 10 s veri del gioco → m.userCalm): duello, fuga e area di tiro si chiudono
#   e per lo stesso portatore non si riaprono subito; il portatore continua da solo;
# - visuale della nostra rimessa laterale alle spalle del battitore (camfit.gd throw_view), girabile col dito.
extends "test_base.gd"

const D := preload("../sim/duel.gd")
const TR := preload("res://scripts/partita/timer_rallenty.gd")
const CF := preload("res://scripts/partita/camfit.gd")
const CU := preload("res://scripts/partita/camuser.gd")

const ASPECT := 390.0 / 844.0
const FOV := 70.0


# portatore umano (squadra 0) a centrocampo che corre verso +y, avversario alle spalle: fuga aperta.
# rif = opzioni del gioco (portaAuto e rifiniture)
static func fuga(seed_value: int, rif: bool) -> Array:
	var m := H.scene(seed_value)
	m.portaAuto = rif
	m.rifiniture = rif
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, 0.0, 0.0)
	p.fx = 0.0
	p.fy = 1.0
	p.vy = 4.0
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, 0.8, -1.2)
	H.run(m, DT)
	return [m, p, o]


func test_dopo_lo_scatto_il_portatore_non_si_blocca() -> bool:
	for sd in [5, 11, 23]:
		# Arrange
		var s := fuga(sd, true)
		var m: SimMatchScript = s[0]
		var p: R.Player = s[1]
		eq(m.fleeFor(0), true, "fuga aperta (seme %d)" % sd)
		# Act: Scatto, poi fine dello scatto
		eq(m.userSprint(0), true, "il tasto funziona (seme %d)" % sd)
		H.run(m, D.BURST_T)
		eq(m.move[0], null, "finito lo scatto niente più corsa dritta verso la meta (seme %d)" % sd)
		var y0 := p.y
		var vmin := 99.0
		var t := 0.0
		while t < 2.0:
			H.run(m, 0.1)
			t += 0.1
			vmin = minf(vmin, C.hyp(p.vx, p.vy))
		# Assert: nei 2 s dopo lo scatto continua a muoversi da solo, in avanti, col pallone e senza un'altra fuga
		eq(m.ball.owner, p, "ha ancora il pallone (seme %d)" % sd)
		check(vmin > 2.0, "mai fermo nei 2 s dopo lo scatto (seme %d: minimo %.1f m/s)" % [sd, vmin])
		check(p.y - y0 > 5.0, "va avanti (seme %d: %.1f m in 2 s)" % [sd, p.y - y0])
		eq(m.fleeFor(0), false, "niente fuga subito dopo lo scatto (seme %d)" % sd)
		m.dispose()
	return done()


func test_scatto_senza_rifiniture_come_prima() -> bool:
	# Arrange: senza le opzioni del gioco (confronti col JS) la corsa dritta dura BURST_T + 1 s
	var s := fuga(5, false)
	var m: SimMatchScript = s[0]
	# Act
	m.userSprint(0)
	H.run(m, D.BURST_T)
	# Assert
	check(m.move[0] != null, "com'era: corsa verso la meta ancora attiva")
	m.dispose()
	return done()


# portatore umano davanti a un difensore: duello aperto
static func duello(seed_value: int) -> Array:
	var m := H.scene(seed_value)
	m.portaAuto = true
	m.rifiniture = true
	var p: R.Player = m.players[9]
	var o: R.Player = m.players[11 + 3]
	H.wake(p, 0.0, 0.0)
	p.fx = 0.0
	p.fy = 1.0
	H.give(m, p)
	m.updateCtrl(0)
	H.wake(o, 0.0, 5.0)
	H.run(m, DT)
	return [m, p, o]


func test_rallenty_scaduto_chiude_il_duello_e_non_lo_riapre_subito() -> bool:
	# Arrange
	var s := duello(3)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	eq(m.duelFor(0), true, "duello aperto")
	# Act
	var ok := m.userCalm(0)
	# Assert
	eq(ok, true, "userCalm fa qualcosa")
	eq(m.duelFor(0), false, "duello chiuso")
	var aperti := 0
	var t := 0.0
	while t < D.CALM_CD - 0.5:
		o.x = p.x # difensore sempre davanti
		o.y = p.y + 4.0
		o.vx = 0.0
		o.vy = 0.0
		o.stun = 0.0
		H.run(m, DT)
		t += DT
		if m.duelFor(0) or m.fleeFor(0):
			aperti += 1
	eq(aperti, 0, "per lo stesso portatore niente duello né fuga per CALM_CD")
	check(C.hyp(p.vx, p.vy) > 1.0, "il portatore continua da solo (%.1f m/s)" % C.hyp(p.vx, p.vy))
	# dopo il raffreddamento il duello torna possibile
	H.run(m, 1.0, func(_mm: SimMatchScript) -> void:
		o.x = p.x
		o.y = p.y + 4.0
		o.stun = 0.0)
	eq(m.duelFor(0), true, "finito CALM_CD il duello si riapre")
	m.dispose()
	return done()


func test_rallenty_scaduto_chiude_la_fuga() -> bool:
	var s := fuga(7, true)
	var m: SimMatchScript = s[0]
	eq(m.fleeFor(0), true, "fuga aperta")
	eq(m.userCalm(0), true, "userCalm")
	eq(m.fleeFor(0), false, "fuga chiusa")
	H.run(m, 1.0)
	eq(m.fleeFor(0), false, "non si riapre subito")
	m.dispose()
	return done()


func test_rallenty_scaduto_nell_area_di_tiro_finche_ha_il_pallone() -> bool:
	# Arrange: portatore nell'area di tiro, nessun avversario vicino
	var m := H.scene(4)
	m.portaAuto = true
	m.rifiniture = true
	var p: R.Player = m.players[9]
	H.wake(p, 4.0, C.HL - 15.0)
	H.give(m, p)
	m.updateCtrl(0)
	eq(m.inZone(0), true, "area di tiro")
	# Act
	m.userCalm(0)
	# Assert
	eq(m.inZone(0), false, "niente più rallenty dell'area di tiro per lui")
	H.run(m, D.CALM_CD + 1.0)
	eq(m.inZone(0), false, "nemmeno dopo CALM_CD, finché ha il pallone")
	# un altro portatore: l'area di tiro rallenta di nuovo
	var q: R.Player = m.players[10]
	H.wake(q, -3.0, C.HL - 14.0)
	H.give(m, q)
	m.updateCtrl(0)
	m.step(DT)
	eq(m.ctrl[0], q, "controllato il nuovo portatore")
	eq(m.inZone(0), true, "nuovo portatore: area di tiro di nuovo")
	m.dispose()
	return done()


func test_rallenty_scaduto_senza_pallone_o_per_la_cpu_non_fa_niente() -> bool:
	var m := H.scene(6)
	eq(m.userCalm(0), false, "pallone libero")
	var o: R.Player = m.players[11 + 3]
	H.wake(o, 0.0, 0.0)
	H.give(m, o)
	eq(m.userCalm(0), false, "pallone dell'avversario")
	eq(m.userCalm(1), false, "squadra della CPU")
	m.dispose()
	return done()


# ---------------------------------------------------------------- timer del gioco (timer_rallenty.gd)
class Finto:
	extends RefCounted
	var x := 0.0


func test_timer_rallenty_scade_dopo_10_secondi_veri() -> bool:
	# Arrange
	var t := TR.new()
	var p := Finto.new()
	eq(t.frazione(), -1.0, "senza rallenty niente cerchio")
	# Act / Assert
	var scaduto := false
	var n := 0
	while not scaduto and n < 2000:
		scaduto = t.passo(1.0 / 60.0, p, false)
		n += 1
	near(n / 60.0, TR.RALLENTY_MAX_S, 0.05, "scade dopo RALLENTY_MAX_S s veri")
	eq(t.frazione(), -1.0, "scaduto: cerchio nascosto")
	return done()


func test_timer_rallenty_fermo_mentre_si_disegna_e_azzerato_da_un_portatore_nuovo() -> bool:
	var t := TR.new()
	var a := Finto.new()
	var b := Finto.new()
	t.passo(4.0, a, false)
	near(t.frazione(), 0.6, 1e-6, "4 s su 10")
	eq(t.passo(30.0, a, true), false, "mentre il dito disegna non scade")
	near(t.frazione(), 0.6, 1e-6, "e il tempo è fermo")
	t.passo(1.0, b, false)
	near(t.frazione(), 0.9, 1e-6, "portatore nuovo: si riparte da capo")
	t.passo(1.0, null, false)
	eq(t.frazione(), -1.0, "fine del rallenty: azzerato")
	return done()


func test_timer_rallenty_riconosce_il_rallenty_col_pallone() -> bool:
	var s := duello(8)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	eq(TR.portatore_in_rallenty(m, 0), p, "duello")
	eq(TR.portatore_in_rallenty(m, 1), null, "non per l'altra squadra")
	m.userDribble(0)
	if m.dribBooked(0):
		eq(TR.portatore_in_rallenty(m, 0), null, "dribbling prenotato: tempo normale")
	m.dispose()
	return done()


# ---------------------------------------------------------------- visuale della rimessa laterale
func test_visuale_rimessa_alle_spalle_del_battitore_verso_il_campo() -> bool:
	for bx: float in [-C.HW, C.HW]:
		# Arrange
		var ball := Vector2(bx, 5.0)
		var sx := signf(bx)
		# Act
		var v := CF.throw_view(ball, 0.0, ASPECT, FOV)
		# Assert
		var pos: Vector3 = v.pos
		var look: Vector3 = v.look
		check(pos.x * sx > C.HW, "telecamera fuori dalla linea laterale (x %.1f)" % pos.x)
		check((look.x - pos.x) * -sx > 0.0, "guarda verso il campo")
		check(look.z > pos.z, "un po' verso la porta avversaria")
		check(pos.y > 3.0, "dall'alto (%.1f m)" % pos.y)
	return done()


func test_visuale_rimessa_girata_col_dito_mai_verso_le_tribune() -> bool:
	var ball := Vector2(-C.HW, 0.0)
	var v0 := CF.throw_view(ball, 0.0, ASPECT, FOV)
	for yaw: float in [-CU.CAM_USER_MAX, -1.0, 1.0, CU.CAM_USER_MAX]:
		var v := CF.throw_view(ball, yaw, ASPECT, FOV)
		var d: Vector3 = (v.look as Vector3) - (v.pos as Vector3)
		check(d.x > 0.0, "girata %.2f: guarda sempre dentro il campo (%.2f)" % [yaw, d.x])
		check((v.pos as Vector3).distance_to(v0.pos) > 0.5 or absf(yaw) < 0.1, "girata %.2f: la visuale cambia" % yaw)
	return done()


func test_rimessa_nostra_solo_col_battitore_sulla_linea() -> bool:
	var m := H.scene(2)
	m.setRestart("throw", 0, -C.HW, 0.0)
	eq(CU.throw_cam_on(m, 0), true, "nostra rimessa pronta")
	eq(CU.throw_cam_on(m, 1), false, "non per la CPU")
	m.restart.scena = "va" # battitore che va a prendere il pallone (riprese.gd)
	eq(CU.throw_cam_on(m, 0), false, "durante la scena no: entra quando il battitore è arrivato")
	m.dispose()
	return done()
