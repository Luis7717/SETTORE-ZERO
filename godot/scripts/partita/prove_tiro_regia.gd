# Regia dell'allenamento libero dentro la partita (scripts/partita/gioco.gd, tipo "prove"): crea la logica
# (prove_tiro.gd) e l'interfaccia (prove_tiro_hud.gd), la chiama attorno ai passi del motore, salva il record nella
# carriera (record_prove.gd, campo `prove`) e gestisce "Riprova" ed "Esci".
# Prova scelta: opzione `prova` di avvia() (dall'app) o `--prove=tiri|punizioni|rigori` da riga di comando.
# Con `--bot` un tiratore finto tira da solo verso un angolo a caso (col seme), per le prove a schermo.
extends Node

const ProveTiro := preload("res://scripts/partita/prove_tiro.gd")
const ProveHud := preload("res://scripts/partita/prove_tiro_hud.gd")
const RecordProve := preload("res://scripts/carriera/record_prove.gd")
const SimRng := preload("res://sim/rng.gd")
const C := preload("res://sim/core.gd")
const RIPROVA_PASSO := 7919   # Riprova: seme nuovo (posti diversi) ma sempre dallo stesso seme di partenza
const BOT_ATTESA := 1.2       # s di gioco prima che il tiratore finto tiri
const BOT_MARGINE := 0.5      # m dal palo dove mira il tiratore finto

var gioco: Node               # scripts/partita/gioco.gd
var logica: ProveTiro = null
var hud: ProveHud
var prova := "tiri"
var seme := 1
var giri := 0                 # "Riprova" premuti
var nuovo_record := false
var _bot: SimRng = null
var _bot_t := 0.0


func avvia(g: Node) -> void:
	gioco = g
	prova = String(g._avvio.get("prova", g._opzioni.get("prove", "tiri")))
	if not ProveTiro.PROVE.has(prova):
		prova = "tiri"
	seme = int(g._seme_partita)
	hud = ProveHud.new()
	add_child(hud)
	hud.record = RecordProve.record(_stato_carriera(), prova)
	hud.riprova.connect(ricomincia)
	hud.esci.connect(func() -> void: gioco._finisci(false))
	if g._opzioni.has("bot"):
		_bot = SimRng.new(seme + 99)
	g.hud.big(ProveTiro.NOMI[prova], "", 1800, "Allenamento libero")
	_nuova_logica()


func _nuova_logica() -> void:
	hud.azzera()
	nuovo_record = false
	logica = ProveTiro.new(gioco.m, self, prova, seme + giri * RIPROVA_PASSO)


## "Riprova": stessa prova, posti nuovi
func ricomincia() -> void:
	giri += 1
	gioco.paused = false
	gioco.gesti.cancel()
	_nuova_logica()


# ---------------------------------------------------------------- attorno ai passi del motore
func before() -> void:
	if logica != null:
		logica.before()


func after(dt: float) -> void:
	if logica == null:
		return
	if _bot != null:
		_tiratore_finto(dt)
	logica.after(dt)


# ---------------------------------------------------------------- `ui` della logica
func stato(prova_: String, tentativo: int, tentativi: int, punti: int) -> void:
	_bot_t = 0.0
	hud.stato(prova_, tentativo, tentativi, punti)


func esito(gol: bool, punti: int, nota: String) -> void:
	hud.esito(gol, punti, nota)


## prova finita: record salvato nella carriera (se c'è), partita ferma e scheda finale
func fine(r: Dictionary) -> void:
	var s := _stato_carriera()
	var prima := RecordProve.record(s, prova)
	nuovo_record = RecordProve.aggiorna(s, prova, int(r.punti))
	if nuovo_record:
		var c: Object = _carriera()
		if c != null:
			c.save()
	hud.record = prima if not nuovo_record else int(r.punti)
	gioco.paused = true
	gioco.gesti.cancel()
	gioco.hud.mostra_dribbling(false)
	gioco.hud.aiuto_visuale("")
	gioco.hud.rallenty(false)
	hud.mostra_fine(r, nuovo_record)
	if gioco._opzioni.has("esci-a-fine"):
		print(riassunto())
	elif _bot != null: # il tiratore finto preme "Riprova" una volta, poi "Esci"
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if giri == 0: hud.premi_riprova()
			else: hud.premi_esci())


## fine dell'allenamento ("Esci" dalla scheda o dalla pausa): risultato all'app, oppure si esce (prove)
func termina(forfait: bool) -> void:
	gioco.stato = "fine"
	gioco.abbandonata = forfait
	gioco.gesti.enabled = false
	gioco.gesti.cancel()
	gioco.audio.folla(0.0)
	gioco.hud.nascondi_overlay()
	hud.chiudi()
	if gioco._opzioni.has("esci-a-fine"):
		print(riassunto())
		gioco._esci()
	elif gioco.avviata_da_app():
		gioco._emetti_finita()
	else:
		print(riassunto()) # prova da riga di comando: il risultato resta nel registro
		gioco._esci()


func riassunto() -> String:
	if logica == null:
		return "prove: niente"
	var r := logica.riassunto()
	return "prove %s: punti %d · gol %d su %d · %s · record %d%s" % [prova, r.punti, r.gol, r.tentativi,
		"finita" if logica.finished else "in corso", hud.record, " (nuovo)" if nuovo_record else ""]


# ---------------------------------------------------------------- carriera
# solo dalla carriera (App.allenamento_libero): le prove da riga di comando non toccano il salvataggio vero
func _carriera() -> Object:
	if gioco == null or not gioco.avviata_da_app():
		return null
	var app := get_node_or_null("/root/App")
	if app == null:
		return null
	var c: Variant = app.get("carriera")
	return c if c is Object else null


func _stato_carriera() -> Dictionary:
	var c := _carriera()
	if c == null:
		return {}
	var s: Variant = c.get("s")
	return s if s is Dictionary else {}


# ---------------------------------------------------------------- tiratore finto (--bot)
func _tiratore_finto(dt: float) -> void:
	var m = gioco.m
	if logica.fase != "tiro" or m.ball.owner != logica.campione:
		return
	_bot_t += dt
	if _bot_t < BOT_ATTESA:
		return
	var lato := -1.0 if _bot.next() < 0.5 else 1.0
	var tx := lato * (C.GW / 2.0 - BOT_MARGINE) * (0.4 + 0.6 * _bot.next())
	var curva := (_bot.next() - 0.5) * (6.0 if prova == "punizioni" else 1.0)
	m.userKick(0, {"type": "shot", "tx": tx, "ty": C.HL, "th": 0.3 + _bot.next() * 1.8, "curve": curva})
