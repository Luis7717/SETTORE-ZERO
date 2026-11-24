# Difesa sui calci d'angolo (solo Godot, opzione "rifiniture" della partita; senza, motore identico al JS).
# Luis 2026-11-24 (richiesta approvata): "la CPU segna troppo dagli angoli" (10-20% degli angoli, obiettivo 3-8%).
# - Marcatura (solo la squadra umana, i cui difensori sugli angoli li muove la CPU; CORNER_MARK_CPU): all'angolo
#   avversario i difensori di movimento prendono in consegna gli attaccanti più pericolosi in area (bravura di testa e
#   vicinanza alla porta) e gli stanno attaccati dal lato della porta, anche mentre il cross vola; CORNER_ZONAL restano
#   a zona. Chi va sul pallone (chase) ci va lo stesso; le linee disegnate e il dito hanno sempre la precedenza.
#   Finito il volo del cross la marcatura resta per la seconda palla (CORNER_SECOND_*), poi si torna a zona.
#   La CPU sui nostri angoli resta a zona: con la marcatura anche lì i gol della persona da angolo si dimezzavano.
# - Contesa aerea (tutte e due le squadre): sul cross dell'angolo un difensore nella propria area si contende il pallone
#   anche un po' più lontano (AIR_MARK_R invece di 0,95 m) e parte un po' avvantaggiato (CORNER_AIR_EDGE).
# - Portiere (tutti e due): esce anche sui cross che scendono a meno di 6 m dalla porta su cui è in anticipo di poco
#   (CORNER_GK_* in ai.gd) e sotto il pallone vince un po' più spesso (CORNER_GK_WIN).
# Numeri: tools/banco_angoli.gd e DECISIONI.md (2026-11-24). Niente numeri casuali in più.
extends "riprese.gd"

const CORNER_MARK_GAP := 0.9   # il marcatore sta a tanto dall'attaccante, dal lato della porta (m)
const CORNER_MARK_LEAD := 0.25 # ... e lo anticipa: posizione prevista fra tanti secondi
const CORNER_MARK_ZONE := 20.0 # si marcano gli attaccanti entro tanti metri dal centro della porta (m)
const CORNER_MARK_TES := 1.0   # pericolosità = colpi di testa × questo − distanza dalla porta × CORNER_MARK_DIST
const CORNER_MARK_DIST := 2.0
const CORNER_ZONAL := 2        # difensori di movimento lasciati a zona (fuori dalla marcatura): seconda palla
const AIR_MARK_R := 1.6        # sul cross dell'angolo un difensore in area si contende il pallone fino a qui (m)
const CORNER_AIR_EDGE := 0.15  # ... con questa probabilità in più nella contesa aerea
const CORNER_GK_WIN := 0.12    # portiere sotto il cross dell'angolo: probabilità in più di vincere il contrasto aereo
const CORNER_MARK_CPU := false # marca anche la CPU sugli angoli della persona (false = solo la squadra umana)
const CORNER_SECOND_T := 3.0   # finito il volo del cross, la marcatura resta per la seconda palla al massimo tanto (s) ...
const CORNER_SECOND_R := 25.0  # ... finché il pallone resta entro tanti metri dalla porta e non lo prende chi difende

var cornerTaker: R.Player = null  # battitore dell'angolo in corso (finché non calcia)
var cornerKick: R.Kick = null     # il cross dell'angolo, finché è in volo
var cornerMarks: Dictionary = {}  # indice del difensore -> indice dell'attaccante da marcare (angolo in corso)
var cornerAtk: int = -1           # squadra che batte l'angolo in corso
var cornerEnd: float = -1.0       # istante (time) in cui è finito il volo del cross; -1 = non ancora


## a ogni pensiero (think): riconosce l'angolo e il suo cross; finito il volo la marcatura resta un po' per la
## seconda palla (CORNER_SECOND_*), poi si torna a zona
func cornerTrack() -> void:
	if not rifiniture:
		return
	var b := ball
	if phase == "restart" and restart.type == "corner":
		if cornerTaker != restart.taker or cornerMarks.is_empty():
			cornerTaker = restart.taker
			cornerKick = null
			cornerAtk = restart.team
			cornerEnd = -1.0
			_cornerAssign(restart.team)
		return
	if cornerTaker != null and phase == "play" and b.kick != null and b.kick.kicker == cornerTaker and cornerKick == null:
		cornerKick = b.kick
		cornerTaker = null
		return
	if cornerKick != null and b.kick == cornerKick and phase == "play":
		return
	if cornerKick != null:
		cornerEnd = time
	cornerTaker = null
	cornerKick = null
	if not cornerMarks.is_empty() and not _cornerSecond():
		cornerMarks.clear()


# seconda palla dopo il cross: marcatura ancora attiva
func _cornerSecond() -> bool:
	var b := ball
	var gy: float = (-1.0 if cornerAtk else 1.0) * HL # porta di chi difende
	if phase != "play" or cornerEnd < 0.0 or time - cornerEnd > CORNER_SECOND_T:
		return false
	if b.owner != null and b.owner.team != cornerAtk:
		return false
	return C.hyp(b.x, b.y - gy) < CORNER_SECOND_R


## il pallone è il cross di un angolo ancora in volo (o l'angolo sta per essere battuto)
func cornerLive() -> bool:
	return rifiniture and (cornerKick != null and ball.kick == cornerKick or cornerTaker != null)


## p difende l'angolo in corso, nella propria area
func cornerDefender(p: R.Player) -> bool:
	if not cornerLive() or p.pos == "P":
		return false
	var atk: int = cornerKick.team if cornerKick != null else cornerTaker.team
	return p.team != atk and inOwnBox(p)


# marcatori: gli attaccanti più pericolosi vicino alla porta, ognuno al difensore libero più vicino
func _cornerAssign(atk: int) -> void:
	cornerMarks.clear()
	var dfn: int = 1 - atk
	if not CORNER_MARK_CPU and not human[dfn]:
		return
	var gy: float = (-1.0 if atk else 1.0) * HL # porta di chi difende
	var foes: Array = []
	for o: R.Player in players:
		if o.team == atk and not o.off and o.pos != "P" and o != cornerTaker and C.hyp(o.x, o.y - gy) < CORNER_MARK_ZONE:
			foes.append(o)
	foes = stableSort(foes, func(o: R.Player) -> float: return -(o.st.tes * CORNER_MARK_TES - C.hyp(o.x, o.y - gy) * CORNER_MARK_DIST))
	var mine: Array = []
	for p: R.Player in players:
		if p.team == dfn and not p.off and p.pos != "P":
			mine.append(p)
	var n: int = mini(foes.size(), maxi(0, mine.size() - CORNER_ZONAL))
	var taken := {}
	for k in n:
		var o: R.Player = foes[k]
		var bp: R.Player = null
		var bd: float = 1e9
		for p: R.Player in mine:
			var key: int = p.team * 11 + p.i
			if taken.has(key):
				continue
			var d: float = C.hyp(p.x - o.x, p.y - o.y)
			if d < bd:
				bd = d
				bp = p
		if bp != null:
			taken[bp.team * 11 + bp.i] = true
			cornerMarks[bp.team * 11 + bp.i] = o.team * 11 + o.i


## marcatura sull'angolo: true se ha scelto la destinazione di p (chi va sul pallone resta al pallone)
func cornerMark(p: R.Player) -> bool:
	if not rifiniture or cornerMarks.is_empty() or p.pos == "P":
		return false
	var key: int = p.team * 11 + p.i
	if not cornerMarks.has(key):
		return false
	var ch: R.Chase = chase[p.team]
	if phase == "play" and ch != null and (ch.p == p or ch.p2 == p):
		return false
	var o: R.Player = players[cornerMarks[key]]
	if o.off:
		return false
	var gy: float = (-1.0 if p.team else 1.0) * -HL # propria porta
	var ox: float = o.x + o.vx * CORNER_MARK_LEAD
	var oy: float = o.y + o.vy * CORNER_MARK_LEAD
	var ux: float = -ox
	var uy: float = gy - oy
	var n: float = C.orf(C.hyp(ux, uy), 1.0)
	p.tx = C.clamp_(ox + ux / n * CORNER_MARK_GAP, -HW + 1.0, HW - 1.0)
	p.ty = C.clamp_(oy + uy / n * CORNER_MARK_GAP, -HL + 0.5, HL - 0.5)
	p.sprint = phase == "play"
	return true


## contesa aerea (motion.gd aerialDuel): raggio entro cui l'avversario q si contende il pallone alto
func airDuelR(q: R.Player) -> float:
	return AIR_MARK_R if cornerDefender(q) else super(q)


func headDuelEdge(p: R.Player, o: R.Player) -> float:
	var e: float = super(p, o)
	if cornerDefender(p):
		e += CORNER_AIR_EDGE
	elif cornerDefender(o):
		e -= CORNER_AIR_EDGE
	return e


## portiere sotto il pallone alto (motion.gd gkContest): probabilità in più sul cross dell'angolo
func gkClaimBonus(g: R.Player) -> float:
	return CORNER_GK_WIN if (cornerLive() and cornerKick != null) else super(g)
