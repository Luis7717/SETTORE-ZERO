# Giochetto "Taglio secco" (id `chop`, scripts/partita/mosse/skill/chop.gd), solo grafica. Luis 2026-11-26: "movimenti
# senza senso". Come deve essere: in corsa, saltello, il piede d'appoggio (lato scelto) si pianta davanti al pallone,
# l'altro piede scende da fuori e con l'interno taglia il pallone DIETRO la gamba d'appoggio: il pallone schizza di lato
# (circa 90° rispetto alla corsa di prima) e il portatore riparte da quella parte senza fermarsi.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")

const TAGLIO_MIN := 60.0       # gradi: di quanto cambia direzione il pallone sul taglio (almeno)
const SCHIZZO_MIN := 0.8       # m: quanto va di lato (verso il lato scelto) il pallone in SCHIZZO_T s dal taglio
const SCHIZZO_T := 0.3
const DIETRO_MIN := 0.1        # m: il pallone passa almeno tanto dietro la caviglia d'appoggio
const V_MIN := 1.8             # m/s: il portatore non si pianta


# fa andare motore e coreografia del portatore come vista.gd; ritorna {S, go, avanti, sx, righe: [{t, corpo, v, palla,
# l, r, l_terra, r_terra, yaw, dif}]} con i punti nel mondo (Vector3) e t in s dall'esito; lato = lato fisso (0 = del motore)
static func traccia(sd: int, lato: float = 0.0) -> Dictionary:
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = "chop"
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	if lato != 0.0 and m.duel != null:   # lato fisso: l'altro lato parte con l'altro piede (i due casi dei passi)
		m.duel.side = lato
	var cp: Coreo = null
	var out := {"S": 0.0, "go": -1.0, "righe": [], "avanti": Vector3.ZERO, "sx": Vector3.ZERO}
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble" and e.ok:
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				out.S = float(e.side)
				out.avanti = Basis(Vector3.UP, cp.yaw) * Vector3(0, 0, 1)
				out.sx = Basis(Vector3.UP, cp.yaw) * Vector3(1, 0, 0)
				CD.portatore(cp, String(e.skill), float(e.side), float(e.show))
			elif e.type == "dribble_go" and cp != null:
				out.go = cp.t
				CD.portatore_go(cp)
		m.events.clear()
		if cp == null:
			continue
		cp.passo(DT, p, m.ball)
		if cp.finito:
			break
		var pd := cp.piedi()
		var palla := cp.pallone() if cp.pallone_attivo() else Vector3(m.ball.x, 0.0, -m.ball.y)
		(out.righe as Array).append({"t": cp.t, "corpo": Vector3(p.x, 0.0, -p.y), "v": Vector3(p.vx, 0.0, -p.vy),
			"palla": palla, "l": pd.l.pos, "r": pd.r.pos, "l_terra": pd.l.terra, "r_terra": pd.r.terra, "yaw": cp.yaw,
			"dif": Vector3(o.x, 0.0, -o.y)})
	m.dispose()
	return out


# velocità media del pallone mostrato tra ta e tb (mondo)
static func vel_palla(tr: Dictionary, ta: float, tb: float) -> Vector3:
	var a: Variant = null
	var b: Variant = null
	for r: Dictionary in tr.righe:
		if a == null and float(r.t) >= ta - 1e-6:
			a = r
		if float(r.t) <= tb + 1e-6:
			b = r
	if a == null or b == null or float(b.t) <= float(a.t):
		return Vector3.ZERO
	return ((b.palla as Vector3) - (a.palla as Vector3)) / (float(b.t) - float(a.t))


# momento del taglio: intorno allo scatto, quando il pallone mostrato cambia direzione di più (s)
static func t_taglio(tr: Dictionary) -> float:
	var go := float(tr.go)
	var meglio := go
	var ang := 0.0
	var t := go - 0.02
	while t < go + 0.2:
		var v0 := vel_palla(tr, t - 0.05, t)
		var v1 := vel_palla(tr, t, t + 0.05)
		if v0.length() > 0.3 and v1.length() > 0.3 and v0.angle_to(v1) > ang:
			ang = v0.angle_to(v1)
			meglio = t
		t += 1.0 / 60.0
	return meglio


static func riga_a(tr: Dictionary, t: float) -> Dictionary:
	for r: Dictionary in tr.righe:
		if float(r.t) >= t - 1e-6:
			return r
	return (tr.righe as Array).back()


func test_il_pallone_schizza_di_lato_sul_taglio() -> bool:
	for lato: float in [1.0, -1.0]:
		_schizzo(lato)
	return done()


func _schizzo(lato_fisso: float) -> void:
	# Arrange / Act
	var tr := traccia(TD.first_ok_seed(), lato_fisso)
	var S := float(tr.S)
	var tt := t_taglio(tr)
	var prima := vel_palla(tr, tt - 0.1, tt - 0.01)
	var dopo := vel_palla(tr, tt + 0.01, tt + 0.1)
	var gradi := rad_to_deg(prima.angle_to(dopo))
	var lato := ((riga_a(tr, tt + SCHIZZO_T).palla as Vector3) - (riga_a(tr, tt).palla as Vector3)).dot(tr.sx) * S
	note("lato %+.0f: taglio a %.2f s (scatto a %.2f): il pallone gira di %.0f gradi, va a %.1f m/s, %.2f m di lato in %.1f s" % [S, tt,
		tr.go, gradi, dopo.length(), lato, SCHIZZO_T])
	# Assert
	check(float(tr.go) > 0.0, "lo scatto arriva")
	check(gradi >= TAGLIO_MIN, "taglio netto: il pallone cambia direzione di %.0f gradi" % gradi)
	check(dopo.length() > prima.length(), "dopo il taglio il pallone va più forte di prima (%.1f contro %.1f m/s)" % [dopo.length(), prima.length()])
	check(lato >= SCHIZZO_MIN, "il pallone schizza dal lato scelto: %.2f m" % lato)


func test_il_pallone_passa_dietro_la_gamba_d_appoggio() -> bool:
	for lato: float in [1.0, -1.0]:
		_dietro(lato)
	return done()


func _dietro(lato_fisso: float) -> void:
	# Arrange / Act
	var tr := traccia(TD.first_ok_seed(), lato_fisso)
	var S := float(tr.S)
	var pS := "l" if S > 0.0 else "r"
	var pF := "r" if S > 0.0 else "l"
	var tt := t_taglio(tr)
	var r := riga_a(tr, tt)
	var corsa := vel_palla(tr, tt - 0.1, tt - 0.01).normalized()    # verso della corsa di prima
	var dopo := vel_palla(tr, tt + 0.01, tt + 0.1).normalized()
	# la caviglia d'appoggio rispetto alla linea su cui parte il pallone: davanti (verso la corsa di prima)
	var d: Vector3 = (r[pS] as Vector3) - (r.palla as Vector3)
	d.y = 0.0
	var fuori := d - dopo * d.dot(dopo)
	var davanti := fuori.dot(corsa)
	var indietro := ((r[pS] as Vector3) - (r[pF] as Vector3)).dot(corsa)
	note("lato %+.0f, al taglio: piede d'appoggio a terra %s, a %.2f m davanti alla linea del pallone; piede che taglia %.2f m più indietro" % [
		S, r[pS + "_terra"], davanti, indietro])
	# Assert
	check(r[pS + "_terra"], "al taglio il piede d'appoggio (lato scelto) è piantato a terra")
	check(not r[pF + "_terra"], "al taglio l'altro piede è in aria: è lui che colpisce")
	check(davanti >= DIETRO_MIN, "il pallone passa dietro la gamba d'appoggio (%.2f m)" % davanti)
	check(indietro > 0.0, "il piede che taglia sta dietro quello d'appoggio")


func test_arriva_in_corsa_e_riparte_dal_lato_scelto() -> bool:
	# Arrange / Act
	var tr := traccia(TD.first_ok_seed())
	var S := float(tr.S)
	var go := float(tr.go)
	var v_min := INF
	for r: Dictionary in tr.righe:
		if float(r.t) > 0.2:
			v_min = minf(v_min, (r.v as Vector3).length())
	var v_dopo: Vector3 = riga_a(tr, go + 0.2).v
	var mis := TC.gira(TD.first_ok_seed(), true, "chop")
	note("velocità minima %.1f m/s; 0,2 s dopo lo scatto %.1f m/s, %.1f verso il lato scelto; corpi dentro %.2f m" % [v_min,
		v_dopo.length(), v_dopo.dot(tr.sx) * S, mis.dentro])
	# Assert
	check(v_min >= V_MIN, "non si pianta: minimo %.1f m/s" % v_min)
	check(v_dopo.dot(tr.sx) * S > 1.0, "riparte dal lato scelto")
	check(mis.dentro <= TC.DENTRO_MAX, "i due corpi non si compenetrano (%.2f m)" % mis.dentro)
	check(mis.salto_piede <= 0.02, "piedi fermi mentre appoggiano (%.3f m)" % mis.salto_piede)
	check(mis.salto_palla <= TC.V_PALLA_MAX, "il pallone non salta (%.1f m/s in più)" % mis.salto_palla)
	check(mis.fine_palla <= 0.05, "alla fine il pallone torna quello del motore (%.2f m)" % mis.fine_palla)
	return done()


# stampa il movimento passo passo nel riferimento dell'inizio (per regolare la coreografia); controlla solo che ci sia
func test_traccia_del_movimento() -> bool:
	var tr := traccia(TD.first_ok_seed())
	var S := float(tr.S)
	var r0: Dictionary = tr.righe[0]
	var n := 0
	for r: Dictionary in tr.righe:
		n += 1
		if n % 3 != 1:
			continue
		var c: Vector3 = (r.corpo as Vector3) - (r0.corpo as Vector3)
		var b: Vector3 = (r.palla as Vector3) - (r.corpo as Vector3)
		var l: Vector3 = (r.l as Vector3) - (r.corpo as Vector3)
		var d: Vector3 = (r.r as Vector3) - (r.corpo as Vector3)
		var df: Vector3 = (r.dif as Vector3) - (r.corpo as Vector3)
		note("t %.2f%s corpo S %.2f av %.2f v(S %.1f av %.1f) yaw %.2f | palla S %.2f av %.2f | l%s S %.2f av %.2f h %.2f | r%s S %.2f av %.2f h %.2f | dif S %.2f av %.2f" % [
			r.t, "*" if float(r.t) >= float(tr.go) else " ", c.dot(tr.sx) * S, c.dot(tr.avanti), (r.v as Vector3).dot(tr.sx) * S, (r.v as Vector3).dot(tr.avanti),
			wrapf(float(r.yaw) - float(r0.yaw), -PI, PI) * S, b.dot(tr.sx) * S, b.dot(tr.avanti),
			"_" if r.l_terra else "^", l.dot(tr.sx) * S, l.dot(tr.avanti), l.y, "_" if r.r_terra else "^", d.dot(tr.sx) * S, d.dot(tr.avanti), d.y,
			df.dot(tr.sx) * S, df.dot(tr.avanti)])
	check((tr.righe as Array).size() > 30, "la coreografia dura")
	return done()
