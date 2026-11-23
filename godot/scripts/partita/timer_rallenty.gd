# Timer del rallenty col pallone (Luis 2026-11-23: "nel caso di passaggio e tiro a rallenty metti un timer di 10
# secondi"). Duello, fuga e area di tiro rallentano il tempo finché dura la situazione: dopo RALLENTY_MAX_S secondi veri
# senza linea né tasto (Dribbling, Scatto) il rallenty finisce (il gioco chiama m.userCalm: il motore chiude duello o
# fuga e per un po' non li riapre allo stesso portatore) e il portatore continua da solo. Mentre il dito disegna il
# timer è fermo. Conti puri: gira anche nei test senza schermo. Il cerchio che si svuota lo disegna l'HUD.
extends RefCounted

const RALLENTY_MAX_S := 10.0   # durata massima del rallenty col pallone, in secondi veri

var passato := -1.0            # secondi veri dall'apertura del rallenty (−1 = nessun rallenty)
var portatore: Object = null   # portatore del rallenty in corso (un portatore nuovo fa ripartire il timer)


## A ogni fotogramma. dt = secondi veri, p = portatore nel rallenty (null = nessun rallenty), disegna = il dito sta
## disegnando una linea. Ritorna true una volta sola, quando il tempo è scaduto.
func passo(dt: float, p: Object, disegna: bool) -> bool:
	if p == null:
		azzera()
		return false
	if p != portatore:
		portatore = p
		passato = 0.0
	if disegna:
		return false
	passato += maxf(0.0, dt)
	if passato < RALLENTY_MAX_S:
		return false
	azzera()
	return true


func azzera() -> void:
	passato = -1.0
	portatore = null


## frazione del cerchio ancora piena (1 = appena aperto, 0 = scaduto); −1 = nessun rallenty
func frazione() -> float:
	if passato < 0.0 or portatore == null:
		return -1.0
	return clampf(1.0 - passato / RALLENTY_MAX_S, 0.0, 1.0)


## portatore nel rallenty col pallone della squadra `me` (duello non prenotato, fuga, area di tiro), o null.
## Stesse condizioni del rallenty di gioco.gd → velocita_voluta.
static func portatore_in_rallenty(m: Object, me: int) -> Object:
	if m == null or m.phase != "play":
		return null
	var c: Object = m.ball.owner
	if c == null or c.team != me:
		return null
	var booked: bool = m.dribBooked(me)
	if (m.duelFor(me) and not booked) or m.fleeFor(me) or (not booked and m.inZone(me)):
		return c
	return null
