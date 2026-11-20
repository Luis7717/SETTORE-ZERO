# Runner dei test del motore in GDScript.
# Uso:  godot --headless --path godot -s res://tests/run_tests.gd [-- filtro]
#   filtro (facoltativo) = parte del nome del file o del test, es. `-- equivalence` o `-- duel`.
# Esce con codice 0 se tutti i test passano, 1 se almeno uno fallisce.
extends SceneTree

const TEST_DIR := "res://tests/"
const H := preload("harness.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var filt: String = args[0] if args.size() > 0 else ""
	var files: Array[String] = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_base.gd":
			files.append(f)
	files.sort()
	var passed := 0
	var failed := 0
	var failedNames: Array[String] = []
	var t0 := Time.get_ticks_msec()
	for f in files:
		var scr: GDScript = load(TEST_DIR + f)
		if scr == null:
			print("FALLITO  %s: lo script non si carica" % f)
			failed += 1
			failedNames.append(f)
			continue
		var names: Array[String] = []
		for m in scr.get_script_method_list():
			var n: String = m.name
			if n.begins_with("test_") and not names.has(n):
				names.append(n)
		for n in names:
			if filt != "" and not (f.contains(filt) or n.contains(filt)):
				continue
			var obj: Object = scr.new()
			var t1 := Time.get_ticks_msec()
			var res: Variant = obj.call(n)
			var ms := Time.get_ticks_msec() - t1
			var fails: Array = obj.failures
			var ok: bool = res == true and fails.is_empty()
			if ok:
				passed += 1
				print("ok       %s :: %s (%d ms)" % [f, n, ms])
			else:
				failed += 1
				failedNames.append(f + " :: " + n)
				print("FALLITO  %s :: %s (%d ms)" % [f, n, ms])
				if res != true:
					print("         interrotto da un errore di script (vedi sopra)")
				for msg in fails:
					print("         - " + str(msg))
			for msg in obj.notes:
				print("         · " + str(msg))
	print("")
	print("test: %d passati, %d falliti (%.1f s)" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	for n in failedNames:
		print("  fallito: " + n)
	quit(1 if failed > 0 else 0)
