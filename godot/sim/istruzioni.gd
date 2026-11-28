# Istruzioni ai giocatori (Luis 2026-11-28): per ogni ruolo una o due "istruzioni", ognuna con tre scelte (quella in
# mezzo = come sempre). Esempi di Luis: terzini difensivi / equilibrati / offensivi; esterni larghi sulla fascia /
# equilibrati / difensivi; mediano che resta nel suo ultimo quarto o arriva fino a centrocampo; attaccante che attacca
# la profondità o fa la boa. Più le idee proposte e accettate: ali che tagliano dentro o restano larghe, centrali che
# escono in anticipo o coprono, attaccanti che pressano o restano su, trequartista che si inserisce o resta tra le
# linee, portiere che esce spesso o resta tra i pali.
#
# Solo dati e funzioni pure (niente grafica, niente numeri casuali del motore). Dove valgono:
# - carriera: `s.istruzioni` = {"<id>": {chiave: scelta}} (campo nuovo, assente = tutto equilibrato);
#   Carriera.squadraPartita mette nella copia di ogni giocatore `istr` = {chiave: scelta};
# - squadre della CPU: per_squadra(stili, ruoli dei posti, seme) secondo i loro stili (Carriera.avversarioPartita);
# - motore: sim/istruzioni_gioco.gd legge p.src.istr col ruolo del posto (p.ruolo). Senza `istr`, o con le scelte di
#   mezzo, il motore è identico a prima (nessun ramo nuovo).
extends RefCounted

## chiave → [nome dell'istruzione, [scelta, nome, spiegazione] × 3]; la seconda scelta è quella di sempre
const ISTRUZIONI := {
	"spinta": ["Spinta", [
		["difensivo", "Difensivo", "Resta indietro vicino ai centrali, sale poco anche quando attacchiamo."],
		["equilibrato", "Equilibrato", "Sale e torna secondo l'azione."],
		["offensivo", "Offensivo", "Sale tanto sulla fascia, si sovrappone e arriva fino al fondo."]]],
	"fascia": ["In fascia", [
		["largo", "Largo sulla fascia", "Corre attaccato alla linea laterale e allarga il gioco."],
		["equilibrato", "Equilibrato", "Un po' largo e un po' dentro, secondo l'azione."],
		["difensivo", "Difensivo", "Resta più basso e rientra ad aiutare il terzino."]]],
	"mediano": ["Posizione", [
		["difensivo", "Difensivo", "Resta nel suo ultimo quarto di campo, davanti ai centrali."],
		["equilibrato", "Equilibrato", "Sale un po' quando la manovra lo chiede."],
		["offensivo", "Offensivo", "Accompagna l'azione fino a centrocampo e oltre."]]],
	"mezzala": ["Posizione", [
		["difensivo", "Difensivo", "Torna di più e sta un po' più indietro."],
		["centrale", "Centrale", "Tiene il suo posto a centrocampo."],
		["avanzato", "Avanzato", "Gioca più alto, vicino alle punte."]]],
	"trequarti": ["Posizione", [
		["difensivo", "Difensivo", "Torna di più e aiuta il centrocampo."],
		["equilibrato", "Equilibrato", "Tiene il suo posto dietro le punte."],
		["avanzato", "Avanzato", "Gioca quasi da seconda punta."]]],
	"area": ["Senza palla", [
		["tra_linee", "Tra le linee", "Resta dietro le punte ad aspettare il pallone, non entra in area."],
		["equilibrato", "Equilibrato", "Entra in area quando serve."],
		["inserimento", "Inserimento", "Entra in area sui cross e sui tiri dei compagni."]]],
	"ala": ["Ala", [
		["larga", "Resta larga", "Va sul fondo per il cross, sempre vicina alla linea laterale."],
		["equilibrata", "Equilibrata", "Larga ma pronta a stringere."],
		["taglia", "Taglia dentro", "Dalla fascia punta verso il centro e la porta."]]],
	"movimento": ["Movimento", [
		["boa", "Boa", "Resta spalle alla porta e viene incontro per fare da appoggio."],
		["equilibrato", "Equilibrato", "Un po' in profondità e un po' incontro."],
		["profondita", "Attacca la profondità", "Scatta sempre alle spalle dei difensori aspettando il filtrante."]]],
	"pressione": ["Senza palla", [
		["resta", "Resta su", "Quando la palla è loro resta alto, pronto al contropiede."],
		["equilibrato", "Equilibrato", "Pressa solo quando il pallone è vicino."],
		["pressa", "Pressa i difensori", "Va addosso ai difensori quando impostano."]]],
	"marcatura": ["Marcatura", [
		["copre", "Copre", "Resta in linea e un po' più dietro, non esce mai."],
		["equilibrato", "Equilibrato", "Difende la sua zona."],
		["anticipo", "Esce in anticipo", "Va incontro all'attaccante: ruba più palloni ma lascia spazio dietro."]]],
	"uscite": ["Uscite", [
		["pali", "Resta tra i pali", "Esce solo sui palloni sicuri."],
		["equilibrato", "Equilibrato", "Esce quando arriva prima degli attaccanti."],
		["esce", "Esce spesso", "Anticipa cross e lanci, anche rischiando."]]],
}

## ruolo del posto → istruzioni che si possono dare (in quest'ordine)
const DEL_RUOLO := {
	"P": ["uscite"], "TD": ["spinta"], "TS": ["spinta"], "DC": ["marcatura"], "CDC": ["mediano"], "CC": ["mezzala"],
	"ED": ["fascia"], "ES": ["fascia"], "COC": ["trequarti", "area"], "AD": ["ala", "pressione"],
	"AS": ["ala", "pressione"], "ATT": ["movimento", "pressione"],
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
			spinge.merge({"spinta": 1, "fascia": -1, "ala": -1})
		"contropiede":
			spinge.merge({"movimento": 1, "mediano": -1, "pressione": -1})
		"possesso":
			spinge.merge({"area": -1, "movimento": -1, "mezzala": 1})
		"lanci":
			spinge.merge({"movimento": -1, "area": 1})
	match stile_dif:
		"pressing":
			spinge.merge({"pressione": 1, "marcatura": 1, "uscite": 1})
		"catenaccio":
			spinge.merge({"spinta": -1, "marcatura": -1, "mediano": -1, "uscite": -1})
		"uomo":
			spinge.merge({"marcatura": 1})
		"fuorigioco":
			spinge.merge({"uscite": 1})
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
