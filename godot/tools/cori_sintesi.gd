# Coro dello stadio sintetizzato da zero (niente registrazioni: è nostro, CC0 come il resto del progetto).
# Una melodia originale di 4 battute cantata a "oh" da tante voci un po' stonate e fuori tempo (come una curva vera),
# battimani nella pausa dell'ultima battuta, un fondo di brusio e un riverbero da stadio. Il pezzo si ripete senza
# salti: si calcolano due giri uguali e si tiene il secondo (riverbero e code del primo giro sono già dentro).
# Usato da tools/genera_cori.gd (scrive assets/audio/cori.wav) e da tests/test_cori.gd.
extends RefCounted

const HZ := 22050
const BPM := 112.0
const BATTUTE := 4
# melodia: [semitoni da MI3, battiti]; null = pausa. Quattro battute da 4/4
const MELODIA := [
	[0, 1.0], [4, 1.0], [7, 2.0],
	[5, 1.0], [4, 1.0], [2, 2.0],
	[0, 1.0], [4, 1.0], [7, 1.0], [12, 1.0],
	[7, 2.0], [null, 2.0],
]
const MI3 := 164.81             # Hz
const BATTIMANI := [14.0, 14.5, 15.0]   # battiti (dall'inizio del giro) dei battimani nella pausa
const VOCI := 48
const OTTAVA_SU := 0.22         # voci un'ottava sopra (ragazzi, donne)
const STONATO := 30.0           # cents, al massimo
const RITARDO := 0.08           # s, al massimo, di ritardo di una voce (mai in anticipo: il giro si chiude pulito)
const ATTACCO := 0.07           # s
const RILASCIO := 0.14          # s
const MANI := 34                # persone che battono le mani
# formanti della vocale "o" (Hz, guadagno, Q)
const FORMANTI := [[480.0, 1.0, 5.0], [820.0, 0.55, 6.0], [2500.0, 0.18, 8.0]]
const BRUSIO := 0.05
const PICCO := 0.9


## durata di un giro (s)
static func durata() -> float:
	return BATTUTE * 4.0 * 60.0 / BPM


## campioni (float, -1..1) di un giro del coro; meno voci = calcolo più corto (per le prove)
static func sintetizza(voci: int = VOCI, seme: int = 2211) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var n := int(round(durata() * HZ))
	var tot := n * 2
	var canto := PackedFloat32Array()
	canto.resize(tot)
	for v in voci:
		_voce(canto, rng, n)
	var forma := _formanti(canto)
	var mani := PackedFloat32Array()
	mani.resize(tot)
	_battimani(mani, rng, n)
	var mix := PackedFloat32Array()
	mix.resize(tot)
	var br := 0.0
	var br2 := 0.0
	for i in tot:
		# brusio: rumore filtrato due volte (più cupo), che sale e scende piano
		br += (rng.randf_range(-1.0, 1.0) - br) * 0.12
		br2 += (br - br2) * 0.12
		var onda := 0.8 + 0.2 * sin(TAU * float(i % n) / n * 3.0)
		mix[i] = forma[i] / sqrt(float(voci)) * 0.5 + mani[i] * 0.35 + br2 * BRUSIO * 4.0 * onda
	var eco := _riverbero(mix)
	var giro := eco.slice(n, tot)
	var picco := 0.0
	for x in giro:
		picco = maxf(picco, absf(x))
	if picco > 0.0:
		for i in giro.size():
			giro[i] = giro[i] * PICCO / picco
	return giro


# una voce: dente di sega senza alias (polyBLEP), stonata e fuori tempo di poco, con un filo di vibrato; due giri
static func _voce(out: PackedFloat32Array, rng: RandomNumberGenerator, n: int) -> void:
	var cents := rng.randf_range(-STONATO, STONATO)
	var ottava := 2.0 if rng.randf() < OTTAVA_SU else 1.0
	var anticipo := rng.randf_range(0.0, RITARDO)
	var vol := rng.randf_range(0.6, 1.0)
	var vib_hz := rng.randf_range(4.5, 6.0)
	var vib := rng.randf_range(0.002, 0.008)
	var fase := rng.randf()
	var battito := 60.0 / BPM
	for giro in 2:
		var t0 := giro * durata()
		var b := 0.0
		for nota: Array in MELODIA:
			var lunga: float = nota[1] * battito
			if nota[0] != null:
				var f0 := MI3 * pow(2.0, (float(nota[0]) + cents / 100.0) / 12.0) * ottava
				var ini := int((t0 + b * battito + anticipo) * HZ)
				var fin := int((t0 + b * battito + lunga * 0.92 + anticipo) * HZ)
				var dur := float(fin - ini) / HZ
				for i in range(maxi(0, ini), mini(out.size(), fin + int(RILASCIO * HZ))):
					var t := float(i - ini) / HZ
					var env := minf(1.0, t / ATTACCO)
					if t > dur:
						env *= maxf(0.0, 1.0 - (t - dur) / RILASCIO)
					var f := f0 * (1.0 + vib * sin(TAU * vib_hz * t))
					var dt := f / HZ
					fase += dt
					if fase >= 1.0:
						fase -= 1.0
					var s := 2.0 * fase - 1.0
					s -= _blep(fase, dt)
					out[i] += s * env * vol
			b += nota[1]


static func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


# filtro a formanti (passabanda in parallelo, biquad RBJ a guadagno di picco costante)
static func _formanti(x: PackedFloat32Array) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	for fm: Array in FORMANTI:
		var w0 := TAU * float(fm[0]) / HZ
		var alfa := sin(w0) / (2.0 * float(fm[2]))
		var a0 := 1.0 + alfa
		var b0 := alfa / a0
		var a1 := -2.0 * cos(w0) / a0
		var a2 := (1.0 - alfa) / a0
		var g: float = fm[1]
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for i in x.size():
			var xi := x[i]
			var yi := b0 * xi - b0 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = xi
			y2 = y1
			y1 = yi
			y[i] += yi * g
	return y


# battimani: ogni persona un colpo di rumore corto, un po' fuori tempo; due giri
static func _battimani(out: PackedFloat32Array, rng: RandomNumberGenerator, n: int) -> void:
	var battito := 60.0 / BPM
	var colpo := int(0.03 * HZ)
	for p in MANI:
		var anticipo := rng.randf_range(-0.025, 0.025)
		var vol := rng.randf_range(0.4, 1.0) / sqrt(float(MANI))
		var tono := rng.randf_range(0.25, 0.6)   # quanto è "chiaro" il colpo (filtro)
		for giro in 2:
			for bt: float in BATTIMANI:
				var ini := int((giro * durata() + bt * battito + anticipo) * HZ)
				var lp := 0.0
				for k in colpo:
					var i := ini + k
					if i < 0 or i >= out.size():
						continue
					var r := rng.randf_range(-1.0, 1.0)
					var hp := r - lp           # passa-alto semplice: colpo secco
					lp += (r - lp) * tono
					out[i] += hp * exp(-float(k) / (0.006 * HZ)) * vol * 3.0


# riverbero alla Schroeder: 4 pettini in parallelo e 2 passatutto in serie (stadio: code lunghe, poco chiaro)
static func _riverbero(x: PackedFloat32Array) -> PackedFloat32Array:
	var pettini := [[1557, 0.8], [1617, 0.79], [1491, 0.81], [1422, 0.8]]
	var bagnato := PackedFloat32Array()
	bagnato.resize(x.size())
	for pc: Array in pettini:
		var d: int = pc[0]
		var g: float = pc[1]
		var buf := PackedFloat32Array()
		buf.resize(d)
		var j := 0
		var lp := 0.0
		for i in x.size():
			var o := buf[j]
			lp += (o - lp) * 0.45            # le pareti mangiano gli acuti
			buf[j] = x[i] + lp * g
			j = (j + 1) % d
			bagnato[i] += o * 0.25
	for ap: Array in [[225, 0.5], [556, 0.5]]:
		var d: int = ap[0]
		var g: float = ap[1]
		var buf := PackedFloat32Array()
		buf.resize(d)
		var j := 0
		for i in bagnato.size():
			var b := buf[j]
			var v := bagnato[i] + b * g
			buf[j] = v
			bagnato[i] = b - v * g
			j = (j + 1) % d
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		y[i] = x[i] * 0.7 + bagnato[i] * 0.55
	return y


## AudioStreamWAV 16 bit mono che si ripete da sé
static func a_wav(campioni: PackedFloat32Array) -> AudioStreamWAV:
	var dati := PackedByteArray()
	dati.resize(campioni.size() * 2)
	for i in campioni.size():
		dati.encode_s16(i * 2, int(clampf(campioni[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = HZ
	w.stereo = false
	w.data = dati
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = campioni.size()
	return w
