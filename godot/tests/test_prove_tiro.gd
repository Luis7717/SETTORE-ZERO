# Allenamento libero (scripts/partita/prove_tiro.gd + scripts/carriera/record_prove.gd): punti dei gol (angolini
# valgono di più), sequenza dei posti ripetibile col seme, prove giocate col motore vero (tiri, punizioni con la
# barriera, rigori a oltranza), record salvato nella carriera e salvataggio vecchio senza il campo.
extends "test_base.gd"

const ProveTiro := preload("res://scripts/partita/prove_tiro.gd")
const RecordProve := preload("res://scripts/carriera/record_prove.gd")
const SimRng := preload("res://sim/rng.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const DIR := "user://prove_carriera/"
const MAX_PASSI := 60 * 60 * 6   # sei minuti di gioco: ogni prova finisce molto prima


## interfaccia finta che registra quello che la prova mostra
class Registro:
	extends RefCounted
	var stati: Array = []
	var esiti: Array = []
	var fini: Array = []

	func stato(prova: String, tentativo: int, tentativi: int, punti: int) -> void:
		stati.append([prova, tentativo, tentativi, punti])

	func esito(gol: bool, punti: int, nota: String) -> void:
		esiti.append([gol, punti, nota])

	func fine(r: Dictionary) -> void:
		fini.append(r)


func nuova_partita(seme: int = 5, campione_idx: int = 9) -> SimMatchScript:
	var a := H.mkTeam("A", 70.0, 1)
	a.players[campione_idx]["champ"] = true
	return H.newMatch(seme, ProveTiro.HALF_LEN, [true, false], a, H.mkTeam("B", 60.0, 2))


# gioca la prova fino in fondo: il "dito" tira verso un punto della porta scelto col seme
func gioca(m: SimMatchScript, p: ProveTiro, seme_dito: int, largo := false) -> void:
	var r := SimRng.new(seme_dito)
	var attesa := 0.0
	for i in MAX_PASSI:
		if p.finished:
			return
		if p.fase == "tiro" and m.ball.owner == p.campione:
			attesa += DT
			if attesa > 1.0:
				var tx := (r.next() - 0.5) * (20.0 if largo else C.GW - 1.0)
				if m.userKick(0, {"type": "shot", "tx": tx, "ty": C.HL, "th": 0.2 + r.next() * 1.9, "curve": 0.0}):
					attesa = 0.0
		p.before()
		m.step(DT)
		p.after(DT)
		m.events.clear()


func test_punti_angolini_valgono_di_piu() -> bool:
	var centro := ProveTiro.punti_gol(0.0, 0.3)
	eq(centro.punti, ProveTiro.PUNTI_GOL, "gol centrale e basso")
	eq(centro.nota, "Gol")
	var palo := ProveTiro.punti_gol(C.GW / 2.0 - 0.4, 0.3)
	eq(palo.punti, ProveTiro.PUNTI_GOL + ProveTiro.PUNTI_PALO, "vicino al palo")
	eq(palo.nota, "Vicino al palo")
	var alto := ProveTiro.punti_gol(-0.5, C.GH - 0.3)
	eq(alto.punti, ProveTiro.PUNTI_GOL + ProveTiro.PUNTI_ALTO, "sotto la traversa")
	var angolino := ProveTiro.punti_gol(-(C.GW / 2.0 - 0.3), C.GH - 0.2)
	eq(angolino.punti, ProveTiro.PUNTI_GOL + ProveTiro.PUNTI_PALO + ProveTiro.PUNTI_ALTO, "angolino")
	eq(angolino.nota, "Angolino!")
	check(angolino.punti > palo.punti and palo.punti > centro.punti, "più vicino all'angolo, più punti")
	return done()


func test_sequenza_ripetibile_col_seme() -> bool:
	for prova: String in ["tiri", "punizioni"]:
		var a := ProveTiro.sequenza(prova, 123)
		eq(a, ProveTiro.sequenza(prova, 123), prova + ": stesso seme, stessi posti")
		check(a != ProveTiro.sequenza(prova, 124), prova + ": seme diverso, posti diversi")
		eq(a.size(), ProveTiro.TENTATIVI[prova], prova + ": un posto per tentativo")
	var tiri := ProveTiro.sequenza("tiri", 9)
	var fuori := 0
	for s: Dictionary in tiri:
		var d := C.hyp(s.x, C.HL - s.y)
		check(d >= ProveTiro.TIRI_DENTRO[0] - 0.2 and d <= ProveTiro.TIRI_FUORI[1] + 0.2, "tiro a %.1f m" % d)
		if C.HL - s.y > C.BOX_D:
			fuori += 1
	check(fuori >= 3, "tiri da fuori area: %d" % fuori)
	check(fuori <= 7, "tiri da dentro l'area: %d" % (10 - fuori))
	for s: Dictionary in ProveTiro.sequenza("punizioni", 9):
		var in_area: bool = absf(s.x) < C.BOX_W / 2.0 and s.y > C.HL - C.BOX_D
		check(not in_area, "punizione fuori dall'area (%.1f, %.1f)" % [s.x, s.y])
	return done()


func test_tiri_col_campione_e_portiere_vero() -> bool:
	var m := nuova_partita()
	var ui := Registro.new()
	var p := ProveTiro.new(m, ui, "tiri", 31)
	check(p.campione.src.get("champ", false), "tira il campione")
	check(m.ball.owner == p.campione and m.ctrl[0] == p.campione, "il campione ha il pallone ed è comandato")
	check(not m.gk(1).off, "il portiere avversario è in campo")
	var in_campo := m.players.filter(func(q: R.Player) -> bool: return absf(q.x) <= C.HW).size()
	eq(in_campo, 3, "in campo solo campione e portieri, gli altri in panchina")
	eq(p.panchina.size(), 19)
	gioca(m, p, 7)
	check(p.finished, "la prova finisce")
	eq(p.esiti.size(), 10, "dieci tiri")
	var somma := 0
	for e: Dictionary in p.esiti:
		somma += int(e.punti)
		check(e.gol == (e.punti > 0), "punti solo coi gol")
	eq(p.punti, somma, "punteggio = somma dei tiri")
	eq(ui.fini.size(), 1, "una sola scheda finale")
	eq(ui.fini[0].punti, p.punti)
	note("tiri: %d gol su 10, %d punti · %s" % [p.gol_fatti(), p.punti, ", ".join(p.esiti.map(func(e: Dictionary) -> String: return e.nota))])
	check(p.gol_fatti() >= 1, "almeno un gol in dieci tiri in porta")
	return done()


func test_stessa_prova_stesso_seme_stesso_risultato() -> bool:
	var esiti: Array = []
	for giro in 2:
		var m := nuova_partita(8)
		var p := ProveTiro.new(m, Registro.new(), "tiri", 55)
		gioca(m, p, 3)
		esiti.append(p.esiti)
	eq(esiti[0], esiti[1], "stessi semi, stessi esiti")
	return done()


func test_punizione_con_barriera() -> bool:
	var m := nuova_partita()
	var p := ProveTiro.new(m, Registro.new(), "punizioni", 4)
	eq(m.phase, "restart")
	eq(m.restart.type, "freekick")
	check(m.restart.taker == p.campione, "batte il campione")
	var barriera := m.team(1).filter(func(q: R.Player) -> bool: return q.wall != null).size()
	check(barriera >= 2, "barriera di %d" % barriera)
	gioca(m, p, 11)
	check(p.finished, "la prova finisce")
	eq(p.esiti.size(), 8, "otto punizioni")
	return done()


func test_rigori_fuori_finisce_dopo_cinque() -> bool:
	var m := nuova_partita()
	var p := ProveTiro.new(m, Registro.new(), "rigori", 2)
	eq(m.restart.type, "penalty")
	check(m.restart.taker == p.campione, "tira il campione")
	gioca(m, p, 5, true) # tiri larghissimi: fuori
	check(p.finished, "la serie finisce")
	eq(p.esiti.size(), 5, "cinque rigori")
	eq(p.punti, 0, "nessun punto")
	return done()


func test_rigori_a_oltranza_fino_al_primo_errore() -> bool:
	var m := nuova_partita()
	var ui := Registro.new()
	var p := ProveTiro.new(m, ui, "rigori", 2)
	for i in 6: # sei gol di fila: si va oltre i cinque
		p._esito(true, 10, "Gol")
		p._prossimo()
	check(not p.finished, "dopo sei gol si continua")
	eq(p.tentativi(), 7, "tentativi che crescono")
	p._esito(false, 0, "Parata")
	p._prossimo()
	check(p.finished, "al primo errore finisce")
	eq(p.esiti.size(), 7)
	eq(p.punti, 60)
	# un errore nei primi cinque: si arriva comunque a cinque, poi basta
	var q := ProveTiro.new(nuova_partita(), Registro.new(), "rigori", 2)
	q._esito(false, 0, "Fuori")
	q._prossimo()
	check(not q.finished, "dopo il primo errore la serie di cinque continua")
	for i in 4:
		q._esito(true, 10, "Gol")
		q._prossimo()
	check(q.finished, "cinque rigori con un errore: fine")
	return done()


func test_campione_portiere_tira_un_altro() -> bool:
	var m := nuova_partita(5, 0) # il campione è il portiere
	var p := ProveTiro.new(m, Registro.new(), "tiri", 1)
	check(p.campione.pos != "P", "tira il migliore al tiro tra gli altri")
	return done()


func test_record_salvataggio_vecchio_e_nuovo_record() -> bool:
	var vecchio := {"club": "Vecchio FC", "money": 100} # salvataggio di prima: niente campo `prove`
	for prova: String in RecordProve.PROVE:
		eq(RecordProve.record(vecchio, prova), 0, "senza campo: nessun record (" + prova + ")")
	check(RecordProve.aggiorna(vecchio, "tiri", 85), "primo punteggio = record")
	eq(RecordProve.record(vecchio, "tiri"), 85)
	check(not RecordProve.aggiorna(vecchio, "tiri", 60), "più basso: niente record")
	check(not RecordProve.aggiorna(vecchio, "tiri", 85), "uguale: niente record")
	eq(RecordProve.record(vecchio, "tiri"), 85)
	check(RecordProve.aggiorna(vecchio, "rigori", 30), "ogni prova ha il suo record")
	eq(RecordProve.record(vecchio, "tiri"), 85, "il record dei tiri resta")
	eq(RecordProve.record({"prove": {"tiri": 40.0}}, "tiri"), 40, "numero letto dal JSON (float)")
	eq(RecordProve.record({"prove": {"tiri": "tanti"}}, "tiri"), 0, "valore rotto = 0")
	eq(RecordProve.record({"prove": 7}, "tiri"), 0, "campo rotto = 0")
	check(not RecordProve.aggiorna(vecchio, "corsa", 999), "prova sconosciuta: niente")
	return done()


func test_record_resta_nel_salvataggio() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + "prove_tiro.json"
	Salv.cancella(c.percorso)
	c.create("Prova Record", 1, 99)
	c.save()
	var c1 := CarrieraScript.new()
	c1.percorso = c.percorso
	check(c1.load(), "carriera senza record si legge")
	eq(RecordProve.record(c1.s, "punizioni"), 0, "carriera nuova: nessun record")
	RecordProve.aggiorna(c1.s, "punizioni", 120)
	c1.save()
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	c2.load()
	eq(RecordProve.record(c2.s, "punizioni"), 120, "record riletto dal file")
	Salv.cancella(c.percorso)
	return done()
