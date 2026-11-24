# Colpo di testa controllato (Luis 2026-11-22: "non ho mai colpito di testa nel gioco").
# Un pallone alto (cross, lancio, angolo) di un compagno sta per arrivare a un attaccante della squadra umana vicino alla
# porta avversaria: si apre il fermatempo (headWin). Il giocatore va sul punto del colpo e diventa il controllato; la
# persona disegna la linea: verso la porta = colpo di testa lì (precisione secondo `tes`), verso un compagno o il campo
# = sponda di testa. Se non disegna niente il pallone è perso: nessun compagno lo tocca finché il momento del colpo non
# è passato (gli passa sopra, lo prende la difesa o il portiere). Senza fermatempo tutto resta come prima.
# Solo con l'opzione "testa" della partita (headCtl): le partite di confronto col JS restano identiche.
# Quanto dura il fermatempo in secondi veri lo decide il gioco (scripts/partita/fermatempo_testa.gd).
extends "falli.gd"

const HEAD_WIN_T := 1.0     # il fermatempo si apre quando il colpo è previsto entro questo tempo di partita (s)
const HEAD_WIN_MIN := 0.25  # ... ma non se manca meno di così (troppo tardi per disegnare) (s)
const HEAD_LATE := 0.35     # passato il momento previsto di tanto senza colpo, il fermatempo si chiude (s)
const HEAD_LOST_T := 0.8    # pallone perso (niente linea): chi doveva colpire non lo tocca per questo tempo ancora (s)
const HEAD_REACH := 0.95    # distanza dal pallone a cui il giocatore lo colpisce (come reachOf) (m)
const HEAD_LOOK := 1.6      # previsione del volo fino a questo tempo (s)
const HEAD_STEP := 3        # ... controllando un punto ogni tanti passi da 1/60 s
const HEAD_PASS_V0 := 8.0   # sponda di testa: velocità base (m/s), più la bravura
const HEAD_DEF_MARGIN := 0.2 # niente fermatempo se un avversario (portiere compreso) arriva sul punto prima di tanto (s):
                            # quel pallone è suo, non è un'occasione vera
const HEAD_DUEL_EDGE := 0.2 # contrasto aereo: chi colpisce con la linea già disegnata è in anticipo (probabilità in più)
const HEAD_DUEL_R := 2.0    # un difensore arriva sul pallone e chi deve colpire è entro tanto: salto conteso (m)
const HEAD_HUMAN_SIG := 0.9 # la linea disegnata è un po' più precisa del colpo automatico


## fermatempo del colpo di testa aperto per la squadra T, in attesa della linea
func headFor(tm: int) -> bool:
	return headWin != null and headWin.team == tm and not headWin.aimed and not headWin.lost and phase == "play"


## tempo del fermatempo finito senza linea (lo decide il gioco): non si può più disegnare, nessun compagno tocca il
## pallone finché il momento del colpo non è passato (poi endHead "perso")
func headExpire() -> void:
	if headWin != null and not headWin.aimed:
		headWin.lost = true


## tempo di partita che manca al colpo previsto (s)
func headLeft() -> float:
	return maxf(0.0, headWin.tc - headWin.age) if headWin != null else 0.0


## durante il fermatempo i compagni non toccano il pallone (senza linea nessuno, con la linea solo chi colpisce)
func headSkip(p: R.Player) -> bool:
	var hw := headWin
	return hw != null and p.team == hw.team and (not hw.aimed or p != hw.p)


## chi deve colpire corre sul punto del colpo (chiamata da assign); true se l'ha guidato
func headRun(p: R.Player) -> bool:
	var hw := headWin
	if hw == null or hw.p != p:
		return false
	p.tx = hw.x
	p.ty = hw.y
	p.sprint = C.hyp(hw.x - p.x, hw.y - p.y) > 1.0
	return true


## a ogni passo: chiude il fermatempo quando non vale più, o lo apre su un lancio alto della squadra umana
func updateHead(dt: float) -> void:
	var b := ball
	var hw := headWin
	if hw != null:
		hw.age += dt
		if phase != "play" or b.owner != null or b.kick != hw.kick:
			endHead("toccato")
		elif hw.age > hw.tc + HEAD_LATE:
			endHead("passato" if hw.aimed else "perso")
		return
	if not headCtl or phase != "play" or b.owner != null or b.shot != null:
		return
	var k := b.kick
	if k == null or k.type != "loft" or not human[k.team] or k == _headSeen:
		return
	var w := headFind(k.team)
	if w == null:
		return
	if w.tc < HEAD_WIN_MIN:
		_headSeen = k # troppo tardi: per questo lancio niente fermatempo
		return
	if w.tc > HEAD_WIN_T:
		return # ancora presto: si riprova al prossimo passo
	_headSeen = k
	w.kick = k
	headWin = w
	ctrl[k.team] = w.p
	move[k.team] = null
	ev("head_win", {"team": k.team, "p": w.p, "t": w.tc, "h": w.h})


var _headSeen: R.Kick = null # ultimo lancio già valutato (un fermatempo solo per lancio)


## primo punto del volo, vicino alla porta avversaria e ad altezza di testa, dove un compagno può arrivare in tempo
func headFind(tm: int) -> R.HeadWin:
	var b := ball
	var dir: float = -1.0 if tm else 1.0
	var s := b.physCopy()
	var n: int = int(HEAD_LOOK * 60.0)
	var k: int = 0
	var oppT: float = 1e9 # primo momento in cui un avversario può prendere il pallone (s)
	while k < n:
		for j in HEAD_STEP:
			C.ballPhys(s, 1.0 / 60.0, roll)
		k += HEAD_STEP
		var tk: float = k / 60.0
		if oppT > 1e8 and headOppReach(tm, s, tk):
			oppT = tk
		if s.h < HEAD_LO or s.h > HEAD_HI or C.hyp(s.x, s.y - dir * HL) > AIR_SHOT_RANGE - 0.5:
			if s.h < VOLLEY_LO and s.vh < 0.0:
				return null # caduto senza passare ad altezza di testa in zona
			continue
		var best: R.Player = null
		var bd: float = 1e9
		for p: R.Player in players:
			if p.team != tm or p.off or p.pos == "P" or p.state != "play" or p.stun > 0.0 or p == b.kick.kicker or dblBan(p):
				continue
			var d: float = C.hyp(p.x - s.x, p.y - s.y)
			if d - HEAD_REACH <= vmax(p) * maxf(0.0, tk - 0.12) and d < bd:
				bd = d
				best = p
		if best == null:
			continue
		# un avversario prende il pallone prima (più indietro sul volo) o arriva sul punto chiaramente prima del nostro:
		# il pallone è suo, non un'occasione vera
		if oppT < tk - HEAD_DEF_MARGIN or headOppETA(tm, s) < 0.12 + maxf(0.0, bd - HEAD_REACH) / vmax(best) - HEAD_DEF_MARGIN:
			return null
		var w := R.HeadWin.new()
		w.team = tm
		w.p = best
		w.x = s.x
		w.y = s.y
		w.h = s.h
		w.tc = tk
		return w
	return null


## primo avversario della squadra T che arriva a toccare il pallone `s` (fermo lì): tempo di corsa (s), 1e9 se nessuno
func headOppETA(tm: int, s: R.Ball) -> float:
	var best: float = 1e9
	for o: R.Player in players:
		var lr := _oppLimReach(tm, o, s)
		if lr.is_empty() or s.h > lr[0]:
			continue
		best = minf(best, 0.12 + maxf(0.0, C.hyp(o.x - s.x, o.y - s.y) - lr[1]) / vmax(o))
	return best


## [altezza massima, raggio] a cui l'avversario o tocca il pallone `s`; vuoto se non conta (fermo, portiere fuori area).
## Portiere nella sua area con le mani (fino a GK_HAND_HI), difensore di testa vicino alla sua porta (fino a HEAD_HI),
## altrimenti fino a 1,7 m; il raggio è quello vero del contatto (sui passaggi avversari il raggio difensivo)
func _oppLimReach(tm: int, o: R.Player, s: R.Ball) -> Array:
	if o.team == tm or o.off or o.state != "play" or o.stun > 0.0:
		return []
	if o.pos == "P":
		return [C.GK_HAND_HI, GK_BOX_REACH] if inOwnBox(o) else []
	var dirO: float = 1.0 if tm else -1.0 # verso d'attacco degli avversari
	return [HEAD_HI if C.hyp(s.x, s.y + dirO * HL) < HEAD_CLEAR_ZONE else 1.7, reachOf(o)]


## un avversario della squadra T può toccare il pallone `s` al tempo tk? Il portiere nella sua area con le mani
## (fino a GK_HAND_HI), un difensore di testa vicino alla sua porta (fino a HEAD_HI), altrimenti fino a 1,7 m
func headOppReach(tm: int, s: R.Ball, tk: float) -> bool:
	for o: R.Player in players:
		var lr := _oppLimReach(tm, o, s)
		if lr.is_empty() or s.h > lr[0]:
			continue
		if C.hyp(o.x - s.x, o.y - s.y) - lr[1] <= vmax(o) * maxf(0.0, tk - 0.12):
			return true
	return false


## l'avversario p sta per toccare il pallone alto mentre per noi c'è il fermatempo e chi deve colpire è vicino?
func headContestable(p: R.Player) -> bool:
	var hw := headWin
	if hw == null or p.team == hw.team or p.pos == "P" or ball.h < HEAD_LO:
		return false
	var q := hw.p
	return q.state == "play" and q.stun <= 0.0 and C.hyp(q.x - ball.x, q.y - ball.y) < HEAD_DUEL_R


## salto conteso tra l'avversario p e chi deve colpire: come aerialDuel (colpi di testa, distanza) più il vantaggio
## di chi ha la linea già disegnata. Ritorna il vincitore
func headContest(p: R.Player) -> R.Player:
	var b := ball
	var q := headWin.p
	var dq: float = C.hyp(q.x - b.x, q.y - b.y)
	var dp: float = C.hyp(p.x - b.x, p.y - b.y)
	var win: float = C.clamp_(0.5 + AIR_TES_K * (q.st.tes - p.st.tes) / 100.0 + (dp - dq) * AIR_DIST_K + headDuelEdge(q, p), AIR_WIN_MIN, AIR_WIN_MAX)
	var w: R.Player = q if rnd() < win else p
	ev("aerial", {"p": w, "o": p if w == q else q})
	return w


## contrasto aereo tra p (il più vicino) e o: vantaggio per chi colpisce con la linea già disegnata
func headDuelEdge(p: R.Player, o: R.Player) -> float:
	var hw := headWin
	if hw == null or not hw.aimed:
		return 0.0
	if p == hw.p:
		return HEAD_DUEL_EDGE
	if o == hw.p:
		return -HEAD_DUEL_EDGE
	return 0.0


## la persona ha disegnato la linea: spec {goal: true, tx, th} = in porta, oppure {tx, ty} = sponda nel campo.
## Il colpo parte appena il pallone arriva alla testa. false se non c'è un fermatempo aperto per la squadra T.
func userHeader(tm: int, spec: Dictionary) -> bool:
	if not headFor(tm):
		return false
	var hw := headWin
	hw.aimed = true
	hw.goal = bool(spec.get("goal", false))
	hw.ax = float(spec.get("tx", 0.0))
	hw.ay = float(spec.get("ty", 0.0))
	hw.ah = float(spec.get("th", 1.0))
	ev("head_aim", {"team": tm, "p": hw.p, "goal": hw.goal})
	return true


func endHead(reason: String) -> void:
	var hw := headWin
	if hw == null:
		return
	headWin = null
	if reason == "perso" and ball.owner == null:
		ball.noP = hw.p
		ball.noT = HEAD_LOST_T
	ev("head_end", {"team": hw.team, "p": hw.p, "reason": reason})


## colpo diretto dalla linea (chiamata da airHit quando colpisce chi ha il fermatempo con la linea già disegnata)
func headStrike(p: R.Player, kind: String) -> void:
	var b := ball
	var hw := headWin
	var tm := p.team
	var k := b.kick
	if k != null and k.team == tm and k.kicker != p:
		lastPass = {"from": k.kicker, "to": p}
	var head: bool = kind == "header"
	var skill: float = p.st.tes if head else p.st.tir
	var press: float = 1.3 if nearOpp(p.x, p.y, tm) < 1.5 else 1.0
	var sig: float = ((4.0 if head else 3.0) + (100.0 - skill) * (0.09 if head else 0.08)) * press * HEAD_HUMAN_SIG
	var tx: float
	var ty: float
	if hw.goal:
		tx = C.clamp_(hw.ax, -GW / 2.0 - 1.0, GW / 2.0 + 1.0)
		ty = (-1.0 if tm else 1.0) * HL
	else:
		tx = hw.ax
		ty = hw.ay
	var dx: float = tx - b.x
	var dy: float = ty - b.y
	var D: float = C.orf(C.hyp(dx, dy), 1.0)
	var a: float = gauss() * sig * PI / 180.0
	var ca: float = F.cos_(a)
	var sa: float = F.sin_(a)
	var ux: float = (dx * ca - dy * sa) / D
	var uy: float = (dx * sa + dy * ca) / D
	headWin = null
	if hw.goal:
		var v: float = (HEAD_V0 + skill * 0.06) if head else (VOLLEY_V0 + skill * 0.12)
		var th: float = maxf(0.05, C.clamp_(hw.ah, 0.1, GH + 0.3) + gauss() * sig * 0.02 * D)
		var Tt: float = maxf(0.15, D / v)
		b.vx = ux * v
		b.vy = uy * v
		b.vh = (th - b.h + 0.5 * G * Tt * Tt) / Tt
		b.kick = R.Kick.make(tm, p, "shot", 0.0, [], true)
		detectShot()
		stats.shots[tm] += 1
		if b.shot != null and b.shot.team == tm and b.shot.on:
			stats.onT[tm] += 1
		useAdvantage(tm)
	else:
		# sponda: pallone che scende verso il punto scelto (un compagno lo controlla o lo colpisce di nuovo)
		var v2: float = minf(HEAD_PASS_V0 + skill * 0.04, D / 0.6)
		var T2: float = maxf(0.3, D / v2)
		b.vx = ux * v2
		b.vy = uy * v2
		b.vh = (0.5 * G * T2 * T2 - b.h) / T2
		b.kick = R.Kick.make(tm, p, "ground", 0.0, [], true)
	if head:
		stats.headers[tm] += 1
		wearDown(p, "tes", WEAR_TES, WEAR_TES_MIN)
	else:
		stats.volleys[tm] += 1
	ev("kick", {"p": p, "kind": kind, "v": C.hyp(b.vx, b.vy), "guidato": true, "sponda": not hw.goal})
	ev("head_end", {"team": tm, "p": p, "reason": "colpito"})
