# Capelli come mesh a parte (scripts/partita/capelli.gd, porting di src/hair3d.js), barbe, sopracciglia e occhi
# dipinti dallo shader della divisa: un tipo per ogni id di Aspetto (stessi id dei salvataggi), pochi triangoli,
# capelli fuori dalla pelle, mesh condivise, e la figura che cambia davvero quando cambia l'aspetto.
extends "test_base.gd"

const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Capelli := preload("res://scripts/partita/capelli.gd")
const Viso := preload("res://scripts/partita/viso.gd")
const Giocatore := preload("res://scripts/giocatore.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const KIT := {"maglia": Color.RED, "calzoncini": Color.WHITE, "calzettoni": Color.RED, "bordino": Color.WHITE}
const MAX_TRIANGOLI := 1800     # capelli di un giocatore


func nuova(look: Dictionary = {}) -> Node3D:
	var f := Figura.new()
	f.prepara(KIT, Asp.parametri_figura(look), 0.0, TV.avviso())
	return f


func triangoli(m: ArrayMesh) -> int:
	return 0 if m == null else (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


func test_un_tipo_per_ogni_taglio_degli_elenchi() -> bool:
	var f := nuova()
	eq(Capelli.N_TAGLI, Asp.HAIR_STYLES.size(), "tagli: stessi id dell'elenco di Aspetto")
	eq(Capelli.HAIR.size(), Capelli.N_TAGLI, "dati per ogni taglio")
	eq(Asp.BEARDS.size(), 7, "barbe: 7 come nel web (maschere 1..6 in viso_maschere.png)")
	f.free()
	return done()


func test_calvo_e_rasato_senza_mesh_gli_altri_con_pochi_triangoli() -> bool:
	var f := nuova()
	for h in Capelli.N_TAGLI:
		var m := Capelli.mesh_per(h)
		check((m == null) == (h <= 1), "taglio %d: mesh %s" % [h, "assente" if m == null else "presente"])
		check(triangoli(m) <= MAX_TRIANGOLI, "taglio %d: %d triangoli" % [h, triangoli(m)])
	f.free()
	return done()


func test_la_mesh_si_costruisce_una_volta_e_si_condivide() -> bool:
	var f := nuova()
	check(Capelli.mesh_per(9) == Capelli.mesh_per(9), "stesso taglio, stessa mesh")
	check(Capelli.mesh_per(9) != Capelli.mesh_per(10), "taglio diverso, mesh diversa")
	check(Capelli.mesh_per(99) == Capelli.mesh_per(16), "valori fuori elenco: riportati dentro")
	var g := nuova({"hair": 9})
	check((f.get("_capelli") as MeshInstance3D).material_override == (g.get("_capelli") as MeshInstance3D).material_override, "un materiale per tutti")
	f.free()
	g.free()
	return done()


func test_i_capelli_stanno_fuori_dalla_pelle() -> bool:
	var f := nuova()
	for h in range(2, Capelli.N_TAGLI):
		var pc := Capelli.pezzi(h)
		var dentro := 0
		var n := 0
		for i in pc.pos.size():
			var uv: Vector2 = pc.uv[i]
			# la calotta lontano dal bordo (il bordo e il risvolto entrano apposta sotto la base)
			if uv.x > 0.8 or uv.y > 0.6:
				continue
			n += 1
			var p: Vector3 = pc.pos[i]
			if p.length() < Capelli.base(p) / 1.015 - 0.01:
				dentro += 1
		check(n > 0 and dentro <= n / 50, "taglio %d: %d vertici su %d sotto la testa" % [h, dentro, n])
	f.free()
	return done()


func test_misure_del_viso_sensate() -> bool:
	var f := nuova()
	var d := Viso.dati
	var occhio: Vector4 = d.occhio
	check(d.mento < occhio.y - 0.08 and d.mento > occhio.y - 0.16, "mento sotto gli occhi (%.3f)" % [occhio.y - d.mento])
	var fin: Vector4 = d.occhio_finestra
	check(fin.z > 6.0 and fin.z < 25.0 and fin.w >= 2.0 and fin.w < 10.0, "finestra dell'occhio in mm: %s" % fin)
	check(Capelli.testa.R > 0.06 and Capelli.testa.R < 0.14, "raggio della testa %.3f" % Capelli.testa.R)
	f.free()
	return done()


func test_testa_e_collo_dalle_ossa_niente_maglia_sotto_il_mento() -> bool:
	var f := nuova()
	var a := Giocatore._mesh_divisa.surface_get_arrays(0)
	var c0: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var c1: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM1]
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var mento: float = Viso.dati.mento
	var testa := 0
	var sotto := 0
	var buoni := 0
	for i in v.size():
		if c0[i * 4 + 3] > 0.5:
			testa += 1
		# sotto il mento, davanti, vicino alla linea di mezzo: testa o collo (pelle), mai busto
		if absf(v[i].x) < 0.02 and v[i].y < mento and v[i].y > mento - 0.03 and v[i].z > 0.0:
			sotto += 1
			if c0[i * 4 + 3] > 0.5 or c1[i * 4 + 3] > 0.5:
				buoni += 1
	check(testa > 100, "vertici della testa: %d" % testa)
	check(sotto > 0 and buoni == sotto, "sotto il mento %d vertici, testa o collo %d" % [sotto, buoni])
	f.free()
	return done()


func test_la_figura_cambia_capelli_barba_e_occhi_quando_cambia_aspetto() -> bool:
	var f := nuova({"hair": 2, "beard": 0, "eyes": 0, "eyeColor": 0})
	var cap: MeshInstance3D = f.get("_capelli")
	var corpo: MeshInstance3D = f.get("_mesh")
	check(cap.mesh == Capelli.mesh_per(2), "taglio corto all'inizio")
	f.metti_aspetto(Asp.parametri_figura({"hair": 9, "beard": 6, "hairColor": 5, "eyes": 3, "eyeColor": 4}))
	check(cap.mesh == Capelli.mesh_per(9), "afro")
	eq(cap.get_instance_shader_parameter(&"colore"), Color(Asp.HAIR_COLORS[5][1]), "colore dei capelli per istanza")
	var s2: Vector4 = corpo.get_instance_shader_parameter(&"stile2")
	eq(int(s2.y), 6, "barba piena nello shader della divisa")
	eq(int(s2.x), 9, "taglio nello shader (cute)")
	eq(corpo.get_instance_shader_parameter(&"occhi_forma"), 3.0, "forma degli occhi nello shader")
	eq(corpo.get_instance_shader_parameter(&"iride"), Color(Asp.EYE_COLORS[4][1]), "colore degli occhi nello shader")
	f.metti_aspetto(Asp.parametri_figura({"hair": 0, "beard": 2, "eyes": 5}))
	check(not cap.visible, "calvo: niente mesh")
	eq(int((corpo.get_instance_shader_parameter(&"stile2") as Vector4).y), 2, "pizzetto anche da calvo")
	eq(corpo.get_instance_shader_parameter(&"occhi_forma"), 5.0, "occhi assonnati")
	f.metti_aspetto({"pelle": Color.TAN, "capelli": Color.BLACK})
	check(not cap.visible, "senza stile2 resta il taglio di prima")
	f.free()
	return done()


func test_shader_della_divisa_ha_maschere_e_misure() -> bool:
	var f := nuova()
	var mat: ShaderMaterial = Giocatore._materiale
	check(mat.get_shader_parameter("viso_maschere") is Texture2D, "maschere di barbe, sopracciglia e labbra")
	var tex: Texture2D = mat.get_shader_parameter("viso_maschere")
	eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(960, 520), "maschere: 4 × 2 celle della zona viso del web")
	eq(mat.get_shader_parameter("occhio_finestra"), Viso.dati.occhio_finestra, "finestra degli occhi nello shader")
	eq(mat.get_shader_parameter("cap_c"), Capelli.testa.c, "riferimento dei capelli nello shader (cute)")
	# la barba k sta nella cella k − 1 (canale rosso): ogni barba ha la sua maschera, diversa dalle altre
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var somme: Array = []
	for k in 6:
		var s := 0.0
		for y in range(0, 260, 4):
			for x in range(0, 240, 4):
				s += img.get_pixel((k % 4) * 240 + x, (k / 4) * 260 + y).r
		somme.append(s)
		check(s > 1.0, "barba %d: maschera non vuota" % (k + 1))
	for k in range(1, 6):
		check(absf(somme[k] - somme[k - 1]) > 0.5, "barba %d diversa dalla %d" % [k + 1, k])
	f.free()
	return done()


# barba visibile (2026-11-22, Luis: "in alcuni casi non si vede proprio"): il colore della barba si stacca sempre dalla
# pelle, per ogni pelle, colore dei capelli e colore scelto della barba
func test_la_barba_si_stacca_sempre_dalla_pelle() -> bool:
	var peggio := 1.0
	var dove := ""
	for s in Asp.SKINS.size():
		for h in Asp.HAIR_COLORS.size():
			for b in Asp.BEARD_COLORS.size():
				var p := Asp.parametri_figura({"skin": s, "hairColor": h, "beard": 6, "beardColor": b})
				var d := absf(Asp.luminanza(p.barba) - Asp.luminanza(p.pelle))
				if d < peggio:
					peggio = d
					dove = "pelle %d, capelli %d, barba %d" % [s, h, b]
	check(peggio >= 0.1, "stacco minimo barba-pelle %.3f (%s)" % [peggio, dove])
	return done()


# "pixel del viso" senza grafica: per ogni barba 1..6 la maschera, letta nei punti del viso veri (vertici della testa
# proiettati come fa lo shader), copre una parte del viso; per ogni pelle e colore dei capelli il cambio di colore che
# ne viene (copertura × stacco) non è mai trascurabile. Corta più rada e meno estesa della piena.
func test_ogni_barba_cambia_i_pixel_del_viso() -> bool:
	var f := nuova()
	var a := Giocatore._mesh_divisa.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var c0: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var pr: Vector4 = Viso.dati.proiezione
	var img: Image = (Giocatore._materiale.get_shader_parameter("viso_maschere") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var cop: Array = []
	for b in range(1, 7):
		var s := 0.0
		var n := 0
		for i in v.size():
			if c0[i * 4 + 3] < 0.5 or v[i].z < Viso.dati.occhio.z - 0.04:
				continue   # solo la testa, davanti
			var uv := Vector2(320.0 + (v[i].x - pr.x) * pr.z, 222.0 + (pr.y - v[i].y) * pr.w) - Vector2(200, 150)
			if uv.x < 0 or uv.y < 0 or uv.x >= 240 or uv.y >= 260:
				continue
			n += 1
			s += img.get_pixel(((b - 1) % 4) * 240 + int(uv.x), ((b - 1) / 4) * 260 + int(uv.y)).r
		cop.append(s / maxf(1.0, n))
	for b in 6:
		check(cop[b] > 0.01, "barba %d (%s): copre il %.1f%% del viso" % [b + 1, Asp.BEARDS[b + 1], cop[b] * 100.0])
	check(cop[5] > cop[4] * 1.3, "barba piena più estesa della corta (%.3f contro %.3f)" % [cop[5], cop[4]])
	for s in Asp.SKINS.size():
		for h in Asp.HAIR_COLORS.size():
			var p := Asp.parametri_figura({"skin": s, "hairColor": h})
			var stacco := absf(Asp.luminanza(p.barba) - Asp.luminanza(p.pelle))
			for b in 6:
				if cop[b] * stacco < 0.001:
					check(false, "barba %d invisibile con pelle %d e capelli %d" % [b + 1, s, h])
	f.free()
	return done()


func test_corta_piu_rada_della_piena_nello_shader() -> bool:
	var src: String = (load("res://shaders/divisa.gdshader") as Shader).code
	var i := src.find("const vec2 BARBA_PELO[6]")
	check(i >= 0, "tabella dei peli delle barbe nello shader")
	var riga := src.substr(i, src.find(";", i) - i)
	var nums: Array = []
	var re := RegEx.create_from_string(r"vec2\(([0-9.]+), ([0-9.]+)\)")
	for m in re.search_all(riga):
		nums.append(Vector2(float(m.get_string(1)), float(m.get_string(2))))
	eq(nums.size(), 6, "6 barbe")
	if nums.size() == 6:
		check(nums[4].x < nums[5].x and nums[4].y < nums[5].y, "corta: meno peli e meno coperta della piena")
		check(nums[0].x < nums[4].x, "ombra ancora più rada della corta")
	return done()
