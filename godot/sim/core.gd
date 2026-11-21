# Motore partita — costanti, formazioni, statistiche e fisica del pallone (porting di src/sim/core.js).
# Coordinate: x = larghezza (-HW..HW), y = lunghezza (-HL..HL), h = altezza.
# La squadra 0 attacca verso +y, la squadra 1 verso -y.
# Tutti i numeri sono float a 64 bit come in JS; le operazioni sono scritte nello stesso ordine del JS
# (anche l'ordine delle somme conta per avere gli stessi bit).
class_name SimCore
extends RefCounted

const R := preload("records.gd")

const W := 64.0
const L := 100.0
const HW := W / 2.0
const HL := L / 2.0
const GW := 7.32
const GH := 2.44
const BOX_W := 40.32
const BOX_D := 16.5
const SIX_W := 18.32
const SIX_D := 5.5
const PEN_D := 11.0
const CIRCLE := 9.15
const G := 11.5
const ROLL := 5.0

# [ruolo, x (-1..1), y (0 = propria porta .. 1 = porta avversaria)]
const FORMATIONS := {
	"4-4-2": [["P", 0.0, 0.03], ["D", -0.72, 0.2], ["D", -0.24, 0.16], ["D", 0.24, 0.16], ["D", 0.72, 0.2], ["C", -0.78, 0.44], ["C", -0.26, 0.4], ["C", 0.26, 0.4], ["C", 0.78, 0.44], ["A", -0.22, 0.66], ["A", 0.22, 0.66]],
	"4-3-3": [["P", 0.0, 0.03], ["D", -0.72, 0.2], ["D", -0.24, 0.16], ["D", 0.24, 0.16], ["D", 0.72, 0.2], ["C", -0.5, 0.42], ["C", 0.0, 0.37], ["C", 0.5, 0.42], ["A", -0.72, 0.64], ["A", 0.0, 0.69], ["A", 0.72, 0.64]],
	"3-5-2": [["P", 0.0, 0.03], ["D", -0.5, 0.19], ["D", 0.0, 0.16], ["D", 0.5, 0.19], ["C", -0.85, 0.45], ["C", -0.4, 0.41], ["C", 0.0, 0.36], ["C", 0.4, 0.41], ["C", 0.85, 0.45], ["A", -0.22, 0.66], ["A", 0.22, 0.66]],
	"4-2-3-1": [["P", 0.0, 0.03], ["D", -0.72, 0.2], ["D", -0.24, 0.16], ["D", 0.24, 0.16], ["D", 0.72, 0.2], ["C", -0.25, 0.35], ["C", 0.25, 0.35], ["C", -0.7, 0.53], ["C", 0.0, 0.52], ["C", 0.7, 0.53], ["A", 0.0, 0.7]],
}

# Colpi di testa (`tes`): i giocatori dei salvataggi vecchi non ce l'hanno e lo si ricava da fisico e tiro,
# con un aggiustamento per ruolo e una piccola variazione fissa presa dalle altre statistiche (niente numeri casuali,
# così lo stesso giocatore ha sempre lo stesso valore). Non viene scritto nel salvataggio.
const TES_ROLE := {"P": -5, "D": 8, "C": -1, "A": 2}
const POSPEN := {"PP": 1.0, "DD": 1.0, "CC": 1.0, "AA": 1.0, "DC": 0.92, "CD": 0.92, "CA": 0.92, "AC": 0.92, "DA": 0.82, "AD": 0.82}


static func clamp_(v: float, a: float, b: float) -> float:
	return a if v < a else (b if v > b else v)


# Math.hypot di V8, rifatto passo per passo (normalizza sul massimo e somma con la compensazione di Kahan):
# sqrt(a*a + b*b) differisce dal risultato di V8 nell'ultima cifra in circa un caso su tre, e la partita divergerebbe.
static func hyp(a: float, b: float) -> float:
	a = absf(a)
	b = absf(b)
	var mx: float = 0.0
	if a > mx:
		mx = a
	if b > mx:
		mx = b
	if mx == 0.0:
		return 0.0
	var n: float = a / mx
	var s1: float = n * n
	n = b / mx
	var summand: float = n * n
	return sqrt(s1 + summand) * mx


# Math.hypot con tre argomenti (Kahan completo: qui la compensazione può non essere zero)
static func hyp3(a: float, b: float, c: float) -> float:
	a = absf(a)
	b = absf(b)
	c = absf(c)
	var mx: float = 0.0
	if a > mx:
		mx = a
	if b > mx:
		mx = b
	if c > mx:
		mx = c
	if mx == 0.0:
		return 0.0
	var sum: float = 0.0
	var comp: float = 0.0
	for v: float in [a, b, c]:
		var n: float = v / mx
		var summand: float = n * n - comp
		var prelim: float = sum + summand
		comp = (prelim - sum) - summand
		sum = prelim
	return sqrt(sum) * mx


# Math.sign del JS (tiene lo zero col segno: -0 resta -0)
static func sign_(x: float) -> float:
	if x > 0.0:
		return 1.0
	if x < 0.0:
		return -1.0
	return x


# Math.round del JS: arrotonda la metà verso +infinito (round di Godot la allontana dallo zero)
static func round_(x: float) -> float:
	return floor(x + 0.5)


# `x || d` del JS per i numeri: d se x è 0 (o NaN)
static func orf(x: float, d: float) -> float:
	return d if (x == 0.0 or is_nan(x)) else x


static func formationNames() -> Array:
	return FORMATIONS.keys()


static func headingOf(src: Dictionary) -> float:
	var tes: Variant = src.get("tes")
	if typeof(tes) == TYPE_FLOAT or typeof(tes) == TYPE_INT:
		return float(tes)
	var vary: int = ((int(src.get("vel", 0)) * 7 + int(src.get("dri", 0)) * 13 + int(src.get("pas", 0)) * 3) % 9) - 4
	var base: float = float(int(src.get("fis", 0)) + int(src.get("tir", 0))) / 2.0
	return clamp_(round_(base + TES_ROLE.get(src.get("pos", ""), 0) + vary), 18.0, 99.0)


static func effStats(src: Dictionary, slotPos: String) -> R.Stats:
	var f: float = POSPEN.get(String(src.get("pos", "")) + slotPos, 0.6)
	var s := R.Stats.new()
	s.vel = float(src.get("vel", 0))
	s.tir = float(src.get("tir", 0)) * f
	s.pas = float(src.get("pas", 0)) * f
	s.dri = float(src.get("dri", 0)) * f
	s.dif = float(src.get("dif", 0)) * f
	s.fis = float(src.get("fis", 0))
	s.por = float(src.get("por", 0))
	s.tes = headingOf(src) * f
	if slotPos == "P" and src.get("pos", "") != "P":
		s.por = minf(float(src.get("por", 0)), 25.0)
	return s


## roll = attrito del rotolamento (m/s²): la partita passa il suo (meteo, SimMatch.roll); senza, ROLL come sempre
static func ballPhys(s: R.Ball, dt: float, roll: float = ROLL) -> void:
	if s.ct > 0.0:
		s.vx += s.cax * dt
		s.vy += s.cay * dt
		s.ct -= dt
	s.x += s.vx * dt
	s.y += s.vy * dt
	if s.h > 0.0 or s.vh > 0.0:
		s.vh -= G * dt
		s.h += s.vh * dt
		if s.h <= 0.0:
			s.h = 0.0
			if s.vh < -2.2:
				s.vh = -s.vh * 0.5
				s.vx *= 0.8
				s.vy *= 0.8
			else:
				s.vh = 0.0
	else:
		var v: float = hyp(s.vx, s.vy)
		if v > 0.0:
			var nv: float = maxf(0.0, v - roll * dt)
			s.vx *= nv / v
			s.vy *= nv / v


# distanza del punto P dal segmento A-B e posizione t (0..1) del punto più vicino: [d, t]
static func segInfo(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> PackedFloat64Array:
	var dx: float = bx - ax
	var dy: float = by - ay
	var l2: float = orf(dx * dx + dy * dy, 1e-9)
	var t: float = clamp_(((px - ax) * dx + (py - ay) * dy) / l2, 0.0, 1.0)
	return PackedFloat64Array([hyp(px - (ax + dx * t), py - (ay + dy * t)), t])
