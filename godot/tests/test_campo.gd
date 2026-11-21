# Righe del campo (scripts/righe_campo.gd) e tagli dell'erba (scripts/tagli_campo.gd): ci sono tutte le righe
# del regolamento con le misure del motore, la mesh sta dentro il campo, il taglio è fisso per squadra.
extends "test_base.gd"

const Righe := preload("res://scripts/righe_campo.gd")
const Tagli := preload("res://scripts/tagli_campo.gd")
const Gioco := preload("res://scripts/partita/gioco.gd")
const Campo := preload("res://scripts/campo.gd")


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


func test_manti_tutti_validi_e_fissi_per_squadra() -> bool:
	var visti := {}
	for seme in range(200):
		var m := Tagli.manto_da_seme(seme)
		check(m >= 0 and m < Tagli.MANTI.size(), "manto valido")
		visti[m] = true
	eq(visti.size(), Tagli.MANTI.size(), "tutti i manti escono")
	eq(Tagli.manto_da_seme(777), Tagli.manto_da_seme(777), "stesso seme, stesso manto")
	eq(Tagli.indice_manto("milano"), 1, "nome")
	var c := Tagli.colori_manto(1)
	check(c[0].g > c[1].g, "fascia chiara più chiara della scura")
	eq(Gioco.manto_campo({"stadio_seme": 5}, 1), Tagli.manto_da_seme(5), "stadio di casa")
	return done()


func test_taglio_diagonali() -> bool:
	eq(Tagli.indice("diagonali"), 8, "taglio diagonali")
	return done()


# distanza da un pezzo di riga come la calcola shaders/erba_ciuffi.gdshader (dist_righe), per provare il formato
func _dist_shader(r: Dictionary, p: Vector2) -> float:
	var a: Vector4 = r.a
	var b: Vector4 = r.b
	if b.w < 0.5:
		var pa := Vector2(a.x, a.y)
		var ab := Vector2(a.z, a.w) - pa
		var t := clampf((p - pa).dot(ab) / maxf(ab.dot(ab), 1e-6), 0.0, 1.0)
		return p.distance_to(pa + ab * t)
	if b.w < 1.5:
		var v := p - Vector2(a.x, a.y)
		return absf(v.length() - a.z) if v.dot(Vector2(b.x, b.y)) >= a.w * v.length() else 1e3
	return maxf(p.distance_to(Vector2(a.x, a.y)) - a.z + Righe.LARGHEZZA / 2.0, 0.0)


func _sulla_riga(p: Vector2) -> bool:
	for r: Dictionary in Campo.righe_per_ciuffi():
		if _dist_shader(r, p) < Righe.LARGHEZZA / 2.0:
			return true
	return false


func test_righe_dei_ciuffi_in_rilievo() -> bool:
	var r := Campo.righe_per_ciuffi()
	eq(r.size(), Righe.pezzi().size(), "un pezzo per ogni riga")
	check(_sulla_riga(Vector2(10.0, 0.0)), "metà campo")
	check(_sulla_riga(Vector2(C.CIRCLE, 0.0)), "cerchio di centrocampo")
	check(_sulla_riga(Vector2(0.0, C.HL - C.PEN_D)), "dischetto")
	check(_sulla_riga(Vector2(0.0, C.HL - C.PEN_D - C.CIRCLE)), "lunetta, fuori dall'area")
	check(not _sulla_riga(Vector2(0.0, C.HL - C.PEN_D + C.CIRCLE)), "la lunetta non continua dentro l'area")
	check(_sulla_riga(Vector2(C.HW, C.HL) + Vector2(-1.0, -1.0).normalized()), "arco d'angolo")
	check(not _sulla_riga(Vector2(C.HW, C.HL) + Vector2(1.0, 1.0).normalized()), "l'arco d'angolo non esce dal campo")
	check(not _sulla_riga(Vector2(5.0, 5.0)), "erba senza righe")
	return done()


func test_righe_vicine_ai_ciuffi() -> bool:
	var r := Campo.righe_per_ciuffi()
	var vuoto := Campo.righe_vicine(r, Vector2(0.0, 22.0), 10.0, 8)
	eq(vuoto.size(), 0, "tra cerchio e lunetta nessuna riga")
	var meta := Campo.righe_vicine(r, Vector2(10.0, 0.0), 20.0, 8)
	eq(meta.size(), 3, "metà campo, cerchio e punto del centro")
	for i in meta:
		var p: Dictionary = r[i]
		check(p.box.intersects(Rect2(Vector2(0.0, -10.0), Vector2(20.0, 20.0)), true), "solo pezzi nel quadrato")
	eq(Campo.righe_vicine(r, Vector2(0.0, C.HL - 8.0), 44.0, 8).size(), 8, "al massimo quanti ne regge lo shader")
	return done()
