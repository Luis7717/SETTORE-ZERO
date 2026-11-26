# Vestibilità della maglia (aderente / larga) per shaders/divisa.gdshader: per ogni vertice del corpo quanto è
# "in una valle" (tra i pettorali, gli addominali, sotto le scapole), misurato in posa di riposo.
# Si leviga la superficie (laplaciano, coi vertici doppi delle cuciture UV saldati insieme) e si guarda di quanto il
# punto levigato sta fuori dal vertice lungo la normale: > 0 nelle valli, 0 sulle gobbe.
# Lo shader lo usa in due modi: maglia larga = le valli si riempiono (la stoffa passa sopra i muscoli, niente corpo
# gonfiato in proporzione), maglia aderente = le valli si scuriscono un poco (la stoffa attillata mostra i muscoli).
# Scritto in CUSTOM2.x da scripts/giocatore.gd (_mesh_con_riposo), una volta sola per tutti i giocatori.
extends RefCounted

const PASSI := 10          # passate di levigatura
const LAMBDA := 0.6        # quanto ci si sposta verso la media dei vicini a ogni passata
const MAX_VALLE := 0.03    # m: oltre non si riempie (ascelle, inguine: lì la stoffa non arriva)
const SALDA := 10000.0     # 1/m: vertici più vicini di 0,1 mm sono lo stesso punto (cuciture UV)

## normali della superficie levigata, una per vertice (riempite da valli()): la stoffa della maglia non segue ogni
## muscolo. scripts/giocatore.gd le mette al posto delle tangenti della mesh (non usate: niente mappe di normali),
## così seguono le ossa come le normali vere e lo shader della divisa le mescola (LISCIA_*).
static var lisce := PackedVector3Array()


## profondità della valle (m, >= 0) per ogni vertice: vertici, normali e indici dei triangoli di una superficie
static func valli(vertici: PackedVector3Array, normali: PackedVector3Array, indici: PackedInt32Array) -> PackedFloat32Array:
	var n := vertici.size()
	var out := PackedFloat32Array()
	out.resize(n)
	if n == 0 or indici.size() < 3:
		return out
	# saldatura: id del punto per vertice
	var id_di := PackedInt32Array()
	id_di.resize(n)
	var mappa := {}
	var punti := PackedVector3Array()
	for i in n:
		var v := vertici[i]
		var chiave := Vector3i(roundi(v.x * SALDA), roundi(v.y * SALDA), roundi(v.z * SALDA))
		if not mappa.has(chiave):
			mappa[chiave] = punti.size()
			punti.append(v)
		id_di[i] = mappa[chiave]
	var m := punti.size()
	# vicini (lati dei triangoli) sui punti saldati
	var vicini: Array[PackedInt32Array] = []
	vicini.resize(m)
	for k in m:
		vicini[k] = PackedInt32Array()
	for t in range(0, indici.size() - 2, 3):
		var a := id_di[indici[t]]
		var b := id_di[indici[t + 1]]
		var c := id_di[indici[t + 2]]
		_lega(vicini, a, b)
		_lega(vicini, b, c)
		_lega(vicini, c, a)
	# levigatura
	var p := punti.duplicate()
	for _passo in PASSI:
		var q := p.duplicate()
		for k in m:
			var vk := vicini[k]
			if vk.is_empty():
				continue
			var media := Vector3.ZERO
			for j in vk:
				media += p[j]
			media /= vk.size()
			q[k] = p[k].lerp(media, LAMBDA)
		p = q
	# normali della superficie levigata (somma delle normali dei triangoli, pesate con l'area)
	var nl := PackedVector3Array()
	nl.resize(m)
	for t in range(0, indici.size() - 2, 3):
		var a := id_di[indici[t]]
		var b := id_di[indici[t + 1]]
		var c := id_di[indici[t + 2]]
		var fn := (p[b] - p[a]).cross(p[c] - p[a])
		nl[a] += fn
		nl[b] += fn
		nl[c] += fn
	lisce = PackedVector3Array()
	lisce.resize(n)
	for i in n:
		var k := id_di[i]
		var nr := normali[i] if i < normali.size() else Vector3.UP
		out[i] = clampf((p[k] - punti[k]).dot(nr), 0.0, MAX_VALLE)
		var l := nl[k].normalized()
		if l.dot(nr) < 0.0:   # il verso dei triangoli non conta: dalla parte della normale vera
			l = -l
		lisce[i] = l if l.length_squared() > 0.5 and l.dot(nr) > 0.3 else nr
	return out


static func _lega(vicini: Array[PackedInt32Array], a: int, b: int) -> void:
	if a == b:
		return
	if not vicini[a].has(b):
		vicini[a].append(b)
	if not vicini[b].has(a):
		vicini[b].append(a)
