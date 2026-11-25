# Falli sui contrasti (Luis 2026-11-24: "rimettere i falli, pochi"). Dal 2026-11-20 i falli venivano solo dalle
# scivolate, che nessuno fa più: in partita erano zero (niente punizioni, rigori, cartellini, vantaggio).
# Ora, solo con l'opzione "falli" della partita (falliOn, la accende il gioco):
#  - contrasto da dietro: il difensore che arriva sul portatore dalle sue spalle (o di fianco, un po' dietro) a volte
#    commette fallo invece di rubare il pallone; il contrasto frontale resta sempre pulito;
#  - fallo in ritardo: chi arriva di corsa addosso a uno che ha appena calciato (il pallone è già andato via).
# Quanto è probabile: angolo del contrasto, velocità di chi entra, sua bravura in difesa (meno brava = più falli),
# pioggia un po' di più; i giocatori della squadra della persona un po' meno (il contrasto "magnetico" è già un aiuto,
# ma un fallo della persona costa una punizione o un rigore che lei non ha scelto). Il portiere non fa falli.
# Il fallo usa foulCall (motion.gd): statistiche, giallo (secondo giallo = rosso, espulso), rigore se in area,
# vantaggio o punizione. Fallo in ritardo: su un tiro da fuori area niente; su un tiro in area si lascia andare il
# tiro e, se non è gol, rigore (penPend, falliStep); dopo un passaggio in area rigore; fuori area vantaggio alla
# squadra che ha calciato solo negli ultimi 35 m (se perde il pallone entro ADV_TIME si torna alla punizione),
# più indietro punizione subito.
# Numeri casuali solo dal seme della partita (rnd()), e solo con l'opzione accesa.
extends "motion.gd"

# angolo: coseno tra la direzione in cui guarda il portatore e la direzione verso chi entra (1 = davanti, -1 = dietro)
const FOUL_BEHIND_DOT := -0.35 # sotto: da dietro
const FOUL_SIDE_DOT := 0.1     # tra i due: di fianco, un po' dietro; sopra: frontale, sempre pulito
const FOUL_P_BEHIND := 0.90    # probabilità di fallo di un contrasto da dietro (a velocità e difesa di riferimento)
const FOUL_P_SIDE := 0.40      # ... di fianco
const FOUL_P_LATE := 0.18      # ... in ritardo (per ogni avversario che arriva di corsa su chi ha appena calciato)
const LATE_T := 0.3            # in ritardo: entro tanto dal calcio (s) ...
const LATE_R := 1.0            # ... a meno di tanto da chi ha calciato (m) ...
const LATE_V := 3.5            # ... andandogli addosso ad almeno questa velocità (m/s)
const LATE_ADV_MIN_Y := 15.0   # vantaggio sul fallo in ritardo solo da qui in avanti (m nel verso d'attacco: ultimi 35 m)
const FOUL_SPD_REF := 5.0      # velocità di chi entra a cui vale la probabilità di base (m/s)
const FOUL_SPD_MIN := 0.5      # limiti del fattore della velocità
const FOUL_SPD_MAX := 1.5
const FOUL_DIF_REF := 60.0     # difesa di riferimento ...
const FOUL_DIF_K := 0.015      # ... ogni punto sotto alza la probabilità di tanto (sopra la abbassa)
const FOUL_DIF_MIN := 0.5      # limiti del fattore della difesa
const FOUL_DIF_MAX := 1.6
const FOUL_RAIN := 1.25        # pioggia: si scivola, entrate più scomposte
const FOUL_HUMAN := 0.3        # giocatori della squadra della persona
const CARD_BEHIND := 0.35      # giallo per un fallo da dietro
const CARD_SIDE := 0.1         # ... di fianco
const CARD_LATE := 0.3         # ... in ritardo
const PEN_HOLD_T := 3.0        # rigore in sospeso: si aspetta l'esito del tiro al massimo tanto (s di gioco)
const FOUL_STUN := 0.5         # vantaggio: chi ha fatto fallo resta fermo tanto (s), così non riprova subito
const FOUL_CD := 1.0           # ... e non contrasta per tanto (s)

var penPend: Variant = null    # rigore in sospeso {team, score, t}: fallo in ritardo sul tiro in area, si aspetta l'esito
var lateKick: R.Kick = null    # calcio di cui si stanno controllando i falli in ritardo
var lateDone: Array = []       # ... avversari già controllati (uno solo tentativo a testa per calcio)


## coseno dell'angolo del contrasto di `o` su `c` (1 = davanti al portatore, -1 = alle sue spalle)
static func tackleDot(o: R.Player, c: R.Player) -> float:
	var dx: float = o.x - c.x
	var dy: float = o.y - c.y
	var d: float = C.hyp(dx, dy)
	var fn: float = C.hyp(c.fx, c.fy)
	if d < 0.01 or fn < 0.01:
		return 1.0 # sovrapposti o senza direzione: si considera frontale (pulito)
	return (c.fx * dx + c.fy * dy) / (d * fn)


## fattore della probabilità di fallo di `o`: velocità, difesa, pioggia, squadra della persona
func foulK(o: R.Player) -> float:
	var k: float = C.clamp_(C.hyp(o.vx, o.vy) / FOUL_SPD_REF, FOUL_SPD_MIN, FOUL_SPD_MAX)
	# meno contrasto (`ctr`) o più aggressività (scarto di `agg` da `fis`) = più falli
	k *= C.clamp_(1.0 + (FOUL_DIF_REF - (o.st.sv("ctr") - o.st.scarto("agg"))) * FOUL_DIF_K, FOUL_DIF_MIN, FOUL_DIF_MAX)
	if meteo == "pioggia":
		k *= FOUL_RAIN
	if human[o.team]:
		k *= FOUL_HUMAN
	return k


## contrasto riuscito di `o` sul portatore `c` (contacts): se arriva da dietro a volte è fallo. Ritorna true se fallo.
func foulTackle(o: R.Player, c: R.Player) -> bool:
	if o.pos == "P":
		return false
	var dot: float = tackleDot(o, c)
	if dot >= FOUL_SIDE_DOT:
		return false # frontale: pulito
	var behind: bool = dot < FOUL_BEHIND_DOT
	var pr: float = (FOUL_P_BEHIND if behind else FOUL_P_SIDE) * foulK(o)
	if not (rnd() < pr):
		return false
	o.contact = 0.0
	foulCall(o, c, rnd() < (CARD_BEHIND if behind else CARD_SIDE), "dietro" if behind else "fianco")
	return true


## pallone libero appena calciato: chi arriva di corsa addosso a chi l'ha calciato può fare fallo in ritardo.
## Ritorna true se c'è stato fallo (gioco fermo o vantaggio).
func lateFoul() -> bool:
	var k := ball.kick
	if k == null or k.age > LATE_T or k.kicker == null:
		return false
	var c: R.Player = k.kicker
	if c.off or c.pos == "P" or c.team != k.team:
		return false
	var dirA: float = -1.0 if c.team else 1.0
	var inBox: bool = absf(c.x) < BOX_W / 2.0 and c.y * dirA > HL - BOX_D
	var shot: bool = k.type == "shot" or ball.shot != null
	if shot and (not inBox or penPend != null):
		return false # tiro da fuori area: niente fallo in ritardo, fermerebbe un pallone che va in porta
	if lateKick != k:
		lateKick = k
		lateDone = []
	for o: R.Player in players:
		if o.team == c.team or o.off or o.state != "play" or o.stun > 0.0 or o.pos == "P" or lateDone.has(o):
			continue
		var dx: float = c.x - o.x
		var dy: float = c.y - o.y
		var d: float = C.hyp(dx, dy)
		if d > LATE_R:
			continue
		var v: float = (o.vx * dx + o.vy * dy) / maxf(d, 0.01) # velocità verso chi ha calciato
		if v < LATE_V:
			continue
		lateDone.append(o)
		if rnd() < FOUL_P_LATE * foulK(o):
			if shot: # tiro in area: si lascia andare il tiro, rigore se non è gol (falliStep)
				foulCall(o, c, rnd() < CARD_LATE, "ritardo", true)
				ev("advantage", {"team": c.team, "p": c})
				penPend = {"team": c.team, "score": score[c.team], "t": PEN_HOLD_T}
				return true
			foulCall(o, c, rnd() < CARD_LATE, "ritardo")
			return true
	return false


## rigore in sospeso (fallo in ritardo su un tiro in area): gol = vale il gol; tiro finito senza gol (parato, fuori,
## respinto, preso dalla difesa) = rigore; pallone a un compagno dopo il tiro (ribattuta) = vantaggio sfruttato.
func falliStep(dt: float) -> void:
	if penPend == null:
		return
	var tm: int = penPend.team
	if score[tm] != int(penPend.score) or phase == "goal":
		penPend = null
		return
	if phase == "full" or phase == "half":
		penPend = null
		return
	var b := ball
	penPend.t = float(penPend.t) - dt
	var over: bool = phase == "restart" or float(penPend.t) <= 0.0 or (b.owner != null and b.owner.team != tm) or (b.shot == null and b.kick == null and b.owner == null)
	if b.owner != null and b.owner.team == tm and b.owner.pos != "P":
		penPend = null # ribattuta presa da un compagno: si gioca
		return
	if over:
		penPend = null
		setRestart("penalty", tm, 0.0, 0.0)


## fallo in ritardo: si lascia correre se il pallone è della squadra di chi l'ha subito (passaggio o tiro in volo) e
## il fallo è negli ultimi 35 m (LATE_ADV_MIN_Y), dove l'azione può diventare un tiro; più indietro punizione
func lateAdvantageOk(on: R.Player) -> bool:
	var b := ball
	var dir: float = -1.0 if on.team else 1.0
	if on.y * dir < LATE_ADV_MIN_Y:
		return false
	if b.owner != null:
		return b.owner.team == on.team
	return b.kick != null and b.kick.team == on.team


## dopo un fallo col vantaggio: chi l'ha fatto si ferma un attimo e non riprova subito il contrasto
func afterFoul(by: R.Player) -> void:
	if not falliOn:
		return
	by.stun = maxf(by.stun, FOUL_STUN)
	by.tackleCd = maxf(by.tackleCd, FOUL_CD)
	by.contact = 0.0
