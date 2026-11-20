# Stampa la struttura di un modello importato (nodi, ossa, animazioni, mesh). Strumento di sviluppo.
# Uso: Godot --headless --path godot --script res://tools/ispeziona_modello.gd -- res://assets/models/athlete.glb
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://assets/models/athlete.glb"
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("non trovo " + path)
		quit(1)
		return
	var root := packed.instantiate()
	_stampa(root, 0)
	for n in root.find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		for a in ap.get_animation_list():
			var anim := ap.get_animation(a)
			print("anim ", a, " len=", anim.length, " loop=", anim.loop_mode, " tracce=", anim.get_track_count())
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var aabb := mi.mesh.get_aabb()
		print("mesh ", mi.name, " superfici=", mi.mesh.get_surface_count(), " aabb=", aabb, " skin=", mi.skin != null)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var mat := mi.mesh.surface_get_material(s)
			print("  sup ", s, " vertici=", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), " formato=", mi.mesh.surface_get_format(s), " mat=", mat)
			if mat is BaseMaterial3D:
				print("    albedo=", mat.albedo_color, " tex=", mat.albedo_texture, " detail=", mat.detail_enabled)
		print("  xform globale=", mi.global_transform if mi.is_inside_tree() else mi.transform)
	for n in root.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		var nomi := []
		for b in sk.get_bone_count():
			nomi.append("%s(y=%.2f)" % [sk.get_bone_name(b), sk.get_bone_global_rest(b).origin.y])
		print("ossa ", sk.get_bone_count(), ": ", ", ".join(nomi))
	root.free()
	quit(0)

func _stampa(n: Node, d: int) -> void:
	var extra := ""
	if n is Node3D:
		extra = " pos=%s scala=%s" % [n.position, n.scale]
	print("  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_stampa(c, d + 1)
