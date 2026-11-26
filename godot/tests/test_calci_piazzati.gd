# Calci piazzati scelti dalla persona (Luis 2026-11-26): rigorista, punizioni lontane e vicine, angolo destro e
# sinistro. Nel motore è il campo facoltativo `piazzati` della squadra (SimMatch.piazzato): senza, o se il scelto non è
# in campo, sceglie il motore come sempre. Nella carriera sta in `s.piazzati` (predefinito: tutto automatico).
extends "test_base.gd"

const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const DIR := "user://test_calci_piazzati/"


func _squadra(nome: String, seme: int) -> Dictionary:
	var t := H.mkTeam(nome, 62, seme)
	for i in t.players.size():
		t.players[i]["id"] = 100 + i
	return t


func _partita(piazzati: Variant, squadra := 0) -> SimMatchScript:
	var a := _squadra("A", 3)
	var b := _squadra("B", 5)
	if piazzati != null:
		(a if squadra == 0 else b)["piazzati"] = piazzati
	return H.newMatch(8, 60.0, [false, false], a, b)


func _batte(m: SimMatchScript, tipo: String, tm: int, x: float, y: float) -> int:
	m.setRestart(tipo, tm, x, y)
	return int(m.restart.taker.src.id)


func test_senza_scelte_il_motore_fa_come_sempre() -> bool:
	var m := _partita(null)
	var vuoto := _partita({"rig": null, "punL": null, "punV": null, "angD": null, "angS": null})
	for caso: Array in [["penalty", 0.0, 0.0], ["corner", 30.0, 49.0], ["corner", -30.0, 49.0], ["freekick", 5.0, 30.0], ["freekick", -8.0, 10.0]]:
		m.setRestart("kickoff", 0, 0.0, 0.0) # stesse posizioni di partenza nelle due partite
		vuoto.setRestart("kickoff", 0, 0.0, 0.0)
		eq(_batte(vuoto, caso[0], 0, caso[1], caso[2]), _batte(m, caso[0], 0, caso[1], caso[2]), "%s: tutto automatico = nessun campo" % caso[0])
	var migliore: R.Player = null
	for p: R.Player in m.team(0):
		if p.pos != "P" and (migliore == null or p.st.sv("rig") > migliore.st.sv("rig")):
			migliore = p
	eq(_batte(m, "penalty", 0, 0.0, 0.0), int(migliore.src.id), "rigore automatico: il migliore nei rigori")
	H.disposeAll()
	return done()


func test_battitori_scelti() -> bool:
	var m := _partita({"rig": 103, "punL": 104, "punV": 105, "angD": 106, "angS": 107})
	eq(_batte(m, "penalty", 0, 0.0, 0.0), 103, "rigore: il rigorista scelto")
	eq(_batte(m, "corner", 0, 30.0, 49.0), 106, "angolo a destra di chi attacca (squadra 0: x > 0)")
	eq(_batte(m, "corner", 0, -30.0, 49.0), 107, "angolo a sinistra")
	var gy := C.HL
	eq(_batte(m, "freekick", 0, 0.0, gy - 20.0), 105, "punizione a 20 m dalla porta: vicina")
	eq(_batte(m, "freekick", 0, 0.0, gy - 30.0), 104, "punizione a 30 m: lontana")
	check(SimMatchScript.PUN_LONTANA_M > 20.0 and SimMatchScript.PUN_LONTANA_M < 30.0, "soglia tra vicina e lontana")
	var senza := _partita(null)
	m.setRestart("kickoff", 0, 0.0, 0.0) # stesse posizioni di partenza nelle due partite
	senza.setRestart("kickoff", 0, 0.0, 0.0)
	var lontano := _batte(m, "freekick", 0, -10.0, -20.0)
	var auto := _batte(senza, "freekick", 0, -10.0, -20.0)
	eq(lontano, auto, "punizione nella propria metà: il più vicino come sempre")
	eq(_batte(m, "penalty", 1, 0.0, 0.0), _batte(_partita(null), "penalty", 1, 0.0, 0.0), "l'altra squadra non cambia")
	H.disposeAll()
	return done()


func test_squadra_che_attacca_verso_il_basso() -> bool:
	var m := _partita({"angD": 106, "angS": 107, "rig": 109}, 1)
	# la squadra 1 attacca verso -y: la sua destra è x < 0
	eq(_batte(m, "corner", 1, -30.0, -49.0), 106, "squadra 1: angolo destro a x < 0")
	eq(_batte(m, "corner", 1, 30.0, -49.0), 107, "squadra 1: angolo sinistro a x > 0")
	eq(_batte(m, "penalty", 1, 0.0, 0.0), 109, "squadra 1: rigorista scelto")
	H.disposeAll()
	return done()


func test_scelto_fuori_dal_campo_vale_il_migliore() -> bool:
	var auto := _batte(_partita(null), "penalty", 0, 0.0, 0.0)
	var altro := 104 if auto != 104 else 105
	var m := _partita({"rig": altro, "angD": 999, "punV": 100})
	eq(_batte(m, "penalty", 0, 0.0, 0.0), altro, "scelto in campo: batte lui")
	for p: R.Player in m.team(0):
		if int(p.src.id) == altro:
			p.off = true # espulso
	eq(_batte(m, "penalty", 0, 0.0, 0.0), auto, "scelto espulso: il migliore in campo")
	eq(_batte(m, "corner", 0, 30.0, 49.0), _batte(_partita(null), "corner", 0, 30.0, 49.0), "id che non c'è (panchina, venduto): automatico")
	var vicina := _batte(m, "freekick", 0, 0.0, C.HL - 20.0)
	check(vicina != 100, "il portiere non batte le punizioni anche se scelto")
	# sostituito: l'id non è più in campo
	var m2 := _partita({"rig": altro})
	var nuovo := {"id": 500, "name": "Nuovo", "pos": "C", "vel": 50, "tir": 50, "pas": 50, "dri": 50, "dif": 50, "fis": 50, "por": 20}
	for p: R.Player in m2.team(0):
		if int(p.src.id) == altro:
			m2.substitute(0, p.i, nuovo)
	check(_batte(m2, "penalty", 0, 0.0, 0.0) != altro, "scelto sostituito: batte un altro")
	H.disposeAll()
	return done()


func test_carriera_salva_le_scelte() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + "piazzati.json"
	Salv.cancella(c.percorso)
	c.create("Prova Piazzati", 1, 44)
	var ch: Dictionary = c.addChampion({"name": "Capitano", "ruolo": "COC", "look": {}, "num": 10})
	eq(c.piazzati(), {"rig": null, "punL": null, "punV": null, "angD": null, "angS": null}, "predefinito: tutto automatico")
	eq(c.capitano().id, ch.id, "il capitano è il campione")
	var tit: Array = c.s.lineup
	var portiere: Dictionary = c.player(tit[0])
	var venduto: int = -1
	for p: Dictionary in c.bench():
		if p.pos != "P" and not p.get("champ", false):
			venduto = p.id
			break
	check(c.setPiazzato("rig", ch.id), "rigorista: il campione")
	check(c.setPiazzato("angD", tit[5]), "angolo destro")
	check(c.setPiazzato("punL", venduto), "punizioni lontane a uno della panchina")
	check(not c.setPiazzato("rig", portiere.id), "il portiere non si può scegliere")
	check(not c.setPiazzato("rig", 99999), "id che non esiste: rifiutato")
	check(not c.setPiazzato("boh", ch.id), "chiave sconosciuta: rifiutata")
	eq(c.piazzati().rig, ch.id, "le scelte rifiutate non cambiano niente")
	eq(c.squadraPartita().piazzati, c.piazzati(), "la squadra della partita porta le scelte al motore")
	check(not c.myMatchTeam().has("piazzati"), "myMatchTeam (confronti col JS) senza scelte")
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "ricaricato")
	eq(c2.piazzati(), c.piazzati(), "scelte salvate e ricaricate")
	eq(c2.sell(venduto), "", "venduto il battitore delle punizioni lontane")
	eq(c2.piazzati().punL, null, "chi esce dalla rosa si toglie dalle scelte")
	eq(c2.piazzati().rig, ch.id, "le altre restano")
	check(c2.setPiazzato("rig", null), "si torna all'automatico")
	eq(c2.piazzati().rig, null, "rigorista automatico")
	# salvataggio vecchio senza il campo
	c2.s.erase("piazzati")
	c2.save()
	var c3 := CarrieraScript.new()
	c3.percorso = c.percorso
	check(c3.load(), "salvataggio senza `piazzati` si carica")
	eq(c3.s.piazzati.size(), 5, "campo nuovo coi predefiniti")
	eq(c3.piazzati().angD, null, "tutto automatico")
	c.reset()
	return done()
