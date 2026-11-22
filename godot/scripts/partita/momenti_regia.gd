# Regia dei momenti chiave: collega la logica (momenti.gd) alla partita vera (gioco.gd) e alla schermata tra le
# azioni (momenti_vista.gd). La crea gioco.gd quando l'avvio ha "momenti": true (o --momenti nelle prove).
#   - all'inizio: cronaca simulata fino alla prima azione, schermata, tocco → prima azione
#   - durante l'azione: gioco.gd chiama dopo_passi(sdt) dopo i passi del motore (prima che gli eventi si consumino)
#   - azione finita (dopo festa e replay, se è un gol): partita in pausa, resto simulato fino alla prossima azione,
#     schermata col minuto e il risultato; tocco → prossima azione
#   - dopo l'ultima: simulato fino al 90', schermata, tocco → fischio finale (evento "full": gioco.gd fa il resto)
extends Node

const Momenti := preload("res://scripts/partita/momenti.gd")
const MomentiVista := preload("res://scripts/partita/momenti_vista.gd")
const Minimappa := preload("res://scripts/partita/minimappa.gd")
const BOT_TOCCA_DOPO := 1.2    # s: il dito finto delle prove tocca "continua" dopo così

var g: Node                    # la scena della partita (gioco.gd)
var mo: Momenti
var vista: MomentiVista


func _init(gioco: Node) -> void:
	g = gioco
	name = "MomentiChiave"


func _ready() -> void:
	mo = Momenti.new(g.m, g.me, g._seme_partita)
	vista = MomentiVista.new()
	add_child(vista)
	vista.continua.connect(_continua)
	_intervallo.call_deferred()


## dopo i passi del motore (gioco._passi_motore), prima di gioco._eventi
func dopo_passi(sdt: float) -> void:
	if mo.stato != "azione":
		return
	mo.leggi(g.m, sdt)
	if mo.stato == "azione" and mo.azione_finita(g.m) and not (g.replay != null and g.replay.attivo()):
		mo.chiudi_azione(g.m)
		_intervallo()


## la schermata tra le azioni è aperta (la partita è ferma)
func in_intervallo() -> bool:
	return vista != null and vista.aperta()


func _intervallo() -> void:
	if g.stato != "partita":
		return
	g.paused = true
	g.gesti.cancel()
	g.hud.mostra_dribbling(false)
	g.hud.aiuto_visuale("")
	g.hud.rallenty(false)
	var ultimo := mo.indice >= 0
	var att: bool = ultimo and mo.piano[mo.indice].tipo == "att"
	var esito: String = mo.esiti[-1] if ultimo and not mo.esiti.is_empty() else ""
	var fino := mo.fino_alla_prossima()
	var righe := mo.simula_fino_a(g.m, fino, g.conta)
	g.hud.aggiorna(g.m, g.me)
	var pr := mo.prossima()
	var t0: Dictionary = g.m.teams[0]
	var t1: Dictionary = g.m.teams[1]
	var d := {
		"sigle": [t0.short, t1.short],
		"colori": [Minimappa.colore(t0.kit.shirt), Minimappa.colore(t1.kit.shirt)],
		"gol": [g.m.score[0], g.m.score[1]],
		"minuto": fino,
		"titolo": Momenti.testo_esito(esito, att) if ultimo else "Calcio d'inizio",
		"colore": Color("#ffe14a") if esito == "gol" else (Color("#ff6b6b") if esito == "subito" else Color.WHITE),
		"sotto": ("Azione %d di %d" % [mo.indice + 1, mo.piano.size()]) if ultimo else "%d azioni da giocare: il resto lo racconta la cronaca" % mo.piano.size(),
		"righe": righe,
		"prossima": _testo_prossima(pr),
		"tasto": "Gioca l'azione" if not pr.is_empty() else "Fischio finale",
	}
	vista.mostra(d)
	if g.bot != null: # prove col dito finto: continua da solo
		get_tree().create_timer(BOT_TOCCA_DOPO).timeout.connect(vista.premi)


static func _testo_prossima(pr: Dictionary) -> String:
	if pr.is_empty():
		return "Si arriva al 90'"
	var chi := "Attacchi tu" if pr.tipo == "att" else "Ti difendi"
	return "Prossima azione · %d' · %s" % [int(pr.minuto), chi]


func _continua() -> void:
	if g.stato != "partita":
		return
	if mo.prossima().is_empty():
		mo.fischio_finale(g.m)
		g.paused = false
		return
	mo.avvia_prossima(g.m)
	if g.replay != null:
		g.replay.buffer.svuota() # niente salto dal posto dell'azione prima nel replay
	g.hud.fade()
	g.ts = 1.0
	g.paused = false
	var att: bool = mo.piano[mo.indice].tipo == "att"
	g.hud.big("Attacca!" if att else "Difendi!", "g" if att else "b", 1300)
