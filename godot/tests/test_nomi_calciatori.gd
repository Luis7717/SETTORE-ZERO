# Nomi dei calciatori (scripts/carriera/nomi_calciatori.gd, Luis 2026-11-28: "praticamente uno diverso per
# giocatore"): tanti cognomi, nome dello stesso paese del cognome, quasi nessun doppione in un campionato.
extends "test_base.gd"

const NC := preload("res://scripts/carriera/nomi_calciatori.gd")
const Car := preload("res://scripts/carriera/carriera.gd")
const JS := preload("res://scripts/carriera/js.gd")


func _init() -> void:
	Car.nomi_web = false # test_carriera.gd lo accende per i confronti col JS


func test_tanti_cognomi_e_nessun_doppione_nelle_liste() -> bool:
	check(NC.quanti_cognomi() >= 700, "almeno 700 cognomi (sono %d)" % NC.quanti_cognomi())
	for paese: Array in NC.PAESI:
		var visti := {}
		for n: String in paese[0]:
			check(not visti.has(n), "nome %s una volta sola nel suo paese" % n)
			visti[n] = true
	return done()


func test_in_un_campionato_quasi_nessun_doppione() -> bool:
	var doppi_peggiori := 0
	for seme in [1, 7, 42, 2026, 99991]:
		var r := JS.rng32(seme)
		var visti := {}
		var doppi := 0
		for i in 300: # circa i giocatori di un campionato (rosa + 11 per ognuna delle altre squadre)
			var n: String = Car.randomName(r)
			if visti.has(n):
				doppi += 1
			visti[n] = true
		doppi_peggiori = maxi(doppi_peggiori, doppi)
	check(doppi_peggiori <= 12, "su 300 giocatori al massimo 12 nomi doppi (con le liste del web erano circa 45) (peggiore: %d)" % doppi_peggiori)
	return done()


func test_nome_dello_stesso_paese_e_due_numeri_casuali() -> bool:
	var r := JS.rng32(5)
	var conta := [0]
	var rc := func() -> float:
		conta[0] += 1
		return r.call()
	for i in 200:
		var n: String = Car.randomName(rc)
		var pezzi := n.split(". ", true, 1)
		eq(pezzi.size(), 2, "forma \"L. Cognome\": %s" % n)
		var ok := false
		for paese: Array in NC.PAESI:
			if (paese[1] as Array).has(pezzi[1]):
				for nome: String in paese[0]:
					if nome.left(1) == pezzi[0]:
						ok = true
		check(ok, "%s: iniziale di un nome del paese del cognome" % n)
	eq(conta[0], 400, "sempre due numeri casuali per nome (la sequenza del seme non cambia)")
	return done()
