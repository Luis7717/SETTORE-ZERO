# Proporzioni del modello dei giocatori (Luis 2026-11-26, "rifiniti un attimo"): athlete.glb resta com'è, e quando si
# carica si ritocca in posa di riposo (a T), una volta per tutti i giocatori:
#   - braccia un po' più corte, mani più piccole e con le dita meno aperte;
#   - spalle più larghe; collo più corto (la testa scende, non cambia forma: viso, sopracciglia e capelli uguali);
#   - sedere e fianchi meno sporgenti dietro.
# Si spostano insieme i vertici (deforma, usata da scripts/giocatore.gd quando prepara la mesh della divisa) e le
# ossa (applica: posa di riposo dello scheletro e pose di legame della pelle), così clip, IK e shader della divisa
# (che misurano tutto dalle ossa) seguono da soli. Le gambe non si toccano: i piedi appoggiano come prima.
# Per tornare al modello originale basta ATTIVE = false.
# Misure in metri del modello (alto 1,82; +X = sinistra del giocatore, +Y = su, −Z = dietro... il viso guarda +Z).
extends RefCounted

const ATTIVE := true

# ---- punti del modello originale (athlete.glb; li ricontrolla tests/test_proporzioni.gd)
const SPALLA_X := 0.19         # articolazione della spalla (upperarm)
const POLSO_X := 0.6845        # polso (hand)
const BRACCIO_Y := 1.4555      # altezza delle braccia a T
const BRACCIO_Z := -0.0654
const CENTRO_X := 0.06         # fin qui (collo, sterno) le spalle non si allargano

# ---- ritocchi
const SPALLE_K := 1.08        # la spalla va a SPALLA_X × questo
const SPALLE_Y0 := 1.2         # da qui in su il busto si allarga piano...
const SPALLE_Y1 := 1.36        # ... e da qui del tutto
const SPALLE_SU := 0.015       # m: spalle più squadrate (salgono loro e le braccia: il collo sembra meno lungo)
const SPALLE_SU_X := [0.07, 0.17]   # dal collo (niente) alla spalla (tutto)
const SPALLE_SU_Y := [1.34, 1.46]   # sul busto solo in alto; oltre la spalla (braccio) a ogni altezza
const BRACCIA_K := 0.97        # lunghezza dalla spalla al polso
const MANO_K := 0.8           # mano più stretta e più sottile attorno al polso...
const MANO_LUNGA_K := 0.84    # ... e più corta (le esultanze sono misurate sulla punta delle dita: mosse/esultanza.gd)
const MANO_SFUMA := 0.03       # m: attorno al polso la mano si restringe piano (niente scalino)
const DITA_DA := 0.075         # m oltre il polso: da qui le dita...
const DITA_K := 0.72           # ... si chiudono (meno aperte a ventaglio, davanti-dietro)
const DITA_Z := -0.058         # asse delle dita
const COLLO_GIU := 0.03       # m: di quanto scende la testa
const COLLO_Y0 := 1.5          # il collo si accorcia tra queste due altezze
const COLLO_Y1 := 1.585
const COLLO_X0 := 0.085        # solo la colonna del collo e della testa (le spalle restano)
const COLLO_X1 := 0.15
const SEDERE_K := 0.8          # quanto resta della sporgenza dietro
const SEDERE_Z := -0.07        # oltre questa profondità (dietro)
const SEDERE_Y := [0.74, 0.88, 1.02, 1.12]   # fascia dei fianchi: sale, piena, scende
# ---- viso (sopracciglia e attaccatura dei capelli non si toccano: sono dipinte e misurate dal centro degli occhi)
const OCCHIO := Vector3(0.034, 1.698, 0.07)   # centro dell'occhio sinistro del modello originale
const OCCHI_K := 0.2           # occhi più grandi: l'apertura si allarga di tanto attorno al centro...
const OCCHI_R0 := 0.012        # ... piena fino a qui (m dal centro), poi sfuma...
const OCCHI_R1 := 0.026        # ... fino a qui
const NASO_Z := 0.092          # naso meno sporgente: oltre questa profondità (davanti)...
const NASO_K := 0.78           # ... resta tanto
const NASO_X := 0.03
const NASO_Y := [1.6, 1.625, 1.69, 1.71]
const MASCELLA_K := 0.07       # mascella e mento più stretti (viso meno quadrato)
const MASCELLA_Y := [1.5, 1.56, 1.6, 1.675]   # sale dal collo, piena sotto la bocca, finisce agli zigomi


## punto del modello in posa di riposo → lo stesso punto con le proporzioni nuove
static func deforma(p: Vector3) -> Vector3:
	if not ATTIVE:
		return p
	var s := 1.0 if p.x >= 0.0 else -1.0
	var ax := absf(p.x)
	var q := p
	if p.y > MASCELLA_Y[0] and ax < 0.12:
		# mascella più stretta
		var wm := smoothstep(MASCELLA_Y[0], MASCELLA_Y[1], p.y) * (1.0 - smoothstep(MASCELLA_Y[2], MASCELLA_Y[3], p.y))
		q.x *= 1.0 - MASCELLA_K * wm
		if p.z > 0.03:
			# occhi più grandi
			var e := Vector2(ax - OCCHIO.x, p.y - OCCHIO.y)
			var r := e.length()
			if r < OCCHI_R1:
				var k := 1.0 + OCCHI_K * (1.0 - smoothstep(OCCHI_R0, OCCHI_R1, r))
				q.x = s * (OCCHIO.x + e.x * k)
				q.y = OCCHIO.y + e.y * k
			# naso meno sporgente
			if p.z > NASO_Z and ax < NASO_X:
				var wz := smoothstep(NASO_Y[0], NASO_Y[1], p.y) * (1.0 - smoothstep(NASO_Y[2], NASO_Y[3], p.y))
				q.z = NASO_Z + (p.z - NASO_Z) * lerpf(1.0, NASO_K, wz)
	# collo più corto: testa e collo scendono
	var wn := 1.0 - smoothstep(COLLO_X0, COLLO_X1, ax)
	q.y -= COLLO_GIU * smoothstep(COLLO_Y0, COLLO_Y1, p.y) * wn
	# spalle più larghe, braccia più corte, mani più piccole (solo dal petto in su)
	var wy := smoothstep(SPALLE_Y0, SPALLE_Y1, p.y)
	if wy > 0.0 and ax > CENTRO_X:
		var nx := ax
		var spalla := SPALLA_X * SPALLE_K
		var polso := spalla + (POLSO_X - SPALLA_X) * BRACCIA_K
		if ax <= SPALLA_X:
			nx = CENTRO_X + (ax - CENTRO_X) * (spalla - CENTRO_X) / (SPALLA_X - CENTRO_X)
		elif ax <= POLSO_X:
			nx = spalla + (ax - SPALLA_X) * BRACCIA_K
		else:
			nx = polso + (ax - POLSO_X) * MANO_LUNGA_K
		q.x = s * lerpf(ax, nx, wy)
		var km := lerpf(1.0, MANO_K, smoothstep(POLSO_X - MANO_SFUMA, POLSO_X + MANO_SFUMA, ax))
		if km < 1.0:
			q.y = BRACCIO_Y + (q.y - BRACCIO_Y) * km
			q.z = BRACCIO_Z + (q.z - BRACCIO_Z) * km
			var kd := lerpf(1.0, DITA_K, smoothstep(POLSO_X + DITA_DA, POLSO_X + DITA_DA + 0.05, ax))
			q.z = DITA_Z + (q.z - DITA_Z) * kd
		var su := smoothstep(SPALLE_SU_X[0], SPALLE_SU_X[1], ax)
		su *= lerpf(smoothstep(SPALLE_SU_Y[0], SPALLE_SU_Y[1], p.y), 1.0, smoothstep(SPALLA_X - 0.02, SPALLA_X + 0.03, ax))
		q.y += SPALLE_SU * su
	# sedere meno sporgente
	if p.z < SEDERE_Z:
		var wf := smoothstep(SEDERE_Y[0], SEDERE_Y[1], p.y) * (1.0 - smoothstep(SEDERE_Y[2], SEDERE_Y[3], p.y))
		q.z = SEDERE_Z + (p.z - SEDERE_Z) * lerpf(1.0, SEDERE_K, wf)
	return q


## sposta le ossa di uno scheletro appena creato dal modello (posa di riposo) e, la prima volta, le pose di legame
## della pelle (condivisa da tutti i giocatori). Chiamarla due volte sullo stesso scheletro non cambia niente.
static func applica(sk: Skeleton3D, pelle: Skin) -> void:
	if not ATTIVE or sk.has_meta(&"proporzioni"):
		return
	sk.set_meta(&"proporzioni", true)
	var n := sk.get_bone_count()
	var nuovi: Array[Transform3D] = []
	var sposta := {}               # nome dell'osso → di quanto si sposta
	for b in n:
		var g := sk.get_bone_global_rest(b)
		var o := deforma(g.origin)
		sposta[sk.get_bone_name(b)] = o - g.origin
		nuovi.append(Transform3D(g.basis, o))
	for b in n:                    # i padri vengono prima dei figli
		var par := sk.get_bone_parent(b)
		var loc := nuovi[b] if par < 0 else nuovi[par].affine_inverse() * nuovi[b]
		sk.set_bone_rest(b, loc)
	sk.reset_bone_poses()
	if pelle == null or pelle.has_meta(&"proporzioni"):
		return
	pelle.set_meta(&"proporzioni", true)
	for i in pelle.get_bind_count():
		var nome := String(pelle.get_bind_name(i))
		if nome.is_empty() and pelle.get_bind_bone(i) >= 0:
			nome = sk.get_bone_name(pelle.get_bind_bone(i))
		var d: Vector3 = sposta.get(nome, Vector3.ZERO)
		if d != Vector3.ZERO:
			pelle.set_bind_pose(i, pelle.get_bind_pose(i) * Transform3D(Basis.IDENTITY, -d))
