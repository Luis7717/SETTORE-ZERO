# Prova della scena del cambio nella partita vera (scenes/partita.tscn, carriera di prova di --scena=cambio):
#   $G --headless --path godot -s res://tests/prova_cambio.gd          (esce con 0 se tutto bene, 1 se no)
# Luis 2026-11-27 "per fare i cambi aspetta che la palla esca": a pallone in gioco dalla pausa "Rosa e tattica", due
# sostituzioni, "Torna alla partita", "Riprendi": la partita riparte senza scena, il motore non cambia e nell'HUD c'è
# "Cambio pronto". Riaperta la Rosa i cambi in attesa contano (Cambi 3/5) e si possono disfare. Al primo pallone
# fuori i cambi vanno nel motore e parte la scena (tempo fermo, CAMBIO / ENTRA / ESCE), che finisce da sola entro
# CambioRegia.DURATA con tutti al loro posto. Poi un'altra sostituzione: all'intervallo entra subito (scena a
# "Secondo tempo", saltata con un tocco). Infine un cambio in attesa e la partita che finisce: si perde.
extends SceneTree

const CambioRegia := preload("res://scripts/partita/cambio_regia.gd")
const C := preload("res://sim/core.gd")
const LIMITE := 4000

var g: Node
var fallimenti: Array[String] = []
var controlli := 0
var fase := "attesa"
var n := 0
var t_partita := 0.0
var posti := {}
var in_campo: Array = []
var lineup_prima: Array = []


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


func _ids() -> Array:
	return g.m.team(g.me).map(func(p: Object) -> Variant: return p.src.id)


func _pallone_in_gioco() -> bool:
	return g.stato == "partita" and not g.paused and g.m != null and g.m.phase == "play" and not g.cambio_in_corso()


# a pallone in gioco: pausa, Rosa e tattica, k sostituzioni, Torna alla partita
func _cambi_dalla_pausa(k: int) -> void:
	g._mostra_pausa()
	g._apri_rosa()
	g.sostituzioni_di_prova(k)
	g.rosa_aperta().chiusa.emit()


func _process(_d: float) -> bool:
	n += 1
	if n > LIMITE:
		check(false, "tempo scaduto nella fase " + fase)
		fine()
		return false
	match fase:
		"attesa": # la pausa automatica di --pausa-rosa=pausa, poi si riprende
			if g.paused and g.cambi != null:
				check(g.carriera_partita() != null, "c'è la carriera della partita")
				g._riprendi()
				fase = "in_gioco"
		"in_gioco":
			if not _pallone_in_gioco():
				return false
			in_campo = _ids()
			_cambi_dalla_pausa(2)
			check(g.cambi.fatti == 2, "due sostituzioni registrate")
			check(g.rosa_aperta() == null, "Rosa chiusa")
			check(g.cambi.attesa, "pallone in gioco: i cambi aspettano")
			check(g.cambi.da_mostrare.is_empty(), "niente da mostrare ancora")
			check(_ids() == in_campo, "nel motore non è cambiato niente")
			g._riprendi()
			check(not g.cambio_in_corso() and not g.paused, "Riprendi: si gioca, niente scena")
			g._aggiorna_hud()
			check(g.hud.cambio_pronto_visibile(), "HUD: Cambio pronto")
			# riaperta la Rosa: i cambi in attesa contano e si possono disfare
			g._mostra_pausa()
			g._aggiorna_hud()
			check(not g.hud.cambio_pronto_visibile(), "in pausa la scritta non c'è")
			g._apri_rosa()
			check(g.cambi.restano() == 3, "Rosa riaperta: Cambi 3/5 (%d)" % g.cambi.restano())
			var c: Object = g.carriera_partita()
			var dentro: Array = g.cambi.entrati_in_attesa(c.s.lineup)
			var fuori: Array = in_campo.filter(func(id: Variant) -> bool: return not c.s.lineup.has(id))
			check(dentro.size() == 2 and fuori.size() == 2, "due in attesa")
			check(g.rosa_aperta()._stato_partita(fuori[0]) == "", "chi aspetta di uscire non è USCITO")
			g.rosa_aperta()._tocca(dentro[0])
			g.rosa_aperta()._tocca(fuori[0])
			g.rosa_aperta()._tocca(fuori[0])
			check(g.cambi.fatti == 1, "un cambio disfatto (%d)" % g.cambi.fatti)
			g.rosa_aperta().chiusa.emit()
			check(g.cambi.attesa, "ancora uno in attesa")
			g._riprendi()
			check(not g.paused, "si gioca")
			n = 0
			fase = "fuori"
		"fuori":
			if n < 20 or not _pallone_in_gioco():
				return false
			check(_ids() == in_campo, "motore invariato finché la palla è in gioco")
			g.m.ball.last = g.m.team(1 - g.me)[9]
			g.m.out(C.HW + 0.6, 6.0, 0.0) # pallone fuori: rimessa
			fase = "scena_parte"
		"scena_parte":
			if not g.cambio_in_corso():
				return false
			check(not g.cambi.attesa, "cambi entrati")
			check(not g.hud.cambio_pronto_visibile(), "scritta tolta")
			check(g.paused, "durante la scena la partita è ferma")
			check(g.m.phase == "restart", "a gioco fermo")
			var ora := _ids()
			check(ora.filter(func(id: Variant) -> bool: return not in_campo.has(id)).size() == 1, "un cambio nel motore")
			var testi: Array = g._cambio.testi()
			check(testi.has("ENTRA") and testi.has("ESCE"), "scritta del cambio: %s" % str(testi))
			for p: Object in g.m.team(g.me):
				posti[p] = Vector2(p.x, p.y)
			for cp: Dictionary in g._cambio._coppie: # chi entra: la scena lo mette in panchina, a fine scena al suo posto
				posti[cp.p] = cp.a
			t_partita = g.m.time
			n = 0
			fase = "scena"
		"scena":
			if g.cambio_in_corso():
				check(g.m.time == t_partita, "tempo di partita fermo")
				return false
			check(n <= ceili(CambioRegia.DURATA * 60.0) + 5, "la scena finisce da sola (%d fotogrammi)" % n)
			check(not g.paused, "dopo la scena la partita riparte")
			for p: Object in posti:
				if Vector2(p.x, p.y).distance_to(posti[p]) >= 0.5:
					check(false, "%s è al suo posto" % p.name)
					break
			check(g.cambi.fatti == 1 and g.cambi.confermati == 1, "un cambio confermato")
			n = 0
			fase = "intervallo"
		"intervallo":
			if n < 30 or not _pallone_in_gioco():
				return false
			_cambi_dalla_pausa(1)
			check(g.cambi.attesa, "secondo cambio in attesa")
			g._riprendi()
			in_campo = _ids()
			g.m.endHalf() # fischio dell'intervallo prima che la palla esca
			fase = "secondo_tempo"
		"secondo_tempo":
			if g.m.phase != "half" or not g.paused:
				return false
			check(not g.cambi.attesa and g.cambi.da_mostrare.size() == 1, "all'intervallo il cambio entra subito")
			check(_ids() != in_campo, "nel motore all'intervallo")
			g._secondo_tempo()
			check(g.cambio_in_corso(), "Secondo tempo: scena del cambio")
			var e := InputEventScreenTouch.new()
			e.pressed = true
			e.position = Vector2(200, 400)
			g._unhandled_input(e)
			check(not g.cambio_in_corso() and not g.paused, "un tocco salta la scena")
			check(g.cambi.fatti == 2, "due cambi")
			n = 0
			fase = "perso"
		"perso":
			if n < 30 or not _pallone_in_gioco():
				return false
			var c2: Object = g.carriera_partita()
			lineup_prima = (c2.s.lineup as Array).duplicate()
			_cambi_dalla_pausa(1)
			check(g.cambi.attesa and c2.s.lineup != lineup_prima, "terzo cambio in attesa")
			g._riprendi()
			g._finisci(false) # la partita finisce prima che la palla esca
			check(not g.cambi.attesa and g.cambi.fatti == 2, "il cambio in attesa non entra più in partita")
			# Luis 2026-11-28: a fine partita la squadra torna quella di prima della partita (non quella dei cambi)
			check(c2.s.lineup == g.cambi.prima.lineup, "la carriera torna alla squadra di prima della partita")
			fine()
	return false
