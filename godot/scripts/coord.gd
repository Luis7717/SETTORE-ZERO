# Misure del campo e passaggio tra le coordinate del gioco e quelle di Godot.
#
# Coordinate del gioco (come src/sim/core.js): x = larghezza (−32..32), y = lunghezza (−50..50), h = altezza;
# la squadra 0 attacca verso +y.
# Coordinate di Godot (Y in alto, come three.js nel gioco web): X = x, Y = h, Z = −y.
# Così la porta verso cui attacca la squadra 0 (y = +50) sta a Z = −50, cioè "davanti" a una telecamera di Godot
# che guarda verso −Z: la stessa convenzione di src/render.js, i numeri si copiano senza cambiare segni.
#
# Uso: const Coord := preload("res://scripts/coord.gd") e poi Coord.a_godot(x, y, h).
# (Niente class_name: il motore in GDScript che arriva in godot/sim/ potrebbe usare gli stessi nomi.)
extends RefCounted

const W := 64.0          # larghezza del campo (m)
const L := 100.0         # lunghezza del campo (m)
const HW := W / 2.0
const HL := L / 2.0
const GW := 7.32         # larghezza della porta (m, tra i pali)
const GH := 2.44         # altezza della porta (m)
const BOX_W := 40.32     # area di rigore: larghezza e profondità
const BOX_D := 16.5
const SIX_W := 18.32     # area piccola
const SIX_D := 5.5
const PEN_D := 11.0      # dischetto del rigore dalla linea di porta
const CIRCLE := 9.15     # raggio del cerchio di centrocampo
const SCALE := 1.25      # i giocatori e il pallone sono ingranditi come nel gioco web (src/render.js)


## punto del gioco (x, y, altezza h) → posizione in Godot
static func a_godot(x: float, y: float, h: float = 0.0) -> Vector3:
	return Vector3(x, h, -y)


## posizione in Godot → punto del gioco (x, y); l'altezza è p.y
static func da_godot(p: Vector3) -> Vector2:
	return Vector2(p.x, -p.z)


## angolo (rad, attorno a Y) che fa guardare un nodo di Godot verso la direzione del gioco (dx, dy)
static func yaw_verso(dx: float, dy: float) -> float:
	# il "davanti" di un nodo di Godot è −Z; la direzione del gioco (dx, dy) in Godot è (dx, 0, −dy)
	return atan2(-dx, dy)
