# Stemma di una squadra (porting di crestSvg / drawCrest di src/crest.js): sagoma, motivo nel colore secondario
# ritagliato dalla sagoma, riflesso chiaro in alto, simbolo al centro col suo contorno, bordo bianco.
# I colori vengono dalla maglia (crestColors: se i due colori sono troppo simili il simbolo diventa bianco o nero).
#
# Uso come nodo: MenuStemma.nuovo(crest, c1, c2, Vector2(46, 54)); oppure solo la texture con texture_di().
class_name MenuStemma
extends Control

const D := preload("res://scripts/menu/menu_dati.gd")
const OMBRA := Color(0, 0, 0, 0.42)
const OMBRA_SPOSTA := Vector2(0, 3)

var crest: Dictionary = {}:
	set(v):
		crest = v
		queue_redraw()
var c1: int = 0xc8102e:
	set(v):
		c1 = v
		queue_redraw()
var c2: int = 0xffffff:
	set(v):
		c2 = v
		queue_redraw()
var ombra := true


static func nuovo(c: Dictionary, col1: int, col2: int, misura: Vector2, con_ombra := true) -> MenuStemma:
	var s := MenuStemma.new()
	s.crest = c
	s.c1 = col1
	s.c2 = col2
	s.ombra = con_ombra
	s.custom_minimum_size = misura
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var r := _riquadro()
	if r.size.y < 1.0:
		return
	var t := texture_di(crest, c1, c2, r.size.y * MenuSvg.scala_schermo())
	if t == null:
		return
	if ombra:
		draw_texture_rect(t, Rect2(r.position + OMBRA_SPOSTA, r.size), false, OMBRA)
	draw_texture_rect(t, r, false)


# riquadro 40×48 centrato nel nodo, senza deformare
func _riquadro() -> Rect2:
	var k := minf(size.x / 40.0, size.y / 48.0)
	var m := Vector2(40.0, 48.0) * k
	return Rect2((size - m) / 2.0, m)


## colori dello stemma da due colori della maglia: fondo, motivo, simbolo e suo contorno
static func crest_colors(col1: int, col2: int) -> Dictionary:
	var near := absf(_lum(col1) - _lum(col2)) < 0.18
	var ink := (0x111827 if _lum(col1) > 0.5 else 0xffffff) if near else col2
	return {"base": D.hex(col1), "alt": D.hex(col2), "ink": D.hex(ink), "line": "#0b1020" if _lum(ink) > 0.5 else "#ffffff"}


static func _lum(n: int) -> float:
	return (((n >> 16) & 255) * 0.299 + ((n >> 8) & 255) * 0.587 + (n & 255) * 0.114) / 255.0


## SVG dello stemma. web = true → lo stesso testo di crestSvg del web (per i test, id del ritaglio = `id`);
## web = false → versione per Godot: dimensioni esplicite e contorno del simbolo disegnato prima del riempimento
## (al posto di paint-order, che ThorVG non conosce): stesso aspetto.
static func svg(c: Variant, col1: int, col2: int, web := false, cls := "", id := "cs") -> String:
	var k := D.normalize_crest(c)
	var col := crest_colors(col1, col2)
	var shape: String = D.crest_shapes()[k.shape][1]
	var pat := ""
	for d: String in D.crest_patterns()[k.pattern][1]:
		pat += '<path d="%s" fill="%s"/>' % [d, col.alt]
	var icon := ""
	for pezzo: Array in D.crest_icons()[k.icon][1]:
		var d: String = pezzo[0]
		var role: String = pezzo[1]
		if role == "s":
			icon += '<path d="%s" fill="none" stroke="%s" stroke-width="1.3" stroke-linecap="round"/>' % [d, col.base]
			continue
		var fill: String = col.base if role == "b" else col.ink
		var sw := "0" if role == "b" else "1.1"
		if web:
			icon += '<path d="%s" fill="%s" stroke="%s" stroke-opacity=".55" stroke-width="%s" paint-order="stroke" stroke-linejoin="round"/>' % [d, fill, col.line, sw]
		else:
			if role != "b":
				icon += '<path d="%s" fill="none" stroke="%s" stroke-opacity=".55" stroke-width="2.2" stroke-linejoin="round"/>' % [d, col.line]
			icon += '<path d="%s" fill="%s"/>' % [d, fill]
	var testa := '<svg class="crest %s" viewBox="0 0 40 48" aria-hidden="true">' % cls if web \
		else '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="48" viewBox="0 0 40 48">'
	return testa + '<defs><clipPath id="%s"><path d="%s"/></clipPath></defs><g clip-path="url(#%s)"><rect width="40" height="48" fill="%s"/>%s<path d="M0 0h40v20C26 16 14 16 0 20z" fill="#fff" opacity=".1"/></g><g transform="translate(9 13.5) scale(.92)">%s</g><path d="%s" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="1.8"/></svg>' % [id, shape, id, col.base, pat, icon, shape]


## texture dello stemma alta `altezza_px` pixel veri
static func texture_di(c: Variant, col1: int, col2: int, altezza_px: float) -> ImageTexture:
	return MenuSvg.texture(svg(c, col1, col2), maxf(altezza_px, 8.0) / 48.0)
