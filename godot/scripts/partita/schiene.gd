# Cognomi e numeri sulle schiene (backCanvas di src/athlete3d.js): un atlante 1024×512 di 8 × 4 celle da 128 px,
# una per giocatore in campo (cella = indice in m.players). Si disegna una volta per partita (e a ogni cambio) in una
# SubViewport, poi si copia in una texture coi mipmap e va nel materiale condiviso dei giocatori ("schiene" di
# shaders/divisa.gdshader). Senza schermo (test headless) non si disegna niente: le schiene restano lisce.
extends Node

const W := 1024
const H := 512
const COLONNE := 8
const CELLA := 128

var _vp: SubViewport
var _disegno: Control
var _giro := 0                 # disegni chiesti: se ne arriva uno nuovo prima della copia, vale l'ultimo


## inchiostro per cognome e numero su una maglia (inkFor di src/players3d.js): il secondo colore se la maglia è
## tinta unita e si distingue, sennò bianco o quasi nero; bordo appena più scuro o più chiaro
static func inchiostro(maglia: Color, alt: Color, motivo: int) -> Array:
	var ls := maglia.get_luminance()
	var fill := alt if motivo == 0 and absf(ls - alt.get_luminance()) > 0.3 else (Color("#14161c") if ls > 0.55 else Color.WHITE)
	var line := Color(0, 0, 0, 0.45) if fill.get_luminance() > 0.5 else Color(1, 1, 1, 0.45)
	return [fill, line]


## cella (colonna, riga) del giocatore i
static func cella(i: int) -> Vector2:
	return Vector2(i % COLONNE, i / COLONNE)


## voci: un Dictionary per giocatore {num: int, nome: String, fill: Color, line: Color}; quando l'atlante è pronto
## lo mette in mat (parametro "schiene")
func prepara(voci: Array, mat: ShaderMaterial) -> void:
	if DisplayServer.get_name() == "headless" or mat == null:
		return
	if _vp == null:
		_vp = SubViewport.new()
		_vp.size = Vector2i(W, H)
		_vp.transparent_bg = true
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_disegno = _Disegno.new()
		_disegno.size = Vector2(W, H)
		_vp.add_child(_disegno)
		add_child(_vp)
	_disegno.voci = voci
	_disegno.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_giro += 1
	var g := _giro
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if g != _giro or not is_instance_valid(mat):
		return
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.generate_mipmaps()
	mat.set_shader_parameter("schiene", ImageTexture.create_from_image(img))


class _Disegno:
	extends Control

	var voci: Array = []
	var _grasso: FontVariation

	func _init() -> void:
		_grasso = FontVariation.new()
		_grasso.base_font = ThemeDB.fallback_font
		_grasso.variation_embolden = 1.0

	# testo centrato in x = cx con la linea di base a y, largo al massimo `largo`, schiacciato in x di sx
	func _scritta(s: String, cx: float, y: float, misura: int, largo: float, sx: float, fill: Color, line: Color, bordo: int) -> void:
		var fs := misura
		var w := _grasso.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * sx
		while w > largo and fs > 6:
			fs -= 1
			w = _grasso.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * sx
		draw_set_transform(Vector2(cx - w * 0.5, y), 0.0, Vector2(sx, 1.0))
		draw_string_outline(_grasso, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, bordo, line)
		draw_string(_grasso, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		for i in voci.size():
			var v: Dictionary = voci[i]
			var o := Vector2(i % COLONNE, i / COLONNE) * CELLA
			var cx := o.x + CELLA * 0.5
			var nome: String = v.get("nome", "")
			if nome != "":
				_scritta(nome, cx, o.y + 30.0, 15, CELLA * 0.6, 1.0, v.fill, v.line, 2)
			var num := int(v.get("num", 0))
			if num > 0:
				var n := str(num)
				_scritta(n, cx, o.y + 92.0, 60 if n.length() > 1 else 62, CELLA * 0.66, 0.78 if n.length() > 1 else 1.0, v.fill, v.line, 4)
