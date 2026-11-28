# Coreografie del dribbling (scripts/partita/mosse/coreo.gd + coreo_dribbling.gd + coreo_skill.gd), solo grafica:
# piedi fermi a terra mentre appoggiano, pallone che non salta, verso del corpo che non scatta, pallone che alla fine
# torna quello del motore; i 16 giochetti si fanno tutti, il pallone si muove davvero (di lato, tra le gambe, sopra la
# testa) e i due corpi non si compenetrano.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const Skill := preload("../sim/skill.gd")
const D := preload("../sim/duel.gd")
const TD := preload("test_dribbling.gd")
const SCALA := Vector3(1.25, 1.25, 1.25)
const V_PALLA_MAX := 14.0      # m/s in più del pallone del motore: più di così a schermo è un salto
const DENTRO_MAX := 0.06       # m: di più e i due corpi a schermo si compenetrano (busto e gambe come capsule)
# il pallone mostrato si sposta di lato (rispetto alla corsa di prima) almeno tanto, dalla finta allo scatto
const LATO_MIN := {"elastico": 0.35, "elastico_inv": 0.3, "suola": 0.3, "croqueta": 0.3}


# caviglie di partenza: piedi a terra di qua e di là del giocatore (riferimento delle figure, flip 1)
static func caviglie(p: R.Player) -> Dictionary:
	var c := Vector3(p.x, 0.0, -p.y)
	var h := Coreo.Corpo.ANKLE_H * SCALA.y
	return {"l": c + Vector3(0.12, h, 0.05), "r": c + Vector3(-0.12, h + 0.08, -0.1)}


static func figura(c: Coreo, p: R.Player) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, c.yaw).scaled(SCALA), Vector3(p.x, 0.0, -p.y))


# fa andare motore e coreografie insieme come vista.gd (eventi dribble / dribble_go); ritorna le misure
static func gira(sd: int, ok: bool, giochetto: String) -> Dictionary:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = giochetto
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99 if ok else 1
	o.st.dif = 20 if ok else 99
	m.userDribble(0)
	var cp: Coreo = null
	var co: Coreo = null
	var mis := {"esito": null, "salto_piede": 0.0, "salto_palla": 0.0, "salto_yaw": 0.0, "fine_palla": INF, "go": false,
		"dentro": 0.0, "lato_min": INF, "lato_max": -INF, "alto": 0.0, "vicino_dif": INF, "giro": 0.0, "id": "",
		# portatore durante il giochetto (da 0,2 s dopo l'esito allo scatto): velocità minima (m/s)
		"v_min": INF,
		# pallone staccato (tunnel, pallonetti): quanto devia dalla linea del lancio (gradi), quanto accelera da solo
		# (m/s per passo, a terra), accelerazione verticale media in volo (m/s²), strada fatta dal portatore dal
		# lancio alla presa (m), distanza pallone-portatore al lancio e minima prima della presa, presa arrivata
		"curva": 0.0, "accelera": 0.0, "grav": 0.0, "strada": 0.0, "presa": false, "lancio": false, "volo_t": 0.0,
		"palla_ferma_o_avanti": true}
	var t_drib := -1.0
	var dir0 := Vector3.ZERO
	var fv_prima := Vector3.INF
	var vh_prima := NAN
	var grav_n := 0
	var pp_prima := Vector3.INF
	var piedi_prima := {}
	var palla_prima := Vector3.INF
	var yaw_prima := NAN
	var sx := Vector3.ZERO    # sinistra del portatore all'inizio (mondo): lato + = lato scelto se side = +1
	var p0 := Vector3.ZERO
	var t_go := INF
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble_palla":
				mis.lancio = true
			elif e.type == "dribble_presa":
				mis.presa = bool(e.ok)
			if e.type == "dribble":
				t_drib = 0.0
				mis.esito = e.ok
				mis.id = String(e.get("skill", ""))
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, SCALA, caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				co = Coreo.new(o, 1.0, SCALA, caviglie(o), bv, Vector3.ZERO)
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				co.ostacolo = func() -> Vector3: return Vector3(p.x, 0.0, -p.y)
				sx = Basis(Vector3.UP, cp.yaw) * Vector3(1, 0, 0) * float(e.side)
				p0 = bv
				if e.ok:
					CD.portatore(cp, String(e.skill), float(e.side), float(e.show))
					CD.difensore_vuoto(co, float(e.side), float(e.show), func() -> Vector3: return cp.pallone(), String(e.skill))
				else:
					CD.inciampo(cp)
					CD.contrasto(co, 0.0, m.ball.owner == o)
			elif e.type == "dribble_go" and cp != null:
				mis.go = true
				t_go = cp.t
				CD.portatore_go(cp)
				CD.difensore_go(co)
		m.events.clear()
		if cp == null:
			continue
		for c: Coreo in [cp, co]:
			if not c.finito:
				c.passo(DT, p if c == cp else o, m.ball)
		t_drib += DT
		if mis.esito == true and not mis.go and t_drib > 0.2:
			mis.v_min = minf(mis.v_min, C.hyp(p.vx, p.vy))
		# pallone staccato del motore: dritto, senza spinte, gravità vera; il portatore gli va incontro
		var fi: R.Ball = m.ball.finto
		if fi != null:
			var fv := Vector3(fi.vx, 0.0, -fi.vy)
			if dir0 == Vector3.ZERO:
				dir0 = fv.normalized()
			elif fv.length() > 0.3:
				mis.curva = maxf(mis.curva, rad_to_deg(dir0.angle_to(fv.normalized())))
			if fv_prima != Vector3.INF and fi.h <= 0.0 and is_nan(vh_prima):
				mis.accelera = maxf(mis.accelera, fv.length() - fv_prima.length())
			fv_prima = fv
			if fi.h > 0.05 and not is_nan(vh_prima) and fi.vh < vh_prima:
				mis.grav += (fi.vh - vh_prima) / DT
				grav_n += 1
				mis.volo_t += DT
			vh_prima = fi.vh if fi.h > 0.05 else NAN
			if pp_prima != Vector3.INF:
				mis.strada += Vector3(p.x, 0, -p.y).distance_to(pp_prima)
			pp_prima = Vector3(p.x, 0, -p.y)
		if cp.finito or (cp.t >= cp.fine and not cp.pallone_attivo()):
			mis.fine_palla = minf(mis.fine_palla, cp.pallone().distance_to(Vector3(m.ball.x, 0.0, -m.ball.y)) if cp.pallone_attivo() else 0.0)
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
		var ph := 0.0 if attivo == null else attivo.pallone_h()
		if palla_prima != Vector3.INF:
			# oltre la velocità del pallone del motore (un rinvio vola a 18 m/s: non è un salto)
			var vm := Vector2(m.ball.vx, m.ball.vy).length()
			mis.salto_palla = maxf(mis.salto_palla, pb.distance_to(palla_prima) / DT - vm)
		palla_prima = pb
		mis.alto = maxf(mis.alto, ph)
		mis.vicino_dif = minf(mis.vicino_dif, Vector2(pb.x - o.x, pb.z + o.y).length())
		if not mis.go or cp.t < t_go + 0.1:   # (fino al tocco dello scatto)
			var lato := (pb - p0).dot(sx)
			mis.lato_min = minf(mis.lato_min, lato)
			mis.lato_max = maxf(mis.lato_max, lato)
		if not is_nan(yaw_prima):
			var dy := wrapf(cp.yaw - yaw_prima, -PI, PI)
			mis.salto_yaw = maxf(mis.salto_yaw, absf(dy) / DT - cp.yaw_v)
			mis.giro += dy
		yaw_prima = cp.yaw
		# i due corpi (finché tutti e due sono in coreografia)
		if not co.finito:
			var sa := Coreo.segmenti(figura(cp, p), cp.frame(figura(cp, p), pb, ph))
			var sb := Coreo.segmenti(figura(co, o), co.frame(figura(co, o), pb, ph))
			mis.dentro = maxf(mis.dentro, Coreo.compenetrazione(sa, sb))
		if cp.t >= cp.fine and attivo == null:
			mis.fine_palla = minf(mis.fine_palla, pb.distance_to(Vector3(m.ball.x, 0.0, -m.ball.y)))
	if grav_n > 0:
		mis.grav /= grav_n
	m.dispose()
	return mis


func test_tutti_i_giochetti_piedi_fermi_pallone_continuo() -> bool:
	var sd := TD.first_ok_seed()
	eq(CD.FINTE.size(), Skill.LISTA.size(), "una coreografia per ogni giochetto del motore")
	for s: Dictionary in Skill.LISTA:
		var g := String(s.id)
		check(g in CD.FINTE, g + ": ha la sua coreografia")
		# Act
		var r := gira(sd, true, g)
		# Assert
		eq(r.esito, true, g + ": dribbling riuscito")
		eq(r.id, g, g + ": giochetto del motore")
		check(r.go, g + ": scatto dopo il giochetto")
		check(r.salto_piede < 1e-4, g + ": piede a terra fermo (%.4f m)" % r.salto_piede)
		check(r.salto_palla < V_PALLA_MAX, g + ": pallone senza salti (%.1f m/s)" % r.salto_palla)
		check(r.salto_yaw <= 0.01, g + ": il corpo non scatta (%.1f rad/s oltre il limite)" % r.salto_yaw)
		near(r.fine_palla, 0.0, 1e-3, g + ": alla fine il pallone è quello del motore")
		check(r.dentro <= DENTRO_MAX, g + ": i due corpi non si compenetrano (%.3f m)" % r.dentro)
	return done()


func test_il_pallone_si_muove_davvero() -> bool:
	var sd := TD.first_ok_seed()
	# finte col pallone: prima va verso la finta (lato −), poi torna dal lato scelto
	for g: String in LATO_MIN:
		var r := gira(sd, true, g)
		var corsa: float = r.lato_max - r.lato_min
		check(corsa >= float(LATO_MIN[g]), "%s: il pallone si sposta di lato di %.2f m" % [g, corsa])
	# tunnel: il pallone passa dove sta il difensore (tra le gambe)
	var tn := gira(sd, true, "tunnel")
	check(tn.vicino_dif < 0.2, "tunnel: il pallone passa tra le gambe del difensore (a %.2f m dal suo centro)" % tn.vicino_dif)
	eq(tn.alto, 0.0, "tunnel: rasoterra")
	# pallonetti: il pallone passa sopra la testa del difensore (figura alta 2,3 m)
	for g: String in ["sombrero", "bicicletta"]:
		var r := gira(sd, true, g)
		check(r.alto > 2.5, "%s: il pallone sale a %.2f m" % [g, r.alto])
		check(r.vicino_dif < 0.45, "%s: passa sopra il difensore (a %.2f m)" % [g, r.vicino_dif])
	# veronica: un giro intero su sé stesso (più il cambio di direzione)
	var v := gira(sd, true, "veronica")
	check(absf(v.giro) > deg_to_rad(270.0), "veronica: giro di %.0f gradi" % rad_to_deg(absf(v.giro)))
	# la finta di corpo non gira su sé stessa
	var f := gira(sd, true, "finta")
	check(absf(f.giro) < deg_to_rad(120.0), "finta di corpo: nessun giro (%.0f gradi)" % rad_to_deg(absf(f.giro)))
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
	check(r.salto_yaw <= 0.01, "il corpo non scatta")
	check(r.dentro <= DENTRO_MAX, "i due corpi non si compenetrano (%.3f m)" % r.dentro)
	return done()


func test_i_piedi_restano_fuori_dal_corpo_dell_altro() -> bool:
	# Arrange: un giocatore fermo e l'altro a 0,5 m davanti a lui (dentro il raggio)
	var s := TD.setup(1, 5.0)
	var m: SimMatchScript = s[0]
	var p: R.Player = s[1]
	var c := Coreo.new(p, 1.0, SCALA, caviglie(p), Vector3(p.x, 0, -p.y - 0.6), Vector3.ZERO)
	var altro := Vector3(p.x, 0.0, -p.y - 0.5)
	c.ostacolo = func() -> Vector3: return altro
	# Act: un passo lungo proprio dove sta l'altro
	c.appoggia("r", 0.2, Vector2(0.0, 0.4))
	for i in 30:
		c.passo(DT, p, m.ball)
	# Assert
	var q: Vector3 = c.piedi().r.pos
	check(Vector2(q.x - altro.x, q.z - altro.z).length() >= c.ost_r - 1e-3, "il piede appoggia fuori dal corpo dell'altro")
	m.dispose()
	return done()


func test_giochetto_scelto_tra_le_coreografie() -> bool:
	for k in 40:
		var tk := CD.scegli(20.0 + k * 2.0, k / 40.0)
		check(String(tk.id) in CD.FINTE, "giochetto %s ha la coreografia" % tk.id)
		check(CD.nome(String(tk.id)) != "Dribbling", "giochetto %s ha il nome" % tk.id)
	return done()


# Luis 2026-11-26: "la palla torna magneticamente al mio: deve essere naturale, è lui che va a prenderla"
func test_tunnel_e_pallonetti_il_pallone_va_dritto_e_il_portatore_lo_va_a_prendere() -> bool:
	var sd := TD.first_ok_seed()
	for g: String in ["tunnel", "sombrero", "bicicletta"]:
		# Act
		var r := gira(sd, true, g)
		# Assert
		check(r.lancio, g + ": il pallone si stacca dal portatore")
		check(r.presa, g + ": il portatore lo riprende")
		check(r.curva < 0.5, g + ": il pallone va dritto, non curva verso il portatore (%.2f gradi)" % r.curva)
		check(r.accelera <= 1e-6, g + ": a terra rallenta soltanto (attrito), nessuna spinta (%.3f m/s)" % r.accelera)
		check(r.strada > 3.0, g + ": è il portatore che gira intorno al difensore e va al pallone (%.1f m)" % r.strada)
		near(r.fine_palla, 0.0, 1e-3, g + ": alla fine il pallone è quello del motore")
		if g != "tunnel":
			near(r.grav, -C.G, 0.2, g + ": in volo scende con la gravità del pallone vero")
			check(r.volo_t > 1.0, g + ": il volo dura quanto un pallonetto vero (%.2f s)" % r.volo_t)
	return done()


# Luis 2026-11-26: "il portatore si ferma sul posto prima del giochetto: deve arrivare in corsa"
func test_nessuna_fermata_durante_il_giochetto() -> bool:
	var sd := TD.first_ok_seed()
	for s: Dictionary in Skill.LISTA:
		var g := String(s.id)
		if g == "stopgo":   # (lo "stop e via" si ferma apposta)
			continue
		var r := gira(sd, true, g)
		check(r.v_min >= 1.8, g + ": durante il giochetto continua ad avanzare (minimo %.1f m/s)" % r.v_min)
	return done()
