# Allenamento libero (PIANO.md, fase E punto 13): scelta della prova a punti (tiri, punizioni, rigori) col record
# di ciascuna e il campione che tira. Tocco su una prova → App.allenamento_libero(prova) (scripts/app.gd); finita o
# abbandonata la prova si torna qui. Logica della prova: scripts/partita/prove_tiro.gd; record: record_prove.gd.
extends MenuSchermata

const RecordProve := preload("res://scripts/carriera/record_prove.gd")
const ProveTiro := preload("res://scripts/partita/prove_tiro.gd")
const DESCRIZIONI := {
	"tiri": "10 tiri da posti diversi, dentro e fuori area",
	"punizioni": "8 punizioni con la barriera, da posti diversi",
	"rigori": "5 rigori, poi a oltranza fino al primo errore",
}


func prepara() -> void:
	titolo = "Allenamento libero"


func costruisci() -> void:
	var s := stato()
	corpo.add_child(U.paragrafo("Si tira coi gesti della partita: linea che finisce in porta, curvala per l'effetto. Gol = %d punti, vicino al palo +%d, sotto la traversa +%d." % [
		ProveTiro.PUNTI_GOL, ProveTiro.PUNTI_PALO, ProveTiro.PUNTI_ALTO], 13.5))
	var c := carriera()
	var champ: Variant = c.campione() if c != null and c.has_method("campione") and not s.is_empty() else null
	if champ is Dictionary:
		corpo.add_child(U.bb("Tira il tuo campione: [color=#ffd93d][b]%s[/b][/color] · Tiro %d" % [
			U.esc(champ.get("name", "")), int(champ.get("tir", 0))], 14, T.DIM))
	for prova: String in ProveTiro.PROVE:
		corpo.add_child(_carta_prova(prova, RecordProve.record(s, prova)))


func _carta_prova(prova: String, record: int) -> Control:
	var b := U.bottone("", "", _gioca_prova.bind(prova), 84)
	var h := U.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -18
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := U.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(U.corto(String(ProveTiro.NOMI[prova]), 18, T.TXT, T.PESO_NERO))
	v.add_child(U.corto(String(DESCRIZIONI[prova]), 12.5, T.DIM, T.PESO_MEDIO))
	h.add_child(v)
	var rec := U.vbox(0)
	rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rec.add_child(U.testo("RECORD", 10.5, T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_RIGHT))
	rec.add_child(U.testo(str(record) if record > 0 else "–", 22, T.GOLD if record > 0 else T.DIM, T.PESO_NERO, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(rec)
	b.add_child(h)
	return b


func _gioca_prova(prova: String) -> void:
	if deviazione.is_valid():
		deviazione.call("gioca:prove", prova)
		return
	var ap := app()
	if ap != null and ap.has_method("allenamento_libero"):
		ap.allenamento_libero(prova)
	else:
		print("Menu: allenamento libero %s (senza App)" % prova)
