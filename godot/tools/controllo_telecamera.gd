# Controllo della telecamera (non è un test: il runner lo ignora). Gioca partite intere con la scena vera
# (scenes/partita.tscn: motore, vista, telecamera, HUD) col dito finto (--bot) e a passo fisso, anche senza schermo, e
# a ogni fotogramma guarda la posa della telecamera e i nodi 3D della vista: segnala posa non finita o degenere,
# campo visivo fuori misura, telecamera sotto terra o troppo lontana dal campo, nodi 3D con posizione non finita.
# Nato per il "tutto nero" su un calcio d'angolo al 49' (Luis 2026-11-24).
#   $G --headless --path godot -s res://tools/controllo_telecamera.gd -- --semi=10 --da=1 --tempo=150 --veloce=1
#   opzioni: --nodi (controlla anche tutti i nodi 3D della vista, più lento) · --max=20 (righe di problemi per partita)
extends SceneTree

const Coord := preload("res://scripts/coord.gd")

const LIMITE_X := Coord.HW + 30.0   # oltre (m) la telecamera è fuori dallo stadio
const LIMITE_Y := Coord.HL + 30.0
const ALTEZZA_MIN := 0.3            # sotto (m) la telecamera è sotto terra
const FOV_MIN := 5.0
const FOV_MAX := 120.0

var semi := 10
var seme := 1
var tempo := "150"
var veloce := "1"
var nodi := false
var max_righe := 20
var g: Node = null
var fotogrammi := 0
var problemi := 0
var problemi_tot := 0
var righe := 0
var angoli := 0
var angoli_tot := 0
var _era_angolo := false
var semi_male: Array = []
var traccia := -1
var traccia_fino := -1


func _initialize() -> void:
	var opz := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opz[kv[0]] = kv[1] if kv.size() > 1 else "1"
	semi = int(opz.get("semi", "10"))
	seme = int(opz.get("da", "1"))
	tempo = String(opz.get("tempo", "150"))
	veloce = String(opz.get("veloce", "1"))
	nodi = opz.has("nodi")
	max_righe = int(opz.get("max", "20"))
	traccia = int(opz.get("traccia", "-1"))
	traccia_fino = int(opz.get("fino", "-1"))
	_nuova()


func _nuova() -> void:
	g = (load("res://scenes/partita.tscn") as PackedScene).instantiate()
	g._opzioni["bot"] = "1"
	g._opzioni["seme"] = str(seme)
	g._opzioni["veloce"] = veloce
	g._opzioni["tempo"] = tempo
	g._opzioni["senza-replay"] = "1"
	root.add_child(g)
	fotogrammi = 0
	problemi = 0
	righe = 0
	angoli = 0
	_era_angolo = false


func _process(_d: float) -> bool:
	if g == null:
		return false
	if g.m == null or g.vista == null or not ("cam" in g.vista):
		return false
	fotogrammi += 1
	if traccia >= 0 and fotogrammi >= traccia:
		_traccia()
	if traccia_fino > 0 and fotogrammi >= traccia_fino:
		quit(0)
		return false
	_controlla()
	if g.stato == "fine" or fotogrammi > 200000:
		print("seme %d: %d fotogrammi, %d angoli, %d problemi, %d-%d" % [seme, fotogrammi, angoli, problemi, g.m.score[0], g.m.score[1]])
		problemi_tot += problemi
		angoli_tot += angoli
		if problemi > 0:
			semi_male.append(seme)
		g.queue_free()
		g = null
		seme += 1
		semi -= 1
		if semi <= 0:
			print("TOTALE: %d problemi, %d angoli, semi con problemi: %s" % [problemi_tot, angoli_tot, str(semi_male)])
			quit(0 if problemi_tot == 0 else 1)
			return false
		_nuova()
	return false


func _controlla() -> void:
	var m: Object = g.m
	var cam: Camera3D = g.vista.cam
	var r: Object = m.restart
	var angolo: bool = m.phase == "restart" and r != null and r.type == "corner"
	if angolo and not _era_angolo:
		angoli += 1
	_era_angolo = angolo
	var tr := cam.global_transform
	var male: Array = []
	if not tr.origin.is_finite() or not tr.basis.is_finite():
		male.append("posa non finita")
	elif absf(tr.basis.determinant()) < 0.5:
		male.append("base degenere (det %.3f)" % tr.basis.determinant())
	if not is_finite(cam.fov) or cam.fov < FOV_MIN or cam.fov > FOV_MAX:
		male.append("fov %.2f" % cam.fov)
	var o := tr.origin
	if o.is_finite():
		if o.y < ALTEZZA_MIN:
			male.append("sotto terra")
		if absf(o.x) > LIMITE_X or absf(o.z) > LIMITE_Y:
			male.append("fuori dallo stadio")
	if nodi and fotogrammi % 5 == 0:
		var n := _nodo_non_finito(g.vista)
		if n != "":
			male.append("nodo non finito: " + n)
	if male.is_empty():
		return
	problemi += 1
	if righe >= max_righe:
		return
	righe += 1
	var info := "seme %d f%d %d' half%d fase=%s" % [seme, fotogrammi, m.minute(), m.half, m.phase]
	if r != null:
		info += " restart=%s team=%d scena=%s x=%.2f y=%.2f" % [r.type, r.team, r.scena, r.x, r.y]
	info += " palla=(%.2f,%.2f,%.2f)" % [m.ball.x, m.ball.y, m.ball.h]
	print("PROBLEMA %s | %s | pos=%s fwd=%s fov=%.2f" % [", ".join(male), info, str(o), str(-tr.basis.z), cam.fov])


func _nodo_non_finito(n: Node) -> String:
	if n is Node3D and n.is_inside_tree():
		var t: Transform3D = (n as Node3D).global_transform
		if not t.origin.is_finite() or not t.basis.is_finite():
			return str(n.get_path())
	for c in n.get_children():
		var s := _nodo_non_finito(c)
		if s != "":
			return s
	return ""


func _traccia() -> void:
	var m: Object = g.m
	var t := "f%d fase=%s" % [fotogrammi, m.phase]
	if m.restart != null:
		t += " %s scena=%s racc=%s rim=%s" % [m.restart.type, m.restart.scena, m.restart.raccatta, m.restart.rimando]
	t += " palla=(%.3f,%.3f,%.2f v %.2f,%.2f)" % [m.ball.x, m.ball.y, m.ball.h, m.ball.vx, m.ball.vy]
	for bb: Object in m.raccatte:
		t += " | bb%d %s (%.4f,%.4f) palla=%s" % [bb.i, bb.stato, bb.x, bb.y, bb.palla]
	print(t)
