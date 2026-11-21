# Esultanze del campione (fase C, punto 12): elenco e valore salvato (partita/esultanze.gd), pose calcolate
# (mosse/esultanza.gd: piedi mai sotto terra, mani mai dentro il busto, durata dentro la festa del gol), figura che
# le esegue (figura.gd), chi esulta dopo un gol (esultanza_regia.gd) e salvataggio nella carriera (anche vecchio).
extends "test_base.gd"

const Esultanze := preload("res://scripts/partita/esultanze.gd")
const E := preload("res://scripts/partita/mosse/esultanza.gd")
const Corpo := preload("res://scripts/partita/mosse/corpo.gd")
const Regia := preload("res://scripts/partita/esultanza_regia.gd")
const Figura := preload("res://scripts/partita/figura.gd")
const TV := preload("res://scripts/partita/texture_vista.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const DIR := "user://prove_carriera/"
const FESTA_GOL := 3.2         # s di pausa dopo il gol nel motore (goalT di sim/match.gd)
const PASSO := 1.0 / 30.0


func test_quindici_esultanze_con_nome_e_predefinita() -> bool:
	var ids := Esultanze.ids()
	eq(ids.size(), 15, "quindici esultanze")
	var visti := {}
	for e: Array in Esultanze.ELENCO:
		check(not visti.has(e[0]), "id doppio " + str(e[0]))
		visti[e[0]] = true
		check(str(e[1]).length() > 3, "nome di " + str(e[0]))
	check(ids.has(Esultanze.PREDEFINITA), "la predefinita è nell'elenco")
	eq(Esultanze.valida(null), Esultanze.PREDEFINITA, "manca → predefinita")
	eq(Esultanze.valida("moonwalk"), Esultanze.PREDEFINITA, "sconosciuta → predefinita")
	eq(Esultanze.valida(7), Esultanze.PREDEFINITA, "numero → predefinita")
	eq(Esultanze.valida("capriola"), "capriola", "buona resta")
	eq(Esultanze.nome("saluto"), "Saluto militare", "nome")
	return done()


# piede (caviglia) e mani nel riferimento del campo: corpo intero (salti, capriola, giri) applicato alla posa
func test_pose_credibili_piedi_sopra_terra_mani_fuori_dal_busto() -> bool:
	for id: String in Esultanze.ids():
		var c: E.Coreografia = E.coreografia(id)
		check(c.T >= 2.4 and c.T <= FESTA_GOL - 0.15, "%s: durata %.2f s dentro la festa del gol" % [id, c.T])
		var t0 := E.posa(id, 0.0)
		check((t0.corpo as Transform3D).origin.length() < 0.15, "%s: parte dal posto del giocatore" % id)
		var piede_min := INF
		var bacino_min := INF
		var mano_dentro := ""
		var t := 0.0
		while t <= c.T + 1e-6:
			var po := E.posa(id, t)
			var fr: Dictionary = po.fr
			var tr: Transform3D = po.corpo
			var w_gambe := 1.0 - float(po.corsa)   # correndo le gambe le fa il clip (sempre sopra terra)
			if w_gambe > 0.5:
				for s: String in ["l", "r"]:
					piede_min = minf(piede_min, (tr * (fr.legs[s].ankle as Vector3)).y)
			bacino_min = minf(bacino_min, (tr * (fr.pelvis.p as Vector3)).y)
			if float(po.braccia) > 0.5:
				var q3: Quaternion = fr.rot.spine_03
				var p3: Vector3 = Corpo.trunk(fr.pelvis.p, fr.pelvis.q, c.mv.bend_at(t)).p.spine_03
				for s: String in ["l", "r"]:
					var h: Vector3 = q3.inverse() * ((fr.arms[s].hand as Vector3) - p3)
					if absf(h.x) < 0.13 and h.z < 0.1 and h.y > -0.45 and h.y < 0.2 and mano_dentro == "":
						mano_dentro = "%s a %.2f s (%s)" % [s, t, h]
			t += PASSO
		check(piede_min > Corpo.ANKLE_H - 0.025, "%s: caviglia più bassa %.3f (sotto terra?)" % [id, piede_min])
		check(bacino_min > 0.4, "%s: bacino più basso %.3f" % [id, bacino_min])
		check(mano_dentro == "", "%s: mano dentro il busto, %s" % [id, mano_dentro])
	return done()


func test_capriola_gira_tutta_e_giravolta_pure() -> bool:
	var c: E.Coreografia = E.coreografia("capriola")
	var b_meta: Basis = (E.posa("capriola", 1.07).corpo as Transform3D).basis
	check((b_meta * Vector3.UP).y < -0.3, "a metà volo è a testa in giù: %s" % (b_meta * Vector3.UP))
	var fine: Transform3D = E.posa("capriola", c.T).corpo
	check((fine.basis * Vector3.UP).y > 0.99, "atterra dritto")
	check(fine.origin.z > 1.5, "è andato avanti: %.2f" % fine.origin.z)
	var g: Basis = (E.posa("giravolta", 0.72).corpo as Transform3D).basis
	check((g * Vector3.BACK).z < 0.0, "giravolta: a metà guarda indietro")
	check(((E.posa("giravolta", 2.7).corpo as Transform3D).basis * Vector3.BACK).z > 0.99, "finita guarda avanti")
	return done()


func test_corsa_col_clip_vero_alla_velocita_giusta() -> bool:
	var po := E.posa("aeroplano", 1.0)
	eq(po.corsa, 1.0, "aeroplano: corre col clip")
	check(float(po.vel) > 2.0 and float(po.vel) < 4.5, "velocità del clip %.2f m/s" % po.vel)
	eq(po.braccia, 1.0, "le braccia larghe le fa la posa calcolata")
	var g := E.posa("ginocchio", 0.2)
	eq(g.braccia, 0.0, "scivolata: nella rincorsa le braccia corrono col clip")
	eq(E.posa("ginocchio", 2.0).corsa, 0.0, "in ginocchio niente clip di corsa")
	eq(E.posa("pugno", 1.0).corsa, 0.0, "pugno: sul posto")
	return done()


func test_la_figura_esegue_e_poi_torna_normale() -> bool:
	var f := Figura.new()
	f.prepara({"maglia": Color.RED}, {"pelle": Color.TAN}, 0.0, TV.avviso())
	var p := R.Player.new()
	var ctx := {"t": 0.0, "phase": "goal", "flip": 1.0, "yaw": 0.0, "ball": null, "trick": null}
	f.posa(p, 0.0, ctx)
	var bacino0: float = f.pos_corpo("pelvis").y
	var po := E.posa("ginocchio", 2.0)
	f.esultanza = po
	f.posa(p, 0.0, ctx)
	check(f.pos_corpo("pelvis").y < 0.65, "in ginocchio: bacino a %.2f" % f.pos_corpo("pelvis").y)
	check(f.corpo.position.z > 2.0, "scivolato avanti: %.2f" % f.corpo.position.z)
	var mano: Vector3 = f.pos_corpo("hand_l")
	check(mano.distance_to(po.fr.arms.l.hand) < 0.06, "mano sinistra dove la vuole la posa: %s contro %s" % [mano, po.fr.arms.l.hand])
	check(mano.y > f.pos_corpo("pelvis").y + 0.7, "braccia al cielo: mano a %.2f" % mano.y)
	po = E.posa("saluto", 2.0)
	f.esultanza = po
	f.posa(p, 0.0, ctx)
	check(f.pos_corpo("hand_r").distance_to(po.fr.arms.r.hand) < 0.06, "saluto: mano destra alla fronte")
	f.esultanza = null
	f.posa(p, 0.0, ctx)
	check(f.corpo.position.length() < 1e-4, "finita: corpo al suo posto")
	near(f.pos_corpo("pelvis").y, bacino0, 0.02, "finita: bacino come prima")
	f.free()
	return done()


func test_esulta_solo_il_campione_della_mia_squadra() -> bool:
	var camp := R.Player.new()
	camp.src = {"champ": true, "esultanza": "cuore"}
	var altro := R.Player.new()
	altro.src = {"name": "Altro"}
	var vecchio := R.Player.new()
	vecchio.src = {"champ": true}   # salvataggio vecchio: niente campo → predefinita
	eq(Regia.esultanza_del_gol({"team": 0, "scorer": camp, "og": false}, 0), "cuore", "gol del campione")
	eq(Regia.esultanza_del_gol({"team": 0, "scorer": vecchio, "og": false}, 0), Esultanze.PREDEFINITA, "campione senza scelta")
	eq(Regia.esultanza_del_gol({"team": 0, "scorer": altro, "og": false}, 0), "", "gol di un altro: come oggi")
	eq(Regia.esultanza_del_gol({"team": 1, "scorer": camp, "og": false}, 0), "", "gol dell'altra squadra")
	eq(Regia.esultanza_del_gol({"team": 0, "scorer": null, "og": true}, 0), "", "autogol")
	return done()


func test_carriera_salva_l_esultanza_solo_del_campione() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + "esultanza.json"
	Salv.cancella(c.percorso)
	c.create("Prova Esultanze", 2, 77)
	var champ := c.addChampion({"name": "Campione", "pos": "A", "look": {}, "num": 10})
	check(not champ.has("esultanza"), "addChampion resta come il JS (niente campo nuovo)")
	eq(CarrieraScript.esultanza_di(champ), Esultanze.PREDEFINITA, "senza campo: predefinita")
	check(c.setEsultanza(champ.id, "bandierina"), "il campione la sceglie")
	var altro: Dictionary = c.s.squad[3]
	check(not c.setEsultanza(altro.id, "capriola"), "un altro giocatore no")
	check(not altro.has("esultanza"), "e non gli resta il campo")
	check(c.setEsultanza(champ.id, "nonesiste"), "valore sbagliato…")
	eq(c.campione().esultanza, Esultanze.PREDEFINITA, "… diventa la predefinita")
	c.setEsultanza(champ.id, "silenzio")
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "si ricarica")
	eq(CarrieraScript.esultanza_di(c2.campione()), "silenzio", "salvata nel file")
	c.reset()
	return done()


func test_salvataggio_vecchio_senza_il_campo_si_carica() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + "esultanza_vecchio.json"
	Salv.cancella(c.percorso)
	c.create("Prova Vecchio", 4, 78)
	c.addChampion({"name": "Vecchio", "pos": "C", "look": {}, "num": 8})
	var st: Dictionary = c.s.duplicate(true)
	for p: Dictionary in st.squad:
		p.erase("esultanza")
	Salv.scrivi(c.percorso, st)
	var c2 := CarrieraScript.new()
	c2.percorso = c.percorso
	check(c2.load(), "il salvataggio vecchio si carica")
	var ch: Variant = c2.campione()
	check(ch is Dictionary, "il campione c'è")
	eq(CarrieraScript.esultanza_di(ch), Esultanze.PREDEFINITA, "esultanza predefinita")
	check(c2.setEsultanza(ch.id, "ballo"), "e la si può scegliere")
	c.reset()
	return done()
