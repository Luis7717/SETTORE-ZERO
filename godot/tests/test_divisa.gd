# Divisa: colletto (girocollo, a V, polo) e vestibilità (aderente, larga) arrivano davvero allo shader della divisa
# (shaders/divisa.gdshader: stile.y = colletto, numero.w = larga) dall'editor e dalla partita, la mesh ha la
# profondità delle valli del corpo in CUSTOM2 (scripts/partita/vestibilita.gd) e lo shader si compila.
extends "test_base.gd"

const Figura := preload("res://scripts/partita/figura.gd")
const Giocatore := preload("res://scripts/giocatore.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Vestibilita := preload("res://scripts/partita/vestibilita.gd")
const Editor := preload("res://scripts/menu/editor.gd")
const SHADER := "res://shaders/divisa.gdshader"
const LOOK := {"pelle": Color.TAN, "capelli": Color.BLACK}


func _kit_editor(collar: int, fit: int) -> Dictionary:
	var ed: Node = Editor.new()
	ed.d = {"kit": 1, "pos": "A", "style": {"fit": fit, "sleeves": 0, "collar": collar, "pattern": 0, "shorts": 0, "socks": 0}}
	var k: Dictionary = ed._kit_figura()
	ed.free()
	return k


func test_editor_colletto_e_maglia_cambiano_i_parametri_dello_shader() -> bool:
	var f := Figura.new()
	f.prepara(_kit_editor(0, 0), LOOK, 0.0, TV.avviso())
	var mi: MeshInstance3D = f.get("_mesh")
	var visti := {}
	for collar in 3:
		for fit in 2:
			var k := _kit_editor(collar, fit)
			for nome: String in k:   # come MenuAnteprima.metti: stesso modello, parametri per istanza
				mi.set_instance_shader_parameter(nome, k[nome])
			var st: Vector4 = mi.get_instance_shader_parameter("stile")
			var num: Vector4 = mi.get_instance_shader_parameter("numero")
			eq(int(st.y), collar, "colletto %d nello shader" % collar)
			eq(int(num.w), fit, "maglia %d nello shader" % fit)
			visti["%s|%s" % [st, num]] = true
	eq(visti.size(), 6, "sei combinazioni = sei coppie di parametri diverse")
	f.free()
	return done()


func test_portiere_resta_girocollo_ma_tiene_la_vestibilita() -> bool:
	var ed: Node = Editor.new()
	ed.d = {"kit": 1, "pos": "P", "style": {"fit": 1, "sleeves": 0, "collar": 2, "pattern": 3, "shorts": 0, "socks": 0}}
	var k: Dictionary = ed._kit_figura()
	ed.free()
	eq(int(k.stile.y), 0, "portiere: girocollo")
	eq(int(k.numero.w), 1, "portiere: la maglia larga resta")
	return done()


func test_mesh_ha_le_valli_del_corpo_in_custom2() -> bool:
	var f := Figura.new()
	f.prepara(_kit_editor(0, 0), LOOK, 0.0, TV.avviso())
	var m: ArrayMesh = Giocatore._mesh_divisa
	check(m.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM2 != 0, "la mesh ha CUSTOM2")
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var c2: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM2]
	eq(c2.size(), v.size(), "un valore per vertice")
	var busto_valli := 0
	var massimo := 0.0
	for i in v.size():
		massimo = maxf(massimo, c2[i])
		if v[i].y > 1.0 and v[i].y < 1.5 and absf(v[i].x) < 0.17 and c2[i] > 0.003:
			busto_valli += 1
	check(busto_valli >= 10, "sul busto ci sono valli da riempire (maglia larga): %d vertici" % busto_valli)
	check(massimo <= Vestibilita.MAX_VALLE + 1e-6, "valli limitate: %s" % massimo)
	f.free()
	return done()


# griglia 9×9 piatta (normale +Z) con un solco lungo la colonna centrale e una gobba: il solco ha valle > 0, la
# gobba e il piano lontano no; i vertici doppi (cucitura UV) hanno lo stesso valore
func test_valli_su_una_griglia_col_solco() -> bool:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var N := 9
	for j in N:
		for i in N:
			var z := 0.0
			if i == 4:
				z = -0.02          # solco
			if i == 1 and j == 4:
				z = 0.02           # gobba
			v.append(Vector3(i * 0.02, j * 0.02, z))
			n.append(Vector3.BACK)
	var idx := PackedInt32Array()
	for j in N - 1:
		for i in N - 1:
			var a := j * N + i
			idx.append_array([a, a + 1, a + N, a + 1, a + N + 1, a + N])
	# doppione del vertice centrale del solco (stessa posizione), usato da un triangolo in più
	v.append(v[4 * N + 4])
	n.append(Vector3.BACK)
	idx.append_array([v.size() - 1, 4 * N + 5, 5 * N + 4])
	var c := Vestibilita.valli(v, n, idx)
	check(c[4 * N + 4] > 0.005, "solco: valle %s" % c[4 * N + 4])
	eq(c[4 * N + 1], 0.0, "gobba: niente valle")
	near(c[v.size() - 1], c[4 * N + 4], 1e-6, "vertice doppio = stesso valore")
	return done()


func test_shader_si_compila_con_colletto_e_vestibilita() -> bool:
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string(SHADER)
	var nomi := []
	for u: Dictionary in sh.get_shader_uniform_list():
		nomi.append(u.name)
	for nome in ["anca_y", "collo_y", "collo_z", "spalla_x", "gomito_x"]:
		check(nomi.has(nome), "lo shader si compila e ha %s" % nome)
	for pezzo in ["CUSTOM2.x", "polo_colletto", "maglia_fine", "V_FONDO"]:
		check(sh.code.contains(pezzo), "lo shader usa %s" % pezzo)
	return done()
