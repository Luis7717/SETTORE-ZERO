# Mappa dei tiri: conti puri (senza nodi) per disegnare i tiri del tabellino (conta_giocatori.gd) su un campo
# intero verticale, con la squadra della persona che attacca verso l'alto. Si prova in tests/test_voti.gd.
# Coordinate del motore: x = larghezza (−32..32), y = lunghezza (−50..50), la squadra 0 attacca verso +y.
extends RefCounted

const MEZZA_LARGHEZZA := 32.0
const MEZZA_LUNGHEZZA := 50.0
const RAPPORTO := MEZZA_LARGHEZZA / MEZZA_LUNGHEZZA   # larghezza / altezza del campo
const ESITI := ["gol", "parato", "respinto", "fuori"]


## punto del tiro dentro `r` (rettangolo del campo disegnato): la persona (me) attacca sempre verso l'alto
static func punto(tiro: Dictionary, me: int, r: Rect2) -> Vector2:
	var s := -1.0 if me == 1 else 1.0
	var x := clampf(float(tiro.get("x", 0.0)) * s, -MEZZA_LARGHEZZA, MEZZA_LARGHEZZA)
	var y := clampf(float(tiro.get("y", 0.0)) * s, -MEZZA_LUNGHEZZA, MEZZA_LUNGHEZZA)
	return Vector2(r.position.x + (x + MEZZA_LARGHEZZA) / (2.0 * MEZZA_LARGHEZZA) * r.size.x,
		r.position.y + (MEZZA_LUNGHEZZA - y) / (2.0 * MEZZA_LUNGHEZZA) * r.size.y)


## pallino pieno solo per i gol; vuoto se parato, respinto o fuori
static func pieno(tiro: Dictionary) -> bool:
	return str(tiro.get("esito", "")) == "gol"


static func nostro(tiro: Dictionary, me: int) -> bool:
	return int(tiro.get("team", -1)) == me


## {gol, parato, respinto, fuori, tiri} per la squadra `team`
static func conta(tiri: Array, team: int) -> Dictionary:
	var out := {"gol": 0, "parato": 0, "respinto": 0, "fuori": 0, "tiri": 0}
	for t: Dictionary in tiri:
		if int(t.get("team", -1)) != team:
			continue
		out.tiri += 1
		var e := str(t.get("esito", "fuori"))
		out[e if ESITI.has(e) else "fuori"] += 1
	return out


## rettangolo del campo più grande che sta in `spazio` con le proporzioni vere, centrato
static func rettangolo(spazio: Vector2) -> Rect2:
	var h := minf(spazio.y, spazio.x / RAPPORTO)
	var w := h * RAPPORTO
	return Rect2((spazio.x - w) / 2.0, (spazio.y - h) / 2.0, w, h)
