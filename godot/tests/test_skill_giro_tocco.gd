# Giochetto "Giro e tocco" (scripts/partita/mosse/skill/giro_tocco.gd), solo grafica: un giro intero continuo sul piede
# di perno con UNA suola che trascina il pallone in cerchio senza lasciarlo, schiena al difensore col pallone coperto,
# poi il tocco dell'altro piede e l'uscita di corsa; gambe mai deformate (anche alla fine del giro).
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")
const TG := preload("test_skill_gambe.gd")
const SCALA := Vector3(1.25, 1.25, 1.25)
const ID := "giro_tocco"


# motore e coreografia insieme come vista.gd, giochetto `id`; lato = lato forzato (0 = quello del motore). Ritorna i
# campioni di ogni passo del portatore: {t, go (s dallo scatto, <0 prima), pos, vel, yaw, piedi, palla, palla_h, dif,
# dentro, side, peso, mani (altezza delle mani sopra il bacino, m), bacino_h}
static func traccia(id: String, sd: int, lato: float = 0.0) -> Array:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = id
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	if lato != 0.0 and m.duel != null:
		m.duel.side = lato
	var cp: Coreo = null
	var co: Coreo = null
	var out: Array = []
	var t_go := INF
	var side := 0.0
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble":
				if not e.ok:
					m.dispose()
					return []
				side = float(e.side)
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				co = Coreo.new(o, 1.0, SCALA, TC.caviglie(o), bv, Vector3.ZERO)
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				co.ostacolo = func() -> Vector3: return Vector3(p.x, 0.0, -p.y)
				CD.portatore(cp, String(e.skill), side, float(e.show))
				CD.difensore_vuoto(co, side, float(e.show), func() -> Vector3: return cp.pallone(), String(e.skill))
			elif e.type == "dribble_go" and cp != null:
				t_go = cp.t
				CD.portatore_go(cp)
				CD.difensore_go(co)
		m.events.clear()
		if cp == null:
			continue
		for c: Coreo in [cp, co]:
			if not c.finito:
				c.passo(DT, p if c == cp else o, m.ball)
		if cp.finito:
			break
		var N := TC.figura(cp, p)
		var attivo := cp.pallone_attivo()
		var pb := cp.pallone() if attivo else Vector3(m.ball.x, 0.0, -m.ball.y)
		var fr := cp.frame(N, pb, 0.0)
		var dentro := 0.0
		if not co.finito:
			var No := TC.figura(co, o)
			dentro = Coreo.compenetrazione(Coreo.segmenti(N, fr), Coreo.segmenti(No, co.frame(No, pb, 0.0)))
		var bac: Vector3 = fr.pelvis.p
		out.append({"t": cp.t, "go": cp.t - t_go if t_go < INF else -1.0, "pos": Vector3(p.x, 0.0, -p.y),
			"vel": Vector3(p.vx, 0.0, -p.vy), "yaw": cp.yaw, "piedi": cp.piedi(), "palla": pb,
			"palla_moto": Vector3(m.ball.x, 0.0, -m.ball.y), "dif": Vector3(o.x, 0.0, -o.y),
			"dentro": dentro, "side": side, "peso": cp.peso, "bacino_h": bac.y,
			"mani": maxf((fr.arms.l.hand as Vector3).y, (fr.arms.r.hand as Vector3).y) - bac.y})
	m.dispose()
	return out


# misure del giro su una traccia: giro totale (rad, nel verso del giro = lontano dal lato scelto), velocità massima e
# minima del giro (rad/s, su finestre di 0,1 s tra 20° e 330°), giro all'indietro più grande (rad), giro fatto a ogni
# campione, quanto dura il giro tra 20° e 330° (s)
static func misura(tr: Array) -> Dictionary:
	var G: float = -float(tr[0].side)
	var tot := 0.0
	var yp: float = tr[0].yaw
	var giri: Array = []
	var indietro := 0.0
	var t_a := -1.0
	var t_b := -1.0
	for c: Dictionary in tr:
		var d := wrapf(float(c.yaw) - yp, -PI, PI) * G
		yp = c.yaw
		tot += d
		indietro = maxf(indietro, -d)
		giri.append(tot)
		if t_a < 0.0 and tot > deg_to_rad(20.0):
			t_a = c.t
		if t_b < 0.0 and tot > deg_to_rad(330.0):
			t_b = c.t
	var w_max := 0.0
	var w_min := INF
	for i in range(6, giri.size()):
		var w: float = (float(giri[i]) - float(giri[i - 6])) / (6.0 * DT)
		if float(giri[i - 6]) > deg_to_rad(20.0) and float(giri[i]) < deg_to_rad(330.0):
			w_max = maxf(w_max, w)
			w_min = minf(w_min, w)
	return {"tot": tot, "w_max": w_max, "w_min": w_min, "indietro": indietro, "giri": giri, "dur": t_b - t_a}


# gambe mai deformate per il giochetto `id` (stesse soglie di test_skill_gambe.gd): ritorna le righe che non vanno
static func gambe_male(id: String) -> Array:
	var r := TG.misura(id, true)
	var male: Array = []
	if r.esito != true:
		return ["dribbling non riuscito"]
	for chi: String in ["p", "o"]:
		var mis: Dictionary = r[chi]
		if float(mis.cav) > TG.SALTO_CAVIGLIA or float(mis.gin) > TG.SALTO_GINOCCHIO \
				or float(mis.dentro) > float(TG.DENTRO_ID.get(id, TG.DENTRO_GAMBE)) or float(mis.lungo) > TG.ALLUNGO_MAX \
				or float(mis.corto) < TG.ALLUNGO_MIN or float(mis.gin_av) < TG.GINOCCHIO_DIETRO:
			male.append(TG.riga(id, chi, mis))
	return male


func test_giro_intero_continuo_sul_perno() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(ID, TD.first_ok_seed(), lato)
		check(not tr.is_empty(), "dribbling riuscito")
		var m := misura(tr)
		note("lato %+d: giro %.0f gradi, velocità del giro da %.1f a %.1f rad/s" % [int(lato), rad_to_deg(m.tot), m.w_min, m.w_max])
		check(m.tot > deg_to_rad(320.0) and m.tot < deg_to_rad(400.0), "un giro intero (%.0f gradi)" % rad_to_deg(m.tot))
		check(m.indietro < 0.02, "sempre nello stesso verso")
		check(m.w_min > 5.0, "nessuna pausa nel giro (minimo %.1f rad/s)" % m.w_min)
		check(m.w_max < 10.0, "non una trottola (massimo %.1f rad/s)" % m.w_max)
	return done()


# la differenza con la veronica: una suola sola, che resta sul pallone e lo trascina in cerchio col corpo che gira
func test_la_suola_trascina_il_pallone_in_cerchio_senza_lasciarlo() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(ID, TD.first_ok_seed(), lato)
		var m := misura(tr)
		var pS := "l" if lato > 0.0 else "r"
		var lontano := 0.0
		var a_terra := 0
		var n := 0
		var davanti_min := INF
		var raggio_min := INF
		var raggio_max := 0.0
		for i in tr.size():
			var c: Dictionary = tr[i]
			var g: float = m.giri[i]
			if g < deg_to_rad(45.0) or g > deg_to_rad(250.0):
				continue
			n += 1
			var piede: Vector3 = c.piedi[pS].pos
			lontano = maxf(lontano, Vector2(piede.x - c.palla.x, piede.z - c.palla.z).length())
			if c.piedi[pS].terra:
				a_terra += 1
			# pallone rispetto al corpo che gira: sempre davanti, a distanza quasi costante
			var rel: Vector3 = Basis(Vector3.UP, c.yaw).inverse() * ((c.palla as Vector3) - (c.pos as Vector3))
			davanti_min = minf(davanti_min, rel.z)
			raggio_min = minf(raggio_min, rel.length())
			raggio_max = maxf(raggio_max, rel.length())
		note("lato %+d: suola al più a %.2f m dal pallone, pallone davanti al corpo tra %.2f e %.2f m" % [int(lato), lontano, raggio_min, raggio_max])
		check(n > 20, "campioni del giro (%d)" % n)
		check(lontano < 0.3, "la suola resta sul pallone (%.2f m)" % lontano)
		eq(a_terra, 0, "quel piede non appoggia mai a terra durante il giro")
		check(davanti_min > 0.25, "il pallone resta davanti al corpo che gira (%.2f m)" % davanti_min)
		check(raggio_max < 0.8 and raggio_min > 0.35, "a distanza quasi costante (%.2f - %.2f m)" % [raggio_min, raggio_max])
	return done()


func test_a_meta_giro_il_corpo_copre_il_pallone_e_il_perno_appoggia() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(ID, TD.first_ok_seed(), lato)
		var m := misura(tr)
		var pF := "r" if lato > 0.0 else "l"
		var coperto := 0
		var meta := 0
		var appoggi := 0
		var prima := true
		var salto := 0.0
		var pos_prima := Vector3.INF
		for i in tr.size():
			var c: Dictionary = tr[i]
			var g: float = m.giri[i]
			if g > deg_to_rad(140.0) and g < deg_to_rad(220.0):
				meta += 1
				if (c.palla as Vector3).distance_to(c.dif) > (c.pos as Vector3).distance_to(c.dif):
					coperto += 1
			var terra: bool = c.piedi[pF].terra
			if terra and not prima and g > 0.3 and g < TAU - 0.5:
				appoggi += 1
			if terra and prima and pos_prima != Vector3.INF:
				salto = maxf(salto, (c.piedi[pF].pos as Vector3).distance_to(pos_prima))
			prima = terra
			pos_prima = c.piedi[pF].pos
		check(meta > 0 and coperto * 10 >= meta * 8, "a metà giro il corpo copre il pallone (%d su %d)" % [coperto, meta])
		check(appoggi >= 2, "il piede di perno saltella e riappoggia (%d volte)" % appoggi)
		check(salto < 0.01, "a terra non scivola (%.3f m)" % salto)
	return done()


func test_tocco_dell_altro_piede_e_via_di_corsa() -> bool:
	for lato: float in [1.0, -1.0]:
		var tr := traccia(ID, TD.first_ok_seed(), lato)
		var pF := "r" if lato > 0.0 else "l"
		var v_min := INF
		var dentro := 0.0
		var salto := 0.0
		var tocco := INF
		for i in range(1, tr.size()):
			var c: Dictionary = tr[i]
			if c.t > 0.2 and c.go < 0.5:
				v_min = minf(v_min, (c.vel as Vector3).length())
			dentro = maxf(dentro, c.dentro)
			salto = maxf(salto, (c.palla as Vector3).distance_to(tr[i - 1].palla) / DT - (c.vel as Vector3).length())
			if c.go > 0.1 and c.go < 0.4 and not c.piedi[pF].terra:
				var piede: Vector3 = c.piedi[pF].pos
				tocco = minf(tocco, Vector2(piede.x - c.palla.x, piede.z - c.palla.z).length())
		var u: Dictionary = tr.back()
		check(tocco < 0.3, "dopo il giro l'altro piede tocca il pallone (%.2f m)" % tocco)
		check(v_min >= 1.5, "non si ferma mai (minimo %.1f m/s)" % v_min)
		check(dentro <= 0.06, "corpi staccati (%.2f m)" % dentro)
		check(salto < 14.0, "il pallone non salta (%.1f m/s oltre il corpo)" % salto)
		check((u.palla as Vector3).distance_to(u.palla_moto) < 0.05, "alla fine il pallone è quello del motore")
	return done()


func test_gambe_mai_deformate() -> bool:
	var male := gambe_male(ID)
	check(male.is_empty(), "gambe a posto: %s" % str(male))
	return done()

