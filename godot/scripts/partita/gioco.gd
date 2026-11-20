# Partita giocabile (porting del ciclo di src/main.js: frame, events, pausa, intervallo, fine).
# Crea la partita (SimMatch con le squadre di prova), la vista, l'HUD, i suoni e i gesti, e a ogni fotogramma fa
# nell'ordine: gesti → passi del motore col tempo scalato (rallenty) → eventi → update_view(dt_game, dt_real).
#
# Vista: scenes/vista_partita.tscn (altro lavoro, class_name PartitaVista); se non c'è ancora, la vista finta
# scripts/partita/vista_finta.gd. Metodi usati: setup, update_view, world_to_screen, screen_to_field, show_path,
# clear_path, trick, dispose; variabili user_yaw, cam_drag, drawing. Facoltativi: screen_to_goal, set_zoom.
#
# Opzioni da riga di comando (dopo "--"), per le prove:
#   --seme=N            seme della partita (predefinito: a caso)
#   --tempo=SEC         durata di un tempo in secondi di gioco (predefinito 150, come il web)
#   --vista-finta       usa la vista finta anche se c'è quella vera
#   --veloce=K          tempo fisso di K/60 s a fotogramma (prove senza schermo: la partita va più veloce del vero)
#   --bot               un "dito finto" gioca la squadra 0 coi gesti veri (scripts/partita/bot_dito.gd)
#   --esci-a-fine       a fine partita stampa il riassunto ed esce (codice 0)
#   --scena=area|duello|angolo|pausa   mette la partita in una situazione da fotografare
#   --schermata=PERCORSO.png [--dopo=SEC] [--alla-fine]   schermata dopo SEC secondi veri, o alla fine partita
#   --esci-dopo=SEC     esce dopo SEC secondi veri
extends Node

const SimMatchScript := preload("res://sim/match.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const Squadre := preload("res://scripts/partita/squadre_prova.gd")
const Gesti := preload("res://scripts/partita/gesti.gd")
const VD := preload("res://scripts/partita/visuale_dito.gd")
const VistaFinta := preload("res://scripts/partita/vista_finta.gd")
const AudioPartita := preload("res://scripts/partita/audio_partita.gd")
const BotDito := preload("res://scripts/partita/bot_dito.gd")
const Minimappa := preload("res://scripts/partita/minimappa.gd")
const HudPartita := preload("res://scripts/partita/hud_partita.gd")
const HudFase1 := preload("res://scripts/hud.gd")
const SCENA_VISTA := "res://scenes/vista_partita.tscn"

# velocità del tempo (rallenty), come src/main.js
const RUN_DRAW_SLOW := 0.25   # mentre si disegna la strada da correre
const GK_SLOW := 0.1          # mentre si para
const DEF_DRAW_SLOW := 0.13   # mentre si disegna una linea di difesa
const PASS_DRAW_SLOW := 0.04  # mentre si disegna un passaggio o un tiro
const DUEL_SLOW := 0.08       # duello col difensore
const ZONE_SLOW := 0.1        # area di tiro (ultimi 20 m prima della porta avversaria)
const TEMPO_K := 14.0         # 1/s: il tempo passa dolcemente da una velocità all'altra
const DT_MAX := 0.05          # fotogramma più lungo considerato (s)
const PASSO_MAX := 1.0 / 60.0 # passo del motore: il tempo del fotogramma si divide in passi non più lunghi di così
const RALLENTY_SOTTO := 0.6   # sotto questa velocità del tempo si vede il bordo scuro del rallenty
const HUD_OGNI_MS := 100
const FINE_DOPO_MS := 1500    # dal fischio finale alla schermata di fine partita
const TEMPO_PREDEFINITO := 150.0
const FOLLA_BASE := 0.16
const TITOLO := "Amichevole"

const HINTS := {
	"attack": "Disegna la strada dal giocatore per correre · linea in porta = tiro",
	"defend": "Disegna linee dai tuoi giocatori: solo chi ha una linea si muove",
	"loose": "Palla libera: disegna una linea da un tuo giocatore per andarci",
	"dive": "PARA! Tira una linea dal portiere al punto della porta",
	"duel": "Disegna fino a un compagno per passare · oppure tocca Dribbling",
	"zone": "Area di tiro: linea in porta = tiro · fino a un compagno = passaggio",
}
const RHINT := {
	"kickoff": "Calcio d'inizio: disegna il passaggio", "throw": "Rimessa: disegna il passaggio",
	"corner": "Calcio d'angolo: disegna il cross", "goalkick": "Rinvio: disegna il passaggio",
	"freekick": "Punizione: disegna il passaggio o il tiro", "penalty": "RIGORE: disegna il tiro in porta",
	"gk": "Rilancio del portiere: disegna il passaggio",
}

var m: SimMatchScript = null
var me := 0
var stato := "partita"        # "partita" o "fine"
var paused := false
var ts := 1.0                 # velocità del tempo attuale (1 = normale)
var gesti: Gesti
var vista = null              # PartitaVista (vera) o vista finta: senza tipo, si chiamano i metodi del contratto
var hud: HudPartita
var audio: AudioPartita
var bot: BotDito = null
var abbandonata := false

var _opzioni := {}
var _fine_ms := 0
var _hud_ms := 0
var _cam_tip_visto := false   # la scritta della visuale si mostra finché non la si gira una volta (web: career.s.camTip)
var _velocita := 1.0
var _dt_fisso := 0.0
var _fotogrammi := 0
var _anteprima_viva := false
var _inizio_ms := 0


func _ready() -> void:
	_leggi_opzioni()
	_inizio_ms = Time.get_ticks_msec()
	_crea_partita()
	_crea_vista()
	hud = preload("res://scenes/hud_partita.tscn").instantiate()
	add_child(hud)
	hud.vista = vista
	hud.gesti = gesti
	var k0: Dictionary = m.teams[0].kit
	var k1: Dictionary = m.teams[1].kit
	hud.imposta_squadre(m.teams[0].short, Minimappa.colore(k0.shirt), m.teams[1].short, Minimappa.colore(k1.shirt))
	hud.pausa_premuta.connect(_mostra_pausa)
	hud.dribbling_premuto.connect(_dribbling)
	hud.riprendi.connect(_riprendi)
	hud.secondo_tempo.connect(_secondo_tempo)
	hud.esci.connect(func() -> void: _finisci(true))
	hud.nuova_partita.connect(_nuova_partita)
	audio = AudioPartita.new()
	add_child(audio)
	audio.folla(FOLLA_BASE)
	hud.big(TITOLO, "", 1800)
	if _opzioni.has("bot"):
		bot = BotDito.new(int(_opzioni.get("seme", "1")) + 99)
	_avvia_prove()


func _crea_partita() -> void:
	var seme := int(_opzioni["seme"]) if _opzioni.has("seme") else randi() % 1000000000
	var tempo := float(_opzioni.get("tempo", str(TEMPO_PREDEFINITO)))
	m = SimMatchScript.new({"seed": seme, "halfLen": tempo, "human": [true, false], "autoGk": [false, false],
		"teams": [Squadre.casa(), Squadre.ospiti()]})
	gesti = Gesti.new()
	gesti.out = Gesti.ComandiPartita.new(m, me)


func _crea_vista() -> void:
	if not _opzioni.has("vista-finta") and ResourceLoader.exists(SCENA_VISTA):
		vista = (load(SCENA_VISTA) as PackedScene).instantiate()
	else:
		vista = VistaFinta.new()
	add_child(vista)
	vista.setup(m, me)
	gesti.vista = vista
	gesti.set_match(m, me)
	gesti.enabled = true
	gesti.dim = get_viewport().get_visible_rect().size


func _exit_tree() -> void:
	if vista != null:
		vista.dispose()
	if m != null:
		m.dispose()


# ---------------------------------------------------------------- ciclo principale (frame() di src/main.js)
func _process(delta: float) -> void:
	if stato != "partita":
		return
	var now := Time.get_ticks_msec()
	_fotogrammi += 1
	var dt := _dt_fisso if _dt_fisso > 0.0 else minf(DT_MAX, delta)
	gesti.dim = get_viewport().get_visible_rect().size
	if paused and bot != null and m.phase == "half":
		_secondo_tempo() # il dito finto preme "Secondo tempo"
	if not paused:
		if bot != null:
			bot.passo(self, now)
		gesti.update(now)
		_passi_motore(dt)
		_eventi()
		_zoom()
		if _fine_ms > 0 and now > _fine_ms:
			_fine_ms = 0
			_finisci(false)
			return
	if now >= _hud_ms:
		_hud_ms = now + HUD_OGNI_MS
		_aggiorna_hud()
	if gesti.drawing or _anteprima_viva:
		hud.aggiorna_anteprima() # anche un fotogramma dopo la fine del disegno, per toglierla
	_anteprima_viva = gesti.drawing
	vista.drawing = gesti.drawing
	var dt_reale := 0.0 if paused else dt
	vista.update_view(0.0 if paused else dt * maxf(ts, 0.25), dt_reale)


## velocità del tempo voluta adesso (rallenty)
func velocita_voluta() -> float:
	var dive: bool = m.diveWin(me) and not m.autoGk[me]
	var duel: bool = m.duelFor(me)
	var zone: bool = not duel and m.inZone(me)
	if gesti.mode == "dpath":
		return DEF_DRAW_SLOW
	if gesti.drawing:
		return RUN_DRAW_SLOW if gesti.run_path() else PASS_DRAW_SLOW
	if dive:
		return GK_SLOW
	if duel:
		return DUEL_SLOW
	if zone:
		return ZONE_SLOW
	return 1.0


func _passi_motore(dt: float) -> void:
	var target := velocita_voluta()
	hud.mostra_dribbling(m.duelFor(me) and not gesti.drawing)
	ts += (target - ts) * minf(1.0, dt * TEMPO_K)
	var sdt := dt * ts * _velocita
	var n := maxi(1, ceili(sdt / PASSO_MAX))
	for i in n:
		m.step(sdt / n)
	hud.rallenty(ts < RALLENTY_SOTTO)
	audio.folla(FOLLA_BASE, AudioPartita.eccitazione(m.ball.y))


# visuale larga senza palla o mentre si disegna (setZoom del web): solo se la vista lo sa fare
func _zoom() -> void:
	if not vista.has_method("set_zoom"):
		return
	var my_restart := m.phase == "restart" and m.restart != null and m.restart.team == me
	var mine := m.ball.owner != null and m.ball.owner.team == me
	vista.set_zoom(1.0 if (gesti.drawing or my_restart or not mine) else (0.5 if m.phase == "restart" else 0.4))


func _aggiorna_hud() -> void:
	hud.aggiorna(m, me)
	# visuale girata col dito: frecce ai lati nel rallenty, la prima volta anche la scritta
	if gesti.cam_used:
		_cam_tip_visto = true
	var on: bool = not paused and not gesti.drawing and VD.user_cam_on(m, me)
	hud.aiuto_visuale(("arr" if _cam_tip_visto else "tip") if on else "")
	var h: String = "duel" if m.duelFor(me) else ("zone" if m.inZone(me) else m.hint(me))
	var txt: String = RHINT.get(m.restart.type, "") if h == "restart" else HINTS.get(h, "")
	var caldo := h == "dive" or (h == "restart" and m.restart.type == "penalty")
	hud.suggerimento(txt, caldo)


# ---------------------------------------------------------------- eventi del motore (events() di src/main.js)
func _eventi() -> void:
	var adv := false
	for e: Dictionary in m.events:
		if e.type == "advantage":
			adv = true
	for e: Dictionary in m.events:
		_evento(e, adv)
	m.events.clear()


func _evento(e: Dictionary, adv: bool) -> void:
	match e.type:
		"kick":
			audio.kick(float(e.get("v", 15.0)))
			var p: R.Player = e.p
			if not e.get("clear", false) and p.team == me and (e.kind == "header" or e.kind == "volley"):
				hud.big("Colpo di testa!" if e.kind == "header" else "Al volo!", "", 900)
		"advantage":
			hud.big("Vantaggio!", "", 1100)
		"advantage_back":
			audio.whistle()
			hud.big("Si torna alla punizione", "", 1300)
		"tackle", "block":
			audio.kick(9.0)
		"dribble":
			var nome := _nome_giochetto(vista.trick(e.p))
			if (e.p as R.Player).team == me:
				hud.big(nome + ("!" if e.ok else ""), "g" if e.ok else "", 1000)
		"goal":
			_gol(e)
		"restart":
			_ripartenza(e)
		"offside":
			hud.big("Fuorigioco", "", 1300)
			audio.whistle()
		"foul":
			_fallo(e, adv)
		"save":
			if not e.get("catch", false):
				hud.big("Parata!", "g" if (e.p as R.Player).team == me else "", 1000)
				audio.ooh()
		"post":
			hud.big("Palo!", "", 1000)
			audio.post()
		"half":
			audio.whistle(true)
			_mostra_intervallo()
		"full":
			audio.whistle(true)
			_fine_ms = Time.get_ticks_msec() + FINE_DOPO_MS


# trick() della vista: il web ritorna {name, ...}; si accetta anche una stringa
static func _nome_giochetto(t: Variant) -> String:
	if t is Dictionary:
		return String((t as Dictionary).get("name", "Dribbling"))
	if t is String:
		return t
	return "Dribbling"


func _gol(e: Dictionary) -> void:
	var chi: String = (e.scorer as R.Player).name if e.scorer != null else "Autogol"
	var piccolo := "%s · %d'" % [chi, e.minute]
	if e.team == me:
		audio.goal()
		hud.big("GOL!", "g", 2600, piccolo)
	else:
		audio.ooh()
		hud.big("Gol subito", "b", 2400, piccolo)


func _ripartenza(e: Dictionary) -> void:
	if e.get("cut", false):
		hud.fade()
	if e.kind == "kickoff" or e.kind == "freekick" or e.kind == "penalty":
		audio.whistle()
	if e.kind == "corner":
		hud.big("Calcio d'angolo", "", 1300)
	elif e.kind == "penalty":
		hud.big("RIGORE!", "g" if e.team == me else "b", 1800)


func _fallo(e: Dictionary, adv: bool) -> void:
	var card: Variant = e.get("card")
	var chi: String = (e.by as R.Player).name if e.by != null else ""
	if adv:
		if card != null:
			hud.big("Espulso!" if card == "red" else "Ammonito", "b", 1500, chi)
		return
	audio.whistle()
	var testo := "Fallo"
	if card == "red":
		testo = "Espulso!"
	elif card == "yellow":
		testo = "Ammonito"
	hud.big(testo, "b" if card != null else "", 1500, chi if card != null else "")


# ---------------------------------------------------------------- tocchi (un dito solo)
func _unhandled_input(event: InputEvent) -> void:
	var giocabile := stato == "partita" and not paused
	var now := Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if giocabile and gesti.dito < 0 and not hud.tocca_hud(e.position):
				gesti.down(e.position, now, e.index)
		else:
			gesti.up(e.position, now, e.index, e.canceled)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		gesti.move_ev(e.position, e.index)


# l'app va in sottofondo (centro di controllo, chiamata): dito annullato e pausa (visibilitychange del web)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if gesti != null:
			gesti.cancel()
		# (nelle prove con schermata no: la finestra di prova può perdere il fuoco per altre finestre del PC)
		if stato == "partita" and m != null and not paused and m.phase != "half" and not _opzioni.has("schermata"):
			_mostra_pausa()


func _dribbling() -> void:
	if stato == "partita" and not paused:
		m.userDribble(me)


# ---------------------------------------------------------------- pausa, intervallo, fine
func _mostra_pausa() -> void:
	if stato != "partita" or paused:
		return
	paused = true
	gesti.cancel()
	hud.mostra_dribbling(false)
	hud.aiuto_visuale("")
	hud.mostra_pausa("Esci dall'amichevole")


func _riprendi() -> void:
	hud.nascondi_overlay()
	paused = false


func _mostra_intervallo() -> void:
	paused = true
	gesti.cancel()
	hud.mostra_dribbling(false)
	hud.mostra_intervallo(m.score[0], m.score[1])


func _secondo_tempo() -> void:
	hud.nascondi_overlay()
	paused = false
	m.startSecondHalf()


func _finisci(forfait: bool) -> void:
	stato = "fine"
	abbandonata = forfait
	gesti.enabled = false
	gesti.cancel()
	audio.folla(0.0)
	hud.mostra_dribbling(false)
	hud.aiuto_visuale("")
	hud.rallenty(false)
	hud.suggerimento("", false)
	hud.mostra_fine(dati_fine())
	if _opzioni.has("esci-a-fine"):
		print(riassunto())
		if not (_opzioni.has("schermata") and _opzioni.has("alla-fine")):
			_esci()


## dati della schermata di fine partita
func dati_fine() -> Dictionary:
	var g0: int = m.score[0]
	var g1: int = m.score[1]
	var marcatori: Array = []
	for g: Dictionary in m.goalsLog:
		marcatori.append([g.team, ("%s %d'" % [g.name, g.minute]) if g.team == 0 else ("%d' %s" % [g.minute, g.name])])
	var st: Dictionary = m.stats
	var poss: Array = st.poss
	var tot: float = maxf(0.001, float(poss[0]) + float(poss[1]))
	var p0 := int(roundf(float(poss[0]) / tot * 100.0))
	return {
		"titolo": TITOLO + (" · abbandonata" if abbandonata else ""),
		"sigle": [m.teams[0].short, m.teams[1].short],
		"colori": [Minimappa.colore(m.teams[0].kit.shirt), Minimappa.colore(m.teams[1].kit.shirt)],
		"gol": [g0, g1],
		"esito": "Vittoria!" if g0 > g1 else ("Sconfitta" if g0 < g1 else "Pareggio"),
		"marcatori": marcatori,
		"statistiche": [["Tiri", st.shots[0], st.shots[1]], ["In porta", st.onT[0], st.onT[1]],
			["Possesso", "%d%%" % p0, "%d%%" % (100 - p0)], ["Angoli", st.corners[0], st.corners[1]],
			["Falli", st.fouls[0], st.fouls[1]], ["Parate", st.saves[0], st.saves[1]]],
	}


func riassunto() -> String:
	var secondi := maxf(0.001, (Time.get_ticks_msec() - _inizio_ms) / 1000.0)
	var testo := "FPS medi %.1f · %s\n" % [_fotogrammi / secondi, HudFase1.testo_memoria()]
	testo += "fine partita %s %d - %d %s · tempo di gioco %.0f s · %s" % [
		m.teams[0].short, m.score[0], m.score[1], m.teams[1].short, m.time, "abbandonata" if abbandonata else ("finita" if stato == "fine" else "in corso")]
	if bot != null:
		testo += "\n" + bot.riassunto()
	return testo


func _esci() -> void:
	audio.ferma()
	# un paio di fotogrammi perché il server audio lasci i suoni fermati (altrimenti restano in memoria all'uscita)
	for i in 3:
		await get_tree().process_frame
	get_tree().quit(0)


func _nuova_partita() -> void:
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- prove da riga di comando
func _leggi_opzioni() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parti := arg.substr(2).split("=", true, 1)
			_opzioni[parti[0]] = parti[1] if parti.size() > 1 else "1"
	if _opzioni.has("veloce"):
		_dt_fisso = 1.0 / 60.0
		_velocita = maxf(0.1, float(_opzioni["veloce"]))


func _avvia_prove() -> void:
	if _opzioni.has("scena"):
		_prepara_scena(_opzioni["scena"])
	if _opzioni.has("schermata"):
		if _opzioni.has("alla-fine"):
			while stato != "fine":
				await get_tree().process_frame
			await get_tree().create_timer(0.6).timeout
		else:
			await get_tree().create_timer(float(_opzioni.get("dopo", "3"))).timeout
		await _salva_schermata(_opzioni["schermata"])
		_esci()
	elif _opzioni.has("esci-dopo"):
		await get_tree().create_timer(float(_opzioni["esci-dopo"])).timeout
		print(riassunto())
		_esci()


func _salva_schermata(percorso: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if percorso.is_relative_path(): # relativo alla cartella del repo (quella che contiene godot/)
		percorso = ProjectSettings.globalize_path("res://").path_join("..").path_join(percorso).simplify_path()
	DirAccess.make_dir_recursive_absolute(percorso.get_base_dir())
	var err := img.save_png(percorso)
	print("schermata %s %dx%d errore=%d" % [percorso, img.get_width(), img.get_height(), err])


## situazioni da fotografare: la partita si mette lì e poi va avanti da sola (col motore vero)
func _prepara_scena(nome: String) -> void:
	await get_tree().create_timer(0.4).timeout
	var att: R.Player = m.team(me)[9]
	match nome:
		"area", "duello", "disegno":
			_metti_in_gioco()
			var y := 8.0 if nome == "duello" else 33.0
			_sposta(att, 4.0, y)
			if nome == "duello":
				_sposta(m.team(1 - me)[3], 4.5, y + 4.5)
			m.ball.owner = att
			m.ball.last = att
			m.ball.x = att.x
			m.ball.y = att.y + 0.6
			m.ctrl[me] = att
			if nome == "disegno":
				_disegno_di_prova(m.team(me)[10])
		"angolo":
			m.setRestart("corner", me, C.HW, C.HL)
		"pausa":
			await get_tree().create_timer(0.8).timeout
			_mostra_pausa()


# dito che disegna un passaggio verso `a` e resta giù (per vedere linea, anteprima e rallenty del disegno)
func _disegno_di_prova(a: R.Player) -> void:
	_sposta(a, -6.0, 40.0)
	await get_tree().create_timer(0.3).timeout
	var s0: Vector3 = vista.world_to_screen(m.ball.x, m.ball.y, 0.3)
	gesti.down(Vector2(s0.x, s0.y), Time.get_ticks_msec())
	for i in range(1, 21):
		var k := float(i) / 20.0
		var s1: Vector3 = vista.world_to_screen(a.x, a.y, 0.0) # la telecamera si muove: il compagno si rilegge
		gesti.move_ev(Vector2(lerpf(s0.x, s1.x, k), lerpf(s0.y, s1.y, k) - sin(k * PI) * 30.0))
		await get_tree().process_frame


func _metti_in_gioco() -> void:
	m.phase = "play"
	m.restart = null
	var b := m.ball
	b.kick = null
	b.shot = null
	b.h = 0.0
	b.vx = 0.0
	b.vy = 0.0
	b.vh = 0.0


func _sposta(p: R.Player, x: float, y: float) -> void:
	p.x = x
	p.y = y
	p.vx = 0.0
	p.vy = 0.0
	p.tx = x
	p.ty = y
	p.fx = 0.0
	p.fy = 1.0 if p.team == 0 else -1.0
	p.state = "play"
	p.stun = 0.0
