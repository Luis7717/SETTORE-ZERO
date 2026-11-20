# Salvataggio della carriera su file (Godot): `user://salvataggio.json` = {"versione": N, "carriera": <stato s>}.
# Nuovo formato, separato da quello dell'app web (localStorage `tag_save_v1`, che qui non si legge).
#
# Scrittura sicura: si scrive `salvataggio.json.tmp`, lo si rilegge per controllarlo, poi il file buono di prima
# diventa `salvataggio.json.bak` e il temporaneo prende il suo posto. Se l'app si chiude a metà resta sempre un file
# intero: la lettura prova nell'ordine il file principale, il temporaneo e la copia.
# Lettura: un file rotto (JSON sbagliato, campi essenziali mancanti) si salta; il primo buono vince.
# I campi mancanti si riempiono coi valori predefiniti in carriera.gd (completa).
extends RefCounted

const JS := preload("res://scripts/carriera/js.gd")

const VERSIONE := 1
const PERCORSO := "user://salvataggio.json"


## scrive lo stato in modo sicuro; ritorna true se il file nuovo è al suo posto
static func scrivi(percorso: String, stato: Dictionary) -> bool:
	var testo := JSON.stringify({"versione": VERSIONE, "carriera": stato}, "", false, true)
	var tmp := percorso + ".tmp"
	DirAccess.make_dir_recursive_absolute(percorso.get_base_dir())
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("salvataggio: non riesco a scrivere %s (errore %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(testo)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK or estrai(leggi_file(tmp)) == null:
		push_warning("salvataggio: il file temporaneo non si rilegge (errore %d)" % err)
		return false
	var bak := percorso + ".bak"
	if FileAccess.file_exists(percorso):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var e1 := DirAccess.rename_absolute(percorso, bak)
		if e1 != OK:
			push_warning("salvataggio: copia .bak non riuscita (errore %d)" % e1)
			DirAccess.remove_absolute(percorso)
	var e2 := DirAccess.rename_absolute(tmp, percorso)
	if e2 != OK:
		push_warning("salvataggio: rinomina del temporaneo non riuscita (errore %d)" % e2)
		return false
	return true


## testo del file, "" se non c'è o non si apre
static func leggi_file(percorso: String) -> String:
	if not FileAccess.file_exists(percorso):
		return ""
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


## stato della carriera dal testo del file, coi numeri interi come int; null se il testo è rotto
## o mancano le parti che non si possono ricostruire (squadre, divisioni, rosa)
static func estrai(testo: String) -> Variant:
	if testo.strip_edges() == "":
		return null
	var json := JSON.new()
	if json.parse(testo) != OK:
		return null
	var dati: Variant = json.data
	if not dati is Dictionary or not dati.get("carriera") is Dictionary:
		return null
	var s: Dictionary = JS.int_numbers(dati.carriera)
	if not s.get("teams") is Dictionary or not s.teams.has("me") or not s.teams.me is Dictionary:
		return null
	if not s.get("divs") is Array or s.divs.size() != 3:
		return null
	var con_me := 0
	for d: Variant in s.divs:
		if not d is Array or d.size() != 10:
			return null
		for id: Variant in d:
			if not id is String:
				return null
		if d.has("me"):
			con_me += 1
	if con_me != 1:
		return null
	if not s.get("squad") is Array or s.squad.size() < 11:
		return null
	for p: Variant in s.squad:
		if not p is Dictionary or not JS.is_integer(p.get("id")):
			return null
	return s


## legge il primo file buono tra principale, temporaneo e copia.
## Ritorna {"stato": Dictionary o null, "fonte": "principale"|"temporaneo"|"copia"|"", "rotti": [percorsi]}
static func leggi(percorso: String) -> Dictionary:
	var rotti: Array = []
	for coppia: Array in [[percorso, "principale"], [percorso + ".tmp", "temporaneo"], [percorso + ".bak", "copia"]]:
		var p: String = coppia[0]
		if not FileAccess.file_exists(p):
			continue
		var s: Variant = estrai(leggi_file(p))
		if s != null:
			return {"stato": s, "fonte": coppia[1], "rotti": rotti}
		rotti.append(p)
	return {"stato": null, "fonte": "", "rotti": rotti}


## mette da parte un file rotto (salvataggio.json → salvataggio.json.rotto) invece di cancellarlo
static func metti_da_parte(percorso: String) -> void:
	if not FileAccess.file_exists(percorso):
		return
	var dest := percorso + ".rotto"
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	DirAccess.rename_absolute(percorso, dest)


## cancella salvataggio, temporaneo e copia
static func cancella(percorso: String) -> void:
	for p: String in [percorso, percorso + ".tmp", percorso + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
