# Gambe dei giochetti del dribbling, per tutti i giochetti del registro (coreo_skill.gd IDS) e per il dribbling fallito, portatore e difensore
# (solo grafica; Luis 2026-11-26: "le gambe lampeggiano, non si capisce nulla", "si incrociano le gambe"):
#   - niente lampi: da un fotogramma all'altro (60 al secondo veri; durante il rallenty della regia del dribbling il
#     tempo di partita va al 30%, quindi lì un fotogramma è 1/200 s di partita) caviglie e ginocchia non saltano (piede
#     che si teletrasporta, ginocchio che si ribalta);
#   - niente gambe una dentro l'altra: stinchi e cosce delle due gambe dello stesso giocatore restano staccati;
#   - niente gambe deformate (Luis: "alla fine della veronica le gambe si deformavano"): la caviglia mai più lontana
#     dall'anca della lunghezza della gamba (gamba stirata, piede che non arriva dove appoggia) né schiacciata contro
#     l'anca, e il ginocchio piega sempre in avanti rispetto al corpo, mai al contrario.
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const CS := preload("res://scripts/partita/mosse/coreo_skill.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")
const Regia := preload("res://scripts/partita/dribbling_regia.gd")
const USCITA_T := 0.15       # s di partita: finito il rallenty della regia il tempo torna normale in circa tanto
# m per fotogramma vero rispetto al corpo (0,3 m = 18 m/s a schermo: più di un calcio)
const SALTO_CAVIGLIA := 0.3
const SALTO_GINOCCHIO := 0.3
# m: quanto possono entrare una nell'altra le due gambe (capsule: stinco 0,075 e coscia 0,106 di raggio a schermo);
# un po' ci sta (piedi che stringono il pallone, ginocchia che si sfiorano), di più si vedono attraversarsi
const DENTRO_GAMBE := 0.12
# ... ma dove una gamba passa apposta raccolta dietro o intorno all'altra (trascinamento dietro l'appoggio, giro) un po' di più
const DENTRO_ID := {"cruyff": 0.16, "veronica": 0.16,
	# provvisori, copiati da quei due
	"colpetto_giro": 0.16, "giro_tocco": 0.16, "veronica_classe": 0.16}
const ALLUNGO_MAX := 1.12    # frazione della gamba (anca → caviglia voluta): un piede a terra fa un passo a 0,93, col saltello (altro
# piede in volo) a 1,02 misurati dal bacino dritto; col bacino inclinato arriva a 1,1 (il piede scivola un attimo di ~10 cm)
const ALLUNGO_MIN := 0.25    # ... e sotto è schiacciata contro l'anca (ginocchio che esce dal corpo)
const GINOCCHIO_DIETRO := -0.35   # quanto il ginocchio può piegare all'indietro (parte del verso del corpo, −1 = tutto)
const PESO_MIN := 0.5        # si misura quando la coreografia comanda la posa almeno tanto (sotto c'è il clip di corsa)


# punti delle gambe rispetto al corpo e segmenti nel mondo: {pt: {cav_l, cav_r, gin_l, gin_r}, seg: [...]}
static func gambe(c: Coreo, p: R.Player, pb: Vector3, ph: float) -> Dictionary:
	var N := TC.figura(c, p)
	var seg := Coreo.segmenti(N, c.frame(N, pb, ph))
	var base := Vector3(p.x, 0.0, -p.y)
	var pt := {}
	for s: Array in seg:
		var nome := String(s[3])
		if nome.begins_with("gamba_"):
			pt["gin_" + nome.right(1)] = (s[0] as Vector3) - base
			pt["cav_" + nome.right(1)] = (s[1] as Vector3) - base
	# deformazioni: quanto è allungata ogni gamba e da che parte piega il ginocchio (rispetto al davanti del corpo)
	var avanti := N.basis.z.normalized()
	var pd := c.piedi()
	var lungo := 0.0
	var corto := INF
	var gin := INF
	for s: Array in seg:
		var nome := String(s[3])
		if not nome.begins_with("coscia_"):
			continue
		var anca: Vector3 = s[0]
		var cav: Vector3 = pd[nome.right(1)].pos
		var d := anca.distance_to(cav) / (Coreo.GAMBA * TC.SCALA.y)
		lungo = maxf(lungo, d)
		corto = minf(corto, d)
		var u := (cav - anca).normalized()
		var w := (s[1] as Vector3) - anca
		w -= u * w.dot(u)
		if w.length() > 0.08 * TC.SCALA.y:   # (gamba quasi dritta: il ginocchio non piega da nessuna parte)
			gin = minf(gin, w.normalized().dot(avanti))
	return {"pt": pt, "seg": seg, "lungo": lungo, "corto": corto, "gin_av": gin}


# quanto entrano una nell'altra le due gambe dello stesso corpo (le cosce tra loro no: partono vicine dal bacino):
# [m, "pezzo/pezzo"]
static func dentro_gambe(seg: Array) -> Array:
	var peggio := 0.0
	var dove := ""
	for x: Array in seg:
		for y: Array in seg:
			var nx := String(x[3])
			var ny := String(y[3])
			if not nx.ends_with("_l") or not ny.ends_with("_r"):
				continue
			if nx.begins_with("coscia") and ny.begins_with("coscia"):
				continue
			var d := float(x[2]) + float(y[2]) - Coreo.dist_segmenti(x[0], x[1], y[0], y[1])
			if d > peggio:
				peggio = d
				dove = nx + "/" + ny
	return [peggio, dove]


# velocità del tempo a schermo `t` s di partita dopo l'esito (regia del dribbling: rallenty fino a `fine_r`, poi normale)
static func tempo_a(t: float, fine_r: float) -> float:
	return lerpf(Regia.TS_GIOCHETTO, 1.0, clampf((t - fine_r) / USCITA_T, 0.0, 1.0))


# motore e coreografie insieme come vista.gd; per "p" (portatore) e "o" (difensore): salto massimo per fotogramma di
# caviglie e ginocchia e gambe più dentro, con l'istante (s dall'esito) in cui succede
static func misura(id: String, ok: bool, sd: int = -1, traccia: String = "", tr_da: float = 0.0, tr_a: float = 9.0) -> Dictionary:
	if sd < 0:
		sd = TD.first_ok_seed()
	var s := TD.setup(sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = id
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99 if ok else 1
	o.st.dif = 20 if ok else 99
	m.userDribble(0)
	var cc := {}
	var out := {"esito": null}
	for chi: String in ["p", "o"]:
		out[chi] = {"cav": 0.0, "cav_t": 0.0, "gin": 0.0, "gin_t": 0.0, "dentro": 0.0, "dentro_t": 0.0, "dentro_dove": "",
			"lungo": 0.0, "lungo_t": 0.0, "corto": INF, "corto_t": 0.0, "gin_av": INF, "gin_av_t": 0.0}
	var prima := {}
	var fine_r := 0.0
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble":
				out.esito = e.ok
				fine_r = (float(e.show) + float(Regia.DOPO_SKILL.get(String(e.skill), Regia.DOPO_OK))) if e.ok else Regia.DOPO_KO
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cc.p = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cc.o = Coreo.new(o, 1.0, TC.SCALA, TC.caviglie(o), bv, Vector3.ZERO)
				(cc.p as Coreo).ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				(cc.o as Coreo).ostacolo = func() -> Vector3: return Vector3(p.x, 0.0, -p.y)
				if e.ok:
					CD.portatore(cc.p, String(e.skill), float(e.side), float(e.show))
					CD.difensore_vuoto(cc.o, float(e.side), float(e.show), func() -> Vector3: return (cc.p as Coreo).pallone(), String(e.skill))
				else:
					CD.inciampo(cc.p)
					CD.contrasto(cc.o, 0.0, m.ball.owner == o)
			elif e.type == "dribble_go" and not cc.is_empty():
				CD.portatore_go(cc.p)
				CD.difensore_go(cc.o)
		m.events.clear()
		if cc.is_empty():
			continue
		var cp: Coreo = cc.p
		var finiti := true
		for chi: String in ["p", "o"]:
			var c: Coreo = cc[chi]
			var g: R.Player = p if chi == "p" else o
			if c.finito:
				prima.erase(chi)
				continue
			finiti = false
			c.passo(DT, g, m.ball)
			if c.peso < PESO_MIN or c.t >= c.fine:
				prima.erase(chi)
				continue
			var pb := cp.pallone() if cp.pallone_attivo() else Vector3(m.ball.x, 0.0, -m.ball.y)
			var r := gambe(c, g, pb, cp.pallone_h() if cp.pallone_attivo() else 0.0)
			var mis: Dictionary = out[chi]
			var d := dentro_gambe(r.seg)
			if float(d[0]) > float(mis.dentro):
				mis.dentro = d[0]
				mis.dentro_t = c.t
				mis.dentro_dove = d[1]
			if float(r.lungo) > float(mis.lungo):
				mis.lungo = r.lungo
				mis.lungo_t = c.t
			if float(r.corto) < float(mis.corto):
				mis.corto = r.corto
				mis.corto_t = c.t
			if float(r.gin_av) < float(mis.gin_av):
				mis.gin_av = r.gin_av
				mis.gin_av_t = c.t
			if traccia == chi and c.t >= tr_da and c.t <= tr_a:
				var pd := c.piedi()
				var riga_t := "%.3f" % c.t
				for k: String in ["cav_l", "cav_r", "gin_l", "gin_r"]:
					var v: Vector3 = r.pt[k]
					riga_t += "  %s(%5.2f %5.2f %5.2f)%s" % [k, v.x, v.y, v.z, ("T" if pd[k.right(1)].terra else " ") if k.begins_with("cav") else ""]
					if prima.has(chi):
						riga_t += " %.2f" % v.distance_to(prima[chi][k])
				for sd3: String in ["l", "r"]:
					var evs: Array = c._piedi[sd3].ev
					riga_t += "  %s>%s" % [sd3, ("%s@%.3f" % [evs[0].tipo, evs[0].t]) if not evs.is_empty() else "-"]
				print(riga_t + "  yaw %.2f dentro %.2f" % [c.yaw, d[0]])
			if prima.has(chi):
				for k: String in r.pt:
					var salto := (r.pt[k] as Vector3).distance_to(prima[chi][k]) * tempo_a(c.t, fine_r)
					var nome := k.left(3)
					if salto > float(mis[nome]):
						mis[nome] = salto
						mis[nome + "_t"] = c.t
			prima[chi] = r.pt
		if finiti:
			break
	m.dispose()
	return out


static func riga(id: String, chi: String, mis: Dictionary) -> String:
	return ("%s %s: caviglia %.2f m (a %.2f s), ginocchio %.2f m (a %.2f s), gambe dentro %.2f m (a %.2f s, %s), " +
		"gamba lunga %.2f (a %.2f s) corta %.2f (a %.2f s), ginocchio in avanti %.2f (a %.2f s)") % [id,
		"portatore" if chi == "p" else "difensore", mis.cav, mis.cav_t, mis.gin, mis.gin_t, mis.dentro, mis.dentro_t, mis.dentro_dove,
		mis.lungo, mis.lungo_t, mis.corto, mis.corto_t, mis.gin_av, mis.gin_av_t]


func _controlla(id: String, r: Dictionary) -> void:
	for chi: String in ["p", "o"]:
		var mis: Dictionary = r[chi]
		check(float(mis.cav) <= SALTO_CAVIGLIA, "salto della caviglia: " + riga(id, chi, mis))
		check(float(mis.gin) <= SALTO_GINOCCHIO, "salto del ginocchio: " + riga(id, chi, mis))
		check(float(mis.dentro) <= float(DENTRO_ID.get(id, DENTRO_GAMBE)), "gambe una dentro l'altra: " + riga(id, chi, mis))
		check(float(mis.lungo) <= ALLUNGO_MAX, "gamba stirata: " + riga(id, chi, mis))
		check(float(mis.corto) >= ALLUNGO_MIN, "gamba schiacciata: " + riga(id, chi, mis))
		check(float(mis.gin_av) >= GINOCCHIO_DIETRO, "ginocchio al contrario: " + riga(id, chi, mis))


func test_in_tutti_i_giochetti_le_gambe_non_saltano_e_non_si_attraversano() -> bool:
	for id: String in CS.IDS:
		# Act
		var r := misura(id, true)
		# Assert
		check(r.esito == true, id + ": dribbling riuscito")
		_controlla(id, r)
	return done()


func test_nel_dribbling_fallito_le_gambe_non_saltano_e_non_si_attraversano() -> bool:
	var r := misura("finta", false)
	check(r.esito == false, "dribbling fallito")
	_controlla("fallito", r)
	return done()
