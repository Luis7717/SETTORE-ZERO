# Giocatori che non si compenetrano e respiro dopo il recupero palla (solo Godot, opzione "contatti" della partita;
# la accende il gioco, spenta nei confronti col JS che restano identici). Luis 2026-11-24: "ogni tanto i giocatori si
# compenetrano" e "quando il mio giocatore recupera la palla sono talmente uno sopra l'altro che qualunque passaggio io
# faccia mi rubano la palla".
# Misure (tools/controllo_gameplay.gd, 40 partite, righe CONTATTI/RECUPERI/PASSAGGI P): il motore teneva i centri
# ad almeno 0,7 m, ma le figure sono ingrandite ×1,25 e il difensore piegato in avanti a 0,7 m entra con la testa nel
# petto del portatore (prova_vista --scena=contatto --dist=0.7). Dopo un recupero l'avversario più vicino era sotto
# 1 m nel 45% dei casi, il rallenty del duello/fuga si apriva quasi sempre (95%) e il passaggio della persona con un
# avversario a meno di 1 m veniva intercettato entro 1 s nel 48% dei casi (contro il 10% con nessuno entro 4 m).
# - Separazione (SEP_R): sotto SEP_R tra i centri due giocatori si spingono via morbidamente (si toglie una parte
#   della sovrapposizione a ogni passo e, a chi va addosso all'altro, la velocità verso di lui), così chi corre contro
#   un altro rallenta invece di correre sul posto o di spingerlo via di corsa. La vecchia separazione rigida a 0,7 m (motion.gd) resta sotto.
# - Respiro dopo il recupero (RESPIRO_*): quando la squadra della persona prende il pallone alla CPU, chi lo ha
#   appena recuperato non può essere contrastato per RESPIRO_PROTECT s e gli avversari che gli stanno addosso restano
#   sbilanciati (niente contrasti) per RESPIRO_CD s.
# - Passaggio che parte bene (SHIELD_*): un passaggio della persona non lo intercetta, finché il pallone non ha fatto
#   SHIELD_D m, l'avversario che al calcio stava entro SHIELD_NEAR dal pallone (anche addosso, davanti: chi ha appena
#   perso palla e sta col piede sul pallone), né quello entro SHIELD_R che non sta davanti sulla linea del passaggio
#   (a più di SHIELD_LANE m di lato). Il misurato: con un avversario a meno di 1 m quasi un passaggio su due era
#   intercettato subito, quasi sempre nello stesso passo del calcio. Più lontano si intercetta come prima.
# Niente numeri casuali: la sequenza del seme resta quella di prima.
extends "duel.gd"

const SEP_R := 0.9            # due giocatori più vicini di così (centri, m) si spingono via (figure ×1,25)
const FRZ_SPINTA := 0.02     # Forza (`frz`, sotto-statistica): ogni punto di differenza sposta il 2% della spinta sull'altro
const SEP_RATE := 18.0        # ... togliendo a ogni passo min(1, dt × SEP_RATE) della sovrapposizione (metà per uno)
const RESPIRO_PROTECT := 0.8  # recupero palla della persona: per tanto tempo di partita nessuno gli ruba il pallone (s)
const RESPIRO_R := 2.5        # ... gli avversari entro tanto da lui (m) ...
const RESPIRO_CD := 1.1       # ... non contrastano per tanto tempo (s)
const SHIELD_NEAR := 1.5     # passaggio della persona: avversario entro tanto dal pallone al calcio (m; anche "sopra" il
                              # pallone, come chi l'ha appena perso: il passaggio gli scivola accanto) ...
const SHIELD_R := 2.5         # ... o entro tanto ma non davanti sulla linea del passaggio (SHIELD_LANE m di lato) ...
const SHIELD_LANE := 0.5
const SHIELD_D := 3.0         # ... non lo tocca finché il pallone non ha fatto tanti metri

var contattiOn: bool = false
var respPoss: int = -1         # ultima squadra col pallone in gioco (per riconoscere il recupero)


# separazione morbida (chiamata in movePlayers dopo quella rigida, solo col gioco in corso)
func softSeparate(dt: float) -> void:
	if phase != "play":
		return
	var k: float = minf(1.0, dt * SEP_RATE) * 0.5
	var own := ball.owner
	var n: int = players.size()
	for i in n:
		var a := players[i]
		if a.off or a.state == "dive" or a.state == "slide":
			continue
		for j in range(i + 1, n):
			var c := players[j]
			if c.off or c.state == "dive" or c.state == "slide":
				continue
			var dx: float = c.x - a.x
			var dy: float = c.y - a.y
			var d2: float = dx * dx + dy * dy
			if d2 >= SEP_R * SEP_R or d2 < 1e-6:
				continue
			var d: float = sqrt(d2)
			var ux: float = dx / d
			var uy: float = dy / d
			# chi ha il pallone non viene spostato (lo spostamento lo fa tutto l'altro): niente portatore spinto fuori
			var pa: float = 0.0 if a == own else (2.0 if c == own else 1.0)
			var pc: float = 2.0 - pa if (a == own or c == own) else 1.0
			if a != own and c != own:
				# il più forte (scarto di `frz` da `fis`) sposta di più l'altro; senza sotto-statistiche metà per uno
				var fz: float = C.clamp_((c.st.scarto("frz") - a.st.scarto("frz")) * FRZ_SPINTA, -0.5, 0.5)
				pa = 1.0 + fz
				pc = 1.0 - fz
			var push: float = (SEP_R - d) * k
			a.x -= ux * push * pa
			a.y -= uy * push * pa
			c.x += ux * push * pc
			c.y += uy * push * pc
			# chi va addosso all'altro perde la velocità verso di lui (senza spingerlo: niente "trenini" di corsa)
			var va: float = a.vx * ux + a.vy * uy
			if va > 0.0:
				a.vx -= ux * va
				a.vy -= uy * va
			var vc: float = -(c.vx * ux + c.vy * uy)
			if vc > 0.0:
				c.vx += ux * vc
				c.vy += uy * vc


# recupero palla della persona (chiamato a ogni passo dopo i contatti): respiro per chi ha appena preso il pallone
func respiroStep() -> void:
	if phase != "play":
		respPoss = -1 # dopo una ripresa il possesso riparte da capo: non è un recupero
		return
	var o := ball.owner
	if o == null or o.team == respPoss:
		return
	if respPoss >= 0 and human[o.team] and not human[respPoss]:
		o.protect = maxf(o.protect, RESPIRO_PROTECT)
		for q: R.Player in players:
			if q.team != o.team and not q.off and C.hyp(q.x - o.x, q.y - o.y) < RESPIRO_R:
				q.tackleCd = maxf(q.tackleCd, RESPIRO_CD)
		ev("respiro", {"p": o})
	respPoss = o.team


# passaggio della persona appena calciato: avversari vicini al pallone che non stanno sulla sua linea (kick.shield)
func shieldOf(k: R.Kick, sx: float, sy: float, vx: float, vy: float) -> void:
	var v: float = C.hyp(vx, vy)
	if v < 0.01:
		return
	var ux: float = vx / v
	var uy: float = vy / v
	k.sx = sx
	k.sy = sy
	for q: R.Player in players:
		if q.team == k.team or q.off:
			continue
		var dx: float = q.x - sx
		var dy: float = q.y - sy
		var d: float = C.hyp(dx, dy)
		if d >= SHIELD_R:
			continue
		var along: float = dx * ux + dy * uy
		var side: float = absf(dx * uy - dy * ux)
		if d >= SHIELD_NEAR and along > 0.0 and side < SHIELD_LANE:
			continue # più in là e proprio sulla linea: il passaggio gli va addosso, lo può prendere
		k.shield.append(q)


# p non può toccare il pallone: è uno degli avversari vicini al calcio e il pallone non si è ancora allontanato
func shielded(p: R.Player) -> bool:
	var k := ball.kick
	if k == null or k.shield.is_empty() or not k.shield.has(p):
		return false
	return C.hyp(ball.x - k.sx, ball.y - k.sy) < SHIELD_D
