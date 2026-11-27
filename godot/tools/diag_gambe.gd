# Gambe dei giochetti del dribbling (non è un test: il runner lo ignora): le misure di tests/test_skill_gambe.gd, per
# tutti i giochetti o fotogramma per fotogramma per uno solo (per trovare un salto, una gamba stirata, due gambe una
# dentro l'altra).
#   $G --headless --path godot -s res://tools/diag_gambe.gd                      una riga per giochetto e per giocatore
#   ... -- --id=tunnel --chi=o [--da=0.3 --a=0.6]    caviglie e ginocchia a ogni fotogramma (chi: p portatore, o difensore;
#                                                    id "fallito" = dribbling fallito)
extends SceneTree

const TG := preload("res://tests/test_skill_gambe.gd")
const CS := preload("res://scripts/partita/mosse/coreo_skill.gd")


func _init() -> void:
	var opz := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if opz.has("id"):
		var id := String(opz.id)
		TG.misura("finta" if id == "fallito" else id, id != "fallito", -1, String(opz.get("chi", "p")),
			float(opz.get("da", "0")), float(opz.get("a", "9")))
	else:
		var ids: Array = CS.IDS.duplicate()
		ids.append("fallito")
		for id: String in ids:
			var r := TG.misura("finta" if id == "fallito" else id, id != "fallito")
			for chi: String in ["p", "o"]:
				print(TG.riga(id, chi, r[chi]))
	quit()
