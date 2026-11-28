# Giochetti del dribbling della persona (Luis 2026-11-26: "fai skill vere e aggiungine"), solo con "rifiniture".
# Il motore sceglie QUALE giochetto fa il portatore quando il dribbling prenotato riesce, perché ognuno dura un tempo
# diverso prima dello scatto (`show`, s di partita); come si muovono gambe e pallone lo decide la grafica
# (scripts/partita/mosse/coreo_dribbling.gd, stesso `id`). L'esito è già deciso prima e non cambia.
# La scelta usa un generatore a parte (base.gd skillRng, stesso seme della partita): la sequenza di rnd() resta uguale.
extends RefCounted

# in ordine di difficoltà: `dri` = sotto-statistica Dribbling che serve per saperlo fare. Durante il giochetto il
# portatore NON si ferma (Luis 2026-11-26: "arriva in corsa e lo fa mantenendo lo slancio"): va a `vel` × DRIB_SHOW_V
# nella direzione `av` (avanti, verso il difensore, che indietreggia) + `lat` (di lato: positivo = verso la finta,
# negativo = dal lato scelto, col pallone).
# `palla` = il pallone si stacca dal portatore e lui lo va a riprendere (sim/duel.gd dribPallaLancia / dribChaseStep):
#   "terra" rasoterra tra le gambe del difensore, "alta" pallonetto sopra la sua testa; parte `tk` s dopo l'inizio.
#   alta: `su` = punto più alto (m), `oltre` = dove cade oltre il difensore (m), `da` = da dove parte rispetto al
#   portatore lungo la corsa (m, negativo = da dietro: il colpo di tacco) e `dh` = a che altezza (m).
# I 13 giochetti aggiunti il 2026-11-27 (suola_via, finta_rientro, doppiopasso_inv, suola_180, ponte, elastico3, giro_tocco,
# waka, colpetto_giro, cucchiaio_finta, abracadabra, veronica_classe, tornado) per ora hanno i numeri del giochetto da
# cui sono copiati (show, av, lat, vel, pallone staccato): chi li rifà li cambia insieme alla sua coreografia.
const LISTA := [
	{"id": "finta", "name": "Finta di corpo", "show": 0.4, "dri": 0.0, "av": 0.8, "lat": 0.8, "vel": 0.85},
	{"id": "stopgo", "name": "Stop e via", "show": 0.45, "dri": 0.0, "av": 1.0, "lat": 0.0, "vel": 0.2},
	{"id": "suola_via", "name": "Suola indietro e via", "show": 0.45, "dri": 22.0, "av": 0.7, "lat": -0.7, "vel": 0.75},
	{"id": "finta_rientro", "name": "Finta avanti e giro", "show": 0.4, "dri": 25.0, "av": 0.8, "lat": 0.8, "vel": 0.85},
	{"id": "suola", "name": "Suola", "show": 0.45, "dri": 30.0, "av": 0.7, "lat": -0.7, "vel": 0.75},
	{"id": "doppiopasso", "name": "Doppio passo", "show": 0.5, "dri": 35.0, "av": 1.0, "lat": 0.1, "vel": 0.7},
	{"id": "doppiopasso_inv", "name": "Doppio passo inverso", "show": 0.5, "dri": 35.0, "av": 1.0, "lat": 0.1, "vel": 0.7},
	{"id": "suola_180", "name": "Suola e giro", "show": 0.45, "dri": 38.0, "av": 0.7, "lat": -0.7, "vel": 0.75},
	{"id": "croqueta", "name": "Croqueta", "show": 0.55, "dri": 40.0, "av": 0.5, "lat": -1.0, "vel": 0.8},
	{"id": "fintatiro", "name": "Finta di tiro", "show": 0.5, "dri": 40.0, "av": 1.0, "lat": 0.2, "vel": 0.65},
	{"id": "chop", "name": "Taglio secco", "show": 0.48, "dri": 45.0, "av": 0.8, "lat": 0.8, "vel": 1.0},
	{"id": "ponte", "name": "Ponte", "show": 0.38, "dri": 45.0, "av": 0.8, "lat": -0.6, "vel": 0.85,
		"palla": "terra", "tk": 0.38, "oltre": 3.4},
	{"id": "elastico3", "name": "Triplo elastico", "show": 0.42, "dri": 48.0, "av": 0.7, "lat": 0.7, "vel": 0.8},
	{"id": "cruyff", "name": "Finta e giro", "show": 0.6, "dri": 50.0, "av": 0.3, "lat": 1.0, "vel": 0.55},
	{"id": "tacco", "name": "Colpo di tacco", "show": 0.42, "dri": 55.0, "av": 0.8, "lat": 0.0, "vel": 0.7},
	{"id": "pedalata", "name": "Pedalata", "show": 0.7, "dri": 55.0, "av": 1.0, "lat": 0.1, "vel": 1.0},
	{"id": "giro_tocco", "name": "Giro e tocco", "show": 0.7, "dri": 58.0, "av": 0.9, "lat": -0.45, "vel": 0.7},
	{"id": "elastico", "name": "Elastico", "show": 0.42, "dri": 60.0, "av": 0.7, "lat": 0.7, "vel": 0.8},
	{"id": "tunnel", "name": "Tunnel", "show": 0.38, "dri": 60.0, "av": 0.8, "lat": -0.6, "vel": 0.85,
		"palla": "terra", "tk": 0.38, "oltre": 3.4},
	{"id": "waka", "name": "Tacco e punta", "show": 0.42, "dri": 62.0, "av": 0.8, "lat": 0.0, "vel": 0.7},
	{"id": "veronica", "name": "Veronica", "show": 0.65, "dri": 65.0, "av": 1.0, "lat": -0.45, "vel": 1.0},
	{"id": "colpetto_giro", "name": "Colpetto e giro", "show": 0.6, "dri": 66.0, "av": 0.3, "lat": 1.0, "vel": 0.55},
	{"id": "cucchiaio_finta", "name": "Finta col cucchiaio", "show": 0.5, "dri": 68.0, "av": 1.0, "lat": 0.2, "vel": 0.65},
	{"id": "elastico_inv", "name": "Elastico inverso", "show": 0.42, "dri": 70.0, "av": 0.7, "lat": 0.6, "vel": 0.8},
	{"id": "abracadabra", "name": "Abracadabra", "show": 0.42, "dri": 72.0, "av": 0.7, "lat": 0.6, "vel": 0.8},
	{"id": "veronica_classe", "name": "Veronica di classe", "show": 0.5, "dri": 74.0, "av": 1.0, "lat": -0.55, "vel": 1.0},
	{"id": "sombrero", "name": "Sombrero", "show": 0.42, "dri": 75.0, "av": 1.0, "lat": -0.3, "vel": 0.55,
		"palla": "alta", "tk": 0.34, "su": 2.75, "oltre": 2.3, "da": 0.55, "dh": 0.05},
	{"id": "tornado", "name": "Tornado", "show": 0.48, "dri": 78.0, "av": 0.8, "lat": 0.8, "vel": 1.0},
	# (Luis 2026-11-26: per lui la "bicicletta" è questa: pallone portato su dietro il polpaccio e alzato col tacco
	# sopra la testa propria e del difensore; i giri alternati del piede intorno al pallone sono la "pedalata")
	{"id": "bicicletta", "name": "Bicicletta", "show": 0.58, "dri": 80.0, "av": 1.0, "lat": 0.0, "vel": 0.55,
		"palla": "alta", "tk": 0.52, "su": 2.9, "oltre": 2.3, "da": -0.3, "dh": 0.6},
]
const PESO_BELLO := 2.0   # tra quelli che sa fare, il più difficile esce tante volte in più del più facile (1 + questo)
const FRONTE := 0.6       # tunnel, sombrero e bicicletta solo col difensore davanti entro tanto di lato (m)
const DAVANTI := ["tunnel", "sombrero", "bicicletta", "ponte"]


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
