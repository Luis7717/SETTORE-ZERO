# Misura dei calci d'angolo (non è un test: il runner lo ignora).
# Uso:  godot --headless --path godot -s res://tests/angoli.gd [-- N]
# Stampa gol, uscite del portiere, prese, respinte e colpi di testa su N angoli a seme fisso (predefinito 200),
# nei due versi (CPU che batte contro di noi, noi contro la CPU) e col portiere manuale o automatico.
extends SceneTree

const Lab := preload("corner_lab.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 200
	print(Lab.riga("CPU batte, nostro portiere manuale", Lab.misura({"n": n, "cpu_batte": true})))
	print(Lab.riga("CPU batte, nostro portiere automatico", Lab.misura({"n": n, "cpu_batte": true, "auto_gk": true})))
	print(Lab.riga("noi battiamo, portiere CPU", Lab.misura({"n": n, "cpu_batte": false})))
	quit(0)
