# Giochetto "Elastico" (skill/elastico.gd), solo grafica: misure sulla traccia di test_skill_finta.gd (piedi e pallone
# nel riferimento del portatore: x = verso il lato scelto, y/z = avanti; m del gioco).
# Qui c'è anche la misura in comune dei tre elastici (`onda`, usata da test_skill_elastico_inv.gd e
# test_skill_elastico3.gd): quanto è fluido il gesto (Luis 2026-11-27: "da rendere più fluidi": un gesto solo, morbido e
# continuo, senza scatti né pause tra i due tocchi), a passi del rallenty della regia come in partita.
extends "test_base.gd"

const TF := preload("test_skill_finta.gd")
const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")
const Regia := preload("res://scripts/partita/dribbling_regia.gd")

const V_FERMO := 0.6          # m/s di lato rispetto al corpo: sotto, il pallone è "fermo" ...
const PAUSA_MAX := 0.06       # ... e può restarci al massimo tanto (s di partita: l'attimo in cui cambia verso)
const SCATTO_MAX := 3.5       # m/s: da un fotogramma all'altro la velocità di lato del pallone non cambia di più
const PIEDE_MAX := 0.5        # m: caviglia del piede del gesto mai più lontana dal pallone (lo accompagna)
const FINESTRA := 6           # fotogrammi su cui si misura il verso del pallone (0,03 s di partita)
const V_VERSO := 1.0          # m/s: sopra, il pallone sta andando da quella parte


## motore e coreografia insieme come vista.gd, a passi da `dt` (predefinito: un fotogramma vero nel rallenty del
## giochetto). Ritorna {tg, t0, t1, righe: [{t, x, z}], pausa, scatto, scatto_t, piede, estremi: [x a ogni cambio di
## verso], fuori (x più verso la finta), dopo (x 0,16 s dopo lo scatto)}: x = pallone di lato rispetto al corpo, + =
## lato scelto; tra il primo tocco (t0) e l'ultimo (t1)
static func onda(id: String, dt: float = DT * Regia.TS_GIOCHETTO) -> Dictionary:
	var s := TD.setup(TD.first_ok_seed(), 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = id
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	var cp: Coreo = null
	var inv := Basis.IDENTITY
	var S := 1.0
	var out := {"tg": INF, "t0": 0.0, "t1": 0.0, "righe": [], "pausa": 0.0, "scatto": 0.0, "scatto_t": 0.0, "piede": 0.0,
		"estremi": [], "fuori": 0.0, "dopo": 0.0}
	var piede := ""
	for i in int(7.0 / dt):
		m.step(dt)
		for e: Dictionary in m.events:
			if e.type == "dribble" and e.ok:
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				S = float(e.side)
				inv = Basis(Vector3.UP, cp.yaw).inverse()
				CD.portatore(cp, String(e.skill), S, float(e.show))
				var el: Dictionary = cp.dati.get("el", {})
				if not el.is_empty():
					piede = String(el.piede)
					out.t0 = float((el.nodi as Array)[0][0])
					out.t1 = float((el.nodi as Array).back()[0])
			elif e.type == "dribble_go" and cp != null:
				out.tg = cp.t
				CD.portatore_go(cp)
		m.events.clear()
		if cp == null:
			continue
		cp.passo(dt, p, m.ball)
		if cp.finito or cp.t > float(out.tg) + 0.3:
			break
		var corpo := Vector3(p.x, 0.0, -p.y)
		var b := inv * (cp.pallone() - corpo)
		var riga := {"t": cp.t, "x": b.x * S, "z": b.z}
		(out.righe as Array).append(riga)
		if piede != "" and cp.t >= float(out.t0) + 0.02 and cp.t <= float(out.t1) - 0.01:
			var cav: Vector3 = cp.piedi()[piede].pos
			out.piede = maxf(out.piede, Vector2(cav.x - cp.pallone().x, cav.z - cp.pallone().z).length())
	m.dispose()
	_misura(out, dt)
	return out


static func _misura(out: Dictionary, dt: float) -> void:
	var righe: Array = out.righe
	var t0 := float(out.t0) + 0.04
	var t1 := float(out.t1) - 0.02
	var fermo_da := -1.0
	var v_prima := NAN
	var verso := 0.0
	var estremo := 0.0
	for i in range(1, righe.size()):
		var r: Dictionary = righe[i]
		var tt := float(r.t)
		if tt <= float(out.tg) + 0.1:
			out.fuori = minf(out.fuori, float(r.x))
		if tt <= float(out.tg) + 0.16:
			out.dopo = float(r.x)
		if tt < t0 or tt > t1:
			continue
		var v := (float(r.x) - float(righe[i - 1].x)) / dt
		# pausa: pallone fermo di lato
		if absf(v) < V_FERMO:
			if fermo_da < 0.0:
				fermo_da = tt
			out.pausa = maxf(out.pausa, tt - fermo_da + dt)
		else:
			fermo_da = -1.0
		# scatto: la velocità cambia di colpo
		if not is_nan(v_prima) and absf(v - v_prima) > float(out.scatto):
			out.scatto = absf(v - v_prima)
			out.scatto_t = tt
		v_prima = v
		# cambi di verso (sulla velocità media di qualche fotogramma)
		if i >= FINESTRA:
			var vm := (float(r.x) - float(righe[i - FINESTRA].x)) / (dt * FINESTRA)
			if absf(vm) > V_VERSO and signf(vm) != verso:
				if verso != 0.0:
					(out.estremi as Array).append(estremo)
				verso = signf(vm)
				estremo = float(r.x)
			if verso < 0.0:
				estremo = minf(estremo, float(r.x))
			elif verso > 0.0:
				estremo = maxf(estremo, float(r.x))


## i controlli di fluidità in comune (t = il test che li fa)
static func controlla_fluido(t: Object, id: String, r: Dictionary) -> void:
	t.note("%s: pausa %.3f s, scatto %.1f m/s (a %.2f s), piede a %.2f m, estremi %s, fuori %.2f, dopo %.2f" % [id, r.pausa, r.scatto,
		r.scatto_t, r.piede, str(r.estremi), r.fuori, r.dopo])
	t.check(float(r.pausa) <= PAUSA_MAX, "%s: nessuna pausa del pallone tra un tocco e l'altro (%.3f s)" % [id, r.pausa])
	t.check(float(r.scatto) <= SCATTO_MAX, "%s: pallone senza scatti (%.1f m/s in un fotogramma, a %.2f s)" % [id, r.scatto, r.scatto_t])
	t.check(float(r.piede) <= PIEDE_MAX, "%s: il piede accompagna il pallone (al massimo a %.2f m)" % [id, r.piede])


func test_elastico_esterno_fuori_e_interno_di_scatto_dal_lato_scelto() -> bool:
	# Arrange / Act
	var righe := TF.traccia("elastico")
	var tg := TF.t_go(righe)
	check(not righe.is_empty() and tg < INF, "il giochetto si fa e arriva lo scatto")
	if righe.is_empty():
		return done()
	check(TF.appoggi(righe) >= 2, "passi di corsa durante il giochetto (%d)" % TF.appoggi(righe))
	check(TF.appoggio_piu_lungo(righe) <= TF.APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % TF.appoggio_piu_lungo(righe))
	# l'esterno porta il pallone fuori dal lato della finta, allo scatto l'interno lo riporta di là in un attimo
	var fuori := 0.0
	for r: Dictionary in righe:
		if not r.go:
			fuori = minf(fuori, (r.palla as Vector2).x)
	check(fuori <= -0.5, "il pallone va fuori dal lato della finta (%.2f m)" % fuori)
	var rientro := (TF.riga_a(righe, tg + 0.16).palla as Vector2).x - fuori
	check(rientro >= 0.7, "l'interno lo riporta di scatto attraverso il corpo (%.2f m in 0,16 s)" % rientro)
	return done()


func test_elastico_un_gesto_solo_senza_pause_ne_scatti() -> bool:
	# Act
	var r := onda("elastico")
	# Assert
	check(float(r.tg) < INF, "arriva lo scatto")
	controlla_fluido(self, "elastico", r)
	eq((r.estremi as Array).size(), 1, "un solo cambio di verso: fuori con l'esterno, dentro con l'interno")
	check(float(r.fuori) <= -0.5 and float(r.dopo) >= 0.05, "fuori dalla finta (%.2f m) e poi dal lato scelto (%.2f m)" % [r.fuori, r.dopo])
	return done()
