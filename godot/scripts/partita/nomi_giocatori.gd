# Nomi sopra i giocatori (Luis 2026-11-26: "sopra i giocatori fai comparire il nome").
# Disegno 2D sopra la partita (un solo Control, niente Label3D): ogni fotogramma si proietta la testa di ogni
# giocatore con la telecamera vera (vista.world_to_screen) e si scrive il cognome, bianco col contorno scuro e un
# filo del colore della maglia sotto. Prima portatore e controllato, poi chi è vicino al pallone, poi gli altri più
# tenui e più piccoli se lontani; chi si sovrapporrebbe a un nome già scritto o al pallone si salta.
# Modi (Impostazioni → "Nomi sopra i giocatori", settings.nomi): "tutti", "pallone" (solo portatore e controllato),
# "nessuno". Solo grafica: legge il motore, non lo cambia.
extends Control

const Asp := preload("res://scripts/carriera/aspetto.gd")

const MODI := ["tutti", "pallone", "nessuno"]
const MODO_PREDEFINITO := "tutti"

const TESTA_H := 2.3            # m: sopra la testa (figure ×1,25)
const SOPRA_SEGNO_H := 3.15     # m: per il controllato, sopra il triangolo / la stellina (vista.gd MARKER_H 2,75)
const SOPRA_CERCHIO_PX := 17.0  # px sopra il centro del cerchietto del rallenty (raggio 13 + margine)
const CERCHIO_H := 3.5          # m: altezza del cerchietto del rallenty (gioco.gd CERCHIO_RALLENTY_H)
const STACCO_PX := 2.0          # px tra la testa e il fondo della scritta
const DIM_K := 0.85             # grandezza del carattere = px per metro × DIM_K ...
const DIM_MIN := 9.0            # ... tra questi due valori (punti logici: sul telefono ×3 pixel)
const DIM_MAX := 13.0           # il carattere si disegna sempre a questa grandezza e si rimpicciolisce con la scala:
                                # una sola grandezza in memoria (glifi e contorno), non una per ogni grandezza
const PPM_MINIMO := 4.0         # sotto tanti px per metro (molto lontano) gli altri non si scrivono
const PPM_PIENO := 40.0         # visuali molto vicine (dribbling, angolo, rimessa: il nome è già sulla schiena e il
const PPM_SPARISCE := 60.0      # corpo si piega lontano dal punto del motore): il nome sbiadisce da qui e sparisce qui
const VICINO_PALLONE := 9.0     # m: entro tanto dal pallone il nome conta di più
const ALFA_VICINO := 0.95
const ALFA_ALTRI := 0.72
const CONTORNO := 4             # px del contorno scuro
const COLORE_CONTORNO := Color(0.03, 0.04, 0.07, 0.85)
const FILO_H := 2.0             # filo del colore della squadra sotto il nome
const FILO_LARGO := 0.6         # ... largo così rispetto alla scritta
const MARGINE_PALLONE := 3.0    # px intorno al pallone che i nomi non coprono
const GRASSETTO := 0.55
const BORDO_PX := 3.0           # i nomi vicino al bordo restano tutti dentro lo schermo

var modo := MODO_PREDEFINITO
var _font: FontVariation
var _voci: Array = []           # scritte da disegnare: {testo, pos (piede della scritta, centro), dim, larg, alfa, col}
var _nomi: Array = []           # nome breve per ogni m.players[i]
var _srcs: Array = []           # src per cui _nomi è stato calcolato (cambio = si ricalcola)
var _colori := [Color.WHITE, Color.WHITE]
var _larghezze := {}            # testo → larghezza a DIM_MAX (si misura una volta)
## tempo speso in aggiorna() (µs, somma) e fotogrammi: misura del costo (gioco.gd lo stampa con --esci-dopo)
var us_tot := 0
var fotogrammi := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = GRASSETTO


## valore valido di settings.nomi (salvataggi vecchi o valori strani → "tutti")
static func modo_valido(v: Variant) -> String:
	var s := str(v) if v != null else ""
	return s if MODI.has(s) else MODO_PREDEFINITO


## colori della squadra 0 e 1 per il filo sotto il nome (quelli troppo scuri un po' schiariti: si vedono sul contorno)
func imposta_colori(c0: Color, c1: Color) -> void:
	_colori = [_filo(c0), _filo(c1)]


static func _filo(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.4) if c.get_luminance() < 0.3 else c


## cognome per ogni giocatore della lista {name, team}: "L. Ferrante" → "Ferrante"; se due compagni hanno lo
## stesso cognome, iniziale + cognome ("L. Ferrante"). Nomi senza iniziale: l'ultima parola se sono lunghi
static func nomi_brevi(giocatori: Array) -> Array:
	var cognomi: Array = []
	var conta := {}
	for g: Dictionary in giocatori:
		var c := cognome(str(g.get("name", "")))
		cognomi.append(c)
		var k := "%d|%s" % [int(g.get("team", 0)), c.to_lower()]
		conta[k] = int(conta.get(k, 0)) + 1
	var out: Array = []
	for i in giocatori.size():
		var g: Dictionary = giocatori[i]
		var c: String = cognomi[i]
		var k := "%d|%s" % [int(g.get("team", 0)), c.to_lower()]
		var ini := _iniziale(str(g.get("name", "")))
		out.append((ini + ". " + c) if int(conta[k]) > 1 and ini != "" and c != "" else c)
	return out


static func cognome(nome: String) -> String:
	var s := nome.strip_edges()
	var punto := s.rfind(". ")
	if punto >= 0:
		s = s.substr(punto + 2).strip_edges()
	elif s.length() > 12 and s.contains(" "):
		s = s.substr(s.rfind(" ") + 1)
	return s.left(14)


static func _iniziale(nome: String) -> String:
	var s := nome.strip_edges()
	return s.left(1).to_upper() if s != "" else ""


## sceglie le scritte da disegnare. cand: {testo, pos, dim, larg, rango (0 portatore/controllato, 1 vicino al
## pallone, 2 altri), dist (m dal pallone), alfa}; palla = rettangolo del pallone a schermo (vuoto = nessuno).
## Nell'ordine di rango e distanza dal pallone; dopo il rango 0, chi tocca una scritta già messa o il pallone si salta
static func scegli(cand: Array, modo_: String, palla: Rect2) -> Array:
	if modo_ == "nessuno":
		return []
	var lista: Array = []
	for c: Dictionary in cand:
		if modo_ == "pallone" and int(c.rango) > 0:
			continue
		lista.append(c)
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.rango < b.rango if a.rango != b.rango else a.dist < b.dist)
	var messe: Array = []
	var rett: Array = []
	for c: Dictionary in lista:
		var r := rettangolo(c)
		if int(c.rango) > 0:
			if palla.has_area() and r.intersects(palla):
				continue
			var tocca := false
			for q: Rect2 in rett:
				if r.intersects(q):
					tocca = true
					break
			if tocca:
				continue
		rett.append(r)
		messe.append(c)
	return messe


## spazio occupato da una scritta (pos = centro in basso)
static func rettangolo(c: Dictionary) -> Rect2:
	var d: float = c.dim
	var w: float = c.larg
	return Rect2(c.pos.x - w * 0.5 - 1.0, c.pos.y - d - 1.0, w + 2.0, d + FILO_H + 4.0)


func nascondi() -> void:
	if not _voci.is_empty():
		_voci.clear()
		queue_redraw()
	visible = false


## un fotogramma: m = SimMatch, vista con world_to_screen; alzato = giocatore col cerchietto del rallenty sopra
func aggiorna(m: Object, me: int, vista: Object, alzato: Object = null) -> void:
	var t0 := Time.get_ticks_usec()
	_aggiorna(m, me, vista, alzato)
	us_tot += Time.get_ticks_usec() - t0
	fotogrammi += 1


func _aggiorna(m: Object, me: int, vista: Object, alzato: Object) -> void:
	visible = true
	if modo == "nessuno" or m == null or vista == null:
		nascondi()
		return
	_controlla_nomi(m)
	var b: Object = m.ball
	var ctrl: Object = m.ctrl[me]
	var cand: Array = []
	for i in m.players.size():
		var p: Object = m.players[i]
		if p.off:
			continue
		var c := _candidato(p, i, b, ctrl, vista, alzato)
		if not c.is_empty():
			cand.append(c)
	var palla := Rect2()
	var bs: Vector3 = vista.world_to_screen(b.x, b.y, b.h + 0.27)
	if bs.z > 0.5:
		var bq: Vector3 = vista.world_to_screen(b.x, b.y, b.h + 1.27)
		var r := maxf(3.0, absf(bs.y - bq.y) * 0.3) + MARGINE_PALLONE
		palla = Rect2(bs.x - r, bs.y - r, 2.0 * r, 2.0 * r)
	_voci = scegli(cand, modo, palla)
	queue_redraw()


func _candidato(p: Object, i: int, b: Object, ctrl: Object, vista: Object, alzato: Object) -> Dictionary:
	var testo: String = _nomi[i] if i < _nomi.size() else ""
	if testo == "":
		return {}
	var a: Vector3 = vista.world_to_screen(p.x, p.y, TESTA_H)
	var q: Vector3 = vista.world_to_screen(p.x, p.y, TESTA_H + 1.0)
	if a.z < 0.5 or q.z < 0.5:
		return {}
	var ppm := a.y - q.y
	if ppm <= 0.0:
		return {}
	var rango := 2
	if p == b.owner or p == ctrl:
		rango = 0
	var dist := Vector2(p.x - b.x, p.y - b.y).length()
	if rango == 2 and dist < VICINO_PALLONE:
		rango = 1
	if (rango == 2 and ppm < PPM_MINIMO) or ppm >= PPM_SPARISCE:
		return {}
	var y := a.y - STACCO_PX
	if p == alzato:
		var cs: Vector3 = vista.world_to_screen(p.x, p.y, CERCHIO_H)
		y = minf(y, cs.y - SOPRA_CERCHIO_PX)
	elif p == ctrl:
		var s: Vector3 = vista.world_to_screen(p.x, p.y, SOPRA_SEGNO_H)
		y = minf(y, s.y)
	var dim := clampf(roundf(ppm * DIM_K), DIM_MIN, DIM_MAX)
	var larg := _larghezza(testo) * dim / DIM_MAX
	var alfa := 1.0
	if rango == 1:
		alfa = ALFA_VICINO
	elif rango == 2:
		alfa = ALFA_ALTRI * clampf((ppm - PPM_MINIMO) / 6.0 + 0.55, 0.55, 1.0)
	alfa *= clampf((PPM_SPARISCE - ppm) / (PPM_SPARISCE - PPM_PIENO), 0.0, 1.0)
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(INF, INF)
	if a.x < -larg or a.x > vp.x + larg or y < 0.0 or y > vp.y + dim:
		return {}
	var x := a.x
	if vp.x < INF:
		var mezzo := larg * 0.5 + BORDO_PX
		x = clampf(x, mezzo, maxf(mezzo, vp.x - mezzo))
	return {"testo": testo, "pos": Vector2(x, y), "dim": dim, "larg": larg, "rango": rango, "dist": dist,
		"alfa": alfa, "col": _colori[clampi(int(p.team), 0, 1)]}


func _larghezza(testo: String) -> float:
	if not _larghezze.has(testo):
		_larghezze[testo] = _font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(DIM_MAX)).x
	return _larghezze[testo]


func _controlla_nomi(m: Object) -> void:
	var cambiato: bool = _srcs.size() != m.players.size()
	if not cambiato:
		for i in m.players.size():
			if not is_same(m.players[i].src, _srcs[i]):
				cambiato = true
				break
	if not cambiato:
		return
	var lista: Array = []
	_srcs.clear()
	for p: Object in m.players:
		var src: Dictionary = p.src if p.src is Dictionary else {}
		lista.append({"name": str(src.get("name", p.name)), "team": int(p.team)})
		_srcs.append(p.src)
	_nomi = nomi_brevi(lista)


## scritte disegnate adesso (prove e test)
func voci() -> Array:
	return _voci


func _draw() -> void:
	for v: Dictionary in _voci:
		var w: float = v.larg
		var a: float = v.alfa
		var k: float = v.dim / DIM_MAX
		var ombra := Color(COLORE_CONTORNO, COLORE_CONTORNO.a * a)
		draw_set_transform(Vector2(v.pos.x - w * 0.5, v.pos.y - 2.0), 0.0, Vector2(k, k))
		draw_string_outline(_font, Vector2.ZERO, v.testo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(DIM_MAX), CONTORNO, ombra)
		draw_string(_font, Vector2.ZERO, v.testo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(DIM_MAX), Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO)
		var fw := maxf(8.0, w * FILO_LARGO)
		var fr := Rect2(v.pos.x - fw * 0.5, v.pos.y + 0.5, fw, FILO_H)
		draw_rect(fr.grow(1.0), ombra)
		var col: Color = v.col
		draw_rect(fr, Color(col, a))
