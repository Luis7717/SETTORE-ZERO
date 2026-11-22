# Impostazioni (settings() di src/ui.js): partita intera o momenti chiave (settings.momenti), durata di un tempo, difficoltà, portiere, audio; in più musica e
# vibrazione (campi nuovi del salvataggio, accesi se mancano); stile della divisa e stemma; cancella la carriera
# (secondo tocco = conferma). Ogni scelta si salva subito e avvisa App (App.impostazioni(), come api.settings).
extends MenuSchermata

var _conferma := false


func prepara() -> void:
	titolo = "Impostazioni"


func costruisci() -> void:
	var s := stato()
	if s.is_empty():
		return
	var st: Dictionary = s.get("settings", {})
	_opzioni(st, "Partita", "momenti", [[false, "Intera"], [true, "Momenti chiave (~10 azioni)"]], false)
	_opzioni(st, "Durata di un tempo", "half", [[90, "1:30"], [150, "2:30"], [240, "4:00"], [360, "6:00"]], 150)
	_opzioni(st, "Difficoltà avversari", "diff", [[0, "Facile"], [1, "Normale"], [2, "Difficile"]], 1)
	_opzioni(st, "Portiere", "autoGk", [[false, "Manuale (tuffo col dito)"], [true, "Automatico"]], false)
	_opzioni(st, "Audio", "sound", [[true, "Acceso"], [false, "Spento"]], true)
	_opzioni(st, "Musica", "music", [[true, "Accesa"], [false, "Spenta"]], true)
	_opzioni(st, "Vibrazione", "vibra", [[true, "Accesa"], [false, "Spenta"]], true)

	corpo.add_child(U.sezione("Squadra"))
	var g := U.griglia(2, 8, 8)
	var kit := U.bottone("Stile della divisa", "", func() -> void: vai("editor", {"flow": "kit"}), 48)
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(kit)
	var cr := U.bottone("", "", func() -> void: vai("editor", {"flow": "crest"}), 48)
	cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var k := D.kit(s.kit)
	U.contenuto_centrato(cr, MenuStemma.nuovo(carriera().crest(), int(k[1]), int(k[2]), Vector2(22, 26)), "Stemma", 16, T.TXT, T.PESO_FORTE)
	g.add_child(cr)
	corpo.add_child(g)

	corpo.add_child(U.sezione("Carriera"))
	var w := U.bottone("Cancella la carriera salvata", "BtnFantasma", Callable())
	w.pressed.connect(func() -> void:
		if U.al_tocco.is_valid():
			U.al_tocco.call()
		if not _conferma:
			_conferma = true
			w.text = "Sicuro? Tocca di nuovo per cancellare tutto"
			return
		carriera().reset()
		vai("nuova_carriera"))
	corpo.add_child(w)


func _opzioni(st: Dictionary, nome: String, chiave: String, valori: Array, predefinito: Variant) -> void:
	corpo.add_child(U.sezione(nome))
	var attuale: Variant = st.get(chiave, predefinito)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for v: Array in valori:
		var on := str(attuale) == str(v[0])
		chips.add_child(U.chip(v[1], on, _imposta.bind(chiave, v[0])))
	corpo.add_child(chips)


func _imposta(chiave: String, valore: Variant) -> void:
	var s := stato()
	if not s.has("settings"):
		s.settings = {}
	s.settings[chiave] = valore
	salva()
	var ap := app()
	if ap != null and ap.has_method("impostazioni"):
		ap.impostazioni()
	ridisegna()
