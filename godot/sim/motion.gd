# Movimento dei giocatori, scivolate, tuffi, parate, falli, possesso e contatti col pallone (porting di src/sim/motion.js).
extends "duel.gd"

# Regolazioni (misurate con test/balance.mjs, test/diag-flow.mjs e i test in test/unit)
const SLIDE_T := 0.45       # durata della scivolata (s); sotto la pioggia ×slideK
const GK_AI_SPEED := 2.6    # velocità base del tuffo del portiere comandato dal computer (m/s)
const GK_HUMAN_SPEED := 2.4 # velocità base del tuffo quando lo comanda il giocatore (m/s)
const SHOT_BLOCK_R := 0.6   # un tiro forte si ferma su un difensore solo se lo prende quasi in pieno (m)
const PARRY_OUT := 0.6      # respinte non bloccate che finiscono oltre la linea di fondo
const BLOCK_OUT := 0.4      # tiri ribattuti vicino all'area che finiscono in angolo
const TACKLE_LOOSE := 0.3   # contrasti vinti in cui la palla schizza via invece di restare al difensore
const PASS_DEFLECT := 0.3   # passaggi intercettati che vengono solo deviati
# raggio difensivo sui passaggi avversari (m): INT_BASE a parità 60 contro 60, più difesa e meno passaggio lo allargano
const INT_BASE := 0.95
const INT_REF := 60.0
const INT_DIF := 0.008
const INT_PAS := 0.008
const INT_MIN := 0.6
const INT_MAX := 1.35
const SPRINT_BONUS := 0.22  # velocità in più nello scatto a energia piena (a energia bassa rende meno); era 0,16, poco visibile
const SPRINT_DRAIN := 3.5   # lo scatto consuma energia questo numero di volte più in fretta della corsa
const RECOVER_V := 2.5      # sotto questa velocità (camminata, fermo) l'energia si recupera (m/s)
const RECOVER_RATE := 0.004 # energia recuperata al secondo camminando o da fermi
const ADV_TIME := 2.5       # vantaggio: entro questo tempo, se la squadra perde palla, si torna alla punizione (s)
const HEAD_LO := 1.3        # da questa altezza in su il pallone si colpisce di testa (m)
const HEAD_HI := 2.6        # altezza massima raggiungibile di testa, saltando (m)
const VOLLEY_LO := 0.5      # sotto HEAD_LO e sopra questa altezza: colpo al volo (m)
const AIR_SHOT_RANGE := 17.0 # distanza massima dalla porta per colpire di testa o al volo verso la porta (m)
const HEAD_CLEAR_ZONE := 32.0 # un difensore entro questa distanza dalla propria porta respinge di testa (m)
const HEAD_V0 := 12.0       # velocità base del colpo di testa (m/s), più la bravura
const VOLLEY_V0 := 18.0     # velocità base del tiro al volo (m/s), più la bravura
const AIR_TES_K := 1.5      # contrasto aereo: quanto pesa la differenza di colpi di testa (per punto / 100)
const AIR_DIST_K := 0.6     # ... e quanto pesa essere più vicini al pallone (per metro)
const AIR_WIN_MIN := 0.15   # limiti della probabilità di vincere il contrasto aereo
const AIR_WIN_MAX := 0.85
# Aiuti ai giocatori mossi dalla persona in difesa (controllato, linea, linea appena finita: vedi directed() in ai.gd)
# (richiesta del 2026-11-20: "rendilo un attimino più magnetico")
const HUM_TACKLE_R := 0.3   # raggio di contrasto sul portatore più largo di così (m)
const HUM_REACH_FREE := 0.25 # pallone libero (non calciato da nessuno) agganciato da così più lontano (m)


# Raggio entro cui p tocca il pallone libero. Sui passaggi avversari è il "raggio difensivo":
# cresce con la difesa di p e cala con il passaggio di chi ha calciato (un buon passaggio passa più vicino).
func reachOf(p: R.Player) -> float:
	var k := ball.kick
	if k == null:
		return 0.95 + (HUM_REACH_FREE if directed(p) else 0.0)
	if k.team == p.team:
		return 0.95
	if k.type == "shot":
		return SHOT_BLOCK_R
	var pas: float = k.kicker.st.pas if (k.kicker != null and k.kicker.st != null) else 60.0
	return C.clamp_(INT_BASE + (p.st.dif - INT_REF) * INT_DIF - (pas - INT_REF) * INT_PAS, INT_MIN, INT_MAX)


func movePlayers(dt: float) -> void:
	var b := ball
	var live: bool = phase == "play"
	for p: R.Player in players:
		if p.off:
			continue
		if p.stun > 0.0:
			p.stun -= dt
		if p.protect > 0.0:
			p.protect -= dt
		if p.tackleCd > 0.0:
			p.tackleCd -= dt
		if p.kickAnim > 0.0:
			p.kickAnim -= dt
		if p.dribCd > 0.0:
			p.dribCd -= dt
		if p.beat > 0.0:
			p.beat -= dt
		if p.burst > 0.0:
			p.burst -= dt
		if p.state == "play":
			_moveRunning(p, dt, b)
		elif p.state == "prep":
			p.t -= dt
			p.vx *= 0.9
			p.vy *= 0.9
			p.x += p.vx * dt
			p.y += p.vy * dt
			if p.t <= 0.0:
				p.warn = false
				var c := b.owner
				var tx: float = b.x
				var ty: float = b.y
				if c != null:
					tx += c.vx * 0.22
					ty += c.vy * 0.22
				var dx: float = tx - p.x
				var dy: float = ty - p.y
				var n: float = C.orf(C.hyp(dx, dy), 1.0)
				if live and c != null and c.team != p.team and n < 5.0:
					p.state = "slide"
					p.t = 0.0
					p.sdx = dx / n
					p.sdy = dy / n
					p.hit = false
					p.fx = p.sdx
					p.fy = p.sdy
					ev("slide", {"p": p})
				else:
					p.state = "play"
		elif p.state == "slide":
			slideStep(p, dt)
		elif p.state == "down":
			p.t -= dt
			p.vx = 0.0
			p.vy = 0.0
			if p.t <= 0.0:
				p.state = "play"
				p.tackleCd = 0.4
		elif p.state == "dive":
			diveStep(p, dt)
		p.x = C.clamp_(p.x, -HW - 3.0, HW + 3.0)
		p.y = C.clamp_(p.y, -HL - 2.5, HL + 2.5)
	# separazione
	var taker: R.Player = restart.taker if phase == "restart" else null
	for i in 22:
		var a := players[i]
		if a.off or a.state == "dive":
			continue
		for j in range(i + 1, 22):
			var c := players[j]
			if c.off or c.state == "dive":
				continue
			var dx: float = c.x - a.x
			var dy: float = c.y - a.y
			var d2: float = dx * dx + dy * dy
			if d2 < 0.49 and d2 > 1e-6:
				var d: float = sqrt(d2)
				var k: float = (0.7 - d) / d * 0.5
				if a != taker:
					a.x -= dx * k
					a.y -= dy * k
				if c != taker:
					c.x += dx * k
					c.y += dy * k


# corsa verso il punto (tx, ty), orientamento, stanchezza (ramo 'play' di movePlayers)
func _moveRunning(p: R.Player, dt: float, b: R.Ball) -> void:
	var dx: float = p.tx - p.x
	var dy: float = p.ty - p.y
	var d: float = C.hyp(dx, dy)
	var vm: float = vmax(p) * ((0.86 + p.st.dri * 0.001) if b.owner == p else 1.0) * p.spdF * ((1.0 + SPRINT_BONUS * (0.3 + 0.7 * p.energy)) if p.sprint else 1.0) * (DRIB_BEAT_SPD if p.beat > 0.0 else 1.0) * (BURST_SPD if p.burst > 0.0 else 1.0) # saltato col dribbling: corre piano; Scatto: più veloce
	var sp: float = 0.0 if p.stun > 0.0 else minf(vm, d * 3.2)
	if d < 0.15:
		sp = 0.0
	var wx: float = dx / d * sp if d > 0.0 else 0.0
	var wy: float = dy / d * sp if d > 0.0 else 0.0
	var acc: float = (11.0 + p.st.fis * 0.06) * dt
	var ex: float = wx - p.vx
	var ey: float = wy - p.vy
	var e: float = C.hyp(ex, ey)
	if e <= acc:
		p.vx = wx
		p.vy = wy
	else:
		p.vx += ex / e * acc
		p.vy += ey / e * acc
	p.x += p.vx * dt
	p.y += p.vy * dt
	var v: float = C.hyp(p.vx, p.vy)
	var lx: float
	var ly: float
	if v > 0.8:
		lx = p.vx / v
		ly = p.vy / v
	else:
		lx = b.x - p.x
		ly = b.y - p.y
		var nn: float = C.hyp(lx, ly)
		if nn > 0.8 and b.owner != p:
			lx /= nn
			ly /= nn
		else:
			lx = p.fx
			ly = p.fy
	var k: float = minf(1.0, dt * ((8.0 + p.st.dri * 0.05) if b.owner == p else 12.0))
	p.fx += (lx - p.fx) * k
	p.fy += (ly - p.fy) * k
	var n: float = C.orf(C.hyp(p.fx, p.fy), 1.0)
	p.fx /= n
	p.fy /= n
	p.phase += v * dt * 1.9
	# stanchezza: correndo l'energia cala (più in fretta con meno `fis` = resistenza, e nello scatto); vmax() la usa
	if v < RECOVER_V:
		p.energy = minf(1.0, p.energy + RECOVER_RATE * dt)
	else:
		p.energy = maxf(0.2, p.energy - (v / 8.0) * (v / 8.0) * dt * 0.0022 * (1.3 - p.st.fis * 0.006) * (SPRINT_DRAIN if p.sprint else 1.0))


# Pallone alto che arriva a p: 'header' / 'volley' = colpo verso la porta (attaccante su un lancio o cross
# di un compagno, vicino alla porta), 'clear' = respinta di testa (difensore vicino alla propria porta), "" = niente.
func airPlay(p: R.Player) -> String:
	var b := ball
	if b.shot != null or b.h < VOLLEY_LO or b.h > HEAD_HI:
		return ""
	var dir: float = -1.0 if p.team else 1.0
	var k := b.kick
	var head: bool = b.h >= HEAD_LO
	if k != null and k.team == p.team:
		if k.kicker == p or k.type != "loft":
			return ""
		if C.hyp(p.x, p.y - dir * HL) < AIR_SHOT_RANGE:
			return "header" if head else "volley"
		return ""
	return "clear" if (head and C.hyp(p.x, p.y + dir * HL) < HEAD_CLEAR_ZONE) else ""


func airHit(p: R.Player, kind: String) -> void:
	var b := ball
	var k := b.kick
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	if k != null and k.team == tm and k.kicker != p and k.off.has(p):
		b.kick = null
		ev("offside", {"p": p})
		setRestart("freekick", 1 - tm, p.x, p.y)
		return
	if b.last != p:
		b.prev = b.last
		b.last = p
	b.ct = 0.0
	b.cax = 0.0
	b.cay = 0.0
	b.shot = null
	b.noP = p
	b.noT = 0.3
	predT = 0.0
	p.kickAnim = 0.35
	if kind == "clear":
		# respinta: lontano dalla propria porta, alta, verso l'esterno
		var a0: float = F.atan2_(dir, (1.0 if b.x > 0.0 else -1.0) * (0.3 + rnd() * 0.5))
		var a: float = a0 + (rnd() - 0.5) * (1.4 - p.st.tes * 0.008)
		var v: float = 8.0 + p.st.tes * 0.05 + rnd() * 4.0
		b.vx = F.cos_(a) * v
		b.vy = F.sin_(a) * v
		b.vh = 3.0 + rnd() * 3.0
		b.kick = null
		lastPass = null
		stats.headers[tm] += 1
		wearDown(p, "tes", WEAR_TES, WEAR_TES_MIN)
		ev("kick", {"p": p, "kind": "header", "clear": true, "v": v})
		return
	if k != null and k.team == tm and k.kicker != p:
		lastPass = {"from": k.kicker, "to": p}
	var head: bool = kind == "header"
	var g := gk(1 - tm)
	var gy: float = dir * HL
	var skill: float = p.st.tes if head else p.st.tir
	var side: float = (-1.0 if g.x > b.x else 1.0) * (1.0 if rnd() < 0.75 else -1.0)
	var tx: float = side * (GW / 2.0 - 0.7)
	var th0: float = (0.2 + rnd() * 1.2) if head else (0.3 + rnd() * 1.4)
	var sig: float = ((4.0 if head else 3.0) + (100.0 - skill) * (0.09 if head else 0.08)) * (1.3 if nearOpp(p.x, p.y, tm) < 1.5 else 1.0)
	var v: float = (HEAD_V0 + skill * 0.06) if head else (VOLLEY_V0 + skill * 0.12)
	var dx: float = tx - b.x
	var dy: float = gy - b.y
	var D: float = C.orf(C.hyp(dx, dy), 1.0)
	var a: float = gauss() * sig * PI / 180.0
	var ca: float = F.cos_(a)
	var sa: float = F.sin_(a)
	var ndx: float = (dx * ca - dy * sa) / D
	var ndy: float = (dx * sa + dy * ca) / D
	dx = ndx
	dy = ndy
	var th: float = maxf(0.05, th0 + gauss() * sig * 0.02 * D)
	var Tt: float = maxf(0.15, D / v)
	b.vx = dx * v
	b.vy = dy * v
	b.vh = (th - b.h + 0.5 * G * Tt * Tt) / Tt
	b.kick = R.Kick.make(tm, p, "shot", 0.0, [], bool(human[tm]))
	detectShot()
	stats.shots[tm] += 1
	if b.shot != null and b.shot.team == tm and b.shot.on:
		stats.onT[tm] += 1
	useAdvantage(tm)
	if head:
		stats.headers[tm] += 1
		wearDown(p, "tes", WEAR_TES, WEAR_TES_MIN)
	else:
		stats.volleys[tm] += 1
	ev("kick", {"p": p, "kind": kind, "v": v})


# Contrasto aereo: `p` è il più vicino al pallone alto; se un avversario può arrivarci anche lui, vince chi ha più
# colpi di testa (e chi è più vicino), con un po' di caso. Ritorna chi prende il pallone.
func aerialDuel(p: R.Player) -> R.Player:
	var b := ball
	var dp: float = C.hyp(p.x - b.x, p.y - b.y)
	var o: R.Player = null
	var dO: float = 0.95
	for q: R.Player in players:
		if q.team == p.team or q.off or q.state != "play" or q.stun > 0.0 or (b.noP == q and b.noT > 0.0) or dblBan(q) or q.pos == "P":
			continue
		var d: float = C.hyp(q.x - b.x, q.y - b.y)
		if d < dO and (airPlay(q) != "" or b.h < 1.7):
			dO = d
			o = q
	if o == null:
		return p
	var win: float = C.clamp_(0.5 + AIR_TES_K * (p.st.tes - o.st.tes) / 100.0 + (dO - dp) * AIR_DIST_K, AIR_WIN_MIN, AIR_WIN_MAX)
	var w: R.Player = p
	var l: R.Player = o
	if not (rnd() < win):
		w = o
		l = p
	ev("aerial", {"p": w, "o": l})
	return w


func slideStep(p: R.Player, dt: float) -> void:
	var b := ball
	var st: float = SLIDE_T * slideK
	var sp: float = 10.5 * (1.0 - p.t / st) + 2.5
	p.vx = p.sdx * sp
	p.vy = p.sdy * sp
	p.x += p.vx * dt
	p.y += p.vy * dt
	p.t += dt
	if phase == "play" and not p.hit:
		var db: float = C.hyp(b.x - p.x, b.y - p.y)
		if b.owner != null and b.owner.team != p.team and not duelGuard(p) and not beaten(p, b.owner):
			var c := b.owner
			var dc: float = C.hyp(c.x - p.x, c.y - p.y)
			if db < 0.95:
				p.hit = true
				c.stun = 0.55 * stunK
				c.tackleCd = 0.8
				b.owner = null
				b.vx = p.sdx * 7.0 + (rnd() - 0.5) * 2.0
				b.vy = p.sdy * 7.0 + (rnd() - 0.5) * 2.0
				b.vh = 1.0
				b.h = 0.05
				b.ct = 0.0
				b.prev = b.last
				b.last = p
				b.kick = null
				b.noP = c
				b.noT = 0.5
				predT = 0.0
				ev("tackle", {"p": p, "on": c, "slide": true})
			elif dc < 0.6:
				p.hit = true
				foul(p, c)
				return
		elif b.owner == null and db < 0.95 and b.h < 0.7 and not (b.noP == p and b.noT > 0.0) and not dblBan(p):
			p.hit = true
			b.vx = p.sdx * 9.0
			b.vy = p.sdy * 9.0
			b.vh = 1.5
			b.ct = 0.0
			if b.last != p:
				b.prev = b.last
				b.last = p
			b.kick = null
			b.shot = null
			b.noP = p
			b.noT = 0.3
			predT = 0.0
			ev("tackle", {"p": p, "slide": true})
	if p.t >= st and p.state == "slide":
		p.state = "down"
		p.t = 0.6
		p.vx = 0.0
		p.vy = 0.0


func diveStep(p: R.Player, dt: float) -> void:
	var hm: bool = human[p.team] and not autoGk[p.team]
	var b := ball
	var d := p.dive
	var vs: float = minf((GK_HUMAN_SPEED + p.st.por * 0.03) if hm else (GK_AI_SPEED + p.st.por * 0.025), (30.0 if hm else 22.0) * (p.t + dt))
	d.hx += C.clamp_(d.tx - d.hx, -vs * dt, vs * dt)
	d.hh += C.clamp_(d.th - d.hh, -vs * 0.7 * dt, vs * 0.7 * dt)
	var bt: float = (d.hx - d.dirx * 0.75) if absf(d.hx - d.x0) > 0.75 else d.x0
	p.x += C.clamp_(bt - p.x, -vs * dt, vs * dt)
	p.t += dt
	if phase == "play" and b.owner == null and not (b.noP == p and b.noT > 0.0) and not dblBan(p) and absf(b.y - p.y) < 0.9 + absf(b.vy) * dt:
		var prog: float = C.clamp_(p.t / 0.4, 0.0, 1.0)
		var dd: float = C.segInfo(b.x, b.h, d.x0, 1.0 - prog * 0.3, d.hx, d.hh)[0]
		if dd < 0.72 + p.st.por * 0.002:
			save(p, absf(b.x - d.x0) < 1.3)
	if p.t > 0.8 and p.state == "dive":
		p.state = "down"
		p.t = 0.55


func save(p: R.Player, central: bool) -> void:
	var b := ball
	var sp: float = C.hyp3(b.vx, b.vy, b.vh)
	stats.saves[p.team] += 1
	if sp < 16.0 or (central and sp < 25.0):
		ev("save", {"p": p, "catch": true})
		give(p)
		return
	if rnd() < PARRY_OUT:
		deflectBehind(p)
		ev("save", {"p": p, "catch": false, "out": true})
		return
	var sx: float = p.dive.dirx if p.dive != null else (1.0 if b.x >= p.x else -1.0)
	b.vx = sx * (5.0 + rnd() * 3.0)
	b.vy = -b.vy * 0.15
	b.vh = 2.0 + rnd() * 2.0
	b.ct = 0.0
	if b.last != p:
		b.prev = b.last
		b.last = p
	b.kick = null
	b.shot = null
	b.noP = p
	b.noT = 0.4
	predT = 0.0
	ev("save", {"p": p, "catch": false})


# Manda il pallone oltre la linea di fondo difesa dalla squadra di p, fuori dai pali
# (o sopra la traversa se è già alto): ne nasce un calcio d'angolo, mai un gol.
func deflectBehind(p: R.Player) -> void:
	var b := ball
	var out_: float = 1.0 if p.team else -1.0
	var by: float = out_ * HL
	var dist: float = maxf(0.3, absf(by - b.y))
	var tt: float = maxf(0.3, dist / (3.0 + rnd() * 3.0))
	var vy: float = out_ * dist / tt
	var sx: float = C.sign_(b.x) if absf(b.x) > 0.3 else (-1.0 if rnd() < 0.5 else 1.0)
	var vx: float = (sx * (GW / 2.0 + 0.9 + rnd() * 3.0) - b.x) / tt
	b.vy = vy
	b.ct = 0.0
	if b.h > 1.5 or absf(vx) > 18.0:
		b.vx = (rnd() - 0.5) * 3.0
		b.vh = (GH + 0.8 - b.h + 0.5 * G * tt * tt) / tt
	else:
		b.vx = vx
		b.vh = 0.5 * G * tt + 0.4 + rnd()
	b.h = maxf(b.h, 0.05)
	if b.last != p:
		b.prev = b.last
		b.last = p
	b.kick = null
	b.shot = null
	b.noP = p
	b.noT = 0.4
	predT = 0.0


func foul(by: R.Player, on: R.Player) -> void:
	stats.fouls[by.team] += 1
	var behind: bool = by.sdx * on.fx + by.sdy * on.fy > 0.45
	var card := "" # "" = nessun cartellino (null in JS)
	if behind:
		by.yellow += 1
		card = "red" if by.yellow >= 2 else "yellow"
	var dirD: float = -1.0 if by.team else 1.0
	var inBox: bool = absf(on.x) < BOX_W / 2.0 and on.y * dirD < -HL + BOX_D
	ev("foul", {"by": by, "on": on, "card": card if card != "" else null, "pen": inBox})
	var ox: float = on.x
	var oy: float = on.y
	if card == "red":
		by.off = true
		by.x = HW + 8.0
		by.y = 0.0
		by.state = "play"
		if ctrl[by.team] == by:
			ctrl[by.team] = null
	elif not inBox and advantageOk(on, by):
		advantage = R.Advantage.new()
		advantage.team = on.team
		advantage.x = ox
		advantage.y = oy
		advantage.t = ADV_TIME
		ev("advantage", {"team": on.team, "p": on})
		return
	if inBox:
		setRestart("penalty", on.team, 0.0, 0.0)
	else:
		setRestart("freekick", on.team, ox, oy)


func give(p: R.Player) -> void:
	var b := ball
	var k := b.kick
	b.owner = p
	b.vh = 0.0
	b.h = 0.0
	b.ct = 0.0
	b.shot = null
	b.vx = p.vx
	b.vy = p.vy
	if k != null and k.team == p.team and k.kicker != p and k.off.has(p):
		b.kick = null
		ev("offside", {"p": p})
		setRestart("freekick", 1 - p.team, p.x, p.y)
		return
	if k != null and k.team == p.team and k.kicker != p:
		lastPass = {"from": k.kicker, "to": p}
	elif k == null or k.team != p.team:
		lastPass = null
	b.kick = null
	if b.last != p:
		b.prev = b.last
		b.last = p
	p.protect = 0.35
	p.aiT = 0.12 + rnd() * 0.2
	p.contact = 0.0
	p.holdN = 0
	p.dx = p.x
	p.dy = p.y
	ev("control", {"p": p})
	if p.pos == "P" and inOwnBox(p) and phase == "play":
		setRestart("gk", p.team, p.x, p.y, p)


func contacts(dt: float) -> void:
	var b := ball
	if b.owner != null:
		_contactsOwned(dt, b)
		return
	if b.kick != null:
		b.kick.age += dt
	var best: R.Player = null
	var bd: float = 9.0
	var bestAir := ""
	for p: R.Player in players:
		if p.off or p.state != "play" or p.stun > 0.0 or (b.noP == p and b.noT > 0.0) or dblBan(p):
			continue
		var isGk: bool = p.pos == "P" and inOwnBox(p)
		var d: float = C.hyp(p.x - b.x, p.y - b.y)
		# palla appena calciata che si allontana: non si può toccare
		if b.kick != null and b.kick.age < 0.3 and b.kick.team != p.team and (p.x - b.x) * b.vx + (p.y - b.y) * b.vy < 0.0:
			continue
		if d >= (1.25 if isGk else reachOf(p)) or d >= bd:
			continue
		var air: String = "" if isGk else airPlay(p)
		if air != "" or b.h < (2.35 if isGk else 1.7):
			bd = d
			best = p
			bestAir = air
	if best == null:
		return
	if b.h >= HEAD_LO and not (best.pos == "P" and inOwnBox(best)):
		var w := aerialDuel(best)
		if w != best:
			best = w
			bestAir = airPlay(w)
			if bestAir == "" and b.h >= 1.7:
				return
	if bestAir != "":
		airHit(best, bestAir)
		return
	var p := best
	var sp: float = C.hyp(b.vx - p.vx, b.vy - p.vy)
	var isGk2: bool = p.pos == "P" and inOwnBox(p)
	if isGk2 and b.shot != null and b.shot.team != p.team:
		save(p, true)
		return
	var mate: bool = b.kick != null and b.kick.team == p.team
	# squadra umana: un passaggio avversario intercettato (anche in corsa) si controlla sempre, niente rimbalzi né deviazioni.
	# L'IA resta com'era: deviazioni e respinte quando la palla arriva forte (realismo, ed equilibrio già misurato)
	if not isGk2 and not mate and b.shot == null and b.kick != null and b.kick.type != "shot" and human[p.team]:
		give(p)
		return
	var fresh: bool = b.kick != null and b.kick.age < 0.22 and sp > 6.0
	if not isGk2 and not mate and ((b.shot != null and sp > 14.0) or sp > 22.0 + p.st.dri * 0.06 or fresh):
		var hard: bool = b.shot != null
		if hard and not mate and absf(b.y) > HL - BOX_D - 4.0 and rnd() < BLOCK_OUT:
			deflectBehind(p)
			b.vh = maxf(b.vh, 1.5)
			ev("block", {"p": p, "hard": hard, "out": true})
			return
		b.vx = -b.vx * 0.25 + (rnd() - 0.5) * 5.0
		b.vy = -b.vy * 0.3 + (rnd() - 0.5) * 3.0
		b.vh = 1.5 + rnd() * 3.0
		b.ct = 0.0
		b.prev = b.last
		b.last = p
		b.shot = null
		b.kick = null
		b.noP = p
		b.noT = 0.3
		predT = 0.0
		ev("block", {"p": p, "hard": hard})
		return
	# passaggio intercettato: a volte il difensore riesce solo a deviarlo
	if not isGk2 and not mate and b.kick != null and b.kick.type != "shot" and sp > 8.0 and rnd() < PASS_DEFLECT:
		var a: float = F.atan2_(b.vy, b.vx) + (-1.0 if rnd() < 0.5 else 1.0) * (0.5 + rnd() * 0.9)
		var v: float = C.hyp(b.vx, b.vy) * (0.45 + rnd() * 0.25)
		b.vx = F.cos_(a) * v
		b.vy = F.sin_(a) * v
		b.vh = 0.5 + rnd() * 2.0
		b.h = maxf(b.h, 0.05)
		b.ct = 0.0
		b.prev = b.last
		b.last = p
		b.shot = null
		b.kick = null
		b.noP = p
		b.noT = 0.3
		lastPass = null
		predT = 0.0
		ev("block", {"p": p, "hard": false, "deflect": true})
		return
	give(p)


# contrasti sul portatore (prima parte di contacts in JS)
func _contactsOwned(dt: float, b: R.Ball) -> void:
	var c := b.owner
	if c.protect > 0.0:
		return
	for o: R.Player in players:
		if o.team == c.team or o.off or o.state != "play" or o.stun > 0.0 or o.tackleCd > 0.0 or duelGuard(o) or beaten(o, c):
			continue
		var d: float = C.hyp(o.x - b.x, o.y - b.y)
		var hc: bool = human[c.team]
		var ho: bool = human[o.team]
		var dirH: bool = ho and directed(o)
		if d < 0.85 + o.st.dif * 0.0025 + (HUM_TACKLE_R if dirH else 0.0):
			o.contact += dt
			var need: float = 0.10 + 0.22 * c.st.dri / (c.st.dri + o.st.dif)
			if hc and not ho:
				need *= 2.5 - 1.3 * float(teams[o.team].skill)
			# chi va sul portatore da solo (CPU) ruba più piano di chi muove la persona (controllato, linea, linea appena finita)
			if ho and not dirH:
				need *= 2.4
			if o.contact >= need and rnd() < TACKLE_LOOSE:
				o.contact = 0.0
				o.tackleCd = 0.5
				c.stun = 0.3 * stunK
				c.tackleCd = 0.6
				var side: float = C.sign_(b.x) if absf(b.x) > HW - 12.0 else (-1.0 if rnd() < 0.5 else 1.0)
				var ang: float = F.atan2_(b.y - o.y, b.x - o.x) + (rnd() - 0.5) * 1.6
				var sp: float = 5.0 + rnd() * 4.0
				b.owner = null
				b.vx = F.cos_(ang) * sp * 0.6 + side * (4.0 + rnd() * 5.0)
				b.vy = F.sin_(ang) * sp
				b.vh = 1.0 + rnd() * 1.5
				b.h = 0.05
				b.ct = 0.0
				b.prev = b.last
				b.last = o
				b.kick = null
				b.shot = null
				b.noP = c
				b.noT = 0.3
				lastPass = null
				predT = 0.0
				ev("tackle", {"p": o, "on": c, "loose": true})
				return
			if o.contact >= need:
				b.owner = o
				b.prev = b.last
				b.last = o
				b.kick = null
				lastPass = null
				o.protect = 0.5
				o.contact = 0.0
				o.aiT = 0.25
				o.dx = o.x
				o.dy = o.y
				o.holdN = 0
				c.stun = 0.4 * stunK
				c.tackleCd = 0.8
				ev("tackle", {"p": o, "on": c})
				if o.pos == "P" and inOwnBox(o):
					setRestart("gk", o.team, o.x, o.y, o)
				return
		elif o.contact > 0.0:
			o.contact = maxf(0.0, o.contact - dt * 2.0)
