# I due raccattapalle a schermo (motore: sim/raccatta.gd, solo con l'opzione "riprese"). Figure come quelle dei
# giocatori (figura.gd) ma più piccole (ragazzini, SCALA) e con la tuta giallo fluo, diversa da tutte le divise; la
# posa la dà la figura leggendo il raccattapalle del motore come un giocatore (chinato quando raccoglie, pallone tra le
# mani, lancio a due mani con la clip mocap della rimessa). Solo grafica: legge il motore, non lo cambia.
extends Node3D

const Coord := preload("res://scripts/coord.gd")
const Figura := preload("figura.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")

const SCALA := 0.8             # rispetto a un giocatore
const TUTA := Color("#d8f22a") # giallo fluo
const PANTALONI := Color("#23262e")
const BORDINO := Color("#1b1b1b")
const ASPETTI := ["raccattapalle_a", "raccattapalle_b"]   # aspetto (pelle, capelli) fisso per ognuno

var _figs: Array = []          # Figura per ogni m.raccatte[i]
var _ctx := {"t": 0.0, "phase": "", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null, "m": null}


## figure per i raccattapalle della partita (nessuna se la partita non li ha)
func prepara(m: Object, tex_avviso: Texture2D) -> void:
	libera()
	for k in m.raccatte.size():
		var f := Figura.new()
		f.name = "Raccattapalle%d" % k
		f.scale = Vector3.ONE * Coord.SCALE * SCALA
		add_child(f)
		f.prepara(_kit(), _aspetto(k), 0.37 * k, tex_avviso)
		_figs.append(f)


func libera() -> void:
	for f: Node3D in _figs:
		if is_instance_valid(f):
			f.queue_free()
	_figs.clear()


## a ogni fotogramma, dopo il motore (dt = tempo di gioco)
func aggiorna(m: Object, flip: float, t: float, dt: float) -> void:
	for k in mini(_figs.size(), m.raccatte.size()):
		var bb: Object = m.raccatte[k]
		var f: Node3D = _figs[k]
		var yaw := atan2(flip * bb.fx, -flip * bb.fy)
		f.position = Vector3(flip * bb.x, 0.0, -flip * bb.y)
		f.rotation = Vector3(0.0, yaw, 0.0)
		_ctx.t = t
		_ctx.phase = m.phase
		_ctx.flip = flip
		_ctx.yaw = yaw
		_ctx.ball = m.ball
		_ctx.m = m
		f.posa(bb, dt, _ctx)


## pallone tra le mani di un raccattapalle: Vector4(x, y, z del mondo, peso 0..1); peso 0 = nessuno lo tiene
func pallone_in_mano() -> Vector4:
	var best := Vector4.ZERO
	for f: Node3D in _figs:
		if is_instance_valid(f) and f.mocap != null:
			var v: Vector4 = f.pallone_in_mano()
			if v.w > best.w:
				best = v
	return best


## figura del raccattapalle k (prove)
func figura(k: int) -> Node3D:
	return _figs[k] if k >= 0 and k < _figs.size() else null


# tuta giallo fluo a maniche lunghe, tinta unita, senza numero
func _kit() -> Dictionary:
	var st := Asp.normalizeKitStyle({"pattern": 0, "sleeves": 1, "collar": 0})
	return {"maglia": TUTA, "calzoncini": PANTALONI, "calzettoni": PANTALONI, "bordino": BORDINO,
		"stile": Asp.stile_figura(st), "numero": Vector4(0, 0, 0, st.fit)}


func _aspetto(k: int) -> Dictionary:
	var src := {"id": ASPETTI[k % ASPETTI.size()], "name": "Raccattapalle", "pos": "C", "look": {"beard": 0}}   # ragazzini: niente barba
	return Asp.parametri_figura(Asp.lookOf(src), Asp.normalizeKitStyle({}))
