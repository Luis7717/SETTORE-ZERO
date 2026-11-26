# Stili di gioco delle squadre (Fase D, Luis 2026-11-22): come attacca e come difende una squadra.
# Solo dati e funzioni pure (niente grafica, niente numeri casuali del motore): il motore legge i parametri
# (base.gd → stA/stD), la carriera sceglie lo stile delle squadre della CPU (perSquadra), i menu i nomi e le spiegazioni.
#
# Nelle opzioni della partita lo stile sta nella squadra: campi facoltativi "stileAtt" e "stileDif" del dizionario
# della squadra (come "skill"). Senza campo, o con lo stile predefinito, o con un valore sconosciuto il motore è
# identico a prima, bit per bit (nessun ramo nuovo viene eseguito: test_stili.gd e test_equivalence.gd).
extends RefCounted

const ATT_BASE := "equilibrato"
const DIF_BASE := "equilibrata"
const ATTACCO := ["equilibrato", "contropiede", "possesso", "fasce", "lanci"]
const DIFESA := ["equilibrata", "pressing", "catenaccio", "uomo", "fuorigioco"]

const NOMI := {
	"equilibrato": "Equilibrato", "contropiede": "Contropiede", "possesso": "Possesso palla",
	"fasce": "Gioco sulle fasce", "lanci": "Lanci lunghi",
	"equilibrata": "Equilibrata", "pressing": "Pressing alto", "catenaccio": "Catenaccio",
	"uomo": "A uomo", "fuorigioco": "Fuorigioco",
}
# nomi corti per i pulsanti (stanno in tre colonne su 390 punti)
const CORTI := {
	"equilibrato": "Equilibrato", "contropiede": "Contropiede", "possesso": "Possesso",
	"fasce": "Fasce", "lanci": "Lanci lunghi",
	"equilibrata": "Equilibrata", "pressing": "Pressing", "catenaccio": "Catenaccio",
	"uomo": "A uomo", "fuorigioco": "Fuorigioco",
}
const SPIEGA := {
	"equilibrato": "Un po' di tutto: passaggi, corse e tiri quando c'è l'occasione.",
	"contropiede": "Squadra bassa; appena si ruba palla, passaggi rapidi in avanti.",
	"possesso": "Tanti passaggi corti e pazienza, pochi lanci; appoggi sempre vicini.",
	"fasce": "Ali larghe vicino alla linea laterale, corsa sulla fascia e cross.",
	"lanci": "Palla lunga e alta verso le punte, anche saltando il centrocampo.",
	"equilibrata": "Uno va sul portatore, gli altri tengono la posizione.",
	"pressing": "In due sul portatore già nella sua metà campo, linea alta.",
	"catenaccio": "Blocco basso e stretto davanti all'area; si pressa solo vicino.",
	"uomo": "Ognuno segue da vicino il suo avversario per tutto il campo.",
	"fuorigioco": "Difensori in linea, alti, che salgono insieme: fuorigioco.",
}

# ---------------------------------------------------------------- regolazioni (misurate con tools/misura_stili.gd)
# Contropiede
const CONTRO_WIN := 7.0        # s dopo il recupero del pallone in cui la squadra verticalizza
const CONTRO_GAIN := 0.08      # peso in più del guadagno in avanti del passaggio (base 0,09 per metro)
const CONTRO_THROUGH := 0.5    # preferenza in più per il filtrante nel contropiede
const CONTRO_THINK := 0.6      # nel contropiede il portatore decide in questa frazione del tempo solito
const CONTRO_LOW := -0.07      # in attacco difensori e centrocampisti restano più bassi (frazione del campo)
const CONTRO_DEEP := 0.03      # ... e le punte più alte
# Possesso palla
const POSS_GAIN := -0.01       # il guadagno in avanti pesa meno: si gioca anche di lato e indietro
const POSS_LEN := 0.05         # penalità per metro di passaggio oltre POSS_LEN0
const POSS_LEN0 := 14.0
const POSS_SAFE := 0.3         # peso in più della sicurezza della linea di passaggio
const POSS_HOLD := 2           # dopo così tante decisioni col pallone il portatore cerca il passaggio ...
const POSS_HOLD_WANT := 0.4    # ... con questa probabilità (base: 5 e 0,3)
const POSS_SHOT := 0.0         # soglia del tiro da fuori area più alta (0: con 0,05-0,1 non tirava quasi più, misura 2026-11-22)
const POSS_SUPPORT := [6.5, 9.5] # gli appoggi si offrono più vicini (base 8-11 m)
const POSS_HELPERS := 1        # un compagno d'appoggio in più
const POSS_NO_LOFT := 0.4      # lanci alti scelti meno volentieri
# Gioco sulle fasce
const FASCE_WIDE_C := 0.35     # anche i centrocampisti con |bx| sopra questo restano larghi in attacco
const FASCE_CROSS_X := 4.0     # il cross parte già a 14-4 = 10 m dal centro (base 14 m)
const FASCE_CROSS_Y := 10.0    # ... e da 24+10 = 34 m dalla porta (base 24 m)
const FASCE_CROSS_FREE := 1.0  # spazio richiesto al compagno in area (base CROSS_FREE = 2,2 m)
const FASCE_CROSS_SC := 0.5    # preferenza in più per il cross
const FASCE_RUN_X := 8.0       # portatore oltre questa distanza dal centro e lontano dalla porta: corre sulla fascia
const FASCE_RUN_DG := 26.0
# Lanci lunghi
const LANCI_SAFE := 0.6        # il lancio alto si valuta anche se la linea rasoterra è sicura fino a così (base 0,3)
const LANCI_MIN := 18.0        # ... per passaggi oltre questi metri (base 16)
const LANCI_RISK := 0.1        # margine richiesto in meno per il lancio alto
const LANCI_SC := 0.2          # preferenza in più per il lancio alto
const LANCI_LEN := 0.025       # premio per metro di passaggio oltre LANCI_LEN0
const LANCI_LEN0 := 18.0
const LANCI_MAX := 52.0        # distanza massima di un passaggio (base 44)
const LANCI_DEEP := 0.04       # le punte restano più alte
const LANCI_WANT := 0.55       # voglia di lanciare quando il lancio alto è buono
# Pressing alto
const PRESS_LINE := 0.06       # linea più alta (frazione del campo)
const PRESS_FROM := -12.0      # il secondo pressatore va sul portatore da qui in avanti (m nel verso d'attacco di chi pressa)
const PRESS_HUM := 1           # squadra umana: un pressatore in più
# Catenaccio
const CAT_LINE := -0.11        # blocco più basso (frazione del campo)
const CAT_NARROW := 0.8        # e più stretto
const CAT_ZONE := 38.0         # si pressa il portatore solo entro questi metri dalla propria linea di fondo
const CAT_HOLD := 5.0          # più lontano: il più vicino resta davanti al portatore a questa distanza (m)
# Marcatura a uomo
const UOMO_K := 0.88           # quanto si sta sull'avversario (base 0,65 e solo entro 7,5 m dal proprio posto)
const UOMO_GAP := 1.3          # distanza dall'avversario, dal lato della propria porta (m)
# Fuorigioco
const OFF_LINE := 0.02         # linea più alta (frazione del campo)
const OFF_BALL := 6.0          # la linea dei difensori resta almeno così dietro il pallone (m)
# Con l'opzione "rifiniture" (difesa.gd, 2026-11-24, misure in DECISIONI.md): le difese degli stili rifatte
const PRESS_LINE_R := 0.08     # pressing: linea ancora più alta
const PRESS_FROM_R := -22.0    # ... il secondo pressatore esce già da qui (m nel verso d'attacco di chi pressa)
const PRESS2_ENGAGED := 2.5    # primo pressatore entro tanto dal portatore = il secondo chiude la linea di passaggio (m) ...
const PRESS2_LANE_R := 20.0    # ... verso il compagno del portatore più vicino entro tanto (m) ...
const PRESS2_LANE_K := 0.3     # ... mettendosi a questa frazione della linea, dal lato del portatore
const PRESS2_LANE_MIN := 2.5   # ... ma almeno a tanto dal portatore (m)
const UOMO_K_R := 0.78         # a uomo: quanto si sta sull'avversario (il resto = posto in squadra)
const UOMO_LEASH := 20.0       # ... al massimo tanto lontano dal proprio posto (m)
const UOMO_KEEP := 5.0         # nel riabbinare, la coppia di prima conta come più vicina di tanto (m): niente scambi continui
const UOMO_ROLE := 8.0         # penalità (m) per un difensore su un centrocampista o un centrocampista su una punta
const UOMO_LIBERO := 4.0       # il libero sta tanto dietro il proprio posto e dietro l'attaccante più avanzato (m)
const UOMO_BEHIND_D := 2.0     # a uomo i difensori restano almeno tanto dietro il pallone (m) ...
const UOMO_BEHIND_C := -2.0    # ... e i centrocampisti al massimo 2 m davanti
const OFF_LINE_R := 0.06       # fuorigioco: linea alta davvero
const OFF_BALL_R := 4.0        # ... almeno tanto dietro il pallone (m)
const OFF_STEP_V := 3.0        # pallone che va verso la porta avversaria più veloce di così (m/s) = la linea sale ...
const OFF_STEP_M := 5.0        # ... di tanti metri in più, tutti insieme e di corsa
const OFF_SPRINT := 2.0        # difensore più lontano di tanto dalla linea: ci va di corsa (m)
const CAT_MARK_R := 10.0       # catenaccio: si prende in consegna l'avversario più vicino al proprio posto fino a tanto (base 7,5 m)


class Att:
	extends RefCounted
	var nome: String = ATT_BASE
	var on: bool = false        # false = predefinito: il motore non tocca niente
	var contro: bool = false
	var poss: bool = false
	var fasce: bool = false
	var lanci: bool = false


class Dif:
	extends RefCounted
	var nome: String = DIF_BASE
	var on: bool = false
	var pressing: bool = false
	var catenaccio: bool = false
	var uomo: bool = false
	var fuorigioco: bool = false


static func att(nome: Variant) -> Att:
	var a := Att.new()
	if nome is String and ATTACCO.has(nome) and nome != ATT_BASE:
		a.nome = nome
		a.on = true
		a.contro = nome == "contropiede"
		a.poss = nome == "possesso"
		a.fasce = nome == "fasce"
		a.lanci = nome == "lanci"
	return a


static func dif(nome: Variant) -> Dif:
	var d := Dif.new()
	if nome is String and DIFESA.has(nome) and nome != DIF_BASE:
		d.nome = nome
		d.on = true
		d.pressing = nome == "pressing"
		d.catenaccio = nome == "catenaccio"
		d.uomo = nome == "uomo"
		d.fuorigioco = nome == "fuorigioco"
	return d


static func valido_att(nome: Variant) -> String:
	return nome if nome is String and ATTACCO.has(nome) else ATT_BASE


static func valido_dif(nome: Variant) -> String:
	return nome if nome is String and DIFESA.has(nome) else DIF_BASE


## "Contropiede · Pressing alto" (per l'hub e la presentazione della partita)
static func testo(stile_att: Variant, stile_dif: Variant) -> String:
	return "%s · %s" % [NOMI[valido_att(stile_att)], NOMI[valido_dif(stile_dif)]]


# ---------------------------------------------------------------- stile delle squadre della CPU
# Fisso per squadra (dal seme della squadra), coerente con la sua identità: il nome (Atletico = contropiede,
# Real = possesso, ...), la forza (le forti tengono palla e pressano, le deboli si chiudono e lanciano) e la
# formazione della stagione (4-3-3 = fasce, 4-4-2 = lanci, ...). Pesi: più alto = più probabile.
const PESI_NOME := {
	"Atletico": {"contropiede": 3, "pressing": 2},
	"Sporting": {"fasce": 3, "pressing": 1},
	"Real": {"possesso": 3, "fuorigioco": 2},
	"Virtus": {"possesso": 2, "uomo": 2},
	"Olimpia": {"fasce": 2, "fuorigioco": 2},
	"Dinamo": {"contropiede": 2, "pressing": 3},
	"Unione": {"lanci": 2, "catenaccio": 2},
	"Pro": {"lanci": 3, "uomo": 1},
	"Fortitudo": {"lanci": 2, "catenaccio": 3},
	"Aurora": {"possesso": 2, "pressing": 1},
	"Audace": {"contropiede": 2, "fuorigioco": 3},
	"Robur": {"lanci": 3, "uomo": 2},
	"Libertas": {"fasce": 2, "catenaccio": 1},
	"Polisportiva": {"contropiede": 1, "uomo": 2},
	"Città di": {"fasce": 1, "catenaccio": 2},
}
const PESI_FORMAZIONE := {
	"4-4-2": {"lanci": 2, "fasce": 1, "fuorigioco": 1},
	"4-3-3": {"fasce": 3, "pressing": 2},
	"3-5-2": {"possesso": 2, "uomo": 2},
	"4-2-3-1": {"possesso": 1, "contropiede": 2, "catenaccio": 1},
	"4-5-1": {"contropiede": 2, "catenaccio": 2},
	"3-4-3": {"fasce": 2, "pressing": 2, "fuorigioco": 1},
	"5-3-2": {"contropiede": 2, "catenaccio": 3},
	"4-1-4-1": {"possesso": 2, "uomo": 1, "pressing": 1},
	"4-2-4": {"fasce": 2, "lanci": 1, "pressing": 2},
	"4-3-2-1": {"possesso": 3, "pressing": 1},
	"4-2-2-2": {"possesso": 2, "contropiede": 1, "uomo": 1},
	"4-3-3 offensivo": {"possesso": 2, "fasce": 1, "pressing": 2, "fuorigioco": 1},
	"4-3-3 difensivo": {"contropiede": 2, "fasce": 1, "catenaccio": 1},
	"4-1-2-1-2 largo": {"fasce": 2, "possesso": 1, "uomo": 1},
}
const FORTE := 70      # forza da cui una squadra è "forte"
const DEBOLE := 57     # forza sotto cui è "debole"
const PESI_FORTE := {"possesso": 2, "pressing": 2, "fuorigioco": 1}
const PESI_DEBOLE := {"contropiede": 2, "lanci": 1, "catenaccio": 2}
const PESO_BASE := 2   # ogni stile parte da qui (gli equilibrati da PESO_BASE + 1)


static func _hash(a: int, b: int) -> int:
	var h: int = (a * 2654435761 + b * 40503 + 12345) & 0xffffffff
	h = ((h ^ (h >> 15)) * 2246822519) & 0xffffffff
	h = ((h ^ (h >> 13)) * 3266489917) & 0xffffffff
	return (h ^ (h >> 16)) & 0xffffffff


static func _scegli(lista: Array, pesi: Dictionary, base: String, r: int) -> String:
	var tot := 0
	var w: Array = []
	for nome: String in lista:
		var p: int = PESO_BASE + (1 if nome == base else 0) + int(pesi.get(nome, 0))
		w.append(p)
		tot += p
	var k: int = r % tot
	for i in lista.size():
		k -= int(w[i])
		if k < 0:
			return lista[i]
	return base


## {att, dif} della squadra della CPU: seme della squadra, nome ("Atletico Valdoro"), forza, formazione
static func perSquadra(seme: int, nome: String, forza: float, formazione: String) -> Dictionary:
	var pesi := {}
	var aggiungi := func(d: Dictionary) -> void:
		for k: String in d:
			pesi[k] = int(pesi.get(k, 0)) + int(d[k])
	for pre: String in PESI_NOME:
		if nome.begins_with(pre + " "):
			aggiungi.call(PESI_NOME[pre])
			break
	aggiungi.call(PESI_FORMAZIONE.get(formazione, {}))
	if forza >= FORTE:
		aggiungi.call(PESI_FORTE)
	elif forza < DEBOLE:
		aggiungi.call(PESI_DEBOLE)
	return {"att": _scegli(ATTACCO, pesi, ATT_BASE, _hash(seme, 1)), "dif": _scegli(DIFESA, pesi, DIF_BASE, _hash(seme, 2))}
