# Capelli e barbe come mesh a parte (scripts/partita/capelli.gd, barbe.gd): una mesh per ogni taglio e barba degli
# elenchi di Aspetto (stessi id dei salvataggi), pochi triangoli, appoggiata fuori dalla pelle, cambiata dalla figura
# quando cambia l'aspetto.
extends "test_base.gd"

const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Capelli := preload("res://scripts/partita/capelli.gd")
const Barbe := preload("res://scripts/partita/barbe.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const KIT := {"maglia": Color.RED, "calzoncini": Color.WHITE, "calzettoni": Color.RED, "bordino": Color.WHITE}
const MAX_TRIANGOLI := 2800     # capelli + barba di un giocatore (vicino; da lontano i livelli di dettaglio ne tolgono)


func nuova(look: Dictionary = {}) -> Node3D:
	var f := Figura.new()
	f.prepara(KIT, Asp.parametri_figura(look), 0.0, TV.avviso())
	return f


func triangoli(m: ArrayMesh) -> int:
	return 0 if m == null else (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


func test_un_tipo_per_ogni_taglio_e_barba_degli_elenchi() -> bool:
	var f := nuova()
	eq(Capelli.N_TAGLI, Asp.HAIR_STYLES.size(), "tagli: stessi id dell'elenco di Aspetto")
	eq(Barbe.SPESSORE.size(), Asp.BEARDS.size(), "barbe: stessi id dell'elenco di Aspetto")
	eq(Capelli.LINEA.size(), Capelli.N_TAGLI, "attaccatura per ogni taglio")
	f.free()
	return done()


func test_calvo_e_rasato_senza_barba_non_hanno_mesh_gli_altri_si() -> bool:
	var f := nuova()
	for h in Capelli.N_TAGLI:
		for b in Asp.BEARDS.size():
			var m := Capelli.mesh_per(h, b)
			var vuota := h <= 1 and b <= 1
			check((m == null) == vuota, "taglio %d barba %d: mesh %s" % [h, b, "assente" if m == null else "presente"])
			check(triangoli(m) <= MAX_TRIANGOLI, "taglio %d barba %d: %d triangoli" % [h, b, triangoli(m)])
	f.free()
	return done()


func test_la_mesh_si_costruisce_una_volta_e_si_condivide() -> bool:
	var f := nuova()
	check(Capelli.mesh_per(9, 6) == Capelli.mesh_per(9, 6), "stessa coppia, stessa mesh")
	check(Capelli.mesh_per(9, 6) != Capelli.mesh_per(9, 5), "barba diversa, mesh diversa")
	check(Capelli.mesh_per(99, -3) == Capelli.mesh_per(16, 0), "valori fuori elenco: riportati dentro")
	f.free()
	return done()


func test_i_capelli_stanno_fuori_dalla_pelle() -> bool:
	var f := nuova()
	for h in range(2, Capelli.N_TAGLI):
		var m := Capelli.mesh_per(h, 0)
		var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var dentro := 0
		for p in v:
			var ae := Capelli.az_el(p)
			if ae.y > -60.0 and p.distance_to(Capelli._c) < Capelli.raggio(ae.x, ae.y, false) - 0.002:
				dentro += 1
		check(dentro <= v.size() / 50, "taglio %d: %d vertici su %d sotto la pelle" % [h, dentro, v.size()])
	f.free()
	return done()


func test_le_barbe_stanno_sul_viso_sotto_gli_occhi() -> bool:
	var f := nuova()
	var occhi: Vector3 = Capelli._c + Vector3(0, 0, 0.075)
	for b in range(2, 7):
		var a: Dictionary = Barbe.parte(b)
		check(not a.is_empty(), "barba %d: c'è" % b)
		var alto := -INF
		var avanti := INF
		for p: Vector3 in a.v:
			alto = maxf(alto, p.y)
			avanti = minf(avanti, p.z)
		check(alto < occhi.y + 0.02, "barba %d: non sale sopra gli occhi (%.3f)" % [b, alto - occhi.y])
		check(avanti > Capelli._c.z - 0.06, "barba %d: non va dietro le orecchie (%.3f)" % [b, avanti])
	check(Barbe.parte(1).is_empty(), "l'ombra è solo dipinta")
	f.free()
	return done()


func test_la_figura_cambia_capelli_quando_cambia_aspetto() -> bool:
	var f := nuova({"hair": 2, "beard": 0})
	var cap: MeshInstance3D = f.get("_capelli")
	check(cap.mesh == Capelli.mesh_per(2, 0), "taglio corto all'inizio")
	f.metti_aspetto(Asp.parametri_figura({"hair": 9, "beard": 6, "hairColor": 5}))
	check(cap.mesh == Capelli.mesh_per(9, 6), "afro con barba piena")
	eq(cap.get_instance_shader_parameter(&"colore"), Color(Asp.HAIR_COLORS[5][1]), "colore dei capelli per istanza")
	f.metti_aspetto(Asp.parametri_figura({"hair": 0, "beard": 0}))
	check(not cap.visible, "calvo senza barba: niente mesh")
	f.metti_aspetto({"pelle": Color.TAN, "capelli": Color.BLACK})
	check(not cap.visible, "senza stile2 resta il taglio di prima")
	f.free()
	return done()
