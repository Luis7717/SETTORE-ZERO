# Istruzioni ai giocatori (Luis 2026-11-28): per ogni ruolo da una a quattro "istruzioni", ognuna con tre scelte
# (quella in mezzo = Equilibrato = come sempre). Rifatte lo stesso giorno: niente più "difensivo / avanzato", ogni
# scelta ha un nome che dice cosa fa il giocatore (Si sovrappone, Si accentra, Torna sempre, Si abbassa tra i
# centrali, Box to box, Falso nove, Fa la boa, Sul filo del fuorigioco, Attacca il secondo palo, Marcatura stretta,
# Gioca semplice / Porta palla, Imposta palla al piede, ...).
#
# Solo dati e funzioni pure (niente grafica, niente numeri casuali del motore). Dove valgono:
# - carriera: `s.istruzioni` = {"<id>": {chiave: scelta}} (campo nuovo, assente = tutto equilibrato);
#   Carriera.squadraPartita mette nella copia di ogni giocatore `istr` = {chiave: scelta};
# - squadre della CPU: per_squadra(stili, ruoli dei posti, seme) secondo i loro stili (Carriera.avversarioPartita);
# - motore: sim/istruzioni_gioco.gd legge p.src.istr col ruolo del posto (p.ruolo). Senza `istr`, o con le scelte di
#   mezzo, il motore è identico a prima (nessun ramo nuovo).
extends RefCounted

## chiave → [nome dell'istruzione, [scelta, nome, spiegazione] × 3]; la seconda scelta è quella di sempre. I nomi dicono
## cosa fa il giocatore (Luis 2026-11-28: "niente avanzato / arretrato, nomi che indichino quello che farà")
const ISTRUZIONI := {
	"spinta": ["Spinta", [
		["bloccato", "Resta bloccato", "Resta dietro coi centrali e non sale, nemmeno quando attacchiamo."],
		["equilibrato", "Equilibrato", "Sale e torna secondo l'azione."],
		["sovrapposizione", "Si sovrappone", "Corre sulla fascia oltre l'esterno e arriva fino al fondo per il cross."]]],
	"corsia": ["Dove attacca", [
		["fascia", "Sempre in fascia", "Quando attacchiamo resta largo, attaccato alla linea laterale."],
		["equilibrato", "Equilibrato", "Largo o dentro secondo l'azione."],
		["accentra", "Si accentra", "Quando abbiamo palla entra in mezzo al campo come un centrocampista."]]],
	"fascia": ["In fascia", [
		["linea", "Attaccato alla linea", "Corre sulla linea laterale e allarga il gioco."],
		["equilibrato", "Equilibrato", "Un po' largo e un po' dentro, secondo l'azione."],
		["torna", "Torna sempre", "Quando perdiamo palla rincorre e aiuta il terzino del suo lato."]]],
	"mediano": ["Posizione", [
		["abbassa", "Si abbassa tra i centrali", "Quando abbiamo palla scende in mezzo ai due centrali e fa partire l'azione."],
		["equilibrato", "Equilibrato", "Resta davanti alla difesa e sale un po' con la manovra."],
		["accompagna", "Accompagna l'azione", "Sale con la squadra fino a centrocampo e oltre."]]],
	"mezzala": ["Compito", [
		["copertura", "Resta in copertura", "Non si sbilancia: resta dietro la palla a proteggere la difesa."],
		["equilibrato", "Equilibrato", "Tiene il suo posto a centrocampo."],
		["box", "Box to box", "Corre da un'area all'altra: torna in difesa e si inserisce in area quando attacchiamo."]]],
	"trequarti": ["Compito", [
		["aiuta", "Aiuta il centrocampo", "Torna a prendere palla e dà una mano ai centrocampisti."],
		["equilibrato", "Equilibrato", "Tiene il suo posto dietro le punte."],
		["seconda_punta", "Seconda punta", "Gioca vicino all'attaccante, quasi alla sua altezza."]]],
	"area": ["Senza palla", [
		["tra_linee", "Tra le linee", "Resta dietro le punte ad aspettare il pallone, non entra in area."],
		["equilibrato", "Equilibrato", "Entra in area quando serve."],
		["inserimento", "Si inserisce in area", "Entra in area sui cross e sui tiri dei compagni."]]],
	"ala": ["Ala", [
		["larga", "Resta larga", "Va sul fondo per il cross, sempre vicina alla linea laterale."],
		["equilibrata", "Equilibrata", "Larga ma pronta a stringere."],
		["taglia", "Taglia dentro", "Dalla fascia punta verso il centro e la porta."]]],
	"cross": ["Sui cross", [
		["fuori", "Aspetta fuori area", "Col pallone sull'altra fascia resta al limite, pronto per la respinta."],
		["equilibrato", "Equilibrato", "Entra in area quando serve."],
		["secondo_palo", "Attacca il secondo palo", "Col pallone sull'altra fascia entra in area sul palo lontano."]]],
	"movimento": ["Movimento", [
		["falso_nove", "Falso nove", "Viene incontro fino a centrocampo e lascia lo spazio alle ali."],
		["equilibrato", "Equilibrato", "Un po' in profondità e un po' incontro."],
		["profondita", "Attacca la profondità", "Scatta sempre alle spalle dei difensori aspettando il filtrante."]]],
	"riferimento": ["Riferimento", [
		["boa", "Fa la boa", "Resta spalle alla porta davanti ai difensori e fa da appoggio."],
		["equilibrato", "Equilibrato", "Si muove secondo l'azione."],
		["filo", "Sul filo del fuorigioco", "Sempre sulla linea dei difensori: pronto per il lancio, ma rischia il fuorigioco."]]],
	"pressione": ["Senza palla", [
		["resta", "Resta su", "Quando la palla è loro resta alto, pronto al contropiede."],
		["equilibrato", "Equilibrato", "Pressa solo quando il pallone è vicino."],
		["pressa", "Pressa i difensori", "Va addosso ai difensori quando impostano."]]],
	"marcatura": ["Marcatura", [
		["copre", "Copre lo spazio", "Resta dietro a coprire lo spazio alle spalle, non esce mai."],
		["equilibrato", "Equilibrato", "Difende la sua zona."],
		["stretta", "Marcatura stretta", "Sta attaccato all'avversario più vicino e prova ad anticiparlo."]]],
	"imposta": ["Con la palla", [
		["semplice", "Gioca semplice", "Passa subito al compagno più vicino."],
		["equilibrato", "Equilibrato", "Passa o avanza secondo lo spazio."],
		["imposta", "Imposta palla al piede", "Se ha spazio sale col pallone fino a centrocampo."]]],
	"con_palla": ["Con la palla", [
		["semplice", "Gioca semplice", "Rallenta, protegge palla e cerca il passaggio facile."],
		["equilibrato", "Equilibrato", "Passa o avanza secondo lo spazio."],
		["porta", "Porta palla", "Punta l'uomo e avanza col pallone."]]],
	"uscite": ["Uscite", [
		["pali", "Resta tra i pali", "Esce solo sui palloni sicuri."],
		["equilibrato", "Equilibrato", "Esce quando arriva prima degli attaccanti."],
		["esce", "Esce spesso", "Anticipa cross e lanci, anche rischiando."]]],
}

## ruolo del posto → istruzioni che si possono dare (in quest'ordine)
const DEL_RUOLO := {
	"P": ["uscite"],
	"TD": ["spinta", "corsia", "con_palla"], "TS": ["spinta", "corsia", "con_palla"],
	"DC": ["marcatura", "imposta"],
	"CDC": ["mediano", "marcatura", "con_palla"],
	"CC": ["mezzala", "con_palla"],
	"ED": ["fascia", "con_palla"], "ES": ["fascia", "con_palla"],
	"COC": ["trequarti", "area", "con_palla"],
	"AD": ["ala", "cross", "pressione", "con_palla"], "AS": ["ala", "cross", "pressione", "con_palla"],
	"ATT": ["movimento", "riferimento", "pressione", "con_palla"],
}


## istruzioni del ruolo (chiavi), [] se il ruolo non ne ha
static func del_ruolo(ruolo: String) -> Array:
	return DEL_RUOLO.get(ruolo, [])


## scelta di mezzo (= come sempre) dell'istruzione
static func base(chiave: String) -> String:
	return String(ISTRUZIONI[chiave][1][1][0]) if ISTRUZIONI.has(chiave) else ""


## scelte possibili [scelta, nome, spiegazione] dell'istruzione
static func scelte(chiave: String) -> Array:
	return ISTRUZIONI[chiave][1] if ISTRUZIONI.has(chiave) else []


static func nome(chiave: String) -> String:
	return String(ISTRUZIONI[chiave][0]) if ISTRUZIONI.has(chiave) else ""


## nome della scelta (es. "Offensivo"); "" se non esiste
static func nome_scelta(chiave: String, scelta: String) -> String:
	for s: Array in scelte(chiave):
		if s[0] == scelta:
			return String(s[1])
	return ""


static func valida(chiave: String, scelta: Variant) -> bool:
	return scelta is String and nome_scelta(chiave, scelta) != ""


## scelta del giocatore per l'istruzione (dal suo `istr`, quello che il motore riceve): quella di mezzo se manca
static func di(istr: Variant, chiave: String) -> String:
	if istr is Dictionary and valida(chiave, istr.get(chiave)):
		return String(istr[chiave])
	return base(chiave)


## la scelta del giocatore spinge verso la prima (-1), la terza (+1) o è quella di mezzo (0)
static func verso(istr: Variant, chiave: String) -> int:
	var sc := scelte(chiave)
	var v := di(istr, chiave)
	if sc.is_empty() or v == String(sc[1][0]):
		return 0
	return -1 if v == String(sc[0][0]) else 1


## solo le istruzioni valide e diverse da quella di mezzo (quelle che si salvano e vanno nel motore)
static func pulisci(istr: Variant) -> Dictionary:
	var r := {}
	if istr is Dictionary:
		for k: Variant in istr:
			if k is String and valida(k, istr[k]) and istr[k] != base(k):
				r[k] = istr[k]
	return r


## riga breve per il pannello del giocatore: "Spinta: Offensivo · ..." (solo le istruzioni del ruolo); "" se tutte di mezzo
static func testo(istr: Variant, ruolo: String) -> String:
	var pezzi: Array = []
	for k: String in del_ruolo(ruolo):
		var v := di(istr, k)
		if v != base(k):
			pezzi.append("%s: %s" % [nome(k), nome_scelta(k, v)])
	return " · ".join(pezzi)


# ---------------------------------------------------------------- squadre della CPU
## istruzioni dei giocatori della CPU, posto per posto, secondo gli stili della squadra (un po' a caso col seme, così le
## squadre non sono tutte uguali): [{chiave: scelta}] × posti. stile_att/stile_dif come in sim/stili.gd
static func per_squadra(stile_att: String, stile_dif: String, ruoli: Array, seme: int) -> Array:
	var spinge := {} # chiave → -1 / +1 preferito dallo stile
	match stile_att:
		"fasce":
			spinge.merge({"spinta": 1, "fascia": -1, "ala": -1, "cross": 1})
		"contropiede":
			spinge.merge({"movimento": 1, "pressione": -1, "con_palla": 1, "mezzala": 1})
		"possesso":
			spinge.merge({"area": -1, "movimento": -1, "corsia": 1, "mediano": -1, "con_palla": -1, "imposta": 1})
		"lanci":
			spinge.merge({"riferimento": -1, "area": 1, "imposta": -1})
	match stile_dif:
		"pressing":
			spinge.merge({"pressione": 1, "marcatura": 1, "uscite": 1})
		"catenaccio":
			spinge.merge({"spinta": -1, "marcatura": -1, "fascia": 1, "mezzala": -1, "uscite": -1})
		"uomo":
			spinge.merge({"marcatura": 1})
		"fuorigioco":
			spinge.merge({"uscite": 1, "riferimento": 1})
	var out: Array = []
	for i in ruoli.size():
		var d := {}
		for k: String in del_ruolo(String(ruoli[i])):
			var h := _hash(seme, i * 16 + k.length() * 7 + k.unicode_at(0)) % 100
			var v := 0
			if spinge.has(k):
				v = int(spinge[k]) if h < 70 else 0 # lo stile si vede nel 70% dei giocatori
			elif h < 15:
				v = -1
			elif h >= 85:
				v = 1
			if v != 0:
				d[k] = String(scelte(k)[1 + v][0])
		out.append(d)
	return out


static func _hash(a: int, b: int) -> int:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)
