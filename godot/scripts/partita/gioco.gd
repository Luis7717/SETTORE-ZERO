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
#   --scena=area|duello|fuga|angolo|rinvio|rilancio|pausa|gol|curva|prima   mette la partita in una situazione da fotografare (gol: tiro a
#                       porta vuota, per vedere cronaca e replay)
#   --scena=fuori_lato|fuori_fondo|fuori_fondo_vicino|fuori_angolo   pallone che esce: scena della ripresa (sim/riprese.gd),
#                       rimessa, rinvio col raccattapalle, rinvio col pallone vicino, calcio d'angolo
#   --esultanza=ID      con --scena=gol chi segna è il campione e fa quell'esultanza (id in esultanze.gd)
#   --senza-replay      dopo il gol niente replay (si va subito al calcio d'inizio)
#   --replay=porta|lato visuale del replay del gol (predefinito: a caso)
#   --schermata=PERCORSO.png [--dopo=SEC] [--alla-fine]   schermata dopo SEC secondi veri, o alla fine partita
#   --ogni=SEC          con --schermata: una schermata ogni SEC secondi veri (PERCORSO_01.png, _02, ...) fino a --dopo
#   --esci-dopo=SEC     esce dopo SEC secondi veri
#   --campo=NOME        taglio dell'erba (strisce, strette, verticali, quadrotti, cerchi, uniforme, rombi, raggi, diagonali)
#   --manto=NOME        colore dell'erba (vivo, milano, naturale, sintetico, sintetico_chiaro, estivo)
#   --meteo=sereno|nuvoloso|pioggia|neve  --ora=giorno|tramonto|notte   forzano meteo e ora (scripts/partita/meteo.gd)
#   --momenti           momenti chiave: ~10 azioni giocate, il resto simulato (scripts/partita/momenti_regia.gd)
#   --allenamento       allenamento guidato (tipo "allenamento", scripts/partita/allenamento.gd) invece dell'amichevole;
#                       con --lezione=N [--prova=K] parte da lì, con --scheda mostra la scheda della lezione N
#   --prove=tiri|punizioni|rigori   allenamento libero a punti (tipo "prove", scripts/partita/prove_tiro_regia.gd)
#
# Dall'app (scripts/app.gd): chi crea la scena chiama `avvia(opz)` prima di aggiungerla o entro il primo fotogramma,
# con opz = {squadra_a, squadra_b, me, tipo: "campionato"|"amichevole"|"allenamento", durata_tempo, seme,
# titolo (facoltativo), autoGk (facoltativo), stadio_seme (facoltativo: seme della squadra di casa, sceglie taglio e
# manto dell'erba; senza, vengono dal seme della partita), derby (facoltativo: partita contro la rivale, pubblico più
# rumoroso), momenti (facoltativo: momenti chiave)}; `--campo=<nome>`/`--manto=<nome>` li forzano per le prove; squadre come Carriera.squadraPartita()/aiMatchTeam() (kit compreso).
# Al fischio finale (la schermata di fine resta sopra) o se si esce dalla pausa la scena emette `finita(esito)` con
# {gol_a, gol_b, marcatori, statistiche, abbandonata, tipo, me, derby, conteggi, tabellino}; conteggi = per giocatore della
# persona (scripts/partita/conta_giocatori.gd), tabellino = dati della schermata delle statistiche (stesso file); "Esci" in campionato = sconfitta 0-3 a tavolino.
# Il tasto "Continua" della schermata di fine emette poi `continua` (chi ha avviato la partita cambia schermata).
# Così il risultato si registra subito, anche se l'app viene chiusa sulla schermata di fine (come il web).
# Se nessuno chiama avvia, la partita parte da sola con le squadre di prova (come prima, per le prove).
extends Node

signal finita(esito: Dictionary)
signal continua

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
const Allenamento := preload("res://scripts/partita/allenamento.gd")
const AllenamentoHud := preload("res://scripts/partita/allenamento_hud.gd")
const BotAllenamento := preload("res://scripts/partita/bot_allenamento.gd")
const ProveRegia := preload("res://scripts/partita/prove_tiro_regia.gd")
const Tagli := preload("res://scripts/tagli_campo.gd")
const ContaGiocatori := preload("res://scripts/partita/conta_giocatori.gd")
const EsultanzaRegia := preload("res://scripts/partita/esultanza_regia.gd")
const Replay := preload("res://scripts/partita/replay.gd")
const Cronaca := preload("res://scripts/partita/cronaca.gd")
const CronacaVista := preload("res://scripts/partita/cronaca_vista.gd")
const Meteo := preload("res://scripts/partita/meteo.gd")
const TifoEventi := preload("res://scripts/partita/tifo_eventi.gd")
const FermatempoTesta := preload("res://scripts/partita/fermatempo_testa.gd")
const MomentiRegia := preload("res://scripts/partita/momenti_regia.gd")
const Momenti := preload("res://scripts/partita/momenti.gd")
const SCENA_VISTA := "res://scenes/vista_partita.tscn"

# velocità del tempo (rallenty), come src/main.js
const GK_SLOW := 0.1          # mentre si para
const DEF_DRAW_SLOW := 0.13   # mentre si disegna una linea di difesa
const PASS_DRAW_SLOW := 0.04  # mentre si disegna un passaggio o un tiro
const DUEL_SLOW := 0.08       # duello col difensore
const FLEE_SLOW := 0.08       # fuga: avversario alla pari o alle spalle, tasto Scatto
const ZONE_SLOW := 0.1        # area di tiro (ultimi 20 m prima della porta avversaria)
const SCENA_VELOCE := 3.0     # scena della ripresa (sim/riprese.gd) dopo un tocco: va tanto più veloce
const TEMPO_K := 14.0         # 1/s: il tempo passa dolcemente da una velocità all'altra
const DT_MAX := 0.05          # fotogramma più lungo considerato (s)
const PASSO_MAX := 1.0 / 60.0 # passo del motore: il tempo del fotogramma si divide in passi non più lunghi di così
const RALLENTY_SOTTO := 0.6   # sotto questa velocità del tempo si vede il bordo scuro del rallenty
const HUD_OGNI_MS := 100
const FINE_DOPO_MS := 1500    # dal fischio finale alla schermata di fine partita
const TEMPO_PREDEFINITO := 150.0
const FOLLA_BASE := 0.16
const TITOLO := "Amichevole"

var m: SimMatchScript = null
var me := 0
var stato := "attesa"         # "attesa" (prima di partire), "partita" o "fine"
var paused := false
var ts := 1.0                 # velocità del tempo attuale (1 = normale)
var gesti: Gesti
var vista = null              # PartitaVista (vera) o vista finta: senza tipo, si chiamano i metodi del contratto
var hud: HudPartita
var audio: AudioPartita
var bot: BotDito = null
var abbandonata := false
var conta: ContaGiocatori = null  # conteggi per giocatore (carriera: crescita del campione)
var esultanza: EsultanzaRegia = null  # esultanza del campione dopo un suo gol (esultanza_regia.gd)
var replay: Replay = null     # replay del gol (null in allenamento o con --senza-replay)
var cronaca: Cronaca = null   # cronaca scritta (null in allenamento)
var cronaca_vista: CronacaVista = null
var tifo_eventi := TifoEventi.new()   # fatti del motore → pubblico 3D e cori (occasione, parata, palo, fischio)
var momenti: MomentiRegia = null  # momenti chiave (avvio.momenti o --momenti): si giocano ~10 azioni, il resto è simulato
var _festa_finita := false    # il motore ha finito la festa del gol ed è trattenuto (aspetta esultanza e replay)
var _esultanza_in_corso := false

var _opzioni := {}
var _avvio := {}              # opzioni di avvia() (vuoto = partita di prova da sola)
var _finita_emessa := false
var _fine_ms := 0
var _hud_ms := 0
var _cam_tip_visto := false   # la scritta della visuale si mostra finché non la si gira una volta (web: career.s.camTip)
var _velocita := 1.0
var _dt_fisso := 0.0
var _fotogrammi := 0
var _anteprima_viva := false
var _inizio_ms := 0
var _seme_partita := 0
var _testa_reale := -1.0       # secondi veri dall'apertura del fermatempo del colpo di testa (−1 = chiuso)
var _scena_veloce := false     # un tocco durante la scena della ripresa la fa andare più veloce (fino alla fine)
var meteo := {"meteo": "sereno", "ora": "giorno"}  # scripts/partita/meteo.gd: avvio.meteo/ora o a caso col seme


## avvio dall'app: da chiamare prima di aggiungere la scena all'albero o entro il primo fotogramma
func avvia(opz: Dictionary) -> void:
	if stato != "attesa":
		push_warning("gioco.avvia: la partita è già partita, opzioni ignorate")
		return
	_avvio = opz.duplicate()


## taglio dell'erba (scripts/tagli_campo.gd) per le opzioni di avvia(): lo stadio della squadra di casa
## (opz.stadio_seme, lo mette l'app in campionato), altrimenti a caso col seme della partita
static func taglio_campo(opz: Dictionary, seme_partita: int) -> int:
	if opz.has("stadio_seme"):
		return Tagli.da_seme(int(opz.stadio_seme))
	return Tagli.da_seme(seme_partita)


## manto dell'erba (colore, tipo d'erba): come il taglio, dallo stadio di casa o dal seme della partita
static func manto_campo(opz: Dictionary, seme_partita: int) -> int:
	return Tagli.manto_da_seme(int(opz.stadio_seme) if opz.has("stadio_seme") else seme_partita)


## momenti chiave: opzione "momenti" dell'avvio (impostazione della carriera) o --momenti nelle prove; mai in allenamento
func con_momenti() -> bool:
	return tipo() != "allenamento" and (bool(_avvio.get("momenti", false)) or _opzioni.has("momenti"))


func avviata_da_app() -> bool:
	return not _avvio.is_empty()


func tipo() -> String:
	if _opzioni.has("allenamento"): # prova da riga di comando
		return "allenamento"
	if _opzioni.has("prove"):
		return "prove"
	return String(_avvio.get("tipo", "amichevole"))


func _ready() -> void:
	_leggi_opzioni()
	if _avvio.is_empty():
		await get_tree().process_frame # chi ha creato la scena può ancora chiamare avvia()
	_parti()


func _parti() -> void:
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
	hud.esci.connect(_esci_dalla_pausa)
	hud.nuova_partita.connect(_nuova_partita)
	audio = AudioPartita.new()
	add_child(audio)
	esultanza = EsultanzaRegia.new()
	add_child(esultanza)
	esultanza.finita.connect(_esultanza_finita)
	audio.folla(FOLLA_BASE)
	var derby := _segna_derby()
	if tipo() == "allenamento":
		_avvia_allenamento()
	elif tipo() == "prove": # allenamento libero: tiri, punizioni, rigori a punti
		prove = ProveRegia.new()
		add_child(prove)
		prove.avvia(self)
	elif derby:
		hud.big("DERBY!", "g", 2400, _titolo() + "
" + Meteo.testo(meteo))
	else:
		hud.big(_titolo(), "", 2200, Meteo.testo(meteo))
	_crea_replay_e_cronaca()
	if con_momenti():
		momenti = MomentiRegia.new(self)
		add_child(momenti)
	stato = "partita"
	if _opzioni.has("bot") and prove == null: # nell'allenamento libero tira la regia
		var seme_bot := int(_opzioni.get("seme", "1")) + 99
		bot = BotAllenamento.new(seme_bot) if allenamento != null else BotDito.new(seme_bot)
	_avvia_prove()


func _crea_partita() -> void:
	var seme := int(_opzioni["seme"]) if _opzioni.has("seme") else randi() % 1000000000
	var tempo := float(_opzioni.get("tempo", str(TEMPO_PREDEFINITO)))
	var squadre: Array = [Squadre.casa(), Squadre.ospiti()]
	if avviata_da_app():
		me = int(_avvio.get("me", 0))
		squadre = [_avvio.squadra_a, _avvio.squadra_b]
		seme = int(_avvio.get("seme", seme))
		if not _opzioni.has("tempo"): # --tempo vince anche dall'app (prove veloci)
			tempo = float(_avvio.get("durata_tempo", TEMPO_PREDEFINITO))
	_seme_partita = seme
	if con_momenti(): # orologio lento: un'azione di 20 s di gioco dura un minuto
		tempo = Momenti.HALF_LEN
	var auto_gk: bool = _avvio.get("autoGk", false)
	meteo = Meteo.per_partita(_avvio, _opzioni, seme, tipo() == "allenamento" or tipo() == "prove")
	m = SimMatchScript.new({"seed": seme, "halfLen": tempo, "human": [me == 0, me == 1],
		"autoGk": [auto_gk and me == 0, auto_gk and me == 1], "teams": squadre, "meteo": meteo.meteo, "testa": true, "rifiniture": true,
		# lezioni e prove di tiro: il tiratore non parte da solo e le riprese restano immediate
		"portaAuto": tipo() != "allenamento" and tipo() != "prove", "riprese": tipo() != "allenamento" and tipo() != "prove"})
	if tipo() == "allenamento":
		tempo = Allenamento.HALF_LEN
		if not avviata_da_app():
			squadre[1] = Allenamento.squadra_ospite()
	gesti = Gesti.new()
	gesti.out = Gesti.ComandiPartita.new(m, me)
	conta = ContaGiocatori.new(me)


func _crea_vista() -> void:
	if not _opzioni.has("vista-finta") and ResourceLoader.exists(SCENA_VISTA):
		vista = (load(SCENA_VISTA) as PackedScene).instantiate()
	else:
		vista = VistaFinta.new()
	add_child(vista)
	vista.setup(m, me)
	if vista.has_method("set_taglio"):
		vista.set_taglio(taglio_campo(_avvio, _seme_partita))
	if vista.has_method("set_manto"):
		vista.set_manto(manto_campo(_avvio, _seme_partita))
	if vista is Node3D:
		var nodo_meteo := Meteo.new()
		nodo_meteo.name = "Meteo"
		add_child(nodo_meteo)
		nodo_meteo.applica(vista, meteo)
	gesti.vista = vista
	gesti.set_match(m, me)
	gesti.enabled = true
	gesti.dim = get_viewport().get_visible_rect().size


func _exit_tree() -> void:
	if vista != null:
		vista.dispose()
	if m != null:
		m.dispose()
	# partita aperta da sola (prova della build, scena di prova): nessuna App lascia le risorse grafiche condivise a
	# fine programma, lo fa la partita (sul Mac della build, senza, uno shader risulta "leaked", 2026-11-23)
	if not avviata_da_app():
		load("res://scripts/giocatore.gd").libera_condivisi()
		load("res://scripts/partita/capelli.gd").libera_condivisi()


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
	elif paused and bot != null and _all_hud != null and _all_hud.scheda_aperta():
		_all_hud.premi_prova() # ... e "Prova (3 volte)" sulla scheda dell'allenamento
	if replay != null and replay.attivo(): # replay del gol: motore fermo, la vista rigioca gli ultimi secondi
		if not paused:
			replay.fotogramma(m, vista, dt * _velocita)
		return
	if not paused:
		if bot != null:
			bot.passo(self, now)
		gesti.update(now)
		_passi_motore(dt)
		_eventi()
		_cerchio_testa()
		if replay != null:
			replay.registra(m)
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
	esultanza.aggiorna(dt_reale, m)
	vista.update_view(0.0 if paused else dt * maxf(ts, 0.25), dt_reale)
	esultanza.camera(vista)


## fermatempo del colpo di testa (sim/testa.gd, Luis 2026-11-23): il tempo si ferma del tutto per
## FermatempoTesta.TESTA_FERMATEMPO_S secondi veri. Linea disegnata = tempo normale subito (il colpo parte appena il
## pallone arriva); secondi finiti senza linea = pallone perso (ma se il dito sta ancora disegnando si aspetta che lo
## alzi). Restituisce la velocità del tempo (0 = fermo, 1 = normale) o −1 senza fermatempo.
func _velocita_testa(dt: float) -> float:
	var hw = m.headWin
	if hw == null or hw.team != me or hw.lost:
		_testa_reale = -1.0
		return -1.0
	if hw.aimed:
		_testa_reale = -1.0
		return 1.0
	if _testa_reale < 0.0:
		_testa_reale = 0.0
	else:
		_testa_reale += dt
	if FermatempoTesta.fermo(_testa_reale, false) or gesti.mode == "head":
		return 0.0
	m.headExpire()
	_testa_reale = -1.0
	return 1.0


## cerchio che si svuota intorno a chi deve colpire di testa
func _cerchio_testa() -> void:
	if not m.headFor(me) or _testa_reale < 0.0:
		hud.cerchio_testa(Vector2.ZERO, -1.0)
		return
	var p: R.Player = m.headWin.p
	var s: Vector3 = vista.world_to_screen(p.x, p.y, 1.0)
	if s.z < 0.5:
		hud.cerchio_testa(Vector2.ZERO, -1.0)
		return
	hud.cerchio_testa(Vector2(s.x, s.y), FermatempoTesta.frazione(_testa_reale))


## velocità del tempo voluta adesso (rallenty)
func velocita_voluta() -> float:
	var dive: bool = m.diveWin(me) and not m.autoGk[me]
	# dribbling prenotato: il portatore corre verso il difensore a tempo normale (duel.gd → dribBookStep)
	var booked: bool = m.dribBooked(me)
	var duel: bool = not booked and m.duelFor(me)
	var flee: bool = not duel and m.fleeFor(me)
	var zone: bool = not booked and not duel and not flee and m.inZone(me)
	if gesti.mode == "dpath":
		return DEF_DRAW_SLOW
	if gesti.drawing:
		return PASS_DRAW_SLOW # col pallone ogni linea è un passaggio o un tiro (niente più strada da correre)
	if dive:
		return GK_SLOW
	if duel:
		return DUEL_SLOW
	if flee:
		return FLEE_SLOW
	if zone:
		return ZONE_SLOW
	return 1.0


func _passi_motore(dt: float) -> void:
	var target := velocita_voluta()
	var flee: bool = not m.duelFor(me) and m.fleeFor(me)
	# toccato Dribbling il tasto sparisce: la prenotazione è partita, il dribbling scatta vicino al difensore
	# nella lezione del passaggio il tasto non c'è (Luis 2026-11-21): lì si impara solo a disegnare il passaggio
	var tasto_ok := allenamento == null or allenamento.finished or String(allenamento.lesson().get("id", "")) != "passaggio"
	hud.mostra_dribbling(tasto_ok and ((m.duelFor(me) and not m.dribBooked(me)) or flee) and not gesti.drawing, flee)
	var testa := _velocita_testa(dt)
	if testa >= 0.0:
		ts = testa # fermatempo del colpo di testa: fermo o normale, niente passaggio dolce
	else:
		ts += (target - ts) * minf(1.0, dt * TEMPO_K)
	var sdt := dt * ts * _velocita
	if _scena_veloce:
		if in_scena():
			sdt *= SCENA_VELOCE
		else:
			_scena_veloce = false
	var n := maxi(1, ceili(sdt / PASSO_MAX)) if sdt > 0.0 else 0 # tempo fermo (colpo di testa): nessun passo
	if allenamento != null:
		allenamento.before()
	if prove != null:
		prove.before()
	for i in n:
		if replay != null and replay.trattieni(m, sdt / n): # fine della festa del gol: motore fermo
			break
		m.step(sdt / n)
	if replay != null and replay.festa_finita():
		_fine_festa_gol()
	if momenti != null:
		momenti.dopo_passi(sdt)
	if allenamento != null:
		_allenamento_dopo(sdt)
	if prove != null:
		prove.after(sdt)
	hud.rallenty(ts < RALLENTY_SOTTO)
	audio.folla(FOLLA_BASE, AudioPartita.eccitazione(m.ball.y))


## scena della ripresa in corso (sim/riprese.gd): il battitore va a prendere il pallone, la rincorsa del calcio
func in_scena() -> bool:
	return m != null and m.phase == "restart" and m.restart != null and (m.restart.scena != "" or m.restart.pend != null)


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
	var on: bool = allenamento == null and prove == null and not paused and not gesti.drawing and VD.user_cam_on(m, me)
	hud.aiuto_visuale(("arr" if _cam_tip_visto else "tip") if on else "")
	# niente suggerimenti in basso (Luis 2026-11-22: "la telecronaca è ok, togli i suggerimenti in basso"): in partita
	# parla la cronaca in alto, in allenamento il riquadro in alto con la spiegazione di ogni lezione


# ---------------------------------------------------------------- eventi del motore (events() di src/main.js)
func _eventi() -> void:
	conta.leggi(m)
	var adv := false
	for e: Dictionary in m.events:
		if e.type == "advantage":
			adv = true
	for e: Dictionary in m.events:
		_evento(e, adv)
		tifo_eventi.applica(e, vista, audio)
		if cronaca != null:
			cronaca_vista.mostra(cronaca.leggi(e, Time.get_ticks_msec() / 1000.0), e.type == "goal")
	m.events.clear()


func _evento(e: Dictionary, adv: bool) -> void:
	match e.type:
		"kick":
			audio.kick(float(e.get("v", 15.0)))
			var p: R.Player = e.p
			if not e.get("clear", false) and p.team == me and (e.kind == "header" or e.kind == "volley"):
				if e.get("sponda", false):
					hud.big("Sponda!", "", 800)
				else:
					hud.big("Colpo di testa!" if e.kind == "header" else "Al volo!", "", 900)
		"head_win":
			if int(e.team) == me:
				gesti.cancel() # una linea a metà (es. difesa) non vale: ora si disegna il colpo di testa
		"advantage":
			hud.big("Vantaggio!", "", 1100)
		"advantage_back":
			audio.whistle()
			hud.big("Si torna alla punizione", "", 1300)
		"tackle", "block":
			audio.kick(9.0)
		"burst": # tasto Scatto nella fuga: niente giochetto, solo suono e scritta
			if (e.p as R.Player).team == me:
				audio.kick(6.0)
				hud.big("Scatto!", "g", 800)
		"dribble":
			# il giochetto va dal lato scelto dal motore (e.side: +1 = sinistra del portatore)
			var nome := _nome_giochetto(vista.trick(e.p, -1.0, float(e.get("side", 0.0))))
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
	if prove != null: # allenamento libero: l'esito (GOL! +punti) lo scrive già il riquadro delle prove
		audio.goal()
	elif e.team == me:
		audio.goal()
		hud.big("GOL!", "g", 2600, piccolo)
	else:
		audio.ooh()
		hud.big("Gol subito", "b", 2400, piccolo)
	# gol del campione: la sua esultanza parte subito, durante la festa del motore; il replay aspetta che finisca
	_festa_finita = false
	_esultanza_in_corso = allenamento == null and prove == null and esultanza.avvia(e, m, me, vista)
	if replay != null:
		replay.gol(m)


# ---------------------------------------------------------------- dopo il gol: esultanza → replay → calcio d'inizio
# Il motore fa la sua festa (fase "goal", 3,2 s di gioco); quando il passo dopo farebbe il calcio d'inizio,
# replay.trattieni() lo tiene fermo lì e si arriva qui, una volta per gol.
# Esultanza del campione (esultanza_regia.gd): parte all'evento "goal" (in _gol) e dura circa quanto la festa; se a
# questo punto non è ancora finita, il motore resta fermo finché non finisce (o la si salta col tocco), poi il replay.
func _fine_festa_gol() -> void:
	_festa_finita = true
	_forse_replay()


# fine (o tocco) dell'esultanza del campione
func _esultanza_finita() -> void:
	_esultanza_in_corso = false
	_forse_replay()


func _forse_replay() -> void:
	if not _festa_finita or _esultanza_in_corso:
		return
	_festa_finita = false
	dopo_esultanza()


## dopo l'esultanza (o subito, se non c'è): parte il replay; finito o saltato, il motore riparte col calcio d'inizio
func dopo_esultanza() -> void:
	esultanza.ferma() # la posa finale dell'esultanza resta fino a qui
	if replay == null or stato != "partita":
		return
	gesti.cancel()
	hud.mostra_dribbling(false)
	hud.aiuto_visuale("")
	hud.rallenty(false)
	hud.suggerimento("", false)
	replay.avvia(vista, hud) # se non parte, emette subito `finito` e il motore riparte da solo


func _crea_replay_e_cronaca() -> void:
	if tipo() == "allenamento" or tipo() == "prove":
		return
	var nomi := [str(m.teams[0].get("name", m.teams[0].short)), str(m.teams[1].get("name", m.teams[1].short))]
	cronaca = Cronaca.new(0, nomi)
	cronaca_vista = CronacaVista.new()
	hud.add_child(cronaca_vista)
	hud.move_child(cronaca_vista, 1) # sopra il bordo del rallenty, sotto punteggio, tasti e menu
	if not _opzioni.has("senza-replay"):
		replay = Replay.new()
		add_child(replay)


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
	if gesti == null:
		return
	var giocabile := stato == "partita" and not paused
	var now := Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and esultanza != null and esultanza.attiva and not paused and not hud.tocca_hud(e.position):
			esultanza.salta() # un tocco salta l'esultanza del campione
			return
		if replay != null and replay.attivo(): # un tocco salta il replay (i tasti dell'HUD restano tasti)
			if e.pressed and not paused and not hud.tocca_hud(e.position):
				replay.salta()
			return
		if e.pressed and giocabile and in_scena() and not hud.tocca_hud(e.position):
			_scena_veloce = true # scena della ripresa: un tocco la fa andare più veloce (non si batte ancora)
			return
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


# tasto in basso: Scatto nella fuga (avversario alla pari o dietro), altrimenti Dribbling nel duello
func _dribbling() -> void:
	if stato != "partita" or paused:
		return
	if m.fleeFor(me):
		m.userSprint(me)
	else:
		m.userDribble(me)


# ---------------------------------------------------------------- pausa, intervallo, fine
func _mostra_pausa() -> void:
	if stato != "partita" or paused:
		return
	paused = true
	gesti.cancel()
	hud.mostra_dribbling(false)
	hud.aiuto_visuale("")
	var esci := "Esci dall'amichevole"
	if allenamento != null or prove != null:
		esci = "Esci dall'allenamento"
	elif avviata_da_app() and tipo() == "campionato":
		esci = "Abbandona (sconfitta 0–3)"
	hud.mostra_pausa(esci)


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
	if allenamento != null:
		_fine_allenamento(forfait)
		return
	if prove != null:
		prove.termina(forfait)
		return
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
	if avviata_da_app():
		_emetti_finita()
		if bot != null: # il dito finto preme "Continua"
			get_tree().create_timer(1.5).timeout.connect(_nuova_partita)
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
		"titolo": _titolo() + (" · abbandonata" if abbandonata else ""),
		"tasto": "Continua" if avviata_da_app() else "Nuova partita",
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
	if momenti != null:
		testo += "\nmomenti chiave: %d azioni %s · esiti %s" % [momenti.mo.piano.size(),
			str(momenti.mo.piano.map(func(a: Dictionary) -> String: return "%d'%s" % [a.minuto, a.tipo])), str(momenti.mo.esiti)]
	if allenamento != null:
		testo += "\n" + _riassunto_allenamento()
	if prove != null:
		testo += "\n" + prove.riassunto()
	return testo


func _esci() -> void:
	audio.ferma()
	# un paio di fotogrammi perché il server audio lasci i suoni fermati (altrimenti restano in memoria all'uscita)
	for i in 3:
		await get_tree().process_frame
	get_tree().quit(0)


func _nuova_partita() -> void:
	if avviata_da_app():
		_emetti_finita()
		continua.emit()
		return
	get_tree().reload_current_scene()


func _titolo() -> String:
	if avviata_da_app():
		return String(_avvio.get("titolo", {"campionato": "Campionato", "allenamento": "Allenamento"}.get(tipo(), TITOLO)))
	return TITOLO


# "Esci" dalla pausa: dall'app la partita finisce subito (in campionato 0-3 a tavolino, come il web);
# nella partita di prova si mostra la schermata di fine come prima
func _esci_dalla_pausa() -> void:
	if not avviata_da_app():
		_finisci(true)
		return
	abbandonata = true
	if tipo() == "campionato":
		m.score[me] = 0
		m.score[1 - me] = maxi(3, m.score[1 - me])
		m.goalsLog = m.goalsLog.filter(func(g: Dictionary) -> bool: return g.team != me)
	stato = "fine"
	gesti.enabled = false
	gesti.cancel()
	audio.folla(0.0)
	_emetti_finita()


## risultato per chi ha avviato la partita (una volta sola)
func esito() -> Dictionary:
	return {"gol_a": m.score[0], "gol_b": m.score[1], "marcatori": m.goalsLog.duplicate(),
		"statistiche": m.stats.duplicate(true), "abbandonata": abbandonata, "tipo": tipo(), "me": me,
		"derby": bool(_avvio.get("derby", false)), "conteggi": conta.per_giocatore() if conta != null else {},
		"tabellino": conta.tabellino() if conta != null else {}}


# derby (opzione di avvia): pubblico più rumoroso, più cori e tifosi più in piedi. Ritorna true se è un derby
func _segna_derby() -> bool:
	if not _avvio.get("derby", false):
		return false
	audio.derby = true
	var pubblico: Node = vista.find_child("Pubblico", true, false) if vista is Node else null
	if pubblico != null and "derby" in pubblico:
		pubblico.derby = true
	return true


func _emetti_finita() -> void:
	if _finita_emessa or m == null:
		return
	_finita_emessa = true
	finita.emit(esito())


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
		elif _opzioni.has("ogni"): # sequenza di schermate
			var ogni := maxf(0.05, float(_opzioni["ogni"]))
			var n := int(float(_opzioni.get("dopo", "3")) / ogni)
			var base: String = _opzioni["schermata"].get_basename()
			for i in range(1, n + 1):
				await get_tree().create_timer(ogni).timeout
				await _salva_schermata("%s_%02d.png" % [base, i])
			_esci()
			return
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
		"area", "duello", "fuga", "disegno":
			_metti_in_gioco()
			var y := 8.0 if nome == "duello" or nome == "fuga" else 33.0
			_sposta(att, 4.0, y)
			if nome == "duello":
				_sposta(m.team(1 - me)[3], 4.5, y + 4.5)
			elif nome == "fuga": # avversario alle spalle: si apre la fuga col tasto Scatto
				_sposta(m.team(1 - me)[3], 5.0, y - 2.5)
			m.ball.owner = att
			m.ball.last = att
			m.ball.x = att.x
			m.ball.y = att.y + 0.6
			m.ctrl[me] = att
			if nome == "disegno":
				_disegno_di_prova(m.team(me)[10])
		"testa", "testa_linea": # cross dalla destra verso il n. 10 in area: fermatempo del colpo di testa
			_metti_in_gioco()
			var dt_ := 1.0 if me == 0 else -1.0
			var cr: R.Player = m.team(me)[7]
			_sposta(att, 1.0, dt_ * (C.HL - 9.0))
			_sposta(cr, 24.0, dt_ * (C.HL - 12.0))
			m.ball.owner = cr
			m.ball.last = cr
			m.ball.x = cr.x
			m.ball.y = cr.y + 0.6 * dt_
			m.ctrl[me] = cr
			m.kick(cr, {"type": "loft", "tx": att.x - 1.5, "ty": att.y + dt_ * 1.0})
			if nome == "testa_linea":
				while not m.headFor(me):
					await get_tree().process_frame
				await get_tree().create_timer(0.8).timeout
				var hp: R.Player = m.headWin.p
				var a: Vector3 = vista.world_to_screen(hp.x, hp.y, 1.0)
				var b: Vector3 = vista.world_to_screen(-2.0, dt_ * C.HL, 1.6)
				gesti.down(Vector2(a.x, a.y), Time.get_ticks_msec())
				for i in range(1, 13):
					gesti.move_ev(Vector2(a.x, a.y).lerp(Vector2(b.x, b.y), i / 12.0))
		"curva", "prima": # curva: passaggio curvo disegnato e tenuto (volo alto a effetto); prima: calcio di prima in attesa
			_metti_in_gioco()
			var dy := 1.0 if me == 0 else -1.0
			var cm: R.Player = m.team(me)[10]
			_sposta(att, 4.0, dy * 20.0)
			_sposta(cm, -8.0, dy * 34.0)
			_sposta(m.team(1 - me)[3], -2.0, dy * 27.0)
			m.ball.owner = att
			m.ball.last = att
			m.ball.x = att.x
			m.ball.y = att.y + 0.6 * dy
			m.ctrl[me] = att
			await get_tree().create_timer(0.3).timeout
			if nome == "curva":
				_linea_curva_di_prova(Vector3(m.ball.x, m.ball.y, 0.3), Vector3(cm.x, cm.y, 0.0), 0.3, false)
			else:
				m.userKick(me, {"type": "auto", "tx": cm.x, "ty": cm.y, "curve": 6.0, "tratto": true})
				await get_tree().create_timer(0.15).timeout
				_linea_curva_di_prova(Vector3(cm.x, cm.y, 0.9), Vector3(2.5, dy * C.HL, 1.2), 0.0, true)
		"angolo":
			m.setRestart("corner", me, C.HW, C.HL)
		"rinvio": # rinvio dal fondo del nostro portiere (posa rilassata dietro il pallone)
			m.setRestart("goalkick", me, 5.0, -C.HL if me == 0 else C.HL)
		"fuori_lato", "fuori_fondo", "fuori_fondo_vicino", "fuori_angolo":
			_pallone_fuori(nome)
		"rilancio": # il nostro portiere ha preso il pallone in area: rilancio dalle mani (pallone tra le mani)
			_metti_in_gioco()
			var por: R.Player = m.gk(me)
			_sposta(por, 2.0, (-C.HL + 7.0) * (1.0 if me == 0 else -1.0))
			m.ball.x = por.x
			m.ball.y = por.y + (0.6 if me == 0 else -0.6)
			m.setRestart("gk", me, por.x, por.y, por)
		"gol": # corsa verso la porta col portiere fuori dai pali, poi tiro: gol quasi sicuro (cronaca e replay)
			_metti_in_gioco()
			var dir := 1.0 if me == 0 else -1.0
			if _opzioni.has("esultanza"): # il n. 10 è il campione e fa quell'esultanza (stesso dizionario: niente figura nuova)
				att.src["champ"] = true
				att.src["esultanza"] = _opzioni["esultanza"]
			_sposta(att, 6.0, dir * 30.0)
			_sposta(m.team(1 - me)[0], -12.0, dir * (C.HL - 1.0))
			m.ball.owner = att
			m.ball.last = att
			m.ball.x = att.x
			m.ball.y = att.y + 0.6 * dir
			m.ctrl[me] = att
			if replay != null:
				replay.buffer.svuota() # niente salto dai posti del calcio d'inizio nel replay
			m.userPath(me,[{"x": 3.0, "y": dir * 34.0}, {"x": 1.0, "y": dir * 38.0}])
			await get_tree().create_timer(0.9).timeout
			m.userKick(me, {"type": "shot", "tx": -1.5, "ty": dir * C.HL, "th": 0.7, "curve": 0.0})
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


## linea di prova dal punto a al punto b del campo (pancia = frazione della lunghezza sullo schermo); alza = dito su alla fine
func _linea_curva_di_prova(a: Vector3, b: Vector3, pancia: float, alza: bool) -> void:
	var s0: Vector3 = vista.world_to_screen(a.x, a.y, a.z)
	gesti.down(Vector2(s0.x, s0.y), Time.get_ticks_msec())
	var ultimo := Vector2(s0.x, s0.y)
	for i in range(1, 21):
		var k := float(i) / 20.0
		var s1: Vector3 = vista.world_to_screen(b.x, b.y, b.z)
		var p0 := Vector2(s0.x, s0.y)
		var p1 := Vector2(s1.x, s1.y)
		ultimo = p0.lerp(p1, k) + (p1 - p0).orthogonal() * pancia * 4.0 * k * (1.0 - k)
		gesti.move_ev(ultimo)
		await get_tree().process_frame
	if alza:
		gesti.up(ultimo, Time.get_ticks_msec())


## pallone che rotola fuori: la ripresa diventa una scena (sim/riprese.gd). fuori_lato = rimessa nostra sulla destra;
## fuori_fondo = rinvio nostro col pallone lontano (raccattapalle); fuori_fondo_vicino = pallone vicino all'area piccola;
## fuori_angolo = angolo nostro a destra
func _pallone_fuori(nome: String) -> void:
	_metti_in_gioco()
	var d := 1.0 if me == 0 else -1.0
	var b := m.ball
	match nome:
		"fuori_lato":
			b.last = m.team(1 - me)[6]
			b.x = d * 31.0
			b.y = d * 6.0
			b.vx = d * 7.0
			b.vy = d * 1.5
			_sposta(m.team(me)[7], d * 24.0, d * 2.0)
		"fuori_fondo", "fuori_fondo_vicino":
			b.last = m.team(1 - me)[9]
			var x0 := 20.0 if nome == "fuori_fondo" else 9.0
			b.x = d * x0
			b.y = -d * (C.HL - 1.0)
			b.vx = d * 1.0
			b.vy = -d * 9.0
			_sposta(m.gk(me), d * 1.0, -d * (C.HL - 2.0))
		"fuori_angolo":
			b.last = m.team(1 - me)[3]
			b.x = d * 27.0
			b.y = d * (C.HL - 1.0)
			b.vx = d * 2.0
			b.vy = d * 9.0
			_sposta(m.team(me)[10], d * 18.0, d * (C.HL - 14.0))
			_sposta(m.team(me)[9], d * 6.0, d * (C.HL - 11.0))
	b.owner = null
	if replay != null:
		replay.buffer.svuota()


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


# ---------------------------------------------------------------- allenamento guidato (tipo "allenamento")
# Come startMatch('tutorial') di src/main.js: partita senza fine contro la squadra "Allenamento", la logica in
# allenamento.gd (before/after attorno ai passi del motore), il riquadro e le schede in allenamento_hud.gd.
var allenamento: Allenamento = null
var _all_hud: AllenamentoHud = null
var prove: Node = null        # allenamento libero (tipo "prove"): scripts/partita/prove_tiro_regia.gd


func _avvia_allenamento() -> void:
	_all_hud = AllenamentoHud.new()
	add_child(_all_hud)
	_all_hud.scheda.connect(_scheda_allenamento)
	_all_hud.prova.connect(_prova_allenamento)
	_all_hud.salta.connect(func() -> void: _finisci(true))
	_all_hud.finito.connect(func() -> void: hud.big("Allenamento finito!", "g", 2400, "Ora sei pronto per il campionato"))
	# creato per ultimo: la sua prima scheda ferma la partita
	allenamento = Allenamento.new(m, _all_hud)
	_all_hud.collega(vista, allenamento) # linea guida di passaggi e tiri
	_vai_alla_lezione.call_deferred()


# scheda aperta: partita ferma (come showLesson del web); chiusa: si riprende con _prova_allenamento
func _scheda_allenamento(aperta: bool) -> void:
	if aperta:
		paused = true
		gesti.cancel()
		hud.mostra_dribbling(false)
		hud.aiuto_visuale("")


func _prova_allenamento() -> void:
	paused = false
	gesti.cancel()
	allenamento.go()


# dopo i passi del motore, prima che _eventi() consumi m.events
func _allenamento_dopo(sdt: float) -> void:
	allenamento.after(sdt)
	if allenamento.finished and _fine_ms == 0 and stato == "partita":
		_fine_ms = Time.get_ticks_msec() + 2600


# fine (tutte le lezioni) o "Salta l'allenamento" / "Esci dall'allenamento". Nel web si torna al menu: qui, se c'è
# il segnale `finita` (carriera, fase 3) lo si manda; senza, si chiude (prove) o si ricomincia.
func _fine_allenamento(forfait: bool) -> void:
	stato = "fine"
	gesti.enabled = false
	gesti.cancel()
	audio.folla(0.0)
	hud.mostra_dribbling(false)
	hud.aiuto_visuale("")
	hud.rallenty(false)
	hud.suggerimento("", false)
	hud.nascondi_overlay()
	_all_hud.chiudi()
	var esito := {"tipo": "allenamento", "completato": allenamento.finished, "abbandonata": forfait}
	if _opzioni.has("esci-a-fine"):
		print(riassunto())
		_esci()
	elif has_signal("finita"):
		emit_signal("finita", esito)
	else:
		_nuova_partita()


func _riassunto_allenamento() -> String:
	var tot := 0
	for v: int in allenamento.riuscite.values():
		tot += v
	return "allenamento: %s · lezione %d di %d · prove riuscite %d · per lezione %s" % [
		"finito" if allenamento.finished else "in corso", mini(allenamento.li + 1, allenamento.lessons.size()),
		allenamento.lessons.size(), tot, allenamento.riuscite]


# prove: --lezione=N [--prova=K] parte da quella prova; con --scheda resta sulla scheda della lezione N
func _vai_alla_lezione() -> void:
	if not _opzioni.has("lezione"):
		return
	var n := clampi(int(_opzioni["lezione"]), 1, allenamento.lessons.size())
	while allenamento.li < n - 1:
		allenamento.next_lesson()
	if _opzioni.has("scheda"):
		return
	_all_hud.premi_prova()
	allenamento.k = clampi(int(_opzioni.get("prova", "1")), 1, Allenamento.REPS) - 1
	allenamento.reset()
