# Righe del campo (scripts/righe_campo.gd) e tagli dell'erba (scripts/tagli_campo.gd): ci sono tutte le righe
# del regolamento con le misure del motore, la mesh sta dentro il campo, il taglio è fisso per squadra.
extends "test_base.gd"

const Righe := preload("res://scripts/righe_campo.gd")
const Tagli := preload("res://scripts/tagli_campo.gd")
const Gioco := preload("res://scripts/partita/gioco.gd")


func _conta(tipo: String) -> int:
	var n := 0
	for p: Dictionary in Righe.pezzi():
		if p.tipo == tipo:
			n += 1
	return n


func _ha_linea(a: Vector2, b: Vector2) -> bool:
	for p: Dictionary in Righe.pezzi():
		if p.tipo == "linea" and ((p.a.distance_to(a) < 0.01 and p.b.distance_to(b) < 0.01) or (p.a.distance_to(b) < 0.01 and p.b.distance_to(a) < 0.01)):
			return true
	return false


func _ha_punto(c: Vector2) -> bool:
	for p: Dictionary in Righe.pezzi():
		if p.tipo == "punto" and p.c.distance_to(c) < 0.01:
			return true
	return false


func test_ci_sono_tutte_le_righe() -> bool:
	# 4 bordi + metà campo + 2 × (3 lati area di rigore + 3 lati area piccola)
	eq(_conta("linea"), 4 + 1 + 12, "linee dritte")
	# cerchio di centrocampo + 2 lunette + 4 archi d'angolo
	eq(_conta("arco"), 1 + 2 + 4, "archi")
	# punto del centro + 2 dischetti
	eq(_conta("punto"), 3, "punti")
	check(_ha_linea(Vector2(-C.HW, 0.0), Vector2(C.HW, 0.0)), "metà campo")
	check(_ha_linea(Vector2(C.HW, -C.HL), Vector2(C.HW, C.HL)), "linea laterale")
	check(_ha_linea(Vector2(-C.BOX_W / 2.0, C.HL - C.BOX_D), Vector2(C.BOX_W / 2.0, C.HL - C.BOX_D)), "area di rigore")
	check(_ha_linea(Vector2(-C.SIX_W / 2.0, -C.HL + C.SIX_D), Vector2(C.SIX_W / 2.0, -C.HL + C.SIX_D)), "area piccola")
	check(_ha_punto(Vector2(0.0, C.HL - C.PEN_D)), "dischetto nord")
	check(_ha_punto(Vector2(0.0, -C.HL + C.PEN_D)), "dischetto sud")
	check(_ha_punto(Vector2.ZERO), "punto del centro")
	return done()


func test_lunette_fuori_dall_area_e_cerchio_giusto() -> bool:
	for p: Dictionary in Righe.pezzi():
		if p.tipo != "arco":
			continue
		var r: float = p.r
		for k in 9:
			var t: float = lerpf(p.da, p.a, k / 8.0)
			var q: Vector2 = p.c + Vector2(cos(t), sin(t)) * r
			check(absf(q.x) <= C.HW + 0.01 and absf(q.y) <= C.HL + 0.01, "arco fuori dal campo in %s" % q)
			if absf(p.c.y) > 1.0 and absf(p.c.x) < 1.0:   # lunetta: fuori dall'area di rigore
				check(absf(q.y) <= C.HL - C.BOX_D + 0.01, "lunetta dentro l'area in %s" % q)
		if p.c == Vector2.ZERO:
			near(r, C.CIRCLE, 1e-6, "raggio del cerchio di centrocampo")
	return done()


func test_mesh_piatta_poco_sopra_l_erba() -> bool:
	var m := Righe.mesh()
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	check(v.size() > 300 and v.size() % 3 == 0, "triangoli: %d vertici" % v.size())
	check(v.size() < 20000, "mesh leggera: %d vertici" % v.size())
	var ok := true
	for p in v:
		if absf(p.y - Righe.ALTEZZA) > 1e-5 or absf(p.x) > C.HW + 0.01 or absf(p.z) > C.HL + 0.01:
			ok = false
	check(ok, "tutti i vertici sul piano delle righe e dentro il campo")
	var custom: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	eq(custom.size(), v.size() * 4, "un CUSTOM0 (4 numeri) per vertice")
	note("righe: %d vertici" % v.size())
	return done()


func test_taglio_fisso_per_squadra_e_tutti_usati() -> bool:
	eq(Tagli.da_seme(12345), Tagli.da_seme(12345), "stesso seme, stesso taglio")
	var visti := {}
	for s in 400:
		var t := Tagli.da_seme(s * 7919 + 13)
		check(t >= 0 and t < Tagli.NOMI.size(), "taglio nei limiti")
		visti[t] = true
	eq(visti.size(), Tagli.NOMI.size(), "con tanti semi escono tutti i tagli")
	check(Tagli.da_seme(-5) >= 0 and Tagli.da_seme(4294967295) >= 0, "semi negativi o enormi")
	return done()


func test_nomi_e_riga_di_comando() -> bool:
	check(Tagli.NOMI.size() >= 8, "almeno 8 tagli")
	eq(Tagli.indice("cerchi"), 4, "cerchi")
	eq(Tagli.indice(" Quadrotti "), 3, "maiuscole e spazi")
	eq(Tagli.indice("2"), 2, "anche il numero")
	eq(Tagli.indice("prato"), -1, "nome sconosciuto")
	eq(Tagli.da_riga_comando(PackedStringArray(["--seme=3", "--campo=rombi"])), Tagli.indice("rombi"), "--campo")
	eq(Tagli.da_riga_comando(PackedStringArray(["--seme=3"])), -1, "senza --campo")
	return done()


func test_taglio_della_squadra_di_casa() -> bool:
	eq(Gioco.taglio_campo({"stadio_seme": 777}, 1), Tagli.da_seme(777), "campionato: lo stadio di casa")
	eq(Gioco.taglio_campo({"stadio_seme": 777}, 2), Gioco.taglio_campo({"stadio_seme": 777}, 99), "non dipende dalla partita")
	eq(Gioco.taglio_campo({}, 4242), Tagli.da_seme(4242), "amichevole: dal seme della partita")
	return done()
