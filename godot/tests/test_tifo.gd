# Pubblico che reagisce in partita vera (2026-11-22): i fatti del motore (tiro, parata, palo, fallo) passano da
# scripts/partita/tifo_eventi.gd alla vista (folla 3D di scripts/stadio/pubblico.gd) e ai cori (audio_partita.gd).
# Prima solo prova_vista.gd faceva reagire la folla; gioco.gd ora chiama lo stesso codice in _eventi.
extends "test_base.gd"

const TifoEventi := preload("res://scripts/partita/tifo_eventi.gd")
const Stadio := preload("res://scripts/stadio.gd")


# vista e audio finti: ricordano le chiamate (la vista vera ha tifo(tipo, squadra), l'audio occasione())
class VistaFinta:
	extends RefCounted
	var chiamate: Array = []
	var stadio: Node3D = null

	func tifo(tipo: String, squadra: int) -> void:
		chiamate.append([tipo, squadra])
		if stadio != null:
			stadio.tifo(tipo, squadra)


class AudioFinto:
	extends RefCounted
	var occasioni := 0

	func occasione() -> void:
		occasioni += 1


func test_eventi_del_motore_in_reazioni() -> bool:
	var t := TifoEventi.new()
	var p0 := R.Player.new()
	p0.team = 0
	var p1 := R.Player.new()
	p1.team = 1
	eq(t.leggi({"type": "kick", "p": p1, "kind": "shot"}), ["occasione", 1], "tiro = occasione")
	eq(t.leggi({"type": "post"}), ["palo", 1], "il palo va a chi ha tirato per ultimo")
	eq(t.leggi({"type": "save", "p": p0, "catch": true}), ["parata", 0], "parata del portiere")
	eq(t.leggi({"type": "foul", "by": p0}), ["fischio", 0], "fallo")
	eq(t.leggi({"type": "kick", "p": p0, "kind": "header"}), ["occasione", 0], "colpo di testa in porta")
	eq(t.leggi({"type": "kick", "p": p0, "kind": "header", "clear": true}), [], "rinvio di testa: niente")
	eq(t.leggi({"type": "kick", "p": p0, "kind": "pass"}), [], "passaggio: niente")
	eq(t.leggi({"type": "goal", "team": 0}), [], "il gol lo vede la vista dal punteggio")
	# senza tifo() (vista finta di gioco.gd) non si rompe
	eq(t.applica({"type": "post"}, RefCounted.new()), "palo", "vista senza tifo()")
	return done()


func test_partita_vera_fa_reagire_folla_e_cori() -> bool:
	# IA contro IA: gli eventi veri del motore arrivano alla folla 3D dello stadio vero e ai cori
	var s: Node3D = Stadio.new()
	s._ready()
	var v := VistaFinta.new()
	v.stadio = s
	var a := AudioFinto.new()
	var t := TifoEventi.new()
	var m := H.newMatch(21, 9999.0, [false, false], H.mkTeam("A", 60, 1), H.mkTeam("B", 60, 2))
	var base: Vector4 = s.pubblico.stato(0) + s.pubblico.stato(1)
	var tipi := {}
	var mosso := false
	for i in 60 * 240:
		m.step(DT)
		for e: Dictionary in m.events:
			var r := t.applica(e, v, a)
			if r != "":
				tipi[r] = int(tipi.get(r, 0)) + 1
				if r == "occasione" and not mosso:
					# la folla insegue il nuovo stato: dopo mezzo secondo è più in piedi di prima
					for k in 30:
						s.pubblico.aggiorna(DT)
					var ora: Vector4 = s.pubblico.stato(0) + s.pubblico.stato(1)
					mosso = ora.x > base.x + 0.1
		m.events.clear()
	note("reazioni in 240 s: %s, cori su %d volte" % [tipi, a.occasioni])
	check(int(tipi.get("occasione", 0)) >= 2, "qualche tiro")
	check(tipi.has("parata") or tipi.has("palo"), "almeno una parata o un palo")
	eq(a.occasioni, int(tipi.get("occasione", 0)), "i cori salgono a ogni occasione")
	eq(v.chiamate.size(), tipi.values().reduce(func(x, y): return x + y, 0), "ogni reazione arriva alla vista")
	check(mosso, "sull'occasione i tifosi si alzano")
	s.free()
	return done()
