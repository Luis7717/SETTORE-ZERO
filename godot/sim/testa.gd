# Colpo di testa controllato (Luis 2026-11-22: "non ho mai colpito di testa nel gioco").
# Un pallone alto (cross, lancio, angolo) di un compagno sta per arrivare a un attaccante della squadra umana vicino alla
# porta avversaria: si apre il fermatempo (headWin). Il giocatore va sul punto del colpo e diventa il controllato; la
# persona disegna la linea: verso la porta = colpo di testa lì (precisione secondo `tes`), verso un compagno o il campo
# = sponda di testa. Se non disegna niente il pallone è perso: nessun compagno lo tocca finché il momento del colpo non
# è passato (gli passa sopra, lo prende la difesa o il portiere). Senza fermatempo tutto resta come prima.
# Salto conteso (Luis 2026-11-24, kind "pass"/"def"): sui passaggi alti della squadra umana fuori dalla zona del cross
# ("pass") e sui palloni alti avversari che arrivano a un nostro difensore ("def") il fermatempo si apre solo se un
# avversario è attaccato (arriva entro HEAD_ATT_R dal punto del colpo al più HEAD_ATT_T dopo il pallone) e il nostro
# vince il salto, deciso col seme PRIMA di aprire (headDuelRoll). Linea = passaggio di testa (o tiro se "pass" è vicino
# alla porta); senza linea, o se il nostro perde il salto, colpisce l'avversario con la sua IA (headGive): chi ha il
# diritto di colpire e non lo usa lo passa all'altro. Senza avversario attaccato tutto come prima (il lancio sulla
# fascia si controlla e si corre).
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
# salto conteso (kind "pass" / "def")
const HEAD_ATT_R := 1.5     # avversario "attaccato": arriva entro tanto dal punto del colpo (m) ...
const HEAD_ATT_T := 0.3     # ... al più tanto dopo il nostro e non dopo il pallone (s) ...
const HEAD_ATT_NEAR := 2.5  # ... ed è già vicino a chi colpisce per noi (m): davvero se lo contende in salto
const HEAD_PASS_LO := 1.7  # sul nostro passaggio il salto conteso vale solo da tanto in su (m): più basso il ricevitore
                            # lo stoppa di petto come prima
const HEAD_PASS_ZONE := 15.0# sul nostro passaggio il salto conteso vale solo oltre tanto dalla metà campo, verso la
                            # porta avversaria (m) ...
const HEAD_DEF_ZONE := 15.0 # ... in difesa solo oltre tanto dalla metà campo verso la nostra porta (m)
const HEAD_PRE_ETA_K := 1.0 # esito deciso prima: probabilità in più per secondo di anticipo sull'avversario
const HEAD_AUTO_LEFT := 0.08 # motore da solo (nessun gioco che ferma il tempo): senza linea a tanto dal colpo il salto
                            # passa all'avversario (s)
const HEAD_PASS_MAX := 30.0 # passaggio di testa della persona nel salto conteso: lungo al massimo tanto (m)
const HEAD_RIVAL_PASS := 24.0 # colpo dell'avversario senza tiro né respinta: di testa a un compagno entro tanto (m) ...
const HEAD_RIVAL_FREE := 3.0 # ... che non ha avversari entro tanto (m), altrimenti avanti verso la fascia ...
const HEAD_RIVAL_FWD := 18.0 # ... di tanto (m)


## fermatempo del colpo di testa aperto per la squadra T, in attesa della linea
func headFor(tm: int) -> bool:
	return headWin != null and headWin.team == tm and not headWin.aimed and not headWin.lost and phase == "play"


## tempo del fermatempo finito senza linea (lo decide il gioco): non si può più disegnare, nessun compagno tocca il
## pallone finché il momento del colpo non è passato (poi endHead "perso"). Nel salto conteso ("pass"/"def") il colpo
## passa all'avversario attaccato (headGive)
func headExpire() -> void:
	var hw := headWin
	if hw == null or hw.aimed:
		return
	if hw.kind == "att":
		hw.lost = true
		return
	headWin = null
	_giveHead(hw)
	ev("head_end", {"team": hw.team, "p": hw.p, "reason": "ceduto"})


## il salto lo vince l'avversario (perso col seme, o fermatempo scaduto senza linea): colpisce lui con la sua IA, chi
## doveva colpire per noi non tocca il pallone
func _giveHead(hw: R.HeadWin) -> void:
	headGive = hw
	ev("head_give", {"team": hw.team, "p": hw.p, "o": hw.rival, "kind": hw.kind})


## si può tirare dal fermatempo aperto? Cross in attacco sì; passaggio alto conteso solo vicino alla porta; in difesa
## mai (la linea è sempre un passaggio o un rinvio di testa)
func headCanShoot() -> bool:
	var hw := headWin
	if hw == null or hw.kind == "def":
		return false
	if hw.kind == "att":
		return true
	return C.hyp(hw.x, hw.y - (-1.0 if hw.team else 1.0) * HL) < AIR_SHOT_RANGE


## tempo di partita che manca al colpo previsto (s)
func headLeft() -> float:
	return maxf(0.0, headWin.tc - headWin.age) if headWin != null else 0.0


## durante il fermatempo i compagni non toccano il pallone (senza linea nessuno, con la linea solo chi colpisce);
## nel salto conteso l'avversario che l'ha perso aspetta; salto ceduto: chi doveva colpire per noi non lo tocca
func headSkip(p: R.Player) -> bool:
	var hw := headWin
	if hw != null and ((p.team == hw.team and (not hw.aimed or p != hw.p)) or p == hw.rival):
		return true
	return headGive != null and p == headGive.p


## salto ceduto: p è l'avversario che ora ha il diritto di colpire
func headGiven(p: R.Player) -> bool:
	return headGive != null and p == headGive.rival


## chi deve colpire corre sul punto del colpo (chiamata da assign); true se l'ha guidato. Nel salto conteso ci va
## anche l'avversario attaccato (salta con lui)
func headRun(p: R.Player) -> bool:
	var hw := headWin
	if headGive != null and headGive.rival == p:
		hw = headGive
	elif hw == null or (hw.p != p and hw.rival != p):
		return false
	p.tx = hw.x
	p.ty = hw.y
	p.sprint = C.hyp(hw.x - p.x, hw.y - p.y) > 1.0
	return true


## a ogni passo: chiude il fermatempo quando non vale più, o lo apre su un lancio alto della squadra umana
func updateHead(dt: float) -> void:
	var b := ball
	var hg := headGive
	if hg != null:
		hg.age += dt
		if phase != "play" or b.owner != null or b.kick != hg.kick or hg.age > hg.tc + HEAD_LATE:
			headGive = null
	var hw := headWin
	if hw != null:
		hw.age += dt
		if phase != "play" or b.owner != null or b.kick != hw.kick:
			endHead("toccato")
		elif hw.age > hw.tc + HEAD_LATE:
			endHead("passato" if hw.aimed else "perso")
		elif hw.kind != "att" and not hw.aimed and headLeft() <= HEAD_AUTO_LEFT:
			headExpire() # motore da solo: nessuno ha fermato il tempo né disegnato
		return
	if not headCtl or phase != "play" or b.owner != null or b.shot != null or headGive != null:
		return
	var k := b.kick
	if k == null or k.type != "loft" or k == _headSeen:
		return
	if not human[k.team]:
		if human[1 - k.team]:
			_headDuel(k, 1 - k.team, "def")
		return
	var w := headFind(k.team)
	if w == null:
		_headDuel(k, k.team, "pass")
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


## salto conteso sul lancio k per la squadra umana T ("pass" = nostro passaggio alto, "def" = pallone alto avversario):
## fermatempo solo con un avversario attaccato e se il nostro vince il salto, deciso qui col seme; perso = headGive
func _headDuel(k: R.Kick, tm: int, kind: String) -> void:
	var w := headFindDuel(tm, HEAD_PASS_LO if kind == "pass" else HEAD_LO)
	if w == null:
		return
	# solo nella metà campo che conta: il passaggio nella metà avversaria, la difesa nella nostra (a centrocampo e
	# dietro, sui nostri lanci, il salto resta automatico come prima: il fermatempo è un momento speciale)
	var avanti: float = w.y * (-1.0 if tm else 1.0)
	if (kind == "pass" and avanti < HEAD_PASS_ZONE) or (kind == "def" and avanti > -HEAD_DEF_ZONE):
		_headSeen = k
		return
	if w.tc < HEAD_WIN_MIN:
		_headSeen = k
		return
	if w.tc > HEAD_WIN_T:
		return
	_headSeen = k
	w.kick = k
	w.kind = kind
	if not headDuelRoll(w):
		_giveHead(w)
		return
	headWin = w
	ctrl[tm] = w.p
	move[tm] = null
	ev("head_win", {"team": tm, "p": w.p, "t": w.tc, "h": w.h, "kind": kind, "o": w.rival})


## esito del salto conteso deciso prima di aprire: come aerialDuel (colpi di testa) più l'anticipo sul punto
func headDuelRoll(w: R.HeadWin) -> bool:
	var p := w.p
	var o := w.rival
	var etaP: float = 0.12 + maxf(0.0, C.hyp(p.x - w.x, p.y - w.y) - HEAD_REACH) / vmax(p)
	var etaO: float = 0.12 + maxf(0.0, C.hyp(o.x - w.x, o.y - w.y) - HEAD_ATT_R) / vmax(o)
	var win: float = C.clamp_(0.5 + AIR_TES_K * (p.st.tes - o.st.tes) / 100.0 + (etaO - etaP) * HEAD_PRE_ETA_K, AIR_WIN_MIN, AIR_WIN_MAX)
	var mine: bool = rnd() < win
	ev("aerial_pre", {"p": p if mine else o, "o": o if mine else p, "win": win, "kind": w.kind})
	return mine


## primo punto del volo ad altezza di testa dove un nostro giocatore arriva in tempo e un avversario è attaccato
## (salto conteso). null se nessuno, se un avversario arriva chiaramente prima o se il pallone è del nostro portiere
func headFindDuel(tm: int, lo: float) -> R.HeadWin:
	var b := ball
	var s := b.physCopy()
	var n: int = int(HEAD_LOOK * 60.0)
	var k: int = 0
	var oppT: float = 1e9
	var g := gk(tm)
	while k < n:
		for j in HEAD_STEP:
			C.ballPhys(s, 1.0 / 60.0, roll)
		k += HEAD_STEP
		var tk: float = k / 60.0
		if oppT > 1e8 and headOppReach(tm, s, tk):
			oppT = tk
		if s.h < lo or s.h > HEAD_HI:
			if s.h < VOLLEY_LO and s.vh < 0.0:
				return null
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
		var etaP: float = 0.12 + maxf(0.0, bd - HEAD_REACH) / vmax(best)
		if oppT < tk - HEAD_DEF_MARGIN or headOppETA(tm, s) < etaP - HEAD_DEF_MARGIN:
			return null
		if g != null and not g.off and inOwnBox(g) and s.h <= C.GK_HAND_HI and C.hyp(g.x - s.x, g.y - s.y) - GK_BOX_REACH <= vmax(g) * maxf(0.0, tk - 0.12):
			return null # pallone del nostro portiere
		var o := headRival(tm, best, s, tk, etaP)
		if o == null:
			return null # nessun avversario attaccato: il nostro controlla o colpisce come prima
		var w := R.HeadWin.new()
		w.team = tm
		w.p = best
		w.rival = o
		w.x = s.x
		w.y = s.y
		w.h = s.h
		w.tc = tk
		return w
	return null


## avversario (non portiere) della squadra T attaccato a p: entro HEAD_ATT_NEAR da lui, arriva entro HEAD_ATT_R dal
## pallone `s` al più HEAD_ATT_T dopo p (che ci arriva in etaP) e non dopo il pallone (tk). Il primo, null se nessuno
func headRival(tm: int, p: R.Player, s: R.Ball, tk: float, etaP: float) -> R.Player:
	var best: R.Player = null
	var bt: float = minf(tk, etaP + HEAD_ATT_T)
	for o: R.Player in players:
		if o.team == tm or o.off or o.pos == "P" or o.state != "play" or o.stun > 0.0 or dblBan(o):
			continue
		if C.hyp(o.x - p.x, o.y - p.y) > HEAD_ATT_NEAR:
			continue
		var t: float = 0.12 + maxf(0.0, C.hyp(o.x - s.x, o.y - s.y) - HEAD_ATT_R) / vmax(o)
		if t <= bt:
			bt = t
			best = o
	return best


## dove mandare il passaggio di testa dal fermatempo aperto [x, y]: il compagno libero (nessun avversario entro
## HEAD_RIVAL_FREE) più avanti tra 6 e HEAD_RIVAL_PASS m, altrimenti HEAD_RIVAL_FWD m avanti verso la fascia. Serve
## alle persone simulate (test, controllo del gameplay, bot del gioco); il motore non lo usa
func headMateTarget() -> Array:
	var hp := headWin.p
	var tm := headWin.team
	var dir: float = -1.0 if tm else 1.0
	var bx: float = C.clamp_(hp.x * 1.3, -HW + 3.0, HW - 3.0)
	var by: float = C.clamp_(hp.y + dir * HEAD_RIVAL_FWD, -HL + 3.0, HL - 3.0)
	var bv: float = -1e9
	for q: R.Player in players:
		if q.team != tm or q == hp or q.off or q.pos == "P":
			continue
		var d: float = C.hyp(q.x - hp.x, q.y - hp.y)
		if d < 6.0 or d > HEAD_RIVAL_PASS or nearOpp(q.x, q.y, tm) < HEAD_RIVAL_FREE:
			continue
		var v: float = (q.y - hp.y) * dir
		if v > bv:
			bv = v
			bx = q.x
			by = q.y
	return [bx, by]


## l'avversario col salto ceduto (headGive) colpisce senza tiro né respinta (airPlay vuoto): di testa a un compagno
## libero più avanti, altrimenti avanti verso la fascia
func headRivalHit(p: R.Player) -> void:
	var b := ball
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var tx: float = C.clamp_(b.x + (1.0 if b.x >= 0.0 else -1.0) * 8.0, -HW + 3.0, HW - 3.0)
	var ty: float = C.clamp_(b.y + dir * HEAD_RIVAL_FWD, -HL + 3.0, HL - 3.0)
	var bestV: float = -1e9
	for q: R.Player in players:
		if q.team != tm or q == p or q.off or q.pos == "P" or q.state != "play":
			continue
		var d: float = C.hyp(q.x - b.x, q.y - b.y)
		if d < 5.0 or d > HEAD_RIVAL_PASS or nearOpp(q.x, q.y, tm) < HEAD_RIVAL_FREE:
			continue
		var v: float = (q.y - b.y) * dir
		if v > bestV:
			bestV = v
			tx = q.x
			ty = q.y
	headGive = null
	_headPass(p, tx, ty, p.st.tes, 4.0 + (100.0 - p.st.tes) * 0.09)
	stats.headers[tm] += 1
	wearDown(p, "tes", WEAR_TES, WEAR_TES_MIN)
	ev("kick", {"p": p, "kind": "header", "v": C.hyp(b.vx, b.vy), "sponda": true})


## passaggio di testa di p verso (tx, ty) con errore `sig` gradi: pallone che scende verso il punto (sponda)
func _headPass(p: R.Player, tx: float, ty: float, skill: float, sig: float) -> void:
	var b := ball
	var dx: float = tx - b.x
	var dy: float = ty - b.y
	var D: float = C.orf(C.hyp(dx, dy), 1.0)
	var a: float = gauss() * sig * PI / 180.0
	var ca: float = F.cos_(a)
	var sa: float = F.sin_(a)
	var ux: float = (dx * ca - dy * sa) / D
	var uy: float = (dx * sa + dy * ca) / D
	var v2: float = minf(HEAD_PASS_V0 + skill * 0.04, D / 0.6)
	var T2: float = maxf(0.3, D / v2)
	b.vx = ux * v2
	b.vy = uy * v2
	b.vh = (0.5 * G * T2 * T2 - b.h) / T2
	b.kick = R.Kick.make(p.team, p, "ground", 0.0, [], true)


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
	if hw.goal and not headCanShoot():
		hw.goal = false # in difesa (o lontano dalla porta) la linea in porta è un passaggio di testa verso di lei
		hw.ay = (-1.0 if tm else 1.0) * HL
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
	var head: bool = kind != "volley" # "clear": il nostro difensore col fermatempo in difesa
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
		var L: float = C.hyp(tx - b.x, ty - b.y)
		if hw.kind != "att" and L > HEAD_PASS_MAX:
			tx = b.x + (tx - b.x) * HEAD_PASS_MAX / L
			ty = b.y + (ty - b.y) * HEAD_PASS_MAX / L
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
	ev("kick", {"p": p, "kind": "header" if head else "volley", "v": C.hyp(b.vx, b.vy), "guidato": true, "sponda": not hw.goal, "difesa": hw.kind == "def"})
	ev("head_end", {"team": tm, "p": p, "reason": "colpito"})
