# Coreografie del dribbling (scripts/partita/mosse/coreo.gd + coreo_dribbling.gd), solo grafica: piedi fermi a terra
# mentre appoggiano, pallone che non salta, verso del corpo che non scatta, pallone che alla fine torna quello del motore.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const D := preload("../sim/duel.gd")
const TD := preload("test_dribbling.gd")
const SCALA := Vector3(1.25, 1.25, 1.25)
const V_PALLA_MAX := 12.0      # m/s in più del pallone del motore: più di così a schermo è un salto


# caviglie di partenza: piedi a terra di qua e di là del giocatore (riferimento delle figure, flip 1)
static func caviglie(p: R.Player) -> Dictionary:
	var c := Vector3(p.x, 0.0, -p.y)
	var h := Coreo.Corpo.ANKLE_H * SCALA.y
	return {"l": c + Vector3(0.12, h, 0.05), "r": c + Vector3(-0.12, h + 0.08, -0.1)}


# fa andare motore e coreografie insieme come vista.gd (eventi dribble / dribble_go); ritorna le misure
static func gira(sd: int, ok: bool, giochetto: String) -> Dictionary:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99 if ok else 1
	o.st.dif = 20 if ok else 99
	m.userDribble(0)
	var cp: Coreo = null
	var co: Coreo = null
	var mis := {"esito": null, "salto_piede": 0.0, "salto_palla": 0.0, "salto_yaw": 0.0, "fine_palla": INF, "go": false}
	var piedi_prima := {}
	var palla_prima := Vector3.INF
	var yaw_prima := NAN
	for i in 300:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble":
				mis.esito = e.ok
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, SCALA, caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				co = Coreo.new(o, 1.0, SCALA, caviglie(o), bv, Vector3.ZERO)
				if e.ok:
					CD.FORZA = giochetto
					CD.portatore(cp, String(CD.scegli(99.0, 0.5).id), float(e.side), float(e.show))
					CD.FORZA = ""
					CD.difensore_vuoto(co, float(e.side), float(e.show), func() -> Vector3: return cp.pallone())
				else:
					CD.inciampo(cp)
					CD.contrasto(co, 0.0, m.ball.owner == o)
			elif e.type == "dribble_go" and cp != null:
				mis.go = true
				CD.portatore_go(cp)
				CD.difensore_go(co)
		m.events.clear()
		if cp == null:
			continue
		for c: Coreo in [cp, co]:
			if not c.finito:
				c.passo(DT, p if c == cp else o, m.ball)
		# misure sul portatore (piedi, verso) e sul pallone mostrato
		if cp.finito:
			break
		var pd := cp.piedi()
		for sd2: String in pd:
			var f: Dictionary = pd[sd2]
			if f.terra and piedi_prima.has(sd2) and piedi_prima[sd2].terra:
				mis.salto_piede = maxf(mis.salto_piede, (f.pos as Vector3).distance_to(piedi_prima[sd2].pos))
		piedi_prima = pd
		var attivo: Coreo = cp if cp.pallone_attivo() else (co if co.pallone_attivo() else null)
		var pb := Vector3(m.ball.x, 0.0, -m.ball.y) if attivo == null else attivo.pallone()
		if palla_prima != Vector3.INF:
			# oltre la velocità del pallone del motore (un rinvio vola a 18 m/s: non è un salto)
			var vm := Vector2(m.ball.vx, m.ball.vy).length()
			mis.salto_palla = maxf(mis.salto_palla, pb.distance_to(palla_prima) / DT - vm)
		palla_prima = pb
		if not is_nan(yaw_prima):
			mis.salto_yaw = maxf(mis.salto_yaw, absf(wrapf(cp.yaw - yaw_prima, -PI, PI)) / DT)
		yaw_prima = cp.yaw
		if cp.t >= cp.fine and attivo == null:
			mis.fine_palla = minf(mis.fine_palla, pb.distance_to(Vector3(m.ball.x, 0.0, -m.ball.y)))
	m.dispose()
	return mis


func test_dribbling_riuscito_piedi_fermi_pallone_continuo() -> bool:
	var sd := TD.first_ok_seed()
	for g: String in CD.FINTE:
		# Act
		var r := gira(sd, true, g)
		# Assert
		eq(r.esito, true, g + ": dribbling riuscito")
		check(r.go, g + ": scatto dopo il giochetto")
		check(r.salto_piede < 1e-4, g + ": piede a terra fermo (%.4f m)" % r.salto_piede)
		check(r.salto_palla < V_PALLA_MAX, g + ": pallone senza salti (%.1f m/s)" % r.salto_palla)
		check(r.salto_yaw <= Coreo.YAW_V + 0.01, g + ": il corpo non scatta (%.1f rad/s)" % r.salto_yaw)
		near(r.fine_palla, 0.0, 1e-3, g + ": alla fine il pallone è quello del motore")
	return done()


func test_dribbling_fallito_inciampo_e_contrasto() -> bool:
	# Arrange: un seme in cui il dribbling fallisce
	var r := {}
	for sd in range(1, 30):
		r = gira(sd, false, "")
		if r.esito == false:
			break
	# Assert
	eq(r.esito, false, "dribbling fallito")
	check(r.salto_piede < 1e-4, "piede a terra fermo (%.4f m)" % r.salto_piede)
	check(r.salto_palla < V_PALLA_MAX, "pallone senza salti (%.1f m/s)" % r.salto_palla)
	check(r.salto_yaw <= Coreo.YAW_V + 0.01, "il corpo non scatta")
	return done()


func test_giochetto_scelto_tra_le_finte() -> bool:
	for k in 20:
		var tk := CD.scegli(30.0 + k * 3.5, k / 20.0)
		check(String(tk.id) in CD.FINTE, "giochetto %s è una finta" % tk.id)
	return done()
