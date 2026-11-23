# Visuale girata col dito: la parte del gesto (porting della metà "input" di src/camuser.js). Conti puri, niente nodi:
# girano anche nei test senza schermo. L'angolo è uno "yaw" come in src/camfit.js: 0 = verso la porta avversaria,
# + = la telecamera guarda verso destra dello schermo, − = verso sinistra.
# La metà "telecamera" (ritorno dolce a 0, porta tenuta a schermo nell'area di tiro) è della vista
# (scripts/partita/camuser.gd, altro lavoro): qui solo quello che serve al gesto.
extends RefCounted

const SimMatchScript := preload("res://sim/match.gd")
const R := preload("res://sim/records.gd")

const CAM_USER_DEG_PER_SCREEN := 150.0         # dito trascinato per tutta la larghezza dello schermo = la visuale gira di tanto (gradi)
const CAM_USER_MAX := deg_to_rad(100.0)        # limite rispetto alla direzione d'attacco (rad)
const CAM_USER_START := 12.0                   # px in orizzontale prima che il gesto diventi rotazione (sotto è un tocco)
const CAM_USER_GRAB := -1.0                    # −1 = si "afferra" il campo: dito verso destra = la visuale guarda più a sinistra


## il pallone è fermo sulla bandierina per un calcio d'angolo (di chiunque): anche lì la visuale si gira col dito
static func corner_cam_on(m: SimMatchScript) -> bool:
	return m != null and m.phase == "restart" and m.restart != null and m.restart.type == "corner" and m.restart.sulPosto()


## visuale che si può girare: calcio d'angolo, oppure rallenty (in gioco, pallone a un giocatore di tm, duello, fuga o area di tiro)
static func user_cam_on(m: SimMatchScript, tm: int) -> bool:
	if corner_cam_on(m):
		return true
	if m == null or m.phase != "play":
		return false
	if m.headFor(tm): # colpo di testa controllato: come nel rallenty col pallone (Luis 2026-11-23)
		return true
	var c: R.Player = m.ball.owner
	if c == null or c.team != tm:
		return false
	return m.duelFor(tm) or m.fleeFor(tm) or m.inZone(tm)


## angolo mentre si trascina: parte da yaw0 e segue lo spostamento orizzontale dx (px) rispetto alla larghezza w (px)
static func drag_yaw(yaw0: float, dx: float, w: float) -> float:
	var k := deg_to_rad(CAM_USER_DEG_PER_SCREEN) / maxf(1.0, w)
	return clampf(yaw0 + CAM_USER_GRAB * dx * k, -CAM_USER_MAX, CAM_USER_MAX)


## il dito si è spostato abbastanza, e più di lato che in verticale, per girare la visuale?
static func is_cam_drag(dx: float, dy: float) -> bool:
	return absf(dx) >= CAM_USER_START and absf(dx) > absf(dy)
