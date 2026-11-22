# Foto dello stadio di notte da lontano, per guardare a occhio le 4 torri faro accese (alone e lampade, meteo.gd).
# Uso (finestra vera, non --headless):
#   $G --path godot -s res://tests/foto_fari.gd [-- --file=shots/fari.png --ora=notte --meteo=sereno]
# (percorso relativo a quella che contiene godot/)
extends SceneTree

const H := preload("res://tests/harness.gd")
const Meteo := preload("res://scripts/partita/meteo.gd")
const Coord := preload("res://scripts/coord.gd")

var _file := "shots/fari.png"
var _attesa := 20
var _opz := {}
var _pronta := false


func _initialize() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var p := a.substr(2).split("=", true, 1)
			opz[p[0]] = p[1] if p.size() > 1 else "1"
	_file = opz.get("file", _file)
	_opz = opz


# al primo fotogramma (nell'_initialize la vista non è ancora pronta: niente @onready)
func _prepara() -> void:
	var opz := _opz
	var vista: Node3D = (load("res://scenes/vista_partita.tscn") as PackedScene).instantiate()
	root.add_child(vista)
	var m := H.newMatch(3, 9999.0, [false, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))
	vista.setup(m, 0)
	var meteo := Meteo.new()
	root.add_child(meteo)
	meteo.applica(vista, {"meteo": opz.get("meteo", "sereno"), "ora": opz.get("ora", "notte")})
	var cam := vista.get_node("Telecamera") as Camera3D
	cam.fov = 70.0
	cam.look_at_from_position(Coord.a_godot(0.0, -70.0, 250.0), Coord.a_godot(0.0, 0.0, 0.0), Vector3.UP)


func _process(_dt: float) -> bool:
	if not _pronta:
		_pronta = true
		_prepara()
	_attesa -= 1
	if _attesa > 0:
		return false
	var img := root.get_viewport().get_texture().get_image()
	var dove := ProjectSettings.globalize_path("res://").path_join("..").path_join(_file).simplify_path()
	DirAccess.make_dir_recursive_absolute(dove.get_base_dir())
	img.save_png(dove)
	print("foto ", dove)
	H.disposeAll()
	return true
