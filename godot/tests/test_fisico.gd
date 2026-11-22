# Fisico dei giocatori (scripts/carriera/fisico.gd): altezza e corporatura. Salvataggi vecchi (campione senza i
# campi = medio/normale), giocatori generati sempre uguali dal seme con pesi per ruolo, statistiche della partita
# (copie: carriera e funzioni del JS invariate), editor (setFisico), scala della figura coi piedi a terra.
extends "test_base.gd"

const Fisico := preload("res://scripts/carriera/fisico.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const Coord := preload("res://scripts/coord.gd")
const DIR := "user://prove_fisico/"
const KIT := {"maglia": Color.RED, "calzoncini": Color.WHITE, "calzettoni": Color.RED, "bordino": Color.WHITE}
const LOOK := {"pelle": Color.TAN, "capelli": Color.BLACK}


func _nuova(nome_file: String, seme: int = 77) -> CarrieraScript:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + nome_file
	Salv.cancella(c.percorso)
	c.create("Prova Fisico", 2, seme)
	return c


static func _giocatore(pos: String = "C") -> Dictionary:
	return {"id": 5, "name": "L. Prova", "pos": pos, "age": 24, "vel": 60, "fis": 60, "dri": 60, "tir": 60, "dif": 60,
		"pas": 60, "por": 12, "tes": 60}


# ---------------------------------------------------------------- dati
func test_campione_senza_campi_medio_normale_campi_sbagliati_ignorati() -> bool:
	eq(Fisico.di({"id": 1, "name": "X", "pos": "A", "champ": true}), {"altezza": 1, "corporatura": 1}, "campione vecchio = medio, normale")
	eq(Fisico.di({"id": 1, "name": "X", "champ": true, "altezza": 2, "corporatura": 0}), {"altezza": 2, "corporatura": 0}, "campi validi")
	eq(Fisico.di({"id": 1, "name": "X", "champ": true, "altezza": 7, "corporatura": "a"}), {"altezza": 1, "corporatura": 1}, "campi sbagliati = predefiniti")
	eq(Fisico.di(null), Fisico.PREDEFINITO, "niente giocatore")
	return done()


func test_giocatori_generati_sempre_uguali_e_diversi_tra_loro() -> bool:
	var p := _giocatore("D")
	eq(Fisico.di(p), Fisico.di(p.duplicate()), "stesso giocatore, stesso fisico")
	var visti := {}
	for i in 60:
		var q := p.duplicate()
		q.id = 100 + i
		var f := Fisico.di(q)
		visti["%d%d" % [f.altezza, f.corporatura]] = true
	check(visti.size() >= 6, "fisici diversi tra i giocatori (%d combinazioni)" % visti.size())
	return done()


func test_portieri_e_difensori_piu_spesso_alti() -> bool:
	var alti := {"P": 0, "D": 0, "C": 0, "A": 0}
	var robusti := {"P": 0, "D": 0, "C": 0, "A": 0}
	for pos: String in alti:
		for i in 1000:
			var f := Fisico.daSeme(i * 31 + 7, pos)
			alti[pos] += 1 if f.altezza == 2 else 0
			robusti[pos] += 1 if f.corporatura == 2 else 0
	note("alti su 1000: %s · robusti: %s" % [alti, robusti])
	check(alti.P > 550 and alti.P > alti.D and alti.D > alti.A and alti.D > alti.C, "portieri > difensori > gli altri")
	check(robusti.D > robusti.C and robusti.P > robusti.C, "difensori e portieri più robusti dei centrocampisti")
	return done()


func test_salvataggio_vecchio_e_campione_nuovo_restano_come_il_js() -> bool:
	var c := _nuova("vecchio.json")
	var champ := c.addChampion({"name": "Campione", "pos": "A", "look": {}, "num": 10})
	check(not champ.has("altezza") and not champ.has("corporatura"), "addChampion non scrive i campi (come il JS)")
	check(c.s.squad.all(func(p: Dictionary) -> bool: return not p.has("altezza")), "la rosa non ha campi nuovi")
	c.save()
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "si carica")
	eq(Fisico.di(c2.campione()), Fisico.PREDEFINITO, "campione senza campi = medio, normale")
	check(c2.setFisico(champ.id, 2, 2), "setFisico sul campione")
	check(not c2.setFisico(c2.s.squad[3].id, 0, 0), "solo il campione si sceglie il fisico")
	var c3 := CarrieraScript.new()
	c3.percorso = c.percorso
	check(c3.load(), "si ricarica")
	eq(Fisico.di(c3.campione()), {"altezza": 2, "corporatura": 2}, "il fisico scelto resta nel salvataggio")
	c3.setFisico(champ.id, 9, null)
	eq(Fisico.di(c3.campione()), {"altezza": 2, "corporatura": 2}, "valori sbagliati non cambiano niente")
	c3.reset()
	return done()


# ---------------------------------------------------------------- statistiche
func test_modificatori_equilibrati() -> bool:
	# testa e parate a parte (contano poco per chi gioca fuori porta), i punti dati e tolti quasi si pareggiano
	for a in 3:
		for k in 3:
			var m := Fisico.modificatori({"altezza": a, "corporatura": k})
			var somma := 0
			for s: String in m:
				if s != "por" and s != "tes":
					somma += int(m[s])
			check(absi(somma) <= 1, "%s: somma dei punti senza testa e parate %d (equilibrio)" % [Fisico.testo({"altezza": a, "corporatura": k}), somma])
	eq(Fisico.modificatori(Fisico.PREDEFINITO), {}, "medio e normale non cambiano niente")
	return done()


func test_statistiche_della_partita_col_fisico() -> bool:
	var p := _giocatore("D")
	p["altezza"] = 2
	p["corporatura"] = 2
	var q: Dictionary = Fisico.applica(p)
	eq(q.tes, 70, "alto e robusto: testa +8 +2")
	eq(q.dif, 66, "contrasti +2 +4")
	eq(q.vel, 57, "velocità −1 −2")
	eq(q.dri, 58, "agilità −2")
	eq(q.fis, 58, "resistenza −2")
	eq(p.tes, 60, "l'originale non cambia")
	var b := _giocatore("A")
	b["altezza"] = 0
	b["corporatura"] = 0
	var qb: Dictionary = Fisico.applica(b)
	eq([qb.tes, qb.dri, qb.vel, qb.dif, qb.fis], [50, 63, 63, 54, 61], "basso e snello")
	# nel motore: colpo di testa e contrasti cambiano davvero (effStats)
	var sa := C.effStats(q, "D")
	var sb := C.effStats(qb, "A")   # ognuno nel suo ruolo (fuori ruolo il motore toglie punti)
	check(sa.tes > sb.tes + 15.0, "di testa l'alto robusto è molto più forte (%.1f contro %.1f)" % [sa.tes, sb.tes])
	check(sb.dri > sa.dri and sb.vel > sa.vel, "il basso snello è più agile e veloce")
	return done()


func test_tes_mancante_calcolato_e_limiti() -> bool:
	var p := _giocatore("C")
	p.erase("tes")
	p["altezza"] = 2
	p["corporatura"] = 1   # senza il campo la corporatura verrebbe dal seme
	var q: Dictionary = Fisico.applica(p)
	eq(q.tes, int(C.headingOf(p)) + 8, "senza tes: quello del motore + 8")
	var r := _giocatore("C")
	r.vel = 98
	r.tes = 3
	r["altezza"] = 0
	r["corporatura"] = 0
	var qr: Dictionary = Fisico.applica(r)
	eq(qr.vel, 99, "massimo 99")
	eq(qr.tes, 1, "minimo 1")
	var gk := _giocatore("P")
	gk.por = 70
	gk["altezza"] = 2
	gk["corporatura"] = 1
	eq(Fisico.applica(gk).por, 75, "portiere alto: copre di più")
	return done()


func test_squadre_della_partita_col_fisico_carriera_invariata() -> bool:
	var c := _nuova("squadre.json")
	var champ := c.addChampion({"name": "Campione", "pos": "A", "look": {}, "num": 10})
	c.setFisico(champ.id, 0, 0)
	var base := c.myMatchTeam()
	var t := c.squadraPartita()
	for i in t.players.size():
		var p: Dictionary = t.players[i]
		var orig: Dictionary = c.player(p.id)
		var f := Fisico.di(orig)
		eq([p.altezza, p.corporatura], [f.altezza, f.corporatura], "campi scritti nella copia")
		var m := Fisico.modificatori(f)
		eq(p.vel, clampi(int(orig.vel) + int(m.get("vel", 0)), 1, 99), "velocità di %s" % p.name)
		check(not orig.has("altezza") or orig.get("champ", false), "la carriera non cambia")
	eq(base.players.size(), t.players.size(), "stessi titolari")
	var nm: Variant = c.nextMatch()
	var ai := c.aiMatchTeam(nm.opp)
	var av := c.avversarioPartita(nm.opp)
	check(not ai.players[0].has("altezza"), "aiMatchTeam resta come il JS")
	eq(av.players.size(), ai.players.size(), "avversario: stessi giocatori")
	for i in ai.players.size():
		eq(Fisico.di(av.players[i]), Fisico.di(ai.players[i]), "avversario %d: stesso fisico" % i)
	eq(Fisico.di(c.avversarioPartita(nm.opp).players[4]), Fisico.di(av.players[4]), "sempre uguale")
	c.reset()
	return done()


# ---------------------------------------------------------------- grafica
func _altezza_testa(f: Node3D, nome: String) -> float:
	return (f.transform * f.corpo.transform * f.pos_corpo(nome)).y


func test_scala_della_figura_piedi_a_terra() -> bool:
	var medio := Fisico.scala(Fisico.PREDEFINITO)
	eq(medio, Vector3.ONE, "medio normale = scala di sempre")
	var alto := Fisico.scala({"altezza": 2, "corporatura": 1})
	var basso := Fisico.scala({"altezza": 0, "corporatura": 1})
	var snello := Fisico.scala({"altezza": 1, "corporatura": 0})
	var robusto := Fisico.scala({"altezza": 1, "corporatura": 2})
	check(alto.y > 1.04 and basso.y < 0.96, "alto %.2f, basso %.2f" % [alto.y, basso.y])
	check(snello.x < 0.95 and robusto.x > 1.05 and snello.y == 1.0 and robusto.y == 1.0, "la corporatura cambia solo la larghezza")
	eq(robusto.x, robusto.z, "uguale in X e Z (girando non si deforma)")
	var hs: Array = []
	for f_: Dictionary in [{"altezza": 0, "corporatura": 1}, Fisico.PREDEFINITO, {"altezza": 2, "corporatura": 1}]:
		var f := Figura.new()
		f.prepara(KIT, LOOK, 0.0, TV.avviso())
		f.scale = Coord.SCALE * Fisico.scala(f_)
		hs.append(_altezza_testa(f, "Head"))
		var piede := minf(_altezza_testa(f, "foot_l"), _altezza_testa(f, "foot_r"))
		check(piede > -0.02 and piede < 0.2, "%s: piedi a terra (%.3f m)" % [Fisico.testo(f_), piede])
		f.free()
	note("testa: basso %.2f m, medio %.2f m, alto %.2f m" % hs)
	near(hs[2] / hs[1], 1.06, 0.005, "l'alto ha la testa più in alto del 6%")
	near(hs[0] / hs[1], 0.94, 0.005, "il basso più in basso del 6%")
	return done()
