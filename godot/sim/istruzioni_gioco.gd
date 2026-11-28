# Istruzioni ai giocatori nel motore (Luis 2026-11-28; dati e nomi in istruzioni.gd). Ogni giocatore resta nel suo
# posto della formazione: l'istruzione sposta solo quanto sale o scende, quanto si allarga, cosa fa senza palla e come
# porta il pallone. Legge p.src.istr ({chiave: scelta}) col ruolo del posto (p.ruolo; senza, il ruolo predefinito del
# gruppo). Senza `istr` o con le scelte di mezzo (Equilibrato) niente cambia: tutti i metodi chiamano super() e tornano.
#  - terzini: spinta (Resta bloccato = indietro e più dentro; Si sovrappone = sale tanto e, col pallone sulla sua fascia
#    nella metà avversaria, fino al fondo); corsia (Sempre in fascia = attaccato alla linea quando attacchiamo; Si
#    accentra = in attacco entra in mezzo al campo, all'altezza dei centrocampisti);
#  - esterni (fascia): Attaccato alla linea = sulla linea laterale; Torna sempre = in difesa molto più basso e più
#    vicino al terzino;
#  - mediano: Si abbassa tra i centrali = in attacco scende tra i due centrali (x quasi 0, mai oltre ABBASSA_Y);
#    Accompagna l'azione = più alto; marcatura come i centrali;
#  - centrocampista (compito): Resta in copertura = più basso in attacco e in difesa; Box to box = più alto in attacco,
#    più basso in difesa e attacca l'area (istrRunBias);
#  - trequartista: compito (Aiuta il centrocampo / Seconda punta) e area (Tra le linee = mai in area; Si inserisce);
#  - ali: ala (Resta larga / Taglia dentro, anche la guida automatica); cross (col pallone sull'altra fascia nell'ultimo
#    terzo: Aspetta fuori area = al limite; Attacca il secondo palo = in area sul palo lontano e prima nella corsa in area);
#  - attaccante: movimento (Falso nove = viene incontro fino a FALSO_DIETRO sotto la linea, niente tagli; Attacca la
#    profondità = tagli più spessi e sulla linea col pallone oltre PROF_DA); riferimento (Fa la boa = BOA_DIETRO sotto la
#    linea, verso il pallone; Sul filo del fuorigioco = sempre sulla linea, anche col pallone lontano, tagli un po' più
#    spessi); pressione come le ali (Resta su / Pressa i difensori);
#  - centrali e mediano (marcatura): Copre lo spazio = più basso; Marcatura stretta = addosso all'avversario vicino,
#    davanti a lui verso il pallone;
#  - con la palla (tutti tranne il portiere; centrali: imposta): Gioca semplice = la CPU passa prima e la guida automatica
#    rallenta e protegge; Porta palla = la CPU passa meno se non è pressata e la guida va più veloce e non aspetta i
#    compagni; Imposta palla al piede = come Porta palla ma solo nella propria metà;
#  - portiere (uscite): Esce spesso = più fuori dai pali e prende più cross; Resta tra i pali = il contrario.
extends "attacco.gd"

const Istr := preload("istruzioni.gd")
const RuoliI := preload("ruoli.gd")

const SPINTA_SU := 0.08        # Si sovrappone: più alto (frazione del campo) ...
const SPINTA_FONDO := 0.08     # ... e ancora di più col pallone sulla sua fascia oltre SPINTA_FONDO_DA
const SPINTA_FONDO_DA := 0.5
const SPINTA_GIU := -0.12      # Resta bloccato: più basso ...
const SPINTA_DENTRO := 0.75    # ... e più dentro (frazione della sua x)
const ACCENTRA_X := 0.3        # Si accentra: x in attacco (frazione della sua x) ...
const ACCENTRA_SU := 0.05      # ... e un po' più alto, all'altezza del centrocampo
const FASCIA_SU := 0.03        # Attaccato alla linea: un po' più alto
const TORNA_GIU := -0.04       # Torna sempre: più basso in attacco ...
const TORNA_DIF := -0.1        # ... e molto più basso in difesa ...
const TORNA_DENTRO := 0.85     # ... un po' più dentro, vicino al terzino (frazione della sua x)
const ABBASSA_Y := 0.2         # Si abbassa tra i centrali: in attacco al massimo qui (frazione del campo dalla sua porta) ...
const ABBASSA_X := 0.15        # ... e quasi al centro (frazione della sua x)
const MEDIANO_SU := 0.09       # Accompagna l'azione: più alto in attacco ...
const MEDIANO_DIF := 0.03      # ... e un po' in difesa
const MEZZALA_ATT := 0.07      # centrocampista: su o giù in attacco ...
const MEZZALA_DIF := 0.04      # ... e in difesa (Box to box: giù anche lui)
const BOX_AREA := 8.0          # Box to box: nella scelta di chi attacca l'area conta come più vicino di tanto (m)
const TREQ_SU := 0.1           # Seconda punta: più alto in attacco
const ALA_DENTRO := 0.55       # Taglia dentro: x in attacco (frazione della metà larghezza)
const ALA_GUIDA_DENTRO := 0.2  # ... e la guida automatica punta a questa frazione della sua x
const CROSS_LATO := 8.0        # sui cross: pallone oltre tanti metri sull'altra fascia ...
const CROSS_DA := 0.68         # ... e oltre questa frazione del campo
const CROSS_FUORI := 4.0       # Aspetta fuori area: tanti metri fuori dall'area
const PALO_X := 1.5            # Attacca il secondo palo: tanto oltre il palo lontano ...
const PALO_FONDO := 6.0        # ... a tanti metri dalla linea di fondo
const FALSO_GIU := -0.1        # Falso nove: più basso ...
const FALSO_DIETRO := 16.0     # ... almeno tanti metri sotto la linea del fuorigioco ...
const FALSO_INCONTRO := 0.45   # ... verso il pallone di questa frazione
const BOA_GIU := -0.03         # Fa la boa: un po' più bassa ...
const BOA_DIETRO := 7.0        # ... almeno tanti metri sotto la linea del fuorigioco
const BOA_INCONTRO := 0.3      # ... spostata verso il pallone di questa frazione
const PROF_TAGLI := 2.5        # Attacca la profondità: tagli oltre la linea così più spesso (CPU)
const PROF_DA := -30.0         # ... e sulla linea del fuorigioco già col pallone da qui (m nel verso d'attacco)
const FILO_TAGLI := 1.5        # Sul filo del fuorigioco: tagli un po' più spessi ...
const FILO_GAP := 0.4          # ... e sempre a tanto dalla linea
const RESTA_SU := 0.1          # Resta su: in difesa più alto
const PRESSA_DA := 8.0         # Pressa i difensori: pallone dei loro da qui in avanti (m nel nostro verso d'attacco) ...
const PRESSA_R := 25.0         # ... e portatore entro tanto ...
const PRESSA_GAP := 2.0        # ... ci si mette davanti a tanto (m)
const COPRE_GIU := -0.03       # Copre lo spazio: più basso
const STRETTA_R := 10.0        # Marcatura stretta: avversario entro tanto dal suo posto (m) ...
const STRETTA_DAVANTI := 1.0   # ... davanti a lui, verso il pallone (m)
const TRA_LINEE := 10.0        # Tra le linee: almeno tanti metri sotto la linea del fuorigioco
const INSERIMENTO := 14.0      # Si inserisce: nella scelta di chi attacca l'area conta come più vicino di tanto (m)
const SEMPLICE_WANT := 0.7     # Gioca semplice: con un passaggio sicuro la CPU passa almeno con questa probabilità
const PORTA_WANT := 0.45       # Porta palla: senza pressione la voglia di passare della CPU ×
const IMPOSTA_WANT := 0.3      # Imposta palla al piede: nella propria metà senza pressione ×
const SEMPLICE_SPD := 0.55     # Gioca semplice: andatura della guida automatica al massimo questa
const PORTA_SPD := 1.0         # Porta palla: andatura della guida automatica almeno questa (se non pressato)
const USCITE_FUORI := [0.7, 1.4] # portiere pali / esce: distanza dalla porta ×
const USCITE_PRESA := 0.08     # ... e presa dei cross (probabilità in meno / in più)

# ruolo predefinito per gruppo (chi non ha il ruolo del posto)
const PREDEF := RuoliI.PREDEFINITO


# ------------------------------------------------------------ lettura delle istruzioni
func _ruolo(p: R.Player) -> String:
	return p.ruolo if p.ruolo != "" else String(PREDEF.get(p.pos, ""))


## -1 / 0 / +1 della chiave per il giocatore (0 se non ha istruzioni o la chiave non è del suo ruolo)
func _iv(p: R.Player, chiave: String) -> int:
	var d: Variant = p.src.get("istr")
	if not d is Dictionary or (d as Dictionary).is_empty() or not (d as Dictionary).has(chiave):
		return 0
	if not Istr.del_ruolo(_ruolo(p)).has(chiave):
		return 0
	return Istr.verso(d, chiave)


func _ha(p: R.Player) -> bool:
	var d: Variant = p.src.get("istr")
	return d is Dictionary and not (d as Dictionary).is_empty()


## pallone sull'altra fascia nell'ultimo terzo (per le istruzioni sui cross dell'ala dal lato sgn)
func _crossAltroLato(sgn: float, bf: float) -> bool:
	return ball.x * sgn < -CROSS_LATO and bf > CROSS_DA


# ------------------------------------------------------------ posti in campo
func anchor(p: R.Player) -> PackedFloat64Array:
	var r := super(p)
	if not _ha(p):
		return r
	var tm := p.team
	var dir: float = -1.0 if tm else 1.0
	var ayf: float = r[1] / (L * dir) + 0.5
	var ay0 := ayf
	var noi: bool = att == tm
	var sgn: float = C.sign_(p.bx) if p.bx != 0.0 else 1.0
	var bf: float = C.clamp_((ball.y * dir + HL) / L, 0.0, 1.0)
	match _ruolo(p):
		"TD", "TS":
			var v := _iv(p, "spinta")
			if noi and v > 0:
				ayf += SPINTA_SU + (SPINTA_FONDO if ball.x * sgn > 2.0 and bf > SPINTA_FONDO_DA else 0.0)
			elif noi and v < 0:
				ayf += SPINTA_GIU
				r[0] *= SPINTA_DENTRO
			var c := _iv(p, "corsia")
			if noi and c < 0:
				r[0] = sgn * (HW - WIDE_GAP)
			elif noi and c > 0:
				r[0] *= ACCENTRA_X
				ayf += ACCENTRA_SU
		"ED", "ES":
			var v := _iv(p, "fascia")
			if noi and v < 0:
				r[0] = sgn * (HW - WIDE_GAP)
				ayf += FASCIA_SU
			elif v > 0:
				ayf += TORNA_GIU if noi else TORNA_DIF
				if not noi:
					r[0] *= TORNA_DENTRO
		"CDC":
			var v := _iv(p, "mediano")
			if noi and v < 0:
				ayf = minf(ayf, ABBASSA_Y)
				r[0] *= ABBASSA_X
			elif noi and v > 0:
				ayf += MEDIANO_SU
			elif v > 0:
				ayf += MEDIANO_DIF
			if _iv(p, "marcatura") < 0:
				ayf += COPRE_GIU
		"CC":
			var v := _iv(p, "mezzala")
			if v < 0:
				ayf -= MEZZALA_ATT if noi else MEZZALA_DIF
			elif v > 0:
				ayf += MEZZALA_ATT if noi else -MEZZALA_DIF
		"COC":
			var v := _iv(p, "trequarti")
			if v < 0:
				ayf -= MEZZALA_ATT if noi else MEZZALA_DIF
			elif v > 0 and noi:
				ayf += TREQ_SU
		"AD", "AS":
			var v := _iv(p, "ala")
			if noi and v < 0:
				r[0] = sgn * (HW - WIDE_GAP)
			elif noi and v > 0:
				r[0] = sgn * HW * ALA_DENTRO
			var cr := _iv(p, "cross")
			if noi and cr != 0 and _crossAltroLato(sgn, bf):
				if cr < 0: # al limite dell'area
					ayf = minf(ayf, (HL - BOX_D - CROSS_FUORI + HL) / L)
				else: # sul palo lontano (il suo lato)
					r[0] = sgn * (GW / 2.0 + PALO_X)
					ayf = (HL - PALO_FONDO + HL) / L
			if not noi and _iv(p, "pressione") < 0:
				ayf += RESTA_SU
		"ATT":
			if noi and _iv(p, "movimento") < 0:
				ayf += FALSO_GIU
			if noi and _iv(p, "riferimento") < 0:
				ayf += BOA_GIU
			if not noi and _iv(p, "pressione") < 0:
				ayf += RESTA_SU
		"DC":
			if _iv(p, "marcatura") < 0:
				ayf += COPRE_GIU
	if ayf != ay0:
		r[1] = (C.clamp_(ayf, 0.04, 0.96) - 0.5) * L * dir
	return r


# ------------------------------------------------------------ senza palla, col pallone nostro
func support(p: R.Player) -> void:
	super(p)
	if not _ha(p) or phase != "play":
		return
	var b := ball
	var tm := p.team
	var c := b.owner
	if c == null or c.team != tm or helpers[tm].has(p) or boxRun[tm].has(p):
		return
	var dir: float = -1.0 if tm else 1.0
	var line: float = maxf(offLine[tm], b.y * dir)
	match _ruolo(p):
		"ATT":
			var v := _iv(p, "movimento")
			if v < 0: # falso nove: incontro, ben sotto la linea
				_sottoLinea(p, line - FALSO_DIETRO, FALSO_INCONTRO)
			elif v > 0 and b.y * dir > PROF_DA: # profondità: sulla linea del fuorigioco
				_sullaLinea(p, 0.8)
			var rf := _iv(p, "riferimento")
			if rf < 0 and v >= 0: # boa: davanti ai difensori, verso il pallone
				_sottoLinea(p, line - BOA_DIETRO, BOA_INCONTRO)
			elif rf > 0: # sul filo: sempre sulla linea, anche col pallone lontano
				_sullaLinea(p, FILO_GAP)
		"COC":
			if _iv(p, "area") < 0: # tra le linee: dietro le punte
				var cap2: float = line - TRA_LINEE
				if p.ty * dir > cap2:
					p.ty = cap2 * dir


# resta almeno fino a `cap` (m nel verso d'attacco) e si sposta verso il pallone di `k`
func _sottoLinea(p: R.Player, cap: float, k: float) -> void:
	var dir: float = -1.0 if p.team else 1.0
	if p.ty * dir > cap:
		p.ty = cap * dir
	p.tx += (ball.x - p.tx) * k


# sale fino alla linea del fuorigioco (meno `gap` metri)
func _sullaLinea(p: R.Player, gap: float) -> void:
	var dir: float = -1.0 if p.team else 1.0
	var lv: float = minf(offLine[p.team] - gap, HL - 6.0)
	if p.ty * dir < lv:
		p.ty = lv * dir
		p.sprint = C.hyp(p.tx - p.x, p.ty - p.y) > 4.0


func istrRunBias(q: R.Player) -> float:
	if not _ha(q):
		return 0.0
	match _ruolo(q):
		"COC":
			var v := _iv(q, "area")
			if v > 0:
				return -INSERIMENTO
			if v < 0:
				return 1000.0 # tra le linee: in area va solo se non c'è nessun altro
		"CC":
			if _iv(q, "mezzala") > 0:
				return -BOX_AREA
			if _iv(q, "mezzala") < 0:
				return 1000.0
		"AD", "AS":
			var cr := _iv(q, "cross")
			var dir: float = -1.0 if q.team else 1.0
			var sgn: float = C.sign_(q.bx) if q.bx != 0.0 else 1.0
			if cr != 0 and _crossAltroLato(sgn, C.clamp_((ball.y * dir + HL) / L, 0.0, 1.0)):
				return -INSERIMENTO if cr > 0 else 1000.0
		"ATT":
			if _iv(q, "movimento") < 0:
				return INSERIMENTO * 0.5 # falso nove: in area ci va meno spesso
	return 0.0


func istrGambleK(p: R.Player) -> float:
	if not _ha(p) or _ruolo(p) != "ATT":
		return 1.0
	var k := 1.0
	var v := _iv(p, "movimento")
	if v > 0:
		k *= PROF_TAGLI
	elif v < 0:
		k = 0.0
	var rf := _iv(p, "riferimento")
	if rf > 0:
		k *= FILO_TAGLI
	elif rf < 0:
		k = 0.0
	return k


func istrAutoGx(p: R.Player, gx: float) -> float:
	if not _ha(p):
		return gx
	var v := _iv(p, "ala")
	if v == 0:
		return gx
	var dir: float = -1.0 if p.team else 1.0
	if v < 0 and p.y * dir < HL - AUTO_CROSS_Y: # larga: sulla fascia fino in fondo
		return C.sign_(p.x if absf(p.x) > 1.0 else p.bx) * (HW - 4.0)
	if v > 0: # taglia dentro: verso il centro e la porta
		return p.x * ALA_GUIDA_DENTRO
	return gx


# ------------------------------------------------------------ con la palla
## -1 Gioca semplice / 0 / +1 Porta palla (centrali: +1 Imposta palla al piede, solo nella propria metà)
func _conPalla(p: R.Player) -> int:
	if not _ha(p):
		return 0
	if _ruolo(p) == "DC":
		var v := _iv(p, "imposta")
		var dir: float = -1.0 if p.team else 1.0
		return v if v < 0 or p.y * dir < 0.0 else 0
	return _iv(p, "con_palla")


func istrWant(p: R.Player, pass_: Variant, want: float, press: float) -> float:
	var v := _conPalla(p)
	if v < 0 and pass_ != null and float(pass_.safe) > 0.15:
		return maxf(want, SEMPLICE_WANT)
	if v > 0 and press >= PRESS_NEAR:
		return want * (IMPOSTA_WANT if _ruolo(p) == "DC" else PORTA_WANT)
	return want


func istrAutoSpd(p: R.Player, spd: float, pressed: bool) -> float:
	var v := _conPalla(p)
	if v < 0:
		return minf(spd, SEMPLICE_SPD)
	if v > 0 and not pressed:
		return maxf(spd, PORTA_SPD)
	return spd


# ------------------------------------------------------------ senza palla, col pallone loro
func defend(p: R.Player) -> void:
	super(p)
	if not _ha(p) or phase != "play":
		return
	var b := ball
	var tm := p.team
	var c := b.owner
	if c == null or c.team == tm or p == ctrl[tm] or p == presser[tm] or p == presser2[tm] or p == cover[tm]:
		return
	var dir: float = -1.0 if tm else 1.0
	var own: float = -dir * HL
	var ruolo := _ruolo(p)
	if (ruolo == "ATT" or ruolo == "AD" or ruolo == "AS") and _iv(p, "pressione") > 0:
		if b.y * dir > PRESSA_DA and C.hyp(c.x - p.x, c.y - p.y) < PRESSA_R:
			var bersaglio: R.Player = c
			for q: R.Player in players: # un compagno che pressa è già più vicino: si chiude sull'avversario più vicino
				if q != p and q.team == tm and not q.off and _ha(q) and _iv(q, "pressione") > 0 and C.hyp(c.x - q.x, c.y - q.y) < C.hyp(c.x - p.x, c.y - p.y):
					bersaglio = _avversarioVicino(p, c)
					break
			if bersaglio != null:
				var ux: float = -bersaglio.x
				var uy: float = own - bersaglio.y
				var n: float = C.orf(C.hyp(ux, uy), 1.0)
				p.tx = bersaglio.x + ux / n * PRESSA_GAP
				p.ty = bersaglio.y + uy / n * PRESSA_GAP
				p.sprint = true
	elif (ruolo == "DC" or ruolo == "CDC") and _iv(p, "marcatura") > 0:
		var an := defAnchor(p)
		var mo: R.Player = null
		var md: float = STRETTA_R
		for o: R.Player in players:
			if o.team != tm and not o.off and o.pos != "P" and o != c:
				var d: float = C.hyp(o.x - an[0], o.y - an[1])
				if d < md:
					md = d
					mo = o
		if mo != null:
			var ux2: float = b.x - mo.x
			var uy2: float = b.y - mo.y
			var n2: float = C.orf(C.hyp(ux2, uy2), 1.0)
			p.tx = mo.x + ux2 / n2 * STRETTA_DAVANTI
			p.ty = mo.y + uy2 / n2 * STRETTA_DAVANTI


# avversario (non portiere, non il portatore) più vicino a p
func _avversarioVicino(p: R.Player, c: R.Player) -> R.Player:
	var best: R.Player = null
	var bd: float = 1e9
	for o: R.Player in players:
		if o.team != p.team and not o.off and o.pos != "P" and o != c:
			var d: float = C.hyp(o.x - p.x, o.y - p.y)
			if d < bd:
				bd = d
				best = o
	return best


# ------------------------------------------------------------ portiere
func gkAI(p: R.Player) -> void:
	super(p)
	if not _ha(p) or phase != "play" or ball.shot != null:
		return
	var v := _iv(p, "uscite")
	var ch: R.Chase = chase[p.team]
	if v == 0 or (ch != null and ch.p == p):
		return
	var dir: float = -1.0 if p.team else 1.0
	var own: float = -dir * HL
	var k: float = USCITE_FUORI[0] if v < 0 else USCITE_FUORI[1]
	p.tx *= k
	p.ty = own + (p.ty - own) * k


func gkClaimBonus(g: R.Player) -> float:
	var b := super(g)
	return b + USCITE_PRESA * _iv(g, "uscite") if _ha(g) else b
