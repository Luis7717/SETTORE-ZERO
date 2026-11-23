# Visuale girata dalla persona nel rallenty in attacco (duello, area di tiro) e nel calcio d'angolo: conti puri,
# porting di src/camuser.js (stessi nomi e numeri). L'angolo è uno "yaw" nello spazio orientato di camfit.gd:
# 0 = verso la porta avversaria, + = la telecamera guarda verso destra dello schermo, − = verso sinistra.
# Il gesto (dito che trascina) lo gestisce chi fa l'input: qui ci sono dragYaw e isCamDrag pronti da usare.
extends RefCounted

const CAM_USER_DEG_PER_SCREEN := 150.0         # dito per tutta la larghezza dello schermo = la visuale gira di tanto (gradi)
const CAM_USER_MAX := deg_to_rad(100.0)        # limite rispetto alla direzione d'attacco (rad)
const CAM_USER_START := 12.0                   # px in orizzontale prima che il gesto diventi rotazione (sotto è un tocco)
const CAM_USER_RETURN := 2.5                   # finito il rallenty l'angolo torna a 0 con questa velocità (1/s, tempo vero)
const CAM_USER_GRAB := -1.0                    # −1 = si "afferra" il campo (dito verso destra = la visuale guarda più a sinistra)
const CAM_USER_GOAL_YAW := deg_to_rad(40.0)    # area di tiro: oltre questo angolo la porta avversaria non si tiene più a schermo


## il pallone è fermo sulla bandierina per un calcio d'angolo (di chiunque): anche lì la visuale si gira col dito
static func corner_cam_on(m: Object) -> bool:
	return m != null and m.phase == "restart" and m.restart != null and m.restart.type == "corner" and m.restart.sulPosto()


## rimessa laterale della squadra tm col battitore pronto sulla linea (Luis 2026-11-23): visuale alle spalle del
## battitore che si gira col dito, come nel calcio d'angolo (le rimesse della CPU no)
static func throw_cam_on(m: Object, tm: int) -> bool:
	return m != null and m.phase == "restart" and m.restart != null and m.restart.type == "throw" and m.restart.team == tm and m.restart.sulPosto()


## ripresa con la visuale alle spalle del battitore che si gira col dito: calcio d'angolo (di chiunque) o nostra rimessa
static func restart_cam_on(m: Object, tm: int) -> bool:
	return corner_cam_on(m) or throw_cam_on(m, tm)


## visuale che si può girare: calcio d'angolo, oppure rallenty (gioco, pallone a un giocatore di tm, duello, fuga o area di tiro)
static func user_cam_on(m: Object, tm: int) -> bool:
	if restart_cam_on(m, tm):
		return true
	if m == null or m.phase != "play":
		return false
	if m.headFor(tm): # colpo di testa controllato: come nel rallenty col pallone (Luis 2026-11-23)
		return true
	var c: Object = m.ball.owner
	if c == null or c.team != tm:
		return false
	return m.duelFor(tm) or m.fleeFor(tm) or m.inZone(tm)


## angolo mentre si trascina: parte da yaw0 (angolo quando il dito si è appoggiato) e segue lo spostamento orizzontale
## dx (px) in proporzione alla larghezza dello schermo w (px), entro ±CAM_USER_MAX
static func drag_yaw(yaw0: float, dx: float, w: float) -> float:
	var k := deg_to_rad(CAM_USER_DEG_PER_SCREEN) / maxf(1.0, w)
	return clampf(yaw0 + CAM_USER_GRAB * dx * k, -CAM_USER_MAX, CAM_USER_MAX)


## il dito si è spostato abbastanza, e più di lato che in verticale, per girare la visuale?
static func is_cam_drag(dx: float, dy: float) -> bool:
	return absf(dx) >= CAM_USER_START and absf(dx) > absf(dy)


## angolo a ogni fotogramma: nel rallenty (o mentre si disegna) resta quello scelto; fuori torna dolcemente a 0
## (rdt = tempo vero in secondi), e del tutto: al rallenty dopo si riparte dritti
static func relax_yaw(yaw: float, hold: bool, rdt: float) -> float:
	if hold:
		return clampf(yaw, -CAM_USER_MAX, CAM_USER_MAX)
	var y := yaw * exp(-CAM_USER_RETURN * maxf(0.0, rdt))
	return 0.0 if absf(y) < 1e-3 else y


## nell'area di tiro la porta avversaria resta a schermo solo con la visuale poco girata
static func keep_goal(zone: bool, yaw: float) -> bool:
	return zone and absf(yaw) <= CAM_USER_GOAL_YAW
