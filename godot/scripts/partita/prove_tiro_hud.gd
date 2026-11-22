# Interfaccia dell'allenamento libero (scripts/partita/prove_tiro.gd): riquadro in alto con prova, tentativo, punti,
# record e un pallino per ogni tentativo (verde gol, rosso sbagliato); dopo ogni tiro il riquadro diventa verde o
# rosso con l'esito ("GOL! +20 · Angolino!"); a fine prova la scheda col punteggio, il record e "Riprova" / "Esci".
# Stesso aspetto dell'allenamento guidato: ne riusa riquadro, scheda e tasti (allenamento_hud.gd).
extends "res://scripts/partita/allenamento_hud.gd"

signal riprova
signal esci

const ProveTiro := preload("res://scripts/partita/prove_tiro.gd")
const ROSSO := Color("#ff6b6b")
const FONDO_MALE := Color(0.165, 0.051, 0.063, 0.9)
const AIUTI := {
	"tiri": "Disegna una linea che finisce in porta. Angolini = più punti.",
	"punizioni": "Linea dal pallone in porta, curvala per scavalcare la barriera.",
	"rigori": "Linea dal pallone all'angolo che vuoi. Il portiere si tuffa.",
}

var record := 0               # record della prova (0 = nessuno), lo mette la regia
var _esiti: Array = []        # [{gol, punti, nota}] finora
var _stato := ["tiri", 0, 10, 0]


## riquadro in alto (tentativo da 0)
func stato(prova_: String, tentativo: int, tentativi: int, punti: int) -> void:
	_stato = [prova_, tentativo, tentativi, punti]
	_scrivi("", 0, false, false)


## dopo ogni tiro: riquadro verde (gol) o rosso con l'esito
func esito(gol: bool, punti: int, nota: String) -> void:
	_esiti.append({"gol": gol, "punti": punti, "nota": nota})
	_scrivi(nota, punti, gol, true)


func azzera() -> void:
	_esiti.clear()


func _scrivi(nota: String, p: int, gol: bool, con_esito: bool) -> void:
	var prova_: String = _stato[0]
	var bb := "[font_size=11][color=#ffe14a][b]%s · TENTATIVO %d DI %d[/b][/color][/font_size]\n" % [
		String(ProveTiro.NOMI.get(prova_, "")).to_upper(), mini(int(_stato[1]) + 1, int(_stato[2])), int(_stato[2])]
	bb += "Punti [color=#ffe14a][b]%d[/b][/color]" % int(_stato[3])
	bb += "  ·  Record %d" % record if record > 0 else "  ·  Nessun record"
	bb += "\n" + pallini(_esiti, int(_stato[2]))
	if con_esito:
		var testo := ("GOL! +%d · %s" % [p, nota]) if gol else nota
		bb += "\n[font_size=18][color=%s][b]%s[/b][/color][/font_size]" % ["#5ee08f" if gol else "#ff6b6b", testo]
	else:
		bb += "\n[font_size=12][color=#c3d0e8]%s[/color][/font_size]" % AIUTI.get(prova_, "")
	_riquadro.visible = true
	var fondo := FONDO
	var bordo := Color(GIALLO, 0.4)
	if con_esito:
		fondo = FONDO_BENE if gol else FONDO_MALE
		bordo = VERDE if gol else ROSSO
	_riquadro.add_theme_stylebox_override("panel", _stile(fondo, 14, bordo))
	_testo.text = bb
	_disponi()


## un pallino per tentativo: verde gol, rosso sbagliato, grigio da tirare
static func pallini(esiti: Array, tentativi: int) -> String:
	var s := ""
	for i in maxi(tentativi, esiti.size()):
		var col := "#5d6b85"
		if i < esiti.size():
			col = "#5ee08f" if esiti[i].gol else "#ff6b6b"
		s += "[color=%s]●[/color] " % col
	return "[font_size=15]%s[/font_size]" % s.strip_edges()


## scheda di fine prova: punteggio, record (o "Nuovo record!"), gol e tasti
func mostra_fine(r: Dictionary, nuovo_record: bool) -> void:
	_riquadro.visible = false
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_spazio(_sicura.size.y * 0.06)
	var su := _etichetta(13, GIALLO)
	su.text = "ALLENAMENTO LIBERO"
	_box.add_child(su)
	var tit := _etichetta(30, Color.WHITE)
	tit.text = String(ProveTiro.NOMI.get(r.prova, ""))
	_box.add_child(tit)
	var pannello := PanelContainer.new()
	var st := _stile(Color(1, 1, 1, 0.05), 16, Color(1, 1, 1, 0.13))
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	pannello.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var punti := _etichetta(54, GIALLO)
	punti.text = str(int(r.punti))
	v.add_child(punti)
	var sotto := _etichetta(15, Color("#c3d0e8"))
	sotto.text = "punti"
	v.add_child(sotto)
	var rec := _etichetta(20 if nuovo_record else 16, VERDE if nuovo_record else Color.WHITE)
	rec.text = "Nuovo record!" if nuovo_record else ("Record: %d" % record if record > 0 else "Nessun record")
	v.add_child(rec)
	var angolini := (r.esiti as Array).filter(func(e: Dictionary) -> bool: return e.nota == "Angolino!").size()
	var gol := _etichetta(16, Color.WHITE)
	gol.text = "Gol %d su %d · Angolini %d" % [int(r.gol), int(r.tentativi), angolini]
	v.add_child(gol)
	var dots := _rich(15)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.custom_minimum_size.x = _box.size.x - 32.0
	dots.text = "[center]%s[/center]" % pallini(r.esiti, 0)
	v.add_child(dots)
	pannello.add_child(v)
	_box.add_child(pannello)
	_spazio(4)
	_tasto("Riprova", true, premi_riprova)
	_tasto("Esci", false, premi_esci)
	_scheda.visible = true
	scheda.emit(true)


func premi_riprova() -> void:
	_chiudi_scheda()
	riprova.emit()


func premi_esci() -> void:
	_chiudi_scheda()
	esci.emit()
