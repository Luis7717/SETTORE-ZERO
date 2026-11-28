# Musiche dei menu (scripts/menu/musiche.gd, Luis 2026-11-28): più brani a rotazione, mai lo stesso due volte di fila.
extends "test_base.gd"

const Mu := preload("res://scripts/menu/musiche.gd")


func test_ci_sono_piu_brani_e_tutti_esistono() -> bool:
	check(Mu.BRANI.size() >= 5, "almeno 5 brani nella lista (sono %d)" % Mu.BRANI.size())
	for b in Mu.BRANI:
		check(ResourceLoader.exists(b), "il brano %s c'è tra i file del gioco" % b)
	eq(Mu.disponibili().size(), Mu.BRANI.size(), "tutti i brani disponibili")
	return done()


func test_mai_lo_stesso_brano_due_volte_di_fila() -> bool:
	var n := Mu.BRANI.size()
	var visti := {}
	for attuale in n:
		for k in 50:
			var p := Mu.prossimo(attuale, n, k / 50.0)
			check(p >= 0 and p < n, "indice valido")
			check(p != attuale, "dopo il brano %d non torna il %d" % [attuale, attuale])
			visti[p] = true
	eq(visti.size(), n, "prima o poi suonano tutti")
	eq(Mu.prossimo(-1, n, 0.0), 0, "primo brano con caso 0")
	eq(Mu.prossimo(-1, n, 0.9999), n - 1, "primo brano con caso quasi 1")
	eq(Mu.prossimo(0, 1, 0.5), 0, "con un brano solo si ripete quello")
	eq(Mu.prossimo(0, 0, 0.5), -1, "nessun brano")
	return done()
