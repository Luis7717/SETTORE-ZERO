# Le 15 esultanze del campione come movimenti calcolati (stesso sistema dei giochetti: mossa.gd + IK di figura.gd).
# Ogni esultanza è una Coreografia:
#   - una Mossa (bacino, busto, testa, braccia e gambe nel riferimento del giocatore: x = sinistra, y = su,
#     z = avanti, metri del modello), senza pallone (lo sguardo va su un punto lontano davanti);
#   - il "corpo": spostamento e giro di tutto il giocatore (corsa in cerchio, scivolata, salti, capriola, giravolta),
#     messo sul nodo Corpo della figura; perno = altezza attorno a cui gira quando si inclina o si capovolge;
#   - la "corsa": nei tratti di corsa le gambe (e il busto) le fa il clip vero di corsa del modello, alla velocità
#     giusta per lo spostamento, e la Mossa fa solo le braccia (o niente, se le braccia corrono anche loro).
# posa(t) → {fr (posa della Mossa, con i poli dei gomiti), corsa (0..1), vel (m/s del clip), corpo (Transform3D),
# braccia e busto (pesi di braccia e busto della Mossa rispetto al clip)}. Chi la mette sullo scheletro: figura.gd (esultanza).
# Solo grafica: il motore non sa niente delle esultanze.
extends RefCounted

const Mossa := preload("mossa.gd")
const Corpo := preload("corpo.gd")
const Esultanze := preload("../esultanze.gd")

const SCALA_GIOCO := 1.25          # i giocatori sono ingranditi così (Coord.SCALE): velocità del clip in m/s veri
const STANCE := {"l": Vector2(0.14, 0.0), "r": Vector2(-0.14, -0.02)}
const LARGHI := {"l": Vector2(0.21, 0.0), "r": Vector2(-0.21, -0.01)}
const PELVIS := Vector3(0, 0.935, -0.045)
const ARMS_REST := Vector3(0.2, -0.5, 0.05)
const POLO := Vector3(0.35, -0.25, -1)     # gomito indietro e in giù (come mossa.gd)
const POLO_FUORI := Vector3(1, 0.1, 0.2)   # gomito in fuori (mano all'orecchio, saluto)
const POLO_GIU := Vector3(0.5, -1, 0.1)    # gomito in giù e un po' in fuori (mani davanti al petto)
const SGUARDO := Vector3(0, 1.62, 40)      # punto lontano davanti: lo sguardo resta dritto
const V_SU := Vector3(0.3, 0.47, 0.05)     # braccia a V verso il cielo
const LARGHE := Vector3(0.55, -0.02, 0.02) # braccia larghe orizzontali
const CAMPIONE_DT := 0.05                  # passo delle chiavi campionate (cerchi, voli, giri)
const Y := Vector3(0, 1, 0)

static var _cache := {}


class Coreografia:
	extends RefCounted
	var id := ""
	var T := 0.0
	var mv: Mossa
	var perno := 0.9                       # altezza del perno per inclinazioni e capovolte (m del modello)
	var braccia_in_corsa := false          # true = anche correndo braccia e busto li fa la Mossa (aeroplano)
	var corsa_k: Array = []                # [Vector2(t, peso)] a tratti lineari
	var corpo_k: Array = []                # [{t, p: Vector3, a: Vector3(giro, avanti, lato), v?}]
	var poli_k := {"l": [], "r": []}       # [{t, p: polo del gomito nel petto (x in fuori)}]
	var _cp: Mossa.Curva = null
	var _ca: Mossa.Curva = null
	var _poli := {}

	func _init(id_: String, tt: float) -> void:
		id = id_
		T = tt
		mv = Mossa.new(0.11)
		mv.ball_rest(0.0, tt + 1.0, SGUARDO)
		mv.leg("l", {"t": 0.0, "plant": STANCE.l}).leg("r", {"t": 0.0, "plant": STANCE.r})
		mv.pelvis(0.0, PELVIS).bend(0.0, Vector3(0.04, 0, 0))
		mv.arm("l", 0.0, ARMS_REST).arm("r", 0.0, ARMS_REST)
		corpo(0.0, Vector3.ZERO)

	## spostamento e giro di tutto il corpo (a = giro, avanti, lato in rad)
	func corpo(t: float, p: Vector3, a: Vector3 = Vector3.ZERO, v: Variant = null) -> Coreografia:
		for i in corpo_k.size():
			if absf(float(corpo_k[i].t) - t) < 1e-9:
				corpo_k.remove_at(i)
				break
		corpo_k.append({"t": t, "p": p, "a": a, "v": v})
		return self

	func corsa(t: float, peso: float) -> Coreografia:
		corsa_k.append(Vector2(t, peso))
		return self

	func polo(side: String, t: float, p: Vector3) -> Coreografia:
		poli_k[side].append({"t": t, "p": p})
		return self

	func poli(t: float, p: Vector3) -> Coreografia:
		return polo("l", t, p).polo("r", t, p)

	## braccia uguali dai due lati
	func braccia(t: float, off: Vector3) -> Coreografia:
		mv.arm("l", t, off).arm("r", t, off)
		return self

	func pronta() -> Coreografia:
		mv.done(T)
		Mossa._by_t(corpo_k)
		var pk: Array = []
		var ak: Array = []
		for k: Dictionary in corpo_k:
			pk.append({"t": k.t, "p": k.p, "v": k.v})
			ak.append({"t": k.t, "p": k.a})
		_cp = Mossa.Curva.new(pk)
		_ca = Mossa.Curva.new(ak)
		corsa_k.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for s: String in ["l", "r"]:
			var kk: Array = Mossa._by_t(poli_k[s])
			_poli[s] = Mossa.Curva.new(kk) if not kk.is_empty() else null
		return self

	func corsa_at(t: float) -> float:
		if corsa_k.is_empty():
			return 0.0
		if t <= corsa_k[0].x:
			return corsa_k[0].y
		for i in range(1, corsa_k.size()):
			var b: Vector2 = corsa_k[i]
			if t <= b.x:
				var a: Vector2 = corsa_k[i - 1]
				return lerpf(a.y, b.y, Corpo.smooth((t - a.x) / maxf(1e-6, b.x - a.x)))
		return corsa_k[-1].y

	## Transform3D del corpo intero al tempo t (rispetto ai piedi della figura)
	func corpo_at(t: float) -> Transform3D:
		var p: Vector3 = _cp.at(t)
		var a: Vector3 = _ca.at(t)
		var b := Basis(Vector3.UP, a.x) * Basis(Vector3.RIGHT, a.y) * Basis(Vector3.BACK, -a.z)
		var h := Vector3(0, perno, 0)
		return Transform3D(b, p + h - b * h)

	func posa(t: float) -> Dictionary:
		t = clampf(t, 0.0, T)
		var fr := mv.at(t)
		var q3: Quaternion = fr.rot.spine_03
		for s: String in ["l", "r"]:
			var pl: Vector3 = POLO
			if _poli[s] != null:
				pl = (_poli[s] as Mossa.Curva).at(t)
			fr.arms[s].pole = q3 * Vector3(pl.x * Corpo.SIDE[s], pl.y, pl.z)
		var c := corsa_at(t)
		var dt := 0.03
		var v := (_cp.at(minf(T, t + dt)) - _cp.at(maxf(0.0, t - dt))).length() / (2.0 * dt) * SCALA_GIOCO
		return {"fr": fr, "corsa": c, "vel": v, "corpo": corpo_at(t), "braccia": 1.0 if braccia_in_corsa else 1.0 - c,
			"busto": 1.0 if braccia_in_corsa else 1.0 - c}


## coreografia dell'esultanza `id` (in cache: è sempre la stessa); id sconosciuto = quella predefinita
static func coreografia(id: Variant) -> Coreografia:
	var k := Esultanze.valida(id)
	if not _cache.has(k):
		_cache[k] = _crea(k).pronta()
	return _cache[k]


static func durata(id: Variant) -> float:
	return coreografia(id).T


static func posa(id: Variant, t: float) -> Dictionary:
	return coreografia(id).posa(t)


static func _crea(id: String) -> Coreografia:
	match id:
		"aeroplano": return _aeroplano()
		"ginocchio": return _ginocchio()
		"capriola": return _capriola()
		"pugno": return _pugno()
		"indice": return _indice()
		"saluto": return _saluto()
		"cuore": return _cuore()
		"ballo": return _ballo()
		"orecchie": return _orecchie()
		"silenzio": return _silenzio()
		"salto": return _salto()
		"inchino": return _inchino()
		"conserte": return _conserte()
		"giravolta": return _giravolta()
		"bandierina": return _bandierina()
	return _aeroplano()


# ---------------------------------------------------------------- aiuti
static func _pianta(c: Coreografia, t: float, piedi: Dictionary = STANCE, yaw: float = 0.0) -> void:
	c.mv.leg("l", {"t": t, "plant": piedi.l, "yaw": yaw}).leg("r", {"t": t, "plant": piedi.r, "yaw": yaw})


## passo: il piede s si alza a metà strada e si appoggia in `a` al tempo t1
static func _passo(c: Coreografia, s: String, t0: float, t1: float, da: Vector2, a: Vector2, alto: float = 0.09) -> void:
	c.mv.leg(s, {"t": t0, "plant": da})
	var m := da.lerp(a, 0.5)
	c.mv.leg(s, {"t": (t0 + t1) / 2.0, "ankle": Vector3(m.x, Corpo.ANKLE_H + alto, m.y), "fq": Mossa.foot_q(0, 0.2)})
	c.mv.leg(s, {"t": t1, "plant": a})


## salto sul posto o in avanti: accucciata, stacco, volo (parabola del corpo) e atterraggio con le ginocchia piegate
static func _salto_corpo(c: Coreografia, t_st: float, t_at: float, alto: float, avanti0: float = 0.0, avanti1: float = 0.0,
		giro0: Vector3 = Vector3.ZERO, giro1: Vector3 = Vector3.ZERO) -> void:
	var n := maxi(2, int(ceil((t_at - t_st) / CAMPIONE_DT)))
	for i in n + 1:
		var s := float(i) / n
		var t := lerpf(t_st, t_at, s)
		var e := Corpo.smooth(s)
		c.corpo(t, Vector3(0, 4.0 * alto * s * (1.0 - s), lerpf(avanti0, avanti1, s)), giro0.lerp(giro1, e))


# ---------------------------------------------------------------- 1. aeroplano: corsa in cerchio a braccia larghe
static func _aeroplano() -> Coreografia:
	var c := Coreografia.new("aeroplano", 3.0)
	c.braccia_in_corsa = true
	c.perno = 0.0
	var r := 1.0                     # raggio del cerchio (verso sinistra)
	var u := 2.4                     # m/s del modello
	var t_lenta := 2.15              # da qui rallenta e si ferma in 0,5 s
	var frena := 0.5
	c.corsa(0.0, 1.0).corsa(t_lenta + 0.25, 1.0).corsa(t_lenta + frena, 0.0)
	var t := 0.0
	while t <= t_lenta + frena + 1e-6:
		var d := u * t if t <= t_lenta else u * t_lenta + u * ((t - t_lenta) - (t - t_lenta) * (t - t_lenta) / (2.0 * frena))
		var th := d / r
		var lean := 0.22 * Corpo.smooth(t / 0.4) * (1.0 - Corpo.smooth((t - t_lenta) / frena))
		c.corpo(t, Vector3(r - r * cos(th), 0, r * sin(th)), Vector3(th, 0.05, lean))
		t += CAMPIONE_DT * 2.0
	var th_fine := (u * t_lenta + u * frena / 2.0) / r
	c.corpo(c.T, Vector3(r - r * cos(th_fine), 0, r * sin(th_fine)), Vector3(th_fine, 0, 0))
	_pianta(c, t_lenta + frena)
	# braccia larghe e simmetriche: l'inclinazione della curva (lean) abbassa già quella dentro la curva
	c.braccia(0.2, Vector3(0.54, -0.04, 0.0)).braccia(t_lenta, Vector3(0.54, -0.04, 0.0))
	c.mv.bend(0.2, Vector3(0.16, 0, 0)).bend(t_lenta, Vector3(0.14, 0, 0)).bend(c.T, Vector3(0.0, 0, 0))
	c.braccia(c.T, Vector3(0.54, 0.0, 0.03))
	c.poli(0.0, Vector3(0.1, -0.3, -1))
	c.mv.head(0.3, Vector2(-0.15, 0)).head(c.T, Vector2(-0.2, 0))
	c.mv.pelvis(t_lenta + frena, PELVIS)
	return c


# ---------------------------------------------------------------- 2. scivolata in ginocchio, busto indietro e braccia al cielo
static func _ginocchio() -> Coreografia:
	var c := Coreografia.new("ginocchio", 3.0)
	var u := 2.8
	var t_giu := 0.5                 # comincia a scendere
	var t_terra := 0.78              # ginocchia a terra
	var t_ferma := 1.5
	c.corsa(0.0, 1.0).corsa(t_giu, 1.0).corsa(t_giu + 0.2, 0.0)
	var z1 := u * t_terra
	c.corpo(0.0, Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, u))
	c.corpo(t_terra, Vector3(0, 0, z1), Vector3.ZERO, Vector3(0, 0, u * 0.9))
	c.corpo(t_ferma, Vector3(0, 0, z1 + u * 0.9 * (t_ferma - t_terra) / 2.0), Vector3.ZERO, Vector3.ZERO)
	c.corpo(c.T, Vector3(0, 0, z1 + u * 0.9 * (t_ferma - t_terra) / 2.0))
	# gambe: dalla corsa alle ginocchia (stinchi e collo del piede a terra, punte indietro)
	_pianta(c, t_giu)
	var fq := Mossa.foot_q(0, 2.55)
	var pg := Vector3(0, -0.3, 1)
	for s: String in ["l", "r"]:
		var x: float = Corpo.SIDE[s] * 0.13
		c.mv.leg(s, {"t": t_giu + 0.12, "ankle": Vector3(x, 0.32, -0.28), "fq": Mossa.foot_q(0, 1.5), "pole": pg})
		c.mv.leg(s, {"t": t_terra, "ankle": Vector3(x, 0.1, -0.4), "fq": fq, "pole": pg})
		c.mv.leg(s, {"t": c.T, "ankle": Vector3(x, 0.1, -0.4), "fq": fq, "pole": pg})
	c.mv.pelvis(t_giu, PELVIS).pelvis(t_terra, Vector3(0, 0.57, -0.06), 0, -0.05)
	c.mv.pelvis(t_ferma, Vector3(0, 0.56, -0.07), 0, -0.12).pelvis(c.T, Vector3(0, 0.56, -0.07), 0, -0.1)
	c.mv.bend(t_giu, Vector3(0.1, 0, 0)).bend(t_terra + 0.1, Vector3(-0.2, 0, 0)).bend(t_ferma, Vector3(-0.42, 0, 0))
	c.mv.bend(2.2, Vector3(-0.36, 0.06, 0.05)).bend(c.T, Vector3(-0.4, 0, 0))
	c.mv.head(t_terra, Vector2(0, 0)).head(t_ferma, Vector2(-0.35, 0)).head(c.T, Vector2(-0.3, 0))
	# braccia: aperte all'arrivo, poi al cielo, con due pugni che spingono
	c.braccia(t_giu, ARMS_REST)
	c.braccia(t_terra, Vector3(0.48, -0.15, 0.15)).braccia(1.15, V_SU)
	c.braccia(1.7, Vector3(0.3, 0.38, 0.1)).braccia(1.95, V_SU).braccia(2.35, Vector3(0.3, 0.38, 0.1)).braccia(2.6, V_SU)
	return c


# ---------------------------------------------------------------- 3. capriola: rincorsa, salto mortale in avanti, braccia al cielo
static func _capriola() -> Coreografia:
	var c := Coreografia.new("capriola", 3.0)
	c.perno = 0.85
	var u := 2.6
	var t_acc := 0.5                 # comincia l'accucciata
	var t_st := 0.72                 # stacco
	var t_at := 1.42                 # atterraggio
	c.corsa(0.0, 1.0).corsa(t_acc - 0.1, 1.0).corsa(t_acc + 0.12, 0.0)
	c.corpo(0.0, Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, u))
	c.corpo(t_acc, Vector3(0, 0, u * t_acc), Vector3.ZERO, Vector3(0, 0, u))
	var z_st := u * t_acc + 0.3
	_salto_corpo(c, t_st, t_at, 0.75, z_st, z_st + 0.85, Vector3.ZERO, Vector3(0, TAU, 0))
	c.corpo(t_at + 0.15, Vector3(0, 0, z_st + 1.0), Vector3(0, TAU, 0))
	c.corpo(c.T, Vector3(0, 0, z_st + 1.0), Vector3(0, TAU, 0))
	# gambe: corsa, spinta, raccolte al petto in volo, giù per atterrare
	_pianta(c, t_acc)
	_pianta(c, t_st + 0.03)
	var pg := Vector3(0, 0.6, 1)
	for s: String in ["l", "r"]:
		var x: float = Corpo.SIDE[s] * 0.12
		c.mv.leg(s, {"t": t_st + 0.16, "ankle": Vector3(x, 0.6, -0.06), "fq": Mossa.foot_q(0, 0.7), "pole": pg})
		c.mv.leg(s, {"t": t_at - 0.18, "ankle": Vector3(x, 0.6, -0.04), "fq": Mossa.foot_q(0, 0.7), "pole": pg})
		c.mv.leg(s, {"t": t_at - 0.05, "ankle": Vector3(x * 1.1, 0.14, 0.04), "fq": Mossa.foot_q(0, 0.15)})
	_pianta(c, t_at, LARGHI)
	c.mv.pelvis(t_acc, PELVIS).pelvis(t_st - 0.02, Vector3(0, 0.76, -0.1), 0, 0.15).pelvis(t_st + 0.06, Vector3(0, 0.95, -0.04))
	c.mv.pelvis(t_at - 0.18, Vector3(0, 0.95, -0.04)).pelvis(t_at + 0.12, Vector3(0, 0.76, -0.1), 0, 0.12)
	c.mv.pelvis(t_at + 0.45, Vector3(0, 0.93, -0.05)).pelvis(c.T, Vector3(0, 0.93, -0.05))
	c.mv.bend(t_acc, Vector3(0.1, 0, 0)).bend(t_st - 0.02, Vector3(0.45, 0, 0)).bend(t_st + 0.06, Vector3(0.0, 0, 0))
	c.mv.bend(t_st + 0.2, Vector3(0.7, 0, 0)).bend(t_at - 0.18, Vector3(0.7, 0, 0)).bend(t_at + 0.12, Vector3(0.35, 0, 0))
	c.mv.bend(t_at + 0.45, Vector3(-0.08, 0, 0)).bend(c.T, Vector3(-0.1, 0, 0))
	c.mv.head(t_st + 0.1, Vector2(0.35, 0)).head(t_at - 0.15, Vector2(0.35, 0)).head(t_at + 0.3, Vector2(0, 0)).head(c.T, Vector2(-0.3, 0))
	c.braccia(t_acc, ARMS_REST).braccia(t_st - 0.02, Vector3(0.22, -0.42, -0.32)).braccia(t_st + 0.08, Vector3(0.22, 0.45, 0.18))
	c.braccia(t_st + 0.22, Vector3(0.02, -0.38, 0.38)).braccia(t_at - 0.18, Vector3(0.02, -0.38, 0.38))
	c.braccia(t_at + 0.1, Vector3(0.35, -0.2, 0.3)).braccia(t_at + 0.5, V_SU).braccia(c.T, V_SU)
	c.poli(t_st + 0.1, POLO).poli(t_st + 0.22, Vector3(1, -0.4, 0)).poli(t_at - 0.18, Vector3(1, -0.4, 0)).poli(t_at + 0.2, POLO)
	return c


# ---------------------------------------------------------------- 4. pugno al cielo
static func _pugno() -> Coreografia:
	var c := Coreografia.new("pugno", 2.8)
	_passo(c, "r", 0.05, 0.3, STANCE.r, Vector2(-0.22, 0.04))
	c.mv.leg("l", {"t": 0.3, "plant": STANCE.l})
	# piccolo saltello sul pugno
	c.corpo(0.36, Vector3.ZERO).corpo(0.5, Vector3(0, 0.07, 0)).corpo(0.66, Vector3.ZERO)
	c.mv.pelvis(0.32, Vector3(0, 0.88, -0.04)).pelvis(0.52, Vector3(0, 0.94, -0.04)).pelvis(0.72, Vector3(0, 0.9, -0.04))
	c.mv.pelvis(c.T, Vector3(0, 0.915, -0.04))
	c.mv.bend(0.32, Vector3(0.2, 0, 0)).bend(0.55, Vector3(-0.12, -0.05, 0.1)).bend(c.T, Vector3(-0.1, -0.04, 0.08))
	c.mv.head(0.55, Vector2(-0.35, 0)).head(c.T, Vector2(-0.3, 0))
	c.mv.arm("r", 0.3, Vector3(0.14, -0.3, 0.18)).arm("r", 0.5, Vector3(0.07, 0.55, 0.08))
	c.mv.arm("r", 1.15, Vector3(0.07, 0.55, 0.08)).arm("r", 1.35, Vector3(0.14, 0.22, 0.16))
	c.mv.arm("r", 1.55, Vector3(0.07, 0.55, 0.08)).arm("r", 2.1, Vector3(0.07, 0.55, 0.08))
	c.mv.arm("r", 2.3, Vector3(0.14, 0.22, 0.16)).arm("r", 2.5, Vector3(0.07, 0.55, 0.08))
	c.mv.arm("l", 0.3, Vector3(0.22, -0.33, 0.2)).arm("l", c.T, Vector3(0.22, -0.3, 0.22))
	c.polo("l", 0.0, POLO)
	return c


# ---------------------------------------------------------------- 5. indici al cielo, sguardo in alto
static func _indice() -> Coreografia:
	var c := Coreografia.new("indice", 2.8)
	_passo(c, "l", 0.05, 0.3, STANCE.l, Vector2(0.19, 0.02))
	c.mv.pelvis(0.4, Vector3(0, 0.925, -0.03)).pelvis(c.T, Vector3(0, 0.93, -0.03))
	c.mv.bend(0.5, Vector3(-0.14, 0, 0)).bend(1.6, Vector3(-0.18, 0, 0)).bend(c.T, Vector3(-0.14, 0, 0))
	c.mv.head(0.6, Vector2(-0.6, 0)).head(1.6, Vector2(-0.65, 0)).head(c.T, Vector2(-0.6, 0))
	var su := Vector3(0.17, 0.52, 0.12)
	c.braccia(0.25, Vector3(0.22, -0.2, 0.2)).braccia(0.55, su)
	c.braccia(1.4, su).braccia(1.65, Vector3(0.2, 0.42, 0.16)).braccia(1.9, su).braccia(c.T, su)
	return c


# ---------------------------------------------------------------- 6. saluto militare: piedi uniti, mano alla fronte
static func _saluto() -> Coreografia:
	var c := Coreografia.new("saluto", 2.8)
	var uniti := {"l": Vector2(0.085, 0.0), "r": Vector2(-0.085, 0.0)}
	_passo(c, "l", 0.05, 0.3, STANCE.l, uniti.l, 0.06)
	_passo(c, "r", 0.22, 0.45, STANCE.r, uniti.r, 0.12)
	c.mv.pelvis(0.45, Vector3(0, 0.95, -0.04)).pelvis(c.T, Vector3(0, 0.95, -0.04))
	c.mv.bend(0.45, Vector3(-0.06, 0, 0)).bend(c.T, Vector3(-0.06, 0, 0))
	c.mv.head(0.5, Vector2(-0.05, 0)).head(c.T, Vector2(-0.05, 0))
	c.mv.arm("r", 0.35, Vector3(0.1, -0.1, 0.25)).arm("r", 0.6, Vector3(0.06, 0.19, 0.15)).arm("r", c.T, Vector3(0.06, 0.19, 0.15))
	c.polo("r", 0.3, POLO).polo("r", 0.6, Vector3(1, 0.15, 0.05))
	c.mv.arm("l", 0.45, Vector3(0.1, -0.56, 0.0)).arm("l", c.T, Vector3(0.1, -0.56, 0.0))
	return c


# ---------------------------------------------------------------- 7. cuore con le mani verso il pubblico
static func _cuore() -> Coreografia:
	var c := Coreografia.new("cuore", 2.8)
	_passo(c, "r", 0.05, 0.3, STANCE.r, Vector2(-0.17, 0.08))
	c.mv.pelvis(0.4, Vector3(0, 0.93, -0.04)).pelvis(c.T, Vector3(0, 0.93, -0.04))
	c.mv.bend(0.5, Vector3(0.05, 0, 0)).bend(1.3, Vector3(-0.06, 0, 0)).bend(c.T, Vector3(-0.06, 0, 0))
	c.mv.head(0.5, Vector2(0.12, 0)).head(1.3, Vector2(-0.05, 0)).head(c.T, Vector2(-0.05, 0))
	c.braccia(0.25, Vector3(0.18, -0.3, 0.25)).braccia(0.6, Vector3(0.03, -0.07, 0.35))
	c.braccia(1.1, Vector3(0.03, -0.07, 0.35)).braccia(1.45, Vector3(0.02, 0.08, 0.38)).braccia(c.T, Vector3(0.02, 0.08, 0.38))
	c.poli(0.0, POLO).poli(0.5, POLO_GIU).poli(c.T, Vector3(1, -0.6, -0.1))
	return c


# ---------------------------------------------------------------- 8. balletto: anche che ondeggiano, talloni a tempo, braccia che pompano
static func _ballo() -> Coreografia:
	var c := Coreografia.new("ballo", 3.0)
	var per := 0.6                   # un ondeggiamento a destra e a sinistra
	_passo(c, "l", 0.05, 0.25, STANCE.l, LARGHI.l)
	_passo(c, "r", 0.15, 0.35, STANCE.r, LARGHI.r)
	var t := 0.35
	while t <= c.T - 0.2:
		var f := (t - 0.35) / per * TAU
		var sw := sin(f)
		c.mv.pelvis(t, Vector3(0.06 * sw, 0.895 + 0.025 * cos(2.0 * f), -0.04), 0.18 * sw, 0.03, 0.1 * sw)
		c.mv.bend(t, Vector3(0.1, -0.12 * sw, -0.12 * sw))
		c.mv.head(t, Vector2(0.05 * cos(2.0 * f), 0.15 * sw))
		# il tallone del piede scarico si alza
		for s: String in ["l", "r"]:
			var x: float = Corpo.SIDE[s]
			var su := maxf(0.0, -sw * x)
			var pl: Vector2 = LARGHI[s]
			c.mv.leg(s, {"t": t, "ankle": Vector3(pl.x, Corpo.ANKLE_H + 0.06 * su, pl.y + 0.02 * su), "fq": Mossa.foot_q(0.1 * x, 0.45 * su)})
		c.mv.arm("l", t, Vector3(0.22, -0.18 + 0.13 * sw, 0.28 - 0.06 * sw))
		c.mv.arm("r", t, Vector3(0.22, -0.18 - 0.13 * sw, 0.28 + 0.06 * sw))
		t += per / 4.0
	_pianta(c, c.T, LARGHI)
	c.mv.pelvis(c.T, Vector3(0, 0.91, -0.04)).bend(c.T, Vector3(0.05, 0, 0)).head(c.T, Vector2.ZERO)
	c.braccia(c.T, V_SU)
	c.poli(0.0, Vector3(0.6, -0.8, -0.2))
	return c


# ---------------------------------------------------------------- 9. mani alle orecchie ("non vi sento"), busto da una parte e dall'altra
static func _orecchie() -> Coreografia:
	var c := Coreografia.new("orecchie", 2.8)
	_passo(c, "l", 0.05, 0.28, STANCE.l, LARGHI.l)
	_passo(c, "r", 0.15, 0.38, STANCE.r, LARGHI.r)
	c.braccia(0.2, Vector3(0.25, -0.15, 0.2)).braccia(0.5, Vector3(-0.02, 0.22, 0.09)).braccia(c.T, Vector3(-0.02, 0.22, 0.09))
	c.poli(0.0, POLO).poli(0.45, Vector3(1, -0.7, 0.2))
	c.mv.pelvis(0.4, Vector3(0, 0.91, -0.04))
	var lati := [[0.8, 1.0], [1.35, -1.0], [1.9, 1.0], [2.45, -1.0]]
	for k: Array in lati:
		var s: float = k[1]
		c.mv.bend(k[0], Vector3(0.06, 0.42 * s, 0.3 * s)).pelvis(k[0], Vector3(-0.05 * s, 0.9, -0.04), 0.12 * s, 0, -0.08 * s)
		c.mv.head(k[0], Vector2(-0.1, 0.3 * s))
	c.mv.bend(c.T, Vector3(0.03, 0, 0)).pelvis(c.T, Vector3(0, 0.92, -0.04)).head(c.T, Vector2(-0.1, 0))
	return c


# ---------------------------------------------------------------- 10. dito sulla bocca: passo avanti, silenzio verso il pubblico
static func _silenzio() -> Coreografia:
	var c := Coreografia.new("silenzio", 2.8)
	_passo(c, "r", 0.05, 0.35, STANCE.r, Vector2(-0.16, 0.24))
	c.mv.leg("l", {"t": 0.35, "plant": STANCE.l, "yaw": 0.15})
	c.mv.pelvis(0.4, Vector3(0, 0.9, 0.06), -0.1).pelvis(c.T, Vector3(0, 0.9, 0.07), -0.1)
	c.mv.bend(0.5, Vector3(0.22, 0, 0.1)).bend(1.6, Vector3(0.26, 0, 0.12)).bend(c.T, Vector3(0.22, 0, 0.1))
	c.mv.head(0.55, Vector2(-0.12, 0)).head(c.T, Vector2(-0.12, 0))
	c.mv.arm("r", 0.3, Vector3(0.12, -0.25, 0.25)).arm("r", 0.6, Vector3(-0.12, 0.06, 0.26)).arm("r", c.T, Vector3(-0.12, 0.06, 0.26))
	c.polo("r", 0.0, POLO).polo("r", 0.55, POLO_GIU)
	c.mv.arm("l", 0.6, Vector3(0.35, -0.38, 0.1)).arm("l", c.T, Vector3(0.38, -0.36, 0.08))
	return c


# ---------------------------------------------------------------- 11. salto col pugno (due volte)
static func _salto() -> Coreografia:
	var c := Coreografia.new("salto", 3.0)
	var salti := [[0.42, 1.0, 0.5], [1.75, 2.28, 0.4]]
	c.braccia(0.0, ARMS_REST)
	for sa: Array in salti:
		var t_st: float = sa[0]
		var t_at: float = sa[1]
		_salto_corpo(c, t_st, t_at, sa[2])
		c.corpo(t_at + 0.01, Vector3.ZERO)
		_pianta(c, t_st - 0.3)
		_pianta(c, t_st + 0.02)
		for s: String in ["l", "r"]:
			var x: float = Corpo.SIDE[s] * 0.12
			c.mv.leg(s, {"t": (t_st + t_at) / 2.0, "ankle": Vector3(x, 0.36, -0.2), "fq": Mossa.foot_q(0, 0.9)})
			c.mv.leg(s, {"t": t_at - 0.04, "ankle": Vector3(x * 1.15, 0.12, 0.0), "fq": Mossa.foot_q(0, 0.2)})
		_pianta(c, t_at)
		c.mv.pelvis(t_st - 0.3, PELVIS).pelvis(t_st - 0.04, Vector3(0, 0.78, -0.09), 0, 0.12).pelvis(t_st + 0.08, Vector3(0, 0.95, -0.04))
		c.mv.pelvis(t_at - 0.06, Vector3(0, 0.93, -0.04)).pelvis(t_at + 0.13, Vector3(0, 0.8, -0.08), 0, 0.1).pelvis(t_at + 0.4, PELVIS)
		c.mv.bend(t_st - 0.04, Vector3(0.35, 0, 0)).bend(t_st + 0.12, Vector3(-0.1, 0, 0)).bend(t_at + 0.13, Vector3(0.25, 0, 0)).bend(t_at + 0.4, Vector3(0.0, 0, 0))
		c.mv.arm("r", t_st - 0.04, Vector3(0.2, -0.45, -0.25)).arm("r", t_st + 0.15, Vector3(0.07, 0.55, 0.08))
		c.mv.arm("r", t_at + 0.15, Vector3(0.12, 0.35, 0.15))
		c.mv.arm("l", t_st - 0.04, Vector3(0.22, -0.45, -0.25)).arm("l", t_st + 0.15, Vector3(0.25, -0.18, 0.22))
		c.mv.arm("l", t_at + 0.15, Vector3(0.28, -0.35, 0.12))
		c.mv.head(t_st + 0.1, Vector2(-0.35, 0)).head(t_at + 0.2, Vector2(-0.1, 0))
	c.mv.arm("r", c.T, Vector3(0.07, 0.55, 0.08)).arm("l", c.T, Vector3(0.25, -0.3, 0.2))
	c.mv.head(c.T, Vector2(-0.3, 0))
	return c


# ---------------------------------------------------------------- 12. inchino: un braccio sulla pancia, l'altro in fuori, poi "eccomi"
static func _inchino() -> Coreografia:
	var c := Coreografia.new("inchino", 3.0)
	_passo(c, "r", 0.05, 0.35, STANCE.r, Vector2(-0.12, -0.2))
	c.mv.leg("l", {"t": 0.35, "plant": STANCE.l})
	c.mv.arm("r", 0.5, Vector3(-0.2, -0.38, 0.24)).arm("r", 1.75, Vector3(-0.2, -0.38, 0.24))
	c.polo("r", 0.0, POLO).polo("r", 0.45, POLO_GIU).polo("r", 1.75, POLO_GIU).polo("r", 2.3, POLO)
	c.mv.arm("l", 0.5, Vector3(0.42, -0.3, -0.12)).arm("l", 1.75, Vector3(0.45, -0.28, -0.15))
	c.mv.pelvis(0.6, Vector3(0, 0.93, -0.05)).pelvis(1.1, Vector3(0, 0.91, -0.13), 0, 0.3).pelvis(1.7, Vector3(0, 0.91, -0.13), 0, 0.3)
	c.mv.pelvis(2.25, Vector3(0, 0.935, -0.04)).pelvis(c.T, Vector3(0, 0.935, -0.04))
	c.mv.bend(0.6, Vector3(0.05, 0, 0)).bend(1.1, Vector3(0.75, 0, 0)).bend(1.7, Vector3(0.78, 0, 0)).bend(2.25, Vector3(-0.08, 0, 0))
	c.mv.bend(c.T, Vector3(-0.1, 0, 0))
	c.mv.head(0.6, Vector2(0, 0)).head(1.1, Vector2(0.9, 0)).head(1.7, Vector2(0.9, 0)).head(2.25, Vector2(-0.2, 0)).head(c.T, Vector2(-0.2, 0))
	c.braccia(2.5, Vector3(0.5, 0.12, 0.12)).braccia(c.T, Vector3(0.5, 0.14, 0.12))
	return c


# ---------------------------------------------------------------- 13. braccia conserte, mento in su, un cenno con la testa
static func _conserte() -> Coreografia:
	var c := Coreografia.new("conserte", 2.8)
	_passo(c, "l", 0.05, 0.28, STANCE.l, LARGHI.l)
	_passo(c, "r", 0.15, 0.38, STANCE.r, LARGHI.r)
	c.mv.pelvis(0.4, Vector3(0, 0.925, -0.05)).pelvis(c.T, Vector3(0, 0.925, -0.05))
	c.mv.bend(0.5, Vector3(-0.1, 0, 0)).bend(c.T, Vector3(-0.1, 0, 0))
	c.mv.head(0.5, Vector2(-0.18, 0)).head(1.4, Vector2(-0.18, 0)).head(1.62, Vector2(0.2, 0)).head(1.85, Vector2(-0.18, 0))
	c.mv.head(c.T, Vector2(-0.18, 0))
	c.mv.arm("l", 0.25, Vector3(0.12, -0.3, 0.22)).arm("l", 0.6, Vector3(-0.27, -0.25, 0.27)).arm("l", c.T, Vector3(-0.27, -0.25, 0.27))
	c.mv.arm("r", 0.25, Vector3(0.12, -0.3, 0.22)).arm("r", 0.6, Vector3(-0.27, -0.21, 0.21)).arm("r", c.T, Vector3(-0.27, -0.21, 0.21))
	c.poli(0.0, POLO).poli(0.5, Vector3(0.7, -1, 0.15))
	return c


# ---------------------------------------------------------------- 14. giravolta in aria a braccia larghe
static func _giravolta() -> Coreografia:
	var c := Coreografia.new("giravolta", 2.8)
	c.perno = 0.0
	var t_st := 0.42
	var t_at := 1.02
	_salto_corpo(c, t_st, t_at, 0.42, 0.0, 0.0, Vector3.ZERO, Vector3(TAU, 0, 0))
	c.corpo(c.T, Vector3(0, 0, 0), Vector3(TAU, 0, 0))
	_pianta(c, t_st - 0.3)
	_pianta(c, t_st + 0.02)
	for s: String in ["l", "r"]:
		var x: float = Corpo.SIDE[s]
		c.mv.leg(s, {"t": (t_st + t_at) / 2.0, "ankle": Vector3(x * 0.1, 0.22, -0.1), "fq": Mossa.foot_q(0, 0.7)})
		c.mv.leg(s, {"t": t_at - 0.04, "ankle": Vector3(x * 0.14, 0.12, 0.0), "fq": Mossa.foot_q(0, 0.2)})
	_pianta(c, t_at, LARGHI)
	c.mv.pelvis(t_st - 0.3, PELVIS).pelvis(t_st - 0.03, Vector3(0, 0.8, -0.08), 0, 0.1).pelvis(t_st + 0.08, Vector3(0, 0.95, -0.04))
	c.mv.pelvis(t_at - 0.06, Vector3(0, 0.93, -0.04)).pelvis(t_at + 0.12, Vector3(0, 0.81, -0.07), 0, 0.08).pelvis(t_at + 0.42, PELVIS)
	c.mv.pelvis(c.T, PELVIS)
	c.mv.bend(t_st - 0.03, Vector3(0.3, 0, 0)).bend(t_st + 0.1, Vector3(-0.05, 0, 0)).bend(t_at + 0.12, Vector3(0.22, 0, 0))
	c.mv.bend(t_at + 0.42, Vector3(-0.1, 0, 0)).bend(c.T, Vector3(-0.1, 0, 0))
	c.braccia(t_st - 0.3, ARMS_REST).braccia(t_st - 0.03, Vector3(0.15, -0.4, 0.28)).braccia(t_st + 0.12, LARGHE)
	c.braccia(t_at - 0.05, LARGHE).braccia(t_at + 0.15, Vector3(0.45, -0.1, 0.2)).braccia(t_at + 0.5, V_SU).braccia(c.T, V_SU)
	c.mv.head(t_at + 0.5, Vector2(-0.3, 0)).head(c.T, Vector2(-0.3, 0))
	return c


# ---------------------------------------------------------------- 15. calcio alla bandierina: rincorsa e gran calcio al volo, poi urlo
static func _bandierina() -> Coreografia:
	var c := Coreografia.new("bandierina", 3.0)
	var u := 2.6
	var t_fr := 0.45                 # comincia a frenare
	var t_ap := 0.62                 # sinistro piantato
	c.corsa(0.0, 1.0).corsa(t_fr - 0.05, 1.0).corsa(t_ap, 0.0)
	c.corpo(0.0, Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, u))
	c.corpo(t_fr, Vector3(0, 0, u * t_fr), Vector3.ZERO, Vector3(0, 0, u))
	c.corpo(t_ap, Vector3(0, 0, u * t_fr + 0.32), Vector3.ZERO, Vector3(0, 0, 0.6))
	c.corpo(1.2, Vector3(0, 0, u * t_fr + 0.45)).corpo(c.T, Vector3(0, 0, u * t_fr + 0.45))
	_pianta(c, t_fr)
	c.mv.leg("l", {"t": t_ap, "plant": Vector2(0.14, 0.06), "yaw": 0.1})
	c.mv.leg("l", {"t": 1.25, "plant": Vector2(0.14, 0.06), "yaw": 0.1})
	c.mv.leg("r", {"t": t_ap, "ankle": Vector3(-0.15, 0.4, -0.38), "fq": Mossa.foot_q(0, 0.9)})
	c.mv.leg("r", {"t": 0.82, "ankle": Vector3(-0.1, 0.95, 0.5), "fq": Mossa.foot_q(0, -0.4), "pole": Vector3(0, 1, 0.3)})
	c.mv.leg("r", {"t": 0.98, "ankle": Vector3(-0.06, 1.08, 0.38), "fq": Mossa.foot_q(0, -0.5), "pole": Vector3(0, 1, 0.3)})
	c.mv.leg("r", {"t": 1.18, "ankle": Vector3(-0.15, 0.3, 0.22), "fq": Mossa.foot_q(0, 0.3)})
	c.mv.leg("r", {"t": 1.3, "plant": Vector2(-0.2, 0.12)})
	c.mv.leg("l", {"t": 1.55, "plant": Vector2(0.2, 0.06)})
	c.mv.leg("r", {"t": c.T, "plant": Vector2(-0.2, 0.12)}).leg("l", {"t": c.T, "plant": Vector2(0.2, 0.06)})
	c.mv.pelvis(t_fr, PELVIS).pelvis(t_ap, Vector3(0.03, 0.9, -0.02), -0.1, -0.05)
	c.mv.pelvis(0.85, Vector3(0.05, 0.9, -0.08), -0.2, -0.3, 0.05).pelvis(1.0, Vector3(0.05, 0.91, -0.08), -0.25, -0.3, 0.05)
	c.mv.pelvis(1.35, Vector3(0, 0.9, 0.03)).pelvis(c.T, Vector3(0, 0.91, 0.04))
	c.mv.bend(t_ap, Vector3(0.0, 0, 0)).bend(0.9, Vector3(0.15, 0, 0)).bend(1.4, Vector3(0.08, 0, 0)).bend(1.6, Vector3(-0.2, 0, 0))
	c.mv.bend(c.T, Vector3(-0.2, 0, 0))
	c.braccia(t_fr, ARMS_REST).braccia(t_ap, Vector3(0.4, -0.25, 0.1))
	c.mv.arm("l", 0.88, Vector3(0.5, 0.0, 0.15)).arm("r", 0.88, Vector3(0.42, -0.15, -0.22))
	c.braccia(1.35, Vector3(0.4, -0.25, 0.15)).braccia(1.65, Vector3(0.48, 0.1, 0.18)).braccia(c.T, Vector3(0.48, 0.12, 0.18))
	c.mv.head(0.85, Vector2(0.15, 0)).head(1.5, Vector2(0, 0)).head(1.8, Vector2(-0.3, 0)).head(c.T, Vector2(-0.3, 0))
	return c
