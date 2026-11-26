# Le 8 formazioni (sim/core.gd, Luis 2026-11-24: alle 4 del web si aggiungono 4-5-1, 3-4-3, 5-3-2, 4-1-4-1):
# - ogni formazione ha 11 posti, un solo portiere (il primo) e i ruoli che dice il nome;
# - le 4 del web restano le prime e nello stesso ordine (sorteggio della CPU uguale al JS);
# - carte della Rosa in file come il nome (portiere + una fila per numero);
# - salvataggio con le formazioni nuove: si salva e si ricarica uguale; formazione sconosciuta = 4-4-2;
# - CPU: tutte e 8 escono, in partita la formazione mostrata, giocatori coi ruoli dei posti;
# - una partita breve con ciascuna (da squadra 0 e da squadra 1) senza errori, giocatori in campo, posizioni
#   medie che rispecchiano il modulo (difensori dietro ai centrocampisti, dietro agli attaccanti).
extends "test_base.gd"

const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const Salv := preload("res://scripts/carriera/salvataggio.gd")
const DIR := "user://test_formazioni/"
const NUOVE := ["4-5-1", "3-4-3", "5-3-2", "4-1-4-1", "4-2-4", "4-3-2-1", "4-2-2-2", "4-3-3 offensivo", "4-3-3 difensivo", "4-1-2-1-2 largo"]
## moduli (Luis 2026-11-26) dove il nome non basta: [P, D, C, A] e file di carte nella Rosa
const GRUPPI_ATTESI := {"4-3-2-1": [1, 4, 3, 3]}
const FILE_ATTESE := {"4-3-3 offensivo": 5, "4-3-3 difensivo": 5, "4-1-2-1-2 largo": 5}
const PARTITA_S := 25.0


func _nuova(nome_file: String) -> CarrieraScript:
	DirAccess.make_dir_recursive_absolute(DIR)
	var c := CarrieraScript.new()
	c.percorso = DIR + nome_file
	Salv.cancella(c.percorso)
	c.create("Prova Formazioni", 1, 91)
	return c


func test_otto_formazioni_coi_ruoli_del_nome() -> bool:
	eq(C.FORMATIONS.size(), 14, "14 formazioni")
	eq(C.FORMATIONS.keys().slice(0, 4), C.FORMATIONS_WEB, "le 4 del web restano le prime")
	for f: String in NUOVE:
		check(C.FORMATIONS.has(f), "c'è " + f)
	for f: String in C.FORMATIONS:
		var F: Array = C.FORMATIONS[f]
		eq(F.size(), 11, f + ": 11 posti")
		eq(F[0][0], "P", f + ": il primo è il portiere")
		var conta := {"P": 0, "D": 0, "C": 0, "A": 0}
		for slot: Array in F:
			conta[slot[0]] += 1
			check(absf(slot[1]) <= 1.0 and slot[2] > 0.0 and slot[2] < 0.75, "%s: posto dentro il campo %s" % [f, str(slot)])
		var n: PackedStringArray = f.split("-")
		var centro := 0
		for k in range(1, n.size() - 1):
			centro += int(n[k])
		eq([conta.P, conta.D, conta.C, conta.A], GRUPPI_ATTESI.get(f, [1, int(n[0]), centro, int(n[-1])]), f + ": ruoli come il nome")
		eq(MenuRosa.field_rows(F).size(), FILE_ATTESE.get(f, n.size() + 1), f + ": portiere + una fila di carte per numero")
		check(C.FORMAZIONE_SPIEGA.has(f) and String(C.FORMAZIONE_SPIEGA[f]).length() <= 75, f + ": spiegazione corta")
	for f: String in C.FORMATIONS_WEB:
		check(NUOVE.has(C.FORMAZIONE_CUGINA[f]), f + ": ha una cugina nuova")
		eq(C.FORMAZIONE_CUGINE[f][0], C.FORMAZIONE_CUGINA[f], f + ": la prima cugina è quella di sempre")
		for cug: String in C.FORMAZIONE_CUGINE[f]:
			check(NUOVE.has(cug), cug + ": cugina solo Godot")
	return done()


func test_salva_e_ricarica_le_formazioni_nuove() -> bool:
	var c := _nuova("nuove.json")
	for f: String in NUOVE:
		c.s.formation = f
		c.autoLineup()
		check(c.save(), f + ": salvato")
		var c2 := CarrieraScript.new()
		c2.percorso = c.percorso
		check(c2.load(), f + ": ricaricato")
		eq(c2.s.formation, f, f + ": formazione uguale")
		eq(c2.s.lineup, c.s.lineup, f + ": titolari uguali")
		var F: Array = C.FORMATIONS[f]
		for i in 11:
			var p: Dictionary = c2.player(c2.s.lineup[i])
			if F[i][0] == "P":
				eq(p.pos, "P", f + ": in porta un portiere")
	c.reset()
	return done()


func test_cpu_usa_tutte_le_formazioni() -> bool:
	var c := _nuova("cpu.json")
	var viste := {}
	for stagione in [1, 2, 3, 4]:
		c.s.season = stagione
		for id: String in c.s.teams:
			if id == "me":
				continue
			var t: Dictionary = c.s.teams[id]
			var f := c.formazioneDi(t)
			viste[f] = true
			check(C.FORMATIONS_WEB.has(c.aiMatchTeam(t).formation), "aiMatchTeam senza formazione = come il web")
			var sq := c.avversarioPartita(t)
			eq(sq.formation, f, "in partita la formazione mostrata")
			var F: Array = C.FORMATIONS[f]
			for i in 11:
				if sq.players[i].pos != F[i][0]:
					check(false, "%s: giocatore %d nel ruolo del posto" % [f, i])
					break
	eq(viste.size(), 14, "escono tutte e 14: " + str(viste.keys()))
	c.reset()
	return done()


# posizioni medie (y verso la porta avversaria) per ruolo, dopo una partita breve col bot
func _partita(f: String, squadra: int, sd: int) -> Dictionary:
	var fA := f if squadra == 0 else "4-4-2"
	var fB := f if squadra == 1 else "4-4-2"
	var m := H.newMatch(sd, PARTITA_S, [true, false], H.mkTeam("A", 62, sd * 7 + 1, fA), H.mkTeam("B", 62, sd * 13 + 5, fB), "", {"portaAuto": true})
	var bot := H.Bot.new(sd + 9)
	var somma := {"D": 0.0, "C": 0.0, "A": 0.0}
	var conta := {"D": 0, "C": 0, "A": 0}
	var fuori := 0
	var passi := int(PARTITA_S * 60.0)
	for k in passi:
		m.step(DT)
		bot.stepBot(m)
		m.events.clear()
		if k % 30 != 0:
			continue
		for p: R.Player in m.players:
			if absf(p.x) > C.HW + 6.0 or absf(p.y) > C.HL + 6.0:
				fuori += 1
			if p.team == squadra and somma.has(p.pos):
				somma[p.pos] += p.y * (1.0 if squadra == 0 else -1.0)
				conta[p.pos] += 1
	var out := {"fuori": fuori, "t": m.t}
	H.disposeAll()
	for r: String in somma:
		out[r] = somma[r] / maxf(1.0, conta[r])
	return out


func test_partita_breve_con_ogni_formazione() -> bool:
	for f: String in C.FORMATIONS:
		for squadra in 2:
			var sd := 5 + squadra + C.FORMATIONS.keys().find(f) * 3
			var r := _partita(f, squadra, sd)
			check(r.t > 1.0, "%s (squadra %d): la partita va avanti" % [f, squadra])
			eq(r.fuori, 0, "%s (squadra %d): nessuno lontano dal campo" % [f, squadra])
			check(r.D < r.C and r.C < r.A, "%s (squadra %d): difesa dietro al centrocampo, dietro all'attacco (D %.1f C %.1f A %.1f)" % [f, squadra, r.D, r.C, r.A])
	return done()
