# Rigenera il tema dei menu (assets/tema/tema.tres) da scripts/menu/tema_menu.gd.
# Uso:  godot --headless --path godot -s res://tools/crea_tema.gd
extends SceneTree


func _init() -> void:
	var tema := MenuTema.crea_tema()
	DirAccess.make_dir_recursive_absolute("res://assets/tema")
	var err := ResourceSaver.save(tema, MenuTema.PERCORSO)
	print("tema: ", MenuTema.PERCORSO, " → ", "ok" if err == OK else "errore %d" % err)
	quit(0 if err == OK else 1)
