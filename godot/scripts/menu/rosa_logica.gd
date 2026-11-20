# Rosa: logica pura della schermata (porting di src/squad-layout.js e delle funzioni pure di src/ui-squad.js).
# Niente nodi: si prova in tests/test_menu_rosa.gd coi valori del web.
# - field_layout: posto delle 11 carte nel campo disegnato, dalla formazione, senza sovrapposizioni;
# - can_swap / swap_lineup / swap_delta: scambi campo↔campo e campo↔panchina, variazione della forza;
# - pick_card: i tocchi sulle carte (scegli, confronta, scambia);
# - short_name, bench_order: nome sulla carta e ordine della panchina.
class_name MenuRosa
extends RefCounted

const D := preload("res://scripts/menu/menu_dati.gd")

const CARD_W := 64.0
const CARD_H := 70.0
const CARD_MIN_SCALE := 0.72
const FIELD_PAD := 4.0          # margine tra carte e bordo del campo
const GAP_X := 6.0              # spazio minimo tra due carte della stessa fila
const GAP_Y := 4.0              # spazio minimo tra due file
const ROW_SPAN := 0.1           # posti con y entro questo scarto stanno nella stessa fila
const ROW_OFFSET_MAX := 7.0     # spostamento dentro la fila (terzini e ali un po' più avanti), se c'è spazio
const ROW_OFFSET_K := 160.0     # px per unità di y nello spostamento dentro la fila
const RELAX_STEPS := 60
const ROLE_ORDER := "PDCA"
const SHORT_NAME_MAX := 10


## file della formazione, dal portiere agli attaccanti: ogni fila è un elenco di indici dei posti
static func field_rows(F: Array) -> Array:
	var order: Array = range(F.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		if F[a][2] != F[b][2]:
			return F[a][2] < F[b][2]
		return F[a][1] < F[b][1])
	var rows: Array = []
	for i: int in order:
		if not rows.is_empty() and F[i][2] - F[rows[-1][0]][2] <= ROW_SPAN:
			rows[-1].append(i)
		else:
			rows.append([i])
	return rows


# centri in una fila: dalla x della formazione, poi le carte troppo vicine si allargano e restano in [lo, hi]
static func _spread_row(xs: Array, min_d: float, lo: float, hi: float) -> Array:
	var c := xs.duplicate()
	for _k in RELAX_STEPS:
		var moved := false
		for i in c.size() - 1:
			var d: float = min_d - (c[i + 1] - c[i])
			if d > 1e-6:
				c[i] -= d / 2.0
				c[i + 1] += d / 2.0
				moved = true
		for i in c.size():
			c[i] = minf(hi, maxf(lo, c[i]))
		if not moved:
			break
	for i in range(1, c.size()):
		c[i] = maxf(c[i], c[i - 1] + min_d)
	if not c.is_empty():
		c[-1] = minf(c[-1], hi)
	for i in range(c.size() - 2, -1, -1):
		c[i] = minf(c[i], c[i + 1] - min_d)
	return c


## carte nel campo largo W e alto H: {cards: [Vector2 centri, nell'ordine dei posti], w, h, scale}
static func field_layout(F: Array, W: float, H: float) -> Dictionary:
	var rows := field_rows(F)
	var n := rows.size()
	var max_per_row := 0
	for r: Array in rows:
		max_per_row = maxi(max_per_row, r.size())
	var sW := (W - 2.0 * FIELD_PAD - (max_per_row - 1) * GAP_X) / (max_per_row * CARD_W)
	var sH := (H - 2.0 * FIELD_PAD - (n - 1) * GAP_Y) / (n * CARD_H) if n > 1 else (H - 2.0 * FIELD_PAD) / CARD_H
	var scale := maxf(CARD_MIN_SCALE, minf(1.0, minf(sW, sH)))
	var w := CARD_W * scale
	var h := CARD_H * scale
	var free := (H - 2.0 * FIELD_PAD - h) / (n - 1) - h - GAP_Y if n > 1 else 0.0
	var off := maxf(0.0, minf(ROW_OFFSET_MAX, free / 2.0))
	var top := FIELD_PAD + off + h / 2.0
	var bottom := H - FIELD_PAD - off - h / 2.0
	var step := (bottom - top) / (n - 1) if n > 1 else 0.0
	var lo := FIELD_PAD + w / 2.0
	var hi := W - FIELD_PAD - w / 2.0
	var half := (hi - lo) / 2.0
	var mid := W / 2.0
	var cards: Array = []
	cards.resize(F.size())
	for r in n:
		var row: Array = rows[r]
		var yc := bottom - r * step if n > 1 else H / 2.0
		var mean_y := 0.0
		for i: int in row:
			mean_y += F[i][2]
		mean_y /= row.size()
		var by_x := row.duplicate()
		by_x.sort_custom(func(a: int, b: int) -> bool: return F[a][1] < F[b][1])
		var xs: Array = []
		for i: int in by_x:
			xs.append(mid + F[i][1] * half)
		xs = _spread_row(xs, w + GAP_X, lo, hi)
		for k in by_x.size():
			var i: int = by_x[k]
			var dy := maxf(-off, minf(off, (F[i][2] - mean_y) * ROW_OFFSET_K))
			cards[i] = Vector2(xs[k], yc - dy)
	return {"cards": cards, "w": w, "h": h, "scale": scale}


## due rettangoli (centri, misure w×h) si toccano?
static func overlaps(a: Vector2, b: Vector2, w: float, h: float) -> bool:
	return absf(a.x - b.x) < w - 1e-6 and absf(a.y - b.y) < h - 1e-6


## scambio possibile: almeno uno dei due è titolare (panchina↔panchina non cambia niente)
static func can_swap(lineup: Array, a: Variant, b: Variant) -> bool:
	return a != b and (lineup.has(a) or lineup.has(b))


## nuova formazione dopo lo scambio di a e b (quella passata non cambia)
static func swap_lineup(lineup: Array, a: Variant, b: Variant) -> Array:
	return lineup.map(func(id: Variant) -> Variant: return b if id == a else (a if id == b else id))


## variazione della somma delle valutazioni dei titolari se si scambiano a e b (giocatori);
## rate(p, ruolo) = valutazione nel ruolo
static func swap_delta(lineup: Array, F: Array, a: Variant, b: Variant, rate: Callable) -> int:
	if a == null or b == null or a.id == b.id:
		return 0
	var ia := lineup.find(a.id)
	var ib := lineup.find(b.id)
	var d := 0
	if ia >= 0:
		d += int(rate.call(b, F[ia][0])) - int(rate.call(a, F[ia][0]))
	if ib >= 0:
		d += int(rate.call(a, F[ib][0])) - int(rate.call(b, F[ib][0]))
	return d


## nome breve per la carta: "L. Ferrante" → "Ferrante"; un nome lungo con spazi → l'ultima parola
static func short_name(name: Variant) -> String:
	var s := str(name if name != null else "")
	var punto := s.rfind(".")
	if punto >= 0:
		s = s.substr(punto + 1)
	s = s.strip_edges()
	if s.length() > SHORT_NAME_MAX and s.contains(" "):
		var parole := s.split(" ", false)
		return parole[-1]
	return s


## panchina in ordine: ruolo (portieri prima) e poi valutazione
static func bench_order(list: Array) -> Array:
	var out := list.duplicate()
	var idx := {}
	for i in out.size():
		idx[out[i].id] = i
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := ROLE_ORDER.find(str(a.pos))
		var rb := ROLE_ORDER.find(str(b.pos))
		if ra != rb:
			return ra < rb
		var oa := D.overall(a)
		var ob := D.overall(b)
		if oa != ob:
			return oa > ob
		return idx[a.id] < idx[b.id])   # come il sort stabile del JS
	return out


## Tocco su una carta. stato = {sel, tgt, just} (sel = scelto, tgt = confronto, just = appena scambiati);
## esiste(id) = il giocatore scelto è ancora in rosa. Ritorna il nuovo stato più "swap": [a, b] se va fatto lo
## scambio (lo fa chi chiama, con Carriera.swap), altrimenti null.
static func pick_card(stato: Dictionary, lineup: Array, id: Variant, esiste: Callable) -> Dictionary:
	var sel: Variant = stato.get("sel")
	var tgt: Variant = stato.get("tgt")
	if sel == null or not esiste.call(sel):
		return {"sel": id, "tgt": null, "just": null, "swap": null}
	if sel == id:
		return {"sel": null, "tgt": null, "just": null, "swap": null}
	if tgt == id:
		return {"sel": null, "tgt": null, "just": [sel, id], "swap": [sel, id]}
	if can_swap(lineup, sel, id):
		return {"sel": sel, "tgt": id, "just": null, "swap": null}
	return {"sel": id, "tgt": null, "just": null, "swap": null}   # panchina → panchina: si sceglie l'altro
