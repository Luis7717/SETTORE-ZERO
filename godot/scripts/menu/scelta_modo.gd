# Scelta del modo della partita prima di giocare (casa della carriera e amichevole): "Partita intera" o
# "Momenti chiave" (~10 azioni giocate, il resto raccontato dalla cronaca: scripts/partita/momenti.gd).
# È l'impostazione `settings.momenti` della carriera (si cambia anche in Impostazioni): si salva subito.
extends RefCounted

const T := preload("res://scripts/menu/tema_menu.gd")
const U := preload("res://scripts/menu/ui.gd")
const CHIAVE := "momenti"
const SPIEGA := "Si giocano circa 10 azioni, il resto lo racconta la cronaca."


## due chip affiancati; `schermata` è la MenuSchermata che li ospita (salva e ridisegna dopo la scelta)
static func nuova(schermata: Node) -> Control:
	var s: Dictionary = schermata.stato()
	var st: Dictionary = s.get("settings", {}) if s.get("settings") is Dictionary else {}
	var on := bool(st.get(CHIAVE, false))
	var v := U.vbox(6)
	var riga := HFlowContainer.new()
	riga.alignment = FlowContainer.ALIGNMENT_CENTER
	riga.add_theme_constant_override("h_separation", 8)
	riga.add_child(U.chip("Partita intera", not on, imposta.bind(schermata, false)))
	riga.add_child(U.chip("Momenti chiave", on, imposta.bind(schermata, true)))
	v.add_child(riga)
	if on:
		var l := U.paragrafo(SPIEGA, 12.0, T.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return v


static func imposta(schermata: Node, valore: bool) -> void:
	var s: Dictionary = schermata.stato()
	if s.is_empty():
		return
	if not s.get("settings") is Dictionary:
		s["settings"] = {}
	s.settings[CHIAVE] = valore
	schermata.salva()
	schermata.ridisegna()
