# Regia del dribbling della persona (Luis 2026-11-24: "quando scelgo di farli tieni il rallenty e falli vedere bene,
# anche ruotando di 45 gradi la telecamera"). Dal tocco del tasto Dribbling alla fine del giochetto il tempo resta in
# rallenty e la telecamera gira intorno al portatore dal lato del dribbling (telecamera_partita.gd → _drib_step);
# finito, il tempo torna normale piano piano. Conti puri: gira anche nei test senza schermo.
#
# Fasi (il motore non le conosce: guarda m.dribBooked e gli eventi 'dribble' / 'dribble_go'):
#   "corsa"     tasto toccato, il portatore va verso il difensore (sim/duel.gd → dribBookStep)
#   "giochetto" esito arrivato: giochetto (riuscito: il motore lo fa durare `show` s, poi lo scatto) o contrasto
#   "uscita"    il tempo torna normale (lentamente) e la telecamera torna dritta
extends RefCounted

const TS_CORSA := 0.4        # velocità del tempo mentre il portatore va verso il difensore
const TS_GIOCHETTO := 0.3    # ... durante il giochetto, lo scatto oltre il difensore o il contrasto
# riuscito: dopo lo scatto il rallenty resta ancora tanto (s di partita). Era 0,4 (1,3 s veri al 30%) e poi il tempo
# tornava normale piano: a schermo il portatore sembrava fermarsi dopo il dribbling (Luis 2026-11-25, "è migliorato
# ma sembra ancora che si fermi"); ora il sorpasso si vede appena e si riparte di corsa (USCITA_K_OK)
const DOPO_OK := 0.12
# ... ma nei giochetti in cui il bello arriva dopo lo scatto (il pallone tra le gambe o sopra la testa, il giro della
# veronica, il taglio dietro la gamba) il rallenty dura fino a lì (Luis 2026-11-26: "falli vedere")
const DOPO_SKILL := {"veronica": 0.4, "tunnel": 0.32, "sombrero": 0.34, "arcobaleno": 0.34, "chop": 0.2, "cruyff": 0.22,
	"tacco": 0.2, "croqueta": 0.2, "elastico": 0.18, "elastico_inv": 0.18}
const DOPO_KO := 0.8         # fallito: contrasto e caduta si guardano per tanto (s di partita)
const USCITA_K := 2.2        # 1/s: alla fine il tempo torna normale con questa dolcezza (TEMPO_K del gioco è 14)
const USCITA_K_OK := 7.0     # 1/s: ... dopo il dribbling riuscito invece in fretta (il portatore scatta via)
const USCITA_FINE := 0.97    # tempo tornato quasi normale: la regia ha finito ...
const USCITA_MAX := 1.0      # ... o comunque dopo tanto tempo di partita (se dopo c'è un altro rallenty, es. area di tiro)
const GIRO := deg_to_rad(45.0)  # la telecamera gira di tanto intorno al portatore, dal lato del dribbling
const BASE_MAX := deg_to_rad(35.0) # verso del difensore rispetto alla direzione d'attacco: contato al massimo così
# grafica dell'esito (vista.gd → trick / reazione), per tutti i dribbling (anche della CPU), in s di partita
const GIOCHETTO_CODA := 0.25 # col giochetto del motore (show) il movimento finisce tanto dopo lo scatto (accelerando)
const AFFONDO_T := 0.9       # riuscito: il difensore si butta dalla parte della finta e interviene a vuoto
const CONTRASTO_T := 0.6     # fallito: il difensore allunga la gamba sul pallone ...
const INCIAMPO_T := 0.5      # ... e il portatore, fermato, perde l'equilibrio

var fase := ""               # "", "corsa", "giochetto", "uscita"
var p: Object = null         # portatore
var o: Object = null         # difensore
var side := 0.0              # lato del dribbling (+1 = sinistra del portatore guardando il difensore)
var ok := true               # esito (vale dalla fase "giochetto")
var resta := 0.0             # s di partita che restano nella fase "giochetto"
var dopo := DOPO_OK          # riuscito: rallenty dopo lo scatto (s di partita; secondo il giochetto)
var yaw := 0.0               # angolo voluto della telecamera (spazio orientato di camfit.gd: 0 = verso la porta avversaria)


## a ogni fotogramma dopo i passi del motore (sdt = tempo di partita passato). ts = velocità del tempo attuale.
func passo(m: Object, me: int, sdt: float, ts: float) -> void:
	if m == null:
		azzera()
		return
	if m.dribBooked(me):
		if fase != "corsa" or p != m.duel.p:
			_inizia(m.duel.p, m.duel.o, m.duel.side, me)
		return
	match fase:
		"corsa": # prenotazione finita senza esito (palla persa, passaggio, difensore lontano): se l'esito è arrivato
			_esci() # adesso, evento() (chiamato dopo, con gli eventi del passo) la rimette a "giochetto"
		"giochetto":
			resta -= sdt
			if resta <= 0.0 or m.phase != "play":
				_esci()
		"uscita":
			resta -= sdt
			if ts >= USCITA_FINE or resta <= 0.0 or m.phase != "play":
				azzera()


## eventi del motore della squadra `me`: 'dribble_book' (tasto toccato: col difensore già vicino l'esito arriva nello
## stesso passo), 'dribble' (esito, con `show` = durata del giochetto prima dello scatto) e 'dribble_go' (scatto)
func evento(e: Dictionary, me: int) -> void:
	var pe: Object = e.get("p")
	if pe == null or pe.team != me:
		return
	match String(e.type):
		"dribble_book":
			if fase != "corsa" or pe != p:
				_inizia(pe, e.o, float(e.side), me)
		"dribble":
			# (in "uscita": la prenotazione è finita nello stesso passo in cui è arrivato l'esito)
			if pe == p and (fase == "corsa" or fase == "uscita"):
				fase = "giochetto"
				ok = bool(e.ok)
				dopo = float(DOPO_SKILL.get(String(e.get("skill", "")), DOPO_OK))
				# riuscito col giochetto del motore: il rallenty dura fino allo scatto (poi dribble_go: DOPO_OK);
				# fallito: il tempo di guardare il contrasto
				resta = (float(e.get("show", 0.0)) + dopo) if ok else DOPO_KO
		"dribble_go":
			if pe == p and fase == "giochetto":
				resta = dopo


## velocità del tempo voluta dalla regia, −1 = nessuna (decide il resto del gioco)
func velocita() -> float:
	match fase:
		"corsa":
			return TS_CORSA
		"giochetto":
			return TS_GIOCHETTO
	return -1.0


## dolcezza del passaggio da una velocità del tempo all'altra (1/s); tk = quella normale del gioco
func k_tempo(tk: float) -> float:
	if fase != "uscita":
		return tk
	return USCITA_K_OK if ok else USCITA_K


## regia in corso (anche mentre il tempo torna normale): il timer del rallenty non conta
func attiva() -> bool:
	return fase != ""


## per la telecamera: {p, o, yaw} mentre la visuale del dribbling è voluta, {} quando deve tornare dritta
func camera() -> Dictionary:
	if (fase == "corsa" or fase == "giochetto") and p != null and o != null:
		return {"p": p, "o": o, "yaw": yaw}
	return {}


func _esci() -> void:
	fase = "uscita"
	resta = USCITA_MAX


func azzera() -> void:
	fase = ""
	p = null
	o = null
	side = 0.0
	resta = 0.0


func _inizia(pp: Object, oo: Object, lato: float, me: int) -> void:
	fase = "corsa"
	p = pp
	o = oo
	side = lato
	ok = true
	resta = 0.0
	yaw = giro_camera(Vector2(p.x, p.y), Vector2(o.x, o.y), side, -1.0 if me == 1 else 1.0)


## angolo della telecamera (spazio orientato, dir = verso d'attacco nel motore): verso il difensore (al massimo
## BASE_MAX dalla direzione d'attacco) più GIRO dalla parte opposta al lato del dribbling. Lato +1 = sinistra del
## portatore: la telecamera si mette dietro a destra e guarda in diagonale verso sinistra (yaw −), cioè nel verso in
## cui il portatore scatterà: durante il giochetto i due si vedono uno accanto all'altro e nel sorpasso il portatore
## passa di fianco al difensore, staccato (Luis 2026-11-26: prima la telecamera stava dal lato del sorpasso e il
## portatore passava davanti al difensore coprendolo: a schermo sembravano uno dentro l'altro).
static func giro_camera(pp: Vector2, po: Vector2, lato: float, dir: float) -> float:
	var u := (po - pp) * dir
	var base := 0.0 if u.length() < 0.1 else clampf(atan2(u.x, u.y), -BASE_MAX, BASE_MAX)
	return base - GIRO * signf(lato) if lato != 0.0 else base


## Grafica dell'esito di un dribbling (evento 'dribble' {p, o, ok, side, show}): durata del giochetto a schermo (−1 =
## la sua, 0 = niente giochetto: fallito) e pose di reazione [[giocatore, tipo, lato, durata], ...] per vista.reazione.
## Riuscito: il difensore si butta verso la finta (lato opposto a `side`) e va a vuoto. Fallito: niente giochetto, il
## difensore allunga la gamba verso il pallone e il portatore inciampa.
static func esito(e: Dictionary) -> Dictionary:
	var pp: Object = e.p
	var oo: Object = e.o
	var show := float(e.get("show", 0.0))
	var dx: float = oo.x - pp.x
	var dy: float = oo.y - pp.y
	var d := maxf(0.1, sqrt(dx * dx + dy * dy))
	if bool(e.ok):
		# finta: alla destra del portatore se il lato scelto è la sua sinistra (+1), e viceversa (come sim/duel.gd)
		var lato := float(e.get("side", 0.0))
		var finta := Vector2(dy / d * lato, -dx / d * lato)
		return {"dur": show + GIOCHETTO_CODA if show > 0.0 else -1.0,
			"reazioni": [[oo, "affondo", lato_del_corpo(oo, finta), AFFONDO_T + show]]}
	var b := Vector2(-dx, -dy) / d # dal difensore verso il portatore (e il pallone)
	return {"dur": 0.0, "reazioni": [[oo, "contrasto", lato_del_corpo(oo, b, 0.35), CONTRASTO_T], [pp, "inciampo", 0.0, INCIAMPO_T]]}


## direzione `w` (motore) rispetto al corpo di q (che guarda verso q.fx, q.fy): +1 = alla sua sinistra, −1 = destra,
## 0 = davanti (componente di lato sotto `soglia`)
static func lato_del_corpo(q: Object, w: Vector2, soglia: float = 0.0) -> float:
	var sx := Vector2(-q.fy, q.fx) # sinistra di chi guarda verso (fx, fy)
	var k := w.normalized().dot(sx)
	if absf(k) <= soglia:
		return 0.0
	return signf(k)
