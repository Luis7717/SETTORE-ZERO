# Animazioni mocap vere nelle figure della partita: esultanze, parate, piatto, collo pieno e rigore, rimessa laterale,
# difesa. Clip del "Free mocap pack 05: Soccer" di Anderson Rohr, reindirizzate sul nostro scheletro da
# tools/converti_mocap.gd in assets/mocap/mocap.res (una AnimationLibrary chiamata "mocap" nell'AnimationPlayer).
#
# Come si innesta in figura.gd (pochi agganci, tutto il resto sta qui):
#   - estendi_albero(t, "salto"): in fondo all'albero delle animazioni (fermo/corsa/scatto/salto) un Blend2 "mocap"
#     mescola sopra la clip mocap scelta (Transition "mc_clip" → TimeSeek "mc_seek" → TimeScale "mc_ts");
#   - new(figura, player, albero): una per figura, aggiunge la libreria al suo AnimationPlayer;
#   - aggiorna(p, dt, ctx) a ogni posa, prima di advance: sceglie la clip, la fa partire nel punto giusto e ritorna
#     il peso (0..1); con peso > 0 la figura non mette le pose calcolate (al_posto_delle_pose) e gira il corpo di yaw.
# Le clip avanzano con l'AnimationTree della figura, quindi col tempo di gioco: rallentano col rallenty.
#
# Quando parte cosa (le regole del motore non cambiano: la vista guarda e basta):
#   - gol: il marcatore e fino a 3 compagni entro ESULTA_RAGGIO fanno esulta1..3, scelta col seme (stessa partita =
#     stesse esultanze); gli altri compagni restano con l'esultanza calcolata;
#   - tuffo del portiere: parata_alta/media/bassa del lato giusto se distanza e altezza del tuffo somigliano a quelle
#     della clip, altrimenti resta il tuffo calcolato; la clip parte poco prima dello slancio (a velocità vera, così
#     i piedi non scivolano mentre il motore sposta il portiere) e arriva al punto più lontano quando il tuffo del
#     motore è a pieno (TUFFO_PIENO);
#   - calcio (p.kickAnim che riparte): passaggio a terra = piatto, alto = collo, tiro = collo o rigore1/2, rigore =
#     rigore1/2, rimessa = rimessa; la clip parte esattamente dal fotogramma del contatto (il pallone parte adesso)
#     e il corpo si gira verso dove va il pallone. Piede: destro, mancino un giocatore su cinque (fisso per nome);
#     colpo di testa = posa calcolata;
#   - rimessa: chi batte prende il pallone e lo tiene sopra la testa (avanti e indietro nel tratto "presa") finché
#     il motore non lancia, poi parte dal rilascio; intanto il pallone sta tra le mani (pallone_in_mano);
#   - difesa1/2 in loop per chi è vicino al portatore avversario, lo guarda e va piano (peso che cala con la velocità).
extends RefCounted

const Coord := preload("res://scripts/coord.gd")
const LIB_PATH := "res://assets/mocap/mocap.res"
const LIB_NOME := &"mocap"

const P_PESO := &"parameters/mocap/blend_amount"
const P_CLIP := &"parameters/mc_clip/transition_request"
const P_SEEK := &"parameters/mc_seek/seek_request"
const P_TS := &"parameters/mc_ts/scale"

const ENTRA := 0.12            # s: la clip arriva a peso pieno
const ENTRA_CALCIO := 0.05     # s: nel calcio si entra quasi subito (il pallone parte adesso)
const ESCE := 0.25             # s: uscita dolce verso fermo/corsa
const XFADE := 0.08            # s: passaggio tra due clip mocap
const HEAD_H := 1.3            # pallone sopra questa altezza vicino al giocatore = colpo di testa (come figura.gd)
const NEAR_BALL := 2.2
const CALCIO_CORSA := 3.5      # m/s: dopo il contatto, se il motore lo fa già correre così, la clip esce prima
const CALCIO_DOPO := 0.35      # s di clip dopo il contatto prima di poter uscire per la corsa
const YAW_MAX := 1.7           # rad: al massimo si gira così verso il pallone calciato
const ESULTA_RAGGIO := 14.0    # m dal marcatore
const ESULTA_COMPAGNI := 3
const TUFFO_PIENO := 0.35      # s: il tuffo calcolato del motore è a pieno dopo questo tempo (figura.gd: p.t / 0.35)
const TUFFO_ANTICIPO := 0.05   # s di clip prima dello stacco (prima non si parte mai)
const PARATA_TOLL_X := 1.0     # m: scarto di distanza accettato tra tuffo e clip...
const PARATA_TOLL_H := 0.8     # ... e di altezza (pesati: costo = dx/TOLL_X + dh/TOLL_H < PARATA_COSTO)
const PARATA_COSTO := 1.6
const PARATA_CENTRALE := 0.35  # m: una clip che si sposta meno di così va bene per tutti e due i lati
const DIFESA_DA := 3.5         # m dal portatore: difesa piena sotto, nulla sopra DIFESA_A
const DIFESA_A := 5.5
const DIFESA_V_DA := 1.2       # m/s: difesa piena sotto, nulla sopra DIFESA_V_A (sopra si vede la corsa: la clip
const DIFESA_V_A := 3.0        # sta sul posto, più veloce i piedi scivolerebbero)
const DIFESA_PESO := 0.9
const PRESA_TS := 0.45         # velocità del tratto "presa" della rimessa (avanti e indietro)
const MANO_ENTRA := 0.2        # s: il pallone arriva nelle mani
const MANO_ESCE := 0.35        # s: dopo il rilascio torna sul pallone vero
const EPS := 0.003

## true = niente mocap (prove di confronto con le pose calcolate: prova_vista --senza-mocap)
static var spento := false
static var _lib: AnimationLibrary = null
static var _info := {}
static var _caricata := false

var clip := ""                 # clip in corso ("" = nessuna)
var tipo := ""                 # esulta, parata, calcio, presa (rimessa in attesa), difesa
var t := 0.0                   # tempo nella clip (s)
var peso := 0.0                # peso attuale (0..1)
var yaw := 0.0                 # rad: giro del corpo verso il pallone calciato

var _fig                       # figura.gd (dinamico: serve pos_corpo, corpo, _gcache)
var _albero: AnimationTree
var _bersaglio := 0.0
var _entra := ENTRA
var _ts := 1.0
var _dur := 0.0
var _scritto := PackedFloat32Array([-1.0, -9.0])   # peso e velocità scritti nell'albero
var _kick_prima := 0.0
var _stato_prima := "play"
var _gol_visto := -1
var _ripresa := ""             # tipo della ripresa di cui questa figura è il battitore (fotogramma prima)
var _piede := ""
var _n_calci := 0
var _mano := 0.0               # peso del pallone tra le mani (rimessa)
var _contatto := 0.0


## carica la libreria una volta; false se manca (allora niente mocap e il gioco va avanti come prima)
static func carica() -> bool:
	if _caricata:
		return _lib != null
	_caricata = true
	if not ResourceLoader.exists(LIB_PATH):
		push_warning("mocap: manca " + LIB_PATH)
		return false
	_lib = load(LIB_PATH) as AnimationLibrary
	if _lib != null:
		_info = _lib.get_meta("info", {})
	return _lib != null


static func libreria() -> AnimationLibrary:
	carica()
	return _lib


## dati di una clip misurati dal convertitore: {tipo, contatto, piede, stacco, lato, raggio_x, raggio_h, presa_da, presa_a}
static func info(nome: String) -> Dictionary:
	carica()
	return _info.get(nome, {})


## da dove parte una clip di parata: TUFFO_PIENO prima del punto più lontano (velocità vera), mai prima dello stacco
static func inizio_parata(inf: Dictionary) -> float:
	return maxf(maxf(0.0, float(inf.stacco) - TUFFO_ANTICIPO), float(inf.contatto) - TUFFO_PIENO)


static func durata(nome: String) -> float:
	carica()
	return _lib.get_animation(nome).length if _lib != null and _lib.has_animation(nome) else 0.0


## aggiunge in fondo all'albero (output ← sorgente) il ramo mocap. Senza libreria non cambia niente
static func estendi_albero(t: AnimationNodeBlendTree, sorgente: StringName) -> void:
	if not carica():
		return
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = XFADE
	tr.allow_transition_to_self = true
	var nomi := _lib.get_animation_list()
	for i in nomi.size():
		tr.add_input(String(nomi[i]))
		tr.set_input_reset(i, false)   # il punto di partenza lo decide mc_seek
	t.add_node("mc_clip", tr, Vector2(800, 600))
	var x := 0.0
	for i in nomi.size():
		var a := AnimationNodeAnimation.new()
		a.animation = String(LIB_NOME) + "/" + String(nomi[i])
		t.add_node("mc_" + String(nomi[i]), a, Vector2(x, 700))
		t.connect_node("mc_clip", i, "mc_" + String(nomi[i]))
		x += 150.0
	t.add_node("mc_seek", AnimationNodeTimeSeek.new(), Vector2(1000, 600))
	t.connect_node("mc_seek", 0, "mc_clip")
	t.add_node("mc_ts", AnimationNodeTimeScale.new(), Vector2(1200, 600))
	t.connect_node("mc_ts", 0, "mc_seek")
	t.add_node("mocap", AnimationNodeBlend2.new(), Vector2(1400, 300))
	t.disconnect_node("output", 0)
	t.connect_node("mocap", 0, sorgente)
	t.connect_node("mocap", 1, "mc_ts")
	t.connect_node("output", 0, "mocap")


func _init(figura: Node3D, player: AnimationPlayer, albero: AnimationTree) -> void:
	_fig = figura
	_albero = albero
	if carica() and not player.has_animation_library(LIB_NOME):
		player.add_animation_library(LIB_NOME, _lib)


## true se la clip mocap sta comandando il corpo (le pose calcolate non servono)
func al_posto_delle_pose() -> bool:
	return peso > 0.0


## Una volta per fotogramma, prima di advance. ctx = quello di figura.posa (t, phase, ball, ...) più m (SimMatch).
## Ritorna il peso della clip (0..1).
func aggiorna(p: Object, dt: float, ctx: Dictionary) -> float:
	if _lib == null or spento or _albero == null:
		return 0.0
	var m: Object = ctx.get("m")
	var b: Object = ctx.get("ball")
	if _piede == "":
		_piede = "sx" if absi(hash(str(p.team) + ":" + str(p.name))) % 5 == 0 else "dx"
	var st: String = p.state
	var calcio_nuovo: bool = p.kickAnim > _kick_prima + 0.05
	_kick_prima = p.kickAnim
	var tuffo_nuovo := st == "dive" and _stato_prima != "dive" and p.dive != null
	_stato_prima = st
	var ripresa_prima := _ripresa
	_ripresa = ""
	if m != null and m.phase == "restart" and m.restart != null and m.restart.taker == p:
		_ripresa = m.restart.type
	_avanza_tempo(dt)
	# ---- esultanza
	if ctx.phase == "goal" and p.cele > 0 and m != null:
		if _gol_visto != m.goalsLog.size():
			_gol_visto = m.goalsLog.size()
			var e := _scegli_esultanza(p, m)
			if e != "":
				_avvia(e, "esulta", 0.0, ENTRA, 1.0)
	elif tipo == "esulta":
		_ferma()
	# ---- tuffo del portiere
	if tuffo_nuovo:
		var v := _scegli_parata(p)
		if v != "":
			var inf := info(v)
			_contatto = float(inf.contatto)
			var t0 := inizio_parata(inf)
			_avvia(v, "parata", t0, ENTRA, clampf((_contatto - t0) / TUFFO_PIENO, 0.7, 2.2))
			yaw = _giro_verso_il_campo(p)
	if tipo == "parata":
		if st != "dive" and st != "down":
			_ferma()
		elif t >= _contatto:
			_imposta_ts(1.0)
	# ---- calcio
	if calcio_nuovo and tipo != "esulta" and tipo != "parata":
		var testa: bool = b != null and Vector2(b.x - p.x, b.y - p.y).length() < NEAR_BALL and b.h > HEAD_H
		if not testa:
			_calcio(p, b, ripresa_prima)
	if tipo == "calcio":
		var v := sqrt(p.vx * p.vx + p.vy * p.vy)
		if t >= _dur - ESCE or (t > _contatto + CALCIO_DOPO and v > CALCIO_CORSA):
			_ferma()
	# ---- rimessa: il battitore prende il pallone e aspetta
	if _ripresa == "throw" and tipo != "calcio" and tipo != "presa":
		_avvia("rimessa", "presa", 0.0, ENTRA, 1.0)
	if tipo == "presa":
		if _ripresa != "throw":
			_ferma()
		else:
			var inf := info("rimessa")
			if t >= float(inf.presa_a) and _ts > 0.0:
				_imposta_ts(-PRESA_TS)
			elif t <= float(inf.presa_da) and _ts < 0.0:
				_imposta_ts(PRESA_TS)
	# ---- difesa
	var wd := _peso_difesa(p, m, ctx)
	if wd > 0.0 and (tipo == "" or tipo == "difesa"):
		if tipo == "":
			var nome := "difesa1" if p.i % 2 == 0 else "difesa2"
			_avvia(nome, "difesa", fmod(p.i * 0.77, durata(nome)), ENTRA * 2.0, 1.0)
		_bersaglio = wd
	elif tipo == "difesa":
		_ferma()
	# ---- pallone tra le mani nella rimessa
	var mano_su := tipo == "presa" or (tipo == "calcio" and clip == "rimessa" and t < _contatto)
	_mano = move_toward(_mano, 1.0 if mano_su else 0.0, dt / (MANO_ENTRA if mano_su else MANO_ESCE))
	# ---- peso
	var rate := _entra if _bersaglio > peso else ESCE
	peso = move_toward(peso, _bersaglio, dt / rate) if dt > 0.0 else peso
	if peso <= 0.0 and _bersaglio <= 0.0 and tipo == "":
		clip = ""
		yaw = 0.0
	elif _bersaglio <= 0.0:
		yaw = move_toward(yaw, 0.0, dt * 3.0)
	_scrivi(0, P_PESO, peso)
	return peso


## stato per i test e le prove: {clip, tipo, t, peso, yaw}
func stato() -> Dictionary:
	return {"clip": clip, "tipo": tipo, "t": t, "peso": peso, "yaw": yaw, "bersaglio": _bersaglio}


## pallone nella rimessa: Vector4(x, y, z del mondo tra le mani, peso 0..1); peso 0 = il pallone resta dov'è
func pallone_in_mano() -> Vector4:
	if _mano <= 0.0 or not _fig.has_method("pos_corpo"):
		return Vector4.ZERO
	_fig._gcache.clear()
	var c: Vector3 = (_fig.pos_corpo("hand_l") + _fig.pos_corpo("hand_r")) * 0.5 + Vector3(0, 0.12, 0.06)
	var corpo: Node3D = _fig.corpo
	var w: Transform3D = _fig.global_transform if _fig.is_inside_tree() else _fig.transform
	var g := w * (corpo.transform * c)
	return Vector4(g.x, g.y, g.z, _mano)


# ---------------------------------------------------------------- scelte
func _calcio(p: Object, b: Object, ripresa: String) -> void:
	_n_calci += 1
	var k: Object = b.kick if b != null else null
	var tk: String = k.type if k != null and k.kicker == p else "shot"
	var n := ""
	if ripresa == "throw":
		n = "rimessa"
	elif ripresa == "penalty":
		n = "rigore%d_%s" % [1 + (_n_calci + p.i) % 2, _piede]
	elif tk == "ground":
		n = "piatto_" + _piede
	elif tk == "loft":
		n = "collo_" + _piede
	else:
		n = ["collo", "rigore1", "rigore2"][(_n_calci + p.i) % 3] + "_" + _piede
	if not _lib.has_animation(n):
		return
	_contatto = float(info(n).get("contatto", 0.0))
	if n == "rimessa" and tipo == "presa":
		# era già col pallone sopra la testa: dal rilascio
		tipo = "calcio"
		t = _contatto
		_albero.set(P_SEEK, t)
		_imposta_ts(1.0)
	else:
		_avvia(n, "calcio", _contatto, ENTRA_CALCIO, 1.0)
	# il corpo si gira verso dove va il pallone (in campo l'angolo tra lo sguardo e la velocità del pallone)
	yaw = 0.0
	if b != null and absf(b.vx) + absf(b.vy) > 0.5:
		var a := atan2(p.fx * b.vy - p.fy * b.vx, p.fx * b.vx + p.fy * b.vy)
		yaw = clampf(a, -YAW_MAX, YAW_MAX)


# marcatore + i compagni più vicini a lui (al massimo ESULTA_COMPAGNI entro ESULTA_RAGGIO); clip scelta col seme
func _scegli_esultanza(p: Object, m: Object) -> String:
	if m.goalsLog.is_empty():
		return ""
	var g: Dictionary = m.goalsLog.back()
	var marcatore: Object = null
	for q: Object in m.players:
		if not q.off and g.get("scorer") != null and q.src == g.scorer:
			marcatore = q
	if marcatore == null:   # autogol: festeggia chi è più vicino al pallone
		var dmin := INF
		for q: Object in m.players:
			if not q.off and q.cele > 0:
				var d := Vector2(q.x - m.ball.x, q.y - m.ball.y).length()
				if d < dmin:
					dmin = d
					marcatore = q
	if marcatore == null or marcatore.team != p.team:
		return ""
	if p != marcatore:
		var d := Vector2(p.x - marcatore.x, p.y - marcatore.y).length()
		if d > ESULTA_RAGGIO:
			return ""
		var piu_vicini := 0
		for q: Object in m.players:
			if q != p and q != marcatore and not q.off and q.team == p.team \
					and Vector2(q.x - marcatore.x, q.y - marcatore.y).length() < d:
				piu_vicini += 1
		if piu_vicini >= ESULTA_COMPAGNI:
			return ""
	var h := absi(hash("%d:%s:%d:%d" % [m.goalsLog.size(), str(g.get("minute", 0)), p.team, p.i]))
	return "esulta%d" % (1 + h % 3)


## clip di parata per il tuffo del motore (p.dive): stesso lato, distanza e altezza vicine; "" = tuffo calcolato
func _scegli_parata(p: Object) -> String:
	var d: Object = p.dive
	# la clip si fa col petto verso il campo (_giro_verso_il_campo): guardando +y la sinistra è −x, guardando −y è +x
	var lato := 1 if d.dirx * _verso_campo(p) < 0.0 else -1
	var r: float = absf(d.tx - d.x0)
	var best := ""
	var costo := PARATA_COSTO
	for nome: String in _info:
		var inf: Dictionary = _info[nome]
		if inf.get("tipo") != "parata":
			continue
		var rx: float = float(inf.raggio_x) * Coord.SCALE
		if rx > PARATA_CENTRALE and int(inf.lato) != lato:
			continue
		var c := absf(r - rx) / PARATA_TOLL_X + absf(float(d.th) - float(inf.raggio_h) * Coord.SCALE) / PARATA_TOLL_H
		if rx <= PARATA_CENTRALE and int(inf.lato) != lato:
			c += 0.01   # centrale: a parità meglio la versione del lato giusto
		if c < costo:
			costo = c
			best = nome
	return best


# il portiere guarda verso il campo: +y se la sua porta è in basso (y < 0), −y altrimenti
func _verso_campo(p: Object) -> float:
	return 1.0 if p.y < 0.0 else -1.0


# giro del corpo (come yaw in _calcio) che mette il petto del portiere verso il campo: il tuffo del motore va lungo
# la linea di porta qualunque sia lo sguardo del portiere in quel momento, la clip va di lato rispetto al petto
func _giro_verso_il_campo(p: Object) -> float:
	var vy := _verso_campo(p)
	return atan2(p.fx * vy, p.fy * vy)


func _peso_difesa(p: Object, m: Object, ctx: Dictionary) -> float:
	if m == null or ctx.phase != "play" or p.pos == "P" or p.state != "play":
		return 0.0
	var o: Object = m.ball.owner
	if o == null or o.team == p.team:
		return 0.0
	var dx: float = o.x - p.x
	var dy: float = o.y - p.y
	var d := sqrt(dx * dx + dy * dy)
	if d > DIFESA_A or d < 0.01 or (p.fx * dx + p.fy * dy) / d < 0.3:
		return 0.0
	var v := sqrt(p.vx * p.vx + p.vy * p.vy)
	return DIFESA_PESO * (1.0 - smoothstep(DIFESA_DA, DIFESA_A, d)) * (1.0 - smoothstep(DIFESA_V_DA, DIFESA_V_A, v))


# ---------------------------------------------------------------- albero
func _avvia(nome: String, tipo_: String, t0: float, entra: float, ts: float) -> void:
	clip = nome
	tipo = tipo_
	t = t0
	_dur = durata(nome)
	_entra = entra
	_bersaglio = 1.0
	_albero.set(P_CLIP, nome)
	_albero.set(P_SEEK, t0)
	_imposta_ts(ts)


func _ferma() -> void:
	tipo = ""
	_bersaglio = 0.0


func _imposta_ts(ts: float) -> void:
	_ts = ts
	_scrivi(1, P_TS, ts)


func _avanza_tempo(dt: float) -> void:
	if clip == "":
		return
	t += dt * _ts
	var anim := _lib.get_animation(clip)
	if anim != null and anim.loop_mode != Animation.LOOP_NONE and _dur > 0.0:
		t = fposmod(t, _dur)
	else:
		t = clampf(t, 0.0, _dur)


func _scrivi(k: int, nome: StringName, val: float) -> void:
	if absf(_scritto[k] - val) > EPS or (val == 0.0 and _scritto[k] != 0.0):
		_scritto[k] = val
		_albero.set(nome, val)
