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
#   --scena=area|duello|fuga|scatto|angolo|rinvio|rilancio|pausa|gol|curva|prima   mette la partita in una situazione da fotografare (gol: tiro a
#                       porta vuota, per vedere cronaca e replay)
#   --scena=dribbling|dribbling_ok|dribbling_ko   duello col difensore e tasto Dribbling (regia del dribbling,
#                       dribbling_regia.gd); _ok / _ko con statistiche estreme (l'esito resta a caso col seme);
#                       --giochetto=ID giochetto fisso (finta, veronica, tunnel, ...: sim/skill.gd)
#   --scena=fallo|rigore|espulso   fallo da dietro sul nostro n. 10 (sim/falli.gd): giallo e punizione con la barriera,
#                       giallo e rigore, secondo giallo = espulso
#   --scena=testa_difesa|testa_difesa_linea|testa_passaggio|testa_passaggio_linea|testa_fascia   salto conteso di
#                       testa (sim/testa.gd): in difesa sul cross della CPU, sul nostro lancio alto con un difensore
#                       attaccato (_linea: il dito disegna il passaggio di testa), lancio sulla fascia senza nessuno
#   --scena=giro|giro_linea   gioco normale col nostro n. 10 che corre da solo: il dito lontano da lui gira la visuale
#                       senza rallentare (giro_linea: poi disegna il passaggio al n. 11 con la visuale girata)
#   --scena=recupero   il nostro n. 4 ruba palla in contrasto frontale: respiro dopo il recupero, rallenty, passaggio
#   --scena=parata|parata_linea   tiro avversario: fermatempo della parata col bersaglio (parata_linea: dito che disegna)
#   --scena=fuori_lato|fuori_lato_cpu|fuori_fondo|fuori_fondo_vicino|fuori_rete|fuori_angolo   pallone che esce: scena della ripresa
#                       (sim/riprese.gd), rimessa, rinvio col raccattapalle (sim/raccatta.gd), rinvio col pallone vicino,
#                       rinvio col pallone dietro la rete (lo prende il raccattapalle), calcio d'angolo
#   --esultanza=ID      con --scena=gol chi segna è il campione e fa quell'esultanza (id in esultanze.gd)
#   --senza-replay      dopo il gol niente replay (si va subito al calcio d'inizio)
#   --replay=porta|lato visuale del replay del gol (predefinito: a caso)
#   --schermata=PERCORSO.png [--dopo=SEC] [--alla-fine]   schermata dopo SEC secondi veri, o alla fine partita
#   --ogni=SEC          con --schermata: una schermata ogni SEC secondi veri (PERCORSO_01.png, _02, ...) fino a --dopo
#   --esci-dopo=SEC     esce dopo SEC secondi veri
#   --campo=NOME        taglio dell'erba (strisce, strette, verticali, quadrotti, cerchi, uniforme, rombi, raggi, diagonali)
#   --manto=NOME        colore dell'erba (vivo, milano, naturale, sintetico, sintetico_chiaro, estivo)
#   --meteo=sereno|nuvoloso|pioggia|neve  --ora=giorno|tramonto|notte   forzano meteo e ora (scripts/partita/meteo.gd)
#   --allenamento       allenamento guidato (tipo "allenamento", scripts/partita/allenamento.gd) invece dell'amichevole;
#                       con --lezione=N [--prova=K] parte da lì, con --scheda mostra la scheda della lezione N
#   --prove=tiri|punizioni|rigori   allenamento libero a punti (tipo "prove", scripts/partita/prove_tiro_regia.gd)
#   --pausa-rosa        amichevole con una carriera di prova (file user://prova_pausa_rosa.json, mai il salvataggio vero):
#                       dopo un attimo pausa e "Rosa e tattica" aperta (cambi, formazione e stili a partita in corso)
#   --scena=cambio      stessa carriera di prova: due sostituzioni dalla pausa e scena del cambio (cambio_regia.gd)
#
# Rosa e tattica (Luis 2026-11-24): nelle partite della carriera (campionato, amichevole) la pausa e l'intervallo hanno
# il tasto "Rosa e tattica": la Rosa del menu (rosa.gd in modo partita) si apre sopra la partita ferma; chiudendola i
# cambi valgono subito nel motore (cambi_partita.gd → SimMatch.cambiaSquadra) e a "Riprendi" / "Secondo tempo" parte
# la scena del cambio (cambio_regia.gd) col tempo fermo. Non nelle lezioni, nelle prove di tiro né senza carriera.
#
# Dall'app (scripts/app.gd): chi crea la scena chiama `avvia(opz)` prima di aggiungerla o entro il primo fotogramma,
# con opz = {squadra_a, squadra_b, me, tipo: "campionato"|"amichevole"|"allenamento", durata_tempo, seme,
# titolo (facoltativo), autoGk (facoltativo), stadio_seme (facoltativo: seme della squadra di casa, sceglie taglio e
# manto dell'erba; senza, vengono dal seme della partita), derby (facoltativo: partita contro la rivale, pubblico più
# rumoroso)}; `--campo=<nome>`/`--manto=<nome>` li forzano per le prove; squadre come Carriera.squadraPartita()/aiMatchTeam() (kit compreso).
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
const ParataRegia := preload("res://scripts/partita/parata_regia.gd")
const TimerRallenty := preload("res://scripts/partita/timer_rallenty.gd")
const DribblingRegia := preload("res://scripts/partita/dribbling_regia.gd")
const CambiPartita := preload("res://scripts/partita/cambi_partita.gd")
const CambioRegia := preload("res://scripts/partita/cambio_regia.gd")
const SCENA_ROSA := "res://scenes/menu/rosa.tscn"
const SALVA_PROVA_ROSA := "user://prova_pausa_rosa.json"   # carriera di prova di --pausa-rosa e --scena=cambio
const SCENA_VISTA := "res://scenes/vista_partita.tscn"

# velocità del tempo (rallenty), come src/main.js
const GK_SLOW := 0.1          # mentre si para
const DEF_DRAW_SLOW := 0.13   # mentre si disegna una linea di difesa
const PASS_DRAW_SLOW := 0.04  # mentre si disegna un passaggio o un tiro
const DUEL_SLOW := 0.08       # duello col difensore
const FLEE_SLOW := 0.08       # fuga: avversario alla pari o alle spalle, tasto Scatto
const ZONE_SLOW := 0.1        # area di tiro (ultimi 20 m prima della porta avversaria)
const CERCHIO_RALLENTY_H := 3.5  # timer del rallenty: il cerchietto sta a tanti metri d'altezza, sopra il triangolo del controllato
const SCENA_VELOCE := 3.0     # scena della ripresa (sim/riprese.gd) dopo un tocco: va tanto più veloce
const SCENA_FONDO := 2.0      # rinvio e angolo (anche col raccattapalle) vanno da soli tanto più veloci: metà del tempo (Luis 2026-11-23)
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
var _festa_finita := false    # il motore ha finito la festa del gol ed è trattenuto (aspetta esultanza e replay)
var _esultanza_in_corso := false
var _fallo_nel_passo := false     # c'è un fallo tra gli eventi del passo (la scritta del vantaggio la fa _fallo)
var _cartellino_rigore: Array = [] # fallo in area col cartellino: [colore, nome] da mostrare con "RIGORE!"

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
var _rallenty := TimerRallenty.new()  # timer di 10 s veri del rallenty col pallone (timer_rallenty.gd)
var _drib := DribblingRegia.new()     # regia del dribbling della persona: rallenty e telecamera girata (dribbling_regia.gd)
var _testa_reale := -1.0       # secondi veri dall'apertura del fermatempo del colpo di testa (−1 = chiuso)
var _parata := ParataRegia.new() # fermatempo della parata col bersaglio (portiere manuale, sim/parata.gd)
var _scena_veloce := false     # un tocco durante la scena della ripresa la fa andare più veloce (fino alla fine)
var meteo := {"meteo": "sereno", "ora": "giorno"}  # scripts/partita/meteo.gd: avvio.meteo/ora o a caso col seme
var cambi: CambiPartita = null  # cambi a partita in corso (null = niente "Rosa e tattica": senza carriera, lezioni, prove)
var carriera_prova: Object = null  # carriera da usare al posto di quella dell'App (prove, test)
var _cambio: CambioRegia = null    # scena del cambio
var _rosa_layer: CanvasLayer = null
var _rosa: Control = null           # Rosa e tattica aperta (rosa.gd in modo partita)
var _menu_sotto := ""               # menu da rimettere chiusa la Rosa: "pausa" o "intervallo"
var _testo_esci := ""               # tasto "Esci" della pausa (per rimetterla uguale)


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
	if _avvio.is_empty() and (_opzioni.has("pausa-rosa") or _opzioni.get("scena", "") == "cambio"):
		_avvio_carriera_prova()
	_parti()


## carriera della partita per "Rosa e tattica": quella di prova, o dell'App nelle partite della carriera; null = niente
func carriera_partita() -> Object:
	if tipo() != "campionato" and tipo() != "amichevole":
		return null
	if carriera_prova != null:
		return carriera_prova
	if not avviata_da_app():
		return null
	var app := get_node_or_null("/root/App")
	var c: Variant = app.get("carriera") if app != null else null
	return c if c is Object and c.get("s") is Dictionary else null


# --pausa-rosa / --scena=cambio: amichevole con una carriera nuova su un file di prova (mai il salvataggio vero)
func _avvio_carriera_prova() -> void:
	var c := Carriera.new()
	c.percorso = SALVA_PROVA_ROSA
	c.create("Prova", 1, 4242)
	carriera_prova = c
	var avv: Dictionary = c.team(c.s.divs[2][1])
	_avvio = {"squadra_a": c.squadraPartita(), "squadra_b": c.avversarioPartita(avv), "me": 0, "tipo": "amichevole",
		"durata_tempo": TEMPO_PREDEFINITO, "seme": int(_opzioni.get("seme", "7")), "titolo": "Amichevole"}


func _parti() -> void:
	_inizio_ms = Time.get_ticks_msec()
	_crea_partita()
	_crea_vista()
	hud = (load("res://scenes/hud_partita.tscn") as PackedScene).instantiate()   # load: non resta vivo con lo script
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
	hud.rosa_premuta.connect(_apri_rosa)
	if carriera_partita() != null:
		cambi = CambiPartita.new()
	_cambio = CambioRegia.new()
	add_child(_cambio)
	_cambio.finita.connect(_fine_cambio)
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
	var auto_gk: bool = _avvio.get("autoGk", false)
	meteo = Meteo.per_partita(_avvio, _opzioni, seme, tipo() == "allenamento" or tipo() == "prove")
	m = SimMatchScript.new({"seed": seme, "halfLen": tempo, "human": [me == 0, me == 1],
		"autoGk": [auto_gk and me == 0, auto_gk and me == 1], "teams": squadre, "meteo": meteo.meteo, "testa": true, "parata": true, "rifiniture": true, "attacco": true,
		# lezioni e prove di tiro: il tiratore non parte da solo e le riprese restano immediate
		"portaAuto": tipo() != "allenamento" and tipo() != "prove", "riprese": tipo() != "allenamento" and tipo() != "prove",
		# falli sui contrasti da dietro e in ritardo (sim/falli.gd): non nelle lezioni e nelle prove di tiro
		"falli": tipo() != "allenamento" and tipo() != "prove", "contatti": true})
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
	if carriera_prova != null and carriera_prova.percorso == SALVA_PROVA_ROSA:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SALVA_PROVA_ROSA))
	if not avviata_da_app() or carriera_prova != null:
		Uscita.libera_cache_grafiche()


# ---------------------------------------------------------------- ciclo principale (frame() di src/main.js)
func _process(delta: float) -> void:
	if stato != "partita":
		return
	var now := Time.get_ticks_msec()
	_fotogrammi += 1
	var dt := _dt_fisso if _dt_fisso > 0.0 else minf(DT_MAX, delta)
	gesti.dim = get_viewport().get_visible_rect().size
	if _cambio != null and _cambio.attiva: # scena del cambio: tempo di partita fermo, la scena muove vista e telecamera
		_cambio.fotogramma(dt)
		return
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
		_parata.mostra(m, me, vista, hud)
		_cerchio_rallenty()
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
	vista.dribbling_cam = _drib.camera()
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
	hud.cerchio_testa(Vector2(s.x, s.y), FermatempoTesta.frazione(_testa_reale), FermatempoTesta.scritta(m.headWin.kind))


## timer del rallenty col pallone (Luis 2026-11-23): dopo TimerRallenty.RALLENTY_MAX_S secondi veri senza linea né
## tasto il rallenty finisce (m.userCalm) e il portatore continua da solo. Non nelle lezioni e nelle prove di tiro.
func _passo_rallenty(dt: float) -> void:
	var p: Object = null
	if allenamento == null and prove == null and not _drib.attiva(): # il dribbling non si chiude a metà
		p = TimerRallenty.portatore_in_rallenty(m, me)
	if _rallenty.passo(dt, p, gesti.drawing):
		m.userCalm(me)


## cerchietto bianco sopra il portatore che si svuota coi secondi del rallenty
func _cerchio_rallenty() -> void:
	var f := _rallenty.frazione()
	var p := _rallenty.portatore as R.Player
	if f < 0.0 or p == null:
		hud.cerchio_rallenty(Vector2.ZERO, -1.0)
		return
	var s: Vector3 = vista.world_to_screen(p.x, p.y, CERCHIO_RALLENTY_H)
	if s.z < 0.5:
		hud.cerchio_rallenty(Vector2.ZERO, -1.0)
		return
	hud.cerchio_rallenty(Vector2(s.x, s.y), f)


## velocità del tempo voluta adesso (rallenty)
func velocita_voluta() -> float:
	var dive: bool = m.diveWin(me) and not m.autoGk[me]
	# dribbling prenotato: il portatore corre verso il difensore, poi il giochetto (rallenty della regia del dribbling)
	var booked: bool = m.dribBooked(me)
	var drib := _drib.velocita()
	var duel: bool = not booked and m.duelFor(me)
	var flee: bool = not duel and m.fleeFor(me)
	var zone: bool = not booked and not duel and not flee and m.inZone(me)
	if gesti.mode == "dpath":
		return DEF_DRAW_SLOW
	if gesti.drawing:
		return PASS_DRAW_SLOW # col pallone ogni linea è un passaggio o un tiro (niente più strada da correre)
	if dive:
		return GK_SLOW
	if drib >= 0.0:
		return drib
	if duel:
		return DUEL_SLOW
	if flee:
		return FLEE_SLOW
	if zone:
		return ZONE_SLOW
	return 1.0


func _passi_motore(dt: float) -> void:
	_passo_rallenty(dt)
	var target := velocita_voluta()
	var flee: bool = not m.duelFor(me) and m.fleeFor(me)
	# toccato Dribbling il tasto sparisce: la prenotazione è partita, il dribbling scatta vicino al difensore
	# nella lezione del passaggio il tasto non c'è (Luis 2026-11-21): lì si impara solo a disegnare il passaggio
	var tasto_ok := allenamento == null or allenamento.finished or String(allenamento.lesson().get("id", "")) != "passaggio"
	hud.mostra_dribbling(tasto_ok and ((m.duelFor(me) and not m.dribBooked(me)) or flee) and not gesti.drawing, flee)
	var testa := _velocita_testa(dt)
	if testa < 0.0: # fermatempo della parata: stessa regola (fermo o normale)
		testa = _parata.velocita(dt, m, me, gesti.mode == "dive" and gesti.dito >= 0)
	if testa >= 0.0:
		ts = testa # fermatempo del colpo di testa: fermo o normale, niente passaggio dolce
	else:
		ts += (target - ts) * minf(1.0, dt * _drib.k_tempo(TEMPO_K)) # fine del dribbling: torna normale piano
	var sdt := dt * ts * _velocita
	if in_scena():
		sdt *= velocita_scena(m.restart.type, _scena_veloce)
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
	_drib.passo(m, me, sdt, ts)
	if replay != null and replay.festa_finita():
		_fine_festa_gol()
	if allenamento != null:
		_allenamento_dopo(sdt)
	if prove != null:
		prove.after(sdt)
	hud.rallenty(ts < RALLENTY_SOTTO)
	audio.folla(FOLLA_BASE, AudioPartita.eccitazione(m.ball.y))


## quanto va veloce la scena della ripresa: rinvio e angolo da soli a SCENA_FONDO, dopo un tocco a SCENA_VELOCE
static func velocita_scena(tipo: String, toccata: bool) -> float:
	var v := SCENA_FONDO if tipo == "goalkick" or tipo == "corner" else 1.0
	return maxf(v, SCENA_VELOCE) if toccata else v


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
	_fallo_nel_passo = false
	for e: Dictionary in m.events:
		if e.type == "advantage":
			adv = true
		elif e.type == "foul":
			_fallo_nel_passo = true
	for e: Dictionary in m.events:
		_drib.evento(e, me)
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
				if e.get("difesa", false):
					hud.big("Respinta!", "", 800)
				elif e.get("sponda", false):
					hud.big("Sponda!", "", 800)
				else:
					hud.big("Colpo di testa!" if e.kind == "header" else "Al volo!", "", 900)
		"head_win":
			if int(e.team) == me:
				gesti.cancel() # una linea a metà (es. difesa) non vale: ora si disegna il colpo di testa
		"advantage":
			if not _fallo_nel_passo:
				hud.big("Vantaggio!", "", 1100)
		"advantage_back":
			audio.whistle()
			hud.big("Si torna alla punizione", "", 1300)
		"tackle", "block":
			audio.kick(9.0)
		"dribble_go": # scatto dopo il giochetto del dribbling: tocco del pallone e primi passi (vista.dribbling_go)
			vista.dribbling_go(e)
		"burst": # tasto Scatto nella fuga: niente giochetto, solo suono e scritta
			if (e.p as R.Player).team == me:
				audio.kick(6.0)
				hud.big("Scatto!", "g", 800)
		"dribble":
			# riuscito: il giochetto va dal lato scelto dal motore (e.side: +1 = sinistra del portatore) e il difensore
			# interviene a vuoto; fallito: contrasto del difensore (dribbling_regia.gd → esito)
			# (coreografie di gambe, busto e pallone: vista.dribbling → mosse/coreo_dribbling.gd)
			var es := DribblingRegia.esito(e)
			var nome := "Dribbling fallito"
			var tk: Dictionary = vista.dribbling(e, es)
			if e.ok:
				nome = _nome_giochetto(tk) + "!"
			if _opzioni.has("scena"):
				print("prova dribbling: %s %s (a %.2f m)" % [nome, "riuscito" if e.ok else "fallito",
					C.hyp(e.p.x - e.o.x, e.p.y - e.o.y)])
			if (e.p as R.Player).team == me:
				if e.ok: # il nome del giochetto: piccolo e in alto, non sopra il portatore nel momento chiave
					hud.nota(nome, "g")
				else:
					hud.big(nome, "", 1000)
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
		var cr := _cartellino_rigore
		_cartellino_rigore = []
		var piccolo := ""
		if not cr.is_empty():
			piccolo = String(cr[1]) # il nome (la scritta grande non ha spazio per "Ammonito ..."): il cartellino lo dice
		hud.big("RIGORE!", "g" if e.team == me else "b", 2000 if piccolo != "" else 1800, piccolo)
		if not cr.is_empty():
			hud.mostra_cartellino(cr[0])


# Fallo (falli.gd): fischio e scritta; col cartellino anche il cartellino disegnato sopra la scritta e il nome.
# Col vantaggio niente fischio: "Vantaggio!" (e sotto chi è stato ammonito); in area la scritta la fa il rigore.
func _fallo(e: Dictionary, adv: bool) -> void:
	var card: Variant = e.get("card")
	var chi: String = (e.by as R.Player).name if e.by != null else ""
	if adv:
		if card != null:
			hud.big("Vantaggio!", "", 1600, chi) # col cartellino sopra: il nome di chi è ammonito
			hud.mostra_cartellino(String(card))
		else:
			hud.big("Vantaggio!", "", 1100)
		return
	audio.whistle()
	if e.get("pen", false):
		_cartellino_rigore = [String(card), chi] if card != null else []
		return
	var testo := "Fallo"
	if card == "red":
		testo = "Espulso!"
	elif card == "yellow":
		testo = "Ammonito"
	hud.big(testo, "b" if card == "red" else ("g" if card == "yellow" else ""), 1700 if card != null else 1200, chi if card != null else "")
	if card != null:
		hud.mostra_cartellino(String(card))


# ---------------------------------------------------------------- tocchi (un dito solo)
func _unhandled_input(event: InputEvent) -> void:
	if gesti == null:
		return
	var giocabile := stato == "partita" and not paused
	var now := Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if _cambio != null and _cambio.attiva: # un tocco salta la scena del cambio
			if e.pressed:
				_cambio.salta()
			return
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
	_menu_sotto = "pausa"
	_testo_esci = esci
	hud.mostra_pausa(esci, cambi != null)


func _riprendi() -> void:
	hud.nascondi_overlay()
	if not _avvia_cambio():
		paused = false


func _mostra_intervallo() -> void:
	paused = true
	gesti.cancel()
	hud.mostra_dribbling(false)
	_menu_sotto = "intervallo"
	hud.mostra_intervallo(m.score[0], m.score[1], cambi != null)


func _secondo_tempo() -> void:
	hud.nascondi_overlay()
	m.startSecondHalf()
	if not _avvia_cambio():
		paused = false


# ---------------------------------------------------------------- rosa e tattica a partita ferma, scena del cambio
## apre la Rosa in modo partita sopra la partita ferma (dalla pausa o dall'intervallo)
func _apri_rosa() -> void:
	var c := carriera_partita()
	if cambi == null or c == null or not paused or _rosa != null:
		return
	cambi.leggi_espulsi(m, me)
	cambi.leggi_energie(m, me)
	hud.nascondi_overlay()
	_rosa_layer = CanvasLayer.new()
	_rosa_layer.layer = 8
	add_child(_rosa_layer)
	_rosa = (load(SCENA_ROSA) as PackedScene).instantiate()
	_rosa.apri({"in_partita": true, "cambi": cambi, "carriera": c})
	_rosa.chiusa.connect(_chiudi_rosa)
	_rosa_layer.add_child(_rosa)


## "Torna alla partita": i cambi valgono subito nel motore, si torna al menu di prima (pausa o intervallo)
func _chiudi_rosa() -> void:
	if _rosa == null:
		return
	var c := carriera_partita()
	if c != null and cambi.applica(m, me, c) == null:
		push_warning("Rosa e tattica: cambi non applicati alla partita")
	_rosa_layer.queue_free()
	_rosa_layer = null
	_rosa = null
	if _menu_sotto == "intervallo":
		hud.mostra_intervallo(m.score[0], m.score[1], true)
	else:
		hud.mostra_pausa(_testo_esci, true)


## Rosa e tattica aperta (per le prove), o null
func rosa_aperta() -> Control:
	return _rosa


## scena del cambio se ci sono cambi da mostrare (il tempo resta fermo finché non finisce). false = niente
func _avvia_cambio() -> bool:
	if cambi == null or cambi.da_mostrare.is_empty() or _cambio == null:
		return false
	var lista: Array = cambi.da_mostrare
	cambi.da_mostrare = []
	gesti.cancel()
	return _cambio.avvia(m, me, vista, lista)


func _fine_cambio() -> void:
	paused = false


## scena del cambio in corso (per le prove)
func cambio_in_corso() -> bool:
	return _cambio != null and _cambio.attiva


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
			["Falli", st.fouls[0], st.fouls[1]]] + _righe_cartellini(st) + [["Parate", st.saves[0], st.saves[1]]],
	}


## righe dei cartellini per la schermata di fine (solo se ce n'è stato almeno uno)
static func _righe_cartellini(st: Dictionary) -> Array:
	var out: Array = []
	for voce: Array in [["Ammonizioni", "yellows"], ["Espulsioni", "reds"]]:
		var v: Array = st.get(voce[1], [0, 0])
		if int(v[0]) + int(v[1]) > 0:
			out.append([voce[0], int(v[0]), int(v[1])])
	return out


func riassunto() -> String:
	var secondi := maxf(0.001, (Time.get_ticks_msec() - _inizio_ms) / 1000.0)
	var testo := "FPS medi %.1f · %s\n" % [_fotogrammi / secondi, HudFase1.testo_memoria()]
	testo += "fine partita %s %d - %d %s · tempo di gioco %.0f s · %s" % [
		m.teams[0].short, m.score[0], m.score[1], m.teams[1].short, m.time, "abbandonata" if abbandonata else ("finita" if stato == "fine" else "in corso")]
	if bot != null:
		testo += "\n" + bot.riassunto()
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
	# via la scena, qualche fotogramma perché materiali e shader vengano liberati, cache static svuotate, poi esce
	# (sul Mac della build a volte uno shader restava vivo oltre lo spegnimento della grafica: "DummyShader leaked")
	Uscita.esci(get_tree(), 0)


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
	if _opzioni.has("pausa-rosa"):
		_prova_pausa_rosa(String(_opzioni["pausa-rosa"]))
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


## prove: con la Rosa e tattica aperta, n sostituzioni coi tocchi veri (attaccante n. 10 e un difensore con il
## migliore della panchina del loro ruolo)
func sostituzioni_di_prova(n: int) -> void:
	if _rosa == null:
		return
	var c := carriera_partita()
	var s: Dictionary = c.s
	var F: Array = C.FORMATIONS[s.formation]
	for slot: int in [9, 2, 6].slice(0, n):
		var tit: Variant = s.lineup[slot]
		var scelto: Variant = null
		for q: Dictionary in MenuRosa.bench_order(c.bench()):
			if not cambi.uscito(q.id) and c.infortunio(q.id) <= 0 and (scelto == null or q.pos == F[slot][0]):
				if scelto == null or c.player(scelto).pos != F[slot][0]:
					scelto = q.id
		if scelto == null:
			continue
		_rosa._tocca(tit)
		_rosa._tocca(scelto)
		_rosa._tocca(scelto)


# --pausa-rosa[=giocatore|formazione|cambi]: pausa e Rosa e tattica aperta (giocatore = pannello del n. 10 scelto,
# formazione = menu Formazione aperto, cambi = due sostituzioni fatte: in panchina i due "USCITO")
func _prova_pausa_rosa(come: String) -> void:
	await get_tree().create_timer(1.2).timeout
	_mostra_pausa()
	if come == "pausa":
		return
	_apri_rosa()
	await get_tree().process_frame
	match come:
		"giocatore":
			_rosa._tocca(carriera_partita().s.lineup[9])
		"formazione":
			_rosa._apri_menu("formazione")
		"cambi":
			sostituzioni_di_prova(2)


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
		"area", "duello", "fuga", "disegno", "scatto":
			_metti_in_gioco()
			var y := 8.0 if nome == "duello" or nome == "fuga" or nome == "scatto" else 33.0
			_sposta(att, 4.0, y)
			if nome == "duello":
				_sposta(m.team(1 - me)[3], 4.5, y + 4.5)
			elif nome == "fuga" or nome == "scatto": # avversario alle spalle: si apre la fuga col tasto Scatto
				_sposta(m.team(1 - me)[3], 5.0, y - 2.5)
			m.ball.owner = att
			m.ball.last = att
			m.ball.x = att.x
			m.ball.y = att.y + 0.6
			m.ctrl[me] = att
			if nome == "disegno":
				_disegno_di_prova(m.team(me)[10])
			if nome == "scatto": # aperta la fuga, il tasto Scatto: poi il portatore deve continuare da solo
				while not m.fleeFor(me):
					await get_tree().process_frame
				await get_tree().create_timer(0.8).timeout
				_dribbling()
		"giro", "giro_linea":
			_scena_giro(att, nome == "giro_linea")
		"dribbling", "dribbling_ok", "dribbling_ko": # duello col difensore davanti, poi il tasto Dribbling (regia del dribbling)
			_scena_dribbling(att, nome)
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
		"testa_difesa", "testa_difesa_linea", "testa_passaggio", "testa_passaggio_linea", "testa_fascia":
			_scena_testa_contesa(nome)
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
		"parata", "parata_linea": # tiro avversario da 20 m verso la nostra porta: fermatempo della parata col bersaglio
			_metti_in_gioco()
			var dp := -1.0 if me == 0 else 1.0 # verso della nostra porta
			var tir_: R.Player = m.team(1 - me)[9]
			_sposta(tir_, -6.0, dp * (C.HL - 20.0))
			_sposta(m.gk(me), 0.0, dp * (C.HL - 0.6))
			tir_.fx = 0.0
			tir_.fy = dp
			m.ball.owner = tir_
			m.ball.last = tir_
			m.ball.x = tir_.x
			m.ball.y = tir_.y + 0.6 * dp
			m.kick(tir_, {"type": "shot", "tx": 2.6, "ty": dp * C.HL, "th": 1.7})
			if nome == "parata_linea": # il dito disegna dal portiere verso l'alto a destra e resta giù
				while not m.paraFor(me):
					await get_tree().process_frame
				await get_tree().create_timer(0.8).timeout
				var gk_: R.Player = m.gk(me)
				var a: Vector3 = vista.world_to_screen(gk_.x, gk_.y, 1.0)
				var b: Vector3 = vista.world_to_screen(2.4, dp * C.HL, 1.8)
				gesti.down(Vector2(a.x, a.y), Time.get_ticks_msec())
				for i in range(1, 13):
					gesti.move_ev(Vector2(a.x, a.y).lerp(Vector2(b.x, b.y), i / 12.0))
		"angolo":
			m.setRestart("corner", me, C.HW, C.HL)
		"rinvio": # rinvio dal fondo del nostro portiere (posa rilassata dietro il pallone)
			m.setRestart("goalkick", me, 5.0, -C.HL if me == 0 else C.HL)
		"fuori_lato", "fuori_lato_cpu", "fuori_fondo", "fuori_fondo_vicino", "fuori_rete", "fuori_angolo":
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
		"cambio": # due sostituzioni dalla pausa (Rosa e tattica), poi la scena del cambio
			await get_tree().create_timer(2.0).timeout
			_mostra_pausa()
			_apri_rosa()
			await get_tree().process_frame
			sostituzioni_di_prova(2)
			_rosa.chiusa.emit()
			await get_tree().create_timer(0.3).timeout
			_riprendi()
		"recupero": # il nostro n. 4 ruba il pallone in contrasto frontale al n. 10 avversario che gli corre addosso
			# (Luis 2026-11-24: "quando recupero palla me la rubano subito"): si vede chi ha perso il pallone e il rallenty
			_metti_in_gioco()
			var dr := 1.0 if me == 0 else -1.0
			var cpu: R.Player = m.team(1 - me)[9]
			var dif: R.Player = m.team(me)[3]
			_sposta(cpu, 3.0, -dr * 14.0)
			_sposta(dif, 3.0, -dr * 15.0)
			_sposta(m.team(me)[6], -9.0, -dr * 4.0) # un compagno libero a cui passare
			cpu.fx = 0.0
			cpu.fy = -dr
			dif.fx = 0.0
			dif.fy = dr
			m.ball.owner = cpu
			m.ball.last = cpu
			m.ball.x = cpu.x
			m.ball.y = cpu.y - 0.6 * dr
			m.ctrl[me] = dif
			dif.contact = 9.0 # contrasto al primo contatto
			cpu.aiT = 9.0 # il portatore non passa subito: gli va addosso
		"fallo", "rigore", "espulso": # fallo da dietro sul nostro n. 10 (sim/falli.gd): giallo e punizione con la
			# barriera a 24 m dalla porta, giallo e rigore in area, secondo giallo = rosso
			_metti_in_gioco()
			var df := 1.0 if me == 0 else -1.0
			var dif: R.Player = m.team(1 - me)[3]
			var dal_fondo := 12.0 if nome == "rigore" else 24.0
			_sposta(att, 5.0, df * (C.HL - dal_fondo))
			_sposta(dif, 5.0, df * (C.HL - dal_fondo - 0.8))
			_sposta(m.team(1 - me)[4], 7.5, df * (C.HL - dal_fondo + 1.0)) # un altro addosso: niente vantaggio
			att.fx = 0.0
			att.fy = df
			m.ball.owner = att
			m.ball.last = att
			m.ball.x = att.x
			m.ball.y = att.y + 0.6 * df
			m.ctrl[me] = att
			if nome == "espulso":
				dif.yellow = 1
			m.foulCall(dif, att, true, "dietro")


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


## pallone che rotola fuori: la ripresa diventa una scena (sim/riprese.gd). fuori_lato = rimessa nostra sulla destra
## (fuori_lato_cpu: la stessa, ma la batte la CPU);
## fuori_fondo = rinvio nostro col pallone lontano (raccattapalle); fuori_fondo_vicino = pallone vicino all'area piccola;
## fuori_rete = pallone che finisce dietro la nostra rete (raccattapalle); fuori_angolo = angolo nostro a destra
func _pallone_fuori(nome: String) -> void:
	_metti_in_gioco()
	var d := 1.0 if me == 0 else -1.0
	var b := m.ball
	match nome:
		"fuori_lato", "fuori_lato_cpu":
			b.last = m.team(me if nome == "fuori_lato_cpu" else 1 - me)[6]
			b.x = d * 31.0
			b.y = d * 6.0
			b.vx = d * 7.0
			b.vy = d * 1.5
			_sposta(m.team(me)[7], d * 24.0, d * 2.0)
		"fuori_fondo", "fuori_fondo_vicino":
			b.last = m.team(1 - me)[9]
			var x0 := 14.0 if nome == "fuori_fondo" else 9.0
			b.x = d * x0
			b.y = -d * (C.HL - 1.0)
			b.vx = d * 1.0
			b.vy = -d * 9.0
			_sposta(m.gk(me), d * 1.0, -d * (C.HL - 2.0))
		"fuori_rete":
			b.last = m.team(1 - me)[9]
			b.x = d * 4.6
			b.y = -d * (C.HL - 2.0)
			b.vx = -d * 1.6
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


## salto conteso del colpo di testa (sim/testa.gd): testa_difesa = cross della CPU verso il suo attaccante col nostro
## difensore attaccato; testa_passaggio = nostro lancio alto al n. 10 a 30 m dalla porta con un difensore attaccato;
## testa_fascia = lancio sulla fascia senza nessuno vicino (si controlla e si corre). _linea: il dito disegna il
## passaggio di testa al compagno più avanti. Bravura di testa estrema perché il salto lo vinca quasi sempre il nostro
## (resta deciso dal seme)
func _scena_testa_contesa(nome: String) -> void:
	_metti_in_gioco()
	var dt_ := 1.0 if me == 0 else -1.0
	var difesa := nome.begins_with("testa_difesa")
	var tira: R.Player
	var mio: R.Player
	var suo: R.Player
	var tx: float
	var ty: float
	if difesa:
		tira = m.team(1 - me)[7]
		suo = m.team(1 - me)[9]
		mio = m.team(me)[3]
		_sposta(suo, 1.0, -dt_ * (C.HL - 10.0))
		_sposta(tira, -24.0, -dt_ * (C.HL - 12.0))
		_sposta(mio, 1.8, -dt_ * (C.HL - 10.6))
		tx = suo.x - 1.5
		ty = suo.y - dt_ * 1.0
	else:
		var fascia := nome == "testa_fascia"
		tira = m.team(me)[6]
		mio = m.team(me)[9]
		suo = m.team(1 - me)[3]
		var x := -25.0 if fascia else -6.0
		var y := dt_ * (24.0 if fascia else 20.0)
		_sposta(tira, x + 4.0, y - dt_ * 24.0)
		_sposta(mio, x, y)
		if fascia: # nessun avversario vicino al punto del lancio
			for o: R.Player in m.team(1 - me):
				if o.pos != "P" and C.hyp(o.x - x, o.y - y) < 14.0:
					_sposta(o, o.x + 18.0, o.y)
			_sposta(suo, x + 16.0, y + dt_ * 12.0)
		else:
			_sposta(suo, x + 0.9, y + dt_ * 0.9)
		tx = x
		ty = y + dt_ * 1.5
	mio.st.tes = 99.0
	suo.st.tes = 20.0
	m.ball.owner = tira
	m.ball.last = tira
	m.ball.x = tira.x
	m.ball.y = tira.y
	m.ctrl[me] = mio if difesa else tira
	m.kick(tira, {"type": "loft", "tx": tx, "ty": ty})
	if not nome.ends_with("_linea"):
		return
	var attesa := 0
	while not m.headFor(me):
		await get_tree().process_frame
		attesa += 1
		if attesa > 240:
			return # salto perso (o niente salto): nessuna linea da disegnare
	await get_tree().create_timer(0.8).timeout
	if not m.headFor(me):
		return
	var hp: R.Player = m.headWin.p
	var q: Array = m.headMateTarget()
	var a: Vector3 = vista.world_to_screen(hp.x, hp.y, 1.0)
	var b: Vector3 = vista.world_to_screen(q[0], q[1], 0.0)
	gesti.down(Vector2(a.x, a.y), Time.get_ticks_msec())
	for i in range(1, 13):
		gesti.move_ev(Vector2(a.x, a.y).lerp(Vector2(b.x, b.y), i / 12.0))
	await get_tree().create_timer(0.6).timeout
	gesti.up(Vector2(b.x, b.y), Time.get_ticks_msec())


## prova della visuale girata in gioco normale (Luis 2026-11-24): n. 10 col pallone nella nostra metà, nessuno vicino;
## dopo 1,5 s il dito si appoggia lontano da lui e trascina verso destra (la visuale guarda a sinistra), il gioco non
## rallenta. Con `linea` poi disegna dal pallone al n. 11 (punti dello schermo della telecamera girata) e alza il dito.
func _scena_giro(att: R.Player, linea: bool) -> void:
	_metti_in_gioco()
	var dy := 1.0 if me == 0 else -1.0
	var cm: R.Player = m.team(me)[10]
	_sposta(att, 6.0, dy * -12.0)
	_sposta(cm, -18.0, dy * -2.0)
	m.ball.owner = att
	m.ball.last = att
	m.ball.x = att.x
	m.ball.y = att.y + 0.6 * dy
	m.ctrl[me] = att
	await get_tree().create_timer(1.5).timeout
	var a := Vector2(70.0, 320.0)
	gesti.down(a, Time.get_ticks_msec())
	print("giro: modo del dito = %s" % gesti.mode)
	for i in range(1, 25):
		gesti.move_ev(a.lerp(Vector2(300.0, 330.0), i / 24.0))
		await get_tree().process_frame
	gesti.up(Vector2(300.0, 330.0), Time.get_ticks_msec())
	print("giro: visuale girata di %.0f gradi, tempo x%.2f, pallone al n. %d" % [rad_to_deg(vista.user_yaw), ts, m.ball.owner.i + 1 if m.ball.owner != null else -1])
	if not linea:
		return
	await get_tree().create_timer(0.8).timeout
	var s0: Vector3 = vista.world_to_screen(m.ball.x, m.ball.y, 0.3)
	gesti.down(Vector2(s0.x, s0.y), Time.get_ticks_msec())
	for i in range(1, 21):
		var s1: Vector3 = vista.world_to_screen(cm.x, cm.y, 0.0)
		gesti.move_ev(Vector2(s0.x, s0.y).lerp(Vector2(s1.x, s1.y), i / 20.0))
		await get_tree().process_frame
	var fine: Dictionary = gesti.pts[-1] if not gesti.pts.is_empty() else {}
	print("giro_linea: fine linea (%.1f, %.1f), n. 11 in (%.1f, %.1f)" % [fine.get("x", NAN), fine.get("y", NAN), cm.x, cm.y])
	await get_tree().create_timer(0.4).timeout
	gesti.up(Vector2.ZERO, Time.get_ticks_msec())


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


## prova del dribbling: n. 10 col pallone e un difensore 6,5 m davanti; aperto il duello si tocca Dribbling.
## dribbling_ok / dribbling_ko: statistiche estreme (riesce o fallisce quasi sempre: il motore resta a caso col seme)
func _scena_dribbling(att: R.Player, nome: String) -> void:
	_metti_in_gioco()
	var dy := 1.0 if me == 0 else -1.0
	var dif: R.Player = m.team(1 - me)[3]
	_sposta(att, 4.0, dy * 8.0)
	_sposta(dif, 4.6, dy * 14.5)
	dif.fx = 0.0
	dif.fy = -dy
	if nome == "dribbling_ok" or nome == "dribbling_ko":
		var ok := nome == "dribbling_ok"
		att.st.dri = 99.0 if ok else 1.0
		dif.st.dif = 1.0 if ok else 99.0
		att.st.sub.erase("drb") # il dribbling guarda Dribbling e Contrasto: senza sotto-statistica vale la grande
		dif.st.sub.erase("ctr")
	m.ball.owner = att
	m.ball.last = att
	m.ball.x = att.x
	m.ball.y = att.y + 0.6 * dy
	m.ctrl[me] = att
	if _opzioni.has("giochetto"):   # --giochetto=ID: giochetto fisso (sim/skill.gd)
		m.skillForza = String(_opzioni.giochetto)
	while not m.duelFor(me):
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	_dribbling()
	print("prova dribbling: prenotato=%s" % m.dribBooked(me))


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
