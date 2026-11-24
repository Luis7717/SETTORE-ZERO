# Misure di un'esultanza (mosse/esultanza.gd) sulla figura vera: dove stanno mani, punta delle dita, gomiti, testa,
# nel riferimento del corpo (x = sinistra, y = su, z = avanti; metri del modello), a qualche istante.
# Uso: $G --headless --path godot -s res://tools/misura_esultanza.gd -- --id=saluto --t=1.0,2.0
extends SceneTree

const Figura := preload("res://scripts/partita/figura.gd")
const E := preload("res://scripts/partita/mosse/esultanza.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const R := preload("res://sim/records.gd")


func _initialize() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var p := a.substr(2).split("=", true, 1)
			opz[p[0]] = p[1] if p.size() > 1 else "1"
	var id: String = opz.get("id", "saluto")
	var f: Node3D = Figura.new()
	root.add_child(f)
	f.prepara({"maglia": Color.RED}, {"pelle": Color.TAN}, 0.0, TV.avviso())
	print("lunghezza mano (polso → punta) %.3f" % f.lunghezza_mano())
	var ctx := {"t": 0.0, "phase": "goal", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}
	var p := R.Player.new()
	for ts in String(opz.get("t", "1.5,2.5")).split(","):
		var t := float(ts)
		f.esultanza = E.posa(id, t)
		f.posa(p, 0.0, ctx)
		print("--- %s t=%.2f" % [id, t])
		for n in ["Head", "spine_03"]:
			print("  %s %s" % [n, _v(f.pos_corpo(n))])
		for s in ["l", "r"]:
			print("  %s spalla %s gomito %s polso %s punta %s dita %s palmo %s" % [s, _v(f.pos_corpo("upperarm_" + s)),
				_v(f.pos_corpo("lowerarm_" + s)), _v(f.pos_corpo("hand_" + s)), _v(f.punta_mano(s)),
				_v(f.verso_mano(s).x), _v(f.verso_mano(s).y)])
			var avamb: Vector3 = (f.pos_corpo("hand_" + s) - f.pos_corpo("lowerarm_" + s)).normalized()
			var brac: Vector3 = (f.pos_corpo("lowerarm_" + s) - f.pos_corpo("upperarm_" + s)).normalized()
			print("    polso piegato %.0f°, gomito %.0f°, avambraccio %s (%.0f° sull'orizzontale)" % [rad_to_deg(avamb.angle_to(f.verso_mano(s).x)),
				rad_to_deg(brac.angle_to(avamb)), _v(avamb), rad_to_deg(asin(avamb.y))])
	f.free()
	quit(0)


func _v(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
