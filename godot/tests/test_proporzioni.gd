# Proporzioni ritoccate del modello dei giocatori (scripts/partita/proporzioni.gd): i punti del modello originale
# sono quelli che il ritocco si aspetta, i ritocchi stanno in un intervallo ragionevole (spalle, braccia, mani,
# collo), le gambe e il centro degli occhi non si muovono, ossa e pelle seguono i vertici (in posa di riposo la
# pelle non deforma niente) e la mesh della divisa ha gli stessi vertici di prima, simmetrici.
extends "test_base.gd"

const P := preload("res://scripts/partita/proporzioni.gd")
const Giocatore := preload("res://scripts/giocatore.gd")
const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const MODELLO := "res://assets/models/athlete.glb"
const PUNTA_X := 0.9058        # punta delle dita del modello originale (mezza apertura delle braccia a T)


func _modello() -> Node3D:
	return (ResourceLoader.load(MODELLO, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as Node3D


func test_i_punti_del_modello_originale_sono_quelli_attesi() -> bool:
	var m := _modello()
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var spalla := sk.get_bone_global_rest(sk.find_bone("upperarm_l")).origin
	var polso := sk.get_bone_global_rest(sk.find_bone("hand_l")).origin
	near(spalla.x, P.SPALLA_X, 0.002, "spalla")
	near(polso.x, P.POLSO_X, 0.002, "polso")
	near(polso.y, P.BRACCIO_Y, 0.002, "altezza delle braccia a T")
	near(polso.z, P.BRACCIO_Z, 0.002, "profondità delle braccia a T")
	var mi := m.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var occhio := Giocatore._centro_occhio(mi.mesh as ArrayMesh)
	check(occhio.distance_to(P.OCCHIO) < 0.004, "centro dell'occhio %s" % occhio)
	near((mi.mesh as ArrayMesh).get_aabb().end.x, PUNTA_X, 0.002, "punta delle dita")
	m.free()
	return done()


func test_ritocchi_in_un_intervallo_ragionevole() -> bool:
	check(P.ATTIVE, "proporzioni attive")
	var spalla := P.deforma(Vector3(P.SPALLA_X, P.BRACCIO_Y, P.BRACCIO_Z))
	var polso := P.deforma(Vector3(P.POLSO_X, P.BRACCIO_Y, P.BRACCIO_Z))
	var punta := P.deforma(Vector3(PUNTA_X, P.BRACCIO_Y, P.BRACCIO_Z))
	var k_spalle := spalla.x / P.SPALLA_X
	var k_braccio := (polso.x - spalla.x) / (P.POLSO_X - P.SPALLA_X)
	var k_mano := (punta.x - polso.x) / (PUNTA_X - P.POLSO_X)
	note("spalle ×%.3f, braccio ×%.3f, mano ×%.3f, spalle su %.3f m" % [k_spalle, k_braccio, k_mano, spalla.y - P.BRACCIO_Y])
	check(k_spalle > 1.03 and k_spalle < 1.12, "spalle un po' più larghe (×%.3f)" % k_spalle)
	check(k_braccio > 0.9 and k_braccio <= 1.0, "braccio un po' più corto (×%.3f)" % k_braccio)
	check(k_mano > 0.75 and k_mano < 0.95, "mano più piccola (×%.3f)" % k_mano)
	check(spalla.y - P.BRACCIO_Y >= 0.0 and spalla.y - P.BRACCIO_Y < 0.03, "spalle appena più alte")
	near(polso.y, spalla.y, 1e-3, "il braccio a T resta dritto")
	# il polso arriva dove arrivava (le pose con la IK hanno i polsi misurati in metri del modello)
	check(absf(polso.x - P.POLSO_X) < 0.02, "polso a T dove stava (%.3f contro %.3f)" % [polso.x, P.POLSO_X])
	# dita meno aperte: un punto davanti alle nocche rientra verso l'asse delle dita
	var dito := P.deforma(Vector3(0.85, P.BRACCIO_Y, P.DITA_Z + 0.05))
	check(dito.z - P.DITA_Z < 0.04 and dito.z - P.DITA_Z > 0.02, "dita meno aperte (%.3f)" % (dito.z - P.DITA_Z))
	# collo: la testa scende tutta insieme
	var cima := P.deforma(Vector3(0, 1.81, 0))
	var nuca := P.deforma(Vector3(0.05, 1.7, -0.09))
	var giu := 1.81 - cima.y
	check(giu > 0.01 and giu < 0.04, "testa più in basso di %.3f m" % giu)
	near(1.7 - nuca.y, giu, 1e-5, "la testa non cambia forma")
	near(P.deforma(P.OCCHIO).x, P.OCCHIO.x, 1e-6, "il centro degli occhi resta dov'è (sopracciglia e maschere del viso)")
	near(P.deforma(P.OCCHIO).y, P.OCCHIO.y - giu, 1e-6, "e scende con la testa")
	return done()


func test_gambe_e_piedi_non_si_toccano_e_tutto_resta_simmetrico() -> bool:
	for p: Vector3 in [Vector3(0.11, 0.09, -0.08), Vector3(0.19, 0.4, -0.1), Vector3(0.11, 0.54, 0.02), Vector3(0.15, 0.7, 0.05), Vector3(0.1, 0.97, 0.0)]:
		eq(P.deforma(p), p, "punto delle gambe %s" % p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 300:
		var p := Vector3(rng.randf_range(0.0, 0.92), rng.randf_range(0.0, 1.82), rng.randf_range(-0.17, 0.13))
		var a := P.deforma(p)
		var b := P.deforma(Vector3(-p.x, p.y, p.z))
		check(a.distance_to(Vector3(-b.x, b.y, b.z)) < 1e-6, "simmetrico in %s" % p)
		check(a.distance_to(p) < 0.09, "nessun punto si sposta di molto (%s → %s)" % [p, a])
	return done()


func test_ossa_e_pelle_seguono_i_vertici() -> bool:
	var m := _modello()
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mi := m.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var prima: Array[Transform3D] = []
	for b in sk.get_bone_count():
		prima.append(sk.get_bone_global_rest(b))
	P.applica(sk, mi.skin)
	for b in sk.get_bone_count():
		var g := sk.get_bone_global_rest(b)
		var atteso := P.deforma(prima[b].origin)
		check(g.origin.distance_to(atteso) < 1e-5, "%s: %s contro %s" % [sk.get_bone_name(b), g.origin, atteso])
		check(g.basis.is_equal_approx(prima[b].basis), "%s: verso uguale" % sk.get_bone_name(b))
		check(sk.get_bone_pose_position(b).is_equal_approx(sk.get_bone_rest(b).origin), "%s: posa = riposo" % sk.get_bone_name(b))
	for n: String in ["thigh_l", "calf_r", "foot_l", "ball_r", "pelvis", "spine_01"]:
		var b := sk.find_bone(n)
		check(sk.get_bone_global_rest(b).origin.is_equal_approx(prima[b].origin), "%s non si sposta" % n)
	# in posa di riposo la pelle lascia ogni vertice dov'è: riposo × legame = identità
	var pelle := mi.skin
	for i in pelle.get_bind_count():
		var nome := String(pelle.get_bind_name(i))
		var b := sk.find_bone(nome) if nome != "" else pelle.get_bind_bone(i)
		var t := sk.get_bone_global_rest(b) * pelle.get_bind_pose(i)
		check(t.is_equal_approx(Transform3D.IDENTITY), "legame di %s" % sk.get_bone_name(b))
	# una seconda volta non cambia niente
	var g1 := sk.get_bone_global_rest(sk.find_bone("hand_l"))
	var l1 := pelle.get_bind_pose(pelle.get_bind_count() - 1)
	P.applica(sk, pelle)
	check(sk.get_bone_global_rest(sk.find_bone("hand_l")).is_equal_approx(g1), "ossa: due volte = una")
	check(pelle.get_bind_pose(pelle.get_bind_count() - 1).is_equal_approx(l1), "pelle: due volte = una")
	m.free()
	return done()


func test_la_mesh_della_divisa_ha_i_vertici_di_prima_spostati() -> bool:
	var f := Figura.new()
	f.prepara({"maglia": Color.RED}, {"pelle": Color.TAN}, 0.0, TV.avviso())
	var m := _modello()
	var mi := m.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var orig: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var arr := Giocatore._mesh_divisa.surface_get_arrays(0)
	var nuovi: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	eq(nuovi.size(), orig.size(), "stessi vertici (nessun poligono in più)")
	var peggio := 0.0
	for i in orig.size():
		peggio = maxf(peggio, nuovi[i].distance_to(P.deforma(orig[i])))
	check(peggio < 1e-4, "ogni vertice = deforma(originale) (scarto %.6f)" % peggio)
	var a_prima := (mi.mesh as ArrayMesh).get_aabb()
	var a := Giocatore._mesh_divisa.get_aabb()
	check(a.size.x < a_prima.size.x - 0.02, "apertura delle braccia più piccola (%.3f contro %.3f)" % [a.size.x, a_prima.size.x])
	near(a.position.y, a_prima.position.y, 1e-5, "piedi alla stessa altezza")
	# normali levigate al posto delle tangenti: una per vertice, lunghe 1, dalla parte della normale vera
	var tang: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
	var nor: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	eq(tang.size(), nuovi.size() * 4, "una normale levigata per vertice")
	var storte := 0
	for i in nuovi.size():
		var l := Vector3(tang[i * 4], tang[i * 4 + 1], tang[i * 4 + 2])
		if absf(l.length() - 1.0) > 0.02 or l.dot(nor[i]) < 0.25:
			storte += 1
	eq(storte, 0, "normali levigate giuste")
	m.free()
	f.free()
	return done()
