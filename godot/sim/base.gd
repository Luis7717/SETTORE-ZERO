# Stato della partita e funzioni di servizio usate da tutte le parti del motore (prima metà di src/sim/match.js).
# In JS i metodi di duel.js, motion.js e ai.js vengono copiati su Match.prototype; GDScript non ha i "mixin",
# quindi le parti sono una catena di classi: base.gd -> duel.gd -> motion.gd -> ai.gd -> match.gd (SimMatch).
# Le poche chiamate "verso l'alto" (es. motion.gd che chiama setRestart di match.gd) sono dichiarate qui sotto
# come metodi vuoti e ridefinite nel file giusto.
extends RefCounted

const R := preload("records.gd")
const C := preload("core.gd")
const SimRngScript := preload("rng.gd")
const F := preload("fmath.gd") # sin, cos, atan2 identici a V8

const HW := C.HW
const HL := C.HL
const L := C.L
const W := C.W
const GW := C.GW
const GH := C.GH
const BOX_W := C.BOX_W
const BOX_D := C.BOX_D
const SIX_D := C.SIX_D
const PEN_D := C.PEN_D
const CIRCLE := C.CIRCLE
const G := C.G
const ROLL := C.ROLL

const SPEED_TIRED := 0.86 # a energia 0 la velocità massima scende a questa frazione (l'energia cala più piano con più fisico = resistenza)
const WIDE_GAP := 2.0 # metri dalla linea laterale degli esterni quando la squadra attacca

var rng: SimRngScript = null
var halfLen: float = 180.0
var human: Array = [true, false]
var autoGk: Array = [false, false]
var teams: Array = []
var players: Array[R.Player] = []
var ball: R.Ball = null
var score: Array = [0, 0]
var half: int = 1
var t: float = 0.0
var time: float = 0.0
var phase: String = "play"
var events: Array = []
var stats: Dictionary = {}
var ctrl: Array = [null, null]
var move: Array = [null, null]
var switchCd: Array = [0.0, 0.0]
var runs: Array = [[], []]
var chase: Array = [null, null]
var presser: Array = [null, null]
var cover: Array = [null, null]
var offLine: Array = [HL, HL]
var autoDef: Array = [true, true] # squadra umana senza palla: false = chi non ha linea né dito resta fermo (allenamento "Recupera palla")
var predT: float = 0.0
var att: int = -1
var dtT: float = 0.0
var lastPass: Variant = null # {from, to}
var restart: R.Restart = null
var goalsLog: Array = []
var advantage: R.Advantage = null
var duel: R.Duel = null
var duelCd: Array = [0.0, 0.0]
var duelCdP: Array = [null, null]
var flee: R.Duel = null # fuga: avversario alla pari o dietro (per linee), tasto Scatto; stessi campi del duello
var fleeCd: Array = [0.0, 0.0]
var fleeCdP: Array = [null, null]
var kickoffTeam: int = 0
# meteo (campo facoltativo "meteo" delle opzioni, match.gd weatherFx): "" = nessuno, motore come sempre
var meteo: String = ""
var roll: float = ROLL # attrito del rotolamento del pallone (m/s²)
var rollKick: float = ROLL # quello usato per la forza dei passaggi rasoterra (max(ROLL, roll))
var slideK: float = 1.0 # durata della scivolata ×
var stunK: float = 1.0 # tempo da fermo di chi perde un contrasto ×
var helpers: Array = [[], []]
var helpWas: Array = []
var hPress: Variant = null # [[], []] dopo il primo calcolo (in JS parte "undefined")
var goalT: float = 0.0
# colpo di testa controllato (testa.gd): solo se l'opzione "testa" della partita è vera (il gioco sì, i confronti col JS no)
var headCtl: bool = false
var headWin: R.HeadWin = null
var nextKick: int = 0


# numero casuale in [0, 1) dal generatore con seme della partita (this.rnd() in JS)
func rnd() -> float:
	return rng.next()


func team(tm: int) -> Array:
	return players.slice(11) if tm else players.slice(0, 11)


func gk(tm: int) -> R.Player:
	return players[tm * 11]


func gauss() -> float:
	return (rnd() + rnd() + rnd() - 1.5) * 2.0


# velocità massima: cresce con `vel` e cala con la stanchezza (p.energy 1 → 0,2 durante la partita, più piano con più `fis`)
func vmax(p: R.Player) -> float:
	return (5.0 + p.st.vel * 0.036) * (SPEED_TIRED + (1.0 - SPEED_TIRED) * p.energy)


# evento della partita: {type, ...dati}
func ev(type: String, d: Dictionary = {}) -> void:
	var e := {"type": type}
	e.merge(d)
	events.append(e)


# p ha battuto il calcio da fermo e nessun altro ha ancora toccato il pallone: non può toccarlo (niente doppio tocco)
func dblBan(p: R.Player) -> bool:
	return ball.dbl == p and ball.last == p


func nearOpp(x: float, y: float, tm: int) -> float:
	var m: float = 99.0
	for o: R.Player in players:
		if o.team != tm and not o.off:
			var d: float = C.hyp(o.x - x, o.y - y)
			if d < m:
				m = d
	return m


func lane(x1: float, y1: float, x2: float, y2: float, tm: int, speed: float, exGK: bool = false) -> float:
	var D: float = C.hyp(x2 - x1, y2 - y1)
	var m: float = 9.0
	for o: R.Player in players:
		if o.team == tm or o.off or (exGK and o.pos == "P"):
			continue
		var si := C.segInfo(o.x, o.y, x1, y1, x2, y2)
		var d: float = si[0]
		var tt: float = si[1]
		var s: float = tt * D
		if s < 1.5:
			if tt > 0.0 and d < 1.1:
				var mm: float = d - 1.1
				if mm < m:
					m = mm
			continue
		if tt >= 0.985:
			var mm2: float = d - 1.0
			if mm2 < m:
				m = mm2
			continue
		var mar: float = d - (0.9 + maxf(0.0, s / speed - 0.2) * vmax(o) * 0.75)
		if mar < m:
			m = mar
	return m


func blocked(x1: float, y1: float, x2: float, y2: float, tm: int) -> bool:
	var D: float = C.hyp(x2 - x1, y2 - y1)
	for o: R.Player in players:
		if o.team == tm or o.off:
			continue
		var si := C.segInfo(o.x, o.y, x1, y1, x2, y2)
		var s: float = si[1] * D
		if s > 2.0 and s < D - 1.5 and si[0] < 1.4:
			return true
	return false


func inOwnBox(p: R.Player) -> bool:
	var dir: float = -1.0 if p.team else 1.0
	return absf(p.x) < BOX_W / 2.0 and p.y * dir < -HL + BOX_D


# ------------------------------------------------------------ posizioni
func anchor(p: R.Player) -> PackedFloat64Array:
	var dir: float = -1.0 if p.team else 1.0
	var b := ball
	var bf: float = C.clamp_((b.y * dir + HL) / L, 0.0, 1.0)
	var bx: float = b.x / HW
	var ax: float
	var ay: float
	# in attacco gli esterni (terzini e ali) restano larghi, quasi sulla linea laterale
	var wide: bool = att == p.team and absf(p.bx) > 0.6 and p.pos != "P"
	if att == p.team:
		ay = p.by * 0.5 + bf * 0.55 + (0.06 if p.pos == "A" else (0.05 if (p.pos == "C" and absf(p.bx) > 0.6) else 0.0))
		ax = C.sign_(p.bx) if wide else p.bx + bx * 0.15
	else:
		ay = p.by * 0.55 + bf * 0.36 - 0.03
		ax = p.bx * 0.7 + bx * 0.28
	return PackedFloat64Array([ax * (HW - WIDE_GAP) if wide else C.clamp_(ax, -0.95, 0.95) * HW * 0.94, (C.clamp_(ay, 0.04, 0.96) - 0.5) * L * dir])


func place(p: R.Player, x: float, y: float) -> void:
	p.x = x
	p.y = y
	p.vx = 0.0
	p.vy = 0.0
	p.tx = x
	p.ty = y
	p.state = "play"
	p.t = 0.0
	p.stun = 0.0
	p.contact = 0.0
	p.dive = null
	p.warn = false
	p.hit = false
	p.cele = 0


func resetStates() -> void:
	for p: R.Player in players:
		p.wall = null
	for p: R.Player in players:
		if not p.off:
			p.state = "play"
			p.t = 0.0
			p.stun = 0.0
			p.contact = 0.0
			p.dive = null
			p.warn = false
			p.cele = 0
			p.beat = 0.0
			p.vx *= 0.3
			p.vy *= 0.3


func pushAway(tm: int, x: float, y: float, Rr: float) -> void:
	for o: R.Player in players:
		if o.team != tm or o.off:
			continue
		var dx: float = o.x - x
		var dy: float = o.y - y
		var d: float = C.hyp(dx, dy)
		if d < Rr:
			var dir: float = -1.0 if o.team else 1.0
			var ux: float = dx / C.orf(d, 1.0)
			var uy: float = dy / C.orf(d, 1.0)
			if d < 0.5:
				ux = 0.0
				uy = -dir
			var nx: float = x + ux * Rr
			var ny: float = y + uy * Rr
			if absf(nx) > HW - 1.0 or absf(ny) > HL - 1.0:
				nx = C.clamp_(x, -HW + 8.0, HW - 8.0) + (o.i - 5) * 0.8
				ny = y - dir * Rr
				ny = C.clamp_(ny, -HL + 1.0, HL - 1.0)
			o.x = nx
			o.y = ny
			o.vx = 0.0
			o.vy = 0.0


func faceTo(p: R.Player, x: float, y: float) -> void:
	var dx: float = x - p.x
	var dy: float = y - p.y
	var n: float = C.orf(C.hyp(dx, dy), 1.0)
	p.fx = dx / n
	p.fy = dy / n


# y (nel verso d'attacco di T) del penultimo avversario; HL se non ce ne sono abbastanza
func lineOf(tm: int) -> float:
	var dir: float = -1.0 if tm else 1.0
	var a: float = -99.0
	var s: float = -99.0
	for o: R.Player in players:
		if o.team != tm and not o.off:
			var v: float = o.y * dir
			if v > a:
				s = a
				a = v
			elif v > s:
				s = v
	return HL if s == -99.0 else s


# linea del fuorigioco per chi attacca (squadra T), in coordinata y del campo:
# penultimo difensore, ma mai dietro al pallone né nella propria metà campo
func offsideY(tm: int) -> float:
	var dir: float = -1.0 if tm else 1.0
	return dir * maxf(maxf(lineOf(tm), ball.y * dir), 0.0)


func runOf(p: R.Player) -> R.Run:
	for r: R.Run in runs[p.team]:
		if r.p == p:
			return r
	return null


# Ordinamento stabile come Array.prototype.sort del JS (sort_custom di Godot non lo è):
# key(p) è il valore da ordinare in modo crescente; a pari valore resta l'ordine di partenza.
static func stableSort(arr: Array, key: Callable) -> Array:
	var out: Array = []
	var keys: Array[float] = []
	for v: Variant in arr:
		var k: float = key.call(v)
		var j: int = out.size()
		while j > 0 and keys[j - 1] > k:
			j -= 1
		out.insert(j, v)
		keys.insert(j, k)
	return out


# ------------------------------------------------------------ metodi ridefiniti più in basso nella catena
func setRestart(_type: String, _team: int, _x: float, _y: float, _taker: R.Player = null) -> void:
	pass # match.gd


func advantageOk(_on: R.Player, _by: R.Player) -> bool:
	return false # match.gd


func detectShot() -> void:
	pass # match.gd


func useAdvantage(_tm: int) -> void:
	pass # match.gd


func kick(_p: R.Player, _spec: Dictionary) -> void:
	pass # match.gd


func followPath(_p: R.Player, _mv: R.Move) -> void:
	pass # match.gd


func followRun(_p: R.Player, _r: R.Run) -> bool:
	return false # match.gd


func directed(_p: R.Player) -> bool:
	return false # ai.gd


func endDuel(_reason: String) -> void:
	pass # duel.gd


func headSkip(_p: R.Player) -> bool:
	return false # testa.gd


func endHead(_reason: String) -> void:
	pass # testa.gd


func headStrike(_p: R.Player, _kind: String) -> void:
	pass # testa.gd
