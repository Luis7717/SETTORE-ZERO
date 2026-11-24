# Studio dei movimenti della CPU secondo stile di gioco e formazione (non è un test: il runner lo ignora).
# Gioca partite a seme fisso con la squadra "S" (stile e formazione da provare) contro una squadra equilibrata 4-4-2
# e misura forma in campo, passaggi, pressing, linea difensiva e cose strane. Opzioni del gioco vere (testa,
# portaAuto, rifiniture, falli, contatti, riprese).
#   $G --headless --path godot -s res://tools/studio_stili.gd -- --modo=cpu --att=fasce --dif=equilibrata --formazione=4-3-3 --partite=6
#   --modo=cpu    S (CPU) contro CPU equilibrata, metà partite in casa e metà fuori
#   --modo=umano  S è la squadra della persona simulata (tools/dito_motore.gd): si misurano i compagni CPU
#   --modo=contro S (CPU) contro la persona simulata (squadra equilibrata)
#   --seme=1 (primo seme) · --tempo=150 · --forza=60 · --png=percorso.png (mappa di calore: sinistra S in attacco,
#   destra S in difesa; S attacca verso l'alto, x del campo; punti = posizione media dei ruoli: giallo P, blu D, verde C, rosso A)
#   --debug-gk stampa i momenti col portiere di S oltre GK_FUORI m dalla sua linea di fondo
# Stessi semi per ogni configurazione: le differenze tra stili non vengono dal caso delle partite.
# Stampa "STUDIO|{json}" con i numeri medi (somma di più processi: tools fuori dal gioco).
extends SceneTree

const H := preload("res://tests/harness.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const Dito := preload("res://tools/dito_motore.gd")

const FRAME := 1.0 / 60.0
const TEMPO_K := 14.0
const CAMPIONE := 0.25        # s di gioco tra due campioni delle posizioni
const FASCIA_X := 18.0        # pallone oltre questa |x| = sulla fascia
const LUNGO := 25.0           # passaggio lungo (m)
const PRESS_R := 6.0          # giocatori entro tanti metri dal portatore avversario = in pressing
const FERMO_M := 1.5          # giocatore che resta entro tanti metri ...
const FERMO_S := 6.0          # ... per tanti secondi di gioco (palla in gioco) = fermo
const GIRO_M := 3.0           # inversione di marcia in lunghezza di almeno tanti metri = avanti e indietro
const VICINI_M := 2.0         # due compagni più vicini di così = ammassati
const CELLA := 2.0            # lato della cella della mappa di calore (m)
const SCALA := 6              # pixel per cella della mappa di calore
const GK_FUORI := 18.0        # portiere oltre tanti metri dalla propria linea di fondo = fuori posto (--debug-gk lo stampa)

var tot := {}
var slot := {}               # "a3" / "d3" -> [somma x, somma y, n]
var heat := {"a": [], "d": []}
var ruoli: Array = []


func _init() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var nx := int(C.W / CELLA)
	var ny := int(C.L / CELLA)
	heat.a.resize(nx * ny); heat.a.fill(0.0)
	heat.d.resize(nx * ny); heat.d.fill(0.0)
	var partite := int(opz.get("partite", "6"))
	var seme0 := int(opz.get("seme", "1"))
	for k in partite:
		_partita(seme0 + k, k, opz)
	var out := _riassunto(partite)
	out["config"] = "%s|%s|%s|%s" % [opz.get("modo", "cpu"), opz.get("att", "equilibrato"), opz.get("dif", "equilibrata"), opz.get("formazione", "4-4-2")]
	print("STUDIO|" + JSON.stringify(out))
	if opz.has("png"):
		_png(String(opz.png))
	H.disposeAll()
	quit(0)


func _add(k: String, v: float = 1.0) -> void:
	tot[k] = float(tot.get(k, 0.0)) + v


func _v(k: String) -> float:
	return float(tot.get(k, 0.0))


func _partita(sd: int, k: int, opz: Dictionary) -> void:
	var modo: String = opz.get("modo", "cpu")
	var forza := float(opz.get("forza", "60"))
	var form: String = opz.get("formazione", "4-4-2")
	var s_team: int = (k % 2) if modo == "cpu" else (0 if modo == "umano" else 1)
	var ts_ := H.mkTeam("S", forza, sd * 7 + 1, form)
	var tb := H.mkTeam("B", forza, sd * 13 + 5, "4-4-2")
	ts_["stileAtt"] = opz.get("att", "equilibrato")
	ts_["stileDif"] = opz.get("dif", "equilibrata")
	var teams: Array = [ts_, tb] if s_team == 0 else [tb, ts_]
	var umano: bool = modo != "cpu"
	var m := H.newMatch(sd, float(opz.get("tempo", "150")), [umano, false], teams[0], teams[1], "sereno",
		{"portaAuto": true, "testa": true, "rifiniture": true, "falli": true, "contatti": true, "riprese": true, "parata": true, "attacco": not opz.has("senza-attacco")})
	if ruoli.is_empty():
		for p: R.Player in m.players:
			if p.team == s_team:
				ruoli.append([p.pos, p.bx, p.by])
	var dito = Dito.new(sd * 31 + 7) if umano else null
	var st := {"ts": 1.0, "testa_reale": -1.0, "camp": 0.0, "poss": -1, "az": null, "pass": null, "fase": "play",
		"fermo": {}, "giro": {}}
	var frames := 0
	while m.phase != "full" and frames < 60 * 60 * 40:
		frames += 1
		if dito != null:
			dito.passo(m, FRAME, FRAME * float(st.ts))
			_tempo(m, dito, st)
		var sdt: float = FRAME * float(st.ts)
		if sdt > 0.0:
			m.step(sdt)
		if m.phase == "half":
			m.startSecondHalf()
		_conta(m, st, s_team, sdt)
		m.events.clear()
	_chiudi_azione(m, st, s_team)
	_add("partite")
	_add("gioco_s", m.time)
	_add("gf", m.score[s_team])
	_add("gs", m.score[1 - s_team])
	_add("tiri", m.stats.shots[s_team])
	_add("tiri_sub", m.stats.shots[1 - s_team])
	var pt: float = maxf(0.001, m.stats.poss[0] + m.stats.poss[1])
	_add("poss", m.stats.poss[s_team] / pt)


## velocità del tempo come gioco.gd (rallenty e fermatempo del colpo di testa), copiata da controllo_gameplay.gd
func _tempo(m, dito, st: Dictionary) -> void:
	var hw = m.headWin
	if hw != null and hw.team == 0 and not hw.lost:
		if hw.aimed:
			st.testa_reale = -1.0
			st.ts = 1.0
			return
		st.testa_reale = 0.0 if st.testa_reale < 0.0 else st.testa_reale + FRAME
		if st.testa_reale < Dito.TESTA_FERMO_S or dito.draw_mode == "head":
			st.ts = 0.0
			return
		m.headExpire()
		st.testa_reale = -1.0
		st.ts = 1.0
		return
	st.testa_reale = -1.0
	st.ts += (dito.velocita_voluta(m) - st.ts) * minf(1.0, FRAME * TEMPO_K)


# coordinate dal punto di vista della squadra S: y' 0 = propria linea di fondo .. 100 = porta avversaria
func _yy(y: float, s: int) -> float:
	return y * (-1.0 if s else 1.0) + C.HL


# x resta quella del campo: i posti della formazione (bx) sono gli stessi per le due squadre
func _xx(x: float, _s: int) -> float:
	return x


func _conta(m, st: Dictionary, s: int, sdt: float) -> void:
	var b: R.Ball = m.ball
	# eventi
	for e: Dictionary in m.events:
		match String(e.type):
			"kick":
				var p: R.Player = e.p
				_fine_passaggio(m, st, s, b.x, b.y, false)
				if p.team == s and (e.kind == "ground" or e.kind == "loft"):
					st.pass = {"x": p.x, "y": p.y, "loft": e.kind == "loft", "p": p}
					_add("pass_n")
					if e.kind == "loft":
						_add("pass_alti")
					if st.az != null:
						st.az.passes += 1
			"out":
				_fine_passaggio(m, st, s, b.x, b.y, false)
			"offside":
				var p2: R.Player = e.p
				_add("fuorigioco_presi" if p2.team == s else "fuorigioco_fatti")
	if m.phase != "play":
		if st.fase == "play":
			_fine_passaggio(m, st, s, b.x, b.y, false)
		st.fase = m.phase
		if m.phase == "restart" and m.restart != null and int(m.restart.team) != int(st.poss):
			_chiudi_azione(m, st, s)
			st.poss = int(m.restart.team)
			_apri_azione(m, st, s, false, 0.0)
		return
	st.fase = "play"
	# possesso e azioni
	var o: R.Player = b.owner
	if o != null:
		if st.pass != null and o != st.pass.p:
			_fine_passaggio(m, st, s, o.x, o.y, o.team == s)
		if o.team != int(st.poss):
			var rec: bool = int(st.poss) >= 0
			_chiudi_azione(m, st, s)
			st.poss = o.team
			_apri_azione(m, st, s, rec, _yy(o.y, s))
		if st.az != null and o.team == s:
			var yo := _yy(o.y, s)
			var az: Dictionary = st.az
			if yo > 70.0 and az.t30 < 0.0:
				az.t30 = m.time - float(az.t0)
			if yo > 100.0 - C.BOX_D and absf(o.x) < C.BOX_W / 2.0:
				az.box = true
	if o != null and o.team == s:
		_add("own_s", sdt)
		if absf(b.x) > FASCIA_X:
			_add("fascia_s", sdt)
	# campioni delle posizioni
	st.camp = float(st.camp) + sdt
	if st.camp >= CAMPIONE:
		st.camp = 0.0
		_campione(m, st, s)


func _fine_passaggio(m, st: Dictionary, s: int, ex: float, ey: float, riuscito: bool) -> void:
	var ps: Variant = st.pass
	if ps == null:
		return
	st.pass = null
	var d: float = C.hyp(ex - ps.x, ey - ps.y)
	_add("pass_m", d)
	_add("pass_chiusi")
	if d > LUNGO:
		_add("pass_lunghi")
	if riuscito:
		_add("pass_ok")
	if absf(ps.x) > FASCIA_X - 2.0 and _yy(ps.y, s) > 66.0 and absf(ex) < C.BOX_W / 2.0 and _yy(ey, s) > 100.0 - C.BOX_D - 2.0:
		_add("cross")


func _apri_azione(m, st: Dictionary, s: int, rec: bool, yrec: float) -> void:
	if int(st.poss) == s:
		st.az = {"t0": m.time, "passes": 0, "t30": -1.0, "box": false, "rec": rec, "y0": yrec}
		if rec:
			_add("rec_n")
			_add("rec_y", yrec)
			if yrec > 50.0:
				_add("rec_alti")
	else:
		st.az = null


func _chiudi_azione(m, st: Dictionary, s: int) -> void:
	var az: Variant = st.az
	if az == null:
		return
	st.az = null
	_add("az_n")
	_add("az_s", m.time - float(az.t0))
	_add("az_pass", az.passes)
	if az.box:
		_add("az_box")
	if az.rec and az.y0 < 50.0:
		_add("ripart_n")
		if az.t30 >= 0.0 and az.t30 <= 10.0:
			_add("ripart_30")
			_add("ripart_30_s", az.t30)


func _campione(m, st: Dictionary, s: int) -> void:
	var b: R.Ball = m.ball
	var ph: String = "a" if int(st.poss) == s else ("d" if int(st.poss) == 1 - s else "")
	if ph == "":
		return
	_add("camp_" + ph)
	var ys := {"D": [], "C": [], "A": []}
	var miny := 999.0
	var maxy := -999.0
	var minx := 999.0
	var maxx := -999.0
	var cx := 0.0
	var cy := 0.0
	var n := 0
	var mine: Array = []
	var opp: Array = []
	for p: R.Player in m.players:
		if p.off:
			continue
		if p.team != s:
			if p.pos != "P":
				opp.append(p)
			continue
		var x := _xx(p.x, s)
		var y := _yy(p.y, s)
		var key := ph + str(p.i)
		var sl: Array = slot.get(key, [0.0, 0.0, 0.0])
		slot[key] = [sl[0] + x, sl[1] + y, sl[2] + 1.0]
		if p.pos == "P":
			_add("gk_y_" + ph, y)
			if y > GK_FUORI:
				_add("gk_fuori_" + ph)
				if OS.get_cmdline_user_args().has("--debug-gk"):
					print("GK fuori t=%.1f fase %s y'=%.1f x=%.1f stato %s palla (%.1f,%.1f h%.1f) owner %s kick %s" % [m.time, ph, y, p.x, p.state,
						b.x, b.y, b.h, b.owner.name if b.owner != null else "-", b.kick.type if b.kick != null else "-"])
			_add("gk_max_" + ph, 0.0)
			tot["gk_max_" + ph] = maxf(float(tot["gk_max_" + ph]), y)
			continue
		mine.append(p)
		ys[p.pos].append(y)
		miny = minf(miny, y)
		maxy = maxf(maxy, y)
		minx = minf(minx, x)
		maxx = maxf(maxx, x)
		cx += x
		cy += y
		n += 1
		var ci := clampi(int((x + C.HW) / CELLA), 0, int(C.W / CELLA) - 1)
		var cj := clampi(int(y / CELLA), 0, int(C.L / CELLA) - 1)
		heat[ph][cj * int(C.W / CELLA) + ci] += 1.0
		if absf(p.x) > C.HW + 1.0 or absf(p.y) > C.HL + 1.0:
			_add("fuori_campo")
		_fermo_giro(m, st, p, x, y)
	if n == 0:
		return
	cx /= n
	cy /= n
	var comp := 0.0
	for p: R.Player in mine:
		comp += C.hyp(_xx(p.x, s) - cx, _yy(p.y, s) - cy)
	_add("lungo_" + ph, maxy - miny)
	_add("largo_" + ph, maxx - minx)
	_add("compatto_" + ph, comp / n)
	var md := _media(ys.D)
	var mc := _media(ys.C)
	var ma := _media(ys.A)
	_add("lineaD_" + ph, md)
	_add("dc_" + ph, mc - md)
	_add("ca_" + ph, ma - mc)
	_add("Dstd_" + ph, _dev(ys.D))
	if not ys.A.is_empty() and not ys.D.is_empty() and ys.D.max() > ys.A.max() + 5.0:
		_add("D_oltre_A_" + ph)
	# ammassati
	for i in mine.size():
		for j in range(i + 1, mine.size()):
			if C.hyp(mine[i].x - mine[j].x, mine[i].y - mine[j].y) < VICINI_M:
				_add("vicini_" + ph)
	var o: R.Player = b.owner
	if ph == "d":
		# pressing, spazio al portatore, marcatura
		if o != null and o.team != s:
			var np := 0
			var dmin := 999.0
			for p: R.Player in mine:
				var d: float = C.hyp(p.x - o.x, p.y - o.y)
				dmin = minf(dmin, d)
				if d < PRESS_R:
					np += 1
			var alto: bool = _yy(o.y, s) > 50.0
			_add("press_n_" + ("alto" if alto else "basso"), np)
			_add("press_c_" + ("alto" if alto else "basso"))
			_add("spazio_port", dmin)
			_add("spazio_c")
		var sm := 0.0
		var nm := 0
		for p: R.Player in mine:
			if p.pos == "A":
				continue
			var dd := 999.0
			for q: R.Player in opp:
				if q != o:
					dd = minf(dd, C.hyp(p.x - q.x, p.y - q.y))
			sm += dd
			nm += 1
		if nm > 0:
			_add("marca_m", sm / nm)
		# avversari liberi (nessun giocatore di S entro 5 m) nella metà campo di S
		for q: R.Player in opp:
			if _yy(q.y, s) < 50.0 and q != o:
				var dd2 := 999.0
				for p: R.Player in mine:
					dd2 = minf(dd2, C.hyp(p.x - q.x, p.y - q.y))
				if dd2 > 5.0:
					_add("liberi_d")
		_add("palla_lineaD", _yy(b.y, s) - md)
	else:
		if o != null and o.team == s and _yy(o.y, s) > 67.0:
			var nb := 0
			for p: R.Player in mine:
				if _yy(p.y, s) > 100.0 - C.BOX_D and absf(p.x) < C.BOX_W / 2.0:
					nb += 1
			_add("in_area", nb)
			_add("in_area_c")


func _fermo_giro(m, st: Dictionary, p: R.Player, x: float, y: float) -> void:
	var k := p.i
	var f: Array = st.fermo.get(k, [x, y, 0.0, false])
	if C.hyp(x - f[0], y - f[1]) > FERMO_M:
		f = [x, y, 0.0, false]
	else:
		f[2] += CAMPIONE
		if f[2] >= FERMO_S and not f[3]:
			f[3] = true
			_add("fermi")
	st.fermo[k] = f
	var g: Array = st.giro.get(k, [y, 0.0])  # [estremo, verso]
	if g[1] >= 0.0 and y > g[0]:
		g[0] = y
		g[1] = 1.0
	elif g[1] <= 0.0 and y < g[0]:
		g[0] = y
		g[1] = -1.0
	elif absf(y - g[0]) > GIRO_M:
		_add("giri")
		g = [y, -g[1]]
	st.giro[k] = g


func _media(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v: float in a:
		s += v
	return s / a.size()


func _dev(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var mu := _media(a)
	var s := 0.0
	for v: float in a:
		s += (v - mu) * (v - mu)
	return sqrt(s / a.size())


func _riassunto(n: int) -> Dictionary:
	var ca := maxf(1.0, _v("camp_a"))
	var cd := maxf(1.0, _v("camp_d"))
	var minuti: float = _v("gioco_s") / 60.0
	var o := {
		"partite": n,
		"gf": _v("gf") / n, "gs": _v("gs") / n, "tiri": _v("tiri") / n, "tiri_sub": _v("tiri_sub") / n, "poss": 100.0 * _v("poss") / n,
		# attacco
		"pass": _v("pass_n") / n, "pass_m": _v("pass_m") / maxf(1.0, _v("pass_chiusi")),
		"lunghi%": 100.0 * _v("pass_lunghi") / maxf(1.0, _v("pass_chiusi")), "alti%": 100.0 * _v("pass_alti") / maxf(1.0, _v("pass_n")),
		"riusciti%": 100.0 * _v("pass_ok") / maxf(1.0, _v("pass_chiusi")), "cross": _v("cross") / n,
		"fascia%": 100.0 * _v("fascia_s") / maxf(0.01, _v("own_s")),
		"azioni": _v("az_n") / n, "pass_az": _v("az_pass") / maxf(1.0, _v("az_n")), "durata_az": _v("az_s") / maxf(1.0, _v("az_n")),
		"az_area%": 100.0 * _v("az_box") / maxf(1.0, _v("az_n")),
		"ripart30%": 100.0 * _v("ripart_30") / maxf(1.0, _v("ripart_n")), "ripart30_s": _v("ripart_30_s") / maxf(1.0, _v("ripart_30")),
		"in_area": _v("in_area") / maxf(1.0, _v("in_area_c")),
		# difesa
		"press_alto": _v("press_n_alto") / maxf(1.0, _v("press_c_alto")), "press_basso": _v("press_n_basso") / maxf(1.0, _v("press_c_basso")),
		"spazio_port": _v("spazio_port") / maxf(1.0, _v("spazio_c")),
		"recuperi": _v("rec_n") / n, "rec_y": _v("rec_y") / maxf(1.0, _v("rec_n")), "rec_alti%": 100.0 * _v("rec_alti") / maxf(1.0, _v("rec_n")),
		"fuorigioco_fatti": _v("fuorigioco_fatti") / n, "fuorigioco_presi": _v("fuorigioco_presi") / n,
		"marca_m": _v("marca_m") / cd, "liberi_d": _v("liberi_d") / cd, "palla_lineaD": _v("palla_lineaD") / cd,
		# cose strane
		"fermi_pm": _v("fermi") / maxf(1.0, minuti), "giri_pgm": _v("giri") / maxf(1.0, minuti) / 10.0,
		"fuori_campo": _v("fuori_campo") / n,
	}
	for ph: String in ["a", "d"]:
		var c := ca if ph == "a" else cd
		o["lungo_" + ph] = _v("lungo_" + ph) / c
		o["largo_" + ph] = _v("largo_" + ph) / c
		o["compatto_" + ph] = _v("compatto_" + ph) / c
		o["lineaD_" + ph] = _v("lineaD_" + ph) / c
		o["dc_" + ph] = _v("dc_" + ph) / c
		o["ca_" + ph] = _v("ca_" + ph) / c
		o["Dstd_" + ph] = _v("Dstd_" + ph) / c
		o["D_oltre_A%_" + ph] = 100.0 * _v("D_oltre_A_" + ph) / c
		o["vicini_" + ph] = _v("vicini_" + ph) / c
		o["gk_y_" + ph] = _v("gk_y_" + ph) / c
		o["gk_max_" + ph] = _v("gk_max_" + ph)
		o["gk_fuori%_" + ph] = 100.0 * _v("gk_fuori_" + ph) / c
	var sl := {}
	for k: String in slot:
		var a: Array = slot[k]
		sl[k] = [snappedf(a[0] / a[2], 0.1), snappedf(a[1] / a[2], 0.1)]
	o["slot"] = sl
	o["ruoli"] = ruoli
	return o


func _png(path: String) -> void:
	var nx := int(C.W / CELLA)
	var ny := int(C.L / CELLA)
	var cw := SCALA
	var gap := 12
	var img := Image.create(nx * cw * 2 + gap, ny * cw, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.1))
	for pi in 2:
		var ph: String = "a" if pi == 0 else "d"
		var h: Array = heat[ph]
		var mx := 0.0
		for v in h:
			mx = maxf(mx, v)
		var ox := pi * (nx * cw + gap)
		for j in ny:
			for i in nx:
				var v: float = sqrt(h[j * nx + i] / maxf(1.0, mx))
				var col := Color(0.08, 0.3, 0.12).lerp(Color(1.0, 0.85, 0.2), v) if v < 0.6 else Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.2, 0.1), (v - 0.6) / 0.4)
				img.fill_rect(Rect2i(ox + i * cw, (ny - 1 - j) * cw, cw, cw), col)
		# linee: metà campo, aree
		var py := func(y: float) -> int: return int((C.L - y) / CELLA * cw)
		var pxf := func(x: float) -> int: return ox + int((x + C.HW) / CELLA * cw)
		img.fill_rect(Rect2i(ox, py.call(50.0), nx * cw, 1), Color.WHITE)
		for yb: float in [C.BOX_D, C.L - C.BOX_D]:
			img.fill_rect(Rect2i(pxf.call(-C.BOX_W / 2.0), py.call(yb), int(C.BOX_W / CELLA * cw), 1), Color.WHITE)
		for k: String in slot:
			if not k.begins_with(ph):
				continue
			var a: Array = slot[k]
			var i2 := int(k.substr(1))
			var pos: String = ruoli[i2][0] if i2 < ruoli.size() else "C"
			var col2: Color = {"P": Color.YELLOW, "D": Color(0.3, 0.5, 1.0), "C": Color(0.2, 1.0, 0.4), "A": Color(1.0, 0.25, 0.25)}[pos]
			var x0: int = pxf.call(a[0] / a[2])
			var y0: int = py.call(a[1] / a[2])
			img.fill_rect(Rect2i(x0 - 5, y0 - 5, 11, 11), Color.WHITE)
			img.fill_rect(Rect2i(x0 - 4, y0 - 4, 9, 9), col2)
	img.save_png(path)
