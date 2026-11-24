# Prova della scena del cambio nella partita vera (scenes/partita.tscn, carriera di prova di --scena=cambio):
#   $G --headless --path godot -s res://tests/prova_cambio.gd          (esce con 0 se tutto bene, 1 se no)
# Dalla pausa "Rosa e tattica", due sostituzioni, "Torna alla partita", "Riprendi": la scena parte col tempo di
# partita fermo e la scritta CAMBI / ENTRA / ESCE, finisce da sola entro CambioRegia.DURATA, chi entra resta al suo
# posto e la partita riparte. Poi un'altra sostituzione e la scena saltata con un tocco.
extends SceneTree

const CambioRegia := preload("res://scripts/partita/cambio_regia.gd")
const LIMITE := 2000

var g: Node
var fallimenti: Array[String] = []
var controlli := 0
var fase := "attesa"
var n := 0
var t_partita := 0.0
var posti := {}


func _initialize() -> void:
	g = (load("res://scenes/partita.tscn") as PackedScene).instantiate()
	g._opzioni["pausa-rosa"] = "pausa"   # carriera di prova, poi solo la pausa
	g._opzioni["seme"] = "21"
	g._opzioni["veloce"] = "1"
	root.add_child(g)


func check(ok: bool, msg: String) -> void:
	controlli += 1
	if not ok:
		fallimenti.append(msg)
		print("FALLITO  " + msg)


func fine() -> void:
	print("prova cambio: %d controlli, %d falliti" % [controlli, fallimenti.size()])
	quit(1 if not fallimenti.is_empty() else 0)


func _process(_d: float) -> bool:
	n += 1
	if n > LIMITE:
		check(false, "tempo scaduto nella fase " + fase)
		fine()
		return false
	match fase:
		"attesa":
			if g.paused and g.cambi != null:
				check(g.carriera_partita() != null, "c'è la carriera della partita")
				g._apri_rosa()
				check(g.rosa_aperta() != null, "Rosa e tattica aperta")
				fase = "rosa"
		"rosa":
			g.sostituzioni_di_prova(2)
			check(g.cambi.fatti == 2, "due sostituzioni registrate")
			g.rosa_aperta().chiusa.emit()
			check(g.rosa_aperta() == null, "Rosa chiusa")
			check(g.cambi.da_mostrare.size() == 2, "due cambi da mostrare")
			for c: Dictionary in g.cambi.da_mostrare:
				posti[c.p] = Vector2(c.p.x, c.p.y)
			t_partita = g.m.time
			g._riprendi()
			check(g.cambio_in_corso(), "la scena del cambio parte")
			check(g.paused, "durante la scena la partita è ferma")
			var testi: Array = g._cambio.testi()
			check(testi.has("CAMBI") and testi.has("ENTRA") and testi.has("ESCE"), "scritta del cambio: %s" % str(testi))
			n = 0
			fase = "scena"
		"scena":
			if g.cambio_in_corso():
				check(g.m.time == t_partita, "tempo di partita fermo")
				return false
			check(n <= ceili(CambioRegia.DURATA * 60.0) + 5, "la scena finisce da sola (%d fotogrammi)" % n)
			check(not g.paused, "dopo la scena la partita riparte")
			for p: Object in posti:
				check(Vector2(p.x, p.y).distance_to(posti[p]) < 0.5, "chi entra è al suo posto")
			n = 0
			fase = "dopo"
		"dopo":
			if n < 60:
				return false
			check(g.m.time > t_partita, "il tempo di partita va avanti")
			g._mostra_pausa()
			g._apri_rosa()
			fase = "salta"
		"salta":
			g.sostituzioni_di_prova(1)
			g.rosa_aperta().chiusa.emit()
			g._riprendi()
			check(g.cambio_in_corso(), "terzo cambio: scena")
			var e := InputEventScreenTouch.new()
			e.pressed = true
			e.position = Vector2(200, 400)
			g._unhandled_input(e)
			check(not g.cambio_in_corso() and not g.paused, "un tocco salta la scena")
			check(g.cambi.fatti == 3, "tre cambi")
			fine()
	return false
