# Genera l'icona 1024×1024 dell'app ingrandendo l'icona 180×180 dell'app web (App/AppIcon60x60@3x.png).
# Uso: Godot --headless --path godot --script res://tools/genera_icona.gd
# Va rifatta solo se cambia l'icona in App/. L'ingrandimento è morbido: un'icona disegnata a 1024 sarà meglio.
extends SceneTree

const SORGENTE := "../App/AppIcon60x60@3x.png"
const DESTINAZIONE := "res://assets/icons/icon_1024.png"
const LATO := 1024

func _init() -> void:
	var img := Image.new()
	var percorso := ProjectSettings.globalize_path("res://").path_join(SORGENTE).simplify_path()
	var err := img.load(percorso)
	if err != OK:
		push_error("icona: non riesco a leggere %s (errore %d)" % [percorso, err])
		quit(1)
		return
	img.convert(Image.FORMAT_RGB8) # iOS non vuole trasparenza nell'icona
	img.resize(LATO, LATO, Image.INTERPOLATE_LANCZOS)
	err = img.save_png(DESTINAZIONE)
	if err != OK:
		push_error("icona: non riesco a scrivere %s (errore %d)" % [DESTINAZIONE, err])
		quit(1)
		return
	print("icona scritta: ", DESTINAZIONE, " ", img.get_size())
	quit(0)
