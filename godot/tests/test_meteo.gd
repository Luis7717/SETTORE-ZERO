# Meteo e ora del giorno (scripts/partita/meteo.gd): scelta col seme, probabilità per stagione, prove da riga di
# comando. Gli effetti sul motore (pioggia, neve) stanno in test_equivalence.gd (tracce 8 e 9 uguali al JS).
extends "test_base.gd"

const Meteo := preload("res://scripts/partita/meteo.gd")


func _conta(giornata: int, n: int) -> Dictionary:
	var c := {"sereno": 0, "nuvoloso": 0, "pioggia": 0, "neve": 0, "giorno": 0, "tramonto": 0, "notte": 0}
	for s in n:
		var x := Meteo.scegli(s * 7 + 3, giornata)
		c[x.meteo] += 1
		c[x.ora] += 1
	return c


func test_stesso_seme_stesso_meteo() -> bool:
	for s: int in [1, 2, 42, 123456789, -5]:
		eq(Meteo.scegli(s), Meteo.scegli(s), "seme %d" % s)
		eq(Meteo.per_giornata(s, 2, 9), Meteo.per_giornata(s, 2, 9), "giornata, seme %d" % s)
	var x := Meteo.scegli(7)
	check(x.meteo in Meteo.METEO and x.ora in Meteo.ORE, str(x))
	return done()


func test_neve_rara_senza_giornata() -> bool:
	var c := _conta(0, 4000)
	var neve := float(c.neve) / 4000.0
	note("fissa: %s" % str(c))
	check(neve > 0.03 and neve < 0.07, "neve %.3f" % neve)
	check(c.sereno > c.pioggia and c.pioggia > c.neve, str(c))
	check(c.notte > 800 and c.tramonto > 600 and c.giorno > 1400, str(c))
	return done()


func test_stagione_piu_pioggia_e_neve_d_inverno() -> bool:
	var estate := _conta(1, 3000)
	var inverno := _conta(9, 3000)
	note("giornata 1: %s · giornata 9: %s" % [str(estate), str(inverno)])
	eq(estate.neve, 0, "niente neve alla prima giornata (fine estate)")
	check(inverno.neve > 200, "neve d'inverno %d" % inverno.neve)
	check(inverno.pioggia > estate.pioggia, "pioggia: inverno %d, estate %d" % [inverno.pioggia, estate.pioggia])
	# su tutta la stagione la neve resta rara (circa 5%)
	var neve := 0
	for g in range(1, Meteo.GIORNATE + 1):
		neve += int(_conta(g, 500).neve)
	var media := float(neve) / (500.0 * Meteo.GIORNATE)
	check(media > 0.035 and media < 0.075, "neve in una stagione %.3f" % media)
	return done()


func test_prove_da_riga_di_comando_e_app() -> bool:
	eq(Meteo.per_partita({}, {"meteo": "neve", "ora": "notte"}, 5), {"meteo": "neve", "ora": "notte"}, "--meteo e --ora")
	eq(Meteo.per_partita({"meteo": "pioggia", "ora": "tramonto"}, {}, 5), {"meteo": "pioggia", "ora": "tramonto"}, "dall'app")
	eq(Meteo.per_partita({"meteo": "pioggia", "ora": "tramonto"}, {"ora": "giorno"}, 5).ora, "giorno", "la riga di comando vince")
	eq(Meteo.per_partita({}, {}, 5), Meteo.scegli(5), "senza niente: dal seme della partita")
	eq(Meteo.per_partita({}, {}, 5, true), {"meteo": "sereno", "ora": "giorno"}, "allenamento sempre sereno di giorno")
	eq(Meteo.per_partita({"meteo": "grandine"}, {}, 5).meteo, Meteo.scegli(5).meteo, "valore sconosciuto ignorato")
	eq(Meteo.testo({"meteo": "pioggia", "ora": "notte"}), "Notte · Pioggia", "testo")
	eq(Meteo.testo({"meteo": "sereno", "ora": "giorno"}), "Pomeriggio · Sereno", "testo di giorno")
	return done()


func test_di_notte_si_accendono_tutti_e_4_i_fari() -> bool:
	# prima gli aloni cercavano i nodi per nome ("FaroLampade*"): con 4 nodi dallo stesso nome Godot rinomina gli altri
	# (@MeshInstance3D@n) e se ne accendeva uno solo
	const Stadio := preload("res://scripts/stadio.gd")
	var s: Node3D = Stadio.new()
	s._ready()
	eq(s.lampade_fari.size(), 4, "4 torri faro")
	var notte: Node3D = Meteo.new()
	notte._stadio(s, true)
	eq(notte.aloni.size(), 4, "4 aloni di notte")
	var posti := {}
	for i in notte.aloni.size():
		var al: MeshInstance3D = notte.aloni[i]
		near(al.position.distance_to(s.lampade_fari[i].position), 0.0, 0.01, "alone sul suo faro %d" % i)
		posti[Vector2i(signi(int(al.position.x)), signi(int(al.position.z)))] = true
	eq(posti.size(), 4, "un alone per angolo")
	eq((s.lampade_fari[0].material_override as StandardMaterial3D).emission_energy_multiplier, Meteo.NOTTE_LAMPADE, "lampade forti")
	var giorno: Node3D = Meteo.new()
	giorno._stadio(s, false)
	eq(giorno.aloni.size(), 0, "di giorno niente aloni")
	notte.free()
	giorno.free()
	s.free()
	return done()
