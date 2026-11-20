# Maxischermo sopra le tribune dietro le porte (porting di src/stadium-screen.js): nome dello stadio, squadre col
# loro colore e risultato; dopo un gol "GOOOL!" in giallo. Una SubViewport 512×192 si ridisegna solo quando
# cambia qualcosa (UPDATE_ONCE); la stessa texture va su tutti gli schermi.
extends Node3D

const W := 512
const H := 192
const STADIO := "STADIO DEI TIGLI"

var _vp: SubViewport
var _disegno: Control
var _mat: StandardMaterial3D
var _stato := {"nomi": ["CASA", "OSPITI"], "colori": [[Color("#d23b3b"), Color.WHITE], [Color("#2f6fd6"), Color("#f2c230")]], "punti": [0, 0], "gol": false}
var _chiave := ""


func _init() -> void:
	name = "Maxischermo"
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(1.25, 1.25, 1.25)   # un filo sopra 1: il bagliore lo accende appena
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.transparent_bg = false
	_disegno = _Disegno.new()
	_disegno.size = Vector2(W, H)
	_disegno.stato = _stato
	_vp.add_child(_disegno)
	add_child(_vp)
	_mat.albedo_texture = _vp.get_texture()


## uno schermo largo `largo` m al centro c (Godot), girato verso il campo (yaw), con la cornice e due sostegni
func schermo(c: Vector3, yaw: float, largo: float, cornice: Material) -> void:
	var alto := largo * H / W
	var nodo := Node3D.new()
	nodo.position = c
	nodo.rotation.y = yaw
	add_child(nodo)
	var q := QuadMesh.new()
	q.size = Vector2(largo, alto)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.z = 0.16
	nodo.add_child(mi)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(largo + 0.8, alto + 0.8, 0.3)
	box.mesh = bm
	box.material_override = cornice
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.add_child(box)
	for s: float in [-1.0, 1.0]:
		var gamba := MeshInstance3D.new()
		var g := BoxMesh.new()
		g.size = Vector3(0.5, 6.0, 0.5)
		gamba.mesh = g
		gamba.material_override = cornice
		gamba.position = Vector3(s * largo * 0.3, -alto * 0.5 - 3.0, -0.2)
		gamba.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.add_child(gamba)


## nomi e colori (maglia, secondo colore) delle due squadre
func squadre(nomi: Array, colori: Array) -> void:
	_stato.nomi = [str(nomi[0]).to_upper(), str(nomi[1]).to_upper()]
	_stato.colori = colori
	_ridisegna()


## risultato; gol = mostra la scritta del gol
func punteggio(a: int, b: int, gol: bool) -> void:
	_stato.punti = [a, b]
	_stato.gol = gol
	_ridisegna()


func _ridisegna() -> void:
	var k := str(_stato)
	if k == _chiave or _vp == null:
		return
	_chiave = k
	_disegno.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


class _Disegno:
	extends Control

	var stato: Dictionary
	var _grasso: FontVariation

	func _init() -> void:
		_grasso = FontVariation.new()
		_grasso.base_font = ThemeDB.fallback_font
		_grasso.variation_embolden = 0.9

	func _testo(s: String, c: Vector2, larghezza: float, misura: int, col: Color) -> void:
		var fs := misura
		var w := _grasso.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while w > larghezza and fs > 8:
			fs -= 2
			w = _grasso.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_grasso, Vector2(c.x - w * 0.5, c.y + (_grasso.get_ascent(fs) - _grasso.get_descent(fs)) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _draw() -> void:
		var w := float(W)
		var h := float(H)
		draw_rect(Rect2(0, 0, w, h), Color("#0a0d14"))
		if stato.gol:
			draw_rect(Rect2(8, 8, w - 16, h - 16), Color("#ffd43b"))
			_testo("GOOOL!", Vector2(w / 2, h / 2 - 16), w - 60, 96, Color("#0b1a3a"))
			_testo("%s  %d - %d  %s" % [stato.nomi[0], stato.punti[0], stato.punti[1], stato.nomi[1]], Vector2(w / 2, h - 34), w - 60, 26, Color("#0b1a3a"))
		else:
			draw_rect(Rect2(8, 8, w - 16, (h - 16) * 0.5), Color("#12306a"))
			draw_rect(Rect2(8, h * 0.5, w - 16, (h - 16) * 0.5), Color("#081a42"))
			_testo(STADIO, Vector2(w / 2, 34), w - 80, 24, Color("#ffd43b"))
			draw_rect(Rect2(30, 54, w - 60, 2), Color(1, 1, 1, 0.15))
			for i in 2:
				var x := w - 105.0 if i == 1 else 105.0
				var col: Array = stato.colori[i]
				draw_rect(Rect2(x - 62, 72, 124, 22), Color.WHITE)
				draw_rect(Rect2(x - 60, 74, 120, 12), col[0])
				draw_rect(Rect2(x - 60, 86, 120, 6), col[1])
				_testo(stato.nomi[i], Vector2(x, 128), 140, 40, Color.WHITE)
			draw_rect(Rect2(w / 2 - 70, 70, 140, 84), Color(0, 0, 0, 0.35))
			_testo("%d - %d" % [stato.punti[0], stato.punti[1]], Vector2(w / 2, 114), 124, 60, Color.WHITE)
			_testo("TIRO A GIRO", Vector2(w / 2, 164), 200, 16, Color(1, 1, 1, 0.55))
		var y := 8
		while y < H - 8:   # righe dello schermo
			draw_rect(Rect2(8, y, w - 16, 1), Color(0, 0, 0, 0.18))
			y += 3
