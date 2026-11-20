# sin, cos e atan2 "fdlibm", gli stessi di V8 (Math.sin / Math.cos / Math.atan2 in Node e nei browser Chrome):
# le funzioni di Godot usano la libreria C del sistema e differiscono di 1 ulp in una parte dei casi
# (misurato: sin ~3%, cos ~4%, atan2 ~19% su Windows; su iPhone la libreria è un'altra ancora).
# Con queste il motore dà gli stessi bit del JS e la stessa partita su ogni piattaforma.
# Porting riga per riga di fdlibm 5.3 (k_sin.c, k_cos.c, e_rem_pio2.c per |x| < 2^19·π/2, s_atan.c, e_atan2.c),
# verificato bit per bit contro V8 su 3 milioni di valori per funzione (e da tests/test_equivalence.gd).
# Validità: argomenti finiti con |x| < 2^19·π/2 (il motore usa angoli di pochi radianti).
class_name SimMath
extends RefCounted

# Costanti scritte come parole esadecimali esatte (come nei commenti di fdlibm): Godot legge i numeri decimali
# lunghi con un errore di 1 ulp in alcuni casi (misurato su 10 delle 41 costanti), i bit invece sono esatti.
static var S1: float = _w(0xBFC55555, 0x55555549)
static var S2: float = _w(0x3F811111, 0x1110F8A6)
static var S3: float = _w(0xBF2A01A0, 0x19C161D5)
static var S4: float = _w(0x3EC71DE3, 0x57B1FE7D)
static var S5: float = _w(0xBE5AE5E6, 0x8A2B9CEB)
static var S6: float = _w(0x3DE5D93A, 0x5ACFD57C)
static var C1: float = _w(0x3FA55555, 0x5555554C)
static var C2: float = _w(0xBF56C16C, 0x16C15177)
static var C3: float = _w(0x3EFA01A0, 0x19CB1590)
static var C4: float = _w(0xBE927E4F, 0x809C52AD)
static var C5: float = _w(0x3E21EE9E, 0xBDB4B1C4)
static var C6: float = _w(0xBDA8FAE9, 0xBE8838D4)
static var INVPIO2: float = _w(0x3FE45F30, 0x6DC9C883)
static var PIO2_1: float = _w(0x3FF921FB, 0x54400000)
static var PIO2_1T: float = _w(0x3DD0B461, 0x1A626331)
static var PIO2_2: float = _w(0x3DD0B461, 0x1A600000)
static var PIO2_2T: float = _w(0x3BA3198A, 0x2E037073)
static var PIO2_3: float = _w(0x3BA3198A, 0x2E000000)
static var PIO2_3T: float = _w(0x397B839A, 0x252049C1)
static var PI_O_2: float = _w(0x3FF921FB, 0x54442D18)
static var PI_: float = _w(0x400921FB, 0x54442D18)
static var PI_LO: float = _w(0x3CA1A626, 0x33145C07)
static var ATANHI: PackedFloat64Array = PackedFloat64Array([_w(0x3FDDAC67, 0x0561BB4F), _w(0x3FE921FB, 0x54442D18), _w(0x3FEF730B, 0xD281F69B), _w(0x3FF921FB, 0x54442D18)])
static var ATANLO: PackedFloat64Array = PackedFloat64Array([_w(0x3C7A2B7F, 0x222F65E2), _w(0x3C81A626, 0x33145C07), _w(0x3C700788, 0x7AF0CBBD), _w(0x3C91A626, 0x33145C07)])
static var AT: PackedFloat64Array = PackedFloat64Array([_w(0x3FD55555, 0x5555550D), _w(0xBFC99999, 0x9998EBC4), _w(0x3FC24924, 0x920083FF), _w(0xBFBC71C6, 0xFE231671), _w(0x3FB745CD, 0xC54C206E), _w(0xBFB3B0F2, 0xAF749A6D), _w(0x3FB10D66, 0xA0D03D51), _w(0xBFADDE2D, 0x52DEFD9A), _w(0x3FA97B4B, 0x24760DEB), _w(0xBFA2B444, 0x2C6A6C2F), _w(0x3F90AD3A, 0xE322DA11)])

static var _b: PackedByteArray = _newBuf()
static var _npio2hw: PackedInt32Array = _mkNpio2()


static func _newBuf() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(8)
	return b


# parola alta (con segno) e parola bassa (senza segno) del double, come __HI / __LO di fdlibm
static func hi(x: float) -> int:
	_b.encode_double(0, x)
	return _b.decode_s32(4)


static func lo(x: float) -> int:
	_b.encode_double(0, x)
	return _b.decode_u32(0)


static func words(h: int, l: int) -> float:
	_b.encode_u32(0, l & 0xFFFFFFFF)
	_b.encode_u32(4, h & 0xFFFFFFFF)
	return _b.decode_double(0)


# parole alte di n·π/2 (n = 1..32): tabella npio2_hw di fdlibm
static func _mkNpio2() -> PackedInt32Array:
	var a := PackedInt32Array()
	var b := _newBuf()
	var pio2: float = _w(0x400921FB, 0x54442D18) / 2.0
	for n in range(1, 33):
		b.encode_double(0, n * pio2)
		a.append(b.decode_s32(4))
	return a


# double dalle due parole (alta, bassa): per le costanti
static func _w(h: int, l: int) -> float:
	var b := _newBuf()
	b.encode_u32(0, l)
	b.encode_u32(4, h)
	return b.decode_double(0)


static func kSin(x: float, y: float, iy: int) -> float:
	var ix: int = hi(x) & 0x7fffffff
	if ix < 0x3e400000: # |x| < 2^-27
		return x
	var z: float = x * x
	var v: float = z * x
	var r: float = S2 + z * (S3 + z * (S4 + z * (S5 + z * S6)))
	if iy == 0:
		return x + v * (S1 + z * r)
	return x - ((z * (0.5 * y - v * r) - y) - v * S1)


static func kCos(x: float, y: float) -> float:
	var ix: int = hi(x) & 0x7fffffff
	if ix < 0x3e400000:
		return 1.0
	var z: float = x * x
	var r: float = z * (C1 + z * (C2 + z * (C3 + z * (C4 + z * (C5 + z * C6)))))
	if ix < 0x3FD33333: # |x| < 0.3
		return 1.0 - (0.5 * z - (z * r - x * y))
	var qx: float = 0.28125 if ix > 0x3fe90000 else words(ix - 0x00200000, 0)
	var hz: float = 0.5 * z - qx
	var a: float = 1.0 - qx
	return a - (hz - (z * r - x * y))


# riduzione dell'argomento: x = n·π/2 + (y0 + y1); ritorna n e scrive y0, y1 in `y`
static func remPio2(x: float, y: PackedFloat64Array) -> int:
	var hx: int = hi(x)
	var ix: int = hx & 0x7fffffff
	if ix < 0x4002d97c: # |x| < 3π/4: n = ±1
		if hx > 0:
			var z: float = x - PIO2_1
			if ix != 0x3ff921fb:
				y[0] = z - PIO2_1T
				y[1] = (z - y[0]) - PIO2_1T
			else:
				z -= PIO2_2
				y[0] = z - PIO2_2T
				y[1] = (z - y[0]) - PIO2_2T
			return 1
		var zn: float = x + PIO2_1
		if ix != 0x3ff921fb:
			y[0] = zn + PIO2_1T
			y[1] = (zn - y[0]) + PIO2_1T
		else:
			zn += PIO2_2
			y[0] = zn + PIO2_2T
			y[1] = (zn - y[0]) + PIO2_2T
		return -1
	var t: float = absf(x)
	var n: int = int(t * INVPIO2 + 0.5)
	var fn: float = float(n)
	var r: float = t - fn * PIO2_1
	var w: float = fn * PIO2_1T
	if n < 32 and ix != _npio2hw[n - 1]:
		y[0] = r - w
	else:
		var j: int = ix >> 20
		y[0] = r - w
		var i: int = j - ((hi(y[0]) >> 20) & 0x7ff)
		if i > 16:
			t = r
			w = fn * PIO2_2
			r = t - w
			w = fn * PIO2_2T - ((t - r) - w)
			y[0] = r - w
			i = j - ((hi(y[0]) >> 20) & 0x7ff)
			if i > 49:
				t = r
				w = fn * PIO2_3
				r = t - w
				w = fn * PIO2_3T - ((t - r) - w)
				y[0] = r - w
	y[1] = (r - y[0]) - w
	if hx < 0:
		y[0] = -y[0]
		y[1] = -y[1]
		return -n
	return n


static func sin_(x: float) -> float:
	if (hi(x) & 0x7fffffff) <= 0x3fe921fb:
		return kSin(x, 0.0, 0)
	var y := PackedFloat64Array([0.0, 0.0])
	var n: int = remPio2(x, y)
	match n & 3:
		0:
			return kSin(y[0], y[1], 1)
		1:
			return kCos(y[0], y[1])
		2:
			return -kSin(y[0], y[1], 1)
		_:
			return -kCos(y[0], y[1])


static func cos_(x: float) -> float:
	if (hi(x) & 0x7fffffff) <= 0x3fe921fb:
		return kCos(x, 0.0)
	var y := PackedFloat64Array([0.0, 0.0])
	var n: int = remPio2(x, y)
	match n & 3:
		0:
			return kCos(y[0], y[1])
		1:
			return -kSin(y[0], y[1], 1)
		2:
			return -kCos(y[0], y[1])
		_:
			return kSin(y[0], y[1], 1)


static func atan_(x: float) -> float:
	var hx: int = hi(x)
	var ix: int = hx & 0x7fffffff
	var id: int
	if ix >= 0x44100000: # |x| >= 2^66
		return ATANHI[3] + ATANLO[3] if hx > 0 else -ATANHI[3] - ATANLO[3]
	if ix < 0x3fdc0000: # |x| < 0.4375
		if ix < 0x3e400000: # |x| < 2^-27
			return x
		id = -1
	else:
		x = absf(x)
		if ix < 0x3ff30000: # |x| < 1.1875
			if ix < 0x3fe60000: # 7/16 <= |x| < 11/16
				id = 0
				x = (2.0 * x - 1.0) / (2.0 + x)
			else: # 11/16 <= |x| < 19/16
				id = 1
				x = (x - 1.0) / (x + 1.0)
		elif ix < 0x40038000: # |x| < 2.4375
			id = 2
			x = (x - 1.5) / (1.0 + 1.5 * x)
		else: # 2.4375 <= |x| < 2^66
			id = 3
			x = -1.0 / x
	var z: float = x * x
	var w: float = z * z
	var s1: float = z * (AT[0] + w * (AT[2] + w * (AT[4] + w * (AT[6] + w * (AT[8] + w * AT[10])))))
	var s2: float = w * (AT[1] + w * (AT[3] + w * (AT[5] + w * (AT[7] + w * AT[9]))))
	if id < 0:
		return x - x * (s1 + s2)
	var zz: float = ATANHI[id] - ((x * (s1 + s2) - ATANLO[id]) - x)
	return -zz if hx < 0 else zz


static func atan2_(y: float, x: float) -> float:
	var hx: int = hi(x)
	var ix: int = hx & 0x7fffffff
	var lx: int = lo(x)
	var hy: int = hi(y)
	var iy: int = hy & 0x7fffffff
	var ly: int = lo(y)
	if ((hx - 0x3ff00000) | lx) == 0: # x = 1
		return atan_(y)
	var m: int = ((hy >> 31) & 1) | ((hx >> 30) & 2) # 2·segno(x) + segno(y)
	if (iy | ly) == 0: # y = ±0
		if m == 0 or m == 1:
			return y
		return PI_ if m == 2 else -PI_
	if (ix | lx) == 0: # x = ±0
		return -PI_O_2 if hy < 0 else PI_O_2
	var k: int = (iy - ix) >> 20
	var z: float
	if k > 60:
		z = PI_O_2 + 0.5 * PI_LO
	elif hx < 0 and k < -60:
		z = 0.0
	else:
		z = atan_(absf(y / x))
	match m:
		0:
			return z
		1:
			return -z
		2:
			return PI_ - (z - PI_LO)
		_:
			return (z - PI_LO) - PI_
