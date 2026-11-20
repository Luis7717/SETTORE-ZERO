# Nodo che mostra un disegno SVG (icone, maglie, coppa...) alla risoluzione vera dello schermo, senza deformarlo.
class_name MenuDisegno
extends Control

var svg := "":
	set(v):
		if v != svg:
			svg = v
			queue_redraw()
var base := Vector2(24, 24)     # misura del disegno (width/height dell'SVG)
var ombra := Color(0, 0, 0, 0)  # ombra sotto il disegno (drop-shadow del web), trasparente = niente
var ombra_sposta := Vector2(0, 4)
var tinta := Color.WHITE


static func nuovo(testo_svg: String, misura_disegno: Vector2, misura: Vector2) -> MenuDisegno:
	var d := MenuDisegno.new()
	d.svg = testo_svg
	d.base = misura_disegno
	d.custom_minimum_size = misura
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _draw() -> void:
	if svg == "" or size.x < 1.0 or size.y < 1.0:
		return
	var k := minf(size.x / base.x, size.y / base.y)
	var m := base * k
	var t := MenuSvg.texture(svg, k * MenuSvg.scala_schermo())
	if t == null:
		return
	var r := Rect2((size - m) / 2.0, m)
	if ombra.a > 0.0:
		draw_texture_rect(t, Rect2(r.position + ombra_sposta, r.size), false, ombra)
	draw_texture_rect(t, r, false, tinta)
