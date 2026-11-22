# Flusso dell'app (autoload `App`): carriera corrente, schermate del menu, partita, fine partita e ritorno.
# La scena principale (scenes/app.tscn) chiama App.avvio() al primo fotogramma.
#
# API per i menu:
#   App.carriera                      la Carriera corrente (scripts/carriera/carriera.gd); App.carriera.s == null
#                                     se non c'è ancora una carriera (allora il menu propone di crearne una)
#   App.vai(schermata, arg = null)    mostra scenes/menu/<schermata>.tscn (se manca: segnaposto.tscn). Se la scena
#                                     ha `func apri(arg)` la si chiama subito dopo averla messa in scena; `arg` è anche
#                                     nel meta "arg" del nodo, leggibile già in _ready
#                                     (get_meta("arg") if has_meta("arg") else null: un meta null non viene scritto)
#   App.gioca_campionato()            prossima partita di campionato (Carriera.nextMatch)
#   App.gioca_amichevole(avversario)  amichevole: id di una squadra ("t3"), oppure livello (numero, come il web),
#                                     oppure null (livello della mia squadra)
#   App.allenamento()                 partita di allenamento (avversario debole, senza fine)
#   App.ultimo_esito                  {esito, res, titolo, tipo} dell'ultima partita (anche come arg della schermata)
#   App.clic()                        suono del tocco (api.click del web), se l'audio è acceso
#   App.impostazioni()                applica subito le impostazioni della carriera (api.settings del web):
#                                     audio spento = bus principale muto (menu e partita); musica di sottofondo
#                                     (assets/audio/music.mp3) solo nei menu, con audio e musica accesi.
#                                     Durata, difficoltà, portiere e modo (partita intera / momenti chiave,
#                                     settings.momenti) valgono dalla partita dopo (le legge _partita);
#                                     la vibrazione la legge MenuSchermata._tocco a ogni tocco.
#   segnale schermata_cambiata(nome)
#
# Dopo la partita (risultato registrato al fischio finale, schermata cambiata col tasto "Continua"):
# campionato → Carriera.finishMatch + Carriera.dopoPartita (derby, crescita del campione, forma e infortuni,
# obiettivo a fine stagione) e schermata "dopo_partita" (arg = ultimo_esito, con res.season a fine stagione); amichevole finita → "dopo_partita" (res = null); amichevole abbandonata e
# allenamento → "hub" (casa della carriera, salvata). L'app che va in sottofondo salva subito.
#
# Prove da riga di comando (dopo "--"):
#   le opzioni della partita (--bot, --scena, --schermata, --veloce, --seme, --tempo, --vista-finta, --esci-a-fine,
#   --partita) senza --app fanno partire subito la partita di prova, come prima della fase 3;
#   --app forza il flusso dell'app; --salvataggio=user://altro.json usa un altro file;
#   --stagione-bot, --app-schermate=CARTELLA, --prova-uscite: vedi scripts/app_prove.gd; --esci-dopo=SEC esce dopo SEC secondi.
extends Node

signal schermata_cambiata(nome: String)

const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const ProveApp := preload("res://scripts/app_prove.gd")
const AudioPartita := preload("res://scripts/partita/audio_partita.gd")
const Meteo := preload("res://scripts/partita/meteo.gd")
const MUSICA := "res://assets/audio/music.mp3"
const MUSICA_VOLUME := 0.35     # come Sfx.music del web (gain 0,35)
const CLIC_HZ := 520.0          # tocco: come Sfx.click del web (triangolo 520 Hz, 0,05 s, volume 0,12)
const CLIC_DURATA := 0.05
const CLIC_VOLUME := 0.12
const SCENA_PARTITA := "res://scenes/partita.tscn"
const DIR_MENU := "res://scenes/menu/"
const SEGNAPOSTO := "res://scenes/menu/segnaposto.tscn"
const PRINCIPALE := "principale"
const DOPO_PARTITA := "dopo_partita"
const OPZIONI_PARTITA := ["bot", "scena", "schermata", "esci-a-fine", "veloce", "vista-finta", "seme", "tempo", "partita"]
const ALLENAMENTO_TEMPO := 99999.0  # l'allenamento non finisce da solo (come il web)
const AVVERSARIO_ALLENAMENTO := {"name": "Allenamento", "short": "ALL", "rating": 40, "seed": 7}

var carriera: CarrieraScript
var schermata := ""
var partita: Node = null        # la scena della partita in corso (scripts/partita/gioco.gd)
var ultimo_esito := {}
var opzioni := {}               # opzioni da riga di comando

var _avviata := false
var _clic: AudioStreamPlayer
var _musica: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parti := arg.substr(2).split("=", true, 1)
			opzioni[parti[0]] = parti[1] if parti.size() > 1 else "1"
	carriera = CarrieraScript.new()
	if opzioni.has("salvataggio"):
		carriera.percorso = opzioni.salvataggio
	carriera.load()
	_prepara_audio()
	# a ogni cambio di schermata: musica sì/no (niente nella partita) e impostazioni di una carriera appena
	# creata o cancellata
	schermata_cambiata.connect(func(_nome: String) -> void: impostazioni())


## primo avvio (da scenes/app.tscn): menu principale, oppure subito la partita di prova se ci sono le sue opzioni
func avvio() -> void:
	if _avviata:
		return
	_avviata = true
	impostazioni()
	if opzioni.has("esci-dopo"):
		var t0 := Time.get_ticks_msec()
		var f0 := Engine.get_process_frames()
		get_tree().create_timer(float(opzioni["esci-dopo"])).timeout.connect(func() -> void:
			var secondi := maxf(0.001, (Time.get_ticks_msec() - t0) / 1000.0)
			print("FPS medi %.1f · schermata %s" % [(Engine.get_process_frames() - f0) / secondi, schermata]) # la build lo cerca
			get_tree().quit(0))
	if not opzioni.has("app") and OPZIONI_PARTITA.any(func(k: String) -> bool: return opzioni.has(k)):
		_metti((load(SCENA_PARTITA) as PackedScene).instantiate()) # partita di prova: parte da sola
		schermata = "partita"
		return
	if opzioni.has("stagione-bot") or opzioni.has("app-schermate") or opzioni.has("prova-uscite"):
		add_child(ProveApp.new())
	vai(PRINCIPALE)


## mostra una schermata del menu (scenes/menu/<nome>.tscn); se non esiste ancora, il segnaposto
func vai(nome: String, arg: Variant = null) -> void:
	var percorso := DIR_MENU + nome + ".tscn"
	if not ResourceLoader.exists(percorso):
		percorso = SEGNAPOSTO
	var n: Node = (load(percorso) as PackedScene).instantiate()
	if arg != null:
		n.set_meta("arg", arg)
	n.set_meta("schermata", nome)
	_metti(n)
	partita = null
	schermata = nome
	if n.has_method("apri"):
		n.apri(arg)
	schermata_cambiata.emit(nome)


func gioca_campionato() -> void:
	if not _ha_carriera():
		return
	var nm: Variant = carriera.nextMatch()
	if nm == null:
		vai(PRINCIPALE)
		return
	var derby := carriera.isDerby(nm.opp)
	var titolo := ("Derby · " if derby else "") + "Giornata %d · %s" % [nm.day, CarrieraScript.DIV_NAMES[nm.div]]
	# stadio (taglio e manto dell'erba) della squadra di casa: in casa il mio, fuori quello dell'avversario
	var stadio: Variant = carriera.s.get("seed") if nm.home else nm.opp.get("seed")
	_partita("campionato", carriera.avversarioPartita(nm.opp), titolo, float(carriera.s.settings.half), stadio, derby,
		Meteo.per_giornata(int(carriera.s.get("seed", 0)), int(carriera.s.get("season", 1)), int(nm.day)))


## avversario: id di una squadra del campionato, oppure livello (numero), oppure null = livello della mia squadra
func gioca_amichevole(avversario: Variant = null) -> void:
	if not _ha_carriera():
		return
	var t: Dictionary
	if avversario is String and carriera.team(avversario) != null:
		t = carriera.team(avversario)
	else:
		var lvl: float = float(avversario) if (avversario is int or avversario is float) else float(carriera.myRating())
		t = {"name": "Amichevole", "short": "AMI", "kit": _kit_avversario(), "rating": lvl, "seed": randi() % 1000000000}
	_partita("amichevole", carriera.avversarioPartita(t), "Amichevole", float(carriera.s.settings.half))


func allenamento() -> void:
	if not _ha_carriera():
		return
	var t := AVVERSARIO_ALLENAMENTO.duplicate()
	t["kit"] = _kit_avversario()
	_partita("allenamento", carriera.avversarioPartita(t), "Allenamento guidato", ALLENAMENTO_TEMPO)


func _kit_avversario() -> int:
	return (int(carriera.s.kit) + 4) % CarrieraScript.KITS.size()


func _ha_carriera() -> bool:
	if carriera.s == null:
		push_warning("App: nessuna carriera, prima crearne una (App.carriera.create)")
		vai(PRINCIPALE)
		return false
	return true


# stadio_seme: seme della squadra di casa (taglio e manto dell'erba); null = a caso col seme della partita
# meteo: {meteo, ora} previsti (campionato: gli stessi dell'hub); vuoto = a caso col seme della partita
func _partita(tipo: String, avversario: Dictionary, titolo: String, durata: float, stadio_seme: Variant = null, derby := false, meteo := {}) -> void:
	if schermata == "partita":
		return # doppio tocco sul tasto: la partita sta già partendo
	var s: Dictionary = carriera.s
	# squadraPartita: niente infortunati, chi è giù di forma parte stanco
	var opz := {"squadra_a": carriera.squadraPartita(), "squadra_b": avversario, "me": 0, "tipo": tipo,
		"durata_tempo": durata, "seme": randi() % 1000000000, "titolo": titolo, "autoGk": bool(s.settings.autoGk),
		"derby": derby, "momenti": tipo != "allenamento" and bool(s.settings.get("momenti", false))}
	if stadio_seme is int or stadio_seme is float:
		opz["stadio_seme"] = int(stadio_seme)
	opz.merge(meteo)
	s.tut = int(s.get("tut", 0)) + 1 # partite iniziate (come il web)
	carriera.save()
	var scena: Node = (load(SCENA_PARTITA) as PackedScene).instantiate()
	scena.avvia(opz)
	scena.finita.connect(_fine_partita.bind(titolo))
	scena.continua.connect(_continua)
	_metti(scena)
	partita = scena
	schermata = "partita"
	schermata_cambiata.emit("partita")


# fischio finale o "Esci": il risultato si registra subito; la schermata cambia con "Continua" (o subito se si esce)
func _fine_partita(esito: Dictionary, titolo: String) -> void:
	var tipo: String = esito.tipo
	if tipo == "allenamento":
		if esito.get("completato", false): # allenamento finito (come il web: tutDone)
			carriera.s.tutDone = true
		carriera.save() # anche se saltato: la carriera appena creata resta salvata
		# dopo il tutorial si va alla casa della carriera, non al titolo con "Nuova carriera" (Luis 2026-11-21)
		ultimo_esito = {}
		vai("hub" if carriera.s != null else PRINCIPALE)
		return
	if tipo == "amichevole" and esito.abbandonata:
		ultimo_esito = {}
		vai(PRINCIPALE)
		return
	var res: Variant = null
	if tipo == "campionato":
		var me: int = esito.me
		var mie: int = esito.gol_a if me == 0 else esito.gol_b
		var loro: int = esito.gol_b if me == 0 else esito.gol_a
		res = carriera.finishMatch(mie, loro, _marcatori_per_me(esito.marcatori, me))
		if (res as Dictionary).is_empty(): # nessuna partita da registrare (calendario finito o rotto)
			res = null
		else:
			res = carriera.dopoPartita(res, esito)
	ultimo_esito = {"esito": esito, "res": res, "titolo": titolo + (" · abbandonata" if esito.abbandonata else ""), "tipo": tipo}
	if esito.abbandonata:
		_continua()


func _continua() -> void:
	if schermata != "partita":
		return
	if ultimo_esito.is_empty():
		vai(PRINCIPALE)
	else:
		vai(DOPO_PARTITA, ultimo_esito)


# finishMatch conta i gol della squadra 0: se la persona fosse la squadra 1 si girano
static func _marcatori_per_me(log: Array, me: int) -> Array:
	if me == 0:
		return log
	return log.map(func(g: Dictionary) -> Dictionary:
		var c := g.duplicate()
		c.team = 1 - int(g.team)
		return c)


# sostituisce la scena corrente con `n`
func _metti(n: Node) -> void:
	var albero := get_tree()
	var vecchia := albero.current_scene
	albero.root.add_child(n)
	albero.current_scene = n
	if vecchia != null and vecchia != n:
		vecchia.queue_free()


# ---------------------------------------------------------------- suoni dei menu e impostazioni
func _prepara_audio() -> void:
	_clic = AudioStreamPlayer.new()
	_clic.name = "Clic"
	add_child(_clic)
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	_musica.volume_db = linear_to_db(MUSICA_VOLUME)
	add_child(_musica)
	if DisplayServer.get_name() == "headless":
		return # senza schermo (prove, build) niente suoni, come audio_partita.gd
	_clic.stream = AudioPartita.tono_triangolo(CLIC_HZ, CLIC_DURATA, CLIC_VOLUME)
	if ResourceLoader.exists(MUSICA):
		var m: AudioStream = (load(MUSICA) as AudioStream).duplicate()
		if m is AudioStreamMP3:
			(m as AudioStreamMP3).loop = true
		_musica.stream = m


## suono breve a ogni tocco nei menu (api.click del web)
func clic() -> void:
	if _clic != null and _clic.stream != null and _impostazione("sound"):
		_clic.play()


## applica subito le impostazioni (api.settings del web); la chiamano la schermata Impostazioni dopo ogni scelta,
## l'avvio e ogni cambio di schermata
func impostazioni() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not _impostazione("sound"))
	if _musica == null:
		return
	var suona := _musica.stream != null and _impostazione("sound") and _impostazione("music") 		and schermata != "" and schermata != "partita"
	if suona and not _musica.playing:
		_musica.play()
	elif not suona and _musica.playing:
		_musica.stop()


# impostazione della carriera (accese se mancano o se la carriera non c'è ancora: come SETTINGS_DEFAULT)
func _impostazione(chiave: String) -> bool:
	if carriera == null or carriera.s == null:
		return true
	var st: Variant = carriera.s.get("settings")
	return bool(st.get(chiave, true)) if st is Dictionary else true


# a fine programma si fermano i suoni (un suono ancora in corso resterebbe in memoria)
func _exit_tree() -> void:
	for p: AudioStreamPlayer in [_clic, _musica]:
		if p != null:
			p.stop()
			p.stream = null
	# e si lasciano le risorse grafiche condivise (variabili static): sul Mac della build, senza, a fine programma
	# uno shader risultava "leaked" (2026-11-22) e la prova della build falliva
	load("res://scripts/giocatore.gd").libera_condivisi()
	load("res://scripts/partita/capelli.gd").libera_condivisi()


# l'app va in sottofondo o si chiude: si salva subito
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if carriera != null and carriera.s != null:
			carriera.save()
