# Tribune, bandiere dei tifosi e cori (2026-11-22): la tribuna dipinta usa un materiale che l'iPhone disegna (niente
# anisotropico, texture RGBA8) e ha sotto una rampa di riserva a tinta unita; le bandiere stanno sulle gradinate coi
# colori giusti; il coro sintetizzato si ripete senza salti e il suo volume segue la partita.
extends "test_base.gd"

const Stadio := preload("res://scripts/stadio.gd")
const Bandiere := preload("res://scripts/stadio/bandiere.gd")
const Sintesi := preload("res://tools/cori_sintesi.gd")
const Audio := preload("res://scripts/partita/audio_partita.gd")


func _stadio() -> Node3D:
	var s: Node3D = Stadio.new()
	s._ready()
	return s


func test_tribune_dipinte_con_materiale_sicuro_e_rampa_di_riserva() -> bool:
	var s := _stadio()
	var dipinte := 0
	var riserva := 0
	# (i nomi dei nodi fuori dall'albero non sono affidabili: due nodi con lo stesso nome diventano @MeshInstance3D@n)
	for mi: MeshInstance3D in s._rampe:
		var mat := mi.material_override as StandardMaterial3D
		dipinte += 1
		check(mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "niente anisotropico")
		eq(mat.albedo_texture.get_image().get_format(), Image.FORMAT_RGBA8, "texture RGBA8")
	for c in s.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == s._mat_riserva:
			var mi := c as MeshInstance3D
			riserva += 1
			check(s._mat_riserva.albedo_texture == null, "riserva senza texture")
			check(mi.get_aabb().position.y < Stadio.MURETTO_H, "riserva sotto la rampa dipinta")
	eq(dipinte, 4, "rampe dipinte")
	eq(riserva, 4, "rampe di riserva")
	# a densità 0 (qualità minima) le rampe passano al pubblico dipinto, con lo stesso materiale sicuro
	s.set_pubblico(0.0)
	var mat0 := (s._rampe[0] as MeshInstance3D).material_override as StandardMaterial3D
	check(mat0.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "dipinto: niente anisotropico")
	eq(mat0.albedo_texture.get_image().get_format(), Image.FORMAT_RGBA8, "dipinto: texture RGBA8")
	s.free()
	return done()


# altezza della gradinata sotto il punto p (Godot) della tribuna t, o NAN se p non ci sta sopra
static func _quota(t: Dictionary, p: Vector3) -> float:
	var a0: Vector3 = t.a0
	var b0: Vector3 = t.b0
	var a1: Vector3 = t.a1
	var lungo := b0 - a0
	var fondo := a1 - a0
	var fondo_or := Vector3(fondo.x, 0.0, fondo.z)
	var q := p - a0
	var u := Vector3(q.x, 0.0, q.z).dot(lungo) / lungo.length_squared()
	var w := Vector3(q.x, 0.0, q.z).dot(fondo_or) / fondo_or.length_squared()
	if u < 0.0 or u > 1.0 or w < 0.0 or w > 1.0:
		return NAN
	return a0.y + fondo.y * w


func test_bandiere_sulle_gradinate_coi_colori_delle_squadre() -> bool:
	var s := _stadio()
	var b: MultiMeshInstance3D = s.pubblico.bandiere
	check(b != null, "bandiere costruite")
	var attese := 0
	for t: Dictionary in s._tribune:
		attese += int(Bandiere.QUANTE.get(String(t.tipo), Bandiere.QUANTE.lato))
	eq(b.quante(), attese, "quante bandiere")
	var casa := [Color("#ff8800"), Color("#000000")]
	var ospiti := [Color("#00aa44"), Color("#ffffff")]
	s.squadre(["A", "B"], [casa, ospiti])
	var mm := b.multimesh
	var fuori := 0
	for i in mm.instance_count:
		var p: Vector3 = b.posa(i).origin
		var sopra := false
		for t: Dictionary in s._tribune:
			var h := _quota(t, p)
			if not is_nan(h) and p.y > h + 1.0 and p.y < h + 2.0:
				sopra = true
		if not sopra:
			fuori += 1
		var sq: Array = ospiti if b.squadra(i) > 0.5 else casa
		var cc: Array[Color] = b.colori_bandiera(i)
		var c := cc[0]
		var cd := cc[1]
		check(Color(c.r, c.g, c.b).is_equal_approx(sq[0]), "primo colore bandiera %d" % i)
		check(Color(cd.r, cd.g, cd.b).is_equal_approx(sq[1]), "secondo colore bandiera %d" % i)
	eq(fuori, 0, "bandiere non sulle mani di un tifoso in gradinata")
	# densità a metà: metà bandiere; a zero spariscono col pubblico
	s.set_pubblico(0.5)
	eq(mm.visible_instance_count, int(mm.instance_count * 0.5), "metà bandiere")
	s.set_pubblico(0.0)
	check(not s.pubblico.visible, "senza pubblico niente bandiere")
	note("%d bandiere, %d vertici l'una" % [b.quante(), Bandiere.mesh_bandiera().surface_get_array_len(0)])
	s.free()
	return done()


func test_coro_si_ripete_senza_salti() -> bool:
	var x := Sintesi.sintetizza(8)
	eq(x.size(), int(round(Sintesi.durata() * Sintesi.HZ)), "lunghezza di un giro")
	var picco := 0.0
	var somma := 0.0
	var salto := 0.0
	for i in x.size():
		picco = maxf(picco, absf(x[i]))
		somma += x[i] * x[i]
		if i > 0:
			salto = maxf(salto, absf(x[i] - x[i - 1]))
	var rms := sqrt(somma / x.size())
	var cucitura := absf(x[0] - x[x.size() - 1])
	note("picco %.2f, rms %.3f, salto massimo tra due campioni %.3f, alla cucitura %.3f" % [picco, rms, salto, cucitura])
	near(picco, Sintesi.PICCO, 0.001, "picco normalizzato")
	check(rms > 0.05, "si sente (rms %.3f)" % rms)
	check(cucitura <= salto, "la cucitura del giro non salta più dei campioni normali")
	eq(Sintesi.sintetizza(4, 9), Sintesi.sintetizza(4, 9), "stesso seme, stesso coro")
	return done()


func test_file_dei_cori_corto_e_in_loop() -> bool:
	var f := "res://assets/audio/cori.wav"
	check(ResourceLoader.exists(f), "cori.wav c'è")
	check(FileAccess.get_file_as_bytes(f).size() < 2 * 1024 * 1024, "sotto i 2 MB")
	var w := load(f) as AudioStreamWAV
	check(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD, "si ripete da sé")
	return done()


func test_volume_dei_cori() -> bool:
	eq(Audio.livello_cori(0.0, 1.0, 0.1, 3.0, 5.0, true), 0.0, "partita ferma: zitti")
	var base := Audio.livello_cori(0.16, 0.0, 0.0, 0.0, 0.0, false)
	check(base > 0.0, "durante il gioco si sentono")
	check(Audio.livello_cori(0.16, 1.0, 0.0, 0.0, 0.0, false) > base, "più forti vicino alla porta")
	check(Audio.livello_cori(0.16, 0.0, 0.08, 0.0, 0.0, false) > base, "più forti durante il coro")
	check(Audio.livello_cori(0.16, 0.0, 0.0, Audio.CORI_OCCASIONE_DURA, 0.0, false) > base, "più forti dopo un'occasione")
	var gol := Audio.livello_cori(0.16, 0.0, 0.0, 0.0, Audio.CORI_GOL_DURA, false)
	check(gol >= Audio.CORI_GOL, "dopo un gol cantano tutti")
	check(Audio.livello_cori(0.16, 0.0, 0.0, 0.0, 0.0, true) > base, "nel derby più forti")
	return done()


# sull'iPhone (Metal) i materiali col filtro anisotropico non si disegnano (pallone il 2026-11-21, tribune, erba, led e
# rete il 2026-11-22): nessuno script o shader deve usarlo (le righe di commento non contano)


static func _file_sorgente(cartella: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(cartella):
		_file_sorgente(cartella + d + "/", out)
	for f in DirAccess.get_files_at(cartella):
		if f.ends_with(".gd") or f.ends_with(".gdshader") or f.ends_with(".gdshaderinc"):
			out.append(cartella + f)


func test_nessun_filtro_anisotropico() -> bool:
	var file: Array[String] = []
	_file_sorgente("res://scripts/", file)
	_file_sorgente("res://shaders/", file)
	check(file.size() > 20, "trovati gli script (%d)" % file.size())
	for f in file:
		var rel := f.trim_prefix("res://")
		var righe := FileAccess.get_file_as_string(f).split("\n")
		for i in righe.size():
			var r := righe[i].strip_edges()
			if r.begins_with("#") or r.begins_with("//"):
				continue
			if r.to_lower().contains("anisotropic"):
				failures.append("%s:%d usa un filtro anisotropico" % [rel, i + 1])
	return done()
