# Istruzioni ai giocatori nel motore (Luis 2026-11-28; dati e nomi in istruzioni.gd). Ogni giocatore resta nel suo
# posto della formazione: l'istruzione sposta solo quanto sale o scende, quanto si allarga e cosa fa senza palla.
# Legge p.src.istr ({chiave: scelta}) col ruolo del posto (p.ruolo; senza, il ruolo predefinito del gruppo). Senza
# `istr` o con le scelte di mezzo niente cambia: tutti i metodi chiamano super() e tornano subito.
#  - terzini (spinta): difensivo = resta indietro e più dentro; offensivo = sale tanto e, col pallone sulla sua fascia
#    nella metà avversaria, arriva fino al fondo;
#  - esterni (fascia): largo = sulla linea laterale; difensivo = più basso e rientra di più;
#  - mediano: difensivo = in attacco mai oltre il suo ultimo quarto (MEDIANO_MAX); offensivo = fino a centrocampo e oltre;
#  - centrocampista e trequartista (posizione): più alti o più bassi, in attacco e un po' in difesa;
#  - trequartista (area): inserimento = attacca l'area per primo; tra le linee = mai in area, dietro le punte;
#  - ali: larga = sulla linea e la guida automatica va sul fondo; taglia dentro = più strette e la guida punta al centro;
#  - attaccanti (movimento): profondità = sempre sulla linea del fuorigioco e tagli più frequenti (CPU); boa = resta
#    BOA_DIETRO metri sotto la linea e viene incontro al pallone (sui cross va in area come gli altri);
#  - ali e attaccanti (pressione): pressa = va sui difensori quando impostano nella loro metà; resta su = in difesa
#    resta alto;
#  - centrali (marcatura): anticipo = va addosso all'attaccante vicino, davanti a lui; copre = più dietro, mai fuori;
#  - portiere (uscite): esce = più fuori dai pali e prende più cross; pali = più vicino alla linea, meno cross.
extends "attacco.gd"

const Istr := preload("istruzioni.gd")
const RuoliI := preload("ruoli.gd")

const SPINTA_SU := 0.08        # terzino offensivo: più alto (frazione del campo) ...
const SPINTA_FONDO := 0.08     # ... e ancora di più col pallone sulla sua fascia oltre SPINTA_FONDO_DA
const SPINTA_FONDO_DA := 0.5
const SPINTA_GIU := -0.12      # terzino difensivo: più basso ...
const SPINTA_DENTRO := 0.75    # ... e più dentro (frazione della sua x)
const FASCIA_SU := 0.03        # esterno largo: un po' più alto
const FASCIA_GIU := -0.07      # esterno difensivo: più basso in attacco ...
const FASCIA_RIENTRO := -0.05  # ... e in difesa
const MEDIANO_MAX := 0.3       # mediano difensivo: in attacco al massimo qui (frazione del campo dalla propria porta)
const MEDIANO_SU := 0.09       # mediano offensivo: più alto in attacco ...
const MEDIANO_DIF := 0.03      # ... e di tanto (su o giù) in difesa
const MEZZALA_ATT := 0.07      # centrocampista e trequartista: su o giù in attacco ...
const MEZZALA_DIF := 0.04      # ... e in difesa
const ALA_DENTRO := 0.55       # ala che taglia: x in attacco (frazione della metà larghezza)
const ALA_GUIDA_DENTRO := 0.2  # ... e la guida automatica punta a questa frazione della sua x
const BOA_GIU := -0.04         # boa: un po' più bassa ...
const BOA_DIETRO := 9.0        # ... e almeno tanti metri sotto la linea del fuorigioco
const BOA_INCONTRO := 0.35     # ... spostata verso il pallone di questa frazione
const PROF_TAGLI := 2.5        # profondità: tagli oltre la linea così più spesso (CPU)
const PROF_DA := -30.0         # ... e sulla linea del fuorigioco già col pallone da qui (m nel verso d'attacco)
const RESTA_SU := 0.1          # resta su: in difesa più alto
const PRESSA_DA := 8.0         # pressa: pallone dei loro da qui in avanti (m nel nostro verso d'attacco) ...
const PRESSA_R := 25.0         # ... e portatore entro tanto ...
const PRESSA_GAP := 2.0        # ... ci si mette davanti a tanto (m)
const COPRE_GIU := -0.03       # centrale che copre: più basso
const ANTICIPO_R := 10.0       # centrale in anticipo: attaccante entro tanto dal suo posto (m) ...
const ANTICIPO_DAVANTI := 1.0  # ... davanti a lui, verso il pallone (m)
const TRA_LINEE := 10.0        # trequartista tra le linee: almeno tanti metri sotto la linea del fuorigioco
const INSERIMENTO := 14.0      # inserimento: nella scelta di chi attacca l'area conta come più vicino di tanto (m)
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
		"ED", "ES":
			var v := _iv(p, "fascia")
			if noi and v < 0:
				r[0] = sgn * (HW - WIDE_GAP)
				ayf += FASCIA_SU
			elif v > 0:
				ayf += FASCIA_GIU if noi else FASCIA_RIENTRO
		"CDC":
			var v := _iv(p, "mediano")
			if noi and v < 0:
				ayf = minf(ayf, MEDIANO_MAX)
			elif noi and v > 0:
				ayf += MEDIANO_SU
			elif v != 0:
				ayf += MEDIANO_DIF * v
		"CC":
			ayf += _iv(p, "mezzala") * (MEZZALA_ATT if noi else MEZZALA_DIF)
		"COC":
			ayf += _iv(p, "trequarti") * (MEZZALA_ATT if noi else MEZZALA_DIF)
		"AD", "AS":
			var v := _iv(p, "ala")
			if noi and v < 0:
				r[0] = sgn * (HW - WIDE_GAP)
			elif noi and v > 0:
				r[0] = sgn * HW * ALA_DENTRO
			if not noi and _iv(p, "pressione") < 0:
				ayf += RESTA_SU
		"ATT":
			if noi and _iv(p, "movimento") < 0:
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
			if v < 0: # boa: sotto la linea, verso il pallone
				var cap: float = line - BOA_DIETRO
				if p.ty * dir > cap:
					p.ty = cap * dir
				p.tx += (b.x - p.tx) * BOA_INCONTRO
			elif v > 0 and b.y * dir > PROF_DA: # profondità: sulla linea del fuorigioco
				var lv: float = minf(offLine[tm] - 0.8, HL - 6.0)
				if p.ty * dir < lv:
					p.ty = lv * dir
					p.sprint = C.hyp(p.tx - p.x, p.ty - p.y) > 4.0
		"COC":
			if _iv(p, "area") < 0: # tra le linee: dietro le punte
				var cap2: float = line - TRA_LINEE
				if p.ty * dir > cap2:
					p.ty = cap2 * dir


func istrRunBias(q: R.Player) -> float:
	if not _ha(q):
		return 0.0
	if _ruolo(q) == "COC":
		var v := _iv(q, "area")
		if v > 0:
			return -INSERIMENTO
		if v < 0:
			return 1000.0 # tra le linee: in area va solo se non c'è nessun altro
	return 0.0


func istrGambleK(p: R.Player) -> float:
	return PROF_TAGLI if _ha(p) and _ruolo(p) == "ATT" and _iv(p, "movimento") > 0 else (0.0 if _ha(p) and _iv(p, "movimento") < 0 else 1.0)


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
	elif ruolo == "DC" and _iv(p, "marcatura") > 0:
		var an := defAnchor(p)
		var mo: R.Player = null
		var md: float = ANTICIPO_R
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
			p.tx = mo.x + ux2 / n2 * ANTICIPO_DAVANTI
			p.ty = mo.y + uy2 / n2 * ANTICIPO_DAVANTI


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
