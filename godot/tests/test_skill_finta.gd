# Giochetto "Finta di corpo" (skill/finta.gd), solo grafica. Qui c'è anche la traccia in comune dei test dei giochetti
# `finta`, `doppiopasso`, `suola`, `stopgo`, `fintatiro`, `tacco`, `elastico`, `elastico_inv` (test_skill_<id>.gd):
# motore e coreografia insieme come in vista.gd, una riga per passo con piedi e pallone nel riferimento del portatore
# all'inizio (lato = verso il lato scelto, av = avanti; m del gioco).
extends "test_base.gd"

const Coreo := preload("res://scripts/partita/mosse/coreo.gd")
const CD := preload("res://scripts/partita/mosse/coreo_dribbling.gd")
const TD := preload("test_dribbling.gd")
const TC := preload("test_coreo.gd")
const APPOGGIO_MAX := 0.3     # s di partita: un piede fermo a terra più a lungo mentre il corpo corre = "piantato"


## righe: {t, go (bool: dopo lo scatto), S, corpo (Vector2 lato/av dall'inizio), vel (m/s), palla (Vector2 rispetto al
## corpo), l / r: {p (Vector3 lato, alto, av rispetto al corpo), terra}}; i piedi con nome "S" (lato scelto) e "F"
static func traccia(id: String, sd: int = -1) -> Array:
	var s := TD.setup(TD.first_ok_seed() if sd < 0 else sd, 5.0)
	var m: SimMatchScript = s[0]
	m.rifiniture = true
	m.skillForza = id
	var p: R.Player = s[1]
	var o: R.Player = s[2]
	p.st.dri = 99
	o.st.dif = 20
	m.userDribble(0)
	var cp: Coreo = null
	var righe: Array = []
	var inv := Basis.IDENTITY
	var c0 := Vector3.ZERO
	var S := 1.0
	var go := false
	for i in 420:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "dribble":
				if not e.ok:
					m.dispose()
					return []
				var bv := Vector3(m.ball.x, 0.0, -m.ball.y)
				cp = Coreo.new(p, 1.0, TC.SCALA, TC.caviglie(p), bv, Vector3(m.ball.vx, 0.0, -m.ball.vy))
				cp.ostacolo = func() -> Vector3: return Vector3(o.x, 0.0, -o.y)
				S = float(e.side)
				inv = Basis(Vector3.UP, cp.yaw).inverse()
				c0 = Vector3(p.x, 0.0, -p.y)
				CD.portatore(cp, String(e.skill), S, float(e.show))
			elif e.type == "dribble_go" and cp != null:
				go = true
				CD.portatore_go(cp)
		m.events.clear()
		if cp == null:
			continue
		cp.passo(DT, p, m.ball)
		if cp.finito:
			break
		var corpo := Vector3(p.x, 0.0, -p.y)
		var riga := {"t": cp.t, "go": go, "S": S, "vel": C.hyp(p.vx, p.vy), "yaw": wrapf(cp.yaw - cp.yaw0, -PI, PI) * S}
		var d := inv * (corpo - c0)
		riga.corpo = Vector2(d.x * S, d.z)
		var b := inv * (cp.pallone() - corpo)
		riga.palla = Vector2(b.x * S, b.z)
		var q := inv * (Vector3(o.x, 0.0, -o.y) - corpo)
		riga.dif = Vector2(q.x * S, q.z)
		var pd := cp.piedi()
		for lato: String in ["l", "r"]:
			var f := inv * ((pd[lato].pos as Vector3) - corpo)
			var nome := "S" if (lato == "l") == (S > 0.0) else "F"
			riga[nome] = {"p": Vector3(f.x * S, (pd[lato].pos as Vector3).y, f.z), "terra": bool(pd[lato].terra),
				"mondo": pd[lato].pos}
		righe.append(riga)
	m.dispose()
	return righe


## appoggio più lungo (s) di un piede fermo a terra tra t0 e lo scatto (parte A)
static func appoggio_piu_lungo(righe: Array) -> float:
	var peggio := 0.0
	for nome: String in ["S", "F"]:
		var da := -1.0
		for r: Dictionary in righe:
			if r.go:
				break
			if r[nome].terra:
				if da < 0.0:
					da = float(r.t)
				peggio = maxf(peggio, float(r.t) - da)
			else:
				da = -1.0
	return peggio


## quante volte un piede atterra nella parte A (passi)
static func appoggi(righe: Array) -> int:
	var n := 0
	for nome: String in ["S", "F"]:
		var prima := true
		for r: Dictionary in righe:
			if r.go:
				break
			if r[nome].terra and not prima:
				n += 1
			prima = r[nome].terra
	return n


## momento dello scatto (s) e riga a un certo tempo
static func t_go(righe: Array) -> float:
	for r: Dictionary in righe:
		if r.go:
			return float(r.t)
	return INF


static func riga_a(righe: Array, tt: float) -> Dictionary:
	for r: Dictionary in righe:
		if float(r.t) >= tt:
			return r
	return righe.back()


func test_finta_in_corsa_passo_largo_dalla_finta_e_pallone_dal_lato_scelto() -> bool:
	# Arrange / Act
	var righe := traccia("finta")
	var tg := t_go(righe)
	# Assert: non si pianta
	check(not righe.is_empty() and tg < INF, "la finta si fa e arriva lo scatto")
	check(appoggi(righe) >= 2, "almeno due passi di corsa durante la finta (%d)" % appoggi(righe))
	check(appoggio_piu_lungo(righe) <= APPOGGIO_MAX, "nessun piede piantato (%.2f s)" % appoggio_piu_lungo(righe))
	# il passo della finta è largo dal lato della finta, e allo scatto il pallone è dal lato scelto
	var largo := 0.0
	for r: Dictionary in righe:
		if not r.go and r.F.terra:
			largo = minf(largo, (r.F.p as Vector3).x)
	check(largo < -0.3, "passo largo dal lato della finta (%.2f m)" % largo)
	var dopo := riga_a(righe, tg + 0.25)
	check((dopo.corpo as Vector2).x > (riga_a(righe, tg).corpo as Vector2).x, "dopo lo scatto va dal lato scelto")
	return done()
