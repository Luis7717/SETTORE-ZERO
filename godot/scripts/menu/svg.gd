# Disegni vettoriali dei menu (stemmi, visi, icone): il codice costruisce lo stesso SVG del web e Godot lo
# trasforma in una texture col suo motore vettoriale (ThorVG, Image.load_svg_from_string), alla risoluzione vera
# dello schermo (sull'iPhone 3 pixel per punto). Le texture fatte restano in memoria (stesso disegno = stessa
# texture): la Rosa ridisegnata o l'editor che cambia scheda non rifanno il lavoro.
class_name MenuSvg
extends RefCounted

const MAX_CACHE := 600          # texture tenute in memoria (un viso a 3x pesa ~15 KB)
const SCALA_MIN := 1.0
const SCALA_MAX := 4.0

static var _cache := {}
static var _ordine: Array[String] = []
static var fatte := 0           # texture create (per le prove: quante volte si è rasterizzato davvero)


## pixel veri per punto dell'interfaccia (390 punti di larghezza → pixel della finestra)
static func scala_schermo() -> float:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return 2.0
	var root := (ml as SceneTree).root
	var vis := root.get_visible_rect().size
	var win := Vector2(root.size)
	if vis.y <= 0.0 or win.y <= 0.0:
		return 2.0
	return clampf(win.y / vis.y, SCALA_MIN, SCALA_MAX)


## texture dal testo SVG; `scala` = pixel per unità del disegno. Null se l'SVG non si legge.
static func texture(svg: String, scala: float) -> ImageTexture:
	var s := snappedf(clampf(scala, 0.05, 64.0), 0.05)
	var key := "%s|%s" % [s, svg]
	var t: ImageTexture = _cache.get(key)
	if t != null:
		return t
	var img := Image.new()
	if img.load_svg_from_string(svg, s) != OK:
		push_warning("MenuSvg: disegno non valido")
		return null
	img.generate_mipmaps()
	t = ImageTexture.create_from_image(img)
	fatte += 1
	_cache[key] = t
	_ordine.append(key)
	if _ordine.size() > MAX_CACHE:
		_cache.erase(_ordine.pop_front())
	return t


static func svuota() -> void:
	_cache.clear()
	_ordine.clear()


## numero #rrggbb di un colore Godot
static func hex(c: Color) -> String:
	return "#" + c.to_html(false)
