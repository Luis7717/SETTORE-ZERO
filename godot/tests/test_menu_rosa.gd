# Rosa: logica pura (scripts/menu/rosa_logica.gd, porting di src/squad-layout.js e src/ui-squad.js).
# Posizioni delle carte uguali al web (tests/fixtures/menu.json, entro 1/1000 di px: Vector2 è a 32 bit), niente sovrapposizioni, scambi, ordine della
# panchina, tocchi sulle carte (scegli → confronta → scambia), stessi casi di test/unit/squad-layout.test.mjs.
extends "test_base.gd"

const Rosa := preload("res://scripts/menu/rosa_logica.gd")
const D := preload("res://scripts/menu/menu_dati.gd")
const TD := preload("test_menu_dati.gd")


func test_carte_nel_campo_come_il_web() -> bool:
	var n := 0
	for l: Dictionary in TD.fx().layouts:
		var F: Array = C.FORMATIONS[l.f]
		var L := Rosa.field_layout(F, l.W, l.H)
		var ok := near(L.scale, l.L.scale, 1e-9, "%s %dx%d scala" % [l.f, l.W, l.H])
		for i in F.size():
			var a: Vector2 = L.cards[i]
			ok = near(a.x, l.L.cards[i].x, 1e-3, "%s x%d" % [l.f, i]) and ok
			ok = near(a.y, l.L.cards[i].y, 1e-3, "%s y%d" % [l.f, i]) and ok
		if ok:
			n += 1
	note("%d disposizioni identiche al web" % n)
	return done()


func test_nessuna_carta_si_sovrappone_ne_esce_dal_campo() -> bool:
	for f: String in C.FORMATIONS:
		for size: Vector2 in [Vector2(358, 420), Vector2(358, 330), Vector2(320, 300)]:
			var L := Rosa.field_layout(C.FORMATIONS[f], size.x, size.y)
			var cards: Array = L.cards
			for i in cards.size():
				var a: Vector2 = cards[i]
				check(a.x - L.w / 2.0 >= -1e-6 and a.x + L.w / 2.0 <= size.x + 1e-6, "%s carta %d dentro in larghezza" % [f, i])
				for j in range(i + 1, cards.size()):
					check(not Rosa.overlaps(a, cards[j], L.w, L.h), "%s %s: carte %d e %d sovrapposte" % [f, size, i, j])
	return done()


func test_file_della_formazione_dal_portiere_agli_attaccanti() -> bool:
	var rows := Rosa.field_rows(C.FORMATIONS["4-4-2"])
	eq(rows.size(), 4, "4 file")
	eq(rows[0], [0], "portiere da solo")
	eq(rows[1].size(), 4, "difesa a 4")
	eq(rows[3], [9, 10], "attaccanti")
	eq(Rosa.field_rows(C.FORMATIONS["4-2-3-1"]).size(), 5, "4-2-3-1 ha 5 file")
	return done()


func test_scambi_campo_panchina() -> bool:
	var lineup := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
	check(Rosa.can_swap(lineup, 1, 12), "titolare con panchina")
	check(Rosa.can_swap(lineup, 3, 9), "due titolari")
	check(not Rosa.can_swap(lineup, 12, 13), "panchina con panchina no")
	check(not Rosa.can_swap(lineup, 5, 5), "con sé stesso no")
	var dopo := Rosa.swap_lineup(lineup, 3, 12)
	eq(dopo[2], 12, "entra il 12 al posto del 3")
	eq(lineup[2], 3, "la formazione passata non cambia")
	eq(Rosa.swap_lineup(lineup, 2, 9).slice(0, 9), [1, 9, 3, 4, 5, 6, 7, 8, 2], "due titolari si scambiano il posto")
	return done()


func test_variazione_della_forza_con_uno_scambio() -> bool:
	var F: Array = C.FORMATIONS["4-4-2"]
	var lineup: Array = range(1, 12)
	var a := {"id": 10, "pos": "A", "tir": 60, "vel": 60, "dri": 60, "pas": 60, "fis": 60, "dif": 30, "por": 12}
	var b := {"id": 30, "pos": "A", "tir": 80, "vel": 70, "dri": 70, "pas": 60, "fis": 60, "dif": 30, "por": 12}
	var rate := func(p: Dictionary, pos: String) -> int: return D.overall_as(p, pos)
	eq(Rosa.swap_delta(lineup, F, a, b, rate), D.overall_as(b, "A") - D.overall_as(a, "A"), "panchinaro più forte in attacco")
	eq(Rosa.swap_delta(lineup, F, a, a, rate), 0, "stesso giocatore")
	var dif := {"id": 2, "pos": "D", "tir": 30, "vel": 60, "dri": 50, "pas": 50, "fis": 70, "dif": 75, "por": 12}
	var d := Rosa.swap_delta(lineup, F, dif, a, rate)
	eq(d, D.overall_as(a, "D") - D.overall_as(dif, "D") + D.overall_as(dif, "A") - D.overall_as(a, "A"), "due titolari: contano i due posti")
	check(d < 0, "difensore in attacco e attaccante in difesa peggiora")
	return done()


func test_nome_breve_come_il_web() -> bool:
	for coppia: Array in TD.fx().names:
		eq(Rosa.short_name(coppia[0]), coppia[1], "shortName(%s)" % coppia[0])
	return done()


func test_panchina_portieri_prima_poi_valutazione() -> bool:
	var mk := func(id: int, pos: String, v: int) -> Dictionary:
		return {"id": id, "pos": pos, "tir": v, "vel": v, "dri": v, "pas": v, "fis": v, "dif": v, "por": v}
	var lista := [mk.call(1, "A", 60), mk.call(2, "D", 50), mk.call(3, "P", 40), mk.call(4, "D", 70), mk.call(5, "C", 65), mk.call(6, "A", 60)]
	var ord := Rosa.bench_order(lista).map(func(p: Dictionary) -> int: return p.id)
	eq(ord, [3, 4, 2, 5, 1, 6], "P, D (forte prima), C, A (a pari valutazione l'ordine resta)")
	eq(lista[0].id, 1, "l'elenco passato non cambia")
	return done()


func test_tocchi_scegli_confronta_scambia() -> bool:
	var lineup := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
	var c := func(_id: Variant) -> bool: return true
	var s := Rosa.pick_card({"sel": null, "tgt": null}, lineup, 4, c)
	eq(s.sel, 4, "primo tocco sceglie")
	s = Rosa.pick_card(s, lineup, 4, c)
	eq(s.sel, null, "toccare di nuovo lo stesso chiude")
	s = Rosa.pick_card({"sel": 4, "tgt": null}, lineup, 15, c)
	check(s.sel == 4 and s.tgt == 15 and s.swap == null, "secondo tocco apre il confronto")
	s = Rosa.pick_card(s, lineup, 15, c)
	eq(s.swap, [4, 15], "toccare di nuovo il confronto scambia")
	eq(s.just, [4, 15], "e illumina i due appena scambiati")
	check(s.sel == null and s.tgt == null, "dopo lo scambio niente scelto")
	s = Rosa.pick_card({"sel": 14, "tgt": null}, lineup, 15, c)
	check(s.sel == 15 and s.tgt == null, "panchina → panchina: si sceglie l'altro")
	s = Rosa.pick_card({"sel": 4, "tgt": 15}, lineup, 7, c)
	check(s.sel == 4 and s.tgt == 7, "col confronto aperto un altro tocco cambia il confronto")
	var sparito := func(_id: Variant) -> bool: return false
	s = Rosa.pick_card({"sel": 99, "tgt": null}, lineup, 3, sparito)
	eq(s.sel, 3, "scelto venduto: si riparte dal nuovo tocco")
	return done()
