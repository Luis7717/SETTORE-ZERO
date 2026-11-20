# Converte le animazioni mocap del "Free mocap pack 05: Soccer" di Anderson Rohr (versione UE5, file .fbx) sullo
# scheletro del nostro modello (assets/models/athlete.glb) e le salva in assets/mocap/mocap.res, una AnimationLibrary
# compressa. Strumento di sviluppo: non finisce nell'app (gira solo dal PC).
#
# Uso:  $G --headless --path godot -s res://tools/converti_mocap.gd [-- CARTELLA_UE5] [--tutte] [--analizza]
#   CARTELLA_UE5   dove stanno i .fbx "*_ue5.fbx" (predefinita: C:/Users/forma/Documents/mocap-pack05/mocap/UE5)
#   --tutte        mette in libreria anche le clip che il gioco non usa (dribbling)
#   --analizza     stampa solo le misure delle clip (contatto, stacco, raggio della parata), non salva
#
# I file del pacchetto sono dati: li legge il lettore FBX di Godot (ufbx), non si esegue niente da lì.
#
# Come funziona il reindirizzamento (retargeting): i due scheletri hanno gli stessi nomi UE ("pelvis", "thigh_l"...)
# e sono tutti e due in posa a T. Per ogni osso del nostro modello si prende l'osso corrispondente del pacchetto e se
# ne copia la rotazione *nel mondo* rispetto alla posa a T (D = Q(t) · Q_riposo⁻¹), passata dal riferimento del
# pacchetto (Z in alto, avanti = −Y) a quello del corpo (+X sinistra, +Y su, +Z avanti) e poi a quello del nostro
# scheletro. Le ossa in più del pacchetto (spine_04/05, neck_02, ossa di torsione, dita) non servono: la rotazione
# nel mondo le comprende già. Il bacino tiene l'altezza (scalata sulla nostra) ma non lo spostamento orizzontale,
# che in partita decide il motore. Il primo fotogramma di ogni file è la posa a T e si salta.
#
# Clip specchiate ("_sx"/"_dx"): destra e sinistra scambiate (ossa _l ↔ _r, rotazioni riflesse sul piano del corpo).
extends SceneTree

const SORGENTE := "C:/Users/forma/Documents/mocap-pack05/mocap/UE5"
const USCITA := "res://assets/mocap/mocap.res"
const MODELLO := "res://assets/models/athlete.glb"
const FPS := 30.0
const PASSO := 1.0 / FPS

# osso del nostro modello ← osso del pacchetto (rotazione nel mondo copiata)
const MAPPA := {
	"pelvis": "pelvis", "spine_01": "spine_02", "spine_02": "spine_04", "spine_03": "spine_05",
	"neck_01": "neck_01", "Head": "head",
	"clavicle_l": "clavicle_l", "upperarm_l": "upperarm_l", "lowerarm_l": "lowerarm_l", "hand_l": "hand_l",
	"clavicle_r": "clavicle_r", "upperarm_r": "upperarm_r", "lowerarm_r": "lowerarm_r", "hand_r": "hand_r",
	"thigh_l": "thigh_l", "calf_l": "calf_l", "foot_l": "foot_l", "ball_l": "ball_l",
	"thigh_r": "thigh_r", "calf_r": "calf_r", "foot_r": "foot_r", "ball_r": "ball_r",
}

# Clip della libreria. da/a = secondi del file sorgente. tipo:
#   calcio   → contatto = fotogramma col piede più veloce vicino a terra; verso girato perché il piede, al contatto,
#              vada dritto in avanti (+Z); versione specchiata per l'altro piede (nome_dx / nome_sx)
#   rimessa  → rilascio = mani più veloci in avanti; presa = tratto con il pallone sopra la testa (attesa)
#   parata   → stacco = mani che partono, raggio = punto più lontano delle mani; specchiata per l'altro lato
#   giro     → clip in loop (dissolvenza tra fine e inizio)
#   semplice → così com'è
const CLIP := [
	{"nome": "piatto", "file": "08_Side_Foot_Kick", "da": 0.95, "a": 2.35, "tipo": "calcio"},
	{"nome": "collo", "file": "09_Power_Kick", "da": 2.1, "a": 3.45, "tipo": "calcio"},
	{"nome": "rigore1", "file": "10_Penalty_Kick_01", "da": 6.1, "a": 7.45, "tipo": "calcio"},
	{"nome": "rigore2", "file": "11_Penalty_Kick_02", "da": 4.55, "a": 5.9, "tipo": "calcio"},
	{"nome": "rimessa", "file": "07_Throw_In", "da": 1.0, "a": 7.9, "tipo": "rimessa", "presa": [2.3, 6.0]},
	{"nome": "esulta1", "file": "12_Goal_Celebration_01", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "esulta2", "file": "13_Goal_Celebration_02", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "esulta3", "file": "14_Goal_Celebration_03", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "parata_alta", "file": "15_Goalkeeper_Save_01", "da": 4.4, "a": 6.7, "tipo": "parata"},
	{"nome": "parata_media", "file": "16_Goalkeeper_Save_02", "da": 2.7, "a": 4.35, "tipo": "parata"},
	{"nome": "parata_bassa", "file": "17_Goalkeeper_Save_03", "da": 5.8, "a": 8.6, "tipo": "parata", "finestra": 1.0},
	{"nome": "difesa1", "file": "18_Defending_01", "da": 0.4, "a": 4.4, "tipo": "giro"},
	{"nome": "difesa2", "file": "19_Defending_02", "da": 0.4, "a": 4.1, "tipo": "giro"},
	{"nome": "giallo", "file": "20_Yellow_Card", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "giallo_rosso", "file": "21_Yellow_And_Red_Card", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "palleggio1", "file": "04_Juggling_01", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "palleggio2", "file": "05_Juggling_02", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "palleggio3", "file": "06_Juggling_03", "da": PASSO, "a": 99.0, "tipo": "semplice"},
	{"nome": "dribbling1", "file": "01_Dribble_01", "da": PASSO, "a": 99.0, "tipo": "semplice", "solo_tutte": true},
	{"nome": "dribbling2", "file": "02_Dribble_02", "da": PASSO, "a": 99.0, "tipo": "semplice", "solo_tutte": true},
	{"nome": "dribbling3", "file": "03_Dribble_03", "da": PASSO, "a": 99.0, "tipo": "semplice", "solo_tutte": true},
]
const GIRO_DISSOLVENZA := 0.4      # s: nelle clip in loop la fine sfuma nell'inizio
const CONTATTO_H := 0.3            # m: il piede al contatto è più basso di così (il pallone è a terra)
const STACCO_V := 1.6              # m/s: velocità delle mani che fa partire la parata
const PARATA_FINESTRA := 0.6       # s: il punto più lontano delle mani si cerca entro questo tempo dallo stacco
                                   # (dopo c'è l'atterraggio; "finestra" nella clip lo cambia)
const COMPRESSIONE_FPS := 60       # Animation.compress: fotogrammi per secondo dei dati compressi
const COMPRESSIONE_TOLLERANZA := 2.0

# riferimento del corpo: +X sinistra, +Y su, +Z avanti
var _bs := Basis.IDENTITY          # colonne = sinistra, su, avanti nelle coordinate del pacchetto
var _bt := Basis.IDENTITY          # idem nelle coordinate del nostro scheletro
var _t_nomi: PackedStringArray     # ossa del nostro scheletro (indice = osso)
var _t_padre: PackedInt32Array
var _t_riposo_q := {}              # osso → rotazione nel nostro scheletro in posa a T
var _t_radice := Transform3D.IDENTITY
var _t_bacino := Vector3.ZERO      # posizione del bacino in posa a T (riferimento del corpo)
var fot_riposo_bacino := Transform3D.IDENTITY   # bacino del pacchetto in posa a T (per _verso_bacino)
var _percorso_tracce := ""         # prefisso delle tracce ("Skeleton3D" o simile), preso dal clip "idle" del modello


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cartella := SORGENTE
	var tutte := args.has("--tutte")
	var analizza := args.has("--analizza")
	for a in args:
		if not a.begins_with("--"):
			cartella = a
	if not _prepara_bersaglio():
		quit(1)
		return
	var lib := AnimationLibrary.new()
	var info := {}
	var ok := true
	for c: Dictionary in CLIP:
		if c.get("solo_tutte", false) and not tutte:
			continue
		var path := cartella.path_join(c.file + "_ue5.fbx")
		if not FileAccess.file_exists(path):
			push_error("manca " + path)
			ok = false
			continue
		var sorg := _leggi_fbx(path)
		if sorg.is_empty():
			ok = false
			continue
		for v: Dictionary in _converti(sorg, c):
			lib.add_animation(v.nome, v.anim)
			info[v.nome] = v.info
			print("%-18s %5.2f s  %s" % [v.nome, v.anim.length, _breve(v.info)])
		(sorg.radice as Node).free()
	if analizza:
		quit(0 if ok else 1)
		return
	lib.set_meta("info", info)
	lib.set_meta("fonte", "Free mocap pack 05: Soccer, Anderson Rohr (andersonrohr.gumroad.com/l/mocap_pack5)")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USCITA.get_base_dir()))
	var err := ResourceSaver.save(lib, USCITA, ResourceSaver.FLAG_COMPRESS)
	var size := FileAccess.get_file_as_bytes(USCITA).size()
	print("salvato %s: %d clip, %.1f KB, errore=%d" % [USCITA, lib.get_animation_list().size(), size / 1024.0, err])
	quit(0 if ok and err == OK else 1)


func _breve(i: Dictionary) -> String:
	var s := ""
	for k: String in i:
		var v: Variant = i[k]
		s += "%s=%s " % [k, ("%.2f" % v) if v is float else str(v)]
	return s


# ---------------------------------------------------------------- scheletro di arrivo (athlete.glb)
func _prepara_bersaglio() -> bool:
	var scena := load(MODELLO) as PackedScene
	if scena == null:
		push_error("non trovo " + MODELLO)
		return false
	var radice := scena.instantiate()
	var sk := radice.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := radice.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var idle := ap.get_animation("idle")
	_percorso_tracce = String(idle.track_get_path(0)).get_slice(":", 0)
	for b in sk.get_bone_count():
		_t_nomi.append(sk.get_bone_name(b))
		_t_padre.append(sk.get_bone_parent(b))
		_t_riposo_q[sk.get_bone_name(b)] = sk.get_bone_global_rest(b).basis.orthonormalized().get_rotation_quaternion()
	for n: String in MAPPA:
		if not _t_nomi.has(n):
			push_error("il modello non ha l'osso " + n)
			radice.free()
			return false
	var g := func(n: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(n)).origin
	_bt = _base_corpo(g.call("Head"), (g.call("foot_l") + g.call("foot_r")) * 0.5, g.call("foot_r"), g.call("ball_r"))
	_t_radice = sk.get_bone_global_rest(sk.find_bone("root")) if sk.find_bone("root") >= 0 else Transform3D.IDENTITY
	_t_bacino = _bt.inverse() * (g.call("pelvis") as Vector3)
	radice.free()
	return true


# colonne: sinistra, su, avanti (su = dai piedi alla testa, avanti = verso la punta del piede, sul piano orizzontale)
static func _base_corpo(testa: Vector3, piedi: Vector3, piede: Vector3, punta: Vector3) -> Basis:
	var su := (testa - piedi).normalized()
	var av := punta - piede
	av = (av - su * av.dot(su)).normalized()
	var sx := su.cross(av).normalized()
	return Basis(sx, su, sx.cross(su).normalized())


# ---------------------------------------------------------------- file del pacchetto
func _leggi_fbx(path: String) -> Dictionary:
	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(path, st) != OK:
		push_error("non riesco a leggere " + path)
		return {}
	var radice := doc.generate_scene(st)
	var sks := radice.find_children("*", "Skeleton3D", true, false)
	var aps := radice.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		push_error("niente scheletro o animazione in " + path)
		radice.free()
		return {}
	var sk := sks[0] as Skeleton3D
	var ap := aps[0] as AnimationPlayer
	var an := ap.get_animation(ap.get_animation_list()[0])
	var s := {"radice": radice, "sk": sk, "an": an, "n": sk.get_bone_count(), "rot": [], "pos": [], "riposo": []}
	for b in sk.get_bone_count():
		var np := NodePath("%s:%s" % [String(an.track_get_path(0)).get_slice(":", 0), sk.get_bone_name(b)])
		s.rot.append(an.find_track(np, Animation.TYPE_ROTATION_3D))
		s.pos.append(an.find_track(np, Animation.TYPE_POSITION_3D))
		s.riposo.append(sk.get_bone_rest(b))
	var gr := _globali(s, -1.0)
	s["riposo_g"] = gr
	fot_riposo_bacino = gr[sk.find_bone("pelvis")]
	var p := func(n: String) -> Vector3: return (gr[sk.find_bone(n)] as Transform3D).origin
	_bs = _base_corpo(p.call("head"), (p.call("foot_l") + p.call("foot_r")) * 0.5, p.call("foot_r"), p.call("ball_r"))
	return s


# pose nel mondo di tutte le ossa all'istante t (t < 0 = posa a T). La radice ("root") porta solo il giro da Z-su a
# Y-su dell'esportazione: si lascia fuori, così posa a T e animazione stanno nello stesso riferimento.
func _globali(s: Dictionary, t: float) -> Array:
	var sk: Skeleton3D = s.sk
	var an: Animation = s.an
	var out := []
	out.resize(s.n)
	for b in s.n:
		var rest: Transform3D = s.riposo[b]
		var q := rest.basis.get_rotation_quaternion()
		var o := rest.origin
		if t >= 0.0:
			if s.rot[b] >= 0:
				q = an.rotation_track_interpolate(s.rot[b], t)
			if s.pos[b] >= 0:
				o = an.position_track_interpolate(s.pos[b], t)
		var par := sk.get_bone_parent(b)
		if par < 0:
			out[b] = Transform3D.IDENTITY
		else:
			out[b] = (out[par] as Transform3D) * Transform3D(Basis(q), o)
	return out


# ---------------------------------------------------------------- conversione
func _converti(s: Dictionary, c: Dictionary) -> Array:
	var an: Animation = s.an
	var da: float = maxf(c.da, PASSO)
	var a: float = minf(c.a, an.length)
	var n := int(floor((a - da) / PASSO + 1e-4)) + 1
	var fot: Array = []   # per ogni fotogramma: Array di pose nel mondo (riferimento del pacchetto)
	for i in n:
		fot.append(_globali(s, da + i * PASSO))
	var sk: Skeleton3D = s.sk
	var idx := func(nome: String) -> int: return sk.find_bone(nome)
	var tipo: String = c.tipo
	var out: Array = []
	match tipo:
		"calcio":
			var m := _misura_calcio(fot, idx)
			# versione col piede usato nel file e versione specchiata per l'altro
			for specchio: bool in [false, true]:
				var piede: String = m.piede if not specchio else ("sx" if m.piede == "dx" else "dx")
				var psi: float = m.psi * (-1.0 if specchio else 1.0)
				var anim := _anima(s, fot, specchio, psi, false)
				out.append({"nome": "%s_%s" % [c.nome, piede], "anim": anim,
					"info": {"tipo": "calcio", "contatto": m.i * PASSO, "piede": piede}})
		"rimessa":
			var m := _misura_rimessa(fot, idx)
			var anim := _anima(s, fot, false, m.psi, false)
			var presa: Array = c.presa
			out.append({"nome": c.nome, "anim": anim, "info": {"tipo": "rimessa", "contatto": m.i * PASSO,
				"presa_da": presa[0] - da, "presa_a": presa[1] - da}})
		"parata":
			var m := _misura_parata(fot, idx, float(c.get("finestra", PARATA_FINESTRA)))
			var lato := 1 if m.x >= 0.0 else -1   # +1 = verso la sinistra del portiere
			var psi := _verso_bacino(fot, idx, 0, maxi(1, m.stacco))   # prima dello stacco guarda chi tira
			for specchio: bool in [false, true]:
				var l := lato * (-1 if specchio else 1)
				var anim := _anima(s, fot, specchio, psi * (-1.0 if specchio else 1.0), false)
				out.append({"nome": "%s_%s" % [c.nome, "sx" if l > 0 else "dx"], "anim": anim,
					"info": {"tipo": "parata", "stacco": m.stacco * PASSO, "contatto": m.i * PASSO,
						"lato": l, "raggio_x": absf(m.x), "raggio_h": m.h}})
		"giro":
			var anim := _anima(s, fot, false, _verso_bacino(fot, idx, 0, fot.size()), true)
			out.append({"nome": c.nome, "anim": anim, "info": {"tipo": "giro"}})
		_:
			var anim := _anima(s, fot, false, _verso_bacino(fot, idx, 0, fot.size()), false)
			out.append({"nome": c.nome, "anim": anim, "info": {"tipo": "semplice"}})
	return out


# verso medio del bacino (rad, da +Z verso +X) nei fotogrammi [da, a): le clip senza un verso preciso (esultanze,
# difesa, parate, cartellini, palleggi) si girano perché in media il corpo guardi avanti
func _verso_bacino(fot: Array, idx: Callable, da: int, a: int) -> float:
	var b: int = idx.call("pelvis")
	var bs_q := _bs.get_rotation_quaternion()
	var somma := Vector2.ZERO
	for i in range(da, mini(a, fot.size())):
		var q := (fot[i][b] as Transform3D).basis.orthonormalized().get_rotation_quaternion()
		var r := ((fot_riposo_bacino as Transform3D).basis.orthonormalized().get_rotation_quaternion())
		var d := bs_q.inverse() * (q * r.inverse()) * bs_q
		var av := d * Vector3.BACK
		somma += Vector2(av.x, av.z)
	return atan2(somma.x, somma.y)


# posizione di un osso nel riferimento del corpo (metri del pacchetto)
func _p(g: Array, b: int) -> Vector3:
	return _bs.inverse() * (g[b] as Transform3D).origin


# contatto del calcio: piede (punta, osso "ball") più veloce mentre è basso; verso del piede in quel momento
func _misura_calcio(fot: Array, idx: Callable) -> Dictionary:
	var best := {"v": -1.0}
	for lato: String in ["l", "r"]:
		var b: int = idx.call("ball_" + lato)
		for i in range(1, fot.size() - 1):
			var p := _p(fot[i], b)
			if p.y > CONTATTO_H:
				continue
			var v := (_p(fot[i + 1], b) - _p(fot[i - 1], b)) / (2.0 * PASSO)
			if v.length() > best.v:
				best = {"v": v.length(), "i": i, "piede": "dx" if lato == "r" else "sx", "dir": v}
	var d: Vector3 = best.dir
	return {"i": best.i, "piede": best.piede, "psi": atan2(d.x, d.z)}


# rilascio della rimessa: mani (punto medio) più veloci in avanti; verso del lancio
func _misura_rimessa(fot: Array, idx: Callable) -> Dictionary:
	var hl: int = idx.call("hand_l")
	var hr: int = idx.call("hand_r")
	var best := {"v": -INF, "i": 0, "dir": Vector3.BACK}
	for i in range(1, fot.size() - 1):
		var p0 := (_p(fot[i - 1], hl) + _p(fot[i - 1], hr)) * 0.5
		var p1 := (_p(fot[i + 1], hl) + _p(fot[i + 1], hr)) * 0.5
		var v := (p1 - p0) / (2.0 * PASSO)
		if v.z > best.v:
			best = {"v": v.z, "i": i, "dir": v}
	var d: Vector3 = best.dir
	return {"i": best.i, "psi": atan2(d.x, d.z)}


# parata: stacco = prima volta che le mani vanno più veloci di STACCO_V; raggio = mani più lontane da dove erano allo
# stacco. x = spostamento di lato (spostamento del bacino compreso: in partita lo fa il motore), h = altezza delle mani
func _misura_parata(fot: Array, idx: Callable, finestra: float) -> Dictionary:
	var hl: int = idx.call("hand_l")
	var hr: int = idx.call("hand_r")
	var mani := func(i: int) -> Vector3: return (_p(fot[i], hl) + _p(fot[i], hr)) * 0.5
	var stacco := 0
	for i in range(1, fot.size() - 1):
		if ((mani.call(i + 1) - mani.call(i - 1)) / (2.0 * PASSO)).length() > STACCO_V:
			stacco = i
			break
	var m0: Vector3 = mani.call(stacco)
	var best := {"d": -1.0, "i": stacco}
	for i in range(stacco, mini(fot.size(), stacco + int(finestra / PASSO) + 1)):
		var dm: Vector3 = mani.call(i) - m0
		var d := Vector2(dm.x, dm.y).length()   # di lato e in alto (in avanti non conta)
		if d > best.d:
			best = {"d": d, "i": i}
	var mr: Vector3 = mani.call(best.i)
	return {"stacco": stacco, "i": best.i, "x": mr.x - m0.x, "h": mr.y}


# l'animazione per il nostro scheletro. specchio = destra/sinistra scambiate; psi = verso da raddrizzare (rad);
# giro = clip in loop con dissolvenza tra fine e inizio
func _anima(s: Dictionary, fot: Array, specchio: bool, psi: float, giro: bool) -> Animation:
	var sk: Skeleton3D = s.sk
	var gr: Array = s.riposo_g
	var yaw := Quaternion(Vector3.UP, -psi)
	var bs_q := _bs.get_rotation_quaternion()
	var bt_q := _bt.get_rotation_quaternion()
	var src_riposo_q := {}
	for n: String in MAPPA:
		var sb := sk.find_bone(MAPPA[n])
		src_riposo_q[n] = (gr[sb] as Transform3D).basis.orthonormalized().get_rotation_quaternion()
	var sb_bacino := sk.find_bone("pelvis")
	var h_sorg := (_bs.inverse() * (gr[sb_bacino] as Transform3D).origin).y
	var k := _t_bacino.y / h_sorg   # altezza del bacino: la nostra rispetto a quella del pacchetto
	var n := fot.size()
	var pose: Array = []            # per fotogramma: {osso: rotazione locale}, "pos": posizione locale del bacino
	for i in n:
		var g: Array = fot[i]
		var glob := {}              # osso del nostro scheletro → rotazione nel nostro scheletro
		for nome: String in MAPPA:
			var sorg_nome: String = nome
			if specchio:
				sorg_nome = _scambia(nome)
			var sb := sk.find_bone(MAPPA[sorg_nome])
			var q := (g[sb] as Transform3D).basis.orthonormalized().get_rotation_quaternion()
			var d := bs_q.inverse() * (q * (src_riposo_q[sorg_nome] as Quaternion).inverse()) * bs_q   # nel corpo
			if specchio:
				d = Quaternion(d.x, -d.y, -d.z, d.w)
			d = yaw * d
			glob[nome] = (bt_q * d * bt_q.inverse() * (_t_riposo_q[nome] as Quaternion)).normalized()
		var loc := {}
		for b in _t_nomi.size():
			var nome := _t_nomi[b]
			if not glob.has(nome):
				glob[nome] = _t_riposo_q[nome]   # ossa senza corrispondenza (la radice): restano come in posa a T
			var par := _t_padre[b]
			var qp: Quaternion = Quaternion.IDENTITY if par < 0 else glob[_t_nomi[par]]
			loc[nome] = (qp.inverse() * (glob[nome] as Quaternion)).normalized()
		var pb := _bs.inverse() * (g[sb_bacino] as Transform3D).origin
		# solo l'altezza: in orizzontale il bacino resta dove sta nella posa a T del nostro modello
		var pt := _bt * Vector3(_t_bacino.x, pb.y * k, _t_bacino.z)
		loc["@pos"] = _t_radice.affine_inverse() * pt
		pose.append(loc)
	if giro:
		pose = _chiudi_giro(pose)
	var anim := Animation.new()
	anim.length = (pose.size() - 1) * PASSO
	anim.step = PASSO
	anim.loop_mode = Animation.LOOP_LINEAR if giro else Animation.LOOP_NONE
	var tp := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(tp, NodePath("%s:pelvis" % _percorso_tracce))
	for i in pose.size():
		anim.position_track_insert_key(tp, i * PASSO, pose[i]["@pos"])
	for nome in _t_nomi:
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath("%s:%s" % [_percorso_tracce, nome]))
		var prev := Quaternion.IDENTITY
		for i in pose.size():
			var q: Quaternion = pose[i][nome]
			if i > 0 and prev.dot(q) < 0.0:   # stesso emisfero: niente giri lunghi interpolando
				q = -q
			anim.rotation_track_insert_key(tr, i * PASSO, q)
			prev = q
	anim.compress(8192, COMPRESSIONE_FPS, COMPRESSIONE_TOLLERANZA)
	return anim


static func _scambia(nome: String) -> String:
	if nome.ends_with("_l"):
		return nome.substr(0, nome.length() - 2) + "_r"
	if nome.ends_with("_r"):
		return nome.substr(0, nome.length() - 2) + "_l"
	return nome


# loop: gli ultimi GIRO_DISSOLVENZA secondi sfumano verso l'inizio, poi si tagliano (il loop riparte dal primo
# fotogramma senza scatti)
func _chiudi_giro(pose: Array) -> Array:
	var L := int(round(GIRO_DISSOLVENZA / PASSO))
	var n := pose.size()
	if n <= L * 2 + 2:
		return pose
	var out: Array = []
	var periodo := n - L
	for i in periodo + 1:
		if i < L:
			# inizio = fine sfumata nell'inizio vero
			var w := float(i) / L
			var a: Dictionary = pose[periodo + i] if periodo + i < n else pose[n - 1]
			var b: Dictionary = pose[i]
			var f := {}
			for k: String in b:
				if k == "@pos":
					f[k] = (a[k] as Vector3).lerp(b[k], w)
				else:
					f[k] = (a[k] as Quaternion).slerp(b[k], w)
			out.append(f)
		elif i < periodo:
			out.append(pose[i])
		else:
			out.append(out[0])   # ultimo fotogramma = primo: il loop si chiude senza salti
	return out
