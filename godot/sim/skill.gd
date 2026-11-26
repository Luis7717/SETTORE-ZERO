# Giochetti del dribbling della persona (Luis 2026-11-26: "fai skill vere e aggiungine"), solo con "rifiniture".
# Il motore sceglie QUALE giochetto fa il portatore quando il dribbling prenotato riesce, perché ognuno dura un tempo
# diverso prima dello scatto (`show`, s di partita); come si muovono gambe e pallone lo decide la grafica
# (scripts/partita/mosse/coreo_dribbling.gd, stesso `id`). L'esito è già deciso prima e non cambia.
# La scelta usa un generatore a parte (base.gd skillRng, stesso seme della partita): la sequenza di rnd() resta uguale.
extends RefCounted

# in ordine di difficoltà: `dri` = sotto-statistica Dribbling che serve per saperlo fare; durante il giochetto il
# portatore va a `vel` × DRIB_SHOW_V, di lato verso la finta per `lat` (0 = dritto e poi fermo davanti al difensore,
# negativo = dal lato scelto, col pallone)
const LISTA := [
	{"id": "finta", "name": "Finta di corpo", "show": 0.35, "dri": 0.0, "lat": 1.0, "vel": 1.0},
	{"id": "stopgo", "name": "Stop e via", "show": 0.45, "dri": 0.0, "lat": 0.0, "vel": 0.3},
	{"id": "suola", "name": "Suola", "show": 0.4, "dri": 30.0, "lat": -0.7, "vel": 0.8},
	{"id": "doppiopasso", "name": "Doppio passo", "show": 0.45, "dri": 35.0, "lat": 0.15, "vel": 0.8},
	{"id": "croqueta", "name": "Croqueta", "show": 0.32, "dri": 40.0, "lat": 0.6, "vel": 0.8},
	{"id": "fintatiro", "name": "Finta di tiro", "show": 0.5, "dri": 40.0, "lat": 0.3, "vel": 0.5},
	{"id": "chop", "name": "Taglio secco", "show": 0.38, "dri": 45.0, "lat": 1.0, "vel": 1.0},
	{"id": "cruyff", "name": "Finta e giro", "show": 0.5, "dri": 50.0, "lat": 0.6, "vel": 0.6},
	{"id": "tacco", "name": "Colpo di tacco", "show": 0.42, "dri": 55.0, "lat": 0.5, "vel": 0.7},
	{"id": "bicicletta", "name": "Bicicletta", "show": 0.6, "dri": 55.0, "lat": 0.1, "vel": 0.8},
	{"id": "elastico", "name": "Elastico", "show": 0.42, "dri": 60.0, "lat": 0.8, "vel": 0.8},
	{"id": "tunnel", "name": "Tunnel", "show": 0.38, "dri": 60.0, "lat": 0.6, "vel": 0.8},
	{"id": "veronica", "name": "Veronica", "show": 0.36, "dri": 65.0, "lat": 0.0, "vel": 0.7},
	{"id": "elastico_inv", "name": "Elastico inverso", "show": 0.42, "dri": 70.0, "lat": 0.7, "vel": 0.8},
	{"id": "sombrero", "name": "Sombrero", "show": 0.42, "dri": 75.0, "lat": 0.0, "vel": 0.4},
	{"id": "arcobaleno", "name": "Arcobaleno", "show": 0.5, "dri": 80.0, "lat": 0.0, "vel": 0.4},
]
const PESO_BELLO := 2.0   # tra quelli che sa fare, il più difficile esce tante volte in più del più facile (1 + questo)
const FRONTE := 0.6       # tunnel, sombrero e arcobaleno solo col difensore davanti entro tanto di lato (m)
const DAVANTI := ["tunnel", "sombrero", "arcobaleno"]


static func trova(id: String) -> Dictionary:
	for s: Dictionary in LISTA:
		if s.id == id:
			return s
	return {}


## giochetto per un portatore con Dribbling `dri`; r in [0, 1); lato = quanto il difensore è spostato di lato rispetto
## alla corsa del portatore (m); forza = id fisso (prove). Più Dribbling = più scelta, e i più difficili più spesso.
static func scegli(dri: float, r: float, lato: float = 0.0, forza: String = "") -> Dictionary:
	if forza != "":
		var f := trova(forza)
		if not f.is_empty():
			return f
	var sa: Array = []
	for s: Dictionary in LISTA:
		if float(s.dri) <= dri and not (absf(lato) > FRONTE and String(s.id) in DAVANTI):
			sa.append(s)
	if sa.size() <= 1:
		return LISTA[0]
	var tot := 0.0
	var pesi: Array = []
	for i in sa.size():
		var w := 1.0 + PESO_BELLO * float(i) / float(sa.size() - 1)
		pesi.append(w)
		tot += w
	var x := clampf(r, 0.0, 0.999999) * tot
	for i in sa.size():
		x -= float(pesi[i])
		if x < 0.0:
			return sa[i]
	return sa.back()
