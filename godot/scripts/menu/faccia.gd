# Ritratto piccolo dei giocatori (porting di faceSvg di src/face2d.js): viso coi colori del `look` (pelle,
# capelli e barba col loro colore, taglio approssimato) e la maglia della squadra. Nelle carte della Rosa sta in
# un tondo con lo sfondo sfumato nel colore della squadra (.fp del web), qui disegnato nello stesso SVG.
class_name MenuFaccia
extends Control

const D := preload("res://scripts/menu/menu_dati.gd")

const CAP := "M11.2 16C11 9 15 6.5 20 6.5S29 9 28.8 16C27 12.5 24 11 20 11S13 12.5 11.2 16Z"
const CAP_HIGH := "M11.2 14.5C11 8.5 15 6.2 20 6.2S29 8.5 28.8 14.5C27.5 11 24 9.6 20 9.6S12.5 11 11.2 14.5Z"
const CURLS := [[12.4, 12.4], [13.8, 8.8], [16.6, 6.7], [20, 6], [23.4, 6.7], [26.2, 8.8], [27.6, 12.4]]
const JAW := "M11.6 18.5C11.8 25 15.5 27.4 20 27.4S28.2 25 28.4 18.5L27 19.2C26.4 22.6 24 23 20 23S13.6 22.6 13 19.2Z"
const MOUSTACHE := "M16.6 22.7Q20 21.2 23.4 22.7Q20 23.5 16.6 22.7Z"
const GOATEE := '<ellipse cx="20" cy="25.7" rx="2.2" ry="1.6"'
const FONDO_BASE := Color("#1c2b49")   # .fp: radial-gradient(var(--k1m40-1c2b49), #0d1626)
const FONDO_FUORI := "#0d1626"

var look: Dictionary = {}:
	set(v):
		look = v
		queue_redraw()
var maglia := "#c8102e"
var colletto := "#ffffff"
var fondo := "#2f3a5c"          # colore della squadra mescolato (vedi fondo_di)
var tondo := true               # dentro il tondo con lo sfondo (carte) oppure il viso da solo


static func nuovo(lk: Dictionary, shirt: String, collar: String, lato: float, k1: int = -1) -> MenuFaccia:
	var f := MenuFaccia.new()
	f.look = lk
	f.maglia = shirt
	f.colletto = collar
	if k1 >= 0:
		f.fondo = fondo_di(k1)
	f.custom_minimum_size = Vector2(lato, lato)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


## colore della squadra mescolato al 40% col blu scuro (var(--k1m40-1c2b49) del web)
static func fondo_di(k1: int) -> String:
	return MenuSvg.hex(FONDO_BASE.lerp(D.colore(k1), 0.4))


func _draw() -> void:
	var lato := minf(size.x, size.y)
	if lato < 1.0:
		return
	var r := Rect2((size - Vector2(lato, lato)) / 2.0, Vector2(lato, lato))
	var s := svg_tondo(look, maglia, colletto, fondo) if tondo else svg(look, maglia, colletto, false)
	var t := MenuSvg.texture(s, lato * MenuSvg.scala_schermo() / 40.0)
	if t != null:
		draw_texture_rect(t, r, false)


## colore #rrggbb scurito (f < 1) o schiarito (f > 1)
static func shade(h: String, f: float) -> String:
	var n := h.substr(1).hex_to_int()
	var ch := func(s: int) -> int: return clampi(int(floor(((n >> s) & 255) * f + 0.5)), 0, 255)
	return "#%06x" % ((ch.call(16) << 16) | (ch.call(8) << 8) | ch.call(0))


static func _hair_parts(style: int, c: String) -> Array:
	var p := func(d: String, extra := "") -> String: return '<path d="%s" fill="%s"%s/>' % [d, c, extra]
	match style:
		0: return ["", ""]
		1: return ["", p.call(CAP, ' opacity=".45"')]
		3: return ["", p.call("M11.2 15L11.4 7.6Q20 4.8 28.6 7.6L28.8 15C27 12 24 10.6 20 10.6S13 12 11.2 15Z")]
		4: return ["", p.call(CAP) + p.call("M14.6 9.6Q20.5 2 27.4 7.8Q23.2 6.6 19 10.4Z")]
		5: return ["", p.call(CAP) + '<path d="M15.4 7.4L14.2 11.6" stroke="%s" stroke-width=".8" opacity=".6"/>' % shade(c, 1.9)]
		6: return ["", p.call(CAP, ' opacity=".3"') + p.call("M17.6 12Q17 4.2 20 2.4Q23 4.2 22.4 12Z")]
		7: return ["", p.call("M11.2 15L11 9L13.5 9.6L14 5L16.8 7.6L18.5 3.4L20.6 7L23 3.8L24.2 7.7L27 5.5L27.2 9.6L29 9.6L28.8 15C27 12 24 10.8 20 10.8S13 12 11.2 15Z")]
		8:
			var ricci := ""
			for xy: Array in CURLS:
				ricci += '<circle cx="%s" cy="%s" r="2.7" fill="%s"/>' % [_num(xy[0]), _num(xy[1]), c]
			return ["", p.call(CAP) + ricci]
		9: return ['<circle cx="20" cy="13.5" r="12.6" fill="%s"/>' % c, p.call(CAP)]
		10: return ["", p.call("M10.6 20C10 9 14.5 5.8 20 5.8S30 9 29.4 20L27.8 20C27.6 15 25 12.6 20 12.6S12.4 15 12.2 20Z")]
		11: return [p.call("M10.5 15C10 7 15 5.5 20 5.5S30 7 29.5 15L30.2 31L26 31L27 18L13 18L14 31L9.8 31Z"), p.call(CAP)]
		12: return [p.call("M26.6 11.6Q33.6 15.6 31.4 27.4Q29.4 21 26.2 16.4Z"), p.call(CAP)]
		13: return ['<circle cx="20" cy="5.4" r="3.7" fill="%s"/>' % c, p.call(CAP)]
		14:
			var tr := ""
			for x: float in [10.8, 12.4, 27.6, 29.2]:
				tr += '<path d="M%s 12V27" stroke="%s" stroke-width="1.5" stroke-linecap="round"/>' % [_num(x), c]
			return [tr, p.call(CAP)]
		15: return ["", p.call(CAP) + p.call("M11.6 14.6Q16 11 20 13.6Q24 11 28.4 14.6L28.6 11Q20 6.8 11.4 11Z")]
		16: return ["", p.call(CAP_HIGH) + '<path d="M15 8.6Q20 7 25 8.6" stroke="%s" stroke-width=".7" fill="none" opacity=".7"/>' % shade(c, 1.6)]
	return ["", p.call(CAP)]


# numero come lo scrive il JS (20 e non 20.0)
static func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else str(x)


static func _beard(kind: int, c: String) -> String:
	var jaw := func(o: String) -> String: return '<path d="%s" fill="%s" opacity="%s"/>' % [JAW, c, o]
	var mou := '<path d="%s" fill="%s"/>' % [MOUSTACHE, c]
	var goat := '%s fill="%s"/>' % [GOATEE, c]
	match kind:
		1: return jaw.call("0.25")
		2: return goat
		3: return mou
		4: return mou + goat
		5: return jaw.call("0.7")
		6: return jaw.call("1") + mou
	return ""


static func _interno(lk: Variant, shirt: String, collar: String) -> String:
	var l := D.normalize_look(lk)
	var skin: String = D.SKINS[l.skin][1]
	var hc: Array = D.HAIR_COLORS[l.hairColor]
	var hair: String = hc[1]
	var parts := _hair_parts(l.hair, hair)
	if hc.size() > 2 and parts[1] != "":   # sfumati: punte colorate sul davanti dei capelli
		parts[1] = '<defs><linearGradient id="pu" x1="0" y1="0" x2="0" y2="1"><stop offset=".35" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>' % [hair, hc[2]] \
			+ parts[1].replace('fill="%s"' % hair, 'fill="url(#pu)"')
	# barba del colore scelto (beardColor 0 = come i capelli, come prima); occhi colorati solo per i colori nuovi
	# (i primi 7 restano i puntini scuri del web)
	var barba: String = hair if l.beardColor == 0 else str(D.BEARD_COLORS[l.beardColor][1])
	var ec: Array = D.EYE_COLORS[l.eyeColor]
	var occhio_d := "#1a1412" if l.eyeColor < 7 else str(ec[1])
	var occhio_s := occhio_d if ec.size() < 3 else str(ec[2])
	var dark := shade(skin, 0.82)
	return parts[0] \
		+ '<path d="M3.5 40C4.5 32 11 29.2 20 29.2S35.5 32 36.5 40Z" fill="%s"/>' % shirt \
		+ '<path d="M15 29.6Q20 34.4 25 29.6" fill="none" stroke="%s" stroke-width="2"/>' % collar \
		+ '<path d="M16.6 23.5h6.8v6.6Q20 32 16.6 30.1Z" fill="%s"/>' % dark \
		+ '<ellipse cx="11.4" cy="18.6" rx="1.7" ry="2.5" fill="%s"/><ellipse cx="28.6" cy="18.6" rx="1.7" ry="2.5" fill="%s"/>' % [dark, dark] \
		+ '<ellipse cx="20" cy="17" rx="8.6" ry="10.2" fill="%s"/>' % skin \
		+ _beard(l.beard, barba) \
		+ '<circle cx="16.6" cy="17.8" r="1.05" fill="%s"/><circle cx="23.4" cy="17.8" r="1.05" fill="%s"/>' % [occhio_d, occhio_s] \
		+ '<path d="M15 15.4h3.2M21.8 15.4H25" stroke="%s" stroke-width="1" stroke-linecap="round"/>' % hair \
		+ '<path d="M18 23.6Q20 24.6 22 23.6" fill="none" stroke="%s" stroke-width=".8" stroke-linecap="round"/>' % shade(skin, 0.6) \
		+ parts[1]


## SVG del viso. web = true → lo stesso testo di faceSvg del web (per i test)
static func svg(lk: Variant, shirt: String, collar: String, web := false, cls := "face") -> String:
	var testa := '<svg class="%s" viewBox="0 0 40 40" aria-hidden="true">' % cls if web \
		else '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">'
	return testa + _interno(lk, shirt, collar) + "</svg>"


## viso dentro il tondo delle carte: sfondo sfumato, ritaglio rotondo, bordino chiaro
static func svg_tondo(lk: Variant, shirt: String, collar: String, fondo_hex: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">' \
		+ '<defs><radialGradient id="g" cx="50%%" cy="35%%" r="70%%"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>' % [fondo_hex, FONDO_FUORI] \
		+ '<clipPath id="t"><circle cx="20" cy="20" r="20"/></clipPath></defs>' \
		+ '<g clip-path="url(#t)"><rect width="40" height="40" fill="url(#g)"/>' + _interno(lk, shirt, collar) + "</g>" \
		+ '<circle cx="20" cy="20" r="19.4" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-width="1.2"/></svg>'
