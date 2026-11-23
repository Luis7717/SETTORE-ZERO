# Regia del fermatempo della parata (sim/parata.gd + fermatempo_parata.gd): decide la velocità del tempo e mostra
# cerchio "Para!" intorno al portiere e bersaglio sulla porta. Tenuta fuori da gioco.gd per non allungarlo.
#   velocita(dt, m, me, disegna) → −1 senza fermatempo, 0 tempo fermo, 1 tempo normale (linea data o tempo scaduto)
#   mostra(m, me, vista, hud)     cerchio e bersaglio (o li nasconde)
extends RefCounted

const FP := preload("res://scripts/partita/fermatempo_parata.gd")
const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")

var reale := -1.0              # secondi veri dall'apertura del fermatempo (−1 = chiuso)
var _volo: Array = []          # scia del volo (calcolata una volta all'apertura: col tempo fermo non cambia)
var _tiro: R.Shot = null


## velocità del tempo voluta dal fermatempo della parata. `disegna` = il dito sta tracciando la linea del tuffo
func velocita(dt: float, m: Object, me: int, disegna: bool) -> float:
	if not m.paraOn(me) or not m.diveWin(me):
		reale = -1.0
		return -1.0
	if not m.paraFor(me):
		reale = -1.0
		return 1.0 # linea disegnata (o tempo scaduto): tempo normale finché il portiere si tuffa
	if reale < 0.0:
		reale = 0.0
	else:
		reale += dt
	if FP.fermo(reale, disegna):
		return 0.0
	m.paraExpire(me) # niente linea: il portiere fa da solo
	reale = -1.0
	return 1.0


func mostra(m: Object, me: int, vista: Object, hud: Object) -> void:
	if reale < 0.0 or not m.paraFor(me):
		hud.cerchio_parata(Vector2.ZERO, -1.0)
		hud.bersaglio_tiro({})
		_tiro = null
		return
	var g: R.Player = m.gk(me)
	var s: Vector3 = vista.world_to_screen(g.x, g.y, 1.0)
	hud.cerchio_parata(Vector2(s.x, s.y) if s.z > 0.5 else Vector2.ZERO, FP.frazione(reale) if s.z > 0.5 else -1.0)
	var a: Dictionary = m.paraArea(me)
	if a.is_empty():
		hud.bersaglio_tiro({})
		return
	if m.ball.shot != _tiro:
		_tiro = m.ball.shot
		_volo = m.paraVolo(me)
	var d := a.duplicate()
	d["gy"] = (-1.0 if me == 0 else 1.0) * C.HL
	d["volo"] = _volo
	hud.bersaglio_tiro(d)
