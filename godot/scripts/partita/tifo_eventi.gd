# Fatti del motore → reazione del pubblico 3D (vista.tifo) e dei cori (audio_partita.occasione).
# Usato in partita vera (gioco.gd, _eventi) e nella prova della vista (prova_vista.gd). Leggero: un match sul tipo
# dell'evento, nessuna allocazione oltre all'array del risultato; la folla fa il resto in pubblico.gd (impulsi).
# Il gol non passa da qui: la vista lo vede da sola dal cambio del punteggio (festa una volta per gol).
extends RefCounted

var ultimo_tiro := 0          # squadra dell'ultimo tiro (il palo non dice di chi era)


## reazione per l'evento e: [tipo, squadra] ("occasione", "parata", "palo", "fischio") o [] se il pubblico non reagisce
func leggi(e: Dictionary) -> Array:
	match e.type:
		"kick":
			if e.get("p") != null and tiro(e):
				ultimo_tiro = e.p.team
				return ["occasione", ultimo_tiro]
		"post":
			return ["palo", ultimo_tiro]
		"save":
			if e.get("p") != null:
				return ["parata", e.p.team]
		"foul":
			if e.get("by") != null:
				return ["fischio", e.by.team]
	return []


## calcio verso la porta: tiro, o colpo di testa / al volo che non sia un rinvio (motion.gd li manda in porta)
static func tiro(e: Dictionary) -> bool:
	var k: String = str(e.get("kind", ""))
	return k == "shot" or ((k == "header" or k == "volley") and not e.get("clear", false))


## fa reagire vista (se ha tifo(): la vista finta no) e cori (se c'è audio); ritorna il tipo di reazione o ""
func applica(e: Dictionary, vista: Object, audio: Object = null) -> String:
	var r := leggi(e)
	if r.is_empty():
		return ""
	if vista != null and vista.has_method("tifo"):
		vista.tifo(r[0], r[1])
	# i cori salgono sull'occasione (tiro); parata e palo li alzano già audio.ooh() / audio.post()
	if r[0] == "occasione" and audio != null and audio.has_method("occasione"):
		audio.occasione()
	return r[0]
