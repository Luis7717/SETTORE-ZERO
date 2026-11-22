# Momenti chiave (PIANO.md, Fase E punto 5): invece di tutta la partita si giocano circa 10 azioni; il resto lo
# simula un modello semplice basato sulla forza delle squadre e si legge come cronaca scritta tra un'azione e l'altra.
# Solo logica (niente nodi): si prova da sola in tests/test_momenti.gd. La regia (momenti_regia.gd) la collega
# alla partita vera (gioco.gd), la schermata tra le azioni è momenti_vista.gd.
#
# - piano_azioni(forza_mia, forza_loro, seme): 9-11 azioni col minuto e il tipo ("att" = attacco io, "dif" = mi
#   difendo). Più sono forte rispetto all'avversario, più azioni d'attacco (quota_attacco); mai meno di MIN_ATT
#   d'attacco né di MIN_DIF in difesa.
# - prepara_azione(m, azione, me): mette la partita a centrocampo (o poco oltre) col pallone alla squadra che attacca,
#   un paio di centrocampisti avversari già saltati alle spalle (contropiede: occasione vera), orologio al minuto giusto.
# - leggi(m, sdt) dopo i passi del motore: l'azione finisce con gol, parata, palla fuori, palla persa / recuperata,
#   fallo, fuorigioco (non il rigore: quello si gioca) o dopo DURATA_MAX s di gioco.
# - simula_fino_a(...): il resto della partita, minuto per minuto, ognuno col suo seme (stesso seme della partita =
#   stessi gol simulati, comunque vadano le azioni giocate). I gol vanno nel punteggio e nei marcatori del motore,
#   tiri, angoli, falli, parate e possesso nelle sue statistiche (la schermata di fine e i voti restano coerenti).
#
# Il caso è un SimRng proprio (mai quello del motore, mai randf): tutto ripetibile col seme.
extends RefCounted

const C := preload("res://sim/core.gd")
const R := preload("res://sim/records.gd")
const SimRng := preload("res://sim/rng.gd")

const HALF_LEN := 900.0       # s di gioco per tempo in questa modalità: 20 s = 1 minuto (l'orologio corre piano nelle azioni)
const AZIONI := 10            # azioni per partita, ±1 col seme ("circa 10 in totale", Luis)
const MIN_ATT := 3            # azioni d'attacco minime, anche con la squadra più scarsa
const MIN_DIF := 2            # azioni in difesa minime, anche con la squadra più forte
const DIFF_PIENA := 40.0      # differenza di forza che sposta la quota d'attacco di 0,5 (prima dei limiti)
const QUOTA_MIN := 0.25
const QUOTA_MAX := 0.8
const PRIMO_MIN := 4          # minuti in cui possono cadere le azioni (lontano da intervallo e fischio finale)
const ULTIMO_1T := 40
const PRIMO_2T := 49
const ULTIMO_MIN := 86
const DURATA_MAX := 30.0      # s di gioco: poi l'azione "sfuma"
const ATTESA := {"parata": 1.2, "fuori": 0.6, "angolo": 0.6, "persa": 0.8, "recuperata": 0.8, "fallo": 0.8, "fuorigioco": 0.8, "tempo": 0.0}
# partenza: [y del pallone nel verso d'attacco, centrocampisti avversari già saltati in attacco, ... in difesa]
const VARIANTI := {"contropiede": [5.0, 3, 2], "manovra": [11.0, 2, 1]}
# resto della partita simulato: per 90 minuti di una squadra con quota d'attacco 0,5 → 5 tiri
const TIRI_90 := 10.0
const IN_PORTA := 0.4         # tiri nello specchio
const SEGNA := 0.3            # ... di questi, gol
const PALO := 0.06
const ANGOLI_90 := 8.0
const FALLI_90 := 7.0
const GIALLO := 0.15
const SEC_MINUTO := HALF_LEN / 45.0   # possesso: secondi di gioco del motore per minuto simulato
const PESO_RUOLO := {"A": 5.0, "C": 2.0, "D": 0.6, "P": 0.0}

var me := 0
var seme := 1
var forze: Array = [60.0, 60.0]
var piano: Array = []         # [{minuto, tipo, variante}]
var indice := -1              # azione in corso (o l'ultima giocata)
var stato := "intervallo"     # "intervallo" (tra le azioni), "azione" o "fine" (dopo il 90')
var minuto_sim := 0           # ultimo minuto già raccontato (simulato o giocato)
var esito := ""               # come è finita l'azione in corso ("" = non ancora)
var esiti: Array = []         # esito di ogni azione giocata
var durata := 0.0             # s di gioco dall'inizio dell'azione
var squadra_palla := 0        # chi attaccava all'inizio dell'azione
var _attesa := 0.0            # s di gioco tra l'esito e la fine vera (si vede la parata, il pallone che esce...)
var _rigore := false


func _init(m: Variant, me_: int, seme_: int) -> void:
	me = me_
	seme = seme_
	forze = [forza_squadra(m.teams[0]), forza_squadra(m.teams[1])]
	piano = piano_azioni(forze[me], forze[1 - me], seme)


# ---------------------------------------------------------------- piano delle azioni
## forza di una squadra (come la usa questa modalità): media delle statistiche dei titolari, il portiere col suo `por`
static func forza_squadra(t: Dictionary) -> float:
	var tot := 0.0
	var n := 0
	for p: Dictionary in t.get("players", []):
		if n >= 11:
			break
		if String(p.get("pos", "")) == "P":
			tot += float(p.get("por", 50))
		else:
			var s := 0.0
			for k: String in ["vel", "tir", "pas", "dri", "dif", "fis"]:
				s += float(p.get(k, 50))
			tot += s / 6.0
		n += 1
	return tot / n if n > 0 else 50.0


## quota di azioni d'attacco (e di occasioni nel resto simulato) per chi ha forza `a` contro `b`
static func quota_attacco(a: float, b: float) -> float:
	return clampf(0.5 + (a - b) / DIFF_PIENA, QUOTA_MIN, QUOTA_MAX)


## [{minuto, tipo: "att"|"dif", variante}] in ordine di minuto; metà circa nel primo tempo
static func piano_azioni(forza_mia: float, forza_loro: float, seme_: int) -> Array:
	var r := SimRng.new(_seme(seme_, 101))
	var n := AZIONI - 1 + int(floor(r.next() * 3.0))
	var n_att := clampi(roundi(n * quota_attacco(forza_mia, forza_loro)), MIN_ATT, n - MIN_DIF)
	var tipi: Array = []
	for i in n:
		tipi.append("att" if i < n_att else "dif")
	for i in range(n - 1, 0, -1): # mescolati col seme (Fisher-Yates)
		var j := int(floor(r.next() * (i + 1)))
		var x: Variant = tipi[i]
		tipi[i] = tipi[j]
		tipi[j] = x
	var n1 := (n + 1) / 2
	var minuti := _minuti(r, n1, PRIMO_MIN, ULTIMO_1T) + _minuti(r, n - n1, PRIMO_2T, ULTIMO_MIN)
	var out: Array = []
	for i in n:
		out.append({"minuto": minuti[i], "tipo": tipi[i], "variante": "contropiede" if r.next() < 0.5 else "manovra"})
	return out


# k minuti distribuiti tra da e a (compresi), con un po' di caso, crescenti e ad almeno 3 minuti l'uno dall'altro
static func _minuti(r: SimRng, k: int, da: int, a: int) -> Array:
	var out: Array = []
	var passo := float(a - da) / maxf(1.0, k)
	for i in k:
		var mn := roundi(da + passo * (i + 0.5) + (r.next() - 0.5) * passo * 0.5)
		if not out.is_empty():
			mn = maxi(mn, int(out[-1]) + 3)
		out.append(clampi(mn, da, a))
	return out


static func _seme(s: int, k: int) -> int:
	var v := (s * 1000003 + k * 7919 + 12345) & 0x7fffffff
	return v if v != 0 else 1


## azione successiva (vuoto = finite)
func prossima() -> Dictionary:
	return piano[indice + 1] if indice + 1 < piano.size() else {}


# ---------------------------------------------------------------- partenza dell'azione
## mette la partita all'inizio dell'azione: orologio al minuto, squadre schierate, pallone a chi attacca
static func prepara_azione(m: Variant, az: Dictionary, me_: int) -> void:
	var tb: int = me_ if az.tipo == "att" else 1 - me_
	var d := 1.0 if tb == 0 else -1.0
	var mn := int(az.minuto)
	m.half = 1 if mn <= 45 else 2
	m.t = (float(mn - 1) - (m.half - 1) * 45.0 + 0.05) / 45.0 * m.halfLen
	m.setupKickoff(tb) # formazione, stati azzerati, niente strade, duelli, vantaggi
	m.events.clear()   # niente fischio né "calcio d'inizio": si parte in gioco
	m.phase = "play"
	m.restart = null
	var v: Array = VARIANTI.get(az.get("variante", "manovra"), VARIANTI.manovra)
	var y0: float = v[0]
	var battuti: int = v[1] if az.tipo == "att" else v[2]
	var r := SimRng.new(_seme(int(m.time * 1000.0) + mn, 7 + tb))
	var mie: Array = m.team(tb).filter(func(p: R.Player) -> bool: return not p.off and p.pos != "P")
	var loro: Array = m.team(1 - tb).filter(func(p: R.Player) -> bool: return not p.off and p.pos != "P")
	# chi porta palla: il centrocampista più centrale (o chiunque, se non ce ne sono)
	var port: R.Player = null
	for p: R.Player in mie:
		if port == null or (p.pos == "C" and port.pos != "C") or (
				(p.pos == "C") == (port.pos == "C") and absf(p.bx) < absf(port.bx)):
			port = p
	if port == null:
		return
	for p: R.Player in mie:
		var y := y0 + 12.0 + r.next() * 5.0           # attaccanti davanti al pallone
		if p.pos == "C":
			y = y0 + (3.0 + r.next() * 4.0 if absf(p.bx) > 0.6 else -3.0 - r.next() * 3.0)
		elif p.pos == "D":
			y = y0 - 22.0 + r.next() * 4.0
		m.place(p, p.bx * C.HW * 0.85, d * y)
	m.place(port, (r.next() - 0.5) * 10.0, d * y0)
	# avversari: i centrocampisti più centrali già saltati (dietro il pallone), gli altri tra palla e porta
	var centrali: Array = loro.filter(func(p: R.Player) -> bool: return p.pos == "C")
	centrali.sort_custom(func(a: R.Player, b: R.Player) -> bool: return absf(a.bx) < absf(b.bx))
	for p: R.Player in loro:
		var y := 0.0
		if p.pos == "D":
			y = y0 + (28.0 if az.get("variante", "") == "contropiede" else 25.0) + r.next() * 3.0
		elif p.pos == "A":
			y = y0 - 9.0 - r.next() * 4.0
		elif centrali.find(p) >= 0 and centrali.find(p) < battuti:
			y = y0 - 7.0 - r.next() * 3.0
		else:
			y = y0 + 9.0 + r.next() * 4.0
		m.place(p, p.bx * C.HW * 0.8, d * y)
	for p: R.Player in m.players:
		if not p.off:
			m.faceTo(p, port.x, port.y)
	port.fx = 0.0
	port.fy = d
	var b: R.Ball = m.ball
	b.owner = port
	b.last = port
	b.prev = null
	b.dbl = null
	b.dblT = 0.0
	b.x = port.x
	b.y = port.y + d * 0.6
	m.att = tb
	m.lastPass = null
	m.updateCtrl(0.0, true)


## parte l'azione successiva del piano
func avvia_prossima(m: Variant) -> void:
	indice += 1
	var az: Dictionary = piano[indice]
	squadra_palla = me if az.tipo == "att" else 1 - me
	prepara_azione(m, az, me)
	stato = "azione"
	esito = ""
	durata = 0.0
	_attesa = 0.0
	_rigore = false


# ---------------------------------------------------------------- fine dell'azione
## dopo i passi del motore, prima che gli eventi vengano consumati
func leggi(m: Variant, sdt: float) -> void:
	if stato != "azione":
		return
	durata += sdt
	var vantaggio := false
	for e: Dictionary in m.events:
		if e.type == "advantage":
			vantaggio = true
	for e: Dictionary in m.events:
		match e.type:
			"half", "full": # non dovrebbe succedere (orologio lento), ma se succede l'azione è finita
				_esito("tempo")
				if e.type == "full":
					stato = "fine"
			"goal":
				esito = "gol" if int(e.team) == me else "subito" # vale anche se c'era già un altro esito
			"save":
				_esito("parata")
			"offside":
				_esito("fuorigioco")
			"out":
				_esito("angolo" if e.get("kind", "") == "corner" else "fuori")
			"foul":
				if e.get("pen", false):
					_rigore = true # il rigore si gioca: l'azione continua fino al tiro
					durata = 0.0
				elif not vantaggio:
					_esito("fallo")
	var o: Variant = m.ball.owner
	if esito == "" and o != null and m.phase == "play" and (o as R.Player).team != squadra_palla:
		_esito("persa" if squadra_palla == me else "recuperata")
	if esito == "" and durata >= DURATA_MAX and m.ball.shot == null:
		_esito("tempo")
	if esito != "" and _attesa > 0.0:
		_attesa -= sdt


func _esito(e: String) -> void:
	if esito != "":
		return
	esito = e
	_attesa = ATTESA.get(e, 0.5)


## l'azione è finita? (gol: quando la festa e il replay sono finiti e il motore ha rimesso il pallone al centro)
func azione_finita(m: Variant) -> bool:
	if stato != "azione" or esito == "":
		return false
	if esito == "gol" or esito == "subito":
		return m.phase != "goal"
	return _attesa <= 0.0


## chiude l'azione in corso: l'orologio della cronaca riparte da dove è arrivata
func chiudi_azione(m: Variant) -> void:
	esiti.append(esito)
	minuto_sim = maxi(minuto_sim, mini(90, int(m.minute()) + 1))
	stato = "intervallo"


## titolo dell'esito, per la schermata tra le azioni
static func testo_esito(e: String, attacco: bool) -> String:
	match e:
		"gol": return "GOL!"
		"subito": return "Gol subito"
		"parata": return "Tiro parato" if attacco else "Parata!"
		"fuori": return "Palla fuori" if attacco else "Palla allontanata"
		"angolo": return "Calcio d'angolo" if attacco else "Palla in angolo"
		"persa": return "Palla persa"
		"recuperata": return "Palla recuperata!"
		"fallo": return "Fallo, gioco fermo"
		"fuorigioco": return "Fuorigioco"
		"tempo": return "L'azione sfuma" if attacco else "Pericolo passato"
	return ""


# ---------------------------------------------------------------- resto della partita (simulato)
## eventi simulati di un minuto (1..90): [{minuto, team, tipo: gol|parata|fuori|palo|angolo|fallo|giallo}].
## Dipende solo da seme, minuto e forze: ripetibile, e uguale comunque siano andate le azioni giocate.
static func simula_minuto(seme_: int, minuto: int, forze_: Array) -> Array:
	var r := SimRng.new(_seme(seme_, 1000 + minuto))
	var out: Array = []
	for t in 2:
		var q := quota_attacco(float(forze_[t]), float(forze_[1 - t]))
		if r.next() < TIRI_90 * q / 90.0:
			var x := r.next()
			var tipo := "fuori"
			if x < IN_PORTA:
				tipo = "gol" if r.next() < SEGNA else "parata"
			elif x < IN_PORTA + PALO:
				tipo = "palo"
			out.append({"minuto": minuto, "team": t, "tipo": tipo})
		if r.next() < ANGOLI_90 * q / 90.0:
			out.append({"minuto": minuto, "team": t, "tipo": "angolo"})
		if r.next() < FALLI_90 / 90.0:
			out.append({"minuto": minuto, "team": t, "tipo": "giallo" if r.next() < GIALLO else "fallo"})
	return out


## simula i minuti da minuto_sim + 1 fino a `fino` (compreso), applica gol e statistiche alla partita e ai conteggi
## (conta: conta_giocatori.gd, facoltativo) e ritorna le righe di cronaca [{minuto, testo, forte}]
func simula_fino_a(m: Variant, fino: int, conta: Variant = null) -> Array:
	var righe: Array = []
	var share := clampf(0.5 + (float(forze[0]) - float(forze[1])) / 60.0, 0.3, 0.7)
	var nomi := [str(m.teams[0].get("name", m.teams[0].get("short", "Casa"))), str(m.teams[1].get("name", m.teams[1].get("short", "Ospiti")))]
	for mn in range(minuto_sim + 1, fino + 1):
		if mn == 46 and minuto_sim < 45:
			righe.append({"minuto": 45, "testo": "Intervallo: %d – %d." % [m.score[0], m.score[1]], "forte": false})
		m.stats.poss[0] += SEC_MINUTO * share
		m.stats.poss[1] += SEC_MINUTO * (1.0 - share)
		var r := SimRng.new(_seme(seme, 5000 + mn))
		for e: Dictionary in simula_minuto(seme, mn, forze):
			var riga := _applica(m, e, r, nomi, conta)
			if riga != "":
				righe.append({"minuto": mn, "testo": riga, "forte": e.tipo == "gol"})
		minuto_sim = mn
	minuto_sim = maxi(minuto_sim, fino)
	return righe


# un evento simulato nel motore (punteggio, marcatori, statistiche) e nei conteggi; ritorna la frase ("" = niente)
func _applica(m: Variant, e: Dictionary, r: SimRng, nomi: Array, conta: Variant) -> String:
	var t: int = e.team
	var st: Dictionary = m.stats
	var tipo: String = e.tipo
	if tipo == "angolo":
		st.corners[t] += 1
		return ("Calcio d'angolo per %s." % nomi[t]) if r.next() < 0.35 else ""
	if tipo == "fallo" or tipo == "giallo":
		st.fouls[t] += 1
		if tipo == "fallo":
			return ""
		var amm := _scegli(m, t, r, {"A": 1.0, "C": 2.0, "D": 3.0, "P": 0.0})
		return ("Ammonito %s." % amm.name) if amm != null else ""
	var tir := _scegli(m, t, r, PESO_RUOLO)
	if tir == null:
		return ""
	var gk: R.Player = m.gk(1 - t)
	st.shots[t] += 1
	var d := 1.0 if t == 0 else -1.0
	var sim := {"tipo": tipo, "team": t, "p": tir, "gk": gk, "x": snappedf((r.next() - 0.5) * 24.0, 0.1),
		"y": snappedf(d * (C.HL - 7.0 - r.next() * 15.0), 0.1)}
	match tipo:
		"gol":
			st.onT[t] += 1
			var ass: R.Player = null
			if r.next() < 0.6:
				ass = _scegli(m, t, r, {"A": 2.0, "C": 3.0, "D": 1.0, "P": 0.0}, tir)
			sim["assist"] = ass
			m.score[t] += 1
			m.goalsLog.append({"team": t, "name": tir.name, "minute": e.minuto, "scorer": tir.src,
				"assist": ass.src if ass != null else null})
			if conta != null:
				conta.aggiungi_simulato(sim)
			if ass != null:
				return "GOL di %s (assist di %s)! %d – %d" % [tir.name, ass.name, m.score[0], m.score[1]]
			return "GOL di %s! %d – %d" % [tir.name, m.score[0], m.score[1]]
		"parata":
			st.onT[t] += 1
			st.saves[1 - t] += 1
			if conta != null:
				conta.aggiungi_simulato(sim)
			return ["Tiro di %s, para %s.", "%s ci prova, %s blocca.", "Conclusione di %s: %s c'è."][int(r.next() * 3.0)] % [tir.name, gk.name]
		"palo":
			if conta != null:
				conta.aggiungi_simulato(sim)
			return "Palo di %s!" % tir.name
	if conta != null:
		conta.aggiungi_simulato(sim)
	return ["Tiro di %s: fuori.", "%s calcia alto.", "%s ci prova da fuori: a lato."][int(r.next() * 3.0)] % tir.name


# un giocatore della squadra t (in campo), a caso col peso del ruolo; `tranne` escluso
static func _scegli(m: Variant, t: int, r: SimRng, pesi: Dictionary, tranne: R.Player = null) -> R.Player:
	var lista: Array = m.team(t).filter(func(p: R.Player) -> bool: return not p.off and p != tranne and float(pesi.get(p.pos, 0.0)) > 0.0)
	var tot := 0.0
	for p: R.Player in lista:
		tot += float(pesi.get(p.pos, 0.0))
	var x := r.next() * tot
	for p: R.Player in lista:
		x -= float(pesi.get(p.pos, 0.0))
		if x <= 0.0:
			return p
	return lista[-1] if not lista.is_empty() else null


## minuto a cui simulare prima della prossima azione (spostata più in là se l'azione giocata è durata tanto);
## 90 se le azioni sono finite
func fino_alla_prossima() -> int:
	var pr := prossima()
	if pr.is_empty():
		return 90
	var mn := int(pr.minuto)
	if mn <= minuto_sim + 1:
		mn = minuto_sim + 2
		if mn <= 45 and mn > ULTIMO_1T + 1: # troppo vicino all'intervallo: si gioca a inizio ripresa
			mn = PRIMO_2T
		mn = mini(mn, 89)
		pr.minuto = mn
	return mn - 1


## dopo l'ultima azione e il resto simulato: fischio finale (il motore manda l'evento "full", gioco.gd fa il resto)
func fischio_finale(m: Variant) -> void:
	stato = "fine"
	m.half = 2
	m.t = m.halfLen
	m.endHalf()
