# Ogni script del gioco si deve caricare senza errori di sintassi. Un errore in uno script del menu (come la
# variabile "riga" dichiarata due volte in dopo_partita.gd, Luis 2026-11-24: fine partita → "Continua" → schermata
# azzurra fissa) non lo vede nessun test del motore: lo script si carica solo quando si apre quella schermata.
extends "res://tests/test_base.gd"

const CARTELLE := ["res://scripts/", "res://sim/", "res://shaders/"]


func test_tutti_gli_script_si_caricano() -> bool:
	var file: Array[String] = []
	for c: String in CARTELLE:
		_raccogli(c, file)
	check(file.size() > 50, "trovati pochi script (%d)" % file.size())
	var rotti: Array[String] = []
	var saltati: Array[String] = []
	var usa_app := RegEx.create_from_string(r'(?m)^[^#"\n]*(?<![\w/.])App\.') # fuori da commenti e testi
	for p in file:
		# chi usa l'autoload App per nome non compila senza l'app (qui c'è solo lo SceneTree dei test): si salta
		if usa_app.search(FileAccess.get_file_as_string(p)) != null:
			saltati.append(p.get_file())
			continue
		var scr: Variant = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
		if not (scr is GDScript) or not (scr as GDScript).can_instantiate():
			rotti.append(p)
	check(rotti.is_empty(), "script che non si caricano: %s" % ", ".join(rotti))
	note("%d script caricati, saltati (usano App): %s" % [file.size() - saltati.size(), ", ".join(saltati)])
	return done()


func _raccogli(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		_raccogli(dir + d + "/", out)
