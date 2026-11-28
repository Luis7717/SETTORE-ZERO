# Giochetto del dribbling "Bicicletta" (id `bicicletta`): parte A (la finta, dura `g` = show di sim/skill.gd) e parte B (dallo
# scatto del motore, evento 'dribble_go'). Aiuti e costanti in comune: comune.gd (K). Vedi ../coreo_skill.gd.
extends RefCounted

const Coreo := preload("../coreo.gd")
const K := preload("comune.gd")

# tempi della parte A, in frazioni di `tk` (quando il motore fa partire il pallone: sim/skill.gd)
const T_PIANTA := 0.27       # il piede davanti (lato scelto) si pianta oltre il pallone: pallone fermo dietro il suo tallone
const T_STRINGE := 0.46      # il collo dell'altro piede arriva da dietro e lo stringe contro il tallone: stacco (saltello)
const T_POLPACCIO := 0.77    # in volo: il pallone è salito a metà polpaccio della gamba davanti
# pallone (riferimento del corpo, m del modello; altezze in m del gioco come sim/skill.gd `dh`)
const Z_PIANTA := 0.33       # davanti al corpo quando il piede lo scavalca
const Z_POLPACCIO := -0.06    # sul polpaccio (gamba piegata, stinco inclinato) a metà salita ...
const H_POLPACCIO := 0.44    # ... alto tanto
const APRE := 0.3            # rad: il piede dietro tiene la punta girata verso il lato scelto mentre stringe e porta su ...
const LARGO_S := 0.1         # ... e la gamba davanti, nel saltello, sta tanto dalla sua parte (m del modello): gambe staccate
const SALTO := 0.08          # di quanto sale il bacino nel saltello (m del modello): le gambe si raccolgono sotto
# parte B: corsa a testa alta verso il pallone che scende
const PASSO_B := 0.16        # s tra due appoggi (falcata vera, non passettini)
const FINE_B := 0.52         # la coreografia finisce tanto dopo lo scatto


# bicicletta (per Luis: il pallone portato su dietro il polpaccio e alzato col tacco sopra la testa propria e del
# difensore). In corsa, senza fermarsi:
#   1. il piede del lato scelto scavalca il pallone e si pianta: il pallone resta fermo sul prato dietro il suo tallone;
#   2. il collo dell'altro piede arriva da dietro e lo stringe contro il tallone; saltello in avanti a piedi uniti;
#   3. in volo il piede dietro lo fa rotolare su per il polpaccio della gamba davanti (il pallone viaggia col corpo
#      perché è stretto tra le gambe), busto piegato avanti, braccia larghe;
#   4. la gamba davanti si piega indietro e il tacco lo colpisce da sotto: da lì è il pallone staccato del motore
#      (gravità vera) che passa sopra la testa sua e del difensore.
static func a(c: Coreo, S: float, _g: float) -> void:
	var pS := K.ls(S)
	var pF := K.ls(-S)
	var sk := K.Skill.trova("bicicletta")
	var tk := float(sk.tk)
	var da := float(sk.get("da", -0.3)) / K.SCALA     # da dove parte il pallone del motore (dietro il corpo) ...
	var dh := float(sk.get("dh", 0.6))                # ... e a che altezza
	var t0 := K.libera(c, pS)
	var tp := maxf(t0 + 0.09, T_PIANTA * tk)
	var ts := maxf(tp + 0.08, T_STRINGE * tk)
	var tm := maxf(lerpf(ts, tk, 0.5), T_POLPACCIO * tk)
	# --- pallone: rallenta davanti, fermo dietro il tallone, poi su col corpo (stretto tra le gambe), fino al tacco
	c.palla_a(0.05, {"rel": Vector3(0, 0, 0.46)})
	c.palla_a(tp, {"rel": Vector3(S * 0.02, 0, Z_PIANTA)})
	# --- piede davanti: scavalca il pallone e si pianta; il tallone è contro il pallone
	c.appoggia_palla(pS, tp, Vector3(S * 0.02, K.H, 0.2), 0.0, 0.1)
	c.stacca(pF, tp + 0.01)
	# --- piede dietro: il collo dietro il pallone (punta in giù), poi sotto, e lo porta su lungo il polpaccio
	# (punta girata verso il lato scelto: la caviglia resta dalla sua parte e le due gambe non si attraversano)
	c.tocca(pF, ts, "instep", Vector3(S * APRE, 0.95, 0), {"resta": true}, 0.07)
	c.tocca(pF, tm, "instep", Vector3(S * APRE, 0.45, 0), {"rel": Vector3(S * 0.02, 0, Z_POLPACCIO), "h": H_POLPACCIO, "lega": true})
	# --- saltello: il piede davanti stacca, resta basso sotto il pallone, poi la gamba si piega indietro: colpo di tacco
	c.stacca(pS, ts + 0.01)
	c.passa(pS, tm, Vector3(S * LARGO_S, 0.28, Z_POLPACCIO + 0.06), Vector3(0, 0.6, 0), 0.0)
	c.tocca(pS, tk, "heel", Vector3(0, 1.25, 0), {"rel": Vector3(S * 0.02, 0, da), "h": dh - 0.02}, 0.0)
	c.passa(pS, tk + 0.07, Vector3(S * 0.08, 0.72, -0.3), Vector3(0, 1.6, 0), 0.0)
	# il piede dietro lascia il pallone e scende: è lui che atterra (subito dopo il colpo di tacco)
	c.appoggia_corsa(pF, tk + 0.035, PASSO_B, Vector2(0, 0.02), 0.0)
	# --- corpo: si raccoglie sul piede piantato, salta, busto giù in avanti sul colpo di tacco
	c.chiave_bacino(tp, Vector3(0, 0.89, 0.0))
	c.chiave_angoli(tp, Vector3(0, 0.12, 0))
	c.chiave_busto(tp, Vector3(0.2, 0, 0))
	c.chiave_bacino(ts, Vector3(0, 0.85, 0.02))
	c.chiave_angoli(ts, Vector3(0, 0.2, 0))
	c.chiave_busto(ts, Vector3(0.32, 0, 0))
	c.chiave_bacino(tm, Vector3(0, 0.93 + SALTO, 0.04))
	c.chiave_angoli(tm, Vector3(0, 0.3, 0))
	c.chiave_busto(tm, Vector3(0.5, 0, 0))
	c.chiave_bacino(tk, Vector3(0, 0.93 + SALTO, 0.06))
	c.chiave_angoli(tk, Vector3(S * 0.12, 0.36, 0))
	c.chiave_busto(tk, Vector3(0.62, 0, -S * 0.1))
	# braccia: raccolte, poi larghe e indietro nel salto (equilibrio), quella del lato del tacco più su
	K.braccia(c, tp, pS, K.BR_DIETRO, K.BR_AVANTI)
	K.braccia(c, ts, pS, K.BR_LARGO, K.BR_LARGO)
	K.braccia(c, tm, pS, Vector3(0.4, -0.1, -0.04), Vector3(0.4, -0.12, 0.0))
	K.braccia(c, tk, pS, Vector3(0.42, 0.04, -0.14), Vector3(0.42, -0.04, -0.08))
	# sguardo: giù sul pallone finché è tra i piedi, poi avanti (è dietro di lui), poi su a seguirlo
	c.chiave_sguardo(ts, 1.0, 0.0)
	c.chiave_sguardo(tm, 0.35, 0.0)
	c.chiave_sguardo(tk, 0.15, 0.0)
	c.chiave_sguardo(tk + 0.22, 1.0, 0.0)


# parte B: S = lato scelto, tg = adesso (lo scatto). Il pallone è già partito (ball.finto del motore): atterra sul
# piede che lo ha portato su e via di corsa a falcate intorno al difensore, testa alta sul pallone che scende
static func b(c: Coreo, S: float, tg: float) -> void:
	var pS := K.ls(S)
	var pF := K.ls(-S)
	c.taglia(tg, false)
	c.yaw_fisso_fino = tg
	c.chiave_giro(tg + 0.16, 0.0)
	c.chiave_sguardo(tg + 0.12, 1.0)
	# atterraggio sul piede dietro (se non è già giù), poi la gamba del tacco viene avanti: primo passo lungo
	var t1 := tg + 0.02
	if not c.a_terra(pF):
		c.appoggia_corsa(pF, tg + 0.03, PASSO_B, Vector2(0, 0.02), 0.0)
		t1 = tg + 0.05
	var a := pS
	var tp := t1 + PASSO_B * 0.75
	while tp < tg + FINE_B + 0.1:
		c.appoggia_corsa(a, tp, PASSO_B, Vector2.ZERO, 0.18)
		c.stacca(K.altro(a), tp - 0.02)
		# braccia di corsa: avanti quello opposto alla gamba che appoggia
		c.chiave_braccio(K.altro(a), tp, K.BR_AVANTI)
		c.chiave_braccio(a, tp, K.BR_DIETRO)
		a = K.altro(a)
		tp += PASSO_B
	# atterra molleggiando (bacino giù), busto ancora avanti, dentro la curva; poi su, di corsa
	c.chiave_bacino(tg + 0.06, Vector3(S * 0.06, 0.85, 0.03))
	c.chiave_angoli(tg + 0.06, Vector3(S * 0.24, 0.3, S * 0.12))
	c.chiave_busto(tg + 0.06, Vector3(0.44, S * 0.2, S * 0.14))
	c.chiave_bacino(tg + 0.26, Vector3(S * 0.03, 0.88, 0.02))
	c.chiave_angoli(tg + 0.26, Vector3(S * 0.1, 0.24, S * 0.05))
	c.chiave_busto(tg + 0.26, Vector3(0.3, S * 0.08, 0))
	c.chiave_bacino(tg + FINE_B, Vector3(0, 0.92, -0.02))
	c.chiave_angoli(tg + FINE_B, Vector3(0, 0.14, 0))
	c.chiave_busto(tg + FINE_B, Vector3(0.16, 0, 0))
	K.braccia(c, tg + 0.06, pS, Vector3(0.36, -0.2, -0.14), K.BR_LARGO)
	c.fine = tg + FINE_B
